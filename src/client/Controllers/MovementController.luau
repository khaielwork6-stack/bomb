--!strict
-- Momentum movement for the local character using the shared MovementCore (same math as bots).
-- Hooks the default PlayerModule ControlModule's moveFunction (keeps its keyboard/gamepad/touch thumbstick input),
-- then drives Humanoid.WalkSpeed + Humanoid:Move each frame. Implements: F-MOVE-03..06, F-MOVE-08 (facing).
-- Omnimovement (2026-10-07): the body's facing comes from MovementCore (`state.facing`), not the Humanoid's
-- AutoRotate. While you move it faces the camera: W runs, A / D strafe still facing ahead, S walks backward at a
-- slow pace that builds up (PC keys, gamepad and the touch thumbstick alike, all camera-relative). Standing still
-- it keeps its facing. A swing / throw turns it to the aim for a moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementCore = require(ReplicatedStorage.Shared.MovementCore)
local Locomotion = require(ReplicatedStorage.Shared.Locomotion)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local InputController = require(script.Parent.InputController)

local player = Players.LocalPlayer

local MovementController = {
	-- (kind, side?) local feedback: "Dash" | "HardStop" | "Slide" | "Dive" | "Land"; side: "Left" / "Right" / "Back"
	Tech = Signal.new(),
}

local M = Config.Movement

local state = MovementCore.newState()
local params = MovementCore.defaultParams()
local rawMove = Vector3.zero
local rawRelative = true
local hooked = false
local loco: Locomotion.Loco? = nil -- this character's run / idle / brake animation layer (replicates)
MovementController.faceCamera = false -- set by CameraController (mouse-locked: swings and throws aim the camera way)

local faceAim: Vector3? = nil -- a swing / throw holds the body on its aim until faceAimUntil
local faceAimUntil = 0
local lastLook: Vector3? = nil -- the facing we gave the root last frame (an outside turn, e.g. a teleport, is adopted)

-- Slopes and landing (2026-10-08 movement polish).
local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude
floorRay.IgnoreWater = true
local slopeMult = 1 -- eased speed multiplier from the incline under the feet (Config SLOPE_*)
local airT = 0 -- seconds off the ground
local landingUntil = 0
local frameSpeed = 0 -- last frame's average MovementCore speed × slope (what drove the Humanoid)

-- Head look (reference video): the camera's look relative to the body, deg (+ yaw = to the body's left, + pitch =
-- up). PoseController turns our own head from it every frame; others get it via the server (Net "Look").
local lookYaw, lookPitch = 0, 0
local sentYaw, sentPitch, sendAcc = 0, 0, 0

function MovementController.state()
	return state
end

-- Turn the body to `dir` at once and hold it there for `seconds` (a swing or a throw reads toward its aim even
-- while running another way); then it eases back to its movement facing.
function MovementController.faceFor(dir: Vector3, seconds: number)
	local f = MovementCore.flat(dir)
	if f == Vector3.zero then
		return
	end
	faceAim = f
	faceAimUntil = os.clock() + seconds
	state.facing = f
end

local MOVE_INPUT_MIN = 0.1

local function worldInput(): Vector3
	local mv = rawMove
	if mv.Magnitude < 0.05 then
		return Vector3.zero
	end
	if not rawRelative then
		return mv
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return mv
	end
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	local right = cam.CFrame.RightVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = cam.CFrame.UpVector * Vector3.new(1, 0, 1)
	end
	local dir = right.Unit * mv.X + look.Unit * -mv.Z
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	return dir
end

-- Is the player steering right now? (drives Dash availability and the Dash slot's dimmed look)
function MovementController.hasMoveInput(): boolean
	return worldInput().Magnitude >= MOVE_INPUT_MIN
end

local function readParams()
	local role = ClientState.role()
	params.lobby = role == Types.Role.None
	params.speedMult = player:GetAttribute("SpeedMult") or 1
	params.accelMult = player:GetAttribute("MoveAccelMult") or 1
	params.decelMult = player:GetAttribute("MoveDecelMult") or 1
	params.turnMult = player:GetAttribute("MoveTurnMult") or 1
	params.dashMult = player:GetAttribute("MoveDashMult") or 1
	MovementCore.applyProfile(params, role) -- Runner / Catcher / Lobby profile (Config.Movement.Profiles)
end

-- Ground speed multiplier for the incline under the feet along the way we move (uphill slower, downhill a little
-- faster; Config SLOPE_*). Flat ground, walls and the air give 1.
local function slopeFactor(root: BasePart, hum: Humanoid, heading: Vector3): number
	if hum.FloorMaterial == Enum.Material.Air or (M.SLOPE_UPHILL_LOSS == 0 and M.SLOPE_DOWNHILL_GAIN == 0) then
		return 1
	end
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), floorRay)
	if not hit then
		return 1
	end
	local angle = math.deg(math.acos(math.clamp(hit.Normal.Y, -1, 1)))
	if angle < M.SLOPE_MIN_ANGLE or angle > M.SLOPE_MAX_ANGLE then
		return 1
	end
	-- The normal's flat part points downhill; + along it = moving downhill.
	local k = heading:Dot(MovementCore.flat(hit.Normal)) * math.sin(math.rad(angle))
	return if k > 0 then 1 + k * M.SLOPE_DOWNHILL_GAIN else 1 + k * M.SLOPE_UPHILL_LOSS
