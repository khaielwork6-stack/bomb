--!strict
-- Round flow (GDD §5, §6, §8.2, Appendix A). Seconds unless noted. [TUNE]

return {
	INTERMISSION = 12,
	INTRO = 8, -- the owner, 2026-10-18: room for the full pick camera (was 4)
	REVIVE_GRACE = 8, -- seconds after a boom when a bought Revive still turns the new Bomber back into a Runner
	READY = 2,
	READY_LATER = 1.5, -- from crossing 2 the countdown is "2, 1, GO" (§5.2; D-PACE-02)
	RESOLVE = 1.5, -- after a field detonation (its sweep and booms need the time)
	RESOLVE_QUICK = 0.8, -- after a crossing that ended clear or wiped: nothing to show, straight on (D-PACE-02)
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
	-- The hurry-up (D-PACE-01): once this share of the Runners still in play is safe — or only idlers are left in the
	-- start strip — the Field Fuse cuts to its last HURRY_LEFT seconds, so the safe ones never stand around waiting.
	HURRY_SHARE = 0.5,
	HURRY_LEFT = 4,
	MIN_PARTICIPANTS = 2, -- a round needs at least this many (bots fill from P2)
	BOOM_GETUP = 1.6, -- F-BOMB-06: ragdoll time before a boomed Runner gets up as a Bomber
}
