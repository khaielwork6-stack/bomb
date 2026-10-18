--!strict
-- Round modifiers (GDD §6.4). RoundService asks at every round start whether this one bends a rule
-- (GameState.Modifier = "" | "Face" | "LightsOut" | "Mole"); the rules themselves live where they act:
--   READ THE FACE: BombService (random fuse, the boom time kept off the Carrier until HOT); clients hide the time.
--   LIGHTS OUT: clients only (ModifierController); bots see through the same eyes (BotService).
--   THE MOLE: here. One Runner is told in secret (ModFx); their STRIKE intent arms a tag window that BombService
--   applies (p.data.strikeUntil), and they're revealed by their strike, their boom, the deadline crossing, or when
--   only MOLE_REVEAL_LEFT other Runners are left.
-- Implements: F-MOD-01 (rotation), F-MOD-04 (the Mole), F-MOD-05 (no payout changes: the strike is a normal tag).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local AdminService = require(script.Parent.AdminService)
local Arena = require(script.Parent.Arena)
local BombService = require(script.Parent.BombService)
local Characters = require(script.Parent.Characters)
local DataService = require(script.Parent.DataService)
local GameState = require(script.Parent.GameState)
local Participants = require(script.Parent.Participants)

type Participant = Participants.Participant

local MOD = Config.Modifiers
local R, S = Types.Role, Types.State

local ModifierService = {}

local rng = Random.new()
local roundsSince = 0 -- non-MEGA rounds since the last modifier round
local last = ""
local current = ""
local mole: Participant? = nil
local forced: string? = nil -- Studio: "modifier <name>" makes the next round that modifier
local forcedMole: string? = nil -- Studio: "modifier Mole <participantId>" also picks the Mole

local function now(): number
	return workspace:GetServerTimeNow()
end

function ModifierService.current(): string
	return current
end

function ModifierService.moleOf(): Participant?
	return mole
end

-- ── The Mole ────────────────────────────────────────────────────────────────────────────────────────────────────
local function lifetimeRounds(p: Participant): number
	local profile = if p.isBot then nil else DataService.get(p)
	return if profile then profile.stats.rounds else (p.data.roundsPlayed or 0)
end

local function pickMole(runners: { Participant }): Participant?
	local pool = {}
	for _, p in ipairs(runners) do
		if p.isBot or lifetimeRounds(p) >= MOD.MOLE_MIN_ROUNDS then
			table.insert(pool, p)
		end
	end
	return if #pool > 0 then pool[rng:NextInteger(1, #pool)] else nil
end

local function clearMole(p: Participant)
	p.data.mole = nil
	p.data.strikeUntil = nil
	p.data.strikeNextAt = nil
	p.data.moleStrikeAt = nil
end

-- Reveal the Mole to everyone. `how` = "strike" | "boom" | "deadline" | "left". Unless they boomed (the get-up makes
-- them a Bomber), they're a Bomber from now on.
local function reveal(how: string)
	local p = mole
	if not p then
		return
	end
	mole = nil
	clearMole(p)
	if how ~= "boom" and p.role == R.Runner and p.state ~= S.Tumbled and p.model then
		Participants.setRole(p, R.Bomber)
		Participants.setState(p, S.Active)
		Characters.applyGroup(p)
	end
	Net.fireAll("RoundFx", { kind = "MoleReveal", who = p.id, how = how, at = now() })
end

-- F-MOD-04: the STRIKE intent (humans via the Strike remote, bots directly). Returns whether it armed.
function ModifierService.strike(p: Participant): boolean
	local t = now()
	local root = p.root
	if
		p ~= mole
		or current ~= "Mole"
		or not BombService.live
		or p.role ~= R.Runner
		or p.state ~= S.Active
		or not root
		or BombService.bombOf(p) ~= nil
		or Arena.inSafe(root.Position, -1)
		or Arena.inSafe(root.Position, 1)
		or t < (p.data.strikeNextAt or 0)
	then
		return false
	end
	p.data.strikeUntil = t + MOD.STRIKE_TIME
	p.data.strikeNextAt = t + MOD.STRIKE_TIME + MOD.STRIKE_RETRY
	if p.player then
		Net.fire(p.player, "ModFx", { kind = "Armed", untilAt = p.data.strikeUntil, nextAt = p.data.strikeNextAt })
	end
	return true
