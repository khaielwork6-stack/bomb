--!strict
-- The WINNER crown (GDD §8.3, Asset Bible §5.5): anyone who won the last round wears a gold crown with a lit
-- sparkler above their head, turning slowly, for the whole next round — everyone sees it (and the Dethrone quest
-- rewards booming them). The modelled crown (ReplicatedStorage.FV_Art.Props.Crown: gold band, red velvet cap,
-- jewels, finials and a star; art/props/build_crown.py) with a lit sparkler rising from its star; it follows the head
-- every frame. (A part-built crown stands in if the model isn't in the place.)
-- The OBSIDIAN CROWN (Asset Bible §8.6, the level-50 reward): anyone wearing the Obsidian Crown title wears the same
-- crown in black volcanic glass with violet veins and amethysts (Props.CrownObsidian), violet embers drifting up
-- instead of the sparkler — all the
-- time, not just after a win (the gold winner's crown takes its place while they're Crowned).
-- Implements: F-WIN-04 (presentation), AB §8.6 (the crown cosmetic).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local new = Theme.new

local CrownController = {}

local GOLD = Color3.fromRGB(255, 196, 64)
local GOLD_DEEP = Color3.fromRGB(214, 140, 30)
local GEMS = { P.Bomber, P.Runner, P.Safe, P.Mega, P.Bomber }
local OBSIDIAN_TITLE = "Title_ObsidianCrown"
local OBSIDIAN = Color3.fromRGB(28, 22, 38)
local OBSIDIAN_EDGE = Color3.fromRGB(64, 48, 92)
local VIOLET = Color3.fromRGB(176, 76, 255)

-- the modelled crown: its pivot is the bottom centre; the band's centre (our origin) sits this far above it, and the
-- star's tip (where the sparkler stands) this far above the band's centre
local MODEL_BAND = CFrame.new(0, 0.18, 0.039)
local STAR_TOP = 1.04

type Kind = "Gold" | "Obsidian"
type Crown = { model: Model, root: BasePart, head: BasePart, kind: Kind }
local crowns: { [Instance]: Crown } = {}

local function part(
	m: Model,
	name: string,
	size: Vector3,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = new("Part", {
		Name = name,
		Size = size,
		Color = color,
		Material = mat,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = m,
	}) :: Part
	if shape then
		p.Shape = shape
	end
	return p
end

-- The modelled crown, cloned from FV_Art.Props, every part's offset from the band's centre kept as an attribute.
local function modelled(kind: Kind): (Model?, BasePart?)
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local props = art and art:FindFirstChild("Props")
	local src = props and props:FindFirstChild(if kind == "Obsidian" then "CrownObsidian" else "Crown")
	if not src or not src:IsA("Model") then
		return nil, nil
	end
	local m = new("Model", { Name = "FV_Crown" }) :: Model
	local root = part(m, "Root", Vector3.one * 0.1, GOLD, Enum.Material.Metal)
	root.Transparency = 1
	root:SetAttribute("Offset", CFrame.identity)
	local origin = src:GetPivot() * MODEL_BAND
	for _, d in ipairs(src:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "Hit" then
			local c = d:Clone()
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
			c:SetAttribute("Offset", origin:ToObjectSpace(d.CFrame))
			c.Parent = m
		end
	end
	m.PrimaryPart = root
	return m, root
end

-- The part-built crown in local space (origin = the band's centre), when the model isn't in the place.
local function partBuilt(kind: Kind): (Model, BasePart)
	local obsidian = kind == "Obsidian"
	local bandA = if obsidian then OBSIDIAN else GOLD
	local bandB = if obsidian then OBSIDIAN_EDGE else GOLD_DEEP
	local metal = if obsidian then Enum.Material.Glass else Enum.Material.Metal
	local m = new("Model", { Name = "FV_Crown" }) :: Model
	local root = part(m, "Root", Vector3.one * 0.1, GOLD, Enum.Material.Metal)
	root.Transparency = 1
	root:SetAttribute("Offset", CFrame.identity)
	local function add(p: BasePart, cf: CFrame)
		p:SetAttribute("Offset", cf)
	end
	local R, N = 0.62, 10
	for i = 0, N - 1 do -- the band: segments round a ring
		local a = i / N * math.pi * 2
		local seg = part(m, "Band", Vector3.new(0.42, 0.34, 0.12), if i % 2 == 0 then bandA else bandB, metal)
		add(seg, CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -R))
	end
	for i = 0, 4 do -- five points, each with a gem and a ball tip
		local a = i / 5 * math.pi * 2
		local pt = part(m, "Point", Vector3.new(0.18, if obsidian then 0.62 else 0.5, 0.1), bandA, metal)
		add(pt, CFrame.Angles(0, a, 0) * CFrame.new(0, 0.38, -R) * CFrame.Angles(math.rad(-8), 0, 0))
		local tip = part(
			m,
			"Tip",
			Vector3.one * 0.16,
			if obsidian then VIOLET else GOLD,
			if obsidian then Enum.Material.Neon else Enum.Material.Metal,
			Enum.PartType.Ball
		)
		add(tip, CFrame.Angles(0, a, 0) * CFrame.new(0, if obsidian then 0.74 else 0.66, -R + 0.04))
		local gem = part(
			m,
			"Gem",
			Vector3.one * 0.14,
			if obsidian then VIOLET else GEMS[i + 1],
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		add(gem, CFrame.Angles(0, a, 0) * CFrame.new(0, 0.02, -R - 0.07))
	end
	m.PrimaryPart = root
	return m, root
end

-- The crown's life: violet embers and a cold glow for the Obsidian Crown; for the winner's gold crown a lit sparkler
-- standing up out of the top (`top` = how far above the band's centre it stands).
local function effects(m: Model, kind: Kind, top: number)
	local function add(p: BasePart, cf: CFrame)
		p:SetAttribute("Offset", cf)
	end
	if kind == "Obsidian" then
		local core = part(m, "Core", Vector3.one * 0.3, VIOLET, Enum.Material.Neon, Enum.PartType.Ball)
		core.Transparency = 1 -- just the embers' source and the light, inside the cap
		add(core, CFrame.new(0, 0.5, 0))
		local att = new("Attachment", { Parent = core })
		new("ParticleEmitter", {
			Texture = Assets.Vfx.Ember,
			Color = ColorSequence.new(VIOLET, Color3.fromRGB(255, 160, 255)),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.8, 1.3),
			Rate = 10,
			Speed = NumberRange.new(0.8, 1.6),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 0.6, 0),
			Parent = att,
		})
		new("PointLight", { Color = VIOLET, Range = 6, Brightness = 1.2, Parent = core })
		return
	end
	local wand = part(m, "Sparkler", Vector3.new(0.05, 0.7, 0.05), Color3.fromRGB(90, 90, 96), Enum.Material.Metal)
	add(wand, CFrame.new(0, top + 0.26, 0) * CFrame.Angles(0, 0, math.rad(12)))
	local tipPart = part(m, "SparkTip", Vector3.one * 0.12, P.Spark, Enum.Material.Neon, Enum.PartType.Ball)
	add(tipPart, CFrame.new(-0.07, top + 0.6, 0))
	local att = new("Attachment", { Parent = tipPart })
	new("ParticleEmitter", {
		Texture = Assets.Vfx.Streak,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(P.Spark, P.Fuse),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.2, 0.4),
		Rate = 30,
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -10, 0),
		Parent = att,
	})
	new("ParticleEmitter", {
		Texture = Assets.Vfx.Flash,
		Color = ColorSequence.new(Color3.new(1, 0.96, 0.8)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(0.5, 0.2),
		Transparency = NumberSequence.new(0, 0.7),
		Lifetime = NumberRange.new(0.06, 0.1),
		Rate = 25,
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		Parent = att,
	})
	new("PointLight", { Color = P.Spark, Range = 7, Brightness = 1.6, Parent = tipPart })
end

local function build(kind: Kind): (Model, BasePart)
	local m, root = modelled(kind)
	if m and root then
		effects(m, kind, STAR_TOP)
		return m, root
	end
	local pm, proot = partBuilt(kind)
	effects(pm, kind, 0.6)
	return pm, proot
end

local function attach(host: Instance, model: Model, kind: Kind)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local m, root = build(kind)
	m.Parent = model
	crowns[host] = { model = m, root = root, head = head, kind = kind }
end

local function detach(host: Instance)
	local c = crowns[host]
	if c then
		c.model:Destroy()
		crowns[host] = nil
	end
end

local function sync()
	local seen: { [Instance]: boolean } = {}
	for _, e in ipairs(ClientState.participants()) do
		local host, model = e.host, e.model
		local kind: Kind? = if host:GetAttribute("Crowned")
			then "Gold"
			elseif host:GetAttribute("Eq_Title") == OBSIDIAN_TITLE then "Obsidian"
			else nil
		if model and kind then
			seen[host] = true
			local c = crowns[host]
			if not c or c.model.Parent ~= model or c.kind ~= kind then
				detach(host)
				attach(host, model, kind)
			end
		end
	end
	for host in pairs(crowns) do
		if not seen[host] then
			detach(host)
		end
	end
end

local function render()
	local t = os.clock()
	for host, c in pairs(crowns) do
		if c.head.Parent == nil then
			detach(host)
			continue
		end
		local base = CFrame.new(c.head.Position + Vector3.new(0, 1.35 + math.sin(t * 2) * 0.05, 0))
			* CFrame.Angles(0, t * 0.8, 0)
			* CFrame.Angles(math.rad(6), 0, 0)
		for _, p in ipairs(c.model:GetChildren()) do
			if p:IsA("BasePart") then
				local off = p:GetAttribute("Offset")
				if typeof(off) == "CFrame" then
					p.CFrame = base * off
				end
			end
		end
	end
end

function CrownController.start()
	task.spawn(function()
		while true do
			pcall(sync)
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(render)
end

return CrownController
