--!strict
-- The results card (GDD §8.4, Asset Bible §7.2), on the partner's Skin kit: a slanted ribbon with the outcome, the
-- winners (avatar headshots for players; bots show their initial on a team-coloured chip) with the MVP called out,
-- then two columns — "your round" (a receipt whose lines print one after another) and the payout (each round key
-- with its XP and Stars, the round's callouts as "Moments", the Hot Streak / squad bonus), then the XP bar filling
-- (wrapping into a level-up), and, after your first win of the session, SHOW YOUR FRIENDS (F-SOC-04). Above the card
-- the top three stand on the 3D podium (UI/Podium; the MVP first, then crossings and defuses). The card fits the
-- screen (phones scale it down). Shown for RESULTS, gone at INTERMISSION. The round's best moment replays in the
-- corner card beside it (MomentController, F-FEEL-06).
-- Implements: F-RES-01, F-RES-02, F-PROG-01 (round payout shown), F-SOC-01 (streak line), F-SOC-03 (squad line),
-- F-SOC-04 (invite), F-FEEL-06 (the MOMENT OF THE ROUND card).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Screen = require(script.Parent.Parent.UI.Screen)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local TitleArt = require(script.Parent.Parent.UI.TitleArt)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Podium = require(script.Parent.Parent.UI.Podium)
local Progress = require(script.Parent.Parent.Progress)
local MomentController = require(script.Parent.MomentController)
local ProgressController = require(script.Parent.ProgressController)

local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local ResultsController = {}

local gui: ScreenGui
local card: Frame?
local face: Frame?
local pendingReward: any = nil
local invitedThisSession = false
local closeMoment: (() -> ())? = nil

local W, ROW = 660, 30

local OUTCOME = {
	LastStand = { title = S.Round.Victory, art = "Victory", color = P.Gold },
	Survivors = { title = S.Round.SurvivorsWinTitle, art = "SurvivorsWin", color = P.Runner },
	Bombers = { title = S.Round.BombersWinTitle, art = "BombersWin", color = P.Bomber },
}

local LINES = {
	{ key = "crossings", label = S.Round.Stats.crossings },
	{ key = "defuses", label = S.Round.Stats.defuses },
	{ key = "clutches", label = S.Round.Stats.clutches },
	{ key = "passes", label = S.Round.Stats.passes },
	{ key = "tags", label = S.Round.Stats.tags },
	{ key = "booms", label = S.Round.Stats.booms },
}

local function close()
	local c = card
	card, face, pendingReward = nil, nil, nil
	if closeMoment then
		closeMoment()
		closeMoment = nil
	end
	if c then
		Widgets.springOut(c, function()
			c:Destroy()
		end)
	end
end

local function nameOf(id: string): (string, number?, Model?)
	local host, model = ClientState.byId(id)
	if host and host:IsA("Player") then
		return host.DisplayName, host.UserId, model
	end
	return ClientState.nameOf(id), nil, model
end

-- A live 3D headshot of a character (bots have no Roblox thumbnail): a still clone in a ViewportFrame, framed on the
-- head, lit warm from the front.
local function headshot(parent: GuiObject, model: Model)
	local was = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	model.Archivable = was
	if not ok or not copy then
		return
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if
			d:IsA("Script")
			or d:IsA("LocalScript")
			or d:IsA("Sound")
			or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local head = copy:FindFirstChild("Head") :: BasePart?
	if not head then
		copy:Destroy()
		return
	end
	local vf = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 160),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.4, -0.6, -1),
		ZIndex = 4,
		Parent = parent,
	}) :: ViewportFrame
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = vf })
	copy.Parent = vf
	local cam = new("Camera", { FieldOfView = 30, Parent = vf }) :: Camera
	local look = head.CFrame
	cam.CFrame = CFrame.lookAt((look * CFrame.new(0, 0.15, -4.4)).Position, look.Position + Vector3.new(0, 0.05, 0))
	vf.CurrentCamera = cam
end

