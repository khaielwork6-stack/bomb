--!strict
-- EmoteFuseDance (2.4 s loop, in place, Action). Emote_FuseDance (Asset Bible §8.5): a silly bobbing dance at
-- 100 BPM, holding an imaginary lit fuse up in front of the face with the right hand (pinched, jiggling) while the
-- left hand pumps like it's fanning the flame. Four beats per loop (a dip on every beat at 0.3 / 0.9 / 1.5 / 2.1):
--   beat 1 the hips sway right, beat 2 the right knee comes up and STOMPS down,
--   beat 3 the hips sway left, beat 4 the left knee comes up and stomps. The torso swivels on a two-beat
--   rhythm, the head bobs a beat behind the body and keeps its eyes on the fuse.
-- Every part on its own timing (bake.luau `tracks`); the loop starts between beats so no impact sits on the seam.
-- Baked by bake.luau.

local LENGTH = 2.4

return {
	name = "EmoteFuseDance",
	length = LENGTH,
	looped = true,
	priority = "Action",
	contact = "feet",
	hipPivot = 1,
	springs = { rArm = { 9, 0.6 }, lArm = { 7, 0.55 }, head = { 7, 0.55 } },
	noSpring = { rLeg = true, lLeg = true },
	lag = { head = 0.06, headYaw = 0.07 },
	noise = { head = 0.5, rArmTwist = 2 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Bounce: a sharp dip on every beat, up between them.
		squash = {
			{ 0, 0 },
			{ 0.3, 0.13, "hit" },
			{ 0.6, 0 },
			{ 0.9, 0.15, "hit" },
			{ 1.2, 0 },
			{ 1.5, 0.13, "hit" },
			{ 1.8, 0 },
			{ 2.1, 0.15, "hit" },
		},
		-- Body: forward bob on the beat, hips swaying side to side, a two-beat swivel.
		pitch = {
			{ 0, -2 },
			{ 0.3, 7, "hit" },
			{ 0.6, -3 },
			{ 0.9, 10, "hit" },
			{ 1.2, -2 },
			{ 1.5, 7, "hit" },
			{ 1.8, -3 },
			{ 2.1, 10, "hit" },
		},
		-- (The torso tips away from each lifted knee so that hip rises with it, and levels out on the stomp.)
		roll = {
			{ 0, 3 },
			{ 0.3, 7 },
			{ 0.62, -8 },
			{ 0.9, 0, "hit" },
			{ 1.2, -3 },
			{ 1.5, -7 },
			{ 1.82, 8 },
			{ 2.1, 0, "hit" },
		},
		yaw = { { 0, 0 }, { 0.3, 12 }, { 0.9, -12 }, { 1.5, 12 }, { 2.1, -12 } },
		-- Fuse hand: held up in front of the face, pinched; it bobs down on the beat and jiggles.
		rArm = {
			{ 0, 132 },
			{ 0.3, 116, "hit" },
			{ 0.6, 134 },
			{ 0.9, 114, "hit" },
			{ 1.2, 132 },
			{ 1.5, 116, "hit" },
			{ 1.8, 136 },
			{ 2.1, 114, "hit" },
		},
		rArmOut = {
			{ 0, 12 },
			{ 0.3, 20 },
			{ 0.6, 10 },
			{ 0.9, 18 },
			{ 1.2, 12 },
			{ 1.5, 20 },
			{ 1.8, 10 },
			{ 2.1, 18 },
		},
		rArmTwist = { { 0, 0 }, { 0.6, 10 }, { 1.2, -4 }, { 1.8, 10 } },
		-- Free hand: pumps forward-up between beats and back down on them, out wide (fanning the flame).
		lArm = {
			{ 0, 58 },
			{ 0.3, -8, "hit" },
			{ 0.6, 62 },
			{ 0.9, -10, "hit" },
			{ 1.2, 58 },
			{ 1.5, -8, "hit" },
			{ 1.8, 66 },
			{ 2.1, -10, "hit" },
		},
		lArmOut = {
			{ 0, 28 },
			{ 0.3, 16 },
			{ 0.6, 30 },
			{ 0.9, 16 },
			{ 1.2, 28 },
			{ 1.5, 16 },
			{ 1.8, 34 },
			{ 2.1, 16 },
		},
		lArmTwist = { { 0, -6 }, { 0.6, 6 }, { 1.2, -6 }, { 1.8, 8 } },
		-- Head: bobs down on the beat (a beat behind the body), eyes up on the fuse in the right hand.
		head = {
			{ 0, -12 },
			{ 0.3, 3 },
			{ 0.6, -12 },
			{ 0.9, 5 },
			{ 1.2, -12 },
			{ 1.5, 3 },
			{ 1.8, -13 },
			{ 2.1, 5 },
		},
		headYaw = { { 0, -8 }, { 0.3, -16 }, { 0.9, -1 }, { 1.5, -16 }, { 2.1, -1 } },
		-- Legs: the right knee lifts and stomps on beat 2, the left on beat 4; a springy stance between.
		rLeg = { { 0, 1 }, { 0.42, 3 }, { 0.64, 48 }, { 0.9, -3, "hit" }, { 1.2, 1 }, { 1.8, 1 }, { 2.1, -2 } },
		lLeg = { { 0, -2 }, { 0.3, -2 }, { 0.6, 1 }, { 1.2, 1 }, { 1.62, 3 }, { 1.84, 48 }, { 2.1, -3, "hit" } },
		rLegOut = { { 0, 6 }, { 0.42, 6 }, { 0.64, 14 }, { 0.9, 8, "hit" }, { 1.2, 6 } },
		lLegOut = { { 0, 7 }, { 1.2, 6 }, { 1.62, 6 }, { 1.84, 14 }, { 2.1, 8, "hit" } },
		rLegTwist = { { 0, 4 }, { 0.64, 12 }, { 0.9, 4 } },
		lLegTwist = { { 0, -4 }, { 1.84, -12 }, { 2.1, -4 } },
	},
}
