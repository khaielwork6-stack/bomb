--!strict
-- TitanRise (1.35 s, Action). TITAN HUNT: the end of the vulnerable phase. From TitanKneel's pose the Titan heaves
-- once more, RIPS the hammer out of the floor (0.4 s), and the recoil throws it back up onto its feet: the back leg
-- steps through, the front leg draws in, the hammer swings up and back down to rest on its head with a thud
-- (≈0.9 s), and it settles into TitanIdle's opening pose, the torso swaying past upright and back.
-- The hammer is planted (solved arm) until the rip; titanprobe.luau checks it never goes through the floor after.

local LENGTH = 1.35
local RIP = 0.4

return {
	name = "TitanRise",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = {
		lArm = { 4.5, 0.6 },
		lArmOut = { 4.5, 0.65 },
		head = { 5, 0.6 },
		rLeg = { 8, 0.85 },
		lLeg = { 8, 0.85 },
	},
	noSpring = { rArm = true },
	lag = { rArm = 0, head = 0.07, headYaw = 0.09, lArm = 0.06 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- hammer arm: planted (solved) → rip → swings up → falls back to rest on its head
		rArm = {
			{ 0, 28.7 },
			{ 0.1, 27.9 },
			{ 0.2, 26.1 },
			{ 0.3, 24.9 },
			{ 0.35, 23.2 },
			{ RIP, 18.7, "hit" },
			{ 0.6, 62 },
			{ 0.88, -3.6, "hit" }, -- the thud: head back on the floor
			{ 1.05, -1.2 },
			{ LENGTH, 0.03 },
		},
		rArmOut = { { 0, 10 }, { RIP, 14 }, { 0.6, 12 }, { 1.0, 7 }, { LENGTH, 6.9 } },
		rArmTwist = { { 0, 2 }, { 0.6, -4 }, { LENGTH, 0 } },
		-- torso: hauls back, the rip throws it upright and past, settles into the idle lean
		pitch = {
			{ 0, 31.8 },
			{ 0.22, 22 },
			{ RIP, 20, "hit" },
			{ 0.62, 4 },
			{ 0.82, 1 },
			{ 1.05, 6.5 },
			{ LENGTH, 5.4 },
		},
		yaw = { { 0, 3 }, { RIP, -4 }, { 0.7, 3 }, { LENGTH, -1 } },
		roll = { { 0, 1 }, { RIP, 4 }, { 0.75, -2 }, { LENGTH, 0 } },
		squash = {
			{ 0, 0.05 },
			{ 0.3, 0.07 },
			{ RIP, 0.02 },
			{ 0.7, 0.0 },
			{ 0.92, 0.07 },
			{ 1.1, 0.03 },
			{ LENGTH, 0.021 },
		},
		-- legs: back leg steps through, front leg draws in under the body
		rLeg = { { 0, -82 }, { 0.3, -80 }, { 0.55, -36 }, { 0.75, 2 }, { 0.92, 6 }, { LENGTH, 5 } },
		lLeg = { { 0, 78 }, { 0.32, 76 }, { 0.58, 38 }, { 0.8, -2 }, { 0.96, -6 }, { LENGTH, -5 } },
		rLegOut = { { 0, 14 }, { 0.5, 11 }, { 0.85, 7 }, { LENGTH, 7 } },
		lLegOut = { { 0, 18 }, { 0.5, 13 }, { 0.85, 7 }, { LENGTH, 7 } },
		rLegTwist = { { 0, 2 }, { 0.8, 6 }, { LENGTH, 6 } },
		lLegTwist = { { 0, -6 }, { LENGTH, -6 } },
		-- free arm: shoves off the knee, swings out for balance as it rises, hangs
		lArm = { { 0, 32 }, { 0.3, 44 }, { 0.55, 22 }, { 0.8, -6 }, { 1.05, 4 }, { LENGTH, 1.7 } },
		lArmOut = { { 0, 8 }, { 0.3, 14 }, { 0.6, 30 }, { 0.95, 17 }, { LENGTH, 15.2 } },
		lArmTwist = { { 0, -2 }, { 0.6, 4 }, { LENGTH, -5.6 } },
		-- head: strains up, eyes come back to the runners as it stands
		head = { { 0, 12 }, { 0.25, 2 }, { RIP, -4 }, { 0.75, -6 }, { 1.0, -1 }, { LENGTH, -2.5 } },
		headYaw = { { 0, 0 }, { 0.6, 6 }, { 1.0, -7 }, { LENGTH, -5.5 } },
	},
}
