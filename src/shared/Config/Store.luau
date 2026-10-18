--!strict
-- The store (GDD §17, Asset Bible §3.7, §5.6, §8): every launch cosmetic, rarities and prices, the crates with their
-- odds and pity, the Robux products and game passes, and the daily featured rotation. An item is only ever shown
-- once its art exists (`Store.ready`, looked up from Assets) — nothing "coming soon" (golden rule 2). Robux
-- products / passes with id 0 haven't been created on the dashboard yet and stay hidden. [TUNE]
-- Implements: F-STORE-01..02, F-STORE-06..09 (numbers), F-STORE-11 (bundle contents).

export type Item = {
	id: string,
	category: string, -- BombSkin | Explosion | FuseSpark | Trail | VictoryBoom | Title | Emote
	name: string,
	rarity: string, -- Default | Common | Rare | Epic | Legendary | Exclusive
	source: string?, -- for Exclusives: how it's earned (Level, Streak, VIP, Group, Bundle, Achievement, Event)
}

local function list(category: string, rows: { { string } }): { Item }
	local out = {}
	for _, r in ipairs(rows) do
		table.insert(out, { id = r[1], category = category, name = r[2], rarity = r[3], source = r[4] })
	end
	return out
end

local Store = {}

Store.CATEGORIES = { "BombSkin", "Explosion", "FuseSpark", "Trail", "VictoryBoom", "Title", "Emote" }
Store.CATEGORY_NAME = {
	BombSkin = "BOMB SKINS",
	Explosion = "EXPLOSIONS",
	FuseSpark = "SPARKS",
	Trail = "TRAILS",
	VictoryBoom = "VICTORY",
	Title = "TITLES",
	Emote = "EMOTES",
}

Store.PRICE = { Common = 400, Rare = 1000, Epic = 2500, Legendary = 6000 } :: { [string]: number }
Store.ROBUX = { Common = 29, Rare = 99, Epic = 249, Legendary = 449 } :: { [string]: number }
Store.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Exclusive" }

local items: { Item } = {}
local function add(rows: { Item })
	for _, it in ipairs(rows) do
		table.insert(items, it)
	end
end

