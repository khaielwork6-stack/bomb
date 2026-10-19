--!strict
-- The loading screen (GDD §20 F-ONB-01, Asset Bible §7.1), in the reference video's join screen: a bright sky with
-- drifting clouds over the studded ground, the 3D FUSE VALLEY logo in the middle (it breathes), a braided fuse under
-- it that burns down as the game loads (a spark at the burn point), a rotating tip — then the big green PLAY! button.
-- Pressing it pops the logo and wipes into the game.
-- Runs from ReplicatedFirst (before the rest of the client); waits for ReplicatedStorage.Shared only for the asset
-- ids and strings, drawing the sky and studs straight away.
-- Implements: F-ONB-01.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(17, 15, 22)

local function new(class: string, props: { [string]: any }): any
	local i = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(i :: any)[k] = v
		end
	end
	if props.Parent then
		i.Parent = props.Parent
	end
	return i
end

local gui = new("ScreenGui", {
	Name = "FV_Loading",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
-- sky
local sky = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui })
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 156, 255)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(150, 210, 255)),
		ColorSequenceKeypoint.new(0.63, Color3.fromRGB(86, 204, 64)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 160, 44)),
	}),
	Rotation = 90,
	Parent = sky,
})
-- clouds: rounded white puffs drifting
local clouds = {}
for _ = 1, 6 do
	local c = new("Frame", {
		Position = UDim2.fromScale(math.random(), 0.06 + math.random() * 0.36),
		Size = UDim2.fromOffset(180 + math.random(0, 160), 60 + math.random(0, 40)),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		ZIndex = 2,
		Parent = sky,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = c })
	for k = 1, 2 do
		local puff = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.3 + k * 0.22, 0.55),
			Size = UDim2.fromScale(0.42, 1.2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
			Parent = c,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = puff })
	end
	table.insert(clouds, { f = c, speed = 0.004 + math.random() * 0.006 })
end
-- the studded ground band (the stud tile over the green)
new("ImageLabel", {
	Position = UDim2.fromScale(0, 0.63),
	Size = UDim2.fromScale(1, 0.37),
	BackgroundTransparency = 1,
	Image = "rbxassetid://140680613862301",
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(48, 48),
	ImageTransparency = 0.1,
	ZIndex = 2,
	Parent = sky,
})

-- logo (the 3D render; a styled title until its id is known)
local logoHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.34),
	Size = UDim2.fromOffset(940, 588),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = gui,
})
local logoScale = new("UIScale", { Parent = logoHolder })
-- the screen size, read live (the camera's viewport is still 1 x 1 this early in ReplicatedFirst)
local function screen(): Vector2
	local s = gui.AbsoluteSize
	return if s.X > 10 and s.Y > 10 then s else Vector2.new(1280, 720)
end
local vp = screen()
logoScale.Scale = math.min(1, vp.Y / 900, vp.X / 1000)
local logo = new("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 5,
	Parent = logoHolder,
})
local fallback = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 110,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "FUSE\nVALLEY",
	ZIndex = 6,
	Parent = logoHolder,
})
new("UIStroke", { Color = INK, Thickness = 8, Parent = fallback })
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 120, 30)),
	Rotation = 90,
	Parent = fallback,
})

-- the burning fuse (loading progress)
local bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.72),
	Size = UDim2.fromOffset(460, 34),
	BackgroundColor3 = Color3.fromRGB(196, 204, 218),
	ZIndex = 6,
	Parent = gui,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
new("UIStroke", { Color = INK, Thickness = 4, Parent = bar })
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(226, 232, 244), Color3.fromRGB(120, 128, 146)),
	Rotation = 90,
	Parent = bar,
})
local gutter = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -14, 0, 16),
	BackgroundColor3 = Color3.fromRGB(34, 30, 40),
	ClipsDescendants = true,
	ZIndex = 6,
	Parent = bar,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gutter })
local cord = new("ImageLabel", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "",
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(64, 16),
	ZIndex = 7,
	Parent = gutter,
})
local spark = new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1,
	Image = "",
	ImageColor3 = Color3.fromRGB(255, 216, 74),
	ZIndex = 9,
	Parent = bar,
})
local tip = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.72, 30),
	Size = UDim2.fromOffset(700, 30),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	ZIndex = 6,
	Parent = gui,
})
new("UIStroke", { Color = INK, Thickness = 3, Parent = tip })

