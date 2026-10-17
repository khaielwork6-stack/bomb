--!strict
-- Round flow (GDD §5, §6, §8.2, Appendix A). Seconds unless noted. [TUNE]

return {
	INTERMISSION = 12,
	INTRO = 4,
	READY = 2,
	RESOLVE = 1.5,
	RESULTS = 8,
	MAX_CROSSINGS = 8, -- D6
	-- The Field Fuse per crossing (F-FUSE-01): it shortens as the Bomber crowd grows. Crossings past the list reuse
	-- its last value.
	FIELD_FUSE = { 20, 16, 13, 11, 10, 10, 10, 10 },
	-- The lengths above are for a FUSE_REF_LENGTH-stud field (the Fireworks Yard, Asset Bible §4.2); other maps scale them by
	-- their length so every map keeps the same pressure (the temporary 198-stud Meadow gets ≈1.4×).
	FUSE_REF_LENGTH = 140,
	FUSE_WARN = 5, -- F-FUSE-02: klaxon, glowing lanes, red HUD fuse
	FUSE_PULSE = 3, -- the glow pulses, the music drops to a heartbeat
	DETONATE_SWEEP = 0.6, -- F-FUSE-03: the rolling chain of blasts crosses the field over this long
	-- Last Stand (F-LAST-01..05)
	LAST_STAND_INTRO = 3,
	LAST_STAND_FUSE = 12,
	LAST_STAND_SPEED = 1.08, -- the adrenaline boost
	LAST_STAND_MIN_RUNNERS = 4, -- a round that started with fewer Runners has no Last Stand
	-- Starting Bombers (D4): clamp(floor(n / BOMBERS_PER), 1, BOMBERS_MAX)
	BOMBERS_PER = 8,
	BOMBERS_MAX = 3,
	BOMBER_REPEAT_GUARD = true, -- nobody starts as a Bomber two rounds in a row
	IDLE_WARN = 5, -- F-CROSS-01: a Runner still in the start strip this long after GO gets "MOVE!"
	MIN_PARTICIPANTS = 2, -- a round needs at least this many (bots fill from P2)
	BOOM_GETUP = 1.6, -- F-BOMB-06: ragdoll time before a boomed Runner gets up as a Bomber
}
