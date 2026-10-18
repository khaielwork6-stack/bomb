--!strict
-- The "NEXT MAP" vote card (the owner's reference video; DECISIONS 2026-10-17 "extras"): in intermission, a blue
-- header card with the countdown and one big thumbnail card per map (its name in a slanted plate, a "FEATURED" /
-- size tag, the live vote count and the voters' avatar heads), "Click or Press 1/2". The pick lights up gold.
-- Server side is the partner's (docs/PARTNER_REQUESTS.md #1): the card shows while ReplicatedStorage.GameState has a
-- `VoteOptions` attribute (JSON: [{ id, name, tag, thumb }]) and reads `VoteCounts` (JSON: { [id] = { userIds } }) and
-- `VoteEndsAt` (server time); a tap fires the `VoteMap` remote with the map id once it exists.
-- Studio preview: set the player's FV_PreviewVote attribute to true.
-- Implements: map vote (client).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local MapVoteController = {}

type Option = { id: string, name: string, tag: string?, thumb: string? }

local gui: ScreenGui
local card: Frame? = nil
local myVote = ""
local preview = false
local previewCounts: { [string]: { number } } = {}

local function decode(v: any): any
	if type(v) ~= "string" or v == "" then
		return nil
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, v)
	return if ok then t else nil
end

local function vote(id: string)
	if myVote == id then
		return
	end
	myVote = id
	Sfx.play("UiPress")
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("VoteMap")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(id)
	elseif preview then
		for _, list in pairs(previewCounts) do
			local i = table.find(list, player.UserId)
			if i then
				table.remove(list, i)
			end
		end
		previewCounts[id] = previewCounts[id] or {}
		table.insert(previewCounts[id], player.UserId)
	end
end

local function close()
	local c = card
	card = nil
	if c then
		Widgets.springOut(c, function()
			c:Destroy()
		end)
	end
end

local function build(options: { Option }, endsAt: number)
	if card then
		card:Destroy()
	end
	local holder = new("Frame", {
		Name = "Vote",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(640, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	card = holder
	local fit = new("UIScale", { Parent = holder })
	local vp = gui.AbsoluteSize
	fit.Scale = math.min(1, (vp.Y - 120) / 320, (vp.X - 40) / 660)
	local body = Theme.panel(holder, {
		Size = UDim2.fromScale(1, 1),
		color = Color3.fromRGB(40, 38, 54),
		color2 = Color3.fromRGB(24, 22, 34),
		border = Color3.fromRGB(20, 18, 26),
	})
	-- the blue header strip
	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = body,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = head })
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(70, 170, 255), Color3.fromRGB(28, 100, 230)),
		Rotation = 90,
		Parent = head,
	})
	Widgets.label(head, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 30,
		font = Theme.Font.Display,
		stroke = 3,
		Text = S.Ui.NextMap,
		ZIndex = 4,
	})
	local timer = Widgets.label(head, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.fromOffset(80, 30),
		TextSize = 22,
		font = Theme.Font.Display,
		stroke = 2.5,
		Text = "",
		ZIndex = 4,
	})
	-- one card per map
	local row = new("Frame", {
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 196),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = body,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
		Parent = row,
	})
	local tiles: { [string]: { face: Frame, count: TextLabel, heads: Frame } } = {}
	for i, opt in ipairs(options) do
		local b = new("TextButton", {
			Name = opt.id,
			Size = UDim2.fromOffset(290, 196),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = 4,
			Parent = row,
		})
		local face = Theme.panel(b, {
			Size = UDim2.fromScale(1, 1),
			color = Color3.fromRGB(70, 160, 255),
			color2 = Color3.fromRGB(30, 90, 200),
			border = Color3.new(1, 1, 1),
		})
		local thumb = new("ImageLabel", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 1, -12),
			BackgroundTransparency = 1,
			Image = opt.thumb or "",
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 5,
			Parent = face,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = thumb })
		if opt.tag and opt.tag ~= "" then
			local tag = new("Frame", {
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(98, 22),
				BackgroundColor3 = P.Ink,
				ZIndex = 7,
				Parent = face,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = tag })
			new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = tag })
			Widgets.label(tag, {
				Size = UDim2.fromScale(1, 1),
				TextSize = 14,
				font = Theme.Font.Display,
				stroke = false,
				Text = string.upper(opt.tag),
				ZIndex = 8,
			})
		end
		local count = Widgets.label(face, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(60, 40),
			TextSize = 38,
			font = Theme.Font.Display,
			stroke = 3,
			align = Enum.TextXAlignment.Right,
			Text = "0",
			ZIndex = 8,
		})
		local heads = new("Frame", {
			Position = UDim2.new(0, 12, 1, -78),
			Size = UDim2.new(1, -24, 0, 30),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = face,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, -6),
			Parent = heads,
		})
		local plate = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundColor3 = Color3.fromRGB(20, 40, 90),
			BackgroundTransparency = 0.15,
			Rotation = -2,
			ZIndex = 7,
			Parent = face,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = plate })
		Widgets.label(plate, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 26,
			font = Theme.Font.Display,
			stroke = 3,
			Text = string.upper(opt.name),
			ZIndex = 8,
		})
		b.Activated:Connect(function()
			vote(opt.id)
		end)
		b.MouseEnter:Connect(function()
			Sfx.play("UiHover")
		end)
		tiles[opt.id] = { face = face, count = count, heads = heads }
	end
	Widgets.label(body, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(300, 24),
		TextSize = 18,
		font = Theme.Font.Display,
		stroke = 2,
		color = Color3.fromRGB(200, 196, 220),
		Text = S.Ui.VoteHint:format(#options),
		ZIndex = 4,
	})
	Widgets.springIn(holder)
	Sfx.play("UiOpen")
	-- live counts, voter heads, the countdown, the gold ring on my pick
	local headCache: { [number]: string } = {}
	local shown: { [string]: string } = {}
	task.spawn(function()
		while card == holder do
			local gs = ReplicatedStorage:FindFirstChild("GameState")
			local counts = if preview then previewCounts else (decode(gs and gs:GetAttribute("VoteCounts")) or {})
			for id, t in pairs(tiles) do
				local list = counts[id] or {}
				t.count.Text = tostring(#list)
				local key = table.concat(list, ",")
				if shown[id] ~= key then
					shown[id] = key
					for _, c in ipairs(t.heads:GetChildren()) do
						if c:IsA("ImageLabel") then
							c:Destroy()
						end
					end
					for k = 1, math.min(#list, 7) do
						local uid = list[k]
						local img = new("ImageLabel", {
							Size = UDim2.fromOffset(30, 30),
							BackgroundColor3 = Color3.fromRGB(240, 240, 250),
							Image = headCache[uid] or "",
							ZIndex = 9,
							Parent = t.heads,
						})
						new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = img })
						new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = img })
						if not headCache[uid] and uid > 0 then
							task.spawn(function()
								local ok, url = pcall(function()
									return Players:GetUserThumbnailAsync(
										uid,
										Enum.ThumbnailType.HeadShot,
										Enum.ThumbnailSize.Size48x48
									)
								end)
								if ok then
									headCache[uid] = url
									img.Image = url
								end
							end)
						end
					end
				end
				Theme.recolor(t.face, {
					border = if myVote == id then P.Spark else Color3.new(1, 1, 1),
					glow = if myVote == id then P.Spark else nil,
					glowT = 0.4,
				})
			end
			local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			timer.Text = ("0:%02d"):format(left)
			if left <= 0 and not preview then
				break
			end
			task.wait(0.25)
		end
	end)
