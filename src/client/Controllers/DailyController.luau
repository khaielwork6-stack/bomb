--!strict
-- The daily side of the lobby (GDD §14, §21.2 F-UI-03, §21.3; Asset Bible §6.6, §7.5): the right-side dock — the
-- gift ring (a segmented ring filling toward the next playtime gift, a countdown, a bouncing CLAIM), the Quests and
-- Calendar buttons — and the two screens they open: Quests (3 cards, live bars, reroll, the Daily Crate) and the
-- Daily Calendar (7 day cards, today pulsing, the CLAIMED stamp). Every claim is a tap the server validates; the
-- reward flies to the Stars counter. The calendar opens by itself on the first visit of the day.
-- Implements: F-DAILY-02..10 (presentation), F-UI-03, F-UI-04 (Quests, Daily Calendar).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Dock = require(script.Parent.Parent.UI.Dock)
local Screen = require(script.Parent.Parent.UI.Screen)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local Modal = require(script.Parent.Parent.UI.Modal)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local StreakScreen = require(script.Parent.Parent.UI.StreakScreen)
local ProgressController = require(script.Parent.ProgressController)

local D = Config.Daily
local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local Ph = Types.Phase
local player = Players.LocalPlayer

local DailyController = {}

local TIER_COLOR = { Easy = P.Safe, Medium = P.Spark, Hard = P.Bomber }
local TIER_FILL = {
	Easy = { Color3.fromRGB(120, 228, 110), Color3.fromRGB(44, 162, 60) },
	Medium = { Color3.fromRGB(255, 220, 96), Color3.fromRGB(236, 150, 24) },
	Hard = { Color3.fromRGB(255, 120, 110), Color3.fromRGB(206, 36, 48) },
}

local hud: ScreenGui
local modal: ScreenGui
local dock: Frame
local giftLabel: TextLabel
local giftButton: GuiButton
local setGiftRing: (number) -> () = function(_: number) end
local stopGiftPulse: (() -> ())? = nil
local questDot: Frame
local calendarDot: Frame
local stopCalPulse: (() -> ())? = nil
local calButton: GuiButton
local shown = true
local openPanel: Frame? = nil
local DOCK_GAP = 12 -- px between the dock's columns
local TWO_COLUMNS_BELOW = 0.6 -- a single-column dock scaled under this folds into two columns
local openName = ""
local autoCalendarDone = false

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function lobbyPhase(): boolean
	local ph = ClientState.phase()
	return ph == Ph.Intermission or ph == Ph.Results or ph == Ph.Boot or ph == ""
end

-- the dock shows between rounds, and all round for an AFK player (they sit in the lobby and need the AFK tile)
local function dockWanted(): boolean
	return lobbyPhase() or player:GetAttribute("Afk") == true
end

-- ── Panels (modal) ──────────────────────────────────────────────────────────────────────────────────────────────
local function closePanel()
	local p = openPanel
	if not p then
		return
	end
	openPanel, openName = nil, ""
	Modal.set("Daily", false)
	local holder = p.Parent :: Frame
	Widgets.springOut(holder, function()
		for _, c in ipairs(modal:GetChildren()) do
			c:Destroy()
		end
	end)
end
DailyController.close = closePanel

-- The screens' header art (the reference video): the title's 3D icon and the strip's colours.
local PANEL_ICON = { Shop = "Shop", Locker = "Items", Quests = "Scroll", Calendar = "Calendar", Settings = "Gear" }
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 96, 130)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 168, 64)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 96)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 226, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 176, 255)),
})
local HEADER = 74 -- the header strip's height
local headerSlot: Frame? = nil -- where a screen puts its tabs (DailyController.headerTabs)

