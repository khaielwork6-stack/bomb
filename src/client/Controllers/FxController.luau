--!strict
-- World effects for the bomb loop (GDD §10.3): booms, defuses, the field detonation, and camera shake scaled by
-- distance. Every texture is in-house (Shared/Assets.Vfx, from art/vfx/make_vfx.py) and plays in the explosion
-- stack's timing (Asset Bible §5.1: pre-swell → flash → fireball + shockwave → sparks → smoke → scorch).
-- Implements: F-FEEL-03 (booms, defuse, detonation beats), F-FUSE-03 (visual sweep).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local FxController = {}

-- ── Camera shake (trauma model: amplitude = trauma², decays) ────────────────────────────────────────────────────
local trauma = 0
function FxController.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

local function shakeStep(dt: number)
	if trauma <= 0 then
		return
	end
	local cam = workspace.CurrentCamera
	local a = trauma * trauma
	local t = os.clock() * 28
	local off = CFrame.Angles(
		math.rad(math.noise(t, 1) * 2.2 * a),
		math.rad(math.noise(t, 2) * 2.2 * a),
		math.rad(math.noise(t, 3) * 1.6 * a)
	)
	cam.CFrame *= off
	trauma = math.max(0, trauma - dt * 1.6)
end

-- ── Bursts ──────────────────────────────────────────────────────────────────────────────────────────────────────
local function burstAt(pos: Vector3, life: number): Attachment
	local att = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain })
	Debris:AddItem(att, life)
	return att
end

local function emit(att: Attachment, count: number, props: { [string]: any })
	local e = new("ParticleEmitter", props)
	e.Rate = 0
	e.Parent = att
	e:Emit(count)
end

