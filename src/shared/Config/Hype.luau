--!strict
-- The hype layer (docs/VIDEO2_NOTES.md §4, §6; the reference video's juke and takedown moments): how loud and bright the
-- juke burst is, how a streak builds it up, and how a paid callout's tag and stars fly. [TUNE]

return {
	-- the juke (our Dodge callout): a gold screen-edge flash, speed lines, a crowd roar, yellow bolts on the floor
	STREAK_WINDOW = 6, -- seconds: jukes this close together build a streak
	STREAK_MAX = 4, -- the streak stops growing the effect here
	FLASH_T = 0.12, -- the gold edge's transparency at the peak (lower = stronger)
	FLASH_TIME = 0.55,
	TINT_T = 0.86, -- the whole-screen gold wash at the peak
	SPEED_LINES = 16,
	CHEER_VOLUME = 0.7, -- the crowd roar, ×(1 + streak × CHEER_STREAK)
	CHEER_STREAK = 0.2,
	PUNCH_FROM_STREAK = 2, -- the camera kicks from the second juke in a streak
	PUNCH_FOV = 4,
	BOLTS = 3, -- yellow zigzags splashing across the floor
	BOLT_SIZE = Vector2.new(9, 4.5), -- studs (length along the run × width)
	BOLT_SPREAD = 38, -- degrees either side of the run
	BOLT_AHEAD = 3.5, -- studs in front of you they start
	BOLT_TIME = 0.75,

	-- paid callouts: the "+N Word!" tag by your body and the stars that fly from it into the counter
	TAG_RISE = 34, -- pixels the body tag floats up
	TAG_TIME = 1.2,
	STAR_FLY_MAX = 8, -- at most this many little stars per reward
	COMBO_WINDOW = 4, -- seconds: paid callouts this close together count as a combo (×2, ×3…)
}
