--!strict
-- Hard Stop (0.45 s, non-looping, in place). Baked by tools/anim/bake.luau (splines + springs + per-frame grounding).
-- approach → heel plant (impact, 0.10 s) → big lean back, arms flung out → scissor through → low ready → settle.
-- Angles are WORLD degrees (see Dash.luau). *Out = outward spread, yaw = torso turn, roll = lean right (+),
-- squash = extra body sink in studs on top of the grounding solver (weight).
-- Key flags: hit = impact (sharp direction change), stop = comes to rest. Unflagged keys are flowed through, and
-- a key where a channel turns around eases in and out on that channel automatically. Arms/head/torso lag behind
-- and overshoot on their own (bake.luau SPRINGS), so keys here are the INTENT; don't hand-key overshoot.

return {
	name = "HardStop",
	length = 0.45,
	looped = false,
	priority = "Action",
	keys = {
		-- 1. Approach: last running stride, blue (right) leg reaching forward, arms pumping.
		{ t = 0.00, pitch = 16, rArm = -46, lArm = 42, rArmOut = 6, lArmOut = 6, rLeg = 32, lLeg = -34, head = -8 },
		-- Reach: torso already checking up, front leg fully out for the heel strike.
		{
			t = 0.07,
			pitch = 2,
			rArm = -56,
			lArm = 52,
			rArmOut = 10,
			lArmOut = 10,
			rLeg = 50,
			lLeg = -30,
			head = -2,
			yaw = -3,
		},
		-- 2. Heel plant (impact): body thumps down, torso whips back, head snaps.
		{
			t = 0.10,
			hit = true,
			pitch = -18,
			rArm = -42,
			lArm = 78,
			rArmOut = 24,
			lArmOut = 20,
			rLeg = 54,
			lLeg = -26,
			rLegOut = 4,
			lLegOut = 4,
			head = 13,
			yaw = -8,
			roll = 2,
			squash = 0.26,
		},
		-- 3. Lean back: kill the momentum; white arm thrown high forward, blue arm back and out, both spread.
		{
			t = 0.20,
			pitch = -40,
			rArm = -20,
			lArm = 126,
			rArmOut = 52,
			lArmOut = 36,
			rLeg = 46,
			lLeg = -2,
			rLegOut = 5,
			lLegOut = 4,
			head = 30,
			yaw = -16,
			roll = 8,
			squash = 0.04,
		},
		-- Recover (breakdown): legs scissor through, torso passes upright on its way forward.
		{
			t = 0.28,
			pitch = 2,
			rArm = 10,
			lArm = 76,
			rArmOut = 22,
			lArmOut = 16,
			rLeg = 0,
			lLeg = 18,
			rLegOut = 7,
			lLegOut = 7,
			head = 0,
			yaw = -6,
			roll = 3,
		},
		-- 4. Low ready: wide staggered base (blue back, white forward), lean in, guard arms out front.
		{
			t = 0.36,
			pitch = 34,
			rArm = 38,
			lArm = 62,
			rArmOut = 16,
			lArmOut = 16,
			rLeg = -50,
			lLeg = 42,
			rLegOut = 10,
			lLegOut = 10,
			head = -26,
			yaw = 2,
			squash = 0.14,
		},
		-- 5. Settle: rises a hair and breathes out; stable.
		{
			t = 0.45,
			stop = true,
			pitch = 27,
			rArm = 29,
			lArm = 53,
			rArmOut = 13,
			lArmOut = 13,
			rLeg = -47,
			lLeg = 40,
			rLegOut = 9,
			lLegOut = 9,
			head = -18,
			squash = 0.05,
		},
	},
}