-- A modal panel scaled to fit the screen, in the reference video's frame: a dark body outlined in ink, a gradient
-- header strip with the title in big round type and its 3D icon breaking out over the top-left corner, a red close
-- square at the strip's right end and a slot for tabs in between. Returns the content face (below the header).
local function panel(name: string, title: string, size: Vector2, accent: Color3, refresh: boolean?): Frame
	for _, c in ipairs(modal:GetChildren()) do
		c:Destroy()
	end
	local back = Widgets.backdrop(modal, 0.4)
	if refresh then
		back.BackgroundTransparency = 0.4 -- a live refresh: no fade, no spring
	end
	back.MouseButton1Click:Connect(closePanel)
	local total = Vector2.new(size.X, size.Y + HEADER - 40)
	local body = Theme.panel(modal, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(total.X, total.Y),
		color = Color3.fromRGB(46, 43, 54),
		color2 = Color3.fromRGB(28, 26, 34),
		border = Color3.fromRGB(20, 18, 26),
		border2 = Color3.fromRGB(20, 18, 26),
		bevelT = 0.95,
	})
	local holder = body.Parent :: Frame
	-- header strip
	local strip = new("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = body,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = strip })
	new("UIGradient", {
		Color = if name == "Shop"
			then RAINBOW
			else ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.25), accent:Lerp(P.Ink, 0.15)),
		Rotation = if name == "Shop" then 0 else 90,
		Parent = strip,
	})
	-- square off the strip's bottom corners and draw the ink line under it
	new("Frame", {
		Name = "Base",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = strip,
	}):SetAttribute("Base", true)
	local baseGrad = strip:FindFirstChildOfClass("UIGradient") :: UIGradient
	baseGrad:Clone().Parent = strip:FindFirstChild("Base")
	new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 2),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = P.Ink,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = strip,
	})
	local iconName = PANEL_ICON[name]
	local titleX = 22
	if iconName then
		Widgets.icon(holder, iconName, 112, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(34, 18),
			Rotation = -10,
			ZIndex = 12,
		})
		titleX = 92
	end
	Widgets.label(strip, {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, titleX, 0.5, -2),
		Size = UDim2.fromOffset(260, 60),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = title,
		TextSize = 50,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		stroke = 4,
		ZIndex = 6,
	})
	local slot = new("Frame", {
		Name = "Tabs",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -86, 0.5, -2),
		Size = UDim2.new(1, -titleX - 96 - math.min(260, 26 * #title + 20), 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = strip,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = slot,
	})
	headerSlot = slot
	-- the content area, below the header
	local face = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, HEADER - 34),
		Size = UDim2.new(1, 0, 1, -(HEADER - 34)),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = body,
	})
	holder.ZIndex = 5
	-- clicks inside the panel (previews, gaps) must not reach the backdrop and close it: an Active Frame doesn't
	-- stop a GuiButton underneath, so an invisible button behind the content takes them
	new("TextButton", {
		Name = "Sink",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 0,
		Parent = holder,
	})
	-- fit the screen, and keep fitting it (a phone turning, a window resized) while the panel is up
	Screen.fit(holder, function(v)
		return math.min(1, (v.Y - 70) / total.Y, (v.X - 60) / total.X)
	end)
	local close = Skin.close(holder, 60, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, HEADER / 2 - 2),
		ZIndex = 9,
	})
	close.Activated:Connect(function()
		Sfx.play("UiClose")
		closePanel()
	end)
	if not refresh then
		Widgets.springIn(holder)
		Sfx.play("UiOpen")
	end
	openPanel, openName = face, name
	Modal.set("Daily", true)
	return face
end

-- ── The Quests screen ───────────────────────────────────────────────────────────────────────────────────────────
local function questText(id: string, target: number): string
	local t = (S.Quests :: any)[id] or id
	return if string.find(t, "%%d") then string.format(t, target) else t
end

