--!strict
-- The loading screen (GDD §20 F-ONB-01, Asset Bible §7.1), in the reference video's join screen: a bright sky with
-- drifting clouds over the studded ground, the 3D FUSE VALLEY logo in the middle (it breathes), a braided fuse under
-- it that burns down as the game loads (a spark at the burn point), a rotating tip — then the big green PLAY! button
-- and "PRESS PLAY TO JOIN". Pressing it pops the logo and wipes into the game.
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
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(640, 400),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = gui,
})
local logoScale = new("UIScale", { Parent = logoHolder })
local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
logoScale.Scale = math.min(1, vp.Y / 820, vp.X / 760)
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
end

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
	logoScale.Scale = math.min(1, vp.Y / 820, vp.X / 760) * (1 + 0.02 * math.sin(t * 2.4))
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
local press = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.74, 82),
	Size = UDim2.fromOffset(600, 40),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 36,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "PRESS PLAY TO JOIN",
	ZIndex = 10,
	Parent = gui,
})
new("UIStroke", { Color = INK, Thickness = 4, Parent = press })
local ps = new("UIScale", { Scale = 0.2, Parent = play })
TweenService:Create(ps, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
task.spawn(function()
	while play.Parent do
		TweenService:Create(ps, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1.06 })
			:Play()
		task.wait(0.7)
		TweenService:Create(ps, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 })
			:Play()
		task.wait(0.7)
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