add(list("BombSkin", {
	{ "Skin_Classic", "Classic Iron", "Default" },
	{ "Skin_RookieBrass", "Rookie Brass", "Rare", "Bundle" },
	{ "Skin_CopperKettle", "Copper Kettle", "Common" },
	{ "Skin_Delft", "Delft", "Rare" },
	{ "Skin_Watermelon", "Watermelon", "Common" },
	{ "Skin_Gumball", "Gumball Machine", "Rare" },
	{ "Skin_LavaForge", "Lava Forge", "Epic" },
	{ "Skin_Frostbite", "Frostbite", "Epic" },
	{ "Skin_Clockwork", "Clockwork", "Epic" },
	{ "Skin_ThunderEgg", "Thunder Egg", "Epic" },
	{ "Skin_Disco", "Disco Night", "Rare" },
	{ "Skin_PaperLantern", "Paper Lantern", "Common" },
	{ "Skin_Galaxy", "Galaxy", "Legendary" },
	{ "Skin_DragonEgg", "Dragon Egg", "Legendary" },
	{ "Skin_Gilded", "Gilded", "Exclusive", "VIP" },
	{ "Skin_JackOFuse", "Jack-o'-Fuse", "Exclusive", "Streak" },
	{ "Skin_Tempered", "Tempered", "Exclusive", "Level" },
	{ "Skin_Meteorite", "Meteorite", "Exclusive", "Level" },
}))
add(list("Explosion", {
	{ "Boom_Classic", "Classic Kaboom", "Default" },
	{ "Boom_Confetti", "Confetti Cannon", "Common" },
	{ "Boom_InkSplat", "Ink Splat", "Rare" },
	{ "Boom_Peony", "Firework Peony", "Rare" },
	{ "Boom_Pixel", "Pixel Burst", "Epic" },
	{ "Boom_Frost", "Frost Nova", "Epic" },
	{ "Boom_BlackHole", "Black Hole", "Legendary" },
	{ "Boom_Champagne", "Champagne", "Exclusive", "VIP" },
}))
add(list("FuseSpark", {
	{ "Spark_Classic", "Classic", "Default" },
	{ "Spark_Sparkler", "Sparkler", "Common" },
	{ "Spark_EmberDrift", "Ember Drift", "Common" },
	{ "Spark_Electric", "Electric", "Rare" },
	{ "Spark_Pixie", "Pixie", "Rare" },
	{ "Spark_Plasma", "Plasma", "Epic" },
	{ "Spark_GoldLeaf", "Gold Leaf", "Legendary" },
	{ "Spark_Insignia", "Insignia", "Exclusive", "Group" },
}))
add(list("Trail", {
	{ "Trail_Soot", "Soot Streak", "Common" },
	{ "Trail_Streamers", "Paper Streamers", "Common" },
	{ "Trail_SparkLine", "Spark Line", "Rare" },
	{ "Trail_Rocket", "Rocket Exhaust", "Rare" },
	{ "Trail_Comet", "Comet", "Epic" },
	{ "Trail_Neon", "Neon Tube", "Epic" },
	{ "Trail_Aurora", "Aurora", "Legendary" },
	{ "Trail_VictoryLap", "Victory Lap", "Exclusive", "Level" },
}))
add(list("VictoryBoom", {
	{ "Victory_Volley", "Firework Volley", "Default" },
	{ "Victory_Confetti", "Confetti Rain", "Common" },
	{ "Victory_Fountain", "Golden Fountain", "Rare" },
	{ "Victory_Finale", "Grand Finale", "Epic" },
	{ "Victory_Dragon", "Dragon Dance", "Legendary" },
	{ "Victory_ChampagneTower", "Champagne Tower", "Exclusive", "VIP" },
}))
add(list("Title", {
	{ "Title_FreshFuse", "Fresh Fuse", "Exclusive", "Bundle" },
	{ "Title_SparkPlug", "Spark Plug", "Exclusive", "Level" },
	{ "Title_ShortFuse", "Short Fuse", "Exclusive", "Level" },
	{ "Title_HotPotato", "Hot Potato", "Exclusive", "Level" },
	{ "Title_PassMaster", "Pass Master", "Exclusive", "Level" },
	{ "Title_FuseWhisperer", "Fuse Whisperer", "Exclusive", "Level" },
	{ "Title_Demolitionist", "Demolitionist", "Exclusive", "Level" },
	{ "Title_BlastRadius", "Blast Radius", "Exclusive", "Level" },
	{ "Title_LivingLegend", "Living Legend", "Exclusive", "Level" },
	{ "Title_BigBang", "Big Bang", "Exclusive", "Level" },
	{ "Title_ObsidianCrown", "Obsidian Crown", "Exclusive", "Level" },
	{ "Title_ClutchKing", "Clutch King", "Exclusive", "Achievement" },
	{ "Title_RevengeServed", "Revenge Served", "Exclusive", "Achievement" },
	{ "Title_ChainReaction", "Chain Reaction", "Exclusive", "Achievement" },
	{ "Title_LastOneStanding", "Last One Standing", "Exclusive", "Achievement" },
	{ "Title_Unboomable", "Unboomable", "Exclusive", "Achievement" },
	{ "Title_MegaBomber", "Mega Bomber", "Exclusive", "Event" },
	{ "Title_MegaSurvivor", "Mega Survivor", "Exclusive", "Event" },
	{ "Title_Dethroner", "Dethroner", "Exclusive", "Achievement" },
	{ "Title_WeeklyChampion", "Weekly Champion", "Exclusive", "Event" },
	{ "Title_VIP", "VIP", "Exclusive", "VIP" },
}))
add(list("Emote", {
	{ "Emote_Wave", "Wave", "Common" },
	{ "Emote_FuseDance", "Fuse Dance", "Rare" },
	{ "Emote_Juggle", "Juggle", "Epic" },
	{ "Emote_Bow", "Bow", "Common" },
	{ "Emote_Shrug", "Shrug", "Common" },
	{ "Emote_VictoryPose", "Victory Pose", "Rare" },
	{ "Emote_Kaboom", "Kaboom", "Epic" },
	{ "Emote_SitSip", "Sit & Sip", "Rare" },
}))

Store.Items = items
Store.ById = {} :: { [string]: Item }
for _, it in ipairs(items) do
	Store.ById[it.id] = it
end

-- The defaults every profile has (not stored in the inventory).
Store.DEFAULTS = {
	BombSkin = "Skin_Classic",
	Explosion = "Boom_Classic",
	FuseSpark = "Spark_Classic",
	VictoryBoom = "Victory_Volley",
} :: { [string]: string }

