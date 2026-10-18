--!strict
-- The MEGA BOMB event (GDD §16, F-MEGA-01..08). Seconds and studs. [TUNE]

return {
	SLOT_MINUTES = 15, -- F-MEGA-01: every 15 minutes on the UTC wall clock (:00 :15 :30 :45)
	HUMAN_WEIGHT = 3, -- F-MEGA-02: humans are this many times likelier than bots to be the giant
	GIANT_SCALE = 3, -- the MEGA BOMBER is a 3× giant
	GIANT_SPEED = 0.9, -- of normal run speed (a giant covers ground with its stride, not its pace)
	REACH = 4.5, -- studs added to the giant's tag reach and to the pass range of anyone feeding it
	TAG_FUSE = 3.0, -- F-MEGA-03: the giant's touch sticks a shorter bomb
	STOMP_RADIUS = 12, -- F-MEGA-04: the Mega's Dash is a ground slam…
	STOMP_TELEGRAPH = 0.6, -- …telegraphed by a ring for this long…
	STOMP_COOLDOWN = 6,
	STOMP_PUSH = 16, -- …that flings Runners (no bomb, no elimination)
	FUSE = 90, -- F-MEGA-05: the giant bomb's fuse (the event clock), from the first GO
	FEED_STAGGER = 1.5, -- F-MEGA-06: a bomb passed onto the giant staggers it…
	FEED_BURN = 6, -- …and burns this much off the Mega Fuse
	REWARD_MULT = 3, -- F-MEGA-08: winners' round Stars (still capped by F-ECO-03)
	REWARD_CRATE = "Spark", -- a free crate for the Runners who win
	TITLE_SURVIVOR = "Title_MegaSurvivor",
	TITLE_GIANT = "Title_MegaBomber",
}
