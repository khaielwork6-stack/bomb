--!strict
-- Jog (39 frames = 0.65 s loop at 60 fps, in place). Setting-off / easy pace: upright, relaxed arms, short stride,
-- a small float.
-- Phase-locked with Sprint.luau (same key fractions: contact 0, load .17, passing .37, toe-off .59, flight .80 of
-- each half), so blending Jog → Sprint by speed reads as one runner opening up the stride. Right-contact half keyed,
-- left half mirrored. Baked by bake.luau.

local LENGTH = 39 / 60
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

local function at(frac: number): number
	return HALF * frac
end

local half = {
	{
		t = at(0),
		pitch = 5,
		rLeg = 24,
		lLeg = -30,
		rArm = -34,
		lArm = 36,
		rArmOut = 7,
		lArmOut = 7,
		rArmTwist = 4,
		lArmTwist = -3,
		rLegOut = 2,
		lLegOut = 3,
		head = -3,
		yaw = -3,
		roll = 2,
		squash = 0.04,
	},
	{
		t = at(0.17),
		pitch = 6,
		rLeg = 12,
		lLeg = -20,
		rArm = -26,
		lArm = 28,
		rArmOut = 7,
		lArmOut = 7,
		rArmTwist = 3,
		lArmTwist = -2,
		rLegOut = 2,
		lLegOut = 3,
		head = -4,
		yaw = -2,
		roll = 3,
		squash = 0.08,
	},
	{
		t = at(0.37),
		pitch = 6,
		rLeg = -2,
		lLeg = 6,
		rArm = -4,
		lArm = 6,
		rArmOut = 6,
		lArmOut = 6,
		rLegOut = 2,
		lLegOut = 2,
		head = -4,
		yaw = -1,
		roll = 2,
		squash = 0.04,
	},
	{
		t = at(0.59),
		pitch = 6,
		rLeg = -22,
		lLeg = 28,
		rArm = 26,
		lArm = -24,
		rArmOut = 7,
		lArmOut = 7,
		rArmTwist = -3,
		lArmTwist = 3,
		rLegOut = 3,
		lLegOut = 2,
		head = -4,
		yaw = 2,
		roll = 0,
		lift = 0.03,
	},
	{
		t = at(0.80),
		pitch = 5,
		rLeg = -32,
		lLeg = 28,
		rArm = 36,
		lArm = -34,
		rArmOut = 7,
		lArmOut = 7,
		rArmTwist = -4,
		lArmTwist = 4,
		rLegOut = 3,
		lLegOut = 2,
		head = -3,
		yaw = 3,
		roll = -1,
		lift = 0.07,
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
	name = "Jog",
	length = LENGTH,
	looped = true,
	priority = "Movement",
	hipPivot = 1,
	contact = "feet",
	springs = { rArm = { 8, 0.6 }, lArm = { 8, 0.6 } },
	noise = { pitch = 0.4, head = 0.6, headYaw = 0.8 },
	keys = keys,
}
