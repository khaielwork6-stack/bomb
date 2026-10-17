--!strict
-- RunnerReady (2.40 s loop, in place). Runners' stance during GET READY: sprinter-ready, hips folded, weight forward.
-- Not a metronome: three bounces of different size and rhythm, a weight shift, and a glance up the field and back,
-- over organic micro-motion. The torso hinges at the hips and the legs never move, so the feet stay planted.
-- Baked by bake.luau (see its header).

local LEGS = { rLeg = -31, lLeg = 23, rLegOut = 2, lLegOut = 3 }

local function key(t: number, pose: { [string]: any }): { [string]: any }
	pose.t = t
	for k, v in pairs(LEGS) do
		pose[k] = v
	end
	return pose
end

return {
	name = "RunnerReady",
	length = 2.40,
	looped = true,
	priority = "Action",
	hipPivot = 1,
	contact = "feet",
	-- Looser arms for the bounce.
	springs = { rArm = { 5.5, 0.5 }, lArm = { 5.5, 0.5 }, head = { 6, 0.55 } },
	noise = { pitch = 0.8, roll = 0.7, yaw = 0.9, head = 1.2, headYaw = 2, rArm = 1.5, lArm = 1.5 },
	keys = {
		-- Folded, eyes up the field, blue arm cocked back.
		key(0.00, { pitch = 52, rArm = -58, lArm = 22, rArmOut = 8, lArmOut = 6, head = -42, roll = -1, yaw = 2 }),
		-- Small bounce.
		key(0.27, { pitch = 41, rArm = -46, lArm = 34, rArmOut = 8, lArmOut = 6, rArmTwist = 6, head = -34, roll = 0 }),
		key(0.52, { pitch = 54, rArm = -60, lArm = 20, rArmOut = 8, lArmOut = 7, head = -43, roll = 1, squash = 0.03 }),
		-- Bigger bounce, light on the feet.
		key(0.80, {
			pitch = 33,
			rArm = -32,
			lArm = 48,
			rArmOut = 7,
			lArmOut = 6,
			rArmTwist = 10,
			lArmTwist = 6,
			head = -26,
			roll = 2,
			headYaw = 3,
			lift = 0.06,
		}),
		-- Deep fold, weight drops onto the front foot.
		key(1.10, {
			pitch = 57,
			rArm = -64,
			lArm = 16,
			rArmOut = 9,
			lArmOut = 7,
			head = -46,
			roll = 3,
			yaw = 3,
			squash = 0.05,
		}),
		-- Half rise while glancing left up the field.
		key(1.42, {
			hold = 0.25,
			drift = 0.1,
			pitch = 46,
			rArm = -50,
			lArm = 28,
			rArmOut = 8,
			lArmOut = 6,
			lArmTwist = 8,
			head = -36,
			headYaw = 18,
			roll = 3,
			yaw = 5,
		}),
		-- Eyes back forward, weight recentres, settle into the fold.
		key(2.02, { pitch = 50, rArm = -54, lArm = 24, rArmOut = 8, lArmOut = 6, head = -40, headYaw = 2, roll = 0 }),
	},
}
