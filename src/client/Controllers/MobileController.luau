--!strict
-- The phone action buttons (GDD §21.2, Asset Bible §6.6; ART_BACKLOG §1 "Mobile action buttons"): a big DASH under
-- the thumb with SLIDE and STOP in an arc round it, bottom-right (jumping is off, so Roblox's jump button never shows
-- there). Each is a round arcade button with its 3D icon; it fires on touch-down (InputController.trigger, the same
-- path as the keys) and sinks as it's pressed. While a move recharges, a ring drains back to full round the button and
-- the face dims; when it's ready again the button pings. In the lobby only DASH shows (slides and stops are run moves);
-- between runs (results, a crossing you're out of) the buttons step aside.
-- Shown on touch devices (UserInputService.TouchEnabled without a keyboard, or the last input was touch); Studio
-- preview: the player attribute FV_SimTouch.
-- Implements: F-UI (touch controls), GDD §21.2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Screen = require(script.Parent.Parent.UI.Screen)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local Settings = require(script.Parent.Parent.Settings)

local MC = Config.Mobile
local MV = Config.Movement
local S = Config.Strings
local new = Theme.new
local player = Players.LocalPlayer

local MobileController = {}

type Btn = {
	action: string,
	holder: Frame,
	face: TextButton,
	scale: UIScale,
	dim: Frame,
	icon: ImageLabel,
	rings: { UIGradient },
	ringFrame: Frame,
	cdKey: string, -- the MovementCore state field that counts the cooldown down
	cdMax: number,
	wasCooling: boolean,
	lobby: boolean, -- usable in the lobby
	carry: boolean?, -- only while you carry a bomb (PASS)
}

local gui: ScreenGui
local root: Frame
local fit: UIScale
local buttons: { Btn } = {}

-- One half of the drain ring: a clipped half-frame holding a full ring whose stroke has a hard-edged gradient; turning
-- the gradient sweeps the visible part round that half (right half: 12 → 6 o'clock; left: 6 → 12).
local function ringHalf(parent: Instance, right: boolean, color: Color3): UIGradient
	local half = new("Frame", {
		Name = if right then "RingR" else "RingL",
		Position = UDim2.fromScale(if right then 0.5 else 0, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 6,
		Parent = parent,
	})
	local ring = new("Frame", {
		Position = UDim2.fromScale(if right then -1 else 0, 0),
		Size = UDim2.fromScale(2, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = half,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local stroke = new("UIStroke", {
		Color = color,
		Thickness = MC.RING_WIDTH,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ring,
	})
	return new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.499, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = stroke,
	})
end

-- Fill the ring to `f` (0..1, clockwise from 12 o'clock).
local function setRing(b: Btn, f: number)
	f = math.clamp(f, 0, 1)
	b.rings[1].Rotation = math.min(f, 0.5) * 360 -- right half
	b.rings[2].Rotation = 180 + math.max(f - 0.5, 0) * 360 -- left half
end

local function makeButton(
	action: string,
	label: string,
	icon: string,
	preset: string,
	size: number,
	cdKey: string,
	cdMax: number,
	lobby: boolean
): Btn
	local p = Skin.Preset[preset]
	local holder = new("Frame", {
		Name = action,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = root,
	})
	-- the lip under the face (it sinks into it when pressed)
	local lip = new("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, size * 0.05),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = p[3],
		ZIndex = 1,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lip })
	new("UIStroke", { Color = Skin.Color.Ink, Thickness = 4, Parent = lip })
	local face = new("TextButton", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = holder,
	}) :: TextButton
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = face })
	new("UIStroke", { Color = Skin.Color.Ink, Thickness = 4, Parent = face })
	new("UIGradient", { Color = ColorSequence.new(p[1], p[2]), Rotation = 90, Parent = face })
	-- the gloss
	local gloss = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromScale(0.72, 0.36),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		ZIndex = 3,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gloss })
	local iconImg = Widgets.icon(face, icon, math.floor(size * 0.58), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		ZIndex = 4,
	})
	Widgets.label(face, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -size * 0.07),
		Size = UDim2.new(1, 0, 0, size * 0.22),
		TextSize = math.floor(size * 0.18),
		font = Theme.Font.Display,
		stroke = 2,
		Text = label,
		ZIndex = 5,
	})
	local dim = new("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Skin.Color.Ink,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dim })
	-- the drain ring, just outside the face
	local ringFrame = new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, MC.RING_WIDTH * 2 + 6, 1, MC.RING_WIDTH * 2 + 6),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = holder,
	})
	local rings = {
		ringHalf(ringFrame, true, Color3.new(1, 1, 1)),
		ringHalf(ringFrame, false, Color3.new(1, 1, 1)),
	}
	local scale = new("UIScale", { Parent = holder })
	local b: Btn = {
		action = action,
		holder = holder,
		face = face,
		scale = scale,
		dim = dim,
		icon = iconImg,
		rings = rings,
		ringFrame = ringFrame,
		cdKey = cdKey,
		cdMax = cdMax,
		wasCooling = false,
		lobby = lobby,
	}
	local function press()
		TweenService:Create(scale, TweenInfo.new(0.05), { Scale = MC.PRESS_SCALE }):Play()
		InputController.trigger(action, Enum.UserInputState.Begin)
	end
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		InputController.trigger(action, Enum.UserInputState.End)
	end
	face.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			press()
		end
	end)
	face.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			release()
		end
	end)
	table.insert(buttons, b)
	return b
