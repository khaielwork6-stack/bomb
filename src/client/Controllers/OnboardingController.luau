--!strict
-- The first session (GDD §20): the four rules card on first join (four animated panels, one GOT IT — reopenable
-- with OnboardingController.showRules), the contextual tips once each (first carry, first time a Bomber, first
-- Field Fuse warning: big, centred, gone in 2.5 s), and the quest intro after round 2 (F-ONB-06: the tracker
-- slides in with "Daily quests: earn Stars!" and a tap to view). Flags live on the profile (the server keeps them).
-- Implements: F-ONB-02, F-ONB-04, F-ONB-06.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Settings = require(script.Parent.Parent.Settings)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Modal = require(script.Parent.Parent.UI.Modal)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local DailyController = require(script.Parent.DailyController)

local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local Ph = Types.Phase
local player = Players.LocalPlayer

local OnboardingController = {}

local gui: ScreenGui
local rulesOpen = false
local tipsShown: { [string]: boolean } = {}
local introShown = false

-- ── The four rules card ─────────────────────────────────────────────────────────────────────────────────────────
-- Each panel's 2 s looping illustration, built from the icon set.
local function illustrate(stage: Frame, i: number)
	local function person(tint: Color3, x: number): Frame
		local img = Widgets.icon(stage, "Person", 54, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, 1, -6),
			tint = tint,
			ZIndex = 6,
		})
		return img.Parent :: Frame
	end
	local function bomb(x: number, y: number, size: number?): Frame
		local img = Widgets.icon(stage, "Bomb", size or 34, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, y, 0),
			ZIndex = 7,
		})
		return img.Parent :: Frame
	end
	local loop = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	if i == 1 then
		-- a Bomber leans in to touch; the bomb pops onto the Runner
		local bomber = person(P.Bomber, 0.28)
		person(P.Runner, 0.7)
		TweenService:Create(bomber, loop, { Position = UDim2.new(0.46, 0, 1, -6) }):Play()
		local b = bomb(0.74, 0.32)
		local sc = new("UIScale", { Scale = 0, Parent = b })
		TweenService
			:Create(sc, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true), { Scale = 1 })
			:Play()
	elseif i == 2 then
		-- the bomb hops between two Runners
		person(P.Runner, 0.26)
		person(P.Runner, 0.74)
		local b = bomb(0.3, 0.3)
		TweenService:Create(b, loop, { Position = UDim2.new(0.7, 0, 0.3, 0), Rotation = 30 }):Play()
	elseif i == 3 then
		-- a fuse burning down that never resets
		bomb(0.5, 0.42, 58)
		local well = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(0.8, 0, 0, 12),
			BackgroundColor3 = P.Ink,
			ZIndex = 6,
			Parent = stage,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = well })
		local fill = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = P.Fuse,
			ZIndex = 7,
			Parent = well,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
		TweenService:Create(
			fill,
			TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Size = UDim2.fromScale(0, 1) }
		):Play()
	else
		-- a Runner reaches the green safe side; the shield pops
		local strip = new("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.new(0.3, 0, 0, 10),
			BackgroundColor3 = P.Safe,
			ZIndex = 5,
			Parent = stage,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = strip })
		local runner = person(P.Runner, 0.25)
		TweenService:Create(runner, loop, { Position = UDim2.new(0.82, 0, 1, -6) }):Play()
		local shield = Widgets.icon(stage, "Shield", 34, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.82, 0, 0.26, 0),
			ZIndex = 7,
		})
		local sc = new("UIScale", { Scale = 0, Parent = shield.Parent })
		TweenService
			:Create(sc, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true), { Scale = 1 })
			:Play()
	end
end

