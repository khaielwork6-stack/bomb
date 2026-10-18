--!strict
-- World effects for the bomb loop (GDD §10.3): booms, defuses, the field detonation, and camera shake scaled by
-- distance. Every texture is in-house (Shared/Assets.Vfx, from art/vfx/make_vfx.py) and plays in the explosion
-- stack's timing (Asset Bible §5.1: pre-swell → flash → fireball + shockwave → sparks → smoke → scorch).
-- A Carrier's equipped explosion (Eq_Explosion, Asset Bible §5.6) swaps the stack's sprites for its recipe in
-- Client/VfxCosmetic, keeping the PointLight flash, the 7-stud shockwave ring (tinted) and the timing.
-- Implements: F-FEEL-03 (booms, defuse, detonation beats), F-FUSE-03 (visual sweep), F-STORE-01 (explosions in play).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.UI.Theme)
local VfxCosmetic = require(script.Parent.Parent.VfxCosmetic)

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
	if count <= 0 then
		return
	end
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

-- The map's floor under `pos`: the highest of five probes, so a seam between floor strips can't bury what's laid
-- on it (decals) or what lands on it (debris) under its neighbours.
local function groundUnder(pos: Vector3): RaycastResult?
	local params = RaycastParams.new()
	local maps = workspace:FindFirstChild("Maps")
	if maps then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { maps, workspace.Terrain }
	end
	local hit: RaycastResult? = nil
	for _, o in ipairs({ Vector3.zero, Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local h = workspace:Raycast(pos + o * 1.5 + Vector3.new(0, 1, 0), Vector3.new(0, -8, 0), params)
		if h and (not hit or h.Position.Y > hit.Position.Y) then
			hit = h
		end
	end
	return hit
end

-- Debris (Asset Bible §5.1, t = 0.10): four iron shell shards and two brass rivets thrown out of the blast. The
-- shards leave white-hot and cool to iron in flight; everything bounces on the floor and is gone after ~1.4 s.
-- Client-side and kinematic (no physics bodies), so nothing can ever shove a player.
local IRON = Color3.fromRGB(46, 44, 51)
local BRASS = Color3.fromRGB(201, 151, 63)
local function debris(pos: Vector3, floorY: number, s: number, rivetsOnly: boolean?)
	type Piece = { part: BasePart, vel: Vector3, spin: Vector3, half: number, hot: boolean }
	local pieces: { Piece } = {}
	for i = if rivetsOnly then 5 else 1, 6 do
		local rivet = i > 4
		local size = if rivet
			then Vector3.one * 0.38
			else Vector3.new(0.55 + math.random() * 0.45, 0.22, 0.6 + math.random() * 0.5) * s
		local part = new(if rivet then "Part" else "WedgePart", {
			Name = "FV_Debris",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Size = size,
			Shape = if rivet then Enum.PartType.Ball else nil,
			Material = if rivet then Enum.Material.Metal else Enum.Material.Neon,
			Color = if rivet then BRASS else P.Ember,
			CFrame = CFrame.new(pos + Vector3.new(0, 1.5 * s, 0))
				* CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28),
			Parent = workspace,
		}) :: BasePart
		Debris:AddItem(part, 2) -- a safety net: the flight below removes it at ~1.4 s
		if not rivet and i <= 2 then -- two of the shards trail embers
			local a = new("Attachment", { Parent = part })
			new("ParticleEmitter", {
				Texture = Assets.Vfx.Ember,
				Color = ColorSequence.new(P.Spark, P.Fuse),
				LightEmission = 1,
				LightInfluence = 0,
				Size = keys({ { 0, 0.35 }, { 1, 0 } }),
				Lifetime = NumberRange.new(0.25, 0.4),
				Rate = 26,
				Speed = NumberRange.new(0),
				Parent = a,
			})
		end
		local ang = math.random() * math.pi * 2
		local out = (12 + math.random() * 14) * s
		table.insert(pieces, {
			part = part,
			vel = Vector3.new(math.cos(ang) * out, (16 + math.random() * 14) * s, math.sin(ang) * out),
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 24,
			half = math.min(size.X, size.Y, size.Z) / 2,
			hot = not rivet,
		})
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local age = os.clock() - t0
		for _, p in ipairs(pieces) do
			local part = p.part
			p.vel += Vector3.new(0, -80, 0) * dt
			local cf = part.CFrame + p.vel * dt
			local floor = floorY + p.half
			if cf.Position.Y < floor then
				cf = cf + Vector3.new(0, floor - cf.Position.Y, 0)
				p.vel = Vector3.new(p.vel.X * 0.55, math.abs(p.vel.Y) * 0.32, p.vel.Z * 0.55)
				p.spin *= 0.5
			end
			part.CFrame = cf * CFrame.Angles(p.spin.X * dt, p.spin.Y * dt, p.spin.Z * dt)
			if p.hot then -- white-hot → iron
				local k = math.clamp(age / 0.45, 0, 1)
				part.Color = P.Ember:Lerp(IRON, k)
				if k >= 1 and part.Material == Enum.Material.Neon then
					part.Material = Enum.Material.Metal
				end
			end
			if age > 1.0 then
				part.Transparency = math.clamp((age - 1.0) / 0.4, 0, 1)
			end
		end
		if age > 1.4 then
			conn:Disconnect()
			for _, p in ipairs(pieces) do
				p.part:Destroy()
			end
		end
	end)
