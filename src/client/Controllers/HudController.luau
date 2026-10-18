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

local Config = require(ReplicatedStorage.Shared.Config)
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
local fuseSpark: Frame
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
local vignette: { Frame } = {}
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

local function dot(parent: Instance, color: Color3, order: number): Frame
	local d = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = color,
		LayoutOrder = order,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
	new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = d })
	return d
end

local function numberLabel(parent: Instance, color: Color3, order: number): TextLabel
	return new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Heavy,
		TextSize = 22,
		TextColor3 = color,
		Text = "0",
		LayoutOrder = order,
		Parent = parent,
	})
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
	local chip = pill(top, "Crossing", UDim2.fromOffset(170, 30))
	local chipHolder = chip.Parent :: Frame
	chipHolder.AnchorPoint = Vector2.new(0.5, 0)
	chipHolder.Position = UDim2.fromScale(0.5, 0)
	crossingLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Heavy,
		TextSize = 17,
		TextColor3 = P.Paper,
		Text = "",
		ZIndex = 3,
		Parent = chip,
	})
	fuseFace = Theme.panel(
		top,
		{ Name = "Fuse", Size = UDim2.fromOffset(300, 22), radius = 999, color = P.Smoke, glow = P.Detonate, glowT = 1 }
	)
	fuseHolder = fuseFace.Parent :: Frame
	fuseHolder.AnchorPoint = Vector2.new(0.5, 0)
	fuseHolder.Position = UDim2.new(0.5, 0, 0, 40)
	local gutter = new("Frame", {
		Name = "Gutter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 0, 8),
		BackgroundColor3 = P.Ink,
		ZIndex = 2,
		Parent = fuseFace,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gutter })
	fuseFill = new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#D9B98A"),
		ZIndex = 3,
		Parent = gutter,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fuseFill })
	-- braid: thin diagonal ticks along the cord
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#B8925E")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#E8CFA3")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#B8925E")),
		}),
		Rotation = 90,
		Parent = fuseFill,
	})
	fuseSpark = new("Frame", {
		Name = "Spark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = P.Spark,
		ZIndex = 4,
		Parent = fuseFill,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fuseSpark })
	new("UIStroke", { Color = P.Fuse, Thickness = 2, Parent = fuseSpark })
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
	counter = pill(gui, "Counter", UDim2.fromOffset(150, 36))
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
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	dot(row, P.Runner, 1)
	runnersLabel = numberLabel(row, P.Runner, 2)
	new("Frame", {
		Size = UDim2.fromOffset(2, 18),
		BackgroundColor3 = P.Smoke,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = row,
	})
	dot(row, P.Bomber, 4)
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
	-- Carrier vignette: four soft red edges (no image asset needed).
	for i, spec in ipairs({
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.22),
			Rotation = 90,
		},
		{
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.22),
			Rotation = -90,
		},
		{
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(0.16, 1),
			Rotation = 0,
		},
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.16, 1),
			Rotation = 180,
		},
	}) do
		local edge = new("Frame", {
			Name = "Vignette" .. i,
			AnchorPoint = spec.AnchorPoint,
			Position = spec.Position,
			Size = spec.Size,
			BackgroundColor3 = P.Detonate,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 0,
			Parent = gui,
		})
		new("UIGradient", {
			Rotation = spec.Rotation,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Parent = edge,
		})
		table.insert(vignette, edge)
	end
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
	fuseHolder.Size = UDim2.fromOffset(if touch() then 220 else 300, 22)
end

-- ── Headlines ───────────────────────────────────────────────────────────────────────────────────────────────────
local lastHeadline = ""
local holdUntil = 0 -- an event headline (YOU'RE A BOMBER, ALL CLEAR) holds until then
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

-- The round's modifier strings (GDD §6.4), or nil on a normal round.
local function modifierText(): { Name: string, Line: string }?
	local m = gs:GetAttribute("Modifier")
	local s = if type(m) == "string" and m ~= "" then (Config.Strings.Modifiers :: any)[m] else nil
	return if type(s) == "table" then s else nil
end

-- An event headline from another controller (the Mole's reveal, GDD §6.4): holds for `seconds`.
function HudController.flash(text: string, sub: string?, color: Color3?, seconds: number)
	lastHeadline = ""
	show(text, sub, color)
	holdUntil = os.clock() + seconds
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
	fuseSpark.Visible = fuseLive and frac > 0
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
	else
		Theme.recolor(fuseFace, { border = P.Fuse, border2 = P.Ember })
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
	runnersLabel.Text = tostring(gs:GetAttribute("RunnersLeft") or 0)
	bombersLabel.Text = tostring(gs:GetAttribute("BombersCount") or 0)
	-- MOVE! and the Carrier vignette.
	moveWarn.Visible = player:GetAttribute("MoveWarn") == true
	-- (a READ THE FACE bomb has no time while LIT: the vignette keeps its LIT beat, F-MOD-02)
	local explodeAt = player:GetAttribute("BombExplodeAt")
	local carrying = player:GetAttribute("BombId") ~= nil
		and (type(explodeAt) == "number" or player:GetAttribute("BombMasked") == true)
	local rem = if carrying and type(explodeAt) == "number" then explodeAt - t else math.huge
	local hz = if rem <= 1 then 10 elseif rem <= 2.5 then 4 else 2
	local beat = 0.5 + 0.5 * math.sin(t * hz * math.pi * 2)
	local strength = if rem <= 1 then 0.7 elseif rem <= 2.5 then 0.45 else 0.2
	for _, edge in ipairs(vignette) do
		edge.Visible = carrying
		edge.BackgroundTransparency = 1 - strength * (0.6 + 0.4 * beat)
	end
	-- Headlines by phase (an event headline holds its moment first).
	if os.clock() < holdUntil then
		return
	end
	if phase == Ph.Intro and gs:GetAttribute("MegaId") then
		show(Config.Strings.Round.Mega, Config.Strings.Round.MegaSub, P.Mega) -- GDD §16
	elseif phase == Ph.Intro and modifierText() then
		local m = modifierText() :: { Name: string, Line: string }
		show(m.Name, m.Line, P.Gold) -- F-MOD-01: the round's modifier, in one line
	elseif phase == Ph.Intro then
		show("BOMBERS", "watch out for the red team", P.Bomber)
	elseif phase == Ph.Ready then
		show(if left <= 1 then "GO!" else "GET READY", "")
	elseif phase == Ph.LastStand and ClientState.sub() == Types.Sub.Intro then
		local id = gs:GetAttribute("LastStandId") or ""
		local _, model = ClientState.byId(id)
		show("LAST STAND", if model then model.Name else "", P.Gold)
	elseif
		ClientState.role() == Types.Role.None
		and (phase == Ph.Ready or phase == Ph.Crossing or phase == Ph.Resolve or phase == Ph.LastStand)
	then
		-- D-LOBBY-01: joined mid-round, waiting in The Depot for the next READY
		show(Config.Strings.Lobby.Joining, Config.Strings.Lobby.JoiningSub, P.Bomber)
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
		if type(p) == "table" and p.kind == "Hurry" then
			lastHeadline = ""
			show(Config.Strings.Round.Hurry, Config.Strings.Round.HurrySub, P.Detonate)
			holdUntil = os.clock() + 1.4
		end
		if type(p) == "table" and p.kind == "Clear" then
			lastHeadline = ""
			show("ALL CLEAR", "", P.Safe)
			holdUntil = os.clock() + 1.2
		end
	end)
end

return HudController
