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
-- builders/MapYardProps.luau then swaps the Yard's part-built props for clones of these (MapDepotToy the Depot's).

-- [Name] = { model id, { [MeshPart] = { COLOR, ROUGHNESS, NORMAL, METAL decal ids } } }; an optional `obsidian` is a
-- second texture set for the same mesh (the Crown's level-50 variant), built as its own prop <Name>Obsidian (a
-- SurfaceAppearance's maps can't be changed at run time, so CrownController picks the prop instead).
local PROPS: {
	[string]: { model: number, maps: { [string]: { number } }, obsidian: { [string]: { number } }? },
} = {
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
	Sandbags = {
		model = 122575295836991,
		maps = {
			Bags = { 129558219894060, 99515410715912, 121148009977243, 101118168506418 },
			BagsTop = { 81126143975902, 98078449070641, 112011060612930, 77808289625557 },
		},
	},
	Shutter = {
		model = 79940434833832,
		maps = {
			Panel = { 92944819457599, 104946349480787, 70375061078590, 133379807123947 },
			BottomBar = { 88137722802985, 86567408464138, 121370106710165, 93210226054451 },
			Housing = { 127885022951573, 106076152747647, 85239004489922, 71944996206112 },
		},
	},
	DockBumper = {
		model = 104188696176957,
		maps = {
			Rubber = { 85325718716628, 133484065377611, 107763397803594, 83588861860649 },
			Plate = { 73145146886910, 121330359159250, 80823161776074, 76767131028317 },
		},
	},
	GiantRocket = {
		model = 73010623403079,
		maps = {
			Body = { 76290805341429, 85182617283709, 134403170122538, 123360068859239 }, -- near-white: MapYardProps tints it (colour A)
			Stripes = { 139914322460250, 102259068785103, 84238377133186, 72108101103687 }, -- near-white: tinted colour B
			Trim = { 82611897013953, 118405221999702, 119436461862224, 90309750327222 },
		},
	},
	Dispenser = {
		model = 115207641252547,
		maps = {
			Body = { 84875609044910, 90861860197938, 86857934697170, 93228990722074 },
			Trim = { 79120629062084, 70714363495129, 84302347273272, 115604079640347 },
			Bomb = { 78540136549446, 122405086338983, 130433305105392, 135543345338034 },
		},
	},
	Crown = { -- the winner's crown (CrownController); `obsidian` = the level-50 Obsidian Crown's maps on the same mesh
		model = 111475008028202,
		maps = {
			Gold = { 79013086805809, 104963681948528, 135883912259531, 104792963475879 },
			Velvet = { 130906693633010, 75214750923844, 112059815997782, 89204613160125 },
			Gems = { 116902536764406, 113797045815920, 122920156350520, 130160214346231 },
			Finials = { 99321491495125, 99604333569393, 134313039835822, 85272513025984 },
		},
		obsidian = {
			Gold = { 124756092254353, 140459337623030, 140713244437225, 102824952111723 },
			Velvet = { 85654968631679, 85566662751752, 104217522555893, 83402807930332 },
			Gems = { 102544611254807, 108515882764435, 139051864096312, 96767480288701 },
			Finials = { 99095943397895, 125352620081453, 72660473728509, 95571595056369 },
		},
	},
	ClockTower = { -- the Depot's clock tower shell (MapDepotToy; ClockFace / TowerBomb / SpiralFuse stay)
		model = 128389046554717,
		maps = {
			Brick = { 133523963377720, 137639886604910, 122918794118183, 114438745131623 },
			Trim = { 132403287502306, 128497236757484, 103828173794006, 72911238855476 },
			Gold = { 107319392381542, 71903066397901, 73279126405865, 116543329011781 },
		},
	},
	PowderKeg = { -- the Depot's dressing barrels (MapDepotToy)
		model = 133162482217426,
		maps = {
			Wood = { 131455464920370, 135255889699499, 114066214390313, 77897799525161 },
			Trim = { 136161995031746, 93571237658584, 70376224854172, 133502032052972 },
		},
	},
	Kiosk = { -- the Depot's shop stall (MapDepotToy; ShopSign / prompt / plinths stay MapDepot's)
		model = 132086991559987,
		maps = {
			Counter = { 117370972302621, 74026055319882, 118107178492870, 101468739627998 },
			Back = { 103767645047107, 84484181112923, 80502372059532, 97657188670982 },
			Awning = { 111628261013319, 109999489537513, 122091663232639, 81489504557402 },
			Trim = { 117850919305808, 85058243538925, 112568898160320, 102453391663028 },
		},
	},
	Palm = { -- MapYardToy's palms (MapYardProps)
		model = 72400061239653,
		maps = {
			Trunk = { 82147168886796, 93514758975973, 86477119792137, 104759194024790 },
			Fronds = { 135419809269461, 93238111431092, 92419486246900, 100044332677271 },
		},
	},
	VoxelTree = { -- MapYardToy's voxel trees (MapYardProps)
		model = 111451232124753,
		maps = {
			Leaves = { 95683798832031, 89716751905577, 73045568868156, 72668329097580 },
			Trunk = { 127484447829226, 117939372563419, 125196481615626, 123346375019924 },
		},
	},
}
local GLOW: { [string]: Color3 } = {
	Lens = Color3.fromRGB(255, 240, 210),
	Spark = Color3.fromRGB(255, 216, 74), -- the lit fuse tips (GiantRocket, Dispenser, PowderKeg)
}
local HIT_H: { [string]: number } = { -- collision height where the bounding box's top is decoration
	FireworkCrate = 2.6, -- the crate body, not the rockets
	HandTruck = 3.4, -- as the part-built one
	Dispenser = 3.4, -- the cabinet, not the bomb (MapDepotToy keeps the old box as the collision anyway)
	PowderKeg = 3, -- the keg, not its fuse: MapDepotToy scales each keg to its barrel's height with this
}
local NO_HIT: { [string]: boolean } = { -- worn / decorative only: the Hit box exists (the PrimaryPart) but never blocks
	Crown = true,
}
-- the FBX's units per stud (kit.export_fbx): 100 by default; props over 20.48 studs tall export at 10 units per stud so
-- Roblox's 2048-unit mesh cap never shrinks a part on its own
local IMPORT_SCALE: { [string]: number } = { ClockTower = 0.1, GiantRocket = 0.1 }
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
	model:ScaleTo(IMPORT_SCALE[name] or 0.01)
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
	hit.Anchored, hit.CanCollide, hit.CanQuery, hit.CanTouch = true, not NO_HIT[name], not NO_HIT[name], false
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
	if def.obsidian then
		local alt = model:Clone()
		alt.Name = name .. "Obsidian"
		for part, ids in pairs(def.obsidian) do
			local mp = alt:FindFirstChild(part)
			local sa = mp and mp:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa.ColorMap = texOf(ids[1])
				sa.RoughnessMap = texOf(ids[2])
				sa.NormalMap = texOf(ids[3])
				sa.MetalnessMap = texOf(ids[4])
				table.insert(sas, sa)
			end
		end
		local oldAlt = (lib :: Instance):FindFirstChild(alt.Name)
		if oldAlt then
			oldAlt:Destroy()
		end
		alt.Parent = lib
	end
	table.insert(report, ("%s %s (%d parts)"):format(name, tostring(size), #model:GetChildren()))
end
game:GetService("ContentProvider"):PreloadAsync(sas)
return table.concat(report, "\n")