-- assets + strings once Shared is in
local Shared = ReplicatedStorage:WaitForChild("Shared", 20)
local tips = { "Bump anyone to pass the bomb!" }
local LC: { [string]: number }? = nil -- Config.Loading (the lobby flyover)
if Shared then
	local ok, Assets = pcall(require, Shared:WaitForChild("Assets", 10))
	if ok and Assets then
		local ui = (Assets :: any).Ui or {}
		cord.Image = ui.Braid or ""
		spark.Image = ((Assets :: any).Vfx or {}).Flash or ""
		if ui.Logo and ui.Logo ~= "" then
			logo.Image = ui.Logo
			fallback.Visible = false
		end
	end
	local ok2, Config = pcall(require, Shared:WaitForChild("Config", 10))
	if ok2 and Config and Config.Strings and Config.Strings.LoadingTips then
		tips = Config.Strings.LoadingTips
	end
	if ok2 and Config and Config.Loading then
		LC = Config.Loading
	end
end

-- The lobby flyover: once the Depot has streamed in, the 2D sky fades away and a slow drone orbit circles the clock
-- tower behind the logo (soft depth of field, a dark shade under the button) until PLAY hands the camera back.
local dof: DepthOfFieldEffect? = nil
local stopFlyover: (() -> ())? = nil -- hands the camera and the game's screens back (once)
local function fadeSky(time: number)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	for _, d in ipairs(sky:GetDescendants()) do
		if d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end
	end
	TweenService:Create(sky, info, { BackgroundTransparency = 1 }):Play()
end
task.spawn(function()
	local c = LC
	if not c then
		return
	end
	local lobby = workspace:WaitForChild("Lobby", c.LOBBY_WAIT)
	local tower = lobby and lobby:WaitForChild("ClockTower", c.LOBBY_WAIT)
	if not tower or not tower:IsA("Model") or not gui.Parent then
		return
	end
	local box, size = tower:GetBoundingBox()
	local aim = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2 + c.LOOK_UP, box.Position.Z)
	local cam = workspace.CurrentCamera
	local fov = cam.FieldOfView
	dof = new("DepthOfFieldEffect", {
		FarIntensity = c.DOF_FAR,
		NearIntensity = 0,
		FocusDistance = Vector2.new(c.RADIUS, c.HEIGHT - c.LOOK_UP).Magnitude,
		InFocusRadius = c.DOF_FOCUS_RADIUS,
		Parent = cam,
	})
	-- the shade: dark at the bottom so the button and tips read on any shot
	local shade = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(1, c.SHADE),
		}),
		Rotation = 90,
		Parent = shade,
	})
	TweenService:Create(shade, TweenInfo.new(c.SKY_FADE), { BackgroundTransparency = 0 }):Play()
	local t1 = os.clock()
	local function shot(): CFrame
		local t = os.clock() - t1
		local a = c.ORBIT_START + t * c.ORBIT_SPEED
		local r = c.RADIUS + c.RADIUS_SWAY * math.sin(t * c.RADIUS_SWAY_SPEED)
		local h = c.HEIGHT + c.HEIGHT_SWAY * math.sin(t * c.HEIGHT_SWAY_SPEED)
		local pos = aim + Vector3.new(math.sin(a) * r, h - c.LOOK_UP, -math.cos(a) * r)
		return CFrame.lookAt(pos, aim)
	end
	-- The game's own screens are up underneath now that the sky is see-through: hide them every frame until PLAY,
	-- then give back the ones we hid. FV_Mobile and FV_Pick set their own Enabled from game state, so they're only
	-- hidden (they put themselves back); a HUD screen the Bomber pick is holding off gets its restore flag instead.
	local pg = player:WaitForChild("PlayerGui")
	local hid: { [ScreenGui]: boolean } = {}
	local SELF_MANAGED = { FV_Mobile = true, FV_Pick = true }
	local function hideOthers()
		for _, g in ipairs(pg:GetChildren()) do
			if g ~= gui and g:IsA("ScreenGui") and g.Enabled then
				g.Enabled = false
				if not SELF_MANAGED[g.Name] then
					hid[g] = true
				end
			end
		end
	end
	-- after the default camera and every controller (Last + 20), so nothing pulls it back while we fly
	RunService:BindToRenderStep("FV_LoadingCam", Enum.RenderPriority.Last.Value + 20, function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = c.FOV
		cam.CFrame = shot()
		hideOthers()
	end)
	fadeSky(c.SKY_FADE)
	-- hand the camera back under the PLAY wipe (or whenever the screen goes)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		RunService:UnbindFromRenderStep("FV_LoadingCam")
		for g in pairs(hid) do
			if g.Parent then
				if g:GetAttribute("FV_PickWasOn") ~= nil then
					g:SetAttribute("FV_PickWasOn", true)
				else
					g.Enabled = true
				end
			end
		end
		if dof then
			dof:Destroy()
		end
		cam.FieldOfView = fov
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	stopFlyover = stop
	gui.Destroying:Connect(stop)
