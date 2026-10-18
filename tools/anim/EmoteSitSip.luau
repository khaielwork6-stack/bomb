--!strict
-- EmoteSitSip (3.2 s loop, Action). Emote_SitSip (Asset Bible §8.5): sits on the ground with the legs stretched
-- out, the left hand resting on the thigh, and sips from an imaginary cup held in the right.
-- 0.00–0.85 relaxed: cup held at the chest, a lazy sway.
-- 0.85–1.00 anticipation: the cup dips a touch and the head leans in to meet it.
-- 1.00–1.30 the cup comes up to the lips; 1.30–1.95 the sip: the head tips back, the cup tips up with it, the body
--           leans back.
-- 1.95–2.35 the cup comes down (dragging past the chest a little), a satisfied "ahh": the head drops and the
--           shoulders slump forward.
-- 2.35–3.20 settles, glances off to the left and back.
-- The loop is the sitting pose only: the emote player's fade-in carries the body down from standing.
-- Ground contact uses every part (contact "all"): the legs lie flat (≈90°) so the body sits low on them.
-- Cup-at-the-lips angles solved offline against the head (lune: the hand ≈0.35 studs in front of the mouth).
-- (R6 arms are too short to prop on the floor from a sit, so the free hand rests on the thigh.)
-- Baked by bake.luau.

local LENGTH = 3.2

return {
	name = "EmoteSitSip",
	length = LENGTH,
	looped = true,
	priority = "Action",
	hipPivot = 1,
	springs = { rArm = { 5.5, 0.6 }, rArmOut = { 6, 0.62 }, head = { 5, 0.6 }, pitch = { 7, 0.75 } },
	lag = { head = 0.06, headYaw = 0.08 },
	noise = { pitch = 0.3, roll = 0.4, head = 0.7, headYaw = 1.2, lArm = 0.6 },
	keys = { { t = 0 }, { t = LENGTH } },
	tracks = {
		-- Body: leaning back a little, further for the sip, slumping forward on the "ahh".
		pitch = {
			{ 0, -12 },
			{ 0.85, -11 },
			{ 1.0, -9 },
			{ 1.5, -17 },
			{ 1.95, -18 },
			{ 2.3, -6 },
			{ 2.65, -11 },
		},
		roll = { { 0, -2 }, { 0.8, -3.5 }, { 1.6, -4 }, { 2.3, -1 }, { 2.9, -2.5 } },
		yaw = { { 0, 0 }, { 1.0, -3 }, { 1.95, -4 }, { 2.4, 1 }, { 2.9, 2 } },
		squash = { { 0, 0.02 }, { 1.0, 0.02 }, { 2.3, 0.05 }, { 2.6, 0.02 } },
		-- Cup hand: at the chest, a small dip, up to the lips, tipping up with the sip, back down past the chest.
		rArm = {
			{ 0, 70 },
			{ 0.85, 67 },
			{ 1.0, 63 },
			{ 1.3, 143 },
			{ 1.6, 152 },
			{ 1.95, 158 },
			{ 2.25, 64 },
			{ 2.45, 74 },
			{ 2.8, 70 },
		},
		rArmOut = {
			{ 0, -32 },
			{ 0.85, -30 },
			{ 1.3, -57 },
			{ 1.95, -56 },
			{ 2.25, -28 },
			{ 2.5, -33 },
			{ 2.8, -32 },
		},
		rArmTwist = { { 0, -6 }, { 1.3, -12 }, { 1.95, -18 }, { 2.3, -6 } },
		-- Free hand: resting on the left thigh, drifting lazily.
		lArm = { { 0, 56 }, { 0.6, 58 }, { 1.2, 55 }, { 1.95, 57 }, { 2.4, 54 }, { 2.8, 57 } },
		lArmOut = { { 0, 8 }, { 1.6, 10 }, { 2.4, 7 } },
		lArmTwist = { { 0, -4 }, { LENGTH, -4 } },
		-- Head: looking at the cup, leaning in, tipped back for the sip, the "ahh" drop, a glance to the left.
		head = {
			{ 0, 6 },
			{ 0.85, 7 },
			{ 1.0, 11 },
			{ 1.3, -4 },
			{ 1.6, -14 },
			{ 1.95, -18 },
			{ 2.3, 13 },
			{ 2.6, 4 },
			{ 2.85, 2 },
		},
		headYaw = { { 0, 0 }, { 0.6, 3 }, { 1.0, 0 }, { 2.3, -3 }, { 2.7, 16 }, { 3.0, 10 } },
		-- Legs: lying flat in front (kept level so the body doesn't bob), a little apart, the feet turned out and
		-- the left foot rocking lazily.
		rLeg = { { 0, 91 }, { 1.6, 90.5 } },
		lLeg = { { 0, 90 }, { 1.6, 89.5 } },
		rLegOut = { { 0, 9 }, { LENGTH, 9 } },
		lLegOut = { { 0, 12 }, { 0.8, 14 }, { 1.6, 12 }, { 2.4, 14 } },
		rLegTwist = { { 0, 12 }, { LENGTH, 12 } },
		lLegTwist = { { 0, 12 }, { 1.2, 16 }, { 2.4, 12 } },
	},
}
