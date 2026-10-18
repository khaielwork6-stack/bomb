--!strict
-- The Shop and the Locker (GDD §17, §21.3; Asset Bible §6, §7.4): category tabs down the left, item cards on the
-- right — bomb skins as live 3D previews of the real bomb wearing the skin (a slow turntable, its lamps pulsing
-- through LIT → HOT → CRITICAL), rarity frames, Stars prices with the daily DEAL; crates with their odds always shown
-- (F-STORE-06), the Inferno pity counter (F-STORE-08), and "Not available in your region" where paid random items
-- are restricted (F-STORE-09). Buying asks once; equipping is a tap. Only items whose art exists are ever listed.
-- Implements: F-STORE-03..09 (presentation), F-UI-04 (Shop, Locker).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Progress = require(script.Parent.Parent.Progress)
local BombFace = require(script.Parent.Parent.BombFace)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local DailyController = require(script.Parent.DailyController)

local St = Config.Store
local P = Theme.Palette
local new = Theme.new

local StoreController = {}

StoreController.RARITY = {
	Default = Color3.fromRGB(140, 132, 152),
	Common = Color3.fromRGB(169, 177, 194),
	Rare = Color3.fromRGB(51, 182, 255),
	Epic = Color3.fromRGB(166, 91, 255),
	Legendary = Color3.fromRGB(255, 182, 39),
	Exclusive = Color3.fromRGB(110, 96, 140),
}
local RARITY = StoreController.RARITY

local screen = "" -- "Shop" | "Locker" | ""
local tab = "Featured"
local viewports: { { vf: ViewportFrame, cam: Camera, model: Model, lamps: { BasePart } } } = {}

local function owned(s: { [string]: any }, id: string): boolean
	local item = St.ById[id]
	if not item then
		return false
	end
	if item.rarity == "Default" then
		return true
	end
	for _, o in ipairs(s.store and s.store.owned or {}) do
		if o == id then
			return true
		end
	end
	return false
end

local function equipped(s: { [string]: any }, id: string): boolean
	local item = St.ById[id]
	local eq = s.store and s.store.equipped
	if not item or not eq then
		return false
	end
	local cur = eq[item.category]
	if cur == nil or cur == "" then
		return St.DEFAULTS[item.category] == id
	end
	return cur == id
end

local function priceOf(s: { [string]: any }, id: string): (number?, boolean)
	local item = St.ById[id]
	local base = item and St.PRICE[item.rarity]
	if not base then
		return nil, false
	end
	local feat = s.store and s.store.featured
	if feat and feat[1] == id then
		return math.floor(base * (1 - St.DEAL_OFF) + 0.5), true
	end
	return base, false
end

-- ── Previews ────────────────────────────────────────────────────────────────────────────────────────────────────
local function bombPreview(parent: Instance, skinId: string): ViewportFrame?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb")
	if not template then
		return nil
	end
	local vf = new("ViewportFrame", {
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 160),
		LightColor = Color3.fromRGB(255, 236, 214),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = 4,
		Parent = parent,
	}) :: ViewportFrame
	local model = (template :: Model):Clone()
	SkinApply.apply(model, skinId)
	BombFace.pose(model, "SMUG") -- the face, as it ticks (Asset Bible §3.8)
	local lamps = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d.Name == "LampF" or d.Name == "LampB" then
				d.Material = Enum.Material.Neon
				table.insert(lamps, d)
			elseif string.match(d.Name, "^SeamGlow") then
				d.Transparency = 1
			elseif d.Name == "LensF" or d.Name == "LensB" then
				d.Material = Enum.Material.Glass
				d.Transparency = 0.45
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vf
	local cam = new("Camera", { FieldOfView = 30, Parent = vf }) :: Camera
	vf.CurrentCamera = cam
	table.insert(viewports, { vf = vf, cam = cam, model = model, lamps = lamps })
	return vf
end

local function spinPreviews()
	local t = os.clock()
	local alive = {}
	for _, v in ipairs(viewports) do
		if v.vf.Parent then
			table.insert(alive, v)
			local a = t * 0.7
			local pos = Vector3.new(math.sin(a) * 7.2, 1.6, math.cos(a) * 7.2)
			v.cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, 0.35, 0))
			-- the lamps run the ticking cycle: LIT (warm) → HOT (orange) → CRITICAL (white-hot flicker)
			local phase = (t % 6) / 6
			local col = if phase < 0.5 then P.Spark elseif phase < 0.8 then P.Fuse else Color3.new(1, 1, 1)
			local blink = if phase >= 0.8 then (math.sin(t * 40) > 0) else true
			for _, l in ipairs(v.lamps) do
				l.Color = col
				l.Transparency = if blink then 0 else 0.6
			end
		end
	end
	viewports = alive
