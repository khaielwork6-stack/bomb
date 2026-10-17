--!strict
-- The bomb, server side (GDD §7). Every Heartbeat while a crossing is live it snapshots the participants, asks
-- Logic/BombRules what happens, and applies it: tags stick fresh bombs, contact passes them, safe strips defuse them
-- and the fuse booms them. Nothing here is triggered by a client remote (F-SEC-01): contact is measured on the server.
-- Clients draw every bomb from the Carrier's attributes (BombId, BombExplodeAt, BombLocked) plus the BombFx beats.
-- Implements: F-BOMB-01..09, the §7.7 edge cases, F-FUSE-03 (boomParticipant), F-SEC-01.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local BombRules = require(ServerScriptService.Server.Logic.BombRules)
local AdminService = require(script.Parent.AdminService)
local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local Participants = require(script.Parent.Participants)

type Participant = Participants.Participant
type Bomb = BombRules.Bomb
type Body = BombRules.Body

local B = Config.Bomb
local R, S = Types.Role, Types.State

local BombService = {
	-- (carrier, bomb, creditBomber?) a bomb blew on a Runner (they turn into a Bomber once they get up).
	RunnerBoomed = Signal.new(),
	-- (bomber, bomb) a passed bomb blew on a Bomber (stunned, stays a Bomber).
	BomberBoomed = Signal.new(),
	-- (carrier, bomb, clutch) a Carrier reached a Safe Strip.
	Defused = Signal.new(),
	-- (from, to, bomb, remaining) every pass; (bomber, target, bomb) every tag.
	Passed = Signal.new(),
	Tagged = Signal.new(),
	-- (runner, bomber) a Runner slipped a ready Bomber's reach by a hair (DODGE!, GDD §11.1)
	Dodged = Signal.new(),
	-- (p) a boomed Runner is back on their feet as a Bomber.
	BecameBomber = Signal.new(),
}

-- Live only while RoundService runs a crossing / the Last Stand run.
BombService.live = false

local bombs: { [number]: Bomb } = {}
local byCarrier: { [string]: Bomb } = {}
local nextId = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function inAnySafe(pos: Vector3): boolean
	return Arena.inSafe(pos, -1) or Arena.inSafe(pos, 1)
end

local function setCarrierAttrs(p: Participant?, bomb: Bomb?)
	if not p then
		return
	end
	p.attrs:SetAttribute("BombId", if bomb then bomb.id else nil)
	p.attrs:SetAttribute("BombExplodeAt", if bomb then bomb.explodeAt else nil)
	p.attrs:SetAttribute("BombLocked", if bomb then bomb.locked else nil)
end

local function detach(bomb: Bomb)
	bombs[bomb.id] = nil
	if byCarrier[bomb.carrier] == bomb then
		byCarrier[bomb.carrier] = nil
	end
	setCarrierAttrs(Participants.get(bomb.carrier), nil)
end

function BombService.bombOf(p: Participant): Bomb?
	return byCarrier[p.id]
end

function BombService.count(): number
	local n = 0
	for _ in pairs(bombs) do
		n += 1
	end
	return n
end

-- ── Snapshots ────────────────────────────────────────────────────────────────────────────────────────────────────
local function bodyOf(p: Participant, t: number): Body?
	local root = p.root
	if not root or root.Parent == nil or (p.role ~= R.Runner and p.role ~= R.Bomber) then
		return nil
	end
	local pos = root.Position
	return {
		id = p.id,
		role = p.role,
		pos = pos,
		active = p.state == S.Active and not p.data.ragdolled and not p.data.locked and (p.data.stunnedUntil or 0) <= t,
		safe = inAnySafe(pos),
		carrying = byCarrier[p.id] ~= nil,
		tagReadyAt = p.data.tagReadyAt or 0,
	}
end

-- ── Booms ────────────────────────────────────────────────────────────────────────────────────────────────────────
local function splash(center: Vector3, except: Participant?)
	for _, q in ipairs(Participants.all()) do
		local root = q.root
		if q ~= except and root and q.role ~= R.None then
			local d = (root.Position - center) * Vector3.new(1, 0, 1)
			if d.Magnitude <= B.SPLASH_RADIUS then
				local dir = if d.Magnitude > 0.1 then d.Unit else Vector3.new(1, 0, 0)
				Characters.push(q, dir, B.SPLASH_PUSH * (1 - d.Magnitude / B.SPLASH_RADIUS * 0.5), B.SPLASH_TIME)
			end
		end
	end
