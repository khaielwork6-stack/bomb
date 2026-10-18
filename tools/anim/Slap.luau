--!strict
-- Slap (0.34 s, non-looping, UPPER BODY, Action priority). The Bomber's tag (GDD F-BOMB-10): the hand bomb is slapped
-- onto the Runner's back. The legs keep running underneath (head + arms only; the torso only turns).
-- Played from TimePosition = CONTACT − SLAP_LEAD (Config.Feel) when the server's Stick arrives, so the hit lands
-- a beat after the event and the hit-stop freezes the contact pose.
-- A tight overhand: the arm cocks up and back while the torso coils (≈0.07 s), whips over and down through the
-- target with the shoulder driving (contact ≈0.11 s, a sharp `hit`), follows through past the hip, rebounds softly.
-- The free arm reaches forward on the load (aim) and snaps back as the strike lands to counter the turn; the head
-- leads into the hit and stays on the target. Same whip principle as Swing v2, shorter and snappier.
-- Baked by bake.luau (parts = head + arms, noDrop).

local LENGTH = 0.34

return {
	name = "Slap",
	length = LENGTH,
	looped = false,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	springs = { rArm = { 16, 0.78 }, rArmOut = { 13, 0.74 }, lArm = { 9, 0.62 } },
	lag = { rArm = 0, rArmOut = 0, rArmTwist = 0.008 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Slapping arm: cock up and back, over the top, a hard hit through the target, past the hip, soft rebound.
		rArm = {
			{ 0, 14 },
			{ 0.04, 110 },
			{ 0.075, 160 },
			{ 0.11, 58, "hit" },
			{ 0.16, 2 },
			{ 0.22, 18 },
			{ 0.28, 12 },
			{ LENGTH, 10 },
		},
		rArmOut = { { 0, 8 }, { 0.04, 30 }, { 0.075, 18 }, { 0.11, 4 }, { 0.17, 12 }, { 0.26, 9 }, { LENGTH, 8 } },
		rArmTwist = { { 0, 0 }, { 0.05, -8 }, { 0.11, 10, "hit" }, { 0.2, 4 }, { LENGTH, 0 } },
		-- Torso: coils away, then the shoulder drives the strike a beat AHEAD of the hand; a small lunge forward.
		yaw = { { 0, 0 }, { 0.06, -14 }, { 0.1, 4 }, { 0.15, 16 }, { 0.25, 7 }, { LENGTH, 0 } },
		pitch = { { 0, 0 }, { 0.06, -6 }, { 0.11, 12, "hit" }, { 0.2, 7 }, { LENGTH, 0 } },
		roll = { { 0, 0 }, { 0.07, 3 }, { 0.12, -4 }, { 0.24, -1 }, { LENGTH, 0 } },
		-- Free arm: reaches out to aim on the load, snaps back as the strike lands.
		lArm = { { 0, 8 }, { 0.05, 38 }, { 0.09, 44 }, { 0.13, 4 }, { 0.19, -26 }, { 0.28, -6 }, { LENGTH, 6 } },
		lArmOut = { { 0, 6 }, { 0.06, 14 }, { 0.13, 18 }, { 0.2, 14 }, { LENGTH, 6 } },
		-- Head: leads into the hit, eyes on the target.
		head = { { 0, 0 }, { 0.07, -6 }, { 0.12, 10, "hit" }, { 0.22, 4 }, { LENGTH, 0 } },
		headYaw = { { 0, 0 }, { 0.07, 8 }, { 0.14, -6 }, { LENGTH, 0 } },
	},
}
