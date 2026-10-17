--!strict
-- Skin: the premium UI kit, by the partner (Chase Game, 2026-10-17: chamfered neon frames, halftone dots, glossy 3D
-- buttons, rarity-lit cards, a red octagon close, a slanted header ribbon). Ported to FUSE VALLEY on 2026-10-17 with
-- its palette and button presets recoloured to the Asset Bible §2.3 tokens (fuse-orange neon, ink-plum panels,
-- brass / gold) — every texture is a white mask tinted here, so the shapes stay the partner's and the colours are
-- FUSE VALLEY's. Textures come from Chase Game's tools/ui/make_ui_kit.py (assets/ui/kit).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)

local Skin = {}

local rgb = Color3.fromRGB

Skin.Tex = {
	ChipBevel = "rbxassetid://92761400127102",
	ChipBorder = "rbxassetid://71768609535408",
	ChipFill = "rbxassetid://83154864308086",
	ChipGlow = "rbxassetid://108065671396055",
	Dots = "rbxassetid://115567285498813",
	DotsCorner = "rbxassetid://90163096415671",
	FrameBevel = "rbxassetid://87152881396277",
	FrameBorder = "rbxassetid://80001872474946",
	FrameFill = "rbxassetid://88909266187470",
	FrameGlow = "rbxassetid://111224733267606",
	Gloss = "rbxassetid://118968224977154",
	HexBorder = "rbxassetid://82000527664573",
	HexFill = "rbxassetid://118491756875680",
	OctagonBorder = "rbxassetid://78348984125012",
	OctagonFill = "rbxassetid://100837119325457",
	Radial = "rbxassetid://91508420435421",
	Sparkle = "rbxassetid://134511066576307",
	Stripes = "rbxassetid://89702410961873",
	TabBorder = "rbxassetid://135332906809482",
	TabFill = "rbxassetid://117127511703937",
	Robux = "rbxasset://textures/ui/common/robux_small@3x.png", -- Roblox's own Robux mark (white: tint it)
}
local T = Skin.Tex

-- Slice data from assets/ui/kit/slices.json (image px): the 9-slice centre, the cut size and the glow margin.
local SHAPE = {
	Frame = {
		fill = T.FrameFill,
		border = T.FrameBorder,
		bevel = T.FrameBevel,
		glow = T.FrameGlow,
		size = 160,
		inset = 39,
		cut = 30,
		glowSize = 224,
		glowInset = 70,
		pad = 32,
	},
	Chip = {
		fill = T.ChipFill,
		border = T.ChipBorder,
		bevel = T.ChipBevel,
		glow = T.ChipGlow,
		size = 96,
		inset = 22,
		cut = 14,
		glowSize = 160,
		glowInset = 54,
		pad = 32,
	},
}

Skin.Color = {
	Ink = rgb(22, 18, 28), -- Theme Ink
	PanelTop = rgb(46, 36, 58),
	PanelBottom = rgb(18, 14, 24),
	CardTop = rgb(44, 34, 56),
	CardBottom = rgb(20, 16, 27),
	Well = rgb(30, 24, 40),
	Accent = rgb(255, 106, 31), -- Fuse: the neon edge
	AccentSoft = rgb(92, 56, 40),
	Text = rgb(255, 255, 255),
	TextSoft = rgb(255, 232, 205),
	TextDim = rgb(140, 132, 152), -- Ash
	Cash = rgb(255, 216, 74), -- Spark: Stars
	Robux = rgb(109, 255, 176),
	Rarity = {
		Default = rgb(150, 160, 178),
		Common = rgb(169, 177, 194),
		Rare = rgb(51, 182, 255),
		Epic = rgb(166, 91, 255),
		Legendary = rgb(255, 182, 39),
		Exclusive = rgb(255, 79, 154),
	},
}
local C = Skin.Color

