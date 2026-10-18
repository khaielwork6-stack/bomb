-- "The Depot" lobby restyled to the owner's reference video (DECISIONS 2026-10-17: the bright, studded, toy-like look;
-- the same pass the Yard gets from MapYardToy). Runs AFTER the partner's MapDepot, on the built Workspace.Lobby, and
-- changes looks only: every part keeps its name, parent, size and position (MapDepot's gameplay contract — the names
-- DepotController / DepotService read), so the clock spark, plinths, quest cards, boards, range and VIP all still work.
--   • recolours by part name to the toy palette (bright orange-wood deck with studs, cream paving with a gold kerb, a
--     toy-red brick tower with cream bands, red-and-white awning, blue counter, navy boards with gold frames, white
--     railings, a purple VIP carpet, bright dummies), plastic instead of brick / slate / metal / wood / fabric;
--   • the shared stud texture on the walkable tops;
--   • the part-built dressing crates become the modelled firework crate (ReplicatedStorage.FV_Art.Props);
--   • adds the crate stands (the three crates on the modelled stands, the price on each sign) at the front-left corner
--     and the modelled spin wheel at the front-right, with the prompts the client opens screens from (FV_Open);
--   • the Fuse Range's part-built practice-bomb dispenser becomes the modelled machine (FV_Art.Props.Dispenser); the
--     old "Dispenser" box stays, invisible, as its collision and prompt holder;
--   • the clock tower's part-built shell (Base, Shaft, Band, Crown) becomes the modelled tower (FV_Art.Props.ClockTower);
--     every part the code reads (ClockFace and its Sign, TowerBomb, SpiralFuse.Seg*, Spark) stays exactly as it is;
--   • the dressing barrels become the modelled powder keg (FV_Art.Props.PowderKeg), each old one invisible as its
--     collision;
--   • the shop stall's counter, back wall and awning become the modelled stall (FV_Art.Props.Kiosk); ShopSign (its
--     text), ShopPromptPart and the plinths stay, the old parts stay invisible as its collision.
-- Re-runnable: it rebuilds its own "Toy" folder and its colour rules are absolute. Re-run it after every MapDepot run.

local rgb = Color3.fromRGB

local C = {
	DeckA = rgb(236, 160, 84),
	DeckB = rgb(220, 142, 68),
	Beam = rgb(222, 74, 48),
	Piling = rgb(246, 238, 222),
	Paving = rgb(222, 188, 138), -- a warm mid-sand: the big sunlit plaza disc glared as near-white
	Gold = rgb(255, 196, 40),
	Brick = rgb(222, 74, 48),
	Cream = rgb(255, 238, 200),
	Fuse = rgb(255, 156, 44),
	Red = rgb(232, 56, 48),
	White = rgb(250, 250, 255),
	Blue = rgb(46, 150, 226),
	Navy = rgb(36, 60, 140),
	Steel = rgb(62, 72, 104),
	Purple = rgb(150, 76, 230),
	Green = rgb(76, 198, 58),
	Yellow = rgb(255, 208, 40),
	Ink = rgb(22, 18, 28),
	Paper = rgb(255, 246, 226),
}

