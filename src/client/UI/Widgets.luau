--!strict
-- Small shared UI pieces for the progression screens, on top of Theme / Skin (Asset Bible §6.1–§6.5): an icon with
-- the house offset shadow, an arcade button that sinks into its skirt, a count-up number, a breathing pulse for
-- claimable things, a spring-in scale, a progress bar, and the open / close motion every panel uses. Every piece
-- respects Reduce Motion (Settings), where springs become fades and nothing pulses.
-- Implements: F-UI-01 (motion rules), Asset Bible §6.3 / §6.5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Sfx)
local Skin = require(script.Parent.Skin)
local Theme = require(script.Parent.Theme)

local P = Theme.Palette
local new = Theme.new

local Widgets = {}

local function reduced(): boolean
	local ok, v = pcall(function()
		return (Settings :: any).get("reduceMotion")
	end)
	return ok and v == true
end
Widgets.reduced = reduced

-- An icon from the custom set with the house shadow (a solid Ink copy offset straight down, Asset Bible §6.1).
function Widgets.icon(parent: Instance, name: string, size: number, props: { [string]: any }?): ImageLabel
	local holder = new("Frame", {
		Name = "Icon_" .. name,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local id = (Assets.Icon :: any)[name] or ""
	new("ImageLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, math.max(2, size * 0.06)),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = id,
		ImageColor3 = P.Ink,
		ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 1,
		Parent = holder,
	})
	local img = new("ImageLabel", {
		Name = "Image",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = id,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = holder,
	})
	if props then
		for k, v in pairs(props) do
			if k == "tint" then
				img.ImageColor3 = v
			else
				(holder :: any)[k] = v
			end
		end
	end
	return img
end

-- A label in the house type: Builder Sans Heavy numbers / Luckiest Guy display, Ink stroke.
function Widgets.label(parent: Instance, props: { [string]: any }): TextLabel
	local l = new("TextLabel", {
		Name = props.Name or "Label",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(100, 24),
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		FontFace = props.font or Theme.Font.Heavy,
		TextSize = props.TextSize or 18,
		TextColor3 = props.color or P.Paper,
		TextXAlignment = props.align or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = props.wrap == true,
		Text = props.Text or "",
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 3,
		Parent = parent,
	})
	if props.stroke ~= false then
		new("UIStroke", {
			Color = P.Ink,
			Thickness = props.stroke or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = l,
		})
	end
	return l
end

-- An arcade button (Asset Bible §6.3): the partner's glossy face, sinking into its skirt on press, with the click.
-- `onClick` runs on release. Returns the button and a setter for its enabled state.
function Widgets.button(
	parent: Instance,
	text: string,
	preset: string?,
	size: UDim2,
	onClick: () -> (),
	props: { [string]: any }?
): (TextButton, (boolean) -> ())
	local b = new("TextButton", {
		Name = "Button",
		AnchorPoint = (props and props.AnchorPoint) or Vector2.zero,
		Position = (props and props.Position) or UDim2.new(),
		Size = size,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = (props and props.LayoutOrder) or 0,
		ZIndex = (props and props.ZIndex) or 3,
		Parent = parent,
	})
	Skin.button(b, preset or "fuse")
	local scale = new("UIScale", { Parent = b })
	local label = Widgets.label(b, {
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextSize = (props and props.TextSize) or 20,
		font = Theme.Font.Display,
		ZIndex = 8,
	})
	local enabled = true
	b.MouseButton1Down:Connect(function()
		if not enabled then
			return
		end
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	b.Activated:Connect(function()
		if not enabled then
			Sfx.play("UiDeny")
			if not reduced() then
				local x = b.Position
				for i, dx in ipairs({ 6, -6, 4, -2, 0 }) do
					task.delay(i * 0.035, function()
						b.Position = x + UDim2.fromOffset(dx, 0)
					end)
				end
			end
			return
		end
		Sfx.play("UiPress")
		onClick()
	end)
	local function setEnabled(on: boolean)
		enabled = on
		Skin.button(b, if on then preset or "fuse" else "grey")
		label.TextColor3 = if on then P.Paper else P.Ash
		label.Parent = b -- keep the label above the re-skinned face
	end
	return b, setEnabled
end

-- Count a label's number up (Asset Bible §6.5: 0.4 s ease-out, a 1.08 bump at the end, a tick every few steps).
function Widgets.countUp(label: TextLabel, from: number, to: number, format: ((number) -> string)?, ticks: boolean?)
	local fmt = format or function(n: number): string
		return tostring(n)
	end
	if from == to or reduced() then
		label.Text = fmt(to)
		return
	end
	local token = (label:GetAttribute("CountToken") or 0) + 1
	label:SetAttribute("CountToken", token)
	task.spawn(function()
		local t0 = os.clock()
		local dur = 0.4
		local lastTick = 0
		while os.clock() - t0 < dur do
			if label:GetAttribute("CountToken") ~= token then
				return
			end
			local a = (os.clock() - t0) / dur
			local e = 1 - (1 - a) ^ 3
			label.Text = fmt(math.floor(from + (to - from) * e + 0.5))
			if ticks and os.clock() - lastTick > 0.07 then
				lastTick = os.clock()
				Sfx.play("CoinTick")
			end
			task.wait()
		end
		label.Text = fmt(to)
		local s = label:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = label })
		s.Scale = 1.08
		TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
end

-- A gentle breathing pulse on a claimable thing (Asset Bible §6.5). Returns a stop function.
function Widgets.pulse(target: GuiObject): () -> ()
	local s = target:FindFirstChild("PulseScale") :: UIScale?
	if not s then
		s = new("UIScale", { Name = "PulseScale", Parent = target })
	end
	local scale = s :: UIScale
	if reduced() then
		return function() end
	end
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.04 }
	)
	tween:Play()
	return function()
		tween:Cancel()
		scale.Scale = 1
	end
