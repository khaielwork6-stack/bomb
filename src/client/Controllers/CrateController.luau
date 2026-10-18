--!strict
-- The crate opening (GDD §17.4 F-STORE-10, Asset Bible §7.4), in the reference video's presentation: a full-screen
-- stage with the real 3D crate (ReplicatedStorage.FV_Art.Crates.<Kind>, art/crate) in a ViewportFrame.
--   1. DROP   — the crate falls in and lands with a thud and a dust puff;
--   2. FUSE   — its fuse lights, the camera pushes in;
--   3. TENSION— it rattles harder and harder, light leaking from the lid seam in the RARITY colour (the hint);
--   4. POP    — the lid blows open with a rarity burst (Legendary adds a light-ray fan);
--   5. REVEAL — the item rises on a beam with its name plate and rarity banner; EQUIP · OPEN ANOTHER · DONE.
-- Tapping during 1–3 jumps to the pop; repeat openings start at the fuse (no forced long version).
-- Listens to the server's Reward { kind = "Crate", crate, item, rarity, duplicate, refund } (StoreService).
-- Implements: F-STORE-07 (duplicate refund shown), F-STORE-10.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Progress = require(script.Parent.Parent.Progress)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Sfx = require(script.Parent.Parent.Sfx)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local St = Config.Store
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local CrateController = {}

local RARITY_COLOR = {
	Common = Color3.fromRGB(220, 228, 240),
	Rare = Color3.fromRGB(64, 176, 255),
	Epic = Color3.fromRGB(176, 96, 255),
	Legendary = Color3.fromRGB(255, 196, 40),
	Exclusive = Color3.fromRGB(255, 92, 186),
}
local CATEGORY_ICON = {
	BombSkin = "Palette",
	Explosion = "Explosion",
	FuseSpark = "Sparkler",
	Trail = "Trail",
	VictoryBoom = "Firework",
	Title = "Plate",
	Emote = "Wave",
}

local gui: ScreenGui
local busy = false
local seen: { [string]: boolean } = {} -- crate kinds already opened this session (skip the drop next time)

local function tween(
	o: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tw =
		TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- The crate model for a kind (falls back to the Spark Crate until the others are modelled).
local function crateModel(kind: string): Model?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local crates = art and art:FindFirstChild("Crates")
	local m = crates and (crates:FindFirstChild(kind) or crates:FindFirstChild("Spark"))
	return if m and m:IsA("Model") then m:Clone() else nil
end

-- 2D bursts: confetti-sparks flying out of a screen point, in the rarity colour.
local function burst(parent: Instance, at: UDim2, color: Color3, count: number)
	for i = 1, count do
		local a = math.random() * math.pi * 2
		local d = 180 + math.random() * 260
		local sz = 10 + math.random() * 16
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Size = UDim2.fromOffset(sz, sz * (0.5 + math.random())),
			Rotation = math.random(0, 360),
			BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color,
			ZIndex = 30,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = f })
		new("UIStroke", { Color = P.Ink, Thickness = 1.5, Transparency = 0.3, Parent = f })
		local goal = at + UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d * 0.8 + 60)
		tween(f, 0.9 + math.random() * 0.4, { Position = goal, Rotation = f.Rotation + math.random(-400, 400) })
		task.delay(0.6, function()
			tween(f, 0.5, { BackgroundTransparency = 1 })
		end)
		task.delay(1.4, function()
			f:Destroy()
		end)
	end
end

-- The light-ray fan behind the reveal (Legendary, and softer for the rest).
local function rays(parent: Instance, color: Color3, strong: boolean): Frame
	return Widgets.rays(parent, color, strong, UDim2.fromScale(0.5, 0.44))
end

