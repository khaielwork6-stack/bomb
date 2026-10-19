--!strict
-- The spin wheel screen (the owner's reference video; DECISIONS 2026-10-17 "extras"): the big studded wheel
-- (art/ui/make_wheel.py) with each prize's icon and amount riding its segment, the gold 3D arrow as the pointer,
-- ODDS (the weights as percentages, always shown — the same honesty rule as crates, F-STORE-06), +1 Spin / SPIN [n] /
-- +5 Spins, and the free-spin countdown. A spin eases round SPIN_TURNS times onto the server's result, ticking as
-- each divider passes the pointer, then the prize pops with confetti.
-- Server side (the free timer, the roll, the products, the payout) is the partner's: docs/PARTNER_REQUESTS.md #2 —
-- this reads `wheel = { spins, freeIn }` from the Progress snapshot, fires the `Spin` remote and lands on the
-- Reward { kind = "Wheel", segment } reply. Opened by the lobby wheel's prompt (attribute FV_Open = "Wheel") or
-- WheelController.open(). Studio preview: the player's FV_PreviewWheel attribute (spins land on weighted randoms;
-- set it to "spin" while open to press SPIN).
-- Implements: the spin wheel (client).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Modal = require(script.Parent.Parent.UI.Modal)
local Screen = require(script.Parent.Parent.UI.Screen)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local TitleArt = require(script.Parent.Parent.UI.TitleArt)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local W = Config.Wheel
local S = Config.Strings
local St = Config.Store
local new = Theme.new
local player = Players.LocalPlayer

local WheelController = {}

local gui: ScreenGui
local root: Frame? = nil
local wheel: Frame
local spinning = false
local preview = false
local previewSpins = 3
local pendingSegment: number? = nil

local function segIcon(seg: { [string]: any }): string
	if seg.kind == "Crate" then
		return if seg.crate == "GiftBox" then "GiftBox" elseif seg.crate == "Inferno" then "CrateInferno" else "Crate"
	end
	return "Gem"
end

local function segText(seg: { [string]: any }): string
	if seg.kind == "Stars" then
		return tostring(seg.amount)
	end
	local c = St.CRATES[seg.crate or ""]
	return if c then string.upper(c.name) else S.Ui.CrateFallback
end

local function totalWeight(): number
	local t = 0
	for _, s in ipairs(W.SEGMENTS) do
		t += s.weight
	end
	return t
end

local function spinsLeft(): (number, number?)
	if preview then
		return previewSpins, nil
	end
	local s = Progress.get()
	local wd = s and (s :: any).wheel
	if type(wd) == "table" then
		return wd.spins or 0, if type(wd.freeIn) == "number" then wd.freeIn - Progress.age() else nil
	end
	return 0, nil
end

local function close()
	local r = root
	root = nil
	if r then
		Modal.set("Wheel", false)
		Sfx.play("UiClose")
		Widgets.springOut(r, function()
			r:Destroy()
		end)
	end
end

-- Ease the wheel onto segment `i` (1 = 12 o'clock, clockwise): the pointer is fixed at the top, so the wheel turns
-- the segment's centre back to 0°.
local function spinTo(i: number, done: () -> ())
	spinning = true
	local n = #W.SEGMENTS
	local seg = 360 / n
	local target = -((i - 1) * seg) + math.random(-14, 14)
	local from = wheel.Rotation % 360
	local to = target - W.SPIN_TURNS * 360
	while to > from - W.SPIN_TURNS * 360 do
		to -= 360
	end
	local t0 = os.clock()
	local lastDivider = math.floor((from + seg / 2) / seg)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / W.SPIN_TIME, 0, 1)
		local e = 1 - (1 - a) ^ 4
		local rot = from + (to - from) * e
		wheel.Rotation = rot
		local d = math.floor((rot + seg / 2) / seg)
		if d ~= lastDivider then
			lastDivider = d
			Sfx.play("UiTab", 0.55, 1 + (1 - a) * 0.4)
		end
		if a >= 1 then
			conn:Disconnect()
			spinning = false
			done()
		end
	end)
end