end

-- The movement state right now, one name (debug overlay, reports): the gameplay states that take the body away
-- first, then the air, then MovementCore's own state.
function MovementController.stateName(): string
	if player:GetAttribute("Locked") == true or player:GetAttribute("InputLocked") == true then
		return "MovementLocked"
	end
	local st = ClientState.state()
	if st == Types.State.Downed then
		return "Caught"
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if st == Types.State.Tumbled or (hum and hum.PlatformStand) then
		return "Ragdolled"
	end
	if airT > 0.12 then
		return "Falling"
	end
	if os.clock() < landingUntil then
		return "Landing"
	end
	return state.mode
end

-- This character's head look right now (deg): yaw (+ = left of the body), pitch (+ = up).
function MovementController.lookAngles(): (number, number)
	return lookYaw, lookPitch
end

-- Debug readout: the speed the Humanoid is driven at, and the slope multiplier in it.
function MovementController.debugInfo(): (number, number)
	return frameSpeed, slopeMult
end

local function canMove(): boolean
	if player:GetAttribute("Locked") == true or player:GetAttribute("InputLocked") == true then
		return false
	end
	local st = ClientState.state()
	return st ~= Types.State.Downed and st ~= Types.State.Tumbled and st ~= Types.State.Spectator
end

-- Outside a round only Dash works (Chase Game rule, kept: no Slide / Stop in the lobby, every device).
local function inLobby(): boolean
	return ClientState.role() == Types.Role.None
end

-- Can we use techniques right now? (live run, or anywhere in the lobby for practice)
local function techAllowed(): boolean
	if not canMove() then
		return false
	end
	if ClientState.role() == Types.Role.None then
		return true
	end
	return ClientState.activeInRun()
end

