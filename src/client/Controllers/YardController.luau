--!strict
-- The Fireworks Yard comes alive with the Field Fuse (Asset Bible §4.2, §5.4): a spark races along both gutter cords
-- from the side the Runners left, charring the cord behind it, as the crossing's fuse burns; the hazard lanes pulse
-- red through the 5 s warning and flash in order, from the side the Runners left, when the yard goes off. Works on
-- any map that has `FuseCords/Cord` parts and `HazardLanes/LaneGlow` parts (the builder's contract); idle otherwise.
-- Implements: F-FUSE-03 (visual sweep), F-FEEL-01 (world reacts to the fuse).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local new = Theme.new

local YardController = {}

type CordFx = { cord: BasePart, spark: Attachment, holder: Part, burnt: Part, emitters: { ParticleEmitter } }

local gs: Configuration
local cords: { CordFx } = {}
local cordsOf: Instance? = nil
local warnUntil = 0

local function activeMap(): Instance?
	local maps = workspace:FindFirstChild("Maps")
	if not maps then
		return nil
	end
	for _, m in ipairs(maps:GetChildren()) do
		if m:FindFirstChild("FuseCords") or m:FindFirstChild("HazardLanes") then
			return m
		end
	end
	return nil
end

local function clearCords()
	for _, c in ipairs(cords) do
		c.holder:Destroy()
		c.burnt:Destroy()
	end
	cords = {}
	cordsOf = nil
end

-- Build the spark rig for every cord on the map (client-only parts, outside the map so nothing replicates).
local function rig(map: Instance)
	clearCords()
	cordsOf = map
	local folder = map:FindFirstChild("FuseCords")
	if not folder then
		return
	end
	for _, cord in ipairs(folder:GetChildren()) do
		if not cord:IsA("BasePart") then
			continue
		end
		local holder = new("Part", {
			Name = "FV_CordSpark",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.one * 0.2,
			Parent = workspace,
		}) :: Part
		local spark = new("Attachment", { Parent = holder }) :: Attachment
		local core = new("ParticleEmitter", {
			Texture = Assets.Vfx.Flash,
			Color = ColorSequence.new(Color3.new(1, 0.95, 0.8)),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.8) }),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.08, 0.14),
			Rate = 30,
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			Enabled = false,
			Parent = spark,
		}) :: ParticleEmitter
		local streaks = new("ParticleEmitter", {
			Texture = Assets.Vfx.Streak,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(P.Spark, P.Fuse),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.2, 0.45),
			Rate = 45,
			Speed = NumberRange.new(6, 14),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -26, 0),
			EmissionDirection = Enum.NormalId.Top,
			Enabled = false,
			Parent = spark,
		}) :: ParticleEmitter
		local smoke = new("ParticleEmitter", {
			Texture = Assets.Vfx.Smoke,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.fromRGB(220, 214, 210)),
			LightInfluence = 0.5,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) }),
			Transparency = NumberSequence.new(0.35, 1),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 10,
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 2, 0),
			Enabled = false,
			Parent = spark,
		}) :: ParticleEmitter
		new("PointLight", { Color = P.Ember, Range = 9, Brightness = 2.5, Enabled = false, Parent = spark })
		local burnt = new("Part", {
			Name = "FV_CordBurnt",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(42, 31, 26),
			Size = Vector3.new(0.05, cord.Size.Y + 0.04, cord.Size.Z + 0.04),
			Transparency = 1,
			Parent = workspace,
		}) :: Part
		table.insert(
			cords,
			{ cord = cord, spark = spark, holder = holder, burnt = burnt, emitters = { core, streaks, smoke } }
		)
	end
end

local function setLit(c: CordFx, on: boolean)
	for _, e in ipairs(c.emitters) do
		e.Enabled = on
	end
	local l = c.spark:FindFirstChildOfClass("PointLight")
	if l then
		l.Enabled = on
	end
	local hiss = c.holder:FindFirstChild("Hiss")
	if on and not hiss then
		local s = Sfx.loop("FuseHiss", c.holder, 0.6)
		if s then
			s.Name = "Hiss"
		end
	elseif not on and hiss then
		hiss:Destroy()
	end
end

-- How many cords the map has streamed in right now (with StreamingEnabled they can arrive after the folder).
local function cordCount(map: Instance): number
	local folder = map:FindFirstChild("FuseCords")
	local n = 0
	if folder then
		for _, c in ipairs(folder:GetChildren()) do
			if c:IsA("BasePart") then
				n += 1
			end
		end
	end
	return n