local function flash(pos: Vector3, range: number, brightness: number, color: Color3, time: number)
	local holder = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		Position = pos,
		Parent = workspace,
	})
	local light = new("PointLight", { Range = range, Brightness = brightness, Color = color, Parent = holder })
	TweenService:Create(light, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()
	Debris:AddItem(holder, time + 0.1)
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function keys(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in ipairs(points) do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

-- The toon flipbooks keep their drawn colours and Ink outlines: no world lighting, no additive wash.
local function flipbook(props: { [string]: any }): { [string]: any }
	props.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	props.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	props.LightInfluence = 0
	props.LightEmission = props.LightEmission or 0
	return props
end

-- A scorch mark on the ground under the blast: holds, then fades (Asset Bible §5.1, step 6).
local function scorch(pos: Vector3, s: number)
	local params = RaycastParams.new()
	local maps = workspace:FindFirstChild("Maps")
	if maps then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { maps, workspace.Terrain }
	end
	-- the highest of five probes, so a seam between turf strips can't bury the decal under its neighbours
	local hit: RaycastResult? = nil
	for _, o in ipairs({ Vector3.zero, Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local h = workspace:Raycast(pos + o * 1.5 + Vector3.new(0, 1, 0), Vector3.new(0, -8, 0), params)
		if h and (not hit or h.Position.Y > hit.Position.Y) then
			hit = h
		end
	end
	if not hit then
		return
	end
	local at = Vector3.new(pos.X, hit.Position.Y, pos.Z)
	local size = 9 * s
	local part = new("Part", {
		Name = "FV_Scorch",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(size, 0.05, size),
		CFrame = CFrame.lookAt(at, at + hit.Normal)
				* CFrame.Angles(-math.pi / 2, 0, 0)
				* CFrame.Angles(0, math.random() * math.pi * 2, 0)
			+ hit.Normal * 0.03,
		Parent = workspace,
	})
	local decal = new("Decal", { Texture = Assets.Vfx.Scorch, Face = Enum.NormalId.Top, Parent = part })
	task.delay(4, function()
		TweenService:Create(decal, TweenInfo.new(5, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(part, 9.5)
end

-- The explosion stack at `pos` (scale 1 = a full bomb boom), Asset Bible §5.1: flash → fireball + shockwave →
-- sparks + embers → smoke that takes over as the fireball burns out → scorch. The pre-swell is the bomb's own.
function FxController.boom(pos: Vector3, scale: number?)
	local s = scale or 1
	local att = burstAt(pos, 3.5)
	-- the fireball, flash and smoke sit up off the ground so they read whole; ring, sparks and scorch start at the floor
	local core = burstAt(pos + Vector3.new(0, 2.5 * s, 0), 3.5)
	flash(pos, 26 * s, 4, P.Spark, 0.2)
	-- 1. the star flash: one frame-fast pop, bigger than everything else
	emit(core, 1, {
		Texture = Assets.Vfx.Flash,
		Color = ColorSequence.new(Color3.new(1, 0.97, 0.85)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = keys({ { 0, 6 * s }, { 0.4, 16 * s }, { 1, 18 * s } }),
		Transparency = keys({ { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.12),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 60),
		ZOffset = 3,
	})
	-- 2. the fireball: one hero ball plus smaller lumps thrown off it, each burning out on its own flipbook
	emit(
		core,
		1,
		flipbook({
			Texture = Assets.Vfx.Fireball,
			Size = keys({ { 0, 9 * s }, { 1, 11 * s } }),
			Lifetime = NumberRange.new(0.6),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			ZOffset = 2,
		})
	)
	emit(
		core,
		math.floor(4 * s + 0.5),
		flipbook({
			Texture = Assets.Vfx.Fireball,
			Size = keys({ { 0, 4 * s }, { 1, 6 * s } }),
			Lifetime = NumberRange.new(0.45, 0.6),
			Speed = NumberRange.new(10 * s, 16 * s),
			Drag = 7,
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 8, 0),
			Rotation = NumberRange.new(0, 360),
			ZOffset = 1.5,
		})
	)
	-- 3. the shockwave ring, flat on the ground
	emit(att, 1, {
		Texture = Assets.Vfx.Ring,
		Color = ColorSequence.new(P.Paper),
		LightEmission = 0.5,
		LightInfluence = 0,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = keys({ { 0, 2 }, { 1, 22 * s } }),
		Transparency = keys({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.32),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
	})
	-- 4. spark streaks (velocity-aligned) and slow embers
	emit(att, math.floor(26 * s), {
		Texture = Assets.Vfx.Streak,
		Color = ColorSequence.new(P.Spark, P.Fuse),
		LightEmission = 1,
		LightInfluence = 0,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = keys({ { 0, 0.9 * s }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(45 * s, 80 * s),
		Drag = 6,
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -30, 0),
	})
	emit(att, math.floor(14 * s), {
		Texture = Assets.Vfx.Ember,
		Color = ColorSequence.new(P.Spark, P.Fuse),
		LightEmission = 1,
		LightInfluence = 0,
		Size = keys({ { 0, 0.45 }, { 0.8, 0.3 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(8, 18),
		Drag = 2,
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 4, 0),
	})
	-- 5. smoke: puffs bloom behind the fireball just as it starts breaking up, then dissolve puff by puff
	task.delay(0.18, function()
		if core.Parent == nil then
			return
		end
		emit(
			core,
			math.floor(6 * s + 0.5),
			flipbook({
				Texture = Assets.Vfx.Smoke,
				Color = ColorSequence.new(Color3.fromRGB(236, 230, 224), Color3.fromRGB(200, 196, 204)),
				Size = keys({ { 0, 5 * s }, { 1, 8 * s } }),
				Lifetime = NumberRange.new(1.1, 1.5),
				Speed = NumberRange.new(5 * s, 10 * s),
				Drag = 3,
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 5, 0),
				Rotation = NumberRange.new(-20, 20),
				RotSpeed = NumberRange.new(-25, 25),
				ZOffset = -1,
			})
		)
	end)
	-- 6. the scorch it leaves behind
	scorch(pos, s)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local d = (root.Position - pos).Magnitude
		FxController.shake(if d <= 10 then 0.6 * s elseif d <= 30 then 0.25 * s else 0)
	end
end

-- Defuse (GDD §10.3): a steam puff off the socket and a soft green ring; a clutch adds a gold flare.
function FxController.defuse(pos: Vector3, clutch: boolean)
	local att = burstAt(pos + Vector3.new(0, 1.5, 0), 2)
	emit(
		att,
		3,
		flipbook({
			Texture = Assets.Vfx.Smoke,
			Color = ColorSequence.new(Color3.fromRGB(240, 246, 244)),
			Size = seq(1.4, 3),
			Lifetime = NumberRange.new(0.8, 1),
			Speed = NumberRange.new(3, 5),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(-20, 20),
		})
	)
	emit(att, 1, {
		Texture = Assets.Vfx.Ring,
		Color = ColorSequence.new(if clutch then P.Gold else P.Safe),
		LightEmission = 0.8,
		LightInfluence = 0,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = seq(1, if clutch then 12 else 7),
		Transparency = seq(0.1, 1),
		Lifetime = NumberRange.new(0.4),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
	})
	if clutch then
		flash(pos, 18, 5, P.Gold, 0.4)
		emit(att, 30, {
			Texture = Assets.Vfx.Ember,
			Color = ColorSequence.new(P.Gold, P.Spark),
			LightEmission = 1,
			LightInfluence = 0,
			Size = seq(0.6, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(10, 22),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 4,
		})
	end
end

-- F-FUSE-03: a rolling chain of blasts across the field over `sweep` seconds, from the side Runners left.
local function fieldDetonation(fromSide: number, sweep: number)
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local frame = gs and gs:GetAttribute("FieldCFrame")
	local halfLen = gs and gs:GetAttribute("FieldHalfLen")
	local halfWidth = gs and gs:GetAttribute("FieldHalfWidth")
	if typeof(frame) ~= "CFrame" or type(halfLen) ~= "number" or type(halfWidth) ~= "number" then
		return
	end
	local rows, cols = 6, 5
	FxController.shake(0.45)
	for r = 0, rows - 1 do
		local z = fromSide * halfLen * (1 - 2 * (r + 0.5) / rows) -- starts at the side the Runners left
		task.delay(sweep * r / rows, function()
			for c = 0, cols - 1 do
				local x = -halfWidth + (c + 0.5) / cols * halfWidth * 2 + (math.random() - 0.5) * 6
				local pos = (frame * CFrame.new(x, 1, -z)).Position
				FxController.boom(pos, 0.55)
			end
		end)
	end
end

function FxController.start()
	RunService:BindToRenderStep("FV_Shake", Enum.RenderPriority.Camera.Value + 10, shakeStep)
	Net.listen("BombFx", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.kind == "Boom" and typeof(p.pos) == "Vector3" then
			FxController.boom(p.pos)
		elseif p.kind == "Defuse" and typeof(p.pos) == "Vector3" then
			FxController.defuse(p.pos, p.clutch == true)
		end
	end)
	Net.listen("FieldFx", function(p)
		if type(p) == "table" and p.kind == "Detonate" then
			fieldDetonation(
				if type(p.side) == "number" then p.side else -1,
				if type(p.sweep) == "number" then p.sweep else 0.6
			)
		end
	end)
end

return FxController
