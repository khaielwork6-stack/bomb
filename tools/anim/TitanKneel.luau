--!strict
-- TitanKneel (1.6 s loop, Action). TITAN HUNT: the vulnerable phase after TitanSlam. Down on one knee (split kneel,
-- both legs on the floor), the hammer stuck in the ground: it heaves on the handle twice per loop (the torso hauls
-- back, the free arm shoves on the front knee), breathes hard, and glances back over its shoulder at the runners
-- behind it. The weak spot (lower back) sits at ≈6 studs the whole loop: reachable.
-- Starts and loops on TitanSlam's final pose. The hammer arm is solved per frame (titansolve.luau) so the head
-- stays planted in the floor while the body heaves.

local LENGTH = 1.6
local SAMPLES = 32
local TAU = 2 * math.pi

-- A smooth periodic bump centred on `c` (fraction of the loop), `h` wide each side.
local function bump(f: number, c: number, h: number): number
	local d = math.abs((f - c + 0.5) % 1 - 0.5)
	return if d < h then 0.5 * (1 + math.cos(math.pi * d / h)) else 0
end
-- Zero at f = 0 (so the loop starts exactly on the slam's end pose).
local function sw(f: number, amp: number, n: number?): number
	return amp * math.sin(TAU * (n or 1) * f)
end

local function pose(f: number): { [string]: number }
	local tug = bump(f, 0.3, 0.14) + 0.8 * bump(f, 0.74, 0.13) -- two heaves on the handle
	return {
		pitch = 32 - 6 * tug + sw(f, 0.6, 2),
		yaw = 3 - 3 * tug + sw(f, 1.5),
		roll = 1 + 2.2 * tug,
		squash = 0.05 + 0.025 * tug + sw(f, 0.012, 2),
		-- split kneel, both legs on the floor
		lLeg = 78,
		rLeg = -82,
		lLegOut = 18,
		rLegOut = 14,
		rLegTwist = 2,
		lLegTwist = -6,
		-- free arm shoves on the front knee as it heaves
		lArm = 32 + 8 * tug,
		lArmOut = 8 + 6 * tug,
		lArmTwist = -2,
		-- head strains up on each heave and glances back over its right shoulder between them
		head = 12 - 9 * tug + sw(f, 1.2, 2),
		headYaw = -26 * bump(f, 0.52, 0.16) + 14 * bump(f, 0.95, 0.12) - 14 * bump(f, 0.05, 0.12),
		-- hammer arm: placeholder, replaced by the solved track below
		rArm = 28.8,
		rArmOut = 10 + 3 * tug,
		rArmTwist = 2,
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
	name = "TitanKneel",
	length = LENGTH,
	looped = true,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { lArm = { 4, 0.65 }, lArmOut = { 4, 0.7 }, head = { 5, 0.6 }, headYaw = { 4, 0.7 }, pitch = { 8, 0.8 } },
	noSpring = { rArm = true },
	lag = { rArm = 0, head = 0.08, headYaw = 0.1, lArm = 0.05 },
	noise = { head = 0.5, pitch = 0.2 },
	keys = keys,
	tracks = {
		-- solved: the hammer head stays planted in the floor
		rArm = {
			{ 0, 28.7 },
			{ 0.1, 29.2 },
			{ 0.2, 29.5 },
			{ 0.3, 29.4 },
			{ 0.4, 28.0 },
			{ 0.5, 27.0 },
			{ 0.6, 27.1 },
			{ 0.7, 28.3 },
			{ 0.8, 28.8 },
			{ 0.9, 29.0 },
			{ 1.0, 28.7 },
			{ 1.1, 28.1 },
			{ 1.2, 27.4 },
			{ 1.3, 27.2 },
			{ 1.4, 27.7 },
			{ 1.5, 28.1 },
		},
	},
}
