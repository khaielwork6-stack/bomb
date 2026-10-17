--!strict
-- Land (0.40 s, non-looping, in place, Movement priority). The touchdown after a jump / drop: Locomotion fades it in
-- on landing, weighted by the impact (full when standing, a light touch under a running stride, which keeps its legs).
-- touch (feet reaching, arms still out from the fall) → impact: the legs split and splay to take the weight, the
-- torso folds forward over them, arms swing down → deepest absorb → rise, a small overshoot back → a balanced stance.
-- R6 has no knees: the drop comes from the legs opening (the grounding solver lowers the body onto them), with only a
-- little extra squash, so it reads as weight instead of the body sinking through the floor.
-- v2 (2026-10-08, "more flowy"): every part on its own timing (bake.luau `tracks`): the impact travels UP the body,
-- legs first (deepest ≈0.10 s), the torso folding after them (≈0.13 s), the arms swinging down and through after
-- that (≈0.17 s) and the head last (≈0.18 s); on the way up the torso overshoots a touch past upright and settles.
-- Baked by bake.luau. Rules (analyse.luau): no body rise over ~8 studs/s, no limb pops, feet planted.

local LENGTH = 0.40

return {
	name = "Land",
	length = LENGTH,
	looped = false,
	priority = "Movement",
	contact = "feet",
	hipPivot = 1,
	springs = { rLeg = { 12, 0.85 }, lLeg = { 12, 0.85 }, rArm = { 7, 0.58 }, lArm = { 7, 0.58 } },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Legs take it first: they open to catch the weight, then gather back under the body.
		rLeg = { { 0, 8 }, { 0.06, 17 }, { 0.11, 20 }, { 0.2, 15 }, { 0.3, 7 }, { LENGTH, 4 } },
		lLeg = { { 0, -4 }, { 0.06, -13 }, { 0.11, -17 }, { 0.21, -12 }, { 0.31, -5 }, { LENGTH, -3 } },
		rLegOut = { { 0, 5 }, { 0.07, 10 }, { 0.12, 12 }, { 0.24, 7 }, { LENGTH, 3 } },
		lLegOut = { { 0, 6 }, { 0.07, 11 }, { 0.12, 13 }, { 0.25, 8 }, { LENGTH, 3 } },
		rLegTwist = { { 0, 0 }, { 0.1, 4 }, { 0.28, 1 }, { LENGTH, 0 } },
		lLegTwist = { { 0, 0 }, { 0.1, -4 }, { 0.28, -1 }, { LENGTH, 0 } },
		-- Body: sinks with the legs, folds forward a beat later, rises with a small overshoot past upright.
		squash = { { 0, 0 }, { 0.06, 0.08 }, { 0.11, 0.12 }, { 0.2, 0.08 }, { 0.3, 0.02 }, { LENGTH, 0.01 } },
		pitch = { { 0, 3 }, { 0.06, 8 }, { 0.13, 15 }, { 0.21, 10 }, { 0.3, 1 }, { 0.35, -0.5 }, { LENGTH, 2 } },
		roll = { { 0, 0 }, { 0.12, -1.5 }, { 0.26, 0.5 }, { LENGTH, 0 } },
		yaw = { { 0, 0 }, { 0.14, 2 }, { 0.3, -0.5 }, { LENGTH, 0 } },
		-- Arms: still spread from the air, they swing down and forward through the absorb, then hang loose.
		rArm = { { 0, 26 }, { 0.07, 24 }, { 0.17, 12 }, { 0.25, 18 }, { 0.33, 8 }, { LENGTH, 4 } },
		lArm = { { 0, 18 }, { 0.08, 18 }, { 0.18, 8 }, { 0.26, 14 }, { 0.34, 6 }, { LENGTH, 3 } },
		rArmOut = { { 0, 38 }, { 0.08, 32 }, { 0.17, 20 }, { 0.28, 11 }, { LENGTH, 5 } },
		lArmOut = { { 0, 42 }, { 0.09, 36 }, { 0.18, 23 }, { 0.29, 12 }, { LENGTH, 6 } },
		rArmTwist = { { 0, 6 }, { 0.16, 3 }, { LENGTH, 0 } },
		lArmTwist = { { 0, -6 }, { 0.17, -3 }, { LENGTH, 0 } },
		-- Head: dips last and comes back up last.
		head = { { 0, -5 }, { 0.08, 1 }, { 0.18, 9 }, { 0.27, 5 }, { 0.36, 0 }, { LENGTH, 0 } },
		headYaw = { { 0, 0 }, { 0.16, -2 }, { LENGTH, 0 } },
	},
}
