--!strict
-- Idle (3.6 s loop, in place). Standing relaxed and alive: slow breathing (the chest lifts and settles), a lazy
-- weight shift from foot to foot, arms hanging a little away from the body and swaying with it, and one glance off
-- to the side and back. Nothing repeats in step: the breath, the sway and the glance run on different rhythms, and
-- organic micro-motion sits on top. Brake.luau ends on this clip's first pose. Baked by bake.luau.

local STANCE = { rLegOut = 2.5, lLegOut = 2.5 }

local function key(t: number, pose: { [string]: any }): { [string]: any }
	pose.t = t
	for k, v in pairs(STANCE) do
		pose[k] = pose[k] or v
	end
	return pose
end

return {
	name = "Idle",
	length = 3.6,
	looped = true,
	priority = "Movement",
	contact = "feet",
	hipPivot = 1,
	springs = { rArm = { 4, 0.55 }, lArm = { 4, 0.55 }, head = { 4.5, 0.6 } },
	noise = { pitch = 0.35, roll = 0.35, yaw = 0.5, head = 0.8, headYaw = 1.4, rArm = 0.9, lArm = 0.9 },
	keys = {
		-- Exhale, weight centred.
		key(0.00, { pitch = 1, rArm = 3, lArm = 2, rArmOut = 5, lArmOut = 5, head = 2, squash = 0.02 }),
		-- Inhale: the chest lifts and opens, weight drifting onto the right foot.
		key(0.95, {
			pitch = -0.6,
			rArm = 5,
			lArm = 4,
			rArmOut = 6,
			lArmOut = 6,
			head = 0.5,
			roll = 1.2,
			side = 0.05,
			yaw = -1,
		}),
		-- Exhale and settle on the right foot; the head turns to look off to the left.
		key(1.75, {
			hold = 0.35,
			drift = 0.2,
			pitch = 1.3,
			rArm = 2,
			lArm = 3,
			rArmOut = 5,
			lArmOut = 5,
			head = 3,
			headYaw = 13,
			roll = 1.6,
			side = 0.06,
			yaw = 1.5,
			squash = 0.03,
		}),
		-- Inhale again, weight crossing back over to the left, eyes coming back past centre.
		key(2.75, {
			pitch = -0.3,
			rArm = 4,
			lArm = 5,
			rArmOut = 6,
			lArmOut = 6,
			head = 1,
			headYaw = -4,
			roll = -0.9,
			side = -0.04,
			yaw = -0.5,
			squash = 0.005,
		}),
	},
}