local function itemArt(parent: Instance, item: { [string]: any })
	if item.category == "BombSkin" then
		local art = ReplicatedStorage:FindFirstChild("FV_Art")
		local template = art and art:FindFirstChild("Bomb")
		if template then
			local vf = new("ViewportFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Ambient = Color3.fromRGB(160, 150, 170),
				LightColor = Color3.fromRGB(255, 240, 220),
				LightDirection = Vector3.new(-0.6, -1, -0.8),
				ZIndex = 12,
				Parent = parent,
			}) :: ViewportFrame
			local m = (template :: Model):Clone()
			SkinApply.apply(m, item.id)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					if string.match(d.Name, "^SeamGlow") then
						d.Transparency = 1
					end
				end
			end
			m:PivotTo(CFrame.new())
			m.Parent = vf
			local cam = new("Camera", { FieldOfView = 30, Parent = vf }) :: Camera
			vf.CurrentCamera = cam
			task.spawn(function()
				while vf.Parent do
					local a = os.clock() * 0.9
					cam.CFrame =
						CFrame.lookAt(Vector3.new(math.sin(a) * 7, 1.4, math.cos(a) * 7), Vector3.new(0, 0.3, 0))
					RunService.RenderStepped:Wait()
				end
			end)
			return
		end
	end
	if item.category == "Title" then
		local plate = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = P.Brass,
			ZIndex = 12,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = plate })
		new("UIStroke", { Color = P.Ink, Thickness = 4, Parent = plate })
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 226, 140), Color3.fromRGB(196, 140, 48)),
			Rotation = 90,
			Parent = plate,
		})
		Widgets.label(plate, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 32,
			font = Theme.Font.Display,
			color = Color3.fromRGB(70, 40, 10),
			stroke = false,
			Text = item.name,
			ZIndex = 13,
		})
		return
	end
	Widgets.icon(parent, CATEGORY_ICON[item.category] or "Star", 200, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 12,
	})
end

-- Swing the lid (LidWood / LidBrass / Spark) about the hinge by `deg` from closed.
local function lidPose(_model: Model, closed: { [BasePart]: CFrame }, hinge: Vector3, axis: Vector3, deg: number)
	local rot = CFrame.new(hinge) * CFrame.fromAxisAngle(axis, math.rad(deg)) * CFrame.new(-hinge)
	for part, cf in pairs(closed) do
		part.CFrame = rot * cf
	end
end

