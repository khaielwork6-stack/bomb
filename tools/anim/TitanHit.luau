--!strict
-- TitanHit (0.85 s, Action). TITAN HUNT: a runner struck the weak spot while the Titan kneels. Pain jolts up the
-- spine: the torso snaps up and back, the head is thrown back (a roar of pain), the free arm flings out, a shudder
-- runs through it, then it slumps lower than before and settles back into the kneel. Starts and ends on
-- TitanKneel's pose (the game plays it over the kneel loop and fades back). The hammer stays planted (solved arm).

local LENGTH = 0.85

return {
	name = "TitanHit",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { lArm = { 6, 0.55 }, lArmOut = { 6, 0.55 }, head = { 7, 0.5 }, pitch = { 12, 0.6 } },
	noSpring = { rArm = true },
	lag = { rArm = 0, head = 0.03, headYaw = 0.05, lArm = 0.04, lArmOut = 0.03 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- the jolt: up and back, a shudder, then a slump below the kneel's lean before settling
		pitch = {
			{ 0, 31.8 },
			{ 0.09, 17, "hit" },
			{ 0.16, 19 },
			{ 0.22, 16.5 },
			{ 0.3, 20 },
			{ 0.48, 37 },
			{ 0.64, 33 },
			{ LENGTH, 31.8 },
		},
		roll = { { 0, 1 }, { 0.1, 6 }, { 0.24, 4 }, { 0.5, -1 }, { LENGTH, 1 } },
		yaw = { { 0, 3 }, { 0.1, -6 }, { 0.3, -3 }, { 0.6, 4 }, { LENGTH, 3 } },
		squash = { { 0, 0.05 }, { 0.1, 0.0 }, { 0.3, 0.03 }, { 0.48, 0.1 }, { 0.65, 0.06 }, { LENGTH, 0.05 } },
		-- head thrown back (pain roar), snaps forward on the slump
		head = {
			{ 0, 12 },
			{ 0.12, -18, "hit" },
			{ 0.2, -14 },
			{ 0.26, -19 },
			{ 0.36, -10 },
			{ 0.52, 16 },
			{ 0.7, 11 },
			{ LENGTH, 12 },
		},
		headYaw = { { 0, 0 }, { 0.12, -6 }, { 0.3, 4 }, { 0.55, 0 }, { LENGTH, 0 } },
		-- free arm flings out, then comes back to the knee
		lArm = { { 0, 32 }, { 0.14, 52 }, { 0.3, 46 }, { 0.55, 26 }, { LENGTH, 32 } },
		lArmOut = { { 0, 8 }, { 0.14, 48 }, { 0.28, 40 }, { 0.55, 10 }, { LENGTH, 8 } },
		lArmTwist = { { 0, -2 }, { 0.14, 10 }, { 0.5, 0 }, { LENGTH, -2 } },
		rArmOut = { { 0, 10 }, { 0.14, 16 }, { 0.5, 9 }, { LENGTH, 10 } },
		-- legs hold the split kneel
		lLeg = { { 0, 78 }, { LENGTH, 78 } },
		rLeg = { { 0, -82 }, { LENGTH, -82 } },
		lLegOut = { { 0, 18 }, { LENGTH, 18 } },
		rLegOut = { { 0, 14 }, { LENGTH, 14 } },
		rLegTwist = { { 0, 2 }, { LENGTH, 2 } },
		lLegTwist = { { 0, -6 }, { LENGTH, -6 } },
		rArmTwist = { { 0, 2 }, { LENGTH, 2 } },
		-- solved per frame below
		rArm = {
			{ 0, 28.7 },
			{ 0.05, 27.2 },
			{ 0.1, 25.0 },
			{ 0.15, 24.8 },
			{ 0.2, 24.3 },
			{ 0.25, 24.1 },
			{ 0.3, 24.1 },
			{ 0.35, 24.4 },
			{ 0.4, 25.9 },
			{ 0.45, 28.1 },
			{ 0.5, 29.5 },
			{ 0.55, 29.8 },
			{ 0.6, 29.5 },
			{ 0.65, 29.1 },
			{ 0.7, 29.0 },
			{ LENGTH, 28.7 },
		},
	},
}
