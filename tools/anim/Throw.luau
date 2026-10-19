--!strict
-- Throw (0.62 s, non-looping, UPPER BODY, Action priority). THROW MODE's release (GDD §7.4c F-THROW-01): a big,
-- cartoon overhand fastball. From ThrowHold's coil: one last squeeze back (0.035 s), then the whip runs up the body in
-- order: the torso unwinds first, the shoulder drives, the arm lags behind and then cracks through overhead (the
-- release ≈ 0.10 s, a sharp `hit`), the wrist snaps over. Huge follow-through: the arm sweeps down and across in front
-- of the body to the opposite knee, the torso folds forward over it and keeps turning, the free arm yanks back to counter the turn,
-- the head follows the throw. Then a springy recovery (overshoot once, settle).
-- Timing: 35 ms load, 65 ms whip, a held follow-through (the "smear" reads in the trail), 0.4 s settle.
-- Played from TimePosition = Feel.THROW_CLIP_FROM so the release frame lands right after you let go.
-- Baked by bake.luau (parts = head + arms, noDrop).

local LENGTH = 0.62

return {
	name = "Throw",
	length = LENGTH,
	looped = false,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	springs = {
		rArm = { 14, 0.58 },
		rArmOut = { 12, 0.6 },
		rArmTwist = { 12, 0.6 },
		lArm = { 9, 0.58 },
		yaw = { 12, 0.6 },
		pitch = { 14, 0.62 },
	},
	lag = { rArm = 0.012, rArmOut = 0.012, rArmTwist = 0.016, lArm = 0.03, head = 0.03, headYaw = 0.035 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Torso: a last squeeze, then it unwinds hard through the target and keeps turning, folding forward.
		yaw = { { 0, -48 }, { 0.035, -55 }, { 0.075, 5 }, { 0.11, 45, "hit" }, { 0.2, 58 }, { 0.34, 30 }, { LENGTH, 0 } },
		pitch = { { 0, -15 }, { 0.035, -19 }, { 0.09, 16 }, { 0.12, 35, "hit" }, { 0.24, 32 }, { 0.4, 10 }, { LENGTH, 0 } },
		roll = { { 0, 8 }, { 0.04, 11 }, { 0.1, -6 }, { 0.14, -14 }, { 0.3, -6 }, { LENGTH, 0 } },
		-- Throwing arm: lags behind the turn, then cracks over the top and down across the body.
		rArm = {
			{ 0, 200 },
			{ 0.04, 214 },
			{ 0.08, 160 },
			{ 0.105, 95, "hit" },
			{ 0.15, 30 },
			{ 0.22, 8 },
			{ 0.34, 4 },
			{ 0.5, 8 },
			{ LENGTH, 10 },
		},
		rArmOut = { { 0, 12 }, { 0.04, 16 }, { 0.09, 4 }, { 0.13, -24 }, { 0.2, -46 }, { 0.32, -26 }, { LENGTH, 6 } },
		rArmTwist = { { 0, 12 }, { 0.06, 22 }, { 0.11, -26, "hit" }, { 0.2, -16 }, { LENGTH, 0 } },
		-- Free arm: from pointing at the target, yanked back and down to counter the turn.
		lArm = { { 0, 88 }, { 0.04, 98 }, { 0.09, 40 }, { 0.13, -30 }, { 0.22, -48 }, { 0.38, -12 }, { LENGTH, 8 } },
		lArmOut = { { 0, 22 }, { 0.06, 28 }, { 0.13, 18 }, { 0.25, 12 }, { LENGTH, 6 } },
		-- Head: drives into the throw and follows the bomb out.
		head = { { 0, -6 }, { 0.04, -9 }, { 0.11, 12, "hit" }, { 0.22, 8 }, { LENGTH, 0 } },
		headYaw = { { 0, 44 }, { 0.05, 50 }, { 0.11, -6 }, { 0.2, -14 }, { 0.4, -6 }, { LENGTH, 0 } },
	},
}
