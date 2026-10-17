--!strict
-- Locomotion and techniques. Transferred unchanged from Chase Game (TICK TAG GDD §9.1), Appendix A. [TUNE]

return {
	MAX_SPEED = 24,
	-- Setting off (2026-10-06 feel pass): the first step jumps straight to a jog (START_FRAC of max), then speed
	-- builds to full on an ease-out curve over ACCEL_TIME, so the last stretch of the sprint visibly "kicks in".
	ACCEL_TIME = 0.95,
	START_FRAC = 0.42,
	ACCEL_FLOOR = 0.22, -- min build-up rate near the top (fraction of max per second) so the ease always lands
	-- Letting go: plant and brake (exponential + a constant so it lands on zero: ≈0.3 s, ≈2.3 studs from full).
	-- Slippery effects (Ice, Marbles: decel multiplier < 1) keep the long linear coast below instead.
	STOP_TAU = 0.12,
	STOP_LINEAR = 16,
	DECEL_TIME = 0.40, -- linear coast (slippery effects) and settling back down after a boost
	TURN_RATE_LOW = 900, -- deg/s below LOW_SPEED_FRAC
	TURN_RATE_HIGH = 320, -- deg/s at max speed
	LOW_SPEED_FRAC = 0.3,
	REVERSAL_ANGLE = 120,
	REVERSAL_MIN_FRAC = 0.7,
	REVERSAL_PENALTY = 0.40,

	-- Omnimovement (2026-10-07, the competitor's feel, PC and mobile): while you move, the body faces the CAMERA
	-- and every direction is its own pace, so W runs, A / D strafe with the body still facing ahead, and S walks
	-- backward with momentum, its pace building quickly and smoothly (BACK_ACCEL) to BACK_SPEED_FRAC of the run.
	-- Turns curve round with momentum (TURN_RATE_* above); reversals follow the momentum timeline below.
	-- Standing still with the cursor locked, the body follows the camera too (FACE_CAMERA_IDLE). PoseController
	-- turns the legs toward the line of travel and leans the torso into a strafe (STRIDE_*), so a strafe runs
	-- instead of skating.
	FACE_RATE_LOW = 1440, -- deg/s the body turns to the camera, from a standstill / walk…
	FACE_RATE_HIGH = 900, -- …and at full speed (a fast camera flick shows the body catching up)
	SIDE_SPEED_FRAC = 0.85, -- strafe pace, of MAX_SPEED (diagonals ahead blend toward the full run)
	-- Backpedal (2026-10-08, the user's reference video: "the backwalk is fast and carries your running momentum"):
	-- a quick pace that builds smoothly from whatever speed you have (no slow first step, no restart).
	BACK_SPEED_FRAC = 0.92, -- backpedal top speed, of MAX_SPEED (≈22 studs/s; was 0.8)
	BACK_ACCEL = 100, -- studs/s²: 0 → full backpedal pace in ≈0.22 s, continuing from the current pace (was 45)
	BACK_ENTER = 0.4, -- input pointing back (of the facing) by more than this starts a backpedal…
	BACK_LEAVE = 0.2, -- …and below this it ends (hysteresis: no flicker on a diagonal)
	-- Momentum timeline (2026-10-08, the user: "momentum is not supposed to get killed unless you stop holding the
	-- keys for a while; left then right carries over to the next route; backwards kills it for a tiny fraction,
	-- then speeds up very fast"). Players only (bots keep the turn rules above):
	--   • letting go: the pace HOLDS for RELEASE_GRACE (losing RELEASE_COAST studs/s²), then the plant brake; so the
	--     gap between letting go of one key and pressing the next costs nothing;
	--   • a flip that isn't into a backpedal (A↔D, S→W, past REVERSAL_ANGLE): you go the new way at once with
	--     LATERAL_CARRY of your pace, then ease back up (no plant, no curve through the middle);
	--   • a flip INTO a backpedal (W→S, a strafe run → S): a short plant at BACK_PLANT_DECEL (≈0.1 s from a run, the
	--     Brake clip plays), then the backpedal builds at BACK_ACCEL;
	--   • a run turned into a strafe (slower pace) settles down at SETTLE_DECEL instead of dropping at once.
	RELEASE_GRACE = 0.14,
	RELEASE_COAST = 10,
	LATERAL_CARRY = 0.85,
	BACK_PLANT_DECEL = 220,
	SETTLE_DECEL = 14,
	STRIDE_HIP_MAX = 45, -- deg the legs turn toward the line of travel (a pure strafe runs on a 45° diagonal)
	STRIDE_LEAN = 7, -- deg the torso leans into a full-pace strafe
	STRIDE_SMOOTH = 14, -- 1/s easing of both

	-- Dash: a burst. Holds DASH_SPEED for DASH_HOLD, then glides back down to running speed by DASH_TIME.
	-- 2026-10-07 nerf (the user's call: too far): ≈14 studs in 0.34 s against ≈8 running, so it gains ≈5.5
	-- (was ≈9 — too strong; ≈2 before that — useless).
	DASH_SPEED = 48,
	DASH_TIME = 0.34,
	DASH_HOLD = 0.13,
	DASH_CD = 2.2,

	-- Hard stop (2026-10-07, much more aggressive): you plant on the spot (speed 0 at once, input ignored for
	-- HARDSTOP_TIME), then a JUKE_WINDOW in which the first direction you push snaps your heading and launches
	-- you out at JUKE_START × top speed: stop dead, cut away at full pace.
	HARDSTOP_MIN_FRAC = 0.2,
	HARDSTOP_TIME = 0.16,
	JUKE_WINDOW = 0.45,
	JUKE_START = 0.95,
	JUKE_ACCEL_MULT = 2.2,
	HARDSTOP_CD = 0.7,

	-- Slide: a real burst (SLIDE_MULT × current speed, at least SLIDE_MIN_FRAC × max) held SLIDE_HOLD, then a smooth
	-- glide down to SLIDE_MIN_FRAC × max: ≈22 % more ground than running for the same time.
	SLIDE_TIME = 0.65,
	SLIDE_HOLD = 0.15,
	SLIDE_MULT = 1.45,
	SLIDE_MIN_FRAC = 0.85,
	SLIDE_STEER = 45, -- deg/s
	SLIDE_CD = 2.5,

	LOBBY_SPEED = 20,
	BRAVE_BOOST_MULT = 1.15,
	BRAVE_BOOST_TIME = 4.0,

	-- Movement polish (2026-10-08, the user's movement spec) ───────────────────────────────────────────────────
	-- Simulation: MovementCore integrates in fixed sub-steps of at most SUBSTEP seconds, so a run, a stop, a dash and
	-- a slide cover the same ground at 30, 60, 120 and 144 FPS (before: a stop at 30 FPS was 28 % shorter).
	SUBSTEP = 1 / 240,
	-- Dash from a standstill (reverses 2026-10-06 "only while steering"): with no input the dash goes the way the
	-- body faces. false = a standing press does nothing again.
	DASH_FROM_STANDSTILL = true,
	-- Backward dash (S + dash): hop back still facing ahead, like the side dashes, instead of turning round.
	-- false = the old behaviour (a dash behind you turns the body and runs that way).
	DASH_BACK_KEEPS_FACING = true,
	-- Slopes (players): ground speed scales with the incline along the way you move:
	-- × (1 − sin(angle) × UPHILL_LOSS) uphill, × (1 + sin(angle) × DOWNHILL_GAIN) downhill.
	-- 30° uphill ≈ −15 %, 30° downhill ≈ +6 % (inside the validator's 15 % tolerance). 0 / 0 = flat feel everywhere.
	SLOPE_UPHILL_LOSS = 0.3,
	SLOPE_DOWNHILL_GAIN = 0.12,
	SLOPE_MIN_ANGLE = 4, -- deg: below this the ground counts as flat
	SLOPE_MAX_ANGLE = 50, -- deg: steeper is a wall, not a slope
	-- Reference match (the user's video, 2026-10-08): with the cursor locked (shift-lock style, live runs on PC) the
	-- body turns with the camera even standing still, so you always see the character's back. false = standing
	-- still keeps its facing (orbit the camera round the character).
	FACE_CAMERA_IDLE = true,
	-- Head look (reference video): the head turns toward where the camera looks, on top of the body's facing.
	-- Other players see it too (the client sends its look HEAD_SEND_HZ times a second).
	HEAD_LOOK = true,
	HEAD_YAW_MAX = 70, -- deg left / right of the body
	HEAD_PITCH_UP = 30, -- deg
	HEAD_PITCH_DOWN = 35, -- deg
	HEAD_SMOOTH = 10, -- 1/s easing
	HEAD_SEND_HZ = 10,
	-- Landing: a fall at least this long (s) plays the landing pose and dust.
	LAND_MIN_AIR = 0.35,
	-- Role profiles: multipliers on the values above, per role ("Lobby" = no role). 1 everywhere = the tuning as it
	-- was before profiles existed (catchers are still slowed by their tier handicap, Config.Tiers, and use the dive,
	-- not the dash). speed scales max speed (the server validator applies it too), accel / decel / turn / dash scale
	-- acceleration, braking, turn rates and dash speed.
	Profiles = {
		Runner = { speed = 1, accel = 1, decel = 1, turn = 1, dash = 1 },
		Bomber = { speed = 1, accel = 1, decel = 1, turn = 1, dash = 1 }, -- GDD §9.3 [TUNE]
		Lobby = { speed = 1, accel = 1, decel = 1, turn = 1, dash = 1 },
	},

	-- Dive (kept from Chase Game's MovementCore; TICK TAG's Bombers don't dive, GDD §9.3) and the giant stride the
	-- Locomotion "Titan" variant uses (the MEGA BOMBER in P6, GDD §16).
	DIVE_DIST = 14,
	DIVE_TIME = 0.35,
	DIVE_RECOVERY = 0.6,
	DIVE_RECOVERY_SPEED = 0.5,
	DIVE_CD = 2.5,
	GIANT_STRIDE = 13,

	-- Position history (PositionHistory: lag-tolerant contact checks, GDD §24.1, and the moment replay §10.5).
	HISTORY_HZ = 30,
	HISTORY_SECONDS = 6.5,

	-- Server movement validation (GDD §24.1)
	VALIDATE_INTERVAL = 0.25,
	VALIDATE_TOLERANCE = 1.15,
	VALIDATE_SLACK = 2,
	VALIDATE_STRIKES = 3,
	VALIDATE_STRIKE_WINDOW = 2,
	VALIDATE_KICK_STRIKES = 10,
}