-- Button presets: face top / bottom, the dark edge (border + 3D lip) and the glow.
Skin.Preset = {
	-- FUSE VALLEY additions first: the brand button (Fuse), and the two team colours.
	fuse = { rgb(255, 170, 96), rgb(255, 106, 31), rgb(110, 36, 4) },
	runner = { rgb(130, 236, 255), rgb(47, 211, 255), rgb(6, 70, 96) },
	bomber = { rgb(255, 138, 110), rgb(255, 74, 46), rgb(102, 18, 8) },
	brass = { rgb(255, 222, 150), rgb(201, 151, 63), rgb(92, 60, 14) },
	gold = { rgb(255, 228, 112), rgb(255, 160, 16), rgb(122, 64, 0) },
	green = { rgb(125, 255, 184), rgb(59, 228, 140), rgb(5, 82, 43) },
	red = { rgb(255, 112, 100), rgb(232, 50, 43), rgb(92, 6, 12) },
	cyan = { rgb(110, 242, 255), rgb(22, 160, 217), rgb(6, 62, 92) },
	pink = { rgb(255, 128, 186), rgb(214, 28, 92), rgb(92, 10, 38) },
	purple = { rgb(196, 148, 255), rgb(176, 76, 255), rgb(44, 16, 96) },
	dark = { rgb(64, 52, 82), rgb(36, 29, 46), rgb(82, 66, 104) },
	grey = { rgb(140, 132, 152), rgb(92, 86, 104), rgb(40, 36, 48) },
}

Skin.Font = {
	Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Round = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Heavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
}

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	local parent = props.Parent
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	inst.Parent = parent
	return inst
end

local function vgrad(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

local function slice(
	parent: Instance,
	name: string,
	image: string,
	inset: number,
	size: number,
	scale: number,
	z: number
): ImageLabel
	return new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(inset, inset, size - inset, size - inset),
		SliceScale = scale,
		ZIndex = z,
		Parent = parent,
	})
end

-- All of a skin's layers live in a Folder: they still draw on the target (under its content, by their negative
-- ZIndex), but UIListLayout / UIGridLayout and AutomaticSize ignore whatever is inside a Folder. As plain children
-- they were laid out like content and made auto-sized pills swell (one ran across the whole screen).
local function makeRoot(target: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "SkinRoot"
	root:SetAttribute("Skin", true)
	root.Parent = target
	return root
end

local function clearSkin(target: Instance)
	for _, c in ipairs(target:GetChildren()) do
		if c:GetAttribute("Skin") then
			c:Destroy()
		end
	end
end

export type FrameOpts = {
	kind: string?, -- "Frame" (panels, cards) | "Chip" (buttons, pills, rows)
	scale: number?, -- SliceScale: the corner cut on screen = cut × scale
	fill: Color3?,
	fill2: Color3?, -- bottom of the vertical fill gradient
	fillT: number?,
	border: Color3?,
	border2: Color3?,
	glow: Color3?,
	glowT: number?,
	dots: Color3?, -- halftone wash over the body, fading downward
	dotsT: number?,
	corner: Color3?, -- comic halftone in two opposite corners (cards)
	cornerT: number?,
	bevelT: number?,
	tint: Color3?, -- a colour wash rising from the bottom (rarity light)
	tintT: number?,
}

-- Skin a frame in place (panel, card, pill, well). Returns its layers so callers can recolour them (selection).
function Skin.frame(target: GuiObject, opts: FrameOpts?): { [string]: ImageLabel }
	local o: FrameOpts = opts or {}
	local s = SHAPE[o.kind or "Frame"]
	local scale = o.scale or 0.5
	clearSkin(target)
	local host = makeRoot(target)
	if target:IsA("GuiObject") then
		target.BackgroundTransparency = 1
		local stroke = target:FindFirstChildOfClass("UIStroke")
		if stroke and not stroke:GetAttribute("Keep") then
			stroke.Enabled = false
		end
	end
	local L: { [string]: ImageLabel } = {}
	if o.glow then
		local pad = s.pad * scale
		local g = new("ImageLabel", {
			Name = "SkinGlow",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-pad, -pad),
			Size = UDim2.new(1, 2 * pad, 1, 2 * pad),
			Image = s.glow,
			ImageColor3 = o.glow,
			ImageTransparency = o.glowT or 0.35,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(s.glowInset, s.glowInset, s.glowSize - s.glowInset, s.glowSize - s.glowInset),
			SliceScale = scale,
			ZIndex = -9,
			Parent = host,
		})
		g:SetAttribute("Skin", true)
		L.glow = g
	end
	local fill = slice(host, "SkinFill", s.fill, s.inset, s.size, scale, -8)
	fill.ImageTransparency = o.fillT or 0.03
	vgrad(fill, o.fill or C.PanelTop, o.fill2 or o.fill or C.PanelBottom)
	L.fill = fill
	local cut = s.cut * scale
	if o.tint then
		local t = slice(host, "SkinTint", s.fill, s.inset, s.size, scale, -7)
		t.ImageColor3 = o.tint
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(1, o.tintT or 0.62),
			}),
			Parent = t,
		})
		L.tint = t
	end
	if o.dots then
		-- tiles can't follow the cut corners, so the wash stays inside them
		local clip = new("Frame", {
			Name = "SkinDots",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(cut, 2),
			Size = UDim2.new(1, -2 * cut, 1, -4),
			ZIndex = -7,
			Parent = host,
		})
		local d = new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = T.Dots,
			ImageColor3 = o.dots,
			ImageTransparency = o.dotsT or 0.88,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(24, 24),
			ZIndex = -7,
			Parent = clip,
		})
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0, 1),
			Parent = d,
		})
		clip:SetAttribute("Skin", true)
	end
	if o.corner then
		for i, at in ipairs({ Vector2.new(0, 0), Vector2.new(1, 1) }) do
			local c = new("ImageLabel", {
				Name = "SkinCorner" .. i,
				BackgroundTransparency = 1,
				AnchorPoint = at,
				Position = UDim2.fromScale(at.X, at.Y),
				Size = UDim2.fromScale(0.8, 0.8),
				Image = T.DotsCorner,
				ImageColor3 = o.corner,
				ImageTransparency = o.cornerT or 0.68,
				Rotation = if i == 2 then 180 else 0,
				ZIndex = -7,
				Parent = host,
			})
			new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = c })
			c:SetAttribute("Skin", true)
		end
	end
	local bevel = slice(host, "SkinBevel", s.bevel, s.inset, s.size, scale, -6)
	bevel.ImageTransparency = o.bevelT or 0.65
	L.bevel = bevel
	local border = slice(host, "SkinBorder", s.border, s.inset, s.size, scale, -5)
	border.ImageColor3 = Color3.new(1, 1, 1)
	vgrad(border, o.border or C.Accent, o.border2 or o.border or C.Accent)
	L.border = border
	for _, l in pairs(L) do
		l:SetAttribute("Skin", true)
	end
	return L
