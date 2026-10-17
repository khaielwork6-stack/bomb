--!strict
-- Brake (0.62 s, non-looping, in place). Letting go at speed: the last stride plants the left foot out front, the
-- body checks up and leans back against the momentum, arms fling forward for balance, then the body rocks forward
-- past upright and sways back a couple of times, each smaller, before settling into Idle's first pose (so the
-- hand-off to the idle loop is seamless). Lighter than HardStop (the technique): this is the everyday stop.
-- Baked by bake.luau.

return {
	name = "Brake",
	length = 0.62,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	-- A soft torso spring lets the rocking carry; arms a little loose.
	springs = { pitch = { 9, 0.55 }, rArm = { 6.5, 0.55 }, lArm = { 6.5, 0.55 } },
	keys = {
		-- Last running stride (matches Sprint around toe-off).
		{
			t = 0.00,
			pitch = 13,
			rLeg = -30,
			lLeg = 36,
			rArm = 40,
			lArm = -38,
			rArmOut = 9,
			lArmOut = 9,
			rLegOut = 3,
			lLegOut = 2,
			head = -9,
			yaw = 2,
		},
		-- Plant: the left heel bites in out front, the torso checks up.
		{
			t = 0.07,
			hit = true,
			pitch = 2,
			rLeg = -20,
			lLeg = 34,
			rArm = 46,
			lArm = -14,
			rArmOut = 11,
			lArmOut = 11,
			rLegOut = 3,
			lLegOut = 3,
			head = -1,
			yaw = 1,
			squash = 0.09,
		},
		-- Lean back against the momentum; the back foot comes up under the body, arms out front for balance and
		-- the head nodding forward as the body stops under it.
		{
			t = 0.15,
			pitch = -9,
			rLeg = -6,
			lLeg = 22,
			rArm = 30,
			lArm = 18,
			rArmOut = 16,
			lArmOut = 14,
			rLegOut = 3,
			lLegOut = 3,
			head = 7,
			yaw = -3,
			roll = 1,
			squash = 0.12,
		},
		-- Rock forward past upright (feet together under the hips).
		{
			t = 0.27,
			pitch = 6,
			rLeg = 3,
			lLeg = 6,
			rArm = 9,
			lArm = 7,
			rArmOut = 9,
			lArmOut = 9,
			rLegOut = 2.5,
			lLegOut = 2.5,
			head = -2,
			yaw = 1,
			roll = -0.5,
			squash = 0.03,
		},
		-- Sway back, smaller.
		{
			t = 0.38,
			pitch = -2.4,
			rLeg = 1,
			lLeg = 2,
			rArm = -3,
			lArm = -2,
			rArmOut = 6,
			lArmOut = 6,
			rLegOut = 2.5,
			lLegOut = 2.5,
			head = 2.5,
			roll = 0.4,
			squash = 0.02,
		},
		-- One last small rock forward.
		{
			t = 0.49,
			pitch = 1.8,
			rArm = 5,
			lArm = 3,
			rArmOut = 5.5,
			lArmOut = 5.5,
			rLegOut = 2.5,
			lLegOut = 2.5,
			head = 1.5,
			squash = 0.025,
		},
		-- Settled: Idle's first pose.
		{
			t = 0.62,
			stop = true,
			pitch = 1,
			rArm = 3,
			lArm = 2,
			rArmOut = 5,
			lArmOut = 5,
			rLegOut = 2.5,
			lLegOut = 2.5,
			head = 2,
			squash = 0.02,
		},
	},
}
