--!strict
-- Nametags (GDD §12.3, Asset Bible §8.4; ART_BACKLOG §1): over everyone else's head, their name in the round arcade
-- type with the level badge beside it (the frame changes every Config.Economy.BADGE_EVERY levels: bronze → silver →
-- gold → platinum → obsidian; bronze is the 3D badge, the rest tint its mask), and under it the equipped title
-- (Eq_Title) on a brass plate whose rim takes the title's rarity colour. Sized in studs, so it shrinks with distance,
-- and gone past MAX_DISTANCE. Your own tag isn't drawn. Bots wear theirs from the DisplayName attribute.
-- Pure presentation: reads Level / Eq_Title / DisplayName on each host (Player or bot model).
-- Implements: F-PROG-02 (level shown to others), AB §8.4 (title plate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Skin = require(script.Parent.Parent.UI.Skin)
local Theme = require(script.Parent.Parent.UI.Theme)
local ProgressController = require(script.Parent.ProgressController)

local St = Config.Store
local E = Config.Economy
local new = Theme.new
local player = Players.LocalPlayer

local NametagController = {}

local WIDTH, NAME_H, PLATE_H = 4.2, 0.95, 0.55 -- studs (a name never spills into the next head's tag)
local OFFSET = 2.35 -- above the head's centre
local MAX_DISTANCE = 90
local PLATE_FILL = { Color3.fromRGB(255, 226, 150), Color3.fromRGB(200, 146, 52) }

type Tag = {
	gui: BillboardGui,
	name: TextLabel,
	badge: ImageLabel,
	level: TextLabel,
	plate: Frame,
	plateText: TextLabel,
	plateRim: UIStroke,
	lastTitle: string?,
}

local tags: { [Model]: Tag } = {}

local function hosts(): { Instance }
	local out: { Instance } = Players:GetPlayers()
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			table.insert(out, m)
		end
	end
	return out
end

local function characterOf(host: Instance): Model?
	if host:IsA("Player") then
		return host.Character
	end
	return if host:IsA("Model") then host else nil
end

local function badgeTier(level: number): string
	local i = math.clamp(math.floor(level / E.BADGE_EVERY) + 1, 1, #E.BADGES)
	return E.BADGES[i]
end

local function build(head: BasePart): Tag
	local gui = new("BillboardGui", {
		Name = "FV_Nametag",
		Adornee = head,
		Size = UDim2.fromScale(WIDTH, NAME_H + PLATE_H + 0.1),
		StudsOffsetWorldSpace = Vector3.new(0, OFFSET, 0),
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Parent = head,
	}) :: BillboardGui
	local nameRow = new("Frame", {
		Size = UDim2.fromScale(1, NAME_H / (NAME_H + PLATE_H + 0.1)),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = nameRow,
	})
	-- the level badge with its number
	local badgeHolder = new("Frame", {
		Size = UDim2.fromScale(1.15, 1.15),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = nameRow,
	})
	local badge = new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Parent = badgeHolder,
	}) :: ImageLabel
	local level = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Skin.Font.Display,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 2,
		Parent = badgeHolder,
	}) :: TextLabel
	new("UIPadding", {
		PaddingTop = UDim.new(0.24, 0),
		PaddingBottom = UDim.new(0.24, 0),
		PaddingLeft = UDim.new(0.2, 0),
		PaddingRight = UDim.new(0.2, 0),
		Parent = level,
	})
	new("UIStroke", { Color = Skin.Color.Ink, Thickness = 1.5, Parent = level })
	local name = new("TextLabel", {
		Size = UDim2.new(1, -1, 0.86, 0), -- the row minus the badge (UIFlexItem fills the rest)
		BackgroundTransparency = 1,
		FontFace = Skin.Font.Display,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		LayoutOrder = 2,
		Parent = nameRow,
	}) :: TextLabel
	new("UIStroke", { Color = Skin.Color.Ink, Thickness = 2.5, Parent = name })
	new("UITextSizeConstraint", { MaxTextSize = 30, Parent = name })
	new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink, Parent = name })
	-- the title plate
	local plate = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.8, PLATE_H / (NAME_H + PLATE_H + 0.1)),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0.35, 0), Parent = plate })
	new("UIGradient", { Color = ColorSequence.new(PLATE_FILL[1], PLATE_FILL[2]), Rotation = 90, Parent = plate })
	local rim = new("UIStroke", {
		Color = Skin.Color.Rarity.Common,
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = plate,
	}) :: UIStroke
	local plateText = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Skin.Font.Display,
		TextScaled = true,
		TextColor3 = Skin.Color.Ink,
		Text = "",
		Parent = plate,
	}) :: TextLabel
	new("UIPadding", {
		PaddingTop = UDim.new(0.14, 0),
		PaddingBottom = UDim.new(0.12, 0),
		PaddingLeft = UDim.new(0.08, 0),
		PaddingRight = UDim.new(0.08, 0),
		Parent = plateText,
	})
	return {
		gui = gui,
		name = name,
		badge = badge,
		level = level,
		plate = plate,
		plateText = plateText,
		plateRim = rim,
		lastTitle = nil,
	}
end

local function refresh(host: Instance, t: Tag)
	local display = if host:IsA("Player")
		then host.DisplayName
		else (host:GetAttribute("DisplayName") :: string?) or host.Name
	t.name.Text = display
	local lv = tonumber(host:GetAttribute("Level")) or 1
	t.level.Text = tostring(lv)
	local tier = badgeTier(lv)
	if tier == "Bronze" then
		t.badge.Image = Assets.Icon.LevelBadge
		t.badge.ImageColor3 = Color3.new(1, 1, 1)
	else
		t.badge.Image = Assets.Icon.Badge
		t.badge.ImageColor3 = ProgressController.BADGE_TINT[tier] or Color3.new(1, 1, 1)
	end
	local title = host:GetAttribute("Eq_Title")
	if title ~= t.lastTitle then
		t.lastTitle = if type(title) == "string" then title else nil
		local item = t.lastTitle and St.ById[t.lastTitle]
		t.plate.Visible = item ~= nil
		if item then
			t.plateText.Text = string.upper(item.name)
			t.plateRim.Color = Skin.Color.Rarity[item.rarity] or Skin.Color.Rarity.Common
		end
	end
end

local function step()
	local seen: { [Model]: boolean } = {}
	for _, host in ipairs(hosts()) do
		local char = characterOf(host)
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if char and head and host ~= player then
			seen[char] = true
			local t = tags[char]
			if not t or t.gui.Parent ~= head then
				if t then
					t.gui:Destroy()
				end
				t = build(head)
				tags[char] = t
			end
			refresh(host, t)
		end
	end
	for char, t in pairs(tags) do
		if not seen[char] then
			t.gui:Destroy()
			tags[char] = nil
		end
	end
end

function NametagController.start()
	task.spawn(function()
		while true do
			step()
			task.wait(0.4)
		end
	end)
end

return NametagController
