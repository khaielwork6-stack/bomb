--!strict
-- The Hand-Off on every client (GDD §7.4b): passing as a 1-second duel, made readable and satisfying.
--   The Danger Ring (F-BOMB-11): under every Carrier, the in-house ring (art/vfx/make_danger_ring.py) drawn at the
--   true pass reach for the bomb's stage, in the stage colour, on an unlit SurfaceGui (it glows the same in sun, in
--   shade and under LIGHTS OUT; a lit decal went dark). Its fuse-link band crawls round faster as the fuse
--   burns, and it pulses with the bomb's tick (2 / 4 / 10 Hz). It pops when the stage changes and when the bomb lands
--   on a new Carrier. A READ THE FACE bomb's ring stays LIT-sized until its time shows, like its face.
--   The Lunge (F-BOMB-12): while a Carrier dashes, the ring stretches into an oval along the dash (+LUNGE_REACH, on
--   a spring). A SLAM PASS lands with a heavier freeze, a shockwave, a spark spray and a low thud; a whiffed lunge
--   puffs dust, plays a miss whoosh, and the Carrier stumbles.
--   The Reject (F-BOMB-13): a bright parry flash and ring at the rejecter, a "ting" over the clamp, both rigs frozen
--   for a beat, and the bomb visibly ricocheting off them and back onto the giver.
--   The Chain Song (F-BOMB-14): every pass plays the next note of a rising major scale (the in-house mallet note,
--   art/audio/make_chain_note.py, pitched by semitones), and a ×N tag rides above the Carrier from ×2.
-- Nothing here decides anything: the server's BombFx beats and the Carrier attributes drive it all.
-- Implements: F-BOMB-11..14 (presentation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BombFace = require(script.Parent.Parent.BombFace)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Theme = require(script.Parent.Parent.UI.Theme)
local BombController = require(script.Parent.BombController)
local CameraController = require(script.Parent.CameraController)
local FxController = require(script.Parent.FxController)
local ImpactController = require(script.Parent.ImpactController)
local SlapController = require(script.Parent.SlapController)

local B = Config.Bomb
local F = Config.Feel
local M = Config.Movement
local P = Theme.Palette
local new = Theme.new
local FLAT = Vector3.new(1, 0, 1)

local HandOffController = {}

-- ── Hosts ───────────────────────────────────────────────────────────────────────────────────────────────────────
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
	-- the Fuse Range dummies hold practice bombs (the ring teaches spacing in the lobby too)
	local lobby = workspace:FindFirstChild("Lobby")
	local range = lobby and lobby:FindFirstChild("FuseRange")
	local dummies = range and range:FindFirstChild("Dummies")
	if dummies then
		for _, m in ipairs(dummies:GetChildren()) do
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

local function rootOf(id: string): BasePart?
	local _, model = ClientState.byId(id)
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stageOf(host: Instance, t: number): string
	local at = host:GetAttribute("BombExplodeAt")
	local left = if type(at) == "number" then at - t else math.huge -- hidden (READ THE FACE): LIT
	return if left <= B.STAGE_CRITICAL then "CRITICAL" elseif left <= B.STAGE_HOT then "HOT" else "LIT"
end

-- ── The Danger Ring ─────────────────────────────────────────────────────────────────────────────────────────────
type Ring = {
	part: BasePart,
	image: ImageLabel,
	stage: string,
	popAt: number, -- os.clock() of the last pop (a new Carrier, a stage change)
	popFrom: number, -- the scale the pop starts from
	spin: number, -- degrees
	stretch: number, -- 0..1, sprung
	stretchVel: number,
	dir: Vector3,
	dying: number?, -- os.clock() it began to shrink away
}
local rings: { [Instance]: Ring } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local rayRefreshAt = 0

-- The floor under a body: ignore every body (players, bots, dummies, friends on the dummies) and our own rings.
local function refreshRayFilter()
	local list: { Instance } = { folder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, path in ipairs({ { "Bots" }, { "FV_FriendDummies" }, { "Lobby", "FuseRange", "Dummies" } }) do
		local at: Instance? = workspace
		for _, n in ipairs(path) do
			at = at and at:FindFirstChild(n)
		end
		if at then
			table.insert(list, at)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

-- The floor under a body. A standing R6 body's feet are FEET_BELOW under its root, and that's where the ring goes:
-- the Yard's visible slabs can't be raycast (CanQuery off), so a ray alone can land a few tenths under them and the
-- ring vanishes. The ray takes over only while the body is in the air.
local function groundY(pos: Vector3): number
	local feet = pos.Y - F.RING_FEET_BELOW
	local hit = workspace:Raycast(pos, Vector3.new(0, -F.RING_RAY, 0), rayParams)
	if hit and feet - hit.Position.Y > F.RING_AIRBORNE then
		return hit.Position.Y -- jumping or falling: stay on the floor below
	end
	return feet
end

local function newRing(stage: string): Ring
	local part = new("Part", {
		Name = "FV_DangerRing",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(1, 0.05, 1),
		Parent = folder,
	}) :: BasePart
	local gui = new("SurfaceGui", {
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(512, 512), -- the whole face, so a stretched part stretches the ring (the lunge oval)
		LightInfluence = 0,
		Brightness = F.RING_BRIGHTNESS,
		ClipsDescendants = false,
		Parent = part,
	})
	local image = new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Vfx.DangerRing,
		ImageColor3 = Theme.stageColor(stage),
		Parent = gui,
	}) :: ImageLabel
	return {
		part = part,
		image = image,
		stage = stage,
		popAt = os.clock(),
		popFrom = 0.35,
		spin = math.random() * 360,
		stretch = 0,
		stretchVel = 0,
		dir = Vector3.new(0, 0, -1),
		dying = nil,
	}