local function step(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end
	readParams()
	if not hooked then
		-- Fallback when the moveFunction hook isn't live: the default controls already called Humanoid:Move
		-- this frame (RenderPriority.Input); read their world-space intent before we overwrite it.
		rawMove = hum.MoveDirection
		rawRelative = false
	end
	local movable = canMove()
	local input = if movable then worldInput() else Vector3.zero
	if not movable then
		-- Run over, caught, ragdolled, stunned: every technique ends at once and input is off, so momentum brakes
		-- out naturally (and the stop animation plays) until the server anchors us once we're still
		-- (Characters.softLock). Nothing dashes on under a state that took the body away.
		MovementCore.cancelTechniques(state)
		if root.Anchored then
			state.speed = 0
		end
	end
	-- Something else turned the body (a teleport, a seat, the end of a ragdoll): adopt its facing.
	local rootLook = MovementCore.flat(root.CFrame.LookVector)
	if rootLook ~= Vector3.zero and (lastLook == nil or rootLook:Dot(lastLook) < 0.9) then
		state.facing = rootLook
		if state.speed < 0.5 then
			state.heading = rootLook
		end
	end
	-- Omnimovement: the camera's look is the way the body faces while it moves (and what "back" is relative to).
	local cam = workspace.CurrentCamera
	local speed, heading, avgSpeed =
		MovementCore.step(state, input, dt, params, if cam then cam.CFrame.LookVector else nil)
	-- Landing: a real fall (LAND_MIN_AIR) plays the landing pose; short hops and steps don't.
	if hum.FloorMaterial == Enum.Material.Air and not root.Anchored and not hum.PlatformStand then
		airT += dt
	else
		if airT >= M.LAND_MIN_AIR and not root.Anchored then
			landingUntil = os.clock() + 0.25
			MovementController.Tech:Fire("Land")
		end
		airT = 0
	end
	if faceAim and os.clock() < faceAimUntil then
		state.facing = faceAim
	else
		faceAim = nil
		-- Cursor locked (live run, PC): standing still, the body still turns with the camera like the reference
		-- (Config FACE_CAMERA_IDLE). Moving, MovementCore already faces it; techniques keep their own facing.
		if
			M.FACE_CAMERA_IDLE
			and MovementController.faceCamera
			and cam
			and input == Vector3.zero
			and state.dashT <= 0
			and state.slideT <= 0
			and state.stopT <= 0
			and state.diveT <= 0
		then
			local look = MovementCore.flat(cam.CFrame.LookVector)
			if look ~= Vector3.zero then
				state.facing = MovementCore.rotateToward(state.facing, look, math.rad(M.FACE_RATE_LOW) * dt)
			end
		end
	end
	if loco then
		-- Animate from the real ground speed (a wall stops the legs too), steering intent and footing.
		local v = if root.Anchored then 0 else (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local busy = hum.PlatformStand or state.dashT > 0 or state.slideT > 0 or state.stopT > 0 or state.diveT > 0
		-- Which way the body moves relative to its facing (a backpedal plays the Walk in reverse).
		local flat = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local forward = if flat.Magnitude > 0.5 and look.Magnitude > 0.1 then flat.Unit:Dot(look.Unit) else 1
		-- …and across it (+ = to its right): the strafe cycles blend in by this.
		local right = root.CFrame.RightVector * Vector3.new(1, 0, 1)
		local side = if flat.Magnitude > 0.5 and right.Magnitude > 0.1 then flat.Unit:Dot(right.Unit) else 0
		-- (A reversal plant counts as letting go: out of a run ahead, the Brake clip plays over it.)
		loco:update(
			dt,
			v,
			input ~= Vector3.zero and not MovementCore.isReverseBraking(state),
			root.Anchored or hum.FloorMaterial ~= Enum.Material.Air,
			busy,
			nil,
			forward,
			side
		)
	end
	if root.Anchored or hum.PlatformStand or hum.Sit then
		lastLook = nil
		return
	end
	-- Drive with the frame's average speed (frame-rate independent ground covered), scaled by the slope.
	local k = 1 - math.exp(-10 * dt)
	slopeMult += (slopeFactor(root, hum, heading) - slopeMult) * k
	frameSpeed = avgSpeed * slopeMult
	hum.WalkSpeed = frameSpeed
	if speed > 0.05 then
		hum:Move(heading, false)
	else
		hum:Move(Vector3.zero, false)
	end
	-- Facing (omnimovement): the body looks where MovementCore turned it: at the camera's way while moving
	-- (FACE_RATE_*), held while standing, along a technique at once, or at a swing's aim.
	hum.AutoRotate = false
	local face = state.facing
	if face.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + face)
		lastLook = face
	end
	-- Head look: where the camera looks, relative to where the body now faces (clamped like the server does).
	if M.HEAD_LOOK and cam then
		local c = cam.CFrame.LookVector
		local cf = MovementCore.flat(c)
		if face.Magnitude > 1e-3 and cf ~= Vector3.zero then
			local yaw = math.deg(math.atan2(face:Cross(cf).Y, face:Dot(cf)))
			lookYaw = math.clamp(yaw, -M.HEAD_YAW_MAX, M.HEAD_YAW_MAX)
		end
		lookPitch = math.clamp(math.deg(math.asin(math.clamp(c.Y, -1, 1))), -M.HEAD_PITCH_DOWN, M.HEAD_PITCH_UP)
		sendAcc += dt
		if
			sendAcc >= 1 / M.HEAD_SEND_HZ
			and (math.abs(lookYaw - sentYaw) >= 2 or math.abs(lookPitch - sentPitch) >= 2)
		then
			sendAcc = 0
			sentYaw, sentPitch = lookYaw, lookPitch
			Net.send("Look", { y = lookYaw, p = lookPitch })
		end
	end
end

local function onPrimary(inputState: Enum.UserInputState): boolean
	if inputState ~= Enum.UserInputState.Begin or not techAllowed() then
		return false
	end
	-- (MEGA BOMB, P6: the giant's primary becomes its STOMP, GDD §16.)
	local dir = worldInput()
	-- Everyone dashes (Runners and Bombers alike, GDD §9.3) the way they steer; standing still (Config
	-- DASH_FROM_STANDSTILL) the way the body faces. A dash straight back is a backward hop still facing ahead
	-- (DASH_BACK_KEEPS_FACING).
	local steering = dir.Magnitude >= MOVE_INPUT_MIN
	if
		(steering or M.DASH_FROM_STANDSTILL)
		and MovementCore.dash(state, if steering then dir else Vector3.zero, M.DASH_BACK_KEEPS_FACING)
	then
		local side = MovementCore.dashSide(state)
		Net.send("RequestDash", { dir = state.dashDir, side = side })
		MovementController.Tech:Fire("Dash", side)
	end
	return true
end

local function onHardStop(inputState: Enum.UserInputState): boolean
	if inputState ~= Enum.UserInputState.Begin or not techAllowed() or inLobby() then
		return false
	end
	if player:GetAttribute("Titan") == true then
		return false -- the Titan's Shift is its CHARGE (TitanController)
	end
	if MovementCore.hardStop(state, params) then
		-- Kill the body's real momentum this frame too (the Humanoid would otherwise coast on for a few studs).
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not root.Anchored then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
		end
		Net.send("MovementTech", { kind = "HardStop", t = workspace:GetServerTimeNow() })
		MovementController.Tech:Fire("HardStop")
	end
	return true
end

local function onSlide(inputState: Enum.UserInputState): boolean
	if inputState ~= Enum.UserInputState.Begin or not techAllowed() or inLobby() then
		return false
	end
	if MovementCore.slide(state, params) then
		Net.send("MovementTech", { kind = "Slide", t = workspace:GetServerTimeNow() })
		MovementController.Tech:Fire("Slide")
	end
	return true
end

-- The PlayerModule lives in PlayerScripts on older places and under StarterPlayer on newer ones.
local function findPlayerModule(): ModuleScript
	local StarterPlayer = game:GetService("StarterPlayer")
	local scripts = player:WaitForChild("PlayerScripts")
	local deadline = os.clock() + 10
	while true do
		local m = scripts:FindFirstChild("PlayerModule") or StarterPlayer:FindFirstChild("PlayerModule")
		if m and m:IsA("ModuleScript") then
			return m
		end
		if os.clock() > deadline then
			return scripts:WaitForChild("PlayerModule") :: ModuleScript
		end
		task.wait(0.1)
	end
end

function MovementController.start()
	-- Classic PlayerModule: :GetControls(). Input-action PlayerModule: the ControlModule child is a client singleton.
	local pmScript = findPlayerModule()
	local controls: any = nil
	local ok, pm = pcall(require, pmScript)
	if ok and type(pm) == "table" and type((pm :: any).GetControls) == "function" then
		controls = (pm :: any):GetControls()
	else
		local cm = pmScript:FindFirstChild("ControlModule")
		if cm and cm:IsA("ModuleScript") then
			local ok2, mod = pcall(require, cm)
			if ok2 and type(mod) == "table" then
				controls = mod
			end
		end
	end
	if controls and controls.moveFunction ~= nil then
		hooked = true
		controls.moveFunction = function(_plr, moveVector: Vector3, relativeToCamera: boolean)
			rawMove = moveVector
			rawRelative = relativeToCamera
		end
	else
		warn("[Movement] could not hook PlayerModule controls; using MoveDirection fallback")
	end
	RunService:BindToRenderStep("CG_Momentum", Enum.RenderPriority.Input.Value + 1, step)
	InputController.on("Primary", onPrimary)
	InputController.on("HardStop", onHardStop)
	InputController.on("Slide", onSlide)
	local bindToken = 0
	local function bindLocomotion(char: Model)
		if loco then
			loco:destroy()
			loco = nil
		end
		bindToken += 1
		local token = bindToken
		task.spawn(function()
			local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if hum and hum:WaitForChild("Animator", 10) and player.Character == char and token == bindToken then
				-- TITAN HUNT: the giant's body walks with its own idle and stride (TitanService sets TitanRig).
				loco = Locomotion.new(hum, if char:GetAttribute("TitanRig") then "Titan" else nil)
			end
		end)
	end
	local rigConn: RBXScriptConnection? = nil
	local function watchRig(char: Model)
		if rigConn then
			rigConn:Disconnect()
		end
		rigConn = char:GetAttributeChangedSignal("TitanRig"):Connect(function()
			if player.Character == char then
				bindLocomotion(char)
			end
		end)
	end
	if player.Character then
		bindLocomotion(player.Character)
		watchRig(player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		watchRig(char)
		state = MovementCore.newState()
		lastLook, faceAim = nil, nil
		airT, landingUntil, slopeMult = 0, 0, 1
		floorRay.FilterDescendantsInstances = { char }
		bindLocomotion(char)
	end)
	if player.Character then
		floorRay.FilterDescendantsInstances = { player.Character }
	end
	-- Server teleports (crossing starts, back to lobby): drop the old momentum and face the new way, so nothing
	-- carries over from the previous side of the field.
	ClientState.myChanged("TeleportAt", function()
		local root = (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) :: BasePart?
		state.speed = 0
		state.dashT, state.stopT, state.slideT, state.diveT, state.recoverT = 0, 0, 0, 0, 0
		if root then
			local look = MovementCore.flat(root.CFrame.LookVector)
			if look ~= Vector3.zero then
				state.heading = look
				state.facing = look
			end
			state.backing = false
			lastLook = nil
		end
	end)
end

return MovementController
