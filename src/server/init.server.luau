--!strict
-- Server entry point. Requires services in an explicit order, calls every init() then every start().
-- GDD §22.3. Add new services to ORDER (dependencies first).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local ORDER = {
	"GameState",
	"Participants",
	"Characters",
	"PlayerService",
	"PositionHistory",
	"Arena",
	"AdminService",
	"MoveService",
	"MovementValidator",
	"AvatarPool",
	"DataService",
	"BombService",
	"CalloutService",
	"MomentService",
	"MegaService",
	"RoundService",
	"BotService",
	"ProgressionService",
	"DailyService",
	"LeaderboardService",
	"OnboardingService",
	"StoreService",
	"DepotService",
}

Net.init()

local services = {}
for _, name in ipairs(ORDER) do
	local module = script.Services:FindFirstChild(name)
	assert(module, "Missing service " .. name)
	services[name] = require(module) :: any
end

for _, name in ipairs(ORDER) do
	local svc = services[name]
	if type(svc.init) == "function" then
		local ok, err = pcall(svc.init)
		if not ok then
			warn(`[Server] {name}.init failed:`, err)
		end
	end
end

for _, name in ipairs(ORDER) do
	local svc = services[name]
	if type(svc.start) == "function" then
		task.spawn(function()
			local ok, err = pcall(svc.start)
			if not ok then
				warn(`[Server] {name}.start failed:`, err)
			end
		end)
	end
end

-- Studio test tools (Dev/*): never run in a live server.
if RunService:IsStudio() then
	require(script.Dev.Dummies).start()
	require(script.Dev.PaceProbe).start()
end

if RunService:IsStudio() and Config.Debug.RUN_TESTS then
	task.defer(function()
		require(script.Tests.Runner).run()
	end)
end

print(`[Server] {Config.GameName} server started`)
