--!strict
-- Equip (0.60 s, non-looping, UPPER BODY, Action priority). Drawing the knife from the back (Weapons: the sheathed
-- knife hangs blade-down across the back, its grip high on the right shoulder blade).
-- a glance at the right shoulder → the arm sweeps up the side and tucks in behind the head → GRAB: the hand is at
-- the knife's handle from ≈0.20 to 0.24 s → pull it up and over the shoulder → present it in front with a little
-- flourish → ready.
-- The back → hand swap belongs at ≈0.22 s. At that moment the hand weld (blade forward out of the fist) points the
-- blade back over the shoulder, not down like the sheath: hidden by the motion, but for a fully seamless draw
-- Weapons can ease the weld from the sheathed angle to the hold over the pull (≈0.22 → 0.44 s).
-- Spread note: the baker applies a limb's spread in its swung frame, so with the arm overhead a POSITIVE rArmOut
-- brings the hand in toward the head.
-- v2 (2026-10-08, "more flowy"): every part on its own timing (bake.luau `tracks`): the eyes lead (the glance comes
-- first), the shoulder turns into the reach, the arm travels one continuous arc (out up the side, in behind the
-- head, over, down the front) with a short dwell at the grab, the torso unwinds ahead of the present and the arm
-- overshoots it a touch before settling.
-- Baked by bake.luau (parts = head + arms, noDrop: the legs and body height stay the locomotion's).

local LENGTH = 0.60
local GRAB = 0.22 -- the hand is on the grip: swap the knife from the back to the hand here

return {
	name = "Equip",
	length = LENGTH,
	looped = false,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	-- The drawing arm leads (no drag), so the hand is at the grip on the GRAB frame; the eyes lead the whole move.
	springs = { rArm = { 12, 0.78 }, rArmOut = { 11, 0.75 } },
	lag = { rArm = 0, rArmOut = 0, rArmTwist = 0.01, head = 0.01, headYaw = 0 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Drawing arm: up the side, tucked in behind the head (dwell at the grab), over the top, down the front.
		rArm = {
			{ 0, 6 },
			{ 0.1, 116 },
			{ GRAB - 0.02, 204 },
			{ GRAB + 0.02, 206 },
			{ 0.33, 150 },
			{ 0.44, 44 },
			{ 0.5, 30 },
			{ LENGTH, 18 },
		},
		rArmOut = {
			{ 0, 6 },
			{ 0.1, 22 },
			{ GRAB - 0.02, 15 },
			{ GRAB + 0.02, 15 },
			{ 0.33, 2 },
			{ 0.44, 10 },
			{ LENGTH, 8 },
		},
		rArmTwist = { { 0, 0 }, { 0.1, -10 }, { GRAB, -10 }, { 0.33, -6 }, { 0.44, 6 }, { LENGTH, 2 } },
		-- Torso: the right shoulder turns back into the reach, then unwinds ahead of the present.
		yaw = { { 0, 0 }, { 0.13, -8 }, { 0.24, -8 }, { 0.36, 2 }, { 0.44, 6 }, { LENGTH, 0 } },
		roll = { { 0, 0 }, { 0.15, -3 }, { 0.25, -2.5 }, { 0.4, 0.5 }, { LENGTH, 0 } },
		pitch = { { 0, 0 }, { 0.2, -2 }, { 0.42, 3 }, { LENGTH, 1 } },
		-- Free arm: drifts out for balance through the reach, back in as the knife comes round.
		lArm = { { 0, 4 }, { 0.12, 12 }, { 0.22, 16 }, { 0.34, 10 }, { 0.45, 2 }, { LENGTH, 4 } },
		lArmOut = { { 0, 6 }, { 0.12, 13 }, { 0.22, 18 }, { 0.34, 12 }, { 0.46, 8 }, { LENGTH, 6 } },
		lArmTwist = { { 0, 0 }, { 0.2, -4 }, { 0.4, 0 }, { LENGTH, 0 } },
		-- Head: the glance to the shoulder comes first, then back to the front just ahead of the knife.
		head = { { 0, 0 }, { 0.12, 3 }, { 0.2, 4 }, { 0.32, 1 }, { 0.44, 3 }, { LENGTH, 0 } },
		headYaw = { { 0, 0 }, { 0.11, -12 }, { 0.2, -14 }, { 0.3, -5 }, { 0.42, 2 }, { LENGTH, 0 } },
	},
}
