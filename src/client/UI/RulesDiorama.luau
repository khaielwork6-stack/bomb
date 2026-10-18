--!strict
-- The How to Play cards' live scenes (GDD §20; the owner, 2026-10-18: "more realistic, more Roblox friendly, more
-- animated and colourful"). Each rule card gets a ViewportFrame with a tiny diorama that loops: blocky R6 players
-- (a red Bomber, blue Runners) running on a studded floor, the real hero bomb (ReplicatedStorage.FV_Art.Bomb) on
-- their backs:
--   1. A BOMBER'S TOUCH: the Bomber dashes in, taps the Runner, and the bomb pops onto the Runner's back.
--   2. BUMP TO PASS: the carrier bumps a second Runner and the bomb arcs over onto them.
--   3. NO RESETS: the bomb hops back and forth between two Runners while its fuse keeps burning down — it never
--      refills — until it pops, then the loop starts again.
--   4. SAFE SIDE: the carrier sprints onto the green SAFE strip; the bomb lifts off with a puff and a shield pops.
-- ViewportFrames draw no particles or SurfaceGuis, so puffs, shields and the fuse bar are 2D overlays.
-- Implements: F-ONB-02 (the rules card's illustrations).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local new = Theme.new
local P = Theme.Palette
local rgb = Color3.fromRGB

local RulesDiorama = {}

local SKIN = rgb(255, 214, 120)
local RUNNER = P.Runner
local BOMBER = P.Bomber
local PANTS = rgb(40, 52, 110)
local LOOP = 2.6 -- seconds per loop
local BOMB_SCALE = 0.62
local CAM = CFrame.lookAt(Vector3.new(0, 5.6, 14), Vector3.new(0, 2.7, 0))
local FOV = 34
local HIDDEN = CFrame.new(0, -100, 0)
local WORDS = Config.Strings.Ui.RuleFx

type Rig = { model: Model, root: CFrame, parts: { [string]: BasePart }, shadow: BasePart, phase: number }

local function part(m: Model, name: string, size: Vector3, color: Color3): Part
	local p = new("Part", {
		Name = name,
		Size = size,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = m,
	}) :: Part
	return p
end

-- A classic blocky R6 player: head with a smile, torso in the team colour, skin arms, dark legs.
local function rig(world: Instance, shirt: Color3): Rig
	local m = new("Model", { Name = "Rig", Parent = world }) :: Model
	local parts = {
		Head = part(m, "Head", Vector3.new(1.2, 1.2, 1.2), SKIN),
		Torso = part(m, "Torso", Vector3.new(2, 2, 1), shirt),
		LArm = part(m, "LArm", Vector3.new(1, 2, 1), SKIN),
		RArm = part(m, "RArm", Vector3.new(1, 2, 1), SKIN),
		LLeg = part(m, "LLeg", Vector3.new(1, 2, 1), PANTS),
		RLeg = part(m, "RLeg", Vector3.new(1, 2, 1), PANTS),
	}
	new("Decal", { Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front, Parent = parts.Head })
	-- a soft round shadow under the feet grounds them on the floor
	local shadow = part(m, "Shadow", Vector3.new(0.05, 2.6, 2.6), Color3.new(0, 0, 0))
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Transparency = 0.65
	return { model = m, root = CFrame.new(), parts = parts, shadow = shadow, phase = math.random() * 6 }
end

-- Pose a rig at `cf` (feet on y = 0), mid-run by `run` (0 = standing, 1 = full stride) at time `t`.
local function pose(r: Rig, cf: CFrame, run: number, t: number)
	r.root = cf
	local swing = math.sin(t * 14 + r.phase) * math.rad(55) * run
	local bob = math.abs(math.sin(t * 14 + r.phase)) * 0.18 * run
	local base = cf * CFrame.new(0, 3 + bob, 0) * CFrame.Angles(math.rad(-10) * run, 0, 0)
	local p = r.parts
	p.Torso.CFrame = base
	p.Head.CFrame = base * CFrame.new(0, 1.6, 0)
	local function limb(bp: BasePart, x: number, y: number, a: number)
		bp.CFrame = base * CFrame.new(x, y, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -1, 0)
	end
	limb(p.LArm, -1.5, 1, swing)
	limb(p.RArm, 1.5, 1, -swing)
	limb(p.LLeg, -0.5, -1, -swing)
	limb(p.RLeg, 0.5, -1, swing)
	r.shadow.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

-- The hero bomb, small, anchored; returns it and a setter for its world CFrame.
local function bomb(world: Instance): (Model?, (CFrame) -> ())
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb")
	if not template or not template:IsA("Model") then
		local ball = new("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			Color = rgb(30, 30, 40),
			Anchored = true,
			Parent = world,
		}) :: Part
		return nil, function(cf: CFrame)
			ball.CFrame = cf
		end
	end
	local m = template:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m:ScaleTo(m:GetScale() * BOMB_SCALE)
	m.Parent = world
	return m, function(cf: CFrame)
		m:PivotTo(cf)
	end
