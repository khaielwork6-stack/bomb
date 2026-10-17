--!strict
-- What each cosmetic looks like (Asset Bible §3.7, §5.6, §8), shared by the server (what may be sold / granted) and
-- every client (how to draw what someone has equipped). An item is `ready` only when its art exists here — the
-- store never shows anything else (GDD golden rule 2). Equipped cosmetics ride on the participant as attributes
-- (Eq_BombSkin, Eq_Explosion, Eq_FuseSpark, Eq_Trail, Eq_VictoryBoom, Eq_Title) so everyone sees them.
-- Implements: F-STORE-01 (definitions), Asset Bible §3.6 (skin rules: texture sets only, same mesh).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local St = Config.Store

local Cosmetics = {}

export type SkinPart = { color: string, normal: string, rough: string, metal: string }
export type Skin = {
	parts: { [string]: SkinPart }, -- Body / Brass / Clamp / Socket (the fuse is never skinned)
	lamp: Color3?, -- the band lamps' resting colour (stage colours still override at HOT / CRITICAL)
	glow: Color3?, -- an optional soft inner light (Paper Lantern, Lava Forge)
}

-- Bomb skins: baked texture sets on the shared mesh (art/bomb/skins.py → uploaded). Filled as each passes review.
Cosmetics.Skins = {} :: { [string]: Skin }

-- Fuse sparks: the spark sprite and streak colours (the ring keeps its stage colours, §3.5).
export type Spark =
	{ core: string, coreColor: Color3, streak: Color3, streak2: Color3, rate: number?, embers: boolean? }
Cosmetics.Sparks = {} :: { [string]: Spark }

-- Trails: a ribbon for dashes, slides and the Last Stand sprint (never team colours, §8.2).
export type Trail = { texture: string?, color: ColorSequence, width: number, lifetime: number, light: number? }
Cosmetics.Trails = {} :: { [string]: Trail }

-- Explosions: the boom stack's tint and texture swaps (same timing, same 7-stud ring, §5.6).
export type Explosion = { [string]: any }
Cosmetics.Explosions = {} :: { [string]: Explosion }

-- Victory booms: the win celebration.
export type Victory = { [string]: any }
Cosmetics.Victories = {} :: { [string]: Victory }

-- Emotes: animation ids (published by the user from tools/anim).
Cosmetics.Emotes = {} :: { [string]: string }

-- Is this item's art in the game?
function Cosmetics.ready(id: string): boolean
	local item = St.ById[id]
	if not item then
		return false
	end
	if item.rarity == "Default" or item.category == "Title" then
		return true
	end
	local c = item.category
	if c == "BombSkin" then
		return Cosmetics.Skins[id] ~= nil
	elseif c == "FuseSpark" then
		return Cosmetics.Sparks[id] ~= nil
	elseif c == "Trail" then
		return Cosmetics.Trails[id] ~= nil
	elseif c == "Explosion" then
		return Cosmetics.Explosions[id] ~= nil
	elseif c == "VictoryBoom" then
		return Cosmetics.Victories[id] ~= nil
	elseif c == "Emote" then
		local anim = Cosmetics.Emotes[id]
		return anim ~= nil and anim ~= ""
	end
	return false
end

-- Can it be bought (with Stars or Robux, or won from crates)? Exclusives and defaults never.
function Cosmetics.sellable(id: string): boolean
	local item = St.ById[id]
	return item ~= nil and St.PRICE[item.rarity] ~= nil and Cosmetics.ready(id)
end

-- The equipped-attribute name for a category.
function Cosmetics.attr(category: string): string
	return "Eq_" .. category
end

return Cosmetics
