--!strict
-- Dash (0.30 s, non-looping, in place). Baked by tools/anim/bake.luau (splines + springs + per-frame grounding).
--
-- Angles are WORLD angles in degrees as you'd read them off the reference sheet:
--   pitch  torso lean forward (+)            squash extra body sink (studs) on top of the grounding solver
--   rArm / lArm  arm swing, forward (+) / back (−), measured from straight down;  *Out = outward spread
--   rLeg / lLeg  leg swing, forward (+) / back (−)
--   head   head tilt down (+) relative to the torso (negative = look up / forward while leaning)
--   roll   torso roll toward the right (+)        yaw  torso turn
-- Key flags: hit = impact / explosive change of direction, stop = starts or ends at rest.

return {
	name = "Dash",
	length = 0.30,
	looped = false,
	priority = "Action",
	keys = {
		-- Right (blue) leg is the push-off leg, left leads (reference sheet); arms swing opposite the legs on the way out.
		-- 1. Compress: coil low, torso forward, arms cocked back.
		{
			t = 0.00,
			stop = true,
			pitch = 30,
			rArm = -26,
			lArm = -32,
			rArmOut = 8,
			lArmOut = 8,
			rLeg = -24,
			lLeg = 28,
			head = -18,
			squash = 0.16,
		},
		-- 2. Explode: push off, both arms whip back, legs split.
		{
			t = 0.05,
			hit = true,
			pitch = 44,
			rArm = -88,
			lArm = -96,
			rArmOut = 14,
			lArmOut = 14,
			rLeg = -48,
			lLeg = 46,
			head = -26,
			roll = -4,
			yaw = 3,
			squash = 0.04,
		},
		-- 3. Burst extreme: fully stretched, arms trailing high, head driving forward.
		{
			t = 0.13,
			pitch = 50,
			rArm = -118,
			lArm = -126,
			rArmOut = 18,
			lArmOut = 18,
			rLeg = -62,
			lLeg = 56,
			head = -36,
			roll = -5,
			yaw = 4,
		},
		-- 4. Rise: torso comes up, right arm whips through forward as the right leg comes through.
		{
			t = 0.22,
			pitch = 26,
			rArm = 22,
			lArm = -52,
			rArmOut = 6,
			lArmOut = 8,
			rLeg = -36,
			lLeg = 28,
			head = -18,
			roll = -2,
			yaw = 1,
		},
		-- 5. Run handoff: sprint-ready pose.
		{ t = 0.30, pitch = 12, rArm = 32, lArm = -30, rLeg = -16, lLeg = 16, head = -6 },
	},
}