end

local SPIN = { LIT = F.RING_SPIN[1], HOT = F.RING_SPIN[2], CRITICAL = F.RING_SPIN[3] }
local HZ = { LIT = 2, HOT = 4, CRITICAL = 10 }

local function updateRing(ring: Ring, root: BasePart, dt: number, clock: number)
	local reach = (B.PASS_RANGE_STAGE :: any)[ring.stage] :: number
	-- the lunge: a Carrier moving at dash speed stretches its ring along the dash, on a spring
	local vel = root.AssemblyLinearVelocity * FLAT
	local lunging = vel.Magnitude > M.MAX_SPEED * F.RING_LUNGE_SPEED and not ring.dying
	if lunging then
		ring.dir = vel.Unit
	end
	local target = if lunging then 1 else 0
	local k, c = F.RING_SPRING, 2 * math.sqrt(F.RING_SPRING) * 0.7
	ring.stretchVel += ((target - ring.stretch) * k - ring.stretchVel * c) * math.min(dt, 0.05)
	ring.stretch = math.clamp(ring.stretch + ring.stretchVel * math.min(dt, 0.05), 0, 1.15)
	-- pop (a new Carrier, a stage change): a quick overshoot that settles
	local pk = math.clamp((clock - ring.popAt) / F.RING_POP_TIME, 0, 1)
	local pop = ring.popFrom + (1 - ring.popFrom) * (1 - (1 - pk) ^ 3) + F.RING_POP * math.sin(pk * math.pi)
	-- the stage's beat
	local beat = 0.5 + 0.5 * math.sin(clock * HZ[ring.stage] * math.pi * 2)
	local breath = if ring.stage == "CRITICAL" then 1 + 0.035 * beat else 1
	local dyingK = if ring.dying then math.clamp(1 - (clock - ring.dying) / F.RING_FADE, 0, 1) else 1
	local s = pop * breath * dyingK
	local width = reach * 2 * s
	local length = (reach * 2 + B.LUNGE_REACH * ring.stretch) * s
	-- spin: the links crawl round (a lunge aligns the oval to the dash; the crawl resumes from there)
	ring.spin += dt * SPIN[ring.stage]
	local yaw: number
	if ring.stretch > 0.02 then
		yaw = math.atan2(-ring.dir.X, -ring.dir.Z)
		ring.spin = math.deg(yaw)
	else
		yaw = math.rad(ring.spin)
	end
	local pos = root.Position
	local centre = Vector3.new(pos.X, groundY(pos) + F.RING_LIFT, pos.Z)
		+ ring.dir * (B.LUNGE_REACH * 0.5 * ring.stretch * s)
	ring.part.Size = Vector3.new(width, 0.05, length)
	ring.part.CFrame = CFrame.new(centre) * CFrame.Angles(0, yaw, 0)
	ring.image.ImageColor3 = Theme.stageColor(ring.stage):Lerp(P.Paper, ring.stretch * 0.25)
	ring.image.ImageTransparency =
		math.max(0, F.RING_ALPHA + F.RING_PULSE * beat - (if ring.stretch > 0.05 then 0.1 else 0))
