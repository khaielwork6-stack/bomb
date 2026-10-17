--!strict
-- Arena rules shared by all maps. GDD §11. Per-map data lives in Config/Maps.

return {
	BLOCKS_MIN = 3,
	BLOCKS_MAX = 5,
	BLOCK_SIZE = Vector3.new(10, 6, 10),
	BLOCK_MOVE_TIME = 1.2,
	BLOCK_TELEGRAPH = 0.5,
	BLOCK_BFS_COLS = 12,
	BLOCK_BFS_ROWS = 8,
	BLOCK_BFS_MARGIN = 2,
	BLOCK_RETRIES = 20,

	SHRINK_START = 4,
	SHRINK_STEP = 0.04,
	SHRINK_MIN = 0.70,
	SHRINK_TIME = 1.0,

	STARS_MIN = 6,
	STARS_MAX = 10,
	STAR_SPACING = 6,
	STAR_PICKUP_RADIUS = 3,
	STAR_LENGTH_FRAC = 0.8,
	STAR_TABLE = {
		{ value = 1, weight = 80, kind = "Common" },
		{ value = 3, weight = 17, kind = "Rare" },
		{ value = 5, weight = 3, kind = "Super" },
	},

	CATCHER_BAND_FRAC = 0.15,
	CATCHER_MIN_SPACING = 6,
	SPAWN_JITTER = 1,
	-- The match arena sits this much below the lobby (2026-10-06) so the lobby looks down onto the field. Applied at
	-- runtime when a map loads (the partner's map models are never edited); the sea foam ring stays at sea level.
	DROP = 6,
}
