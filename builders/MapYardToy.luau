-- "The Fireworks Yard" restyled to the owner's reference video (DECISIONS 2026-10-17: "restyle the map to the video's
-- bright, studded, toy-like look"; concept art: art/ref/map/yard_concept_overview.png). A pass that runs AFTER
-- MapYard on the built map, so the layout, the gameplay contract and every prop stay exactly as MapYard made them:
--   • recolours every part from MapYard's palette to the toy palette (sky-blue field, green SAFE docks, red-orange
--     toy-brick factory with cream trim, yellow crane, bright crates), plastic instead of concrete / brick / metal,
--     and the shared stud texture on the top faces (Theme.StudTexture);
--   • drops the grime / oil / chalk decals (the toy world is clean), keeps the hazard lanes and the bomb roundel;
--   • adds the concept's dressing around the yard: voxel trees and palms, giant striped rockets at the corners,
--     rainbow bleachers along the near side, puffy clouds;
--   • sets sunny midday light (bright blue sky, saturated, crisp shadows).
-- Re-runnable: it rebuilds its own "Toy" folder; run MapYard first for a clean base.

local rgb = Color3.fromRGB

-- MapYard's palette → the toy palette (nearest match within TOL; lerped shades map to their nearest source).
local MAP = {
	{ rgb(170, 162, 150), rgb(132, 202, 246) }, -- Concrete → field sky-blue
	{ rgb(58, 54, 50), rgb(236, 244, 255) }, -- Joint → white lines
	{ rgb(190, 184, 172), rgb(70, 196, 70) }, -- Dock → SAFE green
	{ rgb(70, 68, 72), rgb(84, 88, 104) }, -- Asphalt → toy grey
	{ rgb(196, 190, 178), rgb(240, 240, 246) }, -- Kerb → white
	{ rgb(156, 80, 60), rgb(222, 74, 48) }, -- Brick → toy red
	{ rgb(118, 58, 44), rgb(176, 50, 36) }, -- BrickDark → deep red
	{ rgb(232, 218, 194), rgb(255, 238, 200) }, -- Stone → cream trim
	{ rgb(66, 70, 80), rgb(62, 72, 104) }, -- Steel → slate blue
	{ rgb(128, 134, 146), rgb(168, 182, 206) }, -- SteelLight → light steel
	{ rgb(78, 122, 140), rgb(46, 150, 226) }, -- Shutter → bright blue
	{ rgb(244, 182, 42), rgb(255, 208, 40) }, -- Crane → yellow
	{ rgb(182, 128, 78), rgb(226, 148, 70) }, -- Wood → toy orange-wood
	{ rgb(116, 78, 48), rgb(160, 96, 46) }, -- WoodDark
	{ rgb(186, 160, 112), rgb(238, 200, 128) }, -- Canvas → sand
	{ rgb(118, 150, 76), rgb(78, 200, 58) }, -- Grass → bright green
	{ rgb(92, 124, 62), rgb(56, 168, 44) }, -- GrassDark
	{ rgb(70, 120, 150), rgb(58, 176, 236) }, -- Water → bright blue
	{ rgb(34, 32, 36), rgb(40, 40, 52) }, -- Rubber
}
local TOL = 26
local CRATE_COLORS = { rgb(232, 64, 56), rgb(52, 124, 236), rgb(255, 200, 40), rgb(150, 76, 230), rgb(56, 190, 80) }
local DROP_TEX = { -- MapYard's TEX.Grime / Oil / Chalk
	["rbxassetid://93799948708188"] = true,
	["rbxassetid://82471392661454"] = true,
	["rbxassetid://109155774330745"] = true,
}
local PLASTIC_FROM = {
	[Enum.Material.Concrete] = true,
	[Enum.Material.Brick] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Pavement] = true,
	[Enum.Material.Asphalt] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.Plastic] = true,
}

local function dist(a: Color3, b: Color3): number
	local dr, dg, db = (a.R - b.R) * 255, (a.G - b.G) * 255, (a.B - b.B) * 255
	return math.sqrt(dr * dr + dg * dg + db * db)
