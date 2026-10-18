-- Shared helpers for the world builders: studded parts, models, folders.

local Util = {}

local T

function Util.init(theme)
	T = theme
	return Util
end

-- Real Roblox studs (the owner, 2026-10-18: "the actual roblox studs texture from the properties, this looks
-- painted"): the part's own Studs surface on top and Inlet underneath, like a classic brick. Surfaces only render on
-- the Plastic material, so a studded part becomes Plastic (glow / glass / textured materials are left as they are).
local STUDDABLE = { [Enum.Material.Plastic] = true, [Enum.Material.SmoothPlastic] = true }
function Util.realStuds(part: BasePart)
	if not STUDDABLE[part.Material] then
		return
	end
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
end

-- Stud a part (kept for the older builders' call shape: the tile size and faces no longer apply).
function Util.stud(part, _tile, _faces)
	Util.realStuds(part)
end

-- Create an anchored, studded part.
-- opts: stud (tile number, or false), material, transparency, shape, collide, faces
function Util.block(parent, name, size, cframe, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if opts.shadow == false then
		p.CastShadow = false
	end
	if opts.stud ~= false then
		Util.realStuds(p)
	end
	p.Parent = parent
	return p
end

function Util.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Util.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Destroy an existing child (so builders can be re-run safely) and return a fresh container.
function Util.fresh(parent, name, className)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className or "Model")
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- An invisible, non-colliding marker part for scripts (zones, spawn points).
function Util.marker(parent, name, size, cframe)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = true
	p.Transparency = 1
	p.Size = size
	p.CFrame = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe
	p.Parent = parent
	return p
end

-- Blocky tree: trunk plus stacked, slightly rotated leaf cubes.
function Util.tree(parent, base, scale, rng, palette)
	scale = scale or 1
	local m = Util.model(parent, "Tree")
	local M = T.Map
	local trunkH = 7 * scale
	Util.block(
		m,
		"Trunk",
		Vector3.new(2, trunkH, 2) * Vector3.new(scale, 1, scale),
		base + Vector3.new(0, trunkH / 2, 0),
		M.Trunk,
		{ stud = 1 }
	)
	local leaves = palette or { M.Leaf, M.LeafLight, M.LeafDeep }
	local y = base.Y + trunkH
	local s = 8 * scale
	for i = 1, 3 do
		local yaw = math.rad(rng:NextInteger(0, 45))
		local off = Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8)) * scale
		local size = Vector3.new(s, s * 0.7, s)
		Util.block(
			m,
			"Leaves",
			size,
			CFrame.new(base.X + off.X, y + size.Y / 2 - 1, base.Z + off.Z) * CFrame.Angles(0, yaw, 0),
			leaves[(i - 1) % 3 + 1],
			{ stud = 2 }
		)
		y += size.Y * 0.7
		s *= 0.72
	end
	return m
end

-- Cluster of tiny 1-stud flowers on top of a surface.
function Util.flowers(parent, center, radius, count, rng)
	local m = Util.model(parent, "Flowers")
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius)
		local pos = center + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
		local colors = T.Map.Flowers
		Util.block(
			m,
			"Stem",
			Vector3.new(0.4, 1, 0.4),
			pos,
			T.Map.LeafDeep,
			{ stud = false, collide = false, shadow = false }
		)
		Util.block(
			m,
			"Bloom",
			Vector3.new(1, 0.6, 1),
			pos + Vector3.new(0, 0.7, 0),
			colors[rng:NextInteger(1, #colors)],
			{ stud = 1, collide = false, shadow = false }
		)
	end
	return m
end

-- Text on a SurfaceGui, used for signs and boards.
function Util.surfaceText(part, face, text, color, font, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 30
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.Font = font
	label.TextScaled = true
	label.Parent = gui
	return gui, label
end

-- Floating world label with gradient text (crate names, SHOP, etc).
function Util.billboard(adornee, text, top, bottom, offsetY, width, height)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromScale(width or 14, height or 3)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 5, 0)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Adornee = adornee
	bb.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = T.UI.Font.Display
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = bb
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(top, bottom)
	grad.Rotation = 90
	grad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(28, 22, 52)
	stroke.Parent = label
	return bb
end

-- Small glowing lantern on a post.
function Util.lantern(parent, base, height)
	height = height or 6
	local m = Util.model(parent, "Lantern")
	Util.block(
		m,
		"Post",
		Vector3.new(0.6, height, 0.6),
		base + Vector3.new(0, height / 2, 0),
		T.Map.WoodDark,
		{ stud = false }
	)
	Util.block(
		m,
		"Cap",
		Vector3.new(1.8, 0.4, 1.8),
		base + Vector3.new(0, height + 1.9, 0),
		T.Map.WoodDark,
		{ stud = 1 }
	)
	local lamp = Util.block(
		m,
		"Lamp",
		Vector3.new(1.3, 1.6, 1.3),
		base + Vector3.new(0, height + 0.9, 0),
		T.Map.Lantern,
		{ material = Enum.Material.Neon }
	)
	local light = Instance.new("PointLight")
	light.Color = T.Map.Lantern
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lamp
	return m
end

return Util