local function buildQuests(s: { [string]: any }, refresh: boolean?)
	local d = s.daily
	if not d then
		return
	end
	local face = panel("Quests", S.Ui.QuestsTitle, Vector2.new(560, 380), P.Spark, refresh)
	Widgets.label(face, {
		Name = "Reset",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.new(1, -40, 0, 20),
		TextSize = 14,
		color = P.Ash,
		Text = string.format(S.Ui.QuestsNew, Widgets.clock(d.resetIn - Progress.age())),
		ZIndex = 4,
	})
	local list = new("Frame", {
		Name = "List",
		Position = UDim2.fromOffset(22, 62),
		Size = UDim2.new(1, -44, 0, 236),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = face,
	})
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local freeLeft = d.rerolls < d.freeRerolls
	for i, q in ipairs(d.quests) do
		-- the reference's chance rows: a bright gradient row in the tier's colour, white border, ink outline
		local fill = TIER_FILL[q.tier] or TIER_FILL.Easy
		local card = Theme.panel(list, {
			Name = "Quest" .. i,
			Size = UDim2.new(1, 0, 0, 72),
			color = fill[1],
			color2 = fill[2],
			border = Color3.new(1, 1, 1),
			border2 = Color3.fromRGB(226, 230, 240),
			dots = Color3.new(1, 1, 1),
			dotsT = 0.85,
		});
		(card.Parent :: Frame).LayoutOrder = i
		local chip = new("Frame", {
			Name = "Tier",
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(84, 22),
			BackgroundColor3 = TIER_COLOR[q.tier] or P.Paper,
			ZIndex = 4,
			Parent = card,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = chip })
		new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = chip })
		Widgets.label(chip, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 13,
			color = P.Ink,
			stroke = false,
			Text = (S.Tiers :: any)[q.tier] or q.tier,
			ZIndex = 5,
		})
		Widgets.label(card, {
			Name = "Text",
			Position = UDim2.fromOffset(104, 6),
			Size = UDim2.new(1, -236, 0, 28),
			TextSize = 21,
			font = Theme.Font.Display,
			stroke = 2.5,
			align = Enum.TextXAlignment.Left,
			Text = questText(q.id, q.target),
			ZIndex = 4,
		})
		local _, setBar = Widgets.bar(card, UDim2.new(1, -236, 0, 14), TIER_COLOR[q.tier] or P.Paper, {
			Position = UDim2.fromOffset(104, 42),
			ZIndex = 4,
		})
		setBar(q.progress / math.max(1, q.target), true)
		Widgets.label(card, {
			Name = "Count",
			Position = UDim2.new(1, -128, 0, 38),
			Size = UDim2.fromOffset(48, 22),
			TextSize = 15,
			Text = ("%d/%d"):format(q.progress, q.target),
			ZIndex = 4,
		})
		-- the payout, under the tier chip
		local r = D.TIER_REWARD[q.tier]
		Widgets.icon(card, "Gem", 20, { Position = UDim2.fromOffset(12, 36), ZIndex = 5 })
		Widgets.label(card, {
			Position = UDim2.fromOffset(34, 36),
			Size = UDim2.fromOffset(56, 20),
			TextSize = 15,
			color = P.Spark,
			align = Enum.TextXAlignment.Left,
			Text = "+" .. tostring(r.stars),
			ZIndex = 5,
		})
		Widgets.label(card, {
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.fromOffset(80, 14),
			TextSize = 12,
			color = P.Runner,
			align = Enum.TextXAlignment.Left,
			Text = "+" .. tostring(r.xp) .. " XP",
			stroke = 1.5,
			ZIndex = 5,
		})
		local right = new("Frame", {
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(78, 56),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = card,
		})
		if q.done then
			Widgets.icon(right, "Check", 46, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 6,
			})
		else
			local cost = if freeLeft then S.Ui.RerollFree else tostring(d.rerollCost)
			local b, setOn = Widgets.button(right, S.Ui.Reroll, "dark", UDim2.fromOffset(78, 30), function()
				Progress.action("Reroll", { index = i })
			end, { TextSize = 15, ZIndex = 6 })
			b.Position = UDim2.fromOffset(0, 0)
			setOn(freeLeft or (s.stars or 0) >= d.rerollCost)
			Widgets.label(right, {
				Position = UDim2.fromOffset(0, 33),
				Size = UDim2.fromOffset(78, 18),
				TextSize = 12,
				color = if freeLeft then P.Safe else P.Spark,
				Text = cost,
				ZIndex = 6,
			})
		end
	end
	-- The Daily Crate row
	local crateRow = Theme.panel(face, {
		Name = "DailyCrate",
		Position = UDim2.new(0, 22, 1, -70),
		Size = UDim2.new(1, -44, 0, 54),
		color = Color3.fromRGB(52, 38, 30),
		border = P.Brass,
		border2 = P.Brass:Lerp(P.Ink, 0.4),
	})
	Widgets.icon(crateRow, "Crate", 48, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, -2),
		ZIndex = 5,
	})
	Widgets.label(crateRow, {
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -200, 1, 0),
		TextSize = 16,
		align = Enum.TextXAlignment.Left,
		wrap = true,
		Text = if d.crateClaimed
			then S.Rewards.DailyCrate .. ": " .. S.Ui.Saved
			elseif d.crateReady then S.Ui.DailyCrateReady
			else S.Ui.DailyCrateLocked,
		ZIndex = 5,
	})
	if d.crateReady then
		local b = Widgets.button(crateRow, S.Ui.Claim, "gold", UDim2.fromOffset(110, 38), function()
			Progress.action("ClaimDailyCrate")
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 6 })
		Widgets.pulse(b)
	end
