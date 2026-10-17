--!strict
-- Impact & punctuation (GDD §10.3, §10.4 F-FEEL-04): the hit-stop, the pass flight, the impact freeze and the
-- presentation slow-mo. Times in seconds, distances in studs. [TUNE]

return {
	-- Tag / pass (§10.3): both rigs freeze for HITSTOP; the bomb pops on landing; your own camera kicks.
	HITSTOP = 0.06,
	HITSTOP_RANGE = 80, -- only rigs this close to the camera freeze (no point animating what nobody sees)
	LAND_POP = 1.18, -- the bomb's scale at the top of its landing pop…
	LAND_POP_TIME = 0.16, -- …and how long the pop takes to settle
	KICK_SHAKE = 0.22, -- camera trauma when a bomb lands on you / leaves you
	KICK_FOV = 3, -- degrees of FOV punch when a bomb lands on you

	-- The pass flight (§7.4, §10.3): the real bomb (the giver's skin) flies back to back with a motion trail.
	PASS_TIME = 0.18,
	PASS_ARC = 2, -- studs of lift at the middle of the arc
	PASS_SPINS = 1.5, -- full turns in flight

	-- Boom on you (§10.3): the camera holds while the explosion expands, then a whoosh as you fly.
	IMPACT_FREEZE = 0.35,

	-- Presentation slow-mo (F-FEEL-04): the local camera, VFX and audio run slow; gameplay never pauses.
	SLOWMO_TIME = 0.5,
	SLOWMO_SCALE = 0.3,
	SLOWMO_COOLDOWN = 4, -- at most once per this many seconds per client
	SLOWMO_PASS_LEFT = 0.5, -- a pass with this little fuse left earns it
	SLOWMO_RANGE = 45, -- only moments this close to the camera (or your own)
	SLOWMO_FOV = -6, -- the camera leans in
}