local function winnerChip(parent: Instance, id: string, order: number, mvp: boolean)
	local name, userId, model = nameOf(id)
	local chip = new("Frame", {
		Name = "Winner",
		Size = UDim2.fromOffset(94, 120),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local avatar = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = P.Ink2,
		Image = "",
		Parent = chip,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatar })
	new("UIStroke", { Color = if mvp then P.Gold else P.Fuse, Thickness = 3, Parent = avatar })
	if userId then
		task.spawn(function()
			local ok, img = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
			if ok then
				avatar.Image = img
			end
		end)
	elseif model then
		headshot(avatar, model)
	end
	if mvp then
		-- a gold MVP tag riding the top of the portrait
		local tag = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(46, 20),
			BackgroundColor3 = P.Gold,
			ZIndex = 6,
			Parent = chip,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = tag })
		new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = tag })
		Widgets.label(tag, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 13,
			font = Theme.Font.Display,
			color = P.Ink,
			stroke = false,
			Text = S.Round.MVP,
			ZIndex = 7,
		})
	end
	local label = Widgets.label(chip, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.new(1, 24, 0, 20),
		TextSize = 15,
		Text = name,
		color = if mvp then P.Gold else P.Paper,
		stroke = 1.5,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
end

-- The podium's top three: the MVP first, then the most crossings, then defuses (a Bombers win: the MVP alone).
local function topThree(payload: any): { Podium.Entry }
	local winners = if type(payload.winners) == "table" then table.clone(payload.winners) else {}
	local stats = if type(payload.stats) == "table" then payload.stats else {}
	if payload.outcome == "Bombers" and type(payload.mvp) == "string" then
		winners = { payload.mvp }
	end
	local function score(id: string): number
		if id == payload.mvp then
			return math.huge
		end
		local st = stats[id] or {}
		return (tonumber(st.crossings) or 0) * 100
			+ (tonumber(st.defuses) or 0) * 10
			+ (tonumber(st.clutches) or 0) * 20
	end
	table.sort(winners, function(a, b)
		return score(a) > score(b)
	end)
	local out = {}
	for i = 1, math.min(3, #winners) do
		local name = nameOf(winners[i])
		local _, model = ClientState.byId(winners[i])
		table.insert(out, { model = model, name = name, rank = i })
	end
	return out
end

local function column(parent: Instance, name: string, title: string, x: number): Frame
	local col = new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, 186),
		Size = UDim2.fromOffset(W / 2 - 40, 7 * ROW + 26),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	Widgets.label(col, {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		font = Theme.Font.Display,
		color = P.Ash,
		align = Enum.TextXAlignment.Left,
		Text = title,
		ZIndex = 4,
	})
	local list = new("Frame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = col,
	})
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	return list
end

-- A receipt line that prints in after `delay` seconds; `value` counts up. `stars`/`xp` add payout chips.
local function line(list: Frame, order: number, text: string, delay: number, opts: { [string]: any })
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, ROW - 2),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = list,
	})
	local lbl = Widgets.label(row, {
		Size = UDim2.new(0.62, 0, 1, 0),
		TextSize = 17,
		font = Theme.Font.Bold,
		align = Enum.TextXAlignment.Left,
		Text = text,
		color = opts.color or P.Paper,
		stroke = 1.5,
		ZIndex = 4,
	})
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	local right = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.38, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = row,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = right,
	})
	local nums: { TextLabel } = {}
	local function num(value: number, color: Color3, suffix: string, o: number)
		local l = Widgets.label(right, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, ROW - 2),
			TextSize = 18,
			color = color,
			Text = "",
			LayoutOrder = o,
			ZIndex = 5,
		})
		l:SetAttribute("Value", value)
		l:SetAttribute("Suffix", suffix)
		table.insert(nums, l)
	end
	if opts.value then
		num(opts.value, P.Spark, "", 1)
	end
	if opts.xp and opts.xp > 0 then
		num(opts.xp, P.Runner, " XP", 1)
	end
	if opts.stars and opts.stars > 0 then
		Widgets.icon(right, "Gem", 20, { LayoutOrder = 2 })
		num(opts.stars, P.Spark, "", 3)
	end
	row.Visible = false
	task.delay(delay, function()
		if row.Parent == nil then
			return
		end
		row.Visible = true
		Widgets.springIn(row, 0.8)
		if opts.stars and opts.stars > 0 then
			Sfx.play("CoinTick")
		end
		for _, l in ipairs(nums) do
			local v = l:GetAttribute("Value") :: number
			local suffix = l:GetAttribute("Suffix") :: string
			local prefix = if suffix == "" and not opts.value then "+" else (if suffix ~= "" then "+" else "")
			Widgets.countUp(l, 0, v, function(n)
				return prefix .. tostring(n) .. suffix
			end)
		end
	end)
