--!strict
-- Active map + field frame derived from the built map's Zones (script contract in docs/ASSETS.md).
-- Side -1 = StartZone end, side +1 = FinishZone end. Runtime gameplay objects live in <Map>.Gameplay.
-- Implements: F-ARENA-01 (map data), F-ROLE-03 (safe zones, line walls), §5.2 spawning positions, §11.4 shrink.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local GameState = require(script.Parent.GameState)

local CG = Types.Collision
local A = Config.Arena

export type Field = {
	name: string,
	model: Model,
	gameplay: Folder,
	frame: CFrame, -- origin at field centre on the floor; LookVector points from side -1 to side +1
	halfLen: number, -- centre -> each start line (studs)
	safeDepth: number,
	width: number, -- full lateral width at 100%
	widthScale: number, -- current shrink factor
	floorY: number,
	zones: { [number]: BasePart },
}

local Arena = {}
Arena.current = nil :: Field?

local function mapsFolder(parent: Instance): Folder
	local f = parent:FindFirstChild("Maps") :: Folder?
	if not f then
		f = Instance.new("Folder")
		assert(f, "maps folder")
		f.Name = "Maps"
		f.Parent = parent
	end
	return f :: Folder
end

local function findMap(name: string): Model?
	local w = mapsFolder(workspace):FindFirstChild(name)
	if w and w:IsA("Model") then
		return w
	end
	local s = mapsFolder(ServerStorage):FindFirstChild(name)
	if s and s:IsA("Model") then
		return s
	end
	return nil
end

-- Lower a map below the lobby once (2026-10-06, Config.Arena.DROP) so the lobby looks down onto the field. The
-- attribute survives parking in ServerStorage; the map's sea foam ring stays at sea level.
local function dropMap(model: Model)
	if model:GetAttribute("CG_Dropped") then
		return
	end
	model:SetAttribute("CG_Dropped", true)
	local drop = Vector3.new(0, Config.Arena.DROP, 0)
	model:PivotTo(model:GetPivot() - drop)
	local foam = model:FindFirstChild("Foam")
	if foam and foam:IsA("BasePart") then
		foam.Position += drop
	end
end

function Arena.start()
	for _, parent in ipairs({ workspace, ServerStorage }) do
		for _, m in ipairs(mapsFolder(parent):GetChildren()) do
			if m:IsA("Model") then
				dropMap(m)
			end
		end
	end
end

function Arena.available(): { string }
	local out = {}
	for _, name in ipairs(Config.Maps.Order) do
		if findMap(name) then
			table.insert(out, name)
		end
	end
	return out
end

local function makeWall(parent: Instance, name: string, cf: CFrame, size: Vector3, group: string)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.CollisionGroup = group
	p.Parent = parent
	return p
end

local function buildWalls(f: Field)
	local walls = f.gameplay:FindFirstChild("Walls")
	if walls then
		walls:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	folder.Parent = f.gameplay
	local width = f.width * f.widthScale
	local h = 40
	-- Line walls: catchers can't enter safe zones, safe runners can't leave.
	for _, side in ipairs({ -1, 1 }) do
		makeWall(
			folder,
			"LineWall",
			f.frame * CFrame.new(0, h / 2, -side * f.halfLen) * CFrame.new(0, 0, side * 0.5),
			Vector3.new(width + 4, h, 1),
			CG.LineWall
		)
		-- back wall behind each safe zone
		makeWall(
			folder,
			"BackWall",
			f.frame * CFrame.new(0, h / 2, -side * (f.halfLen + f.safeDepth + 1)),
			Vector3.new(width + 6, h, 2),
			CG.Bounds
		)
	end
	local totalLen = (f.halfLen + f.safeDepth) * 2 + 4
	for _, s in ipairs({ -1, 1 }) do
		makeWall(
			folder,
			"SideWall",
			f.frame * CFrame.new(s * (width / 2 + 1), h / 2, 0),
			Vector3.new(2, h, totalLen),
			CG.Bounds
		)
	end
	-- Shrinking field (§9.2/§11.4): a visible toy fence marks each narrowed edge (the side walls do the blocking).
	-- Each side is its own model so it can slide in from the previous width.
	if f.widthScale < 0.999 then
		local paper, accent, danger =
			Color3.fromRGB(255, 247, 236), Color3.fromRGB(255, 122, 26), Color3.fromRGB(255, 59, 59)
		local len = f.halfLen * 2
		for _, s in ipairs({ -1, 1 }) do
			local fence = Instance.new("Model")
			fence.Name = "ShrinkFence" .. (if s < 0 then "L" else "R")
			fence:SetAttribute("Side", s)
			local function deco(
				size: Vector3,
				cf: CFrame,
				color: Color3,
				material: Enum.Material?,
				transparency: number?
			)
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Material = material or Enum.Material.SmoothPlastic
				p.Color = color
				p.Transparency = transparency or 0
				p.Size = size
				p.CFrame = cf
				p.Parent = fence
				if not fence.PrimaryPart then
					fence.PrimaryPart = p
				end
			end
			local x = s * (width / 2 + 0.2)
			for _, y in ipairs({ 1.2, 2.6 }) do
				deco(Vector3.new(0.35, 0.45, len), f.frame * CFrame.new(x, y, 0), accent)
			end
			deco(
				Vector3.new(1.4, 0.12, len),
				f.frame * CFrame.new(x - s * 0.9, 0.06, 0),
				danger:Lerp(Color3.new(0, 0, 0), 0.2),
				Enum.Material.Neon,
				0.35
			)
			local posts = math.floor(len / 6)
			for i = 0, posts do
				local z = -len / 2 + i * (len / posts)
				deco(Vector3.new(0.6, 3.4, 0.6), f.frame * CFrame.new(x, 1.7, z), paper)
			end
			fence.Parent = folder
		end
	end
