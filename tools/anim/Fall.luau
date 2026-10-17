--!strict
-- Fall (0.90 s loop, Movement priority). Airborne (a jump past its peak, a drop off a ledge, Spring Hop): replaces
-- Roblox's stock arms-up fall. Arms spread wide for balance and paddle in turn, the legs pedal slowly (one reaching
-- down for the floor while the other tucks), the torso tips a touch forward with the head up, scanning ahead.
-- The flight path is the physics', not the clip's: `air` = 1 with `height` = 3 (standing) holds the torso where the
-- character is, so nothing pops when Locomotion blends this in or out.
-- v2 (2026-10-08, "more flowy"): built from continuous waves (like StrafeRight v2) instead of four poses, which the
-- monotone curve eased to a stop at each one; every part cycles on its own phase: the legs pedal, the arms paddle a
-- quarter-beat behind them, the torso sways at half speed, the head counters it.
-- Baked by bake.luau. Rules (analyse.luau): no limb pops; the two sides never move in lockstep.

local LENGTH = 0.90
local SAMPLES = 24
local TAU = 2 * math.pi

-- A wave with its peak at `peak` (fraction of the loop); `n` cycles per loop (default 1).
local function wave(f: number, mean: number, amp: number, peak: number, n: number?): number
	return mean + amp * math.cos(TAU * (n or 1) * (f - peak))
end

local function pose(f: number): { [string]: number }
	return {
		air = 1,
		height = 3,
		-- Torso: a slow sway, tipped a touch forward.
		pitch = wave(f, 6.5, 1.2, 0.1, 2),
		roll = wave(f, 0, 2.2, 0.05),
		yaw = wave(f, 0, 2.5, 0.3),
		-- Head up, countering the sway, scanning.
		head = wave(f, -5.5, -1, 0.15, 2),
		headYaw = wave(f, 0, -3.5, 0.35),
		-- Legs pedal in opposition: one reaching down-forward while the other tucks back.
		rLeg = wave(f, 4, 16, 0),
		lLeg = wave(f, 4, 16, 0.5),
		rLegOut = wave(f, 8.5, 2, 0.25),
		lLegOut = wave(f, 8.5, 2, 0.75),
		rLegTwist = wave(f, 2, 2, 0.1),
		lLegTwist = wave(f, -2, -2, 0.6),
		-- Arms spread for balance, paddling a quarter-beat behind the legs (the high arm on the reaching leg's side).
		rArmOut = wave(f, 66, 6, 0.75),
		lArmOut = wave(f, 66, 6, 0.25),
		rArm = wave(f, 30, 5, 0.25),
		lArm = wave(f, 30, 5, 0.75),
		rArmTwist = wave(f, 11, 2, 0.3),
		lArmTwist = wave(f, -11, -2, 0.8),
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
	name = "Fall",
	length = LENGTH,
	looped = true,
	priority = "Movement",
	contact = "feet",
	hipPivot = 1,
	springs = { rLeg = { 6, 0.7 }, lLeg = { 6, 0.7 }, rArmOut = { 5, 0.55 }, lArmOut = { 5, 0.55 } },
	noise = { rArmOut = 2.5, lArmOut = 2.5, rArm = 2, lArm = 2, head = 0.8, headYaw = 1.5, pitch = 0.5 },
	keys = keys,
}