end

-- ── Cards ───────────────────────────────────────────────────────────────────────────────────────────────────────
local confirmBuy: (id: string) -> ()

local function itemCard(parent: Instance, s: { [string]: any }, id: string, mode: string, order: number)
	local item = St.ById[id]
	if not item then
		return
	end
	local color = RARITY[item.rarity] or P.Ash
	local card = Theme.panel(parent, {
		Name = id,
		Size = UDim2.fromOffset(150, 206),
		color = Color3.fromRGB(40, 32, 52),
		border = color,
		border2 = color:Lerp(P.Ink, 0.45),
		glow = if item.rarity == "Legendary" or item.rarity == "Epic" then color else nil,
		glowT = 0.65,
	})
	local holder = card.Parent :: Frame
	holder.LayoutOrder = order
	local stage = new("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 112),
		BackgroundColor3 = P.Ink,
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = stage })
	new("UIGradient", {
		Color = ColorSequence.new(color:Lerp(P.Ink, 0.55), P.Ink),
		Rotation = 90,
		Parent = stage,
	})
	if item.category == "BombSkin" then
		bombPreview(stage, id)
	elseif item.category == "Title" then
		local plate = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 0, 34),
			BackgroundColor3 = P.Brass,
			ZIndex = 5,
			Parent = stage,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = plate })
		new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = plate })
		Widgets.label(plate, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 15,
			font = Theme.Font.Display,
			color = P.Ink,
			stroke = false,
			Text = item.name,
			ZIndex = 6,
		})
	end
	-- rarity strip + name
	local strip = new("Frame", {
		Position = UDim2.fromOffset(10, 126),
		Size = UDim2.new(1, -20, 0, 16),
		BackgroundColor3 = color,
		ZIndex = 4,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = strip })
	Widgets.label(strip, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 11,
		color = P.Ink,
		stroke = false,
		Text = string.upper(item.rarity),
		ZIndex = 5,
	})
	local name = Widgets.label(card, {
		Position = UDim2.fromOffset(6, 144),
		Size = UDim2.new(1, -12, 0, 22),
		TextSize = 15,
		Text = item.name,
		ZIndex = 4,
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	-- the action
	local has = owned(s, id)
	local action = new("Frame", {
		Position = UDim2.new(0, 10, 1, -40),
		Size = UDim2.new(1, -20, 0, 32),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	if mode == "Locker" or has then
		if equipped(s, id) then
			Widgets.label(action, {
				Size = UDim2.fromScale(1, 1),
				TextSize = 15,
				font = Theme.Font.Display,
				color = P.Safe,
				Text = "EQUIPPED",
				ZIndex = 5,
			})
		else
			Widgets.button(action, "EQUIP", "green", UDim2.fromScale(1, 1), function()
				Net.send("StoreAction", { kind = "Equip", id = id })
			end, { TextSize = 16, ZIndex = 6 })
		end
	else
		local price, deal = priceOf(s, id)
		if price then
			local b = Widgets.button(action, "", if deal then "gold" else "fuse", UDim2.fromScale(1, 1), function()
				confirmBuy(id)
			end, { ZIndex = 6 })
			local row = new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 9,
				Parent = b,
			})
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				Parent = row,
			})
			Widgets.icon(row, "Star", 22, { ZIndex = 10 })
			Widgets.label(row, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				TextSize = 17,
				font = Theme.Font.Display,
				Text = tostring(price),
				ZIndex = 10,
			})
			if deal then
				local tag = new("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 4, 0, -6),
					Size = UDim2.fromOffset(62, 22),
					BackgroundColor3 = P.Detonate,
					Rotation = 8,
					ZIndex = 8,
					Parent = holder,
				})
				new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = tag })
				new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = tag })
				Widgets.label(tag, {
					Size = UDim2.fromScale(1, 1),
					TextSize = 13,
					font = Theme.Font.Display,
					Text = ("DEAL -%d%%"):format(math.floor(St.DEAL_OFF * 100)),
					ZIndex = 9,
				})
			end
		end
	end
end

