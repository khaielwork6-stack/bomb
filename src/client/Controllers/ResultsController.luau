--!strict
-- The results card (GDD §8.4, Asset Bible §7.2), on the partner's Skin kit: a slanted ribbon with the outcome, the
-- winners (avatar headshots for players; bots show their initial on a team-coloured chip) with the MVP called out,
-- and "your round" — a receipt whose lines count up one after another. P4 adds the XP / Stars payouts and the
-- "next" hooks to the same card. Shown for RESULTS, gone at INTERMISSION.
-- Implements: F-RES-01, F-RES-02 (P3 part).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local ResultsController = {}

local gui: ScreenGui
local card: Frame?

local OUTCOME = {
	LastStand = { title = "VICTORY", color = P.Gold },
	Survivors = { title = "SURVIVORS WIN", color = P.Runner },
	Bombers = { title = "BOMBERS WIN", color = P.Bomber },
}

local LINES = {
	{ key = "crossings", label = "Crossings survived" },
	{ key = "defuses", label = "Bombs defused" },
	{ key = "clutches", label = "Clutch defuses" },
	{ key = "passes", label = "Passes" },
	{ key = "tags", label = "Bombs stuck" },
	{ key = "booms", label = "Booms" },
}

local function close()
	local c = card
	card = nil
	if c then
		local scale = c:FindFirstChildOfClass("UIScale")
		if scale then
			TweenService
				:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 })
				:Play()
		end
		task.delay(0.2, function()
			c:Destroy()
		end)
	end
end

local function nameOf(id: string): (string, number?)
	local host, model = ClientState.byId(id)
	if host and host:IsA("Player") then
		return host.DisplayName, host.UserId
	end
	return if model then model.Name else id, nil
end

local function winnerChip(parent: Instance, id: string, order: number, mvp: boolean)
	local name, userId = nameOf(id)
	local chip = new("Frame", {
		Name = "Winner",
		Size = UDim2.fromOffset(104, 128),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local face = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = P.Ink2,
		Image = "",
		Parent = chip,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = face })
	new("UIStroke", { Color = if mvp then P.Gold else P.Fuse, Thickness = 3, Parent = face })
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
				face.Image = img
			end
		end)
	else
		Theme.display(face, { Text = string.upper(string.sub(name, 1, 1)), TextSize = 40, color = P.Paper })
	end
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(1, 8, 0, 20),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Heavy,
		TextSize = 15,
		TextColor3 = P.Paper,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
		Parent = chip,
	})
	if mvp then
		label.Text = "MVP · " .. name
		label.TextColor3 = P.Gold
	end
end

local function show(payload: any)
	close()
	local o = OUTCOME[payload.outcome] or OUTCOME.Bombers
	local panel = Theme.panel(gui, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 420),
		dots = o.color,
		dotsT = 0.88,
		glow = o.color,
		glowT = 0.55,
		border = o.color,
		border2 = o.color:Lerp(P.Ink, 0.4),
	})
	local holder = panel.Parent :: Frame
	card = holder
	local scale = new("UIScale", { Scale = 0.85, Parent = holder })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	Skin.ribbon(holder, o.title, o.color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(360, 64),
		ZIndex = 5,
	})
	-- Winners
	local row = new("Frame", {
		Name = "Winners",
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 0, 132),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = panel,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local winners = if type(payload.winners) == "table" then payload.winners else {}
	if payload.outcome == "Bombers" and type(payload.mvp) == "string" then
		winnerChip(row, payload.mvp, 0, true)
	else
		for i = 1, math.min(#winners, 5) do
			winnerChip(row, winners[i], i, false)
		end
	end
	-- Your round (the receipt)
	local mine = type(payload.stats) == "table" and payload.stats[ClientState.myId()] or nil
	local list = new("Frame", {
		Name = "Round",
		Position = UDim2.fromOffset(40, 196),
		Size = UDim2.new(1, -80, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = panel,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	if not mine then
		Theme.display(list, { Text = "You watched this one", TextSize = 22, font = Theme.Font.Heavy, color = P.Ash })
		return
	end
	local shown = 0
	for i, line in ipairs(LINES) do
		local value = tonumber(mine[line.key]) or 0
		if value > 0 or line.key == "crossings" then
			shown += 1
			local rowF = new("Frame", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = list,
			})
			local lbl = new("TextLabel", {
				Size = UDim2.new(0.75, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Bold,
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = P.Paper,
				TextTransparency = 1,
				Text = line.label,
				Parent = rowF,
			})
			local num = new("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.25, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Heavy,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = P.Spark,
				TextTransparency = 1,
				Text = "0",
				Parent = rowF,
			})
			-- Lines print one after another, numbers count up (Asset Bible §6.5).
			task.delay(0.35 + shown * 0.22, function()
				if rowF.Parent == nil then
					return
				end
				TweenService:Create(lbl, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
				TweenService:Create(num, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
				local t0 = os.clock()
				while os.clock() - t0 < 0.4 and num.Parent do
					num.Text = tostring(math.floor(value * (os.clock() - t0) / 0.4 + 0.5))
					task.wait()
				end
				num.Text = tostring(value)
			end)
		end
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
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		if ClientState.phase() ~= Types.Phase.Results then
			close()
		end
	end)
end

return ResultsController
