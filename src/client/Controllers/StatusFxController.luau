--!strict
-- Status effects on bodies (ART_BACKLOG "Effects polish"; Asset Bible §5.3 stun, §5.4 aftermath):
--   • Soot: anyone blown up (State = Tumbled) goes sooty: a dark Highlight fill over the whole body (it covers shirts
--     and pants, which ignore part colour) and dark smoke wisps curling off the torso while they lie there; once
--     they're up the soot washes off over a couple of seconds. (Roblox draws at most 31 Highlights; past that a body
--     simply shows no soot.)
--   • Stun: a Bomber whose bomb blew on them (StunnedUntil in the future) gets the cartoon dizzy ring: three of the 3D
--     stars circling over their head, shedding little gold sparks, until the stun ends.
-- Pure presentation: reads the server's `State` / `StunnedUntil` attributes on each host (Player or bot model).
-- Implements: ART_BACKLOG effects polish (Bomber stun, ragdoll soot).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Theme = require(script.Parent.Parent.UI.Theme)

local new = Theme.new

local StatusFxController = {}

local SOOT = Color3.fromRGB(46, 40, 44)
local SOOT_FILL = 0.38 -- the Highlight's fill transparency when fully sooty
local SOOT_IN, SOOT_OUT = 0.12, 2.2 -- seconds to blacken / to wash off
local SOOT_HOLD = 1.4 -- seconds the soot stays on after getting up
local STAR_COUNT, STAR_RADIUS, STAR_SPIN, STAR_SIZE = 3, 1.05, 5.5, 0.85 -- studs, rad/s, studs
local STAR_HEIGHT = 1.05 -- above the head's centre

type Sooted = { hl: Highlight, wisps: ParticleEmitter?, cleanAt: number? }
type Dizzy = { gui: BillboardGui, stars: { Frame }, sparks: ParticleEmitter, attach: Attachment }

local sooted: { [Model]: Sooted } = {}
local dizzy: { [Model]: Dizzy } = {}

local function hosts(): { Instance }
	local out: { Instance } = Players:GetPlayers()
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

local function sootOn(char: Model)
	local s = sooted[char]
	if s then
		if s.cleanAt then
			s.cleanAt = nil
			TweenService:Create(s.hl, TweenInfo.new(SOOT_IN), { FillTransparency = SOOT_FILL }):Play()
		end
		if s.wisps then
			s.wisps.Enabled = true
		end
		return
	end
	local hl = new("Highlight", {
		Name = "FV_Soot",
		FillColor = SOOT,
		FillTransparency = 1,
		OutlineTransparency = 1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Adornee = char,
		Parent = char,
	}) :: Highlight
	TweenService:Create(hl, TweenInfo.new(SOOT_IN), { FillTransparency = SOOT_FILL }):Play()
	s = { hl = hl }
	local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	if torso then
		s.wisps = new("ParticleEmitter", {
			Name = "FV_SootWisps",
			Texture = Assets.Vfx.Smoke,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.fromRGB(48, 44, 50), Color3.fromRGB(110, 104, 112)),
			LightInfluence = 0.2,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.8) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.6, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(1.0, 1.4),
			Rate = 9,
			Speed = NumberRange.new(1.5, 3),
			SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 2, 0),
			Rotation = NumberRange.new(-40, 40),
			RotSpeed = NumberRange.new(-30, 30),
			Parent = torso,
		})
	end
	sooted[char] = s
end

local function sootWash(char: Model, s: Sooted)
	TweenService:Create(s.hl, TweenInfo.new(SOOT_OUT, Enum.EasingStyle.Quad), { FillTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(s.hl, SOOT_OUT + 0.2)
	if s.wisps then
		s.wisps.Enabled = false
		game:GetService("Debris"):AddItem(s.wisps, 1.5)
	end
	sooted[char] = nil
end

local function dizzyOn(char: Model): Dizzy?
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local attach = new("Attachment", { Name = "FV_Dizzy", Position = Vector3.new(0, STAR_HEIGHT, 0), Parent = head })
	local gui = new("BillboardGui", {
		Name = "FV_DizzyStars",
		Adornee = head,
		Size = UDim2.fromScale(STAR_RADIUS * 2 + STAR_SIZE, STAR_RADIUS + STAR_SIZE),
		StudsOffsetWorldSpace = Vector3.new(0, STAR_HEIGHT, 0),
		AlwaysOnTop = false,
		LightInfluence = 0,
		Parent = head,
	}) :: BillboardGui
	local stars = {}
	for i = 1, STAR_COUNT do
		local holder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(STAR_SIZE / (STAR_RADIUS * 2 + STAR_SIZE), STAR_SIZE / (STAR_RADIUS + STAR_SIZE)),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Assets.Icon.Star,
			ScaleType = Enum.ScaleType.Fit,
			Parent = holder,
		})
		stars[i] = holder
	end
	local sparks = new("ParticleEmitter", {
		Name = "FV_DizzySparks",
		Texture = Assets.Vfx.Ember,
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 90), Color3.fromRGB(255, 160, 40)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Rate = 14,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(180, 40),
		Acceleration = Vector3.new(0, -6, 0),
		Parent = attach,
	}) :: ParticleEmitter
	local d: Dizzy = { gui = gui, stars = stars, sparks = sparks, attach = attach }
	dizzy[char] = d
	return d
end

local function dizzyOff(char: Model, d: Dizzy)
	d.gui:Destroy()
	d.sparks.Enabled = false
	game:GetService("Debris"):AddItem(d.attach, 0.8)
	dizzy[char] = nil
end

local function step()
	local t = workspace:GetServerTimeNow()
	local clock = os.clock()
	local seen: { [Model]: boolean } = {}
	for _, host in ipairs(hosts()) do
		local char = characterOf(host)
		if char then
			seen[char] = true
			-- soot: on while tumbled, then held a moment and washed off
			if host:GetAttribute("State") == "Tumbled" then
				sootOn(char)
			else
				local s = sooted[char]
				if s then
					if not s.cleanAt then
						s.cleanAt = clock + SOOT_HOLD
						if s.wisps then
							s.wisps.Enabled = false
						end
					elseif clock >= s.cleanAt then
						sootWash(char, s)
					end
				end
			end
			-- dizzy stars while stunned
			local stunned = (host:GetAttribute("StunnedUntil") or 0) > t
			local d = dizzy[char]
			if stunned and not d then
				d = dizzyOn(char)
			elseif not stunned and d then
				dizzyOff(char, d)
				d = nil
			end
			if d then
				local n = #d.stars
				for i, s in ipairs(d.stars) do
					local a = clock * STAR_SPIN + (i - 1) * (math.pi * 2 / n)
					-- the ring seen a little from above: x = cos, y = sin squashed; the far side sinks behind
					s.Position = UDim2.fromScale(
						0.5 + math.cos(a) * STAR_RADIUS / (STAR_RADIUS * 2 + STAR_SIZE),
						0.5 + math.sin(a) * 0.22
					)
					s.Rotation = math.deg(a) * 0.5
					s.ZIndex = if math.sin(a) > 0 then 2 else 1
				end
			end
		end
	end
	-- characters that left (respawned, removed)
	for char in pairs(sooted) do
		if not seen[char] or not char.Parent then
			sooted[char] = nil
		end
	end
	for char, d in pairs(dizzy) do
		if not seen[char] or not char.Parent then
			dizzyOff(char, d)
		end
	end
end

function StatusFxController.start()
	RunService.Heartbeat:Connect(step)
end

return StatusFxController
