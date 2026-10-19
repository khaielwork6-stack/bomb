--!strict
-- THROW MODE (GDD §7.4c, D-THROW-01, the owner's call "bomb is a ball"): the bomb is thrown, not bumped. Hold to wind
-- up, aim with the camera, let go; it flies on a real arc, bounces, and sticks to whoever it hits. Distances in studs,
-- times in seconds, speeds in studs/s. [TUNE]

return {
	ENABLED = true, -- the prototype switch (GameState.ThrowMode; Studio / admins: `throwmode on|off` live)

	-- Charging (F-THROW-01)
	CHARGE_TIME = 0.55, -- hold this long for full power
	TAP_TIME = 0.12, -- a release quicker than this is a tap…
	TAP_POWER = 0.45, -- …thrown at this power
	COOLDOWN = 0.35, -- between two throws by one player

	-- The flight (F-THROW-02): power 0..1 scales the speed along the aim and the lift
	SPEED_MIN = 42,
	SPEED_MAX = 88,
	LIFT_MIN = 14,
	LIFT_MAX = 24,
	GRAVITY = 110, -- heavier than the world's, so arcs read snappy
	INHERIT = 0.5, -- of the thrower's own velocity
	RELEASE_UP = 1.6, -- the release point above the root…
	RELEASE_FORWARD = 1.5, -- …and in front of it
	RADIUS = 0.9, -- the bomb, for bounces
	RESTITUTION = 0.45, -- of the speed into a surface
	FRICTION = 0.75, -- of the speed along it, per bounce
	REST_SPEED = 9, -- slower than this after a bounce: it has landed
	MAX_BOUNCES = 3,
	MAX_FLIGHT = 1.6,

	-- Hits (F-THROW-03): the body is a vertical axis from BODY_LOW under the root to BODY_HIGH over it
	HIT_RADIUS = 2.0,
	BODY_LOW = 2.6,
	BODY_HIGH = 1.8,
	SLIDE_HIGH = -0.8, -- a sliding body's top: a flat throw sails over it (F-THROW-05)
	OWNER_GRACE = 0.25, -- the thrower can't be hit by their own throw for this long
	KNOCK = 6, -- studs the receiver is sent along the throw at full speed (scaled by the hit speed)

	-- A miss (F-THROW-04): the bomb is still on your fuse cord, so it's yanked back to you
	RETURN_TIME = 0.28,
	MISS_SLOW = 0.6, -- speed multiplier while you reel it in…
	MISS_SLOW_TIME = 0.3,
	DODGE_NEAR = 2.0, -- a throw that passes this much beyond HIT_RADIUS without hitting someone is their DODGE!

	-- Parry (F-THROW-06): a Hard Stop within Bomb.REJECT_WINDOW of the hit bats it away
	PARRY_SPEED = 70,
	PARRY_LIFT = 16,

	-- Aim (F-THROW-07): the aim bends toward a target inside this cone (degrees), by device; preview arc
	ASSIST_CONE = { KeyboardMouse = 8, Gamepad = 16, Touch = 28 },
	MAX_RANGE = 55,
	PREVIEW_DOTS = 22,
	PREVIEW_TIME = 1.1,

	-- Bots (F-THROW-08)
	BOT_RANGE = 34, -- throw at targets within this
	BOT_REACT = { 0.35, 0.9 }, -- seconds between throw decisions (÷ the tier's pace)
	BOT_AIM_ERROR = 14, -- degrees of aim error for the weakest tier (Pro ≈ a quarter of it)
	BOT_DODGE_LOOK = 0.45, -- a throw that will reach a bot within this many seconds…
	BOT_DODGE_MISS = 3.0, -- …and pass this close is dodged
}
