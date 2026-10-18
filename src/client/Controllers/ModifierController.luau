--!strict
-- Round modifiers on the client (GDD §6.4). The round chip names the modifier (the INTRO headline is HudController's);
-- READ THE FACE needs nothing here (the bomb, HUD, audio and Carrier toolkit hide a masked bomb's time themselves).
--   LIGHTS OUT: the Yard fades to night (saved and restored at the next intermission), every live bomb becomes a
--   lamp in its stage colour, every Runner gets a soft glow, Bombers get red eye glints that fade in up close, and
--   the Safe Strips glow.
--   THE MOLE: the secret Mole's private beat ("YOU'RE THE MOLE"), the STRIKE button (Q / gamepad X / tap) with its
--   armed and retry states, and everyone's reveal beat (the headline plus a red flash on the Mole).
-- The chip and button are functional styling on the Theme panel (the UI pass restyles them; Asset Bible §6).
-- Implements: F-MOD-01 (chip), F-MOD-03, F-MOD-04 (client).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)

local MOD = Config.Modifiers
local B = Config.Bomb
local S = Config.Strings.Modifiers
local P = Theme.Palette
local Ph = Types.Phase
local new = Theme.new
local FLAT = Vector3.new(1, 0, 1)

local ModifierController = {}

local player = Players.LocalPlayer :: Player
local gs: Configuration
local chip: Frame
local chipLabel: TextLabel
local strikeHolder: Frame
local strikeLabel: TextLabel

-- ── Lights Out ──────────────────────────────────────────────────────────────────────────────────────────────────
local night = false
local saved: { [Instance]: { [string]: any } } = {}
local grade: ColorCorrectionEffect? = nil
local stripLights: { Instance } = {}
local lit: { [Instance]: boolean } = {} -- every light / glint this controller made (cleared with the night)

local function tween(obj: Instance, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(MOD.NIGHT_TWEEN, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), props)
		:Play()
end

local function remember(obj: Instance, props: { [string]: any })
	local s = {}
	for k in pairs(props) do
		s[k] = (obj :: any)[k]
	end
	saved[obj] = s
	tween(obj, props)
end

local function buildStripLights()
	local frame = gs:GetAttribute("FieldCFrame")
	local halfLen = gs:GetAttribute("FieldHalfLen")
	local halfW = gs:GetAttribute("FieldHalfWidth")
	if typeof(frame) ~= "CFrame" or type(halfLen) ~= "number" or type(halfW) ~= "number" then
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		local x = -halfW
		while x <= halfW do
			local part = new("Part", {
				Name = "FV_StripLight",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Transparency = 1,
				Size = Vector3.one * 0.2,
				CFrame = frame * CFrame.new(x, 3, -side * (halfLen + 3)), -- side +1 sits at local −Z (CarrierController)
				Parent = workspace,
			})
			new("PointLight", {
				Range = MOD.STRIP_LIGHT_RANGE,
				Brightness = MOD.STRIP_LIGHT_BRIGHTNESS,
				Color = P.Safe,
				Shadows = false,
				Parent = part,
			})
			table.insert(stripLights, part)
			x += MOD.STRIP_LIGHT_SPACING
		end
	end
end

local function nightOn()
	night = true
	remember(Lighting, MOD.NIGHT)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		remember(atmo, MOD.NIGHT_ATMOSPHERE)
	end
	local cc = new("ColorCorrectionEffect", { Name = "FV_Night", Parent = Lighting })
	grade = cc
	tween(cc, { TintColor = MOD.NIGHT_TINT, Saturation = MOD.NIGHT_SATURATION })
	buildStripLights()
end

local function nightOff()
	night = false
	for obj, props in pairs(saved) do
		if obj.Parent then
			tween(obj, props)
		end
	end
	table.clear(saved)
	local cc = grade
	if cc then
		tween(cc, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
		task.delay(MOD.NIGHT_TWEEN + 0.1, function()
			cc:Destroy()
		end)
		grade = nil
	end
	for _, part in ipairs(stripLights) do
		part:Destroy()
	end
	table.clear(stripLights)
	for inst in pairs(lit) do
		inst:Destroy()
	end
	table.clear(lit)
end

local function hosts(): { Instance }
	local out: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(out, p)
	end
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

-- A light this controller owns, made once per part (`name` tells them apart).
local function lightOn(part: BasePart, name: string): PointLight
	local l = part:FindFirstChild(name) :: PointLight?
	if not l then
		l = new("PointLight", { Name = name, Shadows = false, Parent = part }) :: PointLight
		lit[l :: PointLight] = true
	end
	return l :: PointLight
end

local function lightOff(part: Instance, name: string)
	local l = part:FindFirstChild(name)
	if l then
		lit[l] = nil
		l:Destroy()
	end
end

-- Two red glints on a Bomber's face, welded to the head.
local function eyesOf(head: BasePart): Model
	local eyes = head:FindFirstChild("FV_Eyes") :: Model?
	if eyes then
		return eyes
	end
	local m = new("Model", { Name = "FV_Eyes" }) :: Model
	for _, x in ipairs({ -0.22, 0.22 }) do
		local e = new("Part", {
			Name = "Glint",
			Size = Vector3.new(0.2, 0.09, 0.05),
			Material = Enum.Material.Neon,
			Color = P.Bomber,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			CFrame = head.CFrame * CFrame.new(x, 0.12, -head.Size.Z / 2 - 0.03),
			Parent = m,
		})
		new("WeldConstraint", { Part0 = head, Part1 = e, Parent = e })
	end
	m.Parent = head
	lit[m] = true
	return m
end

local function nightStep()
	local cam = workspace.CurrentCamera
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local eye = if mine then mine.Position elseif cam then cam.CFrame.Position else Vector3.zero
	local t = workspace:GetServerTimeNow()
	for _, host in ipairs(hosts()) do
		local char = characterOf(host)
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if root and head then
			local role = host:GetAttribute("Role")
			local carrying = host:GetAttribute("BombId") ~= nil
			-- the Runner's glow
			if role == "Runner" and host:GetAttribute("State") ~= "Tumbled" then
				local g = lightOn(root, "FV_Glow")
				g.Range = MOD.RUNNER_GLOW
				g.Brightness = MOD.RUNNER_GLOW_BRIGHTNESS
				g.Color = P.Porcelain
			else
				lightOff(root, "FV_Glow")
			end
			-- the bomb lamp, in the stage colour (a hidden READ THE FACE fuse reads LIT)
			if carrying then
				local at = host:GetAttribute("BombExplodeAt")
				local left = if type(at) == "number" then at - t else math.huge
				local stage = if left <= B.STAGE_CRITICAL
					then "CRITICAL"
					elseif left <= B.STAGE_HOT then "HOT"
					else "LIT"
				local l = lightOn(root, "FV_Lamp")
				l.Range = (MOD.LAMP :: any)[stage]
				l.Brightness = MOD.LAMP_BRIGHTNESS
				l.Color = Theme.stageColor(stage)
			else
				lightOff(root, "FV_Lamp")
			end
			-- the Bomber's eye glints, fading in within EYE_RANGE
			if role == "Bomber" and char ~= player.Character then
				local d = ((head.Position - eye) * FLAT).Magnitude
				local a = math.clamp((MOD.EYE_RANGE - d) / (MOD.EYE_RANGE * 0.3), 0, 1)
				for _, g in ipairs(eyesOf(head):GetChildren()) do
					if g:IsA("BasePart") then
						g.Transparency = 1 - a
					end
				end
			else
				local eyes = head:FindFirstChild("FV_Eyes")
				if eyes then
					lit[eyes] = nil
					eyes:Destroy()
				end
			end
		end
	end
end

-- ── The Mole ────────────────────────────────────────────────────────────────────────────────────────────────────
local isMole = false
local armedUntil = 0
local retryAt = 0

local function strike(): boolean
	if not isMole or not ClientState.runLive() or ClientState.role() ~= Types.Role.Runner then
		return false
	end
	Net.send("Strike")
	return true
end

local function revealFlash(who: string)
	local _, model = ClientState.byId(who)
	if not model then
		return
	end
	local h = new("Highlight", {
		FillColor = P.Bomber,
		OutlineColor = P.Paper,
		FillTransparency = 0.35,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Parent = model,
	})
	TweenService:Create(h, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	task.delay(2.1, function()
		h:Destroy()
	end)
end

local function strikeStep(t: number)
	local show = isMole and ClientState.runLive() and ClientState.role() == Types.Role.Runner
	strikeHolder.Visible = show
	if not show then
		return
	end
	if t < armedUntil then
		strikeLabel.Text = S.StrikeArmed
		strikeLabel.TextColor3 = P.Bomber:Lerp(P.Paper, 0.5 + 0.5 * math.sin(t * 16))
	elseif t < retryAt then
		strikeLabel.Text = S.StrikeWait:format(math.ceil(retryAt - t))
		strikeLabel.TextColor3 = P.Ash
	else
		strikeLabel.Text = S.Strike
		strikeLabel.TextColor3 = P.Paper
	end
end

-- ── Per frame ───────────────────────────────────────────────────────────────────────────────────────────────────
local function step()
	local m = gs:GetAttribute("Modifier")
	local modifier = if type(m) == "string" then m else ""
	local phase = ClientState.phase()
	local inRound = phase ~= Ph.Intermission and phase ~= Ph.Results and phase ~= Ph.Boot and phase ~= ""
	local text = (S :: any)[modifier]
	chip.Visible = inRound and type(text) == "table"
	if type(text) == "table" then
		chipLabel.Text = text.Name
	end
	if (modifier == "LightsOut") ~= night then
		if night then
			nightOff()
		else
			nightOn()
		end
	end
	if night then
		nightStep()
	end
	if modifier ~= "Mole" then
		isMole = false
	end
	strikeStep(workspace:GetServerTimeNow())
end

function ModifierController.start()
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local gui = new("ScreenGui", {
		Name = "FV_Modifier",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- the round chip: under the team counter (top-right), clear of the centre headlines
	local face = Theme.panel(gui, {
		Name = "ModifierChip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 176),
		Size = UDim2.fromOffset(210, 38),
		color = P.Ink2,
		border = P.Gold,
		border2 = P.Ink,
		radius = 999,
	})
	chip = face.Parent :: Frame
	chipLabel = Theme.display(face, { Size = UDim2.fromScale(1, 1), TextSize = 20, color = P.Gold })
	chip.Visible = false
	-- the Mole's STRIKE button (right side, above the thumb zone)
	local sface = Theme.panel(gui, {
		Name = "StrikeButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.56, 0),
		Size = UDim2.fromOffset(190, 56),
		color = P.Ink2,
		border = P.Bomber,
		border2 = P.Ink,
		radius = 14,
	})
	strikeHolder = sface.Parent :: Frame
	strikeLabel = Theme.display(sface, { Size = UDim2.fromScale(1, 1), TextSize = 24 })
	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		Parent = strikeHolder,
	}) :: TextButton
	hit.Activated:Connect(function()
		strike()
	end)
	strikeHolder.Visible = false
	InputController.on("Ability", function(state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin then
			return false
		end
		return strike()
	end)
	Net.listen("ModFx", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.kind == "Mole" then
			isMole = true
			armedUntil, retryAt = 0, 0
			HudController.flash(S.YouMole, S.YouMoleSub, P.Bomber, Config.Round.INTRO) -- their whole INTRO
			Sfx.play("Stamp", 0.8, 0.8)
		elseif p.kind == "Armed" then
			armedUntil = if type(p.untilAt) == "number" then p.untilAt else 0
			retryAt = if type(p.nextAt) == "number" then p.nextAt else 0
			Sfx.play("BombClamp", 0.7, 0.8)
		end
	end)
	Net.listen("RoundFx", function(p)
		if type(p) ~= "table" or p.kind ~= "MoleReveal" or type(p.who) ~= "string" then
			return
		end
		if p.who == ClientState.myId() then
			isMole = false
		end
		local _, model = ClientState.byId(p.who)
		HudController.flash(S.Reveal, if model then model.Name else "", P.Bomber, 2.2)
		revealFlash(p.who)
		Sfx.play("CrowdGasp", 0.7, 1)
	end)
	RunService.RenderStepped:Connect(step)
end

return ModifierController
