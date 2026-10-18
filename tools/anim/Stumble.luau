--!strict
-- Stumble (0.5 s, non-looping, UPPER BODY, Action priority). The tagged Runner's reaction (GDD F-BOMB-10): slapped
-- on the back and shoved forward. The legs keep running underneath while the server's shove carries the body.
-- The hit snaps the upper body back (the hips are thrown forward first, so the chest lags), the arms fling up and
-- back and splay, then the body pitches forward to catch its balance with the arms windmilling forward, and settles
-- back into the run. The head whips back on the hit and comes forward over the catch.
-- Baked by bake.luau (parts = head + arms, noDrop).

local LENGTH = 0.5

return {
	name = "Stumble",
	length = LENGTH,
	looped = false,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	springs = { rArm = { 9, 0.55 }, lArm = { 9, 0.55 }, rArmOut = { 9, 0.55 }, lArmOut = { 9, 0.55 } },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Torso: snapped back by the hit, then pitched forward catching its balance.
		pitch = { { 0, 0 }, { 0.05, -12, "hit" }, { 0.16, 14 }, { 0.3, 6 }, { LENGTH, 0 } },
		roll = { { 0, 0 }, { 0.06, 4 }, { 0.18, -5 }, { 0.32, 2 }, { LENGTH, 0 } },
		yaw = { { 0, 0 }, { 0.07, 6 }, { 0.2, -5 }, { LENGTH, 0 } },
		-- Arms: flung up and back and splayed, then windmilling forward to catch the fall (left a beat behind right).
		rArm = { { 0, 10 }, { 0.06, -55, "hit" }, { 0.16, -20 }, { 0.26, 48 }, { 0.38, 14 }, { LENGTH, 10 } },
		lArm = { { 0, 10 }, { 0.08, -62, "hit" }, { 0.19, -16 }, { 0.3, 52 }, { 0.42, 12 }, { LENGTH, 10 } },
		rArmOut = { { 0, 6 }, { 0.06, 38 }, { 0.2, 24 }, { 0.34, 10 }, { LENGTH, 6 } },
		lArmOut = { { 0, 6 }, { 0.08, 42 }, { 0.22, 26 }, { 0.36, 10 }, { LENGTH, 6 } },
		-- Head: whips back on the hit, forward over the catch.
		head = { { 0, 0 }, { 0.05, -16, "hit" }, { 0.17, 12 }, { 0.32, 3 }, { LENGTH, 0 } },
	},
}
