--!strict
-- What each cosmetic looks like (Asset Bible §3.7, §5.6, §8), shared by the server (what may be sold / granted) and
-- every client (how to draw what someone has equipped). An item is `ready` only when its art exists here — the
-- store never shows anything else (GDD golden rule 2). Equipped cosmetics ride on the participant as attributes
-- (Eq_BombSkin, Eq_Explosion, Eq_FuseSpark, Eq_Trail, Eq_VictoryBoom, Eq_Title) so everyone sees them.
-- Implements: F-STORE-01 (definitions), Asset Bible §3.6 (skin rules: texture sets only, same mesh), §5.6 and §8.1–8.3
-- (explosions, sparks, trails and victory booms ready once their art is in: art/vfx/COSMETICS.md).

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
-- `core` is the core sprite's texture (Assets.VfxCosmetic, or Assets.Vfx for a Classic one), `coreColor` the spark's
-- light, `rate` the shed rate; the full recipes live in Client/VfxCosmetic (art/vfx/COSMETICS.md §2).
local WHITE = Color3.new(1, 1, 1)
Cosmetics.Sparks = {
	Spark_Sparkler = {
		core = "spark_sparkler_star",
		coreColor = Color3.fromHex("#FFD84A"),
		streak = WHITE,
		streak2 = WHITE,
		rate = 18,
	},
	Spark_EmberDrift = {
		core = "spark_ember_dot",
		coreColor = Color3.fromHex("#FF9442"),
		streak = WHITE,
		streak2 = WHITE,
		rate = 4,
		embers = true,
	},
	Spark_Electric = {
		core = "spark_electric_arc",
		coreColor = Color3.fromHex("#8FB4FF"),
		streak = WHITE,
		streak2 = WHITE,
		rate = 5,
	},
	Spark_Pixie = {
		core = "spark_pixie_glitter",
		coreColor = Color3.fromHex("#FFB3DA"),
		streak = WHITE,
		streak2 = WHITE,
		rate = 10,
	},
	Spark_Plasma = {
		core = "spark_plasma_ball",
		coreColor = Color3.fromHex("#E83CFF"),
		streak = WHITE,
		streak2 = WHITE,
		rate = 6,
	},
	Spark_GoldLeaf = {
		core = "Flash",
		coreColor = Color3.fromHex("#F2B13A"),
		streak = WHITE,
		streak2 = WHITE,
		rate = 5,
	},
	Spark_Insignia = {
		core = "spark_insignia_star",
		coreColor = Color3.fromHex("#FF6A1F"),
		streak = Color3.fromHex("#FFD84A"),
		streak2 = Color3.fromHex("#FF6A1F"),
		rate = 8,
	},
} :: { [string]: Spark }

-- Trails: a ribbon for dashes, slides and the Last Stand sprint (never team colours, §8.2).
export type Trail = { texture: string?, color: ColorSequence, width: number, lifetime: number, light: number? }
-- `texture` is the strip's Assets.VfxCosmetic key; the ribbons are baked-colour, 1.6 studs wide, 0.25 s (COSMETICS.md §3).
local function trail(texture: string, light: number): Trail
	return { texture = texture, color = ColorSequence.new(WHITE), width = 1.6, lifetime = 0.25, light = light }
end
Cosmetics.Trails = {
	Trail_Soot = trail("trail_soot", 0),
	Trail_Streamers = trail("trail_streamers", 0),
	Trail_SparkLine = trail("trail_sparkline", 1),
	Trail_Rocket = trail("trail_rocket", 0.6),
	Trail_Comet = trail("trail_comet", 1),
	Trail_Neon = trail("trail_neon", 1),
	Trail_Aurora = trail("trail_aurora", 1),
	Trail_VictoryLap = trail("trail_victorylap", 0),
} :: { [string]: Trail }

-- Explosions: the boom stack's tint and texture swaps (same timing, same 7-stud ring, §5.6).
export type Explosion = { [string]: any }
-- Markers: the recipes (layers, tints, light variants) live in Client/VfxCosmetic (COSMETICS.md §1).
Cosmetics.Explosions = {
	Boom_Confetti = { recipe = "Boom_Confetti" },
	Boom_InkSplat = { recipe = "Boom_InkSplat" },
	Boom_Peony = { recipe = "Boom_Peony" },
	Boom_Pixel = { recipe = "Boom_Pixel" },
	Boom_Frost = { recipe = "Boom_Frost" },
	Boom_BlackHole = { recipe = "Boom_BlackHole" },
	Boom_Champagne = { recipe = "Boom_Champagne" },
} :: { [string]: Explosion }

-- Victory booms: the win celebration.
export type Victory = { [string]: any }
-- Markers: the recipes live in Client/VfxCosmetic (COSMETICS.md §4).
Cosmetics.Victories = {
	Victory_Confetti = { recipe = "Victory_Confetti" },
	Victory_Fountain = { recipe = "Victory_Fountain" },
	Victory_Finale = { recipe = "Victory_Finale" },
	Victory_Dragon = { recipe = "Victory_Dragon" },
	Victory_ChampagneTower = { recipe = "Victory_ChampagneTower" },
} :: { [string]: Victory }

-- Emotes: animation ids (tools/anim clips, published to the group — Assets.Anim).
local Assets = require(ReplicatedStorage.Shared.Assets)
Cosmetics.Emotes = {
	Emote_Wave = Assets.Anim.EmoteWave,
	Emote_FuseDance = Assets.Anim.EmoteFuseDance,
	Emote_Juggle = Assets.Anim.EmoteJuggle,
	Emote_Bow = Assets.Anim.EmoteBow,
	Emote_Shrug = Assets.Anim.EmoteShrug,
	Emote_VictoryPose = Assets.Anim.EmoteVictory,
	Emote_Kaboom = Assets.Anim.EmoteKaboom,
	Emote_SitSip = Assets.Anim.EmoteSitSip,
} :: { [string]: string }

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
		-- a skin is ready once its SurfaceAppearance set is built in the place (FV_Art.Skins.<id>)
		local art = ReplicatedStorage:FindFirstChild("FV_Art")
		local skins = art and art:FindFirstChild("Skins")
		return Cosmetics.Skins[id] ~= nil or (skins ~= nil and skins:FindFirstChild(id) ~= nil)
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
