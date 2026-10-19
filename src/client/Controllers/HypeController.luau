--!strict
-- The hype layer (docs/VIDEO2_NOTES.md §4; the reference video's juke moment): when you juke a Bomber (our Dodge
-- callout) the screen's edge flashes gold with speed lines streaking out, the crowd roars, yellow lightning bolts
-- splash across the floor under you, and a streak of jukes builds it — louder, brighter, a camera kick from the
-- second. Reduce motion keeps the flash and the roar, drops the speed lines and the kick.
-- Every paying callout (§6, the reference's "+45 Takedown!"): a "+N Word!" tag pops beside your own body and floats
-- up — gold number, white word, "×2" when callouts chain inside COMBO_WINDOW — and the Stars it paid fly off your
-- body into the Stars counter, which ticks up as each one lands (ProgressController.fly).
-- Pure presentation on the server's Callout event (it's sent only to the player it's about).
-- Implements: docs/VIDEO2_NOTES.md §4 (juke intensity), §6 (takedown / reward to the body).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local CameraController = require(script.Parent.CameraController)
local ProgressController = require(script.Parent.ProgressController)

local H = Config.Hype
local new = Theme.new
local player = Players.LocalPlayer

local HypeController = {}

local GOLD = Color3.fromRGB(255, 214, 60)
local gui: ScreenGui
local streak = 0
local lastJuke = -math.huge
local combo = 0
local lastPaid = -math.huge

-- The gold screen edge (the shared vignette, tinted) and a light gold wash over everything.
local function flash(strength: number)
	local edge = new("ImageLabel", {
		Name = "JukeEdge",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Ui.Vignette,
		ImageColor3 = GOLD,
		ImageTransparency = H.FLASH_T * (1 - strength) + H.FLASH_T * 0.5,
		ZIndex = 2,
		Parent = gui,
	})
	local wash = new("Frame", {
		Name = "JukeWash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = H.TINT_T - strength * 0.06,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = gui,
	})
	local out = TweenInfo.new(H.FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(edge, out, { ImageTransparency = 1 }):Play()
	TweenService:Create(wash, out, { BackgroundTransparency = 1 }):Play()
	task.delay(H.FLASH_TIME + 0.05, function()
		edge:Destroy()
		wash:Destroy()
	end)
end

-- White speed lines streaking out from the middle toward the edges.
local function speedLines(count: number)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.3
		local dir = Vector2.new(math.cos(a), math.sin(a))
		local line = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, dir.X * 160, 0.5, dir.Y * 110),
			Size = UDim2.fromOffset(math.random(60, 120), 4),
			Rotation = math.deg(a),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = gui,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = line })
		TweenService:Create(line, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, dir.X * 720, 0.5, dir.Y * 460),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.4, function()
			line:Destroy()
		end)
	end
end

