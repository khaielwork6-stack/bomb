--!strict
-- The Robux perks' buttons (docs/VIDEO2_NOTES.md §1, §3, §5; prices the owner's calls, 2026-10-18; server PerkService):
--   • BECOME LEAD BOMBER (key R): a red button at the bottom centre between rounds; once bought it turns into a gold
--     "LEAD BOMBER NEXT ROUND" chip until the round that uses it;
--   • the BOMBER PACK / RUNNER PACK card (your role's) bottom-right through the pick and the first crossing:
--     its two cosmetics, the Gems, the green R$ button, and a close button;
--   • REVIVE (key Q): a heart tile at the bottom centre while you tumble after a boom, and for REVIVE_GRACE after you
--     got up as a Bomber — buying it keeps you a Runner. Hidden when you already hold a kept Revive.
-- Every one hides while its product id is 0 (like every product). Studio preview: the player's FV_PreviewPerks
-- attribute shows them all regardless.
-- Implements: the Lead Bomber button, the pack card and the Revive tile (client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Modal = require(script.Parent.Parent.UI.Modal)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Announcer = require(script.Parent.Parent.UI.Announcer)

local PerkController = {}

local St = Config.Store
local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local Ph, R, State = Types.Phase, Types.Role, Types.State
local player = Players.LocalPlayer

local gui: ScreenGui
local gs: Configuration
local lead: Frame
local leadChip: Frame
local pack: Frame
local revive: Frame
local PICK_BAR = 0.11 -- the pick camera's letterbox bar height, a fraction of the screen (PickController BAR)
local LEAD_LIFT = 46 -- px from the bottom to the Lead Bomber button (its price line sits under it)
local packClosed = false -- closed (or bought) this session: it doesn't come back until the next session
local lastRole = "Runner" -- the role I played last round (the lobby pack card offers that team's pack)
local revivesOffered = 0 -- this session (Config.Onboarding.REVIVE_PER_SESSION)
local reviveWasUp = false
local revivedRound = false -- a Revive already worked this round

local function preview(): boolean
	return RunService:IsStudio() and player:GetAttribute("FV_PreviewPerks") == true
end

local function sellable(key: string): boolean
	local prod = St.PRODUCTS[key]
	return preview() or (prod ~= nil and prod.id ~= 0)
end

local function perks(): { [string]: any }
	local s = Progress.get()
	return s and (s :: any).perks or {}
end

local function buy(key: string)
	if preview() then
		Sfx.play("UiPress")
		return
	end
	Sfx.play("UiPress")
	Net.send("StoreAction", { kind = "BuyProduct", product = key })
end

local function packKey(): string
	return if lastRole == R.Bomber then "BomberPack" else "RunnerPack"
end

-- Lifetime rounds played (Config.Onboarding gates the offers on it).
local function roundsPlayed(): number
	local s = Progress.get()
	return if s and type(s.rounds) == "number" then s.rounds else 0
end

local function itemName(id: string): string
	local it = St.ById[id]
	return it and it.name or id
end

-- ── Build ───────────────────────────────────────────────────────────────────────────────────────────────────────
local packLines: { TextLabel } = {}
local packTitle: TextLabel
local packPrice: TextButton
local packIcon: ImageLabel

local function build()
	gui = new("ScreenGui", {
		Name = "FV_Perks",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 9,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Lead Bomber: the red button (and its "bought" chip)
	lead = new("Frame", {
		Name = "LeadBomber",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(240, 46),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}) :: Frame
	Widgets.button(lead, S.Ui.LeadBomber, "red", UDim2.fromOffset(240, 46), function()
		buy("LeadBomber")
	end, { TextSize = 18 })
	local price = Widgets.label(lead, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(200, 20),
		TextSize = 15,
		font = Theme.Font.Display,
		color = P.Gold,
		Text = S.Ui.Robux:format(St.PRODUCTS.LeadBomber.robux) .. "  ·  [R]",
	})
	price.Name = "Price"
	local chipFace = Theme.panel(gui, {
		Name = "LeadChip",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(240, 40),
		radius = 999,
		color = P.Gold,
		color2 = P.Ember,
		border = Color3.new(1, 1, 1),
	})
	leadChip = chipFace.Parent :: Frame
	leadChip.Visible = false
	Widgets.label(chipFace, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		font = Theme.Font.Display,
		Text = S.Ui.LeadBomberSet,
		ZIndex = 5,
	})

	-- the pack card
	local face = Theme.panel(gui, {
		Name = "Pack",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(250, 150),
		color = Color3.fromRGB(58, 64, 96),
		color2 = Color3.fromRGB(30, 32, 52),
		border = P.Gold,
		border2 = P.Ember,
	})
	pack = face.Parent :: Frame
	pack.Visible = false
	packIcon = Widgets.icon(face, "Bomber", 58, { Position = UDim2.fromOffset(8, 10), ZIndex = 5 })
	packTitle = Widgets.label(face, {
		Position = UDim2.fromOffset(72, 8),
		Size = UDim2.new(1, -110, 0, 28),
		TextSize = 22,
		font = Theme.Font.Display,
		color = P.Gold,
		align = Enum.TextXAlignment.Left,
		Text = S.Ui.BomberPack,
		ZIndex = 5,
	})
	for k = 1, 3 do
		packLines[k] = Widgets.label(face, {
			Position = UDim2.fromOffset(72, 36 + (k - 1) * 20),
			Size = UDim2.new(1, -80, 0, 20),
			TextSize = 15,
			font = Theme.Font.Bold,
			align = Enum.TextXAlignment.Left,
			Text = "",
			ZIndex = 5,
		})
	end
	packPrice = Widgets.button(face, "", "green", UDim2.fromOffset(120, 40), function()
		buy(packKey())
	end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), TextSize = 22, ZIndex = 6 })
	local x = Widgets.button(face, "X", "dark", UDim2.fromOffset(30, 30), function()
		packClosed = true
		pack.Visible = false
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), TextSize = 16, ZIndex = 7 })
	x.Name = "Close"

	-- the Revive tile
	local rf = Theme.panel(gui, {
		Name = "Revive",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(230, 96),
		color = Color3.fromRGB(255, 92, 120),
		color2 = Color3.fromRGB(196, 30, 70),
		border = Color3.new(1, 1, 1),
	})
	revive = rf.Parent :: Frame
	revive.Visible = false
	Widgets.icon(rf, "Heart", 64, { Position = UDim2.fromOffset(10, 16), ZIndex = 5 })
	Widgets.label(rf, {
		Position = UDim2.fromOffset(82, 8),
		Size = UDim2.new(1, -90, 0, 32),
		TextSize = 28,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		Text = S.Ui.Revive .. "  [Q]",
		ZIndex = 5,
	})
	Widgets.label(rf, {
		Position = UDim2.fromOffset(82, 40),
		Size = UDim2.new(1, -90, 0, 20),
		TextSize = 15,
		font = Theme.Font.Bold,
		align = Enum.TextXAlignment.Left,
		Text = S.Ui.ReviveSub,
		ZIndex = 5,
	})
	Widgets.label(rf, {
		Position = UDim2.fromOffset(82, 62),
		Size = UDim2.new(1, -90, 0, 24),
		TextSize = 20,
		font = Theme.Font.Display,
		color = P.Gold,
		align = Enum.TextXAlignment.Left,
		Text = S.Ui.Robux:format(St.PRODUCTS.Revive.robux),
		ZIndex = 5,
	})
	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 8,
		Parent = rf,
	}) :: TextButton
	hit.Activated:Connect(function()
		buy("Revive")
	end)
