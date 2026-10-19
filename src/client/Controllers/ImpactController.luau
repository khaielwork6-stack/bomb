--!strict
-- Impact & punctuation (GDD §10.3): the moments that make a tag, a pass and a boom land in the hands, not just on
-- the screen. A tag or a pass freezes both rigs for a 60 ms hit-stop and kicks your camera when it's yours; your own
-- boom holds the camera for an impact freeze while the blast expands, then whooshes you away; a Clutch Defuse or a
-- last-instant pass earns the presentation slow-mo (the local camera leans in, VFX and audio run at 0.3×, gameplay
-- never pauses), budgeted by F-FEEL-04. Reduce motion (Settings) turns the freeze, slow-mo and kicks off.
-- Implements: F-FEEL-03 (hit-stop, kicks, impact freeze), F-FEEL-04 (slow-mo budget).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Sfx)
local CameraController = require(script.Parent.CameraController)
local FxController = require(script.Parent.FxController)

local F = Config.Feel

local ImpactController = {}

local function calm(): boolean
	return Settings.get("reduceMotion") == true
end

local function rootOf(id: string): BasePart?
	local _, model = ClientState.byId(id)
	local r = model and model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function near(pos: Vector3?, range: number): boolean
	local cam = workspace.CurrentCamera
	return pos ~= nil and cam ~= nil and (cam.CFrame.Position - pos).Magnitude <= range
end

-- ── Hit-stop: every playing animation on the rig holds for a beat, then resumes at its own speed ───────────────
local function hitStop(id: string, seconds: number?)
	local _, model = ClientState.byId(id)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local root = rootOf(id)
	if not animator or not near(root and root.Position, F.HITSTOP_RANGE) then
		return
	end
	local held: { [AnimationTrack]: number } = {}
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		held[track] = track.Speed
		track:AdjustSpeed(0)
	end
	task.delay(seconds or F.HITSTOP, function()
		for track, speed in pairs(held) do
			if track.IsPlaying and track.Speed == 0 then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

-- ── Impact freeze: the camera holds its frame while your own boom expands ─────────────────────────────────────
local freezeUntil = 0
local frozen: CFrame? = nil
local function freezeStep()
	local cam = workspace.CurrentCamera
	if not frozen or not cam then
		return
	end
	if os.clock() >= freezeUntil then
		frozen = nil
		Sfx.play("PassWhoosh", 1.2, 0.7) -- …and away you fly
		return
	end
	cam.CFrame = frozen
end

local function impactFreeze()
	local cam = workspace.CurrentCamera
	if calm() or not cam then
		return
	end
	frozen = cam.CFrame
	freezeUntil = os.clock() + F.IMPACT_FREEZE
end

-- ── Presentation slow-mo: VFX and audio near you run slow for a moment; the camera leans in ──────────────────
local lastSlowmo = -math.huge
local slowUntil = 0

local function slowmo()
	local t = os.clock()
	if calm() or t - lastSlowmo < F.SLOWMO_COOLDOWN then
		return
	end
	lastSlowmo, slowUntil = t, t + F.SLOWMO_TIME
	CameraController.punch(F.SLOWMO_FOV)
	local emitters: { [ParticleEmitter]: number } = {}
	local sounds: { [Sound]: number } = {}
	local function grab(d: Instance)
		if d:IsA("ParticleEmitter") and emitters[d] == nil then
			emitters[d] = d.TimeScale
			d.TimeScale = d.TimeScale * F.SLOWMO_SCALE
		elseif d:IsA("Sound") and d.IsPlaying and sounds[d] == nil then
			sounds[d] = d.PlaybackSpeed
			d.PlaybackSpeed = d.PlaybackSpeed * F.SLOWMO_SCALE
		end
	end
	-- the effects live on Terrain attachments (FxController bursts) and on the bombs; sounds in SoundService
	for _, root in ipairs({ workspace.Terrain, SoundService }) do
		for _, d in ipairs(root:GetDescendants()) do
			grab(d)
		end
	end
	local added = workspace.Terrain.DescendantAdded:Connect(function(d)
		task.defer(grab, d) -- bursts born during the slow-mo are slowed too
	end)
	task.delay(F.SLOWMO_TIME, function()
		added:Disconnect()
		for e, scale in pairs(emitters) do
			if e.Parent then
				e.TimeScale = scale
			end
		end
		for s, speed in pairs(sounds) do
			if s.Parent then
				s.PlaybackSpeed = speed
			end
		end
	end)
end

-- The slap's freeze on the contact pose (SlapController, F-BOMB-10).
function ImpactController.hitStop(id: string, seconds: number?)
	hitStop(id, seconds)
end

-- Reduce motion is on (no camera trauma).
function ImpactController.calm(): boolean
	return calm()
end

function ImpactController.slowmoActive(): boolean
	return os.clock() < slowUntil
end

-- ── Events ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function onBomb(p: any)
	if type(p) ~= "table" then
		return
	end
	local me = ClientState.myId()
	-- (a tag's freeze, kick and camera are the slap's: SlapController times them to the contact frame)
	if p.kind == "Pass" then
		-- D-PASS-02: everything lands with the bomb (after its flight), and grows with the chain
		local n = if type(p.chain) == "number" then p.chain else 1
		local hold = if p.slam then F.HITSTOP_SLAM else F.HITSTOP
		hold = math.min(F.HITSTOP_MAX, hold + F.HITSTOP_CHAIN * (n - 1))
		local heat = 1 + 0.15 * (n - 1) * (if p.slam then 1.3 else 1)
		task.delay(F.PASS_TIME, function()
			if type(p.who) == "string" then
				hitStop(p.who, hold)
			end
			if type(p.from) == "string" then
				hitStop(p.from, hold)
			end
			if not calm() then
				if p.who == me then
					FxController.shake(F.KICK_SHAKE * 1.3 * heat)
					CameraController.punch(F.PASS_RECEIVE_FOV * heat)
				elseif p.from == me then
					FxController.shake(F.KICK_SHAKE * 0.5 * heat)
				end
			end
			-- a pass with the fuse nearly out, or a long chain (F-FEEL-04)
			local close = type(p.remaining) == "number" and p.remaining <= F.SLOWMO_PASS_LEFT
			if (close or n >= F.CHAIN_SLOWMO_FROM) and type(p.who) == "string" then
				local r = rootOf(p.who)
				if p.who == me or p.from == me or near(r and r.Position, F.SLOWMO_RANGE) then
					slowmo()
				end
			end
		end)
	elseif p.kind == "Boom" and p.who == me then
		impactFreeze()
	elseif p.kind == "Defuse" and p.clutch == true then
		local pos = if typeof(p.pos) == "Vector3" then p.pos :: Vector3 else nil
		if p.who == me or near(pos, F.SLOWMO_RANGE) then
			slowmo()
		end
	end
end

function ImpactController.start()
	-- after the camera module (Camera) and our camera tweaks (+1), before the shake (+10) so a frozen frame still shakes
	RunService:BindToRenderStep("FV_ImpactFreeze", Enum.RenderPriority.Camera.Value + 5, freezeStep)
	Net.listen("BombFx", onBomb)
end

return ImpactController
