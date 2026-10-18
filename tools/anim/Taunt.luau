--!strict
-- Taunt (1.8 s, non-looping, in place, Action). The T taunt (docs/VIDEO2_NOTES.md §8; the reference's TAUNT button):
-- a cocky "come at me" — chest out, chin up, the right hand beckons twice ("come on, come on").
-- 0.00–0.16 anticipation: a small dip, the shoulders roll back.
-- 0.16–0.40 THE PUFF: the body rises onto its toes, the chest pushes out (torso leans back), the chin lifts, the left
--           fist plants on the hip and the right arm comes up in front, palm up.
-- 0.40–1.20 two beckons: the right forearm curls in and out (the arm swings up / back), the head bobs with each one.
-- 1.20–1.45 a smug little bounce on the heels; the arms drop.
-- 1.45–1.80 settles into Idle's opening pose. Baked by bake.luau.

local LENGTH = 1.8

return {
	name = "Taunt",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { rArm = { 7, 0.55 }, lArm = { 6.5, 0.6 }, rArmOut = { 7, 0.58 }, lArmOut = { 6.5, 0.6 } },
	lag = { lArm = 0.04, head = 0.05 },
	noise = { pitch = 0.3, roll = 0.3, head = 0.5 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: dip, rise onto the toes with the chest out, a smug bounce, settle.
		squash = {
			{ 0, 0.02 },
			{ 0.16, 0.09 },
			{ 0.38, 0 },
			{ 1.2, 0.01 },
			{ 1.32, 0.07 },
			{ 1.55, 0.02 },
			{ LENGTH, 0.02 },
		},
		lift = {
			{ 0, 0 },
			{ 0.16, 0 },
			{ 0.36, 0.08 },
			{ 1.12, 0.06 },
			{ 1.3, 0 },
			{ 1.42, 0.05 },
			{ 1.6, 0 },
			{ LENGTH, 0 },
		},
		pitch = { { 0, 1 }, { 0.16, 4 }, { 0.4, -9 }, { 1.15, -8 }, { 1.45, 2 }, { 1.7, 0 }, { LENGTH, 1 } },
		roll = { { 0, 0 }, { 0.4, -3 }, { 1.15, -3 }, { 1.5, 0.5 }, { LENGTH, 0 } },
		yaw = { { 0, 0 }, { 0.4, 8 }, { 1.15, 8 }, { 1.6, 0 }, { LENGTH, 0 } },
		-- Right arm: up in front palm-up, then two beckons (swing up and back), then down.
		rArm = {
			{ 0, 3 },
			{ 0.16, -6 },
			{ 0.4, 70 },
			{ 0.58, 95 },
			{ 0.74, 64 },
			{ 0.92, 97 },
			{ 1.1, 66 },
			{ 1.3, 8 },
			{ 1.55, 4 },
			{ LENGTH, 3 },
		},
		rArmOut = { { 0, 5 }, { 0.4, 14 }, { 1.1, 14 }, { 1.35, 6 }, { LENGTH, 5 } },
		rArmTwist = { { 0, 0 }, { 0.4, 70 }, { 1.1, 70 }, { 1.35, 0 }, { LENGTH, 0 } },
		-- Left arm: fist on the hip (out to the side, bent back), held, then down.
		lArm = { { 0, 2 }, { 0.16, -2 }, { 0.38, -18 }, { 1.15, -16 }, { 1.4, 0 }, { LENGTH, 2 } },
		lArmOut = { { 0, 5 }, { 0.38, 34 }, { 1.15, 32 }, { 1.4, 7 }, { LENGTH, 5 } },
		lArmTwist = { { 0, 0 }, { 0.38, -30 }, { 1.15, -30 }, { 1.4, 0 }, { LENGTH, 0 } },
		-- Head: chin up and cocked, a nod with each beckon.
		head = {
			{ 0, 2 },
			{ 0.16, 6 },
			{ 0.4, -12 },
			{ 0.6, -6 },
			{ 0.76, -13 },
			{ 0.94, -6 },
			{ 1.12, -12 },
			{ 1.45, 3 },
			{ LENGTH, 2 },
		},
		headYaw = { { 0, 0 }, { 0.4, -10 }, { 1.15, -9 }, { 1.6, 0 }, { LENGTH, 0 } },
		-- Legs: a wide, planted stance while it holds.
		rLegOut = { { 0, 2.5 }, { 0.38, 7 }, { 1.2, 7 }, { 1.55, 2.5 }, { LENGTH, 2.5 } },
		lLegOut = { { 0, 2.5 }, { 0.38, 7 }, { 1.2, 7 }, { 1.55, 2.5 }, { LENGTH, 2.5 } },
	},
}
