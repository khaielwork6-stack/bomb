--!strict
-- Replicated global round state as attributes on ReplicatedStorage.GameState. GDD §22.2.
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
	-- Round (GDD §5, §6.2, §8): the HUD reads these.
	GameState.set("Crossing", 0)
	GameState.set("MaxCrossings", 0)
	GameState.set("StartSide", -1) -- the side the Runners cross FROM this crossing
	GameState.set("FuseEndsAt", 0) -- the Field Fuse (server time)
	GameState.set("FuseTotal", 0)
	GameState.set("RunnersLeft", 0)
	GameState.set("BombersCount", 0)
	GameState.set("LastStandId", "")
	GameState.set("Outcome", "") -- "LastStand" | "Bombers" | "Survivors" at RESULTS
	GameState.set("Headline", "")
	GameState.set("HeadlineSub", "")
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
