--!strict
-- Client entry point. Requires controllers in an explicit order, calls every init() then every start(). GDD §22.3.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The premium loading screen (Asset Bible §7.1) lands in P3. Until then no placeholder: anything named "UILoading"
-- is removed the moment it reaches PlayerGui.
do
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	-- Phones are always landscape (the user's call, 2026-10-07): never portrait, either way up is fine.
	pg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	local function drop(g: Instance)
		if g.Name == "UILoading" then
			g:Destroy()
		end
	end
	for _, g in ipairs(pg:GetChildren()) do
		drop(g)
	end
	pg.ChildAdded:Connect(drop)
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local ORDER: { string } = {
	"InputController",
	"MovementController",
	"CameraController",
	"PoseController",
	"MoveFxController",
	"FootstepController",
	"BombController",
	"FxController",
	"ImpactController",
	"MegaController",
	"HudController",
	"CalloutController",
	"CarrierController",
	"ModifierController",
	"LastStandController",
	"ResultsController",
	"AudioController",
	"YardController",
	"ProgressController",
	"DailyController",
	"QuestTrackerController",
	"LevelUpController",
	"OnboardingController",
	"CrownController",
	"StoreController",
	"DepotController",
}

-- No Backpack tools exist in FUSE VALLEY (the bomb is a welded model, GDD §7.2).
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- No "Reset Character" on any device: a reset mid-run would dodge a bomb or strand you outside the round flow.
-- SetCore fails until the CoreScripts register the callback, so keep trying for a while.
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 60 do
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
			return
		end
		task.wait(0.5)
	end
	warn("[Client] could not disable the reset button")
end)

-- Text always fits its box on every phone (UI/TextFit: system text size, small screens).
task.spawn(function()
	local ok, err = pcall(function()
		require(script.UI.TextFit).start()
	end)
	if not ok then
		warn("[Client] TextFit failed:", err)
	end
end)

local controllers = {}
for _, name in ipairs(ORDER) do
	local module = script.Controllers:FindFirstChild(name)
	assert(module, "Missing controller " .. name)
	controllers[name] = require(module) :: any
end
for _, name in ipairs(ORDER) do
	local c = controllers[name]
	if type(c.init) == "function" then
		local ok, err = pcall(c.init)
		if not ok then
			warn(`[Client] {name}.init failed:`, err)
		end
	end
end
for _, name in ipairs(ORDER) do
	local c = controllers[name]
	if type(c.start) == "function" then
		task.spawn(function()
			local ok, err = pcall(c.start)
			if not ok then
				warn(`[Client] {name}.start failed:`, err)
			end
		end)
	end
end

-- Studio: the phone / tablet layout simulator (Dev/MobileSim; idle until the CG_Sim attribute is set).
if game:GetService("RunService"):IsStudio() then
	require(script.Dev.MobileSim).start()
	-- Movement readout (Dev/MovementDebug; idle until the CG_MoveDebug attribute is set).
	require(script.Dev.MovementDebug).start()
end

Net.send("ClientReady")
print(`[Client] {Config.GameName} client started for {Players.LocalPlayer.Name}`)
