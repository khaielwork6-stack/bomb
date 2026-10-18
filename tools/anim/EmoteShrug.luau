--!strict
-- EmoteShrug (2.2 s, non-looping, in place, Action). Emote_Shrug (Asset Bible §8.5): a big "beats me" shrug.
-- 0.00–0.18 anticipation: a small dip, the arms tuck in, the chin drops.
-- 0.18–0.42 THE SHRUG: the whole body pops up (R6 has no shoulders, so the torso lifts instead), both arms fling
--           out and a little forward with the palms turned up, the torso leans and the head tilts and turns away.
-- 0.42–1.30 held, with a second, smaller "I dunno" bounce at ≈1.05.
-- 1.30–1.62 the arms flop down and swing past the hips (follow-through), the body drops back onto its heels.
-- 1.62–2.20 settles into Idle's opening pose.
-- (No head roll channel on R6: the head tilt is the torso's roll plus the head's turn.) Baked by bake.luau.

local LENGTH = 2.2

return {
	name = "EmoteShrug",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { rArm = { 6.5, 0.55 }, lArm = { 6.5, 0.55 }, rArmOut = { 7, 0.58 }, lArmOut = { 7, 0.58 } },
	lag = { lArm = 0.05, lArmOut = 0.05, head = 0.06 },
	noise = { pitch = 0.3, roll = 0.3, head = 0.6, headYaw = 0.9 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: dip, pop up, hold (with the second bounce), drop back, settle.
		squash = {
			{ 0, 0.02 },
			{ 0.18, 0.1 },
			{ 0.4, 0 },
			{ 0.95, 0.01 },
			{ 1.3, 0.01 },
			{ 1.58, 0.09 },
			{ 1.85, 0.03 },
			{ LENGTH, 0.02 },
		},
		lift = {
			{ 0, 0 },
			{ 0.18, 0 },
			{ 0.4, 0.06 },
			{ 0.92, 0.04 },
			{ 1.06, 0.07 },
			{ 1.3, 0.04 },
			{ 1.55, 0 },
			{ LENGTH, 0 },
		},
		pitch = { { 0, 1 }, { 0.18, 5 }, { 0.42, -4 }, { 1.3, -3 }, { 1.6, 4 }, { 1.9, 0 }, { LENGTH, 1 } },
		roll = {
			{ 0, 0 },
			{ 0.18, -1.5 },
			{ 0.42, 7 },
			{ 1.06, 8 },
			{ 1.3, 6 },
			{ 1.62, -1.5 },
			{ 1.92, 0.5 },
			{ LENGTH, 0 },
		},
		yaw = { { 0, 0 }, { 0.42, -4 }, { 1.3, -3 }, { 1.7, 1 }, { LENGTH, 0 } },
		-- Arms: tuck, fling out with palms up, hold (bounce), flop down past the hips, settle.
		rArm = {
			{ 0, 3 },
			{ 0.18, -4 },
			{ 0.42, 28 },
			{ 0.92, 24 },
			{ 1.06, 31 },
			{ 1.3, 26 },
			{ 1.62, -10 },
			{ 1.85, 6 },
			{ LENGTH, 3 },
		},
		rArmOut = {
			{ 0, 5 },
			{ 0.18, 1 },
			{ 0.42, 44 },
			{ 0.92, 38 },
			{ 1.06, 47 },
			{ 1.3, 40 },
			{ 1.62, 7 },
			{ 1.85, 4 },
			{ LENGTH, 5 },
		},
		rArmTwist = { { 0, 0 }, { 0.42, 38 }, { 1.3, 32 }, { 1.62, 0 }, { LENGTH, 0 } },
		lArm = {
			{ 0, 2 },
			{ 0.18, -4 },
			{ 0.42, 26 },
			{ 0.92, 22 },
			{ 1.06, 29 },
			{ 1.3, 24 },
			{ 1.62, -9 },
			{ 1.85, 5 },
			{ LENGTH, 2 },
		},
		lArmOut = {
			{ 0, 5 },
			{ 0.18, 1 },
			{ 0.42, 42 },
			{ 0.92, 36 },
			{ 1.06, 45 },
			{ 1.3, 38 },
			{ 1.62, 6 },
			{ 1.85, 4 },
			{ LENGTH, 5 },
		},
		lArmTwist = { { 0, 0 }, { 0.42, 38 }, { 1.3, 32 }, { 1.62, 0 }, { LENGTH, 0 } },
		-- Head: chin down on the dip, then tilted (with the torso's lean) and turned away: "who knows?"
		head = { { 0, 2 }, { 0.18, 7 }, { 0.42, -5 }, { 1.06, -6 }, { 1.3, -3 }, { 1.66, 5 }, { LENGTH, 2 } },
		headYaw = { { 0, 0 }, { 0.42, 15 }, { 1.06, 17 }, { 1.3, 12 }, { 1.72, -3 }, { LENGTH, 0 } },
		-- Legs: weight shifts onto the right foot with the lean; the left leg spreads so its foot stays down.
		rLeg = { { 0, 0 }, { 0.42, 2 }, { 1.3, 2 }, { 1.7, 0 }, { LENGTH, 0 } },
		lLeg = { { 0, 0 }, { 0.42, -2 }, { 1.3, -2 }, { 1.7, 0 }, { LENGTH, 0 } },
		rLegOut = { { 0, 2.5 }, { 0.42, 3 }, { 1.3, 3 }, { LENGTH, 2.5 } },
		lLegOut = { { 0, 2.5 }, { 0.42, 12 }, { 1.3, 11 }, { 1.65, 4 }, { LENGTH, 2.5 } },
	},
}