end

-- Where a carried bomb sits: high on the back, peeking over the shoulder so it reads with the body turned to us.
local function backOf(r: Rig): CFrame
	return r.parts.Torso.CFrame * CFrame.new(0.45, 1.5, 0.9) * CFrame.Angles(0, math.pi, 0)
end

local function floor(world: Instance, color: Color3)
	local f = part(world :: any, "Floor", Vector3.new(26, 1, 12), color)
	f.CFrame = CFrame.new(0, -0.5, -1)
	-- studs: a grid of small cylinders reads as the toy floor
	for x = -12, 12, 2 do
		for z = -6, 4, 2 do
			local s = part(world :: any, "Stud", Vector3.new(0.18, 0.7, 0.7), color:Lerp(Color3.new(1, 1, 1), 0.15))
			s.Shape = Enum.PartType.Cylinder
			s.CFrame = CFrame.new(x, 0.05, z) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

-- 2D overlay helpers (ViewportFrames don't draw particles)
local function puff(overlay: Instance, at: UDim2)
	local p = Widgets.icon(overlay, "Explosion", 48, { AnchorPoint = Vector2.new(0.5, 0.5), Position = at, ZIndex = 9 })
	local h = p.Parent :: Frame
	local sc = new("UIScale", { Scale = 0.4, Parent = h })
	TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(p, TweenInfo.new(0.6), { ImageTransparency = 1 }):Play()
	task.delay(0.65, function()
		h:Destroy()
	end)
end

-- A chunky pop word ("TAG!") that springs up, wobbles and fades.
local function popWord(overlay: Instance, text: string, color: Color3, x: number?)
	local l = Widgets.label(overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x or 0.5, 0.26),
		Size = UDim2.fromScale(1, 0.3),
		TextSize = 24,
		font = Theme.Font.Display,
		color = color,
		stroke = 2.5,
		Text = text,
		ZIndex = 11,
	})
	l.Rotation = -8
	local sc = new("UIScale", { Scale = 0.2, Parent = l })
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(l, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Rotation = 6 }):Play()
	task.delay(0.6, function()
		TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, Position = UDim2.fromScale(x or 0.5, 0.14) })
			:Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
	end)
	task.delay(0.95, function()
		l:Destroy()
	end)
end

-- Two soft clouds drifting across the window's sky, behind the 3D.
local function clouds(window: Instance)
	for k = 1, 2 do
		local c = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(if k == 1 then 0.25 else 0.8, if k == 1 then 0.16 else 0.3),
			Size = UDim2.fromOffset(if k == 1 then 46 else 34, if k == 1 then 14 else 11),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.15,
			ZIndex = 5,
			Parent = window,
		}) :: Frame
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = c })
		local bump = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.42, 0.5),
			Size = UDim2.fromScale(0.5, 1.3),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.15,
			ZIndex = 5,
			Parent = c,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bump })
		TweenService:Create(
			c,
			TweenInfo.new(5 + k * 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = c.Position + UDim2.fromScale(if k == 1 then 0.2 else -0.25, 0) }
		):Play()
	end
