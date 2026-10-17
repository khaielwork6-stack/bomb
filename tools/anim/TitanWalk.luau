--!strict
-- TitanWalk (1.6 s loop = 2 steps, Movement priority, in place). TITAN HUNT: the giant's heavy stomp while it
-- hunts. Each swinging leg is lifted HIGH (R6 legs can't bend, so a marching lift is what clears the foot), comes
-- down a little ahead and paws back onto the floor; every landing jolts up the body (squash, pitch nod, head
-- bob a beat later). The weight rolls over the stance leg (side shift + lean), the torso twists against the steps,
-- the free arm swings opposite its leg, and the hammer is carried low just off the floor, swaying with the stride.
-- Feet: right lands at 0, left at 0.5 (gameplay: footstep thud + small camera shake on each).
-- Stride ≈ 13 studs per cycle at the 4x scale (Locomotion-style cadence: playback rate = speed / 13 cycles a second).

local LENGTH = 1.6
local SAMPLES = 48
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
local function wave(f: number, mean: number, amp: number, peak: number, n: number?): number
	return mean + amp * math.cos(TAU * (n or 1) * (f - peak))
end
-- Impact: a sharp rise right after each landing (0 and 0.5) that decays.
local function impact(f: number): number
	local d = (f % 0.5) / 0.5 -- 0..1 through each step
	return math.exp(-d * 9) * math.min(d * 18, 1)
end

-- Right leg: stance 0 → 0.5 sweeping back, swing 0.5 → 1 lifted high, pawing back onto the floor at 1.
local leg = periodic({ { 0, 26 }, { 0.25, 2 }, { 0.5, -22 }, { 0.6, -2 }, { 0.78, 52 }, { 0.91, 36 } })

local function pose(f: number): { [string]: number }
	local hit = impact(f)
	return {
		rLeg = leg(f),
		lLeg = leg(f + 0.5),
		rLegOut = wave(f, 7, 1.5, 0.25),
		lLegOut = wave(f, 7, 1.5, 0.75),
		rLegTwist = 5,
		lLegTwist = -5,
		-- body: nod and sink on each landing, weight over the stance leg, twist against the stride
		pitch = 9 + 2.6 * hit + wave(f, 0, 0.6, 0.25, 2),
		squash = 0.03 + 0.11 * hit,
		side = wave(f, 0, 0.13, 0.22),
		roll = wave(f, 0, 3.5, 0.2),
		yaw = wave(f, 0, -5, 0),
		-- head: steadies the gaze against the twist and nods a beat after each impact
		head = -3 + 2.4 * impact(f - 0.06),
		headYaw = wave(f, 0, 3.6, 0.04),
		-- free arm swings opposite its leg (forward while the left leg is back)
		lArm = wave(f, 4, 20, 0.02),
		lArmOut = wave(f, 14, 3, 0.25, 2),
		lArmTwist = wave(f, -4, 4, 0.02),
		-- hammer carried low, swaying a little with the stride
		rArm = wave(f, 14, 3, 0.55),
		rArmOut = wave(f, 8, 2, 0.3),
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
	name = "TitanWalk",
	length = LENGTH,
	looped = true,
	priority = "Movement",
	contact = "feet",
	hipPivot = 1,
	springs = {
		lArm = { 3.5, 0.65 },
		lArmOut = { 3.5, 0.7 },
		rArm = { 4, 0.75 },
		head = { 6, 0.55 },
	},
	-- The legs follow their curve exactly: a spring made the falling swing leg land late (the stance leg kept the
	-- weight a beat too long).
	lag = { head = 0.06, headYaw = 0.1, lArm = 0.08, rArm = 0.1 },
	noise = { head = 0.4 },
	keys = keys,
}
