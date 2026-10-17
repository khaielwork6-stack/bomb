--!strict
-- World effects for the bomb loop (GDD §10.3): booms, defuses, the field detonation, and camera shake scaled by
-- distance. P1 uses engine particle textures in the explosion stack's timing (Asset Bible §5.1: pre-swell → flash →
-- fireball + shockwave → sparks → smoke); the in-house textures and debris replace them in the P3 FX pass.
-- Implements: F-FEEL-03 (booms, defuse, detonation beats), F-FUSE-03 (visual sweep).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer
local TEX = "rbxasset://textures/particles/"

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

-- The explosion stack at `pos` (scale 1 = a full bomb boom).
function FxController.boom(pos: Vector3, scale: number?)
	local s = scale or 1
	local att = burstAt(pos, 2.5)
	flash(pos, 26 * s, 6, P.Spark, 0.18)
	emit(att, math.floor(3 * s + 0.5), {
		Texture = TEX .. "explosion01_core_main.dds",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0.9)),
			ColorSequenceKeypoint.new(0.35, P.Spark),
			ColorSequenceKeypoint.new(1, P.Fuse),
		}),
		LightEmission = 1,
		Size = seq(3 * s, 8 * s),
		Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.3, 0.4),
		Speed = NumberRange.new(0, 2),
		Rotation = NumberRange.new(0, 360),
	})
	emit(att, 1, {
		Texture = TEX .. "explosion01_shockwave_main.dds",
		Color = ColorSequence.new(P.Paper),
		LightEmission = 0.6,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = seq(1, 14 * s),
		Transparency = seq(0.2, 1),
		Lifetime = NumberRange.new(0.25),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
	})
	emit(att, math.floor(24 * s), {
		Texture = TEX .. "fire_sparks_main.dds",
		Color = ColorSequence.new(P.Spark, P.Fuse),
		LightEmission = 1,
		Size = seq(0.5 * s, 0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(40 * s, 70 * s),
		Drag = 6,
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -30, 0),
	})
	emit(att, math.floor(8 * s), {
		Texture = TEX .. "smoke_main.dds",
		Color = ColorSequence.new(P.Smoke, P.Ash),
		Size = seq(2.5 * s, 7 * s),
		Transparency = seq(0.15, 1),
		Lifetime = NumberRange.new(0.9, 1.2),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 6, 0),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local d = (root.Position - pos).Magnitude
		FxController.shake(if d <= 10 then 0.6 * s elseif d <= 30 then 0.25 * s else 0)
	end
end

-- Defuse (GDD §10.3): a steam puff off the socket and a soft green ring; a clutch adds a gold flare.
function FxController.defuse(pos: Vector3, clutch: boolean)
	local att = burstAt(pos + Vector3.new(0, 1.5, 0), 2)
	emit(att, 6, {
		Texture = TEX .. "smoke_main.dds",
		Color = ColorSequence.new(P.Paper),
		Size = seq(0.6, 2.4),
		Transparency = seq(0.3, 1),
		Lifetime = NumberRange.new(0.7, 1),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
	})
	emit(att, 1, {
		Texture = TEX .. "explosion01_shockwave_main.dds",
		Color = ColorSequence.new(if clutch then P.Gold else P.Safe),
		LightEmission = 0.8,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = seq(1, if clutch then 12 else 7),
		Transparency = seq(0.2, 1),
		Lifetime = NumberRange.new(0.4),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
	})
	if clutch then
		flash(pos, 18, 5, P.Gold, 0.4)
		emit(att, 30, {
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(P.Gold, P.Spark),
			LightEmission = 1,
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
