--!strict
-- AFK and Spectate (the owner's reference video, DECISIONS 2026-10-17 "extras"; moved off the dock into Settings on
-- 2026-10-19 — two fewer tiles for a new player). AFK sets the player's AFK wish and tells the server (SetAfk), which
-- keeps AFK players out of the next rounds. Spectate points CameraController.spectate at a live participant; a bar at
-- the bottom shows who you're watching with ◀ ▶ (or Q / E) to switch and EXIT to come back. Shortcuts: K (AFK) and
-- V (Spectate) still work from anywhere.
-- Implements: F-UI-03 (dock); client side only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local CameraController = require(script.Parent.CameraController)

local S = Config.Strings
local new = Theme.new
local player = Players.LocalPlayer

local LobbyController = {}

local afk = false
local gui: ScreenGui
local bar: Frame
local nameLabel: TextLabel
local watching: number = 0 -- index into the current candidate list, 0 = not spectating

local function setAfk(on: boolean)
	afk = on
	player:SetAttribute("AfkWish", on)
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("SetAfk")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(on)
	end
end

local function candidates(): { { name: string, hum: Humanoid } }
	local out = {}
	local me = ClientState.myId()
	for _, p in ipairs(ClientState.participants()) do
		local id = p.host:GetAttribute("ParticipantId")
		local hum = p.model and p.model:FindFirstChildOfClass("Humanoid")
		if id ~= me and hum and hum.Health > 0 then
			table.insert(out, { name = ClientState.nameOf(id), hum = hum })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

local function stopSpectate()
	watching = 0
	CameraController.spectate = nil
	TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 1, 120) }):Play()
end

local function show(step: number)
	local list = candidates()
	if #list == 0 then
		Sfx.play("UiDeny")
		stopSpectate()
		return
	end
	watching = ((watching - 1 + step) % #list) + 1
	local c = list[watching]
	CameraController.spectate = c.hum
	nameLabel.Text = c.name
	TweenService:Create(bar, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -24),
	}):Play()
end

local function toggleSpectate()
	if watching > 0 then
		stopSpectate()
	else
		watching = 0
		show(1)
	end
end

local function buildBar()
	gui = new("ScreenGui", {
		Name = "FV_Spectate",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 120),
		Size = UDim2.fromOffset(460, 64),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.panel(bar, { Size = UDim2.fromScale(1, 1), border = Color3.fromRGB(196, 150, 255) })
	Widgets.label(bar, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(1, -200, 0, 18),
		Text = S.Ui.Spectating,
		TextSize = 15,
		color = Color3.fromRGB(196, 150, 255),
		ZIndex = 6,
	})
	nameLabel = Widgets.label(bar, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -200, 0, 30),
		Text = "",
		TextSize = 26,
		font = Theme.Font.Display,
		stroke = 3,
		ZIndex = 6,
	})
	Widgets.button(bar, "<", "purple", UDim2.fromOffset(48, 44), function()
		show(-1)
	end, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, -2), TextSize = 28 })
	Widgets.button(bar, ">", "purple", UDim2.fromOffset(48, 44), function()
		show(1)
	end, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 66, 0.5, -2), TextSize = 28 })
	Widgets.button(bar, S.Ui.Exit, "red", UDim2.fromOffset(84, 44), stopSpectate, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -2),
		TextSize = 22,
	})
end

function LobbyController.start()
	buildBar()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		-- the shortcuts (the controls themselves live in Settings now)
		if input.KeyCode == Enum.KeyCode.K then
			setAfk(not afk)
			Sfx.play(if afk then "ToggleOn" else "ToggleOff")
			return
		elseif input.KeyCode == Enum.KeyCode.V and not ClientState.activeInRun() then
			toggleSpectate()
			return
		end
		if watching == 0 then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			show(-1)
		elseif input.KeyCode == Enum.KeyCode.E then
			show(1)
		end
	end)
	-- a round that pulls us in ends spectating
	ClientState.myChanged("Role", function()
		if watching > 0 and ClientState.activeInRun() then
			stopSpectate()
		end
	end)
	-- the watched character was rebuilt or left: move on to the next one (or stop if nobody is left)
	game:GetService("RunService").Heartbeat:Connect(function()
		local hum = CameraController.spectate
		if watching > 0 and (not hum or not hum.Parent or hum.Health <= 0) then
			show(0)
		end
	end)
end

-- For the Settings panel.
function LobbyController.isAfk(): boolean
	return afk
end

function LobbyController.setAfk(on: boolean)
	setAfk(on)
end

function LobbyController.spectate()
	toggleSpectate()
end

return LobbyController
