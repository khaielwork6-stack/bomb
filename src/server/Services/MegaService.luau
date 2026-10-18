--!strict
-- The MEGA BOMB event (GDD §16). Every 15 minutes on the UTC wall clock the next round is a MEGA BOMB round: one
-- player (humans weighted 3×) becomes the MEGA BOMBER, a 3× giant whose touch sticks a 3 s bomb and whose Dash is a
-- telegraphed STOMP; everyone else starts as a Runner. The giant bomb on its back is the event clock (90 s from the
-- first GO): Runners feed it by passing their bombs onto the giant (a stagger and −6 s each) and win by standing in a
-- Safe Strip when it detonates; if every Runner booms first, the giant wins. Crossings run as normal throughout.
-- RoundService drives the round (claim → begin → go → expired → finish); this service owns the clock, the giant, the
-- stomp, feeding and the event rewards. Studio: "mega" makes the next round a MEGA BOMB round.
-- Implements: F-MEGA-01..08 (F-MEGA-09 summon and F-MEGA-10's lobby card styling come with the store product / UI).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local AdminService = require(script.Parent.AdminService)
local Arena = require(script.Parent.Arena)
local BombService = require(script.Parent.BombService)
local Characters = require(script.Parent.Characters)
local GameState = require(script.Parent.GameState)
local MoveService = require(script.Parent.MoveService)
local Participants = require(script.Parent.Participants)

type Participant = Participants.Participant

local MG = Config.Mega
local R, S = Types.Role, Types.State

local MegaService = {}

local SLOT = MG.SLOT_MINUTES * 60
local lastSlot = math.floor(os.time() / SLOT) -- a slot already open when the server starts doesn't count
local forced = false
local giant: Participant? = nil
local lastStomp = -math.huge
local rng = Random.new()

local function now(): number
	return GameState.now()
end

-- Services that require this one's callers are loaded lazily (no require cycles).
local function lazy(name: string): any
	return require(ServerScriptService.Server.Services:FindFirstChild(name) :: ModuleScript)
end

local function publishNext()
	GameState.set("MegaNextAt", (math.floor(os.time() / SLOT) + 1) * SLOT)
end

function MegaService.active(): Participant?
	return giant
end

-- F-MEGA-01/02: is this round a MEGA BOMB round? If so, who's the giant (humans weighted over bots).
function MegaService.claim(candidates: { Participant }): Participant?
	local slot = math.floor(os.time() / SLOT)
	if not forced and slot <= lastSlot then
		return nil
	end
	forced = false
	lastSlot = slot
	publishNext()
	local total = 0
	for _, p in ipairs(candidates) do
		total += if p.isBot then 1 else MG.HUMAN_WEIGHT
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, p in ipairs(candidates) do
		roll -= if p.isBot then 1 else MG.HUMAN_WEIGHT
		if roll <= 0 then
			return p
		end
	end
	return candidates[#candidates]
end

-- The giant takes the field (call after roles are set, before INTRO).
function MegaService.begin(p: Participant)
	giant = p
	p.data.mega = true
	p.attrs:SetAttribute("Mega", true)
	p.attrs:SetAttribute("SpeedMult", MG.GIANT_SPEED)
	Characters.setScale(p, MG.GIANT_SCALE)
	GameState.set("MegaId", p.id)
	GameState.set("MegaRound", true)
	GameState.set("MegaEndsAt", nil)
	for _, q in ipairs(Participants.all()) do
		if not q.isBot and (q.role == R.Runner or q.role == R.Bomber) then
			lazy("DailyService").event(q, "MegaRound")
		end
	end
end

-- The first GO lights the Mega Fuse (F-MEGA-05).
function MegaService.go()
	if giant and GameState.get("MegaEndsAt") == nil then
		GameState.set("MegaEndsAt", now() + MG.FUSE)
	end
end

function MegaService.expired(): boolean
	local ends = GameState.get("MegaEndsAt")
	return giant ~= nil and type(ends) == "number" and now() >= ends
end

-- F-MEGA-05: the MEGA BOMB detonates. Every Runner outside a Safe Strip booms; the ones inside win. Returns them.
function MegaService.detonate(): { Participant }
	Net.fireAll("RoundFx", { kind = "MegaDetonate", who = if giant then giant.id else nil, at = now() })
	local winners = {}
	for _, p in ipairs(Participants.all()) do
		if p.role == R.Runner and (p.state == S.Active or p.state == S.Safe) then
			local root = p.root
			if root and (p.state == S.Safe or Arena.inSafe(root.Position, -1) or Arena.inSafe(root.Position, 1)) then
				table.insert(winners, p)
			else
				BombService.boomParticipant(p)
			end
		end
	end
	return winners
end

-- F-MEGA-08: the event's own rewards (×3 round Stars are paid by ProgressionService from GameState.MegaRound).
function MegaService.reward(outcome: string, winners: { Participant })
	if not giant then
		return
	end
	local store = lazy("StoreService")
	for _, p in ipairs(winners) do
		if not p.isBot then
			if p.data.mega then
				store.grantItem(p, MG.TITLE_GIANT, "Mega")
			elseif outcome == "Survivors" then
				store.grantCrate(p, MG.REWARD_CRATE, "Mega")
				store.grantItem(p, MG.TITLE_SURVIVOR, "Mega")
			end
		end
	end
end

-- Back to normal (RoundService calls this when the round resets).
function MegaService.finish()
	local p = giant
	giant = nil
	if p then
		p.data.mega = nil
		p.attrs:SetAttribute("Mega", nil)
		p.attrs:SetAttribute("SpeedMult", nil)
		if p.model then
			Characters.setScale(p, 1)
		end
	end
	GameState.set("MegaId", nil)
	GameState.set("MegaRound", nil)
	GameState.set("MegaEndsAt", nil)
end

-- F-MEGA-04: the giant's Dash is a STOMP — a ring for STOMP_TELEGRAPH, then Runners in it are flung (no bomb).
local function stomp(p: Participant)
	local t = now()
	local root = p.root
	if not root or t - lastStomp < MG.STOMP_COOLDOWN then
		return
	end
	lastStomp = t
	local center = root.Position
	Net.fireAll("RoundFx", { kind = "MegaStomp", who = p.id, pos = center, radius = MG.STOMP_RADIUS, at = t })
	task.delay(MG.STOMP_TELEGRAPH, function()
		if giant ~= p then
			return
		end
		for _, q in ipairs(Participants.all()) do
			local qr = q.root
			if q.role == R.Runner and q.state == S.Active and qr then
				local d = (qr.Position - center) * Vector3.new(1, 0, 1)
				if d.Magnitude <= MG.STOMP_RADIUS then
					local dir = if d.Magnitude > 0.1 then d.Unit else Vector3.new(1, 0, 0)
					Characters.push(q, dir, MG.STOMP_PUSH * (1 - d.Magnitude / MG.STOMP_RADIUS * 0.5), 0.35)
				end
			end
		end
	end)
end

-- F-MEGA-06: fed a bomb — a stagger and the Mega Fuse jumps.
local function fed(from: Participant, to: Participant)
	if to ~= giant then
		return
	end
	local ends = GameState.get("MegaEndsAt")
	if type(ends) == "number" then
		GameState.set("MegaEndsAt", ends - MG.FEED_BURN)
	end
	Net.fireAll("RoundFx", { kind = "MegaFeed", who = from.id, burn = MG.FEED_BURN, at = now() })
	Characters.setLocked(to, true)
	task.delay(MG.FEED_STAGGER, function()
		if giant == to then
			Characters.setLocked(to, false)
		end
	end)
	if not from.isBot then
		lazy("DailyService").event(from, "MegaFeed")
	end
end

function MegaService.start()
	publishNext()
	MoveService.Action:Connect(function(p: Participant, kind: string)
		if kind == "Dash" and p.data.mega and p == giant then
			stomp(p)
		end
	end)
	BombService.Fed:Connect(fed)
	if RunService:IsStudio() then
		AdminService.register("mega", function()
			forced = true
			return "the next round is a MEGA BOMB round"
		end)
	end
end

return MegaService