end

local function fling(p: Participant, horizontalScale: number)
	local a = math.random() * math.pi * 2
	local impulse = Vector3.new(
		math.cos(a) * B.BOOM_IMPULSE_H * horizontalScale,
		B.BOOM_IMPULSE_V,
		math.sin(a) * B.BOOM_IMPULSE_H * horizontalScale
	)
	Participants.setState(p, S.Tumbled)
	Characters.ragdoll(p, impulse)
	Characters.applyGroup(p)
end

-- A boomed body lands; get it up where it lies, as a Bomber. A body blown into a Safe Strip is moved onto the field
-- edge (Bombers can't stand in the strips, F-CROSS-02).
local function standUpAsBomber(p: Participant)
	if p.model == nil or p.role == R.None then
		return
	end
	Characters.unragdoll(p)
	Participants.setRole(p, R.Bomber)
	Participants.setState(p, S.Active)
	Characters.applyGroup(p)
	local root, f = p.root, Arena.current
	if root and f then
		local x, z = Arena.toLocal(root.Position)
		if math.abs(z) >= f.halfLen - 1 then
			local side = if z > 0 then 1 else -1
			Characters.pivot(
				p,
				Arena.cframeAt(
					math.clamp(x, -Arena.halfWidth() + 3, Arena.halfWidth() - 3),
					side * (f.halfLen - 4),
					-side
				)
			)
		end
	end
	BombService.BecameBomber:Fire(p)
end

-- Turn a Runner into a Bomber through a boom (bomb or field detonation): fling, then get up as a Bomber.
local function boomRunner(p: Participant)
	fling(p, 1)
	local token = (p.data.boomToken or 0) + 1
	p.data.boomToken = token
	task.delay(Config.Round.BOOM_GETUP, function()
		if p.data.boomToken == token and Participants.get(p.id) == p then
			standUpAsBomber(p)
		end
	end)
end

local function stunBomber(p: Participant)
	local t = now()
	p.data.stunnedUntil = t + B.BOMBER_STUN
	p.attrs:SetAttribute("StunnedUntil", p.data.stunnedUntil)
	fling(p, 0.6)
	local token = (p.data.boomToken or 0) + 1
	p.data.boomToken = token
	task.delay(B.BOMBER_STUN, function()
		if p.data.boomToken == token and Participants.get(p.id) == p and p.role ~= R.None then
			Characters.unragdoll(p)
			Participants.setState(p, S.Active)
			Characters.applyGroup(p)
		end
	end)
end

local function boom(bomb: Bomb)
	local p = Participants.get(bomb.carrier)
	detach(bomb)
	local pos = if p and p.root then p.root.Position else nil
	local credit = if bomb.origin then Participants.get(bomb.origin) else nil
	Net.fireAll("BombFx", {
		kind = "Boom",
		bomb = bomb.id,
		who = bomb.carrier,
		credit = if credit then credit.id else nil,
		pos = pos,
		chain = BombRules.chainLength(bomb),
		at = now(),
	})
	if pos then
		splash(pos, p)
	end
	if not p or not p.model then
		return -- §7.7: the Carrier left; the bomb booms in place, no credit
	end
	if p.role == R.Bomber then
		stunBomber(p)
		BombService.BomberBoomed:Fire(p, bomb)
	else
		if credit and credit.role == R.Bomber then
			credit.stats.booms += 1
		end
		boomRunner(p)
		BombService.RunnerBoomed:Fire(p, bomb, credit)
	end
end

local function defuse(bomb: Bomb, p: Participant)
	local remaining = BombRules.remaining(bomb, now())
	local clutch = BombRules.isClutch(remaining)
	detach(bomb)
	p.stats.defuses += 1
	if clutch then
		p.stats.clutches += 1
	end
	Net.fireAll("BombFx", {
		kind = "Defuse",
		bomb = bomb.id,
		who = p.id,
		pos = if p.root then p.root.Position else nil,
		clutch = clutch,
		remaining = remaining,
		at = now(),
	})
	BombService.Defused:Fire(p, bomb, clutch)
end

-- ── Tags & passes ────────────────────────────────────────────────────────────────────────────────────────────────
local function attach(bomb: Bomb, to: Participant)
	bombs[bomb.id] = bomb
	byCarrier[to.id] = bomb
	setCarrierAttrs(to, bomb)
end

local function tag(bomber: Participant, target: Participant, bBody: Body, tBody: Body, t: number)
	nextId += 1
	local bomb = BombRules.newBomb(nextId, bBody, tBody, t)
	bomber.data.tagReadyAt = t + B.TAG_COOLDOWN
	bomber.attrs:SetAttribute("TagReadyAt", bomber.data.tagReadyAt)
	bomber.stats.tags += 1
	attach(bomb, target)
	Net.fireAll("BombFx", { kind = "Stick", bomb = bomb.id, from = bomber.id, who = target.id, at = t })
	BombService.Tagged:Fire(bomber, target, bomb)
end

local function pass(bomb: Bomb, from: Participant, to: Participant, fBody: Body, tBody: Body, t: number)
	byCarrier[from.id] = nil
	setCarrierAttrs(from, nil)
	BombRules.pass(bomb, fBody, tBody, t)
	byCarrier[to.id] = bomb
	setCarrierAttrs(to, bomb)
	from.stats.passes += 1
	local remaining = BombRules.remaining(bomb, t)
	Net.fireAll("BombFx", {
		kind = "Pass",
		bomb = bomb.id,
		from = from.id,
		who = to.id,
		remaining = remaining,
		chain = BombRules.chainLength(bomb),
		at = t,
	})
	BombService.Passed:Fire(from, to, bomb, remaining)
end

-- DODGE! tracking: "runner|bomber" -> when the near miss began; runner -> last dodge (cooldown).
local nearMisses: { [string]: number } = {}
BombService.dodgeCount = 0 -- this server's DODGE! total (the Studio `state` command shows it)
local lastDodge: { [string]: number } = {}

local function dodges(bodies: { Body }, byId: { [string]: Body }, t: number)
	for _, bomber in ipairs(bodies) do
		if bomber.role == R.Bomber and bomber.active and t >= bomber.tagReadyAt then
			local bp = Participants.get(bomber.id)
			local vel = if bp and bp.root then bp.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) else Vector3.zero
			for _, runner in ipairs(bodies) do
				if runner.role == R.Runner and runner.active and not runner.safe and not runner.carrying then
					local key = runner.id .. "|" .. bomber.id
					local toward = (runner.pos - bomber.pos) * Vector3.new(1, 0, 1)
					local closing = if toward.Magnitude > 0.01 then vel:Dot(toward.Unit) else 0
					if BombRules.nearMiss(bomber.pos, runner.pos) and closing >= B.DODGE_CLOSING then
						nearMisses[key] = nearMisses[key] or t
					elseif nearMisses[key] then
						local began = nearMisses[key]
						if t - began > B.DODGE_WINDOW then
							nearMisses[key] = nil
						elseif BombRules.clearOf(bomber.pos, runner.pos) then
							nearMisses[key] = nil
							if t - (lastDodge[runner.id] or -math.huge) >= B.DODGE_COOLDOWN then
								lastDodge[runner.id] = t
								local rp = Participants.get(runner.id)
								if rp and bp then
									rp.stats.dodges += 1
									BombService.dodgeCount += 1
									BombService.Dodged:Fire(rp, bp)
								end
							end
						end
					end
				end
			end
		end
	end
	-- a tagged Runner never dodged: drop their pending near misses
	for key in pairs(nearMisses) do
		local rid = string.match(key, "^([^|]+)")
		local b = rid and byId[rid]
		if not b or b.carrying then
			nearMisses[key] = nil
		end
	end
