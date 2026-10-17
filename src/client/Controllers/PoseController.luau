--!strict
-- Procedural R6 poses layered on top of the default animations by offsetting Motor6D.C0 locally on every client.
-- Asset Bible §6.2. Each pose is a list of keyframes { t, joints } eased with smoothstep; poses expire on their own.
-- Stride layer (2026-10-07, omnimovement): on every player's character, the hips turn toward the line of travel
-- relative to where the body faces (a strafe runs on a diagonal instead of skating sideways; a backward diagonal
-- walks back along its line) and the torso leans into a strafe. Every client drives it for every character from
-- the replicated root velocity and facing, so everyone sees the same legs.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)

local PoseController = {}

local rad = math.rad
local A = CFrame.Angles

type Frame = { t: number, j: { [string]: CFrame } }
-- `override`: joints whose ANIMATION (run, idle…) is faded out while the pose plays (weight 0..1), so a swing
-- isn't mixed with the run cycle's arm pumping. Applied to Motor6D.Transform in Stepped (after the Animator).
type Pose = { duration: number, frames: { Frame }, override: { [string]: number }? }

-- Joint keys: RS/LS = right/left shoulder (Z+ raises arm forward), RH/LH hips (Z+ swings leg forward),
-- NK = neck, RJ = root joint (X+ pitches torso forward).
local POSES: { [string]: Pose } = {
	-- Overhead smash (2026-10-06): a quick wind-up that loads the body (lean back, twist away, left arm out front),
	-- a whip down through the strike at ≈0.2 s with the torso driving into it, an overshoot follow-through and a
	-- springy settle. The weapon (held pointing forward from the fist) arcs from behind the head down in front.
	SwingStrike = {
		duration = 0.52,
		override = { RS = 1, LS = 0.85, NK = 0.6, RJ = 0.55 },
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.06,
				j = {
					RS = A(rad(-12), 0, rad(140)),
					LS = A(0, 0, rad(-35)),
					RJ = A(rad(-8), 0, rad(-12)),
					NK = A(rad(-6), 0, 0),
				},
			},
			{
				t = 0.12,
				j = {
					RS = A(rad(-18), 0, rad(178)),
					LS = A(0, 0, rad(-48)),
					RJ = A(rad(-13), 0, rad(-18)),
					NK = A(rad(-8), 0, rad(-6)),
					RH = A(0, 0, rad(-6)),
				},
			},
			{
				t = 0.2,
				j = {
					RS = A(rad(12), 0, rad(18)),
					LS = A(0, 0, rad(30)),
					RJ = A(rad(17), 0, rad(16)),
					NK = A(rad(10), 0, rad(6)),
					RH = A(0, 0, rad(10)),
					LH = A(0, 0, rad(-8)),
				},
			},
			{
				t = 0.27,
				j = {
					RS = A(rad(16), 0, rad(-12)),
					LS = A(0, 0, rad(38)),
					RJ = A(rad(20), 0, rad(21)),
					NK = A(rad(12), 0, rad(8)),
					RH = A(0, 0, rad(12)),
					LH = A(0, 0, rad(-10)),
				},
			},
			{
				t = 0.38,
				j = {
					RS = A(rad(6), 0, rad(14)),
					LS = A(0, 0, rad(10)),
					RJ = A(rad(6), 0, rad(6)),
					NK = A(rad(3), 0, 0),
				},
			},
			{ t = 0.52, j = {} },
		},
	},
	Dive = {
		duration = 0.95,
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.10,
				j = {
					RJ = A(rad(70), 0, 0),
					RS = A(0, 0, rad(170)),
					LS = A(0, 0, rad(-170)),
					RH = A(0, 0, rad(-20)),
					LH = A(0, 0, rad(20)),
				},
			},
			{ t = 0.35, j = { RJ = A(rad(75), 0, 0), RS = A(0, 0, rad(175)), LS = A(0, 0, rad(-175)) } },
			{ t = 0.65, j = { RJ = A(rad(25), 0, 0), RS = A(0, 0, rad(40)), LS = A(0, 0, rad(-40)) } },
			{ t = 0.95, j = {} },
		},
	},
	DashLean = {
		duration = 0.35,
		frames = {
			{ t = 0, j = {} },
			{ t = 0.06, j = { RJ = A(rad(18), 0, 0), RS = A(0, 0, rad(-30)), LS = A(0, 0, rad(30)) } },
			{ t = 0.25, j = { RJ = A(rad(14), 0, 0), RS = A(0, 0, rad(-25)), LS = A(0, 0, rad(25)) } },
			{ t = 0.35, j = {} },
		},
	},
	-- Fallback only (Assets.Anim.DashBack is set since 2026-10-08; this plays if that clip can't load): the backward
	-- dash (S + dash) hops back still facing ahead — a lean back, arms out front, feet leading.
	DashBack = {
		duration = 0.48,
		override = { RS = 0.85, LS = 0.85, RH = 0.75, LH = 0.75, RJ = 0.5 },
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.06,
				j = {
					RJ = A(rad(-16), 0, 0),
					RS = A(0, 0, rad(55)),
					LS = A(0, 0, rad(-55)),
					RH = A(0, 0, rad(22)),
					LH = A(0, 0, rad(-22)),
				},
			},
			{
				t = 0.3,
				j = {
					RJ = A(rad(-12), 0, 0),
					RS = A(0, 0, rad(42)),
					LS = A(0, 0, rad(-42)),
					RH = A(0, 0, rad(15)),
					LH = A(0, 0, rad(-15)),
				},
			},
			{ t = 0.48, j = {} },
		},
	},
	-- Fallback only (Assets.Anim.Land is set since 2026-10-08): a short dip on landing from a real fall.
	Land = {
		duration = 0.28,
		override = { RS = 0.5, LS = 0.5, RJ = 0.4 },
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.05,
				j = {
					RJ = CFrame.new(0, 0, -0.3) * A(rad(14), 0, 0),
					RH = A(0, 0, rad(16)),
					LH = A(0, 0, rad(-16)),
					RS = A(0, 0, rad(22)),
					LS = A(0, 0, rad(-22)),
				},
			},
			{ t = 0.28, j = {} },
		},
	},
	HardStop = {
		duration = 0.30,
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.06,
				j = {
					RJ = A(rad(-15), 0, 0),
					RS = A(0, 0, rad(60)),
					LS = A(0, 0, rad(-60)),
					RH = A(0, 0, rad(15)),
					LH = A(0, 0, rad(-10)),
				},
			},
			{ t = 0.30, j = {} },
		},
	},
	Slide = {
		duration = 0.75,
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.08,
				j = {
					RJ = A(rad(-55), 0, 0),
					RH = A(0, 0, rad(80)),
					LH = A(0, 0, rad(-20)),
					RS = A(0, 0, rad(-40)),
					LS = A(0, 0, rad(40)),
				},
			},
			{
				t = 0.62,
				j = {
					RJ = A(rad(-50), 0, 0),
					RH = A(0, 0, rad(75)),
					LH = A(0, 0, rad(-15)),
					RS = A(0, 0, rad(-35)),
					LS = A(0, 0, rad(35)),
				},
			},
			{ t = 0.75, j = {} },
		},
	},
	Stumble = {
		duration = 0.5,
		frames = {
			{ t = 0, j = {} },
			{ t = 0.1, j = { RJ = A(rad(10), 0, rad(14)), RS = A(0, 0, rad(70)), LS = A(0, 0, rad(-50)) } },
			{ t = 0.22, j = { RJ = A(rad(6), 0, rad(-12)), RS = A(0, 0, rad(40)), LS = A(0, 0, rad(-80)) } },
			{ t = 0.36, j = { RJ = A(rad(4), 0, rad(8)) } },
			{ t = 0.5, j = {} },
		},
	},
	-- Marble slip (2026-10-07): feet shoot out from under them, a flail in the air, a thud onto their backside
	-- (a little bounce), sitting propped on their hands while the stars spin, then a scramble back up — 2.0 s,
	-- the length of the Slipped status. Owns every joint while it plays. (RootJoint Z lowers the body.)
	Slip = {
		duration = 2.0,
		override = { RS = 1, LS = 1, RH = 1, LH = 1, NK = 1, RJ = 1 },
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.1,
				j = {
					RJ = A(rad(-32), 0, 0),
					RH = A(0, 0, rad(65)),
					LH = A(0, 0, rad(-50)),
					RS = A(0, 0, rad(140)),
					LS = A(0, 0, rad(-120)),
					NK = A(rad(18), 0, 0),
				},
			},
			{
				t = 0.24,
				j = {
					RJ = CFrame.new(0, 0, 0.5) * A(rad(-68), 0, 0),
					RH = A(0, 0, rad(95)),
					LH = A(0, 0, rad(-80)),
					RS = A(0, 0, rad(170)),
					LS = A(0, 0, rad(-160)),
					NK = A(rad(26), 0, 0),
				},
			},
			{
				t = 0.38,
				j = {
					RJ = CFrame.new(0, 0, -1.9) * A(rad(-30), 0, 0),
					RH = A(0, 0, rad(118)),
					LH = A(0, 0, rad(-112)),
					RS = A(0, 0, rad(-30)),
					LS = A(0, 0, rad(30)),
					NK = A(rad(14), 0, 0),
				},
			},
			{
				t = 0.48,
				j = {
					RJ = CFrame.new(0, 0, -1.7) * A(rad(-22), 0, 0),
					RH = A(0, 0, rad(110)),
					LH = A(0, 0, rad(-104)),
					RS = A(0, 0, rad(-34)),
					LS = A(0, 0, rad(34)),
					NK = A(rad(-6), 0, 0),
				},
			},
			{
				t = 0.6,
				j = {
					RJ = CFrame.new(0, 0, -1.85) * A(rad(-18), 0, 0),
					RH = A(0, 0, rad(106)),
					LH = A(0, 0, rad(-100)),
					RS = A(0, 0, rad(-42)),
					LS = A(0, 0, rad(42)),
					NK = A(0, rad(8), 0),
				},
			},
			{
				t = 1.45,
				j = {
					RJ = CFrame.new(0, 0, -1.85) * A(rad(-16), 0, 0),
					RH = A(0, 0, rad(104)),
					LH = A(0, 0, rad(-98)),
					RS = A(0, 0, rad(-40)),
					LS = A(0, 0, rad(40)),
					NK = A(0, rad(-8), 0),
				},
			},
			{
				t = 1.68,
				j = {
					RJ = CFrame.new(0, 0, -0.9) * A(rad(32), 0, 0),
					RH = A(0, 0, rad(72)),
					LH = A(0, 0, rad(-22)),
					RS = A(0, 0, rad(35)),
					LS = A(0, 0, rad(-28)),
					NK = A(rad(-8), 0, 0),
				},
			},
			{
				t = 1.86,
				j = {
					RJ = A(rad(10), 0, 0),
					RH = A(0, 0, rad(16)),
					LH = A(0, 0, rad(-6)),
					RS = A(0, 0, rad(12)),
					LS = A(0, 0, rad(-12)),
				},
			},
			{ t = 2.0, j = {} },
		},
	},
	-- Ground Pound (§14.3): a 0.35 s hop-and-slam. RootJoint C0's Z axis points up, so a Z offset lifts the body.
	PoundHop = {
		duration = 0.5,
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.16,
				j = {
					RJ = CFrame.new(0, 0, 2.2) * A(rad(-10), 0, 0),
					RS = A(0, 0, rad(165)),
					LS = A(0, 0, rad(-165)),
					RH = A(0, 0, rad(25)),
					LH = A(0, 0, rad(-25)),
				},
			},
			{
				t = 0.35,
				j = {
					RJ = CFrame.new(0, 0, -0.6) * A(rad(25), 0, 0),
					RS = A(0, 0, rad(40)),
					LS = A(0, 0, rad(-40)),
					RH = A(0, 0, rad(30)),
					LH = A(0, 0, rad(-30)),
				},
			},
			{ t = 0.5, j = {} },
		},
	},
	-- Brave entrances (§17.1): held through the line-up reveal (ease in, hold, ease out).
	HandsOnHips = {
		duration = 2.4,
		frames = {
			{ t = 0, j = {} },
			{ t = 0.25, j = { RS = A(rad(-40), 0, rad(-12)), LS = A(rad(40), 0, rad(12)), RJ = A(rad(-6), 0, 0) } },
			{ t = 2.1, j = { RS = A(rad(-40), 0, rad(-12)), LS = A(rad(40), 0, rad(12)), RJ = A(rad(-6), 0, 0) } },
			{ t = 2.4, j = {} },
		},
	},
	FistUp = {
		duration = 2.4,
		frames = {
			{ t = 0, j = {} },
			{ t = 0.22, j = { RS = A(0, 0, rad(172)), LS = A(rad(25), 0, rad(-15)), RJ = A(rad(-6), 0, 0) } },
			{ t = 2.1, j = { RS = A(0, 0, rad(172)), LS = A(rad(25), 0, rad(-15)), RJ = A(rad(-6), 0, 0) } },
			{ t = 2.4, j = {} },
		},
	},
	Flex = {
		duration = 2.4,
		frames = {
			{ t = 0, j = {} },
			{ t = 0.25, j = { RS = A(rad(-80), 0, rad(80)), LS = A(rad(80), 0, rad(-80)), RJ = A(rad(-4), 0, 0) } },
			{ t = 1.2, j = { RS = A(rad(-85), 0, rad(95)), LS = A(rad(85), 0, rad(-95)), RJ = A(rad(-4), 0, 0) } },
			{ t = 2.1, j = { RS = A(rad(-80), 0, rad(80)), LS = A(rad(80), 0, rad(-80)), RJ = A(rad(-4), 0, 0) } },
			{ t = 2.4, j = {} },
		},
	},
	Crouch = {
		duration = 2.4,
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.25,
				j = {
					RJ = A(rad(32), 0, 0),
					RH = A(0, 0, rad(45)),
					LH = A(0, 0, rad(-20)),
					RS = A(0, 0, rad(-45)),
					LS = A(0, 0, rad(45)),
				},
			},
			{
				t = 2.1,
				j = {
					RJ = A(rad(32), 0, 0),
					RH = A(0, 0, rad(45)),
					LH = A(0, 0, rad(-20)),
					RS = A(0, 0, rad(-45)),
					LS = A(0, 0, rad(45)),
				},
			},
			{ t = 2.4, j = {} },
		},
	},
	Proud = {
		duration = 2.4,
		frames = {
			{ t = 0, j = {} },
			{
				t = 0.3,
				j = { RJ = A(rad(-8), 0, 0), NK = A(rad(-14), 0, 0), RS = A(0, 0, rad(-18)), LS = A(0, 0, rad(18)) },
			},
			{
				t = 2.1,
				j = { RJ = A(rad(-8), 0, 0), NK = A(rad(-14), 0, 0), RS = A(0, 0, rad(-18)), LS = A(0, 0, rad(18)) },
			},
			{ t = 2.4, j = {} },
		},
	},
	Cheer = {
		duration = 0.9,
		frames = {
			{ t = 0, j = {} },
			{ t = 0.12, j = { RS = A(0, 0, rad(175)), LS = A(0, 0, rad(-175)) } },
			{ t = 0.3, j = { RS = A(0, 0, rad(150)), LS = A(0, 0, rad(-150)) } },
			{ t = 0.48, j = { RS = A(0, 0, rad(175)), LS = A(0, 0, rad(-175)) } },
			{ t = 0.9, j = {} },
		},
	},
}

