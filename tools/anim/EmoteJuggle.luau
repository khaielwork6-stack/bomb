--!strict
-- EmoteJuggle (2.4 s loop, in place, Action). Emote_Juggle (Asset Bible §8.5): juggling three imaginary mini bombs
-- in a cascade. The hands alternate, one throw every 0.4 s (right at 0.22 / 1.02 / 1.82, left at 0.62 / 1.42 /
-- 2.22): each hand catches on the outside, scoops in, POPS the throw up from the inside (a sharp release) and drops
-- back to wait for the next catch. The eyes follow the bombs: the chin lifts to each apex and the head flicks
-- toward the side the bomb is flying to. The body bounces a little on every throw and leans into the throwing hand.
-- The throws are generated per hand from one cycle (`throwCycle`), so both hands share the same shape and spacing.
-- Baked by bake.luau.

local LENGTH = 2.4
local CYCLE = 0.8 -- each hand throws every 0.8 s; the hands are half a cycle apart
local R_THROWS = { 0.22, 1.02, 1.82 }
local L_THROWS = { 0.62, 1.42, 2.22 }

-- One hand's cycle relative to its throw time T: catch outside → scoop in → throw (sharp peak) → drop → wait.
local SWING = { { -0.22, 31 }, { -0.1, 38 }, { 0, 84, "hit" }, { 0.14, 50 }, { 0.38, 44 } }
local OUT = { { -0.22, 17 }, { -0.1, 6 }, { 0, -7, "hit" }, { 0.14, 2 }, { 0.38, 12 } }

-- Points of one hand's channel over the loop, wrapped into [0, LENGTH) and sorted, with a point at t = 0.
local function throwCycle(throws: { number }, shape: { { any } }): { { any } }
	local pts = {}
	for _, T in ipairs(throws) do
		for _, p in ipairs(shape) do
			local t = (T + p[1]) % LENGTH
			table.insert(pts, { t, p[2], p[3] })
		end
	end
	table.sort(pts, function(a, b)
		return a[1] < b[1]
	end)
	if pts[1][1] > 1e-6 then
		-- Interpolate the seam value between the last point and the first (wrapped).
		local last, first = pts[#pts], pts[1]
		local span = (LENGTH - last[1]) + first[1]
		local a = (LENGTH - last[1]) / span
		table.insert(pts, 1, { 0, last[2] + (first[2] - last[2]) * a })
	else
		pts[1][1] = 0
	end
	return pts
end

-- A value that alternates between `a` (at the right hand's throws) and `b` (at the left hand's) over the loop.
local function alternate(a: number, b: number, offset: number): { { any } }
	local pts = {}
	for i = 0, 5 do
		local t = (0.22 + offset + i * CYCLE / 2) % LENGTH
		table.insert(pts, { t, if i % 2 == 0 then a else b })
	end
	table.sort(pts, function(x, y)
		return x[1] < y[1]
	end)
	local last, first = pts[#pts], pts[1]
	local span = (LENGTH - last[1]) + first[1]
	table.insert(pts, 1, { 0, last[2] + (first[2] - last[2]) * (LENGTH - last[1]) / span })
	return pts
end

-- A little body bounce on every throw (both hands).
local function bounce(down: number, up: number): { { any } }
	local pts = { { 0, up } }
	for i = 0, 5 do
		local t = 0.22 + i * CYCLE / 2
		table.insert(pts, { t, down, "hit" })
		if t + 0.2 < LENGTH then -- (the last one wraps onto the first point)
			table.insert(pts, { t + 0.2, up })
		end
	end
	return pts
end

return {
	name = "EmoteJuggle",
	length = LENGTH,
	looped = true,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	-- Stiffer arms so the 0.1 s pop of each throw keeps its snap (they still drag and overshoot a touch).
	springs = { rArm = { 11, 0.62 }, lArm = { 11, 0.62 }, rArmOut = { 11, 0.65 }, lArmOut = { 11, 0.65 } },
	lag = { rArm = 0.01, lArm = 0.015, rArmOut = 0.01, lArmOut = 0.015, head = 0.07, headYaw = 0.08 },
	noise = { pitch = 0.3, roll = 0.3, head = 0.6, headYaw = 0.8 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		rArm = throwCycle(R_THROWS, SWING),
		rArmOut = throwCycle(R_THROWS, OUT),
		lArm = throwCycle(L_THROWS, SWING),
		lArmOut = throwCycle(L_THROWS, OUT),
		rArmTwist = { { 0, 14 }, { LENGTH, 14 } },
		lArmTwist = { { 0, 14 }, { LENGTH, 14 } },
		-- Eyes on the bombs: chin up at each apex (0.2 s after a throw), down a touch at each throw; the head flicks
		-- toward the hand the bomb is flying to (a right-hand throw crosses to the left).
		head = bounce(-7, -15),
		headYaw = alternate(7, -7, 0.2),
		-- Body: a small bounce on every throw, leaning into the throwing side, a slight lean back to look up.
		squash = bounce(0.06, 0.015),
		pitch = bounce(1, -2.5),
		roll = alternate(2.5, -2.5, 0),
		yaw = alternate(-3, 3, 0.05),
		-- Legs: a relaxed, slightly staggered stance.
		rLeg = { { 0, 3 }, { LENGTH, 3 } },
		lLeg = { { 0, -3 }, { LENGTH, -3 } },
		rLegOut = { { 0, 6 }, { LENGTH, 6 } },
		lLegOut = { { 0, 6 }, { LENGTH, 6 } },
		rLegTwist = { { 0, 5 }, { LENGTH, 5 } },
		lLegTwist = { { 0, 5 }, { LENGTH, 5 } },
	},
}
