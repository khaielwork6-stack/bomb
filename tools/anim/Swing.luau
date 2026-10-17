--!strict
-- Swing (0.48 s, non-looping, UPPER BODY, Action priority). The catcher's strike (PoseController "SwingStrike"):
-- the legs keep running underneath (the clip writes only the torso's turn, the head and the arms).
-- Gameplay (Config.Combat): wind-up 0.08 s, hit window 0.08–0.20 s, recovery to 0.45 s. The weapon is held pointing
-- forward out of the fist (a knife flat, a hammer head-up), so the arm's angle aims it: overhead it points back,
-- at the horizontal it points down onto the target.
-- A quick looping load (the arm goes up and out, back in over the head; the torso leans back and turns the right
-- shoulder away, the left arm reaches out front to aim) → overhead ≈0.10 s → whip down through the target (contact
-- ≈0.15 s) → follow-through past the hip → recover into the run.
-- v2 (2026-10-08, "more flowy"): every part on its own timing (bake.luau `tracks`), the strike rolling through the
-- body like a whip: the torso winds up and unwinds a beat AHEAD of the weapon arm (it drives the strike), the free
-- arm pulls back a beat after it, the head keeps the eyes on the target; the weapon arm swings through and
-- rebounds softly instead of stopping dead at the hip. Weapon-arm timing unchanged from v1.
-- Baked by bake.luau (parts = head + arms, noDrop: the body's height and lean stay the locomotion's).

local LENGTH = 0.48

return {
	name = "Swing",
	length = LENGTH,
	looped = false,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	-- The weapon arm LEADS (no drag) on a stiff spring: it has to be overhead by ≈0.1 s and through the target inside
	-- the hit window. The free arm and the head trail as usual.
	springs = { rArm = { 14, 0.75 }, rArmOut = { 12, 0.72 }, lArm = { 8, 0.6 } },
	lag = { rArm = 0, rArmOut = 0, rArmTwist = 0.01 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Weapon arm: up and out, in over the head, down through the target, past the hip, a soft rebound.
		rArm = {
			{ 0, 12 },
			{ 0.05, 92 },
			{ 0.09, 150 },
			{ 0.15, 72 },
			{ 0.205, 6 },
			{ 0.29, 16 },
			{ 0.38, 11 },
			{ LENGTH, 10 },
		},
		rArmOut = { { 0, 6 }, { 0.05, 34 }, { 0.09, 16 }, { 0.15, 3 }, { 0.21, 10 }, { 0.32, 8 }, { LENGTH, 6 } },
		rArmTwist = { { 0, 0 }, { 0.05, -4 }, { 0.09, -6 }, { 0.15, 4 }, { 0.21, 8 }, { 0.34, 3 }, { LENGTH, 0 } },
		-- Torso: winds up and unwinds ahead of the arm (it drives the strike), settles after.
		yaw = { { 0, 0 }, { 0.075, -10 }, { 0.13, 0 }, { 0.19, 12 }, { 0.3, 8 }, { LENGTH, 0 } },
		pitch = { { 0, 0 }, { 0.075, -4 }, { 0.13, 2 }, { 0.19, 8 }, { 0.3, 4 }, { LENGTH, 0 } },
		roll = { { 0, 0 }, { 0.08, 1.5 }, { 0.2, -2 }, { 0.34, -0.5 }, { LENGTH, 0 } },
		-- Free arm: reaches out front to aim during the load, pulls back a beat after the strike to counter the turn.
		lArm = { { 0, 6 }, { 0.04, 26 }, { 0.085, 46 }, { 0.15, 10 }, { 0.22, -22 }, { 0.33, -6 }, { LENGTH, 4 } },
		lArmOut = { { 0, 6 }, { 0.07, 12 }, { 0.15, 16 }, { 0.22, 14 }, { 0.34, 9 }, { LENGTH, 6 } },
		lArmTwist = { { 0, 0 }, { 0.08, 8 }, { 0.16, 4 }, { 0.3, 0 }, { LENGTH, 0 } },
		-- Head: chin up on the load, down onto the target through the strike, eyes on it all the way.
		head = { { 0, 0 }, { 0.08, -5 }, { 0.16, 6 }, { 0.22, 8 }, { 0.33, 3 }, { LENGTH, 0 } },
		headYaw = { { 0, 0 }, { 0.08, 10 }, { 0.15, -2 }, { 0.22, -9 }, { 0.33, -3 }, { LENGTH, 0 } },
	},
}
