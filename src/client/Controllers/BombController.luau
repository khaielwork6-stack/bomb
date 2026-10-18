--!strict
-- The bomb on every Carrier's back (GDD §7.2, Asset Bible §3), built and driven on each client from the Carrier's
-- attributes (BombId, BombExplodeAt, BombLocked) so it costs no replication and every client shows the same fuse.
-- The braided fuse burns down segment by segment as the true remaining time; the lamps pulse and the seams glow
-- through LIT → HOT → CRITICAL; the bomb hangs on a sprung clamp and wobbles with the body. A ring above the
-- Carrier's head shows the time to everyone. P1 builds the bomb from engine parts in the hero design's shapes and
-- materials; the Blender hero model (Asset Bible §3.2) replaces the parts in P3.
-- The fuse spark wears the Carrier's equipped Eq_FuseSpark (Asset Bible §8.1, Client/VfxCosmetic); the ring keeps
-- its stage colours.
-- READ THE FACE (GDD §6.4): a masked bomb (`BombMasked`, no `BombExplodeAt` yet) shows no time while LIT: full braid,
-- full ring, the LIT pulse; once the server sends its time at HOT the braid and ring run over the last STAGE_HOT.
-- Implements: F-BOMB-01 (visuals), F-FEEL-01 (carrier layer), GDD §7.2 stages, §10.4 readability, F-MOD-02,
-- F-STORE-01 (sparks).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BombFace = require(script.Parent.Parent.BombFace)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Sfx)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Theme = require(script.Parent.Parent.UI.Theme)
local VfxCosmetic = require(script.Parent.Parent.VfxCosmetic)

local B = Config.Bomb
local F = Config.Feel
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local BombController = {}

local RADIUS = 1.1
local FUSE_SEGMENTS = 12
local FUSE_LEN = 1.25
local RING_SEGMENTS = 20
-- Where the bomb hangs, in Torso space (R6 Torso: +Z is the back).
local MOUNT = CFrame.new(0, 0.15, 0.5 + 0.4 + RADIUS)

type Visual = {
	host: Instance,
	model: Model,
	mount: BasePart,
	weld: Weld,
	torso: BasePart,
	segments: { BasePart },
	lamps: { BasePart },
	seams: { BasePart },
	spark: ParticleEmitter,
	sparkAtt: Attachment,
	cosmetic: VfxCosmetic.SparkRig?, -- the Carrier's equipped fuse spark (nil: Classic)
	light: PointLight,
	ring: BillboardGui,
	ringDots: { Frame },
	explodeAt: number?, -- nil while a READ THE FACE bomb is LIT (its time is hidden)
	masked: boolean,
	wobble: Vector3, -- spring state (rad): x pitch, z roll
	wobbleVel: Vector3,
	lastVel: Vector3,
	stuckAt: number, -- os.clock() of the stick slam (the wobble waits for it to land)
	artFuse: boolean, -- the imported hero bomb's fuse segments stand along Y (the part-built ones along X)
	face: BombFace.Rig?, -- the face rig (Asset Bible §3.8), when the art has one
	gazeTarget: Vector3?, -- who the face is staring at (a head), re-picked every FACE_GAZE_RATE
	gazeAt: number,
}

local visuals: { [Instance]: Visual } = {}
local gotchaUntil: { [Instance]: number } = {} -- a Bomber's tag just stuck this bomb on: the face grins

local function now(): number
	return workspace:GetServerTimeNow()
end

-- ── Building the bomb ───────────────────────────────────────────────────────────────────────────────────────────
local function part(model: Model, mount: BasePart, props: { [string]: any }): BasePart
	local p = new("Part", {
		Name = props.Name or "Part",
		Shape = props.Shape or Enum.PartType.Block,
		Size = props.Size,
		Material = props.Material or Enum.Material.Metal,
		Color = props.Color,
		Reflectance = props.Reflectance or 0,
		Transparency = props.Transparency or 0,
		CastShadow = props.CastShadow ~= false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CFrame = mount.CFrame * (props.CFrame or CFrame.identity),
		Parent = model,
	})
	new("WeldConstraint", { Part0 = mount, Part1 = p, Parent = p })
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a Cylinder's axis (X) to Y

