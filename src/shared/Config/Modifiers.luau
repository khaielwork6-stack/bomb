--!strict
-- Round modifiers (GDD §6.4). Every 3rd round bends one rule; times in seconds, distances in studs. [TUNE]
-- Implements: F-MOD-01..05 (numbers).

return {
	EVERY = 3, -- F-MOD-01: every EVERY-th non-MEGA round is a modifier round
	POOL = { "Face", "LightsOut", "Mole" },

	-- F-MOD-02 READ THE FACE: a LIT bomb shows no time; every fuse is random in [FUSE_MIN, FUSE_MAX] (average = the
	-- normal Config.Bomb.FUSE). The time shows from Config.Bomb.STAGE_HOT left, as always.
	FACE_FUSE_MIN = 3.0,
	FACE_FUSE_MAX = 5.0,

	-- F-MOD-03 LIGHTS OUT
	LAMP = { LIT = 16, HOT = 20, CRITICAL = 24 }, -- a live bomb's light range by stage
	LAMP_BRIGHTNESS = 2.4,
	RUNNER_GLOW = 6, -- every Runner's own soft light
	RUNNER_GLOW_BRIGHTNESS = 0.9,
	EYE_RANGE = 28, -- Bombers' red eye glints fade in inside this distance (and bot Runners see Bombers this far)
	STRIP_LIGHT_SPACING = 18, -- the Safe Strips' glow: a light every this many studs along each strip
	STRIP_LIGHT_RANGE = 18,
	STRIP_LIGHT_BRIGHTNESS = 0.8,
	NIGHT_TWEEN = 1.2,
	NIGHT = { -- the Lighting the Yard fades to (restored at the next intermission)
		ClockTime = 0.2,
		Brightness = 0.35,
		ExposureCompensation = -0.6,
		Ambient = Color3.fromRGB(26, 24, 40),
		OutdoorAmbient = Color3.fromRGB(46, 48, 78),
		FogEnd = 260,
		FogColor = Color3.fromRGB(14, 14, 26),
	},
	NIGHT_ATMOSPHERE = { -- the Yard's Atmosphere at night (it overrides fog while it exists)
		Density = 0.4,
		Color = Color3.fromRGB(22, 24, 44),
		Decay = Color3.fromRGB(10, 10, 22),
		Glare = 0,
		Haze = 0.4,
	},
	NIGHT_TINT = Color3.fromRGB(196, 206, 255), -- a cool moonlight grade over the scene
	NIGHT_SATURATION = -0.25,

	-- F-MOD-04 THE MOLE
	MOLE_MIN_RUNNERS = 4, -- starting Runners needed
	MOLE_MIN_ROUNDS = 5, -- a human is never the Mole in their first rounds ever
	STRIKE_TIME = 3, -- how long a STRIKE stays armed
	STRIKE_RETRY = 5, -- after a missed STRIKE
	MOLE_DEADLINE = 3, -- revealed at the end of this crossing if they haven't struck
	MOLE_REVEAL_LEFT = 1, -- …or once only this many other Runners are left
	-- a bot Mole strikes a Runner within BOT_STRIKE_RANGE on the field, some time after GO
	BOT_STRIKE_RANGE = 8,
	BOT_STRIKE_DELAY = { 2, 9 },
}
