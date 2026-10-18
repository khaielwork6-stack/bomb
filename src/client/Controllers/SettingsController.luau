--!strict
-- The menu (gear) button and the Settings screen (GDD §21.3 F-UI-04): a gear in Roblox's top-bar row, as in the
-- reference video, opening a panel in the same frame as the Shop — Music and Sound volume sliders, camera
-- sensitivity, Reduce Motion (springs become fades; no shake, slow-mo or vignette pulse), Show Tips, Colour-blind
-- Mode (patterns on the team chips), the mobile button size, and HOW TO PLAY (the 4 rules card again).
-- Values live in Settings (saved to the profile through SaveSettings).
-- Implements: F-UI-04 (Settings), §21.1 (reduced motion), the menu button of §21.2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Parent.Settings)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local DailyController = require(script.Parent.DailyController)
local OnboardingController = require(script.Parent.OnboardingController)

local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local SettingsController = {}

local gear: ImageButton

local function row(parent: Instance, label: string, order: number): Frame
	local r = new("Frame", {
		Name = label,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = 4,
		Parent = parent,
	})
	local face = Theme.panel(r, {
		Size = UDim2.fromScale(1, 1),
		kind = "Chip",
		color = Color3.fromRGB(64, 58, 88),
		color2 = Color3.fromRGB(44, 40, 62),
		border = Color3.fromRGB(96, 88, 128),
		scale = 0.35,
	})
	Widgets.label(face, {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextSize = 22,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		stroke = 2.5,
		Text = label,
		ZIndex = 6,
	})
	return face
end

-- A chunky slider: an ink well, a gradient fill, a round white knob; drag or tap anywhere on it.
local function slider(face: Frame, key: string, lo: number, hi: number, fmt: (number) -> string)
	local well = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -82, 0.5, 0),
		Size = UDim2.new(0.42, 0, 0, 16),
		BackgroundColor3 = P.Ink,
		ZIndex = 6,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = well })
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 7,
		Parent = well,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(60, 140, 255)),
		Parent = fill,
	})
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 8,
		Parent = well,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
	new("UIStroke", { Color = P.Ink, Thickness = 3, Parent = knob })
	local value = Widgets.label(face, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(60, 30),
		TextSize = 22,
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = "",
		ZIndex = 6,
	})
	local function show(v: number)
		local a = (v - lo) / (hi - lo)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		value.Text = fmt(v)
	end
	show(Settings.get(key) or lo)
	local hit = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 24, 0, 40),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 9,
		Parent = well,
	})
	local dragging = false
	local function setFrom(x: number)
		local a = math.clamp((x - well.AbsolutePosition.X) / math.max(1, well.AbsoluteSize.X), 0, 1)
		local v = lo + (hi - lo) * a
		v = if hi - lo > 10 then math.floor(v + 0.5) else math.floor(v * 10 + 0.5) / 10
		Settings.set(key, v)
		show(v)
	end
	hit.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFrom(input.Position.X)
			Sfx.play("UiTab", 0.6)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
end

-- An ON / OFF switch in the arcade style: green ON, grey OFF, the knob slides.
local function toggle(face: Frame, key: string)
	local holder = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(96, 38),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 6,
		Parent = face,
	})
	local track = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.Smoke,
		ZIndex = 6,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	new("UIStroke", { Color = P.Ink, Thickness = 3, Parent = track })
	local label = Widgets.label(track, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		font = Theme.Font.Display,
		stroke = 2,
		Text = "",
		ZIndex = 7,
	})
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.2, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 8,
		Parent = track,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
	new("UIStroke", { Color = P.Ink, Thickness = 2.5, Parent = knob })
	local function show(on: boolean, animate: boolean)
		track.BackgroundColor3 = if on then Color3.fromRGB(56, 204, 32) else Color3.fromRGB(104, 100, 118)
		label.Text = if on then "ON" else "OFF"
		label.Position = UDim2.fromOffset(if on then -12 else 12, 0)
		local goal = UDim2.fromScale(if on then 0.8 else 0.2, 0.5)
		if animate and not Widgets.reduced() then
			TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Position = goal }):Play()
		else
			knob.Position = goal
		end
	end
	show(Settings.get(key) == true, false)
	holder.Activated:Connect(function()
		local on = not (Settings.get(key) == true)
		Settings.set(key, on)
		show(on, true)
		Sfx.play("UiPress")
	end)
