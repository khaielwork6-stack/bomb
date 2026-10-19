--!strict
-- The round HUD (GDD §21.2): the crossing chip over the HUD Field Fuse (a burning fuse in a steel gutter), the team
-- counter top-right (in Roblox's top bar row on phones, the Chase Game lesson), the phase headlines, the MOVE!
-- warning and the Carrier's red vignette (§10.1). P1 lays it out to the Asset Bible panel rules; the full motion and
-- callout pass is P3. Implements: F-UI-02 (layout), F-FUSE-02 (HUD fuse warning), F-CROSS-01 (MOVE!), F-FEEL-01.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Announcer = require(script.Parent.Parent.UI.Announcer)
local NumberArt = require(script.Parent.Parent.UI.NumberArt)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local S = Config.Strings
local new = Theme.new
local Ph = Types.Phase
local player = Players.LocalPlayer

local HudController = {}

local gs: Configuration
local HEADLINE_SIZE, SUBLINE_SIZE = 34, 20 -- the status line (AFK / up next) on a wide screen…
local HEADLINE_REF_W, HEADLINE_MIN = 1000, 0.66 -- …scaled by width / 1000 below that, down to 66%
local gui: ScreenGui
local fuseHolder: Frame
local fuseFill: Frame
local fuseSpark: ImageLabel
local fuseHazard: ImageLabel
local fuseCord: ImageLabel
local crossingDots: { Frame } = {}
local fuseFace: Frame
local crossingLabel: TextLabel
local counter: Frame
local runnersLabel: TextLabel
local bombersLabel: TextLabel
local roleChip: Frame
local roleLabel: TextLabel
local crossNum: NumberArt.Number? -- "1/8" (and the lobby countdown) in baked number art
local runnersNum: NumberArt.Number?
local bombersNum: NumberArt.Number?
local roleArt: { [string]: ImageLabel } = {}
local fuseGlow: ImageLabel
local headline: TextLabel
local headlineScale: UIScale
local subline: TextLabel
local vignette: { GuiObject } = {}
local lastRole = ""

local function touch(): boolean
	return Screen.touch() -- the touch layout (device detection lives in MobileController; Studio can simulate it)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- ── Build ───────────────────────────────────────────────────────────────────────────────────────────────────────
local function pill(parent: Instance, name: string, size: UDim2): Frame
	local face = Theme.panel(parent, { Name = name, Size = size, radius = 999, shadow = 4 })
	return face
end

local function numberLabel(parent: Instance, color: Color3, order: number): TextLabel
	local l = new("TextLabel", {
		Size = UDim2.fromOffset(40, 34),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Display,
		TextSize = 32,
		TextColor3 = color,
		Text = "0",
		LayoutOrder = order,
		ZIndex = 4,
		Parent = parent,
	})
	new("UIStroke", { Color = P.Ink, Thickness = 3, Parent = l })
	return l
end

local function build()
	gui = new("ScreenGui", {
		Name = "FV_Hud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Top-centre: crossing chip + the HUD Field Fuse.
	local top = new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(320, 80),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- The crossing chip: "CROSSING 3/8" over 8 fuse dots (lit = crossed, the current one pulses).
	local chip = pill(top, "Crossing", UDim2.fromOffset(220, 48))
	local chipHolder = chip.Parent :: Frame
	chipHolder.AnchorPoint = Vector2.new(0.5, 0)
	chipHolder.Position = UDim2.fromScale(0.5, 0)
	crossingLabel = new("TextLabel", {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Display,
		TextSize = 22,
		TextColor3 = P.Paper,
		Text = "",
		ZIndex = 3,
		Parent = chip,
	})
	new("UIStroke", { Color = P.Ink, Thickness = 2.5, Parent = crossingLabel })
	if NumberArt.has() then
		crossNum = NumberArt.new(chip, {
			height = 30,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(0.5, 8, 0, 17),
			align = Enum.HorizontalAlignment.Left,
			zIndex = 4,
			name = "Num",
		})
	end
	local dotRow = new("Frame", {
		Name = "Dots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.fromOffset(150, 10),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = chip,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = dotRow,
	})
	for i = 1, 8 do
		local d = new("Frame", {
			Name = "D" .. i,
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = P.Smoke,
			LayoutOrder = i,
			ZIndex = 4,
			Parent = dotRow,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
		new("UIStroke", { Color = P.Ink, Thickness = 1.5, Parent = d })
		table.insert(crossingDots, d)
	end
	-- The HUD Field Fuse: a braided cord in a steel gutter, burning down from the left, a spark at the burn point;
	-- hazard stripes sweep the frame from 5 s left.
	fuseFace = Theme.panel(top, {
		Name = "Fuse",
		Size = UDim2.fromOffset(320, 34),
		radius = 999,
		color = Color3.fromRGB(196, 204, 218),
		color2 = Color3.fromRGB(104, 112, 128),
		border = Color3.new(1, 1, 1),
		glow = P.Detonate,
		glowT = 1,
	})
	fuseHolder = fuseFace.Parent :: Frame
	fuseHolder.AnchorPoint = Vector2.new(0.5, 0)
	fuseHolder.Position = UDim2.new(0.5, 0, 0, 56)
	local hazard = new("ImageLabel", {
		Name = "Hazard",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Ui.Hazard,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(30, 30),
		ImageTransparency = 1,
		ZIndex = 2,
		Parent = fuseFace,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hazard })
	fuseHazard = hazard
	local gutter = new("Frame", {
		Name = "Gutter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 0, 18),
		BackgroundColor3 = Color3.fromRGB(34, 30, 40),
		ZIndex = 2,
		Parent = fuseFace,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gutter })
	fuseFill = new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = gutter,
	})
	-- the cord stays put while the fill shortens from the left, so the braid doesn't slide
	local cord = new("ImageLabel", {
		Name = "Cord",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(320, 18),
		BackgroundTransparency = 1,
		Image = Assets.Ui.Braid,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(72, 18),
		ZIndex = 3,
		Parent = fuseFill,
	})
	fuseCord = cord
	fuseGlow = new("ImageLabel", {
		Name = "SparkGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(64, 40),
		BackgroundTransparency = 1,
		Image = Assets.TitleFx.Glow,
		ImageColor3 = P.Fuse,
		ImageTransparency = 0.25,
		ZIndex = 4,
		Parent = fuseFace,
	}) :: ImageLabel
	fuseSpark = new("ImageLabel", {
		Name = "Spark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Image = Assets.TitleFx.Sparkle,
		ImageColor3 = Color3.fromRGB(255, 240, 190),
		ZIndex = 5,
		Parent = fuseFace,
	}) :: any
	-- Role chip under the fuse.
	roleChip = pill(top, "Role", UDim2.fromOffset(120, 24))
	local roleHolder = roleChip.Parent :: Frame
	roleHolder.AnchorPoint = Vector2.new(0.5, 0)
	roleHolder.Position = UDim2.new(0.5, 0, 0, 98)
	for role, key in pairs({ Runner = "RoleRunner", Bomber = "RoleBomber" }) do
		local art = (Assets.Title :: any)[key]
		if art then
			local h = 30
			roleArt[role] = new("ImageLabel", {
				Name = key,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 96),
				Size = UDim2.fromOffset(math.floor(h * art.size.X / art.size.Y), h),
				BackgroundTransparency = 1,
				Image = art.id,
				ScaleType = Enum.ScaleType.Fit,
				Visible = false,
				ZIndex = 4,
				Parent = top,
			}) :: ImageLabel
		end
	end
	roleLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Display,
		TextSize = 16,
		TextColor3 = P.Paper,
		Text = "",
		ZIndex = 3,
		Parent = roleChip,
	})
	-- Top-right: team counter.
	counter = pill(gui, "Counter", UDim2.fromOffset(196, 50))
	local row = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = counter,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local function teamIcon(name: string, order: number): ImageLabel
		local img = new("ImageLabel", {
			Name = name,
			Size = UDim2.fromOffset(44, 44),
			BackgroundTransparency = 1,
			Image = (Assets.Icon :: any)[name] or "",
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = order,
			ZIndex = 4,
			Parent = row,
		})
		return img
	end
	teamIcon("Runner", 1)
	runnersLabel = numberLabel(row, P.Runner, 2)
	if NumberArt.has() then
		runnersLabel.Visible = false
		runnersNum = NumberArt.new(row, { height = 36, color = P.Runner, zIndex = 4, name = "Runners" });
		(runnersNum :: NumberArt.Number).frame.LayoutOrder = 2
	end
	new("Frame", {
		Size = UDim2.fromOffset(3, 26),
		BackgroundColor3 = P.Ink,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = row,
	})
	teamIcon("Bomber", 4)
	bombersLabel = numberLabel(row, P.Bomber, 5)
	if NumberArt.has() then
		bombersLabel.Visible = false
		bombersNum = NumberArt.new(row, { height = 36, color = P.Bomber, zIndex = 4, name = "Bombers" });
		(bombersNum :: NumberArt.Number).frame.LayoutOrder = 5
	end
	-- The status line: only a lasting state (AFK, up next) — every one-off moment is title art through the
	-- announcer (UI/Announcer), one at a time, in the middle of the screen below this.
	headline = Theme.display(gui, {
		Name = "Headline",
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(700, 70),
		TextSize = HEADLINE_SIZE,
	})
	headlineScale = new("UIScale", { Scale = 1, Parent = headline })
	subline = Theme.display(gui, {
		Name = "Subline",
		Position = UDim2.new(0.5, 0, 0.2, 32),
		Size = UDim2.fromOffset(600, 32),
		TextSize = SUBLINE_SIZE,
		font = Theme.Font.Heavy,
		stroke = 2,
	})
	-- Carrier vignette: one radial edge mask (art/ui/make_hud.py) tinted Detonate, pulsing with the tick.
	local v = new("ImageLabel", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Ui.Vignette,
		ImageColor3 = P.Detonate,
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = false,
		ZIndex = 0,
		Parent = gui,
	})
	table.insert(vignette, v :: any)
