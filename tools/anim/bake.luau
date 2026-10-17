--!strict
-- R6 animation BAKER (tools/anim). Turns a clip of key poses into a smooth, alive KeyframeSequence:
--   1. Splines: every channel follows a monotone cubic Hermite curve through its keys (velocity flows THROUGH poses,
--      never overshoots a key). Key flags: `hit` = impact (sharp change of direction, separate in/out tangents),
--      `stop` = zero velocity. A key where a channel turns around eases in and out on that channel automatically.
--   2. Secondary motion: arms / head / torso channels trail the body (LAG; left and right differ so limbs never move
--      in lockstep) and ride damped springs, so they drag, overshoot once and settle.
--      Key option `hold = s` makes a moving hold: the pose is reached, eased into, and drifts `drift` (default 0.15)
--      of the way toward the next key over `s` seconds before moving on (readable poses, uneven spacing).
--      Clip option `noise = { [channel] = degrees }` adds smooth organic micro-motion (whole cycles in a loop).
--   3. Grounding: every frame the body height is solved from the real R6 geometry (every part's corners, or only the
--      legs with `contact = "feet"`) so the lowest point sits SINK studs into the floor; `squash` sinks further
--      (weight), `lift` raises the body off the floor (airborne).
--   4. Baked at FPS keyframes with Linear easing (Roblox has nothing left to interpolate).
-- Loops (`looped = true`): the curves are periodic and the springs run to steady state, so the seam is invisible.
--
-- Channels (degrees unless noted; omitted = 0). Angles are WORLD angles as read off a side-view reference sheet:
--   pitch   torso lean forward (+)               roll  torso lean to the character's right (+)
--   yaw     torso turn to the left (+)           fwd / side  body shift forward / right (studs)
--   lift    body raised off the floor (studs)    squash  extra sink into the floor (studs)
--   height, air   airborne flight path: torso-centre height above the floor (studs, standing = 3) and how much it
--                 overrides the grounding solver (0 = grounded, 1 = follows `height`; never sinks below the floor)
--   rPlant / lPlant   0..1 while `air` > 0: that leg is weight-bearing; its swing is solved (stance IK) so its foot
--                 stays on the floor as the body follows `height` (smooth get-ups with rigid legs)
--   head    head tilt down (+) relative to the torso;  headYaw  head turn left (+)
--   rArm / lArm / rLeg / lLeg   limb swing forward (+) / back (−), measured from straight down
--   rArmOut / lArmOut / rLegOut / lLegOut   outward spread of that limb (negative = across the body)
--   rArmTwist / lArmTwist / rLegTwist / lLegTwist   rotation about the limb's own length (+ = turned outward)
-- Clip options: name, length, looped, priority, keys, contact ("all" | "feet"), hipPivot (0..1: 1 = the torso
-- hinges at the hips instead of its centre, so leaning doesn't drag the feet), springs (per-channel overrides
-- { hz, damping }), noSpring ({ [channel] = true }), lag (per-channel overrides, seconds), noise,
-- parts (the limbs written into the clip, default all five: an upper-body clip such as a swing lists only
-- { "Head", "Right Arm", "Left Arm" } so the legs keep running underneath at a lower priority; the Torso is always
-- written, as their parent), noDrop (the torso only rotates, never moves: upper-body clips leave the body's height
-- and position to the locomotion underneath), tracks ({ [channel] = { { t, value, flag? }, ... } }: that channel
-- follows its OWN points instead of the keys, so each part of the body moves on its own timing, the overlapping
-- action that reads as flow: the hips lead, the torso follows, the arms and head trail. Same monotone curve as the
-- keys; flag "hit" / "stop" as on a key; a one-shot's first point eases out of rest; a loop closes on its first
-- point. A clip can be all tracks, with `keys = { { t = 0 }, { t = length } }`).
-- Dash and HardStop were baked with the first version of this file (feet-only contact, no monotone limit).

local rad = math.rad
local A = CFrame.Angles