end

local function segmented(face: Frame, key: string, options: { string })
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(170, 40),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = face,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6),
		Parent = holder,
	})
	local function build()
		for _, c in ipairs(holder:GetChildren()) do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		for i, opt in ipairs(options) do
			local b = Widgets.button(
				holder,
				opt,
				if Settings.get(key) == opt then "cyan" else "dark",
				UDim2.fromOffset(50, 36),
				function()
					Settings.set(key, opt)
					build()
				end,
				{ TextSize = 20, LayoutOrder = i, ZIndex = 7 }
			)
			b.LayoutOrder = i
		end
	end
	build()
end

local function open()
	local face = DailyController.panel("Settings", "SETTINGS", Vector2.new(600, 590), Color3.fromRGB(150, 110, 255))
	local list = new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -40, 1, -62),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
		Parent = face,
	})
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), Parent = list })
	slider(row(list, S.Ui.SetMusic, 1), "musicVolume", 0, 100, function(v)
		return tostring(v)
	end)
	slider(row(list, S.Ui.SetSfx, 2), "sfxVolume", 0, 100, function(v)
		return tostring(v)
	end)
	slider(row(list, S.Ui.SetCamera, 3), "cameraSensitivity", 0.2, 2.0, function(v)
		return ("%.1f"):format(v)
	end)
	toggle(row(list, S.Ui.SetReduceMotion, 4), "reduceMotion")
	toggle(row(list, S.Ui.SetTips, 5), "showTips")
	toggle(row(list, S.Ui.SetColourBlind, 6), "colourBlindOutlines")
	segmented(row(list, S.Ui.SetButtons, 7), "mobileButtonSize", { "S", "M", "L" })
	local howRow = new("Frame", {
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		LayoutOrder = 8,
		Parent = list,
	})
	Widgets.button(howRow, S.Ui.HowToPlay, "orange", UDim2.fromOffset(240, 50), function()
		DailyController.close()
		task.delay(0.15, function()
			OnboardingController.showRules()
		end)
	end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextSize = 24 })
end

local function place()
	local tb = Screen.topbar()
	local h = math.max(36, tb.Height - 12)
	gear.Size = UDim2.fromOffset(h + 8, h + 8)
	gear.Position = UDim2.fromOffset(tb.Min.X + 6, tb.Min.Y + tb.Height / 2)
end

function SettingsController.start()
	-- the saved settings come back in the first Progress snapshot: apply them once
	local applied = false
	local function applySaved(s: { [string]: any }?)
		if not applied and s and type(s.settings) == "table" then
			applied = true
			Settings.apply(s.settings)
		end
	end
	Progress.Changed:Connect(applySaved)
	applySaved(Progress.get())
	local gui = new("ScreenGui", {
		Name = "FV_Menu",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	gear = new("ImageButton", {
		Name = "Gear",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	Widgets.icon(gear, "Gear", 44, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	local sc = new("UIScale", { Parent = gear })
	gear.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
		Sfx.play("UiHover")
	end)
	gear.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	gear.Activated:Connect(function()
		Sfx.play("UiPress")
		open()
	end)
	place()
	Screen.Changed:Connect(place)
	-- volumes apply live
	Sfx.setVolume((Settings.get("sfxVolume") or 90) / 100)
	Settings.Changed:Connect(function(key, value)
		if key == "sfxVolume" and type(value) == "number" then
			Sfx.setVolume(value / 100)
		end
	end)
end

return SettingsController
