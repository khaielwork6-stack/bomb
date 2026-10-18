--!strict
-- The lobby HUD's progression corner (GDD §21.2 F-UI-03, Asset Bible §6.6): the Stars counter (top-right — in
-- Roblox's top bar row on phones, the Chase Game lesson), the level badge (tinted by tier, the level inside) with
-- its XP bar, and the Hot Streak flame with its multiplier on a brass tag. Numbers count up; rewards fly into the
-- counter as stars (ProgressController.fly). Shown in the lobby phases; it slides out of the way during a round,
-- where the top-right belongs to the team counter.
-- Implements: F-UI-03, F-SOC-01 (flame), Asset Bible §6.5 (reward pop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local P = Theme.Palette
local new = Theme.new
local Ph = Types.Phase
local player = Players.LocalPlayer

local ProgressController = {}

local BADGE_TINT = {
	Bronze = Color3.fromRGB(214, 140, 82),
	Silver = Color3.fromRGB(206, 214, 226),
	Gold = Color3.fromRGB(255, 204, 72),
	Platinum = Color3.fromRGB(150, 236, 236),
	Obsidian = Color3.fromRGB(150, 110, 210),
}
ProgressController.BADGE_TINT = BADGE_TINT

local gui: ScreenGui
local corner: Frame -- everything in the corner (slides as one)
local starsPill: Frame
local starsIcon: ImageLabel
local starsLabel: TextLabel
local badgeImg: ImageLabel
local levelLabel: TextLabel
local setXp: (number, boolean?) -> ()
local xpLabel: TextLabel
local flameHolder: Frame
local flameImg: ImageLabel
local multTag: Frame
local multLabel: TextLabel
local shown = true
local displayedStars = 0
local holdStars = 0 -- Stars still in flight (the counter waits for them to land)

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function lobbyPhase(): boolean
	local ph = ClientState.phase()
	return ph == Ph.Intermission or ph == Ph.Results or ph == Ph.Boot or ph == ""
end

local function fmtStars(n: number): string
	local s = tostring(n)
	-- 12,345
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ── Build ───────────────────────────────────────────────────────────────────────────────────────────────────────
local function build()
	gui = new("ScreenGui", {
		Name = "FV_Progress",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	corner = new("Frame", {
		Name = "Corner",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(230, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- The wallet (the reference video's bottom-left cash readout): a big 3D Star and the count in large round type
	-- with a gold gradient and a thick ink stroke. Always on screen; rewards fly into it.
	starsPill = new("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(320, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	starsIcon = Widgets.icon(starsPill, "Star", 64, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		ZIndex = 4,
	})
	starsLabel = Widgets.label(starsPill, {
		Name = "Count",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 72, 0.5, 2),
		Size = UDim2.new(1, -72, 1, 0),
		TextSize = 56,
		font = Theme.Font.Display,
		color = Color3.new(1, 1, 1),
		align = Enum.TextXAlignment.Left,
		Text = "0",
		stroke = 4,
		ZIndex = 5,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 238, 120), Color3.fromRGB(255, 170, 24)),
		Rotation = 90,
		Parent = starsLabel,
	})
	-- Level badge + XP bar
	local row = new("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(200, 44),
		BackgroundTransparency = 1,
		Parent = corner,
	})
	badgeImg = Widgets.icon(row, "Badge", 46, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		tint = BADGE_TINT.Bronze,
		ZIndex = 4,
	})
	levelLabel = Widgets.label(badgeImg.Parent :: Frame, {
		Name = "Level",
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		font = Theme.Font.Display,
		Text = "1",
		ZIndex = 6,
	})
	local _, set = Widgets.bar(
		row,
		UDim2.fromOffset(140, 14),
		P.Runner,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 4) }
	)
	setXp = set
	xpLabel = Widgets.label(row, {
		Name = "Xp",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -52, 0.5, -4),
		Size = UDim2.fromOffset(140, 16),
		TextSize = 13,
		color = P.Paper,
		align = Enum.TextXAlignment.Right,
		Text = "0 / 150 XP",
		stroke = 1.5,
	})
	-- Hot Streak flame (left of the Stars pill)
	flameHolder = new("Frame", {
		Name = "Streak",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -206, 0, -2),
		Size = UDim2.fromOffset(44, 48),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = corner,
	})
	flameImg = Widgets.icon(flameHolder, "Flame", 44, { Position = UDim2.fromOffset(0, 0), ZIndex = 4 })
	multTag = new("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(46, 18),
		BackgroundColor3 = P.Brass,
		ZIndex = 6,
		Parent = flameHolder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = multTag })
	new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = multTag })
	multLabel = Widgets.label(multTag, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		color = P.Ink,
		stroke = false,
		Text = "x1.25",
		ZIndex = 7,
	})
end

-- ── Place (phones: the Stars pill rides in the top bar row) ─────────────────────────────────────────────────────
-- The wallet: bottom-left; on phones under the top bar (the thumbstick owns the bottom-left there).
local function placeWallet()
	local tb = Screen.topbar()
	local safe = Screen.safe()
	local fit = starsPill:FindFirstChild("Fit") :: UIScale?
	if not fit then
		fit = new("UIScale", { Name = "Fit", Parent = starsPill })
	end
	if touch() then
		starsPill.AnchorPoint = Vector2.new(0, 0)
		starsPill.Position = UDim2.new(0, 16 + safe.left, 0, tb.Max.Y + 6);
		(fit :: UIScale).Scale = 0.62
	else
		starsPill.AnchorPoint = Vector2.new(0, 1)
		starsPill.Position = UDim2.new(0, 22 + safe.left, 1, -18 - safe.bottom);
		(fit :: UIScale).Scale = 1
	end
