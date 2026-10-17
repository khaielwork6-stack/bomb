--!strict
-- Callouts (GDD §11.1): the server spots every moment worth a word — it knows who passed to whom and whose bomb it
-- was — and tells that player (Net "Callout"). Fired:Fire(p, key, n?) is the single source P4's RewardService pays
-- from, so the words and the rewards always agree. RoundService reports crossing ends and the Last Stand here.
-- Implements: F-CALL-01 (detection + delivery).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local BombRules = require(ServerScriptService.Server.Logic.BombRules)
local BombService = require(script.Parent.BombService)
local Participants = require(script.Parent.Participants)

type Participant = Participants.Participant

local CC = Config.Callouts
local R = Types.Role

local CalloutService = {
	-- (participant, key, n?, other?) every callout, bots included. `other` = the counterpart (the tagged Runner, the
	-- pass receiver, the boomed Runner) — anti-farm needs it (F-CALL-02).
	Fired = Signal.new(),
	-- RewardService sets this: what a callout pays, so the word and its numbers arrive together.
	payer = nil :: ((Participant, string, number?, Participant?) -> (number, number))?,
}

local recentBooms: { [string]: { number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function CalloutService.fire(p: Participant?, key: string, n: number?, other: Participant?)
	if not p or not CC.List[key] then
		return
	end
	local xp, stars = 0, 0
	local payer = CalloutService.payer
	if payer then
		xp, stars = payer(p, key, n, other)
	end
	CalloutService.Fired:Fire(p, key, n, other)
	if p.player then
		Net.fire(p.player, "Callout", { key = key, n = n, xp = xp, stars = stars, at = now() })
	end
end

-- Every Carrier a bomb went through gets CHAIN ×n once the bomb is done (n ≥ 3 distinct Carriers).
local function chainEnded(bomb: BombRules.Bomb)
	local n = BombRules.chainLength(bomb)
	if n < 3 then
		return
	end
	local seen = {}
	for _, id in ipairs(bomb.chain) do
		if not seen[id] then
			seen[id] = true
			CalloutService.fire(Participants.get(id), "Chain", n)
		end
	end
	for _, id in ipairs(bomb.chain) do
		local p = Participants.get(id)
		if p and n > p.stats.bestChain then
			p.stats.bestChain = n
		end
	end
end

-- RoundService: a crossing ended. Runners who made it get SURVIVED; an ALL CLEAR crossing tells every Runner.
function CalloutService.crossingEnded(result: string, crossed: { Participant })
	for _, p in ipairs(crossed) do
		CalloutService.fire(p, if result == "clear" then "AllClear" else "Survived")
	end
end

-- RoundService: the Last Stand began.
function CalloutService.lastStand(runner: Participant)
	CalloutService.fire(runner, "LastStand")
end

function CalloutService.start()
	BombService.Tagged:Connect(function(bomber: Participant, target: Participant)
		CalloutService.fire(bomber, "Tagged", nil, target)
	end)
	BombService.Passed:Connect(function(from: Participant, to: Participant, bomb: BombRules.Bomb, remaining: number)
		if to.role == R.Bomber then
			from.stats.revenges += 1
			CalloutService.fire(from, "RevengePass", nil, to)
			if to.id == bomb.origin then
				CalloutService.fire(from, "Revenge", nil, to)
			end
		elseif remaining <= Config.Bomb.CLOSE_PASS_WINDOW then
			CalloutService.fire(from, "CloseOne", nil, to)
		else
			CalloutService.fire(from, "Pass", nil, to)
		end
	end)
	BombService.Defused:Connect(function(p: Participant, bomb: BombRules.Bomb, clutch: boolean)
		CalloutService.fire(p, if clutch then "ClutchDefuse" else "Defused")
		chainEnded(bomb)
	end)
	BombService.RunnerBoomed:Connect(function(boomed: Participant, bomb: BombRules.Bomb?, credit: Participant?)
		if not bomb then
			return -- a field detonation: nobody's credit (F-FUSE-05)
		end
		-- BETRAYAL: the Runner who handed it over (not the Bomber who started it).
		local giver = if bomb.lastGiver then Participants.get(bomb.lastGiver) else nil
		if giver and giver.role == R.Runner and bomb.lastGiver ~= bomb.origin then
			giver.stats.betrayals += 1
			CalloutService.fire(giver, "Betrayal")
		end
		if credit then
			CalloutService.fire(credit, "Boom", nil, boomed)
			local t = now()
			local list = recentBooms[credit.id] or {}
			local kept = {}
			for _, at in ipairs(list) do
				if t - at <= CC.MULTI_BOOM_WINDOW then
					table.insert(kept, at)
				end
			end
			table.insert(kept, t)
			recentBooms[credit.id] = kept
			if #kept == 2 then
				CalloutService.fire(credit, "DoubleBoom")
			elseif #kept >= 3 then
				CalloutService.fire(credit, "TripleBoom")
			end
		end
		chainEnded(bomb)
	end)
	BombService.BomberBoomed:Connect(function(_p: Participant, bomb: BombRules.Bomb)
		chainEnded(bomb)
	end)
	Participants.Removed:Connect(function(p: Participant)
		recentBooms[p.id] = nil
	end)
end

return CalloutService
