--!strict
-- THROW MODE on every client (GDD §7.4c, D-THROW-01: "the bomb is a ball").
--   The body (tools/anim, 60 fps): ThrowCoil the moment you press (a dip, then a pitcher's wind-up: the torso turns
--   away, the arm flies up behind the head, the free arm points at the target), ThrowHold while you hold (the strain
--   trembles faster as the power builds), Throw on release (a last squeeze, the whip cracks over the top, the bomb
--   leaves on the whip's frame with a freeze, a huge follow-through). A Carrier's bomb moves from the back into the
--   hand for the wind-up. Everyone else sees your wind-up too (ThrowWindup relay), so a throw can be read and dodged.
--   Your throw (F-THROW-01): hold click / R2 / THROW to wind up (the arm draws back and holds, the power ticks up),
--   aim with the camera, let go. A tap throws at once. While you hold, a dotted arc shows exactly where it will come
--   down (the same physics the server runs, Shared/ThrowPhysics), and a white outline marks who the aim bends toward.
--   Aim assist (F-THROW-07): the aim leads a target inside a small cone (wider on a gamepad, widest on a phone; a
--   phone's tap also picks the power for the distance). The server decides everything; your own throw is drawn at once
--   and handed over to the server's flight when it arrives.
--   Every flight (F-THROW-02): the hero bomb in the thrower's skin, wide-eyed, tumbling along its arc with a ribbon
--   trail; dust and a clank on every bounce; a miss is reeled back to the thrower on its fuse cord; a hand bomb that
--   misses fizzles out; a parried one is batted away. The landing beats are the pass's / slap's (HandOff, Slap).
-- Implements: F-THROW-01, -02, -04 (drawn), -06 (drawn), -07.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ThrowPhysics = require(ReplicatedStorage.Shared.ThrowPhysics)
local BombFace = require(script.Parent.Parent.BombFace)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Theme = require(script.Parent.Parent.UI.Theme)
local BombController = require(script.Parent.BombController)
local CameraController = require(script.Parent.CameraController)
local FxController = require(script.Parent.FxController)
local ImpactController = require(script.Parent.ImpactController)
local InputController = require(script.Parent.InputController)
local SlapController = require(script.Parent.SlapController)

local TH = Config.Throw
local B = Config.Bomb
local F = Config.Feel
local P = Theme.Palette
local new = Theme.new
local FLAT = Vector3.new(1, 0, 1)
local player = Players.LocalPlayer

local ThrowController = {}

function ThrowController.on(): boolean
	return ClientState.get("ThrowMode") == true
end

-- ── The world the bomb bounces off (everything but bodies and our own effects) ────────────────────────────────
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true
local castRefreshAt = 0
local fxFolder: Folder

local function refreshCast()
	local list: { Instance } = { fxFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, n in ipairs({ "Bots", "FV_DangerRings" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(list, f)
		end
	end
	castParams.FilterDescendantsInstances = list
end

local function cast(a: Vector3, b: Vector3): (Vector3?, Vector3?)
	local hit = workspace:Raycast(a, b - a, castParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, nil
end

-- ── Flights, drawn ──────────────────────────────────────────────────────────────────────────────────────────────
type Vis = {
	model: Model,
	state: ThrowPhysics.State,
	owner: string,
	bombId: number?,
	tag: boolean,
	turn: CFrame, -- the tumble so far
	predicted: boolean, -- our own throw, before the server's flight arrives
	bornAt: number,
	reel: { from: Vector3, at: number, time: number, to: string, boom: boolean }?, -- being reeled back to `to`
	knocked: number?, -- os.clock() it was batted away (a parried hand bomb)
}
local flights: { [string]: Vis } = {}

local function rootOf(id: string): BasePart?
	local _, model = ClientState.byId(id)
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function artTemplate(): Model?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local t = art and art:FindFirstChild("Bomb")
	return if t and t:IsA("Model") then t else nil
end

local function buildModel(owner: string, tag: boolean): Model?
	local tpl = artTemplate()
	if not tpl then
		return nil
	end
	local model = tpl:Clone()
	model.Name = "FV_BombThrown"
	local host = ClientState.byId(owner)
	local skin = host and host:GetAttribute("Eq_BombSkin")
	SkinApply.apply(model, if type(skin) == "string" then skin else nil)
	BombFace.pose(model, "WHEE", Vector3.new(0, 1, 0.25))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
			if string.match(d.Name, "^SeamGlow") then
				d.Transparency = 1
			elseif d.Name == "LampF" or d.Name == "LampB" then
				d.Material = Enum.Material.Neon
				d.Color = P.Spark
			end
		end
	end
	if tag then
		model:ScaleTo(F.HAND_BOMB_SCALE * 1.6) -- a Bomber's hand bomb: smaller than a Carrier's
	end
	local body = model:FindFirstChild("Body", true) :: BasePart?
	if body then
		local r = body.Size.Y * 0.3
		local top = new("Attachment", { Position = Vector3.new(0, r, 0), Parent = body })
		local bottom = new("Attachment", { Position = Vector3.new(0, -r, 0), Parent = body })
		new("Trail", {
			Attachment0 = top,
			Attachment1 = bottom,
			Texture = Assets.Vfx.PassRibbon,
			TextureMode = Enum.TextureMode.Stretch,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new(0, 0.5),
			WidthScale = NumberSequence.new(1.3, 0.4),
			Lifetime = 0.22,
			LightEmission = 0.8,
			LightInfluence = 0,
			FaceCamera = true,
			Parent = body,
		})
	end
	model.Parent = fxFolder
	return model
end

local function puff(pos: Vector3, color: Color3, n: number, size: number)
	local att = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain }) :: Attachment
	task.delay(1.5, function()
		att:Destroy()
	end)
	local e = new("ParticleEmitter", {
		Texture = Assets.Vfx.Smoke,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Lifetime = NumberRange.new(0.4, 0.6),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(70, 20),
		Size = NumberSequence.new(size * 0.6, size),
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new(0.2, 1),
		Rate = 0,
		Parent = att,
	}) :: ParticleEmitter
	e:Emit(n)
end

local function drop(key: string)
	local v = flights[key]
	if v then
		v.model:Destroy()
		flights[key] = nil
	end
end

local function findBy(fn: (Vis) -> boolean): string?
	for key, v in pairs(flights) do
		if fn(v) then
			return key
		end
	end
	return nil
end

-- Bring a flight to where the server's was `lag` seconds ago, now.
local function fastForward(s: ThrowPhysics.State, lag: number)
	local left = math.clamp(lag, 0, 0.3)
	while left > 1e-3 do
		local dt = math.min(left, 1 / 120)
		ThrowPhysics.step(s, dt, cast)
		left -= dt
	end
end

local function lagOf(at: any): number
	return if type(at) == "number" then workspace:GetServerTimeNow() - at else 0
end

local function step(dt: number)
	local clock = os.clock()
	if clock >= castRefreshAt then
		castRefreshAt = clock + 0.5
		refreshCast()
	end
	for key, v in pairs(flights) do
		local reel = v.reel
		if reel then
			-- reeled back on the fuse cord: out of the air and into the thrower's hands
			local k = math.clamp((clock - reel.at) / reel.time, 0, 1)
			local to = rootOf(reel.to)
			local goal = if to then to.Position + Vector3.new(0, 0.6, 0) else reel.from
			local e = 1 - (1 - k) * (1 - k)
			local pos = reel.from:Lerp(goal, e) + Vector3.new(0, math.sin(k * math.pi) * 1.6, 0)
			v.turn = v.turn * CFrame.Angles(dt * 18, 0, dt * 7)
			v.model:PivotTo(CFrame.new(pos) * v.turn)
			if k >= 1 then
				drop(key)
			end
		elseif v.knocked then
			-- batted out of the air: it keeps flying, spinning, and fades into a puff
			ThrowPhysics.step(v.state, dt, cast)
			v.turn = v.turn * CFrame.Angles(dt * 30, dt * 12, 0)
			v.model:PivotTo(CFrame.new(v.state.pos) * v.turn)
			if clock - v.knocked > 0.4 then
				puff(v.state.pos, Color3.fromRGB(196, 186, 172), 4, 2)
				drop(key)
			end
		else
			ThrowPhysics.step(v.state, dt, cast)
			-- it tumbles end over end around the axis across its flight
			local vel = v.state.vel
			local axis = Vector3.new(0, 1, 0):Cross(vel)
			if axis.Magnitude > 1e-3 then
				v.turn = CFrame.fromAxisAngle(axis.Unit, -vel.Magnitude * dt * 0.35) * v.turn
			end
			v.model:PivotTo(CFrame.new(v.state.pos) * v.turn)
			-- our own throw the server never confirmed (it was refused): fade it away
			if v.predicted and clock - v.bornAt > 0.5 then
				puff(v.state.pos, Color3.fromRGB(196, 186, 172), 3, 1.5)
				drop(key)
			elseif clock - v.bornAt > TH.MAX_FLIGHT + 1.5 then
				drop(key) -- never heard how it ended: tidy up
			end
		end
	end
end

-- ── The body: coil → hold → throw (tools/anim) ──────────────────────────────────────────────────────────────────
local windToken: { [Instance]: number } = {}

local function modelOf(host: Instance): Model?
	if host:IsA("Player") then
		return host.Character
	end
	return if host:IsA("Model") then host else nil
end

-- The wind-up: the coil, then the hold loop; a Carrier's bomb moves from the back into the hand.
local function windUp(host: Instance)
	local model = modelOf(host)
	if not model then
		return
	end
	local token = (windToken[host] or 0) + 1
	windToken[host] = token
	if host:GetAttribute("BombId") ~= nil and host:GetAttribute("Role") == "Runner" then
		SlapController.grip(host, true)
		BombController.setInHand(host, true)
	end
	SlapController.playClip(model, "ThrowCoil", 0)
	task.delay(F.THROW_COIL_TIME, function()
		if windToken[host] == token then
			SlapController.playClip(model, "ThrowHold", 0)
			SlapController.stopClip(model, "ThrowCoil", 0.06)
		end
	end)
end

-- The release (or a cancel): the hold stops, Throw plays from `from`; the bomb leaves the hand.
local function letGo(host: Instance, from: number?)
	windToken[host] = (windToken[host] or 0) + 1
	local model = modelOf(host)
	if model then
		SlapController.stopClip(model, "ThrowCoil", 0.04)
		SlapController.stopClip(model, "ThrowHold", 0.04)
		if from then
			SlapController.playClip(model, "Throw", from)
		end
	end
	SlapController.grip(host, false)
	-- the back bomb comes back only if it didn't fly (BombThrown takes over once the server says it did)
	task.delay(0.45, function()
		BombController.setInHand(host, false)
	end)
end

-- The release burst at the hand: a flash and a spray of speed streaks along the throw.
local function releaseBurst(pos: Vector3, dir: Vector3, power: number)
	local att = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain }) :: Attachment
	if dir.Magnitude > 1e-3 then
		att.CFrame = CFrame.lookAt(pos, pos + dir)
	end
	task.delay(1, function()
		att:Destroy()
	end)
	local flash = new("ParticleEmitter", {
		Texture = Assets.Vfx.Flash,
		Lifetime = NumberRange.new(0.08),
		Size = NumberSequence.new(1.6 + 1.6 * power, 0.3),
		Transparency = NumberSequence.new(0.1, 1),
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)),
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = 1,
		Rate = 0,
		Parent = att,
	}) :: ParticleEmitter
	flash:Emit(1)
	local streaks = new("ParticleEmitter", {
		Texture = Assets.Vfx.Streak,
		Lifetime = NumberRange.new(0.1, 0.2),
		Speed = NumberRange.new(30 + 30 * power, 55 + 45 * power),
		SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = NumberSequence.new(0.3, 0),
		Color = ColorSequence.new(Color3.new(1, 1, 1), P.Spark),
		LightEmission = 1,
		LightInfluence = 0,
		Rate = 0,
		Parent = att,
	}) :: ParticleEmitter
	streaks:Emit(math.floor(6 + 8 * power))
