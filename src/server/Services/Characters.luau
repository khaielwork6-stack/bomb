--!strict
-- R6 character spawning (the place defaults to R15; we build R6 rigs ourselves), collision groups,
-- movement locks, ragdolls and scaling. GDD §7.2, §8.5, §21.8, D-07.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local CosmeticLooks = require(ReplicatedStorage.Shared.CosmeticLooks)
local Participants = require(script.Parent.Participants)
local Arena = require(script.Parent.Arena)

type Participant = Participants.Participant

local CG = Types.Collision
local Characters = {}

local descCache: { [number]: HumanoidDescription } = {}

local CHAR_GROUPS = { CG.Runner, CG.Bomber, CG.SafeRunner, CG.Lobby, CG.Ragdoll }

local function setupCollisionGroups()
	local all = { CG.Runner, CG.Bomber, CG.SafeRunner, CG.Lobby, CG.Ragdoll, CG.LineWall, CG.Bounds, CG.Prop }
	for _, g in ipairs(all) do
		if not PhysicsService:IsCollisionGroupRegistered(g) then
			PhysicsService:RegisterCollisionGroup(g)
		end
	end
	-- Characters never collide with each other.
	for _, a in ipairs(CHAR_GROUPS) do
		for _, b in ipairs(CHAR_GROUPS) do
			PhysicsService:CollisionGroupSetCollidable(a, b, false)
		end
	end
	-- Line walls: block catchers (can't enter safe zones) and safe runners (can't leave). Runners pass.
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.Runner, false)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.Lobby, false)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.Ragdoll, false)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.Bomber, true)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.SafeRunner, true)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.Bounds, false)
	PhysicsService:CollisionGroupSetCollidable(CG.LineWall, CG.Prop, false)
	-- Bounds: everyone collides; world doesn't care.
	PhysicsService:CollisionGroupSetCollidable(CG.Bounds, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(CG.Bounds, CG.Prop, false)
	PhysicsService:CollisionGroupSetCollidable(CG.Prop, "Default", true)
end

function Characters.init()
	setupCollisionGroups()
	Players.CharacterAutoLoads = false
end

local function setGroup(model: Model, group: string)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

function Characters.groupFor(p: Participant): string
	if p.state == Types.State.Downed or p.state == Types.State.Tumbled then
		return CG.Ragdoll
	end
	if p.role == Types.Role.Bomber then
		return CG.Bomber
	end
	if p.role == Types.Role.Runner then
		return if p.state == Types.State.Safe then CG.SafeRunner else CG.Runner
	end
	return CG.Lobby
end

function Characters.applyGroup(p: Participant)
	if p.model then
		setGroup(p.model, Characters.groupFor(p))
	end
end

local function prepareRig(model: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = 0
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.MaxHealth = 1e6
		hum.Health = 1e6
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	-- Shared/Locomotion animates every character (the owner's client for players, the server for bots); the stock
	-- Animate script would fight it for the run and idle.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = CG.Lobby
		end
	end
	-- Generated rigs use Head as PrimaryPart; every placement CFrame in the game is a root CFrame.
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		model.PrimaryPart = root
	end
end

local function getDescription(userId: number): HumanoidDescription
	local cached = descCache[userId]
	if cached then
		return cached:Clone()
	end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	local d = if ok and desc then desc else Instance.new("HumanoidDescription")
	descCache[userId] = d
	return d:Clone()
end

-- Is the lobby in its final place? (LobbyArranger raises and rearranges it at server start.)
function Characters.lobbyReady(): boolean
	local lobby = workspace:FindFirstChild("Lobby")
	return lobby == nil or lobby:GetAttribute("CG_Arranged") == true
end

-- Wait (up to `timeout` seconds) for the lobby to be arranged before placing anyone in it.
function Characters.waitLobby(timeout: number)
	local deadline = os.clock() + timeout
	while not Characters.lobbyReady() and os.clock() < deadline do
		task.wait(0.1)
	end
end

function Characters.lobbyCFrame(): CFrame
	local lobby = workspace:FindFirstChild("Lobby")
	local spawnPart = lobby and lobby:FindFirstChild("LobbySpawn") :: BasePart?
	if spawnPart and spawnPart:IsA("BasePart") then
		local r = Random.new()
		local half = spawnPart.Size * 0.4
		local off =
			Vector3.new(r:NextNumber(-half.X, half.X), spawnPart.Size.Y / 2 + 3.5, r:NextNumber(-half.Z, half.Z))
		return CFrame.new(spawnPart.Position + off) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0)
	end
	-- No lobby until P6 (The Depot): wait on the start dock, never in the air over the field.
	if Arena.current then
		return Arena.runnerLine(-1, 1, Random.new())[1]
	end
	return CFrame.new(0, 20, 0)
end

-- Spawn (or respawn) a human's R6 character at `cf`.
function Characters.spawnHuman(p: Participant, cf: CFrame)
	local player = p.player
	if not player or player.Parent ~= Players or p.data.spawning then
		return
	end
	-- Re-entrancy guard: the description fetch yields, and the rescue loop/ClientReady must not double-spawn.
	p.data.spawning = true
	local old = player.Character
	local desc = getDescription(player.UserId)
	p.data.spawning = nil
	if player.Parent ~= Players then
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[Characters] R6 build failed, using default description", model)
		model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end
	model.Name = player.Name
	prepareRig(model)
	model:PivotTo(cf)
	model.Parent = workspace
	player.Character = model
	if old and old ~= model then
		old:Destroy()
	end
	Participants.setCharacter(p, model)
	p.data.teleportAt = workspace:GetServerTimeNow()
	p.data.ragdolled = false
	p.data.settledParts = nil
	Characters.applyGroup(p)
	local root = p.root
	if root then
		pcall(function()
			root:SetNetworkOwner(player)
		end)
	end
end

function Characters.buildBot(name: string, r: Random): Model
	local desc = Instance.new("HumanoidDescription")
	local skins = {
		Color3.fromRGB(242, 210, 182),
		Color3.fromRGB(224, 172, 138),
		Color3.fromRGB(198, 136, 99),
		Color3.fromRGB(141, 90, 59),
		Color3.fromRGB(92, 58, 38),
		Color3.fromRGB(255, 224, 189),
	}
	local pairsList = {
		{ Color3.fromRGB(255, 138, 61), Color3.fromRGB(40, 36, 70) },
		{ Color3.fromRGB(59, 164, 255), Color3.fromRGB(244, 241, 255) },
		{ Color3.fromRGB(80, 210, 130), Color3.fromRGB(52, 46, 90) },
		{ Color3.fromRGB(255, 200, 61), Color3.fromRGB(40, 36, 70) },
		{ Color3.fromRGB(176, 124, 255), Color3.fromRGB(244, 241, 255) },
		{ Color3.fromRGB(92, 225, 230), Color3.fromRGB(52, 46, 90) },
		{ Color3.fromRGB(255, 77, 94), Color3.fromRGB(244, 241, 255) },
		{ Color3.fromRGB(180, 184, 212), Color3.fromRGB(40, 36, 70) },
	}
	local skin = skins[r:NextInteger(1, #skins)]
	local outfit = pairsList[r:NextInteger(1, #pairsList)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = outfit[1]
	desc.LeftLegColor = outfit[2]
	desc.RightLegColor = outfit[2]
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- LocalScripts don't run on server NPCs; BotAnimator drives bots
	end
	-- Part-built hat (Asset Bible §4.5)
	local hatKind = r:NextInteger(1, 6)
	local head = model:FindFirstChild("Head") :: BasePart?
	if head and hatKind <= 5 then
		local hatColor = outfit[1]:Lerp(Color3.new(1, 1, 1), 0.15)
		local function hatPart(size: Vector3, offset: CFrame, shape: Enum.PartType?)
			local hp = Instance.new("Part")
			hp.Name = "Hat"
			hp.Size = size
			hp.Shape = shape or Enum.PartType.Block
			hp.Color = hatColor
			hp.Material = Enum.Material.SmoothPlastic
			hp.CanCollide = false
			hp.CanQuery = false
			hp.CanTouch = false
			hp.Massless = true
			hp.CastShadow = false
			hp.CFrame = assert(head).CFrame * offset
			local w = Instance.new("WeldConstraint")
			w.Part0 = hp
			w.Part1 = head
			w.Parent = hp
			hp.Parent = model
		end
		if hatKind == 1 then -- cap
			hatPart(Vector3.new(1.3, 0.45, 1.3), CFrame.new(0, 0.6, 0))
			hatPart(Vector3.new(1.2, 0.12, 0.7), CFrame.new(0, 0.42, -0.85))
		elseif hatKind == 2 then -- beanie
			hatPart(Vector3.new(1.3, 0.6, 1.3), CFrame.new(0, 0.55, 0))
			hatPart(Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 1.0, 0), Enum.PartType.Ball)
		elseif hatKind == 3 then -- bucket
			hatPart(Vector3.new(1.25, 0.5, 1.25), CFrame.new(0, 0.6, 0))
			hatPart(Vector3.new(1.8, 0.1, 1.8), CFrame.new(0, 0.38, 0))
		elseif hatKind == 4 then -- headphones
			hatPart(Vector3.new(0.25, 0.7, 0.7), CFrame.new(0.7, 0, 0))
			hatPart(Vector3.new(0.25, 0.7, 0.7), CFrame.new(-0.7, 0, 0))
			hatPart(Vector3.new(1.6, 0.15, 0.25), CFrame.new(0, 0.65, 0))
		else -- propeller cap
			hatPart(Vector3.new(1.3, 0.45, 1.3), CFrame.new(0, 0.6, 0))
			hatPart(Vector3.new(1.6, 0.06, 0.2), CFrame.new(0, 1.0, 0))
		end
	end
	prepareRig(model)
	return model
end

-- A bot wearing a real avatar (AvatarPool: built and tidied in the background): same gameplay setup as any rig.
function Characters.prepareAvatarRig(model: Model, name: string)
	model.Name = name
	prepareRig(model)
end

function Characters.pivot(p: Participant, cf: CFrame)
	p.data.teleportAt = workspace:GetServerTimeNow()
	-- Clients re-frame their camera behind the character after a server teleport.
	p.attrs:SetAttribute("TeleportAt", p.data.teleportAt)
	if p.model then
		p.model:PivotTo(cf)
		local root = p.root
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function restoreOwner(p: Participant)
	local root = p.root
	if not root or root.Anchored then
		return
	end
	pcall(function()
		if p.player then
			root:SetNetworkOwner(p.player)
		else
			root:SetNetworkOwner(nil)
		end
	end)
end

-- Freeze/unfreeze a participant in place (phase locks). Anchors the root.
function Characters.setLocked(p: Participant, locked: boolean)
	local root = p.root
	if not root or root.Parent == nil then
		return
	end
	p.data.lockToken = (p.data.lockToken or 0) + 1 -- cancels a pending soft lock
	p.data.locked = locked
	p.attrs:SetAttribute("Locked", locked)
	if p.data.ragdolled then
		return
	end
	root.Anchored = locked
	if not locked then
		restoreOwner(p)
	end
end

-- Soft lock (a run ends): input is off from now (the Locked attribute), and the body brakes out its momentum and
-- plays its stop like any other release; the root is anchored only once it has come to rest. Nobody freezes
-- mid-stride or mid-air, and a player's own client is never snapped back to the server's slightly older copy of
-- them (by the time the server sees them stand still, its copy has caught up).
local SOFT_STILL = 0.04 -- studs per check that count as standing still
local SOFT_HOLD = 0.2 -- seconds of stillness before anchoring
local SOFT_MAX = 1.4 -- anchor regardless after this long

function Characters.softLock(p: Participant)
	local root = p.root
	if not root or root.Parent == nil then
		return
	end
	local token = (p.data.lockToken or 0) + 1
	p.data.lockToken = token
	p.data.locked = true
	p.attrs:SetAttribute("Locked", true)
	if p.data.ragdolled or root.Anchored then
		return
	end
	task.spawn(function()
		local last = root.Position
		local still, deadline = 0, os.clock() + SOFT_MAX
		while p.data.lockToken == token and root.Parent and not root.Anchored do
			task.wait(0.05)
			if p.data.lockToken ~= token then
				return
			end
			local pos = root.Position
			still = if (pos - last).Magnitude < SOFT_STILL then still + 0.05 else 0
			last = pos
			if still >= SOFT_HOLD or os.clock() > deadline then
				if p.data.locked and not p.data.ragdolled then
					root.Anchored = true
				end
				return
			end
		end
	end)
end

-- R6 ragdoll: swap limb motors for ball sockets; server owns physics while ragdolled.
function Characters.ragdoll(p: Participant, impulse: Vector3)
	local model, root, hum = p.model, p.root, p.humanoid
	if not model or not root or not hum then
		return
	end
	if p.data.ragdolled then
		-- Already limp (a hazard tumble caught at its tail): just knock the body along.
		local limp = model:FindFirstChild("Torso") :: BasePart?
		if limp and not root.Anchored then
			limp.AssemblyLinearVelocity = impulse
		end
		return
	end
	p.data.ragdolled = true
	local torso = model:FindFirstChild("Torso") :: BasePart?
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	hum.PlatformStand = true
	-- Ragdoll style (§17.1, cosmetic only): extra joint freedom, a spin, bounciness, or limbs flung outward.
	local styleId = p.attrs:GetAttribute("Cos_ragdoll")
	local style = (if type(styleId) == "string" then CosmeticLooks.Ragdolls[styleId] else nil) or {}
	local extra = style.extraAngle or 0
	local sockets = {}
	if torso then
		-- { cone°, twist°, friction torque }. Friction + no bounce at the limits (2026-10-08, the user: downed bodies
		-- "keep tilting their heads in circles"): without it the head swung round inside its neck cone for ≈3.5 s
		-- after the body had stopped. Now each joint swings once as the body drops and comes to rest.
		local limits = {
			Neck = { 30, 45, 60 },
			["Right Shoulder"] = { 90, 60, 80 },
			["Left Shoulder"] = { 90, 60, 80 },
			["Right Hip"] = { 75, 30, 100 },
			["Left Hip"] = { 75, 30, 100 },
		}
		for _, m in ipairs(torso:GetChildren()) do
			local lim = limits[m.Name]
			if m:IsA("Motor6D") and lim and m.Part0 and m.Part1 then
				local a0 = Instance.new("Attachment")
				a0.Name = "RagA0"
				a0.CFrame = m.C0
				a0.Parent = m.Part0
				local a1 = Instance.new("Attachment")
				a1.Name = "RagA1"
				a1.CFrame = m.C1
				a1.Parent = m.Part1
				local bs = Instance.new("BallSocketConstraint")
				bs.Name = "RagSocket"
				bs.Attachment0 = a0
				bs.Attachment1 = a1
				bs.LimitsEnabled = true
				bs.UpperAngle = math.min(lim[1] + extra, 175)
				bs.TwistLimitsEnabled = true
				bs.TwistLowerAngle = -math.min(lim[2] + extra, 175)
				bs.TwistUpperAngle = math.min(lim[2] + extra, 175)
				bs.Restitution = if style.elasticity then 0.3 else 0
				bs.MaxFrictionTorque = lim[3]
				bs.Parent = m.Part0
				table.insert(sockets, a0)
				table.insert(sockets, a1)
				table.insert(sockets, bs)
				m.Enabled = false
			end
		end
	end
	-- The root joint lives in the root part (not the torso), so it stayed a Motor6D that every playing animation
	-- (run, idle, emotes, on every client) kept twisting: the torso was yanked against the root each frame, which
	-- made the body shake violently and dig into the floor. While limp a plain weld holds the root instead.
	local rootJoint = root:FindFirstChild("RootJoint") :: Motor6D?
	if rootJoint and rootJoint:IsA("Motor6D") and torso then
		local w = Instance.new("Weld")
		w.Name = "RagRootWeld"
		w.Part0 = root
		w.Part1 = torso
		w.C0 = rootJoint.C0
		w.C1 = rootJoint.C1
		w.Parent = root
		rootJoint.Enabled = false
		table.insert(sockets, w)
	end
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part ~= root then
			part.CanCollide = true
			if style.elasticity then
				part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, style.elasticity, 1, 1)
			end
		end
	end
	-- Socketed parts still collide with each other (constraints don't exclude them like joints do): limbs pressed
	-- into the torso fought it every step. Exclude the touching pairs.
	local function noCollide(a: string, b: string)
		local pa, pb = model:FindFirstChild(a), model:FindFirstChild(b)
		if pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
			local nc = Instance.new("NoCollisionConstraint")
			nc.Name = "RagNoCollide"
			nc.Part0 = pa
			nc.Part1 = pb
			nc.Parent = pa
			table.insert(sockets, nc)
		end
	end
	for _, limb in ipairs({ "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		noCollide("Torso", limb)
	end
	noCollide("Left Leg", "Right Leg")
	setGroup(model, CG.Ragdoll)
	p.data.ragSockets = sockets
	root.AssemblyLinearVelocity = impulse
	if torso then
		torso.AssemblyLinearVelocity = impulse
		torso.AssemblyAngularVelocity = Vector3.new(impulse.Z, 0, -impulse.X) * 0.25
			+ Vector3.new(0, style.spin or 0, 0)
		if style.splay then
			-- Starfish: limbs flung outward from the torso.
			for _, limb in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
				local l = model:FindFirstChild(limb) :: BasePart?
				if l then
					local out = (l.Position - torso.Position) * Vector3.new(1, 0, 1)
					if out.Magnitude > 1e-3 then
						l.AssemblyLinearVelocity = impulse + out.Unit * 18 + Vector3.new(0, 6, 0)
					end
				end
			end
		end
	end
end

-- Knockback without a ragdoll (Bubble pop, abilities): a short-lived LinearVelocity on the root moves the body
-- `distance` studs along `dir` over `time` seconds. Constraints replicate, so a player's own client simulates it
-- (no network-ownership swap); the movement validator allows the extra distance (p.data.extraSlack).
function Characters.push(p: Participant, dir: Vector3, distance: number, time: number?)
	local root = p.root
	local flat = dir * Vector3.new(1, 0, 1)
	if not root or root.Anchored or p.data.ragdolled or flat.Magnitude < 1e-3 then
		return
	end
	local dur = time or 0.25
	local att = Instance.new("Attachment")
	att.Name = "CG_PushAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "CG_Push"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.new(flat.Unit.X, flat.Unit.Z) * (distance / dur)
	lv.MaxForce = 1e6
	lv.Parent = root
	-- The movement validator allows this push's distance on top (not a full reset, which would accept any position).
	local untilT = workspace:GetServerTimeNow() + dur + 0.5
	p.data.extraSlack = math.max(
		if (p.data.extraSlackUntil or 0) > workspace:GetServerTimeNow() then p.data.extraSlack or 0 else 0,
		distance + 2
	)
	p.data.extraSlackUntil = untilT
	Debris:AddItem(att, dur)
	Debris:AddItem(lv, dur)
end

-- Freeze a ragdoll where it lies (downed settle): the whole body, not just the root, so once it has dropped
-- nothing keeps moving (2026-10-08). unragdoll lets go of exactly these parts again.
function Characters.settle(p: Participant)
	if not (p.data.ragdolled and p.root) then
		return
	end
	p.root.Anchored = true
	local frozen = p.data.settledParts or {}
	if p.model then
		for _, part in ipairs(p.model:GetDescendants()) do
			if part:IsA("BasePart") and part ~= p.root and not part.Anchored then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
				part.Anchored = true
				table.insert(frozen, part)
			end
		end
	end
	p.data.settledParts = frozen
end

function Characters.unragdoll(p: Participant)
	local model, root, hum = p.model, p.root, p.humanoid
	if not p.data.ragdolled then
		return
	end
	p.data.ragdolled = false
	for _, part in ipairs(p.data.settledParts or {}) do
		if part.Parent then
			part.Anchored = false
		end
	end
	p.data.settledParts = nil
	for _, inst in ipairs(p.data.ragSockets or {}) do
		inst:Destroy()
	end
	p.data.ragSockets = nil
	if model then
		local torso = model:FindFirstChild("Torso")
		if torso then
			for _, m in ipairs(torso:GetChildren()) do
				if m:IsA("Motor6D") then
					m.Enabled = true
				end
			end
		end
		local rootJoint = root and root:FindFirstChild("RootJoint")
		if rootJoint and rootJoint:IsA("Motor6D") then
			rootJoint.Enabled = true
		end
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") then
				part.CanCollide = part.Name == "Torso" or part.Name == "Head"
				part.CustomPhysicalProperties = nil -- undo a Bouncy Ball ragdoll
			end
		end
	end
	if root then
		-- Stand upright at the current spot, feet on the actual floor under the body (the limp body may lie low or be
		-- tipped against something, so its root height says nothing about where the ground is).
		local torso = model and model:FindFirstChild("Torso") :: BasePart?
		local at = if torso then torso.Position else root.Position
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.1 then
			look = Vector3.new(0, 0, -1)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then
				table.insert(ignore, plr.Character)
			end
		end
		if model then
			table.insert(ignore, model)
		end
		local bots = workspace:FindFirstChild("Bots")
		if bots then
			table.insert(ignore, bots)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
		local scale = p.data.scale or 1
		local standY = if hit then hit.Position.Y + 3 * scale else at.Y + 1.5 * scale -- R6: root 3 studs above the feet
		local pos = Vector3.new(at.X, standY, at.Z)
		root.Anchored = false
		if model then
			model:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	Characters.applyGroup(p)
	if p.data.locked and root then
		root.Anchored = true
	else
		restoreOwner(p)
	end
end

function Characters.isRagdolled(p: Participant): boolean
	return p.data.ragdolled == true
end

function Characters.setScale(p: Participant, scale: number)
	local model = p.model
	if not model then
		return
	end
	local old = p.data.scale or 1
	if math.abs(old - scale) < 1e-3 then
		return
	end
	pcall(function()
		model:ScaleTo(scale)
	end)
	-- ScaleTo scales about the root; R6 hips sit 3 studs up per unit scale, so keep the feet on the floor.
	local root = p.root
	if root then
		model:PivotTo(model:GetPivot() + Vector3.new(0, 3 * (scale - old), 0))
	end
	p.data.scale = scale
	p.attrs:SetAttribute("Scale", scale)
end

function Characters.killPlaneY(): number
	return Config.Game.KILL_PLANE_Y
end

return Characters
