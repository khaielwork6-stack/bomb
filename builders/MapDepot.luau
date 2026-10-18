-- The lobby "The Depot" (GDD §19.1, Asset Bible §4.3, 2026-10-17 first pass): a railway goods depot's timber pier
-- off the Fireworks Yard's quay, raised so it looks down across the field at the factory. Built into
-- Workspace.Lobby (the server spawns everyone on Lobby.LobbySpawn). Everything is within ~2.5 s of running from the
-- spawn plaza, so the 12 s intermission is spent playing, not walking:
--   • SpawnPlaza: cobbles + string lights; you land facing the tower, the field behind you.
--   • ClockTower: brick tower wrapped in a spiral fuse (SpiralFuse.Seg1..N, the spark climbs as the next MEGA BOMB
--     nears — DepotController) with a giant bomb on top (TowerBomb mount) and a clock face (ClockFace).
--   • ShopKiosk: striped-awning firework stall (ShopPrompt) with four brass plinths (Plinth1..4: featured items spin).
--   • QuestBoard: corkboard with three card slots (Card1..3) (QuestPrompt).
--   • LeaderboardWall: three chalkboards (Board_Wins / Board_Clutches / Board_Booms) + StatuePlinth1..3.
--   • FuseRange: practice yard — padded dummies on springs (Dummies.Dummy1..3, R6-shaped, BombController treats them
--     as hosts), a practice-bomb Dispenser and a DefusePad.
--   • VipLounge: gold-trimmed balcony above the stall, VipGate, VipFirework button.
--   • Bounds: invisible walls round the pier (nobody walks or jumps off onto the field).
-- Gameplay contract: the names above. Art passes may restyle everything but must keep the names. Built at TOP = 14
-- (maps drop Config.Arena.DROP at runtime, so the pier sits ~10 studs above the field).

local rgb = Color3.fromRGB

local C = {
	Ink = rgb(22, 18, 28),
	Paper = rgb(255, 243, 226),
	Fuse = rgb(255, 106, 31),
	Ember = rgb(255, 148, 66),
	Spark = rgb(255, 216, 74),
	Gold = rgb(242, 177, 58),
	Brass = rgb(201, 151, 63),
	Safe = rgb(59, 228, 140),
	Mega = rgb(176, 76, 255),
	Timber = rgb(122, 86, 58),
	TimberDark = rgb(86, 60, 42),
	Brick = rgb(150, 70, 52),
	BrickDark = rgb(110, 50, 40),
	Cobble = rgb(128, 120, 112),
	Steel = rgb(78, 82, 92),
	Cork = rgb(176, 128, 82),
	Chalk = rgb(40, 52, 46),
	Canvas = rgb(232, 222, 200),
	Pad = rgb(120, 40, 44),
	Rope = rgb(201, 165, 116),
}
local M = Enum.Material

