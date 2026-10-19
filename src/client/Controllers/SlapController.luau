--!strict
-- The slap (GDD F-BOMB-10, §10.3 "Tag lands"), on every client.
--   The hand bomb: every ready Bomber holds a small copy of the hero bomb (its face, the Bomber's own skin) in their
--   right hand, the face watching the nearest Runner and the fuse sparking. It's gone the moment it's slapped on, and
--   a fresh one pops back in when the tag cooldown ends, so anyone can read at a glance whether a Bomber is loaded.
--   The slap: when the server's Stick lands, the tagger plays Slap from just before its contact frame; SLAP_LEAD
--   later is the contact: the smack burst (art/vfx/make_smack.py) on the Runner's back with a flash, the licensed
--   slap layered over the clamp, a HITSTOP_TAG freeze on both rigs (on the contact pose), the back bomb appearing
--   (BombController.deferAttach), the Runner's Stumble (the server's shove carries the body), and the camera beats.
-- Clips come from Assets.Anim; in Studio, until they're uploaded, the baked ReplicatedStorage.FV_AnimDev copies
-- are registered locally (KeyframeSequenceProvider), so the slap is testable before publishing.
-- Implements: F-BOMB-10, F-FEEL-03 (the tag's beat).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local BombFace = require(script.Parent.Parent.BombFace)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Theme = require(script.Parent.Parent.UI.Theme)
local BombController = require(script.Parent.BombController)
local CameraController = require(script.Parent.CameraController)
local FxController = require(script.Parent.FxController)
local ImpactController = require(script.Parent.ImpactController)

local F = Config.Feel
local P = Theme.Palette
local Ph = Types.Phase
local new = Theme.new
local FLAT = Vector3.new(1, 0, 1)

local SlapController = {}

-- ── Clips ───────────────────────────────────────────────────────────────────────────────────────────────────────
local clipIds: { [string]: string } = {}
local function clipId(name: string): string?
	if clipIds[name] then
		return clipIds[name]
	end
	local id = (Assets.Anim :: any)[name]
	if type(id) == "string" and id ~= "" then
		clipIds[name] = id
		return id
	end
	if not RunService:IsStudio() then
		return nil
	end
	local dev = ReplicatedStorage:FindFirstChild("FV_AnimDev")
	local ks = dev and dev:FindFirstChild(name)
	if not ks or not ks:IsA("KeyframeSequence") then
		return nil
	end
	local ok, temp = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
	end)
	if ok and type(temp) == "string" then
		clipIds[name] = temp
		return temp
	end
	return nil
end

local tracks: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local function play(model: Model, name: string, from: number)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local id = clipId(name)
	if not animator or not id then
		return
	end
	local set = tracks[animator]
	if not set then
		set = {}
		tracks[animator] = set
	end
	local track = set[name]
	if not track then
		local anim = new("Animation", { AnimationId = id })
		local ok, t = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok or not t then
			return
		end
		track = t
		track.Priority = Enum.AnimationPriority.Action
		set[name] = track
	end
	local tr = track :: AnimationTrack
	tr:Play(0.03, 1, 1)
	tr:AdjustSpeed(1)
	tr.TimePosition = from
end

-- Play one of the slap's clips on a body (the Hand-Off's whiff and reject stagger reuse Stumble).
function SlapController.playClip(model: Model, name: string, from: number)
	play(model, name, from)
end

local grips: { [Instance]: boolean } = {} -- THROW MODE: a Carrier winding up holds their own bomb in the hand

-- Stop a clip (THROW MODE: the hold loop when the throw comes), and set a playing clip's speed.
local function trackOf(model: Model, name: string): AnimationTrack?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local set = animator and tracks[animator]
	return set and set[name]
end

function SlapController.stopClip(model: Model, name: string, fade: number?)
	local track = trackOf(model, name)
	if track and track.IsPlaying then
		track:Stop(fade or 0.05)
	end
end

function SlapController.setSpeed(model: Model, name: string, speed: number)
	local track = trackOf(model, name)
	if track and track.IsPlaying then
		track:AdjustSpeed(speed)
	end