end

-- Recolour an already-skinned frame (selection, hover) without rebuilding it.
function Skin.recolor(
	layers: { [string]: ImageLabel },
	o: {
		border: Color3?,
		border2: Color3?,
		glow: Color3?,
		glowT: number?,
		fill: Color3?,
		fill2: Color3?,
	}
)
	if o.border and layers.border then
		local g = layers.border:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new(o.border, o.border2 or o.border)
		end
	end
	if o.fill and layers.fill then
		local g = layers.fill:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new(o.fill, o.fill2 or o.fill)
		end
	end
	if layers.glow then
		layers.glow.Visible = o.glow ~= nil
		if o.glow then
			layers.glow.ImageColor3 = o.glow
			layers.glow.ImageTransparency = o.glowT or 0.35
		end
	end
end

-- Display text: Luckiest Guy (or Fredoka) with a dark outline, like the references' chunky labels.
function Skin.text(
	label: TextLabel | TextButton,
	opts: { font: string?, stroke: number?, color: Color3?, ink: Color3? }?
)
	local o = opts or {}
	label.FontFace = (Skin.Font :: any)[o.font or "Display"]
	if o.color then
		label.TextColor3 = o.color
	end
	local st = label:FindFirstChild("SkinStroke") :: UIStroke?
	if not st then
		st = new("UIStroke", {
			Name = "SkinStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	local s = st :: UIStroke
	s.Color = o.ink or C.Ink
	s.Thickness = o.stroke or 2
	s:SetAttribute("Keep", true)
end

-- A glossy 3D button face on any GuiButton (or Frame): lip, gradient face, stripes, gloss, border, catch-light.
-- A preset from any base colour (face = the colour lit from above, edge = it in shadow).
function Skin.presetOf(color: Color3, deep: Color3?): { Color3 }
	local h, sat, v = color:ToHSV()
	local top = Color3.fromHSV(h, sat * 0.7, math.min(1, v * 1.08 + 0.08))
	local edge = if deep
		then deep:Lerp(Color3.new(0, 0, 0), 0.35)
		else Color3.fromHSV(h, math.min(1, sat * 1.1), v * 0.38)
	return { top, color, edge }
end

function Skin.button(
	target: GuiObject,
	preset: (string | { Color3 })?,
	opts: { scale: number?, glow: Color3?, stripes: boolean?, lip: number? }?
)
	local o = opts or {}
	local p: { Color3 } = if type(preset) == "table"
		then preset
		else Skin.Preset[(preset :: string?) or "fuse"] or Skin.Preset.fuse
	local s = SHAPE.Chip
	local scale = o.scale or 0.6
	clearSkin(target)
	local host = makeRoot(target)
	target.BackgroundTransparency = 1
	if target:IsA("GuiButton") then
		local b: any = target
		b.AutoButtonColor = false
	end
	local stroke = target:FindFirstChildOfClass("UIStroke")
	if stroke and not stroke:GetAttribute("Keep") then
		stroke.Enabled = false
	end
	local lip = o.lip or 4
	local parts: { Instance } = {}
	if o.glow then
		local pad = s.pad * scale
		table.insert(
			parts,
			new("ImageLabel", {
				Name = "SkinGlow",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(-pad, -pad),
				Size = UDim2.new(1, 2 * pad, 1, 2 * pad),
				Image = s.glow,
				ImageColor3 = o.glow,
				ImageTransparency = 0.4,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(s.glowInset, s.glowInset, s.glowSize - s.glowInset, s.glowSize - s.glowInset),
				SliceScale = scale,
				ZIndex = -9,
				Parent = host,
			})
		)
	end
	local under = slice(host, "SkinLip", s.fill, s.inset, s.size, scale, -9)
	under.Position = UDim2.fromOffset(0, lip)
	under.ImageColor3 = p[3]
	table.insert(parts, under)
	local face = slice(host, "SkinFace", s.fill, s.inset, s.size, scale, -8)
	vgrad(face, p[1], p[2])
	table.insert(parts, face)
	if o.stripes ~= false then
		local cut = s.cut * scale
		local clip = new("Frame", {
			Name = "SkinStripes",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(cut, 0),
			Size = UDim2.new(1, -2 * cut, 1, 0),
			ZIndex = -7,
			Parent = host,
		})
		new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = T.Stripes,
			ImageTransparency = 0.9,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(24, 24),
			ZIndex = -7,
			Parent = clip,
		})
		table.insert(parts, clip)
	end
	local gloss = slice(host, "SkinGloss", s.fill, s.inset, s.size, scale, -6)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	table.insert(parts, gloss)
	local border = slice(host, "SkinBorder", s.border, s.inset, s.size, scale, -5)
	border.ImageColor3 = p[3]
	table.insert(parts, border)
	local bevel = slice(host, "SkinBevel", s.bevel, s.inset, s.size, scale, -4)
	bevel.ImageTransparency = 0.5
	table.insert(parts, bevel)
	for _, x in ipairs(parts) do
		x:SetAttribute("Skin", true)
	end
	if target:IsA("TextButton") or target:IsA("TextLabel") then
		local t: any = target
		Skin.text(t, { stroke = 2, ink = p[3] })
		t.TextColor3 = C.Text
	end
