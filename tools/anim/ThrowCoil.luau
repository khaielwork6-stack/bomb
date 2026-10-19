--!strict
-- ThrowCoil (0.28 s, non-looping, UPPER BODY, Action priority). THROW MODE's wind-up entry (GDD §7.4c F-THROW-01):
-- the moment you press, the body winds up like a pitcher. A tiny dip the other way first (the anticipation of the
-- anticipation), then the torso snaps round to the right and leans back, the throwing arm flies up and back behind the
-- head past where it will rest (overshoot), and the free arm shoots out to point at the target while the head stays
-- locked on it. Ends exactly on ThrowHold's first pose, which loops while you keep holding.
-- Cartoon timing: slow-in on the dip, a 0.1 s snap, a soft settle. Upper body only: the legs keep running underneath.
-- Baked by bake.luau (parts = head + arms, noDrop).

local LENGTH = 0.28

return {
	name = "ThrowCoil",
	length = LENGTH,
	looped = false,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	springs = { rArm = { 11, 0.62 }, rArmOut = { 11, 0.62 }, lArm = { 9, 0.6 }, yaw = { 12, 0.62 } },
	lag = { rArm = 0.012, rArmTwist = 0.015, lArm = 0.025, head = 0.02, headYaw = 0.02 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Torso: a little dip into the throw, then a hard turn away and a lean back (the coil), settling.
		yaw = { { 0, 0 }, { 0.06, 8 }, { 0.17, -54 }, { LENGTH, -48, "stop" } },
		pitch = { { 0, 2 }, { 0.06, 8 }, { 0.17, -18 }, { LENGTH, -15, "stop" } },
		roll = { { 0, 0 }, { 0.07, -2 }, { 0.18, 10 }, { LENGTH, 8, "stop" } },
		-- Throwing arm: dips forward, then flies up over the shoulder to well behind the head, elbow out.
		rArm = { { 0, 12 }, { 0.07, 40 }, { 0.17, 215 }, { LENGTH, 200, "stop" } },
		rArmOut = { { 0, 8 }, { 0.08, 14 }, { 0.18, 18 }, { LENGTH, 12, "stop" } },
		rArmTwist = { { 0, 0 }, { 0.1, 6 }, { 0.19, 20 }, { LENGTH, 12, "stop" } },
		-- Free arm: shoots out to point at the target (the aim) as the torso turns away from it.
		lArm = { { 0, 10 }, { 0.07, 4 }, { 0.17, 98 }, { LENGTH, 88, "stop" } },
		lArmOut = { { 0, 6 }, { 0.09, 10 }, { 0.18, 26 }, { LENGTH, 22, "stop" } },
		-- Head: stays on the target while the body turns away (it turns left as the torso turns right).
		head = { { 0, 0 }, { 0.07, 3 }, { 0.17, -9 }, { LENGTH, -6, "stop" } },
		headYaw = { { 0, 0 }, { 0.07, -6 }, { 0.17, 50 }, { LENGTH, 44, "stop" } },
	},
}