local function build(torso: BasePart): (Model, BasePart, { BasePart }, { BasePart }, { BasePart }, Attachment)
	local model = new("Model", { Name = "FV_Bomb" })
	local mount = new("Part", {
		Name = "Mount",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CFrame = torso.CFrame * MOUNT,
		Parent = model,
	})
	model.PrimaryPart = mount
	-- Body: cast iron.
	part(model, mount, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * RADIUS * 2,
		Material = Enum.Material.Metal,
		Color = P.Iron,
		Reflectance = 0.04,
	})
	-- Riveted brass belt.
	part(model, mount, {
		Name = "Belt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, RADIUS * 2 + 0.06, RADIUS * 2 + 0.06),
		Color = P.Brass,
		Reflectance = 0.12,
		CFrame = UP,
	})
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		part(model, mount, {
			Name = "Rivet",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.11,
			Color = P.Brass:Lerp(Color3.new(1, 0.95, 0.8), 0.35),
			Reflectance = 0.2,
			CastShadow = false,
			CFrame = CFrame.new(math.cos(a) * (RADIUS + 0.04), 0, math.sin(a) * (RADIUS + 0.04)),
		})
	end
	-- Indicator lamps (front and back of the belt) in brass bezels.
	local lamps = {}
	for _, z in ipairs({ -1, 1 }) do
		part(model, mount, {
			Name = "Bezel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.08, 0.34, 0.34),
			Color = P.Brass,
			Reflectance = 0.15,
			CFrame = CFrame.new(0, 0, z * (RADIUS + 0.02)) * CFrame.Angles(0, math.rad(90), 0),
		})
		table.insert(
			lamps,
			part(model, mount, {
				Name = "Lamp",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.24,
				Material = Enum.Material.Neon,
				Color = P.Spark,
				CastShadow = false,
				CFrame = CFrame.new(0, 0, z * (RADIUS + 0.07)),
			})
		)
	end
	-- Weld seams (two meridians); they glow from inside as the fuse runs down.
	local seams = {}
	for i = 0, 1 do
		table.insert(
			seams,
			part(model, mount, {
				Name = "SeamGlow",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, RADIUS * 2 + 0.02, RADIUS * 2 + 0.02),
				Material = Enum.Material.Neon,
				Color = P.Ember,
				Transparency = 1,
				CastShadow = false,
				CFrame = CFrame.Angles(0, math.rad(45 + 90 * i), 0),
			})
		)
	end
	-- Knurled brass collar and the glazed porcelain fuse socket.
	part(model, mount, {
		Name = "Collar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.24, 0.64, 0.64),
		Color = P.Brass,
		Reflectance = 0.12,
		CFrame = CFrame.new(0, RADIUS - 0.04, 0) * UP,
	})
	part(model, mount, {
		Name = "Socket",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 0.44, 0.44),
		Material = Enum.Material.SmoothPlastic,
		Color = P.Porcelain,
		Reflectance = 0.12,
		CFrame = CFrame.new(0, RADIUS + 0.16, 0) * UP,
	})
	-- The braided fuse: 12 tapering segments on a gentle S-bend.
	local segments = {}
	local base = RADIUS + 0.26
	local step = FUSE_LEN / FUSE_SEGMENTS
	for i = 1, FUSE_SEGMENTS do
		local t = (i - 0.5) / FUSE_SEGMENTS
		local y = base + (i - 0.5) * step
		local x = math.sin(t * math.pi * 1.3) * 0.12
		local w = 0.12 - 0.035 * t
		table.insert(
			segments,
			part(model, mount, {
				Name = "Fuse" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(step * 1.08, w, w),
				Material = Enum.Material.Fabric,
				Color = Color3.fromHex("#D9B98A"),
				CastShadow = false,
				CFrame = CFrame.new(x, y, 0) * UP,
			})
		)
	end
	local sparkAtt = new("Attachment", { Name = "Spark", Parent = mount })
	return model, mount, segments, lamps, seams, sparkAtt
