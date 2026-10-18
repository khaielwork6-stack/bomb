--!strict
-- MOMENT OF THE ROUND (GDD §10.5): at RESULTS, the round's best moment (MomentService, sent with the results) replays
-- for 4 s in a corner card with the featured player's name, looping while the results show. Every participant in the
-- shot is a puppet — a clone of their character in a ViewportFrame's WorldModel, run by the same Locomotion layer as
-- the real rigs — moved along the server's highlight-buffer track; Carriers wear a still bomb, tumbled bodies lie
-- over. Plain functional layout on the Skin kit panel (the partner restyles the card in the UI pass).
-- Implements: F-FEEL-06 (the replay card).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Locomotion = require(ReplicatedStorage.Shared.Locomotion)
local ClientState = require(script.Parent.Parent.ClientState)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local BombController = require(script.Parent.BombController)

local F = Config.Feel
local S = Config.Strings.Moment
local P = Theme.Palette
local new = Theme.new

local MomentController = {}

local CARD_W, CARD_H = 340, 250
local HEAD = 58 -- the title + name rows above the view
local PAD = 10
local MARGIN = 16 -- from the screen corner
local REF_H = 720 -- screens shorter than this scale the card down
local FLAG_BOMB, FLAG_TUMBLED = 1, 2

type Puppet = {
	model: Model,
	root: BasePart,
	torso: BasePart?,
	loco: any,
	skin: string?,
	bomb: Model?,
	pos: { Vector3 },
	yaw: { number },
	flags: { number },
	drop: number, -- root height above the feet
	last: Vector3?,
}

-- A still copy of a character for the WorldModel: no scripts, sounds, GUIs, effects or bomb; joints whole again.
local function puppetOf(model: Model): Model?
	local was = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(model.Clone, model)
	model.Archivable = was
	if not ok or not copy then
		return nil
	end
	local c = copy :: Model
	for _, child in ipairs(c:GetChildren()) do
		if child:IsA("Model") then
			child:Destroy() -- FV_Bomb and other client dressing
		end
	end
	for _, d in ipairs(c:GetDescendants()) do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter")
			or d:IsA("Trail")
			or d:IsA("Beam")
			or d:IsA("Light")
			or d:IsA("Highlight")
			or d:IsA("ForceField")
			or d:IsA("BallSocketConstraint")
		then
			d:Destroy()
		elseif d:IsA("Motor6D") then
			d.Enabled = true
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return c
end

