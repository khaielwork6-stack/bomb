--!strict
-- TitanRoar (2.7 s, Action). TITAN HUNT: the transformation roar (the chosen player has just grown into the Titan).
-- (The hammer stays on the floor through the hunch: arm angles from titansolve.luau.)
-- 0.00–0.55 gather: it hunches, pulls its arms in and drags in a breath, the left foot lifting.
-- 0.55–0.80 the stomp + explosion: the foot slams down into a wider stance (camera shake / shockwave at 0.62),
--           the torso throws itself back, arms fling wide, the hammer swings up off the floor, head thrown back.
-- 0.80–1.85 THE ROAR: held at full stretch with a tremble running through the whole body.
-- 1.85–2.70 it lowers its head onto the runners, the hammer comes back down onto its head, settles into
--           TitanIdle's opening pose.

local LENGTH = 2.7
local STOMP = 0.62

-- Tremble points between a and b: alternating ± offsets every `dt`, shrinking at the ends.
local function tremble(base: number, amp: number, a: number, b: number, dt: number): { { number } }
	local out = {}
	local t, i = a, 0
	while t <= b + 1e-6 do
		local env = math.sin(math.pi * (t - a) / (b - a))
		table.insert(out, { t, base + (if i % 2 == 0 then 1 else -1) * amp * (0.35 + 0.65 * env) })
		t += dt
		i += 1
	end
	return out
end
local function join(...: { { number } }): { { number } }
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, p in ipairs(list) do
			table.insert(out, p)
		end
	end
	return out
end

return {
	name = "TitanRoar",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { lArm = { 4, 0.6 }, lArmOut = { 4, 0.6 }, rArmOut = { 4, 0.65 }, head = { 7, 0.6 } },
	noSpring = { rArm = true },
	lag = { rArm = 0.04, lArm = 0.06, lArmOut = 0.05, rArmOut = 0.04, head = 0.05 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		pitch = join(
			{ { 0, 5.4 }, { 0.5, 22 }, { STOMP, 18, "hit" }, { 0.8, -15 } },
			tremble(-16, 1.4, 0.88, 1.8, 0.06),
			{ { 2.05, 4 }, { 2.3, 9 }, { LENGTH, 5.4 } }
		),
		roll = { { 0, 0 }, { 0.5, -2 }, { 0.9, 1 }, { 1.8, -1 }, { LENGTH, 0 } },
		yaw = { { 0, -1 }, { 0.5, 4 }, { 0.9, -2 }, { 1.8, 2 }, { LENGTH, -1 } },
		squash = {
			{ 0, 0.021 },
			{ 0.5, 0.09 },
			{ STOMP, 0.16, "hit" },
			{ 0.85, 0.0 },
			{ 1.85, 0.01 },
			{ 2.25, 0.06 },
			{ LENGTH, 0.021 },
		},
		-- head: tucked during the gather, thrown back to roar (shaking), then lowered onto the runners
		head = join(
			{ { 0, -2.5 }, { 0.5, 16 }, { 0.82, -26 } },
			tremble(-27, 2.2, 0.9, 1.8, 0.05),
			{ { 2.05, 6 }, { 2.35, 0 }, { LENGTH, -2.5 } }
		),
		headYaw = { { 0, -5.5 }, { 0.5, 0 }, { 1.85, 0 }, { 2.2, -9 }, { LENGTH, -5.5 } },
		-- arms: drawn in, flung wide, shaking with power, lowered
		lArm = join(
			{ { 0, 1.7 }, { 0.5, -12 }, { 0.84, 28 } },
			tremble(30, 2.5, 0.92, 1.8, 0.07),
			{ { 2.2, 8 }, { LENGTH, 1.7 } }
		),
		lArmOut = join(
			{ { 0, 15 }, { 0.5, 5 }, { 0.84, 76 } },
			tremble(78, 2.5, 0.92, 1.8, 0.07),
			{ { 2.2, 20 }, { LENGTH, 15.2 } }
		),
		lArmTwist = { { 0, -5.6 }, { 0.84, 14 }, { 1.85, 12 }, { LENGTH, -5.6 } },
		-- hammer arm: the hammer swings up and out off the floor, held high, then thuds back down onto its head
		rArm = join(
			{ { 0, 0.03 }, { 0.24, -0.6 }, { 0.32, 0.4 }, { 0.4, 1.7 }, { 0.48, 2.7 }, { 0.56, 3.2 }, { 0.86, 42 } },
			tremble(44, 1.5, 0.94, 1.8, 0.07),
			{ { 2.15, 6 }, { 2.4, -0.6, "hit" }, { LENGTH, 0.03 } }
		),
		rArmOut = join(
			{ { 0, 6.9 }, { 0.5, 4 }, { 0.86, 52 } },
			tremble(54, 2, 0.94, 1.8, 0.07),
			{ { 2.2, 10 }, { LENGTH, 6.9 } }
		),
		rArmTwist = { { 0, 0 }, { 0.86, 10 }, { 1.85, 8 }, { LENGTH, 0 } },
		-- legs: the left foot lifts in the gather and stomps into a wider stance
		lLeg = { { 0, -5 }, { 0.3, 14 }, { 0.5, 46 }, { STOMP, -2, "hit" }, { 1.9, -3 }, { 2.4, -5 }, { LENGTH, -5 } },
		rLeg = { { 0, 5 }, { 0.5, 3 }, { STOMP, 6 }, { LENGTH, 5 } },
		lLegOut = { { 0, 7 }, { 0.5, 5 }, { STOMP, 14, "hit" }, { 1.9, 14 }, { 2.4, 8 }, { LENGTH, 7 } },
		rLegOut = { { 0, 7 }, { STOMP, 10 }, { 1.9, 10 }, { 2.4, 7 }, { LENGTH, 7 } },
		rLegTwist = { { 0, 6 }, { LENGTH, 6 } },
		lLegTwist = { { 0, -6 }, { LENGTH, -6 } },
	},
}
