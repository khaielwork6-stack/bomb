--!strict
-- Studio-only movement readout (2026-10-08 movement polish). Toggle from the client command bar:
--   game.Players.LocalPlayer:SetAttribute("CG_MoveDebug", true)   -- on
--   game.Players.LocalPlayer:SetAttribute("CG_MoveDebug", false)  -- off
-- Shows the movement state (MovementController.stateName), the model's speed vs the speed the Humanoid is driven
-- at vs the real ground speed, the slope multiplier, technique cooldowns and the frame rate. Never runs outside
-- Studio; updates 10 times a second (no per-frame allocation in the movement loop).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MovementDebug = {}

local player = Players.LocalPlayer
local ATTR = "CG_MoveDebug"

local gui: ScreenGui? = nil
local conn: RBXScriptConnection? = nil

local function build(): TextLabel
	local g = Instance.new("ScreenGui")
	g.Name = "CG_MoveDebug"
	g.ResetOnSpawn = false
	g.DisplayOrder = 1000
	local l = Instance.new("TextLabel")
	l.Name = "Readout"
	l.AnchorPoint = Vector2.new(1, 0)
	l.Position = UDim2.new(1, -12, 0, 90)
	l.Size = UDim2.fromOffset(340, 190)
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.35
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.RobotoMono
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = ""
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = l
	l.Parent = g
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	return l
end

local function stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function start()
	stop()
	local MovementController = require(script.Parent.Parent.Controllers.MovementController) :: any
	local l = build()
	local fps, acc = 60, 0
	conn = RunService.RenderStepped:Connect(function(dt)
		fps += ((1 / math.max(dt, 1e-3)) - fps) * 0.1
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local st = MovementController.state()
		local drive, slope = MovementController.debugInfo()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local ground = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
		l.Text = table.concat({
			("state   %s"):format(MovementController.stateName()),
			("speed   model %5.1f  drive %5.1f"):format(st.speed, drive),
			("ground  %5.1f studs/s"):format(ground),
			("slope   x%.2f"):format(slope),
			("dash cd %4.2f  side %s"):format(st.dashCD, tostring(st.dashSide)),
			("stop cd %4.2f  slide cd %4.2f"):format(st.stopCD, st.slideCD),
			("backing %s"):format(tostring(st.backing)),
			("fps     %3.0f"):format(fps),
		}, "\n")
	end)
end

function MovementDebug.start()
	if not RunService:IsStudio() then
		return
	end
	player:GetAttributeChangedSignal(ATTR):Connect(function()
		if player:GetAttribute(ATTR) == true then
			start()
		else
			stop()
		end
	end)
	if player:GetAttribute(ATTR) == true then
		start()
	end
end

return MovementDebug
