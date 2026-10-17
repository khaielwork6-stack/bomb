-- Map 1 v2: "The Meadow" (2026-10-09), the home map every new player sees from the lobby, rebuilt to the user's
-- ChatGPT concept set (Work, GPT-6 Astra) as a championship lawn on a floating farm island beside the lobby island:
--   • the field: a studded lawn mown in a big two-green checker, a white centre circle;
--   • left end (−X): the WINDMILL END, a storybook windmill (its sails turn) on a knoll, a duck pond and a bridge;
--   • right end (+X): the BARN END, a red barn with white trim, a silo, a tractor, stacked hay;
--   • both long sides: white picket fences on lavender-stone kerbs, lanterns; the near side (+Z, the lobby's) low;
--   • far side (−Z): the grandstand under red-and-white awnings (CrowdController, standSides { -1 }), rolling hills,
--     oak and blossom trees, a scarecrow, bunting, hot-air balloons drifting;
--   • the island's lavender cliffs drop to the sea with waterfalls, like the lobby's.
-- Same script contract as every map (MapKit.contract). Keep clear: the field, the stands at z −66…−87, the runtime
-- back walls at x = ±110, and the lobby island's side (z > 70 between x = −90 and 90).

return function(ctx, parent)
	local K = ctx.req("MapKit").new(
		ctx,
		parent or workspace:FindFirstChild("Maps") or ctx.req("Util").folder(workspace, "Maps"),
		"Meadow",
		{ display = "THE MEADOW", seed = 4242 }
	)
	local T, U = K.T, K.U
	local F = T.Farm
	local M = T.Map
	local map, rng, TOP = K.map, K.rng, K.TOP
	local HX, HZ = K.HALF_X, K.HALF_Z
	local block, glow = K.block, K.glow
	local SMOOTH = Enum.Material.SmoothPlastic

	K.useArt(F.Props, {
		Hay = { F.Hay, SMOOTH },
		HayDark = { F.Hay:Lerp(Color3.new(0.5, 0.35, 0.1), 0.18), SMOOTH },
		Straw = { F.Hay:Lerp(Color3.new(1, 1, 0.8), 0.2), SMOOTH },
		Twine = { F.BarnRed, SMOOTH },
		Sail = { F.Trim, Enum.Material.Fabric },
		SailRed = { F.BarnRed, Enum.Material.Fabric },
		Frame = { F.WoodDark, Enum.Material.Wood },
		Body = { F.BarnRed, SMOOTH },
		Tyre = { Color3.fromRGB(36, 36, 40), SMOOTH },
		Hub = { M.ShipTrim, Enum.Material.Metal },
		Glass = { Color3.fromRGB(180, 220, 240), Enum.Material.Glass, 0.4 },
		Grille = { Color3.fromRGB(40, 40, 44), SMOOTH },
		Trunk = { M.Trunk, Enum.Material.Wood },
		Leaf = { M.Leaf, SMOOTH },
		LeafDark = { M.LeafDeep, SMOOTH },
		Balloon = { Color3.fromRGB(250, 196, 64), Enum.Material.Fabric },
		Stripe = { Color3.fromRGB(226, 70, 60), Enum.Material.Fabric },
		Basket = { Color3.fromRGB(160, 112, 64), Enum.Material.Wood },
		Rope = { Color3.fromRGB(90, 70, 50), SMOOTH },
		Picket = { F.Trim, SMOOTH },
		Pumpkin = { Color3.fromRGB(236, 120, 30), SMOOTH },
		Stem = { Color3.fromRGB(90, 120, 50), SMOOTH },
		Glow = { Color3.fromRGB(255, 190, 80), Enum.Material.Neon },
		Wood = { M.ShipRail, Enum.Material.Wood },
		WoodDark = { M.ShipHullDark, Enum.Material.Wood },
		Iron = { M.ShipIron, Enum.Material.Metal },
		Brass = { M.ShipTrim, Enum.Material.Metal },
	})

	local NEAR = HZ + 4

	local function recolor(m: Instance?, role: string, color: Color3)
		if not m then
			return
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name:gsub("%.%d+$", "") == role then
				d.Color = color
			end
		end
	end
	-- A slab whose centre line runs from a to b (its length along that line, `width` across, `thick` thick), its
	-- broad face turned up: roof planes, ramps.
	local function plate(p, n, a: Vector3, b: Vector3, width: number, thick: number, color, o)
		local d = b - a
		local cf = CFrame.lookAt((a + b) / 2, b)
		-- Turn so the width runs horizontally (the line's own right vector).
		return block(p, n, Vector3.new(width, thick, d.Magnitude), cf, color, o)
	end
	local function lantern(into, at: Vector3, h: number)
		local m = K.prop(into, "Lantern", at, h)
		local g = m and m:FindFirstChild("Glow", true)
		if g and g:IsA("BasePart") then
			K.light(g, M.Lantern, 14, 1.2)
		elseif not m then
			glow(into, "Lantern", Vector3.new(1, 1.3, 1), at + Vector3.new(0, h / 2, 0), M.Lantern, 14)
		end
	end
	local function tree(into, at: Vector3, h: number, blossom: boolean?)
		local m = K.prop(into, "OakTree", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), h)
		if m and blossom then
			recolor(m, "Leaf", F.Blossom)
			recolor(m, "LeafDark", F.Blossom:Lerp(Color3.fromRGB(230, 120, 160), 0.4))
		elseif not m then
			U.tree(into, at, h / 16, rng)
		end
	end
	local function bale(into, at: CFrame, h: number)
		return K.prop(into, "HayBale", at, h)
	end

	-- ── The island: grass on lavender stone, cliffs and waterfalls round the rim ──────────────────
	local island = U.model(map, "Island")
	local IX0, IX1, IZ0, IZ1 = -178, 178, -132, NEAR + 3
	block(
		island,
		"Bedrock",
		Vector3.new(IX1 - IX0, TOP + 8, IZ1 - IZ0),
		Vector3.new(0, (TOP - 2) / 2 - 5, (IZ0 + IZ1) / 2),
		F.Stone,
		{ stud = 4 }
	)
	-- The lawn round the field (a hair below the field, studded), in a few soft tones.
	K.tiles(island, {
		x0 = IX0 + 2,
		x1 = IX1 - 2,
		z0 = IZ0 + 2,
		z1 = IZ1,
		tx = 16,
		tz = 16,
		seam = 0,
		y = TOP - 0.3,
		thick = 1.5,
		name = "Ground",
		color = function()
			return K.vary(F.Lawn, 0.04)
		end,
	})
	local cliffs = U.folder(island, "Cliffs")
	local function cliffRun(a: Vector3, b: Vector3, outward: Vector3)
		local len = (b - a).Magnitude
		local n = math.floor(len / 14)
		for i = 0, n - 1 do
			local at = a:Lerp(b, (i + 0.5) / n)
			local h = TOP + 7 + rng:NextNumber(-3, 2)
			local depth = rng:NextNumber(3, 6)
			local yaw = math.atan2(outward.X, outward.Z)
			local cf = CFrame.new(at + outward * (depth / 2 - 1) + Vector3.new(0, h / 2 - 7.5, 0))
				* CFrame.Angles(0, yaw + rng:NextNumber(-0.05, 0.05), 0)
			block(
				cliffs,
				"Cliff",
				Vector3.new(len / n + rng:NextNumber(0, 3), h, depth),
				cf,
				if i % 2 == 0 then F.Stone else F.StoneDark,
				{ stud = 4 }
			)
			block(
				cliffs,
				"GrassLip",
				Vector3.new(len / n + 1, 1.2, depth + 0.6),
				cf * CFrame.new(0, h / 2 + 0.1, 0),
				F.Lawn,
				{
					stud = 2,
				}
			)
		end
	end
	cliffRun(Vector3.new(IX0, 0, IZ1), Vector3.new(IX1, 0, IZ1), Vector3.zAxis)
	cliffRun(Vector3.new(IX0, 0, IZ0), Vector3.new(IX1, 0, IZ0), -Vector3.zAxis)
	cliffRun(Vector3.new(IX0, 0, IZ0), Vector3.new(IX0, 0, IZ1), -Vector3.xAxis)
	cliffRun(Vector3.new(IX1, 0, IZ0), Vector3.new(IX1, 0, IZ1), Vector3.xAxis)
	local falls = U.folder(island, "Waterfalls")
	local function waterfall(top: Vector3, outward: Vector3, w: number)
		local h = top.Y + 2
		local yaw = math.atan2(outward.X, outward.Z)
		local at = top + outward * 1.4
		local sheet = block(
			falls,
			"Fall",
			Vector3.new(w, h, 1),
			CFrame.new(at.X, h / 2 - 1.5, at.Z) * CFrame.Angles(0, yaw, 0),
			M.Foam,
			{ stud = false, collide = false, transparency = 0.15 }
		)
		sheet.Material = Enum.Material.Glass
		block(
			falls,
			"Foam",
			Vector3.new(w + 6, 0.6, 6),
			CFrame.new(at.X, 0.2, at.Z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 2.5),
			M.Foam,
			{ stud = 1, collide = false, shadow = false }
		)
	end
	for _, x in ipairs({ -150, -110, 112, 152 }) do
		waterfall(Vector3.new(x, TOP - 1, IZ1 + 2), Vector3.zAxis, rng:NextNumber(6, 9))
	end
	for _, x in ipairs({ -120, -20, 60, 140 }) do
		waterfall(Vector3.new(x, TOP - 1, IZ0 - 2), -Vector3.zAxis, rng:NextNumber(7, 10))
	end
	for _, z in ipairs({ -90, -20, 40 }) do
		waterfall(Vector3.new(IX0 - 2, TOP - 1, z), -Vector3.xAxis, 8)
		waterfall(Vector3.new(IX1 + 2, TOP - 1, z), Vector3.xAxis, 8)
	end

	-- ── The field: a studded lawn mown in a big two-green checker, a white centre circle ───────────
	local field = U.model(map, "Field")
	K.tiles(field, {
		x0 = -HX,
		x1 = HX,
		z0 = -HZ,
		z1 = HZ,
		tx = 10,
		tz = 10,
		seam = 0.12,
		sub = F.HillDark,
		name = "Turf",
		color = function(ix, iz)
			local c = if ((ix // 2) + (iz // 2)) % 2 == 0 then F.GrassA else F.GrassB
			return K.vary(c, 0.012)
		end,
	})
	local paint = U.folder(field, "CentreCircle")
	local R = 15
	for k = 0, 39 do
		local a = k * math.pi * 2 / 40
		block(
			paint,
			"Circle",
			Vector3.new(0.9, 0.06, R * math.pi * 2 / 40 + 0.15),
			CFrame.new(math.cos(a) * R, TOP + 0.03, math.sin(a) * R) * CFrame.Angles(0, -a, 0),
			M.Line,
			{ stud = false, collide = false, shadow = false }
		)
	end
	block(paint, "Spot", Vector3.new(2, 0.06, 2), Vector3.new(0, TOP + 0.03, 0), M.Line, {
		stud = false,
		collide = false,
		shadow = false,
	})
	K.contract({ green = M.SafeGreen, checkDark = Color3.fromRGB(40, 40, 46) })

	-- ── Picket fences on lavender-stone kerbs, lanterns on every third post ───────────────────────
	local fences = U.folder(map, "Fences")
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (HZ + 2.2)
		block(fences, "Kerb", Vector3.new(HX * 2 + 6, 1, 2.4), Vector3.new(0, TOP + 0.5, z), F.Kerb, { stud = 1 })
		local n = 0
		K.run(Vector3.new(-HX - 3, TOP + 1, z), Vector3.new(HX + 3, TOP + 1, z), 10, function(i, at, count)
			block(fences, "Post", Vector3.new(1, 3.8, 1), at + Vector3.new(0, 1.9, 0), F.Trim, { stud = 1 })
			K.ball(fences, "PostCap", at + Vector3.new(0, 4, 0), 1.1, F.Trim)
			if i % 3 == 0 then
				lantern(fences, at + Vector3.new(0, 4.4, 0), 2.2)
			end
			if i < count then
				n += 1
				local seg = (2 * HX + 6) / count
				local mid = at + Vector3.new(seg / 2, 0, 0)
				if not K.prop(fences, "Picket", CFrame.lookAt(mid, mid + Vector3.zAxis * s), nil, seg - 1.1) then
					block(
						fences,
						"Rail",
						Vector3.new(9, 0.4, 0.3),
						mid + Vector3.new(0, 2.4, 0),
						F.Trim,
						{ stud = false }
					)
				end
			end
		end)
	end

	-- Fences across both short ends too (behind the safe zones), a gate gap in the middle of each.
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (HX + 2.4)
		block(fences, "Kerb", Vector3.new(2.4, 1, HZ * 2 + 6), Vector3.new(x, TOP + 0.5, 0), F.Kerb, { stud = 1 })
		for _, zs in ipairs({ { -HZ - 2, -8 }, { 8, HZ + 2 } }) do
			K.run(Vector3.new(x, TOP + 1, zs[1]), Vector3.new(x, TOP + 1, zs[2]), 10, function(i, at, count)
				block(fences, "Post", Vector3.new(1, 3.8, 1), at + Vector3.new(0, 1.9, 0), F.Trim, { stud = 1 })
				K.ball(fences, "PostCap", at + Vector3.new(0, 4, 0), 1.1, F.Trim)
				if i == count then
					lantern(fences, at + Vector3.new(0, 4.4, 0), 2.2)
				end
				if i < count then
					local seg = (zs[2] - zs[1]) / count
					local mid = at + Vector3.new(0, 0, seg / 2)
					K.prop(fences, "Picket", CFrame.lookAt(mid, mid + Vector3.xAxis * s), nil, seg - 1.1)
				end
			end)
		end
	end

	-- Bushes and flower beds round the edges (the concept is lush everywhere off the field).
	local garden = U.folder(map, "Garden")
	local function bush(at: Vector3, size: number)
		local m = U.model(garden, "Bush")
		for k = 0, 2 do
			local a = k * 2.1 + rng:NextNumber(-0.4, 0.4)
			local r = size * (0.42 - k * 0.06)
			K.ball(
				m,
				"Leaf",
				at + Vector3.new(math.cos(a) * size * 0.28, r * 0.7, math.sin(a) * size * 0.28),
				r * 2,
				if k == 1 then M.LeafDeep else M.Leaf,
				{ collide = false }
			)
		end
		if rng:NextNumber() < 0.4 then -- a few blooms on top
			for _ = 1, 3 do
				local a = rng:NextNumber(0, math.pi * 2)
				K.ball(
					m,
					"Bloom",
					at + Vector3.new(math.cos(a) * size * 0.3, size * 0.75, math.sin(a) * size * 0.3),
					size * 0.18,
					M.Flowers[rng:NextInteger(1, #M.Flowers)],
					{ collide = false }
				)
			end
		end
	end
	-- Along the near side's cliff edge (low, beyond the fence), the ends and the far corners.
	for x = -HX - 50, HX + 50, 9 do
		if math.abs(x) > 80 or rng:NextNumber() < 0.5 then
			bush(
				Vector3.new(x + rng:NextNumber(-2, 2), TOP - 0.3, NEAR + 1 + rng:NextNumber(-0.5, 0.5)),
				rng:NextNumber(2.2, 3.4)
			)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		for z = -HZ, HZ, 8 do
			if math.abs(z) > 10 then
				bush(
					Vector3.new(s * (HX + 6 + rng:NextNumber(0, 2)), TOP - 0.3, z + rng:NextNumber(-2, 2)),
					rng:NextNumber(2.4, 3.6)
				)
			end
		end
	end
	for _, p in ipairs({
		{ -128, -84 },
		{ -100, -96 },
		{ 100, -96 },
		{ 128, -86 },
		{ -150, 30 },
		{ 150, 26 },
		{ -120, 58 },
		{ 124, 58 },
	}) do
		bush(Vector3.new(p[1], TOP - 0.3, p[2]), rng:NextNumber(3, 4.5))
		U.flowers(garden, Vector3.new(p[1] + 4, TOP + 0.1, p[2] + 3), 4, 14, rng)
	end

	-- ── Windmill end (−X) ─────────────────────────────────────────────────────────────────
	local mill = U.model(map, "WindmillEnd")
	local MX, MZ = -HX - 38, -40
	-- The knoll: stepped grass terraces.
	for k = 0, 3 do
		local s = 46 - k * 9
		block(
			mill,
			"Knoll",
			Vector3.new(s, 3, s * 0.9),
			CFrame.new(MX, TOP - 1.5 + k * 2.6, MZ) * CFrame.Angles(0, k * 0.2, 0),
			if k % 2 == 0 then F.Hill else F.HillDark,
			{ stud = 2 }
		)
	end
	local base = Vector3.new(MX, TOP + 8, MZ)
	-- The tower: a stone plinth, then a white body narrowing upward, a dark beam band, door and windows.
	K.column(mill, "Plinth", base, 4, 18, F.StoneDark, { stud = 2 })
	for k = 0, 4 do
		local d = 15 - k * 1.5
		K.column(mill, "Tower", base + Vector3.new(0, 4 + k * 5, 0), 5, d, F.Cream, { stud = 1 })
	end
	K.column(mill, "Beam", base + Vector3.new(0, 15, 0), 1, 14.5, F.WoodDark)
	-- Door and windows facing the field (+X).
	block(mill, "Door", Vector3.new(1, 6, 4), base + Vector3.new(7.3, 7, 0), F.WoodDark, { stud = false })
	for _, y in ipairs({ 14, 21 }) do
		glow(mill, "Window", Vector3.new(0.6, 2.4, 2), base + Vector3.new(6.8 - (y - 14) * 0.18, y, 0), M.Lantern, 10)
	end
	-- The cap: stacked red rings narrowing to a point.
	local capY = base.Y + 29
	for k = 0, 4 do
		K.column(mill, "Cap", Vector3.new(MX, capY + k * 1.6, MZ), 1.7, 11 - k * 2.3, F.BarnRed, { stud = 1 })
	end
	K.ball(mill, "Finial", Vector3.new(MX, capY + 8.6, MZ), 1.4, M.ShipTrim, { material = Enum.Material.Metal })
	-- The sails (spinning about their hub, facing the field and the lobby).
	local hub = Vector3.new(MX + 7.5, capY - 1, MZ + 3)
	local face = Vector3.new(1, 0, 0.55).Unit
	local sails = K.prop(mill, "Sails", CFrame.lookAt(hub, hub + face), nil, 30)
	if sails then
		local box = sails:GetBoundingBox()
		sails.WorldPivot = CFrame.lookAt(box.Position, box.Position + face)
		sails:PivotTo(CFrame.lookAt(hub, hub + face))
		sails:SetAttribute("Spin", 38)
		sails:SetAttribute("SpinAxis", "Z")
	end
	K.rod(mill, "Axle", hub - face * 3, hub, 1.2, F.WoodDark)
	-- The duck pond with a little wooden bridge, ducks, reeds, a dry-stone wall and flower beds.
	local pondAt = Vector3.new(-HX - 22, TOP - 0.2, 22)
	K.column(mill, "PondRim", pondAt - Vector3.new(0, 0.6, 0), 0.9, 30, F.StoneDark, { stud = 1 })
	local water = K.column(mill, "Pond", pondAt - Vector3.new(0, 0.5, 0), 0.9, 27, F.Pond)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	for _, d in ipairs({ { 4, 3 }, { -5, -2 }, { 1, -7 } }) do
		local at = pondAt + Vector3.new(d[1], 0.7, d[2])
		block(mill, "Duck", Vector3.new(1.4, 0.9, 0.9), at, F.Duck, { stud = false })
		block(mill, "DuckHead", Vector3.new(0.6, 0.6, 0.6), at + Vector3.new(0.7, 0.6, 0), F.Duck, { stud = false })
		block(mill, "Beak", Vector3.new(0.4, 0.2, 0.3), at + Vector3.new(1.15, 0.6, 0), Color3.fromRGB(250, 170, 40), {
			stud = false,
		})
	end
	for k = 0, 8 do
		local x = pondAt.X - 6 + k * 1.5
		block(
			mill,
			"Plank",
			Vector3.new(1.3, 0.4, 4),
			Vector3.new(x, TOP + 0.6 + math.sin(k / 8 * math.pi) * 1.2, pondAt.Z - 12),
			F.Wood,
			{
				stud = false,
			}
		)
	end
	for x = MX - 20, MX + 16, 3.2 do
		block(
			mill,
			"StoneWall",
			Vector3.new(3, 1.6 + rng:NextNumber(-0.3, 0.3), 1.8),
			Vector3.new(x, TOP + 0.8, -12),
			F.StoneDark,
			{
				stud = 1,
			}
		)
	end
	U.flowers(mill, Vector3.new(MX - 6, TOP + 0.1, -8), 9, 40, rng)
	U.flowers(mill, Vector3.new(-HX - 14, TOP + 0.1, -46), 7, 28, rng)
	U.flowers(mill, Vector3.new(-HX - 30, TOP + 0.1, 44), 8, 30, rng)
	for _, p in ipairs({
		{ -HX - 62, -72, 20 },
		{ -HX - 58, 6, 17, true },
		{ -HX - 20, -66, 16, true },
		{ -HX - 58, 50, 15 },
	}) do
		tree(mill, Vector3.new(p[1], TOP - 0.3, p[2]), p[3], p[4])
	end

	-- ── Barn end (+X): the red barn, a silo, a tractor, hay ────────────────────────────────────
	local barn = U.model(map, "BarnEnd")
	local BX, BZ = HX + 40, -38
	local BW, BD, BH = 34, 28, 14 -- width along z, depth along x, wall height
	local front = BX - BD / 2 -- the gable end facing the field
	-- The body behind a 4-stud-deep doorway; the front wall is built round the door so the hay inside shows.
	local doorW, doorH, RECESS = 12, 11, 4
	block(barn, "Walls", Vector3.new(BD - RECESS, BH, BW), Vector3.new(BX + RECESS / 2, TOP + BH / 2, BZ), F.BarnRed, {
		stud = 2,
	})
	local side = (BW - doorW) / 2
	for _, s in ipairs({ -1, 1 }) do
		block(
			barn,
			"FrontWall",
			Vector3.new(RECESS, BH, side),
			Vector3.new(front + RECESS / 2, TOP + BH / 2, BZ + s * (doorW / 2 + side / 2)),
			F.BarnRed,
			{ stud = 2 }
		)
	end
	block(
		barn,
		"FrontWall",
		Vector3.new(RECESS, BH - doorH, doorW),
		Vector3.new(front + RECESS / 2, TOP + doorH + (BH - doorH) / 2, BZ),
		F.BarnRed,
		{ stud = 2 }
	)
	block(
		barn,
		"Inside",
		Vector3.new(0.4, doorH, doorW),
		Vector3.new(front + RECESS - 0.2, TOP + doorH / 2, BZ),
		Color3.fromRGB(70, 44, 30),
		{
			stud = false,
		}
	)
	block(
		barn,
		"InsideFloor",
		Vector3.new(RECESS, 0.3, doorW),
		Vector3.new(front + RECESS / 2, TOP + 0.15, BZ),
		F.Wood,
		{
			stud = 1,
		}
	)
	block(barn, "Footing", Vector3.new(BD + 1, 1.2, BW + 1), Vector3.new(BX, TOP + 0.6, BZ), F.StoneDark, { stud = 1 })
	-- Gambrel roof: solid red gable infill, shingle plates on the four slopes, white trim along the gable edges.
	local y0, y1, y2 = TOP + BH, TOP + BH + 8, TOP + BH + 12
	local zA, zB = BW / 2 + 1, BW / 2 - 6
	block(barn, "Gable", Vector3.new(BD, y1 - y0, 2 * zB), Vector3.new(BX, (y0 + y1) / 2, BZ), F.BarnRed, { stud = 2 })
	for _, s in ipairs({ -1, 1 }) do
		local w = K.wedge(
			barn,
			"GableLow",
			Vector3.new(BD, y1 - y0, zA - zB),
			CFrame.new(BX, (y0 + y1) / 2, BZ + s * (zA + zB) / 2) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
			F.BarnRed
		)
		w.Name = "GableLow"
		K.wedge(
			barn,
			"GableHigh",
			Vector3.new(BD, y2 - y1, zB),
			CFrame.new(BX, (y1 + y2) / 2, BZ + s * zB / 2) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
			F.BarnRed
		)
		local pa, pb, pc = Vector3.new(0, y0, s * zA), Vector3.new(0, y1, s * zB), Vector3.new(0, y2, 0)
		for _, seg in ipairs({ { pa, pb }, { pb, pc } }) do
			local a, b = seg[1] + Vector3.new(BX, 0, BZ), seg[2] + Vector3.new(BX, 0, BZ)
			local d = b - a
			local n = Vector3.new(0, math.abs(d.Z), d.Y * s).Unit * 0.45
			plate(barn, "Shingles", a + n, b + n, BD + 2.4, 0.9, F.Roof, { stud = 1 })
			-- White trim along the gable edge facing the field.
			local ta = a + n + Vector3.new(-BD / 2 - 1.2, 0.2, 0)
			local tb = b + n + Vector3.new(-BD / 2 - 1.2, 0.2, 0)
			plate(barn, "Trim", ta, tb, 0.8, 1.1, F.Trim, { stud = false })
		end
	end
	-- White corner boards and a band under the eaves.
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			block(
				barn,
				"Corner",
				Vector3.new(1.2, BH, 1.2),
				Vector3.new(BX + cx * BD / 2, TOP + BH / 2, BZ + cz * BW / 2),
				F.Trim,
				{
					stud = false,
				}
			)
		end
	end
	-- The big doors on the field side: a dark hay-filled opening, two leaves swung open with white X braces.
	-- The white frame round the doorway and the two leaves swung open, white X braces on them.
	for _, s in ipairs({ -1, 1 }) do
		block(
			barn,
			"DoorFrame",
			Vector3.new(0.6, doorH + 0.8, 0.8),
			Vector3.new(front - 0.2, TOP + doorH / 2 + 0.4, BZ + s * (doorW / 2 + 0.4)),
			F.Trim,
			{
				stud = false,
			}
		)
	end
	block(
		barn,
		"DoorFrame",
		Vector3.new(0.6, 0.8, doorW + 1.6),
		Vector3.new(front - 0.2, TOP + doorH + 0.4, BZ),
		F.Trim,
		{
			stud = false,
		}
	)
	for _, s in ipairs({ -1, 1 }) do
		local hinge = Vector3.new(front - 0.3, TOP + doorH / 2, BZ + s * (doorW / 2 + 0.8))
		local dir = Vector3.new(-math.sin(math.rad(65)), 0, s * math.cos(math.rad(65))) -- opened 115 deg: outward
		local centre = hinge + dir * doorW / 4
		local leaf = CFrame.lookAt(centre, centre + dir)
		block(barn, "DoorLeaf", Vector3.new(0.5, doorH, doorW / 2), leaf, F.BarnRed, { stud = 1 })
		for _, off in ipairs({ 0.32, -0.32 }) do -- the X on both faces of the leaf
			local outward = leaf.RightVector * off
			for _, a in ipairs({ 1, -1 }) do
				block(
					barn,
					"DoorX",
					Vector3.new(0.2, math.sqrt(doorH ^ 2 + (doorW / 2) ^ 2) - 0.8, 0.6),
					(leaf + outward) * CFrame.Angles(a * math.atan2(doorW / 2, doorH), 0, 0),
					F.Trim,
					{ stud = false }
				)
			end
		end
		block(
			barn,
			"DoorEdge",
			Vector3.new(0.6, doorH, 0.5),
			leaf * CFrame.new(0, 0, doorW / 4),
			F.Trim,
			{ stud = false }
		)
	end
	for k = 0, 2 do -- hay inside the doorway
		bale(
			barn,
			CFrame.new(front + 2, TOP + 0.3 + (if k == 2 then 3 else 0), BZ - 2.5 + (k % 2) * 5)
				* CFrame.Angles(0, math.pi / 2, 0),
			3
		)
	end
	-- The hayloft door, with a hay tuft.
	block(barn, "Loft", Vector3.new(0.5, 4, 5), Vector3.new(front - 0.2, y0 + 3, BZ), F.Trim, { stud = false })
	block(
		barn,
		"LoftDark",
		Vector3.new(0.6, 3.2, 4.2),
		Vector3.new(front - 0.25, y0 + 3, BZ),
		Color3.fromRGB(70, 44, 30),
		{
			stud = false,
		}
	)
	-- Weather vane on the ridge (turns slowly).
	local vaneAt = Vector3.new(BX, y2 + 0.6, BZ)
	K.column(barn, "VanePole", vaneAt, 5, 0.3, Color3.fromRGB(40, 40, 46), { material = Enum.Material.Metal })
	local vane = U.model(barn, "Vane")
	block(vane, "Arrow", Vector3.new(4, 0.25, 0.25), vaneAt + Vector3.new(0, 4.5, 0), Color3.fromRGB(40, 40, 46), {
		stud = false,
	})
	block(vane, "Rooster", Vector3.new(1.4, 1.4, 0.25), vaneAt + Vector3.new(0.6, 5.4, 0), Color3.fromRGB(40, 40, 46), {
		stud = false,
	})
	vane.WorldPivot = CFrame.new(vaneAt + Vector3.new(0, 4.5, 0))
	vane:SetAttribute("Spin", 9)
	vane:SetAttribute("SpinAxis", "Y")
	-- The silo.
	local siloAt = Vector3.new(BX + 8, TOP, BZ - BW / 2 - 7)
	K.column(barn, "Silo", siloAt, 30, 11, F.Silo, { stud = 2, material = Enum.Material.Metal })
	for k = 1, 5 do
		K.column(
			barn,
			"SiloBand",
			siloAt + Vector3.new(0, k * 5.4, 0),
			0.5,
			11.4,
			F.SiloBand,
			{ material = Enum.Material.Metal }
		)
	end
	K.ball(barn, "SiloDome", siloAt + Vector3.new(0, 30, 0), 11, F.BarnRed)
	-- Tractor, hay stacks, a fence pen, flowers, trees.
	K.prop(barn, "Tractor", CFrame.lookAt(Vector3.new(HX + 18, TOP, -6), Vector3.new(HX + 18, TOP, 10)), 5)
	for _, p in ipairs({ { HX + 20, -60 }, { HX + 27, -61 }, { HX + 23.5, -60.5, 1 }, { HX + 10, 34 }, { HX + 16, 36 } }) do
		bale(barn, CFrame.new(p[1], TOP + (p[3] or 0) * 3, p[2]) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), 3)
	end
	U.flowers(barn, Vector3.new(HX + 40, TOP + 0.1, 0), 8, 32, rng)
	for _, p in ipairs({
		{ HX + 62, 4, 18 },
		{ HX + 66, -70, 20, true },
		{ HX + 40, 44, 15, true },
		{ HX + 66, 46, 17 },
	}) do
		tree(barn, Vector3.new(p[1], TOP - 0.3, p[2]), p[3], p[4])
	end

	-- ── Far side: awnings over the stands, hay at the ends, hills, trees, scarecrow, bunting, balloons ────
	local far = U.model(map, "FarSide")
	-- The stands (CrowdController) sit at z −70…−83 rising to ~TOP+12; three striped awnings on posts over them.
	for _, cx in ipairs({ -66, 0, 66 }) do
		local len = 58
		for _, z in ipairs({ -68, -88 }) do
			for _, x in ipairs({ cx - len / 2 + 1, cx + len / 2 - 1 }) do
				block(far, "AwningPost", Vector3.new(1, 22, 1), Vector3.new(x, TOP + 11, z), F.Wood, { stud = 1 })
			end
		end
		for k = 0, math.floor(len / 4) - 1 do
			local x = cx - len / 2 + 2 + k * 4
			plate(
				far,
				"Awning",
				Vector3.new(x, TOP + 19, -66),
				Vector3.new(x, TOP + 23, -90),
				4,
				0.4,
				if k % 2 == 0 then F.Awning else F.Trim,
				{ stud = false, material = Enum.Material.Fabric }
			)
		end
		-- A scalloped valance along the front edge.
		for k = 0, math.floor(len / 2) - 1 do
			block(
				far,
				"Valance",
				Vector3.new(1.8, 1.2, 0.2),
				Vector3.new(cx - len / 2 + 1 + k * 2, TOP + 18.4, -65.8),
				if (k // 2) % 2 == 0 then F.Awning else F.Trim,
				{ stud = false, collide = false }
			)
		end
	end
	for _, x in ipairs({ -104, 104 }) do
		for k = 0, 2 do
			bale(far, CFrame.new(x + (k - 1) * 3.2, TOP, -76) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), 3)
		end
		bale(far, CFrame.new(x, TOP + 3, -76), 3)
	end
	-- Rolling hills behind the stands.
	for _, h in ipairs({ { -120, -112, 50, 10 }, { -40, -118, 70, 14 }, { 50, -114, 60, 11 }, { 130, -110, 50, 9 } }) do
		for k = 0, 3 do
			local s = h[3] - k * 12
			block(
				far,
				"Hill",
				Vector3.new(s, h[4] / 3 + 1, s * 0.45),
				CFrame.new(h[1], TOP + k * h[4] / 3, h[2] + k * 1.5) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
				if k % 2 == 0 then F.Hill else F.HillDark,
				{ stud = 2 }
			)
		end
	end
	for _, p in ipairs({
		{ -150, -104, 20 },
		{ -96, -122, 22, true },
		{ -64, -100, 17 },
		{ -12, -124, 24 },
		{ 28, -102, 18, true },
		{ 84, -124, 21 },
		{ 118, -100, 18, true },
		{ 160, -116, 20 },
	}) do
		tree(far, Vector3.new(p[1], TOP - 0.3, p[2]), p[3], p[4])
	end
	-- The scarecrow on the middle hill (its eyes glow at night).
	local scareAt = Vector3.new(-36, TOP + 14, -118)
	local scare = K.prop(far, "Scarecrow", CFrame.lookAt(scareAt, Vector3.new(0, scareAt.Y, 0)), 10)
	if not scare then
		K.column(far, "ScarecrowPost", scareAt, 9, 0.6, F.Wood)
	end
	for _, dx in ipairs({ -0.6, 0.6 }) do
		K.nightOnly(
			glow(
				far,
				"ScareEyes",
				Vector3.new(0.5, 0.5, 0.5),
				scareAt + Vector3.new(dx, 8.3, 1.4),
				Color3.fromRGB(255, 170, 40),
				10
			)
		)
	end
	-- Bunting between the awning posts.
	local flagColors =
		{ F.Awning, Color3.fromRGB(250, 200, 60), Color3.fromRGB(80, 160, 230), Color3.fromRGB(110, 190, 90) }
	for _, cx in ipairs({ -66, 0, 66 }) do
		local a, b = Vector3.new(cx - 28, TOP + 21, -66.5), Vector3.new(cx + 28, TOP + 21, -66.5)
		for k = 0, 13 do
			local t = (k + 0.5) / 14
			local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.2, 0)
			local flag = K.wedge(
				far,
				"Bunting",
				Vector3.new(0.15, 1.8, 2.4),
				CFrame.new(p - Vector3.new(0, 1, 0)) * CFrame.Angles(math.pi, math.pi / 2, 0),
				flagColors[k % #flagColors + 1],
				{ stud = false, collide = false }
			)
			flag.CastShadow = false
		end
	end
	-- Hot-air balloons drifting in the sky (they bob).
	for i, p in ipairs({ { -130, 78, -190, 20 }, { 40, 96, -230, 24 }, { 190, 70, -150, 18 }, { -230, 88, -60, 16 } }) do
		local m = K.prop(far, "Balloon", Vector3.new(p[1], p[2], p[3]), p[4])
		if m then
			if i % 2 == 0 then
				recolor(m, "Balloon", Color3.fromRGB(110, 190, 240))
				recolor(m, "Stripe", F.Trim)
			end
			m:SetAttribute("Bob", 3)
			m:SetAttribute("BobRate", 0.06 + i * 0.01)
		end
	end
	-- Small floating grass islets out on the sea (none on the lobby's side).
	local beyond = U.folder(map, "Islets")
	for _, p in ipairs({
		{ -220, 20, -170, 26 },
		{ -60, 30, -200, 20 },
		{ 110, 16, -190, 24 },
		{ 240, 26, -80, 22 },
		{ -250, 14, -30, 18 },
	}) do
		local at = Vector3.new(p[1], p[2], p[3])
		local m = U.model(beyond, "Islet")
		block(m, "Top", Vector3.new(p[4], 3, p[4] * 0.85), at, F.Lawn, { stud = 2 })
		for k = 1, 3 do
			local s = p[4] * (1 - k * 0.24)
			block(
				m,
				"Rock",
				Vector3.new(s, p[4] / 5, s * 0.85),
				at - Vector3.new(0, 1.5 + (k - 0.5) * p[4] / 5, 0),
				if k % 2 == 0 then F.StoneDark else F.Stone,
				{ stud = 4 }
			)
		end
		tree(m, at + Vector3.new(0, 1.5, 0), p[4] * 0.6, rng:NextNumber() < 0.4)
	end

	-- ── Night (Ghost Hunt): jack-o'-lanterns on the hay, fireflies ─────────────────────────────
	local night = U.folder(map, "Night")
	for _, p in ipairs({
		{ -104, TOP + 6, -76 },
		{ 104, TOP + 6, -76 },
		{ HX + 23.5, TOP + 6, -60.5 },
		{ front + 3, TOP + 3, BZ - 3 },
	}) do
		local pk = K.prop(night, "Pumpkin", Vector3.new(p[1], p[2], p[3]), 2.2)
		if pk then
			local g = pk:FindFirstChild("Glow", true)
			if g and g:IsA("BasePart") then
				K.light(g, Color3.fromRGB(255, 150, 50), 16, 1.4)
			end
			K.nightOnly(pk)
		end
	end
	-- String lights along the awnings' front edges, a warm glow in the barn doorway, jack-o'-lanterns by the fences.
	local bulbs = U.model(night, "StringLights")
	for _, cx in ipairs({ -66, 0, 66 }) do
		for k = 0, 19 do
			local t = (k + 0.5) / 20
			local x = cx - 28 + t * 56
			K.ball(
				bulbs,
				"Bulb",
				Vector3.new(x, TOP + 18.6 - math.sin(t * math.pi) * 1.2, -65.4),
				0.45,
				if k % 3 == 0 then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(255, 214, 140),
				{ material = Enum.Material.Neon, collide = false, shadow = false }
			)
		end
	end
	K.nightOnly(bulbs)
	local doorGlow = glow(
		night,
		"BarnGlow",
		Vector3.new(0.2, 9, 10),
		Vector3.new(front + 3.6, TOP + 5, BZ),
		Color3.fromRGB(255, 180, 90),
		26
	)
	doorGlow.Transparency = 0.6
	K.nightOnly(doorGlow)
	for _, s in ipairs({ -1, 1 }) do
		for x = -HX + 20, HX - 20, 40 do
			local pk = K.prop(night, "Pumpkin", Vector3.new(x + s * 6, TOP + 1, s * (HZ + 3.6)), 1.6)
			if pk then
				K.nightOnly(pk)
			end
		end
	end
	for _, x in ipairs({ -70, 0, 70 }) do
		local f = U.marker(night, "Fireflies", Vector3.new(60, 6, 140), Vector3.new(x, TOP + 6, 0))
		f.CanTouch = false
		f.CanQuery = false
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.35)
		e.Lifetime = NumberRange.new(3, 5)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 10
		e.Parent = f
		K.nightOnly(f)
	end

	-- ── Templates: the square hay bale (block), the round bale (roller); the stampede keeps the sheep ────
	local templates = U.folder(map, "Templates")
	K.blockTemplate(templates, "HayBale", "BlockTemplate")
	K.template(templates, "RoundBale", "Roller", 4)

	return K.done()
end
