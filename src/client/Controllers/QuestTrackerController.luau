--!strict
-- The quest tracker on the left edge (GDD §14.1 F-DAILY-04, §21.2; Asset Bible §6.6): collapsed it's three small
-- tier-coloured progress rings (phones), expanded three rows — tier stripe, quest text, a bar and the count (PC
-- default). A tick fills the bar and pops a "+1"; a finished quest turns to a check. Tapping the header toggles it,
-- tapping a row opens the Quests screen. It stays up in rounds (it's what you're playing for) and first slides in
-- after a new player's second round (F-ONB-06).
-- Implements: F-DAILY-04 (tracker), F-ONB-06 (reveal), F-UI-02 (left edge).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Progress = require(script.Parent.Parent.Progress)
local Sfx = require(script.Parent.Parent.Sfx)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local DailyController = require(script.Parent.DailyController)

-- the tracker sits right of the left dock column (DailyController: the tiles + their 14 px margin and badges)
local DOCK_GAP = 16 -- px between the dock's right edge and the tracker

local S = Config.Strings
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local QuestTrackerController = {}

local TIER_COLOR = { Easy = P.Safe, Medium = P.Spark, Hard = P.Bomber }
local SEG = 12
local UNLIT = P.Ash:Lerp(P.Ink2, 0.45) -- unlit ring segments: visible on the dark row, clearly "not yet"

type Row = {
	frame: Frame,
	ringDots: { Frame },
	ringLabel: TextLabel,
	text: TextLabel,
	count: TextLabel,
	setBar: (number, boolean?) -> (),
	check: Frame,
	id: string,
	progress: number,
}

local gui: ScreenGui
local root: Frame
local rows: { Row } = {}
local expanded = false
local headerText: TextLabel? = nil
local revealed = false

-- phones and short screens keep the rows folded to the rings (they'd crowd the top pills); a tap still opens them
local function roomy(): boolean
	return not Screen.touch() and not Screen.compact()
end

local function questText(id: string, target: number): string
	local t = (S.Quests :: any)[id] or id
	return if string.find(t, "%%d") then string.format(t, target) else t
end

local function pop(row: Row)
	if Widgets.reduced() then
		return
	end
	local plus = Widgets.label(row.frame, {
		Text = "+1",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(40, 24),
		TextSize = 20,
		font = Theme.Font.Display,
		color = P.Spark,
		ZIndex = 9,
	})
	TweenService:Create(plus, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 22, 0.5, -34),
		TextTransparency = 1,
	}):Play()
	task.delay(0.72, function()
		plus:Destroy()
	end)
end

local function layout()
	for _, r in ipairs(rows) do
		r.text.Visible = expanded
		r.count.Visible = expanded
		local bar = r.frame:FindFirstChild("Bar") :: Frame?
		if bar then
			bar.Visible = expanded
		end
		r.frame.Size = UDim2.fromOffset(if expanded then 250 else 46, 46)
	end
	root.Size = UDim2.fromOffset(if expanded then 260 else 56, 3 * 52 + 30)
	if headerText then
		headerText.Visible = expanded -- folded: just the scroll icon over the rings
	end
end

