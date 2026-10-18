--!strict
-- The round (GDD §5, §6, §8): INTERMISSION → INTRO → (READY → CROSSING → RESOLVE) × up to 8 → LAST STAND → RESULTS.
-- Owns roles, teleports, locks, the Field Fuse and every ending condition; BombService owns the bombs.
-- Between rounds everyone is in the lobby, The Depot (GDD §19; Characters.lobbyCFrame falls back to the start strip
-- when a place has no lobby).
-- MomentService picks the round's best moment; it goes out with the results (F-FEEL-06).
-- Implements: F-FLOW-01..10, F-CROSS-01..04, F-FUSE-01..05, F-LAST-01..03, F-WIN-01..03, §5.4 sizing, F-FEEL-06 (hooks).

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
local BombService = require(script.Parent.BombService)
local CalloutService = require(script.Parent.CalloutService)
local MegaService = require(script.Parent.MegaService)
local MomentService = require(script.Parent.MomentService)
local DataService = require(script.Parent.DataService)
local Characters = require(script.Parent.Characters)
local GameState = require(script.Parent.GameState)
local Participants = require(script.Parent.Participants)
local PlayerService = require(script.Parent.PlayerService)

type Participant = Participants.Participant

local RC = Config.Round
local Ph, Sub, R, S = Types.Phase, Types.Sub, Types.Role, Types.State

local RoundService = {
	-- (outcome, winners, mvp?) at RESULTS: outcome = "LastStand" | "Bombers" | "Survivors".
	Ended = Signal.new(),
	-- (crossing, result) after every crossing: result = "clear" | "fuse" | "wiped".
	CrossingEnded = Signal.new(),
}

local rng = Random.new()
local skipFlag = false
local lastBombers: { [string]: boolean } = {}
local startSide = -1 -- the side Runners cross FROM this crossing

local function now(): number
	return workspace:GetServerTimeNow()
end

local function timeScale(): number
	return if RunService:IsStudio() then math.clamp(Config.Debug.TIME_SCALE, 0.25, 4) else 1
end

-- Wait `seconds` of round time (Studio TIME_SCALE); the Studio "skip" command cuts it short.
local function hold(seconds: number)
	local deadline = os.clock() + seconds / timeScale()
	while os.clock() < deadline do
		if skipFlag then
			skipFlag = false
			return
		end
		task.wait(0.05)
	end
end

local function setPhase(phase: string, seconds: number?, sub: string?)
	GameState.set("Phase", phase)
	GameState.set("SubPhase", sub or Sub.None)
	GameState.setTimer(if seconds then seconds / timeScale() else 0)
end

-- ── Who's playing ───────────────────────────────────────────────────────────────────────────────────────────────
local function present(p: Participant): boolean
	return p.model ~= nil and p.model.Parent ~= nil and p.root ~= nil and not p.afk
end

local function inRound(): { Participant }
	local out = {}
	for _, p in ipairs(Participants.all()) do
		if present(p) and (p.role == R.Runner or p.role == R.Bomber) then
			table.insert(out, p)
		end
	end
	return out
end

-- Runners still in the round (a Runner mid-fling from a boom is already out).
local function runnersAlive(): { Participant }
	local out = {}
	for _, p in ipairs(Participants.all()) do
		if present(p) and p.role == R.Runner and p.state ~= S.Tumbled then
			table.insert(out, p)
		end
	end
	return out
end

local function withRole(role: string): { Participant }
	local out = {}
	for _, p in ipairs(Participants.all()) do
		if present(p) and p.role == role then
			table.insert(out, p)
		end
	end
	return out
end