end

local function remap(c: Color3): Color3?
	local best, bestD = nil, TOL
	for _, pair in ipairs(MAP) do
		local d = dist(c, pair[1])
		if d < bestD then
			best, bestD = pair, d
		end
	end
	if not best then
		return nil
	end
	-- keep the original's light/dark offset from its source shade (MapYard lerps for variation)
	local src, dst = best[1], best[2]
	local dv = ((c.R + c.G + c.B) - (src.R + src.G + src.B)) / 3
	return Color3.new(math.clamp(dst.R + dv, 0, 1), math.clamp(dst.G + dv, 0, 1), math.clamp(dst.B + dv, 0, 1))
end

return function(ctx)
	local T = ctx.req("Theme")
	local maps = workspace:FindFirstChild("Maps")
	local map = maps and maps:FindFirstChild("Yard")
	assert(map, "Build MapYard first (workspace.Maps.Yard)")
	local old = map:FindFirstChild("Toy")
	if old then
		old:Destroy()
	end
	local rng = Random.new(20261017)

	-- ── 1. Recolour + plastic + studs ────────────────────────────────────────────────────────────────────────────
	local recoloured, studded = 0, 0
	local zf = map:FindFirstChild("Zones", true)
	local fz = zf and zf:FindFirstChild("Field")
	local floorYGuess = if fz and fz:IsA("BasePart") then fz.Position.Y - fz.Size.Y / 2 else 0
	local function stud(p: BasePart, faces: { Enum.NormalId })
		for _, f in ipairs(faces) do
			local tex = Instance.new("Texture")
			tex.Name = "Studs"
			tex.Texture = T.StudTexture
			tex.Face = f
			tex.StudsPerTileU = T.StudTile
			tex.StudsPerTileV = T.StudTile
			tex.Parent = p
		end
		studded += 1
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("Texture") then
			if DROP_TEX[d.Texture] then
				d:Destroy()
			end
		elseif d:IsA("BasePart") then
			if d.Material ~= Enum.Material.Neon and d.Material ~= Enum.Material.Glass and d.Transparency < 0.9 then
				local c = remap(d.Color)
				if c then
					d.Color = c
					recoloured += 1
				end
				if PLASTIC_FROM[d.Material] then
					d.Material = Enum.Material.SmoothPlastic
				end
				-- studs on the walkable tops of big slabs (field, docks, grass, asphalt, roofs)
				local s = d.Size
				if not d:FindFirstChild("Studs") and s.X >= 4 and s.Z >= 4 and s.Y <= math.min(s.X, s.Z) then
					stud(d, { Enum.NormalId.Top })
				end
			end
		elseif d:IsA("TextLabel") and string.upper(d.Text) == "SAFE" then
			d.TextColor3 = Color3.new(1, 1, 1)
			d.TextTransparency = 0
		elseif
			d:IsA("TextLabel")
			and string.find(d:GetFullName(), "Factory")
			and string.find(d:GetFullName(), "Sign")
		then
			-- the factory sign: big gold round letters with a thick dark-red outline on the red board
			d.TextColor3 = rgb(255, 226, 70)
			d.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
			local st = d:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			st.Color = rgb(96, 16, 16)
			st.Thickness = 2.5
			st.Parent = d
		end
	end
	-- name overrides where the concept wants a different colour than the palette swap gives
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d.Material ~= Enum.Material.Neon then
			local n, parentName = d.Name, d.Parent and d.Parent.Name or ""
			if n == "Apron" and parentName == "Ground" then
				-- the yard's surroundings are grass; the narrow front strip stays the grey parking lot
				d.Color = if d.Size.Z <= 30 then rgb(88, 94, 112) else rgb(76, 198, 58)
			elseif n == "Coping" and parentName == "Warehouse" then
				d.Color = rgb(226, 56, 44) -- the red canopy roofs over the docks
			elseif n == "Cladding" and parentName == "Warehouse" then
				d.Color = rgb(255, 206, 60)
			elseif n == "Bedrock" then
				d.Color = rgb(64, 168, 48)
			elseif n == "Lane" and parentName == "HazardLanes" then
				d.Color = rgb(255, 212, 40) -- the hazard lanes: yellow under their black stripes
			elseif string.find(d:GetFullName(), "Sign") and select(3, d.Color:ToHSV()) < 0.22 then
				d.Color = rgb(206, 36, 40) -- the factory sign's board: bright red behind the neon letters
			end
			-- the field: saturated sky-blue slabs (the palette swap's pale blue washed out in the sun) over a white
			-- joint bed, so the expansion joints read as the concept's white grid lines
			if n == "Slab" and parentName == "Yard" then
				d.Color = Color3.fromHSV(0.58, rng:NextNumber(0.6, 0.66), rng:NextNumber(0.9, 0.96))
			elseif n == "JointBed" then
				d.Color = rgb(246, 250, 255)
			end
			local _ = floorYGuess
			if
				math.abs(d.Color.R * 255 - 62) < 6
				and math.abs(d.Color.G * 255 - 72) < 6
				and math.abs(d.Color.B * 255 - 104) < 6
			then
				d.Color = rgb(72, 88, 150) -- roofs: a richer slate blue
			end
		end
	end
	-- crates on the field: each body a bright colour
	local cover = map:FindFirstChild("Cover", true)
	if cover then
		local i = 0
		for _, m in ipairs(cover:GetChildren()) do
			i += 1
			local col = CRATE_COLORS[(i - 1) % #CRATE_COLORS + 1]
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon and p.Size.Magnitude > 2.5 then
					local h, s, v = p.Color:ToHSV()
					if s < 0.55 and v > 0.25 then -- the wooden body, not the brass / rockets on it
						p.Color = col:Lerp(Color3.new(1, 1, 1), math.clamp((v - 0.5) * 0.4, 0, 0.2))
					end
					local _ = h
				end
			end
		end
	end

	-- ── 2. Where things are ──────────────────────────────────────────────────────────────────────────────────────
	local zones = map:FindFirstChild("Zones", true)
	local field = zones and zones:FindFirstChild("Field")
	assert(field and field:IsA("BasePart"), "Yard has no Zones/Field")
	local fc = field.Position
	local floorY = fc.Y - field.Size.Y / 2
	local HL, HW = field.Size.X / 2, field.Size.Z / 2
	local bbCF, bbSize = map:GetBoundingBox()
	local minX, maxX = bbCF.Position.X - bbSize.X / 2, bbCF.Position.X + bbSize.X / 2
	local minZ, maxZ = bbCF.Position.Z - bbSize.Z / 2, bbCF.Position.Z + bbSize.Z / 2

	local toy = Instance.new("Folder")
	toy.Name = "Toy"
	toy.Parent = map
	local function part(parent, n, size: Vector3, cf: CFrame, color: Color3, o)
		o = o or {}
		local p = Instance.new("Part")
		p.Name = n
		p.Anchored = true
		p.CanCollide = o.collide == true
		p.CanQuery = o.collide == true
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = o.mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if o.shape then
			p.Shape = o.shape
			p.Size = size
		end
		if o.stud ~= false and not o.shape and size.X >= 1.5 and size.Z >= 1.5 then
			stud(
				p,
				{ Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
			)
		end
		p.Parent = parent
		return p
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	-- the ground under a point, and whether it's land (a part of the map, not the sea)
	local function groundAt(x: number, z: number): (number, boolean)
		local hit = workspace:Raycast(Vector3.new(x, floorY + 200, z), Vector3.new(0, -400, 0), params)
		if hit and hit.Instance.Parent and hit.Instance.Parent.Name ~= "Toy" then
			return hit.Position.Y, true
		end
		return floorY, false
	end
	local function ground(x: number, z: number): number
		return (groundAt(x, z))
	end
	local function clear(x: number, z: number, r: number): boolean
		-- keep the dressing off the playfield, the docks and the factory footprint
		local inYard = math.abs(x - fc.X) < HL + 26 + r and math.abs(z - fc.Z) < HW + 14 + r
		return not inYard
	end

	-- ── 3. Voxel trees and palms ─────────────────────────────────────────────────────────────────────────────────
	local GREENS = { rgb(64, 190, 56), rgb(46, 166, 48), rgb(92, 210, 70) }
	local function voxelTree(at: Vector3, s: number)
		local m = Instance.new("Model")
		m.Name = "VoxelTree"
		local trunkH = 5 * s
		part(
			m,
			"Trunk",
			Vector3.new(1.8, trunkH, 1.8) * Vector3.new(s, 1, s),
			CFrame.new(at + Vector3.new(0, trunkH / 2, 0)),
			rgb(150, 92, 48)
		)
		local y = at.Y + trunkH
		for i, w in ipairs({ 9, 7, 4.5 }) do
			local h = 3.2 * s
			part(
				m,
				"Leaves" .. i,
				Vector3.new(w * s, h, w * s),
				CFrame.new(at.X, y + h / 2, at.Z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 15), 0),
				GREENS[rng:NextInteger(1, #GREENS)]
			)
			y += h * 0.92
		end
		m.Parent = toy
	end
	local function palm(at: Vector3, s: number)
		local m = Instance.new("Model")
		m.Name = "Palm"
		local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * 0.12
		local p = at
		local seg = 2.2 * s
		for i = 1, 7 do
			local dir = (Vector3.yAxis + lean * i * 0.6).Unit
			local nxt = p + dir * seg
			local c = part(
				m,
				"Trunk" .. i,
				Vector3.new(seg + 0.2, 1.5 * s - i * 0.06, 1.5 * s - i * 0.06),
				CFrame.lookAt((p + nxt) / 2, nxt) * CFrame.Angles(0, math.rad(90), 0),
				if i % 2 == 0 then rgb(196, 132, 70) else rgb(170, 108, 54),
				{ shape = Enum.PartType.Cylinder }
			)
			c.CanCollide = false
			p = nxt
		end
		for k = 1, 7 do
			local yaw = math.rad(k * 360 / 7 + rng:NextNumber(-10, 10))
			local leaf = part(
				m,
				"Frond" .. k,
				Vector3.new(1.2 * s, 0.35 * s, 7 * s),
				CFrame.new(p)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(math.rad(-22), 0, 0)
					* CFrame.new(0, 0, -3.2 * s),
				GREENS[(k % #GREENS) + 1],
				{ stud = false }
			)
			leaf.CanCollide = false
		end
		part(
			m,
			"Coconut",
			Vector3.new(1.2, 1.2, 1.2) * s,
			CFrame.new(p - Vector3.new(0, 0.6 * s, 0)),
			rgb(120, 76, 40),
			{ shape = Enum.PartType.Ball }
		)
		m.Parent = toy
	end
	local placed = 0
	local tries = 0
	while placed < 70 and tries < 900 do
		tries += 1
		local x = rng:NextNumber(minX - 30, maxX + 30)
		local z = rng:NextNumber(minZ - 40, maxZ + 20)
		local y, land = groundAt(x, z)
		if land and clear(x, z, 10) and y < floorY + 40 then
			if rng:NextNumber() < 0.55 then
				voxelTree(Vector3.new(x, y, z), rng:NextNumber(0.9, 1.5))
			else
				palm(Vector3.new(x, y, z), rng:NextNumber(0.9, 1.3))
			end
			placed += 1
		end
	end

	-- ── 4. Giant striped rockets at the yard's corners ───────────────────────────────────────────────────────────
	local function rocket(at: Vector3, colA: Color3, colB: Color3, h: number)
		local m = Instance.new("Model")
		m.Name = "GiantRocket"
		local r = h * 0.11
		local n = 6
		for i = 1, n do
			local seg = h / n
			part(
				m,
				"Body" .. i,
				Vector3.new(seg, r * 2, r * 2),
				CFrame.new(at + Vector3.new(0, (i - 0.5) * seg, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				if i % 2 == 0 then colA else colB,
				{ shape = Enum.PartType.Cylinder }
			)
		end
		-- the nose: stacked shrinking discs
		for k = 1, 6 do
			local f = 1 - k / 7
			part(
				m,
				"Nose" .. k,
				Vector3.new(h * 0.05, r * 2 * f + 0.2, r * 2 * f + 0.2),
				CFrame.new(at + Vector3.new(0, h + k * h * 0.045, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				colA,
				{ shape = Enum.PartType.Cylinder }
			)
		end
		for k = 1, 4 do
			local yaw = math.rad(k * 90)
			part(
				m,
				"Fin" .. k,
				Vector3.new(0.5, h * 0.22, r * 1.4),
				CFrame.new(at + Vector3.new(0, h * 0.1, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, r * 1.2),
				colB,
				{ stud = false }
			)
		end
		m.Parent = toy
	end
	local cx = HL + 30
	local zNear, zFar = fc.Z + HW + 18, fc.Z - HW - 20
	for _, spot in ipairs({
		{ -cx, zNear, rgb(232, 56, 48), rgb(255, 255, 255) },
		{ cx, zNear, rgb(52, 120, 236), rgb(255, 255, 255) },
		{ -cx - 8, zFar, rgb(255, 196, 30), rgb(232, 56, 48) },
		{ cx + 8, zFar, rgb(150, 70, 230), rgb(255, 210, 60) },
	}) do
		local x, z = fc.X + spot[1], spot[2]
		rocket(Vector3.new(x, ground(x, z), z), spot[3], spot[4], 22)
	end

	-- ── 5. Rainbow bleachers along the near side ─────────────────────────────────────────────────────────────────
	local RAINBOW = {
		rgb(232, 64, 56),
		rgb(255, 150, 40),
		rgb(255, 214, 46),
		rgb(70, 196, 70),
		rgb(52, 124, 236),
		rgb(150, 76, 230),
	}
	local benchZ = fc.Z + HW + 22.5 -- on the quay, between the parking bays and the bollards
	for blockI, x0 in ipairs({ -64, -20, 24 }) do
		for row = 0, 2 do
			for col = 0, 9 do
				local x = fc.X + x0 + col * 4
				local z = benchZ + row * 3
				local y = ground(x, z)
				part(
					toy,
					"Seat",
					Vector3.new(4, 1.4 + row * 1.4, 3),
					CFrame.new(x + 2, y + (1.4 + row * 1.4) / 2, z),
					RAINBOW[((col + row + blockI) % #RAINBOW) + 1],
					{ collide = true }
				)
			end
		end
	end

	-- ── 6. Sunny midday (the video's lighting) ───────────────────────────────────────────────────────────────────
	-- the preset lives in Config.Lighting.ToyMidday (shared, so the game and the builder agree)
	local L = game:GetService("Lighting")
	local preset = require(game:GetService("ReplicatedStorage").Shared.Config.Lighting).ToyMidday
	local function apply(inst: Instance?, props: { [string]: any })
		if inst then
			for k, v in pairs(props) do
				(inst :: any)[k] = v
			end
		end
	end
	apply(L, preset.Lighting)
	apply(L:FindFirstChildOfClass("Atmosphere"), preset.Atmosphere)
	apply(L:FindFirstChildOfClass("ColorCorrectionEffect"), preset.ColorCorrection)
	apply(L:FindFirstChildOfClass("BloomEffect"), preset.Bloom)
	local sky = L:FindFirstChildOfClass("Sky")
	if sky then
		sky.SunAngularSize = 14
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.75
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = workspace.Terrain

	-- The place keeps the Yard at an offset from where MapYard builds it (Field at 0, 16, 0 → -3, 94, -38); restore it
	-- after a fresh rebuild so it sits where the rest of the place expects it.
	local PLACE_OFFSET = Vector3.new(-3, 78, -38)
	if (field.Position - Vector3.new(0, 16, 0)).Magnitude < 1 then
		map:PivotTo(map:GetPivot() + PLACE_OFFSET)
	end
	return ("Toy pass: %d recoloured, %d studded, %d trees, bleachers + 4 rockets"):format(recoloured, studded, placed)
end
