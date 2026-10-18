--!strict
-- FUSE VALLEY — Studio import for the Fireworks Yard props (Asset Bible §4.2 Yard / §4.4 props kit, §1 Quality Bar).
-- Run in the EDIT data model (Command Bar or Studio MCP execute_luau). Ids come from art/out/Prop.<Name>/export/ids.json
-- (the FBX model) and export/textures/ids.json (decals: COLOR, ROUGHNESS, NORMAL, METAL per MeshPart group).
-- For each prop it builds ReplicatedStorage.FV_Art.Props.<Name>:
--   • the FBX's MeshParts (named after their group), scaled 0.01 (Blender studs arrive x100), SurfaceAppearance PBR;
--   • Neon glow parts (the floodlight's "Lens");
--   • every MeshPart decorative (no collide / query / touch), plus one invisible "Hit" box (the PrimaryPart) with the
--     prop's footprint that carries the collision; HIT_H trims its height where the top is decoration (crate rockets,
--     the hand-truck's handle);
--   • the pivot at the bottom centre.
-- builders/MapYardProps.luau then swaps the Yard's part-built props for clones of these.

-- [Name] = { model id, { [MeshPart] = { COLOR, ROUGHNESS, NORMAL, METAL decal ids } } }
local PROPS: { [string]: { model: number, maps: { [string]: { number } } } } = {
	FireworkCrate = {
		model = 99527339693045,
		maps = {
			Body = { 101665377981948, 78060503563312, 122438946767974, 81035503341116 },
			Trim = { 82515576441081, 95352941235057, 109842749034427, 111344647946018 },
			Label = { 98278972327808, 81636324161164, 134177262878957, 104890366752698 },
			Rockets = { 83054454629871, 80162403547440, 99005947544471, 100428614120971 },
		},
	},
	HandTruck = {
		model = 82130338078781,
		maps = {
			Frame = { 119658895276627, 75055218300280, 96298662003069, 86308916841031 },
			Wheels = { 85658511020160, 106967051425805, 79737381337198, 82141330112768 },
			Load = { 134349258440016, 128737215207894, 133545111247236, 87201924361176 },
		},
	},
	Pallet = {
		model = 72061905079405,
		maps = {
			Pallet = { 103900027882995, 89521380991766, 100975457269052, 114607202534072 },
		},
	},
	GasBottle = {
		model = 122580265767356,
		maps = {
			Body = { 113504725775408, 114761212256390, 106915432103394, 122784649590885 }, -- near-white albedo: MapYardProps tints it (SurfaceAppearance.Color)
			Trim = { 97709453777973, 94326776563592, 84379609782529, 130844247830652 },
		},
	},
	Floodlight = {
		model = 139392239129268,
		maps = {
			Housing = { 110754374002265, 78396412078245, 108375277814936, 78725181500249 },
			Trim = { 139717746499941, 115541170826079, 116087804308690, 82912713961166 },
		},
	},
	RocketBundle = {
		model = 116751939826344,
		maps = {
			Rockets = { 116064250252998, 113257054730841, 96471681950306, 104265342101797 },
			Trim = { 83621183537142, 119689817855080, 121448226907882, 83478297955270 },
		},
	},
}
local GLOW: { [string]: Color3 } = {
	Lens = Color3.fromRGB(255, 240, 210),
}
local HIT_H: { [string]: number } = { -- collision height where the bounding box's top is decoration
	FireworkCrate = 2.6, -- the crate body, not the rockets
	HandTruck = 3.4, -- as the part-built one
}
local ONLY: string? = nil -- set to a prop name to re-import just that one

local IS = game:GetService("InsertService")
local texCache: { [number]: string } = {}
local function texOf(id: number): string
	if texCache[id] then
		return texCache[id]
	end
	local a = IS:LoadAsset(id)
	local d = a:FindFirstChildWhichIsA("Decal", true)
	local t = if d then d.Texture else ("rbxassetid://" .. id)
	a:Destroy()
	texCache[id] = t
	return t
end

local RS = game:GetService("ReplicatedStorage")
local art = RS:FindFirstChild("FV_Art")
if not art then
	art = Instance.new("Folder")
	art.Name = "FV_Art"
	art.Parent = RS
end
local lib = (art :: Instance):FindFirstChild("Props")
if not lib then
	lib = Instance.new("Folder")
	lib.Name = "Props"
	lib.Parent = art
end

local report = {}
local sas: { Instance } = {}
for name, def in pairs(PROPS) do
	if (ONLY and name ~= ONLY) or def.model == 0 then
		continue
	end
	local imp = IS:LoadAsset(def.model)
	local model = Instance.new("Model")
	model.Name = name
	for _, d in imp:GetDescendants() do
		if d:IsA("MeshPart") then
			d.Name = (d.Name:gsub("%.%d+$", ""))
			d.Parent = model
		end
	end
	imp:Destroy()
	model.WorldPivot = CFrame.new()
	model:ScaleTo(0.01)
	local bb, size = model:GetBoundingBox()
	local pivot = CFrame.new(bb.Position - Vector3.new(0, size.Y / 2, 0))

	for _, p in model:GetChildren() do
		if not p:IsA("MeshPart") then
			continue
		end
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
		local glow = GLOW[p.Name]
		if glow then
			p.Material = Enum.Material.Neon
			p.Color = glow
			p.CastShadow = false
		else
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.new(1, 1, 1)
			local ids = def.maps[p.Name]
			if ids and ids[1] ~= 0 then
				local sa = Instance.new("SurfaceAppearance")
				sa.ColorMap = texOf(ids[1])
				sa.RoughnessMap = texOf(ids[2])
				sa.NormalMap = texOf(ids[3])
				sa.MetalnessMap = texOf(ids[4])
				sa.Parent = p
				table.insert(sas, sa)
			end
		end
	end

	local h = HIT_H[name] or size.Y
	local hit = Instance.new("Part")
	hit.Name = "Hit"
	hit.Size = Vector3.new(size.X, h, size.Z)
	hit.CFrame = pivot * CFrame.new(0, h / 2, 0)
	hit.Anchored, hit.CanCollide, hit.CanQuery, hit.CanTouch = true, true, true, false
	hit.Transparency = 1
	hit.CastShadow = false
	hit.TopSurface, hit.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	hit.Parent = model
	model.PrimaryPart = hit
	-- with a PrimaryPart the model's pivot is the Hit box's pivot, so put the bottom centre there (WorldPivot alone
	-- would leave it at the box's centre and every swapped prop half a box into the floor)
	hit.PivotOffset = hit.CFrame:ToObjectSpace(pivot)

	local old = (lib :: Instance):FindFirstChild(name)
	if old then
		old:Destroy()
	end
	model.Parent = lib
	table.insert(report, ("%s %s (%d parts)"):format(name, tostring(size), #model:GetChildren()))
end
game:GetService("ContentProvider"):PreloadAsync(sas)
return table.concat(report, "\n")