-- Looping status poses (Asset Bible §6.2), held while the status lasts: t = seconds since the loop began.
local TAU = math.pi * 2
local LOOPS: { [string]: (t: number) -> { [string]: CFrame } } = {
	-- Head roll ±10° at 2 Hz (a slow dizzy circle) with a slight torso sway.
	Dazed = function(t)
		local w = t * TAU * 2
		return {
			NK = A(rad(10) * math.sin(w), rad(10) * math.cos(w), 0),
			RJ = A(0, 0, rad(4) * math.sin(w * 0.5)),
		}
	end,
	-- Arms flail ±30° at 4 Hz, out of phase, around a raised rest.
	Rooted = function(t)
		local w = t * TAU * 4
		return {
			RS = A(0, 0, rad(70) + rad(30) * math.sin(w)),
			LS = A(0, 0, rad(-70) + rad(30) * math.sin(w)),
			RJ = A(rad(-6), 0, 0),
		}
	end,
	-- Arms pinned to the sides by the net, wriggling.
	Tangled = function(t)
		local w = t * TAU * 3
		return {
			RS = A(rad(8) * math.sin(w), 0, rad(-6)),
			LS = A(rad(8) * math.sin(w + math.pi), 0, rad(6)),
			RJ = A(0, 0, rad(5) * math.sin(w * 0.5)),
		}
	end,
}

