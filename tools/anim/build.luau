--!strict
-- Builds an R6 KeyframeSequence from a clip table (tools/anim/<Name>.luau). Run in Studio's Edit data model
-- (command bar / MCP execute_luau) with the clip table pasted in as `clip`; the result goes to
-- ServerStorage.AnimationSources.<Name> (master) and ReplicatedStorage.CG_AnimPreview.<Name> (play-test preview).
-- Publish the master from the Animation Editor (or AssetService) and put the asset id in Shared/Assets.Anim.
--
-- R6 joint conventions (measured, character facing −Z):
--   RootJoint  X+ pitches the torso forward, Y+ rolls it left, local −Z translation lowers it
--   Right Shoulder / Right Hip  Z+ swings forward;  Left Shoulder / Left Hip  Z− swings forward
--   Neck       X+ tilts the head down
--   Shoulders / hips  X− swings the limb OUTWARD (both sides); applied before the forward swing so a raised arm
--              still spreads instead of rolling in place
-- Limbs hang off the torso, so a world angle w on a torso pitched p is a joint angle of w + p.

local rad = math.rad
local A = CFrame.Angles

-- Names follow the usual tween meaning (CubicOut = fast start, slow end). Roblox's PoseEasingDirection is inverted
-- relative to that (measured: PoseEasingDirection.Out gives a slow start), so the enum values are swapped here.
local EASE = {
	Linear = { Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In },
	CubicOut = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.In },
	CubicIn = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.Out },
	CubicInOut = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut },
	Constant = { Enum.PoseEasingStyle.Constant, Enum.PoseEasingDirection.In },
}

local function pose(parent: Instance, name: string, cf: CFrame, ease: string): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = 1
	local e = EASE[ease] or EASE.Linear
	p.EasingStyle = e[1]
	p.EasingDirection = e[2]
	p.Parent = parent
	return p
end

local function build(clip: any): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = clip.name
	ks.Loop = clip.looped == true
	ks.Priority = (Enum.AnimationPriority :: any)[clip.priority or "Action"]
	for _, k in ipairs(clip.keys) do
		local kf = Instance.new("Keyframe")
		kf.Time = k.t
		local p = k.pitch or 0
		local root = pose(kf, "HumanoidRootPart", CFrame.identity, k.ease)
		local torso = pose(
			root,
			"Torso",
			CFrame.new(0, 0, -(k.drop or 0)) * A(rad(p), rad(-(k.roll or 0)), rad(k.yaw or 0)),
			k.ease
		)
		pose(torso, "Head", A(rad(k.head or 0), 0, 0), k.ease)
		local function limb(swing: number, out: number?): CFrame
			return A(0, 0, rad(swing)) * A(-rad(out or 0), 0, 0)
		end
		pose(torso, "Right Arm", limb((k.rArm or 0) + p, k.rArmOut), k.ease)
		pose(torso, "Left Arm", limb(-((k.lArm or 0) + p), k.lArmOut), k.ease)
		pose(torso, "Right Leg", limb((k.rLeg or 0) + p, k.rLegOut), k.ease)
		pose(torso, "Left Leg", limb(-((k.lLeg or 0) + p), k.lLegOut), k.ease)
		kf.Parent = ks
	end
	return ks
end

return build