end

-- The approved hero bomb (Asset Bible §3, art/bomb/export.py → imported by the user into
-- ReplicatedStorage.FV_Art.Bomb): textured MeshParts Body / Brass / Socket / Clamp, glass LensF/B, LampF/B and
-- SeamGlow1/2 (set to Neon and animated here), and Fuse1..12 (bottom → top). Returns nil while it isn't imported,
-- so the part-built bomb above stands in.
local function artTemplate(): Model?
	local folder = ReplicatedStorage:FindFirstChild("FV_Art")
	local m = folder and folder:FindFirstChild("Bomb")
	return if m and m:IsA("Model") then m else nil
end

local function buildFromArt(
	torso: BasePart,
	template: Model,
	skinId: string?
): (Model, BasePart, { BasePart }, { BasePart }, { BasePart }, Attachment, BombFace.Rig?)
	local model = template:Clone()
	model.Name = "FV_Bomb"
	SkinApply.apply(model, skinId) -- the Carrier's equipped bomb skin (Asset Bible §3.6: textures only)
	local body = model:FindFirstChild("Body", true) :: BasePart?
	local clamp = model:FindFirstChild("Clamp", true) :: BasePart?
	-- Orientation: the clamp must face the torso (the bomb's -Z in Torso space). Exports can arrive turned round.
	local centre = if body then body.Position else model:GetPivot().Position
	local turn = CFrame.identity
	if clamp then
		local towardClamp = (clamp.Position - centre) * Vector3.new(1, 0, 1)
		if towardClamp.Magnitude > 1e-3 then
			-- rotate so the clamp direction becomes -Z
			local yaw = math.atan2(towardClamp.X, towardClamp.Z) - math.pi
			turn = CFrame.Angles(0, -yaw, 0)
		end
	end
	local mount = new("Part", {
		Name = "Mount",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		Parent = model,
	})
	model.PrimaryPart = mount
	mount.CFrame = CFrame.new(centre)
	local face = BombFace.attach(model, mount) -- welds the face rig while the model is still in bomb space
	model:PivotTo(torso.CFrame * MOUNT * turn)
	local segments: { BasePart } = {}
	local lamps: { BasePart } = {}
	local seams: { BasePart } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= mount and not BombFace.isFace(d) then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			new("WeldConstraint", { Part0 = mount, Part1 = d, Parent = d })
			local n = d.Name
			if string.match(n, "^Fuse%d+$") then
				segments[tonumber(string.sub(n, 5)) :: number] = d
			elseif n == "LampF" or n == "LampB" then
				d.Material = Enum.Material.Neon
				d.Color = P.Spark
				table.insert(lamps, d)
			elseif string.match(n, "^SeamGlow") then
				d.Material = Enum.Material.Neon
				d.Color = P.Ember
				d.Transparency = 1
				table.insert(seams, d)
			elseif n == "LensF" or n == "LensB" then
				d.Material = Enum.Material.Glass
				d.Transparency = 0.45
			end
		end
	end
	mount.Anchored = false
	local sparkAtt = new("Attachment", { Name = "Spark", Parent = mount })
	return model, mount, segments, lamps, seams, sparkAtt, face
end
local function buildRing(adornee: BasePart): (BillboardGui, { Frame })
	local gui = new("BillboardGui", {
		Name = "FV_FuseRing",
		Size = UDim2.fromOffset(64, 64),
		StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
		AlwaysOnTop = true,
		MaxDistance = 60,
		LightInfluence = 0,
		Adornee = adornee,
		ResetOnSpawn = false,
	})
	local back = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = P.Ink2,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = back })
	new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = back })
	-- a tiny bomb glyph in the middle (drawn, no image asset)
	local glyph = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.42, 0.42),
		BackgroundColor3 = P.Iron,
		Parent = back,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glyph })
	new("UIStroke", { Color = P.Brass, Thickness = 1.5, Parent = glyph })
	local dots = {}
	for i = 1, RING_SEGMENTS do
		local a = (i - 1) / RING_SEGMENTS * math.pi * 2
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(a) * 0.42, 0.5 - math.cos(a) * 0.42),
			Size = UDim2.fromScale(0.09, 0.17),
			Rotation = math.deg(a),
			BackgroundColor3 = P.Spark,
			BorderSizePixel = 0,
			Parent = gui,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
		new("UIStroke", { Color = P.Ink, Thickness = 1, Parent = dot })
		table.insert(dots, dot)
	end
	return gui, dots
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────────────────────────────────────────
local function characterOf(host: Instance): Model?
	if host:IsA("Player") then
		return host.Character
	end
	return if host:IsA("Model") then host else nil
