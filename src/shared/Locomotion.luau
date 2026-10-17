--!strict
-- Locomotion animation layer (2026-10-06 feel pass), one per character:
--   • Idle + the Run loop (since 2026-10-06 one clip, Assets.Anim.Run, for every speed; with separate Jog / Sprint
--     clips they're blended by speed and phase-locked). Stride length grows with speed, so the cadence follows the
--     ground speed like a real run and the feet never skate.
--   • Brake: when a run stops without a technique (you let go, or a round ends), the body plants, leans back, rocks
--     and settles into the idle.
--   • Fall while airborne (Spring Hop, dropping off a ledge): Assets.Anim.Fall (2026-10-08), else Roblox's stock fall.
--   • Strafe (2026-10-08, Assets.Anim.StrafeLeft / StrafeRight): moving across the body (omnimovement A / D), the
--     side's strafe cycle takes the pose over from the run, blended on a diagonal, its cadence following the speed.
--   • Walk (2026-10-07, Assets.Anim.Walk): slow movement steps instead of skating (it hands over to the Run as the
--     pace builds), and the omnimovement BACKPEDAL plays it in reverse: upright, deliberate steps whose cadence
--     follows the backward speed, so the build-up of a backpedal shows in the legs.
-- The local player's client drives its own character (Animator tracks replicate to everyone); the server drives the
-- bots. Until the custom clips are published (Shared/Assets.Anim empty), it uses Roblox's stock R6 run/idle/fall,
-- or the baked KeyframeSequences in Shared/AnimPreview while play-testing in Studio (tools/anim/out → Rojo).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local Assets = require(script.Parent.Assets)
local Config = require(script.Parent.Config)

local Locomotion = {}
Locomotion.__index = Locomotion

-- Roblox-owned stock R6 animations (fallbacks).
local STOCK = {
	Idle = "rbxassetid://180435571",
	Run = "rbxassetid://180426354",
	Fall = "rbxassetid://180436148",
}

local MOVE_LO, MOVE_HI = 0.6, 3.0 -- studs/s: idle → moving blend band
local JOG_FULL, SPRINT_FULL = 9, 21 -- studs/s: all Jog below, all Sprint above
local JOG_STRIDE, SPRINT_STRIDE = 0.65 * 11, (28 / 60) * 24 -- studs per cycle at each clip's reference pace
local MIN_RATE, MAX_RATE = 1.25, 3.2 -- cycles per second
local SMOOTH = 12 -- weight smoothing (1/s)
local BRAKE_FROM = 14 -- studs/s: a stop from at least this fast plays Brake
local BRAKE_RELEASE = 0.05 -- seconds without input before a let-go counts as a stop
local BRAKE_RATE = 1.15 -- the 0.92 s clip over ≈0.8 s: the plant (deepest lean ≈0.4 s in) lands with the ≈0.3 s stop
local BRAKE_SKIP = 0.03 -- start a hair into the clip (its frame 0 is a full pose) …
local BRAKE_IN = 0.14 -- … and blend into it this long, so the run flows into the plant
local BRAKE_FADE = 0.36 -- the clip's whole settle (from ≈0.53 s in) dissolves into the idle, never its zero pose
local BRAKE_LIGHT = 0.72 -- weight of the plant for a stop from BRAKE_FROM (full weight from top speed)
local AIR_DELAY = 0.12 -- seconds off the ground before the fall pose blends in
-- Backpedal: the body moves against its facing → the Walk plays in reverse (the run clip reversed without one).
-- Hysteresis keeps it from flickering on a diagonal.
local BACK_ENTER, BACK_LEAVE = -0.4, -0.15 -- forward.facing dot
local BACK_STRIDE = 0.85 -- (no Walk clip) a backward run-stride is shorter
-- Walk pacing: studs of ground per walk cycle (two steps). A full-pace backpedal (≈10.5 studs/s) steps every ≈0.38 s
-- like the reference; its slow first steps come slower still.
local WALK_STRIDE = 6.0
local WALK_MIN_RATE, WALK_MAX_RATE = 0.55, 1.9 -- cycles per second (forward)
-- Backpedal cadence (2026-10-07, the user: the backward walk is ONLY the Walk clip, reversed, just quicker as the
-- pace builds): cycles per second = BACK_RATE_BASE + speed × BACK_RATE_PER, capped — a slow first step (≈0.9 / s)
-- up to a calm-but-brisk ≈1.75 / s at a full-pace backpedal (≈19 studs/s): the arms never flail.
-- 2026-10-08: the backpedal got faster (≈22 studs/s, Config BACK_SPEED_FRAC), so the cap rose to keep the feet
-- from skating: ≈2.2 cycles / s at full pace.
local BACK_RATE_BASE, BACK_RATE_PER, BACK_RATE_MAX = 0.6, 0.075, 2.2
local WALK_FULL, RUN_FULL = 6, 11 -- studs/s going forward: all Walk below, all Run above
-- Strafe cycles (2026-10-08): the side component of the line of travel (0 = straight ahead, 1 = straight across the
-- body) at which a strafe clip starts taking over, and owns the pose; the clips' own pace (playback 1, studs/s:
-- the omnimovement strafe pace, Config SIDE_SPEED_FRAC × MAX_SPEED) and playback-rate limits.
local STRAFE_FROM, STRAFE_FULL = 0.35, 0.85
local STRAFE_PACE = 20
local STRAFE_MIN_RATE, STRAFE_MAX_RATE = 0.55, 1.5

