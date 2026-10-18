--!strict
-- FUSE VALLEY — Studio import for the Spark Crate (GDD §17.4 F-STORE-10, Asset Bible §7.4, §10.4).
-- Run in the EDIT data model of the art Studio (Studio MCP execute_luau). Ids come from art/out/Crate.Spark/export/ids.json
-- and export/textures/ids.json. It builds ReplicatedStorage.FV_Art.Crates.Spark: MeshParts BodyWood / BodyBrass /
-- LidWood / LidBrass with SurfaceAppearance PBR, Neon Spark / LatchSpark / InnerGlow, a Hinge attachment on the back
-- top edge (the lid swings about its X axis), and drops a preview copy on the Yard for screenshots.

local MODEL = 110796700368449
local MAPS = {
	BodyWood = { 116004737732284, 125683385681794, 84902296876237, 123414201632857 },
	BodyBrass = { 113363002393217, 76543966647542, 139766442401646, 127838441601130 },
	LidWood = { 137823230495365, 84114457093161, 85965379138476, 102860145772920 },
	LidBrass = { 70902806713042, 119589285057142, 102927665345278, 115629252981844 },
}
local GLOW = {
	Spark = Color3.fromRGB(255, 216, 74),
	LatchSpark = Color3.fromRGB(255, 216, 74),
	InnerGlow = Color3.fromRGB(255, 194, 58),
}
local HINGE = Vector3.new(0, 1.5, 1.25) -- studs, model space (back top edge; Blender +Y back → Roblox +Z)
local PREVIEW_AT = CFrame.new(-50, 88.1, -55) * CFrame.Angles(0, math.rad(200), 0)

local IS = game:GetService("InsertService")
local function texOf(id: number): string
	local a = IS:LoadAsset(id)
	local d = a:FindFirstChildWhichIsA("Decal", true)
	local t = if d then d.Texture else ("rbxassetid://" .. id)
	a:Destroy()
	return t
end

local imp = IS:LoadAsset(MODEL)
local model = Instance.new("Model")
model.Name = "Spark"
for _, d in imp:GetDescendants() do
	if d:IsA("MeshPart") then
		d.Name = (d.Name:gsub("%.%d+$", ""))
		d.Parent = model
	end
end
imp:Destroy()
model.WorldPivot = CFrame.new()
model:ScaleTo(0.01)
local _, size = model:GetBoundingBox()
-- Pivot at the bottom centre.
local cf = model:GetBoundingBox()
model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))

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
		local ids = MAPS[p.Name]
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.new(1, 1, 1)
		if ids then
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = texOf(ids[1])
			sa.RoughnessMap = texOf(ids[2])
			sa.NormalMap = texOf(ids[3])
			sa.MetalnessMap = texOf(ids[4])
			sa.Parent = p
		end
	end
end

local body = model:FindFirstChild("BodyWood") :: BasePart
local hinge = Instance.new("Attachment")
hinge.Name = "Hinge"
hinge.WorldPosition = model.WorldPivot:PointToWorldSpace(HINGE)
hinge.Parent = body

local art = game.ReplicatedStorage:FindFirstChild("FV_Art") :: Folder
local crates = art:FindFirstChild("Crates") or Instance.new("Folder")
crates.Name = "Crates"
crates.Parent = art
local old = crates:FindFirstChild("Spark")
if old then
	old:Destroy()
end
model.Parent = crates

local prevOld = workspace:FindFirstChild("FV_ModelPreview")
if prevOld then
	prevOld:Destroy()
end
local prev = model:Clone()
prev.Name = "FV_ModelPreview"
prev:PivotTo(PREVIEW_AT)
prev.Parent = workspace
local list = {}
for _, sa in prev:GetDescendants() do
	if sa:IsA("SurfaceAppearance") then
		table.insert(list, sa)
	end
end
game:GetService("ContentProvider"):PreloadAsync(list)
task.wait(8)
local _, sz = model:GetBoundingBox()
return { size = tostring(sz), parts = #model:GetChildren() }
