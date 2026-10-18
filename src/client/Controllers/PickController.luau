--!strict
-- The pick camera (docs/VIDEO2_NOTES.md §2; the reference video's "who's it?" sequence): when INTRO starts and the
-- server has picked the starting Bombers (RoundFx {kind="Intro", bombers}), the camera leaves the player:
--   1. black letterbox bars slide in, the HUD steps aside, a big countdown runs to GO;
--   2. a viewfinder (four white corner brackets) sweeps over the waiting crowd, hopping from player to player with a
--      tick each time;
--   3. it locks onto each starting Bomber in turn: a close shot, their body glows a satisfying gold (a Highlight) with a
--      white rim, their name drops in huge red letters with "BOMBER!" under it, and a sting hits;
--   4. the camera hands back behind the player as READY starts (the gold glow fades over the next second).
-- Same logic as before (the server still picks); only the presentation. Reduce motion skips the sweep.
-- Studio preview: the player attribute FV_PreviewPick.
-- Implements: docs/VIDEO2_NOTES.md §2, GDD §5.1 (INTRO presentation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local CameraController = require(script.Parent.CameraController)

local new = Theme.new
local player = Players.LocalPlayer

local PickController = {}

local GOLD = Color3.fromRGB(255, 206, 40)
local NAME_RED = Color3.fromRGB(240, 52, 44)
local BAR = 0.11 -- letterbox bar height, fraction of the screen
local SWEEP_FRAC = 0.4 -- the share of INTRO spent sweeping the crowd (the rest locks onto the Bombers)
local HOP = 0.22 -- seconds per viewfinder hop
local MAX_LOCKS = 3 -- at most this many Bombers get their own shot
local LOCK_DIST = 6.5 -- studs from the Bomber's chest for the lock-on shot
local HANDBACK_FRAMES = 4 -- frames the snap-behind is re-applied after the sequence
local PUSH_SPEED = 0.7 -- studs / s of slow push-in while a shot holds
local GLOW_FADE = 1.2 -- seconds the gold glow lingers into READY
local HIDE_GUIS =
	{ "FV_Hud", "FV_Callouts", "FV_Carrier", "FV_Progress", "FV_Dock", "FV_Quests", "FV_Mega", "FV_Mobile" }

local gui: ScreenGui
local running = 0 -- a token: a newer INTRO cancels the old sequence
local preview = false -- a Studio preview runs outside INTRO

local function modelOf(id: string): Model?
	local _, m = ClientState.byId(id)
	return m
end

local function rootOf(m: Model?): BasePart?
	return m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The four white corner brackets of the viewfinder, centred on screen.
local function viewfinder(parent: Instance): Frame
	local f = new("Frame", {
		Name = "Viewfinder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	local L, T = 46, 5
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local ax, ay = c[1], c[2]
		new("Frame", {
			AnchorPoint = Vector2.new(ax, ay),
			Position = UDim2.fromScale(ax, ay),
			Size = UDim2.fromOffset(L, T),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = f,
		})
		new("Frame", {
			AnchorPoint = Vector2.new(ax, ay),
			Position = UDim2.fromScale(ax, ay),
			Size = UDim2.fromOffset(T, L),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = f,
		})
	end
	return f
end

local function setHud(on: boolean)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	for _, n in ipairs(HIDE_GUIS) do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") then
			if on then
				local was = g:GetAttribute("FV_PickWasOn")
				if was ~= nil then
					g.Enabled = was
					g:SetAttribute("FV_PickWasOn", nil)
				end
			elseif g:GetAttribute("FV_PickWasOn") == nil then
				g:SetAttribute("FV_PickWasOn", g.Enabled)
				g.Enabled = false
			end
		end
	end
end

-- Ease the camera onto `goal()` over `time` (recomputed each frame, so it follows a moving target; a token check
-- aborts it when a newer sequence starts).
local function moveCam(goal: () -> CFrame, time: number, token: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local from = cam.CFrame
	local t0 = os.clock()
	while os.clock() - t0 < time and running == token do
		local a = math.clamp((os.clock() - t0) / time, 0, 1)
		local e = 1 - (1 - a) ^ 3
		cam.CameraType = Enum.CameraType.Scriptable -- hold it: anything resetting the camera mid-sequence loses
		cam.CFrame = from:Lerp(goal(), e)
		RunService.RenderStepped:Wait()
	end
	if running == token then
		cam.CFrame = goal()
	end
end

-- A shot of `r` from in front: `dist` studs out, `up` above the chest, looking at the chest.
local function shotOf(r: BasePart, dist: number, up: number): () -> CFrame
	return function(): CFrame
		local at = r.Position + Vector3.new(0, 1.4, 0)
		local fwd = r.CFrame.LookVector * Vector3.new(1, 0, 1)
		fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else Vector3.zAxis
		return CFrame.lookAt(at + fwd * dist + Vector3.new(0, up, 0), at + Vector3.new(0, 0.3, 0))
	end
end

-- Give the camera back behind the player. The Custom camera keeps the angle it was handed, so the snap behind runs
-- right after Roblox's camera update for a few frames until it takes.
local function handBack()
	CameraController.cinematic = false
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	local frames = 0
	RunService:BindToRenderStep("FV_PickHandBack", Enum.RenderPriority.Camera.Value + 2, function()
		frames += 1
		CameraController.snapBehind()
		if frames >= HANDBACK_FRAMES then
			RunService:UnbindFromRenderStep("FV_PickHandBack")
		end
	end)
end

local function glow(m: Model): Highlight
	local h = new("Highlight", {
		Name = "FV_PickGlow",
		Adornee = m,
		FillColor = GOLD,
		FillTransparency = 0.3,
		OutlineColor = Color3.new(1, 1, 1),
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = m,
	}) :: Highlight
	return h
end

local function run(bombers: { string })
	running += 1
	local token = running
	local total = Config.Round.INTRO
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	CameraController.cinematic = true
	cam.CameraType = Enum.CameraType.Scriptable
	setHud(false)
	for _, c in ipairs(gui:GetChildren()) do
		c:Destroy()
	end
	gui.Enabled = true
	-- letterbox + countdown
	local top = new("Frame", {
		Size = UDim2.new(1, 0, BAR, 0),
		Position = UDim2.fromScale(0, -BAR),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = gui,
	})
	local bottom = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, BAR, 0),
		Position = UDim2.fromScale(0, 1 + BAR),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = gui,
	})
	local bars = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(top, bars, { Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(bottom, bars, { Position = UDim2.fromScale(0, 1) }):Play()
	local count = Widgets.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, BAR, 14),
		Size = UDim2.fromOffset(200, 70),
		TextSize = 64,
		font = Theme.Font.Display,
		stroke = 4,
		Text = "",
		ZIndex = 6,
	})
	local t0 = os.clock()
	task.spawn(function()
		local shown = -1
		while running == token and gui.Enabled do
			local left = math.max(1, math.ceil(total - (os.clock() - t0)))
			if left ~= shown then
				shown = left
				count.Text = tostring(left)
				local sc = count:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = count })
				sc.Scale = 1.35
				TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			task.wait(0.05)
		end
	end)

	-- 2. the sweep over the crowd (the Runners waiting in the strip)
	local crowd: { BasePart } = {}
	for _, e in ipairs(ClientState.participants()) do
		local r = rootOf(e.model)
		if r and not table.find(bombers, e.host:GetAttribute("ParticipantId") :: any) then
			table.insert(crowd, r)
		end
	end
	local sweepTime = if Widgets.reduced() or #crowd == 0 then 0 else total * SWEEP_FRAC
	if sweepTime > 0 then
		local vf = viewfinder(gui)
		local hops = math.max(1, math.floor(sweepTime / HOP))
		for i = 1, hops do
			if running ~= token then
				return
			end
			local r = crowd[math.random(1, #crowd)]
			local goal = shotOf(r, 9, 4)
			Sfx.play("UiTab", 0.6, 0.9 + i * 0.03)
			vf.Size = UDim2.fromOffset(340, 340)
			TweenService
				:Create(vf, TweenInfo.new(HOP * 0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(260, 300) })
				:Play()
			moveCam(goal, HOP, token)
		end
		vf:Destroy()
	end

	-- 3. lock onto each starting Bomber
	local locks = {}
	for _, id in ipairs(bombers) do
		if #locks >= MAX_LOCKS then
			break
		end
		local m = modelOf(id)
		if m and rootOf(m) then
			table.insert(locks, { id = id, model = m })
		end
	end
	local lockTime = math.max(0.6, (total - (os.clock() - t0)) / math.max(1, #locks))
	local glows: { Highlight } = {}
	for _, l in ipairs(locks) do
		if running ~= token then
			break
		end
		local r = rootOf(l.model) :: BasePart
		local push = 0 -- the slow push-in while the shot holds
		local base = shotOf(r, LOCK_DIST, 1)
		local goal = function(): CFrame
			return base() * CFrame.new(0, 0, -push)
		end
		table.insert(glows, glow(l.model))
		Sfx.play("Stamp", 0.9, 0.85)
		Sfx.play("StingerBombers", 0.5)
		local host = ClientState.byId(l.id)
		local name = if host and host:IsA("Player")
			then host.DisplayName
			else (host and host:GetAttribute("DisplayName") :: string?) or l.model.Name
		local card = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromOffset(900, 160),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = gui,
		})
		local nameL = Widgets.label(card, {
			Size = UDim2.new(1, 0, 0, 110),
			TextSize = 96,
			font = Theme.Font.Display,
			stroke = 6,
			color = NAME_RED,
			Text = string.upper(name),
			ZIndex = 7,
		})
		nameL.TextScaled = true
		Widgets.label(card, {
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 34,
			font = Theme.Font.Display,
			stroke = 3,
			Text = Config.Strings.Ui.PickBomber,
			ZIndex = 7,
		})
		Widgets.springIn(card, 0.3)
		moveCam(goal, math.min(0.45, lockTime * 0.4), token)
		local hold = lockTime - math.min(0.45, lockTime * 0.4)
		local holdEnd = os.clock() + hold
		while os.clock() < holdEnd and running == token do
			local c = workspace.CurrentCamera
			c.CameraType = Enum.CameraType.Scriptable
			push += PUSH_SPEED * RunService.RenderStepped:Wait()
			c.CFrame = goal()
		end
		card:Destroy()
	end

	-- 4. hand the camera back
	if running ~= token then
		return
	end
	gui.Enabled = false
	preview = false
	setHud(true)
	handBack()
	for _, h in ipairs(glows) do
		TweenService:Create(h, TweenInfo.new(GLOW_FADE), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		task.delay(GLOW_FADE + 0.1, function()
			h:Destroy()
		end)
	end
end

function PickController.start()
	gui = new("ScreenGui", {
		Name = "FV_Pick",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 40,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.listen("RoundFx", function(p)
		if type(p) == "table" and p.kind == "Intro" and type(p.bombers) == "table" then
			task.spawn(run, p.bombers)
		end
	end)
	-- Studio preview: the player's FV_PreviewPick attribute plays the sequence on two random bots
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("FV_PreviewPick"):Connect(function()
			if not player:GetAttribute("FV_PreviewPick") then
				return
			end
			local ids = {}
			for _, e in ipairs(ClientState.participants()) do
				local id = e.host:GetAttribute("ParticipantId")
				if type(id) == "string" and e.host ~= player and #ids < 2 then
					table.insert(ids, id)
				end
			end
			preview = true
			task.spawn(run, ids)
		end)
	end
	-- safety: never leave the camera stuck if INTRO is cut short (a skip, a reset)
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if gui.Enabled and not preview and ClientState.phase() ~= Types.Phase.Intro then
			running += 1
			gui.Enabled = false
			setHud(true)
			handBack()
		end
	end)
end

return PickController