end

-- THROW MODE: a Carrier's own bomb in the throwing hand while they wind up (the back bomb hides meanwhile).
function SlapController.grip(host: Instance, on: boolean)
	grips[host] = if on then true else nil
end

-- Hold a clip on one frame (THROW MODE's wind-up: the arm drawn back) until playClip plays it on.
function SlapController.holdClip(model: Model, name: string, at: number)
	play(model, name, at)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local set = animator and tracks[animator]
	local track = set and set[name]
	if track then
		track:AdjustSpeed(0)
	end
end

-- ── The hand bomb ───────────────────────────────────────────────────────────────────────────────────────────────
type Hand = {
	model: Model,
	mount: BasePart,
	face: BombFace.Rig?,
	shown: boolean,
	popAt: number, -- os.clock() the current pop-in started
	skin: string?,
	scale: number,
}
local hands: { [Instance]: Hand } = {}
local slappedAt: { [Instance]: number } = {} -- a hand is empty from its slap until the cooldown ends

local function template(): Model?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local t = art and art:FindFirstChild("Bomb")
	return if t and t:IsA("Model") then t else nil
end

local function buildHand(arm: BasePart, skin: string?, scale: number?): Hand?
	local size = scale or F.HAND_BOMB_SCALE
	local tpl = template()
	if not tpl then
		return nil
	end
	local model = tpl:Clone()
	model.Name = "FV_HandBomb"
	SkinApply.apply(model, skin)
	local body = model:FindFirstChild("Body", true) :: BasePart?
	local clamp = model:FindFirstChild("Clamp", true) :: BasePart?
	local centre = if body then body.Position else model:GetPivot().Position
	-- the clamp toward the Bomber's palm (+Z of the arm), so the face looks where the hand points
	local turn = CFrame.identity
	if clamp then
		local toward = (clamp.Position - centre) * FLAT
		if toward.Magnitude > 1e-3 then
			turn = CFrame.Angles(0, -(math.atan2(toward.X, toward.Z) - math.pi), 0)
		end
	end
	local mount = new("Part", {
		Name = "Mount",
		Size = Vector3.one * 0.2,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		Parent = model,
	}) :: BasePart
	model.PrimaryPart = mount
	mount.CFrame = CFrame.new(centre)
	model:ScaleTo(size)
	local face = BombFace.attach(model, mount, size)
	local grip = arm.CFrame
		* F.HAND_BOMB_GRIP
		* CFrame.Angles(0, 0, -math.rad(F.HAND_BOMB_TILT)) -- the fuse leans out to the Bomber's right
		* CFrame.Angles(0, math.pi, 0)
		* turn
	model:PivotTo(grip)
	local top: BasePart? = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= mount and not BombFace.isFace(d) then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = false
			new("WeldConstraint", { Part0 = mount, Part1 = d, Parent = d })
			local n = string.match(d.Name, "^Fuse(%d+)$")
			if n and (not top or tonumber(n) :: number > tonumber(string.sub(top.Name, 5)) :: number) then
				top = d
			elseif d.Name == "LampF" or d.Name == "LampB" then
				d.Material = Enum.Material.Neon
				d.Color = P.Spark
			end
		end
	end
	mount.Anchored = false
	new("Weld", { Part0 = arm, Part1 = mount, C0 = arm.CFrame:ToObjectSpace(mount.CFrame), Parent = mount })
	-- the lit fuse: a small spark at the tip
	local tip = top
	if tip then
		local att = new("Attachment", { Position = Vector3.new(0, tip.Size.Y * 0.5, 0), Parent = tip })
		new("ParticleEmitter", {
			Texture = Assets.Vfx.Ember,
			Rate = 26,
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(1.5, 3.5),
			SpreadAngle = Vector2.new(70, 70),
			Size = NumberSequence.new(0.16, 0),
			Color = ColorSequence.new(P.Spark, P.Fuse),
			LightEmission = 1,
			Parent = att,
		})
	end
	model.Parent = arm.Parent
	return { model = model, mount = mount, face = face, shown = true, popAt = os.clock(), skin = skin, scale = size }
end

local function dropHand(host: Instance)
	local h = hands[host]
	if h then
		h.model:Destroy()
		hands[host] = nil
	end
end

local function hosts(): { Instance }
	local out: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(out, p)
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			table.insert(out, m)
		end
	end
	return out
end

local function characterOf(host: Instance): Model?
	if host:IsA("Player") then
		return host.Character
	end
	return if host:IsA("Model") then host else nil
end

local LIVE = { [Ph.Intro] = true, [Ph.Ready] = true, [Ph.Crossing] = true, [Ph.Resolve] = true, [Ph.LastStand] = true }

-- Should this host hold a bomb right now (a Bomber in play), and is the tag ready?
local function wants(host: Instance, t: number): (boolean, boolean)
	if grips[host] and LIVE[ClientState.phase()] then
		return true, true -- THROW MODE: a Carrier's own bomb, in the hand for the wind-up
	end
	if not LIVE[ClientState.phase()] or host:GetAttribute("Role") ~= "Bomber" or host:GetAttribute("Mega") then
		return false, false
	end
	local state = host:GetAttribute("State")
	if state == "Tumbled" or (host:GetAttribute("StunnedUntil") or 0) > t then
		return false, false
	end
	local ready = (host:GetAttribute("TagReadyAt") or 0) <= t and (slappedAt[host] or -math.huge) < os.clock() - 0.2
	return true, ready
end

local function nearestRunner(from: Vector3, own: Model?): Vector3?
	local best, at = 60, nil
	for _, h in ipairs(hosts()) do
		if h:GetAttribute("Role") == "Runner" then
			local char = characterOf(h)
			local r = char and char ~= own and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local d = (r.Position - from).Magnitude
				if d < best then
					best, at = d, r.Position + Vector3.new(0, 1.5, 0)
				end
			end
		end
	end
	return at
end

local gazeClock = 0
local function step(dt: number)
	local t = workspace:GetServerTimeNow()
	local clock = os.clock()
	local seen = {}
	local regaze = clock - gazeClock >= F.FACE_GAZE_RATE
	if regaze then
		gazeClock = clock
	end
	for _, host in ipairs(hosts()) do
		local char = characterOf(host)
		local arm = char and char:FindFirstChild("Right Arm") :: BasePart?
		local hold, ready = wants(host, t)
		if arm and hold then
			seen[host] = true
			local skin = host:GetAttribute("Eq_BombSkin")
			local skinId = if type(skin) == "string" then skin else nil
			local h = hands[host]
			local size = if grips[host] then F.CARRY_HAND_SCALE else F.HAND_BOMB_SCALE
			if h and (h.model.Parent ~= char or h.skin ~= skinId or h.scale ~= size) then
				dropHand(host)
				h = nil
			end
			if not h and ready then
				h = buildHand(arm, skinId, size)
				hands[host] = h
			end
			if h then
				if ready and not h.shown then
					h.shown = true
					h.popAt = clock
					h.model.Parent = char
				elseif not ready and h.shown then
					h.shown = false
					h.model.Parent = nil
				end
				if h.shown then
					-- pop in: a quick swell that settles (the fresh bomb "grows back")
					local k = math.clamp((clock - h.popAt) / F.HAND_REGROW, 0, 1)
					local s = if k < 1 then 0.2 + 0.8 * math.sin(k * math.pi * 0.62) / math.sin(math.pi * 0.62) else 1
					if k < 1 or h.model:GetScale() ~= h.scale then
						h.model:ScaleTo(h.scale * (if k < 1 then s else 1))
					end
					if h.face then
						local target = if regaze then nearestRunner(h.mount.Position, char) else nil
						BombFace.update(h.face, dt, "SMUG", target, true, 0)
					end
				end
			end
		end
	end
	for host in pairs(hands) do
		if not seen[host] then
			dropHand(host)
		end
	end
end

-- ── The slap ────────────────────────────────────────────────────────────────────────────────────────────────────
local function smack(pos: Vector3, toward: Vector3)
	local att = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain })
	task.delay(1, function()
		att:Destroy()
	end)
	local burst = new("ParticleEmitter", {
		Texture = Assets.Vfx.Smack,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Lifetime = NumberRange.new(F.SMACK_LIFE),
		Size = NumberSequence.new(F.SMACK_SIZE),
		Rotation = NumberRange.new(-25, 25),
		Speed = NumberRange.new(0),
		LightEmission = 0,
		LightInfluence = 0,
		ZOffset = 1.5,
		Rate = 0,
		Parent = att,
	})
	burst:Emit(1)
	local flash = new("ParticleEmitter", {
		Texture = Assets.Vfx.Flash,
		Lifetime = NumberRange.new(0.09),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0.6) }),
		Transparency = NumberSequence.new(0, 1),
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = 1.6,
		Rate = 0,
		Parent = att,
	})
	flash:Emit(1)
	local streaks = new("ParticleEmitter", {
		Texture = Assets.Vfx.Streak,
		Lifetime = NumberRange.new(0.12, 0.2),
		Speed = NumberRange.new(26, 40),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = NumberSequence.new(0.35, 0),
		Color = ColorSequence.new(P.Paper, P.Spark),
		LightEmission = 1,
		Rate = 0,
		Parent = att,
	})
	att.CFrame = CFrame.lookAt(pos, pos + toward) -- streaks spray the way the slap travels (Terrain sits at the origin)
	streaks:Emit(7)