export type Loco = typeof(setmetatable(
	{} :: {
		animator: Animator,
		tracks: { [string]: AnimationTrack },
		custom: boolean,
		weights: { [string]: number },
		phase: number,
		peak: number,
		airFor: number,
		back: boolean,
		movedAhead: boolean,
		brakeEnding: boolean,
		released: number,
		resync: number,
		offPace: number,
		alive: boolean,
		stride: number?, -- a variant's own cadence (studs per cycle) and cycle-rate band
		minRate: number,
		maxRate: number,
	},
	Locomotion
))

-- Studio play-tests: an unpublished clip can still be previewed from Shared/AnimPreview.<Key> (baked rbxm).
local previewIds: { [string]: string } = {}
local function animId(key: string): string?
	local id = (Assets.Anim :: any)[key]
	if type(id) == "string" and id ~= "" then
		return id
	end
	if not RunService:IsStudio() then
		return nil
	end
	if previewIds[key] then
		return previewIds[key]
	end
	local folder = script.Parent:FindFirstChild("AnimPreview")
	local ks = folder and folder:FindFirstChild(key)
	if ks and ks:IsA("KeyframeSequence") then
		local ok, temp = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
		end)
		if ok and type(temp) == "string" then
			previewIds[key] = temp
			return temp
		end
	end
	return nil
end

-- (Shared with TitanController: the boss clips resolve the same way, published id or Studio preview.)
Locomotion.animId = animId

local function load(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Variants: "Titan" (TITAN HUNT, Config.Titan): the giant's own idle and walk (one clip for every speed, its cadence
-- by the long stride), no strafes / brake / walk blend.
local TITAN_MIN_RATE, TITAN_MAX_RATE = 0.35, 4.2 -- cycles per second (the top end for a CHARGE)