end

-- ── Your throw: charge, aim, preview ────────────────────────────────────────────────────────────────────────────
local charging = false
local chargeAt = 0
local ticks = 0
local nextThrow = 0
local dots: { BasePart } = {}
local landing: BasePart
local outline: Highlight

local function now(): number
	return workspace:GetServerTimeNow()
end

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- What I'd throw right now: "Pass" (my bomb), "Tag" (my hand bomb), or nil.
local function throwKind(): string?
	if not ThrowController.on() or not ClientState.activeInRun() then
		return nil
	end
	local role = ClientState.role()
	if player:GetAttribute("BombId") ~= nil then
		if role == "Runner" and not player:GetAttribute("BombLocked") and not player:GetAttribute("BombThrown") then
			return "Pass"
		end
		return nil
	end
	if role == "Bomber" and (player:GetAttribute("TagReadyAt") or 0) <= now() then
		if (player:GetAttribute("StunnedUntil") or 0) > now() then
			return nil
		end
		return "Tag"
	end
	return nil
end

local function power(): number
	return math.clamp((os.clock() - chargeAt) / TH.CHARGE_TIME, 0, 1)
end

local function camAim(root: BasePart): Vector3
	local cam = workspace.CurrentCamera
	local look = (if cam then cam.CFrame.LookVector else root.CFrame.LookVector) * FLAT
	if look.Magnitude < 1e-3 then
		look = root.CFrame.LookVector * FLAT
	end
	return if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
