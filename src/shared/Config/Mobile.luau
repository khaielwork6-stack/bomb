--!strict
-- The phone layout (GDD §21.2, Asset Bible §6.6): the action buttons bottom-right where the thumb rests. Sizes are in
-- GUI pixels at a 720 px tall screen (scaled with the screen between SCALE_MIN and SCALE_MAX).

return {
	DASH_SIZE = 110, -- the big one, under the thumb
	SMALL_SIZE = 78, -- SLIDE and STOP, in an arc round DASH
	ARC_RADIUS = 104, -- from DASH's centre to the small buttons' centres
	ARC_ANGLES = { 182, 112 }, -- degrees, 0 = right, counter-clockwise (up): SLIDE to the left, STOP above-left
	MARGIN_RIGHT = 34,
	MARGIN_BOTTOM = 38,
	REF_HEIGHT = 720,
	SCALE_MIN = 0.78,
	SCALE_MAX = 1.25,
	RING_WIDTH = 6, -- the cooldown drain ring, px
	PRESS_SCALE = 0.9,
}