local function lerpAngle(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * k
end

local function validTrack(a: any, frames: number): boolean
	return type(a) == "table"
		and type(a.id) == "string"
		and type(a.pos) == "table"
		and type(a.yaw) == "table"
		and type(a.flags) == "table"
		and #a.pos == frames
		and #a.yaw == frames
		and #a.flags == frames
end

local function caption(m: any): string
	local kind = (S :: any)[m.kind]
	if type(kind) ~= "string" then
		return m.name
	end
	if m.kind == "Chain" then
		kind = string.format(kind, tonumber(m.n) or F.MOMENT_CHAIN_MIN)
	end
	return `{m.name} · {kind}`
end

-- Show the card in `parent` (the results ScreenGui). Returns the function that takes it down again.
function MomentController.show(parent: Instance, m: any): () -> ()
	if type(m) ~= "table" or type(m.actors) ~= "table" or type(m.name) ~= "string" or type(m.id) ~= "string" then
		return function() end
	end
	local hz = tonumber(m.hz) or F.MOMENT_HZ
	local first = m.actors[1]
	local frames = if type(first) == "table" and type(first.pos) == "table" then #first.pos else 0
	if frames < 2 then
		return function() end
	end
	local face = Theme.panel(parent, {
		Name = "Moment",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		border = P.Gold,
		border2 = P.Ember,
	})
	local holder = face.Parent :: Frame
	Screen.fit(holder, function(v)
		return math.min(1, v.Y / REF_H)
	end)
	Widgets.springIn(holder)
	Widgets.label(face, {
		Name = "Title",
		Position = UDim2.fromOffset(PAD, 6),
		Size = UDim2.new(1, -2 * PAD, 0, 26),
		TextSize = 22,
		font = Theme.Font.Display,
		color = P.Gold,
		Text = S.Title,
		ZIndex = 4,
	})
	local who = Widgets.label(face, {
		Name = "Who",
		Position = UDim2.fromOffset(PAD, 32),
		Size = UDim2.new(1, -2 * PAD, 0, 22),
		TextSize = 17,
		Text = caption(m),
		ZIndex = 4,
	})
	who.TextTruncate = Enum.TextTruncate.AtEnd
	local vf = new("ViewportFrame", {
		Name = "Replay",
		Position = UDim2.fromOffset(PAD, HEAD),
		Size = UDim2.new(1, -2 * PAD, 1, -HEAD - PAD),
		BackgroundColor3 = P.Ink2,
		BackgroundTransparency = 0,
		Ambient = P.Ash,
		LightColor = P.Paper,
		LightDirection = Vector3.new(-0.5, -1, -0.6),
		ZIndex = 4,
		Parent = face,
	}) :: ViewportFrame
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = vf })
	local world = new("WorldModel", { Parent = vf }) :: WorldModel
	local cam = new("Camera", { FieldOfView = F.MOMENT_CAM_FOV, Parent = vf }) :: Camera
	vf.CurrentCamera = cam

	-- The puppets (participants who left since are skipped).
	local puppets: { Puppet } = {}
	local subject: Puppet? = nil
	for _, a in ipairs(m.actors) do
		if validTrack(a, frames) then
			local host, model = ClientState.byId(a.id)
			local copy = if model then puppetOf(model) else nil
			local root = copy and copy:FindFirstChild("HumanoidRootPart") :: BasePart?
			if copy and root then
				local lowest = math.huge
				for _, d in ipairs(copy:GetDescendants()) do
					if d:IsA("BasePart") and d ~= root then
						lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
					end
				end
				root.Anchored = true
				copy.Parent = world
				local hum = copy:FindFirstChildOfClass("Humanoid")
				local skin = host and host:GetAttribute("Eq_BombSkin")
				local pup: Puppet = {
					model = copy,
					root = root,
					torso = copy:FindFirstChild("Torso") :: BasePart?,
					loco = if hum then Locomotion.new(hum) else nil,
					skin = if type(skin) == "string" then skin else nil,
					bomb = nil,
					pos = a.pos,
					yaw = a.yaw,
					flags = a.flags,
					drop = if lowest < math.huge then root.Position.Y - lowest else root.Size.Y * 1.5,
					last = nil,
				}
				table.insert(puppets, pup)
				if a.id == m.id then
					subject = pup
				end
			end
		end
	end
	local focus = subject or puppets[1]
	if focus then
		-- a floor under the featured participant's lowest point, so the shot isn't floating in the void
		local low = math.huge
		for _, p in ipairs(focus.pos) do
			low = math.min(low, p.Y)
		end
		new("Part", {
			Name = "Floor",
			Anchored = true,
			Size = Vector3.new(F.MOMENT_RADIUS * 4, 1, F.MOMENT_RADIUS * 4),
			CFrame = CFrame.new(focus.pos[1].X, low - focus.drop - 0.5, focus.pos[1].Z),
			Color = P.Smoke,
			Material = Enum.Material.Concrete,
			Parent = world,
		})
	end

	local dur = (frames - 1) / hz
	local clock = 0
	local camAt: Vector3? = nil
	local function step(dt: number)
		clock += dt
		if clock > dur + F.MOMENT_GAP then
			clock = 0
			camAt = nil
			for _, pup in ipairs(puppets) do
				pup.last = nil
			end
		end
		local fi = math.clamp(clock, 0, dur) * hz + 1
		local i0 = math.min(math.floor(fi), frames - 1)
		local k = fi - i0
		for _, pup in ipairs(puppets) do
			local pos = pup.pos[i0]:Lerp(pup.pos[i0 + 1], k)
			local yaw = lerpAngle(pup.yaw[i0], pup.yaw[i0 + 1], k)
			local flags = pup.flags[if k < 0.5 then i0 else i0 + 1]
			local tumbled = flags >= FLAG_TUMBLED
			local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
			if tumbled then
				local lie = pup.drop - (if pup.torso then pup.torso.Size.Z / 2 else 0)
				cf = CFrame.new(0, -lie, 0) * cf * CFrame.Angles(math.rad(-F.MOMENT_TUMBLE_TILT), 0, 0)
			end
			pup.root.CFrame = cf
			-- the legs follow the real ground speed (Locomotion), in the replay's time
			local moved = if pup.last and dt > 0 then (pos - pup.last :: Vector3) * Vector3.new(1, 0, 1) / dt else nil
			pup.last = pos
			if pup.loco then
				local v = moved or Vector3.zero
				local speed = if clock <= dur then v.Magnitude else 0
				local fwd = if speed > 0.1 then v.Unit:Dot(cf.LookVector) else 1
				pcall(Locomotion.update, pup.loco, dt, speed, speed > 0.1, true, tumbled, 1, fwd)
			end
			local carrying = flags % 2 == FLAG_BOMB
			if carrying and not pup.bomb and pup.torso then
				local ok, b = pcall(BombController.dummy, pup.torso, pup.skin)
				pup.bomb = if ok then b else nil
			elseif not carrying and pup.bomb then
				pup.bomb:Destroy()
				pup.bomb = nil
			end
		end
		if focus then
			local target = focus.root.Position
			local a = 1 - math.exp(-F.MOMENT_CAM_SMOOTH * dt)
			camAt = if camAt then (camAt :: Vector3):Lerp(target, a) else target
			cam.CFrame = CFrame.lookAt(camAt :: Vector3 + F.MOMENT_CAM_OFFSET, camAt :: Vector3)
		end
	end
	step(0)
	local conn = RunService.RenderStepped:Connect(step)

	local done = false
	return function()
		if done then
			return
		end
		done = true
		conn:Disconnect()
		for _, pup in ipairs(puppets) do
			if pup.loco then
				pcall(Locomotion.destroy, pup.loco)
			end
		end
		Widgets.springOut(holder, function()
			holder:Destroy()
		end)
	end
end

return MomentController
