--!strict
-- The level-up celebration (GDD §12.3, Asset Bible §7.3): the screen dims, the level badge smashes in (scale 3 → 1)
-- with a shockwave ring and a firework burst of stars, LEVEL UP! drops above it, and the reward card flips in and
-- pays its Stars into the counter. Level-ups are queued and wait for a calm moment (never mid-crossing); several
-- in a row play one after another. Tap to continue.
-- Implements: F-PROG-03 (celebration), F-UI-04 (Level Up).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Modal = require(script.Parent.Parent.UI.Modal)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ProgressController = require(script.Parent.ProgressController)

local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local Ph = Types.Phase
local player = Players.LocalPlayer

local LevelUpController = {}

type Up = { level: number, stars: number, badge: string }
local queue: { Up } = {}
local playing = false
local gui: ScreenGui

local function calm(): boolean
	local ph = ClientState.phase()
	return ph ~= Ph.Crossing and ph ~= Ph.LastStand and ph ~= Ph.Ready and ph ~= Ph.Intro
end

local function burst(parent: Instance)
	-- the shockwave ring
	local ring = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Image = Assets.Vfx.Ring,
		ImageColor3 = P.Spark,
		ZIndex = 3,
		Parent = parent,
	})
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(520, 520),
		ImageTransparency = 1,
	}):Play()
	-- the flash
	local flash = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		BackgroundTransparency = 1,
		Image = Assets.Vfx.Flash,
		ImageColor3 = Color3.new(1, 0.95, 0.8),
		ZIndex = 4,
		Parent = parent,
	})
	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.fromOffset(420, 420),
		ImageTransparency = 1,
		Rotation = 30,
	}):Play()
	-- a firework of stars
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + math.random() * 0.3
		local dist = 160 + math.random() * 120
		local star = Widgets.icon(parent, "Star", 26 + math.random(0, 14), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 5,
		})
		local holder = star.Parent :: Frame
		TweenService:Create(holder, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(a) * dist, 0.5, math.sin(a) * dist),
			Rotation = math.random(-180, 180),
		}):Play()
		task.delay(0.45, function()
			for _, img in ipairs(holder:GetChildren()) do
				if img:IsA("ImageLabel") then
					TweenService:Create(img, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
				end
			end
		end)
	end
end

local function play(up: Up)
	playing = true
	Modal.set("LevelUp", true)
	for _, c in ipairs(gui:GetChildren()) do
		c:Destroy()
	end
	local back = Widgets.backdrop(gui, 0.3)
	local stage = new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(520, 420),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = gui,
	})
	Sfx.play("LevelUp")
	burst(stage)
	-- the badge smashes in
	local badge = Widgets.icon(stage, "Badge", 170, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		tint = ProgressController.BADGE_TINT[up.badge] or ProgressController.BADGE_TINT.Bronze,
		ZIndex = 6,
	})
	local badgeHolder = badge.Parent :: Frame
	Widgets.label(badgeHolder, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 72,
		font = Theme.Font.Display,
		Text = tostring(up.level),
		stroke = 4,
		ZIndex = 8,
	})
	local smash = new("UIScale", { Scale = if Widgets.reduced() then 1 else 3, Parent = badgeHolder })
	TweenService:Create(smash, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local title = Theme.display(stage, {
		Text = S.Ui.LevelUp,
		TextSize = 58,
		color = P.Spark,
		Position = UDim2.fromScale(0.5, 0.1),
		ZIndex = 7,
	})
	local tScale = new("UIScale", { Scale = 0.6, Parent = title })
	TweenService:Create(tScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	-- the reward card flips in
	task.delay(0.45, function()
		if stage.Parent == nil then
			return
		end
		local card = Theme.panel(stage, {
			Name = "Reward",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromOffset(230, 70),
			color = P.Ink2,
			border = P.Spark,
			border2 = P.Gold,
			glow = P.Spark,
			glowT = 0.5,
		})
		local holder = card.Parent :: Frame
		holder.ZIndex = 6
		local starImg = Widgets.icon(card, "Star", 52, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			ZIndex = 8,
		})
		Widgets.label(card, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 74, 0.5, 0),
			Size = UDim2.new(1, -86, 1, 0),
			TextSize = 30,
			font = Theme.Font.Display,
			color = P.Spark,
			align = Enum.TextXAlignment.Left,
			Text = string.format(S.Ui.LevelReward, up.stars),
			ZIndex = 8,
		})
		-- the flip: the card's width springs open from a sliver
		local full = holder.Size
		holder.Size = UDim2.fromOffset(4, 70)
		TweenService
			:Create(holder, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full })
			:Play()
		task.delay(0.5, function()
			if starImg.Parent then
				ProgressController.fly(starImg.AbsolutePosition + starImg.AbsoluteSize / 2, up.stars)
			end
		end)
	end)
	-- leave: a tap (after a beat) or on its own
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		Widgets.springOut(stage, function()
			for _, c in ipairs(gui:GetChildren()) do
				c:Destroy()
			end
			playing = false
			Modal.set("LevelUp", false)
		end)
	end
	task.delay(1.2, function()
		back.MouseButton1Click:Connect(finish)
	end)
	task.delay(3.8, finish)
end

function LevelUpController.start()
	gui = new("ScreenGui", {
		Name = "FV_LevelUp",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.listen("Reward", function(r)
		if type(r) == "table" and r.kind == "LevelUp" and type(r.level) == "number" then
			table.insert(queue, { level = r.level, stars = r.stars or 0, badge = r.badge or "Bronze" })
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			if not playing and #queue > 0 and calm() and not Modal.busy() then
				-- on the results screen, let the receipt print first
				if ClientState.phase() == Ph.Results then
					task.wait(3.2)
				end
				local up = table.remove(queue, 1)
				if up then
					play(up)
				end
			end
		end
	end)
end

return LevelUpController
