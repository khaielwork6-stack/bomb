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
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local new = Theme.new
local Ph = Types.Phase
local player = Players.LocalPlayer

local HudController = {}

local gs: Configuration
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
local headline: TextLabel
local headlineScale: UIScale
local subline: TextLabel
local moveWarn: TextLabel
local vignette: { GuiObject } = {}
local lastRole = ""

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
	local chip = pill(top, "Crossing", UDim2.fromOffset(210, 44))
	local chipHolder = chip.Parent :: Frame
	chipHolder.AnchorPoint = Vector2.new(0.5, 0)
	chipHolder.Position = UDim2.fromScale(0.5, 0)
	crossingLabel = new("TextLabel", {
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Display,
		TextSize = 22,
		TextColor3 = P.Paper,
		Text = "",
		ZIndex = 3,
		Parent = chip,
	})
	new("UIStroke", { Color = P.Ink, Thickness = 2.5, Parent = crossingLabel })
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
		Size = UDim2.fromOffset(300, 30),
		radius = 999,
		color = Color3.fromRGB(196, 204, 218),
		color2 = Color3.fromRGB(104, 112, 128),
		border = Color3.new(1, 1, 1),
		glow = P.Detonate,
		glowT = 1,
	})
	fuseHolder = fuseFace.Parent :: Frame
	fuseHolder.AnchorPoint = Vector2.new(0.5, 0)
	fuseHolder.Position = UDim2.new(0.5, 0, 0, 52)
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
		Size = UDim2.new(1, -14, 0, 14),
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
		Size = UDim2.fromOffset(300, 14),
		BackgroundTransparency = 1,
		Image = Assets.Ui.Braid,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(56, 14),
		ZIndex = 3,
		Parent = fuseFill,
	})
	fuseCord = cord
	fuseSpark = new("ImageLabel", {
		Name = "Spark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Image = Assets.Vfx.Flash,
		ImageColor3 = P.Spark,
		ZIndex = 5,
		Parent = fuseFace,
	}) :: any
	-- Role chip under the fuse.
	roleChip = pill(top, "Role", UDim2.fromOffset(120, 24))
	local roleHolder = roleChip.Parent :: Frame
	roleHolder.AnchorPoint = Vector2.new(0.5, 0)
	roleHolder.Position = UDim2.new(0.5, 0, 0, 70)
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
	new("Frame", {
		Size = UDim2.fromOffset(3, 26),
		BackgroundColor3 = P.Ink,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = row,
	})
	teamIcon("Bomber", 4)
	bombersLabel = numberLabel(row, P.Bomber, 5)
	-- Centre: headline + subline.
	headline = Theme.display(gui, {
		Name = "Headline",
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 70),
		TextSize = 56,
	})
	headlineScale = new("UIScale", { Scale = 1, Parent = headline })
	subline = Theme.display(gui, {
		Name = "Subline",
		Position = UDim2.new(0.5, 0, 0.3, 46),
		Size = UDim2.fromOffset(600, 32),
		TextSize = 24,
		font = Theme.Font.Heavy,
		stroke = 2,
	})
	moveWarn = Theme.display(gui, {
		Name = "MoveWarn",
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(400, 60),
		TextSize = 48,
		color = P.Detonate,
		Text = "MOVE!",
	})
	moveWarn.Visible = false
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
	local inset = GuiService.TopbarInset
	if touch() then
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, -12, 0, inset.Min.Y + inset.Height / 2)
	else
		holder.AnchorPoint = Vector2.new(1, 0)
		holder.Position = UDim2.new(1, -18, 0, inset.Max.Y + 12)
	end
	fuseHolder.Size = UDim2.fromOffset(if touch() then 220 else 300, 30)
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
local holdUntil = 0 -- an event headline (YOU'RE A BOMBER, ALL CLEAR) holds until then
local function show(text: string, sub: string?, color: Color3?)
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
	if phase == Ph.Intermission then
		crossingLabel.Text = `NEXT ROUND {left}`
	elseif phase == Ph.Results then
		crossingLabel.Text = "RESULTS"
	elseif phase == Ph.LastStand then
		crossingLabel.Text = "LAST STAND"
	else
		crossingLabel.Text =
			`CROSSING {math.max(1, gs:GetAttribute("Crossing") or 0)}/{gs:GetAttribute("MaxCrossings") or 8}`
	end
	-- The HUD Field Fuse.
	local fuseLive = phase == Ph.Crossing or (phase == Ph.LastStand and ClientState.sub() == Types.Sub.Run)
	fuseHolder.Visible = inRound
	local total = gs:GetAttribute("FuseTotal") or 0
	local ends = gs:GetAttribute("FuseEndsAt") or 0
	local frac = if fuseLive and total > 0 then math.clamp((ends - t) / total, 0, 1) else 1
	fuseFill.Size = UDim2.fromScale(frac, 1)
	fuseCord.Size = UDim2.fromOffset(fuseFill.Parent and (fuseFill.Parent :: Frame).AbsoluteSize.X or 300, 14)
	fuseSpark.Visible = fuseLive and frac > 0
	-- the spark sits at the burn point (the fill's left end), in the face's space
	fuseSpark.Position = UDim2.new(0, 7 + (1 - frac) * (fuseFill.Parent :: Frame).AbsoluteSize.X, 0.5, 0)
	fuseSpark.Rotation = (t * 360) % 360
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
	fuseSpark.Size = UDim2.fromOffset(14 + pulse * 6, 14 + pulse * 6)
	-- Role chip.
	local role = ClientState.role()
	local roleHolder = roleChip.Parent :: Frame
	roleHolder.Visible = inRound and role ~= Types.Role.None
	roleLabel.Text = string.upper(role)
	if role ~= lastRole then
		lastRole = role
		local rc = Theme.roleColor(role)
		Theme.recolor(roleChip, { fill = rc:Lerp(P.Ink2, 0.3), fill2 = rc:Lerp(P.Ink, 0.6), border = rc, border2 = rc })
	end
	-- Counter.
	local counterHolder = counter.Parent :: Frame
	counterHolder.Visible = inRound
	flip(runnersLabel, tostring(gs:GetAttribute("RunnersLeft") or 0))
	flip(bombersLabel, tostring(gs:GetAttribute("BombersCount") or 0))
	-- MOVE! and the Carrier vignette.
	moveWarn.Visible = player:GetAttribute("MoveWarn") == true
	local explodeAt = player:GetAttribute("BombExplodeAt")
	local carrying = player:GetAttribute("BombId") ~= nil and type(explodeAt) == "number"
	local rem = if carrying then (explodeAt :: number) - t else math.huge
	local hz = if rem <= 1 then 10 elseif rem <= 2.5 then 4 else 2
	local beat = 0.5 + 0.5 * math.sin(t * hz * math.pi * 2)
	local strength = if rem <= 1 then 0.7 elseif rem <= 2.5 then 0.45 else 0.2
	for _, edge in ipairs(vignette) do
		edge.Visible = carrying;
		(edge :: any).ImageTransparency = 1 - math.min(1, strength * 1.3) * (0.6 + 0.4 * beat)
	end
	-- Headlines by phase (an event headline holds its moment first).
	if os.clock() < holdUntil then
		return
	end
	if phase == Ph.Intro then
		show("BOMBERS", "watch out for the red team", P.Bomber)
	elseif phase == Ph.Ready then
		show(if left <= 1 then "GO!" else "GET READY", "")
	elseif phase == Ph.LastStand and ClientState.sub() == Types.Sub.Intro then
		local id = gs:GetAttribute("LastStandId") or ""
		local _, model = ClientState.byId(id)
		show("LAST STAND", if model then model.Name else "", P.Gold)
	elseif carrying and phase ~= Ph.Results then -- (RESULTS belongs to the results card, ResultsController)
		show("BUMP SOMEONE!", "or run to a safe side", P.Detonate)
	else
		show("", nil)
	end
end

function HudController.start()
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	build()
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	UserInputService.LastInputTypeChanged:Connect(place)
	RunService.RenderStepped:Connect(step)
	-- "You're a Bomber" beat when my boom turns me (GDD §10.3).
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if ClientState.role() == Types.Role.Bomber and ClientState.phase() ~= Ph.Intro then
			lastHeadline = ""
			show("YOU'RE A BOMBER", "touch Runners to stick bombs", P.Bomber)
			holdUntil = os.clock() + 1.8
		end
	end)
	Net.listen("FieldFx", function(p)
		if type(p) == "table" and p.kind == "Clear" then
			lastHeadline = ""
			show("ALL CLEAR", "", P.Safe)
			holdUntil = os.clock() + 1.2
		end
	end)
end

return HudController