end

local function step()
	if not BombService.live or not Arena.current then
		return
	end
	local t = now()
	-- Fuses first: a bomb that's out of time booms before it could be passed this frame.
	for _, bomb in pairs(bombs) do
		if t >= bomb.explodeAt then
			boom(bomb)
		end
	end
	local bodies: { Body } = {}
	local byId: { [string]: Body } = {}
	for _, p in ipairs(Participants.all()) do
		local b = bodyOf(p, t)
		if b then
			table.insert(bodies, b)
			byId[b.id] = b
		end
	end
	-- Defuses (F-BOMB-09): a Runner carrying into a Safe Strip.
	for _, bomb in pairs(bombs) do
		local b = byId[bomb.carrier]
		if b and b.safe and b.role == R.Runner then
			local p = Participants.get(bomb.carrier)
			if p then
				defuse(bomb, p)
				b.carrying = false
			end
		end
	end
	-- Passes (F-BOMB-03..05), before tags so a Carrier bumping into a Bomber's reach still passes.
	for _, bomb in pairs(bombs) do
		local from = byId[bomb.carrier]
		if from then
			local to = BombRules.pickReceiver(bomb, from, bodies, t)
			if to then
				local fp, tp = Participants.get(from.id), Participants.get(to.id)
				if fp and tp then
					pass(bomb, fp, tp, from, to, t)
					from.carrying = false
					to.carrying = true
				end
			end
		end
	end
	-- Tags (F-BOMB-02).
	for _, b in ipairs(bodies) do
		if b.role == R.Bomber then
			local target = BombRules.pickTagTarget(b, bodies, t)
			if target then
				local bp, tp = Participants.get(b.id), Participants.get(target.id)
				if bp and tp then
					tag(bp, tp, b, target, t)
					target.carrying = true
					b.tagReadyAt = t + B.TAG_COOLDOWN
				end
			end
		end
	end
	dodges(bodies, byId, t)