end

local function onStick(p: any)
	if type(p.who) ~= "string" then
		return
	end
	local me = ClientState.myId()
	local toHost, toModel = ClientState.byId(p.who)
	local fromHost, fromModel = nil, nil
	if type(p.from) == "string" then
		fromHost, fromModel = ClientState.byId(p.from)
	end
	-- THROW MODE: a thrown hand bomb has already flown there: it lands now, with no slap
	local lead = if p.throw then 0 else F.SLAP_LEAD
	if toHost and not p.throw then
		BombController.deferAttach(toHost, os.clock() + F.SLAP_LEAD)
	end
	if fromHost and fromModel and not p.throw then
		slappedAt[fromHost] = os.clock()
		play(fromModel, "Slap", math.max(0, F.SLAP_CONTACT - F.SLAP_LEAD))
		local root = fromModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Sfx.at("SlapSwing", root.Position)
		end
	end
	task.delay(lead, function()
		-- contact
		if fromHost then
			local h = hands[fromHost]
			if h and h.shown then
				h.shown = false
				h.model.Parent = nil
			end
		end
		local torso = toModel and toModel:FindFirstChild("Torso") :: BasePart?
		local fromRoot = fromModel and fromModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if torso then
			local back = torso.CFrame * CFrame.new(0, 0.2, 0.9)
			local toward = if fromRoot then (torso.Position - fromRoot.Position) * FLAT else torso.CFrame.LookVector
			smack(back.Position, if toward.Magnitude > 1e-3 then toward.Unit else Vector3.new(0, 0, -1))
			if p.who == me then
				Sfx.play("Slap", 1.15)
				Sfx.play("BombClamp", 1.1)
			else
				Sfx.at("Slap", back.Position)
				Sfx.at("BombClamp", back.Position, 0.8)
			end
		end
		if toModel then
			play(toModel, "Stumble", 0)
		end
		ImpactController.hitStop(p.who, F.HITSTOP_TAG)
		if type(p.from) == "string" then
			ImpactController.hitStop(p.from, F.HITSTOP_TAG)
		end
		if not ImpactController.calm() then
			if p.who == me then
				FxController.shake(F.KICK_SHAKE)
				CameraController.punch(F.KICK_FOV)
			elseif p.from == me then
				FxController.shake(F.KICK_SHAKE * 0.5)
				CameraController.punch(F.KICK_FOV * 0.5)
			end
		end
	end)
end

function SlapController.start()
	RunService.RenderStepped:Connect(step)
	Net.listen("BombFx", function(p)
		if type(p) == "table" and p.kind == "Stick" then
			onStick(p)
		end
	end)
end

return SlapController