end

-- ── Round hooks (RoundService) ──────────────────────────────────────────────────────────────────────────────────
-- F-MOD-01: called once roles are set, before INTRO. `mega` = this is a MEGA BOMB round.
function ModifierService.begin(mega: boolean, runners: { Participant })
	current = ""
	local pick = ""
	if forced ~= nil then
		pick = forced :: string
	elseif RunService:IsStudio() and Config.Debug.FORCE_MODIFIER then
		pick = Config.Debug.FORCE_MODIFIER :: string
	elseif not mega then
		roundsSince += 1
		if roundsSince >= MOD.EVERY then
			local options = {}
			for _, name in ipairs(MOD.POOL) do
				if name ~= last and (name ~= "Mole" or #runners >= MOD.MOLE_MIN_RUNNERS) then
					table.insert(options, name)
				end
			end
			if #options > 0 then
				pick = options[rng:NextInteger(1, #options)]
			end
		end
	end
	forced = nil
	if mega then
		pick = "" -- MEGA wins; the modifier waits for the next round
	end
	if pick == "Mole" then
		local p = if #runners >= MOD.MOLE_MIN_RUNNERS then pickMole(runners) else nil
		local chosen = forcedMole and Participants.get(forcedMole)
		if chosen and table.find(runners, chosen) then
			p = chosen
		end
		forcedMole = nil
		if not p then
			pick = ""
		else
			mole = p
			p.data.mole = true
			p.data.strikeNextAt = 0
			p.data.moleStrikeAt = rng:NextNumber(MOD.BOT_STRIKE_DELAY[1], MOD.BOT_STRIKE_DELAY[2]) -- bots: after GO
			if p.player then
				Net.fire(p.player, "ModFx", { kind = "Mole" })
			end
		end
	end
	if pick ~= "" then
		roundsSince = 0
		last = pick
	end
	current = pick
	GameState.set("Modifier", pick)
end

-- After every crossing: the Mole is revealed at the deadline, or once few real Runners are left.
function ModifierService.crossingEnded(k: number)
	local p = mole
	if not p then
		return
	end
	local others = 0
	for _, q in ipairs(Participants.all()) do
		if q ~= p and q.role == R.Runner and q.state ~= S.Tumbled and q.model then
			others += 1
		end
	end
	if k >= MOD.MOLE_DEADLINE then
		reveal("deadline")
	elseif others <= MOD.MOLE_REVEAL_LEFT then
		reveal("left")
	end
end

function ModifierService.reset()
	if mole then
		clearMole(mole)
	end
	mole = nil
	current = ""
	GameState.set("Modifier", "")
end

function ModifierService.start()
	Net.on("Strike", function(player: Player)
		local p = Participants.fromPlayer(player)
		if p then
			ModifierService.strike(p)
		end
	end)
	BombService.Tagged:Connect(function(bomber: Participant)
		if bomber == mole then
			reveal("strike")
		end
	end)
	BombService.RunnerBoomed:Connect(function(p: Participant)
		if p == mole then
			reveal("boom")
		end
	end)
	Participants.Removed:Connect(function(p: Participant)
		if p == mole then
			mole = nil
		end
	end)
	-- Studio: "modifier <Face|LightsOut|Mole|none> [moleId]" makes the next round that modifier (and that Mole).
	AdminService.register("modifier", function(args)
		local name = args[1] or ""
		if not RunService:IsStudio() then
			return "Studio only"
		end
		if name == "none" then
			forced = ""
			return "next round: no modifier"
		end
		if not table.find(MOD.POOL, name) then
			return "usage: modifier <" .. table.concat(MOD.POOL, "|") .. "|none>"
		end
		forced = name
		forcedMole = if name == "Mole" then args[2] else nil
		return "next round: " .. name .. (if forcedMole then " (Mole " .. forcedMole .. ")" else "")
	end)
end

return ModifierService