end

-- Spring a frame in (scale 0.85 → 1, Asset Bible §6.5) or fade it in under Reduce Motion.
function Widgets.springIn(target: GuiObject, from: number?)
	local s = target:FindFirstChild("OpenScale") :: UIScale?
	if not s then
		s = new("UIScale", { Name = "OpenScale", Parent = target })
	end
	local scale = s :: UIScale
	if reduced() then
		scale.Scale = 1
		return
	end
	scale.Scale = from or 0.85
	TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- Close motion: scale to 0.92 and fade, then run `after`.
function Widgets.springOut(target: GuiObject, after: (() -> ())?)
	local s = target:FindFirstChild("OpenScale") :: UIScale?
	if not s then
		s = new("UIScale", { Name = "OpenScale", Parent = target })
	end
	TweenService
		:Create(s :: UIScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.92 })
		:Play()
	task.delay(0.12, function()
		if after then
			after()
		end
	end)
end

-- A chunky progress bar in a dark well. Returns the fill frame and a setter (0..1, animated).
function Widgets.bar(
	parent: Instance,
	size: UDim2,
	color: Color3,
	props: { [string]: any }?
): (Frame, (number, boolean?) -> ())
	local well = new("Frame", {
		Name = "Bar",
		AnchorPoint = (props and props.AnchorPoint) or Vector2.zero,
		Position = (props and props.Position) or UDim2.new(),
		Size = size,
		BackgroundColor3 = P.Ink,
		LayoutOrder = (props and props.LayoutOrder) or 0,
		ZIndex = (props and props.ZIndex) or 3,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = well })
	new("UIStroke", { Color = P.Ink, Thickness = 2, Parent = well })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		ZIndex = well.ZIndex + 1,
		Parent = well,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	new("UIGradient", {
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color),
		Rotation = 90,
		Parent = fill,
	})
	local function set(frac: number, instant: boolean?)
		local goal = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		if instant or reduced() then
			fill.Size = goal
		else
			TweenService
				:Create(fill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = goal })
				:Play()
		end
	end
	return fill, set
end

-- "3:07" / "1:02:15" for a seconds count.
function Widgets.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m, sec = s // 3600, (s % 3600) // 60, s % 60
	if h > 0 then
		return ("%d:%02d:%02d"):format(h, m, sec)
	end
	return ("%d:%02d"):format(m, sec)
end

-- A full-screen dark backdrop for modal screens (tap-through blocked). Returns it.
function Widgets.backdrop(gui: Instance, transparency: number?): Frame
	local f = new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.Ink,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = gui,
	})
	TweenService:Create(f, TweenInfo.new(0.15), { BackgroundTransparency = transparency or 0.35 }):Play()
	return f
end

-- A slowly turning light-ray fan (the crate reveal, the level-up): 12 rays fading out from the centre.
function Widgets.rays(parent: Instance, color: Color3, strong: boolean, position: UDim2?): Frame
	local holder = new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 900),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = parent,
	})
	for i = 1, 12 do
		-- GUI rotation pivots on an element's centre, so each ray is the top half of a full-height arm centred on
		-- the fan's middle
		local arm = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(80, 900),
			Rotation = i * 30,
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = holder,
		})
		local r = new("Frame", {
			Size = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = if strong then 0.6 else 0.78,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = arm,
		})
		new("UIGradient", {
			Transparency = NumberSequence.new({
				-- bright at the hub, gone well before the screen edge: a glow round the prize, never a wash over the screen
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 0.8),
				NumberSequenceKeypoint.new(1, 0.15),
			}),
			Rotation = 90,
			Parent = r,
		})
	end
	task.spawn(function()
		while holder.Parent do
			holder.Rotation += 0.15
			RunService.RenderStepped:Wait()
		end
	end)
	return holder
end

-- A circular progress ring (a track and a fill that sweeps clockwise from 12 o'clock), filling `parent`. Returns a
-- setter for the fill (0..1). Built from two clipped half-rings whose stroke gradients turn (no images needed).
function Widgets.progressRing(parent: Instance, color: Color3, thickness: number, z: number?): (number) -> ()
	local holder = new("Frame", {
		Name = "Ring",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z or 3,
		Parent = parent,
	})
	local track = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z or 3,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	new("UIStroke", { Color = P.Ink, Transparency = 0.55, Thickness = thickness, Parent = track })
	local function half(right: boolean): UIGradient
		local clip = new("Frame", {
			Position = UDim2.fromScale(if right then 0.5 else 0, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = (z or 3) + 1,
			Parent = holder,
		})
		local ring = new("Frame", {
			Position = UDim2.fromScale(if right then -1 else 0, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundTransparency = 1,
			ZIndex = (z or 3) + 1,
			Parent = clip,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
		local stroke = new("UIStroke", { Color = color, Thickness = thickness, Parent = ring })
		return new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.499, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = stroke,
		})
	end
	local r, l = half(true), half(false)
	return function(f: number)
		f = math.clamp(f, 0, 1)
		r.Rotation = math.min(f, 0.5) * 360
		l.Rotation = 180 + math.max(f - 0.5, 0) * 360
	end
end

-- 1200 → "1,200".
function Widgets.commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

return Widgets
