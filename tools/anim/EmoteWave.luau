--!strict
-- EmoteWave (2.6 s, non-looping, in place, Action). Emote_Wave (Asset Bible §8.5): a big, cheerful hello.
-- 0.00–0.20 anticipation: a little dip, the right arm tucks in and back, the chin drops.
-- 0.20–0.45 the arm whips up and out above the head, the body pops up and leans away from it (chest open, head up).
-- 0.45–1.95 four wide waves, hand above the head, the body and head swaying gently against the beat.
-- 1.95–2.60 the arm drops, swings a touch past the hip (follow-through) and settles into Idle's opening pose.
-- Every part on its own timing (bake.luau `tracks`): the body pops before the arm arrives, the head trails both.
-- The arm stays a little in front of the shoulder plane (rArm < 0 with a big rArmOut) so it reads from the front.
-- Baked by bake.luau.

local LENGTH = 2.6

return {
	name = "EmoteWave",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	-- A stiffer spring on the waving arm so the 0.18 s waves keep their size (it still drags and overshoots).
	springs = { rArmOut = { 10, 0.6 }, lArm = { 5, 0.6 }, head = { 6, 0.6 } },
	noise = { pitch = 0.3, roll = 0.3, head = 0.6, headYaw = 1 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Waving arm: tuck, up and out over the head, four waves, down past the hip, settle.
		rArm = {
			{ 0, 3 },
			{ 0.18, -10 },
			{ 0.42, -16 },
			{ 1.95, -14 },
			{ 2.25, 10 },
			{ 2.42, -3 },
			{ LENGTH, 3 },
		},
		rArmOut = {
			{ 0, 5 },
			{ 0.18, -4 },
			{ 0.44, 146 },
			{ 0.62, 118 },
			{ 0.8, 147 },
			{ 0.98, 117 },
			{ 1.16, 147 },
			{ 1.34, 117 },
			{ 1.52, 146 },
			{ 1.7, 120 },
			{ 1.88, 140 },
			{ 2.25, 18 },
			{ 2.42, 2 },
			{ LENGTH, 5 },
		},
		rArmTwist = { { 0, 0 }, { 0.44, 12 }, { 1.9, 10 }, { 2.3, 0 }, { LENGTH, 0 } },
		-- Free arm: swings back on the dip, out a little for balance, hangs loose.
		lArm = { { 0, 2 }, { 0.2, -6 }, { 0.46, 8 }, { 1.2, 5 }, { 1.95, 4 }, { 2.3, -4 }, { LENGTH, 2 } },
		lArmOut = { { 0, 5 }, { 0.46, 13 }, { 1.95, 10 }, { 2.35, 6 }, { LENGTH, 5 } },
		-- Body: dip, pop up leaning away from the raised arm, sway with the waves, settle.
		pitch = { { 0, 1 }, { 0.18, 6 }, { 0.42, -5 }, { 1.2, -3 }, { 1.95, -3.5 }, { 2.3, 3 }, { LENGTH, 1 } },
		roll = {
			{ 0, 0 },
			{ 0.18, 2 },
			{ 0.42, -6.5 },
			{ 0.8, -4.5 },
			{ 1.16, -6 },
			{ 1.52, -4.5 },
			{ 1.95, -5 },
			{ 2.3, 1.5 },
			{ LENGTH, 0 },
		},
		yaw = { { 0, 0 }, { 0.2, -2 }, { 0.45, 5 }, { 1.95, 4 }, { 2.4, -1 }, { LENGTH, 0 } },
		squash = { { 0, 0.02 }, { 0.18, 0.1 }, { 0.42, 0 }, { 1.95, 0.01 }, { 2.3, 0.06 }, { LENGTH, 0.02 } },
		lift = { { 0, 0 }, { 0.2, 0 }, { 0.42, 0.05 }, { 0.75, 0.02 }, { 1.95, 0.02 }, { 2.25, 0 }, { LENGTH, 0 } },
		-- Head: chin down on the dip, up and bright for the wave, bobbing a little with it.
		head = {
			{ 0, 2 },
			{ 0.2, 8 },
			{ 0.46, -8 },
			{ 0.8, -4 },
			{ 1.16, -7 },
			{ 1.52, -4 },
			{ 1.95, -5 },
			{ 2.32, 4 },
			{ LENGTH, 2 },
		},
		headYaw = { { 0, 0 }, { 0.46, 6 }, { 1.0, 3 }, { 1.5, 7 }, { 1.95, 4 }, { LENGTH, 0 } },
		-- Legs: the weight shifts onto the left foot, away from the raised arm.
		rLeg = { { 0, 0 }, { 0.45, -3 }, { 1.95, -3 }, { LENGTH, 0 } },
		lLeg = { { 0, 0 }, { 0.45, 3 }, { 1.95, 3 }, { LENGTH, 0 } },
		rLegOut = { { 0, 2.5 }, { 0.45, 4 }, { 1.95, 4 }, { LENGTH, 2.5 } },
		lLegOut = { { 0, 2.5 }, { 0.45, 3 }, { 1.95, 3 }, { LENGTH, 2.5 } },
	},
}
