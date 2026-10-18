--!strict
-- The cosmetic VFX (Asset Bible §5.6 explosions, §8.1 fuse sparks, §8.2 trails, §8.3 victory booms): every item's
-- recipe as data, straight from art/vfx/COSMETICS.md, plus the small executor that plays them. Textures are the
-- in-house set in Shared/Assets.VfxCosmetic (art/vfx/make_cosmetics.py); Classic ones are named "Vfx.<Name>".
-- A layer's lowercase keys are recipe meta (t, tex, n, lite, at, grid, flip, shell); its Capitalised keys go
-- straight onto the ParticleEmitter. Every emitter is unlit (LightInfluence 0) and white unless the layer tints it.
-- Implements: F-STORE-01 (cosmetics in play), Asset Bible §5.6, §8.1–8.3; GDD §10.4 (same timing, same splash ring).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)

local VfxCosmetic = {}

export type Layer = { [string]: any }
export type Boom = {
	ring: Color3, -- the Classic 7-stud shockwave ring's tint
	ringAlpha: number?, -- its base transparency (Ink Splat's ring is 50 %)
	light: Color3, -- the PointLight flash
	lightBrightness: number?,
	lightRange: number?,
	origin: number, -- the stack time the Boom beat lands on (0.08, the flash; Black Hole: 0, the implosion)
	flashAt: number, -- the stack time of the PointLight flash and the ring
	debris: string, -- "all" | "rivets" (no iron shards) | "none"
	scorch: { t: number, color: Color3?, alpha: number? }?, -- nil: no scorch (a floor sprite replaces it)
	layers: { Layer },
}

-- ── Tunables ────────────────────────────────────────────────────────────────────────────────────────────────────
local MAX_PARTICLES = 220 -- per explosion at peak (COSMETICS.md §0)
local CORE_UP = 2.5 -- studs: the big sprites sit up off the ground, like the Classic fireball
local FLOOR_LIFT = 0.05 -- studs: flat floor sprites ride just above the floor
local CLEAN_PAD = 0.5 -- s: an emitter's holder outlives its longest particle by this
-- Pick-a-frame sheets: one random frame per particle, held. If the engine ever plays them as frame 1 for everyone,
-- switch to { mode = Enum.ParticleFlipbookMode.Random, rate = 0.5 } (COSMETICS.md §0).
local PICK = { mode = Enum.ParticleFlipbookMode.Loop, rate = 0 }

-- ── Little builders for the data below ──────────────────────────────────────────────────────────────────────────
local function r(a: number, b: number?): NumberRange
	return NumberRange.new(a, b or a)
end

local function ramp(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- "Size 0.7–1.0": one value per particle, held (an envelope around the middle).
local function env(lo: number, hi: number): NumberSequence
	local mid, half = (lo + hi) / 2, (hi - lo) / 2
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, mid, half), NumberSequenceKeypoint.new(1, mid, half) })
end

