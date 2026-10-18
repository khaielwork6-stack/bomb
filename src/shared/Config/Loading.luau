--!strict
-- The loading screen's lobby flyover (GDD §20 F-ONB-01; the owner, 2026-10-18: "a very nice camera showing the
-- lobby, just like the video"). Once the Depot has streamed in, the 2D sky fades away and a slow drone orbit
-- circles the clock tower behind the logo until PLAY. Studs, seconds and radians. [TUNE]

return {
	LOBBY_WAIT = 10, -- seconds to wait for the lobby (persistent-streamed) before keeping the 2D sky
	SKY_FADE = 1.4, -- the 2D sky's fade once the flyover starts
	ORBIT_SPEED = 0.07, -- radians / s (about 90 s a lap)
	ORBIT_START = 0, -- radians: 0 = in front of the spawn, looking at the tower
	RADIUS = 66, -- from the tower, out over the sea
	RADIUS_SWAY = 6, -- the drone drifts in and out…
	RADIUS_SWAY_SPEED = 0.13,
	HEIGHT = 27, -- …and up and down, above the deck
	HEIGHT_SWAY = 5,
	HEIGHT_SWAY_SPEED = 0.09,
	LOOK_UP = 1, -- the aim point above the deck at the tower
	FOV = 48,
	-- soft depth of field: the deck sharp, the sea and sky beyond gently soft
	DOF_FAR = 0.25,
	DOF_FOCUS_RADIUS = 40,
	SHADE = 0.3, -- the dark gradient under the PLAY button (0 = black, 1 = none), so it reads on any shot
}