end

local function step()
	local map = activeMap()
	if map ~= cordsOf or (map and cordCount(map) ~= #cords) then
		if map then
			rig(map)
		else
			clearCords()
		end
	end
	local endsAt = gs:GetAttribute("FuseEndsAt")
	local total = gs:GetAttribute("FuseTotal")
	local from = gs:GetAttribute("StartSide")
	local frame = gs:GetAttribute("FieldCFrame")
	local burning = ClientState.phase() == Types.Phase.Crossing
		and type(endsAt) == "number"
		and type(total) == "number"
		and total > 0
		and endsAt > workspace:GetServerTimeNow()
		and typeof(frame) == "CFrame"
	local progress = if burning
		then math.clamp(1 - ((endsAt :: number) - workspace:GetServerTimeNow()) / (total :: number), 0, 1)
		else 0
	for _, c in ipairs(cords) do
		if not burning or c.cord.Parent == nil then
			setLit(c, false)
			c.burnt.Transparency = 1
			continue
		end
		-- the cord's two ends; the spark starts at the end on the side the Runners left
		local half = c.cord.CFrame.RightVector * (c.cord.Size.X / 2)
		local a, b = c.cord.Position - half, c.cord.Position + half
		local axis = (frame :: CFrame).LookVector * (if type(from) == "number" then from else -1)
		if (a - b):Dot(axis) < 0 then
			a, b = b, a -- `a` is now the start-side end
		end
		local at = a:Lerp(b, progress)
		c.holder.CFrame = CFrame.new(at + Vector3.new(0, c.cord.Size.Y * 0.4, 0))
		setLit(c, true)
		local len = (at - a).Magnitude
		if len > 0.1 then
			c.burnt.Size = Vector3.new(len, c.burnt.Size.Y, c.burnt.Size.Z)
			c.burnt.CFrame = CFrame.lookAt((a + at) / 2, at) * CFrame.Angles(0, math.rad(90), 0)
			c.burnt.Transparency = 0
		else
			c.burnt.Transparency = 1
		end
	end
	-- the warning pulse on the hazard lanes
	if map and os.clock() < warnUntil then
		local lanes = map:FindFirstChild("HazardLanes")
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 * 3)
		if lanes then
			for _, g in ipairs(lanes:GetChildren()) do
				if g:IsA("BasePart") and g:GetAttribute("Lane") then
					g.Transparency = 0.25 + 0.6 * pulse
				end
			end
		end
	end
end

local function lanesOff(map: Instance?)
	local lanes = map and map:FindFirstChild("HazardLanes")
	if not lanes then
		return
	end
	for _, g in ipairs(lanes:GetChildren()) do
		if g:IsA("BasePart") and g:GetAttribute("Lane") then
			g.Transparency = 1
		end
	end
end

-- The yard goes off: every lane flashes in order from the side the Runners left.
local function detonate(fromSide: number)
	warnUntil = 0
	local map = activeMap()
	local lanes = map and map:FindFirstChild("HazardLanes")
	local frame = gs:GetAttribute("FieldCFrame")
	if not lanes or typeof(frame) ~= "CFrame" then
		return
	end
	local list = {}
	for _, g in ipairs(lanes:GetChildren()) do
		if g:IsA("BasePart") and g:GetAttribute("Lane") then
			table.insert(list, g)
		end
	end
	local axis = frame.LookVector * fromSide
	table.sort(list, function(x, y)
		return x.Position:Dot(axis) > y.Position:Dot(axis) -- the side the Runners left first
	end)
	for i, g in ipairs(list) do
		task.delay((i - 1) * 0.08, function()
			g.Color = P.Spark
			g.Transparency = 0
			TweenService:Create(g, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = 1, Color = P.Bomber })
				:Play()
		end)
	end
end

function YardController.start()
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	RunService.RenderStepped:Connect(step)
	Net.listen("FieldFx", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.kind == "Warn" then
			warnUntil = os.clock() + 5.5
		elseif p.kind == "Detonate" then
			detonate(if type(p.side) == "number" then p.side else -1)
		elseif p.kind == "Clear" then
			warnUntil = 0
			lanesOff(activeMap())
		end
	end)
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if ClientState.phase() ~= Types.Phase.Crossing then
			warnUntil = 0
			lanesOff(activeMap())
		end
	end)
end

return YardController
