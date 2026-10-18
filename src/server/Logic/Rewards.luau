--!strict
-- Reward maths (GDD §11.1, §12.1, §13.3, §15.1, §15.3, §24.1) as pure functions: what a callout pays, the anti-farm
-- rules, and the round's Stars after the Hot Streak and squad multipliers and the balance cap. RewardService keeps
-- the per-round counters and does the paying. Specs: Tests/Rewards.spec.
-- Implements: F-CALL-02, F-ECO-03, F-SOC-03 (maths).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local E = Config.Economy

local Rewards = {}

export type Pay = { xp: number, stars: number }

-- What a callout pays before multipliers. `n` = chain links; `onBot` = the credit was earned on a bot (halved for
-- the keys in BOT_HALVED); `smallPrivate` halves the Stars (private server with too few humans).
function Rewards.callout(key: string, n: number?, onBot: boolean?, smallPrivate: boolean?): Pay
	local def = E.Callouts[key]
	if not def then
		return { xp = 0, stars = 0 }
	end
	local k = if key == "Chain" then math.max(0, n or 0) else 1
	local xp, stars = def.xp * k, def.stars * k
	if onBot and E.BOT_HALVED[key] then
		xp, stars = xp * E.BOT_CREDIT_MULT, stars * E.BOT_CREDIT_MULT
	end
	if smallPrivate then
		stars *= E.PRIVATE_SMALL_MULT
	end
	return { xp = math.floor(xp + 0.5), stars = math.floor(stars + 0.5) }
end

-- Anti-farm for PASS (F-CALL-02): pays only while under the per-round cap and only the first time a pair passes in
-- a crossing. `pairKey` identifies (giver, receiver, crossing); `paidPairs` is the round's set.
function Rewards.passPays(passesPaid: number, paidPairs: { [string]: boolean }, pairKey: string): boolean
	return passesPaid < E.PASS_PAID_PER_ROUND and not paidPairs[pairKey]
end

-- Squad bonus: +SQUAD_PER_FRIEND per friend in the server, capped.
function Rewards.squad(friends: number): number
	return math.min(E.SQUAD_CAP, math.max(0, friends) * E.SQUAD_PER_FRIEND)
end

-- A round's Stars: (callouts + round payouts × Hot Streak) × (1 + squad), capped by the balance rule. Hot Streak
-- multiplies only the round payouts (§15.1 "that round's payout"; DECISIONS D-ECO-02); squad + VIP cover it all.
function Rewards.roundStars(callouts: number, round: number, streakMult: number, squad: number): number
	return math.min(E.ROUND_STARS_CAP, math.floor((callouts + round * streakMult) * (1 + squad) + 0.5))
end

-- The round payout keys a participant earns at RESULTS.
-- outcome: "LastStand" | "Survivors" | "Bombers"; role: "Runner" | "Bomber"; firstWinToday: no win paid yet today.
function Rewards.roundKeys(outcome: string, won: boolean, isMvp: boolean, firstWinToday: boolean): { string }
	local keys = { "RoundComplete" }
	if won then
		if outcome == "LastStand" then
			table.insert(keys, "LastStandWin")
		elseif outcome == "Survivors" or outcome == "MegaSurvivors" then
			table.insert(keys, "SurvivorWin")
		else
			table.insert(keys, "BomberWin")
		end
		if firstWinToday then
			table.insert(keys, "FirstWinOfDay")
		end
	end
	if isMvp then
		table.insert(keys, "MVP")
	end
	return keys
end

return Rewards
