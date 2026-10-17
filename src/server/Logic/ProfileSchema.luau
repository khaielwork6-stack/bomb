--!strict
-- Profile template, migrations and repair (GDD §16.7). Pure: no Roblox services.
-- reconcile() fills anything missing or of the wrong type from the template without touching valid data, so
-- adding a field is just adding it here. Open maps (inventory, settings, tips) keep whatever keys they hold.

local ProfileSchema = {}

ProfileSchema.VERSION = 1

-- Loadout slots: "" means "nothing equipped / default".
local function template(): { [string]: any }
	return {
		version = ProfileSchema.VERSION,
		saveCount = 0,
		level = 1,
		xp = 0, -- progress inside the current level
		stars = 0,
		stats = {
			wins = 0,
			lastStandWins = 0,
			bonks = 0,
			anklesBroken = 0,
			braveEscapes = 0,
			revives = 0,
			crossingsSurvived = 0,
			matchesPlayed = 0,
			mvps = 0,
			perfectDodges = 0,
			longestSurvival = 0,
			bestDashTime = 0,
		},
		inventory = {}, -- itemId -> true (cosmetics owned)
		loadout = {
			tool = "",
			caughtFx = "",
			trail = "",
			brave = "",
			emote = "",
			ragdoll = "",
			title = "",
			abilityRunner = "",
			abilityCatcher = "",
		},
		settings = {}, -- key -> value (validated by PlayerService)
		rival = { name = "", n = 0 }, -- lifetime top rival (§18.2)
		receipts = {}, -- purchase ids already granted (newest last), for idempotent ProcessReceipt
		vip = false, -- VIP game pass (re-verified on every join)
		starterBundle = false, -- Starter Bundle bought (one per account)
		-- funnel: analytics onboarding steps logged (§21.9); modes: crossing modifiers met (the Modes page, discovery)
		flags = { welcomed = false, tips = {}, funnel = {}, modes = {} },
		-- spin wheel: free = earned free spins waiting (one per FREE_EVERY seconds played, they stack), progress =
		-- seconds played towards the next one, bank = bought spins not yet played. freeAt is the pre-stacking field
		-- (kept so old profiles load cleanly; unused).
		spins = { free = 1, progress = 0, freeAt = 0, bank = 0, total = 0 },
		-- weekly leaderboards: the week number and each counter's value at your first match that week
		weekly = { week = 0, base = {} },
		-- social rewards: who referred this player (0 = nobody), and which rewards were claimed
		-- supporterAt: when the supporter gift's panel first opened (os.time; 0 = never), supporterClaimed: got it
		social = {
			referredBy = 0,
			inviteClaimed = false,
			groupClaimed = false,
			supporterAt = 0,
			supporterClaimed = false,
		},
		firstJoin = 0,
		lastJoin = 0,
	}
end

function ProfileSchema.new(): { [string]: any }
	return template()
end

-- Keys whose table values are open maps / lists: kept as stored (only the type is checked).
local OPEN = { inventory = true, settings = true, receipts = true, tips = true, funnel = true, modes = true }

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