end

local function remove(host: Instance)
	local v = visuals[host]
	if v then
		visuals[host] = nil
		v.model:Destroy()
		v.ring:Destroy()
	end
end

local function attach(host: Instance): Visual?
	local char = characterOf(host)
	local torso = char and char:FindFirstChild("Torso") :: BasePart?
	if not char or not torso then
		return nil
	end
	local template = artTemplate()
	local model, mount, segments, lamps, seams, sparkAtt, face
	if template then
		local skin = host:GetAttribute("Eq_BombSkin")
		model, mount, segments, lamps, seams, sparkAtt, face =
			buildFromArt(torso, template, if type(skin) == "string" then skin else nil)
	else
		model, mount, segments, lamps, seams, sparkAtt = build(torso)
	end
	local weld = new("Weld", { Part0 = torso, Part1 = mount, C0 = MOUNT, Parent = mount })
	local spark = new("ParticleEmitter", {
		Texture = Assets.Vfx.Streak,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(P.Spark, P.Fuse),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.15, 0.35),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -12, 0),
		Rate = 40,
		Parent = sparkAtt,
	})
	-- The burning point itself (Asset Bible §5.2): a flickering six-point star, always on top of the cord.
	local core = new("ParticleEmitter", {
		Name = "SparkCore",
		Texture = Assets.Vfx.Flash,
		Color = ColorSequence.new(Color3.new(1, 0.96, 0.82), P.Spark),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 0.45) }),
		Transparency = NumberSequence.new(0, 0.6),
		Lifetime = NumberRange.new(0.05, 0.09),
		Rate = 40,
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		ZOffset = 0.4,
		Parent = sparkAtt,
	})
	local light = new("PointLight", { Color = P.Fuse, Range = 5, Brightness = 2, Parent = sparkAtt })
	local cosmetic = VfxCosmetic.spark(host:GetAttribute("Eq_FuseSpark"), sparkAtt, mount, spark, core, light)
	Sfx.loop("FuseHiss", sparkAtt) -- the burning cord, 3D on the Carrier's back (destroyed with the bomb)
	model.Parent = char
	local ring, dots = buildRing(torso)
	ring.Parent = player:WaitForChild("PlayerGui")
	local v: Visual = {
		host = host,
		model = model,
		mount = mount,
		weld = weld,
		torso = torso,
		segments = segments,
		lamps = lamps,
		seams = seams,
		spark = spark,
		sparkAtt = sparkAtt,
		cosmetic = cosmetic,
		light = light,
		ring = ring,
		ringDots = dots,
		explodeAt = host:GetAttribute("BombExplodeAt"),
		masked = host:GetAttribute("BombMasked") == true,
		wobble = Vector3.zero,
		wobbleVel = Vector3.zero,
		lastVel = Vector3.zero,
		stuckAt = os.clock(),
		artFuse = template ~= nil,
		face = face,
		gazeTarget = nil,
		gazeAt = 0,
	}
	visuals[host] = v
	-- Stick: the bomb slams onto the back with a squash and a snap (GDD §10.3).
	weld.C0 = MOUNT * CFrame.new(0, 0, 1.2) * CFrame.Angles(math.rad(-25), 0, 0)
	TweenService:Create(weld, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = MOUNT })
		:Play()
	-- …and pops as the clamp bites: a quick swell that settles (§10.3 squash-stretch, in uniform scale)
	if template then
		local t0 = os.clock()
		local pop: RBXScriptConnection
		pop = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / F.LAND_POP_TIME, 0, 1)
			if not model.Parent then
				pop:Disconnect()
				return
			end
			model:ScaleTo(1 + (F.LAND_POP - 1) * math.sin(k * math.pi))
			if k >= 1 then
				model:ScaleTo(1)
				pop:Disconnect()
			end
		end)
	end
	return v
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
	-- The Depot's Fuse Range dummies hold practice bombs (DepotController sets their attributes locally)
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