end

-- ── The Daily Calendar ──────────────────────────────────────────────────────────────────────────────────────────

local popToday: (() -> ())? = nil -- the open streak screen's confetti pop

-- The Daily Streak (UI/StreakScreen): this frames the panel, the screen fills it.
local function buildCalendar(s: { [string]: any }, refresh: boolean?)
	if not s.daily then
		return
	end
	local face = panel("Calendar", S.Ui.CalendarTitle, Vector2.new(720, 440), P.Fuse, refresh)
	popToday = StreakScreen.build(face, s, {
		refresh = refresh,
		onClaim = function()
			Progress.action("ClaimLogin")
		end,
	})
end

-- The stamp slam on today's card after a claim (Asset Bible §7.5): confetti now, then the card turns CLAIMED (with
-- the stamp slamming down) as soon as the server's new snapshot arrives (applyDock).
local stampPending = false
local function stampToday()
	if not openPanel or openName ~= "Calendar" then
		return
	end
	Sfx.play("Stamp")
	if popToday then
		popToday()
	end
	stampPending = true
end

local function slamStamp(day: number)
	local f = openPanel
	local slot = f and f:FindFirstChild("Day" .. tostring(day), true)
	local stamp = slot and slot:FindFirstChild("Stamp", true)
	if stamp and stamp:IsA("TextLabel") then
		local sc = new("UIScale", { Scale = 2.4, Parent = stamp })
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 })
			:Play()
	end
end

-- ── The dock ────────────────────────────────────────────────────────────────────────────────────────────────────
-- The left-side stack of square tiles (UI/Dock, the owner's reference video): the Shop and Items (StoreController),
-- Quests, the Calendar, the playtime Gift (its countdown is its label), and AFK / Spectate (LobbyController).
local function dockButton(
	name: string,
	icon: string,
	order: number,
	onClick: () -> (),
	opts: Dock.TileOpts?
): (TextButton, Frame)
	local o: Dock.TileOpts = table.clone(opts or {})
	o.order = order
	local t = Dock.tile(dock, name, icon, onClick, o)
	return t.button, t.badge
end

local function buildDock()
	dock = new("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(Dock.SIZE + 24, 560),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	new("UIGridLayout", {
		Name = "Grid",
		CellSize = UDim2.fromOffset(Dock.SIZE, Dock.SIZE + 10),
		CellPadding = UDim2.fromOffset(DOCK_GAP, 10),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = dock,
	})
	-- Gift: a pink tile whose label is the countdown; it bounces when the gift is ready.
	local gt = Dock.tile(dock, "Gift", "Gift", function()
		local s = Progress.get()
		if s and s.daily and s.daily.gift.ready then
			Progress.action("ClaimGift")
		else
			Sfx.play("UiDeny")
		end
	end, { color = "pink", order = 5, label = "" })
	giftButton = gt.button
	giftLabel = gt.label
	giftLabel.TextSize = 22
	-- the progress ring round the gift: fills toward the next playtime gift
	local ringBox = new("Frame", {
		Name = "GiftRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gt.icon.Parent and gt.icon.Parent.Parent or gt.button,
	})
	setGiftRing = Widgets.progressRing(ringBox, Color3.fromRGB(255, 226, 90), 5, 3)
	local _, qd = dockButton("Quests", "Scroll", 3, function()
		local s = Progress.get()
		if s then
			buildQuests(s)
			Progress.action("QuestsOpened")
		end
	end, { color = "green", key = Enum.KeyCode.J })
	questDot = qd
	local cb, cd = dockButton("Calendar", "Calendar", 4, function()
		local s = Progress.get()
		if s then
			buildCalendar(s)
		end
	end, { color = "orange", label = "Daily" })
	calButton, calendarDot = cb, cd