-- The Level Track (Asset Bible §8.6): level → item granted on reaching it.
Store.LEVEL_TRACK = {
	[5] = "Spark_EmberDrift",
	[10] = "Skin_CopperKettle",
	[15] = "Title_PassMaster",
	[20] = "Trail_SparkLine",
	[25] = "Skin_Tempered",
	[30] = "Trail_VictoryLap",
	[40] = "Skin_Meteorite",
	[50] = "Title_ObsidianCrown",
} :: { [number]: string }
-- Level titles not on the track: earned at these levels.
Store.LEVEL_TITLES = {
	[2] = "Title_SparkPlug",
	[6] = "Title_ShortFuse",
	[12] = "Title_HotPotato",
	[18] = "Title_FuseWhisperer",
	[24] = "Title_Demolitionist",
	[32] = "Title_BlastRadius",
	[45] = "Title_LivingLegend",
	[60] = "Title_BigBang",
} :: { [number]: string }
-- Achievement titles: lifetime stat → threshold.
Store.ACHIEVEMENTS = {
	{ id = "Title_ClutchKing", stat = "clutches", at = 100 },
	{ id = "Title_RevengeServed", stat = "revenge", at = 100 },
	{ id = "Title_ChainReaction", stat = "chains5", at = 25 },
	{ id = "Title_LastOneStanding", stat = "lastStandWins", at = 10 },
	{ id = "Title_Unboomable", stat = "wins", at = 50 },
}
-- The monthly Streak Bomb: "YYYY-MM" → skin id (falls back to the newest one listed).
Store.STREAK_BOMBS = { ["2026-10"] = "Skin_JackOFuse" } :: { [string]: string }

-- Crates (§17.4). Odds by rarity; pity: Epic+ guaranteed within `pity` openings.
Store.CRATES = {
	Spark = { name = "Spark Crate", stars = 600, odds = { Common = 0.60, Rare = 0.30, Epic = 0.09, Legendary = 0.01 } },
	Inferno = {
		name = "Inferno Crate",
		stars = 1500,
		odds = { Rare = 0.55, Epic = 0.35, Legendary = 0.10 },
		pity = 8,
	},
	-- the 60-minute playtime Gift Box: Rare guaranteed, 15 % Epic
	GiftBox = { name = "Gift Box", stars = 0, odds = { Rare = 0.85, Epic = 0.15 }, free = true },
} :: { [string]: any }
Store.DUPLICATE_REFUND = 0.5 -- of the item's Stars price

-- Daily featured rotation (F-STORE-03): 4 items, one DEAL.
Store.FEATURED = 4
Store.DEAL_OFF = 0.20

-- Robux developer products and game passes (§17.2). id = 0: not created on the dashboard yet (hidden).
Store.PRODUCTS = {
	Stars500 = { id = 0, robux = 49, stars = 500 },
	Stars1200 = { id = 0, robux = 99, stars = 1200, tag = "BEST VALUE" },
	Stars3000 = { id = 0, robux = 229, stars = 3000 },
	Stars7000 = { id = 0, robux = 479, stars = 7000 },
	StarterBundle = { id = 0, robux = 99, stars = 1500, items = { "Skin_RookieBrass", "Title_FreshFuse" } },
	ItemCommon = { id = 0, robux = 29 },
	ItemRare = { id = 0, robux = 99 },
	ItemEpic = { id = 0, robux = 249 },
	ItemLegendary = { id = 0, robux = 449 },
	CrateSpark = { id = 0, robux = 49, crate = "Spark" },
	CrateInferno = { id = 0, robux = 129, crate = "Inferno" },
	SummonMega = { id = 0, robux = 99 },
	-- The owner's calls, 2026-10-18 ("decide the prices… reasonable, we could change this later"; DECISIONS):
	Spin1 = { id = 0, robux = 25, spins = 1 }, -- the lobby wheel
	Spin5 = { id = 0, robux = 99, spins = 5 },
	LeadBomber = { id = 0, robux = 25, lead = true }, -- start the next round as a Bomber
	Revive = { id = 0, robux = 20, revive = true }, -- get up as a Runner after a boom (once per round)
	-- the pack card during the pick (the reference's was R$ 112 for 2 items + 50 Gems): 2 Epic cosmetics + 500 Gems
	BomberPack = { id = 0, robux = 99, stars = 500, items = { "Boom_Frost", "Emote_Kaboom" } },
	RunnerPack = { id = 0, robux = 99, stars = 500, items = { "Trail_Comet", "Emote_FuseDance" } },
} :: { [string]: any }
Store.PASSES = {
	VIP = {
		id = 0,
		robux = 299,
		starsBonus = 0.10,
		items = { "Skin_Gilded", "Boom_Champagne", "Victory_ChampagneTower", "Title_VIP" },
	},
	Workshop = { id = 0, robux = 149 },
} :: { [string]: any }

Store.STARTER_OFFER_AFTER_ROUNDS = 3
Store.STARTER_OFFER_HOURS = 48

return Store