end

-- Slide each fence from the previous width to the current one over SHRINK_TIME (server-driven; replicated).
local function slideFences(f: Field, fromWidth: number)
	local walls = f.gameplay:FindFirstChild("Walls")
	if not walls then
		return
	end
	local toWidth = f.width * f.widthScale
	local delta = (fromWidth - toWidth) / 2
	if delta <= 0.01 then
		return
	end
	for _, fence in ipairs(walls:GetChildren()) do
		if fence:IsA("Model") and fence:GetAttribute("Side") then
			local s = fence:GetAttribute("Side") :: number
			local target = fence:GetPivot()
			local offset = f.frame:VectorToWorldSpace(Vector3.new(s * delta, 0, 0))
			fence:PivotTo(target + offset)
			task.spawn(function()
				local t0 = os.clock()
				local dur = A.SHRINK_TIME
				while fence.Parent do
					local a = math.clamp((os.clock() - t0) / dur, 0, 1)
					local e = a * a * (3 - 2 * a)
					fence:PivotTo(target + offset * (1 - e))
					if a >= 1 then
						break
					end
					task.wait()
				end
			end)
		end
	end
end

-- Make `name` the active map. Returns the Field or nil if the map is missing.
function Arena.load(name: string): Field?
	local model = findMap(name)
	if not model then
		warn("[Arena] map not found:", name)
		return nil
	end
	-- Park every other map in ServerStorage.Maps; activate this one in Workspace.Maps.
	local wMaps, sMaps = mapsFolder(workspace), mapsFolder(ServerStorage)
	for _, m in ipairs(wMaps:GetChildren()) do
		if m ~= model and m:IsA("Model") then
			local g = m:FindFirstChild("Gameplay")
			if g then
				g:Destroy()
			end
			m.Parent = sMaps
		end
	end
	model.Parent = wMaps
	dropMap(model)
	-- Clone-at-runtime pieces the map's builder left (e.g. the Ship's crate block) go to ReplicatedStorage.CG_MapTemplates
	-- once, so they never show in the world and every client can clone them.
	local tpl = model:FindFirstChild("Templates")
	if tpl then
		local store = ReplicatedStorage:FindFirstChild("CG_MapTemplates")
		if not store then
			store = Instance.new("Folder")
			store.Name = "CG_MapTemplates"
			store.Parent = ReplicatedStorage
		end
		local old = store:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		tpl.Name = name
		tpl.Parent = store
	end

	local zones = model:FindFirstChild("Zones")
	local zA = zones and zones:FindFirstChild("StartZone") :: BasePart?
	local zB = zones and zones:FindFirstChild("FinishZone") :: BasePart?
	local fieldZone = zones and zones:FindFirstChild("Field") :: BasePart?
	local lineA = model:FindFirstChild("StartLine") :: BasePart?
	local lineB = model:FindFirstChild("FinishLine") :: BasePart?
	if not (zA and zB and fieldZone and lineA and lineB) then
		warn("[Arena] map is missing Zones/StartZone/FinishZone/Field or StartLine/FinishLine:", name)
		return nil
	end
	for _, z in ipairs({ zA, zB, fieldZone }) do
		z.CanCollide = false
		z.CanQuery = false
		z.CanTouch = false
	end

	local flat = Vector3.new(1, 0, 1)
	local axis = ((zB.Position - zA.Position) * flat).Unit
	local mid = (lineA.Position + lineB.Position) / 2
	local floorY = fieldZone.Position.Y - fieldZone.Size.Y / 2
	local origin = Vector3.new(mid.X, floorY, mid.Z)
	-- CFrame.lookAt puts -Z along axis; we want LookVector = axis (side -1 -> +1).
	local frame = CFrame.lookAt(origin, origin + axis)
	local halfLen = ((lineB.Position - lineA.Position) * flat).Magnitude / 2
	local zoneLocal = frame:VectorToObjectSpace(zA.CFrame:VectorToWorldSpace(zA.Size))
	local safeDepth = math.max(math.abs(zoneLocal.Z), 8)
	local lateral = frame:VectorToObjectSpace(lineA.CFrame:VectorToWorldSpace(lineA.Size))
	local width = math.max(math.abs(lateral.X), 20)

	local gameplay = model:FindFirstChild("Gameplay") :: Folder?
	if gameplay then
		gameplay:Destroy()
	end
	local g = Instance.new("Folder")
	g.Name = "Gameplay"
	g.Parent = model

	local f: Field = {
		name = name,
		model = model,
		gameplay = g,
		frame = frame,
		halfLen = halfLen,
		safeDepth = safeDepth,
		width = width,
		widthScale = 1,
		floorY = floorY,
		zones = { [-1] = zA, [1] = zB },
	}
	Arena.current = f
	-- Publish the field frame so clients can dress it (crowd stands, celebrations) without re-deriving it.
	GameState.set("FieldCFrame", frame)
	GameState.set("FieldHalfLen", halfLen)
	GameState.set("FieldHalfWidth", width / 2) -- unshrunk; FieldWidthScale carries the shrink
	GameState.set("FieldWidthScale", 1)
	buildWalls(f)
	return f
