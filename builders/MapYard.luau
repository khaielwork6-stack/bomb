-- The launch map "The Fireworks Yard" (Asset Bible §4.2, 2026-10-17 first pass): the loading yard of an old
-- fireworks factory on the coast at golden hour.
--   • the field (the yard): weathered concrete slabs with expansion joints, grime, oil stains and chalk marks, four
--     painted hazard lanes (they light up for the Field Fuse — YardController), the painted bomb roundel at centre;
--   • the Safe Strips (the loading docks): pale concrete with a hazard edge and a green floodlight strip, "SAFE"
--     stencilled, a cantilevered canopy with floodlights, the warehouse behind (brick, roll-up shutters, one open on
--     a lit interior), sandbag walls at the ends;
--   • both long sides: steel gutters carrying the Field Fuse cords (a spark races along them — YardController);
--   • far side (−Z): the factory — brick, lit windows, a sawtooth roof, the neon "FUSE VALLEY FIREWORKS Co." sign,
--     two chimneys glowing and smoking, a yellow gantry crane hung with bunting, a water tower, hills behind;
--   • near side (+Z, the lobby's side, kept low): a railing under string lights, crates and pallets, the quay.
-- Cover on the field: four waist-high firework crates and two hand-trucks (BotService steers round `Cover` parts).
-- Gameplay contract: StartLine / FinishLine, Zones (StartZone / FinishZone / Field). The field is 140 × 90 between
-- the lines, the docks 14 deep (GDD §6, [TUNE]). Built at TOP = 10 (Arena drops every map 6 at runtime).
-- Every texture is in-house (art/yard/make_textures.py, art/vfx/make_vfx.py).

local rgb = Color3.fromRGB

local TEX = {
	Grime = "rbxassetid://93799948708188",
	Oil = "rbxassetid://82471392661454",
	Chalk = "rbxassetid://109155774330745",
	Hazard = "rbxassetid://71476708809896",
	Emblem = "rbxassetid://83865739495931",
	Smoke = "rbxassetid://98967284678053",
	Ember = "rbxassetid://135076496021372",
}

local C = {
	Ink = rgb(22, 18, 28),
	Paper = rgb(255, 243, 226),
	Fuse = rgb(255, 106, 31),
	Ember = rgb(255, 148, 66),
	Spark = rgb(255, 216, 74),
	Gold = rgb(242, 177, 58),
	Safe = rgb(59, 228, 140),
	Bomber = rgb(255, 74, 46),
	Runner = rgb(47, 211, 255),
	Concrete = rgb(170, 162, 150),
	Joint = rgb(58, 54, 50),
	Dock = rgb(190, 184, 172),
	Asphalt = rgb(70, 68, 72),
	Kerb = rgb(196, 190, 178),
	Brick = rgb(156, 80, 60),
	BrickDark = rgb(118, 58, 44),
	Stone = rgb(232, 218, 194),
	Steel = rgb(66, 70, 80),
	SteelLight = rgb(128, 134, 146),
	Shutter = rgb(78, 122, 140),
	Crane = rgb(244, 182, 42),
	Wood = rgb(182, 128, 78),
	WoodDark = rgb(116, 78, 48),
	Cord = rgb(217, 185, 138),
	Canvas = rgb(186, 160, 112),
	Grass = rgb(118, 150, 76),
	GrassDark = rgb(92, 124, 62),
	Window = rgb(255, 168, 86),
	Rubber = rgb(34, 32, 36),
	Water = rgb(70, 120, 150),
}

local M = Enum.Material

return function(ctx, parent)
	local U = ctx.req("Util").init(ctx.req("Theme"))
	parent = parent or workspace:FindFirstChild("Maps") or U.folder(workspace, "Maps")
	local map = U.fresh(parent, "Yard")
	map:SetAttribute("DisplayName", "THE FIREWORKS YARD")
	local rng = Random.new(1017)

	local TOP = 10
	local HL = 70 -- half the field's length (centre → each line)
	local HW = 45 -- half the field's width
	local DOCK = 14 -- dock (Safe Strip) depth
	local WALL = HL + DOCK + 1 -- the warehouse facades (Arena's back walls sit here)

	-- ── Part helpers (no stud textures: this map is material-rich, Asset Bible §2.2) ──────────────────────────
	local function part(p, n, size: Vector3, at, color: Color3, mat, o)
		o = o or {}
		local x = Instance.new(o.class or "Part")
		x.Name = n
		x.Anchored = true
		x.Size = size
		x.CFrame = if typeof(at) == "Vector3" then CFrame.new(at) else at
		x.Color = color
		x.Material = mat or M.SmoothPlastic
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		if o.shape then
			x.Shape = o.shape
		end
		if o.t then
			x.Transparency = o.t
		end
		if o.deco then -- decoration: never in the way
			x.CanCollide = false
			x.CanQuery = false
			x.CanTouch = false
		end
		if o.shadow == false then
			x.CastShadow = false
		end
		if o.reflect then
			x.Reflectance = o.reflect
		end
		x.Parent = p
		return x
	end
	local function deco(p, n, size, at, color, mat, o)
		o = table.clone(o or {})
		o.deco = true
		return part(p, n, size, at, color, mat, o)
	end
	-- A cylinder between two points.
	local function rod(p, n, a: Vector3, b: Vector3, d: number, color, mat, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Cylinder
		local dir = b - a
		return part(
			p,
			n,
			Vector3.new(dir.Magnitude, d, d),
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			color,
			mat,
			o
		)
	end
	local function ball(p, n, at: Vector3, d: number, color, mat, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Ball
		return part(p, n, Vector3.one * d, at, color, mat, o)
	end
	-- An ellipsoid (sandbags, hills, rounded loads): a block rendered as a stretched sphere.
	local function blob(p, n, size: Vector3, at, color, mat, o)
		local x = part(p, n, size, at, color, mat, o)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = x
		return x
	end
	local function wedge(p, n, size, cf, color, mat, o)
		o = table.clone(o or {})
		o.class = "WedgePart"
		return part(p, n, size, cf, color, mat, o)
	end
	local function glow(p, n, size, at, color, o)
		o = table.clone(o or {})
		o.shadow = false
		return deco(p, n, size, at, color, M.Neon, o)
	end
	local function light(x: Instance, color: Color3, range: number, brightness: number?, kind: string?, face)
		local l = Instance.new(kind or "PointLight") :: any
		l.Color = color
		l.Range = range
		l.Brightness = brightness or 1
		l.Shadows = false -- dozens of lights: shadows only from the sun (mobile budget)
		if face then
			l.Face = face
		end
		if kind == "SpotLight" then
			l.Angle = 70
		end
		l.Parent = x
		return l
	end
	local function texture(x: BasePart, face, id: string, tile: number, o)
		o = o or {}
		local t = Instance.new("Texture")
		t.Texture = id
		t.Face = face
		t.StudsPerTileU = tile
		t.StudsPerTileV = o.tileV or tile
		t.OffsetStudsU = o.u or 0
		t.OffsetStudsV = o.v or 0
		t.Transparency = o.t or 0
		if o.color then
			t.Color3 = o.color
		end
		t.Parent = x
		return t
	end
	-- A flat decal lying on the floor (oil, chalk, paint): a hairline part above the surface.
	local function floorDecal(p, n, id: string, w: number, d: number, at: Vector3, yaw: number, lift: number, o)
		o = o or {}
		local x = deco(
			p,
			n,
			Vector3.new(w, 0.02, d),
			CFrame.new(at.X, TOP + lift, at.Z) * CFrame.Angles(0, yaw, 0),
			C.Ink,
			M.SmoothPlastic,
			{ t = 1, shadow = false }
		)
		local dc = Instance.new("Decal")
		dc.Texture = id
		dc.Face = Enum.NormalId.Top
		dc.Transparency = o.t or 0
		if o.color then
			dc.Color3 = o.color
		end
		dc.Parent = x
		return x
	end
	local HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	local DISPLAY = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	local function label(x: BasePart, face, text: string, color: Color3, o)
		o = o or {}
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = o.pps or 24
		g.LightInfluence = o.lit or 1
		g.Brightness = o.brightness or 1
		g.Parent = x
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		local pad = o.pad or 0
		l.Size = UDim2.fromScale(1 - pad * 2, 1 - pad * 2)
		l.Position = UDim2.fromScale(pad, pad)
		l.Text = text
		l.TextColor3 = color
		l.FontFace = o.font or DISPLAY
		l.TextScaled = true
		l.TextTransparency = o.t or 0
		l.Rotation = o.rot or 0
		l.Parent = g
		if o.stroke then
			local s = Instance.new("UIStroke")
			s.Color = o.stroke
			s.Thickness = o.strokeT or 3
			s.Parent = l
		end
		return g, l
	end
	-- A sagging line of points between a and b (string lights, bunting ropes).
	local function sag(a: Vector3, b: Vector3, droop: number, n: number)
		local pts = {}
		for i = 0, n do
			local t = i / n
			table.insert(pts, a:Lerp(b, t) - Vector3.new(0, droop * 4 * t * (1 - t), 0))
		end
		return pts
	end

	-- ── The ground: a coastal landmass of asphalt, kerbs and grass ────────────────────────────────────────────
	local ground = U.model(map, "Ground")
	local GX0, GX1, GZ0, GZ1 = -190, 190, -180, 78
	part(
		ground,
		"Bedrock",
		Vector3.new(GX1 - GX0, 18, GZ1 - GZ0),
		Vector3.new(0, TOP - 1.1 - 9, (GZ0 + GZ1) / 2),
		rgb(112, 104, 96),
		M.Rock
	)
	-- Asphalt apron round the yard (a hair under the field so the slabs read as a raised pad), in four pieces
	-- round the yard + gutters so the gutters stay open.
	local AX, AZ = HL + DOCK + 1, HW + 2.4
	for _, r in ipairs({
		{ GX0, GX1, AZ, GZ1 - 2 },
		{ GX0, GX1, GZ0, -AZ },
		{ GX0, -AX, -AZ, AZ },
		{ AX, GX1, -AZ, AZ },
	}) do
		local apron = part(
			ground,
			"Apron",
			Vector3.new(r[2] - r[1], 1, r[4] - r[3]),
			Vector3.new((r[1] + r[2]) / 2, TOP - 0.62, (r[3] + r[4]) / 2),
			C.Asphalt,
			M.Asphalt
		)
		texture(apron, Enum.NormalId.Top, TEX.Grime, 34, { t = 0.35 })
	end
	-- Painted bays and arrows on the apron (dull, worn: the yard's own paint is the bright stuff)
	for i = -3, 3 do
		deco(
			ground,
			"BayLine",
			Vector3.new(0.4, 0.04, 9),
			Vector3.new(i * 14 - 4, TOP - 0.1, 62),
			rgb(214, 204, 176),
			M.SmoothPlastic,
			{ t = 0.25, shadow = false }
		)
	end
	-- The sea wall on the near side and the rock edge round the rest (stepped stone blocks).
	local edge = U.folder(ground, "Edge")
	for x = GX0, GX1 - 1, 12 do
		local h = TOP + 5 + rng:NextNumber(-1.5, 1.5)
		part(
			edge,
			"QuayStone",
			Vector3.new(12.2, h, 3),
			Vector3.new(x + 6, (TOP - 0.1) - h / 2 + 0.6, GZ1 - 0.2),
			rgb(150, 140, 126):Lerp(rgb(110, 102, 94), rng:NextNumber()),
			M.Slate
		)
	end
	for x = GX0 + 10, GX1 - 10, 22 do -- bollards with mooring rope coils
		rod(
			edge,
			"Bollard",
			Vector3.new(x, TOP - 0.2, GZ1 - 1.4),
			Vector3.new(x, TOP + 1.3, GZ1 - 1.4),
			1.1,
			C.Steel,
			M.Metal
		)
		ball(edge, "BollardCap", Vector3.new(x, TOP + 1.3, GZ1 - 1.4), 1.3, C.Steel, M.Metal)
	end
	for x = GX0 + 21, GX1 - 21, 44 do -- old tyres hung as fenders
		local t = rod(
			edge,
			"Fender",
			Vector3.new(x, TOP - 2.6, GZ1 + 1.4),
			Vector3.new(x, TOP - 2.6, GZ1 + 2.1),
			2.4,
			C.Rubber,
			M.Rubber,
			{ deco = true }
		)
		t.CastShadow = false
	end
	-- Grass verges and hills behind the factory (the horizon reads warm, not blocky).
	local hills = U.folder(map, "Hills")
	for i, h in ipairs({
		{ -150, -240, 170, 46 },
		{ -20, -270, 220, 60 },
		{ 130, -235, 180, 42 },
		{ 230, -150, 120, 34 },
		{ -235, -140, 120, 30 },
		{ 60, -320, 260, 80 },
	}) do
		blob(
			hills,
			"Hill",
			Vector3.new(h[3], h[4] * 2, h[3] * 0.7),
			Vector3.new(h[1], TOP - 8, h[2]),
			if i % 2 == 0 then C.Grass else C.GrassDark,
			M.Grass,
			{ shadow = false }
		)
	end
	part(ground, "Verge", Vector3.new(GX1 - GX0, 1, 40), Vector3.new(0, TOP - 0.5, GZ0 + 20), C.GrassDark, M.Grass)

	-- ── The yard (the field): concrete slabs with joints ──────────────────────────────────────────────────────
	local yard = U.model(map, "Yard")
	part(
		yard,
		"JointBed",
		Vector3.new(HL * 2, 1.6, HW * 2),
		Vector3.new(0, TOP - 0.25 - 0.8, 0),
		C.Joint,
		M.SmoothPlastic
	)
	local SLAB = 10
	for ix = 0, HL * 2 / SLAB - 1 do
		for iz = 0, HW * 2 / SLAB - 1 do
			local cx, cz = -HL + (ix + 0.5) * SLAB, -HW + (iz + 0.5) * SLAB
			local v = rng:NextNumber(-0.05, 0.05)
			local tone = if v >= 0
				then C.Concrete:Lerp(rgb(214, 206, 192), v * 2)
				else C.Concrete:Lerp(rgb(96, 90, 84), -v * 2)
			local s = part(
				yard,
				"Slab",
				Vector3.new(SLAB - 0.22, 2, SLAB - 0.22),
				Vector3.new(cx, TOP - 1, cz),
				tone,
				M.Concrete
			)
			-- every slab gets the grime at its own offset, so the tiling never lines up
			texture(
				s,
				Enum.NormalId.Top,
				TEX.Grime,
				26,
				{ u = rng:NextNumber(0, 26), v = rng:NextNumber(0, 26), t = 0.08 }
			)
		end
	end
	local marks = U.folder(yard, "Marks")
	floorDecal(marks, "Roundel", TEX.Emblem, 26, 26, Vector3.new(0, 0, 0), math.rad(90), 0.03)
	for _ = 1, 9 do
		local at = Vector3.new(rng:NextNumber(-HL + 6, HL - 6), 0, rng:NextNumber(-HW + 5, HW - 5))
		if math.abs(at.X) > 16 or math.abs(at.Z) > 16 then
			local s = rng:NextNumber(3.5, 7)
			floorDecal(marks, "Oil", TEX.Oil, s, s, at, rng:NextNumber(0, math.pi * 2), 0.025, { t = 0.1 })
		end
	end
	for _, c in ipairs({ { -58, -30, 0.2 }, { 54, 34, -2.6 }, { -12, 36, 0.05 }, { 30, -38, 3.0 } }) do
		floorDecal(marks, "Chalk", TEX.Chalk, 9, 4.5, Vector3.new(c[1], 0, c[2]), c[3], 0.026, { t = 0.15 })
	end

	-- Hazard lanes across the yard (YardController pulses their Glow for the Field Fuse, then flashes them in order).
	local lanes = U.folder(map, "HazardLanes")
	for i, x in ipairs({ -46.5, -23.25, 23.25, 46.5 }) do
		local lane = deco(
			lanes,
			"Lane",
			Vector3.new(2.6, 0.03, HW * 2 - 1),
			Vector3.new(x, TOP + 0.02, 0),
			C.Ink,
			M.SmoothPlastic,
			{ t = 1, shadow = false }
		)
		texture(lane, Enum.NormalId.Top, TEX.Hazard, 2.6)
		local g = glow(
			lanes,
			"LaneGlow",
			Vector3.new(2.6, 0.03, HW * 2 - 1),
			Vector3.new(x, TOP + 0.035, 0),
			C.Bomber,
			{ t = 1 }
		)
		g:SetAttribute("Lane", i)
		g:SetAttribute("X", x)
	end

	-- ── Long sides: steel gutters carrying the Field Fuse cords, then kerbs ──────────────────────────────────
	local cords = U.folder(map, "FuseCords")
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (HW + 1.2)
		part(yard, "GutterBed", Vector3.new(WALL * 2, 1, 2.4), Vector3.new(0, TOP - 1.1, z), rgb(40, 38, 42), M.Metal)
		for _, lip in ipairs({ -1.1, 1.1 }) do
			part(
				yard,
				"GutterLip",
				Vector3.new(WALL * 2, 0.6, 0.3),
				Vector3.new(0, TOP - 0.3, z + lip),
				C.SteelLight,
				M.DiamondPlate
			)
		end
		for x = -WALL + 4, WALL - 4, 8 do -- cord saddles
			deco(yard, "Saddle", Vector3.new(0.4, 0.8, 2.0), Vector3.new(x, TOP - 0.55, z), C.Steel, M.Metal)
		end
		local cord = rod(
			cords,
			"Cord",
			Vector3.new(-WALL, TOP - 0.45, z),
			Vector3.new(WALL, TOP - 0.45, z),
			0.75,
			C.Cord,
			M.Fabric,
			{ deco = true }
		)
		cord:SetAttribute("Side", s)
		local kz = s * (HW + 3.4)
		part(yard, "Kerb", Vector3.new(WALL * 2 + 4, 0.9, 2), Vector3.new(0, TOP - 0.05, kz), C.Kerb, M.Concrete)
		local stripe = deco(
			yard,
			"KerbPaint",
			Vector3.new(WALL * 2 + 4, 0.92, 0.6),
			Vector3.new(0, TOP - 0.05, kz + s * 0.71),
			C.Ink,
			M.SmoothPlastic,
			{ t = 1 }
		)
		texture(stripe, if s < 0 then Enum.NormalId.Back else Enum.NormalId.Front, TEX.Hazard, 1.8)
	end

	-- ── The gameplay contract ──────────────────────────────────────────────────────────────────────────────────
	for n, x in pairs({ StartLine = -HL, FinishLine = HL }) do
		local p = deco(
			map,
			n,
			Vector3.new(1, 0.05, HW * 2),
			Vector3.new(x, TOP + 0.01, 0),
			C.Paper,
			M.SmoothPlastic,
			{ t = 1 }
		)
		p.CanQuery = false
	end
	local zones = U.folder(map, "Zones")
	U.marker(zones, "StartZone", Vector3.new(DOCK, 12, HW * 2), Vector3.new(-HL - DOCK / 2, TOP + 6, 0))
	U.marker(zones, "FinishZone", Vector3.new(DOCK, 12, HW * 2), Vector3.new(HL + DOCK / 2, TOP + 6, 0))
	U.marker(zones, "Field", Vector3.new(HL * 2, 12, HW * 2), Vector3.new(0, TOP + 6, 0))

	-- ── The docks (Safe Strips) and the warehouses behind ────────────────────────────────────────────────────
	local function dockEnd(s: number)
		local dock = U.model(map, if s < 0 then "DockA" else "DockB")
		local inner = s * HL -- the safe line
		local cx = s * (HL + DOCK / 2)
		-- the dock floor: smooth pale concrete, power-floated
		local floor =
			part(dock, "DockFloor", Vector3.new(DOCK, 2, HW * 2 + 12), Vector3.new(cx, TOP - 1, 0), C.Dock, M.Concrete)
		texture(floor, Enum.NormalId.Top, TEX.Grime, 30, { t = 0.3, u = s * 7 })
		-- the safe edge: a painted hazard band, then the green floodlight strip (the line Runners aim for)
		local band = deco(
			dock,
			"EdgeBand",
			Vector3.new(1.4, 0.03, HW * 2),
			Vector3.new(inner + s * 0.7, TOP + 0.02, 0),
			C.Ink,
			M.SmoothPlastic,
			{ t = 1, shadow = false }
		)
		texture(band, Enum.NormalId.Top, TEX.Hazard, 1.4)
		local strip = glow(
			dock,
			"SafeStrip",
			Vector3.new(0.35, 0.06, HW * 2),
			Vector3.new(inner + s * 1.6, TOP + 0.03, 0),
			C.Safe
		)
		for z = -HW + 8, HW - 8, 16 do
			light(
				deco(
					dock,
					"StripLight",
					Vector3.new(0.2, 0.2, 0.2),
					Vector3.new(inner + s * 1.6, TOP + 0.4, z),
					C.Safe,
					M.SmoothPlastic,
					{ t = 1 }
				),
				C.Safe,
				9,
				0.9
			)
		end
		strip:SetAttribute("SafeStrip", s)
		-- "SAFE" stencilled on the dock, upright for a Runner coming in
		local stencil = deco(
			dock,
			"Stencil",
			Vector3.new(7, 0.03, 30),
			CFrame.fromMatrix(Vector3.new(cx + s * 0.5, TOP + 0.025, 0), Vector3.new(-s, 0, 0), Vector3.yAxis),
			C.Ink,
			M.SmoothPlastic,
			{ t = 1, shadow = false }
		)
		label(stencil, Enum.NormalId.Top, "SAFE", C.Safe, { pps = 14, t = 0.08, rot = 0 })
		for _, z in ipairs({ -30, 30 }) do
			local arrow = deco(
				dock,
				"ArrowPaint",
				Vector3.new(4, 0.03, 6),
				CFrame.fromMatrix(Vector3.new(cx - s * 2, TOP + 0.025, z), Vector3.new(-s, 0, 0), Vector3.yAxis),
				C.Ink,
				M.SmoothPlastic,
				{ t = 1, shadow = false }
			)
			label(arrow, Enum.NormalId.Top, "▲", C.Paper, { pps = 12, t = 0.25, rot = -90 })
		end
		-- sandbag walls at the dock's ends (decoration; the side walls do the blocking)
		for _, zs in ipairs({ -1, 1 }) do
			local z0 = zs * (HW + 2.2)
			for row = 0, 2 do
				local n = 6 - row
				for i = 0, n - 1 do
					local x = cx + (i - (n - 1) / 2) * 2.15 + (row % 2) * 0.5
					blob(
						dock,
						"Sandbag",
						Vector3.new(2.3, 0.95, 1.3),
						CFrame.new(x, TOP + 0.45 + row * 0.82, z0 + zs * row * 0.15)
							* CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.05, 0.05)),
						C.Canvas:Lerp(rgb(150, 126, 86), rng:NextNumber()),
						M.Fabric,
						{ deco = true }
					)
				end
			end
		end

		-- the warehouse facade
		local wh = U.model(dock, "Warehouse")
		local fx = s * WALL -- the facade plane
		local depth = 22
		local wx = fx + s * depth / 2
		local L = HW * 2 + 36
		-- the mass sits 10 back; a 1-stud front wall (piers between the doors) and the upper storey make the facade,
		-- so the open door shows a real room
		part(wh, "Upper", Vector3.new(depth, 10, L), Vector3.new(wx, TOP + 17, 0), C.Brick, M.Brick)
		part(
			wh,
			"Mass",
			Vector3.new(depth - 10, 12, L),
			Vector3.new(fx + s * (10 + (depth - 10) / 2), TOP + 6, 0),
			C.Brick,
			M.Brick
		)
		for _, seg in ipairs({ { -L / 2, -39 }, { -25, -7 }, { 7, 25 }, { 39, L / 2 } }) do
			part(
				wh,
				"Pier",
				Vector3.new(1, 12, seg[2] - seg[1]),
				Vector3.new(fx + s * 0.5, TOP + 6, (seg[1] + seg[2]) / 2),
				C.Brick,
				M.Brick
			)
			deco(
				wh,
				"PierPlinth",
				Vector3.new(1.4, 1.4, seg[2] - seg[1]),
				Vector3.new(fx + s * 0.5, TOP + 0.7, (seg[1] + seg[2]) / 2),
				C.BrickDark,
				M.Concrete
			)
		end
		part(wh, "Band", Vector3.new(depth + 0.8, 0.8, L + 0.8), Vector3.new(wx, TOP + 14.6, 0), C.Stone, M.Slate)
		-- corrugated cladding above the band: vertical ribs in painted steel
		part(
			wh,
			"Cladding",
			Vector3.new(depth + 0.2, 7.2, L + 0.2),
			Vector3.new(wx, TOP + 18.6, 0),
			C.Shutter:Lerp(C.Steel, 0.35),
			M.CorrodedMetal
		)
		for z = -L / 2 + 1, L / 2 - 1, 1.6 do
			deco(
				wh,
				"Rib",
				Vector3.new(0.25, 7.2, 0.5),
				Vector3.new(fx + s * -0.05, TOP + 18.6, z),
				C.Shutter:Lerp(C.SteelLight, 0.3),
				M.Metal
			)
		end
		part(wh, "Coping", Vector3.new(depth + 1.2, 0.8, L + 1.2), Vector3.new(wx, TOP + 22.4, 0), C.Steel, M.Metal)
		local sign = deco(
			wh,
			"DockSign",
			Vector3.new(0.3, 3.4, 16),
			Vector3.new(fx - s * 0.2, TOP + 18.4, 0),
			C.Ink,
			M.SmoothPlastic
		)
		label(
			sign,
			if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left,
			if s < 0 then "DOCK A" else "DOCK B",
			C.Paper,
			{ pps = 20, stroke = C.Ink }
		)
		-- the roll-up shutter doors (the middle one rolled up on a lit, stacked interior)
		for di, z in ipairs({ -32, 0, 32 }) do
			local open = di == 2
			local W, H = 14, 11
			part(
				wh,
				"DoorFrameL",
				Vector3.new(1.4, H + 1, 1),
				Vector3.new(fx - s * 0.3, TOP + (H + 1) / 2, z - W / 2 - 0.7),
				C.Fuse,
				M.Metal
			)
			part(
				wh,
				"DoorFrameR",
				Vector3.new(1.4, H + 1, 1),
				Vector3.new(fx - s * 0.3, TOP + (H + 1) / 2, z + W / 2 + 0.7),
				C.Fuse,
				M.Metal
			)
			part(
				wh,
				"DoorHead",
				Vector3.new(1.6, 1.4, W + 2.8),
				Vector3.new(fx - s * 0.3, TOP + H + 0.7, z),
				C.Fuse,
				M.Metal
			)
			part(wh, "RollBox", Vector3.new(1.6, 1.6, W), Vector3.new(fx - s * 0.9, TOP + H + 0.4, z), C.Steel, M.Metal)
			if open then
				-- the doorway: a lit room with stacked crates (side walls, a dark back wall)
				for _, wz in ipairs({ -1, 1 }) do
					deco(
						wh,
						"InsideWall",
						Vector3.new(10, 12, 0.6),
						Vector3.new(fx + s * 5, TOP + 6, z + wz * (W / 2 + 0.3)),
						C.BrickDark,
						M.Brick
					)
				end
				deco(
					wh,
					"InsideBack",
					Vector3.new(0.2, 12, W),
					Vector3.new(fx + s * 9.85, TOP + 6, z),
					rgb(52, 40, 38),
					M.Brick
				)
				deco(
					wh,
					"InsideFloor",
					Vector3.new(8, 0.2, W),
					Vector3.new(fx + s * 4, TOP + 0.1, z),
					C.Dock,
					M.Concrete
				)
				local lamp = glow(
					wh,
					"InsideLamp",
					Vector3.new(0.4, 0.3, W - 2),
					Vector3.new(fx + s * 3, TOP + H - 0.6, z),
					C.Window
				)
				light(lamp, C.Window, 18, 2.2)
				for k = 0, 5 do
					local cz = z - W / 2 + 1.8 + (k % 3) * 4.2
					local cy = TOP + 1.3 + math.floor(k / 3) * 2.7
					local crate = deco(
						wh,
						"InsideCrate",
						Vector3.new(2.6, 2.5, 3.6),
						Vector3.new(fx + s * 3.6, cy, cz),
						C.Wood:Lerp(C.WoodDark, rng:NextNumber(0, 0.5)),
						M.WoodPlanks
					)
					crate.CastShadow = false
				end
				part(
					wh,
					"Shutter",
					Vector3.new(0.4, 1.4, W),
					Vector3.new(fx - s * 0.4, TOP + H - 0.5, z),
					C.Shutter,
					M.Metal
				)
			else
				for k = 0, 10 do -- the slats
					part(
						wh,
						"Slat",
						Vector3.new(0.35, 0.95, W),
						Vector3.new(fx - s * 0.35, TOP + 0.5 + k * 1, z),
						C.Shutter:Lerp(C.Steel, (k % 2) * 0.12),
						M.CorrodedMetal
					)
				end
				part(
					wh,
					"Handle",
					Vector3.new(0.4, 0.3, 2),
					Vector3.new(fx - s * 0.6, TOP + 1.2, z),
					C.SteelLight,
					M.Metal
				)
			end
			-- rubber dock bumpers either side of the door (black / yellow)
			for _, side in ipairs({ -1, 1 }) do
				local bz = z + side * (W / 2 + 2.2)
				part(
					wh,
					"Bumper",
					Vector3.new(1.0, 2.2, 1.6),
					Vector3.new(fx - s * 0.6, TOP + 1.6, bz),
					C.Rubber,
					M.Rubber
				)
				deco(
					wh,
					"BumperStripe",
					Vector3.new(1.02, 0.4, 1.62),
					Vector3.new(fx - s * 0.6, TOP + 2.1, bz),
					C.Spark,
					M.SmoothPlastic
				)
			end
		end
		-- the cantilevered canopy over the dock: steel beams braced to the wall, corrugated sheet, floodlights
		local canopy = U.model(dock, "Canopy")
		local reach = DOCK - 1.5
		local cy0, cy1 = TOP + 16.2, TOP + 15.2 -- at the wall, at the tip
		for z = -HW - 6, HW + 6, 12 do
			local a = Vector3.new(fx, cy0, z)
			local b = Vector3.new(fx - s * reach, cy1, z)
			part(
				canopy,
				"Beam",
				Vector3.new(reach, 0.8, 0.5),
				CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
				C.Steel,
				M.Metal,
				{ deco = true }
			)
			rod(
				canopy,
				"Brace",
				Vector3.new(fx, TOP + 11.5, z),
				Vector3.new(fx - s * reach * 0.6, cy0 - 0.6 - (cy0 - cy1) * 0.6, z),
				0.35,
				C.Steel,
				M.Metal,
				{ deco = true }
			)
		end
		local sheet = part(
			canopy,
			"Roof",
			Vector3.new(reach + 0.6, 0.25, HW * 2 + 14),
			CFrame.new(fx - s * reach / 2, (cy0 + cy1) / 2 + 0.5, 0)
				* CFrame.Angles(0, 0, s * math.atan((cy0 - cy1) / reach)),
			C.SteelLight:Lerp(C.Paper, 0.15),
			M.CorrodedMetal,
			{ deco = true }
		)
		sheet.CastShadow = true
		deco(
			canopy,
			"Fascia",
			Vector3.new(0.3, 1.1, HW * 2 + 14),
			Vector3.new(fx - s * (reach + 0.15), cy1 + 0.35, 0),
			C.Fuse,
			M.Metal
		)
		for z = -HW + 6, HW - 6, 14 do
			local lamp = deco(
				canopy,
				"Floodlight",
				Vector3.new(0.9, 0.7, 1.4),
				CFrame.new(fx - s * (reach - 0.6), cy1 - 0.4, z) * CFrame.Angles(0, 0, s * math.rad(35)),
				C.Steel,
				M.Metal
			)
			local lens = glow(
				canopy,
				"Lens",
				Vector3.new(0.1, 0.5, 1.1),
				lamp.CFrame * CFrame.new(-s * 0.47, 0, 0),
				rgb(255, 236, 200)
			)
			local spot = light(
				lens,
				rgb(255, 222, 176),
				34,
				1.6,
				"SpotLight",
				if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left
			)
			spot.Angle = 80
		end
	end
	dockEnd(-1)
	dockEnd(1)

	-- ── The factory (far side, −Z) ───────────────────────────────────────────────────────────────────────────
	local factory = U.model(map, "Factory")
	local FZ = -HW - 13 -- the facade plane
	local FD = 34 -- depth
	local FW = 210 -- width
	local FH = 24
	local fzc = FZ - FD / 2
	part(factory, "Body", Vector3.new(FW, FH, FD), Vector3.new(0, TOP + FH / 2, fzc), C.Brick, M.Brick)
	part(factory, "Plinth", Vector3.new(FW + 0.6, 2, FD + 0.6), Vector3.new(0, TOP + 1, fzc), C.BrickDark, M.Concrete)
	for _, y in ipairs({ 11.4, FH - 0.5 }) do
		part(factory, "Cornice", Vector3.new(FW + 1.2, 1, FD + 1.2), Vector3.new(0, TOP + y, fzc), C.Stone, M.Slate)
	end
	-- pilasters and two storeys of tall lit windows
	local bays = 15
	local bw = FW / bays
	for i = 0, bays - 1 do
		local x = -FW / 2 + (i + 0.5) * bw
		deco(
			factory,
			"Pilaster",
			Vector3.new(1.6, FH - 2, 0.8),
			Vector3.new(-FW / 2 + i * bw, TOP + FH / 2, FZ + 0.4),
			C.BrickDark,
			M.Brick
		)
		for _, row in ipairs({ { 2.8, 7.2 }, { 13.2, 8.4 } }) do
			local y0, h = row[1], row[2]
			local w = bw - 5
			deco(
				factory,
				"Reveal",
				Vector3.new(w + 1.2, h + 1.2, 0.4),
				Vector3.new(x, TOP + y0 + h / 2, FZ + 0.15),
				C.Stone,
				M.Slate
			)
			local pane = glow(
				factory,
				"Window",
				Vector3.new(w, h, 0.3),
				Vector3.new(x, TOP + y0 + h / 2, FZ + 0.3),
				C.Window,
				{ t = 0.32 }
			)
			if rng:NextNumber() < 0.35 then
				pane.Color = C.Window:Lerp(C.Ink, 0.55) -- a few dark rooms: lights off
			end
			for k = 1, 2 do -- mullions
				deco(
					factory,
					"Mullion",
					Vector3.new(0.25, h, 0.4),
					Vector3.new(x - w / 2 + k * w / 3, TOP + y0 + h / 2, FZ + 0.45),
					C.Ink,
					M.SmoothPlastic
				)
			end
			for k = 1, 2 do
				deco(
					factory,
					"Transom",
					Vector3.new(w, 0.25, 0.4),
					Vector3.new(x, TOP + y0 + k * h / 3, FZ + 0.45),
					C.Ink,
					M.SmoothPlastic
				)
			end
			deco(
				factory,
				"Lintel",
				Vector3.new(w + 1.6, 0.8, 0.7),
				Vector3.new(x, TOP + y0 + h + 0.4, FZ + 0.35),
				C.Stone,
				M.Slate
			)
			deco(
				factory,
				"Keystone",
				Vector3.new(1.2, 1.3, 0.8),
				Vector3.new(x, TOP + y0 + h + 0.55, FZ + 0.45),
				C.Stone,
				M.Slate
			)
		end
		if i % 3 == 1 then
			light(
				deco(
					factory,
					"WindowGlow",
					Vector3.new(0.2, 0.2, 0.2),
					Vector3.new(x, TOP + 8, FZ + 3),
					C.Window,
					M.SmoothPlastic,
					{ t = 1 }
				),
				C.Window,
				16,
				0.8
			)
		end
	end
	-- the sawtooth roof: north lights (glass to the back, steel to the front)
	local teeth = 14
	local tw = FW / teeth
	for i = 0, teeth - 1 do
		local x = -FW / 2 + (i + 0.5) * tw
		wedge(
			factory,
			"Saw",
			Vector3.new(FD - 4, 7, tw),
			CFrame.new(x, TOP + FH + 3.5, fzc) * CFrame.Angles(0, math.rad(-90), 0),
			C.Steel:Lerp(C.Shutter, 0.4),
			M.CorrodedMetal
		)
		glow(
			factory,
			"SawGlass",
			Vector3.new(0.3, 6.6, FD - 5),
			CFrame.new(x - tw / 2 + 0.25, TOP + FH + 3.4, fzc),
			rgb(150, 190, 200),
			{ t = 0.35 }
		)
	end
	-- the neon sign on a steel frame above the cornice
	local signFrame = U.model(factory, "Sign")
	local SY = TOP + FH + 9
	for _, x in ipairs({ -44, -15, 15, 44 }) do
		rod(
			signFrame,
			"SignLeg",
			Vector3.new(x, TOP + FH, FZ - 2),
			Vector3.new(x, SY + 5, FZ - 2),
			0.6,
			C.Steel,
			M.Metal,
			{ deco = true }
		)
		rod(
			signFrame,
			"SignStay",
			Vector3.new(x, TOP + FH, FZ - 8),
			Vector3.new(x, SY + 3, FZ - 2),
			0.4,
			C.Steel,
			M.Metal,
			{ deco = true }
		)
	end
	local board =
		deco(signFrame, "Board", Vector3.new(96, 11, 0.6), Vector3.new(0, SY, FZ - 1.4), C.Ink, M.SmoothPlastic)
	local _, txt = label(
		board,
		Enum.NormalId.Back,
		"FUSE VALLEY FIREWORKS Co.",
		C.Fuse,
		{ pps = 18, lit = 0, brightness = 3.2, stroke = rgb(120, 30, 10), strokeT = 2 }
	)
	txt.Size = UDim2.fromScale(0.94, 0.72)
	txt.Position = UDim2.fromScale(0.03, 0.14)
	light(board, C.Fuse, 40, 1.4, "SurfaceLight", Enum.NormalId.Back)
	for k = 0, 47 do -- marquee bulbs round the board
		local t = k / 48
		local px, py
		if t < 0.5 then
			px, py = -48 + t * 2 * 96, if k % 2 == 0 then 5.7 else 5.7
		else
			px, py = -48 + (t - 0.5) * 2 * 96, -5.7
		end
		ball(
			signFrame,
			"Bulb",
			Vector3.new(px, SY + py, FZ - 1.0),
			0.6,
			C.Spark,
			M.Neon,
			{ deco = true, shadow = false }
		)
	end
	-- two chimneys, glowing at the top and smoking
	for _, ch in ipairs({ { -62, 66 }, { 70, 58 } }) do
		local x, h = ch[1], ch[2]
		local z = fzc - 4
		part(
			factory,
			"Chimney",
			Vector3.new(7, h, 7),
			Vector3.new(x, TOP + h / 2, z),
			C.Brick:Lerp(C.BrickDark, 0.3),
			M.Brick
		)
		for _, y in ipairs({ h * 0.45, h * 0.72, h - 3 }) do
			part(factory, "ChimneyBand", Vector3.new(7.6, 0.9, 7.6), Vector3.new(x, TOP + y, z), C.Steel, M.Metal)
		end
		part(factory, "ChimneyCap", Vector3.new(8.4, 1.4, 8.4), Vector3.new(x, TOP + h + 0.7, z), C.Stone, M.Slate)
		local mouth =
			glow(factory, "ChimneyGlow", Vector3.new(5.2, 0.4, 5.2), Vector3.new(x, TOP + h + 1.3, z), C.Ember)
		light(mouth, C.Ember, 22, 2)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = TEX.Smoke
		smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		smoke.Color = ColorSequence.new(rgb(210, 196, 186), rgb(160, 150, 156))
		smoke.LightInfluence = 0.6
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 14) })
		smoke.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.5) })
		smoke.Lifetime = NumberRange.new(7, 9)
		smoke.Rate = 0.9
		smoke.Speed = NumberRange.new(4, 6)
		smoke.SpreadAngle = Vector2.new(8, 8)
		smoke.Acceleration = Vector3.new(3, 0.6, 1)
		smoke.Rotation = NumberRange.new(-30, 30)
		smoke.RotSpeed = NumberRange.new(-6, 6)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = mouth
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = TEX.Ember
		embers.Color = ColorSequence.new(C.Spark, C.Fuse)
		embers.LightEmission = 1
		embers.LightInfluence = 0
		embers.Size = NumberSequence.new(0.5, 0)
		embers.Lifetime = NumberRange.new(2, 3.5)
		embers.Rate = 5
		embers.Speed = NumberRange.new(5, 9)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.Acceleration = Vector3.new(2, -1, 0)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Parent = mouth
	end
	-- the strip between the gutter kerb and the factory: pallets, gas bottles, rocket crates
	local strip = U.folder(factory, "Strip")

	-- ── Props kit (part-built; Asset Bible §4.4) ─────────────────────────────────────────────────────────────
	local ROCKETS = { C.Bomber, C.Runner, C.Spark, C.Paper, rgb(176, 76, 255) }
	-- A firework crate: planked box with dark battens, rope handles, a stencilled label, rockets poking out.
	local function crate(into, cf: CFrame, size: Vector3, opts)
		opts = opts or {}
		local m = U.model(into, opts.name or "Crate")
		local body = part(m, "Body", size, cf, C.Wood:Lerp(C.WoodDark, rng:NextNumber(0, 0.35)), M.WoodPlanks)
		if opts.cover then
			body:SetAttribute("Cover", true)
		end
		local sx, sy, sz = size.X / 2, size.Y / 2, size.Z / 2
		for _, e in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do -- vertical corner battens
			deco(
				m,
				"Batten",
				Vector3.new(0.3, size.Y + 0.04, 0.3),
				cf * CFrame.new(e[1] * (sx - 0.1), 0, e[2] * (sz - 0.1)),
				C.WoodDark,
				M.Wood
			)
		end
		for _, y in ipairs({ -1, 1 }) do -- top and bottom rails
			deco(
				m,
				"Rail",
				Vector3.new(size.X + 0.06, 0.3, 0.3),
				cf * CFrame.new(0, y * (sy - 0.15), sz - 0.1),
				C.WoodDark,
				M.Wood
			)
			deco(
				m,
				"Rail",
				Vector3.new(size.X + 0.06, 0.3, 0.3),
				cf * CFrame.new(0, y * (sy - 0.15), -sz + 0.1),
				C.WoodDark,
				M.Wood
			)
			deco(
				m,
				"Rail",
				Vector3.new(0.3, 0.3, size.Z + 0.06),
				cf * CFrame.new(sx - 0.1, y * (sy - 0.15), 0),
				C.WoodDark,
				M.Wood
			)
			deco(
				m,
				"Rail",
				Vector3.new(0.3, 0.3, size.Z + 0.06),
				cf * CFrame.new(-sx + 0.1, y * (sy - 0.15), 0),
				C.WoodDark,
				M.Wood
			)
		end
		for _, side in ipairs({ -1, 1 }) do -- rope handles
			rod(
				m,
				"Handle",
				(cf * CFrame.new(side * (sx + 0.08), sy * 0.35, -0.5)).Position,
				(cf * CFrame.new(side * (sx + 0.08), sy * 0.35, 0.5)).Position,
				0.18,
				C.Cord,
				M.Fabric,
				{ deco = true }
			)
		end
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			label(body, face, "FIREWORKS\nHANDLE WITH CARE", C.Ink, { pps = 30, t = 0.18, font = HEAVY, pad = 0.1 })
		end
		if not opts.closed then -- rockets poking out of the open top
			for k = 1, opts.rockets or 4 do
				local off = Vector3.new(rng:NextNumber(-sx + 0.5, sx - 0.5), 0, rng:NextNumber(-sz + 0.5, sz - 0.5))
				local h = rng:NextNumber(0.8, 1.8)
				local col = ROCKETS[rng:NextInteger(1, #ROCKETS)]
				local base = (cf * CFrame.new(off.X, sy - 0.2, off.Z)).Position
				local tip = base + Vector3.new(rng:NextNumber(-0.15, 0.15), h, rng:NextNumber(-0.15, 0.15))
				rod(m, "Rocket", base, tip, 0.42, col, M.SmoothPlastic, { deco = true })
				ball(m, "Nose", tip, 0.46, C.Paper, M.SmoothPlastic, { deco = true })
				rod(m, "Wick", tip, tip + Vector3.new(0.1, 0.45, 0.05), 0.08, C.Cord, M.Fabric, { deco = true })
				if k == 1 then
					deco(
						m,
						"Band",
						Vector3.new(0.12, 0.44, 0.44),
						CFrame.lookAt((base + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0),
						C.Gold,
						M.Metal,
						{ shape = Enum.PartType.Cylinder }
					)
				end
			end
		end
		return m
	end
	local function pallet(into, cf: CFrame)
		local m = U.model(into, "Pallet")
		for k = -2, 2 do
			deco(
				m,
				"Board",
				Vector3.new(4, 0.2, 0.7),
				cf * CFrame.new(0, 0.55, k * 0.85),
				C.Wood:Lerp(C.Paper, 0.2),
				M.Wood
			)
		end
		for k = -1, 1 do
			part(m, "Block", Vector3.new(0.7, 0.45, 4), cf * CFrame.new(k * 1.6, 0.23, 0), C.WoodDark, M.Wood)
		end
		return m
	end
	local function bottle(into, at: Vector3, color: Color3)
		local m = U.model(into, "GasBottle")
		rod(m, "Body", at, at + Vector3.new(0, 3.2, 0), 1.1, color, M.SmoothPlastic)
		ball(m, "Shoulder", at + Vector3.new(0, 3.2, 0), 1.1, color, M.SmoothPlastic, { deco = true })
		rod(
			m,
			"Valve",
			at + Vector3.new(0, 3.6, 0),
			at + Vector3.new(0, 4.1, 0),
			0.35,
			C.Gold,
			M.Metal,
			{ deco = true }
		)
		return m
	end
	local function handTruck(into, cf: CFrame, cover: boolean)
		local m = U.model(into, "HandTruck")
		local hit = part(
			m,
			"Hit",
			Vector3.new(2.2, 3.4, 1.8),
			cf * CFrame.new(0, 1.7, 0),
			C.Steel,
			M.Metal,
			{ t = 1, shadow = false }
		)
		if cover then
			hit:SetAttribute("Cover", true)
		end
		for _, x in ipairs({ -0.85, 0.85 }) do
			rod(
				m,
				"Rail",
				(cf * CFrame.new(x, 0.4, 0.6)).Position,
				(cf * CFrame.new(x, 4.2, 0.9)).Position,
				0.2,
				C.Fuse,
				M.Metal,
				{ deco = true }
			)
			rod(
				m,
				"Wheel",
				(cf * CFrame.new(x + (if x > 0 then 0.15 else -0.15), 0.55, 0.75)).Position,
				(cf * CFrame.new(x + (if x > 0 then 0.4 else -0.4), 0.55, 0.75)).Position,
				1.1,
				C.Rubber,
				M.Rubber,
				{ deco = true }
			)
		end
		rod(
			m,
			"Grip",
			(cf * CFrame.new(-0.95, 4.2, 0.9)).Position,
			(cf * CFrame.new(0.95, 4.2, 0.9)).Position,
			0.22,
			C.Ink,
			M.Rubber,
			{ deco = true }
		)
		deco(m, "Toe", Vector3.new(2, 0.15, 1.2), cf * CFrame.new(0, 0.15, -0.2), C.Steel, M.Metal)
		crate(
			m,
			cf * CFrame.new(0, 1.35, 0) * CFrame.Angles(0, 0, 0),
			Vector3.new(1.8, 2.2, 1.4),
			{ closed = true, name = "Load" }
		)
		return m
	end

	-- Cover on the field (waist-high crates and two hand-trucks), kept off the centre roundel and the lanes.
	local cover = U.folder(map, "Cover")
	for _, c in ipairs({ { -34, -19, 0.2 }, { 34, 19, -0.15 }, { -12, 25, 0.5 }, { 12, -25, -0.4 } }) do
		crate(
			cover,
			CFrame.new(c[1], TOP + 1.3, c[2]) * CFrame.Angles(0, c[3], 0),
			Vector3.new(3.2, 2.6, 3.2),
			{ cover = true, rockets = 5 }
		)
	end
	handTruck(cover, CFrame.new(-36, TOP, 24) * CFrame.Angles(0, 0.6, 0), true)
	handTruck(cover, CFrame.new(36, TOP, -24) * CFrame.Angles(0, -2.4, 0), true)

	-- Dressing outside the yard: the factory strip and the near side.
	for x = -96, 96, 16 do
		local zz = FZ + 4.5 + rng:NextNumber(-0.8, 0.8)
		local pick = rng:NextInteger(1, 4)
		if x > 40 and x < 96 then
			pick = 0 -- the crane's footprint
		end
		if pick == 1 then
			pallet(strip, CFrame.new(x, TOP - 0.1, zz) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0))
			crate(
				strip,
				CFrame.new(x, TOP + 1.8, zz) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
				Vector3.new(3, 2.6, 3),
				{ rockets = 3 }
			)
		elseif pick == 2 then
			for k = 0, 2 do
				bottle(
					strip,
					Vector3.new(x - 1.2 + k * 1.2, TOP - 0.1, zz + 1.2),
					if k == 1 then C.Bomber else C.Steel:Lerp(C.Runner, 0.3)
				)
			end
		elseif pick == 3 then
			crate(
				strip,
				CFrame.new(x, TOP + 1.2, zz) * CFrame.Angles(0, 0.1, 0),
				Vector3.new(3.4, 2.4, 3.2),
				{ closed = true }
			)
			crate(
				strip,
				CFrame.new(x + 0.3, TOP + 3.4, zz) * CFrame.Angles(0, -0.2, 0),
				Vector3.new(2.6, 2, 2.6),
				{ rockets = 4 }
			)
		elseif pick == 4 then
			pallet(strip, CFrame.new(x, TOP - 0.1, zz))
			pallet(strip, CFrame.new(x, TOP + 0.55, zz) * CFrame.Angles(0, 0.08, 0))
			pallet(strip, CFrame.new(x, TOP + 1.2, zz) * CFrame.Angles(0, -0.05, 0))
		end
	end

	-- ── The gantry crane (far corner) with bunting ───────────────────────────────────────────────────────────
	local crane = U.model(map, "Crane")
	local GY = TOP + 24
	local legsX = { 46, 92 }
	local legZ = { FZ + 1.5, FZ + 7 } -- between the factory and the far railing
	for _, x in ipairs(legsX) do
		for _, z in ipairs(legZ) do
			rod(
				crane,
				"Leg",
				Vector3.new(x, TOP - 0.2, z),
				Vector3.new(x, GY, z),
				1.3,
				C.Crane,
				M.Metal,
				{ deco = true }
			)
			part(crane, "Foot", Vector3.new(3, 1, 3), Vector3.new(x, TOP + 0.3, z), C.Steel, M.Metal)
		end
		rod(
			crane,
			"Tie",
			Vector3.new(x, GY - 2, legZ[1]),
			Vector3.new(x, GY - 2, legZ[2]),
			0.9,
			C.Crane,
			M.Metal,
			{ deco = true }
		)
		rod(
			crane,
			"Diag",
			Vector3.new(x, TOP + 4, legZ[1]),
			Vector3.new(x, GY - 2, legZ[2]),
			0.6,
			C.Crane,
			M.Metal,
			{ deco = true }
		)
		rod(
			crane,
			"Diag",
			Vector3.new(x, TOP + 4, legZ[2]),
			Vector3.new(x, GY - 2, legZ[1]),
			0.6,
			C.Crane,
			M.Metal,
			{ deco = true }
		)
	end
	local mid = (legZ[1] + legZ[2]) / 2
	for _, dz in ipairs({ -1.4, 1.4 }) do
		part(
			crane,
			"Girder",
			Vector3.new(legsX[2] - legsX[1] + 6, 2.2, 1),
			Vector3.new((legsX[1] + legsX[2]) / 2, GY + 1, mid + dz),
			C.Crane,
			M.Metal,
			{ deco = true }
		)
	end
	for x = legsX[1], legsX[2] - 3, 3 do -- lattice web
		rod(
			crane,
			"Web",
			Vector3.new(x, GY, mid),
			Vector3.new(x + 3, GY + 2, mid),
			0.25,
			C.Crane:Lerp(C.Steel, 0.2),
			M.Metal,
			{ deco = true }
		)
	end
	local tx = 66
	part(crane, "Trolley", Vector3.new(4, 1.6, 4.2), Vector3.new(tx, GY - 0.4, mid), C.Steel, M.Metal, { deco = true })
	rod(
		crane,
		"Cable",
		Vector3.new(tx, GY - 1, mid),
		Vector3.new(tx, TOP + 12.2, mid),
		0.15,
		C.Ink,
		M.Metal,
		{ deco = true }
	)
	crate(
		crane,
		CFrame.new(tx, TOP + 10.6, mid) * CFrame.Angles(0, 0.3, 0),
		Vector3.new(4, 3, 4),
		{ rockets = 6, name = "HungCrate" }
	)
	-- bunting: a rope from the crane top to each canopy corner and the factory, flags in the palette
	local bunting = U.folder(map, "Bunting")
	local FLAGS = { C.Fuse, C.Spark, C.Runner, C.Paper, C.Bomber, C.Safe }
	local function bunt(a: Vector3, b: Vector3, droop: number)
		local pts = sag(a, b, droop, math.floor((b - a).Magnitude / 2.2))
		for i = 1, #pts - 1 do
			rod(bunting, "Rope", pts[i], pts[i + 1], 0.12, C.Ink, M.Fabric, { deco = true, shadow = false })
			local midp = (pts[i] + pts[i + 1]) / 2
			local dir = (pts[i + 1] - pts[i]).Unit
			local flat = Vector3.new(dir.X, 0, dir.Z).Unit
			-- a pennant: two mirrored wedges meeting at the point (an isosceles triangle hanging from the rope)
			local cf = CFrame.fromMatrix(midp - Vector3.new(0, 0.75, 0), flat, Vector3.yAxis)
				* CFrame.Angles(math.rad(180), 0, 0)
				* CFrame.Angles(0, math.rad(90), 0)
			local col = FLAGS[(i - 1) % #FLAGS + 1]
			wedge(
				bunting,
				"Flag",
				Vector3.new(0.05, 1.4, 0.65),
				cf * CFrame.new(0, 0, 0.325),
				col,
				M.Fabric,
				{ deco = true, shadow = false }
			)
			wedge(
				bunting,
				"Flag",
				Vector3.new(0.05, 1.4, 0.65),
				cf * CFrame.new(0, 0, -0.325) * CFrame.Angles(0, math.pi, 0),
				col,
				M.Fabric,
				{ deco = true, shadow = false }
			)
		end
	end
	bunt(Vector3.new(legsX[1], GY + 2, mid), Vector3.new(WALL - 1, TOP + 16.5, -HW - 6), 3)
	bunt(Vector3.new(legsX[1], GY + 2, mid), Vector3.new(-20, TOP + FH + 1, FZ - 0.5), 4)
	bunt(Vector3.new(-WALL + 1, TOP + 16.5, -HW - 6), Vector3.new(-70, TOP + FH + 1, FZ - 0.5), 2)

	-- ── The water tower (behind the factory, left) ───────────────────────────────────────────────────────────
	local tower = U.model(map, "WaterTower")
	local WX, WZ, WH = -112, -100, 34
	for _, o in ipairs({ { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } }) do
		rod(
			tower,
			"Leg",
			Vector3.new(WX + o[1] * 1.3, TOP, WZ + o[2] * 1.3),
			Vector3.new(WX + o[1], TOP + WH, WZ + o[2]),
			1,
			C.Steel,
			M.Metal,
			{ deco = true }
		)
	end
	for _, y in ipairs({ 10, 22 }) do
		part(
			tower,
			"Ring",
			Vector3.new(13, 0.6, 13),
			Vector3.new(WX, TOP + y, WZ),
			C.Steel,
			M.Metal,
			{ deco = true, t = 0 }
		)
	end
	local tank = rod(
		tower,
		"Tank",
		Vector3.new(WX, TOP + WH, WZ),
		Vector3.new(WX, TOP + WH + 12, WZ),
		16,
		C.Wood,
		M.WoodPlanks,
		{ deco = true }
	)
	for _, y in ipairs({ 2, 6, 10 }) do
		rod(
			tower,
			"Hoop",
			Vector3.new(WX, TOP + WH + y - 0.2, WZ),
			Vector3.new(WX, TOP + WH + y + 0.2, WZ),
			16.3,
			C.Steel,
			M.Metal,
			{ deco = true }
		)
	end
	for k, d in ipairs({ 16.6, 12, 7.4, 3 }) do
		rod(
			tower,
			"Roof",
			Vector3.new(WX, TOP + WH + 12 + (k - 1) * 1.4, WZ),
			Vector3.new(WX, TOP + WH + 12 + k * 1.4, WZ),
			d,
			C.Bomber:Lerp(C.BrickDark, 0.3),
			M.Metal,
			{ deco = true }
		)
	end
	local painted = deco(
		tower,
		"Paint",
		Vector3.new(8, 6, 0.1),
		Vector3.new(WX, TOP + WH + 6, WZ + 8.05),
		C.Ink,
		M.SmoothPlastic,
		{ t = 1 }
	)
	label(painted, Enum.NormalId.Back, "FV", C.Paper, { pps = 16, t = 0.1 })
	tank.CastShadow = true

	-- ── Near side (+Z, the lobby's side; kept low): railing under string lights ─────────────────────────────
	local near = U.model(map, "NearSide")
	local RZ = HW + 5
	for x = -WALL, WALL, 6 do
		rod(near, "Post", Vector3.new(x, TOP, RZ), Vector3.new(x, TOP + 3.4, RZ), 0.35, C.Steel, M.Metal)
	end
	rod(near, "TopRail", Vector3.new(-WALL, TOP + 3.4, RZ), Vector3.new(WALL, TOP + 3.4, RZ), 0.4, C.Fuse, M.Metal)
	rod(near, "MidRail", Vector3.new(-WALL, TOP + 1.8, RZ), Vector3.new(WALL, TOP + 1.8, RZ), 0.25, C.Steel, M.Metal)
	-- the far railing too, in front of the factory strip
	local FRZ = -HW - 5
	for x = -WALL, WALL, 6 do
		rod(near, "Post", Vector3.new(x, TOP, FRZ), Vector3.new(x, TOP + 3.4, FRZ), 0.35, C.Steel, M.Metal)
	end
	rod(near, "TopRail", Vector3.new(-WALL, TOP + 3.4, FRZ), Vector3.new(WALL, TOP + 3.4, FRZ), 0.4, C.Fuse, M.Metal)
	rod(near, "MidRail", Vector3.new(-WALL, TOP + 1.8, FRZ), Vector3.new(WALL, TOP + 1.8, FRZ), 0.25, C.Steel, M.Metal)
	-- string light poles and the lights: sagging between poles on both long sides
	local lights = U.folder(map, "StringLights")
	for _, z in ipairs({ RZ + 1.5, FRZ - 1.5 }) do
		local poles = {}
		for x = -WALL, WALL, 28 do
			rod(lights, "Pole", Vector3.new(x, TOP, z), Vector3.new(x, TOP + 12, z), 0.5, C.Steel, M.Metal)
			ball(lights, "PoleCap", Vector3.new(x, TOP + 12, z), 0.7, C.Fuse, M.Metal, { deco = true })
			table.insert(poles, Vector3.new(x, TOP + 11.6, z))
		end
		for i = 1, #poles - 1 do
			local pts = sag(poles[i], poles[i + 1], 2.4, 14)
			for k = 1, #pts - 1 do
				rod(lights, "Wire", pts[k], pts[k + 1], 0.08, C.Ink, M.SmoothPlastic, { deco = true, shadow = false })
				if k > 1 then
					local b = ball(
						lights,
						"Bulb",
						pts[k] - Vector3.new(0, 0.3, 0),
						0.42,
						rgb(255, 214, 150),
						M.Neon,
						{ deco = true, shadow = false }
					)
					if k == 7 then
						light(b, rgb(255, 200, 130), 12, 0.7)
					end
				end
			end
		end
	end
	-- crates, pallets and rocket bundles outside the near railing
	for x = -84, 84, 21 do
		local zz = RZ + 6 + rng:NextNumber(-1, 2)
		if rng:NextNumber() < 0.5 then
			crate(
				near,
				CFrame.new(x, TOP + 1.2, zz) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
				Vector3.new(3.2, 2.4, 3),
				{ rockets = 4 }
			)
		else
			pallet(near, CFrame.new(x, TOP - 0.1, zz) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0))
			crate(
				near,
				CFrame.new(x, TOP + 1.9, zz) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
				Vector3.new(3, 2.4, 3),
				{ closed = true }
			)
		end
	end

	-- ── Sky: soft volumetric clouds instead of the Meadow's brick ones (Environment keeps only its sea) ─────────
	local env = workspace:FindFirstChild("Environment")
	if env then
		for _, n in ipairs({ "Clouds", "HorizonIslands" }) do
			local old = env:FindFirstChild(n)
			if old then
				old:Destroy() -- Environment's builder brings them back if the Meadow ever returns
			end
		end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.32
	clouds.Color = rgb(255, 226, 200)
	clouds.Parent = workspace.Terrain

	-- ── Lighting: "Golden Fuse" (Asset Bible §2.5) ───────────────────────────────────────────────────────────
	local L = game:GetService("Lighting")
	pcall(function()
		(L :: any).Technology = Enum.Technology.Future
	end)
	-- a low sun over the open near side (+Z): it lights the factory front and rakes long shadows across the yard
	L.ClockTime = 15.4
	L.GeographicLatitude = 77 -- with ClockTime 15.4: the sun 22° up, from (−0.46, 0.37, 0.80)
	L.Brightness = 2.6
	L.EnvironmentDiffuseScale = 0.75
	L.EnvironmentSpecularScale = 0.6
	L.Ambient = rgb(70, 64, 80)
	L.OutdoorAmbient = rgb(93, 106, 143)
	L.ColorShift_Top = rgb(255, 197, 138)
	L.ColorShift_Bottom = rgb(60, 70, 110)
	L.ShadowSoftness = 0.25
	local function effect(class: string, name: string)
		local e = L:FindFirstChild(name) or Instance.new(class)
		e.Name = name
		e.Parent = L
		return e :: any
	end
	local atmo = L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.12
	atmo.Color = rgb(255, 214, 170)
	atmo.Decay = rgb(140, 110, 120)
	atmo.Glare = 0.35
	atmo.Haze = 1.2
	atmo.Parent = L
	local bloom = effect("BloomEffect", "Bloom")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	local grade = effect("ColorCorrectionEffect", "Grade")
	grade.Saturation = 0.08
	grade.Contrast = 0.06
	grade.TintColor = rgb(255, 246, 236)
	local rays = effect("SunRaysEffect", "SunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6

	return ("Yard built: %d parts"):format(#map:GetDescendants())
end
