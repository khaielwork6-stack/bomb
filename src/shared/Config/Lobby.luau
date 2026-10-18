--!strict
-- The lobby "The Depot" (GDD §19, Asset Bible §4.3). Seconds and studs. [TUNE]

return {
	BOARD_REFRESH = 90, -- seconds between leaderboard reads for the wall
	BOARD_ROWS = 8,
	STATUES = 3, -- the weekly Wins champions on the plinths
	-- The Fuse Range (practice, local to each player; no rewards, so it never needs the server)
	PRACTICE_FUSE = 4.0, -- a practice bomb's fuse (the real one: Config.Bomb.FUSE)
	PRACTICE_REACH = 4.5, -- bump a dummy this close to pass to it
	PRACTICE_REGRAB = 0.5, -- a dummy that just handed it to you can't take it straight back
	DUMMY_HOLD = { 0.6, 1.2 }, -- seconds a dummy holds the bomb before handing it back…
	DUMMY_RETURN = 14, -- …if you're this close (otherwise it holds on and booms)
	DEFUSE_RADIUS = 3.2, -- the defuse pad's reach (flat)
	FIREWORK_COOLDOWN = 10, -- the VIP firework button, server-wide
	FADE = 0.35, -- the flash that hides the teleport into a round
}