end

-- ── The "next" hooks (F-RES-04): the two most relevant reasons to play one more round ──────────────────────────────
local function hooks(f: Frame, r: any)
	local s = Progress.get()
	local list = {}
	local need = (r.xpToNext or 0) - (r.xp or 0)
	if need > 0 and need <= 150 then
		table.insert(list, { icon = "Badge", text = ("1 more round to level %d"):format((r.level or 1) + 1) })
	end
	local d = s and s.daily
	if d then
		local best, bestFrac = nil, -1
		for _, q in ipairs(d.quests) do
			local frac = q.progress / math.max(1, q.target)
			if not q.done and frac > bestFrac then
				best, bestFrac = q, frac
			end
		end
		if best then
			local t = (S.Quests :: any)[best.id] or best.id
			t = if string.find(t, "%%d") then string.format(t, best.target) else t
			table.insert(list, { icon = "Scroll", text = ("%s %d/%d"):format(t, best.progress, best.target) })
		end
		local g = d.gift
		if g then
			local left = math.max(0, g.left - Progress.age())
			table.insert(list, {
				icon = "Gift",
				text = if g.ready or left <= 0 then "Gift ready!" else "Gift in " .. Widgets.clock(left),
			})
		end
	end
	local row = new("Frame", {
		Name = "Hooks",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -48, 0, 34),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = f,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for i = 1, math.min(2, #list) do
		local h = list[i]
		local chip = Theme.panel(row, {
			Name = "Hook" .. i,
			Size = UDim2.fromOffset(290, 34),
			radius = 999,
			color = P.Ink2,
			border = P.Spark,
			border2 = P.Gold,
		});
		(chip.Parent :: Frame).LayoutOrder = i
		Widgets.icon(chip, h.icon, 28, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			ZIndex = 5,
			tint = if h.icon == "Badge" then ProgressController.BADGE_TINT.Gold else nil,
		})
		local l = Widgets.label(chip, {
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -46, 1, 0),
			TextSize = 14,
			align = Enum.TextXAlignment.Left,
			Text = h.text,
			ZIndex = 5,
			stroke = 1.5,
		})
		l.TextTruncate = Enum.TextTruncate.AtEnd
		Widgets.springIn(chip.Parent :: Frame, 0.8)
	end
end

