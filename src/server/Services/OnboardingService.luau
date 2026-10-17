--!strict
-- The first session, measured (GDD §20, §25.2): the 10-step onboarding funnel, logged once per profile with
-- AnalyticsService, and the custom round / reward events. The client-side onboarding (rules card, tips, the quest
-- intro) reports through DailyService's DailyAction; everything else is detected here on the server.
-- Implements: F-ONB-05 (the level-2 step is measured), F-KPI-02.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local BombService = require(script.Parent.BombService)
local DailyService = require(script.Parent.DailyService)
local DataService = require(script.Parent.DataService)
local Participants = require(script.Parent.Participants)
local ProgressionService = require(script.Parent.ProgressionService)
local RoundService = require(script.Parent.RoundService)

type Participant = Participants.Participant

local R = Types.Role

local OnboardingService = {}

-- The funnel (§25.2), in order.
local STEPS = {
	"Loaded",
	"RulesClosed",
	"Round1Started",
	"FirstCarry",
	"FirstPassOrDefuse",
	"Round1Finished",
	"Level2",
	"Round3Finished",
	"QuestTrackerOpened",
	"Round5Finished",
}
local STEP_INDEX: { [string]: number } = {}
for i, s in ipairs(STEPS) do
	STEP_INDEX[s] = i
end

function OnboardingService.step(p: Participant, name: string)
	local player = p.player
	local d = if p.isBot then nil else DataService.get(p)
	local i = STEP_INDEX[name]
	if not player or not d or not i or d.flags.funnel[name] then
		return
	end
	d.flags.funnel[name] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, i, name)
	end)
end

function OnboardingService.custom(p: Participant, name: string, value: number?)
	local player = p.player
	if not player then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

function OnboardingService.start()
	DataService.Loaded:Connect(function(p: Participant)
		OnboardingService.step(p, "Loaded")
	end)
	DailyService.ClientMoment:Connect(function(p: Participant, kind: string)
		if kind == "RulesSeen" then
			OnboardingService.step(p, "RulesClosed")
		elseif kind == "QuestsOpened" then
			OnboardingService.step(p, "QuestTrackerOpened")
		end
	end)
	Participants.RoleChanged:Connect(function(p: Participant, role: string)
		local d = if p.isBot then nil else DataService.get(p)
		if d and d.stats.rounds == 0 and (role == R.Runner or role == R.Bomber) then
			OnboardingService.step(p, "Round1Started")
		end
	end)
	BombService.Tagged:Connect(function(_bomber: Participant, target: Participant)
		OnboardingService.step(target, "FirstCarry")
	end)
	BombService.Passed:Connect(function(from: Participant, to: Participant)
		OnboardingService.step(to, "FirstCarry")
		OnboardingService.step(from, "FirstPassOrDefuse")
	end)
	BombService.Defused:Connect(function(p: Participant)
		OnboardingService.step(p, "FirstPassOrDefuse")
	end)
	ProgressionService.RoundPaid:Connect(function(p: Participant, s: { [string]: any })
		local d = DataService.get(p)
		local rounds = d and d.stats.rounds or 0
		if rounds == 1 then
			OnboardingService.step(p, "Round1Finished")
		elseif rounds == 3 then
			OnboardingService.step(p, "Round3Finished")
		elseif rounds == 5 then
			OnboardingService.step(p, "Round5Finished")
		end
		OnboardingService.custom(p, "RoundCrossings", s.reached)
		if s.won and s.outcome == "LastStand" then
			OnboardingService.custom(p, "LastStandWon")
		end
	end)
	ProgressionService.LeveledUp:Connect(function(p: Participant, level: number)
		if level == 2 then
			OnboardingService.step(p, "Level2")
		end
	end)
	RoundService.Ended:Connect(function(outcome: string)
		for _, p in ipairs(Participants.humans()) do
			if p.role == R.Runner or p.role == R.Bomber then
				OnboardingService.custom(p, "RoundOutcome_" .. outcome)
				OnboardingService.custom(p, "RoundBooms", p.stats.booms)
				OnboardingService.custom(p, "RoundClutches", p.stats.clutches)
			end
		end
	end)
end

return OnboardingService
