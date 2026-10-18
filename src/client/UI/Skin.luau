--!strict
-- Skin: the UI kit every screen is built from (panels, cards, pills, arcade buttons, the close button, header tabs).
-- 2026-10-17: restyled to the owner's reference video (DECISIONS: "the video wins for UI") — flat rounded bodies with a
-- soft vertical gradient and a gloss band, a coloured border ring and a thick ink outline; bright arcade buttons with a
-- darker lip; round Fredoka One type with an ink stroke. Everything is native UI (UICorner / UIStroke / UIGradient), so
-- it stays crisp at any size; the API is the partner's original one (Chase Game), so every screen picks it up as is.
-- Implements: F-UI-01, Asset Bible §6.1–§6.3.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)

local Skin = {}

local rgb = Color3.fromRGB

Skin.Tex = {
	Dots = "rbxassetid://115567285498813",
	DotsCorner = "rbxassetid://90163096415671",
	Radial = "rbxassetid://91508420435421",
	Sparkle = "rbxassetid://134511066576307",
	Stripes = "rbxassetid://89702410961873",
	Robux = "rbxasset://textures/ui/common/robux_small@3x.png", -- Roblox's own Robux mark (white: tint it)
}
local T = Skin.Tex

Skin.Color = {
	Ink = rgb(17, 15, 22), -- the outline on everything
	PanelTop = rgb(48, 43, 70),
	PanelBottom = rgb(29, 26, 44),
	CardTop = rgb(58, 52, 84),
	CardBottom = rgb(36, 32, 54),
	Well = rgb(24, 21, 36),
	Accent = rgb(255, 198, 44), -- the gold border ring on panels
	AccentSoft = rgb(120, 92, 30),
	Text = rgb(255, 255, 255),
	TextSoft = rgb(255, 240, 214),
	TextDim = rgb(170, 164, 190),
	Cash = rgb(255, 216, 74), -- Stars
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

-- Button presets: face top / face / lip (the reference's tab and price-button colours).
Skin.Preset = {
	fuse = { rgb(255, 176, 92), rgb(255, 112, 30), rgb(150, 50, 6) },
	runner = { rgb(140, 238, 255), rgb(47, 211, 255), rgb(10, 100, 140) },
	bomber = { rgb(255, 150, 120), rgb(255, 74, 46), rgb(140, 24, 10) },
	brass = { rgb(255, 228, 150), rgb(214, 160, 58), rgb(120, 78, 16) },
	gold = { rgb(255, 236, 120), rgb(255, 196, 30), rgb(170, 108, 0) },
	green = { rgb(140, 246, 80), rgb(56, 204, 32), rgb(24, 112, 12) },
	red = { rgb(255, 128, 92), rgb(236, 56, 30), rgb(132, 20, 8) },
	cyan = { rgb(120, 214, 255), rgb(36, 152, 240), rgb(14, 78, 150) },
	pink = { rgb(255, 150, 236), rgb(232, 76, 206), rgb(128, 22, 110) },
	purple = { rgb(196, 150, 255), rgb(146, 78, 246), rgb(70, 26, 150) },
	orange = { rgb(255, 170, 110), rgb(250, 108, 46), rgb(150, 50, 10) },
	dark = { rgb(76, 70, 102), rgb(46, 41, 66), rgb(22, 19, 34) },
	grey = { rgb(150, 146, 162), rgb(104, 100, 118), rgb(52, 49, 62) },
}

-- Fredoka One everywhere (the reference's round arcade face); Builder Sans stays for long body copy.
Skin.Font = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Round = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Heavy = Font.new("rbxasset://fonts/families/FredokaOne.json"),
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

-- A full-size layer: a plain Frame with the shape's rounded corners.
local function layer(parent: Instance, name: string, radius: number, z: number, props: { [string]: any }?): Frame
	local f = new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = f })
	if props then
		for k, v in pairs(props) do
			(f :: any)[k] = v
		end
	end
	return f
end

-- A stroke drawn just outside a layer's edge (UIStroke grows outward from the bounds).
local function ring(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

local function tag(host: Instance)
	for _, x in ipairs(host:GetDescendants()) do
		x:SetAttribute("Skin", true)
	end
end

export type FrameOpts = {
	kind: string?, -- "Frame" (panels, cards) | "Chip" (buttons, pills, rows)
	scale: number?, -- outline weight: 0.5 = the standard 3 px colour ring + ink outline
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
function Skin.frame(target: GuiObject, opts: FrameOpts?): { [string]: GuiObject }
	local o: FrameOpts = opts or {}
	local chip = (o.kind or "Frame") == "Chip"
	local weight = (o.scale or 0.5) * 2
	local radius = if chip then 8 else 12
	clearSkin(target)
	local host = makeRoot(target)
	if target:IsA("GuiObject") then
		target.BackgroundTransparency = 1
		local stroke = target:FindFirstChildOfClass("UIStroke")
		if stroke and not stroke:GetAttribute("Keep") then
			stroke.Enabled = false
		end
	end
	local L: { [string]: GuiObject } = {}
	local glow = layer(host, "SkinGlow", radius, -10)
	ring(glow, o.glow or C.Accent, 10 * weight, o.glowT or 0.55)
	glow.Visible = o.glow ~= nil
	L.glow = glow
	local outline = layer(host, "SkinOutline", radius, -9)
	ring(outline, C.Ink, 5.5 * weight)
	local fill = layer(host, "SkinFill", radius, -8, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = o.fillT or 0,
	})
	vgrad(fill, o.fill or C.PanelTop, o.fill2 or o.fill or C.PanelBottom)
	L.fill = fill
	if o.tint then
		local t = layer(host, "SkinTint", radius, -7, { BackgroundColor3 = o.tint, BackgroundTransparency = 0 })
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
		local clip = layer(host, "SkinDots", radius, -7, { ClipsDescendants = true })
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
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = d })
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
		end
	end
	-- Gloss: a white band over the top 45 %, fading out (the "lit from above" read of the reference cards).
	local bevel = layer(host, "SkinBevel", radius, -6, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
	})
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - (1 - (o.bevelT or 0.65)) * 0.3),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = bevel,
	})
	L.bevel = bevel
	local border = layer(host, "SkinBorder", radius, -5)
	local bs = ring(border, Color3.new(1, 1, 1), 3 * weight)
	vgrad(bs, o.border or C.Accent, o.border2 or o.border or C.Accent)
	L.border = border
	tag(host)
	return L
