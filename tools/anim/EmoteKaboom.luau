--!strict
-- EmoteKaboom (3.0 s, non-looping, in place, Action). Emote_Kaboom (Asset Bible §8.5): mimes an explosion.
-- 0.00–0.62 the fuse burns: it crouches over its cupped hands (holding the bomb in front of the belly), staring at
--           it, the hands trembling more and more.
-- 0.66–0.84 KABOOM: the hands burst outward into a starfish, the body is blown up and back off its feet (small hop),
--           head thrown back, legs flung wide.
-- 0.84–1.45 the stagger: it lands, rocks back on its heels, a stumbling step back, arms windmilling for balance.
-- 1.45–2.15 dazed: it sways on the spot, head lolling, arms dangling.
-- 2.15–2.55 shakes it off (a quick head shake), and 2.55–3.00 settles into Idle's opening pose.
-- Baked by bake.luau.

local LENGTH = 3.0
local BOOM = 0.66

-- Alternating ± offsets every `dt` between a and b, the amplitude growing from amp0 to amp1 (a fuse burning down).
local function shake(base: number, amp0: number, amp1: number, a: number, b: number, dt: number): { { any } }
	local out = {}
	local t, i = a, 0
	while t <= b + 1e-6 do
		local amp = amp0 + (amp1 - amp0) * (t - a) / (b - a)
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
	name = "EmoteKaboom",
	length = LENGTH,
	looped = false,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = {
		rArm = { 8, 0.55 },
		lArm = { 8, 0.55 },
		rArmOut = { 8, 0.55 },
		lArmOut = { 8, 0.55 },
		head = { 6, 0.45 },
		pitch = { 10, 0.6 },
	},
	lag = { head = 0.06, headYaw = 0.07 },
	noise = { pitch = 0.4, head = 0.8 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: crouch over the bomb, blown up and back, land, rock back, sway, settle.
		squash = {
			{ 0, 0.02 },
			{ 0.38, 0.12 },
			{ 0.6, 0.14 },
			{ BOOM, 0.15 },
			{ 0.84, 0 },
			{ 0.98, 0.14, "hit" },
			{ 1.2, 0.05 },
			{ 1.45, 0.08 },
			{ 2.15, 0.04 },
			{ 2.55, 0.06 },
			{ LENGTH, 0.02 },
		},
		lift = { { 0, 0 }, { BOOM, 0 }, { 0.86, 0.26 }, { 0.98, 0, "hit" }, { LENGTH, 0 } },
		pitch = join(
			{ { 0, 1 }, { 0.38, 24 }, { 0.6, 28 }, { BOOM, 29 }, { 0.8, -20 }, { 1.0, -12 } },
			{ { 1.15, -17 }, { 1.38, -5 }, { 1.6, -8 }, { 2.15, -2 }, { 2.5, 3 }, { LENGTH, 1 } }
		),
		roll = {
			{ 0, 0 },
			{ BOOM, 0 },
			{ 0.8, 3 },
			{ 1.0, -8 },
			{ 1.25, 7 },
			{ 1.5, -5 },
			{ 1.78, 4 },
			{ 2.05, -2.5 },
			{ 2.35, 1 },
			{ LENGTH, 0 },
		},
		yaw = { { 0, 0 }, { BOOM, -2 }, { 0.8, 4 }, { 1.1, -6 }, { 1.4, 5 }, { 1.75, -3 }, { 2.2, 1 }, { LENGTH, 0 } },
		-- Arms: cupped round the bomb in front of the belly (trembling harder as the fuse burns down), burst out into a
		-- starfish, windmill for balance through the stagger, dangle while dazed, settle.
		rArm = join(
			{ { 0, 3 }, { 0.38, 50 } },
			shake(48, 1, 4, 0.42, 0.6, 0.045),
			{ { BOOM, 46 }, { 0.78, -6, "hit" }, { 0.98, -10 }, { 1.12, 40 }, { 1.3, -30 } },
			{ { 1.48, 18 }, { 1.8, 8 }, { 2.15, 4 }, { 2.4, 6 }, { LENGTH, 3 } }
		),
		rArmOut = join(
			{ { 0, 5 }, { 0.38, -34 } },
			shake(-35, 1, 4, 0.42, 0.6, 0.045),
			{ { BOOM, -36 }, { 0.78, 112, "hit" }, { 0.98, 104 }, { 1.12, 70 }, { 1.3, 92 } },
			{ { 1.48, 30 }, { 1.8, 18 }, { 2.15, 12 }, { 2.4, 8 }, { LENGTH, 5 } }
		),
		lArm = join(
			{ { 0, 2 }, { 0.4, 50 } },
			shake(48, 1, 4, 0.44, 0.62, 0.045),
			{ { BOOM, 46 }, { 0.78, -6, "hit" }, { 1.0, -12 }, { 1.16, -34 }, { 1.34, 36 } },
			{ { 1.52, 10 }, { 1.85, 6 }, { 2.15, 3 }, { 2.42, 5 }, { LENGTH, 2 } }
		),
		lArmOut = join(
			{ { 0, 5 }, { 0.4, -34 } },
			shake(-35, 1, 4, 0.44, 0.62, 0.045),
			{ { BOOM, -36 }, { 0.78, 112, "hit" }, { 1.0, 102 }, { 1.16, 84 }, { 1.34, 60 } },
			{ { 1.52, 28 }, { 1.85, 16 }, { 2.15, 12 }, { 2.42, 8 }, { LENGTH, 5 } }
		),
		rArmTwist = { { 0, 0 }, { 0.4, -10 }, { BOOM, -10 }, { 0.78, 18 }, { 1.4, 6 }, { LENGTH, 0 } },
		lArmTwist = { { 0, 0 }, { 0.4, -10 }, { BOOM, -10 }, { 0.78, 18 }, { 1.4, 6 }, { LENGTH, 0 } },
		-- Head: staring down at the bomb, thrown back by the blast, lolling while dazed, a quick shake, settle.
		head = {
			{ 0, 2 },
			{ 0.38, 22 },
			{ BOOM, 26 },
			{ 0.8, -30 },
			{ 1.0, -14 },
			{ 1.3, 4 },
			{ 1.6, 10 },
			{ 1.9, 6 },
			{ 2.15, 8 },
			{ 2.55, 3 },
			{ LENGTH, 2 },
		},
		headYaw = join(
			{ { 0, 0 }, { BOOM, 0 }, { 1.0, 6 }, { 1.45, -12 }, { 1.8, 13 }, { 2.12, -4 } },
			{ { 2.2, 18 }, { 2.28, -18 }, { 2.36, 15 }, { 2.44, -10 }, { 2.55, 3 }, { LENGTH, 0 } }
		),
		-- Legs: braced wide in the crouch, flung out by the blast, a stumbling step back with the right foot, gather.
		rLeg = {
			{ 0, 0 },
			{ 0.38, 10 },
			{ BOOM, 10 },
			{ 0.82, -10 },
			{ 0.98, 4, "hit" },
			{ 1.12, -20 },
			{ 1.3, -14 },
			{ 1.6, -6 },
			{ 2.3, -2 },
			{ LENGTH, 0 },
		},
		lLeg = {
			{ 0, 0 },
			{ 0.38, -9 },
			{ BOOM, -9 },
			{ 0.82, 10 },
			{ 0.98, 6, "hit" },
			{ 1.6, 4 },
			{ 2.3, 1 },
			{ LENGTH, 0 },
		},
		rLegOut = {
			{ 0, 2.5 },
			{ 0.38, 18 },
			{ BOOM, 19 },
			{ 0.82, 22 },
			{ 0.98, 10, "hit" },
			{ 1.6, 7 },
			{ LENGTH, 2.5 },
		},
		lLegOut = {
			{ 0, 2.5 },
			{ 0.38, 18 },
			{ BOOM, 19 },
			{ 0.82, 22 },
			{ 0.98, 10, "hit" },
			{ 1.6, 7 },
			{ LENGTH, 2.5 },
		},
	},
}