end

local function step(dt: number)
	local t = workspace:GetServerTimeNow()
	local clock = os.clock()
	if clock >= rayRefreshAt then
		rayRefreshAt = clock + 0.5
		refreshRayFilter()
	end
	local seen = {}
	for _, host in ipairs(hosts()) do
		local char = characterOf(host)
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and host:GetAttribute("BombId") ~= nil and not host:GetAttribute("BombLocked") then
			seen[host] = true
			local stage = stageOf(host, t)
			local ring = rings[host]
			if ring and ring.dying then
				ring.part:Destroy()
				ring = nil
			end
			if not ring then
				ring = newRing(stage)
				rings[host] = ring
			elseif ring.stage ~= stage then
				ring.stage = stage
				ring.popAt = clock
				ring.popFrom = 1.0
			end
			updateRing(ring :: Ring, root, dt, clock)
		end
	end
	for host, ring in pairs(rings) do
		if not seen[host] then
			local char = characterOf(host)
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not ring.dying then
				ring.dying = clock
			end
			if root and clock - (ring.dying :: number) < F.RING_FADE then
				updateRing(ring, root, dt, clock)
			else
				ring.part:Destroy()
				rings[host] = nil
			end
		end
	end
	-- the ×N tags follow their Carriers; a bomb that's gone takes its tag with it
	for host, tag in pairs(HandOffController.tags) do
		if host:GetAttribute("BombId") == nil then
			tag:Destroy()
			HandOffController.tags[host] = nil
			BombController.setChain(host, nil)
		end
	end
end

-- ── The Chain Song + the ×N tag ─────────────────────────────────────────────────────────────────────────────────
HandOffController.tags = {} :: { [Instance]: BillboardGui }
local SCALE = { 0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19 } -- a major scale up from the note (C5 → G6)