end

local function placeDock()
	-- short phone screens: the dock shrinks to fit between the top bar and the bottom-left currency
	local fit = dock:FindFirstChild("Fit") :: UIScale?
	if not fit then
		fit = new("UIScale", { Name = "Fit", Parent = dock })
	end
	local v = Screen.size()
	local count = 0
	for _, c in ipairs(dock:GetChildren()) do
		if c:IsA("GuiButton") and c.Visible then
			count += 1
		end
	end
	-- one column while it stays readable; short phone screens fold it into two columns of bigger tiles
	local rowH = Dock.SIZE + 20
	local room = v.Y * 0.66
	local cols = if room / math.max(count * rowH, 1) < TWO_COLUMNS_BELOW then 2 else 1
	local need = math.ceil(count / cols) * rowH
	local grid = dock:FindFirstChild("Grid") :: UIGridLayout?
	if grid then
		grid.FillDirectionMaxCells = cols
	end
	dock.Size = UDim2.fromOffset(cols * Dock.SIZE + (cols - 1) * DOCK_GAP + 24, need);
	(fit :: UIScale).Scale = math.min(1, room / math.max(need, 1))
	local safe = Screen.safe()
	local x = if shown then 14 + safe.left else -(Dock.SIZE + 60)
	local goal = UDim2.new(0, x, 0.5, if touch() then -10 else 10)
	if Widgets.reduced() or dock.Position == UDim2.new() then
		dock.Position = goal
	else
		TweenService:Create(dock, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Position = goal }):Play()
	end
end

-- ── Live state ──────────────────────────────────────────────────────────────────────────────────────────────────
local giftWasReady = false
local function applyDock(s: { [string]: any })
	local d = s.daily
	if not d then
		return
	end
	-- calendar
	local claimable = d.login.claimable
	calendarDot.Visible = claimable
	if claimable and not stopCalPulse then
		stopCalPulse = Widgets.pulse(calButton)
	elseif not claimable and stopCalPulse then
		stopCalPulse()
		stopCalPulse = nil
	end
	-- quests: the dot when the Daily Crate waits
	questDot.Visible = d.crateReady == true
	-- live refresh of an open screen
	if openName == "Quests" then
		buildQuests(s, true)
	elseif openName == "Calendar" and stampPending and not d.login.claimable then
		stampPending = false
		buildCalendar(s, true)
		slamStamp(d.login.day)
	end
	-- first visit of the day: open the calendar once (after the rules card, OnboardingController)
	if claimable and not autoCalendarDone and d.flags and d.flags.tutorial then
		autoCalendarDone = true
		-- wait for a calm lobby moment: intermission (never over the results card) with nothing else up
		task.spawn(function()
			while true do
				task.wait(0.5)
				local now = Progress.get()
				if not now or not now.daily.login.claimable then
					return
				end
				if ClientState.phase() == Ph.Intermission and not openPanel and not Modal.busy() then
					task.wait(0.8)
					if ClientState.phase() == Ph.Intermission and not Modal.busy() then
						buildCalendar(now)
						return
					end
				end
			end
		end)
	end
end

