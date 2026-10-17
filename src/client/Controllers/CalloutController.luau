--!strict
-- Callouts on screen (GDD §11.1, Asset Bible §6.7): every moment the server spots pops in as a word with its tier's
-- treatment — Small floats up and fades, Medium sits on a slowly turning starburst plate, Big is a full-width banner
-- with light rays and a camera kick. At most three stack (newest on top, older ones step down).
-- Implements: F-CALL-01 (presentation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local FxController = require(script.Parent.FxController)

local CC = Config.Callouts
local P = Theme.Palette
local new = Theme.new
local player = Players.LocalPlayer

local CalloutController = {}

local SIZES = { Small = 30, Medium = 44, Big = 64 }
local HOLD = { Small = 0.8, Medium = 1.2, Big = 1.6 }
local SLOT = { Small = 48, Medium = 70, Big = 100 } -- vertical space each takes in the stack

type Entry = { frame: Frame, tier: string }
local stack: { Entry } = {}
local layer: Frame

local function relayout()
	local y = 0
	for _, e in ipairs(stack) do
		TweenService:Create(e.frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 0, y) })
			:Play()
		y += SLOT[e.tier]
	end
end

local function remove(entry: Entry)
	local i = table.find(stack, entry)
	if i then
		table.remove(stack, i)
		relayout()
	end
end

-- A starburst plate (Asset Bible §2.7: starbursts only on reward moments): 8 rotated rounded bars.
local function starburst(parent: Instance, color: Color3, size: number): Frame
	local holder = new("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	for i = 0, 7 do
		local bar = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, size * 0.26),
			Rotation = i * 22.5,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.55,
			ZIndex = 1,
			Parent = holder,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	end
	return holder
end

function CalloutController.show(key: string, n: number?)
	local def = CC.List[key]
	if not def then
		return
	end
	local tier = def.tier
	if key == "Chain" and (n or 0) >= CC.CHAIN_BIG then
		tier = "Big"
	end
	local color = (P :: any)[def.color] or P.Paper
	local text = if string.find(def.text, "%%d") then string.format(def.text, n or 0) else def.text
	local frame = new("Frame", {
		Name = "Callout_" .. key,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -30),
		Size = UDim2.new(1, 0, 0, SLOT[tier]),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	if tier == "Big" then
		local banner = Theme.panel(frame, {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 560, 0, SIZES.Big + 22),
			color = P.Ink2,
			transparency = 0.1,
		})
		Theme.recolor(banner, { border = color, border2 = color, glow = color, glowT = 0.45 })
		starburst(frame, color, 220)
		FxController.shake(0.18)
	elseif tier == "Medium" then
		local burst = starburst(frame, color, 120)
		TweenService:Create(burst, TweenInfo.new(HOLD.Medium + 0.4, Enum.EasingStyle.Linear), { Rotation = 45 }):Play()
	end
	local label = Theme.display(frame, {
		Text = text,
		TextSize = SIZES[tier],
		color = color,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 6,
	})
	local scale = new("UIScale", { Scale = 1.3, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local entry: Entry = { frame = frame, tier = tier }
	table.insert(stack, 1, entry)
	while #stack > CC.MAX_ON_SCREEN do
		local old = table.remove(stack) :: Entry
		old.frame:Destroy()
	end
	relayout()
	task.delay(HOLD[tier], function()
		if frame.Parent == nil then
			return
		end
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		local s = label:FindFirstChildOfClass("UIStroke")
		if s then
			TweenService:Create(s, fade, { Transparency = 1 }):Play()
		end
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("Frame") then
				TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
			end
		end
		TweenService:Create(scale, fade, { Scale = 0.9 }):Play()
		task.delay(0.36, function()
			remove(entry)
			frame:Destroy()
		end)
	end)
end

function CalloutController.start()
	local gui = new("ScreenGui", {
		Name = "FV_Callouts",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- The stack sits just under the centre third's top edge (out of the play area's middle, GDD §21.1).
	layer = new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(640, 320),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Net.listen("Callout", function(p)
		if type(p) == "table" and type(p.key) == "string" then
			CalloutController.show(p.key, if type(p.n) == "number" then p.n else nil)
		end
	end)
end

return CalloutController