end

-- ── Placement (phones: the counter sits in the top bar row) ─────────────────────────────────────────────────────
local function place()
	local holder = counter.Parent :: Frame
	local inset = Screen.topbar()
	if touch() then
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, -12, 0, inset.Min.Y + inset.Height / 2)
	else
		holder.AnchorPoint = Vector2.new(1, 0)
		holder.Position = UDim2.new(1, -18, 0, inset.Max.Y + 12)
	end
	fuseHolder.Size = UDim2.fromOffset(if touch() then 240 else 320, 34)
	-- the big centre lines shrink with the screen's width, so they never run edge to edge on a small phone
	local k = math.clamp(Screen.size().X / HEADLINE_REF_W, HEADLINE_MIN, 1)
	headline.TextSize = math.floor(HEADLINE_SIZE * k)
	subline.TextSize = math.floor(SUBLINE_SIZE * k)
end

-- A count changes like a split-flap: the old number squashes shut, the new one springs open.
local function flip(label: TextLabel, text: string)
	if label.Text == text then
		return
	end
	local sc = label:FindFirstChild("Flip") :: UIScale?
	if not sc then
		sc = new("UIScale", { Name = "Flip", Parent = label })
	end
	if label:GetAttribute("Shown") ~= true then
		label.Text = text
		label:SetAttribute("Shown", true)
		return
	end
	local s = sc :: UIScale
	TweenService:Create(s, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.2 }):Play()
	task.delay(0.07, function()
		label.Text = text
		s.Scale = 1.35
		TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
end

-- ── Headlines ───────────────────────────────────────────────────────────────────────────────────────────────────
local lastHeadline = ""
local function show(text: string, sub: string?, color: Color3?)
	if not headline then
		return
	end
	if text == lastHeadline and subline.Text == (sub or "") then
		return
	end
	lastHeadline = text
	headline.Text = text
	headline.TextColor3 = color or P.Paper
	subline.Text = sub or ""
	if text ~= "" then
		headlineScale.Scale = 1.35
		TweenService
			:Create(headlineScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

-- The round's twist as a title key (MEGA BOMB!, or the modifier: READ THE FACE / LIGHTS OUT / THE MOLE), or nil.
local TWISTS = { Face = "ReadTheFace", LightsOut = "LightsOut", Mole = "TheMole" }
local function twistTitle(): string?
	if gs:GetAttribute("MegaId") then
		return "MegaBomb"
	end
	local m = gs:GetAttribute("Modifier")
	return if type(m) == "string" then TWISTS[m] else nil
end
local twistSaid: any = nil -- the READY (by its end time) each one-off moment was said for
local goSaid: any = nil
local lastStandSaid: any = nil

-- ── Per frame ───────────────────────────────────────────────────────────────────────────────────────────────────
local function step()
	local phase = ClientState.phase()
	local t = now()
	local inRound = phase == Ph.Ready
		or phase == Ph.Crossing
		or phase == Ph.Resolve
		or phase == Ph.LastStand
		or phase == Ph.Intro
	-- Crossing chip / intermission countdown.
	local left = math.max(0, math.ceil((gs:GetAttribute("PhaseEndsAt") or 0) - t))
	-- a label with the number beside it in number art (or one line of text when the art isn't there)
	local function chipText(label: string, num: string?)
		local cn = crossNum
		if cn and num then
			crossingLabel.Text = label
			crossingLabel.TextSize = 16
			crossingLabel.TextXAlignment = Enum.TextXAlignment.Right
			crossingLabel.Size = UDim2.new(0.5, 0, 0, 28)
			cn.frame.Visible = true
			cn:set(num, true)
		else
			if cn then
				cn.frame.Visible = false
			end
			crossingLabel.Text = if num then label .. " " .. num else label
			crossingLabel.TextSize = 22
			crossingLabel.TextXAlignment = Enum.TextXAlignment.Center
			crossingLabel.Size = UDim2.new(1, 0, 0, 28)
		end
	end
	if phase == Ph.Intermission then
		chipText(S.Ui.NextRound, tostring(left))
	elseif phase == Ph.Results then
		chipText(S.Ui.ResultsChip, nil)
	elseif phase == Ph.LastStand then
		chipText(S.Ui.LastStandChip, nil)
	else
		chipText(
			S.Ui.CrossingChip,
			`{math.max(1, gs:GetAttribute("Crossing") or 0)}/{gs:GetAttribute("MaxCrossings") or 8}`
		)
	end
	-- The HUD Field Fuse.
	local fuseLive = phase == Ph.Crossing or (phase == Ph.LastStand and ClientState.sub() == Types.Sub.Run)
	fuseHolder.Visible = inRound
	local total = gs:GetAttribute("FuseTotal") or 0
	local ends = gs:GetAttribute("FuseEndsAt") or 0
	local frac = if fuseLive and total > 0 then math.clamp((ends - t) / total, 0, 1) else 1
	fuseFill.Size = UDim2.fromScale(frac, 1)
	fuseCord.Size = UDim2.fromOffset(fuseFill.Parent and (fuseFill.Parent :: Frame).AbsoluteSize.X or 320, 18)
	fuseSpark.Visible = fuseLive and frac > 0
	fuseGlow.Visible = fuseSpark.Visible
	-- the spark sits at the burn point (the fill's left end), in the face's space; it spins and flickers (rotation and
	-- transparency draw smoothly — a size pulse would step a pixel at a time)
	local sparkAt = UDim2.new(0, 7 + (1 - frac) * (fuseFill.Parent :: Frame).AbsoluteSize.X, 0.5, 0)
	fuseSpark.Position = sparkAt
	fuseGlow.Position = sparkAt
	fuseSpark.Rotation = (t * 300) % 360
	fuseSpark.ImageTransparency = 0.1 * math.random()
	fuseGlow.ImageTransparency = 0.2 + 0.15 * math.random()
	-- crossing dots: crossed = Spark, current = pulsing Fuse, the rest dark
	local crossing = gs:GetAttribute("Crossing") or 0
	local maxC = gs:GetAttribute("MaxCrossings") or 8
	for i, d in ipairs(crossingDots) do
		d.Visible = i <= maxC
		if i < crossing then
			d.BackgroundColor3 = P.Spark
		elseif i == crossing and inRound then
			d.BackgroundColor3 = P.Fuse:Lerp(P.Spark, 0.5 + 0.5 * math.sin(t * 8))
		else
			d.BackgroundColor3 = P.Smoke
		end
	end
	local remaining = if fuseLive then ends - t else math.huge
	local pulse = 0.5 + 0.5 * math.sin(t * 12)
	-- F-FUSE-02: the frame flashes Detonate red with a glow from 5 s left.
	if remaining <= 5 then
		Theme.recolor(fuseFace, {
			border = P.Detonate:Lerp(P.Spark, pulse * 0.4),
			border2 = P.Detonate,
			glow = P.Detonate,
			glowT = 0.25 + pulse * 0.4,
		})
		fuseHazard.ImageTransparency = 0.1 + 0.3 * (1 - pulse)
		fuseHazard.TileSize = UDim2.fromOffset(30, 30)
		fuseHazard.Position = UDim2.fromOffset(-((t * 40) % 30), 0)
	else
		Theme.recolor(fuseFace, { border = Color3.new(1, 1, 1), border2 = Color3.fromRGB(210, 216, 230) })
		fuseHazard.ImageTransparency = 1
	end
	fuseHolder.Rotation = if remaining <= 3 then (math.random() - 0.5) * 3 else 0
	fuseGlow.ImageColor3 = if remaining <= 5 then P.Detonate else P.Fuse
	-- Role chip.
	local role = ClientState.role()
	local roleHolder = roleChip.Parent :: Frame
	local art = roleArt[role]
	roleHolder.Visible = inRound and role ~= Types.Role.None and art == nil
	for r, img in pairs(roleArt) do
		img.Visible = inRound and r == role
	end
	roleLabel.Text = string.upper(role)
	if role ~= lastRole then
		lastRole = role
		local rc = Theme.roleColor(role)
		Theme.recolor(roleChip, { fill = rc:Lerp(P.Ink2, 0.3), fill2 = rc:Lerp(P.Ink, 0.6), border = rc, border2 = rc })
	end
	-- Counter.
	local counterHolder = counter.Parent :: Frame
	counterHolder.Visible = inRound
	local rn, bn = runnersNum, bombersNum
	if rn and bn then
		rn:set(tostring(gs:GetAttribute("RunnersLeft") or 0), true)
		bn:set(tostring(gs:GetAttribute("BombersCount") or 0), true)
	else
		flip(runnersLabel, tostring(gs:GetAttribute("RunnersLeft") or 0))
		flip(bombersLabel, tostring(gs:GetAttribute("BombersCount") or 0))
	end
	-- The Carrier vignette (no MOVE! / BUMP SOMEONE! text: the BUMP! marker and the safe-side chevron already say it).
	-- (a READ THE FACE bomb has no time while LIT: the vignette keeps its LIT beat, F-MOD-02)
	local explodeAt = player:GetAttribute("BombExplodeAt")
	local carrying = player:GetAttribute("BombId") ~= nil
		and (type(explodeAt) == "number" or player:GetAttribute("BombMasked") == true)
	local rem = if carrying and type(explodeAt) == "number" then explodeAt - t else math.huge
	local hz = if rem <= 1 then 10 elseif rem <= 2.5 then 4 else 2
	local beat = 0.5 + 0.5 * math.sin(t * hz * math.pi * 2)
	local strength = if rem <= 1 then 0.7 elseif rem <= 2.5 then 0.45 else 0.2
	for _, edge in ipairs(vignette) do
		edge.Visible = carrying;
		(edge :: any).ImageTransparency = 1 - math.min(1, strength * 1.3) * (0.6 + 0.4 * beat)
	end
	-- One-off moments: title art through the announcer, once each.
	if phase == Ph.Ready then
		local readyId = gs:GetAttribute("PhaseEndsAt")
		if crossing <= 1 and twistSaid ~= readyId then
			-- the round's twist, once, as crossing 1 gets ready (the pick camera hides the INTRO)
			twistSaid = readyId
			local twist = twistTitle()
			if twist then
				Announcer.say({ key = twist, tier = "Moment", priority = 3, hold = 1.2 })
			end
		end
		if left <= 1 and goSaid ~= readyId then
			goSaid = readyId
			Announcer.say({ key = "Go", priority = 1.7, hold = 0.5 })
		end
	elseif phase == Ph.LastStand and ClientState.sub() == Types.Sub.Intro then
		local id = gs:GetAttribute("LastStandId") or ""
		if lastStandSaid ~= id then
			lastStandSaid = id
			local _, model = ClientState.byId(id)
			Announcer.say({
				key = "LastStand",
				tier = "Moment",
				priority = 3,
				sub = if model then ClientState.nameOf(id) else nil,
				icon = "Crown",
				hold = Config.Round.LAST_STAND_INTRO,
			})
		end
	end
	-- The status line: only while sitting out mid-round (D-LOBBY-01: waiting in The Depot for the next READY).
	if
		ClientState.role() == Types.Role.None
		and (phase == Ph.Ready or phase == Ph.Crossing or phase == Ph.Resolve or phase == Ph.LastStand)
	then
		if player:GetAttribute("Afk") then
			show(Config.Strings.Lobby.Afk, Config.Strings.Lobby.AfkSub, P.Paper)
		else
			show(Config.Strings.Lobby.Joining, Config.Strings.Lobby.JoiningSub, P.Bomber)
		end
	else
		show("", nil)
	end
end

function HudController.start()
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	build()
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	Screen.Changed:Connect(place)
	RunService.RenderStepped:Connect(step)
	-- BOMBER! when my boom turns me (GDD §10.3)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if ClientState.role() == Types.Role.Bomber and ClientState.phase() ~= Ph.Intro then
			Announcer.say({ key = "Bomber", tier = "Moment", priority = 2.5, hold = 1.4 })
		end
	end)
	Net.listen("FieldFx", function(p)
		if type(p) == "table" and p.kind == "Hurry" then
			Announcer.say({ key = "Hurry", priority = 2.5 })
		elseif type(p) == "table" and p.kind == "Clear" then
			Announcer.say({ key = "AllClear", priority = 1.6 })
		end
	end)
end

return HudController