local function build()
	gui = new("ScreenGui", {
		Name = "FV_Quests",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = new("Frame", {
		Name = "Tracker",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -300, 0.4, 0),
		Size = UDim2.fromOffset(260, 186),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local header = new("TextButton", {
		Name = "Header",
		Size = UDim2.fromOffset(160, 26),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = root,
	})
	Widgets.icon(header, "Scroll", 26, { Position = UDim2.fromOffset(4, 0), ZIndex = 4 })
	headerText = Widgets.label(header, {
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.fromOffset(126, 26),
		TextSize = 15,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		Text = S.Ui.QuestsTitle,
		ZIndex = 4,
	})
	header.Activated:Connect(function()
		Sfx.play("UiPress")
		expanded = not expanded
		layout()
	end)
	for i = 1, 3 do
		local row = new("TextButton", {
			Name = "Row" .. i,
			Position = UDim2.fromOffset(0, 30 + (i - 1) * 52),
			Size = UDim2.fromOffset(250, 46),
			BackgroundColor3 = P.Ink2,
			BackgroundTransparency = 0.15,
			Text = "",
			AutoButtonColor = false,
			Parent = root,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = row })
		new("UIStroke", { Color = P.Ink, Thickness = 3, Parent = row })
		-- the ring
		local ring = new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 23, 0.5, 0),
			Size = UDim2.fromOffset(38, 38),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = row,
		})
		local dots = {}
		for k = 1, SEG do
			local a = (k - 1) / SEG * math.pi * 2
			local dot = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + math.sin(a) * 0.42, 0.5 - math.cos(a) * 0.42),
				Size = UDim2.fromOffset(5, 8),
				Rotation = math.deg(a),
				BackgroundColor3 = UNLIT,
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = ring,
			})
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
			table.insert(dots, dot)
		end
		local ringLabel = Widgets.label(ring, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 12,
			Text = "",
			ZIndex = 5,
			stroke = 1.5,
		})
		local check = new("Frame", {
			Name = "Check",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 6,
			Parent = ring,
		})
		Widgets.icon(check, "Check", 34, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 7,
		})
		local text = Widgets.label(row, {
			Name = "Text",
			Position = UDim2.fromOffset(48, 3),
			Size = UDim2.fromOffset(190, 20),
			TextSize = 13,
			align = Enum.TextXAlignment.Left,
			Text = "",
			ZIndex = 4,
			stroke = 1.5,
		})
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local _, setBar = Widgets.bar(row, UDim2.fromOffset(150, 10), P.Spark, {
			Position = UDim2.fromOffset(48, 28),
			ZIndex = 4,
		})
		local count = Widgets.label(row, {
			Name = "Count",
			Position = UDim2.fromOffset(200, 24),
			Size = UDim2.fromOffset(44, 18),
			TextSize = 12,
			Text = "",
			ZIndex = 4,
			stroke = 1.5,
		})
		row.Activated:Connect(function()
			Sfx.play("UiPress")
			DailyController.open("Quests")
		end)
		table.insert(rows, {
			frame = row :: any,
			ringDots = dots,
			ringLabel = ringLabel,
			text = text,
			count = count,
			setBar = setBar,
			check = check,
			id = "",
			progress = -1,
		})
	end
end

-- just right of the dock (one or two columns, at its scale)
local function besideDock(): UDim2
	return UDim2.new(0, 14 + Screen.safe().left + DailyController.dockWidth() + DOCK_GAP, 0.4, 0)
end

local function apply(s: { [string]: any })
	local d = s.daily
	if not d then
		return
	end
	-- F-ONB-06: new players meet the tracker after their second round
	local should = (d.flags and d.flags.questsIntro) or (s.rounds or 0) >= 2
	if should and not revealed then
		revealed = true
		TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = besideDock(),
		}):Play()
	end
	for i, r in ipairs(rows) do
		local q = d.quests[i]
		r.frame.Visible = q ~= nil
		if q then
			local color = TIER_COLOR[q.tier] or P.Paper
			local frac = q.progress / math.max(1, q.target)
			local lit = math.floor(frac * SEG + 0.5)
			for k, dot in ipairs(r.ringDots) do
				dot.BackgroundColor3 = if k <= lit then color else UNLIT
			end
			r.text.Text = questText(q.id, q.target)
			r.count.Text = ("%d/%d"):format(q.progress, q.target)
			r.ringLabel.Text = if q.done then "" else tostring(q.progress)
			r.check.Visible = q.done
			local fill = r.frame:FindFirstChild("Bar") and (r.frame :: any).Bar:FindFirstChild("Fill")
			if fill then
				fill.BackgroundColor3 = color
			end
			local ticked = r.id == q.id and q.progress > r.progress and r.progress >= 0
			r.setBar(frac, r.id ~= q.id)
			if ticked then
				pop(r)
				Sfx.play("CoinTick")
			end
			r.id, r.progress = q.id, q.progress
		end
	end
end

function QuestTrackerController.start()
	Progress.start()
	build()
	-- the rows stay out of the field during a round (§21.1): collapsed to the rings while playing, expanded between
	-- rounds on PC (a tap still toggles them until the next phase change)
	local function auto()
		local ph = ClientState.phase()
		local lobby = ph == Types.Phase.Intermission or ph == Types.Phase.Results or ph == Types.Phase.Boot or ph == ""
		expanded = lobby and roomy()
		layout()
	end
	auto()
	Screen.Changed:Connect(function()
		auto()
		if revealed then
			root.Position = besideDock()
		end
	end)
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	gs:GetAttributeChangedSignal("Phase"):Connect(auto)
	Progress.Changed:Connect(apply)
	local s = Progress.get()
	if s then
		apply(s)
	end
end

return QuestTrackerController