function Locomotion.new(humanoid: Humanoid, variant: string?): Loco?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		if not RunService:IsServer() then
			return nil
		end
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local a = animator :: Animator
	local M = Enum.AnimationPriority.Movement
	local tracks: { [string]: AnimationTrack } = {}
	local titan = variant == "Titan"
	local idle, jog, sprint = animId("Idle"), animId("Jog"), animId("Sprint")
	if titan then
		idle, jog = animId("TitanIdle") or idle, animId("TitanWalk") or jog
		sprint = jog
	end
	local custom = jog ~= nil and sprint ~= nil
	tracks.Idle = load(a, idle or STOCK.Idle, M, true) :: AnimationTrack
	if custom then
		tracks.Jog = load(a, jog :: string, M, true) :: AnimationTrack
		-- One Run clip for every speed (Jog = Sprint): a single track, its cadence still opening up with speed.
		if sprint ~= jog then
			tracks.Sprint = load(a, sprint :: string, M, true) :: AnimationTrack
		end
	else
		tracks.Run = load(a, STOCK.Run, M, true) :: AnimationTrack
	end
	tracks.Fall = load(a, animId("Fall") or STOCK.Fall, M, true) :: AnimationTrack
	local walk = if titan then nil else animId("Walk")
	if walk and custom then
		tracks.Walk = load(a, walk, M, true) :: AnimationTrack
	end
	-- Strafe cycles (2026-10-08): blended in by how far the line of travel swings across the body (omnimovement A / D).
	local strafeL, strafeR = animId("StrafeLeft"), animId("StrafeRight")
	if strafeL and strafeR and custom and not titan then
		tracks.StrafeL = load(a, strafeL, M, true) :: AnimationTrack
		tracks.StrafeR = load(a, strafeR, M, true) :: AnimationTrack
	end
	local brake = if titan then nil else animId("Brake")
	if brake then
		tracks.Brake = load(a, brake, Enum.AnimationPriority.Action, false) :: AnimationTrack
	end
	local weights: { [string]: number } = {}
	for key, t in pairs(tracks) do
		if key ~= "Brake" then
			-- Every loop runs all the time at its blend weight (a near-zero weight costs nothing and keeps phase).
			t:Play(0, if key == "Idle" then 1 else 0.001, 1)
			weights[key] = if key == "Idle" then 1 else 0
		end
	end
	local self = setmetatable({
		animator = a,
		tracks = tracks,
		custom = custom,
		weights = weights,
		phase = 0,
		peak = 0,
		airFor = 0,
		back = false,
		movedAhead = true,
		brakeEnding = false,
		released = 0,
		resync = 0,
		offPace = 0,
		alive = true,
		stride = if titan then Config.Movement.GIANT_STRIDE else nil,
		minRate = if titan then TITAN_MIN_RATE else MIN_RATE,
		maxRate = if titan then TITAN_MAX_RATE else MAX_RATE,
	}, Locomotion)
	return self
end