function OnboardingController.showRules()
	if rulesOpen then
		return
	end
	rulesOpen = true
	Modal.set("Rules", true)
	for _, c in ipairs(gui:GetChildren()) do
		c:Destroy()
	end
	Widgets.backdrop(gui, 0.3)
	local face = Theme.panel(gui, {
		Name = "Rules",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(700, 340),
		color = P.Ink2,
		border = P.Fuse,
		border2 = P.Ember,
		dots = P.Fuse,
		dotsT = 0.9,
		glow = P.Fuse,
		glowT = 0.55,
	})
	local holder = face.Parent :: Frame
	holder.ZIndex = 5
	local v = Screen.size()
	new("UIScale", { Scale = math.min(1, (v.Y - 50) / 340, (v.X - 30) / 700), Parent = holder })
	Theme.display(face, {
		Text = S.RulesTitle,
		TextSize = 34,
		color = P.Spark,
		Position = UDim2.new(0.5, 0, 0, 30),
		ZIndex = 6,
	})
	local row = new("Frame", {
		Position = UDim2.fromOffset(20, 58),
		Size = UDim2.new(1, -40, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = face,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for i, rule in ipairs(S.Rules) do
		local card = Theme.panel(row, {
			Name = "Rule" .. i,
			Size = UDim2.fromOffset(152, 200),
			color = Color3.fromRGB(44, 34, 56),
			border = P.Paper,
			border2 = P.Ash,
		});
		(card.Parent :: Frame).LayoutOrder = i
		local num = new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = P.Fuse,
			ZIndex = 6,
			Parent = card,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = num })
		new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = num })
		Widgets.label(num, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 16,
			font = Theme.Font.Display,
			Text = tostring(i),
			ZIndex = 7,
		})
		local stage = new("Frame", {
			Name = "Stage",
			Position = UDim2.fromOffset(8, 30),
			Size = UDim2.new(1, -16, 0, 96),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 5,
			Parent = card,
		})
		illustrate(stage, i)
		Widgets.label(card, {
			Position = UDim2.fromOffset(6, 128),
			Size = UDim2.new(1, -12, 0, 24),
			TextSize = 15,
			font = Theme.Font.Display,
			color = P.Spark,
			Text = rule.head,
			ZIndex = 6,
		})
		Widgets.label(card, {
			Position = UDim2.fromOffset(8, 152),
			Size = UDim2.new(1, -16, 0, 42),
			TextSize = 14,
			font = Theme.Font.Bold,
			wrap = true,
			Text = rule.body,
			ZIndex = 6,
			stroke = 1.5,
		})
	end
	Widgets.button(face, S.Ui.GotIt, "fuse", UDim2.fromOffset(200, 50), function()
		Progress.action("RulesSeen")
		Widgets.springOut(holder, function()
			for _, c in ipairs(gui:GetChildren()) do
				c:Destroy()
			end
			rulesOpen = false
			Modal.set("Rules", false)
		end)
	end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), TextSize = 26, ZIndex = 7 })
	Widgets.springIn(holder)
end

-- ── Contextual tips (once each) ─────────────────────────────────────────────────────────────────────────────────
local tipLayer: Frame
local function tip(id: string, text: string)
	local s = Progress.get()
	local flags = s and s.daily and s.daily.flags
	if tipsShown[id] or not flags or (flags.tips and flags.tips[id]) then
		return
	end
	if Settings.get("showTips") == false then
		return
	end
	tipsShown[id] = true
	Progress.action("Tip", { id = id })
	local label = Theme.display(tipLayer, {
		Text = text,
		TextSize = 36,
		color = P.Paper,
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 5,
	})
	label.TextWrapped = true
	Widgets.springIn(label, 0.7)
	task.delay(2.5, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		task.delay(0.4, function()
			label:Destroy()
		end)
	end)
end

-- ── The quest intro (F-ONB-06) ──────────────────────────────────────────────────────────────────────────────────
local function questIntro()
	if introShown then
		return
	end
	introShown = true
	Progress.action("QuestsIntro")
	local toast = Theme.panel(gui, {
		Name = "QuestIntro",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 280, 0.4, 0),
		Size = UDim2.fromOffset(280, 64),
		color = P.Ink2,
		border = P.Spark,
		border2 = P.Gold,
		glow = P.Spark,
		glowT = 0.6,
	})
	local holder = toast.Parent :: Frame
	Widgets.icon(toast, "Scroll", 44, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		ZIndex = 5,
	})
	Widgets.label(toast, {
		Position = UDim2.fromOffset(58, 6),
		Size = UDim2.new(1, -150, 1, -12),
		TextSize = 16,
		wrap = true,
		align = Enum.TextXAlignment.Left,
		Text = S.Tips.QuestsIntro,
		ZIndex = 5,
	})
	Widgets.button(toast, "VIEW", "gold", UDim2.fromOffset(80, 38), function()
		DailyController.open("Quests")
		holder:Destroy()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextSize = 18, ZIndex = 6 })
	Widgets.springIn(holder)
	task.delay(8, function()
		if holder.Parent then
			Widgets.springOut(holder, function()
				holder:Destroy()
			end)
		end
	end)
end

function OnboardingController.start()
	Progress.start()
	gui = new("ScreenGui", {
		Name = "FV_Onboarding",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local tipGui = new("ScreenGui", {
		Name = "FV_Tips",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	tipLayer = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 60),
		BackgroundTransparency = 1,
		Parent = tipGui,
	})
	local function onProgress(s: { [string]: any })
		local d = s.daily
		if not d or not d.flags then
			return
		end
		if not d.flags.tutorial and not rulesOpen then
			OnboardingController.showRules()
		end
		if not d.flags.questsIntro and (s.rounds or 0) >= 2 and ClientState.phase() ~= Ph.Crossing then
			questIntro()
		end
	end
	Progress.Changed:Connect(onProgress)
	local s = Progress.get()
	if s then
		onProgress(s)
	end
	-- tips
	player:GetAttributeChangedSignal("BombId"):Connect(function()
		if player:GetAttribute("BombId") ~= nil then
			tip("FirstCarry", S.Tips.FirstCarry)
		end
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") == Types.Role.Bomber then
			tip("FirstBomber", S.Tips.FirstBomber)
		end
	end)
	Net.listen("FieldFx", function(p)
		if type(p) == "table" and p.kind == "Warn" then
			tip("FirstFieldWarn", S.Tips.FirstFieldWarn)
		end
	end)
end

return OnboardingController