end

-- ── Per frame: who shows ────────────────────────────────────────────────────────────────────────────────────────
local function step()
	local v = Screen.size()
	local safe = Screen.safe()
	local k = math.clamp(v.Y / 720, 0.7, 1)
	for _, f in ipairs({ lead, leadChip, revive }) do
		local sc = f:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = f })
		sc.Scale = k
		-- the Lead Bomber button keeps room under it for its price line
		local lift = if f == lead then LEAD_LIFT else 24
		f.Position = UDim2.new(0.5, 0, 1, -(lift * k + safe.bottom))
	end
	local psc = pack:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = pack })
	psc.Scale = k
	-- above the touch buttons on phones; above the pick camera's letterbox bar during the pick
	local up = (if Screen.touch() then 230 else 24)
		+ (if ClientState.phase() == Ph.Intro then v.Y * PICK_BAR / k + 10 else 0)
	pack.Position = UDim2.new(1, -(16 + safe.right), 1, -up * k - safe.bottom)

	local phase = ClientState.phase()
	local calm = not Modal.busy()
	-- Nothing for sale while a round is live (DECISIONS 2026-10-19): every offer is a lobby thing, and a new player
	-- meets them only after a few rounds (Config.Onboarding).
	local O = Config.Onboarding
	local played = roundsPlayed()
	-- Lead Bomber: between rounds, not AFK, from round LEAD_FROM_ROUND
	local lobby = phase == Ph.Intermission and player:GetAttribute("Afk") ~= true and calm
	local bought = perks().leadBomber == true
	lead.Visible = lobby and not bought and played >= O.LEAD_FROM_ROUND and sellable("LeadBomber")
	leadChip.Visible = lobby and bought
	-- the pack card: in the lobby, from round PACK_FROM_ROUND, once per session (closing it ends it for the session)
	local key = packKey()
	local showPack = lobby and played >= O.PACK_FROM_ROUND and not packClosed and sellable(key)
	if showPack and not pack.Visible then
		local prod = St.PRODUCTS[key]
		packIcon.Image = (Assets.Icon :: any)[if key == "BomberPack" then "Bomber" else "Runner"] or ""
		packTitle.Text = if key == "BomberPack" then S.Ui.BomberPack else S.Ui.RunnerPack
		packLines[1].Text = itemName(prod.items[1])
		packLines[2].Text = itemName(prod.items[2])
		packLines[3].Text = S.Ui.PackGems:format(prod.stars)
		packPrice.Text = S.Ui.Robux:format(prod.robux)
	end
	pack.Visible = showPack
	-- Revive: while I tumble after a boom, or just after I got up as a Bomber
	local boomedAt = player:GetAttribute("BoomedAt")
	local recent = type(boomedAt) == "number" and workspace:GetServerTimeNow() - boomedAt <= Config.Round.REVIVE_GRACE
	local downed = ClientState.role() == R.Runner and ClientState.state() == State.Tumbled
	local justBomber = ClientState.role() == R.Bomber and recent and ClientState.activeInRun()
	-- (the one offer that rides a live moment — your own boom — so it's capped: from REVIVE_FROM_ROUND, and only
	-- REVIVE_PER_SESSION times a session)
	local reviveUp = (downed or justBomber)
		and recent
		and not revivedRound
		and (perks().revives or 0) == 0
		and played >= O.REVIVE_FROM_ROUND
		and (reviveWasUp or revivesOffered < O.REVIVE_PER_SESSION)
		and sellable("Revive")
	if reviveUp and not reviveWasUp then
		revivesOffered += 1
	end
	reviveWasUp = reviveUp
	revive.Visible = reviveUp
end

function PerkController.start()
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	build()
	RunService.RenderStepped:Connect(step)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.R and lead.Visible then
			buy("LeadBomber")
		elseif input.KeyCode == Enum.KeyCode.Q and revive.Visible then
			buy("Revive")
		end
	end)
	Net.listen("Reward", function(r)
		if type(r) ~= "table" then
			return
		end
		if r.kind == "Revived" then
			revivedRound = true
			Sfx.play("Claim")
			Announcer.say({ key = "Revived", tier = "Moment", priority = 2.7, hold = 1.3 })
		elseif r.kind == "ReviveSaved" then
			Announcer.say({ key = "ReviveSaved", priority = 2, hold = 1.3 })
		end
	end)
	-- a new round: the pack card and the Revive come back
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if ClientState.phase() == Ph.Intermission then
			revivedRound = false
		elseif ClientState.role() == R.Runner or ClientState.role() == R.Bomber then
			lastRole = ClientState.role()
		end
	end)
end

return PerkController
