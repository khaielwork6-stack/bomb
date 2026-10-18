-- "The Depot" lobby (Asset Bible §4.3, GDD §19.1) as static art in the reference video's toy style (DECISIONS
-- 2026-10-17), built on the grass beside Dock B so the lobby looks onto the field. Inside the Yard model (folder
-- "Depot"), so it moves with the map (Arena drops every map 6 at runtime). Re-runnable: rebuilds its own folder.
--   • the spawn plaza: a studded paved circle with the MEGA BOMB clock tower (a brick tower, clock faces, a spiral
--     fuse climbing to a giant copy of the hero bomb on top);
--   • the shop kiosk: a fireworks stall under a red-and-white striped awning, crates of rockets on the counter;
--   • the quest board: a corkboard with three pinned paper cards;
--   • the leaderboard wall: three framed boards (WINS · CLUTCHES · BOOMS) and three statue plinths;
--   • the Fuse Range: a fenced practice yard with padded dummies on coil springs;
--   • the VIP balcony: a raised gold-trimmed deck with a red carpet and a VIP sign;
--   • the crate stands: the three crates on their stands (art/props) with billboards, and the spin wheel.
-- Spawns / board data / the range's practice bomb are the partner's (docs/PARTNER_REQUESTS.md); this is the art.

local rgb = Color3.fromRGB

local C = {
	Paving = rgb(232, 236, 244),
	PavingRing = rgb(255, 206, 60),
	Brick = rgb(222, 74, 48),
	BrickDark = rgb(176, 50, 36),
	Cream = rgb(255, 238, 200),
	Slate = rgb(72, 88, 150),
	Gold = rgb(255, 196, 40),
	White = rgb(250, 250, 255),
	Red = rgb(232, 56, 48),
	Wood = rgb(214, 140, 70),
	WoodDark = rgb(150, 90, 44),
	Cork = rgb(196, 140, 84),
	Paper = rgb(255, 246, 226),
	BoardBlue = rgb(36, 60, 140),
	BoardInk = rgb(22, 26, 52),
	Canvas = rgb(238, 200, 128),
	Steel = rgb(168, 182, 206),
	Carpet = rgb(196, 24, 40),
	Green = rgb(70, 196, 70),
	Fuse = rgb(226, 190, 138),
	Ink = rgb(22, 18, 28),
}

-- Uploaded props (art/props → tools/upload_assets.py ids). 0 = not uploaded: the part-built fallback is used.
local PROPS = {
	CrateStand = 0,
	SpinWheel = 0,
	Podium = 0,
}