end

-- F-THROW-07: bend the aim toward (and lead) a target inside the device's cone. Returns the aim, the target's model,
-- and (on a phone) the power for that distance.
local function assist(root: BasePart, aim: Vector3, kind: string, pw: number?): (Vector3, Model?, number?)
	local device = InputController.device
	local cone = math.cos(math.rad((TH.ASSIST_CONE :: any)[device] or 8))
	local origin = root.Position + Vector3.new(0, TH.RELEASE_UP, 0)
	local best: BasePart? = nil
	local bestModel: Model? = nil
	local bestDot = cone
	for _, e in ipairs(ClientState.participants()) do
		local host, model = e.host, e.model
		local r = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local role = host:GetAttribute("Role")
		local eligible = host ~= player
			and r ~= nil
			and host:GetAttribute("State") == "Active"
			and host:GetAttribute("BombId") == nil
			and (role == "Runner" or (kind == "Pass" and role == "Bomber"))
		if eligible and r then
			local d = (r.Position - root.Position) * FLAT
			if d.Magnitude > 1e-3 and d.Magnitude <= TH.MAX_RANGE then
				local dot = d.Unit:Dot(aim)
				if dot > bestDot then
					best, bestModel, bestDot = r, model, dot
				end
			end
		end
	end
	if not best then
		return aim, nil, nil
	end
	local rel = best.AssemblyLinearVelocity - root.AssemblyLinearVelocity * TH.INHERIT
	local solved, solvedPower = ThrowPhysics.solve(origin, best.Position, rel, pw)
	return solved or aim, bestModel, solvedPower