local JOINTS = {
	RS = { "Torso", "Right Shoulder" },
	LS = { "Torso", "Left Shoulder" },
	RH = { "Torso", "Right Hip" },
	LH = { "Torso", "Left Hip" },
	NK = { "Torso", "Neck" },
	RJ = { "HumanoidRootPart", "RootJoint" },
}

type Active = { pose: Pose, start: number, speed: number }
type Rig = {
	motors: { [string]: Motor6D },
	base: { [string]: CFrame },
	active: { Active },
	loops: { [string]: number }, -- loop name -> start clock
	scale: number, -- the model scale `base` was captured at (Tiny / Giant modes rescale the rig)
	strideYaw: number, -- current hip turn (rad, + = toward the body's left)
	strideLean: number, -- current torso lean (rad, + = leaning left)
	strideBack: boolean, -- moving against the facing (the legs walk back along the line)
	lookYaw: number, -- current head turn (rad, + = toward the body's left)
	lookPitch: number, -- current head tilt (rad, + = up)
	hold: number, -- weapon-hold blend on the right arm (0..1)
}

local rigs: { [Model]: Rig } = {}

local function getRig(model: Model): Rig?
	local rig = rigs[model]
	if rig then
		return rig
	end
	local motors, base = {}, {}
	for key, path in pairs(JOINTS) do
		local part = model:FindFirstChild(path[1])
		local m = part and part:FindFirstChild(path[2])
		if m and m:IsA("Motor6D") then
			motors[key] = m
			base[key] = m.C0
		end
	end
	if not motors.RS then
		return nil
	end
	rig = {
		motors = motors,
		base = base,
		active = {},
		loops = {},
		scale = model:GetScale(),
		strideYaw = 0,
		strideLean = 0,
		strideBack = false,
		lookYaw = 0,
		lookPitch = 0,
		hold = 0,
	}
	rigs[model] = rig
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			rigs[model] = nil
		end
	end)
	return rig
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

local function sample(pose: Pose, t: number): { [string]: CFrame }
	local frames = pose.frames
	for i = 1, #frames - 1 do
		local a, b = frames[i], frames[i + 1]
		if t >= a.t and t <= b.t then
			local alpha = smooth((t - a.t) / math.max(b.t - a.t, 1e-3))
			local out = {}
			for key in pairs(JOINTS) do
				local ca = a.j[key] or CFrame.identity
				local cb = b.j[key] or CFrame.identity
				if a.j[key] or b.j[key] then
					out[key] = ca:Lerp(cb, alpha)
				end
			end
			return out
		end
	end
	return {}
end

-- Uploaded animations replace the procedural pose once their asset id is set in Shared/Assets.Anim (Asset Bible §6.1:
-- "check for an asset first, then fall back to the procedural pose"). Sources live in tools/anim/.
local ANIM_FOR: { [string]: string } = {
	DashLean = "Dash",
	DashLeft = "DashLeft",
	DashRight = "DashRight",
	DashBack = "DashBack",
	Land = "Land",
	Equip = "Equip",
	Slide = "Slide",
	SwingStrike = "Swing",
	Dive = "Dive",
	HardStop = "HardStop",
}
-- Blend in / blend out (seconds). The blend out starts that long before the clip ends, so the last frames dissolve
-- into the run cycle instead of the track cutting off at its final pose.
local FADE: { [string]: { number } } = {
	Dash = { 0.1, 0.24 },
	DashLeft = { 0.08, 0.2 },
	DashRight = { 0.08, 0.2 },
	DashBack = { 0.08, 0.2 },
	Land = { 0.04, 0.12 },
	Equip = { 0.1, 0.2 },
	HardStop = { 0.06, 0.16 },
	Slide = { 0.07, 0.22 },
	Dive = { 0.05, 0.24 },
}
-- How long each clip should take on screen (seconds): the move itself plus its get-up, so the body never holds the
-- pose after the move is over (or lets go of it before). The clip's playback speed is set from its real length.
local M, C = Config.Movement, Config.Movement
-- Blend weight (1 = the clip owns the body; the default). Dash is at 1 too (the user: no running anim while dashing):
-- the soft FADE in / out is what keeps it flowing from and back into the run.
local WEIGHT: { [string]: number } = {
	Dash = 1, -- owns the whole body: no run cycle showing through the burst (blends in/out over FADE.Dash)
	DashLeft = 1,
	DashRight = 1,
	DashBack = 1,
}
local DURATION: { [string]: number } = {
	Dash = M.DASH_TIME + 0.14,
	DashLeft = M.DASH_TIME + 0.14,
	DashRight = M.DASH_TIME + 0.14,
	DashBack = M.DASH_TIME + 0.14,
	Land = 0.3,
	Slide = M.SLIDE_TIME + 0.2,
	Dive = C.DIVE_TIME + C.DIVE_RECOVERY,
}
local DEFAULT_FADE = { 0.08, 0.12 }
local LOOP_FADE_OUT = 0.22 -- a looping stance dissolves into the run instead of popping
-- Loaded tracks per model, held strongly until the model goes away. (A weak Animator key lost bot entries: no
-- client script holds a bot's Animator, so its proxy could be collected while the loop kept playing, and the
-- later "stop" loaded a fresh, idle track and stopped that instead.)
local tracks: { [Model]: { animator: Animator, byId: { [string]: AnimationTrack }, conns: { RBXScriptConnection } } } =
	{}
local plays: { [AnimationTrack]: number } = setmetatable({}, { __mode = "k" }) :: any

local function forget(model: Model)
	local entry = tracks[model]
	if not entry then
		return
	end
	tracks[model] = nil
	for _, c in ipairs(entry.conns) do
		c:Disconnect()
	end
	for _, t in pairs(entry.byId) do
		pcall(t.Stop, t, 0)
	end
end

local function hasAsset(key: string?): boolean
	local id = key and Assets.Anim[key]
	return type(id) == "string" and id ~= ""
end

-- Another player's character: their own client plays uploaded animations on it and those replicate, so playing a
-- second copy here would blend two slightly offset tracks into mush.
local function remoteCharacter(model: Model): boolean
	local owner = Players:GetPlayerFromCharacter(model)
	return owner ~= nil and owner ~= Players.LocalPlayer
end

local function trackFor(model: Model, id: string, looped: boolean): AnimationTrack?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local entry = tracks[model]
	if entry and entry.animator ~= animator then
		forget(model) -- rebuilt rig: tracks on the old Animator are dead
		entry = nil
	end
	if not entry then
		entry = {
			animator = animator,
			byId = {},
			conns = {
				model.Destroying:Connect(function()
					forget(model)
				end),
				model.AncestryChanged:Connect(function(_, parent)
					if parent == nil then
						forget(model)
					end
				end),
			},
		}
		tracks[model] = entry
	end
	local cache = (entry :: any).byId
	local track = cache[id]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, t = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok or not t then
			return nil
		end
		t.Priority = Enum.AnimationPriority.Action
		t.Looped = looped
		cache[id] = t
		track = t
	end
	return track
end

local function playAsset(model: Model, id: string, key: string, speed: number?): boolean
	local t = trackFor(model, id, false)
	if not t then
		return false
	end
	local rate = speed or 1
	local want = DURATION[key]
	if want and t.Length > 0 then
		rate *= t.Length / want
	end
	local fade = FADE[key] or DEFAULT_FADE
	t:Play(fade[1] / rate, WEIGHT[key] or 1, rate)
	local n = (plays[t] or 0) + 1
	plays[t] = n
	if t.Length > 0 then
		task.delay(math.max(t.Length - fade[2], 0) / rate, function()
			if plays[t] == n and t.IsPlaying then
				t:Stop(fade[2])
			end
		end)
	end
	return true
end

-- `speed`: playback rate (the Final Moment Replay plays its puppets' moves in slow motion).
function PoseController.play(model: Model?, name: string, speed: number?)
	if not model then
		return
	end
	local key = ANIM_FOR[name]
	if hasAsset(key) then
		if remoteCharacter(model) or playAsset(model, Assets.Anim[key :: string], key :: string, speed) then
			return
		end
	end
	local pose = POSES[name]
	local rig = getRig(model)
	if not pose or not rig then
		return
	end
	table.insert(rig.active, { pose = pose, start = os.clock(), speed = speed or 1 })
end

-- Start or stop a looping status pose on a model (idempotent).
function PoseController.setLoop(model: Model?, name: string, on: boolean)
	if not model or not LOOPS[name] then
		return
	end
	local rig = if on then getRig(model) else rigs[model]
	if not rig then
		return
	end
	if on then
		rig.loops[name] = rig.loops[name] or os.clock()
	else
		rig.loops[name] = nil
	end
end

-- Start or stop a looping uploaded animation (Shared/Assets.Anim[key]) on a model (idempotent; no-op without an
-- asset or on another player's character, whose own client plays it). Each model starts at a random point of the
-- loop and a slightly different speed, so a line of characters never bobs in unison.
function PoseController.setAnimLoop(model: Model?, key: string, on: boolean)
	if not model or not hasAsset(key) or remoteCharacter(model) then
		return
	end
	local t = trackFor(model, Assets.Anim[key], true)
	if not t then
		return
	end
	if on and not t.IsPlaying then
		t:Play(0.25, 1, 0.92 + math.random() * 0.16)
		if t.Length > 0 then
			t.TimePosition = math.random() * t.Length
		end
	elseif not on then
		if t.IsPlaying then
			t:Stop(LOOP_FADE_OUT)
		end
		PoseController.stopAnimId(model, Assets.Anim[key])
	end
end

-- Stop every playing track of this animation on a model, whoever loaded it (safety net for loops).
function PoseController.stopAnimId(model: Model?, id: string)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator or id == "" then
		return
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local anim = track.Animation
		if anim and anim.AnimationId == id then
			track:Stop(LOOP_FADE_OUT)
		end
	end
end

local MV = Config.Movement
local FLAT = Vector3.new(1, 0, 1)
local STRIDE_MIN = 1.5 -- studs/s: below this the legs straighten back to the facing

-- The stride layer's hip turn and torso lean for one character this frame (eased), seeded into its offsets.
-- Move clips that own the whole body (dashes, slide, dive, hard stop): the stride layer steps aside while one plays,
-- so a side dash isn't twisted by the strafe's hip turn and lean.
local moveClipIds: { [string]: boolean }? = nil
local function moveClipPlaying(hum: Humanoid): boolean
	if not moveClipIds then
		local set = {}
		for _, key in ipairs({ "Dash", "DashLeft", "DashRight", "DashBack", "Slide", "Dive", "HardStop" }) do
			local id = (Assets.Anim :: any)[key]
			if type(id) == "string" and id ~= "" then
				set[id] = true
			end
		end
		moveClipIds = set
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		local a = t.Animation
		if a and (moveClipIds :: any)[a.AnimationId] and t.WeightCurrent > 0.2 then
			return true
		end
	end
	return false
end

-- With the uploaded strafe cycles (Assets.Anim.StrafeLeft / StrafeRight, 2026-10-08) a sideways run is animated
-- by the clips themselves, so the procedural hip turn and lean step aside there (they'd twist the clip); a
-- backward line of travel (the reversed Walk) still gets them.
local strafeAssets: boolean? = nil
local function strafeClips(): boolean
	if strafeAssets == nil then
		strafeAssets = hasAsset("StrafeLeft") and hasAsset("StrafeRight")
	end
	return strafeAssets :: boolean
end
local function isStrafing(look: Vector3, v: Vector3): boolean
	return look.Unit:Dot(v.Unit) > -0.4 -- not walking back
end

local function stride(model: Model, rig: Rig, dt: number, offsets: { [string]: CFrame })
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local yaw, lean = 0, 0
	if
		root
		and hum
		and not root.Anchored
		and hum.Health > 0
		and not hum.PlatformStand
		and not hum.Sit
		and not moveClipPlaying(hum)
	then
		local v = root.AssemblyLinearVelocity * FLAT
		local look = root.CFrame.LookVector * FLAT
		local speed = v.Magnitude
		if speed > STRIDE_MIN and look.Magnitude > 0.1 and not (strafeClips() and isStrafing(look, v)) then
			local l, u = look.Unit, v.Unit
			local cosA = l:Dot(u)
			local sinA = l:Cross(u).Y -- + = moving toward the body's left
			-- Same hysteresis as Locomotion's backpedal (it plays the Walk in reverse past it).
			rig.strideBack = if rig.strideBack then cosA < -0.15 else cosA < -0.4
			local a = math.atan2(sinA, cosA)
			if rig.strideBack then
				a -= if a > 0 then math.pi else -math.pi -- walking back: the legs follow the same line, reversed
			end
			local hipMax = math.rad(MV.STRIDE_HIP_MAX)
			yaw = math.clamp(a, -hipMax, hipMax) * math.clamp((speed - STRIDE_MIN) / 4, 0, 1)
			lean = math.rad(MV.STRIDE_LEAN) * sinA * math.clamp(speed / MV.MAX_SPEED, 0, 1)
		else
			rig.strideBack = false
		end
	end
	local k = 1 - math.exp(-MV.STRIDE_SMOOTH * dt)
	rig.strideYaw += (yaw - rig.strideYaw) * k
	rig.strideLean += (lean - rig.strideLean) * k
	if math.abs(rig.strideYaw) > 1e-3 then
		local hip = CFrame.Angles(0, rig.strideYaw, 0) -- both hips turn about the torso's vertical axis
		offsets.RH = hip
		offsets.LH = hip
	end
	if math.abs(rig.strideLean) > 1e-3 then
		offsets.RJ = CFrame.Angles(0, rig.strideLean, 0) -- the root joint's local Y is the root's back axis: a roll
	end
end

-- Head look (2026-10-08, the user's reference video): the head turns toward where the player's camera looks, on
-- top of the body's facing. Our own character reads MovementController live; other players' heads follow the
-- CG_Look attribute the server relays (Net "Look", ≈10 / s); bots look straight ahead. R6 Neck C0: local Z is the
-- torso's up axis (yaw, + = left), local X its left axis (so a look up is a negative X turn).
local MovementController: any = nil
local function headLook(model: Model, rig: Rig, dt: number, offsets: { [string]: CFrame })
	if not MV.HEAD_LOOK or not rig.motors.NK then
		return
	end
	local yaw, pitch = 0, 0
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and not hum.PlatformStand and not moveClipPlaying(hum) then
		local owner = Players:GetPlayerFromCharacter(model)
		if owner == Players.LocalPlayer then
			MovementController = MovementController or require(script.Parent.MovementController) :: any
			yaw, pitch = MovementController.lookAngles()
		elseif owner then
			local v = model:GetAttribute("CG_Look")
			if typeof(v) == "Vector2" then
				yaw, pitch = v.X, v.Y
			end
		end
	end
	local k = 1 - math.exp(-MV.HEAD_SMOOTH * dt)
	rig.lookYaw += (math.rad(yaw) - rig.lookYaw) * k
	rig.lookPitch += (math.rad(pitch) - rig.lookPitch) * k
	if math.abs(rig.lookYaw) > 1e-3 or math.abs(rig.lookPitch) > 1e-3 then
		offsets.NK = CFrame.Angles(-rig.lookPitch, 0, rig.lookYaw)
	end
end

local function update(dt: number)
	-- Every player's character runs the stride layer, so it needs a rig even when no pose is playing.
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character
		if ch and ch.Parent then
			getRig(ch)
		end
	end
	-- Bots holding a weapon need a rig too (the weapon-hold layer, overrideAnimations).
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") and m:FindFirstChild("CG_Tool") then
				getRig(m)
			end
		end
	end
	local now = os.clock()
	for model, rig in pairs(rigs) do
		-- The rig was rescaled (Tiny / Giant): the joints' rest offsets scale with it. Writing back the old-size
		-- offsets every frame pulled a tiny character's arms and legs away from its body.
		local sc = model:GetScale()
		if math.abs(sc - rig.scale) > 1e-4 then
			local k = sc / rig.scale
			for key, b in pairs(rig.base) do
				rig.base[key] = b - b.Position + b.Position * k
			end
			rig.scale = sc
		end
		local offsets: { [string]: CFrame } = {}
		stride(model, rig, dt, offsets)
		headLook(model, rig, dt, offsets)
		local alive = {}
		for _, a in ipairs(rig.active) do
			local t = (now - a.start) * a.speed
			if t < a.pose.duration then
				table.insert(alive, a)
				for key, cf in pairs(sample(a.pose, t)) do
					offsets[key] = (offsets[key] or CFrame.identity) * cf
				end
			end
		end
		rig.active = alive
		for name, start in pairs(rig.loops) do
			for key, cf in pairs(LOOPS[name](now - start)) do
				offsets[key] = (offsets[key] or CFrame.identity) * cf
			end
		end
		for key, m in pairs(rig.motors) do
			if m.Parent and m.Enabled then
				local target = rig.base[key] * (offsets[key] or CFrame.identity)
				if m.C0 ~= target then
					m.C0 = target
				end
			end
		end
		if #alive == 0 and next(offsets) == nil and model.Parent == nil then
			rigs[model] = nil
		end
	end
end

-- Poses with `override`: fade the animation out of those joints while they play (smooth in over the first
-- 0.07 s, out over the last 0.14 s), so e.g. a swing owns the arms and torso and the run keeps the legs. Runs in
-- Stepped, after the Animator has written this frame's Transforms (writing them earlier would be overwritten).
local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Weapon hold (2026-10-08, the user: "hold the hammer with the arm, facing forward not backwards"): while a
-- character holds its weapon (CG_Tool, Server/Weapons), the right arm keeps a steady hold a little forward instead
-- of pumping with the run — the run's arm swing carried a hammer's head behind the body. Every client applies it
-- to every character (players and bots), so everyone sees the same. The swing / draw / dive clips own the arm
-- while they play.
local HOLD_ARM = CFrame.Angles(0, 0, math.rad(22)) -- RS Transform: the arm raised 22° forward
local HOLD_WEIGHT = 0.85 -- of the hold vs the animation (a touch of the run's motion stays)
local HOLD_SMOOTH = 10 -- 1/s
local armClipIds: { [string]: boolean }? = nil
local function armClipPlaying(hum: Humanoid): boolean
	if not armClipIds then
		local set = {}
		for _, key in ipairs({ "Swing", "Equip", "Dive" }) do
			local id = (Assets.Anim :: any)[key]
			if type(id) == "string" and id ~= "" then
				set[id] = true
			end
		end
		armClipIds = set
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		local a = t.Animation
		if a and (armClipIds :: any)[a.AnimationId] and t.WeightCurrent > 0.15 then
			return true
		end
	end
	return false
end

local lastStep = os.clock()
local function overrideAnimations()
	local now = os.clock()
	local dt = math.clamp(now - lastStep, 0, 0.1)
	lastStep = now
	for model, rig in pairs(rigs) do
		-- Weapon hold on the right arm.
		local rs = rig.motors.RS
		if rs then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local want = 0
			if
				model:FindFirstChild("CG_Tool")
				and hum
				and hum.Health > 0
				and not hum.PlatformStand
				and not armClipPlaying(hum)
			then
				want = HOLD_WEIGHT
			end
			rig.hold += (want - rig.hold) * (1 - math.exp(-HOLD_SMOOTH * dt))
			if rig.hold > 0.01 and rs.Parent and rs.Enabled then
				rs.Transform = rs.Transform:Lerp(HOLD_ARM, rig.hold)
			end
		end
		local weights: { [string]: number }? = nil
		for _, a in ipairs(rig.active) do
			local ov = a.pose.override
			if ov then
				local t = (now - a.start) * a.speed
				local d = a.pose.duration
				local env = smoothstep(0, 0.07, t) * (1 - smoothstep(d - 0.14, d, t))
				if env > 0 then
					weights = weights or {}
					for key, w in pairs(ov) do
						local ws = weights :: { [string]: number }
						ws[key] = math.max(ws[key] or 0, w * env)
					end
				end
			end
		end
		if weights then
			for key, w in pairs(weights) do
				local m = rig.motors[key]
				if m and m.Parent and m.Enabled then
					m.Transform = m.Transform:Lerp(CFrame.identity, math.clamp(w, 0, 1))
				end
			end
		end
	end
end

function PoseController.start()
	RunService:BindToRenderStep("CG_Poses", Enum.RenderPriority.Character.Value + 1, update)
	RunService.Stepped:Connect(overrideAnimations)
	-- Fetch the uploaded action animations up front, so the first dash / stop of a session isn't a no-show.
	task.spawn(function()
		local list = {}
		local keys = { "RunnerReady" }
		for _, key in pairs(ANIM_FOR) do
			table.insert(keys, key)
		end
		for _, key in ipairs(keys) do
			if hasAsset(key) then
				local anim = Instance.new("Animation")
				anim.AnimationId = Assets.Anim[key]
				table.insert(list, anim)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return PoseController
