--!strict
-- The lobby dock's AFK toggle and Spectate camera (the owner's reference video, DECISIONS 2026-10-17 "extras").
-- AFK: a red tile showing ON / OFF; it sets the player's AFK wish and, once the partner's server remote exists
-- (docs/PARTNER_REQUESTS.md #4, "SetAfk"), tells the server, which then keeps AFK players out of the next rounds.
-- Spectate: a purple camera tile that points CameraController.spectate at a live participant; a bar at the bottom
-- shows who you're watching with ◀ ▶ (or Q / E) to switch and EXIT (or V again) to come back.
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
local DailyController = require(script.Parent.DailyController)

local S = Config.Strings
local new = Theme.new
local player = Players.LocalPlayer

local LobbyController = {}

local afk = false
local afkText: TextLabel
local gui: ScreenGui
local bar: Frame
local nameLabel: TextLabel
local watching: number = 0 -- index into the current candidate list, 0 = not spectating

local function setAfk(on: boolean)
	afk = on
	player:SetAttribute("AfkWish", on)
	afkText.Text = if on then S.Ui.On else S.Ui.Off
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
	-- AFK: a red tile with ON / OFF in big type instead of an icon
	local afkButton = DailyController.addDockButton("AFK", "Sleep", 6, function()
		setAfk(not afk)
	end, { color = "red", key = Enum.KeyCode.K, label = "AFK" })
	local face = afkButton:FindFirstChild("Face")
	local icon = face and face:FindFirstChild("Icon_Sleep")
	if icon and icon:IsA("GuiObject") then
		icon.Visible = false
	end
	afkText = Widgets.label(face or afkButton, {
		Name = "State",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(1, 0.5),
		Text = S.Ui.Off,
		TextSize = 34,
		font = Theme.Font.Display,
		stroke = 3,
		ZIndex = 6,
	})
	DailyController.addDockButton("Spectate", "Camera", 7, toggleSpectate, {
		color = "purple",
		key = Enum.KeyCode.V,
	})
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or watching == 0 or UserInputService:GetFocusedTextBox() then
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
end

return LobbyController
