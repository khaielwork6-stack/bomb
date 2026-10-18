--!strict
-- Lay the imported face rig onto the bomb (Asset Bible §3.8). Run ONCE in Studio's command bar (View → Command Bar)
-- after importing art/out/Bomb.Face/export/FaceRig.glb with Import 3D (default settings):
--   • finds the imported parts by name, fits them onto ReplicatedStorage.FV_Art.Bomb (scale + 3-point rigid fit), so it
--     doesn't matter where the importer dropped them or how it turned them;
--   • tags each part for Client/BombFace (FaceRole, FaceSide, FaceMouth, FacePivot, FaceRest);
--   • gives porcelain / brass / ink their PBR sets from Assets.Face, makes the glints and the scream's core Neon;
--   • shows only the Smirk mouth at rest, removes what's left of the import.
-- Then save + publish the place: the rig lives in the place file. The data below is generated from
-- art/out/Bomb.Face/export/FaceRig.json (pivots) and FaceRig.glb (rest centres), in the bomb's space.
-- Implements: Asset Bible §3.8 (import), §10.4.

local RIG = {
	BrowL = {
		role = "brow",
		side = "L",
		mouth = "",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, 0.00000, 0.00000),
			Vector3.new(-0.93042, 0.00000, -0.36650),
			Vector3.new(-0.24760, 0.73728, 0.62858),
			Vector3.new(0.27021, 0.67559, -0.68598)
		),
		centre = Vector3.new(-0.27330, 0.82594, 0.67943),
	},
	BrowR = {
		role = "brow",
		side = "R",
		mouth = "",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, 0.00000, 0.00000),
			Vector3.new(-0.93042, 0.00000, 0.36650),
			Vector3.new(0.24760, 0.73728, 0.62858),
			Vector3.new(-0.27021, 0.67559, -0.68598)
		),
		centre = Vector3.new(0.27330, 0.82594, 0.67943),
	},
	EyeL = {
		role = "eye",
		side = "L",
		mouth = "",
		mat = "Porcelain",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, -0.36650),
			Vector3.new(-0.32941, 0.43837, 0.83625),
			Vector3.new(0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(-0.33850, 0.44964, 0.88485),
	},
	EyeR = {
		role = "eye",
		side = "R",
		mouth = "",
		mat = "Porcelain",
		pivot = CFrame.fromMatrix(
			Vector3.new(0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, 0.36650),
			Vector3.new(0.32941, 0.43837, 0.83625),
			Vector3.new(-0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(0.33850, 0.44964, 0.88485),
	},
	GlintL = {
		role = "glint",
		side = "L",
		mouth = "",
		mat = "Glint",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, -0.36650),
			Vector3.new(-0.32941, 0.43837, 0.83625),
			Vector3.new(0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(-0.34652, 0.55742, 0.99078),
	},
	GlintR = {
		role = "glint",
		side = "R",
		mouth = "",
		mat = "Glint",
		pivot = CFrame.fromMatrix(
			Vector3.new(0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, 0.36650),
			Vector3.new(0.32941, 0.43837, 0.83625),
			Vector3.new(-0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(0.42228, 0.55742, 0.96094),
	},
	LidL = {
		role = "lid",
		side = "L",
		mouth = "",
		mat = "Ink",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, -0.36650),
			Vector3.new(-0.32941, 0.43837, 0.83625),
			Vector3.new(0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(-0.30523, 0.48547, 0.76626),
	},
	LidR = {
		role = "lid",
		side = "R",
		mouth = "",
		mat = "Ink",
		pivot = CFrame.fromMatrix(
			Vector3.new(0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, 0.36650),
			Vector3.new(0.32941, 0.43837, 0.83625),
			Vector3.new(-0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(0.30523, 0.48547, 0.76626),
	},
	MouthGrimace_Brass = {
		role = "mouth",
		side = "",
		mouth = "Grimace",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.59661, 0.91662),
	},
	MouthGrimace_Ink = {
		role = "mouth",
		side = "",
		mouth = "Grimace",
		mat = "Ink",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.60626, 0.93266),
	},
	MouthGrimace_Porcelain = {
		role = "mouth",
		side = "",
		mouth = "Grimace",
		mat = "Porcelain",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.60144, 0.92484),
	},
	MouthGrin_Brass = {
		role = "mouth",
		side = "",
		mouth = "Grin",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.63501, 0.89042),
	},
	MouthGrin_Ink = {
		role = "mouth",
		side = "",
		mouth = "Grin",
		mat = "Ink",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.62345, 0.92319),
	},
	MouthGrin_Porcelain = {
		role = "mouth",
		side = "",
		mouth = "Grin",
		mat = "Porcelain",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.63613, 0.90591),
	},
	MouthOoh_Brass = {
		role = "mouth",
		side = "",
		mouth = "Ooh",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.60768, 0.93442),
	},
	MouthOoh_Recess = {
		role = "mouth",
		side = "",
		mouth = "Ooh",
		mat = "Recess",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.59984, 0.92354),
	},
	MouthPanic_Brass = {
		role = "mouth",
		side = "",
		mouth = "Panic",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.62075, 0.90785),
	},
	MouthPanic_Core = {
		role = "mouth",
		side = "",
		mouth = "Panic",
		mat = "Core",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.00000, -0.61368, 0.90772),
	},
	MouthSmirk_Brass = {
		role = "mouth",
		side = "",
		mouth = "Smirk",
		mat = "Brass",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.00000, -0.59910, 0.92254),
			Vector3.new(-1.00000, 0.00000, -0.00000),
			Vector3.new(-0.00000, -0.54464, 0.83867),
			Vector3.new(-0.00000, 0.83867, 0.54464)
		),
		centre = Vector3.new(-0.02507, -0.56316, 0.93038),
	},
	PupilL = {
		role = "pupil",
		side = "L",
		mouth = "",
		mat = "Ink",
		pivot = CFrame.fromMatrix(
			Vector3.new(-0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, -0.36650),
			Vector3.new(-0.32941, 0.43837, 0.83625),
			Vector3.new(0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(-0.38490, 0.51222, 0.97714),
	},
	PupilR = {
		role = "pupil",
		side = "R",
		mouth = "",
		mat = "Ink",
		pivot = CFrame.fromMatrix(
			Vector3.new(0.30635, 0.40769, 0.77772),
			Vector3.new(-0.93042, 0.00000, 0.36650),
			Vector3.new(0.32941, 0.43837, 0.83625),
			Vector3.new(-0.16066, 0.89879, -0.40787)
		),
		centre = Vector3.new(0.38490, 0.51222, 0.97714),
	},
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Assets = require(ReplicatedStorage.Shared.Assets) :: any

local bomb = ReplicatedStorage:WaitForChild("FV_Art"):WaitForChild("Bomb") :: Model
local found: { [string]: MeshPart } = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("MeshPart") then
		-- the importer names a part after its node, or after its mesh inside a model named after the node
		local name = if RIG[d.Name] then d.Name elseif d.Parent and RIG[d.Parent.Name] then d.Parent.Name else nil
		if name and not found[name] then
			found[name] = d
		end
	end
end
local missing = {}
for name in pairs(RIG) do
	if not found[name] then
		table.insert(missing, name)
	end
end
if #missing > 0 then
	error("[FaceLayout] import FaceRig.glb first; missing: " .. table.concat(missing, ", "))
end

local recording = ChangeHistoryService:TryBeginRecording("FV face rig layout")

-- 1. Scale: the importer may have changed units. Match the eye spacing.
local holder = Instance.new("Model")
holder.Name = "FV_FaceFit"
holder.Parent = workspace
local sources: { [Instance]: boolean } = {} -- whatever the importer put the parts in (removed once empty)
for _, part in pairs(found) do
	if part.Parent and part.Parent ~= workspace then
		sources[part.Parent :: Instance] = true
	end
	part.Parent = holder
end
local want = (RIG.EyeR.centre - RIG.EyeL.centre).Magnitude
local got = (found.EyeR.Position - found.EyeL.Position).Magnitude
if math.abs(got / want - 1) > 0.005 then
	holder:ScaleTo(holder:GetScale() * want / got)
end

-- 2. A rigid fit from three reference points (both eyes and the smirk).
local function frameOf(a: Vector3, b: Vector3, c: Vector3): CFrame
	local x = (b - a).Unit
	local z = x:Cross(c - a).Unit
	return CFrame.fromMatrix(a, x, z:Cross(x), z)
end
local fit = frameOf(RIG.EyeL.centre, RIG.EyeR.centre, RIG.MouthSmirk_Brass.centre)
	* frameOf(found.EyeL.Position, found.EyeR.Position, found.MouthSmirk_Brass.Position):Inverse()
local worst = 0
for name, part in pairs(found) do
	part.CFrame = fit * part.CFrame
	worst = math.max(worst, (part.Position - RIG[name].centre).Magnitude)
end

-- 3. Tag, dress and move into the bomb.
local old = bomb:FindFirstChild("Face")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Face"
folder.Parent = bomb
local inv = bomb:GetPivot():Inverse() -- the bomb's own space (its pivot is the body centre)
for name, part in pairs(found) do
	local r = RIG[name]
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = r.role == "eye" or r.role == "brow"
	pcall(function()
		(part :: any).RenderFidelity = Enum.RenderFidelity.Precise
	end)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	if r.mat == "Glint" then
		part.Material = Enum.Material.Neon
		part.Color = Color3.new(1, 1, 1)
	elseif r.mat == "Core" then
		part.Material = Enum.Material.Neon
		part.Color = Color3.new(1, 0.92, 0.7)
	else
		local set = Assets.Face[if r.mat == "Recess" then "Ink" else r.mat]
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = set.color
		sa.NormalMap = set.normal
		sa.RoughnessMap = set.rough
		sa.MetalnessMap = set.metal
		if r.mat == "Recess" then
			sa.Color = Color3.fromRGB(150, 140, 160) -- the mouth's dark inside, a shade under the ink
		end
		sa.Parent = part
	end
	part:SetAttribute("FaceRole", r.role)
	part:SetAttribute("FaceSide", if r.side ~= "" then r.side else nil)
	part:SetAttribute("FaceMouth", if r.mouth ~= "" then r.mouth else nil)
	part:SetAttribute("FacePivot", r.pivot)
	part:SetAttribute("FaceRest", inv * part.CFrame)
	part.Transparency = if r.role == "mouth" and r.mouth ~= "Smirk" then 1 else 0
	part.Parent = folder
end
holder:Destroy()
for source in pairs(sources) do
	local top = source
	while top.Parent and top.Parent ~= workspace do
		top = top.Parent :: Instance
	end
	local hasParts = false
	for _, d in ipairs(top:GetDescendants()) do
		if d:IsA("BasePart") then
			hasParts = true
			break
		end
	end
	if top.Parent == workspace and not hasParts then
		top:Destroy()
	end
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(
	("[FaceLayout] %d parts on FV_Art.Bomb.Face; worst fit error %.4f studs (should be < 0.01). Save + publish."):format(
		#folder:GetChildren(),
		worst
	)
)
