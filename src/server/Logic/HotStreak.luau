--!strict
-- Hot Streak (GDD §15.1) as pure maths: the streak grows on a win or on reaching crossing STREAK_CROSSING, otherwise
-- resets; it multiplies that round's Stars. Specs: Tests/HotStreak.spec.
-- Implements: F-SOC-01 (rules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local E = Config.Economy

local HotStreak = {}

-- The streak after a round: `won` (any way) or `reached` (the highest crossing you were alive at the start of).
function HotStreak.after(streak: number, won: boolean, reached: number): number
	if won or reached >= E.STREAK_CROSSING then
		return streak + 1
	end
	return 0
end

-- The Stars multiplier for a streak (1 below 2; the top entry holds for anything above it).
function HotStreak.mult(streak: number): number
	local best, bestAt = 1, 0
	for at, m in pairs(E.STREAK_MULT) do
		if streak >= at and at > bestAt then
			best, bestAt = m, at
		end
	end
	return best
end

return HotStreak