-- Yellow lightning zigzags splashing out across the floor ahead of you, along your run.
local function bolts(root: BasePart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	if not hit then
		return
	end
	local v = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local fwd = if v.Magnitude > 2 then v.Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 1e-3 then
		return
	end
	fwd = fwd.Unit
	for i = 1, H.BOLTS do
		local spread = if H.BOLTS > 1 then (i - 1) / (H.BOLTS - 1) * 2 - 1 else 0
		local dir = CFrame.Angles(0, math.rad(spread * H.BOLT_SPREAD), 0):VectorToWorldSpace(fwd)
		local centre = hit.Position + dir * (H.BOLT_AHEAD + H.BOLT_SIZE.X / 2) + Vector3.new(0, 0.06, 0)
		-- a flat card: its top face is the bolt, +U (the arrow) pointing along `dir`
		local card = new("Part", {
			Name = "FV_JukeBolt",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(H.BOLT_SIZE.X * 0.3, 0.05, H.BOLT_SIZE.Y * 0.3),
			CFrame = CFrame.lookAt(centre, centre + dir) * CFrame.Angles(0, math.rad(90), 0),
			Parent = workspace,
		}) :: Part
		local decal = new("Decal", {
			Texture = Assets.Vfx.JukeBolt,
			Face = Enum.NormalId.Top,
			Transparency = 0,
			Parent = card,
		}) :: Decal
		local grow = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(card, grow, { Size = Vector3.new(H.BOLT_SIZE.X, 0.05, H.BOLT_SIZE.Y) }):Play()
		TweenService
			:Create(
				decal,
				TweenInfo.new(H.BOLT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			:Play()
		task.delay(H.BOLT_TIME + 0.05, function()
			card:Destroy()
		end)
	end
end

function HypeController.juke()
	local t = os.clock()
	streak = if t - lastJuke <= H.STREAK_WINDOW then math.min(streak + 1, H.STREAK_MAX) else 1
	lastJuke = t
	local strength = (streak - 1) / math.max(1, H.STREAK_MAX - 1)
	flash(strength)
	Sfx.play("CrowdCheer", H.CHEER_VOLUME * (1 + (streak - 1) * H.CHEER_STREAK), 1 + (streak - 1) * 0.04)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		bolts(root)
	end
	if not Widgets.reduced() then
		speedLines(H.SPEED_LINES + (streak - 1) * 4)
		if streak >= H.PUNCH_FROM_STREAK then
			CameraController.punch(H.PUNCH_FOV)
		end
	end
end

-- "TAGGED!" → "Tagged!", "CHAIN ×%d" → "Chain ×3".
local function wordOf(key: string, n: number?): string
	local def = Config.Callouts.List[key]
	if not def then
		return key
	end
	local text = if string.find(def.text, "%%d") then string.format(def.text, n or 0) else def.text
	return (
		string.gsub(string.lower(text), "(%a)(%a*)", function(a: string, b: string)
			return string.upper(a) .. b
		end)
	)
end

-- "+N" (and the word, when the centre isn't saying it) beside your body, floating up and fading (world-anchored).
local function bodyTag(amount: number, word: string, comboN: number)
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local bb = new("BillboardGui", {
		Name = "FV_RewardTag",
		Adornee = head,
		Size = UDim2.fromOffset(260, 40),
		StudsOffset = Vector3.new(3.6, -0.2, 0),
		AlwaysOnTop = false, -- (an always-on-top billboard doesn't draw in Studio captures; beside the body it's rarely hidden)
		LightInfluence = 0,
		MaxDistance = 200,
		Parent = head,
	}) :: BillboardGui
	local row = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local parts: { TextLabel } = {}
	local function piece(text: string, color: Color3, size: number, order: number)
		local l = Widgets.label(row, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 40),
			TextSize = size,
			font = Theme.Font.Display,
			stroke = 2.5,
			color = color,
			Text = text,
			LayoutOrder = order,
		})
		table.insert(parts, l)
	end
	if amount > 0 then
		piece("+" .. tostring(amount), GOLD, 30, 1)
	end
	if word ~= "" then
		piece(word, Color3.new(1, 1, 1), 26, 2)
	end
	if comboN >= 2 then
		piece(("×%d"):format(comboN), Color3.fromRGB(255, 140, 60), 24, 3)
	end
	local scale = new("UIScale", { Scale = 0.4, Parent = row })
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(bb, TweenInfo.new(H.TAG_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(3.6, -0.2 + H.TAG_RISE / 20, 0),
	}):Play()
	task.delay(H.TAG_TIME * 0.6, function()
		local fade = TweenInfo.new(H.TAG_TIME * 0.4)
		for _, l in ipairs(parts) do
			TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				TweenService:Create(st, fade, { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(H.TAG_TIME + 0.05, function()
		bb:Destroy()
	end)
end

-- A paying callout: the tag by your body, the Stars flying from you into the counter.
function HypeController.reward(key: string, n: number?, xp: number, stars: number)
	local t = os.clock()
	combo = if t - lastPaid <= H.COMBO_WINDOW then combo + 1 else 1
	lastPaid = t
	-- the word only when the middle of the screen doesn't already say it (one voice: BOOM! is the title, "+20" here)
	local def = Config.Callouts.List[key]
	local word = if def and def.title then "" else wordOf(key, n)
	bodyTag(if stars > 0 then stars else xp, word, combo)
	local cam = workspace.CurrentCamera
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if stars > 0 and cam and head then
		local p, onScreen = cam:WorldToViewportPoint(head.Position)
		local from = if onScreen then Vector2.new(p.X, p.Y) else ProgressController.centre()
		ProgressController.fly(from, stars)
	end
end

function HypeController.start()
	gui = new("ScreenGui", {
		Name = "FV_Hype",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 4, -- under the callouts and the HUD
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.listen("Callout", function(p)
		if type(p) ~= "table" or type(p.key) ~= "string" then
			return
		end
		if p.key == "Dodge" then
			HypeController.juke()
		end
		local xp = if type(p.xp) == "number" then p.xp else 0
		local stars = if type(p.stars) == "number" then p.stars else 0
		if xp > 0 or stars > 0 then
			HypeController.reward(p.key, if type(p.n) == "number" then p.n else nil, xp, stars)
		end
	end)
end

return HypeController