end

-- ── API for RoundService ─────────────────────────────────────────────────────────────────────────────────────────
-- F-FUSE-03: the field detonation booms a participant with no bomb and no credit (a Bomber is only flung).
function BombService.boomParticipant(p: Participant)
	local bomb = byCarrier[p.id]
	if bomb then
		detach(bomb)
	end
	if p.role == R.Bomber then
		stunBomber(p)
	elseif p.role == R.Runner then
		boomRunner(p)
		BombService.RunnerBoomed:Fire(p, bomb, nil)
	end
end

-- The crossing ended (§7.7): bombs on Runners in a Safe Strip are defused; any others are cleared by the caller's
-- field detonation (which booms whoever is still on the field).
function BombService.endCrossing()
	for _, bomb in pairs(bombs) do
		local p = Participants.get(bomb.carrier)
		if p and p.root and inAnySafe(p.root.Position) and p.role == R.Runner then
			defuse(bomb, p)
		end
	end
end

-- Remove every bomb with no effect (round over / reset).
function BombService.clear()
	for _, bomb in pairs(bombs) do
		detach(bomb)
	end
	table.clear(bombs)
	table.clear(byCarrier)
end

-- Finish every pending get-up now (READY / RESOLVE): boomed Runners stand up as Bombers at once.
function BombService.finishGetups()
	for _, p in ipairs(Participants.all()) do
		if p.role == R.Runner and p.state == S.Tumbled and p.model then
			p.data.boomToken = (p.data.boomToken or 0) + 1
			standUpAsBomber(p)
		end
	end
end

function BombService.start()
	RunService.Heartbeat:Connect(step)
	-- §7.7: a Carrier who leaves → the bomb booms in place (splash, no credit).
	Participants.Removed:Connect(function(p: Participant)
		local bomb = byCarrier[p.id]
		if bomb then
			local pos = if p.root then p.root.Position else nil
			detach(bomb)
			Net.fireAll("BombFx", { kind = "Boom", bomb = bomb.id, who = p.id, pos = pos, at = now() })
			if pos then
				splash(pos, p)
			end
		end
		for _, b in pairs(bombs) do
			if b.origin == p.id then
				b.origin = nil -- §7.7: credit falls back to the field
			end
		end
	end)
	-- Studio: "bomb <id>" sticks a fresh bomb on a participant (tests without a Bomber in reach).
	AdminService.register("bomb", function(args)
		local p = Participants.get(args[1] or "")
		if not RunService:IsStudio() or not p or byCarrier[p.id] then
			return "usage: bomb <participantId> (not already carrying)"
		end
		local t = now()
		nextId += 1
		local bomb: Bomb = {
			id = nextId,
			carrier = p.id,
			explodeAt = t + (tonumber(args[2]) or B.FUSE),
			origin = nil,
			chain = { p.id },
			lastGiver = nil,
			receivedAt = t,
			locked = p.role == R.Bomber,
		}
		attach(bomb, p)
		Net.fireAll("BombFx", { kind = "Stick", bomb = bomb.id, who = p.id, at = t })
		return "bomb " .. bomb.id .. " on " .. p.id
	end)
end

return BombService
