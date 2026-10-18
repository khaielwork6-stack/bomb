--!strict
-- The bomb (GDD §7, the table in §7.8). Distances in studs, times in seconds. [TUNE]

return {
	FUSE = 4.0, -- D5: seconds on a fresh bomb
	STAGE_HOT = 2.5, -- remaining time at which LIT turns HOT
	STAGE_CRITICAL = 1.0, -- …and HOT turns CRITICAL
	TAG_RANGE = 3.5, -- root to root: a Bomber's reach (D-FEEL-01: 4.5 + the lag slack tagged from 6.5 studs)
	PASS_RANGE = 4.0, -- root to root: body contact (the LIT reach)
	-- The Hand-Off (GDD §7.4b). F-BOMB-11 the Danger Ring: the pass reach grows as the fuse burns (the ring shows it).
	PASS_RANGE_STAGE = { LIT = 4.0, HOT = 4.75, CRITICAL = 5.5 },
	-- F-BOMB-12 the Lunge: during a Carrier's dash, bodies within LUNGE_CONE° of the dash direction are in reach
	-- LUNGE_REACH further; a pass made lunging is a SLAM PASS (the receiver knocked SLAM_KNOCK studs). Lunging at
	-- someone (in the cone within reach + WHIFF_AIM when the dash started) and missing stumbles you.
	LUNGE_REACH = 2.5,
	LUNGE_CONE = 60,
	SLAM_KNOCK = 5,
	WHIFF_AIM = 3,
	WHIFF_TIME = 0.35,
	WHIFF_SPEED = 0.6,
	-- F-BOMB-13 the Reject: a Hard Stop within REJECT_WINDOW before the bomb reaches you bounces it back; the giver
	-- is staggered (REJECT_SPEED for REJECT_STAGGER s, knocked REJECT_KNOCK studs). One per bomb per player.
	REJECT_WINDOW = 0.25,
	REJECT_COOLDOWN = 4,
	REJECT_STAGGER = 0.4,
	REJECT_SPEED = 0.5,
	REJECT_KNOCK = 4,
	TAG_COOLDOWN = 1.5,
	-- The slap (F-BOMB-10): the tagged Runner stumbles forward, away from the Bomber; a pass bumps both bodies apart.
	TAG_SHOVE = 6, -- studs
	TAG_SHOVE_TIME = 0.25,
	PASS_BUMP = 3, -- studs each
	PASS_BUMP_TIME = 0.2,
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
	-- DODGE! (GDD §11.1): a ready Bomber closing fast comes within DODGE_MARGIN of its reach, and the Runner gets
	-- clear (DODGE_CLEAR beyond the reach) untagged within DODGE_WINDOW. One per Runner per DODGE_COOLDOWN.
	DODGE_MARGIN = 1.0,
	DODGE_CLEAR = 2.5,
	DODGE_WINDOW = 1.2,
	DODGE_CLOSING = 6, -- studs/s toward the Runner
	DODGE_COOLDOWN = 3,
}