local function publishCounts()
	GameState.set("RunnersLeft", #runnersAlive())
	GameState.set("BombersCount", #withRole(R.Bomber))
end

-- The Field Fuse scales with the field's length (Config.Round.FUSE_REF_LENGTH).
local function lengthFactor(): number
	local f = Arena.current
	return if f then math.max(0.5, f.halfLen * 2 / RC.FUSE_REF_LENGTH) else 1
end

-- ── Placement ───────────────────────────────────────────────────────────────────────────────────────────────────
local function strip(side: number): CFrame
	return Arena.runnerLine(side, 1, rng)[1]
end

local function placeRunners(side: number, onlyStrays: boolean)
	local list = runnersAlive()
	local spots = Arena.runnerLine(side, math.max(#list, 1), rng)
	for i, p in ipairs(list) do
		if not onlyStrays or not (p.root and Arena.inSafe(p.root.Position, side)) then
			Characters.pivot(p, spots[i])
		end
		Participants.setState(p, S.Safe)
		Characters.applyGroup(p)
	end
end

local function placeBombers(faceSide: number)
	local list = withRole(R.Bomber)
	local spots = Arena.bomberBand(math.max(#list, 1), faceSide, rng)
	for i, p in ipairs(list) do
		Characters.unragdoll(p)
		p.data.stunnedUntil = 0
		p.attrs:SetAttribute("StunnedUntil", nil)
		Participants.setState(p, S.Active)
		Characters.applyGroup(p)
		Characters.pivot(p, spots[i])
	end
end

local function lockAll(locked: boolean, role: string?)
	for _, p in ipairs(inRound()) do
		if role == nil or p.role == role then
			Characters.setLocked(p, locked)
		end
	end
end

-- ── Round setup ─────────────────────────────────────────────────────────────────────────────────────────────────
local function eligible(): { Participant }
	local out = {}
	for _, p in ipairs(Participants.all()) do
		if
			present(p)
			and (
				p.isBot
				or p.data.clientReady
				or os.clock() - (p.data.joinedAt or 0) > Config.Game.CLIENT_READY_TIMEOUT
			)
		then
			table.insert(out, p)
		end
	end
	return out
end

-- §5.4 + F-ONB-03: random starting Bombers; nobody twice in a row, and new players (first 2 rounds) last.
local function pickBombers(list: { Participant }, count: number): { [Participant]: boolean }
	local scored = {}
	for _, p in ipairs(list) do
		local score = rng:NextNumber()
		if RC.BOMBER_REPEAT_GUARD and lastBombers[p.id] then
			score += 10
		end
		-- F-ONB-03: a new player is never a starting Bomber in their first 2 rounds ever (lifetime, from the profile)
		local profile = if p.isBot then nil else DataService.get(p)
		local lifetime = if profile then profile.stats.rounds else (p.data.roundsPlayed or 0)
		if not p.isBot and lifetime < 2 then
			score += 20
		end
		table.insert(scored, { p = p, score = score })
	end
	table.sort(scored, function(a, b)
		return a.score < b.score
	end)
	local picked = {}
	for i = 1, math.min(count, #scored - 1) do
		picked[scored[i].p] = true
	end
	return picked
end

-- ── A crossing ──────────────────────────────────────────────────────────────────────────────────────────────────
-- Runs one crossing from `from` to `-from` with a Field Fuse of `fuse` seconds. Returns "clear" | "fuse" | "wiped".
local function crossing(k: number, from: number, fuse: number, lastStand: boolean): string
	local to = -from
	local total = fuse / timeScale()
	local endsAt = now() + total
	GameState.set("Crossing", k)
	GameState.set("StartSide", from)
	GameState.set("FuseTotal", total)
	GameState.set("FuseEndsAt", endsAt)
	setPhase(if lastStand then Ph.LastStand else Ph.Crossing, fuse, if lastStand then Sub.Run else nil)
	-- GO: the barrier drops (Runners leave the Safe state, so the line wall lets them through) and Bombers move.
	local goAt = now()
	for _, p in ipairs(inRound()) do
		if p.role == R.Runner then
			Participants.setState(p, S.Active)
			Characters.applyGroup(p)
			p.data.crossedThis = false
		end
		Characters.setLocked(p, false)
	end
	BombService.live = true
	MegaService.go() -- the first GO of a MEGA BOMB round lights its fuse (F-MEGA-05)
	local result = "fuse"
	local warned = false
	local hurried = lastStand -- the Last Stand keeps its full fuse
	while true do
		task.wait(0.05)
		local t = now()
		local alive = runnersAlive()
		local allSafe = #alive > 0
		for _, p in ipairs(alive) do
			local root = p.root
			if p.state == S.Active and root and Arena.inSafe(root.Position, to) then
				-- F-CROSS-04: made it; safe for the rest of the crossing (the line wall holds them in).
				Participants.setState(p, S.Safe)
				Characters.applyGroup(p)
				p.data.crossedThis = true
			end
			if p.state ~= S.Safe then
				allSafe = false
			end
			-- F-CROSS-01: still idling in the start strip.
			local idle = p.state == S.Active
				and root ~= nil
				and Arena.inSafe(root.Position, from)
				and t - goAt > RC.IDLE_WARN
			if (p.attrs:GetAttribute("MoveWarn") == true) ~= idle then
				p.attrs:SetAttribute("MoveWarn", if idle then true else nil)
			end
		end
		publishCounts()
		-- The hurry-up (D-PACE-01): most Runners are safe, or only idlers are left in the start strip → the fuse cuts
		-- to its last seconds (the warning below then fires at once).
		if not hurried and #alive > 0 then
			local safe, onField = 0, 0
			for _, p in ipairs(alive) do
				if p.state == S.Safe then
					safe += 1
				elseif p.state == S.Active and not (p.root and Arena.inSafe(p.root.Position, from)) then
					onField += 1
				end
			end
			local idlersOnly = onField == 0 and t - goAt > RC.IDLE_WARN / timeScale()
			if safe > 0 and (safe / #alive >= RC.HURRY_SHARE or idlersOnly) then
				hurried = true
				local cut = t + RC.HURRY_LEFT / timeScale()
				if cut < endsAt then
					endsAt = cut
					GameState.set("FuseEndsAt", endsAt)
					Net.fireAll("FieldFx", { kind = "Hurry", crossing = k, at = t })
				end
			end
		end
		if not warned and endsAt - t <= RC.FUSE_WARN / timeScale() then
			warned = true
			Net.fireAll("FieldFx", { kind = "Warn", crossing = k, at = t })
		end
		if #alive == 0 then
			result = "wiped"
			break
		end
		if MegaService.expired() then
			result = "mega" -- F-MEGA-05: the MEGA BOMB goes off (playRound runs the finale)
			break
		end
		if allSafe then
			result = "clear"
			break
		end
		if t >= endsAt or skipFlag then
			skipFlag = false
			result = "fuse"
			break
		end
	end
	BombService.live = false
	BombService.endCrossing()
	for _, p in ipairs(Participants.all()) do
		if p.attrs:GetAttribute("MoveWarn") then
			p.attrs:SetAttribute("MoveWarn", nil)
		end
	end
	if result == "fuse" then
		-- F-FUSE-03: the field detonates; everyone still on it (or idling in the start strip) booms. No credit.
		Net.fireAll("FieldFx", { kind = "Detonate", crossing = k, side = from, at = now(), sweep = RC.DETONATE_SWEEP })
		for _, p in ipairs(inRound()) do
			local root = p.root
			local made = p.role == R.Runner and p.state == S.Safe
			if root and not made and p.state ~= S.Tumbled and not Arena.inSafe(root.Position, to) then
				if p.role == R.Runner or Arena.inField(root.Position) then
					BombService.boomParticipant(p)
				end
			end
		end
	elseif result == "clear" then
		Net.fireAll("FieldFx", { kind = "Clear", crossing = k, at = now() })
	end
	BombService.clear()
	local crossed = {}
	for _, p in ipairs(runnersAlive()) do
		if p.data.crossedThis then
			p.stats.crossings += 1
			table.insert(crossed, p)
		end
	end
	CalloutService.crossingEnded(result, crossed)
	RoundService.CrossingEnded:Fire(k, result)
	return result
end

-- ── Results ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function finish(outcome: string, winners: { Participant })
	local mvp: Participant? = nil
	if outcome == "Bombers" then
		for _, p in ipairs(withRole(R.Bomber)) do
			if p.stats.booms > 0 and (mvp == nil or p.stats.booms > (mvp :: Participant).stats.booms) then
				mvp = p
			end
		end
	end
	local ids = {}
	for _, p in ipairs(winners) do
		table.insert(ids, p.id)
		p.data.wonLast = true
	end
	GameState.set("Outcome", outcome)
	setPhase(Ph.Results, RC.RESULTS)
	local headline = if outcome == "LastStand"
		then "VICTORY"
		elseif outcome == "Survivors" then "SURVIVORS WIN"
		else "BOMBERS WIN"
	GameState.headline(headline, if #winners == 1 then winners[1].name else "")
	local stats = {}
	for _, p in ipairs(inRound()) do
		stats[p.id] = {
			crossings = p.stats.crossings,
			tags = p.stats.tags,
			passes = p.stats.passes,
			defuses = p.stats.defuses,
			clutches = p.stats.clutches,
			booms = p.stats.booms,
		}
	end
	Net.fireAll("RoundFx", {
		kind = "Results",
		outcome = outcome,
		winners = ids,
		mvp = if mvp then mvp.id else nil,
		stats = stats,
		moment = MomentService.best(), -- F-FEEL-06: the MOMENT OF THE ROUND replay (nil if none was top-tier)
		at = now(),
	})
	RoundService.Ended:Fire(outcome, winners, mvp)
	hold(RC.RESULTS)
end

-- ── The round ───────────────────────────────────────────────────────────────────────────────────────────────────
local function resetToLobby()
	MegaService.finish()
	BombService.live = false
	BombService.clear()
	GameState.headline("")
	GameState.set("LastStandId", "")
	GameState.set("Outcome", "")
	GameState.set("FuseEndsAt", 0)
	GameState.set("Crossing", 0)
	for _, p in ipairs(Participants.all()) do
		p.data.boomToken = (p.data.boomToken or 0) + 1 -- cancel pending get-ups
		if p.model then
			Characters.unragdoll(p)
			Characters.setLocked(p, false)
			p.attrs:SetAttribute("SpeedMult", nil)
			p.attrs:SetAttribute("StunnedUntil", nil)
			p.attrs:SetAttribute("Crowned", nil)
			Participants.setRole(p, R.None)
			Participants.setState(p, S.Lobby)
			Characters.applyGroup(p)
			Characters.pivot(p, Characters.lobbyCFrame()) -- back to The Depot (GDD §19)
		end
	end
	startSide = -1
end

local function lastStand(runner: Participant, from: number): boolean
	GameState.set("LastStandId", runner.id)
	setPhase(Ph.LastStand, RC.LAST_STAND_INTRO, Sub.Intro)
	Net.fireAll("RoundFx", { kind = "LastStand", who = runner.id, at = now() })
	placeRunners(from, true)
	placeBombers(-from)
	lockAll(true, R.Bomber)
	runner.attrs:SetAttribute("SpeedMult", RC.LAST_STAND_SPEED)
	CalloutService.lastStand(runner)
	hold(RC.LAST_STAND_INTRO)
	local result = crossing(GameState.get("Crossing") + 1, from, RC.LAST_STAND_FUSE * lengthFactor(), true)
	runner.attrs:SetAttribute("SpeedMult", nil)
	local won = result == "clear" and runner.role == R.Runner
	MomentService.lastStandEnded(runner, won)
	return won
end

local function playRound()
	local list = eligible()
	local count = BombRules.bomberCount(#list)
	-- F-MEGA-01/02: a MEGA BOMB round has one giant and no regular Bombers at the start
	local giant = MegaService.claim(list)
	local bombers = if giant then { [giant] = true } else pickBombers(list, count)
	MomentService.reset()
	table.clear(lastBombers)
	for _, p in ipairs(list) do
		p.stats = Participants.newStats()
		p.data.roundsPlayed = (p.data.roundsPlayed or 0) + 1
		-- F-WIN-04: last round's winners wear the crown for this whole round
		p.attrs:SetAttribute("Crowned", if p.data.wonLast then true else nil)
		p.data.wonLast = nil
		if bombers[p] then
			lastBombers[p.id] = true
			Participants.setRole(p, R.Bomber)
		else
			Participants.setRole(p, R.Runner)
		end
	end
	if giant then
		MegaService.begin(giant)
	end
	local startRunners = #runnersAlive()
	GameState.set("MaxCrossings", RC.MAX_CROSSINGS)
	-- INTRO: everyone to their spots, frozen, the Bombers revealed.
	startSide = -1
	placeRunners(startSide, false)
	placeBombers(-startSide)
	lockAll(true)
	publishCounts()
	setPhase(Ph.Intro, RC.INTRO)
	Net.fireAll("RoundFx", {
		kind = "Intro",
		bombers = (function()
			local ids = {}
			for p in pairs(bombers) do
				table.insert(ids, p.id)
			end
			return ids
		end)(),
		at = now(),
	})
	hold(RC.INTRO)
	local k = 0
	while true do
		k += 1
		-- READY: joiners become Bombers (F-FLOW-09), Bombers back to the middle, Runners hold behind the line.
		for _, p in ipairs(Participants.all()) do
			if present(p) and p.role == R.None then
				p.stats = Participants.newStats()
				p.stats.joinedMidMatch = true
				Participants.setRole(p, R.Bomber)
			end
		end
		BombService.finishGetups()
		placeRunners(startSide, true)
		placeBombers(-startSide)
		lockAll(true, R.Bomber)
		publishCounts()
		local ready = if k == 1 then RC.READY else RC.READY_LATER
		setPhase(Ph.Ready, ready)
		hold(ready)
		local result = if MegaService.expired()
			then "mega"
			else crossing(k, startSide, BombRules.fieldFuse(k) * lengthFactor(), false)
		if result == "mega" then
			-- F-MEGA-05: Runners in a Safe Strip win; everyone else booms. No Runners left → the giant's side wins.
			local winners = MegaService.detonate()
			hold(RC.RESOLVE)
			BombService.finishGetups()
			if #winners > 0 then
				MegaService.reward("Survivors", winners)
				finish("Survivors", winners)
			else
				MegaService.reward("Bombers", withRole(R.Bomber))
				finish("Bombers", withRole(R.Bomber))
			end
			return
		end
		local resolve = if result == "fuse" then RC.RESOLVE else RC.RESOLVE_QUICK
		setPhase(Ph.Resolve, resolve)
		hold(resolve)
		BombService.finishGetups()
		local alive = runnersAlive()
		publishCounts()
		if #alive == 0 or result == "wiped" then
			MegaService.reward("Bombers", withRole(R.Bomber))
			finish("Bombers", withRole(R.Bomber))
			return
		end
		startSide = -startSide
		if #alive == 1 and startRunners >= RC.LAST_STAND_MIN_RUNNERS then
			local runner = alive[1]
			if lastStand(runner, startSide) then
				finish("LastStand", { runner })
			else
				BombService.finishGetups()
				finish("Bombers", withRole(R.Bomber))
			end
			return
		end
		if k >= RC.MAX_CROSSINGS then
			finish("Survivors", alive)
			return
		end
	end
end

local function loop()
	while true do
		resetToLobby()
		setPhase(Ph.Intermission, RC.INTERMISSION)
		hold(RC.INTERMISSION)
		local min = if RunService:IsStudio() and Config.Debug.SIM_MODE then 1 else RC.MIN_PARTICIPANTS
		if #eligible() >= min and Arena.current then
			local ok, err = pcall(playRound)
			if not ok then
				warn("[Round] round failed, resetting:", err) -- fail forward: never freeze the server
			end
		end
	end
end

function RoundService.init()
	-- Joiners and respawns land on the waiting strip; in a round, the current start strip (they become Bombers at
	-- the next READY).
	PlayerService.spawnResolver = function(p: Participant)
		local t = os.clock()
		while not Arena.current and os.clock() - t < 30 do -- boot can take a while (avatar loading runs first)
			task.wait(0.1)
		end
		if not Arena.current then
			return Characters.lobbyCFrame()
		end
		if p.role == R.Bomber then
			return Arena.bomberBand(1, -startSide, rng)[1]
		end
		return strip(startSide)
	end
end

function RoundService.start()
	if not Arena.load(Config.Maps.Order[1]) then
		warn("[Round] no map loaded; rounds can't start")
	end
	AdminService.register("skip", function()
		skipFlag = true
		return "skipping the current wait"
	end)
	AdminService.register("state", function()
		return `{GameState.get("Phase")} {GameState.get("SubPhase")} crossing {GameState.get("Crossing")} runners {#runnersAlive()} bombers {#withRole(
			R.Bomber
		)} bombs {BombService.count()} dodges {BombService.dodgeCount}`
	end)
	AdminService.register("role", function(args)
		local p = Participants.get(args[1] or "")
		if not RunService:IsStudio() or not p or (args[2] ~= R.Runner and args[2] ~= R.Bomber) then
			return "usage: role <participantId> <Runner|Bomber>"
		end
		Participants.setRole(p, args[2])
		Participants.setState(p, S.Active)
		Characters.applyGroup(p)
		return p.id .. " is now " .. args[2]
	end)
	AdminService.register("cfg", function(args)
		-- cfg <Section> <KEY> <value>: Studio tuning, e.g. cfg Round INTERMISSION 3 / cfg Debug SIM_MODE true.
		local section = (Config :: any)[args[1] or ""]
		if not RunService:IsStudio() or type(section) ~= "table" or args[2] == nil then
			return "usage: cfg <Section> <KEY> <value>"
		end
		local v: any = args[3]
		if v == "true" or v == true then
			v = true
		elseif v == "false" or v == false then
			v = false
		elseif tonumber(v) then
			v = tonumber(v)
		end
		section[args[2]] = v
		return `{args[1]}.{args[2]} = {tostring(v)}`
	end)
	task.spawn(loop)
end

return RoundService
