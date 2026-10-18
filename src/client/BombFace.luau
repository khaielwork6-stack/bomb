--!strict
-- The bomb's face (Asset Bible §3.8): the rig made in art/bomb/face.py, living in ReplicatedStorage.FV_Art.Bomb as
-- MeshParts tagged with attributes — FaceRole (eye / pupil / glint / lid / brow / mouth), FaceSide (L / R),
-- FaceMouth (Smirk / Grimace / Panic / Ooh / Grin), FacePivot (the CFrame it turns about, bomb space) and FaceRest
-- (where it sits at rest, bomb space). Every part only rotates about its pivot, exactly as on the contact sheet:
--   pupils + glints  gaze (toward a target)          lids   slant (out axis) then open/close (horizontal axis)
--   brows            raise (horizontal) then tilt    mouths one shows at a time
-- attach() welds a live rig to a Carrier's bomb (BombController) and update() eases it toward a pose each frame;
-- pose() sets a still pose on an anchored copy (the pass flight, the shop and locker previews).
-- Implements: F-FEEL-01 (the bomb's escalation on its face), Asset Bible §3.8.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local F = Config.Feel
local POSES = F.FACE_POSES

local BombFace = {}

type Pose = { lid: number, slant: number, raise: number, tilt: number, pupil: number, mouth: string }

type FacePart = {
	part: BasePart,
	role: string,
	sgn: number, -- +1 left, −1 right (mirrors slant and tilt)
	mouth: string?,
	pivot: CFrame, -- in the rig's reference frame (the mount for a live rig, bomb space for a still one)
	rest: CFrame,
	weld: Weld?,
	size: Vector3,
}

export type Rig = {
	parts: { FacePart },
	current: { lid: number, slant: number, raise: number, tilt: number, pupil: number },
	mouth: string,
	gaze: { [number]: Vector3 }, -- per side (eye space, unit)
	nextBlink: number,
	blinkUntil: number,
}

local function isFace(d: Instance): boolean
	return d:IsA("BasePart") and type(d:GetAttribute("FaceRole")) == "string"
end
BombFace.isFace = isFace

-- The rotation that turns +Y (straight out of the eye) onto `dir` (eye space).
local function aimFrom(dir: Vector3): CFrame
	local y = Vector3.yAxis
	local d = dir.Unit
	local axis = y:Cross(d)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(y:Dot(d), -1, 1)))
end

-- Keep a gaze inside the eye's range.
local function clampGaze(dir: Vector3): Vector3
	local d = dir.Unit
	local max = math.rad(F.FACE_GAZE_MAX)
	local a = math.acos(math.clamp(d.Y, -1, 1))
	if a <= max then
		return d
	end
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 1e-5 then
		return Vector3.yAxis
	end
	flat = flat.Unit
	return (Vector3.yAxis * math.cos(max) + flat * math.sin(max)).Unit
end

-- A part's offset from its rest place for a pose (in the pivot's own frame), and its size.
local function local_(fp: FacePart, p: Pose, gaze: Vector3?): (CFrame, Vector3)
	local rad = math.rad
	if fp.role == "pupil" then
		-- the meshes come in world-aligned, so a pupil shrinks evenly and rises by as much to stay on the eye
		return aimFrom(gaze or F.FACE_GAZE_IDLE) * CFrame.new(0, (1 - p.pupil) * F.FACE_PUPIL_LIFT, 0),
			fp.size * p.pupil
	elseif fp.role == "glint" then
		-- the glint's offset from the pupil's centre shrinks with the pupil, so it never floats on the white
		local o = rad(F.FACE_GLINT_OFFSET)
		local full = CFrame.fromAxisAngle(Vector3.zAxis, o) * CFrame.fromAxisAngle(Vector3.xAxis, o)
		local now = CFrame.fromAxisAngle(Vector3.zAxis, o * p.pupil) * CFrame.fromAxisAngle(Vector3.xAxis, o * p.pupil)
		return aimFrom(gaze or F.FACE_GAZE_IDLE) * now * full:Inverse(), fp.size
	elseif fp.role == "lid" then
		return CFrame.fromAxisAngle(Vector3.yAxis, rad(p.slant * fp.sgn)) * CFrame.fromAxisAngle(
			Vector3.xAxis,
			rad(p.lid)
		),
			fp.size
	elseif fp.role == "brow" then
		return CFrame.fromAxisAngle(Vector3.xAxis, rad(p.raise)) * CFrame.fromAxisAngle(
			Vector3.yAxis,
			rad(-p.tilt * fp.sgn)
		),
			fp.size
	end
	return CFrame.identity, fp.size
end

-- Where the part goes for a pose: turned about its pivot, from its rest place.
local function placed(fp: FacePart, p: Pose, gaze: Vector3?): (CFrame, Vector3)
	local r, size = local_(fp, p, gaze)
	return fp.pivot * r * fp.pivot:Inverse() * fp.rest, size
end