end

local function place()
	placeWallet()
	local tb = Screen.topbar()
	local safe = Screen.safe()
	local x = if shown then -12 - safe.right else 260
	if touch() then
		corner.Position = UDim2.new(1, x, 0, tb.Min.Y + math.max(0, (tb.Height - 40) / 2))
	else
		corner.Position = UDim2.new(1, x - 6, 0, tb.Max.Y + 12)
	end
end

local function setShown(on: boolean)
	if on == shown then
		return
	end
	shown = on
	local tb = Screen.topbar()
	local safe = Screen.safe()
	local x = if on then -12 - safe.right else 260
	local y = if touch() then tb.Min.Y + math.max(0, (tb.Height - 40) / 2) else tb.Max.Y + 12
	local goal = UDim2.new(1, if touch() then x else x - 6, 0, y)
	if Widgets.reduced() then
		corner.Position = goal
	else
		TweenService
			:Create(corner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = goal })
			:Play()
	end
end

-- ── Apply a snapshot ────────────────────────────────────────────────────────────────────────────────────────────
local lastLevel = 0
local lastStreak = -1
local function apply(s: { [string]: any })
	-- Stars: count to the new total unless rewards are still flying in
	local target = (s.stars or 0) - holdStars
	if target ~= displayedStars then
		local from = displayedStars
		displayedStars = target
		Widgets.countUp(starsLabel, from, target, fmtStars, target > from and (target - from) >= 10)
	end
	-- Level + XP
	local level = s.level or 1
	if level ~= lastLevel then
		lastLevel = level
		levelLabel.Text = tostring(level)
		badgeImg.ImageColor3 = BADGE_TINT[s.badge or "Bronze"] or BADGE_TINT.Bronze
	end
	setXp((s.xp or 0) / math.max(1, s.xpToNext or 1))
	xpLabel.Text = ("%d / %d XP"):format(s.xp or 0, s.xpToNext or 0)
	-- Hot Streak
	local streak = s.hotStreak or 0
	if streak ~= lastStreak then
		local grew = streak > lastStreak and lastStreak >= 0
		lastStreak = streak
		flameHolder.Visible = streak >= 1
		local size = math.clamp(32 + streak * 4, 32, 48)
		local f = flameImg.Parent :: Frame
		f.Size = UDim2.fromOffset(size, size)
		f.Position = UDim2.fromOffset((44 - size) / 2, 40 - size)
		multTag.Visible = (s.streakMult or 1) > 1
		multLabel.Text = "x" .. tostring(s.streakMult or 1)
		if grew and not Widgets.reduced() then
			local sc = f:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = f })
			sc.Scale = 1.4
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
	end
end

-- ── Reward pop: stars fly from a screen point into the counter (Asset Bible §6.5) ───────────────────────────────
function ProgressController.fly(from: Vector2, amount: number)
	if amount <= 0 then
		return
	end
	local count = math.clamp(math.floor(amount / 15) + 3, 3, 10)
	holdStars += amount
	local target = starsIcon.AbsolutePosition + starsIcon.AbsoluteSize / 2
	local landed = 0
	for i = 1, count do
		task.delay((i - 1) * 0.05, function()
			local img = Widgets.icon(gui, "Star", 30, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20 })
			local holder = img.Parent :: Frame
			local mid = (from + target) / 2 + Vector2.new(math.random(-120, 120), -math.random(80, 180))
			local t0 = os.clock()
			local dur = 0.55 + math.random() * 0.15
			while os.clock() - t0 < dur do
				local a = (os.clock() - t0) / dur
				local e = a * a * (3 - 2 * a)
				local p = from:Lerp(mid, e):Lerp(mid:Lerp(target, e), e) -- a quadratic bezier
				holder.Position = UDim2.fromOffset(p.X, p.Y)
				holder.Size = UDim2.fromOffset(30 - 10 * e, 30 - 10 * e)
				task.wait()
			end
			holder:Destroy()
			landed += 1
			Sfx.play("CoinTick")
			if landed == count then
				holdStars = math.max(0, holdStars - amount)
				local sc = starsPill:FindFirstChild("Punch") :: UIScale?
				if not sc then
					sc = new("UIScale", { Name = "Punch", Parent = starsPill })
				end
				(sc :: UIScale).Scale = 1.15
				TweenService:Create(sc :: UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				local s = Progress.get()
				if s then
					apply(s)
				end
			end
		end)
	end
end

-- Where a reward coming from the screen centre starts.
function ProgressController.centre(): Vector2
	local v = Screen.size()
	return Vector2.new(v.X / 2, v.Y / 2)
end

function ProgressController.start()
	Progress.start()
	build()
	place()
	Screen.Changed:Connect(place)
	Progress.Changed:Connect(apply)
	local s = Progress.get()
	if s then
		apply(s)
	end
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local function onPhase()
		setShown(lobbyPhase())
	end
	gs:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	shown = not lobbyPhase() -- force the first setShown to place it
	onPhase()
end

return ProgressController
