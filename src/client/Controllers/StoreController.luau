--!strict
-- The Shop and the Locker (GDD §17, §21.3; Asset Bible §6, §7.4): category tabs down the left, item cards on the
-- right — bomb skins as live 3D previews of the real bomb wearing the skin (a slow turntable, its lamps pulsing
-- through LIT → HOT → CRITICAL), rarity frames, Stars prices with the daily DEAL; crates with their odds always shown
-- (F-STORE-06), the Inferno pity counter (F-STORE-08), and "Not available in your region" where paid random items
-- are restricted (F-STORE-09). Buying asks once; equipping is a tap. Only items whose art exists are ever listed.
-- The Starter Bundle (F-STORE-11): a full-screen offer card once the 3rd round's results close (once ever, never
-- twice a session; the server decides via `store.starter.popup`), then a "NEW PLAYER" shop tab with its countdown.
-- Implements: F-STORE-03..09, F-STORE-11 (presentation), F-UI-04 (Shop, Locker).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Modal = require(script.Parent.Parent.UI.Modal)
local Progress = require(script.Parent.Parent.Progress)
local BombFace = require(script.Parent.Parent.BombFace)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local DailyController = require(script.Parent.DailyController)
local OfferController = require(script.Parent.OfferController)

local St = Config.Store
local S = Config.Strings
local P = Theme.Palette
local Ph = Types.Phase
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

-- Each category's 3D icon (art/icons), for cards whose item has no live preview.
local CATEGORY_ICON = {
	BombSkin = "Palette",
	Explosion = "Explosion",
	FuseSpark = "Sparkler",
	Trail = "Trail",
	VictoryBoom = "Firework",
	Title = "Plate",
	Emote = "Wave",
}

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

-- ── Cards (the reference video's shop: bright rarity-gradient cards, the art filling them, big round type) ──────
local confirmBuy: (id: string) -> ()

-- Card fills by rarity (top → bottom of the gradient).
local CARD_FILL = {
	Default = { Color3.fromRGB(190, 196, 210), Color3.fromRGB(120, 126, 142) },
	Common = { Color3.fromRGB(236, 240, 246), Color3.fromRGB(164, 174, 190) },
	Rare = { Color3.fromRGB(120, 204, 255), Color3.fromRGB(38, 118, 232) },
	Epic = { Color3.fromRGB(204, 158, 255), Color3.fromRGB(128, 66, 236) },
	Legendary = { Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 152, 28) },
	Exclusive = { Color3.fromRGB(255, 150, 214), Color3.fromRGB(214, 52, 146) },
}

-- A rarity card body: gradient fill, white border ring, ink outline, the faint halftone wash. Returns the face.
local function cardBody(parent: Instance, name: string, size: UDim2, rarity: string, order: number): Frame
	local fill = CARD_FILL[rarity] or CARD_FILL.Common
	local face = Theme.panel(parent, {
		Name = name,
		Size = size,
		color = fill[1],
		color2 = fill[2],
		border = Color3.new(1, 1, 1),
		border2 = Color3.fromRGB(226, 230, 240),
		dots = Color3.new(1, 1, 1),
		dotsT = 0.8,
		glow = if rarity == "Legendary" or rarity == "Exclusive" then fill[1] else nil,
		glowT = 0.6,
	});
	(face.Parent :: Frame).LayoutOrder = order
	return face
end

