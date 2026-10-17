--!strict
-- Cosmetic looks shared by in-game effects and the Locker previews (Asset Bible §8). P0 stub: only what the
-- transferred ragdoll needs. The FUSE VALLEY catalogue (bomb skins, explosions, sparks, trails…) lands in P5.

local CosmeticLooks = {}

-- Ragdoll styles by id (Characters.ragdoll reads `elasticity` and limb limit extras). Empty = the default limp.
CosmeticLooks.Ragdolls = {} :: { [string]: { [string]: any } }

return CosmeticLooks
