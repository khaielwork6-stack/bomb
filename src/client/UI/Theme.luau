--!strict
-- FUSE VALLEY UI tokens (Asset Bible §2.3 palette, §2.6 type) and the panel recipe (the partner's Skin kit, tinted).
-- Every screen reads its colours, fonts and panels from here, so the look is defined once.

local Skin = require(script.Parent.Skin)

local Theme = {}

local hex = Color3.fromHex

Theme.Palette = {
	Ink = hex("#16121C"),
	Ink2 = hex("#241D2E"),
	Smoke = hex("#3B3447"),
	Ash = hex("#8C8498"),
	Paper = hex("#FFFFFF"),
	Fuse = hex("#FF6A1F"),
	Ember = hex("#FF9442"),
	Spark = hex("#FFD84A"),
	Gold = hex("#F2B13A"),
	Detonate = hex("#E8322B"),
	Runner = hex("#2FD3FF"), -- reserved: the Runner team
	Bomber = hex("#FF4A2E"), -- reserved: the Bomber team
	Safe = hex("#3BE48C"),
	Mega = hex("#B04CFF"),
	Iron = hex("#2E2C33"),
	Brass = hex("#C9973F"),
	Porcelain = hex("#F4EFE6"),
}

Theme.Font = {
	-- The reference video's round arcade face everywhere (DECISIONS 2026-10-17): Fredoka One for display, numbers and
	-- labels; Builder Sans Bold only for long body copy.
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Heavy = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Bold = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

-- Team colour for a role.
function Theme.roleColor(role: string?): Color3
	if role == "Bomber" then
		return Theme.Palette.Bomber
	elseif role == "Runner" then
		return Theme.Palette.Runner
	end
	return Theme.Palette.Ash
end

-- Bomb stage colours (GDD §7.2): LIT → HOT → CRITICAL.
function Theme.stageColor(stage: string): Color3
	if stage == "CRITICAL" then
		return Theme.Palette.Detonate
	elseif stage == "HOT" then
		return Theme.Palette.Ember
	end
	return Theme.Palette.Spark
end

local function new(class: string, props: { [string]: any }): any
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
Theme.new = new

-- Panels are the Skin kit (UI/Skin: rounded body, gloss, gold border ring, ink outline, optional glow and halftone),
-- tinted with these tokens. Pills (radius 999) use the kit's Chip shape, everything else its Frame.
local layersOf: { [Instance]: { [string]: GuiObject } } = setmetatable({}, { __mode = "k" }) :: any

function Theme.panel(parent: Instance, props: { [string]: any }): Frame
	local holder = new("Frame", {
		Name = props.Name or "Panel",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(200, 60),
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = holder,
	})
	local pill = (props.radius or 14) >= 999
	local base = props.color or Skin.Color.PanelTop
	layersOf[face] = Skin.frame(face, {
		kind = if pill then "Chip" else "Frame",
		scale = props.scale or (if pill then 0.42 else 0.5),
		fill = base,
		fill2 = props.color2 or base:Lerp(Skin.Color.PanelBottom, 0.6),
		fillT = props.transparency,
		border = props.border or Skin.Color.Accent,
		border2 = props.border2 or (props.border or Skin.Color.Accent):Lerp(Color3.new(0, 0, 0), 0.18),
		glow = props.glow,
		glowT = props.glowT,
		dots = props.dots,
		dotsT = props.dotsT,
	})
	return face
end

-- The skin layers of a panel made by Theme.panel (for Skin.recolor: warnings, selection, team colours).
function Theme.layers(face: Instance): { [string]: GuiObject }?
	return layersOf[face]
end

-- Recolour a Theme.panel in place.
function Theme.recolor(face: Instance, o: { [string]: any })
	local layers = layersOf[face]
	if layers then
		Skin.recolor(layers, o :: any)
	end
end

-- Display text with the Asset Bible rule: a 3 px Ink stroke and a solid drop below (never a glow outline).
function Theme.display(parent: Instance, props: { [string]: any }): TextLabel
	local label = new("TextLabel", {
		Name = props.Name or "Display",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(400, 60),
		BackgroundTransparency = 1,
		FontFace = props.font or Theme.Font.Display,
		Text = props.Text or "",
		TextColor3 = props.color or Theme.Palette.Paper,
		TextSize = props.TextSize or 40,
		TextScaled = false,
		ZIndex = props.ZIndex or 5,
		Parent = parent,
	})
	new("UIStroke", { Color = Theme.Palette.Ink, Thickness = props.stroke or 3, Parent = label })
	return label
end

return Theme