-- The green price button: a Star and the price in big white type. `h` = its height in pixels (for the type size).
local function priceButton(
	parent: Instance,
	price: number,
	size: UDim2,
	onClick: () -> (),
	props: { [string]: any }?,
	h: number?
)
	local b, setOn = Widgets.button(parent, "", "green", size, onClick, props)
	local row = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9, Parent = b })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = row,
	})
	local px = h or (if size.Y.Offset > 0 then size.Y.Offset else 40)
	local text = tostring(price)
	Widgets.icon(row, "Star", math.floor(px * 0.8), { ZIndex = 10 })
	Widgets.label(row, {
		Size = UDim2.fromOffset(math.ceil(#text * px * 0.4) + 4, px),
		TextSize = math.floor(px * 0.62),
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = tostring(price),
		ZIndex = 10,
	})
	return b, setOn
end

-- A small tag in the card's top-right ("RARE", "DEAL -20%", "EQUIPPED").
local function tag(parent: Instance, text: string, color: Color3, z: number)
	Widgets.label(parent, {
		Name = "Tag",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(150, 22),
		TextSize = 18,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Right,
		color = color,
		stroke = 2.5,
		Text = text,
		ZIndex = z,
	})
end

local function preview(stage: Instance, item: { [string]: any })
	if item.category == "BombSkin" then
		bombPreview(stage, item.id)
	elseif item.category == "Title" then
		local plate = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -20, 0, 40),
			BackgroundColor3 = P.Brass,
			ZIndex = 5,
			Parent = stage,
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
			Text = item.name,
			ZIndex = 6,
		})
	else
		Widgets.icon(stage, CATEGORY_ICON[item.category] or "Star", 96, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 5,
		})
	end
end

-- The action row: EQUIPPED / EQUIP when owned (or in the Locker), else the green price button (gold for the DEAL).
local function action(
	parent: Instance,
	s: { [string]: any },
	id: string,
	mode: string,
	size: UDim2,
	props: { [string]: any },
	h: number
)
	local has = owned(s, id)
	if mode == "Locker" or has then
		if equipped(s, id) then
			local b = Widgets.button(parent, "EQUIPPED", "dark", size, function() end, props)
			b.Active = false
		else
			Widgets.button(parent, "EQUIP", "cyan", size, function()
				Net.send("StoreAction", { kind = "Equip", id = id })
			end, props)
		end
	else
		local price = priceOf(s, id)
		if price then
			priceButton(parent, price, size, function()
				confirmBuy(id)
			end, props, h)
		end
	end
end