local FPS = 60
local SINK = 0.12
local CHANNELS = {
	"pitch",
	"roll",
	"yaw",
	"fwd",
	"side",
	"lift",
	"squash",
	"height",
	"air",
	"head",
	"headYaw",
	"rArm",
	"lArm",
	"rArmOut",
	"lArmOut",
	"rLeg",
	"lLeg",
	"rLegOut",
	"lLegOut",
	"rArmTwist",
	"lArmTwist",
	"rLegTwist",
	"lLegTwist",
	"rPlant",
	"lPlant",
}
-- Springs on the "follow" channels: frequency (Hz) and damping ratio (< 1 overshoots). Damped enough to overshoot
-- once and settle; lighter damping rings like rubber, which reads as mechanical.
local SPRINGS: { [string]: { number } } = {
	rArm = { 7.5, 0.58 },
	lArm = { 7.5, 0.58 },
	rArmOut = { 8, 0.6 },
	lArmOut = { 8, 0.6 },
	rArmTwist = { 7, 0.6 },
	lArmTwist = { 7, 0.6 },
	head = { 8, 0.55 },
	headYaw = { 7, 0.6 },
	pitch = { 14, 0.7 },
	roll = { 10, 0.65 },
	yaw = { 10, 0.65 },
}
-- Drag: seconds a channel trails the body's timing. Overlapping action; the two sides differ on purpose.
local LAG: { [string]: number } = {
	rArm = 0.02,
	lArm = 0.035,
	rArmOut = 0.02,
	lArmOut = 0.035,
	rArmTwist = 0.03,
	lArmTwist = 0.045,
	head = 0.045,
	headYaw = 0.06,
}

