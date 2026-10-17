--!strict
-- The bomb (GDD §7, the table in §7.8). Distances in studs, times in seconds. [TUNE]

return {
	FUSE = 4.0, -- D5: seconds on a fresh bomb
	STAGE_HOT = 2.5, -- remaining time at which LIT turns HOT
	STAGE_CRITICAL = 1.0, -- …and HOT turns CRITICAL
	TAG_RANGE = 4.5, -- root to root: a Bomber's reach
	PASS_RANGE = 4.0, -- root to root: body contact
	TAG_COOLDOWN = 1.5,
	NO_PASSBACK = 1.0, -- you can't pass straight back to whoever just gave it to you
	RECEIVE_GRACE = 0.2, -- a fresh Carrier can't pass in its first moments
	BOMBER_STUN = 3.0, -- a bomb that blows on a Bomber
	SPLASH_RADIUS = 7,
	SPLASH_PUSH = 14, -- studs of shove for bystanders
	SPLASH_TIME = 0.3,
	BOOM_IMPULSE_H = 70, -- studs/s fling
	BOOM_IMPULSE_V = 55,
	CLUTCH_WINDOW = 1.0, -- a defuse with this little left is a CLUTCH DEFUSE
	CLOSE_PASS_WINDOW = 1.0, -- a pass with this little left is a CLOSE ONE
	LAG_SLACK = 2.0, -- extra server tolerance on contact ranges (replication delay, GDD §24.1)
	VERTICAL_REACH = 5, -- contact needs the two roots within this height of each other
}
