--!strict
-- Crate openings (GDD §17.4) as pure maths: roll a rarity by the crate's odds (with the Inferno pity forcing Epic+
-- once enough openings missed it), pick an item of that rarity from the pool, refund duplicates at half price, and
-- the paid-random-items policy branch: where those are restricted, free crates give a fixed-list item instead of
-- rolling. Specs: Tests/Store.spec (odds over 100k rolls, pity, policy).
-- Implements: F-STORE-06..09 (maths).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local St = Config.Store

local CrateRoll = {}

export type Result = { item: string, rarity: string, duplicate: boolean, refund: number, pity: number }

local ORDER = { "Common", "Rare", "Epic", "Legendary" }

-- Roll a rarity from `odds` (a number in [0, 1) from the injected rng). `forceEpic` renormalises to Epic+.
function CrateRoll.rarity(odds: { [string]: number }, r: number, forceEpic: boolean?): string
	local total = 0
	for _, k in ipairs(ORDER) do
		if odds[k] and (not forceEpic or k == "Epic" or k == "Legendary") then
			total += odds[k]
		end
	end
	local x = r * total
	local last = "Common"
	for _, k in ipairs(ORDER) do
		local p = odds[k]
		if p and (not forceEpic or k == "Epic" or k == "Legendary") then
			last = k
			if x < p then
				return k
			end
			x -= p
		end
	end
	return last
end

-- One opening. `pool` = item ids by rarity; `owned` = the inventory; `pity` = openings since the last Epic+ (for
-- crates with pity). Returns the result (with the new pity count).
function CrateRoll.open(
	crate: { [string]: any },
	pool: { [string]: { string } },
	owned: { [string]: boolean },
	pity: number,
	rng: Random
): Result
	local force = crate.pity ~= nil and pity >= crate.pity - 1
	local rarity = CrateRoll.rarity(crate.odds, rng:NextNumber(), force)
	-- a rarity with no items in the pool falls back to the nearest one that has some (never an empty roll)
	if not pool[rarity] or #pool[rarity] == 0 then
		for _, k in ipairs(ORDER) do
			if pool[k] and #pool[k] > 0 then
				rarity = k
				if crate.odds[k] then
					break
				end
			end
		end
	end
	local list = pool[rarity] or {}
	local item = list[rng:NextInteger(1, math.max(1, #list))] or ""
	local duplicate = owned[item] == true
	local newPity = if crate.pity == nil then 0 elseif rarity == "Epic" or rarity == "Legendary" then 0 else pity + 1
	return {
		item = item,
		rarity = rarity,
		duplicate = duplicate,
		refund = if duplicate then math.floor((St.PRICE[rarity] or 0) * St.DUPLICATE_REFUND) else 0,
		pity = newPity,
	}
end

-- Policy branch (F-STORE-09): the free crate's fixed-list item for this opening number (no randomness).
function CrateRoll.fixed(pool: { [string]: { string } }, crate: { [string]: any }, openings: number): Result
	local all = {}
	for _, k in ipairs(ORDER) do
		if crate.odds[k] then
			for _, id in ipairs(pool[k] or {}) do
				table.insert(all, { id = id, rarity = k })
			end
		end
	end
	table.sort(all, function(a, b)
		return a.id < b.id
	end)
	local pick = all[(openings % math.max(1, #all)) + 1]
	return {
		item = if pick then pick.id else "",
		rarity = if pick then pick.rarity else "Common",
		duplicate = false,
		refund = 0,
		pity = 0,
	}
end

return CrateRoll