local function open(r: { [string]: any })
	if busy then
		return
	end
	local item = St.ById[r.item]
	if not item then
		return
	end
	busy = true
	Modal.set("Crate", true)
	local color = RARITY_COLOR[r.rarity] or RARITY_COLOR.Common
	local quick = seen[r.crate] == true
	seen[r.crate] = true

	local root = new("Frame", {
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 10, 18),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(40, 34, 60), Color3.fromRGB(8, 6, 12)),
		Rotation = 90,
		Parent = root,
	})
	tween(root, 0.25, { BackgroundTransparency = 0.08 })
	local skip = false
	local tap = new("TextButton", {
		Name = "Tap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = root,
	})
	tap.Activated:Connect(function()
		skip = true
	end)
	local hint = Widgets.label(root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(400, 28),
		TextSize = 22,
		font = Theme.Font.Display,
		color = Color3.fromRGB(200, 196, 220),
		stroke = 2.5,
		Text = "Tap to open",
		ZIndex = 5,
	})
	local title = Widgets.label(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(600, 60),
		TextSize = 54,
		font = Theme.Font.Display,
		stroke = 4,
		Text = string.upper((St.CRATES[r.crate] and St.CRATES[r.crate].name) or "Crate"),
		ZIndex = 5,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 176, 40)),
		Rotation = 90,
		Parent = title,
	})

	-- the 3D stage
	local vf = new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(620, 520),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 170),
		LightColor = Color3.fromRGB(255, 236, 214),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = 4,
		Parent = root,
	}) :: ViewportFrame
	local cam = new("Camera", { FieldOfView = 34, Parent = vf }) :: Camera
	vf.CurrentCamera = cam
	local model = crateModel(r.crate)
	local closed: { [BasePart]: CFrame } = {}
	local hinge = Vector3.new(0, 1.5, 1.25)
	local axis = Vector3.xAxis
	local glow: BasePart? = nil
	local spark: BasePart? = nil
	if model then
		model:PivotTo(CFrame.new())
		model.Parent = vf
		local h = model:FindFirstChild("Hinge", true)
		if h and h:IsA("Attachment") then
			hinge = h.WorldPosition
		end
		for _, n in ipairs({ "LidWood", "LidBrass", "Spark" }) do
			local p = model:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				closed[p] = p.CFrame
			end
		end
		local g = model:FindFirstChild("InnerGlow")
		glow = if g and g:IsA("BasePart") then g else nil
		local s = model:FindFirstChild("Spark")
		spark = if s and s:IsA("BasePart") then s else nil
		if glow then
			glow.Color = color
		end
		if spark then
			spark.Transparency = 1
		end
	end
	local look = Vector3.new(0, 1.2, 0)
	local camFrom = Vector3.new(5.5, 4.2, -9.5) -- the crate's front is -Z
	cam.CFrame = CFrame.lookAt(camFrom, look)

	local function hold(t: number): boolean
		local t0 = os.clock()
		while os.clock() - t0 < t do
			if skip then
				return true
			end
			RunService.RenderStepped:Wait()
		end
		return skip
	end

	-- 1. DROP (first opening of this kind only)
	if model and not quick then
		local t0 = os.clock()
		local fell = false
		while not fell do
			local a = math.min(1, (os.clock() - t0) / 0.45)
			model:PivotTo(CFrame.new(0, 9 * (1 - a * a), 0))
			if a >= 1 then
				fell = true
			end
			RunService.RenderStepped:Wait()
		end
		Sfx.play("BoomBody", 0.35, 1.6)
		local sc = new("UIScale", { Parent = vf })
		sc.Scale = 1.06
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		hold(0.35)
	end
	-- 2. FUSE + push-in
	if spark then
		spark.Transparency = 0
	end
	Sfx.play("FuseHiss", 0.6)
	Sfx.play("BombIgnite", 0.8)
	local rattle = Sfx.loop("CrateRattle", nil)
	local pushT0 = os.clock()
	-- 3. TENSION: rattle with growing amplitude, the lid lifting a crack and leaking the rarity light
	local tension = if skip then 0 else 1.6
	local t0 = os.clock()
	while os.clock() - t0 < tension and not skip do
		local a = (os.clock() - t0) / tension
		local p = math.min(1, (os.clock() - pushT0) / 1.6)
		cam.CFrame = CFrame.lookAt(camFrom:Lerp(Vector3.new(3.6, 3.2, -6.6), p), look)
		if model then
			local shake = 0.03 + a * 0.12
			model:PivotTo(
				CFrame.new(math.noise(os.clock() * 30, 1) * shake, 0, math.noise(os.clock() * 30, 2) * shake)
					* CFrame.Angles(0, 0, math.noise(os.clock() * 25, 3) * shake * 0.6)
			)
			lidPose(model, closed, hinge, axis, -(math.abs(math.sin(os.clock() * 22)) * (2 + a * 9)))
			if glow then
				glow.Transparency = 0
			end
		end
		if rattle then
			rattle.PlaybackSpeed = 0.9 + a * 0.5
			rattle.Volume = 0.3 + a * 0.4
		end
		RunService.RenderStepped:Wait()
	end
	if rattle then
		rattle:Destroy()
	end
	-- 4. POP
	hint.Visible = false
	if model then
		model:PivotTo(CFrame.new())
		task.spawn(function()
			local s0 = os.clock()
			while os.clock() - s0 < 0.35 do
				local a = (os.clock() - s0) / 0.35
				lidPose(model, closed, hinge, axis, -115 * (1 - (1 - a) ^ 3))
				RunService.RenderStepped:Wait()
			end
			lidPose(model, closed, hinge, axis, -115)
		end)
	end
	Sfx.play("CratePop")
	Sfx.play("Claim")
	if r.rarity == "Legendary" or r.rarity == "Exclusive" then
		Sfx.play("CrateLegendary")
	end
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		ZIndex = 40,
		Parent = root,
	})
	tween(flash, 0.4, { BackgroundTransparency = 1 })
	burst(root, UDim2.fromScale(0.5, 0.5), color, if r.rarity == "Legendary" then 60 else 34)
	local fan = rays(root, color, r.rarity == "Legendary" or r.rarity == "Epic")
	task.wait(0.35)
	-- the crate sinks away, the item rises on its beam
	tween(vf, 0.3, { Position = UDim2.fromScale(0.5, 0.95), ImageTransparency = 0.4 })
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = root,
	})
	itemArt(card, item)
	tween(card, 0.5, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	Widgets.springIn(card, 0.3)
	-- name plate + rarity banner
	local banner = Theme.panel(root, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 18),
		Size = UDim2.fromOffset(420, 92),
		color = color:Lerp(Color3.new(1, 1, 1), 0.2),
		color2 = color:Lerp(P.Ink, 0.25),
		border = Color3.new(1, 1, 1),
		glow = color,
		glowT = 0.5,
	})
	local bh = banner.Parent :: Frame
	bh.ZIndex = 12
	Widgets.label(banner, {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 38,
		font = Theme.Font.Display,
		stroke = 3.5,
		Text = item.name,
		ZIndex = 14,
	})
	Widgets.label(banner, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 24,
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = string.upper(r.rarity) .. "  ·  " .. (St.CATEGORY_NAME[item.category] or ""),
		ZIndex = 14,
	})
	Widgets.springIn(bh, 0.6)
	if r.duplicate then
		Widgets.label(root, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.62, 116),
			Size = UDim2.fromOffset(420, 30),
			TextSize = 26,
			font = Theme.Font.Display,
			color = P.Spark,
			stroke = 3,
			Text = Config.Strings.Ui.DuplicateRefund:format(r.refund or 0),
			ZIndex = 14,
		})
	end
	-- buttons
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(620, 56),
		BackgroundTransparency = 1,
		ZIndex = 14,
		Parent = root,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
		Parent = row,
	})
	local function close()
		Modal.set("Crate", false)
		tween(root, 0.18, { BackgroundTransparency = 1 })
		Widgets.springOut(row)
		task.delay(0.18, function()
			root:Destroy()
			busy = false
		end)
		fan:Destroy()
	end
	if not r.duplicate then
		Widgets.button(row, Config.Strings.Ui.Equip, "cyan", UDim2.fromOffset(170, 54), function()
			Net.send("StoreAction", { kind = "Equip", id = r.item })
			close()
		end, { TextSize = 26, ZIndex = 15 })
	end
	local crate = St.CRATES[r.crate]
	local s = Progress.get()
	if crate and not crate.free and s and (s.stars or 0) >= crate.stars then
		Widgets.button(row, Config.Strings.Ui.OpenAnother, "green", UDim2.fromOffset(230, 54), function()
			close()
			task.delay(0.25, function()
				Net.send("StoreAction", { kind = "OpenCrate", crate = r.crate, source = "Stars" })
			end)
		end, { TextSize = 26, ZIndex = 15 })
	end
	Widgets.button(
		row,
		Config.Strings.Ui.DoneButton,
		"dark",
		UDim2.fromOffset(150, 54),
		close,
		{ TextSize = 26, ZIndex = 15 }
	)
end

function CrateController.start()
	gui = new("ScreenGui", {
		Name = "FV_Crate",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.listen("Reward", function(r)
		if type(r) == "table" and r.kind == "Crate" then
			task.spawn(open, r)
		end
	end)
	-- Studio: set the player's FV_PreviewCrate attribute to "Spark|Skin_Galaxy|Legendary" to watch the sequence
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("FV_PreviewCrate"):Connect(function()
			local v = player:GetAttribute("FV_PreviewCrate")
			if type(v) == "string" and v ~= "" then
				local crate, item, rarity = string.match(v, "^(%w+)|([%w_]+)|(%w+)$")
				if crate then
					CrateController.preview(crate, item :: string, rarity :: string)
				end
			end
		end)
	end
end

-- Studio: play the sequence without spending anything (CrateController.preview("Spark", "Skin_Galaxy", "Legendary")).
function CrateController.preview(crate: string, item: string, rarity: string)
	task.spawn(open, { kind = "Crate", crate = crate, item = item, rarity = rarity, duplicate = false, refund = 0 })
end

return CrateController
