--!strict
-- The perks (the owner's calls, 2026-10-18: "decide the prices… we could change this later"; DECISIONS):
--   • the lobby spin wheel: one free spin every Config.Wheel.FREE_EVERY, bought spins (Spin1 / Spin5) on top; the
--     server rolls the weighted segment, pays it (Gems or a crate), and replies Reward { kind = "Wheel", segment };
--   • Become Lead Bomber (product LeadBomber): the buyer is a starting Bomber in the next round they play
--     (RoundService.pickBombers reads the profile flag and clears it);
--   • Revive (product Revive): a bought Revive turns a boomed Runner back into a Runner — during the tumble, or within
--     Config.Round.REVIVE_GRACE after they got up as a Bomber; if it can't apply now it's kept and used at their next
--     boom. Once per round.
-- Snapshot sections: `wheel = { spins, freeIn }` (WheelController) and `perks = { leadBomber, revives }`.
-- Implements: the spin wheel (server), the Lead Bomber and Revive products (docs/PARTNER_REQUESTS.md #2, #11, #13).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Participants = require(script.Parent.Participants)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local StoreService = require(script.Parent.StoreService)
local BombService = require(script.Parent.BombService)

type Participant = Participants.Participant

local W = Config.Wheel
local PerkService = {}

local rng = Random.new()

local function freeReady(d: { [string]: any }): boolean
	return os.time() - (d.wheel.lastFree or 0) >= W.FREE_EVERY
end

local function spinsOf(d: { [string]: any }): number
	return (d.wheel.spins or 0) + (if freeReady(d) then 1 else 0)
end

local function roll(): number
	local total = 0
	for _, s in ipairs(W.SEGMENTS) do
		total += s.weight
	end
	local r = rng:NextNumber() * total
	for i, s in ipairs(W.SEGMENTS) do
		r -= s.weight
		if r <= 0 then
			return i
		end
	end
	return #W.SEGMENTS
end

local function spin(player: Player)
	local p = Participants.fromPlayer(player)
	local d = p and DataService.get(p)
	if not p or not d or spinsOf(d) <= 0 then
		return
	end
	-- the free spin first, then a bought one
	if freeReady(d) then
		d.wheel.lastFree = os.time()
	else
		d.wheel.spins -= 1
	end
	local i = roll()
	local seg = W.SEGMENTS[i]
	if seg.kind == "Stars" then
		ProgressionService.grant(p, 0, seg.amount, "Wheel")
	elseif seg.kind == "Crate" then
		StoreService.grantCrate(p, seg.crate, "Wheel")
	end
	Net.fire(player, "Reward", { kind = "Wheel", segment = i })
	ProgressionService.push(p)
end

-- A bought Revive: apply it now if it can, else keep it for the next boom.
local function tryRevive(p: Participant)
	local d = DataService.get(p)
	if not d or (d.revives or 0) <= 0 then
		return
	end
	if BombService.revive(p) then
		d.revives -= 1
		if p.player then
			Net.fire(p.player, "Reward", { kind = "Revived" })
		end
	elseif p.player then
		Net.fire(p.player, "Reward", { kind = "ReviveSaved" })
	end
	ProgressionService.push(p)
end

function PerkService.start()
	Net.on("Spin", spin)
	ProgressionService.addSection(function(_p, d)
		local freeIn = if freeReady(d) then nil else W.FREE_EVERY - (os.time() - (d.wheel.lastFree or 0))
		return "wheel", { spins = spinsOf(d), freeIn = freeIn }
	end)
	ProgressionService.addSection(function(_p, d)
		return "perks", { leadBomber = d.flags.leadBomber == true, revives = d.revives or 0 }
	end)
	StoreService.ProductGranted:Connect(function(p: Participant, key: string)
		if key == "Revive" then
			tryRevive(p)
		end
	end)
	-- a kept Revive is used automatically at the owner's next boom (once per round)
	BombService.autoRevive = function(p: Participant): boolean
		local d = DataService.get(p)
		if d and (d.revives or 0) > 0 and not p.data.revived then
			d.revives -= 1
			ProgressionService.push(p)
			if p.player then
				Net.fire(p.player, "Reward", { kind = "Revived" })
			end
			return true
		end
		return false
	end
end

return PerkService
