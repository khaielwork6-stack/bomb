--!strict
-- Put a bomb skin on a copy of the hero bomb (Asset Bible §3.6): each skinned part's SurfaceAppearance is swapped
-- for the skin's (ReplicatedStorage.FV_Art.Skins.<SkinId>.<Part> — prebuilt in Studio, because SurfaceAppearance maps
-- can't be set at runtime). The mesh, the fuse, the seams and the lamp stages never change. Used on every Carrier's
-- bomb (BombController) and in the shop / locker previews.
-- Implements: F-STORE-01 (bomb skins on the real bomb).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinApply = {}

local PARTS = { "Body", "Brass", "Clamp", "Socket" }

-- The skin's folder of SurfaceAppearances, or nil (Classic / not built yet).
function SkinApply.folder(skinId: string?): Folder?
	if not skinId or skinId == "" or skinId == "Skin_Classic" then
		return nil
	end
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local skins = art and art:FindFirstChild("Skins")
	local f = skins and skins:FindFirstChild(skinId)
	return if f and f:IsA("Folder") then f else nil
end

-- Apply `skinId` to the parts of `model` (a clone of FV_Art.Bomb). Returns the skin's lamp colour, if it has one.
function SkinApply.apply(model: Instance, skinId: string?): Color3?
	local f = SkinApply.folder(skinId)
	if not f then
		return nil
	end
	for _, name in ipairs(PARTS) do
		local sa = f:FindFirstChild(name)
		local part = model:FindFirstChild(name, true)
		if sa and sa:IsA("SurfaceAppearance") and part and part:IsA("MeshPart") then
			local old = part:FindFirstChildOfClass("SurfaceAppearance")
			if old then
				old:Destroy()
			end
			sa:Clone().Parent = part
		end
	end
	local lamp = f:GetAttribute("Lamp")
	return if typeof(lamp) == "Color3" then lamp else nil
end

return SkinApply
