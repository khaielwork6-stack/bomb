--!strict
-- EmoteVictory (2.8 s, non-looping, in place, Action). Emote_VictoryPose (Asset Bible §8.5): fist pump into a held
-- champion pose.
-- 0.00–0.30 anticipation: a deep crouch, the right fist cocked down and back by the hip, head down.
-- 0.30–0.48 PUMP 1: the fist punches straight up, the body springs up into a little hop, chin up.
-- 0.48–0.64 the fist yanks down to the shoulder ("YES!"), the body lands and sinks.
-- 0.64–0.80 PUMP 2: up again, higher, the feet stamp out into a wide power stance.
-- 0.80–2.80 the held pose: fist high, left fist planted on the hip, chest out, chin up, the whole body breathing
--           and trembling slightly with the effort. Ends on the held pose (the emote player holds or fades it).
-- Baked by bake.luau.

local LENGTH = 2.8
local PUMP1, PUMP2 = 0.46, 0.8

-- Small alternating offsets (a held-with-effort tremble) between a and b.
local function tremble(base: number, amp: number, a: number, b: number, dt: number): { { any } }
	local out = {}
	local t, i = a, 0
	while t <= b + 1e-6 do
		table.insert(out, { t, base + (if i % 2 == 0 then amp else -amp) })
		t += dt
		i += 1
	end
	return out
end
local function join(...: { { any } }): { { any } }
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, p in ipairs(list) do
			table.insert(out, p)
		end
	end
	return out
end

return {
	name = "EmoteVictory",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	-- The punching arm leads on a stiff spring (no drag): the pumps must snap.
	springs = { rArm = { 12, 0.6 }, rArmOut = { 10, 0.62 }, lArm = { 6, 0.6 }, lArmOut = { 6, 0.6 } },
	lag = { rArm = 0, rArmOut = 0.01, head = 0.05 },
	noise = { pitch = 0.35, roll = 0.3, head = 0.7, headYaw = 1.2, lArm = 0.8 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: crouch, hop up on pump 1, land and sink, rise on pump 2 into the wide stance, breathe.
		squash = {
			{ 0, 0.02 },
			{ 0.3, 0.13 },
			{ PUMP1, 0 },
			{ 0.62, 0.14, "hit" },
			{ PUMP2, 0.02 },
			{ 0.95, 0.06 },
			{ 1.6, 0.03 },
			{ 2.2, 0.06 },
			{ LENGTH, 0.03 },
		},
		lift = { { 0, 0 }, { 0.3, 0 }, { PUMP1, 0.32 }, { 0.58, 0, "hit" }, { LENGTH, 0 } },
		pitch = {
			{ 0, 1 },
			{ 0.3, 18 },
			{ PUMP1, -8 },
			{ 0.62, 8 },
			{ PUMP2, -9 },
			{ 1.0, -6 },
			{ 1.6, -8 },
			{ 2.2, -6 },
			{ LENGTH, -7 },
		},
		roll = { { 0, 0 }, { 0.3, 3 }, { PUMP1, -4 }, { 0.62, 1 }, { PUMP2, -5 }, { 1.2, -4 }, { LENGTH, -4.5 } },
		yaw = { { 0, 0 }, { 0.3, -8 }, { PUMP1, 6 }, { 0.62, -2 }, { PUMP2, 7 }, { 1.2, 5 }, { LENGTH, 5 } },
		-- Punching arm: cocked low and back, up, yanked down, up again and held (trembling with effort).
		rArm = join(
			{ { 0, 3 }, { 0.3, -34 }, { PUMP1, 172, "hit" }, { 0.62, 118 }, { PUMP2, 176, "hit" } },
			tremble(170, 1.2, 0.95, 2.6, 0.09),
			{ { LENGTH, 170 } }
		),
		rArmOut = { { 0, 5 }, { 0.3, 12 }, { PUMP1, 14 }, { 0.62, 30 }, { PUMP2, 12 }, { 1.2, 15 }, { LENGTH, 15 } },
		rArmTwist = { { 0, 0 }, { PUMP1, 10 }, { LENGTH, 10 } },
		-- Free arm: swings back with the crouch, out on the hop, then the fist plants on the hip.
		lArm = { { 0, 2 }, { 0.3, -20 }, { PUMP1, 12 }, { 0.62, -8 }, { 0.95, 2 }, { LENGTH, 3 } },
		lArmOut = { { 0, 5 }, { 0.3, 12 }, { PUMP1, 30 }, { 0.62, 22 }, { 0.95, 34 }, { LENGTH, 32 } },
		lArmTwist = { { 0, 0 }, { 0.95, -12 }, { LENGTH, -12 } },
		-- Head: down in the crouch, thrown up with each pump, chin held high.
		head = { { 0, 2 }, { 0.3, 16 }, { PUMP1, -16 }, { 0.62, -2 }, { PUMP2, -18 }, { 1.1, -12 }, { LENGTH, -13 } },
		headYaw = { { 0, 0 }, { 0.3, 4 }, { PUMP1, -6 }, { PUMP2, -10 }, { 1.4, -6 }, { LENGTH, -7 } },
		-- Legs: gather in the crouch, tuck a little in the hop, stamp out wide on pump 2.
		rLeg = { { 0, 0 }, { 0.3, 10 }, { PUMP1, 10 }, { 0.62, 3 }, { PUMP2, 2 }, { LENGTH, 2 } },
		lLeg = { { 0, 0 }, { 0.3, -8 }, { PUMP1, -8 }, { 0.62, -2 }, { PUMP2, -2 }, { LENGTH, -2 } },
		rLegOut = { { 0, 2.5 }, { 0.3, 14 }, { PUMP1, 4 }, { 0.62, 8 }, { PUMP2, 13, "hit" }, { LENGTH, 13 } },
		lLegOut = { { 0, 2.5 }, { 0.3, 14 }, { PUMP1, 4 }, { 0.62, 8 }, { PUMP2, 13, "hit" }, { LENGTH, 13 } },
		rLegTwist = { { 0, 0 }, { PUMP2, 8 }, { LENGTH, 8 } },
		lLegTwist = { { 0, 0 }, { PUMP2, 8 }, { LENGTH, 8 } },
	},
}