local function chainNote(n: number, pos: Vector3?, mine: boolean)
	local semis = SCALE[math.clamp(n - 1, 1, #SCALE)]
	local key = if (Assets.SFX :: any).ChainNote.id ~= "" then "ChainNote" else "BombTickHotA"
	local pitch = 2 ^ (semis / 12)
	if mine or not pos then
		Sfx.play(key, 1.1, pitch)
	else
		Sfx.at(key, pos, 1, pitch)
	end
end

local function tagColor(n: number): Color3
	return if n >= 5 then P.Detonate elseif n >= 3 then P.Ember else P.Spark
end

local function setTag(host: Instance, n: number)
	local old = HandOffController.tags[host]
	if old then
		old:Destroy()
		HandOffController.tags[host] = nil
	end
	BombController.setChain(host, n)
	if n < 2 then
		return
	end
	local char = characterOf(host)
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = new("BillboardGui", {
		Name = "FV_ChainTag",
		Size = UDim2.fromOffset(110, 48),
		StudsOffsetWorldSpace = Vector3.new(0, F.CHAIN_TAG_HEIGHT, 0),
		AlwaysOnTop = true,
		MaxDistance = 70,
		LightInfluence = 0,
		Adornee = head,
		Parent = head,
	}) :: BillboardGui
	local label = Theme.display(gui, {
		Size = UDim2.fromScale(1, 1),
		Text = "×" .. n,
		TextSize = 34 + math.min(n, 8) * 2,
		color = tagColor(n),
	})
	local scale = new("UIScale", { Scale = 1.7, Parent = label }) :: UIScale
	TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	HandOffController.tags[host] = gui
end

-- ── Beats ───────────────────────────────────────────────────────────────────────────────────────────────────────
local function burst(pos: Vector3, color: Color3, size: number, streaks: number, toward: Vector3?)
	local att = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain }) :: Attachment
	if toward and toward.Magnitude > 1e-3 then
		att.CFrame = CFrame.lookAt(pos, pos + toward)
	end
	task.delay(1.2, function()
		att:Destroy()
	end)
	local flash = new("ParticleEmitter", {
		Texture = Assets.Vfx.Flash,
		Lifetime = NumberRange.new(0.1),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.25) }),
		Transparency = NumberSequence.new(0, 1),
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5)),
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = 1.2,
		Rate = 0,
		Parent = att,
	}) :: ParticleEmitter
	flash:Emit(1)
	local ring = new("ParticleEmitter", {
		Texture = Assets.Vfx.Ring,
		Lifetime = NumberRange.new(0.22),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.3),
			NumberSequenceKeypoint.new(1, size * 1.6),
		}),
		Transparency = NumberSequence.new(0.1, 1),
		Color = ColorSequence.new(color),
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = 1.1,
		Rate = 0,
		Parent = att,
	}) :: ParticleEmitter
	ring:Emit(1)
	if streaks > 0 then
		local spray = new("ParticleEmitter", {
			Texture = Assets.Vfx.Streak,
			Lifetime = NumberRange.new(0.12, 0.22),
			Speed = NumberRange.new(24, 42),
			SpreadAngle = if toward then Vector2.new(40, 40) else Vector2.new(180, 180),
			EmissionDirection = Enum.NormalId.Front,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(0.3, 0),
			Color = ColorSequence.new(P.Paper, color),
			LightEmission = 1,
			Rate = 0,
			Parent = att,
		}) :: ParticleEmitter
		spray:Emit(streaks)
	end
end

local function dust(pos: Vector3)
	local att = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain }) :: Attachment
	task.delay(1.5, function()
		att:Destroy()
	end)
	local puff = new("ParticleEmitter", {
		Texture = Assets.Vfx.Smoke,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(70, 10),
		Size = NumberSequence.new(1.2, 2.2),
		Color = ColorSequence.new(Color3.fromRGB(196, 186, 172)),
		Transparency = NumberSequence.new(0.2, 1),
		Rate = 0,
		Parent = att,
	}) :: ParticleEmitter
	puff:Emit(3)
end

-- The bomb ricochets off the rejecter and back onto the giver: the hero bomb, wide-eyed, out and back.
local function ricochet(giverId: string, rejecterId: string)
	local giverHost, giverModel = ClientState.byId(giverId)
	local _, rejModel = ClientState.byId(rejecterId)
	local a = giverModel and giverModel:FindFirstChild("Torso") :: BasePart?
	local b = rejModel and rejModel:FindFirstChild("Torso") :: BasePart?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb") :: Model?
	if not a or not b or not template then
		return
	end
	local ghost = template:Clone()
	ghost.Name = "FV_BombRicochet"
	local skin = giverHost and giverHost:GetAttribute("Eq_BombSkin")
	SkinApply.apply(ghost, if type(skin) == "string" then skin else nil)
	BombFace.pose(ghost, "WHEE", Vector3.new(0, 1, 0.25))
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	ghost.Parent = workspace
	local t0 = os.clock()
	local out = F.RICOCHET_TIME * 0.45
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		local from = a.Position + Vector3.new(0, 0.6, 0)
		local hit = from:Lerp(b.Position + Vector3.new(0, 0.6, 0), 0.82)
		local pos: Vector3
		if e < out then
			local k = e / out
			pos = from:Lerp(hit, k * k) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0)
		else
			local k = math.clamp((e - out) / (F.RICOCHET_TIME - out), 0, 1)
			pos = hit:Lerp(from, 1 - (1 - k) * (1 - k)) + Vector3.new(0, math.sin(k * math.pi) * 2.4, 0)
		end
		ghost:PivotTo(CFrame.new(pos) * CFrame.Angles(e * 26, e * 9, 0))
		if e >= F.RICOCHET_TIME then
			conn:Disconnect()
			ghost:Destroy()
		end
	end)