return function(ctx)
	local T = ctx.req("Theme")
	local map = workspace:FindFirstChild("Maps") and workspace.Maps:FindFirstChild("Yard")
	assert(map, "Build MapYard (+ MapYardToy) first")
	local old = map:FindFirstChild("Depot")
	if old then
		old:Destroy()
	end
	local depot = Instance.new("Folder")
	depot.Name = "Depot"
	depot.Parent = map

	local field = map:FindFirstChild("Zones", true):FindFirstChild("Field")
	local fc = field.Position
	local HL = field.Size.X / 2
	-- the grass beside Dock B (+X), on the side apron
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	local function groundY(x: number, z: number): number
		local hit = workspace:Raycast(Vector3.new(x, fc.Y + 200, z), Vector3.new(0, -400, 0), params)
		return if hit then hit.Position.Y else fc.Y - field.Size.Y / 2
	end
	local O = Vector3.new(fc.X + HL + 58, 0, fc.Z) -- the plaza centre (x past the warehouse behind Dock B)
	local Y0 = groundY(O.X, O.Z)
	local function at(x: number, y: number, z: number): Vector3
		return Vector3.new(O.X + x, Y0 + y, O.Z + z)
	end

	-- A ProximityPrompt the client opens a screen from (StoreController / WheelController read FV_Open).
	local function prompt(on: BasePart, action: string, object: string, open: string)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = action
		pp.ObjectText = object
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.MaxActivationDistance = 12
		pp.RequiresLineOfSight = false
		pp:SetAttribute("FV_Open", open)
		pp.Parent = on
		return pp
	end

	local function stud(p: BasePart, faces)
		for _, f in ipairs(faces or { Enum.NormalId.Top }) do
			local tex = Instance.new("Texture")
			tex.Name = "Studs"
			tex.Texture = T.StudTexture
			tex.Face = f
			tex.StudsPerTileU = T.StudTile
			tex.StudsPerTileV = T.StudTile
			tex.Parent = p
		end
	end
	local function part(parent, n, size: Vector3, cf, color: Color3, o)
		o = o or {}
		local p = Instance.new("Part")
		p.Name = n
		p.Anchored = true
		p.CanCollide = o.collide ~= false
		p.Material = o.mat or Enum.Material.SmoothPlastic
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if o.shape then
			p.Shape = o.shape
		end
		p.Size = size
		p.CFrame = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
		if o.t then
			p.Transparency = o.t
		end
		if
			o.studs ~= false
			and not o.shape
			and p.Material ~= Enum.Material.Neon
			and size.X >= 1.5
			and size.Z >= 1.5
		then
			stud(p, o.faces)
		end
		p.Parent = parent
		return p
	end
	local function cyl(parent, n, len: number, d: number, cf: CFrame, color: Color3, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Cylinder
		return part(parent, n, Vector3.new(len, d, d), cf, color, o)
	end
	local function sign(p: BasePart, face: Enum.NormalId, text: string, color: Color3, size: number?)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Parent = p
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextScaled = size == nil
		if size then
			l.TextSize = size
		end
		l.TextColor3 = color
		l.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
		l.Parent = g
		local st = Instance.new("UIStroke")
		st.Color = C.Ink
		st.Thickness = 3
		st.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.12, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.PaddingLeft = UDim.new(0.06, 0)
		pad.PaddingRight = UDim.new(0.06, 0)
		pad.Parent = l
		return l
	end
	local function billboard(adornee: BasePart, title: string, sub: string, color: Color3, height: number)
		local b = Instance.new("BillboardGui")
		b.Size = UDim2.fromOffset(260, 90)
		b.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		b.MaxDistance = 90
		b.LightInfluence = 0
		b.Adornee = adornee
		b.Parent = adornee
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0.6, 0)
		t.BackgroundTransparency = 1
		t.Text = title
		t.TextScaled = true
		t.TextColor3 = color
		t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
		t.Parent = b
		local st = Instance.new("UIStroke")
		st.Color = C.Ink
		st.Thickness = 3
		st.Parent = t
		local s2 = t:Clone()
		s2.Position = UDim2.fromScale(0, 0.6)
		s2.Size = UDim2.new(1, 0, 0.4, 0)
		s2.Text = sub
		s2.TextColor3 = Color3.new(1, 1, 1)
		s2.Parent = b
	end

	-- ── 1. The spawn plaza + the MEGA BOMB clock tower ───────────────────────────────────────────────────────────
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = depot
	cyl(
		plaza,
		"Paving",
		0.6,
		46,
		CFrame.new(at(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		C.Paving,
		{ studs = false }
	)
	cyl(
		plaza,
		"Ring",
		0.62,
		50,
		CFrame.new(at(0, 0.29, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		C.PavingRing,
		{ studs = false }
	)
	local spawn = part(plaza, "Spawn", Vector3.new(12, 0.2, 12), at(0, 0.7, -16), C.Green)
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn:SetAttribute("LobbySpawn", true)
	local tower = Instance.new("Model")
	tower.Name = "ClockTower"
	tower.Parent = plaza
	part(tower, "Base", Vector3.new(14, 3, 14), at(0, 1.5, 0), C.Cream)
	part(
		tower,
		"Shaft",
		Vector3.new(10, 34, 10),
		at(0, 20, 0),
		C.Brick,
		{ faces = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } }
	)
	for i, h in ipairs({ 10, 22, 34 }) do
		part(tower, "Band" .. i, Vector3.new(10.8, 0.8, 10.8), at(0, h, 0), C.Cream, { studs = false })
	end
	part(tower, "Crown", Vector3.new(13, 3, 13), at(0, 38.5, 0), C.Cream)
	-- four clock faces counting down to the next event (the hands are the partner's clock, P6)
	for k = 0, 3 do
		local yaw = math.rad(k * 90)
		local cf = CFrame.new(at(0, 30, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -5.15)
		cyl(tower, "Clock", 0.4, 7.5, cf * CFrame.Angles(0, math.rad(90), 0), C.White, { studs = false })
		cyl(
			tower,
			"ClockRim",
			0.3,
			8.3,
			cf * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, math.rad(90), 0),
			C.Gold,
			{ studs = false }
		)
		part(tower, "HandH", Vector3.new(0.5, 2.4, 0.2), cf * CFrame.new(0, 0.9, -0.3), C.Ink, { studs = false })
		part(
			tower,
			"HandM",
			Vector3.new(0.35, 3.2, 0.2),
			cf * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.new(0, 1.3, -0.32),
			C.Ink,
			{ studs = false }
		)
	end
	-- the spiral fuse climbing the tower
	local turns, steps = 3, 72
	local prev: Vector3? = nil
	for i = 0, steps do
		local a = i / steps * turns * math.pi * 2
		local y = 3 + (i / steps) * 34
		local p = at(math.cos(a) * 6.4, y, math.sin(a) * 6.4)
		if prev then
			local mid = (prev + p) / 2
			cyl(
				tower,
				"Fuse",
				(p - prev).Magnitude + 0.2,
				1.1,
				CFrame.lookAt(mid, p) * CFrame.Angles(0, math.rad(90), 0),
				C.Fuse,
				{ studs = false }
			)
		end
		prev = p
	end
	local spark = part(
		tower,
		"FuseSpark",
		Vector3.new(1.6, 1.6, 1.6),
		at(6.4, 37.6, 0),
		rgb(255, 216, 74),
		{ mat = Enum.Material.Neon, shape = Enum.PartType.Ball, collide = false }
	)
	spark:SetAttribute("TowerSpark", true)
	-- the giant bomb on top: a copy of the hero bomb (ReplicatedStorage.FV_Art.Bomb), 5x
	local art = game:GetService("ReplicatedStorage"):FindFirstChild("FV_Art")
	local bombTemplate = art and art:FindFirstChild("Bomb")
	if bombTemplate then
		local big = bombTemplate:Clone()
		big.Name = "GiantBomb"
		for _, d in ipairs(big:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				if string.match(d.Name, "^SeamGlow") then
					d.Transparency = 1
				end
			end
		end
		big:ScaleTo(5)
		big:PivotTo(CFrame.new(at(0, 46, 0)) * CFrame.Angles(0, math.rad(180), 0))
		big.Parent = tower
	else
		part(
			tower,
			"GiantBomb",
			Vector3.new(11, 11, 11),
			at(0, 45.5, 0),
			rgb(40, 38, 46),
			{ shape = Enum.PartType.Ball }
		)
	end
	billboard(tower:FindFirstChild("Crown") :: BasePart, "MEGA BOMB", "every 15 minutes", rgb(196, 120, 255), 14)

	-- ── 2. The shop kiosk ────────────────────────────────────────────────────────────────────────────────────────
	local shop = Instance.new("Model")
	shop.Name = "ShopKiosk"
	shop.Parent = depot
	local sx, sz = -22, -26
	part(shop, "Floor", Vector3.new(18, 1, 10), at(sx, 0.5, sz), C.WoodDark)
	part(
		shop,
		"Counter",
		Vector3.new(16, 3.4, 3),
		at(sx, 2.7, sz + 2.5),
		C.Wood,
		{ faces = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back } }
	)
	local counterTop = part(shop, "CounterTop", Vector3.new(17, 0.6, 3.6), at(sx, 4.7, sz + 2.5), C.Red)
	prompt(counterTop, "Shop", "Shop", "Shop")
	for _, px in ipairs({ -8, 8 }) do
		part(shop, "Post", Vector3.new(0.8, 10, 0.8), at(sx + px, 5.5, sz + 3.6), C.White, { studs = false })
		part(shop, "PostBack", Vector3.new(0.8, 10, 0.8), at(sx + px, 5.5, sz - 4), C.White, { studs = false })
	end
	-- the striped awning: alternating red / white slats with a scalloped edge
	for i = -8, 7 do
		local col = if i % 2 == 0 then C.Red else C.White
		part(
			shop,
			"Awning",
			Vector3.new(1, 0.4, 9.5),
			CFrame.new(at(sx + i + 0.5, 11, sz)) * CFrame.Angles(math.rad(-14), 0, 0),
			col,
			{ studs = false }
		)
		part(
			shop,
			"Scallop",
			Vector3.new(0.9, 0.9, 0.9),
			at(sx + i + 0.5, 9.9, sz + 4.8),
			col,
			{ shape = Enum.PartType.Ball, studs = false }
		)
	end
	local shopSign = part(shop, "Sign", Vector3.new(10, 2.6, 0.5), at(sx, 12.6, sz + 3.4), C.Gold, { studs = false })
	sign(shopSign, Enum.NormalId.Front, "SHOP", C.White)
	-- rocket crates on the counter
	for i, cx in ipairs({ -5, 0, 5 }) do
		part(
			shop,
			"Crate" .. i,
			Vector3.new(3, 2, 2.4),
			at(sx + cx, 6, sz + 2.5),
			({ C.Red, rgb(52, 124, 236), rgb(255, 200, 40) })[i]
		)
		for k = -1, 1 do
			cyl(
				shop,
				"Rocket",
				2.6,
				0.5,
				CFrame.new(at(sx + cx + k * 0.8, 8.2, sz + 2.5)) * CFrame.Angles(0, 0, math.rad(90)),
				({ C.Red, C.White, rgb(150, 76, 230) })[k + 2],
				{ studs = false }
			)
		end
	end

	-- ── 3. The quest board ───────────────────────────────────────────────────────────────────────────────────────
	local quest = Instance.new("Model")
	quest.Name = "QuestBoard"
	quest.Parent = depot
	local qx, qz = 22, -26
	for _, px in ipairs({ -6.5, 6.5 }) do
		part(quest, "Leg", Vector3.new(1, 9, 1), at(qx + px, 4.5, qz), C.WoodDark, { studs = false })
	end
	part(quest, "Frame", Vector3.new(14, 8.4, 0.8), at(qx, 6.4, qz), C.WoodDark, { studs = false })
	local cork = part(
		quest,
		"Cork",
		Vector3.new(12.6, 7, 0.4),
		at(qx, 6.4, qz + 0.4),
		C.Cork,
		{ studs = false, mat = Enum.Material.Fabric }
	)
	local _ = cork
	local qsign = part(quest, "Header", Vector3.new(9, 1.8, 0.4), at(qx, 11.4, qz + 0.2), C.Green, { studs = false })
	sign(qsign, Enum.NormalId.Front, "DAILY QUESTS", C.White)
	for i, cx in ipairs({ -4, 0, 4 }) do
		local card = part(
			quest,
			"Card" .. i,
			Vector3.new(3.2, 4.2, 0.1),
			CFrame.new(at(qx + cx, 6.2, qz + 0.65)) * CFrame.Angles(0, 0, math.rad(({ -4, 2, 5 })[i])),
			C.Paper,
			{ studs = false }
		)
		sign(
			card,
			Enum.NormalId.Front,
			({ "EASY", "MEDIUM", "HARD" })[i],
			({ rgb(70, 196, 70), rgb(255, 170, 30), rgb(232, 56, 48) })[i]
		)
		part(
			quest,
			"Pin" .. i,
			Vector3.new(0.5, 0.5, 0.5),
			at(qx + cx, 8.1, qz + 0.8),
			C.Red,
			{ shape = Enum.PartType.Ball, studs = false }
		)
	end

	-- ── 4. The leaderboard wall + statue plinths ────────────────────────────────────────────────────────────────
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"
	boards.Parent = depot
	local bz = 30
	for i, title in ipairs({ "WINS", "CLUTCHES", "BOOMS" }) do
		local bx = (i - 2) * 15
		part(boards, "Frame" .. i, Vector3.new(13, 16, 1.2), at(bx, 9, bz), C.BoardBlue, { studs = false })
		local face =
			part(boards, "Board" .. i, Vector3.new(11.6, 13, 0.3), at(bx, 8.6, bz - 0.7), C.BoardInk, { studs = false })
		face:SetAttribute("LeaderboardStat", title)
		local head =
			part(boards, "Head" .. i, Vector3.new(11.6, 2.2, 0.4), at(bx, 16.2, bz - 0.8), C.Gold, { studs = false })
		sign(head, Enum.NormalId.Front, title, C.White)
		sign(face, Enum.NormalId.Front, "ALL-TIME TOP 10", rgb(150, 200, 255), 28)
		local plinth = part(boards, "Plinth" .. i, Vector3.new(5, 2.4, 5), at(bx, 1.2, bz - 7), C.Cream)
		plinth:SetAttribute("StatueSpot", i)
		part(boards, "PlinthTop", Vector3.new(5.4, 0.4, 5.4), at(bx, 2.6, bz - 7), C.Gold, { studs = false })
	end

	-- ── 5. The Fuse Range (practice yard) ────────────────────────────────────────────────────────────────────────
	local range = Instance.new("Model")
	range.Name = "FuseRange"
	range.Parent = depot
	local rx, rz = 30, 6
	part(range, "Mat", Vector3.new(20, 0.4, 18), at(rx, 0.2, rz), rgb(132, 202, 246))
	for k = 0, 9 do
		for _, side in ipairs({ -1, 1 }) do
			part(
				range,
				"Fence",
				Vector3.new(0.6, 3, 0.6),
				at(rx - 9.5 + k * 2.1, 1.5, rz + side * 9),
				C.White,
				{ studs = false }
			)
		end
		part(range, "FenceSide", Vector3.new(0.6, 3, 0.6), at(rx + 10, 1.5, rz - 9 + k * 2), C.White, { studs = false })
	end
	for _, side in ipairs({ -1, 1 }) do
		part(range, "Rail", Vector3.new(20.6, 0.5, 0.5), at(rx, 2.6, rz + side * 9), C.Red, { studs = false })
	end
	part(range, "RailEnd", Vector3.new(0.5, 0.5, 18.6), at(rx + 10, 2.6, rz), C.Red, { studs = false })
	for i, dz in ipairs({ -5, 0, 5 }) do
		local base = at(rx + 4, 0, rz + dz)
		cyl(
			range,
			"DummyBase",
			0.6,
			3.4,
			CFrame.new(base + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			C.Steel,
			{ studs = false }
		)
		-- the coil spring: a stack of thin rings
		for k = 0, 5 do
			local r = Instance.new("Part")
			r.Shape = Enum.PartType.Cylinder
			r.Size = Vector3.new(0.25, 1.4, 1.4)
			r.CFrame = CFrame.new(base + Vector3.new(0, 1.3 + k * 0.32, 0)) * CFrame.Angles(0, 0, math.rad(90))
			r.Color = C.Steel
			r.Material = Enum.Material.SmoothPlastic
			r.Anchored = true
			r.Name = "Coil"
			r.Parent = range
		end
		part(
			range,
			"DummyBody",
			Vector3.new(2.4, 3.8, 1.6),
			base + Vector3.new(0, 4.9, 0),
			C.Canvas,
			{ studs = false, mat = Enum.Material.Fabric }
		)
		part(
			range,
			"DummyHead",
			Vector3.new(1.8, 1.8, 1.8),
			base + Vector3.new(0, 7.7, 0),
			C.Canvas,
			{ studs = false, shape = Enum.PartType.Ball, mat = Enum.Material.Fabric }
		)
		part(range, "Target", Vector3.new(0.1, 1.6, 1.6), base + Vector3.new(-0.85, 5.2, 0), C.Red, { studs = false })
		local _ = i
	end
	local rsign =
		part(range, "Sign", Vector3.new(8, 2, 0.4), at(rx - 9.5, 4.2, rz - 9.2), rgb(255, 150, 40), { studs = false })
	sign(rsign, Enum.NormalId.Front, "FUSE RANGE", C.White)

	-- ── 6. The VIP balcony ───────────────────────────────────────────────────────────────────────────────────────
	local vip = Instance.new("Model")
	vip.Name = "VIP"
	vip.Parent = depot
	local vx, vz = -30, 10
	part(vip, "Deck", Vector3.new(16, 1, 14), at(vx, 6, vz), C.Cream)
	part(vip, "Carpet", Vector3.new(6, 0.12, 14), at(vx, 6.56, vz), C.Carpet, { studs = false })
	for _, c in ipairs({ { -7.5, -6.5 }, { 7.5, -6.5 }, { -7.5, 6.5 }, { 7.5, 6.5 } }) do
		part(vip, "Pillar", Vector3.new(1.4, 6, 1.4), at(vx + c[1], 3, vz + c[2]), C.Gold, { studs = false })
	end
	for _, side in ipairs({ -1, 1 }) do
		part(vip, "Railing", Vector3.new(16, 0.6, 0.6), at(vx, 8.4, vz + side * 7), C.Gold, { studs = false })
	end
	part(vip, "RailingBack", Vector3.new(0.6, 0.6, 14), at(vx - 8, 8.4, vz), C.Gold, { studs = false })
	for k = 0, 5 do -- stairs up the open side
		part(vip, "Step", Vector3.new(4, 1, 6), at(vx + 10 + k * -0.01 + (5 - k) * 1.2, 0.5 + k, vz), C.Cream)
	end
	local vsign = part(vip, "Sign", Vector3.new(8, 2.6, 0.4), at(vx, 11, vz - 7), C.Gold, { studs = false })
	sign(vsign, Enum.NormalId.Front, "VIP", C.White)
	vip:SetAttribute("VipOnly", true)

	-- ── 7. The crate stands + the spin wheel ────────────────────────────────────────────────────────────────────
	local stands = Instance.new("Model")
	stands.Name = "CrateStands"
	stands.Parent = depot
	local IS = game:GetService("InsertService")
	local crates = art and art:FindFirstChild("Crates")
	for i, kind in ipairs({ "Spark", "Inferno", "GiftBox" }) do
		local x = -12 + (i - 1) * 12
		local base = at(x, 0, 16)
		local stand: Instance? = nil
		if PROPS.CrateStand ~= 0 then
			local ok, m = pcall(function()
				return IS:LoadAsset(PROPS.CrateStand)
			end)
			if ok and m then
				stand = m:FindFirstChildWhichIsA("Model") or m
			end
		end
		local top: BasePart
		if not stand then
			cyl(
				stands,
				"Pedestal" .. i,
				1.2,
				6,
				CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				C.Red,
				{ studs = false }
			)
			top = cyl(
				stands,
				"PedestalTop" .. i,
				0.4,
				6.4,
				CFrame.new(base + Vector3.new(0, 1.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				C.Gold,
				{ studs = false }
			)
		else
			(stand :: Model):PivotTo(CFrame.new(base));
			(stand :: Model).Parent = stands
			top = (stand :: Model).PrimaryPart or (stand :: Model):FindFirstChildWhichIsA("BasePart") :: BasePart
		end
		local crate = crates and (crates:FindFirstChild(kind) or crates:FindFirstChild("Spark"))
		if crate then
			local c = crate:Clone()
			c.Name = "Crate_" .. kind
			c:PivotTo(CFrame.new(base + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, math.rad(180), 0))
			c.Parent = stands
		end
		local labels = {
			Spark = { "SPARK CRATE", "600 Stars" },
			Inferno = { "INFERNO CRATE", "1,500 Stars" },
			GiftBox = { "GIFT BOX", "playtime gift" },
		}
		billboard(
			top,
			labels[kind][1],
			labels[kind][2],
			({ rgb(255, 170, 60), rgb(255, 80, 60), rgb(196, 120, 255) })[i],
			7
		)
		top:SetAttribute("CrateStand", kind)
		prompt(top, "Open", labels[kind][1], "Crates")
	end
	-- the spin wheel by the shop
	local wheel = Instance.new("Model")
	wheel.Name = "SpinWheel"
	wheel.Parent = depot
	local wpos = at(-36, 0, -16)
	local wheelCF = CFrame.new(wpos + Vector3.new(0, 7.5, 0)) * CFrame.Angles(0, math.rad(-60), 0)
	part(wheel, "Stand", Vector3.new(3, 7, 2), wpos + Vector3.new(0, 3.5, 0), C.BoardBlue, { studs = false })
	local segColors = {
		rgb(232, 56, 48),
		rgb(255, 150, 40),
		rgb(255, 214, 46),
		rgb(70, 196, 70),
		rgb(52, 140, 236),
		rgb(150, 76, 230),
		rgb(255, 92, 168),
		rgb(40, 200, 200),
	}
	for k = 1, 8 do
		local a = math.rad((k - 0.5) * 45)
		part(
			wheel,
			"Seg" .. k,
			Vector3.new(0.6, 3.6, 2.6),
			wheelCF * CFrame.Angles(a, 0, 0) * CFrame.new(0, 2.2, 0),
			segColors[k],
			{ studs = false }
		)
	end
	cyl(wheel, "Rim", 0.8, 9.6, wheelCF, C.Gold, { studs = false })
	cyl(wheel, "Hub", 1, 2, wheelCF * CFrame.new(0.2, 0, 0), C.White, { studs = false })
	part(wheel, "Pointer", Vector3.new(0.8, 1.6, 1.2), wheelCF * CFrame.new(0, 5.2, 0), C.Gold, { studs = false })
	billboard(
		wheel:FindFirstChild("Hub") :: BasePart,
		"SPIN THE WHEEL",
		"free spin every 12 hours",
		rgb(255, 214, 46),
		8
	)
	prompt(wheel:FindFirstChild("Stand") :: BasePart, "Spin", "Spin Wheel", "Wheel")

	-- ── 8. Dressing: benches, palms already round the yard; a few flower beds and lamps ───────────────────────────
	for k = 0, 5 do
		local a = math.rad(k * 60 + 30)
		local p = at(math.cos(a) * 21, 0, math.sin(a) * 21)
		cyl(
			depot,
			"Lamp",
			6,
			0.4,
			CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			C.BoardInk,
			{ studs = false }
		)
		local bulb = part(
			depot,
			"LampBulb",
			Vector3.new(1.1, 1.1, 1.1),
			p + Vector3.new(0, 6.3, 0),
			rgb(255, 236, 170),
			{ mat = Enum.Material.Neon, shape = Enum.PartType.Ball, collide = false }
		)
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 1.2
		light.Color = rgb(255, 220, 160)
		light.Parent = bulb
	end

	return ("Depot built at %s (%d parts)"):format(tostring(O), #depot:GetDescendants())
end
