--!strict
-- Profile template, migrations and repair (GDD §24.3, schema v1). Pure: no Roblox services.
-- reconcile() fills anything missing or of the wrong type from the template without touching valid data, so
-- adding a field is just adding it here. Open maps (inventory, receipts, quests…) keep whatever entries they hold.
-- Implements: F-DATA-01.

local ProfileSchema = {}

ProfileSchema.VERSION = 1

local function template(): { [string]: any }
	return {
		version = ProfileSchema.VERSION,
		createdAt = 0,
		saveCount = 0,
		firstJoin = 0,
		lastJoin = 0,
		level = 1,
		xp = 0, -- progress inside the current level
		stars = 0,
		inventory = {}, -- itemId -> true
		-- "" = the default for that slot
		equipped = {
			BombSkin = "",
			Explosion = "",
			FuseSpark = "",
			Trail = "",
			VictoryBoom = "",
			Title = "",
			Emotes = {},
		},
		stats = {
			rounds = 0,
			wins = 0,
			lastStandWins = 0,
			bomberWins = 0,
			defuses = 0,
			clutches = 0,
			passes = 0,
			booms = 0,
			revenge = 0,
			chains5 = 0,
			crossings = 0,
		},
		-- Daily systems (§14). day = the UTC day number these belong to.
		daily = {
			day = 0,
			quests = {}, -- { { id, progress, done, paid } } in tier order
			lastIds = {}, -- yesterday's quest ids (no repeats)
			rerolls = 0, -- rerolls used today
			crateClaimed = false, -- the Daily Crate for finishing all three
			playSec = 0, -- seconds played today (playtime gifts)
			giftsClaimed = {}, -- milestone index (as string) -> true
			firstWin = false, -- the first win of the day has been paid
		},
		login = { lastDay = 0, streakDay = 0, claimedDay = 0 },
		hotStreak = 0,
		pity = { Inferno = 0, opened = 0 }, -- Inferno pity + crate openings (the policy branch's fixed list)
		-- Rewards won before the P5 store exists to open / grant them: crates to open, items still owed.
		crates = { Spark = 0, GiftBox = 0 },
		owed = {}, -- list of reward kinds ("RareItem", "StreakBomb:2026-10") granted once the catalogue ships
		-- weekly leaderboards: the week number and each counter's value at the first round that week
		weekly = { week = 0, base = {} },
		settings = {}, -- key -> value (validated by PlayerService)
		wheel = { lastFree = 0, spins = 0 }, -- the lobby spin wheel: last free spin (os.time) and bought spins
		revives = 0, -- bought Revives not yet used (one applies at a boom, once per round)
		flags = {
			tutorial = false, -- the 4 rules card was closed
			starterOffered = false,
			starterAt = 0, -- when the Starter Bundle offer began (its 48 h countdown)
			starterBought = false,
			groupPerk = false,
			leadBomber = false, -- bought "Become Lead Bomber": starts the next round they play as a Bomber
			questsIntro = false,
			tips = {}, -- contextual tip id -> true (shown once)
			funnel = {}, -- onboarding funnel step -> true (logged once)
		},
		receipts = {}, -- purchase ids already granted (newest last), for idempotent ProcessReceipt
	}
end

function ProfileSchema.new(): { [string]: any }
	return template()
end

-- Keys whose table values are open maps / lists: kept as stored (only the type is checked).
local OPEN = {
	inventory = true,
	receipts = true,
	settings = true,
	tips = true,
	funnel = true,
	quests = true,
	lastIds = true,
	giftsClaimed = true,
	owed = true,
	base = true,
	Emotes = true,
}

local function fill(into: { [string]: any }, defaults: { [string]: any })
	for key, def in pairs(defaults) do
		local v = into[key]
		if type(v) ~= type(def) or v ~= v then -- missing, wrong type or NaN
			into[key] = if type(def) == "table" then table.clone(def) else def
		elseif type(def) == "table" and not OPEN[key] then
			fill(v, def)
		end
	end
end

-- Upgrade an older profile shape step by step. (Version 1 is the first; steps are added here as needed.)
local MIGRATIONS: { [number]: (any) -> () } = {}

function ProfileSchema.migrate(data: { [string]: any }): { [string]: any }
	local v = if type(data.version) == "number" then data.version else 1
	while v < ProfileSchema.VERSION do
		local step = MIGRATIONS[v]
		if step then
			step(data)
		end
		v += 1
	end
	data.version = ProfileSchema.VERSION
	return data
end

-- Returns a usable profile from whatever was stored (nil / garbage gives a fresh one).
function ProfileSchema.reconcile(stored: any): { [string]: any }
	if type(stored) ~= "table" then
		return template()
	end
	local data = ProfileSchema.migrate(stored)
	fill(data, template())
	data.level = math.max(1, math.floor(data.level))
	data.xp = math.max(0, math.floor(data.xp))
	data.stars = math.max(0, math.floor(data.stars))
	data.hotStreak = math.max(0, math.floor(data.hotStreak))
	return data
end

-- Remember a purchase id; keeps the newest `keep`. Returns false if it was already granted.
function ProfileSchema.addReceipt(data: { [string]: any }, purchaseId: string, keep: number): boolean
	local list = data.receipts :: { string }
	if table.find(list, purchaseId) then
		return false
	end
	table.insert(list, purchaseId)
	while #list > keep do
		table.remove(list, 1)
	end
	return true
end

return ProfileSchema
