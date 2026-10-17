--!strict
-- Text that always fits its box (2026-10-07, the partner's phone). A phone set to a larger system text size
-- (GuiService.PreferredTextSize) makes Roblox draw ALL text bigger, fixed sizes and auto-fitted (TextScaled) alike,
-- so labels overflowed their boxes and ran into each other: tabs on top of each other, crate names piled up, the
-- settings sliders over their labels. And on any small phone a long label could still spill out of its box.
--
-- On our screens (ScreenGuis named CG_*), on touch devices or whenever the text is inflated:
--   • the inflation factor is measured directly (at the normal setting one line of text is exactly TextSize tall);
--   • every fixed-size label is drawn at its DESIGNED size (TextSize ÷ factor), auto-fitted labels get the same
--     cap (UITextSizeConstraint), so the screens look the same as they were designed on every phone;
--   • a label that still doesn't fit its box steps down until it does (never below MIN_SIZE). Labels that size
--     themselves to their text (AutomaticSize) only get the factor (they grow to fit by design).
-- Code that later sets a TextSize sets the new DESIGN size; the fit follows text and box changes.
-- Studio: the LocalPlayer attribute CG_TextFactor (a number) stands in for a device's inflation.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Screen = require(script.Parent.Screen)

local TextFit = {}

local MIN_SIZE = 8
local factor = 1
local active = false

type Track = { design: number, applied: number, aspect: number, conns: { RBXScriptConnection } }
local tracked: { [GuiObject]: Track } = setmetatable({}, { __mode = "k" }) :: any
local busy: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isText(o: Instance): boolean
	return o:IsA("TextLabel") or o:IsA("TextButton")
end

-- Ours: under a ScreenGui named CG_* (not the probe).
local function ours(o: Instance): boolean
	local sg = o:FindFirstAncestorWhichIsA("LayerCollector")
	return sg ~= nil and sg:IsA("ScreenGui") and string.sub(sg.Name, 1, 3) == "CG_"
end

local function measure()
	local lp = Players.LocalPlayer
	local sim = if RunService:IsStudio() and lp then lp:GetAttribute("CG_TextFactor") else nil
	if type(sim) == "number" then
		factor = math.clamp(sim, 1, 3)
		return
	end
	local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "TextFitProbe"
	g.ResetOnSpawn = false
	g.Enabled = true
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextTransparency = 1
	l.Size = UDim2.fromOffset(2000, 400)
	l.TextSize = 50
	l.FontFace = Font.fromEnum(Enum.Font.GothamBold) -- one line = exactly TextSize tall at the normal setting (the default font is 1.5×)
	l.Text = "Hg"
	l.Parent = g
	g.Parent = pg
	local h = l.TextBounds.Y
	g:Destroy()
	factor = if h > 0 then math.clamp(h / 50, 1, 3) else 1
end

-- The label's own size cap (auto-fitted text): one we made, or the designer's (its design values kept as attributes).
local function capOf(o: GuiObject): UITextSizeConstraint
	local c = o:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c:SetAttribute("CG_Max", 100)
		c:SetAttribute("CG_Min", 1)
		c.Parent = o
	elseif c:GetAttribute("CG_Max") == nil then
		c:SetAttribute("CG_Max", c.MaxTextSize)
		c:SetAttribute("CG_Min", c.MinTextSize)
	end
	return c :: UITextSizeConstraint
end

local function setSize(o: GuiObject, t: Track, size: number)
	t.applied = size
	if (o :: any).TextSize ~= size then
		busy[o] = true
		(o :: any).TextSize = size
		busy[o] = nil
	end
end

local function apply(o: GuiObject)
	local t = tracked[o]
	if not t or not o.Parent then
		return
	end
	local label = o :: any
	if label.TextScaled then
		if not active and not o:FindFirstChildOfClass("UITextSizeConstraint") then
			return -- (PC at the normal size: leave auto-fitted text exactly as designed)
		end
		local c = capOf(o)
		local max0, min0 = c:GetAttribute("CG_Max") :: number, c:GetAttribute("CG_Min") :: number
		local f = if active then factor else 1
		c.MinTextSize = math.max(1, math.floor(min0 / f))
		c.MaxTextSize = math.max(c.MinTextSize, math.floor(max0 / f))
		if active and o.AutomaticSize == Enum.AutomaticSize.None and o.AbsoluteSize.X > 2 then
			-- Still spilling out (a long word in a tiny box, a minimum size): cap it down until it fits.
			local guard = 0
			while not label.TextFits and c.MaxTextSize > MIN_SIZE and guard < 40 do
				guard += 1
				c.MinTextSize = math.min(c.MinTextSize, MIN_SIZE)
				c.MaxTextSize = math.max(MIN_SIZE, math.min(c.MaxTextSize, math.floor(label.TextBounds.Y)) - 1)
			end
		end
		return
	end
	local want = if active then math.max(1, math.floor(t.design / factor + 0.5)) else t.design
	setSize(o, t, want)
	if active and o.AutomaticSize == Enum.AutomaticSize.None and o.AbsoluteSize.X > 2 then
		local size = want
		local guard = 0
		while not label.TextFits and size > MIN_SIZE and guard < 60 do
			guard += 1
			size -= 1
			setSize(o, t, size)
		end
	end
end

local function track(o: Instance)
	if not isText(o) or tracked[o :: GuiObject] or not ours(o) then
		return
	end
	local g = o :: GuiObject
	local t: Track = { design = (g :: any).TextSize, applied = (g :: any).TextSize, aspect = 0, conns = {} }
	tracked[g] = t
	table.insert(
		t.conns,
		g:GetPropertyChangedSignal("TextSize"):Connect(function()
			if busy[g] then
				return
			end
			-- Someone else set it: that's the new design size.
			if (g :: any).TextSize ~= t.applied then
				t.design = (g :: any).TextSize
				apply(g)
			end
		end)
	)
	table.insert(
		t.conns,
		g:GetPropertyChangedSignal("Text"):Connect(function()
			if active then
				setSize(g, t, t.design) -- start again from the design size: the new text may fit better
				apply(g)
			end
		end)
	)
	table.insert(
		t.conns,
		g:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			-- A label that sizes itself to its text always fits; refitting it would resize it again, and again
			-- (an AbsoluteSize feedback loop).
			if not active or busy[g] or g.AutomaticSize ~= Enum.AutomaticSize.None then
				return
			end
			-- A panel popping in only scales its boxes (the fit can't change): refit only when the shape changes.
			local a = g.AbsoluteSize
			local aspect = if a.Y > 0 then a.X / a.Y else 0
			if t.aspect > 0 and math.abs(aspect - t.aspect) < 0.01 * t.aspect then
				return
			end
			t.aspect = aspect
			setSize(g, t, t.design)
			apply(g)
		end)
	)
	table.insert(
		t.conns,
		g.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				for _, c in ipairs(t.conns) do
					c:Disconnect()
				end
				tracked[g] = nil
			end
		end)
	)
	apply(g)
end

local function refreshAll()
	for o in pairs(tracked) do
		local t = tracked[o]
		if t then
			setSize(o, t, t.design)
		end
		apply(o)
	end
end

local function update()
	measure()
	local was = active
	active = factor > 1.03 or Screen.touch()
	if active ~= was or active then
		refreshAll()
	end
end

-- The factor text is drawn bigger by on this device (1 = normal).
function TextFit.factor(): number
	return factor
end

function TextFit.start()
	local lp = Players.LocalPlayer
	local pg = lp:WaitForChild("PlayerGui")
	measure()
	active = factor > 1.03 or Screen.touch()
	for _, d in ipairs(pg:GetDescendants()) do
		track(d)
	end
	pg.DescendantAdded:Connect(function(d)
		if isText(d) then
			-- Parented before its screen was named / its text set: settle first.
			task.defer(track, d)
		end
	end)
	pcall(function()
		(GuiService :: any):GetPropertyChangedSignal("PreferredTextSize"):Connect(update)
	end)
	Screen.Changed:Connect(function()
		task.defer(update)
	end)
	if RunService:IsStudio() then
		lp:GetAttributeChangedSignal("CG_TextFactor"):Connect(update)
	end
end

return TextFit
