--!strict
-- Sprint (28 frames = 0.467 s loop at 60 fps: a whole number of frames, so the seam lands exactly; in place).
-- Full-speed run: strong forward lean from the hips, big pumping arms, a long stride with the back leg kicking
-- high behind and a real flight phase. Phase-locked with Jog.luau (right contact at 0, left contact at 0.5 of the
-- cycle, same key fractions), so the locomotion layer can blend the two by speed without the feet ever skating.
-- Only the right-contact half is keyed; the left half is its mirror, so the cycle is perfectly symmetric.
-- Baked by bake.luau (see its header for the channels).

local LENGTH = 28 / 60
local HALF = LENGTH / 2

local SWAP = {
	{ "rArm", "lArm" },
	{ "rLeg", "lLeg" },
	{ "rArmOut", "lArmOut" },
	{ "rLegOut", "lLegOut" },
	{ "rArmTwist", "lArmTwist" },
	{ "rLegTwist", "lLegTwist" },
}
local NEGATE = { "yaw", "roll", "side", "headYaw" }

local function mirror(k: { [string]: any }): { [string]: any }
	local m = table.clone(k)
	for _, pair in ipairs(SWAP) do
		m[pair[1]], m[pair[2]] = k[pair[2]], k[pair[1]]
	end
	for _, ch in ipairs(NEGATE) do
		m[ch] = if k[ch] then -k[ch] else nil
	end
	m.t = k.t + HALF
	return m
end

-- Fractions of the half cycle: contact 0, load .17, passing .37, toe-off .59, flight peak .80.
local half = {
	-- Right heel strikes ahead of the body; left leg has just left the ground behind; arms at full opposite swing.
	{
		t = 0.000,
		pitch = 12,
		rLeg = 30,
		lLeg = -44,
		rArm = -52,
		lArm = 56,
		rArmOut = 9,
		lArmOut = 9,
		rArmTwist = 6,
		lArmTwist = -4,
		rLegOut = 2,
		lLegOut = 3,
		head = -9,
		yaw = -4,
		roll = 2,
		squash = 0.05,
	},
	-- Load: the body sinks onto the right leg, torso folds a touch more.
	{
		t = HALF * 0.17,
		pitch = 14,
		rLeg = 16,
		lLeg = -30,
		rArm = -40,
		lArm = 44,
		rArmOut = 9,
		lArmOut = 9,
		rArmTwist = 4,
		lArmTwist = -3,
		rLegOut = 2,
		lLegOut = 3,
		head = -10,
		yaw = -3,
		roll = 3,
		squash = 0.11,
	},
	-- Passing: the free leg swings through under the hips, arms cross by the sides.
	{
		t = HALF * 0.37,
		pitch = 15,
		rLeg = -4,
		lLeg = 8,
		rArm = -6,
		lArm = 10,
		rArmOut = 8,
		lArmOut = 8,
		rLegOut = 2,
		lLegOut = 2,
		head = -11,
		yaw = -1,
		roll = 2,
		squash = 0.05,
	},
	-- Toe-off: drive off the right foot, left knee punches forward, arms reversing hard.
	{
		t = HALF * 0.59,
		pitch = 14,
		rLeg = -36,
		lLeg = 42,
		rArm = 40,
		lArm = -38,
		rArmOut = 9,
		lArmOut = 9,
		rArmTwist = -5,
		lArmTwist = 5,
		rLegOut = 3,
		lLegOut = 2,
		head = -10,
		yaw = 2,
		roll = 0,
		lift = 0.06,
	},
	-- Flight: both feet off the ground, right leg kicked high behind, left reaching for the next strike.
	{
		t = HALF * 0.80,
		pitch = 12,
		rLeg = -50,
		lLeg = 40,
		rArm = 58,
		lArm = -52,
		rArmOut = 9,
		lArmOut = 9,
		rArmTwist = -7,
		lArmTwist = 6,
		rLegOut = 3,
		lLegOut = 2,
		head = -9,
		yaw = 4,
		roll = -1,
		lift = 0.16,
	},
}

local keys = {}
for _, k in ipairs(half) do
	table.insert(keys, k)
end
for _, k in ipairs(half) do
	table.insert(keys, mirror(k))
end

return {
	name = "Sprint",
	length = LENGTH,
	looped = true,
	priority = "Movement",
	hipPivot = 1,
	contact = "feet",
	-- A fast cycle: stiffer arm springs keep the pump crisp instead of washing it out.
	springs = { rArm = { 9, 0.6 }, lArm = { 9, 0.6 }, head = { 9, 0.6 } },
	noise = { pitch = 0.4, head = 0.6, headYaw = 0.8 },
	keys = keys,
}