-- name (or "Parent/name") → colour; the first match wins
local NAMED: { [string]: Color3 } = {
	["Pier/EdgeBeam"] = C.Beam,
	["Pier/Piling"] = C.Piling,
	Cobbles = C.Paving,
	Kerb = C.Gold,
	Shaft = C.Brick,
	["ClockTower/Wall"] = C.Brick,
	Band = C.Cream,
	Base = C.Cream,
	Coping = C.Cream,
	Crown = C.Gold,
	ClockFace = C.White,
	Counter = C.Blue,
	CounterTop = C.Gold,
	["LeaderboardWall/Wall"] = C.Brick,
	Board_Wins = C.Navy,
	Board_Clutches = C.Navy,
	Board_Booms = C.Navy,
	BoardFrame = C.Gold,
	Frame = C.Gold,
	StatuePlinth1 = C.White,
	StatuePlinth2 = C.White,
	StatuePlinth3 = C.White,
	PlinthBase = C.Navy,
	Plinth1 = C.Gold,
	Plinth2 = C.Gold,
	Plinth3 = C.Gold,
	Plinth4 = C.Gold,
	["FuseRange/Floor"] = C.Green,
	["VipLounge/Floor"] = C.Purple,
	FencePost = C.White,
	FenceRail = C.Red,
	Post = C.White,
	Rail = C.Red,
	LampPost = C.Steel,
	SignPost = C.Steel,
	Leg = C.Steel,
	Step = C.DeckA,
	Landing = C.DeckA,
	Back = C.Navy,
	Cork = rgb(214, 156, 92),
	Barrel = C.Red,
	Spring = rgb(168, 182, 206),
	PadRim = C.Yellow,
	ShopSign = C.Navy,
	RangeSign = C.Navy,
	VipSign = C.Navy,
	Title = C.Navy,
	-- the practice dummies (R6-shaped): toy colours
	Head = rgb(255, 226, 150),
	Torso = C.Red,
	["Left Arm"] = C.Yellow,
	["Right Arm"] = C.Yellow,
	["Left Leg"] = C.Blue,
	["Right Leg"] = C.Blue,
}
local PLASTIC_FROM = {
	[Enum.Material.Brick] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.Marble] = true,
}
local CRATES = { -- the stands, left to right as you face them from the plaza
	{ kind = "Spark", title = "SPARK CRATE", price = "600 Gems", color = rgb(255, 170, 60) },
	{ kind = "Inferno", title = "INFERNO CRATE", price = "1,500 Gems", color = rgb(255, 80, 60) },
	{ kind = "GiftBox", title = "GIFT BOX", price = "playtime gift", color = rgb(196, 120, 255) },
}
local STAND_SPACING = 10.5
local WHEEL_SCALE = 1.4
local AWNING_STRIPES = { C.Red, C.White }
-- The modelled props are built 1:1 with MapDepot's parts (art/props/build_*.py; numbers from their manifest.json):
local TOWER_SHAFT_H = 26 -- Prop.ClockTower "shaft_height_studs" (MapDepot's Shaft)
local TOWER_SHELL = { Base = true, Shaft = true, Band = true, Crown = true } -- hidden; Base + Shaft keep colliding
local KIOSK_SHELL = { Counter = true, CounterTop = true, Back = true, Awning = true } -- hidden, still colliding
local KIOSK_FROM_PIVOT = Vector3.new(0, 0, -1.35) -- Prop.Kiosk "CounterBase" roblox_from_pivot (the Counter's foot)

return function(ctx)
	local T = ctx.req("Theme")
	local lobby = workspace:FindFirstChild("Lobby")
	assert(lobby, "Build MapDepot first (workspace.Lobby)")
	local old = lobby:FindFirstChild("Toy")
	if old then
		old:Destroy()
	end
	local toy = Instance.new("Folder")
	toy.Name = "Toy"
	toy.Parent = lobby
	local art = game:GetService("ReplicatedStorage"):FindFirstChild("FV_Art")
	local props = art and art:FindFirstChild("Props")
	local crates = art and art:FindFirstChild("Crates")

	-- studs on whichever face of `p` looks up (a disc is a cylinder lying on its side)
	local function stud(p: BasePart)
		if p:FindFirstChild("Studs") then
			return
		end
		local up, best = Enum.NormalId.Top, -2
		for _, n in ipairs(Enum.NormalId:GetEnumItems()) do
			local y = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n)).Y
			if y > best then
				up, best = n, y
			end
		end
		local tex = Instance.new("Texture")
		tex.Name = "Studs"
		tex.Texture = T.StudTexture
		tex.Face = up
		tex.StudsPerTileU = T.StudTile
		tex.StudsPerTileV = T.StudTile
		tex.Parent = p
	end

	-- ── 1. Recolour + plastic + studs ────────────────────────────────────────────────────────────────────────────
	local recoloured = 0
	local deckI, awningI = 0, 0
	for _, d in ipairs(lobby:GetDescendants()) do
		if
			d:IsA("BasePart")
			and d.Transparency < 0.9
			and d.Material ~= Enum.Material.Neon
			and not d:IsDescendantOf(toy)
		then
			local parentName = d.Parent and d.Parent.Name or ""
			local col = NAMED[parentName .. "/" .. d.Name] or NAMED[d.Name]
			if d.Name == "Deck" and parentName == "Pier" then
				deckI += 1
				col = if deckI % 2 == 0 then C.DeckA else C.DeckB
			elseif d.Name == "Awning" then
				awningI += 1
				col = AWNING_STRIPES[awningI % 2 + 1]
			elseif string.match(d.Name, "^Seg%d+$") then
				col = C.Fuse -- the spiral fuse up the tower (DepotController lights it as the MEGA BOMB nears)
			end
			if col then
				d.Color = col
				recoloured += 1
			end
			if PLASTIC_FROM[d.Material] then
				d.Material = Enum.Material.SmoothPlastic
			end
			if d.Name == "Deck" or d.Name == "Cobbles" or d.Name == "Floor" or d.Name == "Landing" then
				stud(d)
			end
			if d.Name == "Cobbles" then
				d.Material = Enum.Material.Plastic -- the big sunlit disc glares in smooth plastic
			end
		end
	end

	-- ── 2. The dressing crates become the modelled firework crate ────────────────────────────────────────────────
	local swapped = 0
	local fw = props and props:FindFirstChild("FireworkCrate")
	local dressing = lobby:FindFirstChild("Dressing")
	if fw and dressing then
		for _, c in ipairs(dressing:GetChildren()) do
			if c:IsA("BasePart") and c.Name == "Crate" then
				local m = fw:Clone()
				m:ScaleTo(m:GetScale() * (c.Size.Y / 2.6))
				local bottom = c.CFrame * CFrame.new(0, -c.Size.Y / 2, 0)
				m:PivotTo(bottom)
				m.Name = "Crate"
				m.Parent = toy
				c.Transparency = 1 -- the box stays as its collision
				swapped += 1
			end
		end
	end

	-- ── 3. Where the new things go: the pier's front corners ────────────────────────────────────────────────────
	local pier = lobby:FindFirstChild("Pier")
	local minX, maxX, minZ, top = math.huge, -math.huge, math.huge, 0
	for _, p in ipairs(pier and pier:GetChildren() or {}) do
		if p:IsA("BasePart") and p.Name == "Deck" then
			minX = math.min(minX, p.Position.X - p.Size.X / 2)
			maxX = math.max(maxX, p.Position.X + p.Size.X / 2)
			minZ = math.min(minZ, p.Position.Z - p.Size.Z / 2)
			top = p.Position.Y + p.Size.Y / 2
		end
	end
	assert(minX < math.huge, "Lobby has no Pier/Deck")
	local spawn = lobby:FindFirstChild("LobbySpawn") :: BasePart?
	local look = if spawn then Vector3.new(spawn.Position.X, top, spawn.Position.Z) else Vector3.new(0, top, minZ + 20)

	local function prompt(on: BasePart, action: string, object: string, open: string)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = action
		pp.ObjectText = object
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.MaxActivationDistance = 12
		pp.RequiresLineOfSight = false
		pp:SetAttribute("FV_Open", open)
		pp.Parent = on
	end
	local function billboard(adornee: BasePart, title: string, sub: string, color: Color3, height: number)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Label"
		bb.Adornee = adornee
		bb.Size = UDim2.fromScale(5.6, 1.6)
		bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		bb.Parent = adornee
		local function line(text: string, y: number, h: number, c: Color3, stroke: number)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(0, y)
			t.Size = UDim2.fromScale(1, h)
			t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
			t.TextScaled = true
			t.TextColor3 = c
			t.Text = text
			t.Parent = bb
			local st = Instance.new("UIStroke")
			st.Color = C.Ink
			st.Thickness = stroke
			st.Parent = t
		end
		line(title, 0, 0.6, color, 3)
		line(sub, 0.6, 0.4, C.White, 2)
	end

	-- the crate stands: front-left corner, in a row across the pier, facing the spawn
	local stands = Instance.new("Model")
	stands.Name = "CrateStands"
	stands.Parent = toy
	local standArt = props and props:FindFirstChild("CrateStand")
	local rowZ = minZ + 6.5
	local rowX = minX + 8
	for i, info in ipairs(CRATES) do
		local base = Vector3.new(rowX + (i - 1) * STAND_SPACING, top, rowZ)
		local face = CFrame.lookAt(base, Vector3.new(look.X, top, look.Z + 30))
		local topPart: BasePart? = nil
		local crateAt = base + Vector3.new(0, 1.2, 0)
		if standArt and standArt:IsA("Model") then
			local st = standArt:Clone()
			st:PivotTo(face)
			st.Parent = stands
			topPart = st:FindFirstChild("Pedestal") :: BasePart?
			local spot = st:FindFirstChild("CrateSpot", true) :: Attachment?
			if spot then
				crateAt = spot.WorldCFrame.Position
			end
			-- the price on the stand's little sign (a thin card laid on SignFace; manifest centre / normal)
			if st:FindFirstChild("SignFace") then
				local pv = st:GetPivot()
				local centre = pv:PointToWorldSpace(Vector3.new(-2.463, 1.88, -2.885))
				local normal = pv:VectorToWorldSpace(Vector3.new(-0.4695, 0, -0.8829))
				local card = Instance.new("Part")
				card.Name = "SignCard"
				card.Anchored = true
				card.CanCollide, card.CanQuery, card.CanTouch = false, false, false
				card.Material = Enum.Material.SmoothPlastic
				card.Color = C.Paper
				card.CastShadow = false
				card.Size = Vector3.new(1.1, 0.5, 0.02)
				card.CFrame = CFrame.lookAt(centre + normal * 0.12, centre + normal * 2)
				card.Parent = st
				local sg = Instance.new("SurfaceGui")
				sg.Face = Enum.NormalId.Front
				sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sg.PixelsPerStud = 100
				sg.LightInfluence = 0.3
				sg.Parent = card
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
				t.TextScaled = true
				t.TextColor3 = C.Ink
				t.Text = info.price
				t.Parent = sg
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0.08, 0)
				pad.PaddingRight = UDim.new(0.08, 0)
				pad.PaddingTop = UDim.new(0.12, 0)
				pad.PaddingBottom = UDim.new(0.12, 0)
				pad.Parent = t
			end
		end
		local crate = crates and (crates:FindFirstChild(info.kind) or crates:FindFirstChild("Spark"))
		if crate then
			local c = crate:Clone()
			c.Name = "Crate_" .. info.kind
			c:PivotTo(CFrame.lookAt(crateAt, crateAt + face.LookVector))
			c.Parent = stands
		end
		if topPart then
			topPart:SetAttribute("CrateStand", info.kind)
			billboard(topPart, info.title, info.price, info.color, 6)
			prompt(topPart, "Open", info.title, "Crates")
		end
	end

	-- the spin wheel: front-right corner, facing the spawn
	local wheelArt = props and props:FindFirstChild("SpinWheel")
	if wheelArt and wheelArt:IsA("Model") then
		local w = wheelArt:Clone()
		w.Name = "SpinWheel"
		w:ScaleTo(w:GetScale() * WHEEL_SCALE)
		local at = Vector3.new(maxX - 9, top, minZ + 7)
		w:PivotTo(CFrame.lookAt(at, Vector3.new(look.X, top, look.Z + 20)))
		w.Parent = toy
		local stand = w:FindFirstChild("Stand") :: BasePart?
		local hub = w:FindFirstChild("Hub") :: BasePart?
		if stand then
			stand.CanCollide = true
			prompt(stand, "Spin", "Spin Wheel", "Wheel")
		end
		if hub then
			billboard(hub, "SPIN THE WHEEL", "free spin every 12 hours", C.Yellow, 8.5)
		end
	end

	-- ── 4. The Fuse Range's practice-bomb dispenser becomes the modelled machine ─────────────────────────────────
	-- MapDepot's "Dispenser" box stays (invisible) as the collision and keeps its PracticePrompt (DepotController /
	-- BotService read it by name); "DispenserBomb" stays too, hidden: the model carries its own bomb on top, at the
	-- same height. The model sits on the box's bottom, its chute turned toward the spawn.
	local dispArt = props and props:FindFirstChild("Dispenser")
	local range = lobby:FindFirstChild("FuseRange")
	local disp = range and range:FindFirstChild("Dispenser")
	local dispBomb = range and range:FindFirstChild("DispenserBomb")
	local dispensed = false
	if dispArt and dispArt:IsA("Model") and disp and disp:IsA("BasePart") then
		local m = dispArt:Clone()
		m.Name = "DispenserModel"
		local foot = disp.Position - Vector3.new(0, disp.Size.Y / 2, 0)
		m:PivotTo(CFrame.lookAt(foot, Vector3.new(look.X, foot.Y, look.Z)))
		-- the pivot is the bounding box's bottom centre (the crank and the tray push it off-centre): centre the
		-- cabinet ("Body") on the old box
		local body = m:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			local d = foot - body.Position
			m:PivotTo(m:GetPivot() + Vector3.new(d.X, 0, d.Z))
		end
		local hit = m:FindFirstChild("Hit")
		if hit and hit:IsA("BasePart") then
			hit.CanCollide, hit.CanQuery, hit.CanTouch = false, false, false -- the old box does the blocking
		end
		m.Parent = toy
		disp.Transparency = 1
		if dispBomb and dispBomb:IsA("BasePart") then
			dispBomb.Transparency = 1
		end
		dispensed = true
	end

	-- a modelled prop's own collision box ("Hit") off: the old parts it replaces stay as the collision
	local function noHit(m: Model)
		local hit = m:FindFirstChild("Hit")
		if hit and hit:IsA("BasePart") then
			hit.CanCollide, hit.CanQuery, hit.CanTouch = false, false, false
		end
	end
	-- Roblox's camera only stops at parts that are solid and visible: make the model's big visible shells solid too,
	-- so the camera never swings inside them (the old invisible parts underneath still do the blocking)
	local function camSolid(m: Model, names: { string })
		for _, n in ipairs(names) do
			local p = m:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				p.CanCollide, p.CanQuery = true, true
			end
		end
	end
	local function hide(p: BasePart, collide: boolean)
		p.Transparency = 1
		p.CastShadow = false
		if not collide then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end

	-- ── 5. The clock tower's shell becomes the modelled tower ───────────────────────────────────────────────────
	-- Only the shell is hidden (Base, Shaft, the Bands, Crown); ClockFace (DepotController writes the countdown on its
	-- Sign), TowerBomb (the hero bomb's mount), SpiralFuse.Seg* and Spark are untouched. Base and Shaft stay solid as
	-- the tower's collision (and Base stays a BotService lobby spot); the bands and the crown stop colliding. The model
	-- stands on the Base's bottom with its gold clock frame turned toward the ClockFace.
	local towerArt = props and props:FindFirstChild("ClockTower")
	local tower = lobby:FindFirstChild("ClockTower")
	local towered = false
	if towerArt and towerArt:IsA("Model") and tower then
		local base, shaft, face =
			tower:FindFirstChild("Base"), tower:FindFirstChild("Shaft"), tower:FindFirstChild("ClockFace")
		if base and base:IsA("BasePart") and shaft and shaft:IsA("BasePart") and face and face:IsA("BasePart") then
			local m = towerArt:Clone()
			m.Name = "ClockTowerModel"
			local s = shaft.Size.Y / TOWER_SHAFT_H
			if math.abs(s - 1) > 1e-3 then
				m:ScaleTo(m:GetScale() * s)
			end
			local foot = base.Position - Vector3.new(0, base.Size.Y / 2, 0)
			local dir = (face.Position - shaft.Position) * Vector3.new(1, 0, 1)
			m:PivotTo(CFrame.lookAt(foot, foot + dir))
			noHit(m)
			camSolid(m, { "Brick" })
			m.Parent = toy
			for _, p in ipairs(tower:GetChildren()) do
				if p:IsA("BasePart") and TOWER_SHELL[p.Name] then
					hide(p, p.Name == "Base" or p.Name == "Shaft")
				end
			end
			towered = true
		end
	end

	-- ── 6. The dressing barrels become the modelled powder keg ───────────────────────────────────────────────────
	-- Each keg stands on its barrel's foot, scaled to its height, its label turned toward the spawn; the old barrel
	-- (a cylinder standing on end: its length is on X) stays, invisible, as the collision.
	local kegArt = props and props:FindFirstChild("PowderKeg")
	local kegHit = kegArt and kegArt:FindFirstChild("Hit")
	local kegs = 0
	if kegArt and kegArt:IsA("Model") and kegHit and kegHit:IsA("BasePart") and dressing then
		for _, c in ipairs(dressing:GetChildren()) do
			if c:IsA("BasePart") and c.Name == "Barrel" then
				local h = c.Size.X
				local m = kegArt:Clone()
				m.Name = "PowderKeg"
				m:ScaleTo(m:GetScale() * h / kegHit.Size.Y)
				local foot = c.Position - Vector3.new(0, h / 2, 0)
				m:PivotTo(CFrame.lookAt(foot, Vector3.new(look.X, foot.Y, look.Z)))
				-- the pivot is the bounding box's bottom centre (the label and the fuse pull it off-centre): centre the
				-- keg itself ("Wood") on the old barrel
				local wood = m:FindFirstChild("Wood")
				if wood and wood:IsA("BasePart") then
					local d = foot - wood.Position
					m:PivotTo(m:GetPivot() + Vector3.new(d.X, 0, d.Z))
				end
				noHit(m)
				m.Parent = toy
				hide(c, true)
				kegs += 1
			end
		end
	end

	-- ── 7. The shop stall's counter, back wall and awning become the modelled stall ─────────────────────────────
	-- The model's Counter foot lands on the old Counter's foot, facing the same way (the customer side, -Z, where the
	-- ShopPromptPart is). ShopSign keeps its "FIREWORKS & SKINS" SurfaceGui inside the model's gold frame;
	-- ShopPromptPart and PlinthBase / Plinth1..4 (DepotController spins the featured items on them) are untouched.
	local kioskArt = props and props:FindFirstChild("Kiosk")
	local shop = lobby:FindFirstChild("ShopKiosk")
	local counter = shop and shop:FindFirstChild("Counter")
	local stalled = false
	if kioskArt and kioskArt:IsA("Model") and shop and counter and counter:IsA("BasePart") then
		local m = kioskArt:Clone()
		m.Name = "ShopKioskModel"
		local foot = counter.CFrame * CFrame.new(0, -counter.Size.Y / 2, 0)
		m:PivotTo(foot * CFrame.new(-KIOSK_FROM_PIVOT))
		noHit(m)
		camSolid(m, { "Counter", "Back" })
		m.Parent = toy
		for _, p in ipairs(shop:GetChildren()) do
			if p:IsA("BasePart") and KIOSK_SHELL[p.Name] then
				hide(p, true)
			end
		end
		stalled = true
	end

	return ("Depot restyled: %d parts recoloured, %d crates swapped, %d stands, wheel %s, dispenser %s, tower %s, %d kegs, stall %s"):format(
		recoloured,
		swapped,
		#CRATES,
		if wheelArt then "yes" else "missing",
		if dispensed then "yes" else "missing",
		if towered then "yes" else "missing",
		kegs,
		if stalled then "yes" else "missing"
	)
end
