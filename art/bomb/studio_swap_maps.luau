--!strict
-- FUSE VALLEY — swap the hero bomb's Classic Iron maps for the Toy Arcade re-bake (Asset Bible §3, §10.4;
-- DECISIONS 2026-10-17 "Bomb": same mesh, better materials). Run ONCE in the EDIT data model of the art Studio
-- (Command Bar or Studio MCP execute_luau), then save + publish the place: FV_Art lives in the place file.
--
-- What it touches, and nothing else: the SurfaceAppearance of each Classic Iron MeshPart in
-- ReplicatedStorage.FV_Art.Bomb (Body / Brass / Socket / Clamp, and Fuse1..12, which all carry the one FuseCord set).
-- The face rig (parts tagged FaceRole), the lenses, lamps and seam glows, and the skins' prebuilt SurfaceAppearances
-- (FV_Art.Skins.<SkinId>, which SkinApply swaps in whole) are left alone. Before overwriting a map it stores the old id
-- on the SurfaceAppearance as an attribute (FV_Prev_ColorMap / _NormalMap / _RoughnessMap / _MetalnessMap), only if
-- no backup is there yet, so re-running keeps the ORIGINAL ids. Undo: Ctrl+Z, or copy the attributes back.
--
-- Ids: art/out/Bomb.ClassicIron/export/textures/ids.json (Open Cloud uploads, group 3774675, all Approved). They are
-- Decal ids; each is resolved to its image through InsertService (an id that is already an image is used as is).
-- Implements: Asset Bible §3 (Classic Iron materials), §10.4 (import).

local MAPS: { [string]: { color: number, normal: number, rough: number, metal: number } } = {
	Body = { color = 129150031808199, normal = 124459093039476, rough = 127336540606795, metal = 94017984233066 },
	Brass = { color = 80523836508117, normal = 137531708159286, rough = 97061373419088, metal = 87118073033039 },
	Socket = { color = 112786570026563, normal = 75108248800126, rough = 114157784321258, metal = 122377761744118 },
	Clamp = { color = 122475206988221, normal = 100785530010147, rough = 113604286127069, metal = 96759336441673 },
	FuseCord = { color = 118078181635002, normal = 107446530511372, rough = 138924699247606, metal = 97125824825683 },
}
local FIELDS = {
	{ key = "color", prop = "ColorMap" },
	{ key = "normal", prop = "NormalMap" },
	{ key = "rough", prop = "RoughnessMap" },
	{ key = "metal", prop = "MetalnessMap" },
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local cache: { [number]: string } = {}
local function texOf(id: number): string
	if cache[id] then
		return cache[id]
	end
	local tex = "rbxassetid://" .. id
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok and asset then
		local d = asset:FindFirstChildWhichIsA("Decal", true)
		if d and d.Texture ~= "" then
			tex = d.Texture
		end
		asset:Destroy()
	end
	cache[id] = tex
	return tex
end

local function setOf(part: MeshPart): string?
	if part:GetAttribute("FaceRole") ~= nil then
		return nil -- the face rig has its own sets (Assets.Face)
	end
	local n = part.Name
	if MAPS[n] then
		return n
	end
	if string.match(n, "^Fuse%d+$") then
		return "FuseCord"
	end
	return nil
end

local art = ReplicatedStorage:FindFirstChild("FV_Art")
local bomb = art and art:FindFirstChild("Bomb")
assert(bomb and bomb:IsA("Model"), "[SwapMaps] ReplicatedStorage.FV_Art.Bomb not found")

local recording = ChangeHistoryService:TryBeginRecording("FV Classic Iron maps (Toy Arcade)")
local report: { string } = {}
local swapped = 0
local missing: { string } = {}
for _, d in ipairs(bomb:GetDescendants()) do
	if not d:IsA("MeshPart") then
		continue
	end
	local key = setOf(d)
	if not key then
		continue
	end
	local sa = d:FindFirstChildOfClass("SurfaceAppearance")
	if not sa then
		table.insert(missing, d:GetFullName())
		continue
	end
	local ids = MAPS[key]
	for _, f in ipairs(FIELDS) do
		local backup = "FV_Prev_" .. f.prop
		local old = (sa :: any)[f.prop] :: string
		if sa:GetAttribute(backup) == nil then
			sa:SetAttribute(backup, old)
		end
		(sa :: any)[f.prop] = texOf((ids :: any)[f.key])
	end
	swapped += 1
	table.insert(report, ("%s <- %s"):format(d.Name, key))
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

if #missing > 0 then
	warn("[SwapMaps] no SurfaceAppearance on: " .. table.concat(missing, ", "))
end
print(
	("[SwapMaps] %d SurfaceAppearances updated (expect 16: Body, Brass, Socket, Clamp, Fuse1-12). Save + publish."):format(
		swapped
	)
)
return { swapped = swapped, missing = missing, parts = report }
