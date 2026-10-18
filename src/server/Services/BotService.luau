--!strict
-- Bots (GDD §18): fill every round to Config.Bots.FILL_TARGET participants with bodies that move exactly like players
-- (Shared/MovementCore, the same physics and techniques; Shared/Locomotion for animation) and play the bomb game with
-- bomb-aware brains (Logic/BombBrain): Runners pick lanes and dodge, Carriers defuse or pass, Bombers hunt and spread.
-- Bots wear real avatars when AvatarPool has one ready (never a name: bots keep generated names). D-LOBBY-02: they
-- wear the humans' friends, split evenly between the humans here (rebalanced at every intermission, as looks arrive).
-- Round modifiers (GDD §6.4): bots play by what a player could see. Under READ THE FACE a LIT bomb is assumed to be
-- about to turn HOT; under LIGHTS OUT a bot Runner only sees a Bomber by its eye glints or a bomb's light; a bot Mole
-- strikes a nearby Runner some time after GO.
-- Implements: F-BOT-01..06, F-MOD-02..04 (bots).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Locomotion = require(ReplicatedStorage.Shared.Locomotion)
local MovementCore = require(ReplicatedStorage.Shared.MovementCore)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local BombBrain = require(ServerScriptService.Server.Logic.BombBrain)
local AdminService = require(script.Parent.AdminService)
local Arena = require(script.Parent.Arena)
local AvatarPool = require(script.Parent.AvatarPool)
local Characters = require(script.Parent.Characters)
local GameState = require(script.Parent.GameState)
local ModifierService = require(script.Parent.ModifierService)
local MoveService = require(script.Parent.MoveService)
local Participants = require(script.Parent.Participants)

type Participant = Participants.Participant

local BC = Config.Bots
local MOD = Config.Modifiers
local R, S, Ph = Types.Role, Types.State, Types.Phase
local FLAT = Vector3.new(1, 0, 1)

local BotService = {}

type Tier = { reaction: number, error: number, dash: number, pace: number }

type Brain = {
	tier: Tier,
	tierName: string,
	ms: MovementCore.State,
	params: MovementCore.Params,
	loco: Locomotion.Loco?,
	desired: Vector3,
	steerDir: Vector3,
	nextDecide: number,
	crossingKey: string,
	laneX: number,
	startAt: number,
	targetId: string?,
	lobbyGoal: Vector3?, -- between rounds: the Depot station it's strolling to
	lobbyNext: number?,
}

local brains: { [string]: Brain } = {}
local rng = Random.new()

-- The Depot's stations bots stroll between (GDD §19.1), gathered once.
local depotSpots: { Vector3 }? = nil
local function lobbySpots(): { Vector3 }
	if depotSpots then
		return depotSpots
	end
	local spots = {}
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby then
		for _, n in ipairs({
			"ShopPromptPart",
			"Cork",
			"Dispenser",
			"Dummy1",
			"Dummy2",
			"Cobbles",
			"StatuePlinth2",
			"Base",
		}) do
			local x = lobby:FindFirstChild(n, true)
			local pos = if x and x:IsA("BasePart")
				then x.Position
				elseif x and x:IsA("Model") then x:GetPivot().Position
				else nil
			if pos then
				table.insert(spots, pos + Vector3.new(0, 0, -3)) -- stand in front of it, not inside it
			end
		end
	end
	depotSpots = spots
	return spots
end
local nextBotId = 0
local frozen = false -- Studio: "botfreeze" stops every bot (manual tests)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flatUnit(v: Vector3): Vector3
	local f = v * FLAT
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zero
end

-- ── Population ──────────────────────────────────────────────────────────────────────────────────────────────────
local function botsFolder(): Folder
	local f = workspace:FindFirstChild("Bots") :: Folder?
	if not f then
		f = Instance.new("Folder")
		assert(f, "folder")
		f.Name = "Bots"
		f.Parent = workspace
	end
	return f :: Folder
end