local function tickGift()
	local s = Progress.get()
	local d = s and s.daily
	if not d then
		return
	end
	local g = d.gift
	local left = if g.ready then 0 else math.max(0, g.left - Progress.age())
	local ready = g.ready or left <= 0
	-- ring fill: progress from the previous milestone to this one
	local idx = g.index
	local prevMin = 0
	if idx > 1 then
		local pi = idx - 1
		prevMin = if pi <= #D.GIFTS
			then D.GIFTS[pi].minutes
			else D.GIFTS[#D.GIFTS].minutes + (pi - #D.GIFTS) * D.REPEAT_EVERY
	end
	local thisMin = if idx <= #D.GIFTS
		then D.GIFTS[idx].minutes
		else D.GIFTS[#D.GIFTS].minutes + (idx - #D.GIFTS) * D.REPEAT_EVERY
	local span = math.max(1, (thisMin - prevMin) * 60)
	local frac = if ready then 1 else math.clamp(1 - left / span, 0, 1)
	setGiftRing(frac)
	giftLabel.Text = if ready then S.Ui.GiftReady else Widgets.clock(left)
	giftLabel.TextColor3 = if ready then P.Spark else P.Paper
	if ready and not giftWasReady then
		stopGiftPulse = Widgets.pulse(giftButton)
	elseif not ready and giftWasReady and stopGiftPulse then
		stopGiftPulse()
		stopGiftPulse = nil
	end
	giftWasReady = ready
end

local function onReward(r: any)
	if type(r) ~= "table" then
		return
	end
	local from = ProgressController.centre()
	if r.kind == "Login" then
		Sfx.play("Claim")
		stampToday()
		if r.reward == "Stars" then
			ProgressController.fly(from, r.amount or 0)
		end
	elseif r.kind == "Gift" then
		Sfx.play("Claim")
		local g = giftButton.AbsolutePosition + giftButton.AbsoluteSize / 2
		if r.reward == "Stars" then
			ProgressController.fly(g, r.amount or 0)
		end
	elseif r.kind == "DailyCrate" then
		Sfx.play("Claim")
	elseif r.kind == "Quest" then
		Sfx.play("QuestDone")
		ProgressController.fly(from, r.stars or 0)
	elseif r.kind == "Reroll" then
		Sfx.play("UiPress")
	elseif r.kind == "Denied" then
		Sfx.play("UiDeny")
	end
end

function DailyController.start()
	Progress.start()
	hud = new("ScreenGui", {
		Name = "FV_Dock",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	modal = new("ScreenGui", {
		Name = "FV_Daily",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildDock()
	shown = dockWanted()
	placeDock()
	Screen.Changed:Connect(placeDock)
	Progress.Changed:Connect(applyDock)
	local s = Progress.get()
	if s then
		applyDock(s)
	end
	Net.listen("Reward", onReward)
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local function refreshShown()
		local on = dockWanted()
		if on ~= shown then
			shown = on
			placeDock()
		end
	end
	player:GetAttributeChangedSignal("Afk"):Connect(refreshShown)
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		local on = dockWanted()
		refreshShown()
		-- §19.2: a menu open at round start closes gracefully
		if not on and openPanel then
			closePanel()
		end
	end)
	task.spawn(function()
		while true do
			tickGift()
			task.wait(0.5)
		end
	end)
end

-- Another controller's button in the dock (the Shop and Locker, StoreController). Returns the button and its dot.
function DailyController.addDockButton(
	name: string,
	icon: string,
	order: number,
	onClick: () -> (),
	opts: Dock.TileOpts?
): (TextButton, Frame)
	while not dock do
		task.wait()
	end
	local b, dot = dockButton(name, icon, order, onClick, opts)
	placeDock()
	return b, dot
end

-- A panel in the shared modal layer (other screens use it so only one is ever open).
function DailyController.panel(name: string, title: string, size: Vector2, accent: Color3, refresh: boolean?): Frame
	return panel(name, title, size, accent, refresh)
end

-- The open panel's header slot for tabs (right of the title, left of the close square).
function DailyController.headerTabs(): Frame?
	return headerSlot
end

-- How far the dock reaches in from the left edge (screen px, its scale included), so the quest tracker sits beside it.
function DailyController.dockWidth(): number
	if not dock then
		return Dock.SIZE + 24
	end
	local fit = dock:FindFirstChild("Fit") :: UIScale?
	return dock.Size.X.Offset * (if fit then fit.Scale else 1)
end

-- The name of the open panel ("" when none), so other screens can tell whether theirs is still up.
function DailyController.openName(): string
	return openName
end

-- Open a screen from elsewhere (the quest tracker, onboarding).
function DailyController.open(name: string)
	local s = Progress.get()
	if not s then
		return
	end
	if name == "Quests" then
		buildQuests(s)
		Progress.action("QuestsOpened")
	elseif name == "Calendar" then
		buildCalendar(s)
	end
end

return DailyController