end

-- Recolour an already-skinned frame (selection, hover) without rebuilding it.
function Skin.recolor(
	layers: { [string]: GuiObject },
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
		local st = layers.border:FindFirstChildOfClass("UIStroke")
		local g = st and st:FindFirstChildOfClass("UIGradient")
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
		local st = layers.glow:FindFirstChildOfClass("UIStroke")
		if o.glow and st then
			st.Color = o.glow
			st.Transparency = o.glowT or 0.55
		end
	end
end

-- Display text: the round arcade face with a dark outline, like the reference's chunky labels.
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

-- A preset from any base colour (face top = the colour lit from above, face = the colour, lip = it in shadow).
function Skin.presetOf(color: Color3, deep: Color3?): { Color3 }
	local h, sat, v = color:ToHSV()
	local top = Color3.fromHSV(h, sat * 0.7, math.min(1, v * 1.08 + 0.08))
	local edge = if deep
		then deep:Lerp(Color3.new(0, 0, 0), 0.35)
		else Color3.fromHSV(h, math.min(1, sat * 1.1), v * 0.45)
	return { top, color, edge }
end

-- The reference's arcade button: a bright rounded face with a lighter top, a darker lip under it, a gloss band, and a
-- thick ink outline round face + lip; white text with an ink stroke.
function Skin.button(
	target: GuiObject,
	preset: (string | { Color3 })?,
	opts: { scale: number?, glow: Color3?, stripes: boolean?, lip: number? }?
)
	local o = opts or {}
	local p: { Color3 } = if type(preset) == "table"
		then preset
		else Skin.Preset[(preset :: string?) or "fuse"] or Skin.Preset.fuse
	local weight = (o.scale or 0.6) / 0.6
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
	local radius = 8
	if o.glow then
		local g = layer(host, "SkinGlow", radius, -10)
		ring(g, o.glow, 8 * weight, 0.5)
	end
	local base = layer(host, "SkinLip", radius, -9, {
		BackgroundColor3 = p[3],
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 1, lip),
	})
	ring(base, C.Ink, 3 * weight)
	local face = layer(host, "SkinFace", radius, -8, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
	})
	vgrad(face, p[1], p[2])
	if o.stripes ~= false then
		local clip = layer(host, "SkinStripes", radius, -7, { ClipsDescendants = true })
		new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = T.Stripes,
			ImageTransparency = 0.93,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(24, 24),
			ZIndex = -7,
			Parent = clip,
		})
	end
	local gloss = layer(host, "SkinGloss", radius, -6, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
	})
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.46, 0.85),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	tag(host)
	if target:IsA("TextButton") or target:IsA("TextLabel") then
		local t: any = target
		Skin.text(t, { stroke = 2, ink = C.Ink })
		t.TextColor3 = C.Text
	end