local function pickTier(mix: { [string]: number }): string
	local roll = rng:NextNumber()
	local acc = 0
	for _, name in ipairs({ "Rookie", "Regular", "Pro" }) do
		acc += mix[name] or 0
		if roll <= acc then
			return name
		end
	end
	return "Regular"
end

local function newbiePresent(): boolean
	for _, p in ipairs(Participants.humans()) do
		if (p.data.roundsPlayed or 0) < 2 then
			return true
		end
	end
	return false
end

local function uniqueName(): string
	local taken = {}
	for _, p in ipairs(Participants.all()) do
		taken[p.name] = true
	end
	for _ = 1, 40 do
		local name = BC.NAME_A[rng:NextInteger(1, #BC.NAME_A)] .. BC.NAME_B[rng:NextInteger(1, #BC.NAME_B)]
		if rng:NextNumber() < 0.4 then
			name ..= tostring(rng:NextInteger(1, 99))
		end
		if not taken[name] then
			return name
		end
	end
	return "Player" .. tostring(rng:NextInteger(100, 999))
end

local function spawnBot(prefer: number?): Participant?
	nextBotId += 1
	local name = uniqueName()
	local model: Model? = nil
	local okPool, rig, _, avatarId, owner = pcall(AvatarPool.takeRig, prefer)
	if okPool and rig then
		model = rig
		Characters.prepareAvatarRig(rig, name)
	end
	if not model then
		model = Characters.buildBot(name, rng)
	end
	local m = model :: Model
	m:PivotTo(Characters.lobbyCFrame()) -- The Depot (or the start strip in a place without a lobby)
	m.Parent = botsFolder()
	local p = Participants.addBot("B" .. nextBotId, name, m, rng:NextInteger(1, 35), rng:NextInteger(0, 60))
	p.data.avatarId = if okPool then avatarId else nil -- whose look it wears…
	p.data.avatarOwner = if okPool then owner else nil -- …and whose friend that is (nil = a filler)
	local root = p.root
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	Characters.applyGroup(p)
	local tierName = pickTier(if newbiePresent() then BC.NEWBIE_MIX else BC.TIER_MIX)
	brains[p.id] = {
		tier = (BC.TIERS :: any)[tierName],
		tierName = tierName,
		ms = MovementCore.newState(),
		params = MovementCore.defaultParams(),
		loco = if p.humanoid then Locomotion.new(p.humanoid) else nil,
		desired = Vector3.zero,
		steerDir = Vector3.zero,
		nextDecide = 0,
		crossingKey = "",
		laneX = 0,
		startAt = 0,
		targetId = nil,
	}
	m:SetAttribute("BotTier", tierName)
	return p
end

local function despawn(p: Participant)
	local brain = brains[p.id]
	if brain and brain.loco then
		brain.loco:destroy()
	end
	brains[p.id] = nil
	AvatarPool.release(p.data.avatarId)
	Participants.remove(p)
	if p.model then
		p.model:Destroy()
	end
end

-- D-LOBBY-02: the bots wear the humans' friends, split evenly (2 players → half each). A bot wearing a filler look, a
-- look of someone who left, or more than its owner's share is swapped for a look of the player furthest under their
-- share, while the pool has one built. Runs at INTERMISSION (everyone's in The Depot, the post-round flash covers it).
function BotService.balanceLooks()
	local owners: { number } = {}
	for _, h in ipairs(Participants.humans()) do
		if h.player then
			table.insert(owners, h.player.UserId)
		end
	end
	local bots = Participants.bots()
	if #owners == 0 or #bots == 0 then
		return
	end
	local share: { [number]: number } = {}
	for i, owner in ipairs(owners) do
		share[owner] = math.floor(#bots / #owners) + (if i <= #bots % #owners then 1 else 0)
	end
	local count: { [number]: number } = {}
	for _, b in ipairs(bots) do
		local o = b.data.avatarOwner
		if o and share[o] then
			count[o] = (count[o] or 0) + 1
		end
	end
	local function neediest(): number?
		local best: number? = nil
		local gap = 0
		for _, owner in ipairs(owners) do
			local g = share[owner] - (count[owner] or 0)
			if g > gap and AvatarPool.readyFor(owner) > 0 then
				best, gap = owner, g
			end
		end
		return best
	end
	for _, b in ipairs(bots) do
		local o = b.data.avatarOwner
		local misfit = not o or not share[o] or (count[o] or 0) > share[o]
		if misfit then
			local want = neediest()
			if not want then
				break
			end
			if o and count[o] then
				count[o] -= 1
			end
			despawn(b)
			if spawnBot(want) then -- (it lands in The Depot)
				count[want] = (count[want] or 0) + 1
			end
		end
	end
end

-- F-BOT-01: at INTERMISSION, fill to FILL_TARGET (or trim bots when humans need the room); re-roll tiers so a new
-- player's first rounds get the easier mix.
function BotService.fill()
	local target = BC.FILL_TARGET
	local all = Participants.all()
	local bots = Participants.bots()
	local humans = #all - #bots
	local want = math.max(0, math.min(target, Config.Game.MAX_PLAYERS) - humans)
	while #Participants.bots() > want do
		local list = Participants.bots()
		despawn(list[#list])
	end
	for _ = 1, want - #Participants.bots() do
		spawnBot()
	end
	BotService.balanceLooks()
	local mix = if newbiePresent() then BC.NEWBIE_MIX else BC.TIER_MIX
	for id, brain in pairs(brains) do
		brain.tierName = pickTier(mix)
		brain.tier = (BC.TIERS :: any)[brain.tierName]
		local p = Participants.get(id)
		if p and p.model then
			p.model:SetAttribute("BotTier", brain.tierName)
		end
	end
end

-- ── Seeing ──────────────────────────────────────────────────────────────────────────────────────────────────────
type Seen = { p: Participant, pos: Vector3, vel: Vector3, carrying: boolean, safe: boolean, active: boolean }

-- F-MOD-03: in the dark a Runner sees a Bomber only by its eye glints (EYE_RANGE) or inside a bomb's light.
local function litFor(self: Participant, q: Participant, pos: Vector3, lamps: { Vector3 }): boolean
	if self.role ~= R.Runner or q.role ~= R.Bomber or not self.root then
		return true
	end
	if ((pos - self.root.Position) * FLAT).Magnitude <= MOD.EYE_RANGE then
		return true
	end
	for _, l in ipairs(lamps) do
		if ((pos - l) * FLAT).Magnitude <= MOD.LAMP.LIT then
			return true
		end
	end
	return false
end

local function look(self: Participant): { Seen }
	local out = {}
	local t = now()
	local dark = GameState.get("Modifier") == "LightsOut"
	local lamps: { Vector3 } = {}
	if dark then
		for _, q in ipairs(Participants.all()) do
			if q.root and q.attrs:GetAttribute("BombId") ~= nil then
				table.insert(lamps, q.root.Position)
			end
		end
	end
	for _, q in ipairs(Participants.all()) do
		local root = q.root
		if
			q ~= self
			and root
			and root.Parent
			and (q.role == R.Runner or q.role == R.Bomber)
			and (not dark or litFor(self, q, root.Position, lamps))
		then
			local pos = root.Position
			table.insert(out, {
				p = q,
				pos = pos,
				vel = root.AssemblyLinearVelocity,
				carrying = q.attrs:GetAttribute("BombId") ~= nil,
				safe = Arena.inSafe(pos, -1) or Arena.inSafe(pos, 1),
				active = q.state == S.Active and not q.data.ragdolled and (q.data.stunnedUntil or 0) <= t,
			})
		end
	end
	return out
end

local function liveRun(): boolean
	local phase = GameState.get("Phase")
	return phase == Ph.Crossing or (phase == Ph.LastStand and GameState.get("SubPhase") == Types.Sub.Run)
end

-- A technique on behalf of a bot: the same MovementCore move a player gets, recorded and shown to every client.
local function technique(p: Participant, brain: Brain, kind: string, dir: Vector3)
	local ok = false
	if kind == "Dash" then
		ok = MovementCore.dash(brain.ms, dir)
	elseif kind == "HardStop" then
		ok = MovementCore.hardStop(brain.ms, brain.params)
	elseif kind == "Slide" then
		ok = MovementCore.slide(brain.ms, brain.params)
	end
	if ok then
		MoveService.recordTech(p, kind)
		Net.fireAll("ActionFx", {
			who = p.id,
			kind = kind,
			pos = if p.root then p.root.Position else nil,
			side = if kind == "Dash" then MovementCore.dashSide(brain.ms) else nil,
		})
	end
end

-- ── Deciding ────────────────────────────────────────────────────────────────────────────────────────────────────
local function runnerDecide(p: Participant, brain: Brain, root: BasePart, seen: { Seen })
	local f = assert(Arena.current, "no arena")
	local from = GameState.get("StartSide") or -1
	local to = -from
	local halfLen, halfW = f.halfLen, Arena.halfWidth()
	local key = `{GameState.get("Crossing")}:{GameState.get("Phase")}`
	if brain.crossingKey ~= key then
		brain.crossingKey = key
		brain.laneX = rng:NextNumber(-halfW * 0.8, halfW * 0.8)
		-- Wait for a gap only while the fuse still leaves the whole run (with 25 % slack for dodging).
		local fuse = GameState.get("FuseTotal") or 10
		local travel = halfLen * 2 / (Config.Movement.MAX_SPEED * brain.tier.pace)
		local latest = math.max(0, fuse - travel * 1.25)
		brain.startAt = now() + math.min(BombBrain.startDelay(fuse, rng:NextNumber()), latest)
	end
	if p.state ~= S.Active then
		brain.desired = Vector3.zero -- made it (Safe) or not in play
		return
	end
	local pos = root.Position
	local x = Arena.toLocal(pos)
	local fuseLeft = (GameState.get("FuseEndsAt") or 0) - now()
	local urgent = fuseLeft < 4
	if now() < brain.startAt and not urgent and Arena.inSafe(pos, from) then
		brain.desired = Vector3.zero -- waiting for a gap
		return
	end
	local threats, carriers = {}, {}
	local nearest: Seen? = nil
	local nearestD = math.huge
	for _, s in ipairs(seen) do
		if s.active and s.p.role == R.Bomber then
			table.insert(threats, s.pos)
			local d = ((s.pos - pos) * FLAT).Magnitude
			if d < nearestD then
				nearest, nearestD = s, d
			end
		elseif s.carrying and s.p.role == R.Runner then
			table.insert(carriers, s.pos)
		end
	end
	local goal = Arena.toWorld(brain.laneX, to * (halfLen + 4), 0)
	local dir = flatUnit(goal - pos)
	local push = BombBrain.threatPush(pos, threats, BC.THREAT_RADIUS) * (if urgent then 0.6 else 1.4)
		+ BombBrain.threatPush(pos, carriers, BC.CARRIER_AVOID) * 1.2
	-- Keep heading forward: a push may bend the line sideways, never turn the run round.
	local forward = Arena.toWorld(0, to, 0) - Arena.toWorld(0, 0, 0)
	local pushLateral = push - flatUnit(forward) * math.min(0, push:Dot(flatUnit(forward)))
	brain.desired = flatUnit(dir + pushLateral)
	-- Adapt the lane toward where the push sends us.
	local nx = Arena.toLocal(pos + brain.desired * 6)
	brain.laneX = math.clamp(brain.laneX + (nx - x) * 0.25, -halfW * 0.85, halfW * 0.85)
	-- Dodge a committed Bomber (F-BOT-02).
	if nearest and nearestD < BC.DODGE_RADIUS and rng:NextNumber() < brain.tier.dash * 0.5 then
		local closing = (nearest.vel * FLAT):Dot(flatUnit(pos - nearest.pos)) > 4
		if closing then
			if MovementCore.canDash(brain.ms) then
				local away = flatUnit(pos - nearest.pos)
				local side = Vector3.new(-away.Z, 0, away.X) * (if rng:NextNumber() < 0.5 then 1 else -1)
				technique(p, brain, "Dash", flatUnit(side + dir * 0.6))
			else
				technique(p, brain, "HardStop", Vector3.zero)
			end
		end
	end
end

-- F-MOD-04: a bot Mole blends in as a Runner, then, some time after GO, strikes a Runner close by on the field and
-- runs it down while the strike is armed. Returns true when it took over this decision.
local function moleDecide(p: Participant, brain: Brain, root: BasePart, seen: { Seen }): boolean
	if not p.data.mole or p.state ~= S.Active then
		return false
	end
	local t = now()
	local pos = root.Position
	local best: Seen? = nil
	local bestD = math.huge
	for _, s in ipairs(seen) do
		if s.p.role == R.Runner and s.active and not s.safe and not s.carrying then
			local d = ((s.pos - pos) * FLAT).Magnitude
			if d < bestD then
				best, bestD = s, d
			end
		end
	end
	if (p.data.strikeUntil or 0) > t then
		if best then
			brain.desired = flatUnit(BombBrain.intercept(best.pos, best.vel, BC.LEAD_TIME) - pos)
			if bestD < BC.TAG_DASH_RANGE and bestD > 3 and MovementCore.canDash(brain.ms) then
				technique(p, brain, "Dash", brain.desired)
			end
			return true
		end
		return false
	end
	local elapsed = (GameState.get("FuseTotal") or 0) - ((GameState.get("FuseEndsAt") or 0) - t)
	if best and bestD <= MOD.BOT_STRIKE_RANGE and elapsed >= (p.data.moleStrikeAt or 0) then
		ModifierService.strike(p)
	end
	return false
end

local function carrierDecide(p: Participant, brain: Brain, root: BasePart, seen: { Seen })
	local f = assert(Arena.current, "no arena")
	local pos = root.Position
	local _, z = Arena.toLocal(pos)
	-- F-MOD-02: a hidden (LIT) fuse could turn HOT any moment, so assume it's about to
	local at = p.attrs:GetAttribute("BombExplodeAt")
	local remaining = if type(at) == "number"
		then at - now()
		elseif p.attrs:GetAttribute("BombMasked") then Config.Bomb.STAGE_HOT
		else 0
	local side, dist = BombBrain.nearestStrip(z, f.halfLen)
	-- A pass target: the nearest eligible body; a Bomber in reach is the favourite when time is short (revenge).
	local target: Seen? = nil
	local best = math.huge
	for _, s in ipairs(seen) do
		if s.active and not s.carrying and not s.safe then
			local d = ((s.pos - pos) * FLAT).Magnitude
			if s.p.role == R.Bomber and remaining < BC.REVENGE_WINDOW then
				d -= 6
			end
			local feed = s.p.data.mega == true -- F-MEGA-06: feeding the giant is the Runners' whole play
			if feed then
				d -= 14
			end
			if d < best and d < (if feed then 44 else 32) then
				target, best = s, d
			end
		end
	end
	local choice = BombBrain.carrierChoice(remaining, dist, 22 * brain.tier.pace, target ~= nil)
	if rng:NextNumber() < brain.tier.error then
		choice = if choice == "defuse" and target then "pass" else choice -- a panicky misjudgement
	end
	if choice == "pass" and target then
		local aim = BombBrain.intercept(target.pos, target.vel, 0.2)
		brain.desired = flatUnit(aim - pos)
		if best < BC.PASS_DASH_RANGE and MovementCore.canDash(brain.ms) and rng:NextNumber() < brain.tier.dash then
			technique(p, brain, "Dash", brain.desired)
		end
	else
		local x = Arena.toLocal(pos)
		local goal = Arena.toWorld(x, side * (f.halfLen + 3), 0)
		brain.desired = flatUnit(goal - pos)
		if dist > 10 and remaining < 2 and MovementCore.canDash(brain.ms) and rng:NextNumber() < brain.tier.dash then
			technique(p, brain, "Dash", brain.desired)
		end
	end
end

local function bomberDecide(p: Participant, brain: Brain, root: BasePart, seen: { Seen })
	local pos = root.Position
	local t = now()
	-- How many other Bombers already chase each Runner (spread out, F-BOT-04).
	local chasing: { [string]: number } = {}
	for id, b in pairs(brains) do
		if id ~= p.id and b.targetId then
			chasing[b.targetId] = (chasing[b.targetId] or 0) + 1
		end
	end
	local target: Seen? = nil
	local bestScore = math.huge
	local fears = {}
	for _, s in ipairs(seen) do
		if s.p.role == R.Runner then
			if s.carrying and s.active then
				table.insert(fears, s.pos)
			elseif s.active and not s.safe and Arena.inField(s.pos) then
				local d = ((s.pos - pos) * FLAT).Magnitude
				local score = BombBrain.targetScore(d, chasing[s.p.id] or 0)
				if s.p.id == brain.targetId then
					score -= 6 -- hysteresis: don't flip targets every decision
				end
				if score < bestScore then
					target, bestScore = s, score
				end
			end
		end
	end
	local f = assert(Arena.current, "no arena")
	local from = GameState.get("StartSide") or -1
	local to = -from
	-- F-MEGA-04: a giant stomps when it can catch two or more Runners in the ring
	if p.data.mega and MovementCore.canDash(brain.ms) then
		local caught = 0
		for _, s in ipairs(seen) do
			if
				s.p.role == R.Runner
				and s.active
				and not s.safe
				and ((s.pos - pos) * FLAT).Magnitude <= Config.Mega.STOMP_RADIUS
			then
				caught += 1
			end
		end
		if caught >= 2 then
			technique(p, brain, "Dash", if brain.desired.Magnitude > 0 then brain.desired else Vector3.new(0, 0, -1))
		end
	end
	if target then
		brain.targetId = target.p.id
		-- D-BOT-01: cut a Runner off on its way to the strip rather than tail it; plain lead pursuit up close
		local goal = Arena.toWorld(Arena.toLocal(target.pos), to * (f.halfLen + 4), 0)
		local aim = BombBrain.cutoff(target.pos, goal, pos, BC.CUTOFF_MIN, BC.CUTOFF_LEAD)
			or BombBrain.intercept(target.pos, target.vel, BC.LEAD_TIME)
		local push = BombBrain.threatPush(pos, fears, BC.CARRIER_FEAR) * 1.5
		brain.desired = flatUnit(flatUnit(aim - pos) + push)
		local d = ((target.pos - pos) * FLAT).Magnitude
		-- …and sway side to side up close to bait the Runner's dodge
		if d < BC.JUKE_RANGE then
			local side = Vector3.new(-brain.desired.Z, 0, brain.desired.X)
			local sway = math.sin(t * BC.JUKE_HZ * math.pi * 2 + (#p.id % 7)) * BC.JUKE * brain.tier.dash
			brain.desired = flatUnit(brain.desired + side * sway)
		end
		local ready = (p.attrs:GetAttribute("TagReadyAt") or 0) <= t
		if
			ready
			and d < BC.TAG_DASH_RANGE
			and d > 3
			and MovementCore.canDash(brain.ms)
			and rng:NextNumber() < brain.tier.dash
		then
			technique(p, brain, "Dash", flatUnit(aim - pos))
		end
	else
		brain.targetId = nil
		-- Nobody on the field. Runners still waiting in the start strip? Guard the line in front of one (spread out,
		-- like players do); otherwise hold the middle, a little toward the side the Runners are heading.
		local waiting: Seen? = nil
		local best = math.huge
		for _, s in ipairs(seen) do
			if s.p.role == R.Runner and s.active and Arena.inSafe(s.pos, from) then
				local score = BombBrain.targetScore(((s.pos - pos) * FLAT).Magnitude, chasing[s.p.id] or 0)
				if score < best then
					waiting, best = s, score
				end
			end
		end
		local goal
		if waiting then
			brain.targetId = waiting.p.id -- counts toward the spread, so Bombers fan out along the line
			goal = Arena.toWorld(Arena.toLocal(waiting.pos), from * (f.halfLen - BC.LINE_DEPTH), 0)
		else
			goal = Arena.toWorld(Arena.toLocal(pos) * 0.5, to * f.halfLen * 0.35, 0)
		end
		local d = goal - pos
		brain.desired = if (d * FLAT).Magnitude > 2 then flatUnit(d) else Vector3.zero
	end
end

-- The active map's cover (parts the builder tagged `Cover`), gathered once per map.
local coverOf: Model? = nil
local cover: { BombBrain.Obstacle } = {}
local function mapCover(): { BombBrain.Obstacle }
	local f = Arena.current
	if not f then
		return {}
	end
	if coverOf ~= f.model then
		coverOf = f.model
		cover = {}
		for _, d in ipairs(f.model:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Cover") then
				table.insert(cover, { pos = d.Position, r = math.max(d.Size.X, d.Size.Z) * 0.72 })
			end
		end
	end
	return cover
end

local function decide(p: Participant, brain: Brain)
	local root = p.root
	if not frozen and root and p.role == R.None then
		-- Between rounds: stroll between The Depot's stations, so the lobby feels like a place people are in.
		local t = now()
		local goal = brain.lobbyGoal
		if not goal or t >= (brain.lobbyNext or 0) then
			local spots = lobbySpots()
			goal = if #spots > 0
				then spots[rng:NextInteger(1, #spots)] + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				else nil
			brain.lobbyGoal = goal
			brain.lobbyNext = t + rng:NextNumber(3, 7)
		end
		local d = if goal then (goal - root.Position) * FLAT else Vector3.zero
		brain.desired = if d.Magnitude > 2.5 then d.Unit * 0.55 else Vector3.zero -- an easy walk, not a sprint
		return
	end
	if frozen or not root or not Arena.current or not liveRun() then
		brain.desired = Vector3.zero
		return
	end
	local seen = look(p)
	local carrying = p.attrs:GetAttribute("BombId") ~= nil
	if p.role == R.Runner and carrying and p.state == S.Active then
		carrierDecide(p, brain, root, seen)
	elseif p.role == R.Runner then
		if not moleDecide(p, brain, root, seen) then
			runnerDecide(p, brain, root, seen)
		end
	elseif p.role == R.Bomber and p.state == S.Active then
		bomberDecide(p, brain, root, seen)
	else
		brain.desired = Vector3.zero
	end
	if brain.desired.Magnitude > 0.05 then
		brain.desired =
			BombBrain.avoid(root.Position, brain.desired, mapCover(), BC.COVER_CLEARANCE, BC.COVER_LOOKAHEAD)
	end
	-- A tier's error: now and then the line is a little off.
	if brain.desired.Magnitude > 0 and rng:NextNumber() < brain.tier.error * 0.5 then
		local a = math.rad(rng:NextNumber(-35, 35))
		local d = brain.desired
		brain.desired = Vector3.new(d.X * math.cos(a) - d.Z * math.sin(a), 0, d.X * math.sin(a) + d.Z * math.cos(a))
	end
end

-- ── Steering (every frame) ──────────────────────────────────────────────────────────────────────────────────────
local function steer(p: Participant, brain: Brain, dt: number)
	local hum, root = p.humanoid, p.root
	if not hum or not root or root.Parent == nil then
		return
	end
	local busy = hum.PlatformStand or p.state == S.Tumbled or p.data.ragdolled == true
	local canMove = not root.Anchored and not busy and not p.data.locked and (p.role == R.None or liveRun())
	local params = brain.params
	params.lobby = p.role == R.None
	params.speedMult = (p.attrs:GetAttribute("SpeedMult") or 1) * brain.tier.pace
	params.accelMult, params.decelMult, params.turnMult, params.dashMult = 1, 1, 1, 1
	MovementCore.applyProfile(params, p.role)
	if busy then
		MovementCore.cancelTechniques(brain.ms)
	end
	local k = 1 - math.exp(-10 * dt)
	brain.steerDir = brain.steerDir:Lerp(brain.desired, k)
	if brain.desired.Magnitude < 0.05 and brain.steerDir.Magnitude < 0.15 then
		brain.steerDir = Vector3.zero
	end
	local input = if canMove then brain.steerDir else Vector3.zero
	if root.Anchored then
		brain.ms.speed = 0
	end
	local _, heading, frameSpeed = MovementCore.step(brain.ms, input, dt, params)
	if not root.Anchored and not hum.PlatformStand then
		hum.WalkSpeed = frameSpeed
		hum:Move(if frameSpeed > 0.05 then heading else Vector3.zero, false)
	end
	local loco = brain.loco
	if loco then
		local v = if root.Anchored then 0 else (root.AssemblyLinearVelocity * FLAT).Magnitude
		loco:update(dt, v, input.Magnitude > 0.05, root.Anchored or hum.FloorMaterial ~= Enum.Material.Air, busy)
	end
end

local function heartbeat(dt: number)
	local t = os.clock()
	for id, brain in pairs(brains) do
		local p = Participants.get(id)
		if not p then
			brains[id] = nil
			continue
		end
		if t >= brain.nextDecide then
			-- Reaction: slower tiers decide less often (they act on what they saw a moment ago).
			brain.nextDecide = t + 1 / BC.DECIDE_HZ + brain.tier.reaction * rng:NextNumber(0.6, 1.2)
			local ok, err = pcall(decide, p, brain)
			if not ok then
				warn("[Bots] decide failed:", err)
				brain.desired = Vector3.zero
			end
		end
		steer(p, brain, dt)
	end
end

function BotService.start()
	RunService.Heartbeat:Connect(heartbeat)
	-- Fill at every intermission (and once at boot).
	local gs = GameState.instance()
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if GameState.get("Phase") == Ph.Intermission then
			task.defer(BotService.fill)
		end
	end)
	task.defer(BotService.fill)
	AdminService.register("bots", function(args)
		-- bots <n>: set the fill target (Studio tuning); "bots 0" removes them at the next intermission.
		local n = tonumber(args[1])
		if not n then
			return "usage: bots <fillTarget>"
		end
		local tunable: any = BC
		tunable.FILL_TARGET = math.clamp(math.floor(n), 0, Config.Game.MAX_PLAYERS)
		BotService.fill()
		return `fill target {BC.FILL_TARGET}`
	end)
	AdminService.register("looks", function()
		-- whose friends the bots are wearing (D-LOBBY-02): "<owner userId> n", "filler n", "generated n"
		local tally: { [string]: number } = {}
		for _, b in ipairs(Participants.bots()) do
			local key = if b.data.avatarOwner
				then tostring(b.data.avatarOwner)
				elseif b.data.avatarId then "filler"
				else "generated"
			tally[key] = (tally[key] or 0) + 1
		end
		local out = {}
		for k, n in pairs(tally) do
			table.insert(out, `{k} {n}`)
		end
		return table.concat(out, ", ") .. ` · ready rigs {AvatarPool.readyCount()}`
	end)
	AdminService.register("botfreeze", function(args)
		frozen = args[1] ~= "off" and args[1] ~= false
		return `bots frozen: {frozen}`
	end)
	AdminService.register("bot", function()
		local lines = {}
		for id, b in pairs(brains) do
			local p = Participants.get(id)
			if p then
				table.insert(lines, `{id} {p.name} {b.tierName} {p.role}/{p.state} target={b.targetId or "-"}`)
			end
		end
		return table.concat(lines, "\n")
	end)
end

return BotService
