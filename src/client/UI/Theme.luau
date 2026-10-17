--!strict
-- FUSE VALLEY UI tokens (Asset Bible §2.3 palette, §2.6 type, §6.2 panels). Every screen reads its colours, fonts
-- and panel recipe from here, so the look is defined once.

local Theme = {}

local hex = Color3.fromHex

Theme.Palette = {
	Ink = hex("#16121C"),
	Ink2 = hex("#241D2E"),
	Smoke = hex("#3B3447"),
	Ash = hex("#8C8498"),
	Paper = hex("#FFF3E2"),
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
	-- Display / callouts: Luckiest Guy. UI headings and numbers: Builder Sans Heavy. Body: Builder Sans Bold.
	Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Heavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
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

-- Asset Bible §6.2 panel: a solid offset shadow, an Ink outline, the fill and a top bevel highlight.
-- Returns the panel frame (children go inside it) with its shadow parented alongside.
function Theme.panel(parent: Instance, props: { [string]: any }): Frame
	local radius = props.radius or 14
	local holder = new("Frame", {
		Name = props.Name or "Panel",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(200, 60),
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local shadow = new("Frame", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, props.shadow or 5),
		BackgroundColor3 = Theme.Palette.Ink,
		BackgroundTransparency = 0.45,
		ZIndex = 0,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = shadow })
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.color or Theme.Palette.Ink2,
		BackgroundTransparency = props.transparency or 0,
		ZIndex = 1,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = face })
	new("UIStroke", { Color = Theme.Palette.Ink, Thickness = 3, Parent = face })
	-- The bevel: a 2 px inner highlight along the top edge (Asset Bible §6.2).
	local bevel = new("Frame", {
		Name = "Bevel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.new(1, -radius, 0, 2),
		BackgroundColor3 = Theme.Palette.Paper,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bevel })
	return face
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