end

-- Field-local (x = lateral studs, z = along-axis studs where +z points to side +1) -> world.
function Arena.toWorld(x: number, z: number, y: number?): Vector3
	local f = assert(Arena.current, "no arena")
	return (f.frame * CFrame.new(x, y or 0, -z)).Position
end

-- World -> field-local (x lateral, z along axis toward side +1).
function Arena.toLocal(pos: Vector3): (number, number, number)
	local f = assert(Arena.current, "no arena")
	local l = f.frame:PointToObjectSpace(pos)
	return l.X, -l.Z, l.Y
end

function Arena.halfWidth(): number
	local f = assert(Arena.current, "no arena")
	return f.width * f.widthScale / 2
end

-- Facing CFrame at local (x, z) looking toward side `towardSide`.
function Arena.cframeAt(x: number, z: number, towardSide: number, lift: number?): CFrame
	local f = assert(Arena.current, "no arena")
	local pos = Arena.toWorld(x, z, lift or 3.0) -- R6 root centre sits 3 studs above the floor
	local dir = f.frame.LookVector * towardSide
	return CFrame.lookAt(pos, pos + dir)
end

-- Runner start positions on side `side` (inside the safe zone, just behind the line), facing the far side.
function Arena.runnerLine(side: number, count: number, r: Random?): { CFrame }
	local f = assert(Arena.current, "no arena")
	local out = {}
	local usable = Arena.halfWidth() * 2 * 0.9
	local spacing = usable / (count + 1)
	local z = side * (f.halfLen + math.min(f.safeDepth * 0.45, 4))
	for i = 1, count do
		local x = -usable / 2 + spacing * i
		if r then
			x += r:NextNumber(-A.SPAWN_JITTER, A.SPAWN_JITTER)
		end
		table.insert(out, Arena.cframeAt(x, z, -side))
	end
	return out
end

-- Catcher positions spread across the centre band, facing side `faceSide`.
function Arena.catcherBand(count: number, faceSide: number, r: Random?): { CFrame }
	local f = assert(Arena.current, "no arena")
	local out = {}
	local bandHalf = f.halfLen * A.CATCHER_BAND_FRAC
	local usable = Arena.halfWidth() * 2 * 0.8
	local perRow = math.max(1, math.floor(usable / A.CATCHER_MIN_SPACING))
	local rows = math.max(1, math.ceil(count / perRow))
	for i = 1, count do
		local row = (i - 1) // perRow
		local col = (i - 1) % perRow
		local inRow = math.min(perRow, count - row * perRow)
		local spacing = usable / (inRow + 1)
		local x = -usable / 2 + spacing * (col + 1)
		local z = if rows == 1 then 0 else -bandHalf + (2 * bandHalf) * (row / (rows - 1))
		if r then
			x += r:NextNumber(-A.SPAWN_JITTER, A.SPAWN_JITTER)
		end
		table.insert(out, Arena.cframeAt(x, z, faceSide))
	end
	return out
end

-- Is world position inside the safe zone on `side`? (local z beyond the line, within width)
function Arena.inSafe(pos: Vector3, side: number): boolean
	local f = Arena.current
	if not f then
		return false
	end
	local x, z, y = Arena.toLocal(pos)
	if y < -5 or y > 40 then
		return false
	end
	if math.abs(x) > Arena.halfWidth() + 2 then
		return false
	end
	return z * side >= f.halfLen
end

-- Is world position on the field (between the lines)?
function Arena.inField(pos: Vector3): boolean
	local f = Arena.current
	if not f then
		return false
	end
	local _, z = Arena.toLocal(pos)
	return math.abs(z) < f.halfLen
end

function Arena.setWidthScale(scale: number)
	local f = Arena.current
	if not f then
		return
	end
	local fromWidth = f.width * f.widthScale
	f.widthScale = math.clamp(scale, A.SHRINK_MIN, 1)
	GameState.set("FieldWidthScale", f.widthScale)
	buildWalls(f)
	slideFences(f, fromWidth)
end

return Arena