end

local function onBomb(p: any)
	if type(p) ~= "table" or type(p.who) ~= "string" then
		return
	end
	local me = ClientState.myId()
	local calm = ImpactController.calm()
	if p.kind == "Pass" then
		local toHost = ClientState.byId(p.who)
		local toRoot = rootOf(p.who)
		local n = if type(p.chain) == "number" then p.chain else 2
		chainNote(n, if toRoot then toRoot.Position else nil, p.who == me or p.from == me)
		if toHost then
			local fromHost = if type(p.from) == "string" then ClientState.byId(p.from) else nil
			if fromHost then
				setTag(fromHost, 0)
			end
			setTag(toHost, n)
			local ring = rings[toHost]
			if ring then
				ring.popAt = os.clock()
				ring.popFrom = 0.35
			end
		end
		if p.from == me then
			Sfx.play("PassWhoosh", 0.7, 1.65) -- relief: it's gone
		end
		if p.slam and toRoot then
			-- SLAM PASS: a shockwave and a spray the way it was shoved, a low thud, a heavier freeze
			local fromRoot = if type(p.from) == "string" then rootOf(p.from) else nil
			local dir = if fromRoot then (toRoot.Position - fromRoot.Position) * FLAT else Vector3.zero
			burst(toRoot.Position, P.Spark, 4.2, 9, if dir.Magnitude > 1e-3 then dir.Unit else nil)
			Sfx.at("Slap", toRoot.Position, 1.1, 0.82)
			Sfx.at("BombClamp", toRoot.Position, 1, 0.8)
			ImpactController.hitStop(p.who, F.HITSTOP_SLAM)
			if type(p.from) == "string" then
				ImpactController.hitStop(p.from, F.HITSTOP_SLAM)
			end
			if not calm and (p.who == me or p.from == me) then
				FxController.shake(F.KICK_SHAKE * 1.3)
				CameraController.punch(F.KICK_FOV * 1.4)
			end
		end
	elseif p.kind == "Reject" and type(p.from) == "string" then
		-- p.who rejected, p.from (the giver) gets it back
		local rej = rootOf(p.who)
		if rej then
			burst(rej.Position + Vector3.new(0, 0.6, 0), P.Runner, 5, 12, nil)
			Sfx.at("BombTickHotA", rej.Position, 1.2, 2.6) -- the "ting"
			Sfx.at("BombClamp", rej.Position, 0.9, 1.55)
		end
		ricochet(p.from, p.who)
		ImpactController.hitStop(p.who, F.HITSTOP_REJECT)
		ImpactController.hitStop(p.from, F.HITSTOP_REJECT)
		local _, giverModel = ClientState.byId(p.from)
		if giverModel then
			SlapController.playClip(giverModel, "Stumble", 0)
		end
		if not calm then
			if p.who == me then
				CameraController.punch(F.KICK_FOV * 1.2)
				FxController.shake(F.KICK_SHAKE * 0.6)
			elseif p.from == me then
				FxController.shake(F.KICK_SHAKE * 1.2)
			end
		end
	elseif p.kind == "Whiff" then
		-- a lunge at somebody that missed: dust at the feet, a miss whoosh, a stumble
		local root = rootOf(p.who)
		if root then
			dust(root.Position - Vector3.new(0, 2.6, 0))
			Sfx.at("PassWhoosh", root.Position, 0.9, 0.78)
		end
		local _, model = ClientState.byId(p.who)
		if model then
			SlapController.playClip(model, "Stumble", 0)
		end
	end
end

function HandOffController.start()
	folder = new("Folder", { Name = "FV_DangerRings", Parent = workspace }) :: Folder
	refreshRayFilter()
	RunService.RenderStepped:Connect(step)
	Net.listen("BombFx", onBomb)
end

return HandOffController
