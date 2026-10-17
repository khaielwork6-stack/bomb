--!strict
-- Server-level rules. GDD §2, §5, Appendix A.

return {
	NAME = "TICK TAG",
	MAX_PLAYERS = 20, -- D2
	MIN_HUMANS_TO_START = 1,
	SHOW_BOT_TAG = false,
	-- Joining (Chase Game lesson): a player only counts for the round once their client says it's ready (or after
	-- CLIENT_READY_TIMEOUT), and someone who has just loaded gets at least JOIN_GRACE seconds before a round takes them.
	JOIN_GRACE = 6,
	CLIENT_READY_TIMEOUT = 30,
	KILL_PLANE_Y = -30,
}
