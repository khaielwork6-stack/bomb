--!strict
-- The calendar maths (GDD §14.2, §14.3) as pure functions: UTC day numbers, the login streak (with the miss penalty
-- and the 8+ loop), and playtime gift milestones. Specs: Tests/Daily.spec.
-- Implements: F-DAILY-05..10 (rules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local D = Config.Daily

local Daily = {}

-- The UTC day number of time `t` (seconds since the epoch).
function Daily.dayOf(t: number): number
	return math.floor(t / D.SECONDS_PER_DAY)
end

-- Seconds until the next UTC midnight.
function Daily.untilReset(t: number): number
	return D.SECONDS_PER_DAY - (t % D.SECONDS_PER_DAY)
end

-- The streak day you can claim `today`, given the day you last claimed and the streak day you claimed then.
-- Returns (dayToClaim, missed). Already claimed today → (streakDay, false) with nothing new to claim.
function Daily.loginDay(lastDay: number, streakDay: number, today: number): (number, boolean)
	if lastDay == 0 or streakDay <= 0 then
		return 1, false
	end
	if today == lastDay then
		return streakDay, false
	end
	if today == lastDay + 1 then
		return streakDay + 1, false
	end
	return math.max(1, streakDay + 1 - D.STREAK_MISS_PENALTY), true
end

-- Which of the 7 calendar rewards a streak day pays (days 8+ repeat LOOP_FROM..7).
function Daily.rewardIndex(streakDay: number): number
	local n = #D.LOGIN
	if streakDay <= n then
		return math.max(1, streakDay)
	end
	local span = n - D.LOOP_FROM + 1
	return D.LOOP_FROM + (streakDay - n - 1) % span
end

-- Playtime gift milestone `i` (1-based): the minutes it unlocks at and its reward (repeating after the list ends).
function Daily.gift(i: number): (number, string, number?)
	local list = D.GIFTS
	if i <= #list then
		local g = list[i]
		return g.minutes, g.kind, g.amount
	end
	return list[#list].minutes + (i - #list) * D.REPEAT_EVERY, "Stars", D.REPEAT_STARS
end

-- The first milestone not yet claimed: its index, whether it's ready, and the seconds left until it is.
function Daily.nextGift(playSec: number, claimed: { [string]: boolean }): (number, boolean, number)
	local i = 1
	while claimed[tostring(i)] do
		i += 1
	end
	local minutes = Daily.gift(i)
	local need = minutes * 60
	return i, playSec >= need, math.max(0, need - playSec)
end

return Daily
