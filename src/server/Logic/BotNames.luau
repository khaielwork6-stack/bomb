--!strict
-- Bot names that read like real Roblox usernames (the owner, 2026-10-18: "SpicyMuffin" style names gave the bots
-- away). Real names are messy: a word and a birth year, a first name and some digits, an underscore, an "x" or "its"
-- prefix, a stretched vowel, a "YT" tag, mixed casing. This builds them from Config.Bots.Names fragments with the
-- same rules Roblox enforces: 3–20 characters, letters / digits / at most one underscore, never at either end.
-- Pure (an rng in, a name out) so it has specs (Tests/BotNames.spec). No famous names; nobody is impersonated.
-- Implements: F-BOT-06 (natural names), DECISIONS 2026-10-19.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local N = Config.Bots.Names

local BotNames = {}

local function pick(rng: Random, list: { string }): string
	return list[rng:NextInteger(1, #list)]
end

local function cap(s: string): string
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- some casing: all lower, Capitalised, or (rarely) ALL CAPS
local function cased(rng: Random, s: string): string
	local r = rng:NextNumber()
	if r < 0.55 then
		return string.lower(s)
	elseif r < 0.95 then
		return cap(string.lower(s))
	end
	return string.upper(s)
end

local function digits(rng: Random): string
	local r = rng:NextNumber()
	if r < 0.35 then
		return tostring(rng:NextInteger(N.YEAR_MIN, N.YEAR_MAX)) -- a birth year
	elseif r < 0.6 then
		return tostring(rng:NextInteger(1, 99))
	elseif r < 0.85 then
		return tostring(rng:NextInteger(100, 9999))
	end
	return string.rep(tostring(rng:NextInteger(1, 9)), rng:NextInteger(2, 3)) -- 777, 22
end

local function stretch(rng: Random, s: string): string
	-- double one vowel: "jaxon" → "jaaxon"
	local vowels = {}
	for i = 1, #s do
		if string.find("aeiouy", string.sub(s, i, i), 1, true) then
			table.insert(vowels, i)
		end
	end
	if #vowels == 0 then
		return s
	end
	local i = vowels[rng:NextInteger(1, #vowels)]
	local c = string.sub(s, i, i)
	return string.sub(s, 1, i) .. string.rep(c, rng:NextInteger(1, 2)) .. string.sub(s, i + 1)
end

local function leet(s: string): string
	return (string.gsub(string.gsub(string.lower(s), "o", "0"), "i", "1"))
end

-- One candidate (may break the rules; `legal` checks).
local function candidate(rng: Random): string
	local r = rng:NextNumber()
	local word, other, first = pick(rng, N.WORDS), pick(rng, N.WORDS), pick(rng, N.FIRST)
	local maybeDigits = if rng:NextNumber() < 0.6 then digits(rng) else ""
	if r < 0.22 then
		return cased(rng, first) .. (if rng:NextNumber() < 0.4 then "_" else "") .. digits(rng) -- maya_2011, Kai88
	elseif r < 0.36 then
		return string.lower(first) .. tostring(rng:NextInteger(100, 99999)) -- lily38213
	elseif r < 0.48 then
		return if rng:NextNumber() < 0.5
			then cased(rng, word) .. "_" .. string.lower(first)
			else string.lower(first) .. "_" .. cased(rng, word) -- sleepy_kai, kai_frosty
	elseif r < 0.58 then
		return cased(rng, word) .. string.lower(other) .. digits(rng) -- ghostwolf2012 (always with digits)
	elseif r < 0.66 then
		return pick(rng, N.PREFIX) .. cap(if rng:NextNumber() < 0.6 then first else word) .. maybeDigits -- itsLuna, TheRealMax09
	elseif r < 0.73 then
		return cap(stretch(rng, string.lower(first))) .. maybeDigits -- Jaaaxon
	elseif r < 0.8 then
		return if rng:NextNumber() < 0.75
			then "x" .. cap(if rng:NextNumber() < 0.5 then first else word) .. (if rng:NextNumber() < 0.5
				then "x"
				else "")
			else "xX" .. cap(word) .. "Xx" -- xMaya, xXGlitchXx
	elseif r < 0.86 then
		return leet(if rng:NextNumber() < 0.5 then word else first) .. maybeDigits -- n0va77, l1ly
	elseif r < 0.92 then
		return cap(if rng:NextNumber() < 0.5 then first else word) .. pick(rng, N.SUFFIX) -- MayaYT, NovaPlayz
	end
	return cap(word) .. cap(other) .. tostring(rng:NextInteger(1, 999)) -- ShadowFox77 (rare, never bare)
end

-- Does `name` follow Roblox's username rules and our filter?
function BotNames.legal(name: string): boolean
	if #name < 3 or #name > 20 then
		return false
	end
	if string.find(name, "[^%w_]") then
		return false
	end
	local _, underscores = string.gsub(name, "_", "")
	if underscores > 1 or string.sub(name, 1, 1) == "_" or string.sub(name, -1) == "_" then
		return false
	end
	local lower = string.lower(name)
	for _, bad in ipairs(N.BLOCK) do
		if string.find(lower, bad, 1, true) then
			return false
		end
	end
	return true
end

-- A fresh name not in `taken` (compared without case). Falls back to a plain name + digits after many tries.
function BotNames.generate(rng: Random, taken: { [string]: boolean }): string
	for _ = 1, 60 do
		local name = candidate(rng)
		if BotNames.legal(name) and not taken[string.lower(name)] then
			return name
		end
	end
	local name: string
	repeat
		name = string.lower(pick(rng, N.FIRST)) .. tostring(rng:NextInteger(1000, 99999))
	until not taken[string.lower(name)]
	return name
end

return BotNames