-- speed: horizontal ground speed (studs/s). hasInput: the character is being steered (a release from a run brakes).
-- grounded: standing on something. busy: a technique / ragdoll / emote owns the body (no Brake, no fall).
-- timeScale: slow motion (the Final Moment Replay plays at 0.4×); speeds are in game units either way.
-- forward: how the body moves relative to where it faces (1 ahead, -1 straight back); omit for always ahead.
-- side: the same across the body (1 straight to its right, -1 to its left); omit for none (bots face their motion).
function Locomotion.update(
	self: Loco,
	dt: number,
	speed: number,
	hasInput: boolean,
	grounded: boolean,
	busy: boolean,
	timeScale: number?,
	forward: number?,
	side: number?
)
	if not self.alive then
		return
	end
	local ts = timeScale or 1
	if self.animator.Parent == nil then
		self:destroy()
		return
	end
	dt = math.clamp(dt, 0, 0.1)
	local tracks = self.tracks
	-- Airborne for a moment → fall pose.
	self.airFor = if grounded or busy then 0 else self.airFor + dt
	local air = smoothstep(AIR_DELAY, AIR_DELAY + 0.15, self.airFor)
	local moving = smoothstep(MOVE_LO, MOVE_HI, speed)
	local sprint = smoothstep(JOG_FULL, SPRINT_FULL, speed)
	local f = forward or 1
	if self.back then
		self.back = f < BACK_LEAVE and speed > MOVE_LO
	else
		self.back = f < BACK_ENTER and speed > MOVE_HI
	end
	if self.back then
		sprint = 0 -- backpedalling is a jog at any speed
	end
	-- Which way the last real run went (kept through the slow-down): only a run AHEAD plants into the Brake (a stop out
	-- of a backpedal or a strafe would skid or lean the wrong way).
	if speed > MOVE_HI then
		self.movedAhead = not self.back and f > 0.5
	end
	local want: { [string]: number } = { Idle = (1 - moving) * (1 - air), Fall = air }
	-- The Walk's share of the moving pose: all of a backpedal; going forward, the slow end of a start or stop.
	local walkShare = 0
	local walkTrack = tracks.Walk
	if walkTrack then
		walkShare = if self.back then 1 else 1 - smoothstep(WALK_FULL, RUN_FULL, speed)
	end
	-- Strafing: as the line of travel swings across the body, the strafe cycle for that side takes the pose over
	-- from the run / walk (a diagonal blends the two). Not while backpedalling: that's the reversed Walk's.
	local strafeL, strafeR = 0, 0
	if tracks.StrafeR and tracks.StrafeL then
		if not self.back then
			local s = side or 0
			strafeR = smoothstep(STRAFE_FROM, STRAFE_FULL, s)
			strafeL = smoothstep(STRAFE_FROM, STRAFE_FULL, -s)
		end
		-- (Always written, so a strafe that turns into a backpedal fades its clip out.)
		want.StrafeR = moving * strafeR * (1 - air)
		want.StrafeL = moving * strafeL * (1 - air)
	end
	local ahead = 1 - strafeL - strafeR
	if walkTrack then
		want.Walk = moving * walkShare * ahead * (1 - air)
	end
	local runShare = (1 - walkShare) * ahead
	if self.custom and not tracks.Sprint then
		want.Jog = moving * runShare * (1 - air) -- the single Run clip covers every speed
	elseif self.custom then
		want.Jog = moving * (1 - sprint) * runShare * (1 - air)
		want.Sprint = moving * sprint * runShare * (1 - air)
	else
		want.Run = moving * (1 - air)
	end
	-- Strafe cadence follows the ground speed (playback 1 at the strafe pace the clips were made for).
	if tracks.StrafeR and tracks.StrafeL then
		local rate = math.clamp(speed / STRAFE_PACE, STRAFE_MIN_RATE, STRAFE_MAX_RATE) * ts
		tracks.StrafeR:AdjustSpeed(rate)
		tracks.StrafeL:AdjustSpeed(rate)
	end
	local k = 1 - math.exp(-SMOOTH * dt)
	for key, w in pairs(want) do
		local t = tracks[key]
		if t then
			local cur = self.weights[key] or 0
			cur += (w - cur) * k
			self.weights[key] = cur
			t:AdjustWeight(math.max(cur, 0.001), 0)
		end
	end
	-- Walk cadence follows the ground speed (in reverse for a backpedal).
	if walkTrack and walkTrack.Length > 0 then
		local rate = if self.back
			then math.min(BACK_RATE_BASE + speed * BACK_RATE_PER, BACK_RATE_MAX)
			else math.clamp(speed / WALK_STRIDE, WALK_MIN_RATE, WALK_MAX_RATE)
		walkTrack:AdjustSpeed(rate * walkTrack.Length * ts * (if self.back then -1 else 1))
	end
	-- Cadence: stride length grows with speed, so the legs keep pace with the ground.
	if self.custom then
		local stride = (self.stride or (JOG_STRIDE + (SPRINT_STRIDE - JOG_STRIDE) * sprint))
			* (if self.back then BACK_STRIDE else 1)
		local rate = math.clamp(speed / stride, self.minRate, self.maxRate) * (if self.back then -1 else 1)
		local jog, spr = tracks.Jog, tracks.Sprint
		if not spr then
			if jog.Length > 0 then
				jog:AdjustSpeed(rate * jog.Length * ts)
			end
		elseif jog.Length > 0 and spr.Length > 0 then
			-- Playback speed 1 runs one cycle per Length seconds; `rate` cycles per second needs rate × Length.
			jog:AdjustSpeed(rate * jog.Length * ts)
			spr:AdjustSpeed(rate * spr.Length * ts)
			-- Keep the two loops on the same phase (they drift apart by floating-point and frame timing).
			self.resync -= dt
			if self.resync <= 0 then
				self.resync = 0.5
				local pj = jog.TimePosition / jog.Length
				local ps = spr.TimePosition / spr.Length
				local d = math.abs(pj - ps)
				if math.min(d, 1 - d) > 0.015 then
					spr.TimePosition = pj * spr.Length
				end
			end
		end
	elseif tracks.Run then
		tracks.Run:AdjustSpeed(math.clamp(speed / 16, 0.5, 2.2) * ts * (if self.back then -1 else 1))
	end
	-- Self-heal (2026-10-15, the user: the Titan's animation "sometimes breaks"): a loop something else stopped plays
	-- again, and an idle left frozen (speed 0) past a hit-stop's beat gets its pace back.
	for key, t in pairs(tracks) do
		if key ~= "Brake" and not t.IsPlaying then
			t:Play(0, math.max(self.weights[key] or 0, 0.001), 1)
		end
	end
	self.offPace = if math.abs(tracks.Idle.Speed - ts) > 1e-3 then self.offPace + dt else 0
	if ts ~= 1 or self.offPace > 0.25 then
		tracks.Idle:AdjustSpeed(ts)
		tracks.Fall:AdjustSpeed(ts)
	end
	-- Brake: a run that stops without a technique. It starts the moment you let go (after BRAKE_RELEASE, so a
	-- key change mid-turn doesn't count), while the body is still decelerating, so the plant lines up with the
	-- ≈0.3 s stop and the rest of the clip settles into the idle; the last BRAKE_FADE dissolves into it.
	self.peak = math.max(self.peak - 40 * dt, speed)
	self.released = if hasInput then 0 else self.released + dt
	local brake = tracks.Brake
	if brake then
		if busy or air > 0.5 then
			self.peak = 0
			if brake.IsPlaying then
				brake:Stop(0.1)
			end
		elseif
			not brake.IsPlaying
			and self.released >= BRAKE_RELEASE
			and self.peak >= BRAKE_FROM
			and self.movedAhead
		then
			-- A harder stop plants harder: full weight from top speed, lighter from a jog.
			local w = BRAKE_LIGHT + (1 - BRAKE_LIGHT) * smoothstep(BRAKE_FROM, 24, self.peak)
			self.peak = 0
			self.brakeEnding = false
			brake:Play(BRAKE_IN, w, BRAKE_RATE * ts)
			brake.TimePosition = BRAKE_SKIP
		elseif brake.IsPlaying and (hasInput and speed > MOVE_HI) and not self.brakeEnding then
			self.brakeEnding = true
			brake:Stop(0.12) -- set off again: let go of the plant at once (still a blend, never a snap)
		elseif
			brake.IsPlaying
			and not self.brakeEnding
			and brake.Length > 0
			and brake.TimePosition >= brake.Length - BRAKE_FADE * BRAKE_RATE
		then
			self.brakeEnding = true
			brake:Stop(BRAKE_FADE)
		end
	end
end

-- Is the Brake settle playing (callers keep other layers off the body meanwhile)?
function Locomotion.braking(self: Loco): boolean
	local b = self.tracks.Brake
	return b ~= nil and b.IsPlaying
end

function Locomotion.destroy(self: Loco)
	if not self.alive then
		return
	end
	self.alive = false
	for _, t in pairs(self.tracks) do
		pcall(t.Stop, t, 0.1)
		task.delay(0.15, pcall, t.Destroy, t) -- free the Animator's track slot once the fade is done
	end
	table.clear(self.tracks)
end

return Locomotion