end

local function hidePreview()
	for _, d in ipairs(dots) do
		d.Transparency = 1
	end
	landing.Transparency = 1
	outline.Adornee = nil
	outline.Enabled = false
end

local function showPreview(root: BasePart, kind: string)
	local pw = power()
	local aim, target = assist(root, camAim(root), kind, pw)
	local origin = root.Position + Vector3.new(0, TH.RELEASE_UP, 0) + aim * TH.RELEASE_FORWARD
	local vel = ThrowPhysics.launch(aim, pw) + root.AssemblyLinearVelocity * FLAT * TH.INHERIT
	local path = ThrowPhysics.predict(origin, vel, cast, TH.PREVIEW_TIME, TH.PREVIEW_DOTS)
	local at = player:GetAttribute("BombExplodeAt")
	local stage = if type(at) ~= "number"
		then "LIT"
		elseif at - now() <= B.STAGE_CRITICAL then "CRITICAL"
		elseif at - now() <= B.STAGE_HOT then "HOT"
		else "LIT"
	local color = if kind == "Tag" then P.Bomber else Theme.stageColor(stage)
	for i, d in ipairs(dots) do
		local p = path[i + 1]
		if p then
			d.Position = p
			d.Color = color:Lerp(Color3.new(1, 1, 1), 0.25)
			d.Transparency = 0.05 + 0.6 * (i / #dots)
		else
			d.Transparency = 1
		end
	end
	local last = path[#path]
	landing.CFrame = CFrame.new(last - Vector3.new(0, TH.RADIUS - 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	landing.Color = color
	landing.Transparency = 0.25
	outline.Adornee = target
	outline.Enabled = target ~= nil
	-- the power ticks up as you hold (a rising click at a third, two thirds, full)
	local tick = math.floor(pw * 3 + 1e-6)
	if tick > ticks then
		ticks = tick
		Sfx.play("BombTickHotA", 0.5, 1 + 0.25 * tick)
	end
end

local function startCharge(): boolean
	if charging or os.clock() < nextThrow or not throwKind() then
		return false
	end
	local char = player.Character
	if not char then
		return false
	end
	charging, chargeAt, ticks = true, os.clock(), 0
	windUp(player)
	Net.send("ThrowWindup", true)
	Sfx.play("SlapSwing", 0.45, 0.6)
	return true
end

local function release()
	if not charging then
		return
	end
	charging = false
	hidePreview()
	local kind = throwKind()
	local root = myRoot()
	letGo(player, if kind and root then F.THROW_CLIP_FROM else nil)
	if not kind or not root then
		Net.send("ThrowWindup", false)
		return
	end
	local held = os.clock() - chargeAt
	local tap = held < TH.TAP_TIME
	local pw = if tap then TH.TAP_POWER else power()
	local aim, _, autoPower = assist(root, camAim(root), kind, if InputController.device == "Touch" then nil else pw)
	if InputController.device == "Touch" and autoPower then
		pw = autoPower -- a phone throw takes the power for the distance
	end
	nextThrow = os.clock() + TH.COOLDOWN
	-- the bomb leaves the hand on the whip's frame (the clip's `hit`), not on the click: the body sells the throw
	task.delay(F.THROW_RELEASE_AT - F.THROW_CLIP_FROM, function()
		local r = myRoot()
		if not r or throwKind() ~= kind then
			return
		end
		Net.send("Throw", aim, pw)
		-- drawn at once; the server's flight takes over when it arrives
		local origin = r.Position + Vector3.new(0, TH.RELEASE_UP, 0) + aim * TH.RELEASE_FORWARD
		local vel = ThrowPhysics.launch(aim, pw) + r.AssemblyLinearVelocity * FLAT * TH.INHERIT
		local model = buildModel(ClientState.myId(), kind == "Tag")
		if model then
			drop("mine")
			flights["mine"] = {
				model = model,
				state = ThrowPhysics.new(origin, vel),
				owner = ClientState.myId(),
				bombId = player:GetAttribute("BombId"),
				tag = kind == "Tag",
				turn = CFrame.identity,
				predicted = true,
				bornAt = os.clock(),
			}
		end
		releaseBurst(origin, vel, pw)
		ImpactController.hitStop(ClientState.myId(), F.THROW_RELEASE_FREEZE) -- the release pose holds a beat
		Sfx.play("PassWhoosh", 1, 0.8 + 0.5 * pw)
		Sfx.play("SlapSwing", 0.7, 0.75 + 0.35 * pw)
		if not ImpactController.calm() then
			CameraController.punch(F.KICK_FOV * (0.6 + 0.9 * pw))
			FxController.shake(F.KICK_SHAKE * (0.3 + 0.5 * pw))
		end
	end)
end

local function onSwing(state: Enum.UserInputState): boolean
	if not ThrowController.on() then
		return false
	end
	if state == Enum.UserInputState.Begin then
		return startCharge()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if charging then
			release()
			return true
		end
	end
	return false
end

local function chargeStep()
	if not charging then
		return
	end
	local kind = throwKind()
	local root = myRoot()
	if not kind or not root then
		-- it was passed / defused / the round ended while winding up
		charging = false
		hidePreview()
		letGo(player, nil)
		Net.send("ThrowWindup", false)
		return
	end
	showPreview(root, kind)
	local char = player.Character
	if char then
		local sp = F.THROW_HOLD_SPEED
		SlapController.setSpeed(char, "ThrowHold", sp[1] + (sp[2] - sp[1]) * power())
	end
end

-- ── The server's beats ──────────────────────────────────────────────────────────────────────────────────────────
local function onBomb(p: any)
	if type(p) ~= "table" then
		return
	end
	local myId = ClientState.myId()
	if
		p.kind == "Throw"
		and type(p.flight) == "number"
		and typeof(p.pos) == "Vector3"
		and typeof(p.vel) == "Vector3"
	then
		local key = tostring(p.flight)
		local state = ThrowPhysics.new(p.pos, p.vel)
		fastForward(state, lagOf(p.at))
		local mine = flights["mine"]
		if p.who == myId and mine and mine.predicted then
			-- our own: keep the model we drew, now on the server's flight
			flights["mine"] = nil
			mine.predicted = false
			mine.state = state
			mine.bombId = p.bomb
			flights[key] = mine
			return
		end
		local model = buildModel(p.who, p.tag == true)
		if not model then
			return
		end
		flights[key] = {
			model = model,
			state = state,
			owner = p.who,
			bombId = p.bomb,
			tag = p.tag == true,
			turn = CFrame.identity,
			predicted = false,
			bornAt = os.clock(),
		}
		-- the thrower's arm cracks through (from the wind-up if we saw it, straight into the throw if not)
		local throwerHost = ClientState.byId(p.who)
		if throwerHost then
			letGo(throwerHost, F.THROW_REMOTE_FROM)
		end
		local pw = if type(p.power) == "number" then p.power else 0.5
		releaseBurst(p.pos, p.vel, pw)
		Sfx.at("PassWhoosh", p.pos, 0.9, 0.8 + 0.5 * pw)
	elseif p.kind == "Windup" and type(p.who) == "string" and p.who ~= myId then
		-- someone is winding up: you see it coming
		local host = ClientState.byId(p.who)
		if host then
			if p.on then
				windUp(host)
			else
				letGo(host, nil)
			end
		end
	elseif p.kind == "Bounce" and type(p.flight) == "number" and typeof(p.pos) == "Vector3" then
		local v = flights[tostring(p.flight)]
		if v and not v.reel and not v.knocked then
			v.state = ThrowPhysics.new(p.pos, if typeof(p.vel) == "Vector3" then p.vel else v.state.vel)
			fastForward(v.state, lagOf(p.at))
		end
		local speed = if typeof(p.vel) == "Vector3" then (p.vel :: Vector3).Magnitude else 20
		puff(p.pos - Vector3.new(0, TH.RADIUS * 0.8, 0), Color3.fromRGB(214, 206, 192), 2, 1.2 + speed * 0.02)
		Sfx.at("BombDrop", p.pos, math.clamp(speed / 40, 0.3, 1), 0.9 + math.random() * 0.25)
	elseif (p.kind == "Return" or p.kind == "Reject") and type(p.flight) == "number" then
		local key = tostring(p.flight)
		local v = flights[key]
		if not v then
			return
		end
		if p.kind == "Reject" and p.tag then
			-- a hand bomb batted out of the air: away it goes
			local from = rootOf(p.who)
			local away = if from then (v.state.pos - from.Position) * FLAT else -v.state.vel * FLAT
			v.state = ThrowPhysics.new(
				v.state.pos,
				(if away.Magnitude > 1e-3 then away.Unit else Vector3.zAxis) * TH.PARRY_SPEED
					+ Vector3.new(0, TH.PARRY_LIFT, 0)
			)
			v.knocked = os.clock()
			return
		end
		-- reeled back to its thrower on the fuse cord (a parry sends it back faster)
		v.reel = {
			from = v.model:GetPivot().Position,
			at = os.clock(),
			time = if p.boom then 0.08 elseif p.kind == "Reject" then TH.RETURN_TIME * 0.7 else TH.RETURN_TIME,
			to = if p.kind == "Reject" and type(p.from) == "string" then p.from else p.who,
			boom = p.boom == true,
		}
		if p.kind == "Return" and not p.boom then
			Sfx.at("PassWhoosh", v.state.pos, 0.6, 0.7)
		end
	elseif p.kind == "Fizzle" and type(p.flight) == "number" then
		local key = tostring(p.flight)
		local v = flights[key]
		local pos = if typeof(p.pos) == "Vector3" then p.pos elseif v then v.state.pos else nil
		if pos then
			puff(pos, Color3.fromRGB(150, 146, 156), 5, 1.8)
			Sfx.at("Defuse", pos, 0.5, 1.3)
		end
		drop(key)
	elseif p.kind == "Pass" and p.throw then
		-- it hit: the flight ends on the receiver's back (the landing beats are the pass's)
		local key = findBy(function(v)
			return v.bombId == p.bomb and not v.tag
		end)
		if key then
			drop(key)
		end
	elseif p.kind == "Stick" and p.throw then
		local key = findBy(function(v)
			return v.tag and v.owner == p.from
		end)
		if key then
			drop(key)
		end
	elseif p.kind == "Boom" and type(p.bomb) == "number" then
		local key = findBy(function(v)
			return v.bombId == p.bomb and v.reel == nil
		end)
		if key then
			drop(key)
		end
	end
end

function ThrowController.charging(): boolean
	return charging
end

function ThrowController.start()
	fxFolder = new("Folder", { Name = "FV_Throws", Parent = workspace }) :: Folder
	refreshCast()
	for i = 1, TH.PREVIEW_DOTS do
		dots[i] = new("Part", {
			Name = "AimDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.42 - 0.012 * i),
			Material = Enum.Material.Neon,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Parent = fxFolder,
		}) :: BasePart
	end
	landing = new("Part", {
		Name = "AimLanding",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 3.2, 3.2),
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Parent = fxFolder,
	}) :: BasePart
	outline = new("Highlight", {
		Name = "FV_AimTarget",
		FillTransparency = 0.85,
		FillColor = Color3.new(1, 1, 1),
		OutlineColor = Color3.new(1, 1, 1),
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Enabled = false,
		Parent = fxFolder,
	}) :: Highlight
	InputController.on("Swing", onSwing)
	RunService.RenderStepped:Connect(function(dt)
		chargeStep()
		step(dt)
	end)
	Net.listen("BombFx", onBomb)
	-- a round that ends takes every flight with it
	ClientState.changed("Phase", function()
		if not ClientState.runLive() then
			for key in pairs(flights) do
				drop(key)
			end
			if charging then
				charging = false
				hidePreview()
			end
		end
	end)
end

return ThrowController
