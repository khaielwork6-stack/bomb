--!strict
-- ThrowHold (1.2 s loop, UPPER BODY, Action priority). THROW MODE's held wind-up (GDD §7.4c F-THROW-01): the coil
-- held under tension. The throwing arm strains a little further back and eases off, the chest breathes, the aiming
-- arm stays on the target, and a fine tremble rides on top (the game speeds the clip up as the power builds, so the
-- strain visibly grows). Starts and ends on ThrowCoil's last pose; Throw starts from it too.
-- Baked by bake.luau (parts = head + arms, noDrop).

local LENGTH = 1.2

local COIL = {
	yaw = -48,
	pitch = -15,
	roll = 8,
	rArm = 200,
	rArmOut = 12,
	rArmTwist = 12,
	lArm = 88,
	lArmOut = 22,
	head = -6,
	headYaw = 44,
}

local function key(t: number, extra: { [string]: number }?): { [string]: any }
	local k: { [string]: any } = { t = t }
	for ch, v in pairs(COIL) do
		k[ch] = v
	end
	for ch, v in pairs(extra or {}) do
		k[ch] = v
	end
	return k
end

return {
	name = "ThrowHold",
	length = LENGTH,
	looped = true,
	priority = "Action",
	parts = { "Head", "Right Arm", "Left Arm" },
	noDrop = true,
	springs = { rArm = { 9, 0.6 }, lArm = { 8, 0.6 } },
	-- the strain: a fine tremble on the arms and shoulders
	noise = { rArm = 2.6, rArmOut = 1.6, rArmTwist = 1.5, yaw = 1.3, pitch = 0.8, roll = 0.7, lArm = 1.6, head = 0.7 },
	keys = {
		key(0),
		-- strain: the arm pulls back further, the torso winds tighter, a breath in
		key(0.55, { rArm = 207, rArmOut = 14, yaw = -51, pitch = -17, roll = 9, lArm = 91, headYaw = 46 }),
		key(LENGTH),
	},
}