local function celebrate(i: number)
	local r = root
	if not r then
		return
	end
	local seg = W.SEGMENTS[i]
	Sfx.play("Claim")
	if seg.kind == "Stars" and seg.amount >= 100 then
		Sfx.play("CrateLegendary", 0.7)
	end
	local pop = Theme.panel(r, {
		Name = "Won",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(340, 170),
		color = Color3.fromRGB(255, 226, 110),
		color2 = Color3.fromRGB(255, 150, 30),
		border = Color3.new(1, 1, 1),
		glow = Color3.fromRGB(255, 220, 80),
		glowT = 0.4,
	})
	local holder = pop.Parent :: Frame
	holder.ZIndex = 30
	-- YOU WON! as title art across the card's top edge (the plain label only if the art is missing)
	if TitleArt.has("YouWon") then
		TitleArt.show(holder, "YouWon", { tier = "Callout", y = 0, hold = 0, zIndex = 33 })
	else
		Widgets.label(pop, {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 36,
			font = Theme.Font.Display,
			stroke = 3.5,
			Text = S.Ui.YouWon,
			ZIndex = 32,
		})
	end
	Widgets.icon(pop, segIcon(seg), 80, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0, 104),
		ZIndex = 32,
	})
	Widgets.label(pop, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 130, 0, 104),
		Size = UDim2.fromOffset(190, 50),
		TextSize = if seg.kind == "Stars" then 46 else 24,
		font = Theme.Font.Display,
		stroke = 3.5,
		align = Enum.TextXAlignment.Left,
		Text = segText(seg),
		ZIndex = 32,
	})
	Widgets.springIn(holder, 0.4)
	for _ = 1, 30 do
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(12, 7),
			Rotation = math.random(0, 360),
			BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1),
			ZIndex = 31,
			Parent = r,
		})
		local a = math.random() * math.pi * 2
		local d = 160 + math.random() * 220
		TweenService:Create(f, TweenInfo.new(1 + math.random() * 0.4, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, math.cos(a) * d, 0.46, math.sin(a) * d + 80),
			Rotation = f.Rotation + 360,
			BackgroundTransparency = 1,
		}):Play()
		task.delay(1.5, function()
			f:Destroy()
		end)
	end
	task.delay(2.4, function()
		if holder.Parent then
			Widgets.springOut(holder, function()
				holder:Destroy()
			end)
		end
	end)
end

local function weightedRandom(): number
	local roll = math.random() * totalWeight()
	for i, s in ipairs(W.SEGMENTS) do
		roll -= s.weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

local function trySpin()
	if spinning then
		return
	end
	local n = spinsLeft()
	if n <= 0 then
		Sfx.play("UiDeny")
		return
	end
	Sfx.play("UiPress")
	if preview then
		previewSpins -= 1
		local i = weightedRandom()
		spinTo(i, function()
			celebrate(i)
		end)
		return
	end
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("Spin")
	if remote and remote:IsA("RemoteEvent") then
		pendingSegment = nil
		remote:FireServer()
		-- spin freely until the server answers, then land
		spinning = true
		task.spawn(function()
			local t0 = os.clock()
			while pendingSegment == nil and os.clock() - t0 < 4 do
				wheel.Rotation -= 14
				RunService.RenderStepped:Wait()
			end
			spinning = false
			local seg = pendingSegment
			if seg then
				spinTo(seg, function()
					celebrate(seg)
				end)
			end
		end)
	end
end