local function collect(model: Instance, reference: CFrame): { FacePart }
	local out = {}
	local inv = reference:Inverse()
	for _, d in ipairs(model:GetDescendants()) do
		if isFace(d) then
			local part = d :: BasePart
			local pivot = part:GetAttribute("FacePivot")
			local rest = part:GetAttribute("FaceRest")
			if typeof(pivot) == "CFrame" and typeof(rest) == "CFrame" then
				local mouth = part:GetAttribute("FaceMouth")
				table.insert(out, {
					part = part,
					role = part:GetAttribute("FaceRole") :: string,
					sgn = if part:GetAttribute("FaceSide") == "R" then -1 else 1,
					mouth = if type(mouth) == "string" then mouth else nil,
					pivot = inv * pivot,
					rest = inv * rest,
					weld = nil,
					size = part.Size,
				})
			end
		end
	end
	return out
end

local function showMouth(parts: { FacePart }, mouth: string)
	for _, fp in ipairs(parts) do
		if fp.role == "mouth" then
			fp.part.Transparency = if fp.mouth == mouth then 0 else 1
		end
	end
end

-- A still pose on a copy of the bomb that is still in bomb space (call before moving it). `gaze` is eye space.
function BombFace.pose(model: Instance, poseName: string, gaze: Vector3?)
	local p = POSES[poseName] or POSES.SMUG
	local parts = collect(model, CFrame.identity)
	for _, fp in ipairs(parts) do
		local cf, size = placed(fp, p, gaze)
		fp.part.CFrame = cf
		fp.part.Size = size
	end
	showMouth(parts, p.mouth)
end

-- Weld a live rig to `mount`. Call while the model is still in bomb space (before it's pivoted onto a Carrier); the
-- face parts must not have been welded otherwise.
function BombFace.attach(model: Instance, mount: BasePart): Rig?
	local parts = collect(model, mount.CFrame)
	if #parts == 0 then
		return nil
	end
	for _, fp in ipairs(parts) do
		local part = fp.part
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = mount
		weld.Part1 = part
		weld.C0 = fp.rest
		weld.Parent = part
		fp.weld = weld
	end
	local s = POSES.SMUG
	showMouth(parts, s.mouth)
	return {
		parts = parts,
		current = { lid = s.lid, slant = s.slant, raise = s.raise, tilt = s.tilt, pupil = s.pupil },
		mouth = s.mouth,
		gaze = { [1] = F.FACE_GAZE_IDLE.Unit, [-1] = F.FACE_GAZE_IDLE.Unit },
		nextBlink = os.clock() + F.FACE_BLINK_EVERY[1],
		blinkUntil = 0,
	}
end

-- Ease a live rig toward a pose. `target`: a world point to stare at (or nil); `blinks`: blinking allowed now;
-- `shake`: degrees of pupil jitter (CRITICAL).
function BombFace.update(rig: Rig, dt: number, poseName: string, target: Vector3?, blinks: boolean, shake: number)
	local want = POSES[poseName] or POSES.SMUG
	local t = os.clock()
	if blinks and t >= rig.nextBlink then
		rig.blinkUntil = t + F.FACE_BLINK_TIME
		local lo, hi = F.FACE_BLINK_EVERY[1], F.FACE_BLINK_EVERY[2]
		rig.nextBlink = t + lo + math.random() * (hi - lo)
	end
	local k = 1 - math.exp(-F.FACE_BLEND * dt)
	local c = rig.current
	local lidGoal = if t < rig.blinkUntil then F.FACE_BLINK_LID else want.lid
	c.lid += (lidGoal - c.lid) * (if t < rig.blinkUntil then 1 else k) -- a blink snaps shut
	c.slant += (want.slant - c.slant) * k
	c.raise += (want.raise - c.raise) * k
	c.tilt += (want.tilt - c.tilt) * k
	c.pupil += (want.pupil - c.pupil) * k
	if want.mouth ~= rig.mouth then
		rig.mouth = want.mouth
		showMouth(rig.parts, want.mouth)
	end
	local p: Pose = { lid = c.lid, slant = c.slant, raise = c.raise, tilt = c.tilt, pupil = c.pupil, mouth = rig.mouth }
	local jitter = if shake > 0
		then CFrame.Angles(math.rad((math.random() - 0.5) * 2 * shake), 0, math.rad((math.random() - 0.5) * 2 * shake))
		else CFrame.identity
	-- the gaze, once per eye (from the pupil's pivot), eased so the eyes glide onto a target rather than snap
	for _, fp in ipairs(rig.parts) do
		local weld = fp.weld
		if fp.role == "pupil" and weld and weld.Part0 then
			local want_ = F.FACE_GAZE_IDLE.Unit
			if target then
				local d = ((weld.Part0 :: BasePart).CFrame * fp.pivot):PointToObjectSpace(target)
				if d.Magnitude > 1e-3 then
					want_ = clampGaze(d)
				end
			end
			rig.gaze[fp.sgn] = rig.gaze[fp.sgn]:Lerp(want_, k).Unit
		end
	end
	for _, fp in ipairs(rig.parts) do
		local weld = fp.weld
		if weld and fp.role ~= "eye" and fp.role ~= "mouth" then
			local gaze = if fp.role == "pupil" or fp.role == "glint"
				then jitter:VectorToWorldSpace(rig.gaze[fp.sgn]).Unit
				else nil
			local r, size = local_(fp, p, gaze)
			weld.C0 = fp.pivot * r * fp.pivot:Inverse() * fp.rest
			if size ~= fp.part.Size then
				fp.part.Size = size
			end
		end
	end
end

return BombFace
