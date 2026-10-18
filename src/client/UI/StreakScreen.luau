--!strict
-- The Daily Streak screen's content (Asset Bible §7.5; the owner, 2026-10-18: "super clicky, super animated, super glowy
-- and colourful"). DailyController builds the panel frame and calls StreakScreen.build with its content face.
--   • a streak meter: a flame, "N DAY STREAK", seven fuse segments filling toward the Day 7 reward;
--   • seven day cards in a rainbow run (green → cyan → blue → violet → pink → orange → the big gold Day 7), each with
--     its 3D reward icon bobbing on its own beat;
--   • today's card is the star: a rainbow rim that turns, a light sweep across it, slow rays behind, a bouncing TODAY!
--     tag — and tapping it claims;
--   • the Day 7 card always has its own gold rays and sparkles (the big reward);
--   • every card is clicky: it lifts and tilts on hover, squishes on press, and a tap on a card that isn't claimable
--     wiggles it and names the reward;
--   • claimed days sink under a green check and a CLAIMED stamp; the next one counts down to the daily reset;
--   • the cards cascade in when the screen opens (not on a live refresh), and a claim pops confetti off the card.
-- Implements: F-DAILY-02..04 (presentation), F-UI-04 (Daily Calendar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local D = Config.Daily
local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local rgb = Color3.fromRGB

local StreakScreen = {}

-- the rainbow run of day colours (top, bottom), Day 7 last
local DAY_COLORS = {
	{ rgb(130, 236, 110), rgb(40, 168, 62) },
	{ rgb(110, 232, 240), rgb(20, 156, 200) },
	{ rgb(110, 176, 255), rgb(40, 96, 226) },
	{ rgb(196, 140, 255), rgb(124, 62, 226) },
	{ rgb(255, 140, 220), rgb(214, 56, 162) },
	{ rgb(255, 178, 90), rgb(232, 104, 26) },
	{ rgb(255, 230, 110), rgb(236, 150, 20) },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 90, 90)),
	ColorSequenceKeypoint.new(0.2, rgb(255, 196, 60)),
	ColorSequenceKeypoint.new(0.4, rgb(120, 236, 110)),
	ColorSequenceKeypoint.new(0.6, rgb(80, 200, 255)),
	ColorSequenceKeypoint.new(0.8, rgb(196, 120, 255)),
	ColorSequenceKeypoint.new(1, rgb(255, 90, 90)),
})
local REWARD_ICON =
	{ Stars = "Star", SparkCrate = "Crate", GiftBox = "GiftBox", RareItem = "Gift", StreakBomb = "Bomb" }
local CARD = Vector2.new(84, 150)
local BIG = Vector2.new(124, 182)
local GAP = 8
local CASCADE = 0.06 -- seconds between cards dropping in
local HOVER_LIFT = 8

export type Ctx = {
	refresh: boolean?, -- a live refresh: no entrance cascade
	onClaim: () -> (),
}

local function rewardIndex(day: number): number
	local n = #D.LOGIN
	if day <= n then
		return math.max(1, day)
	end
	local span = n - D.LOOP_FROM + 1
	return D.LOOP_FROM + (day - n - 1) % span
end

local function rewardText(r: { [string]: any }): string
	if r.kind == "Stars" then
		return tostring(r.amount)
	end
	return (S.Rewards :: any)[r.kind] or r.kind
end

local function rewardLong(r: { [string]: any }): string
	if r.kind == "Stars" then
		return string.format(S.Rewards.Stars, r.amount)
	end
	return (S.Rewards :: any)[r.kind] or r.kind
end

-- A small sunburst (12 soft rays) sized to `size`, turning slowly; returns the holder.
local function sunburst(parent: Instance, color: Color3, size: number, z: number, alpha: number): Frame
	local holder = new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	for i = 1, 12 do
		local arm = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.13, 0, 1, 0),
			Rotation = i * 30,
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = holder,
		})
		local ray = new("Frame", {
			Size = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = alpha,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = arm,
		})
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.7, 0.4),
				NumberSequenceKeypoint.new(1, 0.2),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	return holder
end

-- A rounded fill with a vertical gradient (the card's body).
local function body(parent: Instance, size: Vector2, top: Color3, bottom: Color3, z: number): Frame
	local f = new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = f })
	new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90, Parent = f })
	return f
end

