--!strict
-- Levels (GDD §12.2, §12.3) as pure maths: XP to the next level, adding XP across several level-ups, the Stars each
-- level-up pays, and the level badge. Specs: Tests/LevelCurve.spec.
-- Implements: F-PROG-02, F-PROG-03 (numbers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local E = Config.Economy

local LevelCurve = {}

-- XP needed to go from `level` to `level + 1`.
function LevelCurve.xpToNext(level: number): number
	return math.min(E.XP_CAP, E.XP_BASE + E.XP_STEP * (math.max(1, level) - 1))
end

-- Add `gained` XP to (level, xp-into-level). Returns the new level, the new xp-into-level and every level reached.
function LevelCurve.add(level: number, xp: number, gained: number): (number, number, { number })
	local ups = {}
	local l, x = level, xp + math.max(0, math.floor(gained))
	while x >= LevelCurve.xpToNext(l) do
		x -= LevelCurve.xpToNext(l)
		l += 1
		table.insert(ups, l)
	end
	return l, x, ups
end

-- Stars paid on reaching `level`.
function LevelCurve.levelStars(level: number): number
	return math.min(E.LEVEL_STARS_CAP, E.LEVEL_STARS_BASE + E.LEVEL_STARS_PER * level)
end

-- Does reaching `level` earn a Level Track cosmetic?
function LevelCurve.trackLevel(level: number): boolean
	return level % E.LEVEL_TRACK_EVERY == 0
end

-- The level badge frame (bronze → … → obsidian), changing every BADGE_EVERY levels.
function LevelCurve.badge(level: number): string
	local i = math.clamp(math.floor((math.max(1, level) - 1) / E.BADGE_EVERY) + 1, 1, #E.BADGES)
	return E.BADGES[i]
end

-- Total XP ever earned at (level, xp) — for sorting and soak maths.
function LevelCurve.total(level: number, xp: number): number
	local sum = xp
	for l = 1, level - 1 do
		sum += LevelCurve.xpToNext(l)
	end
	return sum
end

return LevelCurve
