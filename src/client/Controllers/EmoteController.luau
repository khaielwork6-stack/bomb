--!strict
-- Emotes and the taunt (docs/VIDEO2_NOTES.md §8; the reference video's EMOTES [G] and TAUNT [T] buttons on the right
-- edge): G (or the EMOTES tile) opens a wheel of the eight emotes round the screen centre — the ones you own lit with
-- their name and number key (1–8), the rest locked — and picking one plays it on your character; T (or the TAUNT tile)
-- plays the quick "come at me" taunt (tools/anim/Taunt). Your character's animations replicate, so everyone sees them.
-- Moving cancels an emote. Never during a live run (you can't emote while you're dodging a bomb): in the lobby, in
-- the Safe Strips and when you're out of the run (and never over a cinematic such as the pick camera).
-- Implements: docs/VIDEO2_NOTES.md §8 (emote wheel + taunt), Asset Bible §8.5.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Dock = require(script.Parent.Parent.UI.Dock)
local Screen = require(script.Parent.Parent.UI.Screen)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local CameraController = require(script.Parent.CameraController)

local St = Config.Store
local S = Config.Strings
local new = Theme.new
local player = Players.LocalPlayer

local EmoteController = {}

local WHEEL_RADIUS = 150
local XP_CLEAR = 54 -- px under the top bar kept for the XP strip and level badge (top right)
local SLOT_SIZE = 96
local CANCEL_MOVE = 0.2 -- MoveDirection magnitude that cancels an emote

local gui: ScreenGui
local side: Frame
local wheel: Frame? = nil
-- the wheel's two pages: FREE (Roblox's own emotes, everyone has them) and SHOP (the store's emotes, owned or locked)
type Page = "Free" | "Shop"
type Entry = { name: string, anim: string, mine: boolean }
local FREE_ORDER = { "Wave", "Point", "Cheer", "Laugh", "Dance", "Dance2", "Dance3" }
local page: Page? = nil -- remembered for the session; first open picks FREE unless you own a shop emote
local track: AnimationTrack? = nil
local cache: { [string]: Animation } = {}

local function emoteIds(): { string }
	local out = {}
	for _, it in ipairs(St.Items) do
		if it.category == "Emote" and Cosmetics.ready(it.id) then
			table.insert(out, it.id)
		end
	end
	return out
end

local function owns(id: string): boolean
	local s = Progress.get()
	for _, o in ipairs(s and s.store and s.store.owned or {}) do
		if o == id then
			return true
		end
	end
	return false
end

local function entries(pg: Page): { Entry }
	local out = {}
	if pg == "Free" then
		for _, key in ipairs(FREE_ORDER) do
			local anim = Assets.Anim.FreeEmotes[key]
			if anim then
				table.insert(out, { name = S.Ui.FreeEmoteNames[key] or key, anim = anim, mine = true })
			end
		end
	else
		for _, id in ipairs(emoteIds()) do
			local item = St.ById[id]
			table.insert(out, { name = item and item.name or id, anim = Cosmetics.Emotes[id] or "", mine = owns(id) })
		end
	end
	return out
end

local function ownsAnyShopEmote(): boolean
	for _, id in ipairs(emoteIds()) do
		if owns(id) then
			return true
		end
	end
	return false
end

local function allowed(): boolean
	return not ClientState.activeInRun() and not CameraController.cinematic
end

local function stop()
	if track then
		track:Stop(0.2)
		track = nil
	end
end

local function play(animId: string)
	if not allowed() then
		Sfx.play("UiDeny")
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator or animId == "" then
		return
	end
	stop()
	local anim = cache[animId]
	if not anim then
		anim = new("Animation", { AnimationId = animId }) :: Animation
		cache[animId] = anim :: Animation
	end
	local t = (animator :: Animator):LoadAnimation(anim :: Animation)
	t.Priority = Enum.AnimationPriority.Action
	t:Play(0.15)
	track = t
end

local function closeWheel()
	local w = wheel
	wheel = nil
	if w then
		Widgets.springOut(w, function()
			w:Destroy()
		end)
	end
end

local openWheel: () -> ()

local function buildWheel()
	local pg: Page = page or "Free"
	Sfx.play("UiOpen")
	local w = new("Frame", {
		Name = "EmoteWheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset((WHEEL_RADIUS + SLOT_SIZE) * 2, (WHEEL_RADIUS + SLOT_SIZE) * 2),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})
	wheel = w
	-- the dark disc behind the slots
	local disc = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WHEEL_RADIUS * 2 + SLOT_SIZE, WHEEL_RADIUS * 2 + SLOT_SIZE),
		BackgroundColor3 = Skin.Color.PanelBottom,
		BackgroundTransparency = 0.25,
		ZIndex = 10,
		Parent = w,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = disc })
	new("UIStroke", { Color = Skin.Color.Accent, Thickness = 4, Parent = disc })
	Widgets.label(w, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -18),
		Size = UDim2.fromOffset(160, 40),
		TextSize = 30,
		font = Theme.Font.Display,
		stroke = 3,
		Text = S.Ui.Emotes,
		ZIndex = 12,
	})
	-- the page toggle: shows the page you'd switch to
	local other: Page = if pg == "Free" then "Shop" else "Free"
	Widgets.button(
		w,
		if other == "Free" then S.Ui.EmotesFree else S.Ui.EmotesShop,
		if other == "Free" then "green" else "gold",
		UDim2.fromOffset(110, 40),
		function()
			page = other
			local old = wheel
			wheel = nil
			if old then
				old:Destroy()
			end
			buildWheel()
		end,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 24),
			TextSize = 20,
			ZIndex = 13,
		}
	)
	local list = entries(pg)
	for i, e in ipairs(list) do
		local a = math.rad(-90 + (i - 1) * 360 / #list)
		local slot = Widgets.button(
			w,
			"",
			if e.mine then (if pg == "Free" then "green" else "cyan") else "dark",
			UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
			function()
				if e.mine then
					play(e.anim)
					closeWheel()
				else
					Sfx.play("UiDeny")
				end
			end,
			{
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(a) * WHEEL_RADIUS, 0.5, math.sin(a) * WHEEL_RADIUS),
				ZIndex = 12,
			}
		)
		slot.Name = "Slot" .. i
		Widgets.icon(slot, if e.mine then "Wave" else "Lock", if e.mine then 46 else 36, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			ZIndex = 14,
		})
		local nameL = Widgets.label(slot, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -8, 0, 22),
			TextSize = 16,
			font = Theme.Font.Display,
			stroke = 2,
			Text = e.name,
			ZIndex = 14,
		})
		nameL.TextScaled = true
		Widgets.label(slot, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			Size = UDim2.fromOffset(20, 20),
			TextSize = 18,
			font = Theme.Font.Display,
			stroke = 2,
			color = Skin.Color.Cash,
			Text = tostring(i),
			ZIndex = 15,
		})
	end
	Widgets.springIn(w, 0.3)