end

-- A light sweep across a skinned button. Returns the play function.
function Skin.shine(target: GuiObject, transparency: number?): () -> ()
	local clip = new("Frame", {
		Name = "SkinShine",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = -3,
		Parent = target,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = clip })
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

-- The reference's close button: a red-orange rounded square with a bold white X, outlined in ink.
function Skin.close(parent: Instance, size: number?, props: { [string]: any }?): ImageButton
	local s = size or 44
	local b = new("ImageButton", {
		Name = "Close",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(s, s),
		Image = "",
		AutoButtonColor = false,
		Parent = parent,
	})
	Skin.button(b, "red", { stripes = false, lip = 4 })
	local x = new("TextLabel", {
		Name = "X",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "X",
		TextScaled = true,
		TextColor3 = C.Text,
		Parent = b,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0.16, 0),
		PaddingBottom = UDim.new(0.16, 0),
		Parent = x,
	})
	Skin.text(x, { stroke = 2.5, ink = C.Ink })
	if props then
		for k, v in pairs(props) do
			(b :: any)[k] = v
		end
	end
	return b
end

-- A header tab ("SHOP", "TRAIL CHEST" plates in the reference): a bright rounded plate in `color`, outlined in ink,
-- with the title in white Fredoka.
function Skin.ribbon(parent: Instance, text: string, color: Color3?, props: { [string]: any }?): Frame
	local col = color or C.Accent
	local r = new("Frame", {
		Name = "Ribbon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(200, 50),
		Parent = parent,
	})
	Skin.button(r, Skin.presetOf(col), { stripes = false, lip = 5 })
	local t = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = string.upper(text),
		TextScaled = true,
		TextColor3 = C.Text,
		Parent = r,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0.18, 0),
		PaddingBottom = UDim.new(0.16, 0),
		PaddingLeft = UDim.new(0.1, 0),
		PaddingRight = UDim.new(0.1, 0),
		Parent = t,
	})
	Skin.text(t, { stroke = 2.5, ink = C.Ink })
	if props then
		for k, v in pairs(props) do
			(r :: any)[k] = v
		end
	end
	return r
end

-- Skin a frame whose state colour lives on a UIStroke (selection, ready / cooldown): the border ring (and its glow,
-- with `glowOn`) follows the stroke's colour, so the old state code keeps working unchanged.
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

-- A premium icon image (Assets.Icon), or nil when it isn't uploaded yet.
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