end

-- A scorch mark on the ground under the blast: holds, then fades (Asset Bible §5.1, step 6).
local function scorch(pos: Vector3, s: number, hit: RaycastResult?, color: Color3?, alpha: number?)
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
	local decal = new("Decal", {
		Texture = Assets.Vfx.Scorch,
		Face = Enum.NormalId.Top,
		Color3 = color or Color3.new(1, 1, 1),
		Transparency = alpha or 0,
		Parent = part,
	})
	task.delay(4, function()
		TweenService:Create(decal, TweenInfo.new(5, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(part, 9.5)
end

-- The shockwave ring, flat on the ground (Asset Bible §5.1; cosmetics only tint it, §5.6). `alpha` lifts its base
-- transparency (Ink Splat's ring is 50 %).
local function shockwave(att: Attachment, s: number, color: Color3, alpha: number)
	emit(att, 1, {
		Texture = Assets.Vfx.Ring,
		Color = ColorSequence.new(color),
		LightEmission = 0.5,
		LightInfluence = 0,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = keys({ { 0, 2 }, { 1, 22 * s } }),
		Transparency = keys({ { 0, alpha }, { 0.6, 0.3 + alpha * 0.7 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.32),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
	})
end

-- Camera shake for a blast at `pos`, by the local player's distance.
local function shakeNear(pos: Vector3, s: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local d = (root.Position - pos).Magnitude
		FxController.shake(if d <= 10 then 0.6 * s elseif d <= 30 then 0.25 * s else 0)
	end
end

-- More than CROWD booms inside CROWD_WINDOW seconds play the cosmetics' light variants (COSMETICS.md §0).
local CROWD, CROWD_WINDOW = 3, 1
local recentBooms: { number } = {}
local function crowded(): boolean
	local t = os.clock()
	for i = #recentBooms, 1, -1 do
		if t - recentBooms[i] > CROWD_WINDOW then
			table.remove(recentBooms, i)
		end
	end
	table.insert(recentBooms, t)
	return #recentBooms > CROWD
end

-- A cosmetic explosion (Asset Bible §5.6): the recipe's layers replace the Classic flash sprite, fireball, sparks,
-- smoke, soot and embers; the PointLight flash, the shockwave ring (tinted), debris and timing stay. `lite` (or a
-- crowd of booms) plays the recipe's light variant: no light, ring, debris or scorch, like the Classic one.
local function cosmeticBoom(pos: Vector3, recipe: VfxCosmetic.Boom, lite: boolean)
	local light = lite or crowded()
	local ground = groundUnder(pos)
	local floorY = if ground then ground.Position.Y else nil
	VfxCosmetic.burst(recipe.layers, pos, recipe.origin, light, floorY)
	if not light then
		local function pop()
			flash(pos, recipe.lightRange or 26, recipe.lightBrightness or 4, recipe.light, 0.2)
			shockwave(burstAt(pos, 1), 1, recipe.ring, recipe.ringAlpha or 0)
		end
		local at = recipe.flashAt - recipe.origin
		if at > 0 then
			task.delay(at, pop)
		else
			pop()
		end
		if recipe.debris ~= "none" then
			debris(pos, floorY or pos.Y - 3, 1, recipe.debris == "rivets")
		end
		local sc = recipe.scorch
		if sc then
			task.delay(math.max(0, sc.t - recipe.origin), scorch, pos, 1, ground, sc.color, sc.alpha)
		end
	end
	shakeNear(pos, 1)
end

-- The explosion stack at `pos` (scale 1 = a full bomb boom), Asset Bible §5.1: flash → fireball + shockwave →
-- sparks + embers → smoke that takes over as the fireball burns out → scorch. The pre-swell is the bomb's own.
-- `lite` is the §5.1 light variant for many booms at once (the field detonation): flash + fireball + 5 sparks +
-- 3 smoke puffs; no light, lumps, ring, embers, debris or scorch (30 of them at once must hold on a phone).
-- `explosion` is the Carrier's equipped Eq_Explosion: one with a recipe plays that instead (at scale 1).
function FxController.boom(pos: Vector3, scale: number?, lite: boolean?, explosion: string?)
	local recipe = VfxCosmetic.explosion(explosion)
	if recipe then
		cosmeticBoom(pos, recipe, lite == true)
		return
	end
	local s = scale or 1
	local att = burstAt(pos, 3.5)
	-- the fireball, flash and smoke sit up off the ground so they read whole; ring, sparks and scorch start at the floor
	local core = burstAt(pos + Vector3.new(0, 2.5 * s, 0), 3.5)
	if not lite then
		flash(pos, 26 * s, 4, P.Spark, 0.2)
	end
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
		if lite then 0 else math.floor(4 * s + 0.5),
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
	if not lite then
		shockwave(att, s, P.Paper, 0)
	end
	-- 4. spark streaks (velocity-aligned) and slow embers
	emit(att, if lite then 5 else math.floor(26 * s), {
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
	emit(att, if lite then 0 else math.floor(14 * s), {
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
			if lite then 3 else math.floor(6 * s + 0.5),
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
	-- 6. debris thrown out, and the scorch it leaves behind
	if not lite then
		local ground = groundUnder(pos)
		debris(pos, if ground then ground.Position.Y else pos.Y - 3, s)
		scorch(pos, s, ground)
	end
	shakeNear(pos, s)
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
				FxController.boom(pos, 0.55, true)
			end
			-- the dust sheet: low, wide puffs kicked up along the row, lingering as a haze for ~2 s (§5.4)
			for c = 0, 4 do
				local x = -halfWidth + (c + 0.5) / 5 * halfWidth * 2
				local dust = burstAt((frame * CFrame.new(x, 1.5, -z)).Position, 3.2)
				emit(
					dust,
					1,
					flipbook({
						Texture = Assets.Vfx.Smoke,
						Color = ColorSequence.new(Color3.fromRGB(214, 196, 170), Color3.fromRGB(186, 174, 160)),
						LightInfluence = 0.4,
						Size = keys({ { 0, 10 }, { 1, 18 } }),
						Transparency = keys({ { 0, 0.3 }, { 0.6, 0.5 }, { 1, 1 } }),
						Lifetime = NumberRange.new(2, 2.6),
						Speed = NumberRange.new(2, 4),
						SpreadAngle = Vector2.new(60, 60),
						EmissionDirection = Enum.NormalId.Top,
						Acceleration = Vector3.new(0, 0.8, 0),
						Rotation = NumberRange.new(-30, 30),
						RotSpeed = NumberRange.new(-10, 10),
						ZOffset = -2,
					})
				)
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
			local host = if type(p.who) == "string" then ClientState.byId(p.who) else nil
			local eq = host and host:GetAttribute("Eq_Explosion")
			FxController.boom(p.pos, nil, nil, if type(eq) == "string" then eq else nil)
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
