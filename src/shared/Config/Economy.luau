--!strict
-- XP, levels and Stars (GDD §11.1, §12, §13, §15.1, §15.3, §24.1). Every payout reads this table; RewardService does
-- the paying, Logic/Rewards + Logic/LevelCurve + Logic/HotStreak do the maths (with specs). [TUNE]
-- Implements: F-PROG-01..03, F-ECO-01..03, F-SOC-01, F-SOC-03, F-CALL-02 (numbers).

export type Reward = { xp: number, stars: number }

return {
	-- Stars here were tuned down ~0.35x from the GDD §11.1 / §12.1 tables so the P4 soak lands in 600–900 Stars/h
	-- (DECISIONS D-ECO-01); the XP values are the GDD's.
	-- Callouts (§11.1): keyed by the callout key. Chain pays `xp`/`stars` per link (n links); Revenge, DoubleBoom and
	-- TripleBoom are bonuses paid on top of the callout that fires with them.
	Callouts = {
		Tagged = { xp = 5, stars = 0 },
		Pass = { xp = 5, stars = 1 },
		CloseOne = { xp = 15, stars = 1 },
		Defused = { xp = 15, stars = 1 },
		ClutchDefuse = { xp = 40, stars = 3 },
		RevengePass = { xp = 20, stars = 2 },
		Revenge = { xp = 10, stars = 1 },
		Betrayal = { xp = 10, stars = 1 },
		Chain = { xp = 10, stars = 1 }, -- per link
		Boom = { xp = 20, stars = 1 },
		DoubleBoom = { xp = 25, stars = 2 },
		TripleBoom = { xp = 60, stars = 4 },
		Survived = { xp = 10, stars = 1 },
		AllClear = { xp = 5, stars = 0 },
		Dodge = { xp = 5, stars = 0 },
		LastStand = { xp = 30, stars = 2 },
	} :: { [string]: Reward },
	-- Round payouts (§12.1), paid at RESULTS.
	Rounds = {
		RoundComplete = { xp = 15, stars = 1 },
		SurvivorWin = { xp = 60, stars = 5 },
		LastStandWin = { xp = 150, stars = 20 },
		BomberWin = { xp = 40, stars = 3 },
		MVP = { xp = 30, stars = 4 },
		FirstWinOfDay = { xp = 100, stars = 25 },
	} :: { [string]: Reward },

	-- Anti-farm (F-CALL-02, F-SEC-05)
	PASS_PAID_PER_ROUND = 4, -- PASS rewards stop paying after this many in a round
	BOT_CREDIT_MULT = 0.5, -- TAGGED / PASS / BOOM credit on a bot pays half
	BOT_HALVED = { Tagged = true, Pass = true, Boom = true } :: { [string]: boolean },
	PRIVATE_SMALL_HUMANS = 4, -- private servers with fewer humans than this…
	PRIVATE_SMALL_MULT = 0.5, -- …pay callout Stars at this rate

	-- The balance rule (F-ECO-03): no single round pays more Stars than this (≈ 45 min of play).
	ROUND_STARS_CAP = 550,

	-- Levels (§12.2, §12.3)
	XP_BASE = 150, -- xpToNext(1)
	XP_STEP = 50, -- + per level
	XP_CAP = 2000, -- xpToNext never exceeds this
	LEVEL_STARS_BASE = 40, -- Stars at each level-up: BASE + PER × L …
	LEVEL_STARS_PER = 10,
	LEVEL_STARS_CAP = 300, -- … capped
	LEVEL_TRACK_EVERY = 5, -- a Level Track cosmetic every N levels (granted once the P5 catalogue exists)
	BADGE_EVERY = 10, -- the level badge frame changes every N levels
	BADGES = { "Bronze", "Silver", "Gold", "Platinum", "Obsidian" },

	-- Hot Streak (§15.1): +1 per round you win or reach this crossing; the Stars multiplier by streak.
	STREAK_CROSSING = 5,
	STREAK_MULT = { [2] = 1.25, [3] = 1.5, [4] = 2.0 } :: { [number]: number }, -- 4+ stays at the 4 value

	-- Squad bonus (§15.3): + per Roblox friend in the server, capped.
	SQUAD_PER_FRIEND = 0.10,
	SQUAD_CAP = 0.30,

	-- Group perk (F-SOC-05): one-time Stars for members of the game's group.
	GROUP_ID = 3774675,
	GROUP_STARS = 150,
}
