--!strict
-- Arena rules shared by all maps (GDD §6, §23.1: transferred from Chase Game). Per-map data lives in Config/Maps.

return {
	-- Bombers' starting band across the middle of the field (GDD §5.2 READY).
	BOMBER_BAND_FRAC = 0.15,
	BOMBER_MIN_SPACING = 6,
	SPAWN_JITTER = 1,
	-- Narrow-field variant for tiny rounds (GDD §5.4); unused at launch, kept for Arena.setWidthScale.
	SHRINK_MIN = 0.70,
	SHRINK_TIME = 1.0,
	-- Maps sit this much lower than built (Chase Game's lobby looked down onto the field). [TUNE]
	DROP = 6,
}
