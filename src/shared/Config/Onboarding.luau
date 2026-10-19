--!strict
-- The first sessions, introduced a little at a time (the owner, 2026-10-19: "too many systems"). Lifetime rounds
-- played (the profile's stats.rounds) unlock things; nothing for sale ever appears while a round is live. [TUNE]
-- Implements: F-ONB-01 (the first 5 minutes), DECISIONS 2026-10-19.

return {
	-- dock / side tiles: the round count after which each appears (0 = from the first join)
	UNLOCK_AFTER = {
		Shop = 1,
		Locker = 1,
		Emotes = 1,
		Taunt = 1,
		Quests = 2,
		Calendar = 2,
		Gift = 2,
	} :: { [string]: number },
	CALENDAR_AUTO_AFTER = 2, -- the daily calendar opens by itself once this many rounds are played (with its dock tile)
	PACK_FROM_ROUND = 3, -- the Bomber / Runner Pack card: from this round, in the lobby only, once per session
	REVIVE_FROM_ROUND = 4, -- the Revive offer: from this round
	REVIVE_PER_SESSION = 1, -- …and offered at most this often per session
	LEAD_FROM_ROUND = 4, -- the Lead Bomber chip in the lobby: from this round
}
