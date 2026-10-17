--!strict
-- Over-the-shoulder match camera + cursor rule: cursor locks ONLY while actively running/catching in a live run
-- (PC); unlocked everywhere else. Hold Alt to free it temporarily. Implements: F-MOVE-08.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local Settings = require(script.Parent.Parent.Settings)

local player = Players.LocalPlayer

local CameraController = {}

-- Centred behind the character like the reference match (the user's video, 2026-10-08); was over the right
-- shoulder (1.6, 0.8, 0). Y lifts the view a little so the character sits low in frame.
local MATCH_OFFSET = Vector3.new(0, 0.8, 0)
local MATCH_FOV = 72
local LOBBY_FOV = 70

CameraController.cinematic = false -- set by CinematicController while it owns the camera
CameraController.fovPunch = 0 -- additive, decays (feedback effects)
CameraController.uiOpen = 0 -- count of modal gameplay screens open (picker/chooser); cursor stays free
CameraController.follow = nil :: Humanoid? -- Brave run / Last Stand follow-cam (CinematicController); nil = none
-- Lobby spectating (LobbyHudController). Its own slot (2026-10-07): the follow-cam above is recomputed every frame,
-- and sharing one field made the two fight, flipping the camera between you and the target ("spectate spazzes").
CameraController.spectate = nil :: Humanoid?

local locked = false

local function wantLock(): boolean
	if CameraController.cinematic or CameraController.uiOpen > 0 or InputController.device ~= "KeyboardMouse" then
		return false
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
		return false
	end
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	return ClientState.activeInRun()
end

local function update(dt: number)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local inMatch = ClientState.role() ~= Types.Role.None
	-- Subject: a spectate target if one is set and alive, otherwise our own humanoid. Server-built characters can
	-- replace each other quickly, so never leave the camera on a destroyed rig.
	if cam and hum and not CameraController.cinematic then
		local follow = CameraController.follow
		if follow and not follow:IsDescendantOf(workspace) then
			CameraController.follow = nil
			follow = nil
		end
		local spec = CameraController.spectate
		if spec and not spec:IsDescendantOf(workspace) then
			spec = nil
		end
		local want: Humanoid = follow or spec or hum
		if cam.CameraSubject ~= want then
			cam.CameraSubject = want
		end
	end
	local lock = wantLock()
	if lock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	elseif locked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	locked = lock
	-- Mouse-locked (shift-lock style) play faces the camera for every role, so S backpedals and A/D strafe.
	MovementController.faceCamera = lock and ClientState.role() ~= Types.Role.None
	if hum then
		local target = if inMatch and not CameraController.cinematic then MATCH_OFFSET else Vector3.zero
		hum.CameraOffset = hum.CameraOffset:Lerp(target, math.clamp(dt * 8, 0, 1))
	end
	if cam and not CameraController.cinematic then
		CameraController.fovPunch *= math.exp(-dt * 6)
		local base = if inMatch then MATCH_FOV else LOBBY_FOV
		cam.FieldOfView = base + CameraController.fovPunch
	end
end

function CameraController.isLocked(): boolean
	return locked
end

function CameraController.punch(amount: number)
	-- Reduce motion (GDD §20.5) turns FOV punches off along with screen shake.
	if Settings.get("reduceMotion") then
		return
	end
	CameraController.fovPunch += amount
end

-- Put the camera behind the character, looking the way it faces (players are placed facing the far side).
function CameraController.snapBehind()
	local cam = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not root or CameraController.cinematic then
		return
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		return
	end
	look = look.Unit
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	cam.CFrame = CFrame.lookAt(focus - look * 13 + Vector3.new(0, 4.5, 0), focus + look * 6)
end

function CameraController.start()
	RunService:BindToRenderStep("CG_Camera", Enum.RenderPriority.Camera.Value + 1, update)
	-- Re-frame after every server teleport (match intro, each GET_READY, rescues). The attribute can arrive a
	-- frame before the new CFrame replicates, so wait briefly first.
	ClientState.myChanged("TeleportAt", function()
		task.delay(0.15, CameraController.snapBehind)
	end)
end

return CameraController