-- A grid card (category tabs): the art fills the top, name + rarity at the bottom, the action under it.
local function itemCard(parent: Instance, s: { [string]: any }, id: string, mode: string, order: number)
	local item = St.ById[id]
	if not item then
		return
	end
	local card = cardBody(parent, id, UDim2.fromOffset(158, 214), item.rarity, order)
	local stage = new("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 118),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = card,
	})
	preview(stage, item)
	local _, deal = priceOf(s, id)
	if deal and not owned(s, id) and mode == "Shop" then
		tag(card, ("DEAL -%d%%"):format(math.floor(St.DEAL_OFF * 100)), P.Spark, 8)
	end
	local nameL = Widgets.label(card, {
		Position = UDim2.fromOffset(6, 120),
		Size = UDim2.new(1, -12, 0, 26),
		TextSize = 20,
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = item.name,
		ZIndex = 6,
	})
	nameL.TextTruncate = Enum.TextTruncate.AtEnd
	Widgets.label(card, {
		Position = UDim2.fromOffset(6, 144),
		Size = UDim2.new(1, -12, 0, 18),
		TextSize = 15,
		font = Theme.Font.Display,
		stroke = 2,
		color = if item.rarity == "Common" then Color3.fromRGB(240, 244, 250) else Color3.new(1, 1, 1),
		Text = string.upper(item.rarity),
		ZIndex = 6,
	})
	local row = new("Frame", {
		Position = UDim2.new(0, 10, 1, -46),
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	action(row, s, id, mode, UDim2.fromScale(1, 1), { TextSize = 20, ZIndex = 6 }, 36)
end

-- A big Featured card (two per row): the name and rarity top-left, the art large on the right, the action
-- bottom-left — the reference's "Soul Reaper" card.
local function featuredCard(parent: Instance, s: { [string]: any }, id: string, mode: string, order: number)
	local item = St.ById[id]
	if not item then
		return
	end
	local card = cardBody(parent, id, UDim2.fromOffset(330, 214), item.rarity, order)
	Widgets.label(card, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.62, 0, 0, 40),
		TextSize = 32,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		stroke = 3,
		wrap = true,
		Text = item.name,
		ZIndex = 6,
	})
	Widgets.label(card, {
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(0.55, 0, 0, 22),
		TextSize = 18,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		stroke = 2.5,
		Text = (St.CATEGORY_NAME[item.category] or "") .. " · " .. string.upper(item.rarity),
		ZIndex = 6,
	})
	local _, deal = priceOf(s, id)
	if deal and not owned(s, id) then
		tag(card, ("DEAL  -%d%%"):format(math.floor(St.DEAL_OFF * 100)), P.Spark, 8)
	end
	local stage = new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(160, 160),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = card,
	})
	preview(stage, item)
	local row = new("Frame", {
		Position = UDim2.new(0, 16, 1, -62),
		Size = UDim2.fromOffset(150, 48),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	action(row, s, id, mode, UDim2.fromScale(1, 1), { TextSize = 24, ZIndex = 6 }, 48)
end

local function crateCard(parent: Instance, s: { [string]: any }, kind: string, order: number)
	local crate = St.CRATES[kind]
	local store = s.store or {}
	local rarity = if kind == "Inferno" then "Legendary" elseif kind == "GiftBox" then "Epic" else "Rare"
	local card = cardBody(parent, kind, UDim2.fromOffset(330, 300), rarity, order)
	Widgets.label(card, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 40),
		TextSize = 32,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		stroke = 3,
		Text = crate.name,
		ZIndex = 6,
	})
	local icon = if kind == "Inferno" then "CrateInferno" elseif kind == "GiftBox" then "GiftBox" else "Crate"
	Widgets.icon(card, icon, 132, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(8, 52),
		ZIndex = 5,
	})
	-- the odds, always shown (F-STORE-06): a chance row per rarity in its colour (the reference's CHANCES list)
	local list = new("Frame", {
		Position = UDim2.fromOffset(150, 54),
		Size = UDim2.fromOffset(166, 150),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = card,
	})
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, r in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
		local p = crate.odds[r]
		if p then
			local fill = CARD_FILL[r]
			local chip = Theme.panel(list, {
				Name = r,
				Size = UDim2.fromOffset(166, 30),
				radius = 999,
				color = fill[1],
				color2 = fill[2],
				border = Color3.new(1, 1, 1),
				scale = 0.35,
			});
			(chip.Parent :: Frame).LayoutOrder = i
			Widgets.label(chip, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -20, 1, 0),
				TextSize = 16,
				font = Theme.Font.Display,
				align = Enum.TextXAlignment.Left,
				stroke = 2,
				Text = r,
				ZIndex = 7,
			})
			Widgets.label(chip, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -20, 1, 0),
				TextSize = 16,
				font = Theme.Font.Display,
				align = Enum.TextXAlignment.Right,
				stroke = 2,
				Text = tostring(math.floor(p * 1000 + 0.5) / 10) .. "%",
				ZIndex = 7,
			})
		end
	end
	if crate.pity then
		Widgets.label(card, {
			Position = UDim2.fromOffset(16, 192),
			Size = UDim2.fromOffset(140, 20),
			TextSize = 16,
			font = Theme.Font.Display,
			color = P.Spark,
			align = Enum.TextXAlignment.Left,
			stroke = 2,
			Text = ("Epic+ in %d"):format(math.max(1, crate.pity - (store.pity or 0))),
			ZIndex = 6,
		})
	end
	local row = new("Frame", {
		Position = UDim2.new(0, 16, 1, -66),
		Size = UDim2.new(1, -32, 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		Parent = row,
	})
	local tokens = store.crates and store.crates[kind] or 0
	if tokens > 0 then
		Widgets.button(row, ("OPEN FREE x%d"):format(tokens), "cyan", UDim2.fromOffset(170, 48), function()
			Net.send("StoreAction", { kind = "OpenCrate", crate = kind, source = "Token" })
		end, { TextSize = 20, ZIndex = 6 })
	end
	if store.restricted then
		Widgets.label(row, {
			Size = UDim2.fromOffset(280, 48),
			TextSize = 16,
			font = Theme.Font.Display,
			color = Color3.new(1, 1, 1),
			wrap = true,
			stroke = 2,
			Text = "Not available in your region",
			ZIndex = 6,
		})
	elseif not crate.free then
		priceButton(row, crate.stars, UDim2.fromOffset(150, 48), function()
			local now = Progress.get()
			if now and (now.stars or 0) >= crate.stars then
				Net.send("StoreAction", { kind = "OpenCrate", crate = kind, source = "Stars" })
			else
				Sfx.play("UiDeny")
			end
		end, { ZIndex = 6 })
	end
end

-- The Starter Bundle's contents, countdown and Robux button, inside `parent` (the shop tab's card or the popup).
local function starterBody(parent: Instance, s: { [string]: any }, width: number)
	local offer = s.store and s.store.starter
	if not offer then
		return
	end
	local stage = new("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = P.Ink,
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = stage })
	local lines = { S.Ui.StarterStars:format(tostring(offer.stars)) }
	for _, id in ipairs(offer.items or {}) do
		local item = St.ById[id]
		if item and item.category == "BombSkin" then
			bombPreview(stage, id)
			table.insert(lines, S.Ui.StarterSkin:format(item.name))
		elseif item and item.category == "Title" then
			table.insert(lines, S.Ui.StarterTitleLine:format(item.name))
		end
	end
	local list = new("Frame", {
		Position = UDim2.fromOffset(146, 12),
		Size = UDim2.fromOffset(width - 158, 96),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = parent,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, text in ipairs(lines) do
		Widgets.label(list, {
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 18,
			align = Enum.TextXAlignment.Left,
			Text = "+ " .. text,
			LayoutOrder = i,
			ZIndex = 5,
		})
	end
	Widgets.label(parent, {
		Position = UDim2.fromOffset(146, 110),
		Size = UDim2.fromOffset(width - 158, 20),
		TextSize = 13,
		color = P.Spark,
		align = Enum.TextXAlignment.Left,
		Text = S.Ui.StarterValue,
		ZIndex = 5,
	})
	local ends = Widgets.label(parent, {
		Position = UDim2.fromOffset(12, 140),
		Size = UDim2.new(1, -24, 0, 22),
		TextSize = 16,
		color = P.Fuse,
		Text = "",
		ZIndex = 5,
	})
	task.spawn(function()
		while ends.Parent do
			ends.Text = S.Ui.StarterEnds:format(Widgets.clock(offer.endsIn - Progress.age()))
			task.wait(1)
		end
	end)
	Widgets.button(parent, S.Ui.StarterBuy:format(offer.robux), "gold", UDim2.fromOffset(180, 44), function()
		Net.send("StoreAction", { kind = "BuyProduct", product = "StarterBundle" })
	end, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 168),
		TextSize = 20,
		ZIndex = 6,
	})