local function confetti(parent: Instance, at: UDim2, count: number)
	for _ = 1, count do
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Size = UDim2.fromOffset(math.random(7, 11), math.random(4, 7)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = Color3.fromHSV(math.random(), 0.7, 1),
			BorderSizePixel = 0,
			ZIndex = 40,
			Parent = parent,
		})
		local a = math.rad(math.random(200, 340))
		local d = 80 + math.random() * 140
		TweenService:Create(f, TweenInfo.new(0.8 + math.random() * 0.4, Enum.EasingStyle.Quad), {
			Position = at + UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d + 120),
			Rotation = f.Rotation + 360,
			BackgroundTransparency = 1,
		}):Play()
		task.delay(1.3, function()
			f:Destroy()
		end)
	end
end

function StreakScreen.build(face: Frame, s: { [string]: any }, ctx: Ctx)
	local d = s.daily
	local login = d.login
	local day = login.day
	local idx = rewardIndex(day)
	local first = if day <= #D.LOGIN then 1 else day - (idx - D.LOOP_FROM) - (D.LOOP_FROM - 1)
	local alive = true
	face.Destroying:Connect(function()
		alive = false
	end)
	local animators: { (number) -> () } = {} -- per-frame idle motion, run while the screen is open

	-- ── the streak meter ──
	local meter = new("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(560, 40),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = face,
	})
	local flame = Widgets.icon(meter, "Flame", 44, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, -2),
		ZIndex = 6,
	})
	local streak = math.max(0, login.streakDay or 0)
	Widgets.label(meter, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(200, 32),
		TextSize = 24,
		font = Theme.Font.Display,
		stroke = 2.5,
		color = if login.missed then P.Ember else Color3.new(1, 1, 1),
		align = Enum.TextXAlignment.Left,
		Text = if login.missed
			then string.format(S.Ui.CalendarMissed, D.STREAK_MISS_PENALTY)
			elseif streak <= 0 then S.Ui.StreakStart
			else string.format(S.Ui.StreakDays, streak),
		ZIndex = 6,
	})
	-- seven fuse segments toward Day 7
	local segs = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(250, 16),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = meter,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = segs,
	})
	local within = ((day - first) % 7) + (if login.claimable then 0 else 1)
	for i = 1, 7 do
		local lit = i <= within
		local seg = new("Frame", {
			Size = UDim2.fromOffset(32, if i == 7 then 16 else 12),
			BackgroundColor3 = if lit then Color3.new(1, 1, 1) else rgb(40, 36, 54),
			ZIndex = 5,
			Parent = segs,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = seg })
		new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = seg })
		if lit then
			new("UIGradient", { Color = ColorSequence.new(rgb(255, 214, 80), rgb(255, 120, 40)), Parent = seg })
		end
	end
	if not Widgets.reduced() then
		table.insert(animators, function(t: number)
			local holder = flame.Parent :: Frame
			holder.Rotation = math.sin(t * 6) * 6
			local sc = holder:FindFirstChild("Live") :: UIScale? or new("UIScale", { Name = "Live", Parent = holder })
			if sc then
				sc.Scale = 1 + math.sin(t * 11) * 0.05
			end
		end)
	end

	-- ── the cards ──
	local row = new("Frame", {
		Name = "Days",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.new(1, -24, 0, BIG.Y + 34),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = face,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local tip: TextLabel? = nil
	local todayCard: Frame? = nil
	for k = 0, 6 do
		local n = first + k
		local ri = rewardIndex(n)
		local reward = D.LOGIN[ri]
		local big = ri == #D.LOGIN
		local isToday = n == day
		local claimable = isToday and login.claimable
		local claimed = n < day or (isToday and not login.claimable)
		local size = if big then BIG else CARD
		local cols = DAY_COLORS[ri] or DAY_COLORS[1]
		-- the slot keeps the layout still while the card inside lifts, tilts and squishes
		local slot = new("Frame", {
			Name = "Day" .. n,
			Size = UDim2.fromOffset(size.X, size.Y + 30),
			BackgroundTransparency = 1,
			LayoutOrder = k,
			ZIndex = 3,
			Parent = row,
		})
		local card = new("Frame", {
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = slot,
		})
		local scale = new("UIScale", { Parent = card })
		if claimable or big then
			-- rays behind the special cards
			local rays = sunburst(card, if big then rgb(255, 214, 80) else Color3.new(1, 1, 1), size.X * 2.1, 3, 0.55)
			rays.Position = UDim2.fromScale(0.5, 0.45)
			table.insert(animators, function(t: number)
				rays.Rotation = t * (if big then 14 else 22)
			end)
		end
		if claimable then
			-- a soft white halo pulsing behind today's card
			local halo = new("Frame", {
				Name = "Halo",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 8),
				Size = UDim2.fromOffset(size.X + 16, size.Y + 16),
				BackgroundColor3 = rgb(255, 250, 200),
				BackgroundTransparency = 0.5,
				ZIndex = 4,
				Parent = card,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 20), Parent = halo })
			table.insert(animators, function(t: number)
				local a = (math.sin(t * 4) + 1) / 2
				halo.BackgroundTransparency = 0.45 + a * 0.35
				halo.Size = UDim2.fromOffset(size.X + 12 + a * 10, size.Y + 12 + a * 10)
			end)
		end
		local fill = body(card, size, cols[1], cols[2], 5)
		-- the rim: white, a turning rainbow for today, gold for Day 7
		local rim = new("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = if claimable then 5 else 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = fill,
		})
		if claimable then
			local g = new("UIGradient", { Color = RAINBOW, Parent = rim }) :: UIGradient
			table.insert(animators, function(t: number)
				g.Rotation = (t * 120) % 360
			end)
		elseif big then
			rim.Color = rgb(255, 236, 140)
		end
		new("UIStroke", { -- the ink outline outside the rim
			Name = "Ink",
			Color = P.Ink,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = fill,
		})
		-- the gloss band across the top
		local gloss = new("Frame", {
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(1, -12, 0.32, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.78,
			ZIndex = 6,
			Parent = fill,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = gloss })
		-- a light sweep across today / Day 7
		if (claimable or big) and not Widgets.reduced() then
			local sweep = new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 9,
				Parent = fill,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = sweep })
			local sg = new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.42, 1),
					NumberSequenceKeypoint.new(0.5, 0.55),
					NumberSequenceKeypoint.new(0.58, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 20,
				Parent = sweep,
			}) :: UIGradient
			local phase = k * 0.37
			table.insert(animators, function(t: number)
				local c = ((t + phase) % 2.4) / 2.4 -- one sweep every 2.4 s
				sg.Offset = Vector2.new(-1.2 + c * 2.6, 0)
			end)
		end
		-- the day number on a dark pill
		local pill = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(if big then 76 else 62, 24),
			BackgroundColor3 = rgb(30, 26, 42),
			ZIndex = 8,
			Parent = fill,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = pill })
		Widgets.label(pill, {
			Size = UDim2.fromScale(1, 1),
			TextSize = if big then 18 else 15,
			font = Theme.Font.Display,
			stroke = false,
			Text = string.format(S.Ui.CalendarDay, n),
			ZIndex = 9,
		})
		-- the reward icon, bobbing on its own beat
		local iconSize = if big then 86 else 58
		local icon = Widgets.icon(fill, REWARD_ICON[reward.kind] or "Star", iconSize, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			ZIndex = 8,
		})
		local iconHolder = icon.Parent :: Frame
		if not Widgets.reduced() and not claimed then
			local beat = k * 0.7
			table.insert(animators, function(t: number)
				iconHolder.Position = UDim2.new(0.5, 0, 0.46, math.sin(t * 2.6 + beat) * 3)
				iconHolder.Rotation = math.sin(t * 1.9 + beat) * 6
			end)
		end
		Widgets.label(fill, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -6, 0, 30),
			TextSize = if reward.kind == "Stars" then (if big then 28 else 22) else 14,
			font = Theme.Font.Display,
			wrap = true,
			stroke = 2.5,
			Text = rewardText(reward),
			ZIndex = 8,
		})
		if big then
			-- sparkles round the big reward
			for i = 1, 4 do
				local sp = Widgets.icon(fill, "Star", 18, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(if i % 2 == 0 then 0.18 else 0.84, if i <= 2 then 0.2 else 0.66),
					ZIndex = 10,
				})
				local h = sp.Parent :: Frame
				table.insert(animators, function(t: number)
					local a = (math.sin(t * 3 + i * 1.7) + 1) / 2
					sp.ImageTransparency = 1 - a
					h.Rotation = t * 60 + i * 40
				end)
			end
		end
		if claimable then
			-- the bouncing TODAY! tag over the card
			local tag = Widgets.label(slot, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -size.Y - 14),
				Size = UDim2.fromOffset(96, 24),
				TextSize = 20,
				font = Theme.Font.Display,
				stroke = 3,
				color = rgb(255, 230, 90),
				Text = S.Ui.Today,
				ZIndex = 12,
			})
			table.insert(animators, function(t: number)
				tag.Position = UDim2.new(0.5, 0, 1, -size.Y - 14 - math.abs(math.sin(t * 4)) * 8)
			end)
			todayCard = card
		end
		if claimed then
			local dim = new("Frame", {
				Name = "Dim",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = P.Ink,
				BackgroundTransparency = 0.4,
				ZIndex = 11,
				Parent = fill,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = dim })
			Widgets.icon(fill, "Check", 46, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.42),
				ZIndex = 12,
			})
			local stamp = Widgets.label(fill, {
				Name = "Stamp",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.7),
				Size = UDim2.new(1, 6, 0, 26),
				TextSize = 18,
				font = Theme.Font.Display,
				stroke = 3,
				color = P.Safe,
				Text = S.Ui.Claimed,
				ZIndex = 12,
			})
			stamp.Rotation = -12
		end
		-- clicky: hover lifts and tilts, press squishes, a tap claims (today) or wiggles and names the reward
		local hit = new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 20,
			Parent = slot,
		}) :: TextButton
		local function lift(on: boolean)
			TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 1, if on then -HOVER_LIFT else 0),
				Rotation = if on then (if k % 2 == 0 then -3 else 3) else 0,
			}):Play()
		end
		hit.MouseEnter:Connect(function()
			lift(true)
			Sfx.play("UiHover", 0.6)
		end)
		hit.MouseLeave:Connect(function()
			lift(false)
			scale.Scale = 1
		end)
		hit.MouseButton1Down:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
		end)
		hit.MouseButton1Up:Connect(function()
			TweenService
				:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end)
		hit.Activated:Connect(function()
			if claimable then
				ctx.onClaim()
				return
			end
			Sfx.play("UiTab", 0.8, 1.1)
			for i, r in ipairs({ -8, 8, -5, 3, 0 }) do
				task.delay(i * 0.04, function()
					card.Rotation = r
				end)
			end
			if tip then
				tip:Destroy()
			end
			local t = Widgets.label(face, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 92 + BIG.Y + 34),
				Size = UDim2.fromOffset(420, 26),
				TextSize = 20,
				font = Theme.Font.Display,
				stroke = 2.5,
				color = rgb(255, 230, 120),
				Text = ("%s · %s"):format(string.format(S.Ui.CalendarDay, n), rewardLong(reward))
					.. (if claimed then " · " .. S.Ui.Claimed else ""),
				ZIndex = 14,
			})
			tip = t
			task.delay(1.8, function()
				if tip == t then
					t:Destroy()
					tip = nil
				end
			end)
		end)
		-- the cascade in
		if not ctx.refresh and not Widgets.reduced() then
			card.Position = UDim2.new(0.5, 0, 1, -60)
			scale.Scale = 0.3
			local cardRef = card
			task.delay(k * CASCADE, function()
				if not alive then
					return
				end
				TweenService:Create(
					cardRef,
					TweenInfo.new(0.42, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
					{ Position = UDim2.fromScale(0.5, 1) }
				):Play()
				TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
				Sfx.play("UiTab", 0.35, 0.9 + k * 0.06)
			end)
		end
	end

	-- ── the CLAIM button / the countdown ──
	if login.claimable then
		local b = Widgets.button(face, S.Ui.Claim, "green", UDim2.fromOffset(220, 56), ctx.onClaim, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			TextSize = 28,
			ZIndex = 8,
		})
		Widgets.pulse(b)
		if not Widgets.reduced() then
			local sweep = new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 9,
				Parent = b,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = sweep })
			local sg = new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.42, 1),
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(0.58, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 20,
				Parent = sweep,
			}) :: UIGradient
			table.insert(animators, function(t: number)
				sg.Offset = Vector2.new(-1.2 + ((t % 1.8) / 1.8) * 2.6, 0)
			end)
		end
	else
		local next = Widgets.label(face, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -22),
			Size = UDim2.fromOffset(420, 30),
			TextSize = 22,
			font = Theme.Font.Display,
			stroke = 2.5,
			color = rgb(180, 220, 255),
			Text = "",
			ZIndex = 8,
		})
		local last = -1
		table.insert(animators, function()
			local left = math.max(0, (d.resetIn or 0) - Progress.age())
			local whole = math.floor(left)
			if whole ~= last then
				last = whole
				next.Text = string.format(S.Ui.NextRewardIn, Widgets.clock(left))
			end
		end)
	end

	-- run the idle motion while the screen is up
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not alive or not face.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		for _, f in ipairs(animators) do
			f(t)
		end
	end)

	-- the confetti pop off today's card (DailyController calls this on the claim's reward)
	return function()
		if todayCard and todayCard.Parent then
			local at = todayCard.AbsolutePosition + todayCard.AbsoluteSize / 2 - face.AbsolutePosition
			confetti(face, UDim2.fromOffset(at.X, at.Y), 36)
		end
	end
end

return StreakScreen