end)

-- animate while loading
local t0 = os.clock()
local tipIndex = 0
local nextTip = 0
local progress = 0
local done = false
local conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	for _, c in ipairs(clouds) do
		local x = c.f.Position.X.Scale + c.speed * dt * 4
		if x > 1.15 then
			x = -0.3
		end
		c.f.Position = UDim2.fromScale(x, c.f.Position.Y.Scale)
	end
	vp = screen()
	logoScale.Scale = math.min(1, vp.Y / 900, vp.X / 1000) * (1 + 0.02 * math.sin(t * 2.4))
	-- progress: the content queue draining, eased, never backwards; game.Loaded finishes it
	local queue = ContentProvider.RequestQueueSize
	local target = if game:IsLoaded() and queue == 0 then 1 else math.clamp(t / 6, 0, 0.9) * (1 / (1 + queue * 0.02))
	progress = math.max(progress, progress + (target - progress) * math.min(1, dt * 3))
	cord.Size = UDim2.fromScale(1 - progress, 1)
	spark.Position = UDim2.new(0, 7 + progress * (bar.AbsoluteSize.X - 14), 0.5, 0)
	spark.Rotation = (t * 400) % 360
	spark.Size = UDim2.fromOffset(40 + 8 * math.sin(t * 20), 40 + 8 * math.sin(t * 20))
	if t >= nextTip then
		tipIndex = tipIndex % #tips + 1
		tip.Text = tips[tipIndex]
		nextTip = t + 3.2
	end
	if progress > 0.985 then
		done = true
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
while not done and os.clock() - t0 < 20 do
	task.wait(0.05)
end

-- PLAY!
bar.Visible = false
tip.Visible = false
local play = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.74),
	Size = UDim2.fromOffset(300, 130),
	BackgroundColor3 = Color3.fromRGB(56, 210, 40),
	AutoButtonColor = false,
	Text = "",
	ZIndex = 10,
	Parent = gui,
})
new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = play })
new("UIStroke", { Color = INK, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = play })
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(150, 250, 90), Color3.fromRGB(30, 170, 30)),
	Rotation = 90,
	Parent = play,
})
new("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "rbxassetid://140680613862301",
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(28, 28),
	ImageTransparency = 0.35,
	ZIndex = 10,
	Parent = play,
})
local playText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	TextSize = 72,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "PLAY!",
	ZIndex = 11,
	Parent = play,
})
new("UIStroke", { Color = INK, Thickness = 6, Parent = playText })
local ps = new("UIScale", { Scale = 0.2, Parent = play })
TweenService:Create(ps, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
-- the house button feel (the same as UI/Motion, which isn't loaded yet this early): it breathes while idle, springs
-- up and tilts on hover, squishes on press and bounces back on release
local hovering, pressing = false, false
local function scaleTo(s: number, t: number, style: Enum.EasingStyle?)
	TweenService:Create(ps, TweenInfo.new(t, style or Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = s })
		:Play()
end
local function tilt(r: number)
	TweenService:Create(play, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = r })
		:Play()
end
task.spawn(function()
	task.wait(0.45)
	while play.Parent do
		if not hovering and not pressing then
			scaleTo(1.06, 0.7, Enum.EasingStyle.Sine)
		end
		task.wait(0.7)
		if not hovering and not pressing then
			scaleTo(1, 0.7, Enum.EasingStyle.Sine)
		end
		task.wait(0.7)
	end
end)
play.MouseEnter:Connect(function()
	hovering = true
	if not pressing then
		scaleTo(1.1, 0.3)
		tilt(-2)
	end
end)
play.MouseLeave:Connect(function()
	hovering, pressing = false, false
	scaleTo(1, 0.3)
	tilt(0)
end)
play.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressing = true
		scaleTo(0.92, 0.07, Enum.EasingStyle.Quad)
	end
end)
play.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressing = false
		scaleTo(if hovering then 1.1 else 1, 0.3)
	end
end)

local entered = false
local function enter()
	if entered then
		return
	end
	entered = true
	TweenService:Create(logoScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = logoScale.Scale * 1.25,
	}):Play()
	local wipe = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 50,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = wipe })
	local big = math.max(vp.X, vp.Y) * 2.4
	TweenService:Create(wipe, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(big, big),
	}):Play()
	task.wait(0.32)
	conn:Disconnect()
	if stopFlyover then
		stopFlyover()
	end
	for _, c in ipairs(gui:GetChildren()) do
		if c ~= wipe then
			c:Destroy()
		end
	end
	TweenService:Create(wipe, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.wait(0.4)
	gui:Destroy()
end
play.Activated:Connect(enter)