end

-- A light sweep across a skinned button (Kit.shine clips the whole button, which would cut its glow and lip): the
-- band runs inside a clip inset by the chamfer. Returns the play function.
function Skin.shine(target: GuiObject, transparency: number?): () -> ()
	local cut = SHAPE.Chip.cut * 0.6
	local clip = new("Frame", {
		Name = "SkinShine",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(cut * 0.5, 2),
		Size = UDim2.new(1, -cut, 1, -4),
		ZIndex = -3,
		Parent = target,
	})
	clip:SetAttribute("SkinKeep", true)
	local band = new("Frame", {
		Size = UDim2.new(0.45, 0, 1, 0),
		Position = UDim2.fromScale(-0.6, 0),
		BackgroundColor3 = C.Text,
		ZIndex = -3,
		Parent = clip,
	})
	new("UIGradient", {
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, transparency or 0.62),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	return function()
		band.Position = UDim2.fromScale(-0.6, 0)
		local tw = TweenService:Create(band, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Position = UDim2.fromScale(1.2, 0),
		})
		tw:Play()
	end
end

-- The red octagon close button (Otarplayz reference), an ImageButton with an X.
function Skin.close(parent: Instance, size: number?, props: { [string]: any }?): ImageButton
	local s = size or 44
	local b = new("ImageButton", {
		Name = "Close",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(s, s),
		Image = T.OctagonFill,
		AutoButtonColor = false,
		Parent = parent,
	})
	vgrad(b, rgb(255, 104, 92), rgb(200, 24, 28))
	new("ImageLabel", {
		Name = "Edge",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = T.OctagonBorder,
		ImageColor3 = rgb(74, 6, 8),
		Parent = b,
	})
	local x = new("TextLabel", {
		Name = "X",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0.04),
		Text = "X",
		TextScaled = true,
		TextColor3 = C.Text,
		Parent = b,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0.2, 0),
		PaddingBottom = UDim.new(0.2, 0),
		Parent = x,
	})
	Skin.text(x, { stroke = 2, ink = rgb(74, 6, 8) })
	if props then
		for k, v in pairs(props) do
			(b :: any)[k] = v
		end
	end
	return b