local function crateCard(parent: Instance, s: { [string]: any }, kind: string, order: number)
	local crate = St.CRATES[kind]
	local store = s.store or {}
	local card = Theme.panel(parent, {
		Name = kind,
		Size = UDim2.fromOffset(300, 206),
		color = Color3.fromRGB(52, 38, 30),
		border = if kind == "Inferno" then P.Fuse else P.Spark,
		border2 = P.Brass,
		glow = if kind == "Inferno" then P.Fuse else nil,
		glowT = 0.6,
	});
	(card.Parent :: Frame).LayoutOrder = order
	Widgets.icon(card, "Crate", 92, { Position = UDim2.fromOffset(10, 14), ZIndex = 5 })
	Widgets.label(card, {
		Position = UDim2.fromOffset(110, 10),
		Size = UDim2.fromOffset(180, 26),
		TextSize = 22,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		Text = string.upper(crate.name),
		ZIndex = 5,
	})
	-- the odds, always shown (F-STORE-06)
	local y = 40
	for _, r in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
		local p = crate.odds[r]
		if p then
			local dot = new("Frame", {
				Position = UDim2.fromOffset(112, y + 5),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = RARITY[r],
				ZIndex = 5,
				Parent = card,
			})
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
			Widgets.label(card, {
				Position = UDim2.fromOffset(128, y),
				Size = UDim2.fromOffset(160, 20),
				TextSize = 14,
				align = Enum.TextXAlignment.Left,
				Text = ("%s  %s%%"):format(r, tostring(math.floor(p * 1000 + 0.5) / 10)),
				stroke = 1.5,
				ZIndex = 5,
			})
			y += 20
		end
	end
	if crate.pity then
		Widgets.label(card, {
			Position = UDim2.fromOffset(12, 112),
			Size = UDim2.fromOffset(110, 18),
			TextSize = 13,
			color = P.Spark,
			align = Enum.TextXAlignment.Left,
			Text = ("Epic+ in %d"):format(math.max(1, crate.pity - (store.pity or 0))),
			ZIndex = 5,
		})
	end
	local row = new("Frame", {
		Position = UDim2.new(0, 10, 1, -46),
		Size = UDim2.new(1, -20, 0, 38),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = row,
	})
	local tokens = store.crates and store.crates[kind] or 0
	if tokens > 0 then
		Widgets.button(row, ("OPEN FREE x%d"):format(tokens), "green", UDim2.fromOffset(140, 38), function()
			Net.send("StoreAction", { kind = "OpenCrate", crate = kind, source = "Token" })
		end, { TextSize = 15, ZIndex = 6 })
	end
	if store.restricted then
		Widgets.label(row, {
			Size = UDim2.fromOffset(200, 38),
			TextSize = 13,
			color = P.Ash,
			wrap = true,
			Text = "Not available in your region",
			ZIndex = 6,
		})
	elseif not crate.free then
		local b, setOn = Widgets.button(row, "", "fuse", UDim2.fromOffset(120, 38), function()
			Net.send("StoreAction", { kind = "OpenCrate", crate = kind, source = "Stars" })
		end, { ZIndex = 6 })
		setOn((s.stars or 0) >= crate.stars)
		local inner = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9, Parent = b })
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			Parent = inner,
		})
		Widgets.icon(inner, "Star", 22, { ZIndex = 10 })
		Widgets.label(inner, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			TextSize = 17,
			font = Theme.Font.Display,
			Text = tostring(crate.stars),
			ZIndex = 10,
		})
	end
end

-- ── Screens ─────────────────────────────────────────────────────────────────────────────────────────────────────
local render: (refresh: boolean?) -> ()

local function tabsFor(s: { [string]: any }, mode: string): { string }
	local out = {}
	if mode == "Shop" then
		if #(s.store and s.store.featured or {}) > 0 then
			table.insert(out, "Featured")
		end
	end
	for _, cat in ipairs(St.CATEGORIES) do
		for _, it in ipairs(St.Items) do
			if it.category == cat then
				local show = if mode == "Shop"
					then Cosmetics.sellable(it.id)
					else owned(s, it.id) and Cosmetics.ready(it.id)
				if show then
					table.insert(out, cat)
					break
				end
			end
		end
	end
	if mode == "Shop" then
		table.insert(out, "Crates")
	end
	return out
end