-- ── Per frame ───────────────────────────────────────────────────────────────────────────────────────────────────
local function update(v: Visual, dt: number, t: number)
	local at = v.explodeAt
	local remaining = if at then math.max(0, at - t) elseif v.masked then math.huge else 0
	local frac = math.clamp(remaining / (if v.masked then B.STAGE_HOT else B.FUSE), 0, 1)
	local stage = if remaining <= B.STAGE_CRITICAL then "CRITICAL" elseif remaining <= B.STAGE_HOT then "HOT" else "LIT"
	local stageColor = Theme.stageColor(stage)
	-- The fuse: segments above the burn point are gone, the burning one shortens, the ones just below char.
	local burnt = (1 - frac) * FUSE_SEGMENTS
	local tipY = 0
	for i, seg in ipairs(v.segments) do
		local fromTop = FUSE_SEGMENTS - i -- 0 for the last (top) segment
		if fromTop < math.floor(burnt) then
			seg.Transparency = 1
		else
			seg.Transparency = 0
			local charred = math.clamp(1 - (fromTop - burnt), 0, 1)
			seg.Color = Color3.fromHex("#D9B98A"):Lerp(Color3.fromHex("#2A1F1A"), charred)
			if fromTop == math.floor(burnt) then
				tipY = math.max(tipY, i)
			end
		end
	end
	local tip = v.segments[math.clamp(tipY, 1, FUSE_SEGMENTS)]
	v.sparkAtt.WorldPosition = tip.Position + Vector3.new(0, (if v.artFuse then tip.Size.Y else tip.Size.X) * 0.5, 0)
	-- Spark, lamps, seams by stage.
	local cosmetic = v.cosmetic
	if cosmetic then
		VfxCosmetic.sparkStep(cosmetic, dt, stage == "CRITICAL")
	else
		v.spark.Rate = if stage == "CRITICAL" then 120 elseif stage == "HOT" then 70 else 40
	end
	local hz = if stage == "CRITICAL" then 10 elseif stage == "HOT" then 4 else 2
	local pulse = 0.5 + 0.5 * math.sin(t * hz * math.pi * 2)
	for _, lamp in ipairs(v.lamps) do
		lamp.Color = stageColor:Lerp(Color3.new(1, 1, 1), if stage == "CRITICAL" then pulse * 0.6 else 0)
		lamp.Transparency = 0.35 - pulse * 0.35
	end
	local seamT = if stage == "CRITICAL"
		then 0.15 - pulse * 0.15
		elseif stage == "HOT" then 0.75 - (1 - remaining / B.STAGE_HOT) * 0.45
		else 1
	for _, seam in ipairs(v.seams) do
		seam.Transparency = seamT
		seam.Color = if stage == "CRITICAL" then P.Spark:Lerp(Color3.new(1, 1, 1), pulse) else P.Ember
	end
	v.light.Range = if stage == "CRITICAL" then 10 elseif cosmetic then cosmetic.range else 5
	v.light.Color = if cosmetic then cosmetic.color else stageColor
	-- Sprung clamp: the bomb lags the body's acceleration and settles (k 180, damping ≈0.35).
	local root = v.torso.Parent and (v.torso.Parent :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and dt > 0 then
		local vel = root.AssemblyLinearVelocity
		local acc = (vel - v.lastVel) / dt
		v.lastVel = vel
		local localAcc = v.torso.CFrame:VectorToObjectSpace(acc)
		local force = Vector3.new(-localAcc.Z, 0, localAcc.X) * 0.004
		local k, c = 180, 2 * math.sqrt(180) * 0.35
		v.wobbleVel += (force * k - v.wobble * k - v.wobbleVel * c) * math.min(dt, 0.05)
		v.wobble += v.wobbleVel * math.min(dt, 0.05)
		v.wobble = Vector3.new(math.clamp(v.wobble.X, -0.14, 0.14), 0, math.clamp(v.wobble.Z, -0.14, 0.14))
	end
	local shake = if stage == "CRITICAL"
		then CFrame.new((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08, 0)
		else CFrame.identity
	if os.clock() - v.stuckAt > 0.24 then
		v.weld.C0 = MOUNT * CFrame.Angles(v.wobble.X, 0, v.wobble.Z) * shake
	end
	-- The overhead ring: remaining dots lit in the stage colour, spent ones dark.
	local lit = math.ceil(frac * RING_SEGMENTS)
	for i, dot in ipairs(v.ringDots) do
		local on = i <= lit
		dot.BackgroundColor3 = if on then stageColor else P.Ink2
		dot.BackgroundTransparency = if on then 0 else 0.35
	end
	v.ring.Size = UDim2.fromOffset(64, 64)
	if stage == "CRITICAL" then
		local s = 64 * (1 + pulse * 0.12)
		v.ring.Size = UDim2.fromOffset(s, s)
	end
	-- The face (Asset Bible §3.8): smug while LIT, nervous at HOT, panicking at CRITICAL, a grin when it just stuck,
	-- blinking while LIT and staring at the nearest player.
	if v.face then
		local clock = os.clock()
		if clock - v.gazeAt >= F.FACE_GAZE_RATE then
			v.gazeAt = clock
			v.gazeTarget = nil
			local from = v.mount.Position
			local best = F.FACE_GAZE_RANGE
			local own = characterOf(v.host)
			for _, h in ipairs(hosts()) do
				local char = characterOf(h)
				local other = char and char ~= own and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if other then
					local d = (other.Position - from).Magnitude
					if d < best then
						best = d
						v.gazeTarget = other.Position + Vector3.new(0, 1.5, 0) -- the head
					end
				end
			end
		end
		local gotcha = (gotchaUntil[v.host] or 0) > clock
		local pose = if gotcha
			then "GOTCHA"
			elseif stage == "CRITICAL" then "PANIC"
			elseif stage == "HOT" then "UHOH"
			else "SMUG"
		local jitter = if stage == "CRITICAL" and not Settings.get("reduceMotion") then F.FACE_SHAKE else 0
		BombFace.update(v.face, dt, pose, v.gazeTarget, stage == "LIT" and not gotcha, jitter)
	end
end

-- The slap (F-BOMB-10): a tagged host's back bomb appears on the slap's contact frame, not when the event lands.
local deferred: { [Instance]: number } = {}
function BombController.deferAttach(host: Instance, untilClock: number)
	deferred[host] = untilClock
end

local function step(dt: number)
	local t = now()
	local seen = {}
	for _, host in ipairs(hosts()) do
		local id = host:GetAttribute("BombId")
		if id ~= nil and (deferred[host] or 0) > os.clock() and not visuals[host] then
			seen[host] = true -- held back until the hand lands
		elseif id ~= nil then
			seen[host] = true
			local v = visuals[host]
			local char = characterOf(host)
			if v and (v.model.Parent == nil or v.model.Parent ~= char) then
				remove(host)
				v = nil
			end
			if not v then
				v = attach(host)
			end
			if v then
				local at = host:GetAttribute("BombExplodeAt")
				v.masked = host:GetAttribute("BombMasked") == true
				if type(at) == "number" then
					v.explodeAt = at
				elseif v.masked then
					v.explodeAt = nil
				end
				update(v, dt, t)
			end
		end
	end
	for host in pairs(visuals) do
		if not seen[host] then
			remove(host)
		end
	end
end

-- Pass arc (GDD §7.4, §10.3): the real bomb, in the giver's skin, flies back to back with spins and a motion trail,
-- then the receiver's clamp catches it (attach() does the slam and the pop).
local function passArc(fromId: string, toId: string)
	local fromHost, fromModel = ClientState.byId(fromId)
	local _, toModel = ClientState.byId(toId)
	local a = fromModel and fromModel:FindFirstChild("Torso") :: BasePart?
	local b = toModel and toModel:FindFirstChild("Torso") :: BasePart?
	local template = artTemplate()
	if not a or not b or not template then
		return
	end
	local ghost = template:Clone()
	ghost.Name = "FV_BombFlight"
	local skin = fromHost and fromHost:GetAttribute("Eq_BombSkin")
	SkinApply.apply(ghost, if type(skin) == "string" then skin else nil)
	BombFace.pose(ghost, "WHEE", Vector3.new(0, 1, 0.25)) -- wide-eyed and looking up as it flies
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if string.match(d.Name, "^SeamGlow") then
				d.Transparency = 1
			elseif d.Name == "LampF" or d.Name == "LampB" then
				d.Material = Enum.Material.Neon
				d.Color = P.Spark
			end
		end
	end
	local body = ghost:FindFirstChild("Body", true) :: BasePart?
	if body then
		local top = new("Attachment", { Position = Vector3.new(0, RADIUS * 0.6, 0), Parent = body })
		local bottom = new("Attachment", { Position = Vector3.new(0, -RADIUS * 0.6, 0), Parent = body })
		new("Trail", {
			Attachment0 = top,
			Attachment1 = bottom,
			Color = ColorSequence.new(P.Spark, P.Fuse),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = 0.16,
			LightEmission = 0.6,
			FaceCamera = true,
			Parent = body,
		})
	end
	ghost.Parent = workspace
	local spin = F.PASS_SPINS * math.pi * 2
	local start = (a.CFrame * MOUNT).Position
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / F.PASS_TIME, 0, 1)
		local finish = (b.CFrame * MOUNT).Position
		local pos = start:Lerp(finish, k) + Vector3.new(0, math.sin(k * math.pi) * F.PASS_ARC, 0)
		ghost:PivotTo(CFrame.new(pos) * CFrame.Angles(k * spin, 0, 0))
		if k >= 1 then
			conn:Disconnect()
			ghost:Destroy()
		end
	end)
end

-- A still bomb (no fuse burn, sparks or ring) welded to `torso` the same way: MomentController's replay puppets.
function BombController.dummy(torso: BasePart, skinId: string?): Model
	local template = artTemplate()
	local model, mount
	if template then
		model, mount = buildFromArt(torso, template, skinId)
	else
		model, mount = build(torso)
	end
	mount.Anchored = false
	new("Weld", { Part0 = torso, Part1 = mount, C0 = MOUNT, Parent = mount })
	model.Parent = torso.Parent
	return model
end

function BombController.start()
	RunService.RenderStepped:Connect(step)
	Net.listen("BombFx", function(payload)
		if type(payload) == "table" and payload.kind == "Stick" and type(payload.who) == "string" then
			local host = ClientState.byId(payload.who)
			if host then
				gotchaUntil[host] = os.clock() + F.FACE_GOTCHA_TIME
			end
		end
		if
			type(payload) == "table"
			and payload.kind == "Pass"
			and type(payload.from) == "string"
			and type(payload.who) == "string"
		then
			passArc(payload.from, payload.who)
		end
	end)
end

return BombController