-- ── The payout (arrives a moment after RESULTS, per player) ─────────────────────────────────────────────────────
local function applyReward(r: any)
	local f = face
	if not f then
		pendingReward = r
		return
	end
	pendingReward = nil
	local list = f:FindFirstChild("Payout") and (f :: any).Payout:FindFirstChild("List")
	if not list then
		return
	end
	local delay = 0.5
	local order = 0
	local total = 0
	for _, l in ipairs(r.lines or {}) do
		order += 1
		local label = (S.Round :: any)[l.key] or l.key
		line(
			list,
			order,
			label,
			delay,
			{ xp = l.xp, stars = l.stars, color = if l.key == "FirstWinOfDay" then P.Gold else nil }
		)
		total += l.stars
		delay += 0.22
	end
	if (r.calloutXp or 0) > 0 or (r.calloutStars or 0) > 0 then
		order += 1
		line(list, order, S.Round.Callouts, delay, { xp = r.calloutXp, stars = r.calloutStars })
		delay += 0.22
	end
	if (r.bonus or 0) > 0 then
		order += 1
		local parts = {}
		if (r.mult or 1) > 1 then
			table.insert(parts, string.format(S.Ui.HotStreak, tostring(r.mult)))
		end
		if (r.squad or 0) > 0 then
			table.insert(parts, string.format(S.Ui.Squad, math.floor(r.squad * 100 + 0.5)))
		end
		if (r.vip or 0) > 0 then
			table.insert(parts, string.format(S.Ui.VipBonus, math.floor(r.vip * 100 + 0.5)))
		end
		line(list, order, table.concat(parts, " · "), delay, { stars = r.bonus, color = P.Ember })
		total += r.bonus
		delay += 0.22
	end
	task.delay(delay + 1.2, function()
		if face == f then
			hooks(f, r)
		end
	end)
	-- the stars fly into the counter once the receipt has printed
	task.delay(delay + 0.2, function()
		if face and total > 0 then
			local from = (face :: Frame).AbsolutePosition
				+ Vector2.new((face :: Frame).AbsoluteSize.X * 0.75, (face :: Frame).AbsoluteSize.Y * 0.6)
			ProgressController.fly(from, total)
		end
	end)
	-- the XP bar
	local xpRow = f:FindFirstChild("Xp") :: Frame?
	if xpRow then
		local levelLabel = xpRow:FindFirstChild("Level", true) :: TextLabel?
		local fill = xpRow:FindFirstChild("Fill", true) :: Frame?
		local caption = xpRow:FindFirstChild("Caption") :: TextLabel?
		if levelLabel and fill and caption then
			levelLabel.Text = tostring(r.levelBefore)
			fill.Size = UDim2.fromScale((r.xpBefore or 0) / math.max(1, r.xpToNextBefore or 1), 1)
			caption.Text = ("%d / %d XP"):format(r.xpBefore or 0, r.xpToNextBefore or 0)
			task.delay(delay + 0.3, function()
				if fill.Parent == nil then
					return
				end
				local levels = (r.level or 1) - (r.levelBefore or 1)
				for _ = 1, levels do
					TweenService
						:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 1) })
						:Play()
					task.wait(0.42)
					fill.Size = UDim2.fromScale(0, 1)
				end
				levelLabel.Text = tostring(r.level)
				TweenService:Create(
					fill,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad),
					{ Size = UDim2.fromScale((r.xp or 0) / math.max(1, r.xpToNext or 1), 1) }
				):Play()
				caption.Text = ("%d / %d XP"):format(r.xp or 0, r.xpToNext or 0)
			end)
		end
	end
end

