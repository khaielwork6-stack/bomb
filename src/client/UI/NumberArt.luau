--!strict
-- Numbers in the title-art style (Asset Bible §6.2): any string of 0-9, "x" and "/" built from the baked glyphs
-- (Assets.Glyph, art/titles: one strip, so every glyph shares a scale and a baseline). Neutral white art, tinted by
-- ImageColor3 (the dark outline stays dark). Used wherever a number is a moment: the chain ×N, the crossing count,
-- the team counters. `set` swaps the glyphs and gives a small pop when the value changes.
-- Implements: Asset Bible §6.2 / §6.5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Motion = require(script.Parent.Motion)

local NumberArt = {}

local GLYPH_KEY = { x = "X", ["×"] = "X", ["/"] = "Slash" }
local OVERLAP = 0.14 -- of the height: neighbouring glyphs tuck their outlines together, like set type

export type Props = {
	height: number, -- px
	color: Color3?,
	align: Enum.HorizontalAlignment?,
	zIndex: number?,
	anchor: Vector2?,
	position: UDim2?,
	name: string?,
}

export type Number = {
	frame: Frame,
	set: (self: Number, text: string, pop: boolean?) -> (),
	tint: (self: Number, color: Color3) -> (),
	text: string,
}

local function glyphOf(ch: string): { id: string, size: Vector2 }?
	local g = (Assets :: any).Glyph
	return g and g[GLYPH_KEY[ch] or ch] or nil
end

function NumberArt.has(): boolean
	return (Assets :: any).Glyph ~= nil and glyphOf("0") ~= nil
end

function NumberArt.new(parent: Instance, p: Props): Number
	local frame = Instance.new("Frame")
	frame.Name = p.name or "Number"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = p.anchor or Vector2.new(0.5, 0.5)
	frame.Position = p.position or UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(0, p.height)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.ZIndex = p.zIndex or 5
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = p.align or Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, -math.floor(p.height * OVERLAP))
	list.Parent = frame
	frame.Parent = parent

	local self = { frame = frame, text = "" } :: any
	local color = p.color or Color3.new(1, 1, 1)
	local images: { ImageLabel } = {}

	function self.set(this: Number, text: string, pop: boolean?)
		if text == this.text then
			return
		end
		this.text = text
		local n = 0
		for i = 1, #text do
			local g = glyphOf(string.sub(text, i, i))
			if g then
				n += 1
				local img = images[n]
				if not img then
					img = Instance.new("ImageLabel")
					img.BackgroundTransparency = 1
					img.ScaleType = Enum.ScaleType.Fit
					img.ZIndex = frame.ZIndex
					img.Parent = frame
					images[n] = img
				end
				img.Image = g.id
				img.ImageColor3 = color
				img.LayoutOrder = n
				img.Size = UDim2.fromOffset(math.floor(p.height * g.size.X / g.size.Y + 0.5), p.height)
				img.Visible = true
			end
		end
		for i = n + 1, #images do
			images[i].Visible = false
		end
		if pop and not Motion.reduced() then
			Motion.set(frame, "Pulse", 1.28)
			Motion.tween(frame, "Pulse", 1, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		end
	end

	function self.tint(_this: Number, c: Color3)
		color = c
		for _, img in ipairs(images) do
			TweenService:Create(img, TweenInfo.new(0.2), { ImageColor3 = c }):Play()
		end
	end

	return self :: Number
end

return NumberArt
