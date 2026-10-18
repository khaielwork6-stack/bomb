--!strict
-- The left-side dock tile (the owner's reference video, 2026-10-17): a chunky rounded square in its own colour
-- gradient with a big 3D icon, the name in large round type overlapping its bottom edge, the keyboard shortcut in the
-- top-right corner and a red "!" badge when something waits. Taps squash; the shortcut works on keyboards.
-- Implements: F-UI-03 (lobby dock), Asset Bible §6.3 / §6.5.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent.Parent.Sfx)
local Skin = require(script.Parent.Skin)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local P = Theme.Palette
local new = Theme.new

local Dock = {}

Dock.SIZE = 84

-- Tile colours (top → bottom of the gradient). "rainbow" is the Shop tile's multi-stop sweep.
Dock.Colors = {
	rainbow = {
		Color3.fromRGB(255, 92, 120),
		Color3.fromRGB(255, 176, 60),
		Color3.fromRGB(255, 232, 90),
		Color3.fromRGB(110, 230, 120),
		Color3.fromRGB(80, 170, 255),
	},
	blue = { Color3.fromRGB(110, 196, 255), Color3.fromRGB(28, 112, 230) },
	green = { Color3.fromRGB(150, 236, 96), Color3.fromRGB(40, 160, 46) },
	orange = { Color3.fromRGB(255, 190, 90), Color3.fromRGB(240, 96, 28) },
	pink = { Color3.fromRGB(255, 150, 226), Color3.fromRGB(214, 56, 180) },
	purple = { Color3.fromRGB(190, 140, 255), Color3.fromRGB(110, 54, 220) },
	red = { Color3.fromRGB(255, 108, 92), Color3.fromRGB(196, 28, 28) },
	gold = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(236, 150, 20) },
}

export type TileOpts = {
	color: string?, -- a Dock.Colors key
	key: Enum.KeyCode?, -- keyboard shortcut (shown as its letter)
	label: string?, -- the name under the icon (defaults to `name`)
	order: number?,
}

export type Tile = {
	button: TextButton,
	badge: Frame,
	label: TextLabel,
	icon: ImageLabel,
	setBadge: (boolean) -> (),
}

local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local kps = {}
	for i, c in ipairs(colors) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(kps)
end

local function keyName(k: Enum.KeyCode): string
	local s = k.Name
	return if #s == 1 then s else (UserInputService:GetStringForKeyCode(k) or s)
end

function Dock.tile(parent: Instance, name: string, icon: string, onClick: () -> (), opts: TileOpts?): Tile
	local o: TileOpts = opts or {}
	local S = Dock.SIZE
	local b = new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(S, S + 10),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = o.order or 0,
		Parent = parent,
	})
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromOffset(S, S),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = b,
	})
	local colors = Dock.Colors[o.color or "blue"] or Dock.Colors.blue
	local layers = Skin.frame(face, {
		kind = "Chip",
		fill = colors[1],
		fill2 = colors[#colors],
		border = Color3.new(1, 1, 1),
		border2 = Color3.fromRGB(220, 226, 240),
		scale = 0.42,
		bevelT = 0.4,
	})
	local g = layers.fill:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = sequence(colors)
		g.Rotation = if o.color == "rainbow" then 45 else 90
	end
	local img = Widgets.icon(face, icon, math.floor(S * 0.86), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		ZIndex = 4,
	})
	local label = Widgets.label(b, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 16, 0, 30),
		Text = o.label or name,
		TextSize = 26,
		font = Theme.Font.Display,
		stroke = 3,
		ZIndex = 7,
	})
	if o.key then
		Widgets.label(b, {
			Name = "Key",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 8, 0, -8),
			Size = UDim2.fromOffset(24, 24),
			Text = keyName(o.key),
			TextSize = 22,
			font = Theme.Font.Display,
			stroke = 2.5,
			ZIndex = 8,
		})
	end
	local badge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = P.Detonate,
		Visible = false,
		ZIndex = 9,
		Parent = b,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2.5, Parent = badge })
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 120, 110), Color3.fromRGB(214, 24, 30)),
		Rotation = 90,
		Parent = badge,
	})
	Widgets.label(badge, {
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		TextSize = 24,
		font = Theme.Font.Display,
		stroke = 2,
		ZIndex = 10,
	})
	local sc = new("UIScale", { Parent = b })
	local function press()
		TweenService:Create(sc, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
	end
	local function release()
		TweenService:Create(sc, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	b.MouseEnter:Connect(function()
		if not Widgets.reduced() then
			TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.05 }):Play()
		end
		Sfx.play("UiHover")
	end)
	b.MouseLeave:Connect(release)
	b.MouseButton1Down:Connect(press)
	b.MouseButton1Up:Connect(function()
		release()
		Sfx.play("UiRelease")
	end)
	b.Activated:Connect(function()
		Sfx.play("UiPress")
		onClick()
	end)
	if o.key then
		local key = o.key
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed or input.KeyCode ~= key or UserInputService:GetFocusedTextBox() then
				return
			end
			if not b.Visible or not b:IsDescendantOf(game) then
				return
			end
			press()
			task.delay(0.08, release)
			Sfx.play("UiPress")
			onClick()
		end)
	end
	local stopPulse: (() -> ())? = nil
	local function setBadge(on: boolean)
		badge.Visible = on
		if on and not stopPulse then
			stopPulse = Widgets.pulse(badge)
		elseif not on and stopPulse then
			stopPulse()
			stopPulse = nil
		end
	end
	return { button = b, badge = badge, label = label, icon = img, setBadge = setBadge }
end

return Dock