local function show(payload: any)
	close()
	local o = OUTCOME[payload.outcome] or OUTCOME.Bombers
	local panelFace = Theme.panel(gui, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, 186 + 7 * ROW + 26 + 92 + 40),
		dots = o.color,
		dotsT = 0.88,
		glow = o.color,
		glowT = 0.55,
		border = o.color,
		border2 = o.color:Lerp(P.Ink, 0.4),
	})
	local holder = panelFace.Parent :: Frame
	card, face = holder, panelFace
	-- room for the podium above and the HUD's round chip at the top
	Screen.fit(holder, function(v)
		return math.min(1, (v.Y - 150) / (holder.Size.Y.Offset + Podium.HEIGHT), (v.X - 30) / W)
	end)
	local top = topThree(payload)
	if #top > 0 then
		holder.Position =
			UDim2.new(0.5, 0, 0.5, (Podium.HEIGHT / 2 + 36) * (holder:FindFirstChild("Fit") :: UIScale).Scale)
		Podium.build(holder, top, payload.outcome == "Bombers" and type(payload.mvp) == "string")
	end
	Widgets.springIn(holder)
	-- the outcome as title art across the card's top edge (the flat ribbon only if the art is missing)
	if TitleArt.has(o.art) then
		TitleArt.show(holder, o.art, { tier = "Callout", y = 0, hold = 0, zIndex = 8 })
	else
		Skin.ribbon(holder, o.title, o.color, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(360, 64),
			ZIndex = 5,
		})
	end
	-- Winners
	local row = new("Frame", {
		Name = "Winners",
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.new(1, -40, 0, 124),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = panelFace,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local winners = if type(payload.winners) == "table" then payload.winners else {}
	if payload.outcome == "Bombers" and type(payload.mvp) == "string" then
		winnerChip(row, payload.mvp, 0, true)
	else
		for i = 1, math.min(#winners, 6) do
			winnerChip(row, winners[i], i, false)
		end
	end
	-- Your round (the receipt) | the payout
	local mine = type(payload.stats) == "table" and payload.stats[ClientState.myId()] or nil
	local stats = column(panelFace, "Round", S.Round.YourRound, 24)
	column(panelFace, "Payout", S.Round.Payout, W / 2 + 16)
	if not mine then
		Widgets.label(stats, {
			Size = UDim2.new(1, 0, 0, ROW),
			TextSize = 18,
			color = P.Ash,
			align = Enum.TextXAlignment.Left,
			Text = S.Round.Watched,
		})
	else
		local shown = 0
		for i, l in ipairs(LINES) do
			local value = tonumber(mine[l.key]) or 0
			if value > 0 or l.key == "crossings" then
				shown += 1
				line(stats, i, l.label, 0.3 + shown * 0.18, { value = value })
			end
		end
	end
	-- The XP bar across the bottom
	local xpRow = new("Frame", {
		Name = "Xp",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -58),
		Size = UDim2.new(1, -48, 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = panelFace,
	})
	local badge = Widgets.icon(xpRow, "Badge", 48, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		tint = ProgressController.BADGE_TINT.Bronze,
		ZIndex = 4,
	})
	Widgets.label(badge.Parent :: Frame, {
		Name = "Level",
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		font = Theme.Font.Display,
		Text = tostring(player:GetAttribute("Level") or 1),
		ZIndex = 6,
	})
	local _, setBar = Widgets.bar(xpRow, UDim2.new(1, -250, 0, 16), P.Runner, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 58, 0.5, 6),
		ZIndex = 4,
	})
	setBar(0, true)
	Widgets.label(xpRow, {
		Name = "Caption",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 58, 0.5, -4),
		Size = UDim2.new(1, -250, 0, 16),
		TextSize = 13,
		align = Enum.TextXAlignment.Left,
		Text = "",
		stroke = 1.5,
		ZIndex = 4,
	})
	-- F-SOC-04: after your first win of the session, once
	local won = table.find(winners, ClientState.myId()) ~= nil
		or (payload.outcome == "Bombers" and player:GetAttribute("Role") == Types.Role.Bomber)
	if won and not invitedThisSession then
		invitedThisSession = true
		task.spawn(function()
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can and face == panelFace then
				Widgets.button(
					xpRow,
					S.Ui.InviteFriends,
					"cyan",
					UDim2.fromOffset(178, 42),
					function()
						pcall(SocialService.PromptGameInvite, SocialService, player)
					end,
					{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), TextSize = 15, ZIndex = 6 }
				)
			end
		end)
	end
	if payload.moment ~= nil then
		closeMoment = MomentController.show(gui, payload.moment)
	end
	if pendingReward then
		applyReward(pendingReward)
	end
end

function ResultsController.start()
	gui = new("ScreenGui", {
		Name = "FV_Results",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.listen("RoundFx", function(p)
		if type(p) == "table" and p.kind == "Results" then
			show(p)
		end
	end)
	Net.listen("Reward", function(r)
		if type(r) == "table" and r.kind == "Round" then
			applyReward(r)
		end
	end)
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if ClientState.phase() ~= Types.Phase.Results then
			close()
		end
	end)
end

return ResultsController
