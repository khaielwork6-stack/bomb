--!strict
-- The Starter Bundle offer (GDD §17.5 F-STORE-11), in the reference video's "STARTER PACK" card: a rainbow card with
-- the contents as three tiles (1,500 Stars · the Rookie Brass bomb skin, live in 3D · the "Fresh Fuse" title), the
-- 48 h countdown, the struck-through value next to the real Robux price on a big green button, and a tilted
-- "x3 VALUE" burst. When it pops is the server's call (`store.starter.popup`): StoreController's popStarter opens it
-- with OfferController.open at the first calm moment of the intermission after the 3rd round's results; the server
-- only sends `store.starter` while the offer is live (and only once the product exists on the dashboard). It closes
-- itself if the offer goes away (bought, or the 48 h ran out).
-- Implements: F-STORE-11 (presentation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Progress = require(script.Parent.Parent.Progress)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Sfx = require(script.Parent.Parent.Sfx)
local Modal = require(script.Parent.Parent.UI.Modal)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local St = Config.Store
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local OfferController = {}

local gui: ScreenGui
local open = false
local closeCard: (() -> ())? = nil

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 150)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 186, 80)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 236, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 230, 140)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 180, 255)),
})

local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	return ("%02d:%02d:%02d"):format(sec // 3600, (sec % 3600) // 60, sec % 60)
end

local function tile(parent: Instance, title: string, order: number): Frame
	local face = Theme.panel(parent, {
		Name = title,
		Size = UDim2.fromOffset(150, 170),
		color = Color3.fromRGB(58, 52, 84),
		color2 = Color3.fromRGB(30, 27, 46),
		border = Color3.new(1, 1, 1),
	});
	(face.Parent :: Frame).LayoutOrder = order
	Widgets.label(face, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -10, 0, 26),
		TextSize = 22,
		font = Theme.Font.Display,
		stroke = 2.5,
		color = P.Spark,
		Text = title,
		ZIndex = 6,
	})
	return face
end

