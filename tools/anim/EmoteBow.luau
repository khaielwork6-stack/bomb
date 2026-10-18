--!strict
-- EmoteBow (3.0 s, non-looping, in place, Action). Emote_Bow (Asset Bible §8.5): a showy, theatrical stage bow.
-- 0.00–0.45 anticipation: it draws itself up tall, chest out, chin up, and the right hand rises up and out in a
--           flourish while the left arm opens wide; the right foot starts to slide back.
-- 0.45–0.90 the bow: the right hand sweeps down in a big arc onto the belly, the left arm swings out and back, the
--           body folds deep from the hips (≈60°), the head tucks.
-- 0.90–1.90 held low (a slow drift deeper, so it never freezes).
-- 1.90–2.45 it springs back up, overshooting a little past upright (chest proud, chin up), arms dropping.
-- 2.45–3.00 settles into Idle's opening pose.
-- Hand placement: limb angles are WORLD angles, so with the torso pitched 60° the belly hand is rArm ≈ −25
-- (≈35° forward of the torso). Baked by bake.luau.

local LENGTH = 3.0

return {
	name = "EmoteBow",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { pitch = { 9, 0.62 }, rArm = { 6.5, 0.58 }, lArm = { 5.5, 0.58 }, lArmOut = { 6, 0.6 } },
	lag = { head = 0.07 },
	noise = { pitch = 0.4, head = 0.6, headYaw = 0.8 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: draws up tall, folds deep from the hips, holds (drifting deeper), springs back past upright, settles.
		pitch = {
			{ 0, 1 },
			{ 0.32, -8 },
			{ 0.45, -9 },
			{ 0.9, 62 },
			{ 1.9, 66 },
			{ 2.35, -6 },
			{ 2.62, 3 },
			{ LENGTH, 1 },
		},
		squash = {
			{ 0, 0.02 },
			{ 0.32, 0 },
			{ 0.9, 0.08 },
			{ 1.9, 0.09 },
			{ 2.35, 0 },
			{ 2.6, 0.05 },
			{ LENGTH, 0.02 },
		},
		lift = { { 0, 0 }, { 0.38, 0.05 }, { 0.6, 0 }, { 2.3, 0.03 }, { 2.5, 0 }, { LENGTH, 0 } },
		yaw = { { 0, 0 }, { 0.4, -7 }, { 0.9, 2 }, { 1.9, 1 }, { 2.4, -2 }, { LENGTH, 0 } },
		roll = { { 0, 0 }, { 0.4, 2 }, { 0.9, -1 }, { 2.35, 1 }, { LENGTH, 0 } },
		-- Flourish hand: up and out, then a big sweep down onto the belly, and back down to the side on the rise.
		rArm = {
			{ 0, 3 },
			{ 0.15, -8 },
			{ 0.42, 30 },
			{ 0.9, -25 },
			{ 1.9, -22 },
			{ 2.3, 8 },
			{ 2.5, -5 },
			{ 2.75, 4 },
			{ LENGTH, 3 },
		},
		rArmOut = {
			{ 0, 5 },
			{ 0.15, 0 },
			{ 0.42, 112 },
			{ 0.68, 40 },
			{ 0.9, -38 },
			{ 1.9, -36 },
			{ 2.3, 10 },
			{ 2.6, 6 },
			{ LENGTH, 5 },
		},
		rArmTwist = { { 0, 0 }, { 0.42, 20 }, { 0.9, -6 }, { 1.9, -6 }, { 2.4, 0 }, { LENGTH, 0 } },
		-- Free arm: opens wide on the draw-up, swings out and back through the bow, drops on the rise.
		lArm = {
			{ 0, 2 },
			{ 0.42, 14 },
			{ 0.95, -22 },
			{ 1.9, -20 },
			{ 2.32, 6 },
			{ 2.55, -4 },
			{ 2.8, 3 },
			{ LENGTH, 2 },
		},
		lArmOut = { { 0, 5 }, { 0.42, 48 }, { 0.95, 62 }, { 1.9, 60 }, { 2.35, 14 }, { 2.65, 4 }, { LENGTH, 5 } },
		lArmTwist = { { 0, 0 }, { 0.95, 10 }, { 1.9, 8 }, { 2.4, 0 }, { LENGTH, 0 } },
		-- Head: chin up on the draw-up, tucked low in the bow, up proud on the rise.
		head = {
			{ 0, 2 },
			{ 0.4, -12 },
			{ 0.95, 18 },
			{ 1.9, 20 },
			{ 2.35, -10 },
			{ 2.65, 4 },
			{ LENGTH, 2 },
		},
		headYaw = { { 0, 0 }, { 0.4, 9 }, { 0.95, 0 }, { 2.35, -4 }, { LENGTH, 0 } },
		-- Legs: the right foot slides back into the bow and comes back under the body on the rise.
		rLeg = { { 0, 0 }, { 0.4, -4 }, { 0.9, -18 }, { 1.9, -17 }, { 2.45, -2 }, { LENGTH, 0 } },
		lLeg = { { 0, 0 }, { 0.4, 2 }, { 0.9, 9 }, { 1.9, 9 }, { 2.45, 1 }, { LENGTH, 0 } },
		rLegOut = { { 0, 2.5 }, { 0.9, 4 }, { 1.9, 4 }, { LENGTH, 2.5 } },
		lLegOut = { { 0, 2.5 }, { 0.9, 4 }, { 1.9, 4 }, { LENGTH, 2.5 } },
		rLegTwist = { { 0, 0 }, { 0.9, 8 }, { 1.9, 8 }, { 2.45, 0 }, { LENGTH, 0 } },
	},
}
