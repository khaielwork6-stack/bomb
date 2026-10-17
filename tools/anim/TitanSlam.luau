--!strict
-- TitanSlam (2.1 s, Action). TITAN HUNT boss attack: the ground slam that ends in the vulnerable kneel.
-- 0.00–0.55 wind-up: the hammer arm sweeps up and OUT (a loop, never a dead stop) until the hammer is overhead and
--           behind, the torso leans back and turns the right shoulder away, the free arm reaches out ahead for
--           balance, the left foot lifts for the step.
-- 0.55–0.72 the hang: a heavy pause at the top (the slam telegraph players read).
-- 0.72–0.98 the strike: the hammer whips down as the left foot stomps forward; IMPACT on the floor at 0.98 s
--           (gameplay: shockwave + camera shake on that frame).
-- 0.98–1.30 the body crashes down onto the blow, compresses, bounces once.
-- 1.30–2.10 it sinks to one knee, the hammer stuck in the floor: ends in TitanKneel's pose (the weak spot low).
-- Every part on its own timing (bake.luau `tracks`): torso first, arm after, head last.
-- Checked with scratchpad titanprobe.luau: hammer head never through the floor, touches at 0.98 s.

local LENGTH = 2.1
local IMPACT = 0.98

return {
	name = "TitanSlam",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = {
		rArmOut = { 8, 0.8 },
		lArm = { 4, 0.6 },
		lArmOut = { 4, 0.65 },
		rLeg = { 9, 0.85 },
		lLeg = { 9, 0.85 },
		head = { 5, 0.6 },
		pitch = { 11, 0.75 },
	},
	-- The hammer arm is exact (no spring, no drag): the head has to meet the floor ON the impact frame and then stay
	-- planted (after IMPACT its angle is solved per frame by titansolve.luau as the body sinks into the kneel).
	noSpring = { rArm = true },
	lag = { rArm = 0, rArmOut = 0.02, head = 0.07, headYaw = 0.09, lArm = 0.06 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Hammer arm: up and out → overhead behind → whip down → impact → holds the stuck hammer as the body kneels
		rArm = {
			{ 0, 1 },
			{ 0.3, 112 },
			{ 0.55, 204 },
			{ 0.72, 212 },
			{ 0.86, 120 },
			{ IMPACT, 7.5, "hit" },
			-- planted: solved so the head stays on the floor as the body crashes down and sinks into the kneel
			{ 1.06, 10.9 },
			{ 1.14, 9.7 },
			{ 1.22, 5.8 },
			{ 1.30, 4.6 },
			{ 1.38, 4.5 },
			{ 1.46, 6.2 },
			{ 1.54, 9.8 },
			{ 1.62, 14.2 },
			{ 1.70, 17.9 },
			{ 1.78, 21.7 },
			{ 1.86, 25.3 },
			{ 1.94, 27.5 },
			{ 2.02, 28.5 },
			{ LENGTH, 28.8 },
		},
		rArmOut = { { 0, 6 }, { 0.3, 24 }, { 0.55, 12 }, { 0.72, 10 }, { IMPACT, 8 }, { 1.4, 10 }, { LENGTH, 10 } },
		rArmTwist = { { 0, 0 }, { 0.3, -8 }, { 0.6, -10 }, { IMPACT, 4 }, { LENGTH, 2 } },
		-- Torso: lean back + twist away, then crash forward onto the blow, compress, then fold down into the kneel
		pitch = {
			{ 0, 7 },
			{ 0.35, -6 },
			{ 0.6, -12 },
			{ 0.72, -12 },
			{ 0.9, 22 },
			{ 1.06, 38, "hit" },
			{ 1.22, 33 },
			{ 1.5, 36 },
			{ 1.9, 32 },
			{ LENGTH, 32 },
		},
		yaw = { { 0, 0 }, { 0.4, -12 }, { 0.68, -15 }, { 0.96, 10 }, { 1.2, 7 }, { 1.7, 3 }, { LENGTH, 3 } },
		roll = { { 0, 0 }, { 0.4, -4 }, { 0.7, -5 }, { 0.98, 3 }, { 1.3, 1 }, { LENGTH, 1 } },
		squash = {
			{ 0, 0.045 },
			{ 0.45, 0.02 },
			{ 0.75, 0.02 },
			{ 1.02, 0.18 },
			{ 1.1, 0.24 },
			{ 1.24, 0.12 },
			{ 1.6, 0.06 },
			{ LENGTH, 0.05 },
		},
		-- Legs: left foot lifts in the wind-up, stomps forward with the strike, then the right knee goes down
		lLeg = {
			{ 0, -5 },
			{ 0.25, 12 },
			{ 0.55, 40 },
			{ 0.72, 42 },
			{ 0.95, 30, "hit" },
			{ 1.3, 34 },
			{ 1.62, 62 },
			{ 1.9, 77 },
			{ LENGTH, 78 },
		},
		rLeg = { { 0, 5 }, { 0.5, 2 }, { 0.95, -6 }, { 1.3, -14 }, { 1.62, -58 }, { 1.9, -80 }, { LENGTH, -82 } },
		lLegOut = { { 0, 7 }, { 0.6, 9 }, { 1.0, 10 }, { 1.6, 15 }, { LENGTH, 18 } },
		rLegOut = { { 0, 7 }, { 1.0, 9 }, { 1.6, 12 }, { LENGTH, 14 } },
		rLegTwist = { { 0, 6 }, { 1.0, 4 }, { LENGTH, 2 } },
		lLegTwist = { { 0, -6 }, { 1.0, -8 }, { LENGTH, -6 } },
		-- Free arm: reaches ahead for balance in the wind-up, yanks back on the strike, then braces on the front knee
		lArm = { { 0, 5 }, { 0.4, 44 }, { 0.7, 48 }, { 0.98, -12 }, { 1.25, 8 }, { 1.7, 30 }, { LENGTH, 32 } },
		lArmOut = { { 0, 13 }, { 0.4, 28 }, { 0.7, 32 }, { 1.0, 22 }, { 1.6, 10 }, { LENGTH, 8 } },
		lArmTwist = { { 0, -4 }, { 0.6, 6 }, { 1.2, 0 }, { LENGTH, -2 } },
		-- Head: eyes on the target through the wind-up, snaps down with the blow, then hangs over the stuck hammer
		head = { { 0, -2 }, { 0.6, 8 }, { 0.72, 9 }, { 1.0, -2 }, { 1.2, 10 }, { 1.7, 12 }, { LENGTH, 12 } },
		headYaw = { { 0, 0 }, { 0.6, 12 }, { 1.0, -6 }, { 1.5, -2 }, { LENGTH, 0 } },
	},
}
