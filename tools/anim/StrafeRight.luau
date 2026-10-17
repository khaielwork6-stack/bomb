--!strict
-- StrafeRight (0.50 s loop at 60 fps, in place). Omnimovement strafe (v2, 2026-10-08): the body keeps FACING FORWARD
-- while it runs to its right, a light skipping side-run. v1 hit every pose at once with a locked torso and still
-- arms (the user: "stiff"); v2 is built from smooth periodic curves instead of poses: every channel moves all the
-- time, each on its own timing, so the motion overlaps and flows through the cycle.
-- Footfalls (fraction of the loop): right foot lands out to the right 0 → weight rolls onto it (deepest .12) → the
-- left foot closes in under the body .22 as the right knee lifts → the left leg drives off .47 → float .48–.90 (the
-- right leg reaching for the next step) → touch. analyse.luau: the planted foot sits on the floor, the other clears.
-- Leg spread is planned in WORLD angles (how far the foot is out from under its hip) and converted to the joint
-- angle here: the torso's lean into the run tilts the hips with it (raising the left), so it is added back.
-- R6 legs are blocks: spreading one (up to ≈50°) or swinging it a little LOWERS its bottom corner, so the planted
-- leg is always the more spread one, and a lifting leg comes in under its hip with the knee swung forward (> ≈35°).
-- The head counters the torso so the eyes stay level and ahead; the arms open and close with the legs and pump in
-- opposition, trailing the body on loose springs.
-- StrafeLeft.luau is this clip mirrored (mirror.luau). Locomotion blends it with the Run by the angle of travel;
-- its STRAFE_STRIDE (studs per cycle) must match: 20.3 studs/s × 0.50 s ≈ 10.15.

local LENGTH = 30 / 60
local SAMPLES = 24
local TAU = 2 * math.pi

-- A smooth closed curve through { fraction, value } points (the first at 0): periodic Catmull-Rom.
local function periodic(points: { { number } }): (number) -> number
	local n = #points
	local function at(i: number): (number, number)
		local k = (i - 1) % n + 1
		return points[k][1] + (i - k) / n, points[k][2]
	end
	return function(f: number): number
		f %= 1
		local i = 1
		for j = 1, n do
			if points[j][1] <= f then
				i = j
			end
		end
		local fa, va = at(i - 1)
		local f0, v0 = at(i)
		local f1, v1 = at(i + 1)
		local fb, vb = at(i + 2)
		local h = f1 - f0
		local m0 = (v1 - va) / (f1 - fa) * h
		local m1 = (vb - v0) / (fb - f0) * h
		local s = (f - f0) / h
		local s2, s3 = s * s, s * s * s
		return (2 * s3 - 3 * s2 + 1) * v0 + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * v1 + (s3 - s2) * m1
	end
end
local function wave(f: number, mean: number, amp: number, peak: number): number
	return mean + amp * math.cos(TAU * (f - peak))
end
local function bump(f: number, centre: number, half: number): number
	local d = math.abs((f - centre + 0.5) % 1 - 0.5)
	return if d < half then 0.5 * (1 + math.cos(math.pi * d / half)) else 0
end

-- Torso: slow single waves (one swell per cycle), so the body rides the steps instead of ticking through them.
local function roll(f: number): number
	return wave(f, 5.5, 1.1, 0.05) -- leans into the run, most as it lands on the lead foot
end
local function pitch(f: number): number
	return wave(f, 6.8, 1.5, 0.12) -- folds a touch forward into the landing
end
local function yaw(f: number): number
	return wave(f, -7.5, -2.6, 0.12) -- turned toward the travel, most while absorbing
end
local squash = periodic({
	{ 0, 0.04 },
	{ 0.12, 0.1 },
	{ 0.22, 0.05 },
	{ 0.3, 0.06 },
	{ 0.4, 0.02 },
	{ 0.47, 0 },
	{ 0.9, 0 },
	{ 0.95, 0.01 },
})
-- Legs, in WORLD angles: out = how far the foot is out from under its hip, fwd = forward swing (knee-up stand-in).
local rOut = periodic({
	{ 0, 28 },
	{ 0.12, 22 },
	{ 0.22, 12 },
	{ 0.32, 2 },
	{ 0.42, 4 },
	{ 0.55, 30 },
	{ 0.75, 36 },
	{ 0.9, 32 },
})
local rFwd =
	periodic({ { 0, 3 }, { 0.12, 0 }, { 0.22, 10 }, { 0.32, 36 }, { 0.42, 34 }, { 0.55, 14 }, { 0.75, 6 }, { 0.9, 4 } })
local lOut =
	periodic({ { 0, 18 }, { 0.1, 3 }, { 0.2, 11 }, { 0.3, 20 }, { 0.42, 26 }, { 0.55, 28 }, { 0.75, 26 }, { 0.9, 24 } })
local lFwd = periodic({
	{ 0, 10 },
	{ 0.08, 27 },
	{ 0.18, 13 },
	{ 0.3, 0 },
	{ 0.42, -4 },
	{ 0.55, -8 },
	{ 0.75, -6 },
	{ 0.9, -2 },
})

local function pose(f: number): { [string]: number }
	local r, p, y = roll(f), pitch(f), yaw(f)
	return {
		roll = r,
		pitch = p,
		yaw = y,
		squash = squash(f),
		lift = 0.24 * bump(f, 0.69, 0.21),
		side = wave(f, 0, 0.08, 0.6),
		-- The head counters the torso (and trails it, bake.luau lag): eyes level and ahead.
		head = -3 - (p - 6.5) * 0.8,
		headYaw = -y * 0.85,
		-- The torso's roll tilts the legs with it (feet swing toward its left): add it back to keep the world angles.
		rLegOut = rOut(f) + r,
		lLegOut = lOut(f) - r,
		rLeg = rFwd(f),
		lLeg = lFwd(f),
		rLegTwist = wave(f, -4, 2, 0.9),
		lLegTwist = wave(f, 3, 2, 0.4),
		-- Arms: open with the lead leg's reach, close as the legs gather; a light opposite pump.
		rArmOut = wave(f, 17, 9, 0.8),
		lArmOut = wave(f, 9, 7, 0.6), -- the lean already tips this arm out (it rides the high side)
		rArm = wave(f, 0, 16, 0.35),
		lArm = wave(f, 2, 16, 0.85),
		rArmTwist = wave(f, 4, 3, 0.8),
		lArmTwist = wave(f, -4, -3, 0.6),
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
	name = "StrafeRight",
	length = LENGTH,
	looped = true,
	priority = "Movement",
	hipPivot = 1,
	contact = "feet",
	-- Looser arms than the defaults: they swing and settle instead of being placed.
	springs = {
		rArm = { 6, 0.55 },
		lArm = { 6, 0.55 },
		rArmOut = { 6.5, 0.6 },
		lArmOut = { 6.5, 0.6 },
		rLeg = { 11, 0.8 },
		lLeg = { 11, 0.8 },
	},
	noise = { pitch = 0.3, head = 0.4, headYaw = 0.5 },
	keys = keys,
}