end

-- The slanted header ribbon ("STORE" tab in the references) that sits over a panel's top-left edge.
function Skin.ribbon(parent: Instance, text: string, color: Color3?, props: { [string]: any }?): Frame
	local col = color or C.Accent
	local h, s = 0.6, 0
	h, s = col:ToHSV()
	local r = new("Frame", {
		Name = "Ribbon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(200, 50),
		Parent = parent,
	})
	local fill = new("ImageLabel", {
		Name = "Fill",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = T.TabFill,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(28, 0, 192, 64),
		SliceScale = 0.8,
		ZIndex = -2,
		Parent = r,
	})
	vgrad(fill, Color3.fromHSV(h, s * 0.75, 1), Color3.fromHSV(h, math.min(1, s * 1.05), 0.82))
	new("ImageLabel", {
		Name = "Edge",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = T.TabBorder,
		ImageColor3 = Color3.fromHSV(h, s, 0.32),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(28, 0, 192, 64),
		SliceScale = 0.8,
		ZIndex = -1,
		Parent = r,
	})
	local t = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0.05),
		Text = string.upper(text),
		TextScaled = true,
		TextColor3 = C.Text,
		Parent = r,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0.2, 0),
		PaddingBottom = UDim.new(0.18, 0),
		PaddingLeft = UDim.new(0.16, 0),
		PaddingRight = UDim.new(0.16, 0),
		Parent = t,
	})
	Skin.text(t, { stroke = 2.5, ink = Color3.fromHSV(h, s, 0.3) })
	if props then
		for k, v in pairs(props) do
			(r :: any)[k] = v
		end
	end
	return r
end

-- Skin a frame whose state colour lives on a UIStroke (selection, ready / cooldown): the chamfered edge (and its
-- glow, with `glowOn`) follows the stroke's colour, so the old state code keeps working unchanged.
function Skin.follow(target: GuiObject, stroke: UIStroke, opts: FrameOpts?, glowOn: ((Color3) -> boolean)?)
	local o: FrameOpts = table.clone(opts or {})
	o.border = stroke.Color
	o.glow = o.glow or stroke.Color
	local layers = Skin.frame(target, o)
	local function sync()
		local c = stroke.Color
		local lit = if glowOn then glowOn(c) else false
		Skin.recolor(layers, { border = c, border2 = c:Lerp(Color3.new(0, 0, 0), 0.3), glow = if lit then c else nil })
	end
	stroke:GetPropertyChangedSignal("Color"):Connect(sync)
	sync()
	return layers
end

-- One line of text, as big as fits: TextScaled without wrapping only fits the height, so a long name ran past its
-- box. This shrinks TextSize from `max` until the line fits the width (re-checked when the box or text changes).
function Skin.fitLine(label: TextLabel, max: number, min: number?)
	label.TextScaled = false
	label.TextWrapped = false
	local lo = min or 8
	local function fit()
		if label.AbsoluteSize.X < 2 then
			return
		end
		local size = max
		label.TextSize = size
		while not label.TextFits and size > lo do
			size -= 1
			label.TextSize = size
		end
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	task.defer(fit)
end

-- A premium icon image (assets/ui/icons via Assets.Icon), or nil when it isn't uploaded yet.
function Skin.icon(parent: Instance, name: string, props: { [string]: any }?): ImageLabel?
	local id = (Assets.Icon :: any)[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local img = new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = id,
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	})
	if props then
		for k, v in pairs(props) do
			(img :: any)[k] = v
		end
	end
	return img
end

function Skin.hasIcon(name: string): boolean
	local id = (Assets.Icon :: any)[name]
	return type(id) == "string" and id ~= ""
end

-- A soft coloured light behind featured art (cards, previews, rewards).
function Skin.light(parent: Instance, color: Color3, transparency: number?, scale: number?): ImageLabel
	local l = new("ImageLabel", {
		Name = "SkinLight",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale or 1.2, scale or 1.2),
		Image = T.Radial,
		ImageColor3 = color,
		ImageTransparency = transparency or 0.45,
		ZIndex = -3,
		Parent = parent,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = l })
	l:SetAttribute("Skin", true)
	return l
end

return Skin