render = function(refresh: boolean?)
	local s = Progress.get()
	if not s or screen == "" then
		return
	end
	table.clear(viewports)
	local face = DailyController.panel(
		screen,
		if screen == "Shop" then "SHOP" else "LOCKER",
		Vector2.new(780, 470),
		P.Fuse,
		refresh
	)
	local tabs = tabsFor(s, screen)
	if not table.find(tabs, tab) then
		tab = tabs[1] or "Crates"
	end
	-- tab column
	local col = new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(0, 150, 1, -60),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = face,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
	for i, t in ipairs(tabs) do
		local label = if t == "Featured" then "FEATURED" elseif t == "Crates" then "CRATES" else St.CATEGORY_NAME[t] or t
		local b = Widgets.button(col, label, if t == tab then "fuse" else "dark", UDim2.new(1, 0, 0, 40), function()
			tab = t
			render(true)
		end, { TextSize = 16, LayoutOrder = i, ZIndex = 4 })
		b.LayoutOrder = i
	end
	-- the grid
	local grid = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(184, 44),
		Size = UDim2.new(1, -200, 1, -60),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = P.Ash,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
		Parent = face,
	})
	new("UIGridLayout", {
		CellSize = if tab == "Crates" then UDim2.fromOffset(280, 206) else UDim2.fromOffset(136, 206),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), Parent = grid })
	if tab == "Crates" then
		crateCard(grid, s, "Spark", 1)
		crateCard(grid, s, "Inferno", 2)
		if (s.store and s.store.crates and s.store.crates.GiftBox or 0) > 0 then
			crateCard(grid, s, "GiftBox", 3)
		end
	elseif tab == "Featured" then
		for i, id in ipairs(s.store.featured) do
			itemCard(grid, s, id, screen, i)
		end
	else
		local order = 0
		for _, it in ipairs(St.Items) do
			if it.category == tab then
				local show = if screen == "Shop"
					then Cosmetics.sellable(it.id)
					else owned(s, it.id) and Cosmetics.ready(it.id)
				if show then
					order += 1
					itemCard(grid, s, it.id, screen, order)
				end
			end
		end
	end
end

local confirmOpen = false
confirmBuy = function(id: string)
	local s = Progress.get()
	local item = St.ById[id]
	if not s or not item or confirmOpen then
		return
	end
	local price = priceOf(s, id)
	if not price then
		return
	end
	confirmOpen = true
	local gui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"):FindFirstChild("FV_Daily") :: ScreenGui
	-- dims the shop behind (its cards otherwise read through the box); a tap outside cancels
	local back = Widgets.backdrop(gui, 0.35)
	back.ZIndex = 45
	local box = Theme.panel(gui, {
		Name = "Confirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 170),
		color = P.Ink2,
		border = RARITY[item.rarity] or P.Fuse,
		border2 = P.Ink,
	})
	local holder = box.Parent :: Frame
	holder.ZIndex = 50
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex += 40
		end
	end
	Widgets.label(box, {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(1, -32, 0, 60),
		TextSize = 20,
		wrap = true,
		Text = ("Buy %s for %d Stars?"):format(item.name, price),
		ZIndex = 60,
	})
	local function done()
		holder:Destroy()
	end
	-- also when the panel closes under it (a round starting clears the whole modal gui)
	holder.Destroying:Connect(function()
		confirmOpen = false
		back:Destroy()
	end)
	back.MouseButton1Click:Connect(done)
	local _, setOn = Widgets.button(box, "BUY", "green", UDim2.fromOffset(130, 44), function()
		Net.send("StoreAction", { kind = "Buy", id = id })
		done()
	end, { Position = UDim2.new(0, 24, 1, -60), TextSize = 20, ZIndex = 61 })
	setOn((s.stars or 0) >= price)
	Widgets.button(box, "CANCEL", "dark", UDim2.fromOffset(130, 44), done, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 1, -60),
		TextSize = 20,
		ZIndex = 61,
	})
	Widgets.springIn(holder)
end

function StoreController.open(which: string)
	screen = which
	tab = if which == "Shop" then "Featured" else "BombSkin"
	render()
end

function StoreController.start()
	Progress.start()
	task.spawn(function()
		DailyController.addDockButton("Shop", "Shop", 1, function()
			StoreController.open("Shop")
		end, { color = "rainbow", key = Enum.KeyCode.B })
		DailyController.addDockButton("Locker", "Items", 2, function()
			StoreController.open("Locker")
		end, { color = "blue", key = Enum.KeyCode.N, label = "Items" })
	end)
	RunService.RenderStepped:Connect(spinPreviews)
	Progress.Changed:Connect(function()
		-- live refresh while open (a purchase, an equip, a crate); forget the screen once something else replaced it
		if screen ~= "" and DailyController.openName() ~= screen then
			screen = ""
		elseif screen ~= "" and not confirmOpen then
			render(true)
		end
	end)
	Net.listen("Reward", function(r)
		if type(r) ~= "table" then
			return
		end
		if r.kind == "Bought" then
			Sfx.play("Claim")
		elseif r.kind == "Equipped" then
			Sfx.play("UiPress")
		end
	end)
end

return StoreController