local function keys(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in ipairs(points) do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function cs(a: string, b: string?): ColorSequence
	return ColorSequence.new(hex(a), hex(b or a))
end

local function with(base: Layer, extra: Layer): Layer
	local out = table.clone(base)
	for k, v in pairs(extra) do
		out[k] = v
	end
	return out
end

local SPHERE = Vector2.new(180, 180)
local function cone(deg: number): Vector2
	return Vector2.new(deg, deg)
end
local UP = Enum.NormalId.Top
local PARALLEL = Enum.ParticleOrientation.VelocityParallel

-- Classic motion, reused where a recipe says "Classic" (FxController's smoke and embers, Asset Bible §5.1).
local SMOKE: Layer = {
	tex = "Vfx.Smoke",
	grid = "4x4",
	flip = "OneShot",
	Speed = r(5, 10),
	Drag = 3,
	SpreadAngle = SPHERE,
	Acceleration = Vector3.new(0, 5, 0),
	Rotation = r(-20, 20),
	RotSpeed = r(-25, 25),
	ZOffset = -1,
}
local EMBER: Layer = {
	tex = "Vfx.Ember",
	LightEmission = 1,
	Speed = r(8, 18),
	Drag = 2,
	SpreadAngle = SPHERE,
	Acceleration = Vector3.new(0, 4, 0),
}
local FLASH: Layer = { tex = "Vfx.Flash", n = 1, LightEmission = 1, Speed = r(0), ZOffset = 3 }

-- ── §1 Explosions ───────────────────────────────────────────────────────────────────────────────────────────────
local PIXEL_BLINK = keys({ { 0, 0 }, { 0.6, 0 }, { 0.65, 1 }, { 0.72, 0 }, { 0.8, 1 }, { 0.86, 0 }, { 1, 1 } })
local PIXEL_CUBE: Layer = {
	t = 0.10,
	tex = "boom_pixel_cube",
	n = 9,
	lite = 3,
	at = "base",
	Size = env(0.9, 1.3),
	Lifetime = r(0.7, 1.0),
	Speed = r(28, 44),
	SpreadAngle = SPHERE,
	Acceleration = Vector3.new(0, -50, 0),
	Drag = 1.5,
	Rotation = r(0),
	RotSpeed = r(0),
	Transparency = PIXEL_BLINK,
}

VfxCosmetic.Explosions = {
	Boom_Confetti = {
		ring = hex("#FF5CA8"),
		light = hex("#FFD84A"),
		origin = 0.08,
		flashAt = 0.08,
		debris = "rivets",
		scorch = { t = 0.15, alpha = 0.4 },
		layers = {
			{
				t = 0.08,
				tex = "boom_confetti_pop",
				n = 1,
				lite = 1,
				Size = ramp(8, 10),
				Lifetime = r(0.14),
				Speed = r(0),
				Rotation = r(-15, 15),
				Transparency = keys({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
			},
			{
				t = 0.08,
				tex = "boom_confetti_pieces",
				grid = "4x4",
				flip = "Pick",
				n = 70,
				lite = 20,
				at = "base",
				Size = env(0.7, 1.0),
				Lifetime = r(1.6, 2.2),
				Speed = r(30, 48),
				EmissionDirection = UP,
				SpreadAngle = cone(70),
				Acceleration = Vector3.new(0, -30, 0),
				Drag = 3,
				Rotation = r(0, 360),
				RotSpeed = r(-360, 360),
			},
			{
				t = 0.10,
				tex = "boom_confetti_streamers",
				grid = "2x2",
				flip = "Pick",
				n = 10,
				lite = 2,
				at = "base",
				Size = env(2.2, 2.8),
				Lifetime = r(1.8),
				Speed = r(22, 32),
				EmissionDirection = UP,
				SpreadAngle = cone(50),
				Acceleration = Vector3.new(0, -18, 0),
				Drag = 2.5,
				RotSpeed = r(-120, 120),
			},
			with(SMOKE, { t = 0.15, n = 4, Size = ramp(5, 7), Lifetime = r(0.9), Color = cs("#FFF3E2") }),
		},
	},
	Boom_InkSplat = {
		ring = hex("#16121C"),
		ringAlpha = 0.5,
		light = hex("#FFF3E2"),
		lightBrightness = 3,
		origin = 0.08,
		flashAt = 0.08,
		debris = "all",
		scorch = nil, -- the floor splat is the scorch
		layers = {
			{
				t = 0.08,
				tex = "boom_ink_splash",
				grid = "4x4",
				flip = "OneShot",
				n = 2,
				lite = 1,
				Size = env(7.5, 8.5),
				Lifetime = r(0.55),
				Speed = r(0),
				Rotation = r(0, 360),
				ZOffset = 1,
			},
			{
				t = 0.10,
				tex = "boom_ink_droplet",
				n = 20,
				lite = 8,
				at = "base",
				Orientation = PARALLEL,
				Size = ramp(0.5, 0.25),
				Lifetime = r(0.5, 0.7),
				Speed = r(30, 50),
				SpreadAngle = SPHERE,
				Acceleration = Vector3.new(0, -60, 0),
				Drag = 2,
			},
			{
				t = 0.15,
				tex = "boom_ink_floor",
				n = 1,
				at = "floor",
				Size = NumberSequence.new(9),
				Lifetime = r(6),
				Transparency = keys({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
			},
		},
	},
	Boom_Peony = {
		ring = hex("#B04CFF"),
		light = hex("#E83CFF"),
		lightRange = 30,
		origin = 0.08,
		flashAt = 0.08,
		debris = "all",
		scorch = { t = 0.15 },
		layers = {
			with(FLASH, { t = 0.08, Size = ramp(9, 0), Lifetime = r(0.06), Color = cs("#FFD84A") }),
			{
				t = 0.08,
				tex = "boom_peony_burst",
				grid = "4x4",
				flip = "OneShot",
				n = 1,
				lite = 1,
				Size = env(11, 12),
				Lifetime = r(0.9),
				Speed = r(0),
				LightEmission = 1,
				Brightness = 1.5,
				ZOffset = 1,
			},
			{
				t = 0.10,
				tex = "boom_peony_star",
				n = 26,
				lite = 8,
				Orientation = PARALLEL,
				Size = ramp(0.9, 0.4),
				Lifetime = r(0.6, 0.9),
				Speed = r(34, 50),
				SpreadAngle = SPHERE,
				Drag = 4,
				Acceleration = Vector3.new(0, -12, 0),
				LightEmission = 1,
			},
			{
				t = 0.30,
				tex = "Vfx.Ember",
				n = 14,
				Size = NumberSequence.new(0.35),
				Lifetime = r(1.2),
				Speed = r(2, 4),
				SpreadAngle = SPHERE,
				Acceleration = Vector3.new(0, -4, 0),
				Color = cs("#FFD84A", "#E83CFF"),
				Transparency = keys({ { 0, 0 }, { 0.3, 0.6 }, { 0.5, 0 }, { 0.8, 0.7 }, { 1, 1 } }),
				LightEmission = 1,
			},
			with(SMOKE, { t = 0.15, n = 3, Size = ramp(6, 8), Lifetime = r(1.0), Color = cs("#3B3447") }),
		},
	},
	Boom_Pixel = {
		ring = hex("#FFD84A"),
		light = hex("#FFD84A"),
		origin = 0.08,
		flashAt = 0.08,
		debris = "none", -- the voxel cubes are the debris
		scorch = { t = 0.15 },
		layers = {
			{
				t = 0.08,
				tex = "boom_pixel_pop",
				grid = "4x4",
				flip = "OneShot",
				n = 1,
				lite = 1,
				Size = NumberSequence.new(9),
				Lifetime = r(0.5),
				Speed = r(0),
				Rotation = r(0), -- pixel art stays axis-aligned
				ZOffset = 1,
			},
			{
				t = 0.08,
				tex = "boom_pixel_ring", -- the air ring
				n = 1,
				Size = ramp(2, 10),
				Lifetime = r(0.25),
				Speed = r(0),
				Rotation = r(0),
				Transparency = keys({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
			},
			with(PIXEL_CUBE, { Color = cs("#FFD84A") }),
			with(PIXEL_CUBE, { Color = cs("#3BE48C") }),
			with(PIXEL_CUBE, { Color = cs("#B04CFF") }),
			with(PIXEL_CUBE, { Color = cs("#FF5CA8") }),
		},
	},
	Boom_Frost = {
		ring = hex("#BFDDFF"),
		light = hex("#BFDDFF"),
		origin = 0.08,
		flashAt = 0.08,
		debris = "all",
		scorch = nil, -- the frozen floor replaces it
		layers = {
			with(FLASH, { t = 0.08, Size = ramp(9, 0), Lifetime = r(0.06), Color = cs("#F4FBFF") }),
			{
				t = 0.08,
				tex = "boom_frost_shard",
				n = 18,
				lite = 8,
				at = "base",
				Orientation = PARALLEL,
				Size = ramp(1.4, 1.0),
				Lifetime = r(0.45, 0.6),
				Speed = r(36, 56),
				EmissionDirection = UP,
				SpreadAngle = cone(80),
				Drag = 5,
				Acceleration = Vector3.new(0, -20, 0),
			},
			{
				t = 0.10,
				tex = "boom_frost_flake",
				n = 16,
				lite = 4,
				Size = env(0.5, 0.8),
				Lifetime = r(1.2, 1.6),
				Speed = r(6, 12),
				SpreadAngle = SPHERE,
				Acceleration = Vector3.new(0, -3, 0),
				Drag = 1,
				Rotation = r(0, 360),
				RotSpeed = r(-90, 90),
				LightEmission = 0.3,
			},
			{
				t = 0.15,
				tex = "boom_frost_ring",
				n = 1,
				lite = 1,
				at = "floor",
				Size = keys({ { 0, 12 }, { 0.1, 14 }, { 1, 14 } }),
				Lifetime = r(2.5),
				Transparency = keys({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
			},
			with(SMOKE, { t = 0.15, n = 4, Size = ramp(5, 7), Lifetime = r(1.0), Color = cs("#DDEBFF") }),
		},
	},
	Boom_BlackHole = {
		ring = hex("#A65BFF"),
		light = hex("#B04CFF"),
		origin = 0, -- the one timing exception: a 0.15 s implosion, then the pop
		flashAt = 0.15,
		debris = "all",
		scorch = { t = 0.20, color = hex("#241D2E") },
		layers = {
			{
				t = 0,
				tex = "boom_blackhole_swirl",
				grid = "4x4",
				flip = "OneShot",
				n = 1,
				lite = 1,
				Size = ramp(9, 3),
				Lifetime = r(0.2),
				Speed = r(0),
				RotSpeed = r(-360),
				ZOffset = 1, -- LightEmission 0: the dark core must stay dark
			},
			{
				t = 0,
				tex = "Vfx.Streak",
				n = 20,
				shell = 6, -- emitted on a 6-stud sphere's surface, flying inward
				Orientation = PARALLEL,
				Size = NumberSequence.new(0.5),
				Lifetime = r(0.15),
				Speed = r(40),
				Color = cs("#CDB8FF"),
				LightEmission = 1,
			},
			with(FLASH, { t = 0.15, lite = 1, Size = ramp(10, 0), Lifetime = r(0.08), Color = cs("#E83CFF") }),
			{
				t = 0.15,
				tex = "boom_blackhole_ring",
				n = 1,
				lite = 1,
				Size = ramp(3, 12),
				Lifetime = r(0.45),
				Speed = r(0),
				Transparency = keys({ { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }),
			},
			{
				t = 0.17,
				tex = "Vfx.Streak",
				n = 16,
				Orientation = PARALLEL,
				Size = ramp(0.6, 0.2),
				Lifetime = r(0.35),
				Speed = r(40, 60),
				SpreadAngle = SPHERE,
				Color = cs("#E83CFF", "#B04CFF"),
				LightEmission = 1,
			},
		},
	},
	Boom_Champagne = {
		ring = hex("#F2B13A"),
		light = hex("#FFE9A6"),
		origin = 0.08,
		flashAt = 0.08,
		debris = "all",
		scorch = nil, -- a celebration, not a scorch
		layers = {
			{
				t = 0.08,
				tex = "boom_champagne_cork",
				n = 1,
				lite = 1,
				Size = ramp(7, 10),
				Lifetime = r(0.16),
				Speed = r(0),
				LightEmission = 1,
				Transparency = keys({ { 0, 0 }, { 0.5, 0 }, { 1, 1 } }),
			},
			{
				t = 0.10,
				tex = "boom_champagne_foil",
				grid = "4x4",
				flip = "Pick",
				n = 60,
				lite = 18,
				at = "base",
				Size = env(0.6, 0.9),
				Lifetime = r(1.6, 2.2),
				Speed = r(28, 44),
				EmissionDirection = UP,
				SpreadAngle = cone(65),
				Acceleration = Vector3.new(0, -26, 0),
				Drag = 3,
				Rotation = r(0, 360),
				RotSpeed = r(-400, 400),
			},
			{
				t = 0.12,
				tex = "boom_champagne_bubble",
				n = 30,
				lite = 8,
				at = "base",
				Size = env(0.3, 0.6),
				Lifetime = r(1.2, 1.8),
				Speed = r(4, 9),
				EmissionDirection = UP,
				SpreadAngle = cone(35),
				Acceleration = Vector3.new(0, 6, 0),
				Drag = 1.5,
				LightEmission = 0.6,
				Transparency = keys({ { 0, 0.1 }, { 0.8, 0.2 }, { 1, 1 } }),
			},
			with(EMBER, { t = 0.30, n = 10, Size = NumberSequence.new(0.3), Lifetime = r(1.4), Color = cs("#F2B13A") }),
		},
	},
} :: { [string]: Boom }

-- ── The executor ────────────────────────────────────────────────────────────────────────────────────────────────
local function texture(key: string): string
	if string.sub(key, 1, 4) == "Vfx." then
		return Assets.Vfx[string.sub(key, 5)] or ""
	end
	local id = Assets.VfxCosmetic[key]
	if not id then
		warn("[VfxCosmetic] no texture " .. key)
	end
	return id or ""
end

-- Builds a layer's emitter (disabled: it's fired with :Emit, or switched on by the caller).
local function emitter(layer: Layer, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	e.LightEmission = 0
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	if layer.tex then
		e.Texture = texture(layer.tex)
	end
	if layer.grid then
		e.FlipbookLayout = if layer.grid == "2x2"
			then Enum.ParticleFlipbookLayout.Grid2x2
			else Enum.ParticleFlipbookLayout.Grid4x4
		if layer.flip == "Pick" then
			e.FlipbookMode = PICK.mode
			e.FlipbookStartRandom = true
			e.FlipbookFramerate = NumberRange.new(PICK.rate)
		elseif layer.flip == "Loop" then
			e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		else
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	end
	if layer.at == "floor" then -- flat on the floor, facing up
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		e.EmissionDirection = UP
		e.Speed = NumberRange.new(0.01)
		e.Acceleration = Vector3.zero
		e.Rotation = NumberRange.new(0, 360)
	end
	for k, v in pairs(layer) do
		if string.match(k, "^%u") then
			(e :: any)[k] = v
		end
	end
	e.Parent = parent
	return e
end
VfxCosmetic.emitter = emitter

local function lifeOf(layer: Layer): number
	local life = layer.Lifetime
	return if typeof(life) == "NumberRange" then life.Max else 1
end

-- An attachment at `cf` that cleans itself up after `life` seconds.
local function holderAt(cf: CFrame, life: number): Attachment
	local att = Instance.new("Attachment")
	att.WorldCFrame = cf
	att.Parent = workspace.Terrain
	Debris:AddItem(att, life)
	return att
end

-- Fire one layer: n particles from `cf`.
local function fireAt(layer: Layer, cf: CFrame, n: number)
	local life = lifeOf(layer) + CLEAN_PAD
	if layer.shell then -- a sphere shell (the emitter's shape needs a part to take its size from)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * layer.shell * 2
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.CFrame = cf
		part.Parent = workspace
		Debris:AddItem(part, life)
		local e = emitter(layer, part)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		e:Emit(n)
		return
	end
	emitter(layer, holderAt(cf, life)):Emit(n)
end
VfxCosmetic.fireAt = fireAt

local function countOf(layer: Layer, lite: boolean): number
	return if lite then (layer.lite or 0) else layer.n or 0
end

-- Play a stack of layers at `pos` (the blast's foot, where the Classic ring and sparks start). Each layer fires at
-- its stack time `t`, counted from `origin` (the moment this is called). `lite` plays the light variant. The total
-- is held to MAX_PARTICLES. `floorY` places the flat floor sprites (they're skipped without one).
function VfxCosmetic.burst(layers: { Layer }, pos: Vector3, origin: number, lite: boolean, floorY: number?)
	local total = 0
	for _, layer in ipairs(layers) do
		total += countOf(layer, lite)
	end
	local k = if total > MAX_PARTICLES then MAX_PARTICLES / total else 1
	for _, layer in ipairs(layers) do
		local count = countOf(layer, lite)
		local n = if count > 0 then math.max(1, math.floor(count * k)) else 0
		local at: Vector3? = if layer.at == "base"
			then pos
			elseif layer.at == "floor" then (if floorY then Vector3.new(pos.X, floorY + FLOOR_LIFT, pos.Z) else nil)
			else pos + Vector3.new(0, CORE_UP, 0)
		if n > 0 and at then
			local cf = CFrame.new(at)
			local delay = math.max(0, (layer.t or 0) - origin)
			if delay <= 0 then
				fireAt(layer, cf, n)
			else
				task.delay(delay, fireAt, layer, cf, n)
			end
		end
	end
end

function VfxCosmetic.explosion(id: any): Boom?
	return if type(id) == "string" then VfxCosmetic.Explosions[id] else nil
end

-- ── §2 Fuse sparks ──────────────────────────────────────────────────────────────────────────────────────────────
-- core: the sprite at the fuse tip (Rate 30, Lifetime 0.08, Speed 0, locked to the bomb, unless it says otherwise).
-- shed: what it throws off (`rate` is its LIT rate; CRITICAL ×3 plus a sputter). `classic` keeps the Classic shed
-- and only applies what's listed. light: the PointLight (range 4).
export type SparkRecipe = {
	core: Layer,
	shed: Layer,
	light: Color3,
	brightness: number?,
	flicker: boolean?, -- Electric: brightness 1 ↔ 2.5 every 0.05 s
	motes: Layer?, -- Plasma: three orbiting motes
}

local SPARK_RANGE = 4
local SPARK_CRIT_MULT = 3
local SPARK_SPUTTER = 6 -- particles…
local SPARK_SPUTTER_EVERY = 0.2 -- …every this many seconds at CRITICAL
local FLICKER_EVERY = 0.05
local FLICKER_LO, FLICKER_HI = 1, 2.5
local MOTE_COUNT, MOTE_RADIUS, MOTE_REV, MOTE_BOB = 3, 0.6, 2, 0.15

local CORE_BASE: Layer = {
	Rate = 30,
	Lifetime = r(0.08),
	Speed = r(0),
	LockedToPart = true,
	Size = env(0.3, 0.45),
	Transparency = NumberSequence.new(0),
	Color = ColorSequence.new(Color3.new(1, 1, 1)),
	Rotation = r(0, 360),
	RotSpeed = r(0),
}
local SHED_BASE: Layer = {
	Orientation = Enum.ParticleOrientation.FacingCamera,
	Color = ColorSequence.new(Color3.new(1, 1, 1)),
	Transparency = NumberSequence.new(0),
	Acceleration = Vector3.zero,
	Drag = 0,
	Rotation = r(0),
	RotSpeed = r(0),
	LockedToPart = false,
}

VfxCosmetic.Sparks = {
	Spark_Sparkler = {
		core = { tex = "spark_sparkler_star", Size = env(0.45, 0.6), RotSpeed = r(-720, 720), LightEmission = 1 },
		shed = {
			tex = "spark_sparkler_needle",
			rate = 18,
			Orientation = PARALLEL,
			Lifetime = r(0.25, 0.4),
			Speed = r(8, 14),
			SpreadAngle = SPHERE,
			Acceleration = Vector3.new(0, -25, 0),
			Size = ramp(0.35, 0.1),
			LightEmission = 1,
		},
		light = hex("#FFD84A"),
	},
	Spark_EmberDrift = {
		core = { tex = "spark_ember_dot", Size = env(0.35, 0.45), LightEmission = 1 },
		shed = {
			tex = "spark_ember_dot",
			rate = 4,
			Lifetime = r(1.4, 2.0),
			Speed = r(0.5, 1.5),
			Acceleration = Vector3.new(0, 1.5, 0),
			Size = ramp(0.22, 0.05),
			Transparency = keys({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } }),
			LightEmission = 1,
		},
		light = hex("#FF9442"),
		brightness = 0.6,
	},
	Spark_Electric = {
		core = {
			tex = "spark_electric_arc",
			grid = "2x2",
			flip = "Loop",
			FlipbookFramerate = r(24),
			FlipbookStartRandom = true,
			Size = env(0.55, 0.7),
			Rotation = r(0, 360),
			LightEmission = 1,
		},
		shed = {
			tex = "spark_electric_arc",
			grid = "2x2",
			flip = "Loop",
			FlipbookFramerate = r(24),
			FlipbookStartRandom = true,
			rate = 5,
			Lifetime = r(0.08),
			Size = env(0.8, 1.0),
			Speed = r(0),
			Rotation = r(0, 360),
			LightEmission = 1,
		},
		light = hex("#8FB4FF"),
		flicker = true,
	},
	Spark_Pixie = {
		core = {
			tex = "spark_pixie_glitter",
			grid = "2x2",
			flip = "Pick",
			Size = env(0.4, 0.55),
			RotSpeed = r(-90, 90),
			LightEmission = 1,
		},
		shed = {
			tex = "spark_pixie_glitter",
			grid = "2x2",
			flip = "Pick",
			rate = 10,
			Lifetime = r(0.6, 0.9),
			Speed = r(0.5, 1),
			Acceleration = Vector3.new(0, -1.5, 0),
			Size = ramp(0.3, 0),
			LockedToPart = false, -- it trails behind as the Carrier runs
			LightEmission = 1,
		},
		light = hex("#FFB3DA"),
	},
	Spark_Plasma = {
		core = { tex = "spark_plasma_ball", Size = env(0.45, 0.55), RotSpeed = r(180), LightEmission = 1 },
		shed = {
			tex = "spark_plasma_mote",
			rate = 6,
			Lifetime = r(0.4),
			Speed = r(2, 4),
			SpreadAngle = SPHERE,
			Size = ramp(0.15, 0),
			LightEmission = 1,
		},
		motes = {
			tex = "spark_plasma_mote",
			Rate = 30,
			Lifetime = r(0.1),
			Speed = r(0),
			Size = NumberSequence.new(0.18),
			LightEmission = 1,
		},
		light = hex("#E83CFF"),
	},
	Spark_GoldLeaf = {
		core = { tex = "Vfx.Flash", Color = cs("#FFE9A6"), Size = env(0.35, 0.45), LightEmission = 1 },
		shed = {
			tex = "spark_goldleaf_flake",
			grid = "2x2",
			flip = "Loop", -- the 4 frames are a flutter cycle
			FlipbookFramerate = r(6, 10),
			FlipbookStartRandom = true,
			rate = 5,
			Lifetime = r(1.6, 2.2),
			Speed = r(1, 2),
			Acceleration = Vector3.new(0, -2.5, 0),
			Drag = 1.2,
			Size = env(0.3, 0.4),
			RotSpeed = r(-60, 60),
		},
		light = hex("#F2B13A"),
	},
	Spark_Insignia = {
		core = { tex = "spark_insignia_star", Size = env(0.45, 0.55), RotSpeed = r(90), LightEmission = 0 },
		shed = { classic = true, rate = 8, Color = cs("#FFD84A", "#FF6A1F") },
		light = hex("#FF6A1F"),
	},
} :: { [string]: SparkRecipe }

export type SparkRig = {
	recipe: SparkRecipe,
	shed: ParticleEmitter,
	light: PointLight,
	rate: number, -- the shed's LIT rate
	range: number,
	color: Color3,
	sputterAt: number,
	flickerAt: number,
	flickerHi: boolean,
	motes: { Attachment },
	anchor: Attachment,
	t: number,
}

local function apply(e: ParticleEmitter, base: Layer?, layer: Layer)
	local merged = if base then with(base, layer) else layer
	if merged.tex then
		e.Texture = texture(merged.tex)
	end
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	if merged.grid then
		e.FlipbookLayout = if merged.grid == "2x2"
			then Enum.ParticleFlipbookLayout.Grid2x2
			else Enum.ParticleFlipbookLayout.Grid4x4
		if merged.flip == "Pick" then
			e.FlipbookMode = PICK.mode
			e.FlipbookStartRandom = true
			e.FlipbookFramerate = NumberRange.new(PICK.rate)
		elseif merged.flip == "Loop" then
			e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		else
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	end
	for k, v in pairs(merged) do
		if string.match(k, "^%u") then
			(e :: any)[k] = v
		end
	end
end

-- Re-dress a carried bomb's fuse spark (BombController's shed + core emitters and its PointLight) in the Carrier's
-- equipped spark. Returns nil for Classic (or anything without a recipe), which stays as it is.
function VfxCosmetic.spark(
	id: any,
	anchor: Attachment,
	mount: BasePart,
	shed: ParticleEmitter,
	core: ParticleEmitter,
	light: PointLight
): SparkRig?
	local recipe = if type(id) == "string" then VfxCosmetic.Sparks[id] else nil
	if not recipe then
		return nil
	end
	apply(core, CORE_BASE, recipe.core)
	local s = recipe.shed
	if s.classic then
		apply(shed, nil, s)
	else
		apply(shed, SHED_BASE, s)
	end
	light.Color = recipe.light
	light.Range = SPARK_RANGE
	light.Brightness = recipe.brightness or light.Brightness
	local motes = {}
	if recipe.motes then
		for _ = 1, MOTE_COUNT do
			local a = Instance.new("Attachment")
			a.Name = "SparkMote"
			a.Parent = mount
			local e = emitter(recipe.motes, a)
			e.LockedToPart = true
			e.Enabled = true
			table.insert(motes, a)
		end
	end
	return {
		recipe = recipe,
		shed = shed,
		light = light,
		rate = s.rate or shed.Rate,
		range = SPARK_RANGE,
		color = recipe.light,
		sputterAt = 0,
		flickerAt = 0,
		flickerHi = false,
		motes = motes,
		anchor = anchor,
		t = 0,
	}
end

-- Per frame, for a cosmetic spark: the shed rate (×3 and a sputter at CRITICAL), the light flicker, the motes.
function VfxCosmetic.sparkStep(rig: SparkRig, dt: number, critical: boolean)
	rig.t += dt
	rig.shed.Rate = if critical then rig.rate * SPARK_CRIT_MULT else rig.rate
	if critical and rig.t >= rig.sputterAt then
		rig.sputterAt = rig.t + SPARK_SPUTTER_EVERY
		rig.shed:Emit(SPARK_SPUTTER)
	end
	if rig.recipe.flicker and rig.t >= rig.flickerAt then
		rig.flickerAt = rig.t + FLICKER_EVERY
		rig.flickerHi = not rig.flickerHi
		rig.light.Brightness = if rig.flickerHi then FLICKER_HI else FLICKER_LO
	end
	local tip = rig.anchor.WorldPosition
	for i, a in ipairs(rig.motes) do
		local ang = (rig.t * MOTE_REV + (i - 1) / #rig.motes) * math.pi * 2
		local bob = math.sin(ang * 1.5 + i) * MOTE_BOB
		a.WorldPosition = tip + Vector3.new(math.cos(ang) * MOTE_RADIUS, bob, math.sin(ang) * MOTE_RADIUS)
	end
end

-- ── §3 Trails ───────────────────────────────────────────────────────────────────────────────────────────────────
export type TrailRecipe = {
	tex: string,
	light: number,
	width: NumberSequence?,
	alpha: NumberSequence?,
	flicker: boolean?, -- Neon: the tube flickers while the trail runs
}

local TRAIL_A0 = Vector3.new(0, -0.8, 0.4) -- on the HumanoidRootPart, 1.6 studs apart, vertical
local TRAIL_A1 = Vector3.new(0, 0.8, 0.4)
local TRAIL_LIFETIME = 0.25
local TRAIL_MIN_LENGTH = 0.05
local TRAIL_WIDTH = ramp(1, 0.6)
local TRAIL_ALPHA = ramp(0, 0.35)
local NEON_DIM = ramp(0.6, 0.8)
local NEON_EVERY_MIN, NEON_EVERY_MAX, NEON_DIM_ODDS = 0.06, 0.18, 6

VfxCosmetic.Trails = {
	Trail_Soot = { tex = "trail_soot", light = 0, width = ramp(0.9, 1.3) },
	Trail_Streamers = { tex = "trail_streamers", light = 0 },
	Trail_SparkLine = { tex = "trail_sparkline", light = 1, width = ramp(0.7, 0.5) },
	Trail_Rocket = { tex = "trail_rocket", light = 0.6, width = ramp(1, 0.8) },
	Trail_Comet = { tex = "trail_comet", light = 1, width = ramp(1.1, 0.5) },
	Trail_Neon = { tex = "trail_neon", light = 1, flicker = true },
	Trail_Aurora = { tex = "trail_aurora", light = 1, alpha = ramp(0.05, 0.45), width = ramp(1.2, 1.4) },
	Trail_VictoryLap = { tex = "trail_victorylap", light = 0 },
} :: { [string]: TrailRecipe }

type LiveTrail = { id: string, trail: Trail, a0: Attachment, a1: Attachment, untilT: number }
local live: { [Model]: LiveTrail } = {}

local function dropTrail(model: Model, lt: LiveTrail)
	if live[model] == lt then
		live[model] = nil
	end
	lt.trail.Enabled = false
	Debris:AddItem(lt.trail, TRAIL_LIFETIME + CLEAN_PAD)
	Debris:AddItem(lt.a0, TRAIL_LIFETIME + CLEAN_PAD)
	Debris:AddItem(lt.a1, TRAIL_LIFETIME + CLEAN_PAD)
end

-- Show `model`'s equipped trail (`id`) for `duration` seconds (a repeat extends the one already running).
function VfxCosmetic.trail(model: Model?, id: any, duration: number)
	local recipe = if type(id) == "string" then VfxCosmetic.Trails[id] else nil
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not recipe or not model or not root then
		return
	end
	local cur = live[model]
	if cur and cur.id == id and cur.trail.Parent then
		cur.untilT = math.max(cur.untilT, os.clock() + duration)
		return
	elseif cur then
		dropTrail(model, cur)
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "FV_TrailA0"
	a0.Position = TRAIL_A0
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "FV_TrailA1"
	a1.Position = TRAIL_A1
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "FV_Trail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Texture = texture(recipe.tex)
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Lifetime = TRAIL_LIFETIME
	trail.MinLength = TRAIL_MIN_LENGTH
	trail.FaceCamera = true
	trail.LightInfluence = 0
	trail.LightEmission = recipe.light
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = recipe.alpha or TRAIL_ALPHA
	trail.WidthScale = recipe.width or TRAIL_WIDTH
	trail.Parent = root
	local lt: LiveTrail = { id = id, trail = trail, a0 = a0, a1 = a1, untilT = os.clock() + duration }
	live[model] = lt
	local nextFlick = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		if live[model] ~= lt or not trail.Parent or clock >= lt.untilT then
			conn:Disconnect()
			dropTrail(model, lt)
			return
		end
		if recipe.flicker and clock >= nextFlick then
			nextFlick = clock + NEON_EVERY_MIN + math.random() * (NEON_EVERY_MAX - NEON_EVERY_MIN)
			trail.Transparency = if math.random(NEON_DIM_ODDS) == 1 then NEON_DIM else TRAIL_ALPHA
		end
	end)
end

-- End `model`'s trail now (its ribbon still fades over its lifetime).
function VfxCosmetic.stopTrail(model: Model?)
	local cur = model and live[model]
	if model and cur then
		cur.untilT = 0
	end
end

-- ── §4 Victory booms ────────────────────────────────────────────────────────────────────────────────────────────
local function pointLight(at: CFrame, color: Color3, range: number, brightness: number, life: number): PointLight
	local att = holderAt(at, life + CLEAN_PAD)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = att
	return light
end

local function flashLight(at: CFrame, color: Color3, range: number, brightness: number, time: number)
	local light = pointLight(at, color, range, brightness, time)
	TweenService:Create(light, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()
end

-- Rate-driven emitters on one holder, switched on for `time` seconds.
local function runFor(cf: CFrame, layers: { Layer }, time: number): Attachment
	local maxLife = 0
	for _, l in ipairs(layers) do
		maxLife = math.max(maxLife, lifeOf(l))
	end
	local att = holderAt(cf, time + maxLife + CLEAN_PAD)
	local list = {}
	for _, l in ipairs(layers) do
		local e = emitter(l, att)
		e.Enabled = true
		table.insert(list, e)
	end
	task.delay(time, function()
		for _, e in ipairs(list) do
			e.Enabled = false
		end
	end)
	return att
end

local function feet(root: CFrame): Vector3
	return root.Position - Vector3.new(0, 3, 0)
end

-- Victory_Confetti: two cannons 6 studs either side, aimed 35° inward and 60° up, three volleys each.
local CONFETTI_V = {
	side = 6,
	up = 1,
	inward = 35,
	elevation = 60,
	volleys = { 0, 0.6, 1.2 },
	pieces = {
		tex = "victory_confetti_pieces",
		grid = "4x4",
		flip = "Pick",
		n = 40,
		EmissionDirection = Enum.NormalId.Front,
		Size = env(0.8, 1.2),
		Lifetime = r(2.6, 3.4),
		Speed = r(40, 55),
		SpreadAngle = cone(18),
		Acceleration = Vector3.new(0, -20, 0),
		Drag = 2.2,
		Rotation = r(0, 360),
		RotSpeed = r(-360, 360),
	},
	muzzle = {
		tex = "boom_confetti_streamers",
		grid = "2x2",
		flip = "Pick",
		n = 4,
		EmissionDirection = Enum.NormalId.Front,
		Size = NumberSequence.new(2.5),
		Lifetime = r(2),
		Speed = r(40, 55),
		SpreadAngle = cone(18),
		Acceleration = Vector3.new(0, -20, 0),
		Drag = 2.2,
		RotSpeed = r(-120, 120),
	},
}

local function confettiRain(root: CFrame)
	local c = CONFETTI_V
	local flat = CFrame.lookAlong(root.Position, root.LookVector * Vector3.new(1, 0, 1))
	for _, sideSign in ipairs({ -1, 1 }) do
		local at = (flat * CFrame.new(sideSign * c.side, c.up, 0)).Position
		-- forward, turned inward, then raised
		local aim = flat
			* CFrame.Angles(0, math.rad(c.inward) * sideSign, 0)
			* CFrame.Angles(math.rad(c.elevation), 0, 0)
		local cf = CFrame.lookAlong(at, aim.LookVector)
		for _, t in ipairs(c.volleys) do
			task.delay(t, function()
				fireAt(c.pieces, cf, c.pieces.n)
				fireAt(c.muzzle, cf, c.muzzle.n)
			end)
		end
	end
end

-- Victory_Fountain: four ground fountains at the corners of a 6-stud square, 4 s.
local FOUNTAIN_V = {
	half = 3,
	time = 4,
	light = { color = hex("#F2B13A"), range = 10, brightness = 2 },
	spray = {
		tex = "victory_fountain_spark",
		Rate = 45,
		Orientation = PARALLEL,
		EmissionDirection = UP,
		Lifetime = r(0.9, 1.2),
		Speed = r(26, 34),
		SpreadAngle = cone(12),
		Acceleration = Vector3.new(0, -38, 0),
		Size = ramp(0.9, 0.5),
		LightEmission = 1,
	},
	glints = {
		tex = "victory_fountain_glint",
		Rate = 10,
		EmissionDirection = UP,
		Lifetime = r(0.4),
		Speed = r(20, 30),
		SpreadAngle = cone(12),
		Acceleration = Vector3.new(0, -38, 0),
		Size = env(0.6, 0.9),
		Rotation = r(0, 360),
		RotSpeed = r(180),
		LightEmission = 1,
	},
}

local function goldenFountain(root: CFrame)
	local f = FOUNTAIN_V
	local base = feet(root)
	for _, o in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		local cf = CFrame.new(base + Vector3.new(o[1] * f.half, 0, o[2] * f.half))
		local att = runFor(cf, { f.spray, f.glints }, f.time)
		local light = Instance.new("PointLight")
		light.Color = f.light.color
		light.Range = f.light.range
		light.Brightness = f.light.brightness
		light.Parent = att
		task.delay(f.time, function()
			light.Enabled = false
		end)
	end
end

-- Victory_Finale: nine shells from behind the winner, then the finale triple.
local FINALE_V = {
	shells = { 0, 0.4, 0.8, 1.3, 1.7, 2.2, 2.8, 3.3, 3.6 },
	triple = 4.1,
	behind = { 4, 10 },
	across = 5,
	height = { 18, 26 },
	rise = {
		tex = "Vfx.Streak",
		n = 1,
		Orientation = PARALLEL,
		EmissionDirection = UP,
		Speed = r(45),
		Lifetime = r(0.45),
		Size = ramp(0.9, 0.3),
		Color = cs("#FFE9A6"),
		LightEmission = 1,
	},
	burst = {
		tex = "victory_finale_peony",
		grid = "4x4",
		flip = "OneShot",
		n = 1,
		Size = env(16, 20),
		Lifetime = r(1.1),
		Speed = r(0),
		Rotation = r(0, 360),
		LightEmission = 1,
		Brightness = 1.6,
	},
	stars = {
		tex = "boom_peony_star",
		n = 16,
		Orientation = PARALLEL,
		Size = ramp(0.9, 0.4),
		Lifetime = r(0.8),
		Speed = r(30, 40),
		SpreadAngle = SPHERE,
		Drag = 4,
		Acceleration = Vector3.new(0, -12, 0),
		LightEmission = 1,
	},
	light = { color = hex("#FFE9A6"), range = 40, brightness = 4, time = 0.2 },
}

local function shell(root: CFrame, withStars: boolean)
	local f = FINALE_V
	local flat = CFrame.lookAlong(root.Position, root.LookVector * Vector3.new(1, 0, 1))
	local back = f.behind[1] + math.random() * (f.behind[2] - f.behind[1])
	local across = (math.random() * 2 - 1) * f.across
	local launch = (flat * CFrame.new(across, -3, back)).Position -- +Z is behind
	local top = launch + Vector3.new(0, f.height[1] + math.random() * (f.height[2] - f.height[1]), 0)
	fireAt(f.rise, CFrame.new(launch), f.rise.n)
	task.delay(lifeOf(f.rise), function()
		local cf = CFrame.new(top)
		fireAt(f.burst, cf, f.burst.n)
		if withStars then
			fireAt(f.stars, cf, f.stars.n)
		end
		flashLight(cf, f.light.color, f.light.range, f.light.brightness, f.light.time)
	end)
end

local function grandFinale(root: CFrame)
	local f = FINALE_V
	for i, t in ipairs(f.shells) do
		task.delay(t, shell, root, i % 2 == 1)
	end
	for i = 1, 3 do
		task.delay(f.triple, shell, root, i ~= 2)
	end
end

-- Victory_Dragon: a billboard head and nine segments circling the winner, then up and pop.
local DRAGON_V = {
	segments = 9,
	headSize = 3.6,
	segFirst = 2.4,
	segLast = 1.4,
	radius = 5,
	height = 3,
	bob = 0.8,
	bobHz = 1.2,
	rev = 0.45,
	delay = 0.11,
	fly = 4.5,
	climb = 12,
	climbTime = 0.4,
	popSize = 14,
	glints = {
		tex = "victory_fountain_glint",
		Rate = 5,
		Lifetime = r(0.5),
		Speed = r(1, 2),
		SpreadAngle = SPHERE,
		Size = env(0.4, 0.6),
		LightEmission = 1,
	},
	embers = {
		tex = "spark_ember_dot",
		Rate = 8,
		Lifetime = r(0.8),
		Speed = r(0.5, 1.5),
		SpreadAngle = SPHERE,
		Acceleration = Vector3.new(0, -4, 0),
		Size = ramp(0.2, 0),
		LightEmission = 1,
	},
}

local function dragonDance(root: CFrame)
	local d = DRAGON_V
	local centre = root.Position
	local function path(t: number): Vector3
		local tt = math.min(t, d.fly)
		local a = tt * d.rev * math.pi * 2
		local p = centre
			+ Vector3.new(
				math.cos(a) * d.radius,
				d.height + d.bob * math.sin(2 * math.pi * tt * d.bobHz),
				math.sin(a) * d.radius
			)
		if t > d.fly then
			local k = math.clamp((t - d.fly) / d.climbTime, 0, 1)
			p += Vector3.new(0, d.climb * (1 - (1 - k) ^ 2), 0)
		end
		return p
	end
	local parts: { Attachment } = {}
	for k = 0, d.segments do
		local att = Instance.new("Attachment")
		att.Name = if k == 0 then "FV_DragonHead" else "FV_DragonSeg" .. k
		att.WorldPosition = path(0)
		local size = if k == 0
			then d.headSize
			else d.segFirst + (d.segLast - d.segFirst) * (k - 1) / math.max(1, d.segments - 1)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(size, size)
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.Adornee = att
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = texture(if k == 0 then "victory_dragon_head" else "victory_dragon_segment")
		img.Parent = gui
		gui.Parent = att
		if k > 0 then
			emitter(d.glints, att).Enabled = true
			emitter(d.embers, att).Enabled = true
		end
		att.Parent = workspace.Terrain
		table.insert(parts, att)
	end
	local t0 = os.clock()
	local finish = d.fly + d.climbTime
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		for k, att in ipairs(parts) do
			att.WorldPosition = path(math.max(0, t - (k - 1) * d.delay))
		end
		if t >= finish then
			conn:Disconnect()
			local pop = CFrame.new(path(finish))
			fireAt(with(FINALE_V.burst, { Size = NumberSequence.new(d.popSize) }), pop, 1)
			flashLight(pop, FINALE_V.light.color, FINALE_V.light.range, FINALE_V.light.brightness, FINALE_V.light.time)
			for _, att in ipairs(parts) do
				att:Destroy()
			end
		end
	end)
end

-- Victory_ChampagneTower: a bubble column round the winner and three foil bursts from above.
local TOWER_V = {
	radius = 3,
	time = 4,
	bursts = { 0, 1.5, 3 },
	above = 7,
	light = { color = hex("#FFE9A6"), range = 14, brightness = 2 },
	bubbles = {
		tex = "victory_champagne_bubble",
		Rate = 40,
		EmissionDirection = UP,
		Lifetime = r(2, 2.8),
		Speed = r(5, 8),
		Acceleration = Vector3.new(0, 3, 0),
		Size = env(0.5, 1.1),
		Transparency = keys({ { 0, 0.2 }, { 0.85, 0.1 }, { 1, 1 } }),
		LightEmission = 0.5,
	},
	foil = {
		tex = "boom_champagne_foil",
		grid = "4x4",
		flip = "Pick",
		n = 45,
		Size = env(0.7, 1.0),
		Lifetime = r(2.5),
		Speed = r(18, 28),
		SpreadAngle = SPHERE,
		Acceleration = Vector3.new(0, -14, 0),
		Drag = 2.5,
		Rotation = r(0, 360),
		RotSpeed = r(-400, 400),
	},
	pop = {
		tex = "boom_champagne_cork",
		n = 1,
		Size = NumberSequence.new(6),
		Lifetime = r(0.16),
		Speed = r(0),
		LightEmission = 1,
		Transparency = keys({ { 0, 0 }, { 0.5, 0 }, { 1, 1 } }),
	},
}

local function champagneTower(root: CFrame)
	local c = TOWER_V
	local base = feet(root)
	-- the column: a disc's rim (radius 3) at the feet, bubbling straight up
	local disc = Instance.new("Part")
	disc.Name = "FV_BubbleColumn"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Transparency = 1
	disc.Size = Vector3.new(c.radius * 2, 0.2, c.radius * 2)
	disc.CFrame = CFrame.new(base)
	disc.Parent = workspace
	Debris:AddItem(disc, c.time + lifeOf(c.bubbles) + CLEAN_PAD)
	local e = emitter(c.bubbles, disc)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.Enabled = true
	task.delay(c.time, function()
		e.Enabled = false
	end)
	local top = CFrame.new(root.Position + Vector3.new(0, c.above, 0))
	local light = pointLight(top, c.light.color, c.light.range, c.light.brightness, c.time)
	task.delay(c.time, function()
		light.Enabled = false
	end)
	for _, t in ipairs(c.bursts) do
		task.delay(t, function()
			fireAt(c.foil, top, c.foil.n)
			fireAt(c.pop, top, c.pop.n)
		end)
	end
end

VfxCosmetic.Victories = {
	Victory_Confetti = confettiRain,
	Victory_Fountain = goldenFountain,
	Victory_Finale = grandFinale,
	Victory_Dragon = dragonDance,
	Victory_ChampagneTower = champagneTower,
} :: { [string]: (root: CFrame) -> () }

-- Play the winner's equipped victory boom at their HumanoidRootPart. False for the default volley (the caller's).
function VfxCosmetic.victory(id: any, root: CFrame): boolean
	local play = if type(id) == "string" then VfxCosmetic.Victories[id] else nil
	if not play then
		return false
	end
	play(root)
	return true
end

return VfxCosmetic
