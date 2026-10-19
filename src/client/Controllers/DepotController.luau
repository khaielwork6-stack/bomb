--!strict
-- The lobby "The Depot" on every client (GDD §19, Asset Bible §4.3). The 12 s between rounds are for playing:
--   • the Fuse Range: grab a practice bomb at the dispenser, bump a padded dummy to pass it, the dummy hands it back,
--     the green pad defuses it; keep the streak going before the fuse runs out. Purely local (no rewards), shown on the
--     real bomb (BombController reads the attributes this sets on you and on the dummies).
--   • the clock tower: its spiral fuse burns up toward the giant bomb as the next MEGA BOMB nears; the bomb panics and
--     bursts when it starts. The clock face counts down.
--   • the shop kiosk spins today's featured bomb skins on its plinths; the quest board pins today's three quests;
--     walking up to either and pressing E opens the Shop / Quests.
--   • the leaderboard wall renders the weekly boards DepotService publishes; the VIP gate lets VIP pass owners through.
--   • going into a round, a quick flash hides the teleport.
-- Idle when the place has no lobby.
-- Implements: F-LOBBY-01 (the Depot's stations), F-LOBBY-02 (intermission), F-STORE-03 (featured plinths in world).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local BombFace = require(script.Parent.Parent.BombFace)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local SkinApply = require(script.Parent.Parent.SkinApply)
local Announcer = require(script.Parent.Parent.UI.Announcer)
local Theme = require(script.Parent.Parent.UI.Theme)
local DailyController = require(script.Parent.DailyController)
local FxController = require(script.Parent.FxController)
local StoreController = require(script.Parent.StoreController)

local LC = Config.Lobby
local S = Config.Strings.Lobby
local St = Config.Store
local P = Theme.Palette
local Ph = Types.Phase
local new = Theme.new
local player = Players.LocalPlayer

local DepotController = {}

local lobby: Model
local gs: Configuration
local hud: TextLabel
local hudHint: TextLabel

local function now(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function myRoot(): BasePart?
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function inLobby(): boolean
	return ClientState.role() == Types.Role.None
end

-- ── The Fuse Range (practice hot potato) ──────────────────────────────────────────────────────────────────────
type Practice = { holder: Instance?, explodeAt: number, handedAt: number, from: Instance?, releaseAt: number }
local practice: Practice = { holder = nil, explodeAt = 0, handedAt = 0, from = nil, releaseAt = 0 }
local streak, best = 0, 0
local dummies: { Model } = {}
local pad: BasePart? = nil

local function setBomb(host: Instance?, explodeAt: number?)
	host = host or player
	host:SetAttribute("BombId", if explodeAt then -1 else nil)
	host:SetAttribute("BombExplodeAt", explodeAt)
end

local function hand(to: Instance)
	if practice.holder then
		setBomb(practice.holder, nil)
	end
	practice.from = practice.holder
	practice.holder = to
	practice.handedAt = os.clock()
	setBomb(to, practice.explodeAt)
	if to ~= player then
		local lo, hi = LC.DUMMY_HOLD[1], LC.DUMMY_HOLD[2]
		practice.releaseAt = os.clock() + lo + math.random() * (hi - lo)
		-- the padded dummy rocks on its spring
		local torso = to:FindFirstChild("Torso") :: BasePart?
		local home = torso and torso:GetAttribute("Home")
		if torso and typeof(home) == "CFrame" then
			torso.CFrame = home * CFrame.Angles(math.rad(14), 0, math.rad(math.random(-8, 8)))
			TweenService:Create(torso, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { CFrame = home }):Play()
		end
	end
	Sfx.play("BombClamp", 0.8, if to == player then 1.25 else 1)
end

local function clearPractice()
	if practice.holder then
		setBomb(practice.holder, nil)
	end
	practice.holder = nil
	hud.Visible = false
	hudHint.Visible = false
end

local function give()
	if not inLobby() or practice.holder then
		return
	end
	practice.explodeAt = now() + LC.PRACTICE_FUSE
	practice.from = nil
	streak = 0
	hand(player)
	hud.Visible = true
	hudHint.Visible = true
end

local function hostPos(host: Instance): Vector3?
	if host == player then
		local r = myRoot()
		return r and r.Position
	end
	local t = host:FindFirstChild("Torso") :: BasePart?
	return t and t.Position
end

local function practiceStep()
	local h = practice.holder
	if not h then
		return
	end
	if not inLobby() then
		clearPractice()
		return
	end
	local t = now()
	local root = myRoot()
	if t >= practice.explodeAt then
		local at = hostPos(h)
		if at then
			FxController.boom(at, 0.55, true)
		end
		best = math.max(best, streak)
		-- one voice: the BOOM! title with the reset on its plate (the streak line steps aside)
		hud.Visible = false
		hudHint.Visible = false
		Announcer.say({ key = "Boom", sub = S.StreakReset, merge = false })
		setBomb(h, nil)
		practice.holder = nil
		return
	end
	if h == player and root then
		-- the defuse pad
		if pad then
			local d = (root.Position - pad.Position) * Vector3.new(1, 0, 1)
			if d.Magnitude <= LC.DEFUSE_RADIUS and math.abs(root.Position.Y - pad.Position.Y) < 6 then
				FxController.defuse(root.Position, practice.explodeAt - t <= Config.Bomb.CLUTCH_WINDOW)
				streak += 1
				best = math.max(best, streak)
				setBomb(player, nil)
				practice.holder = nil
				hud.Visible = false
				hudHint.Visible = false
				Announcer.say({
					key = "Defused",
					sub = S.Streak:format(streak) .. "  ·  " .. S.Best:format(best),
					merge = false,
				})
				return
			end
		end
		-- bump a dummy to pass it
		for _, d in ipairs(dummies) do
			local dp = hostPos(d)
			local justGave = d == practice.from and os.clock() - practice.handedAt < LC.PRACTICE_REGRAB
			if dp and not justGave and ((dp - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= LC.PRACTICE_REACH then
				streak += 1
				hand(d)
				break
			end
		end
	elseif h ~= player and root and os.clock() >= practice.releaseAt then
		-- the dummy hands it back if you're close enough; otherwise it holds on (and booms)
		local dp = hostPos(h)
		if dp and ((dp - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= LC.DUMMY_RETURN then
			hand(player)
		end
	end
	if practice.holder then
		hud.Text = S.Streak:format(streak) .. "  ·  " .. S.Best:format(best)
	end
end

-- ── The clock tower ───────────────────────────────────────────────────────────────────────────────────────────
local spiral: { BasePart } = {}
local spark: BasePart? = nil
local faceLabel: TextLabel? = nil
local towerFace: BombFace.Rig? = nil
local towerWasLive = false

local function buildTowerBomb(tower: Instance)
	local mount = tower:FindFirstChild("TowerBomb") :: BasePart?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb") :: Model?
	if not mount or not template then
		return
	end
	local model = template:Clone()
	model.Name = "FV_TowerBomb"
	local m =
		new("Part", { Name = "Mount", Size = Vector3.one * 0.2, Transparency = 1, CanCollide = false, Parent = model })
	model.PrimaryPart = m
	m.CFrame = CFrame.new()
	local scale = 3
	model:ScaleTo(scale)
	towerFace = BombFace.attach(model, m, scale)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= m and not BombFace.isFace(d) then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			new("WeldConstraint", { Part0 = m, Part1 = d, Parent = d })
		end
	end
	model:PivotTo(CFrame.lookAt(mount.Position, mount.Position + Vector3.new(0, 0, -1)))
	m.Anchored = true
	model.Parent = tower
end

local function towerStep(dt: number)
	local t = workspace:GetServerTimeNow()
	local live = gs:GetAttribute("MegaId") ~= nil
	local nextAt = gs:GetAttribute("MegaNextAt")
	local slot = Config.Mega.SLOT_MINUTES * 60
	local frac = if live then 1 elseif type(nextAt) == "number" then math.clamp(1 - (nextAt - t) / slot, 0, 1) else 0
	local n = #spiral
	local k = math.floor(frac * n)
	for i, seg in ipairs(spiral) do
		seg.Color = if i <= k then Color3.fromRGB(42, 31, 26) else Color3.fromRGB(201, 165, 116)
	end
	if spark and n > 0 then
		local seg = spiral[math.clamp(k + 1, 1, n)]
		spark.Position = seg.Position
		spark.Size = Vector3.one * (0.8 + 0.25 * math.sin(os.clock() * 30))
	end
	if faceLabel then
		local phase = ClientState.phase()
		local left = math.max(0, math.ceil((gs:GetAttribute("PhaseEndsAt") or 0) - t))
		if phase == Ph.Intermission then
			faceLabel.Text = S.NextRound:format(left)
		elseif live then
			faceLabel.Text = S.Mega .. "\n" .. S.MegaLive
		else
			faceLabel.Text = S.Mega
				.. "\n"
				.. S.MegaIn:format(clock(if type(nextAt) == "number" then nextAt - t else 0))
		end
	end
	if towerFace then
		local pose = if live then "PANIC" elseif frac > 0.85 then "UHOH" else "SMUG"
		BombFace.update(towerFace, dt, pose, nil, pose == "SMUG", if live then Config.Feel.FACE_SHAKE else 0)
	end
	if live and not towerWasLive and spark then -- the event starts: the tower bomb bursts
		FxController.boom(spark.Position + Vector3.new(0, 6, 0), 1.6, true)
	end
	towerWasLive = live
end

-- ── The shop plinths (today's featured bomb skins) and the quest board ────────────────────────────────────────
local plinths: { BasePart } = {}
local plinthModels: { Model } = {}
local shownFeatured = ""
local cards: { BasePart } = {}

local function showFeatured(s: { [string]: any })
	local feat = s.store and s.store.featured or {}
	local key = table.concat(feat, ",")
	if key == shownFeatured then
		return
	end
	shownFeatured = key
	for _, m in ipairs(plinthModels) do
		m:Destroy()
	end
	table.clear(plinthModels)
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb") :: Model?
	if not template then
		return
	end
	local slot = 1
	for _, id in ipairs(feat) do
		local item = St.ById[id]
		local plinth = plinths[slot]
		if item and item.category == "BombSkin" and plinth then
			local model = template:Clone()
			SkinApply.apply(model, id)
			BombFace.pose(model, "SMUG")
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			model:SetAttribute("Base", plinth.Position + Vector3.new(0, 2.2, 0))
			model:PivotTo(CFrame.new(plinth.Position + Vector3.new(0, 2.2, 0)))
			model.Parent = lobby
			table.insert(plinthModels, model)
			slot += 1
		end
	end
end

local function questText(id: string, target: number): string
	local t = (Config.Strings.Quests :: any)[id] or id
	return if string.find(t, "%%d") then string.format(t, target) else t
end

local function showQuests(s: { [string]: any })
	local qs = s.daily and s.daily.quests or {}
	for i, card in ipairs(cards) do
		local gui = card:FindFirstChild("Card") :: SurfaceGui?
		if not gui then
			gui = new("SurfaceGui", {
				Name = "Card",
				Face = Enum.NormalId.Front,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 60,
				LightInfluence = 0.4,
				Parent = card,
			}) :: SurfaceGui
			new("TextLabel", {
				Name = "Text",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = P.Ink,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextWrapped = true,
				Parent = gui,
			})
		end
		local q = qs[i]
		local label = (gui :: SurfaceGui):FindFirstChild("Text") :: TextLabel
		label.Text = if q then ("%s\n\n%d / %d"):format(questText(q.id, q.target), q.progress, q.target) else ""
	end
end

-- ── The leaderboard wall ──────────────────────────────────────────────────────────────────────────────────────
local function showBoard(part: BasePart, key: string)
	local gui = part:FindFirstChild("Board") :: SurfaceGui?
	if not gui then
		gui = new("SurfaceGui", {
			Name = "Board",
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0.3,
			Parent = part,
		}) :: SurfaceGui
		new("TextLabel", {
			Name = "Title",
			Size = UDim2.fromScale(1, 0.16),
			BackgroundTransparency = 1,
			TextColor3 = P.Spark,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			Text = (S.Boards :: any)[key] or key,
			Parent = gui,
		})
		new("TextLabel", {
			Name = "Rows",
			Position = UDim2.fromScale(0.06, 0.2),
			Size = UDim2.fromScale(0.88, 0.76),
			BackgroundTransparency = 1,
			TextColor3 = P.Paper,
			Font = Enum.Font.GothamMedium,
			TextSize = 30, -- fixed: eight rows fit the board (scaled text blew one row up to the board's size)
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = gui,
		})
	end
	local raw = gs:GetAttribute("LB_" .. key)
	local ok, rows = pcall(function()
		return if type(raw) == "string" then HttpService:JSONDecode(raw) else {}
	end)
	local lines = {}
	if ok and type(rows) == "table" then
		for i, r in ipairs(rows) do
			table.insert(lines, ("%d.  %s  —  %s"):format(i, tostring(r.name), tostring(r.value)))
		end
	end
	local label = (gui :: SurfaceGui):FindFirstChild("Rows") :: TextLabel
	label.Text = if #lines > 0 then table.concat(lines, "\n") else S.NoChampions
end

-- ── Going into a round: a quick flash hides the teleport ──────────────────────────────────────────────────────
local flash: Frame
local function flashOut()
	flash.BackgroundTransparency = 0
	TweenService:Create(
		flash,
		TweenInfo.new(LC.FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

function DepotController.start()
	local found = workspace:WaitForChild("Lobby", 20)
	if not found or not found:IsA("Model") then
		return
	end
	lobby = found
	-- the stations (the lobby streams as one persistent model; wait for them anyway, they may still be arriving)
	for _, n in ipairs({ "FuseRange", "ClockTower", "ShopKiosk", "QuestBoard", "LeaderboardWall", "VipLounge" }) do
		lobby:WaitForChild(n, 10)
	end
	local range0 = lobby:FindFirstChild("FuseRange")
	if range0 then
		range0:WaitForChild("DefusePad", 10)
		local dm0 = range0:WaitForChild("Dummies", 10)
		if dm0 then
			dm0:WaitForChild("Dummy3", 10)
		end
	end
	local tower0 = lobby:FindFirstChild("ClockTower")
	if tower0 then
		tower0:WaitForChild("TowerBomb", 10)
		tower0:WaitForChild("ClockFace", 10)
		local sp0 = tower0:WaitForChild("SpiralFuse", 10)
		if sp0 then
			sp0:WaitForChild("Seg54", 10)
		end
	end
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local gui = new("ScreenGui", {
		Name = "FV_Depot",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	hud = Theme.display(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(520, 44),
		TextSize = 34,
		TextColor3 = P.Spark,
		Text = "",
		Visible = false,
	}) :: TextLabel
	hudHint = Theme.display(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 194),
		Size = UDim2.fromOffset(560, 26),
		TextSize = 18,
		TextColor3 = P.Paper,
		Text = S.PracticeHint,
		Visible = false,
	}) :: TextLabel
	flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	}) :: Frame
	-- the stations
	local range = lobby:FindFirstChild("FuseRange")
	local dm = range and range:FindFirstChild("Dummies")
	if dm then
		for _, d in ipairs(dm:GetChildren()) do
			if d:IsA("Model") then
				table.insert(dummies, d)
			end
		end
	end
	pad = range and range:FindFirstChild("DefusePad") :: BasePart?
	local tower = lobby:FindFirstChild("ClockTower")
	if tower then
		local sp = tower:FindFirstChild("SpiralFuse")
		if sp then
			for _, seg in ipairs(sp:GetChildren()) do
				if seg:IsA("BasePart") then
					table.insert(spiral, seg)
				end
			end
			table.sort(spiral, function(a, b)
				return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
			end)
		end
		spark = tower:FindFirstChild("Spark") :: BasePart?
		local face = tower:FindFirstChild("ClockFace")
		local signGui = face and face:FindFirstChild("Sign")
		faceLabel = signGui and signGui:FindFirstChildOfClass("TextLabel")
		buildTowerBomb(tower)
	end
	local shop = lobby:FindFirstChild("ShopKiosk")
	if shop then
		for _, d in ipairs(shop:GetChildren()) do
			if d:IsA("BasePart") and string.match(d.Name, "^Plinth%d$") then
				table.insert(plinths, d)
			end
		end
		table.sort(plinths, function(a, b)
			return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
		end)
	end
	local qb = lobby:FindFirstChild("QuestBoard")
	if qb then
		for i = 1, 3 do
			local c = qb:FindFirstChild("Card" .. i)
			if c and c:IsA("BasePart") then
				table.insert(cards, c)
			end
		end
	end
	local wall = lobby:FindFirstChild("LeaderboardWall")
	local function boards()
		if not wall then
			return
		end
		for _, key in ipairs({ "Wins", "Clutches", "Booms" }) do
			local b = wall:FindFirstChild("Board_" .. key)
			if b and b:IsA("BasePart") then
				showBoard(b, key)
			end
		end
	end
	boards()
	for _, key in ipairs({ "Wins", "Clutches", "Booms" }) do
		gs:GetAttributeChangedSignal("LB_" .. key):Connect(boards)
	end
	-- the VIP gate: VIP pass owners walk through it on their own client
	local vip = lobby:FindFirstChild("VipLounge")
	local gate = vip and vip:FindFirstChild("VipGate") :: BasePart?
	local function vipGate()
		if gate then
			local isVip = player:GetAttribute("VIP") == true
			gate.CanCollide = not isVip
			gate.Transparency = if isVip then 0.85 else 0.45
		end
	end
	vipGate()
	player:GetAttributeChangedSignal("VIP"):Connect(vipGate)
	-- prompts
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if not prompt:IsDescendantOf(lobby) then
			return
		end
		if prompt.Name == "ShopPrompt" then
			StoreController.open("Shop")
		elseif prompt.Name == "QuestPrompt" then
			DailyController.open("Quests")
		elseif prompt.Name == "PracticePrompt" then
			give()
		elseif prompt.Name == "FireworkPrompt" and player:GetAttribute("VIP") ~= true then
			hud.Text = S.VipOnly
			hud.Visible = true
			task.delay(1.6, function()
				if not practice.holder then
					hud.Visible = false
				end
			end)
		end
	end)
	-- live data
	Progress.start()
	local function apply()
		local s = Progress.get()
		if s then
			showFeatured(s)
			showQuests(s)
		end
	end
	apply()
	Progress.Changed:Connect(apply)
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if ClientState.phase() == Ph.Intro then
			clearPractice()
			flashOut()
		end
	end)
	Net.listen("RoundFx", function(p)
		if type(p) == "table" and p.kind == "VipFirework" and typeof(p.pos) == "Vector3" then
			for i = 0, 2 do
				task.delay(i * 0.35, function()
					FxController.boom(
						(p.pos :: Vector3) + Vector3.new(math.random(-6, 6), 26 + i * 4, math.random(-6, 6)),
						1,
						true
					)
				end)
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		practiceStep()
		towerStep(dt)
		for _, m in ipairs(plinthModels) do
			local base = m:GetAttribute("Base")
			if typeof(base) == "Vector3" then
				m:PivotTo(
					CFrame.new(base + Vector3.new(0, math.sin(os.clock() * 2) * 0.15, 0))
						* CFrame.Angles(0, os.clock() * 0.8, 0)
				)
			end
		end
	end)
end

return DepotController