end

openWheel = function()
	if wheel then
		closeWheel()
		return
	end
	if not allowed() then
		Sfx.play("UiDeny")
		return
	end
	if page == nil then
		page = if ownsAnyShopEmote() then "Shop" else "Free"
	end
	buildWheel()
end

local function onKey(name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if name == "FV_EmoteWheel" then
		openWheel()
	elseif name == "FV_Taunt" then
		closeWheel()
		play(Assets.Anim.Taunt)
	elseif name == "FV_EmoteSlot" and wheel then
		local n = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		local e = entries(page or "Free")[n]
		if e and e.mine then
			play(e.anim)
			closeWheel()
		elseif e then
			Sfx.play("UiDeny")
		end
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local function place()
	local safe = Screen.safe()
	local fit = side:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = side })
	local v = Screen.size()
	fit.Scale = math.clamp(v.Y / 900, 0.7, 1)
	-- centred a little above the middle, but never up under the XP strip (short phone screens)
	local h = side.Size.Y.Offset * fit.Scale
	local top = math.max(v.Y * 0.42 - h / 2, Screen.topbar().Max.Y + XP_CLEAR)
	side.Position = UDim2.new(1, -(14 + safe.right), 0, top)
end

function EmoteController.start()
	gui = new("ScreenGui", {
		Name = "FV_Emotes",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- the two tiles on the right edge (the reference's EMOTES / TAUNT column)
	side = new("Frame", {
		Name = "EmoteDock",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(Dock.SIZE + 12, (Dock.SIZE + 20) * 2),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	Dock.tile(
		side,
		"Emotes",
		"Wave",
		openWheel,
		{ color = "pink", key = Enum.KeyCode.G, label = S.Ui.Emotes, order = 1 }
	)
	Dock.tile(side, "Taunt", "Flame", function()
		play(Assets.Anim.Taunt)
	end, { color = "orange", key = Enum.KeyCode.T, label = S.Ui.Taunt, order = 2 })
	place()
	Screen.Changed:Connect(place)
	ContextActionService:BindAction("FV_EmoteWheel", onKey, false, Enum.KeyCode.G)
	ContextActionService:BindAction("FV_Taunt", onKey, false, Enum.KeyCode.T)
	ContextActionService:BindAction(
		"FV_EmoteSlot",
		onKey,
		false,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight
	)
	-- moving (or a run starting) cancels an emote; the tiles hide while you're in a live run
	RunService.Heartbeat:Connect(function()
		local live = not allowed()
		side.Visible = not live
		if live and wheel then
			closeWheel()
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if track and (live or (hum and hum.MoveDirection.Magnitude > CANCEL_MOVE)) then
			stop()
		end
	end)
end

return EmoteController
