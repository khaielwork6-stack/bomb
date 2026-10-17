--!strict
-- Daily quests (GDD §14.1) as pure functions: drawing today's three (one per tier, no repeat of yesterday's, only
-- quests whose features exist), and counting progress. Specs: Tests/Quests.spec.
-- Implements: F-DAILY-01, F-DAILY-03 (draw rules), F-DAILY-04 (progress counting).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)

type QuestDef = DailyConfig.Quest

local D = Config.Daily

local Quests = {}

export type Entry = { id: string, progress: number, done: boolean, paid: boolean }

local byId: { [string]: QuestDef } = {}
for _, q in ipairs(D.Pool) do
	byId[q.id] = q
end

function Quests.def(id: string): QuestDef?
	return byId[id]
end

-- Quests of `tier` that can be drawn: their feature exists and they weren't in `exclude`.
function Quests.candidates(tier: string, features: { [string]: boolean }, exclude: { string }): { string }
	local out = {}
	for _, q in ipairs(D.Pool) do
		if q.tier == tier and (q.requires == nil or features[q.requires]) and not table.find(exclude, q.id) then
			table.insert(out, q.id)
		end
	end
	return out
end

-- Draw one quest per tier. `avoid` = yesterday's ids (skipped unless nothing else is left). `rng` is injected.
function Quests.draw(features: { [string]: boolean }, avoid: { string }, rng: Random): { Entry }
	local out = {}
	for _, tier in ipairs(D.TIERS) do
		local pool = Quests.candidates(tier, features, avoid)
		if #pool == 0 then
			pool = Quests.candidates(tier, features, {})
		end
		if #pool > 0 then
			local id = pool[rng:NextInteger(1, #pool)]
			table.insert(out, { id = id, progress = 0, done = false, paid = false })
		end
	end
	return out
end

-- Replace the quest at `index` with a different one of the same tier (never one already in the list).
function Quests.reroll(list: { Entry }, index: number, features: { [string]: boolean }, rng: Random): boolean
	local entry = list[index]
	local q = entry and byId[entry.id]
	if not q or entry.done then
		return false
	end
	local taken = {}
	for _, e in ipairs(list) do
		table.insert(taken, e.id)
	end
	local pool = Quests.candidates(q.tier, features, taken)
	if #pool == 0 then
		return false
	end
	list[index] = { id = pool[rng:NextInteger(1, #pool)], progress = 0, done = false, paid = false }
	return true
end

-- Count `amount` of `event` toward every matching unfinished quest. Returns the indices that just completed.
function Quests.progress(list: { Entry }, event: string, amount: number?): { number }
	local finished = {}
	for i, e in ipairs(list) do
		local q = byId[e.id]
		if q and not e.done and q.event == event then
			e.progress = math.min(q.target, e.progress + (amount or 1))
			if e.progress >= q.target then
				e.done = true
				table.insert(finished, i)
			end
		end
	end
	return finished
end

function Quests.allDone(list: { Entry }): boolean
	if #list == 0 then
		return false
	end
	for _, e in ipairs(list) do
		if not e.done then
			return false
		end
	end
	return true
end

return Quests
