--!strict
-- TitanIdle (3.2 s loop, Movement priority). TITAN HUNT boss (a 4x-scaled R6 in armour, war hammer in the right
-- fist with its head resting on the floor). A giant breathes slowly and heavily: the chest rises and the shoulders
-- open on the in-breath, the body settles and slumps on the out-breath; the torso sways and turns as it scans the
-- arena with the head a beat behind; the free arm hangs and swings a little; the hammer stays down, rocking on its
-- head with the breath. Everything from continuous waves (no poses to stop at), each part on its own phase.
-- Hammer and weak-spot checks: scratchpad titanprobe.luau (hammer head on the floor all loop).

local LENGTH = 3.2
local SAMPLES = 32
local TAU = 2 * math.pi

local function wave(f: number, mean: number, amp: number, peak: number, n: number?): number
	return mean + amp * math.cos(TAU * (n or 1) * (f - peak))
end

-- One breath per loop: in-breath peaks at f = 0.1 (chest up), out-breath settles at 0.6.
local function pose(f: number): { [string]: number }
	return {
		-- Body
		pitch = wave(f, 7, -1.6, 0.1) + wave(f, 0, 0.4, 0.3, 2),
		roll = wave(f, 0, 1.3, 0.25),
		yaw = wave(f, 0, 3.2, 0.7),
		side = wave(f, 0, 0.035, 0.25),
		squash = wave(f, 0.045, -0.03, 0.1),
		-- Head: scans opposite to the torso's turn and later, chin lifting with the in-breath
		head = wave(f, -2, -2.2, 0.15) + wave(f, 0, 0.8, 0.5, 2),
		headYaw = wave(f, 0, -13, 0.82),
		-- Legs: a wide, staggered stance (feet planted: no swing)
		rLeg = 5,
		lLeg = -5,
		rLegOut = 7,
		lLegOut = 7,
		rLegTwist = 6,
		lLegTwist = -6,
		-- Free (left) arm: hangs heavy, opens with the breath, drifts forward and back
		lArm = wave(f, 5, 3.5, 0.55),
		lArmOut = wave(f, 13, 3, 0.12),
		lArmTwist = wave(f, -4, 2, 0.4),
		-- Hammer arm: barely moves (the hammer rests on its head), rocking with the breath
		rArm = wave(f, 1, 1.2, 0.6),
		rArmOut = wave(f, 6, 1.2, 0.12),
		rArmTwist = 0,
	}
end

local keys = {}
for i = 0, SAMPLES - 1 do
	local f = i / SAMPLES
	local k = pose(f)
	k.t = LENGTH * f
	table.insert(keys, k)
end

return {
	name = "TitanIdle",
	length = LENGTH,
	looped = true,
	priority = "Movement",
	contact = "feet",
	hipPivot = 1,
	-- Heavy limbs: slow, well-damped springs (a giant's arm doesn't flick)
	springs = {
		lArm = { 3.5, 0.7 },
		lArmOut = { 3.5, 0.7 },
		rArm = { 4, 0.8 },
		head = { 4, 0.6 },
		headYaw = { 3, 0.7 },
	},
	lag = { head = 0.12, headYaw = 0.18, lArm = 0.1, lArmOut = 0.08 },
	noise = { head = 0.6, headYaw = 1.2, pitch = 0.25 },
	keys = keys,
}