end

local function starterCard(parent: Instance, s: { [string]: any })
	local card = Theme.panel(parent, {
		Name = "StarterBundle",
		Size = UDim2.fromOffset(420, 226),
		color = Color3.fromRGB(52, 38, 30),
		border = P.Gold,
		border2 = P.Brass,
		glow = P.Gold,
		glowT = 0.6,
	})
	starterBody(card, s, 420)
end

-- ── Screens ─────────────────────────────────────────────────────────────────────────────────────────────────────
local render: (refresh: boolean?) -> ()

local function tabsFor(s: { [string]: any }, mode: string): { string }
	local out = {}
	if mode == "Shop" then
		if s.store and s.store.starter then
			table.insert(out, "Starter")
		end
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

-- Tab colours, in the reference's order of bright presets.
local TAB_PRESET = {
	Featured = "gold",
	BombSkin = "orange",
	Explosion = "red",
	FuseSpark = "pink",
	Trail = "cyan",
	VictoryBoom = "purple",
	Title = "brass",
	Emote = "pink",
	Crates = "green",
	Starter = "rainbow",
}

local TAB_NAME = { Featured = "Featured", Crates = "Crates", BombSkin = "Skins", FuseSpark = "Sparks" }

render = function(refresh: boolean?)
	local s = Progress.get()
	if not s or screen == "" then
		return
	end
	table.clear(viewports)
	local face = DailyController.panel(
		screen,
		if screen == "Shop" then "SHOP" else "ITEMS",
		Vector2.new(880, 520),
		if screen == "Shop" then P.Fuse else Color3.fromRGB(56, 150, 255),
		refresh
	)
	local tabs = tabsFor(s, screen)
	if not table.find(tabs, tab) then
		tab = tabs[1] or "Crates"
	end
	-- tabs in the header strip (the reference's coloured tab row)
	local slot = DailyController.headerTabs()
	if slot then
		for i, t in ipairs(tabs) do
			local label = TAB_NAME[t]
				or (if t == "Starter" then S.Ui.StarterTab else nil)
				or (St.CATEGORY_NAME[t] and (string.sub(St.CATEGORY_NAME[t], 1, 1) .. string.lower(
					string.sub(St.CATEGORY_NAME[t], 2)
				)))
				or t
			local w = math.max(96, 16 * #label + 30)
			local b = Widgets.button(slot, label, TAB_PRESET[t] or "cyan", UDim2.fromOffset(w, 46), function()
				if tab ~= t then
					Sfx.play("UiTab")
				end
				tab = t
				render(true)
			end, { TextSize = 24, LayoutOrder = i, ZIndex = 7 })
			if t == tab then
				local ring = new("UIStroke", {
					Color = Color3.new(1, 1, 1),
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = b,
				})
				ring:SetAttribute("Keep", true)
			else
				b.Size = UDim2.fromOffset(w, 42)
			end
		end
	end
	-- the grid
	local grid = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 1, -58),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(150, 146, 170),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
		Parent = face,
	})
	local big = tab == "Crates" or tab == "Featured"
	new("UIGridLayout", {
		CellSize = if tab == "Starter"
			then UDim2.fromOffset(420, 226)
			elseif tab == "Crates" then UDim2.fromOffset(406, 300)
			elseif big then UDim2.fromOffset(406, 214)
			else UDim2.fromOffset(158, 214),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = grid,
	})
	if tab == "Starter" then
		starterCard(grid, s)
	elseif tab == "Crates" then
		crateCard(grid, s, "Spark", 1)
		crateCard(grid, s, "Inferno", 2)
		if (s.store and s.store.crates and s.store.crates.GiftBox or 0) > 0 then
			crateCard(grid, s, "GiftBox", 3)
		end
	elseif tab == "Featured" then
		for i, id in ipairs(s.store.featured) do
			featuredCard(grid, s, id, screen, i)
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
	-- fill the wider Featured / Crates cells
	if big then
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("Frame") then
				c.Size = UDim2.fromScale(1, 1)
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

