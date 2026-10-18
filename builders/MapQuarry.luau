-- Map 2, "The Quarry" (docs/maps/QUARRY_BRIEF.md; the owner's pick, 2026-10-18; concept art art/ref/quarry/): a sunny
-- sandstone canyon quarry in the restyled Yard's bright toy look, every brick with real Roblox studs (Util.realStuds).
--   • the field: sandstone slabs in two tones with seams, cracks and pebbles, four mine-rail lanes across it (the
--     hazard lanes YardController flashes), the painted bomb roundel at centre;
--   • the Safe Strips: timber plank decks with a yellow bumper edge and the green safe strip, "SAFE" painted, corner
--     bumper posts; behind each, a stepped canyon wall with two timber mine-tunnel mouths, lanterns and rails running in;
--   • both long sides: timber troughs carrying the Field Fuse cords, then a low timber rail with lantern posts and
--     string lights;
--   • far side (−Z): irregular stepped sandstone cliffs with cream strata, a waterfall with foam and mist into a pool,
--     the ore head-frame and its chute, a mine-cart spur on a terrace, scaffolds and ladders, a water tower, palms,
--     voxel trees, cacti and scrub, the "FUSE VALLEY QUARRY" sign on the top ledge, distant mesas;
--   • near side (+Z, the lobby's side) kept low: sand, boulders, powder kegs, crates, a parked cart, cacti.
-- Cover: four mine carts on rail stubs and two dynamite stacks, waist-high, at the Yard's six cover spots.
-- Props: modelled pieces come from ReplicatedStorage.FV_Art.Props (MineCart, DynamiteStack, TunnelMouth, HeadFrame,
-- WaterTower, QuarrySign, Cactus, CactusSmall, Rock1 / Rock2, Palm, VoxelTree, PowderKeg) when imported; each has a
-- built fallback, so the map is always complete.
-- Gameplay contract (as MapYard): StartLine / FinishLine, Zones (StartZone / FinishZone / Field), the field 140 × 90
-- between the lines, the strips 14 deep; HazardLanes/LaneGlow and FuseCords/Cord for YardController; `Cover` parts.
-- Built round the origin at TOP = 10, then moved by PLACE_OFFSET onto the Yard's field frame (the lobby looks down on
-- whichever map is active). Lighting stays the shared Config.Lighting.ToyMidday (set by MapYardToy).

local rgb = Color3.fromRGB

local C = {
	Ink = rgb(22, 18, 28),
	Paper = rgb(255, 243, 226),
	Safe = rgb(59, 228, 140),
	Fuse = rgb(255, 106, 31),
	Cord = rgb(217, 185, 138),
	Sand = rgb(214, 176, 120), -- mid-tone: bright sand blows out under the sunny preset
	SandDark = rgb(196, 156, 100),
	Seam = rgb(160, 120, 76),
	Slab = rgb(222, 188, 138),
	Crack = rgb(150, 108, 66),
	Terracotta = rgb(217, 130, 74),
	RedRock = rgb(186, 88, 50),
	RockDeep = rgb(150, 66, 40),
	Cream = rgb(244, 220, 170),
	Timber = rgb(160, 104, 58),
	TimberDark = rgb(112, 70, 40),
	Iron = rgb(70, 74, 88),
	Steel = rgb(120, 128, 146),
	Rail = rgb(150, 156, 170),
	Dynamite = rgb(232, 64, 47),
	Water = rgb(56, 201, 217),
	WaterDeep = rgb(32, 150, 196),
	Foam = rgb(236, 252, 255),
	Cactus = rgb(92, 184, 72),
	CactusDark = rgb(64, 150, 56),
	Scrub = rgb(124, 196, 70),
	Gold = rgb(255, 196, 40),
	Lantern = rgb(255, 196, 96),
	Hazard = rgb(255, 208, 40),
	Bulbs = { rgb(255, 90, 80), rgb(255, 210, 70), rgb(90, 210, 120), rgb(80, 170, 255), rgb(220, 120, 255) },
}

local SMOKE = "rbxassetid://98967284678053" -- art/vfx/make_vfx.py (Assets.Vfx.Smoke), the waterfall's mist
local EMBER = "rbxassetid://135076496021372" -- art/vfx/make_vfx.py (Assets.Vfx.Ember): the spray droplets, tinted
-- art/vfx/make_water.py (art/out/Water): the flowing water, scrolled by Beams
local WATER = {
	Body = "rbxassetid://112397119042285", -- the falling sheet (greyscale, tinted blue)
	Streaks = "rbxassetid://108614212981784", -- white foam streaks running down it
	Foam = "rbxassetid://120738064245514", -- foam blobs (landings, the pool)
	Ripple = "rbxassetid://116371811165463", -- foam ripple lines (streams, the pool)
}

local M = Enum.Material

return function(ctx, parent)
	local T = ctx.req("Theme")
	local U = ctx.req("Util").init(T)
	parent = parent or workspace:FindFirstChild("Maps") or U.folder(workspace, "Maps")
	local map = U.fresh(parent, "Quarry")
	map:SetAttribute("DisplayName", "THE QUARRY")
	local rng = Random.new(2018)

	local TOP = 10
	local HL = 70 -- half the field's length (centre → each line)
	local HW = 45 -- half the field's width
	local DOCK = 14 -- Safe Strip depth
	local WALL = HL + DOCK + 1 -- the canyon walls behind the strips (Arena's back walls sit here)
	local FZ = -(HW + 7) -- where the far cliffs start
	local PLACE_OFFSET = Vector3.new(-3, 78, -38) -- the Yard's field frame (MapYardToy)

	-- ── Part helpers ─────────────────────────────────────────────────────────────────────────────────────────
	local function block(p, n, size: Vector3, at, color: Color3, o)
		o = o or {}
		return U.block(p, n, size, at, color, {
			stud = o.stud,
			material = o.material,
			shape = o.shape,
			transparency = o.t,
			collide = o.collide,
			shadow = o.shadow,
		})
	end
	local function deco(p, n, size: Vector3, at, color: Color3, o)
		o = table.clone(o or {})
		o.collide = false
		return block(p, n, size, at, color, o)
	end
	local function smooth(p, n, size: Vector3, at, color: Color3, o)
		o = table.clone(o or {})
		o.stud = false
		return deco(p, n, size, at, color, o)
	end
	local function glow(p, n, size: Vector3, at, color: Color3, t: number?)
		return smooth(p, n, size, at, color, { material = M.Neon, t = t, shadow = false })
	end
	local function rod(p, n, a: Vector3, b: Vector3, d: number, color: Color3, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Cylinder
		o.stud = false
		local dir = b - a
		return block(
			p,
			n,
			Vector3.new(dir.Magnitude, d, d),
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			color,
			o
		)
	end
	local function ball(p, n, at: Vector3, d: number, color: Color3, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Ball
		o.stud = false
		return deco(p, n, Vector3.one * d, at, color, o)
	end
	local function light(p: BasePart, color: Color3, range: number, brightness: number)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
		l.Parent = p
	end
	local function label(face: BasePart, side: Enum.NormalId, text: string, color: Color3, ppu: number)
		local gui = Instance.new("SurfaceGui")
		gui.Face = side
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = ppu
		gui.LightInfluence = 0.6
		gui.Parent = face
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeColor3 = C.Ink
		l.TextStrokeTransparency = 0.2
		l.Text = text
		l.Parent = gui
		return l
	end
	-- Text painted on the floor, upright for someone looking along `toward`.
	local function paint(p, n, text: string, at: Vector3, toward: Vector3, w: number, h: number, color: Color3)
		local plate = smooth(p, n, Vector3.new(h, 0.04, w), CFrame.fromMatrix(at, -toward, Vector3.yAxis), C.Ink, {
			t = 1,
			shadow = false,
		})
		label(plate, Enum.NormalId.Top, text, color, 20)
		return plate
	end

	-- A modelled prop from FV_Art.Props, scaled to `height` (or as built), its bottom centre at `cf`. Decoration
	-- unless `solid`; nil when the prop isn't in the place (the caller builds the fallback).
	local art = game:GetService("ReplicatedStorage"):FindFirstChild("FV_Art")
	local props = art and art:FindFirstChild("Props")
	local function prop(p, name: string, cf: CFrame, height: number?, solid: boolean?): Model?
		local src = props and props:FindFirstChild(name)
		if not src or not src:IsA("Model") then
			return nil
		end
		local m = src:Clone()
		if height then
			local _, size = m:GetBoundingBox()
			m:ScaleTo(m:GetScale() * height / size.Y)
		end
		m:PivotTo(cf)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				if d.Name == "Hit" then
					d.CanCollide, d.CanQuery = solid == true, solid == true
				else
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				end
			end
		end
		m.Parent = p
		return m
	end

	-- ── Ground ───────────────────────────────────────────────────────────────────────────────────────────────
	local ground = U.folder(map, "Ground")
	block(ground, "Bedrock", Vector3.new(460, 4, 360), Vector3.new(0, TOP - 2.25, -40), C.SandDark)

	-- ── The field: sandstone slabs, cracks, pebbles, the roundel ─────────────────────────────────────────────
	local field = U.model(map, "Field")
	smooth(
		field,
		"Floor",
		Vector3.new(WALL * 2, 2, HW * 2 + 8),
		Vector3.new(0, TOP - 1.05, 0),
		C.Seam,
		{ collide = true }
	)
	local tile = 10
	for x = -HL + tile / 2, HL - tile / 2, tile do
		for z = -HW + tile / 2, HW - tile / 2, tile do
			local shade = if (math.floor(x / tile) + math.floor(z / tile)) % 2 == 0 then C.Sand else C.Slab
			if rng:NextNumber() < 0.2 then
				shade = shade:Lerp(C.SandDark, 0.45)
			end
			block(field, "Slab", Vector3.new(tile - 0.3, 0.2, tile - 0.3), Vector3.new(x, TOP - 0.1, z), shade)
		end
	end
	local marks = U.folder(map, "FieldMarks")
	for _ = 1, 26 do -- hairline cracks across a few slabs (flat, painted on, never a lip)
		local at = Vector3.new(rng:NextNumber(-HL + 3, HL - 3), TOP + 0.012, rng:NextNumber(-HW + 3, HW - 3))
		if at.Magnitude > 15 then
			smooth(
				marks,
				"Crack",
				Vector3.new(rng:NextNumber(2, 5), 0.02, 0.18),
				CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				C.Crack,
				{
					shadow = false,
				}
			)
		end
	end
	for _ = 1, 60 do -- pebbles along the edges, by the troughs and the decks (decoration, knee-free)
		local s = if rng:NextNumber() < 0.5 then -1 else 1
		local at = if rng:NextNumber() < 0.6
			then Vector3.new(rng:NextNumber(-HL, HL), TOP + 0.1, s * (HW - rng:NextNumber(0.4, 2.5)))
			else Vector3.new(s * (HL - rng:NextNumber(0.6, 3)), TOP + 0.1, rng:NextNumber(-HW, HW))
		smooth(
			marks,
			"Pebble",
			Vector3.new(rng:NextNumber(0.3, 0.7), 0.2, rng:NextNumber(0.3, 0.6)),
			CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			C.Terracotta:Lerp(C.Cream, rng:NextNumber()),
			{
				shadow = false,
			}
		)
	end
	-- the bomb roundel (painted: cream ring, fuse-orange band, dark disc, the bomb with its fuse and spark)
	local roundel = U.folder(map, "Roundel")
	for i, r in ipairs({ { 26, C.Paper }, { 22.4, C.Fuse }, { 17, C.Ink }, { 9.4, C.Iron } }) do
		smooth(
			roundel,
			"Ring" .. i,
			Vector3.new(0.04, r[1], r[1]),
			CFrame.new(0, TOP + 0.01 + i * 0.008, 0) * CFrame.Angles(0, 0, math.rad(90)),
			r[2],
			{
				shape = Enum.PartType.Cylinder,
				shadow = false,
			}
		)
	end
	smooth(
		roundel,
		"Shine",
		Vector3.new(0.05, 2.6, 2.6),
		CFrame.new(-2, TOP + 0.05, -2) * CFrame.Angles(0, 0, math.rad(90)),
		C.Steel,
		{
			shape = Enum.PartType.Cylinder,
			shadow = false,
		}
	)
	smooth(
		roundel,
		"FuseLine",
		Vector3.new(4, 0.05, 0.7),
		CFrame.new(3.6, TOP + 0.05, 3.6) * CFrame.Angles(0, math.rad(-45), 0),
		C.Cord,
		{
			shadow = false,
		}
	)
	glow(
		roundel,
		"Spark",
		Vector3.new(1.4, 0.06, 1.4),
		CFrame.new(5.2, TOP + 0.06, 5.2) * CFrame.Angles(0, math.rad(45), 0),
		C.Gold
	)

	-- ── Hazard lanes: four mine-rail lines across the field (YardController pulses LaneGlow for the Field Fuse) ─
	local lanes = U.folder(map, "HazardLanes")
	for i, x in ipairs({ -46.5, -23.25, 23.25, 46.5 }) do
		smooth(
			lanes,
			"Bed",
			Vector3.new(3.4, 0.04, HW * 2 - 1),
			Vector3.new(x, TOP + 0.02, 0),
			C.TimberDark,
			{ shadow = false }
		)
		for z = -HW + 1.5, HW - 1.5, 3 do
			smooth(
				lanes,
				"Sleeper",
				Vector3.new(3.8, 0.06, 0.9),
				Vector3.new(x, TOP + 0.04, z),
				C.Timber,
				{ shadow = false }
			)
			for _, dx in ipairs({ -1.5, 1.5 }) do -- spike heads
				smooth(
					lanes,
					"Spike",
					Vector3.new(0.18, 0.08, 0.18),
					Vector3.new(x + dx, TOP + 0.07, z),
					C.Iron,
					{ shadow = false }
				)
			end
		end
		for _, dx in ipairs({ -0.9, 0.9 }) do
			smooth(lanes, "Rail", Vector3.new(0.3, 0.1, HW * 2 - 1), Vector3.new(x + dx, TOP + 0.08, 0), C.Rail, {
				material = M.Metal,
				shadow = false,
			})
		end
		local g = glow(lanes, "LaneGlow", Vector3.new(3.4, 0.03, HW * 2 - 1), Vector3.new(x, TOP + 0.12, 0), C.Fuse, 1)
		g:SetAttribute("Lane", i)
		g:SetAttribute("X", x)
	end

	-- ── Long sides: timber troughs carrying the Field Fuse cords, a low rail, lantern posts, string lights ────
	local cords = U.folder(map, "FuseCords")
	local sides = U.folder(map, "Sides")
	local lights = U.folder(map, "StringLights")
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (HW + 1.2)
		smooth(
			sides,
			"TroughBed",
			Vector3.new(WALL * 2, 1, 2.4),
			Vector3.new(0, TOP - 1.1, z),
			C.TimberDark,
			{ collide = true }
		)
		for _, lip in ipairs({ -1.1, 1.1 }) do
			smooth(
				sides,
				"TroughLip",
				Vector3.new(WALL * 2, 0.6, 0.3),
				Vector3.new(0, TOP - 0.3, z + lip),
				C.Timber,
				{ collide = true }
			)
		end
		for x = -WALL + 4, WALL - 4, 8 do -- iron saddles holding the cord
			smooth(sides, "Saddle", Vector3.new(0.4, 0.8, 2.0), Vector3.new(x, TOP - 0.55, z), C.Iron)
		end
		local cord =
			rod(cords, "Cord", Vector3.new(-WALL, TOP - 0.45, z), Vector3.new(WALL, TOP - 0.45, z), 0.75, C.Cord, {
				material = M.Fabric,
				collide = false,
			})
		cord:SetAttribute("Side", s)
		-- the kerb and the knee-high timber rail
		local rz = s * (HW + 3.6)
		block(sides, "Kerb", Vector3.new(WALL * 2 + 4, 0.9, 2), Vector3.new(0, TOP - 0.05, rz), C.Cream)
		for x = -WALL + 2, WALL - 2, 8 do
			block(sides, "Post", Vector3.new(0.8, 2.4, 0.8), Vector3.new(x, TOP + 1.6, rz), C.Timber)
			smooth(sides, "PostCap", Vector3.new(1, 0.25, 1), Vector3.new(x, TOP + 2.9, rz), C.TimberDark)
		end
		smooth(
			sides,
			"Beam",
			Vector3.new(WALL * 2, 0.5, 0.5),
			Vector3.new(0, TOP + 2.3, rz),
			C.Timber,
			{ collide = true }
		)
		smooth(sides, "BeamLow", Vector3.new(WALL * 2, 0.4, 0.4), Vector3.new(0, TOP + 1.2, rz), C.TimberDark)
		-- lantern posts every 24 studs with string lights swagged between them
		local prev: Vector3? = nil
		for x = -WALL + 4, WALL - 4, 24 do
			local base = Vector3.new(x, TOP, rz + s * 1.6)
			block(sides, "LanternPost", Vector3.new(0.7, 7, 0.7), base + Vector3.new(0, 3.5, 0), C.TimberDark)
			smooth(sides, "LanternArm", Vector3.new(0.4, 0.4, 1.8), base + Vector3.new(0, 6.8, -s * 0.7), C.TimberDark)
			local lamp =
				glow(sides, "Lantern", Vector3.new(0.8, 1.1, 0.8), base + Vector3.new(0, 6.1, -s * 1.4), C.Lantern)
			light(lamp, C.Lantern, 9, 0.8)
			smooth(sides, "LanternCap", Vector3.new(1, 0.3, 1), base + Vector3.new(0, 6.8, -s * 1.4), C.Iron)
			local top = base + Vector3.new(0, 7, 0)
			if prev then
				-- a sagging swag of bulbs
				local n = 9
				for k = 1, n - 1 do
					local a = k / n
					local p = prev:Lerp(top, a) - Vector3.new(0, math.sin(a * math.pi) * 1.6, 0)
					glow(lights, "Bulb", Vector3.new(0.45, 0.55, 0.45), p, C.Bulbs[(k % #C.Bulbs) + 1])
				end
				rod(lights, "Wire", prev, top, 0.08, C.Ink, { collide = false })
			end
			prev = top
		end
	end

	-- ── The gameplay contract ────────────────────────────────────────────────────────────────────────────────
	for n, x in pairs({ StartLine = -HL, FinishLine = HL }) do
		local p = smooth(map, n, Vector3.new(1, 0.05, HW * 2), Vector3.new(x, TOP + 0.01, 0), C.Paper, { t = 1 })
		p.CanQuery = false
	end
	local zones = U.folder(map, "Zones")
	U.marker(zones, "StartZone", Vector3.new(DOCK, 12, HW * 2), Vector3.new(-HL - DOCK / 2, TOP + 6, 0))
	U.marker(zones, "FinishZone", Vector3.new(DOCK, 12, HW * 2), Vector3.new(HL + DOCK / 2, TOP + 6, 0))
	U.marker(zones, "Field", Vector3.new(HL * 2, 12, HW * 2), Vector3.new(0, TOP + 6, 0))

	-- ── A stepped rock wall from blocks (cliffs, canyon walls): irregular tops, strata bands, ledge dressing ──
	local function rockWall(p, from: Vector3, to: Vector3, h0: number, h1: number, depth: number, segW: { number })
		local dir = (to - from).Unit
		local len = (to - from).Magnitude
		local right = dir:Cross(Vector3.yAxis)
		local d = 0
		local k = 0
		while d < len do
			k += 1
			local w = math.min(rng:NextNumber(segW[1], segW[2]), len - d)
			local a = (d + w / 2) / len
			local h = h0 + (h1 - h0) * a + rng:NextNumber(-2.5, 2.5)
			local inset = rng:NextNumber(-1.2, 1.2)
			local c = from + dir * (d + w / 2) + right * inset
			local cf =
				CFrame.lookAt(Vector3.new(c.X, TOP + h / 2 - 0.5, c.Z), Vector3.new(c.X, TOP + h / 2 - 0.5, c.Z) + dir)
			local rock = block(
				p,
				"Rock",
				Vector3.new(w + 0.4, h, depth),
				cf * CFrame.Angles(0, math.rad(90), 0),
				if k % 3 == 0 then C.RedRock else C.Terracotta
			)
			rock:SetAttribute("Backdrop", true)
			for _, sh in ipairs({ 0.32, 0.68 }) do -- cream / deep strata bands
				if h > 7 then
					smooth(
						p,
						"Strata",
						Vector3.new(w + 0.6, 1.1, depth + 0.2),
						cf * CFrame.new(0, -h / 2 + h * sh, 0) * CFrame.Angles(0, math.rad(90), 0),
						if sh < 0.5 then C.Cream else C.RockDeep
					)
				end
			end
			d += w
		end
	end

	-- ── The Safe Strips: plank decks, bumper edge, SAFE; the canyon walls and tunnel mouths behind ───────────
	local function stripEnd(s: number)
		local deck = U.model(map, if s < 0 then "PlatformA" else "PlatformB")
		local inner = s * HL
		local cx = s * (HL + DOCK / 2)
		for z = -HW - 4, HW + 2, 2 do
			local shade = if (z / 2) % 2 == 0 then C.Timber else C.Timber:Lerp(C.TimberDark, 0.25)
			smooth(
				deck,
				"Plank",
				Vector3.new(DOCK, 0.2, 1.9),
				Vector3.new(cx, TOP - 0.1, z + 1),
				shade:Lerp(C.Cream, rng:NextNumber(0, 0.08)),
				{
					collide = true,
				}
			)
			for _, dx in ipairs({ -DOCK / 2 + 0.6, 0, DOCK / 2 - 0.6 }) do -- nail heads
				smooth(
					deck,
					"Nail",
					Vector3.new(0.16, 0.04, 0.16),
					Vector3.new(cx + dx, TOP + 0.01, z + 1),
					C.Iron,
					{ shadow = false }
				)
			end
		end
		-- the safe edge: a yellow-black bumper band, then the green safe strip (the line Runners aim for)
		smooth(
			deck,
			"EdgeBand",
			Vector3.new(1.4, 0.05, HW * 2),
			Vector3.new(inner + s * 0.7, TOP + 0.03, 0),
			C.Hazard,
			{ shadow = false }
		)
		for z = -HW + 1, HW - 1, 2 do
			smooth(
				deck,
				"EdgeStripe",
				Vector3.new(1.42, 0.06, 0.7),
				CFrame.new(inner + s * 0.7, TOP + 0.035, z) * CFrame.Angles(0, math.rad(45), 0),
				C.Ink,
				{
					shadow = false,
				}
			)
		end
		local strip = glow(
			deck,
			"SafeStrip",
			Vector3.new(0.35, 0.06, HW * 2),
			Vector3.new(inner + s * 1.6, TOP + 0.05, 0),
			C.Safe
		)
		strip:SetAttribute("SafeStrip", s)
		for z = -HW + 8, HW - 8, 16 do
			local l = glow(
				deck,
				"StripLight",
				Vector3.new(0.2, 0.2, 0.2),
				Vector3.new(inner + s * 1.6, TOP + 0.4, z),
				C.Safe,
				1
			)
			light(l, C.Safe, 9, 0.9)
		end
		paint(deck, "SafeText", "SAFE", Vector3.new(cx + s * 0.5, TOP + 0.03, 0), Vector3.new(s, 0, 0), 30, 7, C.Paper)
		-- corner bumper posts (yellow-black, at the strip's ends beyond the field width)
		for _, z in ipairs({ -HW - 2.4, HW + 2.4 }) do
			for k = 0, 3 do
				smooth(
					deck,
					"Bumper",
					Vector3.new(1.2, 0.7, 1.2),
					Vector3.new(inner + s * 1.2, TOP + 0.35 + k * 0.7, z),
					if k % 2 == 0 then C.Hazard else C.Ink,
					{ collide = true }
				)
			end
		end
		-- the canyon wall behind: steps down from the far side (tall) toward the lobby's side (low)
		local wx = s * (WALL + 4)
		rockWall(map, Vector3.new(wx, 0, FZ - 10), Vector3.new(wx, 0, HW + 26), 24, 6, 7, { 4, 8 })
		rockWall(map, Vector3.new(wx + s * 7, 0, FZ - 20), Vector3.new(wx + s * 7, 0, HW + 6), 34, 12, 8, { 5, 9 })
		rockWall(map, Vector3.new(wx + s * 15, 0, FZ - 30), Vector3.new(wx + s * 15, 0, HW - 10), 44, 22, 9, { 6, 11 })
		-- two tunnel mouths in the wall, rails running in across the deck
		for _, z in ipairs({ -22, 22 }) do
			local cf = CFrame.lookAt(Vector3.new(wx - s * 4.1, TOP, z), Vector3.new(0, TOP, z))
			if not prop(deck, "TunnelMouth", cf, nil, true) then
				smooth(
					deck,
					"Mouth",
					Vector3.new(2, 11, 11),
					cf * CFrame.new(0, 5.5, 0.9) * CFrame.Angles(0, math.rad(90), 0),
					C.Ink
				)
				for _, dz in ipairs({ -6.4, 6.4 }) do
					block(deck, "FramePost", Vector3.new(1.5, 12.4, 1.5), cf * CFrame.new(dz, 6.2, 0), C.Timber)
					smooth(
						deck,
						"Brace",
						Vector3.new(0.6, 3.6, 0.6),
						cf
							* CFrame.new(dz * 0.8, 10.6, -0.4)
							* CFrame.Angles(0, 0, math.rad(if dz < 0 then -40 else 40)),
						C.TimberDark
					)
					local lamp = glow(
						deck,
						"Lantern",
						Vector3.new(0.9, 1.2, 0.9),
						cf * CFrame.new(dz * 0.75, 8.6, -1.4),
						C.Lantern
					)
					light(lamp, C.Lantern, 10, 1.2)
					smooth(
						deck,
						"LanternHook",
						Vector3.new(0.2, 1.2, 0.2),
						cf * CFrame.new(dz * 0.75, 9.6, -1.2),
						C.Iron
					)
				end
				block(deck, "FrameBeam", Vector3.new(15.4, 1.8, 1.8), cf * CFrame.new(0, 12.6, 0), C.TimberDark)
				smooth(deck, "Plate", Vector3.new(6, 1.4, 0.3), cf * CFrame.new(0, 12.6, -1), C.Gold)
			end
			for _, dz in ipairs({ -0.9, 0.9 }) do
				smooth(
					deck,
					"TunnelRail",
					Vector3.new(DOCK + 4, 0.1, 0.3),
					Vector3.new(cx + s * 2, TOP + 0.09, z + dz),
					C.Rail,
					{
						material = M.Metal,
					}
				)
			end
			for x = -DOCK / 2, DOCK / 2 + 2, 2.5 do
				smooth(
					deck,
					"TunnelSleeper",
					Vector3.new(0.8, 0.06, 2.8),
					Vector3.new(cx + s * x, TOP + 0.05, z),
					C.TimberDark
				)
			end
		end
		-- crates and kegs stacked against the wall, outside the field's width
		for _, z in ipairs({ -HW - 6, HW + 5 }) do
			if not prop(deck, "PowderKeg", CFrame.new(cx - s * 2, TOP, z), 2.6) then
				block(deck, "Keg", Vector3.new(2, 2.6, 2), Vector3.new(cx - s * 2, TOP + 1.3, z), C.Timber)
			end
			block(deck, "Crate", Vector3.new(3, 2.6, 3), Vector3.new(cx + s * 2.5, TOP + 1.3, z), C.Timber)
			block(
				deck,
				"CrateTop",
				Vector3.new(2.2, 1.8, 2.2),
				CFrame.new(cx + s * 2.5, TOP + 3.5, z) * CFrame.Angles(0, 0.4, 0),
				C.Timber:Lerp(C.TimberDark, 0.3)
			)
		end
	end
	stripEnd(-1)
	stripEnd(1)

	-- ── Cover: mine carts on rail stubs and dynamite stacks (waist-high), at the Yard's cover spots ──────────
	local cover = U.folder(map, "Cover")
	local function cart(cf: CFrame)
		local m = prop(cover, "MineCart", cf, 2.8, true)
		if m then
			local hit = m:FindFirstChild("Hit")
			if hit then
				hit:SetAttribute("Cover", true)
			end
			return
		end
		m = U.model(cover, "MineCart")
		for _, dx in ipairs({ -0.9, 0.9 }) do
			smooth(m, "Stub", Vector3.new(0.3, 0.1, 6), cf * CFrame.new(dx, 0.05, 0), C.Rail, { material = M.Metal })
		end
		for z = -2.4, 2.4, 1.2 do
			smooth(m, "StubSleeper", Vector3.new(2.8, 0.06, 0.6), cf * CFrame.new(0, 0.03, z), C.Timber)
		end
		local body = smooth(
			m,
			"Tub",
			Vector3.new(3, 1.9, 3.4),
			cf * CFrame.new(0, 1.35, 0),
			C.Iron,
			{ material = M.Metal, collide = true }
		)
		body:SetAttribute("Cover", true)
		smooth(m, "Rim", Vector3.new(3.3, 0.3, 3.7), cf * CFrame.new(0, 2.3, 0), C.Steel, { material = M.Metal })
		for _, z in ipairs({ -1.2, 0, 1.2 }) do
			smooth(m, "Band", Vector3.new(3.08, 1.9, 0.2), cf * CFrame.new(0, 1.35, z), C.Steel, { material = M.Metal })
		end
		deco(m, "Ore", Vector3.new(2.6, 0.6, 3), cf * CFrame.new(0, 2.4, 0), C.Gold)
		for _ = 1, 4 do
			ball(
				m,
				"Nugget",
				(cf * CFrame.new(rng:NextNumber(-1, 1), 2.75, rng:NextNumber(-1.2, 1.2))).Position,
				0.6,
				C.Gold
			)
		end
		for _, wz in ipairs({ -1.2, 1.2 }) do
			for _, wx in ipairs({ -1.55, 1.55 }) do
				smooth(
					m,
					"Wheel",
					Vector3.new(0.3, 0.9, 0.9),
					cf * CFrame.new(wx, 0.5, wz),
					C.Ink,
					{ shape = Enum.PartType.Cylinder }
				)
			end
		end
	end
	local function dynamite(cf: CFrame)
		local m = prop(cover, "DynamiteStack", cf, 2.9, true)
		if m then
			local hit = m:FindFirstChild("Hit")
			if hit then
				hit:SetAttribute("Cover", true)
			end
			return
		end
		m = U.model(cover, "DynamiteStack")
		local base = block(m, "Crate", Vector3.new(3.2, 1.6, 3.2), cf * CFrame.new(0, 0.8, 0), C.Timber)
		base:SetAttribute("Cover", true)
		block(
			m,
			"Crate2",
			Vector3.new(2.4, 1.2, 2.4),
			cf * CFrame.new(0.2, 2.2, -0.1) * CFrame.Angles(0, 0.3, 0),
			C.Timber:Lerp(C.TimberDark, 0.2)
		)
		for k = -2, 2 do
			smooth(
				m,
				"Stick",
				Vector3.new(2.6, 0.5, 0.5),
				cf * CFrame.new(0, 1.7, k * 0.55),
				C.Dynamite,
				{ shape = Enum.PartType.Cylinder }
			)
		end
		smooth(m, "Rope", Vector3.new(0.3, 0.62, 2.9), cf * CFrame.new(0, 1.7, 0), C.Cord)
		glow(m, "FuseSpark", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(1.4, 2.0, 0), C.Gold)
	end
	for _, c in ipairs({ { -34, -19, 0.2 }, { 34, 19, -0.15 }, { -12, 25, 0.5 }, { 12, -25, -0.4 } }) do
		cart(CFrame.new(c[1], TOP, c[2]) * CFrame.Angles(0, c[3] + math.rad(90), 0))
	end
	dynamite(CFrame.new(-36, TOP, 24) * CFrame.Angles(0, 0.6, 0))
	dynamite(CFrame.new(36, TOP, -24) * CFrame.Angles(0, -2.4, 0))

	-- ── Far side (−Z): the stepped cliffs and everything on them ─────────────────────────────────────────────
	local far = U.folder(map, "FarSide")
	local TERRACE = { { h = 9, z = FZ - 4 }, { h = 20, z = FZ - 16 }, { h = 32, z = FZ - 30 }, { h = 46, z = FZ - 46 } }
	local wx = -38 -- the waterfall's line (left of centre)
	local GAP = { 13, 8, 8, 8 } -- half-width of each terrace's flat channel round the water (the pool on terrace 1)
	for k, t in ipairs(TERRACE) do
		rockWall(far, Vector3.new(-WALL - 40, 0, t.z), Vector3.new(wx - GAP[k], 0, t.z), t.h, t.h, 14, { 7, 14 })
		rockWall(far, Vector3.new(wx + GAP[k], 0, t.z), Vector3.new(WALL + 40, 0, t.z), t.h, t.h, 14, { 7, 14 })
	end
	local function ledge(k: number, x: number): Vector3 -- a point on top of terrace k, near its front
		local t = TERRACE[k]
		return Vector3.new(x, TOP + t.h - 0.5, t.z + rng:NextNumber(-3, 1))
	end
	-- ── The waterfall: real flowing water, a three-step cascade (the owner, 2026-10-18: "actual real water that
	-- flows down from the top"). A spring on the top terrace feeds a stream that runs to each lip and falls to the
	-- next step, then into the pool on the first. Every sheet is a Beam scrolling the in-house water textures
	-- (art/vfx/make_water.py), so it streams on its own; splash spray and mist where each fall lands; flowing
	-- ripples and foam on the pool. Each terrace gets a flat channel with banks so the water sits exactly on it.
	local water = U.folder(far, "Waterfall")
	local holder =
		smooth(water, "WaterAnchor", Vector3.one * 0.2, Vector3.new(wx, TOP, TERRACE[1].z), C.Water, { t = 1 })
	local function waterBeam(name, p0: Vector3, p1: Vector3, axis: Vector3, across: Vector3, o)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = name .. "0", name .. "1"
		a0.Parent, a1.Parent = holder, holder -- parent first: WorldCFrame is relative to the parent
		-- a non-facing Beam spreads its width along the attachments' Y axis (`across`) and curves along X (`axis`)
		a0.WorldCFrame = CFrame.fromMatrix(p0, axis, across)
		a1.WorldCFrame = CFrame.fromMatrix(p1, axis, across)
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = o.tex
		b.TextureMode = Enum.TextureMode.Static
		b.TextureLength = o.len
		b.TextureSpeed = o.speed
		b.Width0, b.Width1 = o.w0, o.w1 or o.w0
		b.CurveSize0, b.CurveSize1 = o.curve or 0, 0
		b.FaceCamera = false
		b.Segments = o.segments or 10
		b.Color = ColorSequence.new(o.c0, o.c1 or o.c0)
		b.Transparency = o.t or NumberSequence.new(0)
		b.LightEmission = o.emission or 0
		b.LightInfluence = 0.7
		b.ZOffset = o.z or 0
		b.Parent = holder
		return b
	end
	local function emitter(at: Vector3, o)
		local p = smooth(water, o.name, Vector3.one * 0.2, at, C.Foam, { t = 1 })
		local att = Instance.new("Attachment")
		att.Parent = p
		local e = Instance.new("ParticleEmitter")
		e.Texture = o.tex
		e.Color = ColorSequence.new(o.color)
		e.Size = o.size
		e.Transparency = o.trans
		e.Lifetime = o.life
		e.Rate = o.rate
		e.Speed = o.speed
		e.SpreadAngle = o.spread
		e.Acceleration = o.accel or Vector3.zero
		e.EmissionDirection = Enum.NormalId.Top
		e.LightEmission = o.emission or 0.2
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = att
	end
	local function splash(at: Vector3, big: boolean)
		-- droplets thrown up and falling back, and a soft mist cloud
		emitter(at, {
			name = "Spray",
			tex = EMBER,
			color = C.Foam,
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if big then 0.7 else 0.5),
				NumberSequenceKeypoint.new(1, 0.15),
			}),
			trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) }),
			life = NumberRange.new(0.5, 0.9),
			rate = if big then 60 else 30,
			speed = NumberRange.new(5, if big then 11 else 8),
			spread = Vector2.new(55, 35),
			accel = Vector3.new(0, -30, 0),
			emission = 0.4,
		})
		emitter(at + Vector3.new(0, 0.6, 0), {
			name = "Mist",
			tex = SMOKE,
			color = C.Foam,
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if big then 3 else 2),
				NumberSequenceKeypoint.new(1, if big then 8 else 5),
			}),
			trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			life = NumberRange.new(1.4, 2.4),
			rate = if big then 14 else 7,
			speed = NumberRange.new(1.5, 3.5),
			spread = Vector2.new(70, 25),
		})
	end
	local ACROSS = Vector3.new(1, 0, 0)
	local FORWARD = Vector3.new(0, 0, 1)
	local function topOf(k: number): number
		return TOP + TERRACE[k].h - 0.5
	end
	-- the channel on each terrace: a flat rock block at the exact height with a bank on each side
	for k, t in ipairs(TERRACE) do
		local g = GAP[k]
		block(far, "Channel", Vector3.new(g * 2, t.h, 14), Vector3.new(wx, TOP + t.h / 2 - 0.5, t.z), C.Terracotta)
		smooth(
			far,
			"ChannelStrata",
			Vector3.new(g * 2 + 0.2, 1.1, 14.2),
			Vector3.new(wx, TOP + t.h * 0.32, t.z),
			C.Cream
		)
		for _, sx in ipairs({ -1, 1 }) do
			local bank = Vector3.new(wx + sx * (g - 1.6), topOf(k) + 1.2, t.z)
			block(far, "Bank", Vector3.new(3.2, 2.4, 14), bank, C.RedRock)
			block(
				far,
				"BankStone",
				Vector3.new(2, 1.4, 3),
				bank + Vector3.new(0, 1.6, rng:NextNumber(-4, 4)),
				C.Terracotta
			)
		end
	end
	-- the spring at the back of the top terrace: a rock mouth the water pours out of
	local spring = Vector3.new(wx, topOf(4), TERRACE[4].z - 5)
	block(far, "SpringRock", Vector3.new(12, 6, 4), spring + Vector3.new(0, 3, -2.4), C.RedRock)
	smooth(far, "SpringMouth", Vector3.new(7, 2.6, 0.4), spring + Vector3.new(0, 1.5, -0.3), C.Ink)
	-- streams across terraces 4, 3 and 2 (flat sheets with ripples), each falling over its lip to the step below
	local WATER_C0, WATER_C1 = Color3.fromRGB(100, 214, 255), Color3.fromRGB(46, 162, 232)
	for k = 4, 2, -1 do
		local t = TERRACE[k]
		local y = topOf(k) + 0.12
		local back = if k == 4 then spring.Z else t.z - 7
		local lip = t.z + 7
		local w = if k == 4 then 7 else 9
		smooth(
			far,
			"StreamBed",
			Vector3.new(w + 0.6, 0.1, lip - back),
			Vector3.new(wx, y - 0.08, (back + lip) / 2),
			C.WaterDeep,
			{
				material = M.Glass,
				t = 0.05,
			}
		)
		waterBeam("Stream", Vector3.new(wx, y, back), Vector3.new(wx, y, lip), Vector3.yAxis, ACROSS, {
			tex = WATER.Ripple,
			len = 6,
			speed = 1.2,
			w0 = w,
			c0 = Color3.new(1, 1, 1),
			t = NumberSequence.new(0.15),
			emission = 0.3,
		})
		-- the fall: from this lip (bulging forward over it) down to the next step
		local fallTop = Vector3.new(wx, y, lip + 0.3)
		local fallBot = Vector3.new(wx, if k == 2 then topOf(1) + 0.3 else topOf(k - 1) + 0.1, lip + 1.4)
		local fw = w + 0.6
		waterBeam("FallBack", fallTop - Vector3.new(0, 0, 0.25), fallBot - Vector3.new(0, 0, 0.25), FORWARD, ACROSS, {
			tex = WATER.Body,
			len = 16,
			speed = 1.1,
			w0 = fw - 0.6,
			w1 = fw + 0.4,
			curve = 1.6,
			c0 = Color3.fromRGB(40, 140, 210),
			t = NumberSequence.new(0.1),
			z = -1,
		})
		waterBeam("Fall", fallTop, fallBot, FORWARD, ACROSS, {
			tex = WATER.Body,
			len = 12,
			speed = 1.8,
			w0 = fw,
			w1 = fw + 1.2,
			curve = 2,
			c0 = WATER_C0,
			c1 = WATER_C1,
			t = NumberSequence.new(0.05),
			emission = 0.15,
		})
		waterBeam("FallStreaks", fallTop + Vector3.new(0, 0, 0.1), fallBot + Vector3.new(0, 0, 0.1), FORWARD, ACROSS, {
			tex = WATER.Streaks,
			len = 9,
			speed = 2.8,
			w0 = fw,
			w1 = fw + 1.2,
			curve = 2,
			c0 = Color3.new(1, 1, 1),
			t = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.3, 0.15),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
			emission = 0.5,
			z = 1,
		})
		-- the lip's white edge and the splash where it lands
		smooth(far, "LipFoam", Vector3.new(fw, 0.3, 0.8), Vector3.new(wx, y + 0.05, lip - 0.2), C.Foam)
		splash(fallBot + Vector3.new(0, 0.2, 0.6), k == 2)
	end
	-- the pool on the first terrace: a stone rim, deep water, ripples flowing out from the landing, foam at the fall
	local py = topOf(1) + 0.2
	local pz0, pz1 = TERRACE[1].z - 6.5, TERRACE[1].z + 5.5
	local pcz = (pz0 + pz1) / 2
	smooth(far, "Pool", Vector3.new(GAP[1] * 2 - 4, 0.4, pz1 - pz0), Vector3.new(wx, py - 0.1, pcz), C.Water, {
		material = M.Glass,
		t = 0.05,
	})
	smooth(
		far,
		"PoolDeep",
		Vector3.new(GAP[1] * 2 - 10, 0.35, pz1 - pz0 - 5),
		Vector3.new(wx, py - 0.06, pcz),
		C.WaterDeep,
		{
			material = M.Glass,
		}
	)
	block(far, "PoolRim", Vector3.new(GAP[1] * 2 - 2, 1.2, 1.4), Vector3.new(wx, py + 0.3, pz1 + 0.7), C.Cream)
	for _ = 1, 7 do
		block(
			far,
			"RimStone",
			Vector3.new(rng:NextNumber(1.4, 2.6), rng:NextNumber(0.8, 1.6), rng:NextNumber(1.2, 2)),
			Vector3.new(wx + rng:NextNumber(-GAP[1] + 2, GAP[1] - 2), py + 0.6, pz1 + rng:NextNumber(-0.2, 1.2)),
			C.RedRock
		)
	end
	waterBeam(
		"PoolRipples",
		Vector3.new(wx, py + 0.12, pz0 + 1),
		Vector3.new(wx, py + 0.12, pz1),
		Vector3.yAxis,
		ACROSS,
		{
			tex = WATER.Ripple,
			len = 5,
			speed = 0.7,
			w0 = 12,
			w1 = GAP[1] * 2 - 5,
			c0 = Color3.new(1, 1, 1),
			t = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.7) }),
			emission = 0.3,
		}
	)
	waterBeam(
		"PoolFoam",
		Vector3.new(wx, py + 0.16, pz0),
		Vector3.new(wx, py + 0.16, pz0 + 4.5),
		Vector3.yAxis,
		ACROSS,
		{
			tex = WATER.Foam,
			len = 4,
			speed = 0.9,
			w0 = 11,
			w1 = 13,
			c0 = Color3.new(1, 1, 1),
			t = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.6) }),
			emission = 0.3,
		}
	)
	-- the ore head-frame (right of centre) on the second terrace, its chute down to a hopper on the first
	local hx = 42
	local hcf = CFrame.lookAt(ledge(2, hx), ledge(2, hx) + Vector3.new(0, 0, 1))
	if not prop(far, "HeadFrame", hcf, 30) then
		local hbase = hcf.Position
		for _, o in ipairs({
			Vector3.new(-4, 0, -4),
			Vector3.new(4, 0, -4),
			Vector3.new(-4, 0, 4),
			Vector3.new(4, 0, 4),
		}) do
			rod(far, "HeadLeg", hbase + o, hbase + Vector3.new(o.X * 0.4, 26, o.Z * 0.4), 1.2, C.Timber)
		end
		for _, y in ipairs({ 8, 16 }) do
			rod(
				far,
				"HeadBrace",
				hbase + Vector3.new(-3.4, y, 3.4),
				hbase + Vector3.new(3.4, y, 3.4),
				0.7,
				C.TimberDark
			)
			rod(
				far,
				"HeadBrace",
				hbase + Vector3.new(-3.4, y, -3.4),
				hbase + Vector3.new(3.4, y, -3.4),
				0.7,
				C.TimberDark
			)
		end
		smooth(
			far,
			"HeadWheel",
			Vector3.new(0.8, 9, 9),
			CFrame.new(hbase + Vector3.new(0, 27, 0)),
			C.Dynamite,
			{ shape = Enum.PartType.Cylinder }
		)
		smooth(far, "Bucket", Vector3.new(2.4, 2.4, 2.4), hbase + Vector3.new(0, 18, 4), C.Iron, { material = M.Metal })
	end
	local hopper = ledge(1, hx - 20)
	block(far, "Hopper", Vector3.new(6, 4, 6), hopper + Vector3.new(0, 2, 0), C.Timber)
	ball(far, "OrePile", hopper + Vector3.new(0, 4.2, 0), 4.5, C.Gold)
	rod(far, "Chute", ledge(2, hx - 4) + Vector3.new(-2, 12, 2), hopper + Vector3.new(0, 4.4, 0), 2.4, C.TimberDark)
	-- a mine-cart spur along the first terrace (rails + two carts)
	local sz = TERRACE[1].z + 3
	for _, dz in ipairs({ -0.9, 0.9 }) do
		smooth(
			far,
			"SpurRail",
			Vector3.new(70, 0.12, 0.3),
			Vector3.new(70 / 2 - 4, TOP + TERRACE[1].h - 0.4, sz + dz),
			C.Rail,
			{ material = M.Metal }
		)
	end
	for x = -2, 64, 2.4 do
		smooth(
			far,
			"SpurSleeper",
			Vector3.new(0.8, 0.08, 2.8),
			Vector3.new(x, TOP + TERRACE[1].h - 0.46, sz),
			C.TimberDark
		)
	end
	for _, x in ipairs({ 14, 48 }) do
		local cf = CFrame.new(x, TOP + TERRACE[1].h - 0.5, sz) * CFrame.Angles(0, math.rad(90), 0)
		if not prop(far, "MineCart", cf, 2.8) then
			smooth(
				far,
				"SpurCart",
				Vector3.new(3, 1.9, 3.4),
				cf * CFrame.new(0, 1.35, 0),
				C.Iron,
				{ material = M.Metal }
			)
			deco(far, "SpurOre", Vector3.new(2.6, 0.6, 3), cf * CFrame.new(0, 2.4, 0), C.Gold)
		end
	end
	-- scaffolds and ladders up the terraces
	for _, x in ipairs({ -70, -8, 70 }) do
		for k = 1, 3 do
			local lo, hi = TERRACE[k], TERRACE[k + 1]
			local bx = x + (k - 2) * 3
			local base = Vector3.new(bx, TOP + lo.h - 0.5, hi.z + 7.6)
			for _, dx in ipairs({ -0.8, 0.8 }) do
				rod(
					far,
					"LadderRail",
					base + Vector3.new(dx, 0, 0),
					base + Vector3.new(dx, hi.h - lo.h + 2, -1.2),
					0.3,
					C.Timber
				)
			end
			for r = 1, math.floor(hi.h - lo.h), 2 do
				rod(
					far,
					"Rung",
					base + Vector3.new(-0.8, r, -r / (hi.h - lo.h) * 1.2),
					base + Vector3.new(0.8, r, -r / (hi.h - lo.h) * 1.2),
					0.2,
					C.TimberDark
				)
			end
		end
	end
	for _, x in ipairs({ -90, 96 }) do -- timber scaffold towers
		local base = ledge(1, x)
		for _, o in ipairs({
			Vector3.new(-3, 0, -2),
			Vector3.new(3, 0, -2),
			Vector3.new(-3, 0, 2),
			Vector3.new(3, 0, 2),
		}) do
			rod(far, "ScaffoldLeg", base + o, base + o + Vector3.new(0, 14, 0), 0.6, C.Timber)
		end
		for _, y in ipairs({ 5, 10, 14 }) do
			smooth(
				far,
				"ScaffoldDeck",
				Vector3.new(7, 0.4, 5),
				base + Vector3.new(0, y, 0),
				C.Timber:Lerp(C.Cream, 0.15)
			)
		end
		rod(far, "ScaffoldBrace", base + Vector3.new(-3, 0.5, 2), base + Vector3.new(3, 10, 2), 0.35, C.TimberDark)
	end
	-- the water tower (far right, top terrace) and the sign (top ledge, centre)
	local twcf = CFrame.new(ledge(4, 84))
	if not prop(far, "WaterTower", twcf, 22) then
		local tw = twcf.Position
		for _, o in ipairs({
			Vector3.new(-3, 0, -3),
			Vector3.new(3, 0, -3),
			Vector3.new(-3, 0, 3),
			Vector3.new(3, 0, 3),
		}) do
			rod(far, "TowerLeg", tw + o, tw + o * 0.8 + Vector3.new(0, 12, 0), 0.8, C.TimberDark)
		end
		smooth(
			far,
			"Tank",
			Vector3.new(9, 10, 10),
			CFrame.new(tw + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			C.Terracotta,
			{
				shape = Enum.PartType.Cylinder,
			}
		)
		for _, y in ipairs({ 14, 20 }) do
			smooth(
				far,
				"TankBand",
				Vector3.new(0.4, 10.3, 10.3),
				CFrame.new(tw + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				C.Iron,
				{
					shape = Enum.PartType.Cylinder,
				}
			)
		end
		smooth(far, "TankRoof", Vector3.new(11, 1.6, 11), tw + Vector3.new(0, 22.6, 0), C.RedRock)
	end
	local signCf = CFrame.lookAt(ledge(4, 0) + Vector3.new(0, 0, 4), ledge(4, 0) + Vector3.new(0, 0, 50))
	if not prop(far, "QuarrySign", signCf, 12) then
		for _, dx in ipairs({ -12, 12 }) do
			block(far, "SignPost", Vector3.new(1.2, 12, 1.2), signCf * CFrame.new(dx, 6, 0), C.TimberDark)
		end
		local board =
			block(far, "Sign", Vector3.new(32, 8, 1), signCf * CFrame.new(0, 8, -0.6), C.Timber, { stud = false })
		label(board, Enum.NormalId.Back, "FUSE VALLEY QUARRY", C.Gold, 16)
		smooth(far, "SignTrim", Vector3.new(33, 0.8, 1.2), signCf * CFrame.new(0, 12.2, -0.6), C.TimberDark)
		smooth(far, "SignTrim", Vector3.new(33, 0.8, 1.2), signCf * CFrame.new(0, 3.8, -0.6), C.TimberDark)
	end
	-- greenery on the ledges: palms, voxel trees, cacti, scrub
	for i = 1, 46 do
		local k = (i % 4) + 1
		local x = rng:NextNumber(-WALL - 30, WALL + 30)
		if math.abs(x - wx) > GAP[1] + 3 and math.abs(x - hx) > 8 and math.abs(x) > 18 then
			local at = CFrame.new(ledge(k, x)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local r = rng:NextNumber()
			if r < 0.18 then
				if not prop(far, "Palm", at, rng:NextNumber(11, 15)) then
					rod(far, "PalmTrunk", at.Position, at.Position + Vector3.new(0, 11, 0), 1, C.TimberDark)
					block(far, "PalmTop", Vector3.new(7, 1.4, 7), at.Position + Vector3.new(0, 11, 0), C.Cactus)
				end
			elseif r < 0.32 then
				if not prop(far, "VoxelTree", at, rng:NextNumber(9, 12)) then
					block(far, "TreeTop", Vector3.new(6, 6, 6), at.Position + Vector3.new(0, 7, 0), C.Scrub)
				end
			elseif r < 0.7 then
				if
					not prop(far, if rng:NextNumber() < 0.7 then "Cactus" else "CactusSmall", at, rng:NextNumber(4, 7))
				then
					block(far, "Cactus", Vector3.new(1.6, 5, 1.6), at.Position + Vector3.new(0, 2.5, 0), C.Cactus)
					block(
						far,
						"CactusArm",
						Vector3.new(1.2, 2.4, 1.2),
						at.Position + Vector3.new(1.4, 3.2, 0),
						C.CactusDark
					)
					block(
						far,
						"CactusArmUp",
						Vector3.new(1.2, 2, 1.2),
						at.Position + Vector3.new(1.4, 4.6, 0),
						C.Cactus
					)
				end
			else
				block(
					far,
					"Scrub",
					Vector3.new(rng:NextNumber(3, 5), 2.2, rng:NextNumber(3, 5)),
					at.Position + Vector3.new(0, 1.1, 0),
					C.Scrub
				)
				block(
					far,
					"ScrubTop",
					Vector3.new(2.4, 1.4, 2.4),
					at.Position + Vector3.new(0.4, 2.6, 0.2),
					C.Scrub:Lerp(C.Cactus, 0.4)
				)
			end
		end
	end
	-- distant mesas behind everything
	for _, m in ipairs({ { -150, -230, 60, 34 }, { -40, -250, 80, 46 }, { 90, -240, 70, 40 }, { 190, -200, 50, 30 } }) do
		local mesa = block(
			far,
			"Mesa",
			Vector3.new(m[3], m[4], 36),
			Vector3.new(m[1], TOP + m[4] / 2 - 1, m[2]),
			C.Terracotta:Lerp(C.Paper, 0.18)
		)
		mesa.CastShadow = false
		smooth(
			far,
			"MesaStrata",
			Vector3.new(m[3] + 0.2, 2, 36.2),
			Vector3.new(m[1], TOP + m[4] * 0.6, m[2]),
			C.Cream:Lerp(C.Paper, 0.2)
		)
	end

	-- ── Near side (+Z, the lobby's side): low dressing only ──────────────────────────────────────────────────
	local near = U.folder(map, "NearSide")
	local function nearRock(at: Vector3, size: number)
		local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if prop(near, if rng:NextNumber() < 0.5 then "Rock1" else "Rock2", cf, size) then
			return
		end
		local w = size * rng:NextNumber(1.2, 1.7)
		block(
			near,
			"Rock",
			Vector3.new(w, size, w * rng:NextNumber(0.7, 1)),
			cf * CFrame.new(0, size / 2 - 0.2, 0),
			if rng:NextNumber() < 0.5 then C.Terracotta else C.RedRock
		)
		block(
			near,
			"RockCap",
			Vector3.new(w * 0.7, size * 0.3, w * 0.6),
			cf * CFrame.new(rng:NextNumber(-0.4, 0.4), size + size * 0.1 - 0.3, 0),
			C.Cream
		)
	end
	local function nearCactus(at: Vector3)
		local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local small = rng:NextNumber() < 0.5
		if prop(near, if small then "CactusSmall" else "Cactus", cf, if small then 1.7 else rng:NextNumber(3.5, 5)) then
			return
		end
		block(near, "Cactus", Vector3.new(1.2, 3.6, 1.2), cf * CFrame.new(0, 1.8, 0), C.Cactus)
		block(near, "CactusArm", Vector3.new(0.9, 1.6, 0.9), cf * CFrame.new(1, 2.2, 0), C.CactusDark)
	end
	-- row 1, against the rail: rocks, cacti, kegs, crate stacks (all under 3.5 tall)
	for x = -WALL + 4, WALL - 4, 7 do
		local z = HW + 7.5 + rng:NextNumber(-0.8, 1.2)
		local at = Vector3.new(x + rng:NextNumber(-2, 2), TOP, z)
		local r = rng:NextNumber()
		if r < 0.3 then
			nearRock(at, rng:NextNumber(1.6, 2.8))
			nearCactus(at + Vector3.new(2.6, 0, 1.4))
		elseif r < 0.5 then
			for k = 0, rng:NextInteger(1, 2) do
				local kp = at + Vector3.new(k * 2.2, 0, rng:NextNumber(-0.6, 0.6))
				if not prop(near, "PowderKeg", CFrame.new(kp) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 2.4) then
					block(near, "Keg", Vector3.new(1.8, 2.4, 1.8), kp + Vector3.new(0, 1.2, 0), C.Timber)
				end
			end
		elseif r < 0.7 then
			block(
				near,
				"Crate",
				Vector3.new(2.8, 2.4, 2.8),
				CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
				C.Timber
			)
			smooth(near, "CrateStencil", Vector3.new(1.8, 1, 0.05), at + Vector3.new(0, 1.3, -1.43), C.Dynamite)
			if rng:NextNumber() < 0.5 then
				block(
					near,
					"CrateTop",
					Vector3.new(2, 1.6, 2),
					CFrame.new(at + Vector3.new(0.3, 3.2, 0)) * CFrame.Angles(0, 0.5, 0),
					C.Timber:Lerp(C.TimberDark, 0.3)
				)
			end
		else
			nearCactus(at)
			nearCactus(at + Vector3.new(1.8, 0, 1.6))
		end
	end
	-- row 2, low rock ridges and ore piles further out (the lobby looks over them)
	for x = -WALL - 10, WALL + 10, 13 do
		local base = Vector3.new(x + rng:NextNumber(-3, 3), TOP, HW + 16 + rng:NextNumber(-2, 4))
		for k = 0, rng:NextInteger(2, 4) do
			nearRock(
				base + Vector3.new(k * 2.6 + rng:NextNumber(-1, 1), 0, rng:NextNumber(-1.5, 1.5)),
				rng:NextNumber(1.2, 2.4)
			)
		end
		if rng:NextNumber() < 0.4 then
			ball(near, "OrePile", base + Vector3.new(-3, 0.2, 2), 2.6, C.Gold)
			ball(near, "OrePile", base + Vector3.new(-1.6, 0.1, 2.8), 1.8, C.Gold:Lerp(C.Terracotta, 0.3))
		end
		if rng:NextNumber() < 0.5 then
			nearCactus(base + Vector3.new(4, 0, 3))
		end
	end
	-- a parked cart on a short spur by the near rail
	local pcf = CFrame.new(-56, TOP, HW + 14) * CFrame.Angles(0, 0.2, 0)
	if not prop(near, "MineCart", pcf, 2.8) then
		smooth(
			near,
			"ParkedCart",
			Vector3.new(3, 1.9, 3.4),
			pcf * CFrame.new(0, 1.35, 0),
			C.Iron,
			{ material = M.Metal }
		)
	end

	-- Onto the Yard's field frame.
	map:PivotTo(map:GetPivot() + PLACE_OFFSET)
	local n = 0
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return ("Quarry built: %d parts"):format(n)
end