local function show(endsIn: number, preview: boolean?)
	if open then
		return
	end
	open = true
	Modal.set("Offer", true)
	for _, c in ipairs(gui:GetChildren()) do
		c:Destroy()
	end
	local back = Widgets.backdrop(gui, 0.35)
	local card = Theme.panel(gui, {
		Name = "Starter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(620, 380),
		color = Color3.new(1, 1, 1),
		border = Color3.new(1, 1, 1),
		dots = Color3.new(1, 1, 1),
		dotsT = 0.75,
	})
	local holder = card.Parent :: Frame
	holder.ZIndex = 5
	local layers = Theme.layers(card)
	local g = layers and layers.fill and layers.fill:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = RAINBOW
		g.Rotation = 20
	end
	local fit = math.min(1, (workspace.CurrentCamera.ViewportSize.Y - 60) / 400)
	new("UIScale", { Name = "Fit", Scale = fit, Parent = holder })
	-- header: title plate across the top
	Skin.ribbon(holder, "STARTER PACK", Color3.fromRGB(255, 120, 60), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(360, 64),
		ZIndex = 9,
	})
	local timer = Widgets.label(card, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(400, 26),
		TextSize = 22,
		font = Theme.Font.Display,
		stroke = 2.5,
		color = Color3.fromRGB(255, 70, 60),
		Text = "OFFER ENDS IN " .. clock(endsIn),
		ZIndex = 8,
	})
	-- the x3 VALUE burst
	local burst = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(104, 62),
		Rotation = -14,
		BackgroundColor3 = Color3.fromRGB(236, 44, 44),
		ZIndex = 10,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = burst })
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Parent = burst })
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 120, 100), Color3.fromRGB(200, 20, 30)),
		Rotation = 90,
		Parent = burst,
	})
	Widgets.label(burst, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 24,
		font = Theme.Font.Display,
		stroke = 3,
		Text = "x3\nVALUE",
		ZIndex = 11,
	})
	-- contents
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(500, 170),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = card,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local product = St.PRODUCTS.StarterBundle
	local t1 = tile(row, "Stars", 1)
	Widgets.icon(
		t1,
		"GemChest",
		96,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), ZIndex = 7 }
	)
	Widgets.label(t1, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 26,
		font = Theme.Font.Display,
		stroke = 3,
		Text = "x" .. tostring(product.stars),
		ZIndex = 8,
	})
	local skinId = product.items and product.items[1] or "Skin_RookieBrass"
	local t2 = tile(row, "Bomb Skin", 2)
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb")
	if template then
		local vf = new("ViewportFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(130, 110),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(160, 150, 170),
			LightColor = Color3.fromRGB(255, 240, 220),
			LightDirection = Vector3.new(-0.6, -1, -0.8),
			ZIndex = 7,
			Parent = t2,
		}) :: ViewportFrame
		local m = (template :: Model):Clone()
		SkinApply.apply(m, skinId)
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
				local a = os.clock() * 0.8
				cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 7, 1.4, math.cos(a) * 7), Vector3.new(0, 0.3, 0))
				RunService.RenderStepped:Wait()
			end
		end)
	end
	local skinItem = St.ById[skinId]
	Widgets.label(t2, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -8, 0, 24),
		TextSize = 20,
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = if skinItem then skinItem.name else "Rookie Brass",
		ZIndex = 8,
	})
	local titleId = product.items and product.items[2] or "Title_FreshFuse"
	local titleItem = St.ById[titleId]
	local t3 = tile(row, "Title", 3)
	local plate = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(132, 40),
		BackgroundColor3 = P.Brass,
		ZIndex = 7,
		Parent = t3,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = plate })
	new("UIStroke", { Color = P.Ink, Thickness = 3, Parent = plate })
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 140), Color3.fromRGB(196, 140, 48)),
		Rotation = 90,
		Parent = plate,
	})
	Widgets.label(plate, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		font = Theme.Font.Display,
		color = Color3.fromRGB(70, 40, 10),
		stroke = false,
		Text = if titleItem then titleItem.name else "Fresh Fuse",
		ZIndex = 8,
	})
	-- price: the struck-through value, then the real price on the big green button
	local value = math.floor(product.robux * 3.5)
	local was = Widgets.label(card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.5, -110, 1, -48),
		Size = UDim2.fromOffset(18 * #tostring(value) + 6, 34),
		TextSize = 30,
		font = Theme.Font.Display,
		stroke = 3,
		Text = tostring(value),
		ZIndex = 8,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 4),
		Rotation = -12,
		BackgroundColor3 = Color3.fromRGB(240, 40, 40),
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = was,
	})
	local function close()
		closeCard = nil
		open = false
		Modal.set("Offer", false)
		Widgets.springOut(holder, function()
			for _, c in ipairs(gui:GetChildren()) do
				c:Destroy()
			end
		end)
	end
	closeCard = close
	local buy = Widgets.button(card, "", "green", UDim2.fromOffset(200, 60), function()
		if not preview then
			Net.send("StoreAction", { kind = "BuyProduct", product = "StarterBundle" })
		end
		close()
	end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -48), ZIndex = 10 })
	local inner = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12, Parent = buy })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = inner,
	})
	new("ImageLabel", {
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Image = Skin.Tex.Robux,
		ZIndex = 13,
		Parent = inner,
	})
	Widgets.label(inner, {
		Size = UDim2.fromOffset(70, 40),
		TextSize = 36,
		font = Theme.Font.Display,
		stroke = 3,
		Text = tostring(product.robux),
		ZIndex = 13,
	})
	Widgets.label(card, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, 116, 1, -48),
		Size = UDim2.fromOffset(150, 50),
		TextSize = 24,
		font = Theme.Font.Display,
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		Text = "MEGA\nDEAL",
		ZIndex = 8,
	})
	local x = Skin.close(holder, 52, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		ZIndex = 12,
	})
	x.Activated:Connect(function()
		Sfx.play("UiClose")
		close()
	end)
	back.MouseButton1Click:Connect(close)
	Widgets.springIn(holder)
	Sfx.play("UiOpen")
	task.spawn(function()
		local t0 = os.clock()
		while open and timer.Parent do
			timer.Text = "OFFER ENDS IN " .. clock(endsIn - (os.clock() - t0))
			task.wait(0.5)
		end
	end)
end

-- Open the card (StoreController.popStarter decides when). Returns false if one is already up.
function OfferController.open(endsIn: number): boolean
	if open then
		return false
	end
	show(endsIn)
	return true
end

function OfferController.start()
	gui = new("ScreenGui", {
		Name = "FV_Offer",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 24,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Progress.start()
	Progress.Changed:Connect(function(st)
		if open and not (st and st.store and st.store.starter) and closeCard then
			closeCard()
		end
	end)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("FV_PreviewOffer"):Connect(function()
			if player:GetAttribute("FV_PreviewOffer") then
				show(48 * 3600 - 5, true)
			end
		end)
	end
end

return OfferController
