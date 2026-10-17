--!strict
-- Daily systems (GDD §14): quests, the login streak calendar and playtime gifts. Days are UTC (00:00 resets).
-- Logic/Quests and Logic/Daily do the maths (with specs); DailyService runs them. [TUNE]
-- Implements: F-DAILY-01..10 (numbers and pools).

export type Quest = {
	id: string,
	tier: string, -- "Easy" | "Medium" | "Hard"
	event: string, -- the progress event that counts (QuestService maps callouts / round results to these)
	target: number,
	requires: string?, -- a feature that must exist first ("Dodge", "Crown", "Mega"); filtered out until it ships
}

export type DayReward = { kind: string, amount: number? } -- kind: "Stars" | "SparkCrate" | "RareItem" | "StreakBomb"

return {
	SECONDS_PER_DAY = 86400,

	-- Quests (§14.1)
	QUESTS_PER_DAY = 3, -- one of each tier
	TIERS = { "Easy", "Medium", "Hard" },
	TIER_REWARD = {
		Easy = { xp = 60, stars = 40 },
		Medium = { xp = 100, stars = 70 },
		Hard = { xp = 160, stars = 120 },
	},
	FREE_REROLLS = 1,
	REROLL_COST = 50, -- Stars, after the free one
	-- event keys: Pass, Survive, Tag, Round, Dodge, CleanCrossing, Defuse, RevengePass, Boom, Reach4, BomberWin,
	-- Betrayal, Dethrone, Clutch, Win, Chain5, TripleBoom, LastStandReached, LastStandWin, MegaRound, MegaFeed
	Pool = {
		{ id = "E_Pass", tier = "Easy", event = "Pass", target = 10 },
		{ id = "E_Survive", tier = "Easy", event = "Survive", target = 8 },
		{ id = "E_Tag", tier = "Easy", event = "Tag", target = 8 },
		{ id = "E_Rounds", tier = "Easy", event = "Round", target = 5 },
		{ id = "E_Dodge", tier = "Easy", event = "Dodge", target = 5, requires = "Dodge" },
		{ id = "E_Clean", tier = "Easy", event = "CleanCrossing", target = 3 },
		{ id = "E_Mega", tier = "Easy", event = "MegaRound", target = 1, requires = "Mega" },
		{ id = "M_Defuse", tier = "Medium", event = "Defuse", target = 3 },
		{ id = "M_Revenge", tier = "Medium", event = "RevengePass", target = 3 },
		{ id = "M_Boom", tier = "Medium", event = "Boom", target = 5 },
		{ id = "M_Reach4", tier = "Medium", event = "Reach4", target = 3 },
		{ id = "M_BomberWin", tier = "Medium", event = "BomberWin", target = 2 },
		{ id = "M_Betrayal", tier = "Medium", event = "Betrayal", target = 2 },
		{ id = "M_Dethrone", tier = "Medium", event = "Dethrone", target = 1, requires = "Crown" },
		{ id = "H_Clutch", tier = "Hard", event = "Clutch", target = 2 },
		{ id = "H_Win", tier = "Hard", event = "Win", target = 1 },
		{ id = "H_Chain5", tier = "Hard", event = "Chain5", target = 1 },
		{ id = "H_Triple", tier = "Hard", event = "TripleBoom", target = 1 },
		{ id = "H_LastStand", tier = "Hard", event = "LastStandReached", target = 1 },
		{ id = "H_MegaFeed", tier = "Hard", event = "MegaFeed", target = 3, requires = "Mega" },
		{ id = "H_LastStandWin", tier = "Hard", event = "LastStandWin", target = 1 },
	} :: { Quest },
	-- Features that exist (quests needing anything else stay out of the draw).
	FEATURES = { Dodge = true, Crown = true, Mega = false } :: { [string]: boolean },

	-- Login streak (§14.2): day 1..7, then days 8+ repeat days 4..7.
	LOGIN = {
		{ kind = "Stars", amount = 100 },
		{ kind = "Stars", amount = 150 },
		{ kind = "SparkCrate" },
		{ kind = "Stars", amount = 250 },
		{ kind = "RareItem" },
		{ kind = "Stars", amount = 400 },
		{ kind = "StreakBomb" },
	} :: { DayReward },
	LOOP_FROM = 4, -- after day 7 the calendar loops back to this day
	STREAK_MISS_PENALTY = 2, -- a missed day drops the streak back this many days (never below day 1)

	-- Playtime gifts (§14.3): minutes played today (UTC) → reward. After the last, every REPEAT_EVERY minutes →
	-- REPEAT_STARS. Claiming is always a tap.
	GIFTS = {
		{ minutes = 5, kind = "Stars", amount = 40 },
		{ minutes = 15, kind = "Stars", amount = 100 },
		{ minutes = 30, kind = "SparkCrate" },
		{ minutes = 45, kind = "Stars", amount = 150 },
		{ minutes = 60, kind = "GiftBox" },
	},
	REPEAT_EVERY = 30,
	REPEAT_STARS = 100,
	PLAYTIME_TICK = 5, -- seconds between playtime accruals (AFK players don't accrue)
}