end

local function ping(b: Btn)
	b.scale.Scale = 1.18
	TweenService:Create(b.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local flash = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = b.holder,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = flash })
	local st = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 5, Parent = flash })
	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.5, 1.5) }):Play()
	TweenService:Create(st, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	task.delay(0.4, function()
		flash:Destroy()
	end)
end

local function wanted(): boolean
	if player:GetAttribute("FV_SimTouch") == true then
		return true
	end
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or InputController.device == "Touch"
end

local function place()
	local v = Screen.size()
	-- the Settings "Button Size" (S / M / L) scales the action buttons on top of the screen fit
	local size = MC.BUTTON_SIZE[Settings.get("mobileButtonSize")] or 1
	fit.Scale = math.clamp(v.Y / MC.REF_HEIGHT, MC.SCALE_MIN, MC.SCALE_MAX) * size
	local safe = Screen.safe()
	root.Position = UDim2.new(1, -(MC.MARGIN_RIGHT + safe.right), 1, -(MC.MARGIN_BOTTOM + safe.bottom))
end

local function step()
	local show = wanted()
	if Screen.touch() ~= show then
		Screen.setTouch(show)
	end
	local char = player.Character
	gui.Enabled = show and char ~= nil and player:GetAttribute("Titan") ~= true
	if not gui.Enabled then
		return
	end
	local lobby = ClientState.role() == Types.Role.None
	local ph = ClientState.phase()
	local live = lobby or ClientState.activeInRun() or ph == Types.Phase.Ready
	root.Visible = live
	local state = MovementController.state() :: any
	local carrying = player:GetAttribute("BombId") ~= nil and ClientState.role() == Types.Role.Runner
	-- THROW MODE: a Bomber with a bomb in hand throws it too
	if not carrying and ClientState.get("ThrowMode") == true and ClientState.role() == Types.Role.Bomber then
		carrying = (player:GetAttribute("TagReadyAt") or 0) <= workspace:GetServerTimeNow()
	end
	for _, b in ipairs(buttons) do
		b.holder.Visible = (b.lobby or not lobby) and (not b.carry or carrying)
		local cd = if state then (state[b.cdKey] or 0) else 0
		local cooling = cd > 0.02
		if cooling then
			b.ringFrame.Visible = true
			setRing(b, 1 - cd / b.cdMax)
			b.dim.BackgroundTransparency = 0.45
			b.icon.ImageTransparency = 0.35
		elseif b.wasCooling then
			b.ringFrame.Visible = false
			b.dim.BackgroundTransparency = 1
			b.icon.ImageTransparency = 0
			if b.holder.Visible then
				ping(b)
			end
		end
		b.wasCooling = cooling
	end
end

function MobileController.start()
	gui = new("ScreenGui", {
		Name = "FV_Mobile",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- `root` is DASH's centre; everything is laid out round it
	root = new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(MC.DASH_SIZE, MC.DASH_SIZE),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	fit = new("UIScale", { Parent = root })
	local dash = makeButton("Primary", S.Ui.BtnDash, "Dash", "fuse", MC.DASH_SIZE, "dashCD", MV.DASH_CD, true)
	dash.holder.Position = UDim2.fromScale(0.5, 0.5)
	local small = {
		makeButton("Slide", S.Ui.BtnSlide, "Slide", "cyan", MC.SMALL_SIZE, "slideCD", MV.SLIDE_CD, false),
		makeButton("HardStop", S.Ui.BtnStop, "Stop", "red", MC.SMALL_SIZE, "stopCD", MV.HARDSTOP_CD, false),
		-- F-BOMB-15: the Slap-Pass, only while you carry
		makeButton(
			"Swing",
			if Config.Throw.ENABLED then S.Ui.BtnThrow else S.Ui.BtnPass,
			"Bomb",
			"orange",
			MC.SMALL_SIZE,
			"passCD",
			Config.Bomb.PASS_SLAP_CD,
			false
		),
	}
	small[3].carry = true
	for i, b in ipairs(small) do
		local a = math.rad(MC.ARC_ANGLES[i])
		b.holder.Position = UDim2.new(0.5, math.cos(a) * MC.ARC_RADIUS, 0.5, -math.sin(a) * MC.ARC_RADIUS)
	end
	place()
	Screen.Changed:Connect(place)
	Settings.Changed:Connect(function(key)
		if key == "mobileButtonSize" then
			place()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return MobileController