return function(_ctx, parent)
	parent = parent or workspace
	local old = parent:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby:SetAttribute("DisplayName", "THE DEPOT")
	lobby:SetAttribute("CG_Arranged", true) -- Characters.lobbyReady(): built in place, nothing to rearrange
	lobby.Parent = parent
	local rng = Random.new(1017)

	local TOP = 14 -- deck surface
	local X0, X1, Z0, Z1 = -48, 48, 84, 144 -- the pier deck

	local function folder(p, n)
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = p
		return f
	end
	local function model(p, n)
		local m = Instance.new("Model")
		m.Name = n
		m.Parent = p
		return m
	end
	local function part(p, n, size: Vector3, at, color: Color3, mat, o)
		o = o or {}
		local x = Instance.new("Part")
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
		if o.deco then
			x.CanCollide = false
			x.CanQuery = false
			x.CanTouch = false
		end
		if o.shadow == false then
			x.CastShadow = false
		end
		x.Parent = p
		return x
	end
	local function deco(p, n, size, at, color, mat, o)
		o = table.clone(o or {})
		o.deco = true
		return part(p, n, size, at, color, mat, o)
	end
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
	local function neon(p, n, size, at, color, light: number?)
		local x = deco(p, n, size, at, color, M.Neon, { shadow = false })
		if light then
			local l = Instance.new("PointLight")
			l.Color = color
			l.Range = light
			l.Brightness = 1.4
			l.Shadows = false
			l.Parent = x
		end
		return x
	end
	local function sign(p: BasePart, face: Enum.NormalId, text: string, size: number, color: Color3, bg: Color3?)
		local g = Instance.new("SurfaceGui")
		g.Name = "Sign"
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.4
		g.Parent = p
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = if bg then 0 else 1
		l.BackgroundColor3 = bg or C.Ink
		l.Text = text
		l.TextColor3 = color
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Parent = g
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.1, 0)
		pad.PaddingBottom = UDim.new(0.1, 0)
		pad.PaddingLeft = UDim.new(0.05, 0)
		pad.PaddingRight = UDim.new(0.05, 0)
		pad.Parent = l
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.Parent = l
		return l
	end
	local function prompt(p: BasePart, name: string, action: string, object: string)
		local pr = Instance.new("ProximityPrompt")
		pr.Name = name
		pr.ActionText = action
		pr.ObjectText = object
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = p
		return pr
	end

	-- ── The pier: deck planks, pilings, edge beams ─────────────────────────────────────────────────────────────
	local pier = folder(lobby, "Pier")
	for z = Z0, Z1 - 1, 4 do
		local tint = C.Timber:Lerp(C.TimberDark, rng:NextNumber(0, 0.35))
		part(pier, "Deck", Vector3.new(X1 - X0, 1.2, 3.9), Vector3.new(0, TOP - 0.6, z + 2), tint, M.WoodPlanks)
	end
	for x = X0 + 4, X1 - 4, 12 do
		for z = Z0 + 4, Z1 - 4, 14 do
			rod(pier, "Piling", Vector3.new(x, TOP - 1.2, z), Vector3.new(x, -6, z), 1.8, C.TimberDark, M.Wood)
		end
	end
	for _, z in ipairs({ Z0 + 0.5, Z1 - 0.5 }) do
		part(pier, "EdgeBeam", Vector3.new(X1 - X0 + 1, 1.4, 1), Vector3.new(0, TOP - 0.3, z), C.TimberDark, M.Wood)
	end
	for _, x in ipairs({ X0 + 0.5, X1 - 0.5 }) do
		part(
			pier,
			"EdgeBeam",
			Vector3.new(1, 1.4, Z1 - Z0),
			Vector3.new(x, TOP - 0.3, (Z0 + Z1) / 2),
			C.TimberDark,
			M.Wood
		)
	end
	-- railings (open to the field on the front edge)
	local rails = folder(lobby, "Railings")
	local function railing(a: Vector3, b: Vector3)
		local dir = (b - a)
		local n = math.floor(dir.Magnitude / 4)
		for i = 0, n do
			local at = a + dir * (i / n)
			rod(rails, "Post", at, at + Vector3.new(0, 3.4, 0), 0.4, C.Steel, M.Metal)
		end
		rod(rails, "Rail", a + Vector3.new(0, 3.4, 0), b + Vector3.new(0, 3.4, 0), 0.32, C.Fuse, M.Metal)
		rod(rails, "Rail", a + Vector3.new(0, 1.9, 0), b + Vector3.new(0, 1.9, 0), 0.24, C.Steel, M.Metal)
	end
	railing(Vector3.new(X0 + 1, TOP, Z0 + 1), Vector3.new(X1 - 1, TOP, Z0 + 1))
	railing(Vector3.new(X0 + 1, TOP, Z0 + 1), Vector3.new(X0 + 1, TOP, Z1 - 1))
	railing(Vector3.new(X1 - 1, TOP, Z0 + 1), Vector3.new(X1 - 1, TOP, Z1 - 1))
	railing(Vector3.new(X0 + 1, TOP, Z1 - 1), Vector3.new(X1 - 1, TOP, Z1 - 1))
	-- invisible bounds: nobody goes over the rail onto the field or into the sea
	local bounds = folder(lobby, "Bounds")
	for _, b in ipairs({
		{ Vector3.new(X1 - X0, 24, 1), Vector3.new(0, TOP + 12, Z0) },
		{ Vector3.new(X1 - X0, 24, 1), Vector3.new(0, TOP + 12, Z1) },
		{ Vector3.new(1, 24, Z1 - Z0), Vector3.new(X0, TOP + 12, (Z0 + Z1) / 2) },
		{ Vector3.new(1, 24, Z1 - Z0), Vector3.new(X1, TOP + 12, (Z0 + Z1) / 2) },
	}) do
		local w = part(bounds, "Wall", b[1], b[2], C.Ink, M.SmoothPlastic, { t = 1, shadow = false })
		w.CanQuery = false
	end

	-- ── Spawn plaza: cobble disc, string lights, the spawn plate ──────────────────────────────────────────────
	local plaza = folder(lobby, "SpawnPlaza")
	part(
		plaza,
		"Cobbles",
		Vector3.new(0.4, 34, 34),
		CFrame.new(0, TOP + 0.05, 104) * CFrame.Angles(0, 0, math.rad(90)),
		C.Cobble,
		M.Cobblestone,
		{ shape = Enum.PartType.Cylinder }
	)
	part(
		plaza,
		"Kerb",
		Vector3.new(0.5, 35, 35),
		CFrame.new(0, TOP + 0.02, 104) * CFrame.Angles(0, 0, math.rad(90)),
		C.BrickDark,
		M.Slate,
		{ shape = Enum.PartType.Cylinder }
	)
	local spawnPlate = part(
		lobby,
		"LobbySpawn",
		Vector3.new(14, 0.2, 8),
		Vector3.new(0, TOP + 0.3, 97),
		C.Ink,
		M.SmoothPlastic,
		{ t = 1 }
	)
	spawnPlate.CanCollide = false
	spawnPlate.CanQuery = false
	spawnPlate:SetAttribute("Face", Vector3.new(0, 0, 1)) -- land facing the tower (Characters.lobbyCFrame)
	-- lamp posts + string lights criss-crossing the plaza
	local lights = folder(lobby, "StringLights")
	local posts = {
		Vector3.new(-16, TOP, 90),
		Vector3.new(16, TOP, 90),
		Vector3.new(-17, TOP, 118),
		Vector3.new(17, TOP, 118),
	}
	for _, at in ipairs(posts) do
		rod(lights, "LampPost", at, at + Vector3.new(0, 11, 0), 0.6, C.Steel, M.Metal)
		ball(lights, "LampHead", at + Vector3.new(0, 11.2, 0), 1.2, C.Spark, M.Neon, { deco = true })
	end
	local function strand(a: Vector3, b: Vector3)
		local n = 10
		for i = 0, n do
			local k = i / n
			local at = a:Lerp(b, k) - Vector3.new(0, math.sin(k * math.pi) * 1.6, 0)
			neon(
				lights,
				"Bulb",
				Vector3.one * 0.45,
				at,
				if i % 3 == 0 then C.Fuse elseif i % 3 == 1 then C.Spark else C.Paper,
				if i % 4 == 0 then 8 else nil
			)
		end
		rod(lights, "Wire", a, b, 0.06, C.Ink, M.SmoothPlastic, { deco = true })
	end
	local h = Vector3.new(0, 10.6, 0)
	strand(posts[1] + h, posts[4] + h)
	strand(posts[2] + h, posts[3] + h)
	strand(posts[1] + h, posts[2] + h)
	strand(posts[3] + h, posts[4] + h)

	-- ── The clock tower (MEGA BOMB clock) ─────────────────────────────────────────────────────────────────────
	local tower = model(lobby, "ClockTower")
	local TC = Vector3.new(0, TOP, 122)
	part(tower, "Base", Vector3.new(8, 3, 8), TC + Vector3.new(0, 1.5, 0), C.BrickDark, M.Brick)
	part(tower, "Shaft", Vector3.new(6, 26, 6), TC + Vector3.new(0, 16, 0), C.Brick, M.Brick)
	for y = 6, 28, 7 do
		part(tower, "Band", Vector3.new(6.6, 0.6, 6.6), TC + Vector3.new(0, y, 0), C.BrickDark, M.Brick)
	end
	part(tower, "Crown", Vector3.new(8, 2, 8), TC + Vector3.new(0, 30, 0), C.Brass, M.Metal)
	local face =
		part(tower, "ClockFace", Vector3.new(4.6, 4.6, 0.3), TC + Vector3.new(0, 24, -3.15), C.Paper, M.SmoothPlastic)
	sign(face, Enum.NormalId.Front, "", 80, C.Ink) -- DepotController writes the countdown
	local mount =
		part(tower, "TowerBomb", Vector3.new(1, 1, 1), TC + Vector3.new(0, 36, 0), C.Ink, M.SmoothPlastic, { t = 1 })
	mount.CanCollide = false
	-- the spiral fuse: segments in climbing order (the spark climbs toward the bomb as the next MEGA BOMB nears)
	local spiral = folder(tower, "SpiralFuse")
	local turns, segs, r = 3, 54, 4.4
	local prev: Vector3? = nil
	for i = 0, segs do
		local a = i / segs * turns * math.pi * 2
		local at = TC + Vector3.new(math.cos(a) * r, 4 + i / segs * 26, math.sin(a) * r)
		if prev then
			local s = rod(spiral, "Seg" .. i, prev, at, 0.5, C.Rope, M.Fabric, { deco = true })
			s:SetAttribute("Order", i)
		end
		prev = at
	end
	local spark = ball(tower, "Spark", TC + Vector3.new(r, 4, 0), 0.9, C.Spark, M.Neon, { deco = true, shadow = false })
	local sl = Instance.new("PointLight")
	sl.Color = C.Fuse
	sl.Range = 10
	sl.Brightness = 3
	sl.Parent = spark

	-- ── The shop kiosk (left), its plinths, and the VIP lounge above it ───────────────────────────────────────
	local shop = model(lobby, "ShopKiosk")
	local SC = Vector3.new(-30, TOP, 108)
	part(shop, "Counter", Vector3.new(14, 3.4, 3), SC + Vector3.new(0, 1.7, 0), C.Timber, M.WoodPlanks)
	part(shop, "CounterTop", Vector3.new(14.6, 0.4, 3.6), SC + Vector3.new(0, 3.6, 0), C.Brass, M.Metal)
	part(shop, "Back", Vector3.new(14, 9, 1), SC + Vector3.new(0, 4.5, 4), C.TimberDark, M.WoodPlanks)
	for i = 0, 6 do -- the striped awning
		local col = if i % 2 == 0 then C.Fuse else C.Canvas
		part(
			shop,
			"Awning",
			Vector3.new(2, 0.3, 5.4),
			CFrame.new(SC + Vector3.new(-6 + i * 2, 8.6, 1.2)) * CFrame.Angles(math.rad(-16), 0, 0),
			col,
			M.Fabric
		)
	end
	local shopSign =
		part(shop, "ShopSign", Vector3.new(10, 2, 0.4), SC + Vector3.new(0, 10.2, 3.2), C.Ink, M.SmoothPlastic)
	sign(shopSign, Enum.NormalId.Front, "FIREWORKS & SKINS", 60, C.Spark)
	local shopPrompt = part(
		shop,
		"ShopPromptPart",
		Vector3.new(4, 4, 1),
		SC + Vector3.new(0, 2.5, -1.8),
		C.Ink,
		M.SmoothPlastic,
		{ t = 1 }
	)
	shopPrompt.CanCollide = false
	prompt(shopPrompt, "ShopPrompt", "Shop", "Fireworks stall")
	for i = 1, 4 do
		local at = SC + Vector3.new(-6 + (i - 1) * 4, 0, -6)
		rod(shop, "PlinthBase", at, at + Vector3.new(0, 2.6, 0), 2.2, C.TimberDark, M.Wood)
		local top = part(
			shop,
			"Plinth" .. i,
			Vector3.new(0.4, 2.6, 2.6),
			CFrame.new(at + Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			C.Brass,
			M.Metal,
			{ shape = Enum.PartType.Cylinder }
		)
		top:SetAttribute("Order", i)
	end
	-- the VIP lounge: a gold-trimmed balcony above the stall, stairs up the side, a gate at the top
	local vip = model(lobby, "VipLounge")
	local VY = TOP + 10
	part(vip, "Floor", Vector3.new(20, 1, 12), Vector3.new(-30, VY - 0.5, 118), C.TimberDark, M.WoodPlanks) -- x −40…−20, z 112…124
	for _, x in ipairs({ -37.5, -22.5 }) do
		for _, z in ipairs({ 112.5, 123.5 }) do
			rod(vip, "Leg", Vector3.new(x, TOP, z), Vector3.new(x, VY - 1, z), 0.9, C.Steel, M.Metal)
		end
	end
	for _, seg in ipairs({ -- round the balcony, open only where the stairs arrive (x −40, z 121…124)
		{ Vector3.new(-40, VY, 112), Vector3.new(-20, VY, 112) },
		{ Vector3.new(-20, VY, 112), Vector3.new(-20, VY, 124) },
		{ Vector3.new(-40, VY, 124), Vector3.new(-20, VY, 124) },
		{ Vector3.new(-40, VY, 112), Vector3.new(-40, VY, 121) },
	}) do
		rod(vip, "GoldRail", seg[1] + Vector3.new(0, 3.2, 0), seg[2] + Vector3.new(0, 3.2, 0), 0.4, C.Gold, M.Metal)
		rod(vip, "GoldRailLow", seg[1] + Vector3.new(0, 1.6, 0), seg[2] + Vector3.new(0, 1.6, 0), 0.25, C.Gold, M.Metal)
	end
	for i = 0, 8 do -- the stairs up the west side, climbing from the front (z 104) to the landing
		part(vip, "Step", Vector3.new(4, 1, 2), Vector3.new(-42, TOP + i + 0.5, 104 + i * 2), C.Timber, M.WoodPlanks)
	end
	part(vip, "Landing", Vector3.new(4, 1, 4), Vector3.new(-42, VY - 0.5, 122.5), C.Timber, M.WoodPlanks)
	local gate =
		part(vip, "VipGate", Vector3.new(0.4, 6, 3), Vector3.new(-40, VY + 3, 122.5), C.Gold, M.Glass, { t = 0.45 })
	gate:SetAttribute("VipOnly", true) -- DepotController lets VIP pass owners through on their own client
	local gateSign =
		part(vip, "VipSign", Vector3.new(0.2, 1.2, 3), Vector3.new(-40.3, VY + 6.8, 122.5), C.Ink, M.SmoothPlastic)
	sign(gateSign, Enum.NormalId.Left, "VIP", 50, C.Gold)
	local button =
		part(vip, "VipFirework", Vector3.new(1.6, 1.2, 1.6), Vector3.new(-30, VY + 0.6, 122), C.Gold, M.Metal)
	neon(vip, "VipButtonCap", Vector3.new(1.2, 0.3, 1.2), Vector3.new(-30, VY + 1.35, 122), C.Bomber, 6)
	prompt(button, "FireworkPrompt", "Launch firework", "VIP")

	-- ── The quest board (right) ───────────────────────────────────────────────────────────────────────────────
	local board = model(lobby, "QuestBoard")
	local QC = Vector3.new(28, TOP, 100)
	for _, x in ipairs({ -5.2, 5.2 }) do
		rod(board, "Post", QC + Vector3.new(x, 0, 0), QC + Vector3.new(x, 8, 0), 0.7, C.TimberDark, M.Wood)
	end
	part(board, "Frame", Vector3.new(10.8, 6.4, 0.6), QC + Vector3.new(0, 5, 0), C.TimberDark, M.Wood)
	local cork = part(board, "Cork", Vector3.new(10, 5.6, 0.2), QC + Vector3.new(0, 5, -0.35), C.Cork, M.Fabric)
	local title = part(board, "Title", Vector3.new(8, 1.2, 0.3), QC + Vector3.new(0, 8.8, 0), C.Ink, M.SmoothPlastic)
	sign(title, Enum.NormalId.Front, "TODAY'S QUESTS", 60, C.Paper)
	for i = 1, 3 do
		local card = part(
			board,
			"Card" .. i,
			Vector3.new(2.8, 3.6, 0.1),
			QC + Vector3.new(-3.3 + (i - 1) * 3.3, 4.9, -0.5),
			C.Paper,
			M.SmoothPlastic
		)
		card:SetAttribute("Order", i)
		ball(
			board,
			"Pin",
			QC + Vector3.new(-3.3 + (i - 1) * 3.3, 6.6, -0.6),
			0.3,
			C.Bomber,
			M.SmoothPlastic,
			{ deco = true }
		)
	end
	prompt(cork, "QuestPrompt", "Quests", "Quest board")

	-- ── The leaderboard wall (back left) ──────────────────────────────────────────────────────────────────────
	local wall = model(lobby, "LeaderboardWall")
	local WZ = 141
	part(wall, "Wall", Vector3.new(58, 12, 1.2), Vector3.new(-17, TOP + 6, WZ + 1), C.Brick, M.Brick)
	part(wall, "Coping", Vector3.new(59, 0.8, 1.8), Vector3.new(-17, TOP + 12.4, WZ + 1), C.BrickDark, M.Slate)
	for i, key in ipairs({ "Wins", "Clutches", "Booms" }) do
		local x = -36 + (i - 1) * 19
		part(wall, "BoardFrame", Vector3.new(16, 10, 0.4), Vector3.new(x, TOP + 6.4, WZ + 0.2), C.TimberDark, M.Wood)
		local b =
			part(wall, "Board_" .. key, Vector3.new(15, 9, 0.2), Vector3.new(x, TOP + 6.4, WZ - 0.05), C.Chalk, M.Slate)
		b:SetAttribute("Board", key)
		local plinth = part(
			wall,
			"StatuePlinth" .. i,
			Vector3.new(4, 2, 4),
			Vector3.new(x, TOP + 1, WZ - 6),
			C.Paper:Lerp(C.Cobble, 0.4),
			M.Marble
		)
		plinth:SetAttribute("Rank", i)
	end

	-- ── The Fuse Range (right back): dummies on springs, a dispenser, a defuse pad ────────────────────────────
	local range = model(lobby, "FuseRange")
	local RX0, RX1, RZ0, RZ1 = 18, 46, 110, 142
	part(
		range,
		"Floor",
		Vector3.new(RX1 - RX0, 0.2, RZ1 - RZ0),
		Vector3.new((RX0 + RX1) / 2, TOP + 0.1, (RZ0 + RZ1) / 2),
		rgb(70, 92, 72),
		M.Grass
	)
	for _, seg in ipairs({ -- a low fence with a gap at the front-left entrance
		{ Vector3.new(RX0 + 6, TOP, RZ0), Vector3.new(RX1, TOP, RZ0) },
		{ Vector3.new(RX0, TOP, RZ0 + 0.1), Vector3.new(RX0, TOP, RZ1) },
	}) do
		local dir = seg[2] - seg[1]
		for k = 0, math.floor(dir.Magnitude / 3) do
			local at = seg[1] + dir.Unit * (k * 3)
			rod(range, "FencePost", at, at + Vector3.new(0, 2.2, 0), 0.35, C.TimberDark, M.Wood)
		end
		rod(
			range,
			"FenceRail",
			seg[1] + Vector3.new(0, 1.8, 0),
			seg[2] + Vector3.new(0, 1.8, 0),
			0.25,
			C.Timber,
			M.Wood
		)
	end
	local rsign = part(
		range,
		"RangeSign",
		Vector3.new(8, 1.6, 0.3),
		Vector3.new(RX0 + 10, TOP + 4.2, RZ0 - 0.2),
		C.Ink,
		M.SmoothPlastic
	)
	sign(rsign, Enum.NormalId.Front, "FUSE RANGE  ·  PRACTICE", 54, C.Fuse)
	rod(
		range,
		"SignPost",
		Vector3.new(RX0 + 6.5, TOP, RZ0 - 0.2),
		Vector3.new(RX0 + 6.5, TOP + 3.6, RZ0 - 0.2),
		0.3,
		C.Steel,
		M.Metal
	)
	rod(
		range,
		"SignPost",
		Vector3.new(RX0 + 13.5, TOP, RZ0 - 0.2),
		Vector3.new(RX0 + 13.5, TOP + 3.6, RZ0 - 0.2),
		0.3,
		C.Steel,
		M.Metal
	)
	-- the dispenser: a red post box with a bomb on top
	local disp = part(
		range,
		"Dispenser",
		Vector3.new(2.4, 3.4, 2.4),
		Vector3.new(RX0 + 3, TOP + 1.7, RZ0 + 3),
		C.Bomber,
		M.Metal
	)
	ball(range, "DispenserBomb", Vector3.new(RX0 + 3, TOP + 4.1, RZ0 + 3), 1.5, C.Ink, M.Metal, { deco = true })
	prompt(disp, "PracticePrompt", "Take a practice bomb", "Dispenser")
	-- the defuse pad
	local pad = part(
		range,
		"DefusePad",
		Vector3.new(6, 0.3, 6),
		Vector3.new(RX1 - 5, TOP + 0.25, RZ1 - 5),
		C.Safe,
		M.Neon,
		{ shadow = false }
	)
	pad.CanCollide = false
	local padRim = part(
		range,
		"PadRim",
		Vector3.new(6.8, 0.2, 6.8),
		Vector3.new(RX1 - 5, TOP + 0.15, RZ1 - 5),
		C.Steel,
		M.DiamondPlate
	)
	padRim.CanCollide = false
	-- the dummies: R6-shaped, padded, each on a spring post
	local dummies = folder(range, "Dummies")
	for i, at in ipairs({ Vector3.new(28, TOP, 120), Vector3.new(38, TOP, 126), Vector3.new(30, TOP, 134) }) do
		local d = model(dummies, "Dummy" .. i)
		rod(d, "Spring", at, at + Vector3.new(0, 1.2, 0), 0.8, C.Steel, M.Metal)
		local root = part(
			d,
			"HumanoidRootPart",
			Vector3.new(2, 2, 1),
			at + Vector3.new(0, 4.2, 0),
			C.Ink,
			M.SmoothPlastic,
			{ t = 1 }
		)
		root.CanCollide = false
		local torso = part(d, "Torso", Vector3.new(2, 2, 1), at + Vector3.new(0, 4.2, 0), C.Pad, M.Fabric)
		part(d, "Head", Vector3.new(1.2, 1.2, 1.2), at + Vector3.new(0, 5.8, 0), C.Pad:Lerp(C.Canvas, 0.3), M.Fabric)
		part(d, "Left Arm", Vector3.new(1, 2, 1), at + Vector3.new(-1.5, 4.2, 0), C.Pad, M.Fabric)
		part(d, "Right Arm", Vector3.new(1, 2, 1), at + Vector3.new(1.5, 4.2, 0), C.Pad, M.Fabric)
		part(d, "Left Leg", Vector3.new(1, 2, 1), at + Vector3.new(-0.5, 2.2, 0), C.TimberDark, M.Fabric)
		part(d, "Right Leg", Vector3.new(1, 2, 1), at + Vector3.new(0.5, 2.2, 0), C.TimberDark, M.Fabric)
		d.PrimaryPart = root
		d:SetAttribute("PracticeDummy", true)
		torso:SetAttribute("Home", torso.CFrame)
	end

	-- ── Dressing: crates and barrels round the edges ──────────────────────────────────────────────────────────
	local dress = folder(lobby, "Dressing")
	for _, at in ipairs({
		Vector3.new(-44, TOP, 88),
		Vector3.new(44, TOP, 88),
		Vector3.new(-44, TOP, 100),
		Vector3.new(10, TOP, 138),
	}) do
		part(
			dress,
			"Crate",
			Vector3.new(3, 2.6, 3),
			CFrame.new(at + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			C.Timber,
			M.WoodPlanks
		)
		rod(dress, "Barrel", at + Vector3.new(2.6, 0, 1), at + Vector3.new(2.6, 3, 1), 2, C.TimberDark, M.Wood)
	end

	return ("Depot built: %d parts"):format(#lobby:GetDescendants())
end