-- Standard R6 joints (identical on every R6 character): { C0, C1 } per limb, and the box each part occupies
-- (half extents; the head is its visible ~1.2-stud mesh, not its 2×1×1 collision box).
local ROOT_C = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local JOINTS: { [string]: { CFrame } } = {
	Head = { CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	["Right Arm"] = {
		CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	["Left Arm"] = {
		CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	["Right Leg"] = {
		CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	["Left Leg"] = {
		CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
}
local EXTENTS: { [string]: Vector3 } = {
	Torso = Vector3.new(1, 1, 0.5),
	Head = Vector3.new(0.6, 0.6, 0.6),
	["Right Arm"] = Vector3.new(0.5, 1, 0.5),
	["Left Arm"] = Vector3.new(0.5, 1, 0.5),
	["Right Leg"] = Vector3.new(0.5, 1, 0.5),
	["Left Leg"] = Vector3.new(0.5, 1, 0.5),
}
local LEGS = { "Right Leg", "Left Leg" }
local ALL = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local function hermiteChannel(keys: { any }, ch: string, looped: boolean): (number) -> number
	local n = #keys
	local ts, vs = {}, {}
	for i, k in ipairs(keys) do
		ts[i], vs[i] = k.t, k[ch] or 0
	end
	local slope = {}
	for i = 1, n - 1 do
		slope[i] = (vs[i + 1] - vs[i]) / (ts[i + 1] - ts[i])
	end
	local mIn, mOut = {}, {}
	for i = 1, n do
		local k = keys[i]
		local sIn: number? = slope[i - 1]
		local sOut: number? = slope[i]
		if looped then
			-- The last key repeats the first: wrap the neighbouring slopes around the seam.
			sIn = sIn or slope[n - 1]
			sOut = sOut or slope[1]
		end
		if k.stop or (not looped and i == n) then
			mIn[i], mOut[i] = 0, 0
		elseif k.hit then
			mIn[i], mOut[i] = sIn or 0, sOut or 0
		else
			local m
			if sIn and sOut then
				if sIn * sOut <= 0 then
					m = 0 -- the channel turns around here: ease out and back in
				else
					-- Catmull-Rom average, limited (Fritsch–Carlson) so the curve never overshoots its keys.
					local cap = 3 * math.min(math.abs(sIn), math.abs(sOut))
					m = math.clamp((sIn + sOut) / 2, -cap, cap)
				end
			else
				m = sOut or sIn or 0
			end
			mIn[i], mOut[i] = m, m
		end
	end
	return function(t: number): number
		if t <= ts[1] then
			return vs[1]
		elseif t >= ts[n] then
			return vs[n]
		end
		local i = 1
		while ts[i + 1] < t do
			i += 1
		end
		local h = ts[i + 1] - ts[i]
		local s = (t - ts[i]) / h
		local s2, s3 = s * s, s * s * s
		return (2 * s3 - 3 * s2 + 1) * vs[i]
			+ (s3 - 2 * s2 + s) * h * mOut[i]
			+ (-2 * s3 + 3 * s2) * vs[i + 1]
			+ (s3 - s2) * h * mIn[i + 1]
	end
end

-- Damped spring following a target curve (semi-implicit Euler at 480 Hz), sampled at the frame times. A looped clip
-- runs three cycles and keeps the last one (steady state, so the end flows into the start).
local function springChannel(
	target: (number) -> number,
	f: number,
	zeta: number,
	length: number,
	looped: boolean
): (number) -> number
	local w = 2 * math.pi * f
	local k, c = w * w, 2 * zeta * w
	local dt = 1 / 480
	local steps = math.ceil(length / dt)
	local cycles = if looped then 3 else 1
	local y = target(0)
	local v = if looped then 0 else (target(dt) - target(0)) / dt
	local samples = { [0] = y }
	for cycle = 1, cycles do
		if cycle == cycles then
			samples[0] = y
		end
		for i = 1, steps do
			local t = math.min(i * dt, length)
			v += (k * (target(t) - y) - c * v) * dt
			y += v * dt
			if cycle == cycles then
				samples[i] = y
			end
		end
	end
	return function(t: number): number
		local x = math.clamp(t / dt, 0, steps)
		local i0 = math.floor(x)
		local i1 = math.min(i0 + 1, steps)
		local a = x - i0
		return samples[i0] * (1 - a) + samples[i1] * a
	end
end

-- Joint transforms for one frame. RootJoint C0 frame: local X = character left, Y = backward, Z = up.
local function joints(v: { [string]: number }, drop: number, hipPivot: number): { [string]: CFrame }
	local p = v.pitch
	local rot = A(rad(p), rad(-v.roll), rad(v.yaw))
	-- Hinge at the hips: cancel the horizontal travel of the torso's bottom centre caused by the rotation.
	local hip = rot * Vector3.new(0, 0, -1) - Vector3.new(0, 0, -1)
	local function limb(swing: number, out: number, twist: number): CFrame
		return A(0, 0, rad(swing)) * A(-rad(out), 0, 0) * A(0, rad(twist), 0)
	end
	return {
		Torso = CFrame.new(-v.side - hip.X * hipPivot, -v.fwd - hip.Y * hipPivot, -drop) * rot,
		Head = A(rad(v.head), 0, rad(v.headYaw)),
		["Right Arm"] = limb(v.rArm + p, v.rArmOut, v.rArmTwist),
		["Left Arm"] = limb(-(v.lArm + p), v.lArmOut, -v.lArmTwist),
		["Right Leg"] = limb(v.rLeg + p, v.rLegOut, v.rLegTwist),
		["Left Leg"] = limb(-(v.lLeg + p), v.lLegOut, -v.lLegTwist),
	}
end

-- World CFrame of every part for a frame (HumanoidRootPart at the origin, 3 studs up = standing height, facing −Z).
local function world(j: { [string]: CFrame }): { [string]: CFrame }
	local torso = CFrame.new(0, 3, 0) * ROOT_C * j.Torso * ROOT_C:Inverse()
	local cf = { Torso = torso }
	for name, jc in pairs(JOINTS) do
		cf[name] = torso * jc[1] * j[name] * jc[2]:Inverse()
	end
	return cf
end

-- Lowest and highest corner heights of the given parts, plus the lowest corner per part.
local function extent(cf: { [string]: CFrame }, parts: { string }): (number, number, { [string]: number })
	local low, high, per = math.huge, -math.huge, {}
	for _, name in ipairs(parts) do
		local e = EXTENTS[name]
		local pl = math.huge
		for _, x in ipairs({ -1, 1 }) do
			for _, y in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					local h = (cf[name] * Vector3.new(x * e.X, y * e.Y, z * e.Z)).Y
					pl = math.min(pl, h)
					high = math.max(high, h)
				end
			end
		end
		per[name] = pl
		low = math.min(low, pl)
	end
	return low, high, per
end

local Bake = { FPS = FPS, SINK = SINK, CHANNELS = CHANNELS, ALL = ALL, joints = joints, world = world, extent = extent }

-- Moving holds: after a key with `hold`, a copy drifts `drift` of the way toward the next key `hold` seconds later.
-- The monotone tangents then cushion the arrival into the pose and the departure out of it.
-- A channel on its own timing (clip.tracks).
local function trackChannel(points: { { any } }, looped: boolean, length: number): (number) -> number
	local keys = {}
	for i, pt in ipairs(points) do
		keys[i] = { t = pt[1], v = pt[2], hit = pt[3] == "hit", stop = pt[3] == "stop" or (i == 1 and not looped) }
	end
	if looped then
		assert(keys[1].t == 0, "a looped track starts at t = 0")
		if keys[#keys].t < length - 1e-6 then
			table.insert(keys, { t = length, v = keys[1].v })
		end
	end
	return hermiteChannel(keys, "v", looped)
end

local function expandHolds(keys: { any }): { any }
	local out = {}
	for i, k in ipairs(keys) do
		table.insert(out, k)
		local nxt = keys[i + 1]
		if k.hold and k.hold > 0 and nxt and k.t + k.hold < nxt.t then
			local h = table.clone(k)
			h.t, h.hold, h.hit, h.stop = k.t + k.hold, nil, nil, nil
			local drift = k.drift or 0.15
			for _, ch in ipairs(CHANNELS) do
				local a, b = k[ch] or 0, nxt[ch] or 0
				h[ch] = a + (b - a) * drift
			end
			table.insert(out, h)
		end
	end
	return out
end

-- Organic micro-motion: three smooth sines with fixed pseudo-random phases (deterministic per channel). In a loop
-- every frequency is a whole number of cycles per loop, so the seam stays invisible.
local function noiseChannel(amp: number, ch: string, length: number, looped: boolean): (number) -> number
	local seed = 0
	for i = 1, #ch do
		seed = (seed * 31 + string.byte(ch, i)) % 100003
	end
	local comps = {}
	for i = 1, 3 do
		local f = 0.55 + i * 0.85 + ((seed * (i + 3)) % 97) / 240
		if looped then
			f = math.max(1, math.floor(f * length + 0.5)) / length
		end
		local phase = ((seed * (2 * i + 1)) % 628) / 100
		table.insert(comps, { f, phase, amp / i })
	end
	return function(t: number): number
		local s = 0
		for _, c in ipairs(comps) do
			s += c[3] * math.sin(2 * math.pi * c[1] * t + c[2])
		end
		return s
	end
end

function Bake.curves(clip: any): { [string]: (number) -> number }
	local looped = clip.looped == true
	local length = clip.length
	local keys = expandHolds(clip.keys)
	if looped and keys[#keys].t < length - 1e-6 then
		-- Close the loop: the final key is the first one again.
		local seam = table.clone(keys[1])
		seam.t = length
		table.insert(keys, seam)
	end
	local springs = table.clone(SPRINGS)
	for ch, s in pairs(clip.springs or {}) do
		springs[ch] = s
	end
	local lags = table.clone(LAG)
	for ch, l in pairs(clip.lag or {}) do
		lags[ch] = l
	end
	local curves = {}
	for _, ch in ipairs(CHANNELS) do
		local track = clip.tracks and clip.tracks[ch]
		local base = if track then trackChannel(track, looped, length) else hermiteChannel(keys, ch, looped)
		local lag = lags[ch] or 0
		if lag > 0 then
			local f = base
			base = if looped
				then function(t: number): number
					return f((t - lag) % length)
				end
				else function(t: number): number
					return f(math.max(t - lag, 0))
				end
		end
		local s = springs[ch]
		local curve = if s and not (clip.noSpring and clip.noSpring[ch])
			then springChannel(base, s[1], s[2], length, looped)
			else base
		local amp = clip.noise and clip.noise[ch]
		if amp then
			local n, c = noiseChannel(amp, ch, length, looped), curve
			curve = function(t: number): number
				return c(t) + n(t)
			end
		end
		curves[ch] = curve
	end
	return curves
end

-- One frame: joint transforms, the solved drop, the channel values and the world part CFrames.
-- Stance IK: swing a planted leg (keeping the keyed direction) until its lowest corner meets the floor at this body
-- height. R6 legs are rigid, so this is how a weight-bearing leg "bends": the body follows its authored height curve
-- and the leg angle adapts, instead of the leg's cosine reach yanking the body up and down.
local function plantLeg(v: { [string]: number }, drop: number, pivot: number, ch: string, part: string, w: number)
	local keyed = v[ch]
	local sign = if keyed < 0 then -1 else 1
	local function lowAt(m: number): number
		v[ch] = sign * m
		local _, _, per = extent(world(joints(v, drop, pivot)), { part })
		return per[part]
	end
	-- The corner reaches lowest around 14° (a block hinged at its top edge), then rises monotonically with the angle.
	local lo, hi = 14, 115
	if lowAt(lo) > -SINK or lowAt(hi) < -SINK then
		v[ch] = keyed -- can't reach the floor (or can't clear it): leave the keyed angle
		return
	end
	for _ = 1, 22 do
		local mid = (lo + hi) / 2
		if lowAt(mid) < -SINK then
			lo = mid
		else
			hi = mid
		end
	end
	v[ch] = keyed + (sign * (lo + hi) / 2 - keyed) * math.min(w, 1)
end

function Bake.frame(clip: any, curves: { [string]: (number) -> number }, t: number)
	local v: { [string]: number } = {}
	for _, ch in ipairs(CHANNELS) do
		v[ch] = curves[ch](t)
	end
	local pivot = clip.hipPivot or 0
	local parts = if clip.contact == "feet" then LEGS else ALL
	local low = extent(world(joints(v, 0, pivot)), parts)
	local ground = low + SINK + v.squash
	local drop = ground - v.lift
	if v.air > 0 then
		local want = drop + (3 - v.height - drop) * math.min(v.air, 1)
		if v.rPlant > 0.01 then
			plantLeg(v, want, pivot, "rLeg", "Right Leg", v.rPlant)
		end
		if v.lPlant > 0.01 then
			plantLeg(v, want, pivot, "lLeg", "Left Leg", v.lPlant)
		end
		low = extent(world(joints(v, 0, pivot)), parts)
		ground = low + SINK + v.squash
		drop = math.min(want, ground)
	end
	drop = math.clamp(drop, -3, 4)
	local j = joints(v, drop, pivot)
	return j, drop, v, world(j)
end

function Bake.bake(clip: any): KeyframeSequence
	local curves = Bake.curves(clip)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = clip.name
	ks.Loop = clip.looped == true
	ks.Priority = (Enum.AnimationPriority :: any)[clip.priority or "Action"]
	local frames = math.floor(clip.length * FPS + 0.5)
	for f = 0, frames do
		local t = math.min(f / FPS, clip.length)
		local j = Bake.frame(clip, curves, t)
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local function pose(parent: Instance, name: string, cf: CFrame): Pose
			local p = Instance.new("Pose")
			p.Name = name
			p.CFrame = cf
			p.Weight = 1
			p.EasingStyle = Enum.PoseEasingStyle.Linear
			p.Parent = parent
			return p
		end
		local root = pose(kf, "HumanoidRootPart", CFrame.identity)
		local torso = pose(root, "Torso", if clip.noDrop then j.Torso.Rotation else j.Torso)
		for _, part in ipairs(clip.parts or { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }) do
			pose(torso, part, j[part])
		end
		kf.Parent = ks
	end
	return ks
end

return Bake