end

local function project(world: Vector3, size: Vector2): UDim2
	local p = CAM:PointToObjectSpace(world)
	local t = math.tan(math.rad(FOV) / 2)
	local aspect = size.X / math.max(1, size.Y)
	local x = p.X / (-p.Z * t * aspect)
	local y = p.Y / (-p.Z * t)
	return UDim2.fromScale((x + 1) / 2, (1 - y) / 2)
end

local function lerp(a: number, b: number, x: number): number
	return a + (b - a) * math.clamp(x, 0, 1)
end

local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Build rule `i`'s scene inside `stage` (a Frame), floor tinted `color`. It animates while `stage` is in the game.
function RulesDiorama.build(stage: Frame, i: number, color: Color3)
	-- the window: a rounded sky-blue screen with a white rim (a CanvasGroup so the 3D clips to the corners)
	local window = new("CanvasGroup", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = stage,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = window })
	-- the sky on its own layer (a gradient on the CanvasGroup itself would tint the whole scene)
	local sky = new("Frame", {
		Name = "Sky",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = window,
	})
	new("UIGradient", {
		Color = ColorSequence.new(rgb(88, 190, 255), rgb(200, 238, 255)),
		Rotation = 90,
		Parent = sky,
	})
	new("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = window,
	})
	clouds(window)
	local vp = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = rgb(200, 200, 210),
		LightColor = rgb(255, 248, 232),
		LightDirection = Vector3.new(-0.5, -1, -0.6),
		ZIndex = 6,
		Parent = window,
	}) :: ViewportFrame
	local world = new("WorldModel", { Parent = vp })
	local cam = new("Camera", { CFrame = CAM, FieldOfView = FOV, Parent = vp }) :: Camera
	vp.CurrentCamera = cam
	local overlay =
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = stage })
	floor(world, color)
	local face = CFrame.Angles(0, math.rad(-122), 0) -- running toward +X (screen right), turned 3/4 to the camera
	local step: (number, number) -> ()

	if i == 1 then
		local runner, bomber = rig(world, RUNNER), rig(world, BOMBER)
		local _, setBomb = bomb(world)
		local stuck = false
		step = function(t: number, c: number)
			local tapAt = 0.45
			local rx = lerp(-0.5, 3, c)
			local bx = if c < tapAt then lerp(-6.5, rx - 2.2, c / tapAt) else rx - 2.2 - (c - tapAt) * 6
			pose(runner, CFrame.new(rx, 0, 0) * face, 1, t)
			pose(bomber, CFrame.new(bx, 0, 0.3) * face, 1, t)
			local onRunner = c >= tapAt
			if onRunner and not stuck then
				puff(overlay, project(backOf(runner).Position, vp.AbsoluteSize))
				popWord(overlay, WORDS[1], rgb(255, 90, 70))
			end
			stuck = onRunner
			if onRunner then
				local pop = math.clamp((c - tapAt) / 0.12, 0, 1)
				setBomb(backOf(runner) * CFrame.new(0, (1 - pop) * 1.4, 0))
			else
				setBomb(HIDDEN)
			end
		end
	elseif i == 2 then
		local a, b = rig(world, RUNNER), rig(world, rgb(120, 236, 110))
		local _, setBomb = bomb(world)
		local passed = false
		step = function(t: number, c: number)
			local bumpAt = 0.4
			if c >= bumpAt and not passed then
				passed = true
				popWord(overlay, WORDS[2], rgb(255, 220, 60))
			elseif c < bumpAt then
				passed = false
			end
			local ax = lerp(-6, -0.6, math.min(c / bumpAt, 1)) - math.max(0, c - bumpAt) * 3
			pose(a, CFrame.new(ax, 0, 0) * face, if c < bumpAt then 1 else 0.3, t)
			pose(b, CFrame.new(1.6 + math.max(0, c - bumpAt) * 5, 0, 0) * face, if c < bumpAt then 0.15 else 1, t)
			if c < bumpAt then
				setBomb(backOf(a))
			else
				local f = ease((c - bumpAt) / 0.25)
				local from, to = backOf(a).Position, backOf(b).Position
				local arc = from:Lerp(to, f) + Vector3.new(0, math.sin(f * math.pi) * 1.1, 0)
				setBomb(CFrame.new(arc) * CFrame.Angles(f * math.pi * 2, 0, 0))
			end
		end
	elseif i == 3 then
		local a, b = rig(world, RUNNER), rig(world, rgb(255, 160, 220))
		local bombModel, setBomb = bomb(world)
		-- the fuse bar (2D) that only ever burns down
		local well = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(0.8, 0, 0, 10),
			BackgroundColor3 = P.Ink,
			ZIndex = 9,
			Parent = overlay,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = well })
		local fill =
			new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.Fuse, ZIndex = 10, Parent = well })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
		new("UIGradient", { Color = ColorSequence.new(rgb(255, 220, 90), rgb(255, 90, 40)), Parent = fill })
		local popped = false
		step = function(t: number, c: number)
			pose(a, CFrame.new(-2.6, 0, 0) * CFrame.Angles(0, math.rad(-135), 0), 0.25, t)
			pose(b, CFrame.new(2.6, 0, 0) * CFrame.Angles(0, math.rad(135), 0), 0.25, t)
			fill.Size = UDim2.fromScale(1 - c, 1)
			-- three hops back and forth
			local hop = c * 3
			local k = math.floor(hop)
			local f = ease(hop - k)
			local fromR, toR = if k % 2 == 0 then a else b, if k % 2 == 0 then b else a
			local from, to = backOf(fromR).Position, backOf(toR).Position
			local arc = from:Lerp(to, f) + Vector3.new(0, math.sin(f * math.pi) * 0.7, 0)
			setBomb(CFrame.new(arc) * CFrame.Angles(0, math.pi, 0))
			if c > 0.96 and not popped then
				popped = true
				puff(overlay, project(arc, vp.AbsoluteSize))
				popWord(overlay, WORDS[3], rgb(255, 170, 40))
				if bombModel then
					bombModel.Parent = nil
				end
			elseif c < 0.5 and popped then
				popped = false
				if bombModel then
					bombModel.Parent = world
				end
			end
		end
	else
		local runner = rig(world, RUNNER)
		local _, setBomb = bomb(world)
		local strip = part(world :: any, "Safe", Vector3.new(4.6, 1.05, 12), rgb(70, 235, 120))
		strip.CFrame = CFrame.new(3.6, -0.48, -1)
		local shield = Widgets.icon(overlay, "Shield", 40, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.78, 0.22),
			ZIndex = 10,
		})
		local shieldHolder = shield.Parent :: Frame
		local sc = new("UIScale", { Scale = 0, Parent = shieldHolder })
		local safeAt = 0.55
		local defused = false
		step = function(t: number, c: number)
			local x = lerp(-5, 3.2, math.min(c / safeAt, 1))
			pose(runner, CFrame.new(x, 0, 0) * face, if c < safeAt then 1 else 0.1, t)
			if c < safeAt then
				setBomb(backOf(runner))
				sc.Scale = 0
			else
				local f = (c - safeAt) / (1 - safeAt)
				setBomb(backOf(runner) * CFrame.new(0, f * 6, -f * 2) * CFrame.Angles(f * 4, 0, 0))
				sc.Scale = math.min(1, f * 4)
			end
			if c >= safeAt and not defused then
				defused = true
				puff(overlay, project(backOf(runner).Position, vp.AbsoluteSize))
				popWord(overlay, WORDS[4], rgb(110, 255, 140), 0.38)
			elseif c < safeAt then
				defused = false
			end
		end
	end

	local t0 = os.clock() + i * 0.37
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not stage.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		step(t, (t % LOOP) / LOOP)
	end)
end

return RulesDiorama