function WheelController.open()
	if root then
		return
	end
	Modal.set("Wheel", true)
	local r = new("Frame", {
		Name = "Wheel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	root = r
	local back = Widgets.backdrop(r, 0.45)
	back.MouseButton1Click:Connect(close)
	local stage = new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(560, 640),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = r,
	})
	Screen.fit(stage, function(vp)
		return math.min(1, (vp.Y - 40) / 660, (vp.X - 40) / 580)
	end)
	Widgets.label(stage, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(560, 50),
		TextSize = 46,
		font = Theme.Font.Display,
		stroke = 4,
		Text = S.Ui.WheelTitle,
		ZIndex = 4,
	})
	-- the wheel and its prize labels (children rotate with it)
	wheel = new("ImageLabel", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 330),
		Size = UDim2.fromOffset(470, 470),
		BackgroundTransparency = 1,
		Image = Assets.Ui.WheelFace,
		ZIndex = 4,
		Parent = stage,
	})
	local n = #W.SEGMENTS
	for i, seg in ipairs(W.SEGMENTS) do
		local a = (i - 1) * (360 / n)
		local arm = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Rotation = a,
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = wheel,
		})
		Widgets.icon(arm, segIcon(seg), 58, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.17),
			ZIndex = 6,
		})
		Widgets.label(arm, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.29),
			Size = UDim2.fromOffset(110, 26),
			TextSize = if seg.kind == "Stars" then 26 else 15,
			font = Theme.Font.Display,
			stroke = 2.5,
			Text = segText(seg),
			ZIndex = 6,
		})
	end
	-- the pointer: the gold 3D arrow pointing down at 12 o'clock
	Widgets.icon(stage, "Arrow", 84, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 92),
		Rotation = 90,
		ZIndex = 8,
	})
	-- ODDS + close
	local oddsOpen = false
	local oddsPanel: Frame? = nil
	Widgets.button(stage, S.Ui.Odds, "cyan", UDim2.fromOffset(96, 40), function()
		oddsOpen = not oddsOpen
		if oddsPanel then
			oddsPanel:Destroy()
			oddsPanel = nil
		end
		if oddsOpen then
			local face = Theme.panel(stage, {
				Name = "OddsList",
				Position = UDim2.fromOffset(-210, 110),
				Size = UDim2.fromOffset(200, 34 * n + 20),
			})
			oddsPanel = face.Parent :: Frame
			local tw = totalWeight()
			for i, seg in ipairs(W.SEGMENTS) do
				Widgets.label(face, {
					Position = UDim2.fromOffset(14, 10 + (i - 1) * 34),
					Size = UDim2.new(1, -28, 0, 30),
					TextSize = 20,
					font = Theme.Font.Display,
					stroke = 2,
					align = Enum.TextXAlignment.Left,
					Text = ("%s   %d%%"):format(segText(seg), math.floor(seg.weight / tw * 100 + 0.5)),
					ZIndex = 9,
				})
			end
		end
	end, { Position = UDim2.fromOffset(10, 80), TextSize = 20, ZIndex = 8 })
	local x = Skin.close(stage, 52, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 76), ZIndex = 8 })
	x.Activated:Connect(close)
	-- the spin row
	local row = new("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(560, 56),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = stage,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local function buy(key: string)
		local net = ReplicatedStorage:FindFirstChild("Net")
		local remote = net and net:FindFirstChild("StoreAction")
		if remote and (Config.Store.PRODUCTS :: any)[key].id ~= 0 then
			Net.send("StoreAction", { kind = "BuyProduct", product = key })
		else
			Sfx.play("UiDeny")
		end
	end
	if Config.Store.PRODUCTS.Spin1.id ~= 0 or preview then
		Widgets.button(row, S.Ui.SpinOne, "purple", UDim2.fromOffset(130, 46), function()
			buy("Spin1")
		end, { TextSize = 22, LayoutOrder = 1, ZIndex = 7 })
	end
	local spinBtn = Widgets.button(row, "", "gold", UDim2.fromOffset(170, 56), trySpin, { LayoutOrder = 2, ZIndex = 7 })
	spinBtn.Name = "Spin"
	local spinLabel = Widgets.label(spinBtn, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 30,
		font = Theme.Font.Display,
		stroke = 3,
		Text = S.Ui.Spin,
		ZIndex = 9,
	})
	if Config.Store.PRODUCTS.Spin5.id ~= 0 or preview then
		Widgets.button(row, S.Ui.SpinFive, "purple", UDim2.fromOffset(130, 46), function()
			buy("Spin5")
		end, { TextSize = 22, LayoutOrder = 3, ZIndex = 7 })
	end
	local free = Widgets.label(stage, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(400, 24),
		TextSize = 20,
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = "",
		ZIndex = 6,
	})
	Widgets.springIn(stage)
	Sfx.play("UiOpen")
	task.spawn(function()
		while root == r do
			local count, freeIn = spinsLeft()
			spinLabel.Text = ("%s [%d]"):format(S.Ui.Spin, count)
			if count > 0 then
				free.Text = S.Ui.FreeSpinReady
				free.TextColor3 = Color3.fromRGB(255, 230, 90)
			elseif freeIn then
				free.Text = S.Ui.FreeSpinIn:format(Widgets.clock(freeIn))
				free.TextColor3 = Color3.new(1, 1, 1)
			else
				free.Text = ""
			end
			task.wait(0.25)
		end
	end)
end

function WheelController.start()
	gui = new("ScreenGui", {
		Name = "FV_Wheel",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 22,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.listen("Reward", function(r)
		if type(r) == "table" and r.kind == "Wheel" and type(r.segment) == "number" then
			pendingSegment = r.segment
		end
	end)
	-- the lobby wheel's prompt (LobbyDepot puts FV_Open = "Wheel" on it)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt:GetAttribute("FV_Open") == "Wheel" then
			WheelController.open()
		end
	end)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("FV_PreviewWheel"):Connect(function()
			if player:GetAttribute("FV_PreviewWheel") == "spin" and root then -- Studio test hook: press SPIN
				trySpin()
			elseif player:GetAttribute("FV_PreviewWheel") then
				preview = true
				previewSpins = 3
				WheelController.open()
			end
		end)
	end
end

return WheelController
