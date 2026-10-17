--!strict
-- Replicated global match state as attributes on ReplicatedStorage.GameState. GDD §21.4.
-- Clients read these; timers use workspace:GetServerTimeNow() (PhaseEndsAt).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local GameState = {}

local holder: Configuration

function GameState.init()
	local existing = ReplicatedStorage:FindFirstChild("GameState")
	if existing then
		existing:Destroy()
	end
	holder = Instance.new("Configuration")
	holder.Name = "GameState"
	holder.Parent = ReplicatedStorage
	GameState.set("Phase", Types.Phase.Boot)
	GameState.set("SubPhase", Types.Sub.None)
	GameState.set("PhaseEndsAt", 0)
	GameState.set("CrossingIndex", 0)
	GameState.set("CleanStreak", 0)
	GameState.set("Tier", "I")
	GameState.set("ThemeId", "Classic")
	GameState.set("MapId", "")
	GameState.set("ModifierId", "")
	GameState.set("ModifierSeed", 0)
	GameState.set("RunnersLeft", 0)
	GameState.set("CatchersCount", 0)
	GameState.set("LeadId", "")
	GameState.set("ChosenIds", "")
	GameState.set("BraveState", "")
	GameState.set("Headline", "")
	GameState.set("HeadlineSub", "")
	GameState.set("StartSide", 1)
	GameState.set("MatchSeed", 0)
end

function GameState.set(key: string, value: any)
	holder:SetAttribute(key, value)
end

function GameState.get(key: string): any
	return holder:GetAttribute(key)
end

function GameState.instance(): Configuration
	return holder
end

function GameState.now(): number
	return workspace:GetServerTimeNow()
end

-- Sets PhaseEndsAt to now + seconds (seconds already time-scaled by caller).
function GameState.setTimer(seconds: number)
	holder:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + seconds)
end

function GameState.headline(text: string, sub: string?)
	holder:SetAttribute("Headline", text)
	holder:SetAttribute("HeadlineSub", sub or "")
end

return GameState
