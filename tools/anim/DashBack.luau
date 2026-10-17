--!strict
-- DashBack (0.40 s, non-looping, in place). The backward dash (S + dash, omnimovement): the body keeps facing ahead
-- and bursts BACKWARD. Gameplay: DASH_SPEED held DASH_HOLD (0.13 s), gliding back to pace by DASH_TIME (0.34 s); the
-- last 0.06 s overlaps the blend back into the locomotion.
-- coil (sink, arms cocked) → explode off the front (right) foot → low backward glide, legs scissored, a little float
-- → the back (left) foot plants and absorbs → upright, ready.
-- v2 (2026-10-08, "more flowy"): every part on its own timing (bake.luau `tracks`), the motion rolling through the
-- body: the hips and torso fire first (deepest lean ≈0.15 s), the legs reach a beat behind them, the arms are
-- flung forward a few frames later still (peak ≈0.19 s) and float back down, the head trails last; nothing stops
-- dead between the coil and the ready stance.
-- Baked by bake.luau. Rules (analyse.luau): no body rise over ~8 studs/s, no limb pops, feet planted when bearing weight.

local LENGTH = 0.40

return {
	name = "DashBack",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { rLeg = { 12, 0.8 }, lLeg = { 12, 0.8 }, rArm = { 7, 0.62 }, lArm = { 7, 0.62 } },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: leans in to coil, snaps back into the burst, floats, lands back over the feet.
		pitch = { { 0, 6 }, { 0.05, -1 }, { 0.12, -15 }, { 0.18, -17 }, { 0.25, -9 }, { 0.33, 0 }, { LENGTH, 3 } },
		lift = { { 0, 0 }, { 0.04, 0 }, { 0.11, 0.18 }, { 0.17, 0.14 }, { 0.22, 0 }, { LENGTH, 0 } },
		squash = { { 0, 0.11 }, { 0.06, 0.01 }, { 0.2, 0 }, { 0.25, 0.08 }, { 0.31, 0.05 }, { LENGTH, 0.02 } },
		roll = { { 0, 0 }, { 0.09, 2 }, { 0.19, 3 }, { 0.3, 1 }, { LENGTH, 0 } },
		yaw = { { 0, 0 }, { 0.09, -3 }, { 0.19, -4 }, { 0.3, -1.5 }, { LENGTH, 0 } },
		-- Legs: the front (right) one drives and stays reaching ahead; the back (left) one swings back for the plant.
		rLeg = { { 0, 14 }, { 0.06, 26 }, { 0.14, 34 }, { 0.22, 30 }, { 0.3, 18 }, { LENGTH, 8 } },
		lLeg = { { 0, -10 }, { 0.07, -22 }, { 0.15, -38 }, { 0.22, -30 }, { 0.3, -18 }, { LENGTH, -8 } },
		rLegOut = { { 0, 3 }, { 0.14, 5 }, { 0.3, 3 }, { LENGTH, 2 } },
		lLegOut = { { 0, 5 }, { 0.15, 8 }, { 0.3, 5 }, { LENGTH, 3 } },
		rLegTwist = { { 0, 0 }, { 0.14, 3 }, { LENGTH, 0 } },
		lLegTwist = { { 0, 0 }, { 0.15, -4 }, { LENGTH, 0 } },
		-- Arms: flung forward for balance a beat after the body (the left a touch later and higher), then drifting down.
		rArm = { { 0, -12 }, { 0.06, 8 }, { 0.12, 50 }, { 0.18, 74 }, { 0.26, 52 }, { 0.34, 18 }, { LENGTH, 6 } },
		lArm = { { 0, -16 }, { 0.07, 6 }, { 0.14, 58 }, { 0.2, 84 }, { 0.28, 58 }, { 0.36, 20 }, { LENGTH, 3 } },
		rArmOut = { { 0, 8 }, { 0.12, 14 }, { 0.2, 17 }, { 0.3, 10 }, { LENGTH, 5 } },
		lArmOut = { { 0, 10 }, { 0.13, 17 }, { 0.22, 20 }, { 0.32, 11 }, { LENGTH, 6 } },
		rArmTwist = { { 0, 0 }, { 0.16, 8 }, { 0.3, 4 }, { LENGTH, 0 } },
		lArmTwist = { { 0, 0 }, { 0.18, -10 }, { 0.32, -5 }, { LENGTH, 0 } },
		-- Head: counters the lean last, keeping the eyes on the chaser ahead.
		head = { { 0, -4 }, { 0.08, 4 }, { 0.17, 14 }, { 0.24, 13 }, { 0.33, 4 }, { LENGTH, -1 } },
		headYaw = { { 0, 0 }, { 0.2, 3 }, { LENGTH, 0 } },
	},
}