function StoreController.open(which: string, startTab: string?)
	screen = which
	tab = startTab or (if which == "Shop" then "Featured" else "BombSkin")
	render()
end

-- The full-screen Starter Bundle card (F-STORE-11), at the first calm lobby moment after a round's results close.
local offerPopped = false -- this session
local function popStarter()
	local s = Progress.get()
	local offer = s and s.store and s.store.starter
	if offerPopped or not offer or not offer.popup then
		return
	end
	offerPopped = true
	task.spawn(function()
		while ClientState.phase() == Ph.Intermission do
			if not Modal.busy() then
				local now = Progress.get()
				if not now or not now.store.starter then
					return
				end
				-- the reference video's STARTER PACK card (OfferController)
				if not OfferController.open(now.store.starter.endsIn - Progress.age()) then
					return
				end
				Net.send("StoreAction", { kind = "StarterSeen" })
				return
			end
			task.wait(0.5)
		end
		offerPopped = false -- the lobby ended before a calm moment: try after the next results
	end)
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
	-- the lobby's shop kiosk and crate stands (LobbyDepot puts FV_Open on their prompts)
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, who)
		local want = prompt:GetAttribute("FV_Open")
		if who == Players.LocalPlayer and want == "Shop" then
			StoreController.open("Shop")
		elseif who == Players.LocalPlayer and want == "Crates" then
			StoreController.open("Shop", "Crates")
		end
	end)
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local last = ClientState.phase()
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = ClientState.phase()
		if last == Ph.Results and ph == Ph.Intermission then
			popStarter()
		end
		last = ph
	end)
	Progress.Changed:Connect(function(s)
		-- the offer card closes itself once the bundle is bought (or the offer ran out)
		if DailyController.openName() == "StarterOffer" and not (s and s.store and s.store.starter) then
			DailyController.close()
		end
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