end

local function refresh()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local opts = decode(gs and gs:GetAttribute("VoteOptions"))
	if type(opts) == "table" and #opts >= 2 then
		if not card then
			myVote = ""
			build(opts, (gs :: Instance):GetAttribute("VoteEndsAt") or (workspace:GetServerTimeNow() + 15))
		end
	elseif card and not preview then
		close()
	end
end

function MapVoteController.start()
	gui = new("ScreenGui", {
		Name = "FV_Vote",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 9,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local gs = ReplicatedStorage:WaitForChild("GameState")
	gs:GetAttributeChangedSignal("VoteOptions"):Connect(refresh)
	refresh()
	-- keys 1..n vote
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not card or UserInputService:GetFocusedTextBox() then
			return
		end
		local n = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 })[input.KeyCode]
		local row = n and card:FindFirstChild("Frame", true)
		if n and row then
			local i = 0
			for _, b in ipairs((card :: Frame):GetDescendants()) do
				if b:IsA("TextButton") and b.Name ~= "" and b.Size.X.Offset == 290 then
					i += 1
					if i == n then
						vote(b.Name)
					end
				end
			end
		end
	end)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("FV_PreviewVote"):Connect(function()
			if player:GetAttribute("FV_PreviewVote") then
				preview = true
				previewCounts = { Yard = { 1, 2, 3 }, Yard2 = { 4, 5 } }
				build({
					{ id = "Yard", name = "Fireworks Yard", tag = "Featured" },
					{ id = "Yard2", name = "Rooftop Pier", tag = "Big Field" },
				}, workspace:GetServerTimeNow() + 15)
			else
				preview = false
				close()
			end
		end)
	end
end

return MapVoteController
