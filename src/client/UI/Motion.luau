--!strict
-- The one owner of a frame's scale (Asset Bible §6.5). Roblox applies only the FIRST UIScale under a GuiObject, so
-- a panel that got a "Fit" scale (Screen.fit) and then an "OpenScale" (the spring) silently lost one of them: most
-- panels snapped open with no motion at all. Here every reason to scale is a CHANNEL on that single UIScale and the
-- channels multiply: Base (fit to the screen) × Open (the spring in / out) × Hover (hover lift / press squish) ×
-- Pulse (a claimable thing breathing).
-- A UIScale also grows a frame out of its AnchorPoint, so a corner- or edge-anchored popup unfolded from the side.
-- open / close keep the frame's visual centre still while it scales, whatever its anchor.
-- button() is the house button feel: hover (or gamepad selection) springs up with a soft light and a shine sweep
-- (square icon buttons tilt a touch), press squishes, release bounces back. Reduce Motion keeps the press and drops
-- the rest.
-- Implements: F-UI-01 (motion rules), Asset Bible §6.3 (buttons) / §6.5 (motion).

local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Sfx)

local Motion = {}

local OPEN_TIME = 0.34
local CLOSE_TIME = 0.14

export type Channel = "Base" | "Open" | "Hover" | "Pulse"

function Motion.reduced(): boolean
	local ok, v = pcall(function()
		return (Settings :: any).get("reduceMotion")
	end)
	return ok and v == true
end

-- ── Channels ────────────────────────────────────────────────────────────────────────────────────────────────────
type State = {
	target: GuiObject,
	sc: UIScale,
	ch: { [string]: number },
	tweens: { [string]: Tween },
	pad: UIPadding?,
	padBase: { UDim }?,
	rest: UDim2?, -- Position at rest, while a self-drawn frame is shifted (see centre)
}
local states: { [Instance]: State } = setmetatable({}, { __mode = "k" }) :: any

local function state(target: GuiObject): State
	local st = states[target]
	if st and st.sc.Parent == target then
		return st
	end
	-- adopt the UIScale Roblox actually applies (the first one), or make one; whatever it was set to is the Base
	local sc = target:FindFirstChildOfClass("UIScale")
	local base = 1
	if sc then
		base = sc.Scale
	else
		sc = Instance.new("UIScale")
		sc.Name = "Motion"
		sc.Parent = target
	end
	local s = sc :: UIScale
	s:SetAttribute("Motion", true)
	st = { target = target, sc = s, ch = { Base = base }, tweens = {} }
	states[target] = st
	return st
end

-- Where Roblox pivots this frame's UIScale (measured in Studio): a free frame scales out of its AnchorPoint, a
-- UIListLayout child out of the list's alignment corner (Left/Top lists grow it down-right), a UIGridLayout child
-- from its centre. nil = already the centre.
local ALIGN_X = {
	[Enum.HorizontalAlignment.Left] = 0,
	[Enum.HorizontalAlignment.Center] = 0.5,
	[Enum.HorizontalAlignment.Right] = 1,
}
local ALIGN_Y = {
	[Enum.VerticalAlignment.Top] = 0,
	[Enum.VerticalAlignment.Center] = 0.5,
	[Enum.VerticalAlignment.Bottom] = 1,
}
local function pivotOf(target: GuiObject): Vector2?
	local parent = target.Parent
	local p = target.AnchorPoint
	if parent then
		if parent:FindFirstChildOfClass("UIGridLayout") then
			return nil
		end
		local list = parent:FindFirstChildOfClass("UIListLayout")
		if list then
			p = Vector2.new(ALIGN_X[list.HorizontalAlignment] or 0, ALIGN_Y[list.VerticalAlignment] or 0)
		end
	end
	return if p.X == 0.5 and p.Y == 0.5 then nil else p
end

-- Hover and Pulse must grow a button from its centre wherever Roblox pivots it. Its Position can't be the fix (a list
-- owns it, and other code moves buttons), so the contents are shifted instead with a UIPadding: everything drawn
-- inside the button (skin layers, label, icon, its own text) moves by exactly the opposite of the drift. At rest the
-- padding is back to what it was. Open keeps its own Position-based pivot (panels are free frames).
-- Does the frame draw anything itself (a background or its own image)? Padding can't move that.
local function selfDrawn(o: GuiObject): boolean
	if o.BackgroundTransparency < 0.99 then
		return true
	end
	if o:IsA("ImageButton") or o:IsA("ImageLabel") then
		local i = o :: any
		return i.Image ~= "" and i.ImageTransparency < 0.99
	end
	return false
end

local function laidOutIn(o: GuiObject): boolean
	local parent = o.Parent
	return parent ~= nil and parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local function centre(st: State)
	local h = (st.ch.Hover or 1) * (st.ch.Pulse or 1)
	local target = st.target
	-- a free frame that draws its own background: move the frame itself (nothing else positions it)
	if st.rest or (h ~= 1 and selfDrawn(target) and not laidOutIn(target)) then
		local p = pivotOf(target)
		local parent = target.Parent
		if not st.rest then
			if not p or not parent or not parent:IsA("GuiBase2d") then
				return
			end
			st.rest = target.Position
		end
		local rest = st.rest :: UDim2
		if h == 1 or not p or not parent or not parent:IsA("GuiBase2d") then
			target.Position = rest
			st.rest = nil
			return
		end
		local ps = (parent :: GuiBase2d).AbsoluteSize
		local full = target.AbsoluteSize / h
		if ps.X > 0 and ps.Y > 0 then
			target.Position = rest
				+ UDim2.fromScale(-(0.5 - p.X) * full.X * (h - 1) / ps.X, -(0.5 - p.Y) * full.Y * (h - 1) / ps.Y)
		end
		return
	end
	if h == 1 and not st.pad then
		return
	end
	local p = if h ~= 1 then pivotOf(target) else nil
	if not p and not st.pad then
		return
	end
	if not st.pad then
		local existing = target:FindFirstChildOfClass("UIPadding")
		if existing then
			st.pad = existing
			st.padBase = { existing.PaddingLeft, existing.PaddingRight, existing.PaddingTop, existing.PaddingBottom }
		else
			local pad = Instance.new("UIPadding")
			pad.Name = "MotionPad"
			pad.Parent = target
			st.pad = pad
			st.padBase = { UDim.new(), UDim.new(), UDim.new(), UDim.new() }
		end
	end
	local pad = st.pad :: UIPadding
	local base = st.padBase :: { UDim }
	-- the centre drifts by (0.5 − p)·W·(h − 1); content padded by u·W moves u·W·h, so u = −(0.5 − p)(h − 1)/h
	local ux = if p then -(0.5 - p.X) * (h - 1) / h else 0
	local uy = if p then -(0.5 - p.Y) * (h - 1) / h else 0
	pad.PaddingLeft = base[1] + UDim.new(ux, 0)
	pad.PaddingRight = base[2] - UDim.new(ux, 0)
	pad.PaddingTop = base[3] + UDim.new(uy, 0)
	pad.PaddingBottom = base[4] - UDim.new(uy, 0)
end

local function apply(st: State)
	local v = 1
	for _, x in pairs(st.ch) do
		v *= x
	end
	st.sc.Scale = v
	centre(st)
end

-- Set a channel now.
function Motion.set(target: GuiObject, channel: Channel, value: number)
	local st = state(target)
	local tw = st.tweens[channel]
	if tw then
		tw:Cancel()
		st.tweens[channel] = nil
	end
	st.ch[channel] = value
	apply(st)
end

-- The single UIScale that sizes `target` (made if it has none).
function Motion.scaleOf(target: GuiObject): UIScale
	return state(target).sc
end

function Motion.get(target: GuiObject, channel: Channel): number
	return state(target).ch[channel] or 1
end

-- Tween a channel to `value`; `step` (optional) runs every frame with the channel's value.
function Motion.tween(
	target: GuiObject,
	channel: Channel,
	value: number,
	info: TweenInfo,
	step: ((number) -> ())?
): Tween
	local st = state(target)
	local old = st.tweens[channel]
	if old then
		old:Cancel()
	end
	local nv = Instance.new("NumberValue")
	nv.Value = st.ch[channel] or 1
	nv.Changed:Connect(function(v)
		st.ch[channel] = v
		apply(st)
		if step then
			step(v)
		end
	end)
	local tw = TweenService:Create(nv, info, { Value = value })
	st.tweens[channel] = tw
	tw.Completed:Connect(function()
		if st.tweens[channel] == tw then
			st.tweens[channel] = nil
		end
		nv:Destroy()
	end)
	tw:Play()
	return tw
end

-- ── Open / close, pivoting on the visual centre ─────────────────────────────────────────────────────────────────
local function laidOut(target: GuiObject): boolean
	local p = target.Parent
	return p ~= nil and p:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

-- While the Open channel is `s`, shift the frame so its centre stays where it rests at s = 1.
local function pivot(target: GuiObject): ((number) -> ())?
	local a = target.AnchorPoint
	if (a.X == 0.5 and a.Y == 0.5) or laidOut(target) then
		return nil
	end
	local parent = target.Parent
	if not parent or not parent:IsA("GuiBase2d") then
		return nil
	end
	local rest = target:GetAttribute("MotionRest")
	if typeof(rest) ~= "UDim2" then
		rest = target.Position
		target:SetAttribute("MotionRest", rest)
	end
	local restPos = rest :: UDim2
	return function(s: number)
		local open = math.max(Motion.get(target, "Open"), 1e-3)
		local full = target.AbsoluteSize / open -- the frame's on-screen size at s = 1
		local ps = (parent :: GuiBase2d).AbsoluteSize
		if ps.X <= 0 or ps.Y <= 0 then
			return
		end
		local dx = (0.5 - a.X) * full.X * (1 - s) / ps.X
		local dy = (0.5 - a.Y) * full.Y * (1 - s) / ps.Y
		target.Position = restPos + UDim2.fromScale(dx, dy)
	end
end

local function settle(target: GuiObject)
	local rest = target:GetAttribute("MotionRest")
	if typeof(rest) == "UDim2" then
		target.Position = rest
		target:SetAttribute("MotionRest", nil)
	end
end

-- Spring a frame open from `from` (default 0.85) to full size, centred, with a soft overshoot.
function Motion.open(target: GuiObject, from: number?)
	if Motion.reduced() then
		Motion.set(target, "Open", 1)
		settle(target)
		return
	end
	local start = from or 0.85
	local step = pivot(target)
	Motion.set(target, "Open", start)
	if step then
		step(start)
	end
	local tw =
		Motion.tween(target, "Open", 1, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), step)
	tw.Completed:Connect(function(playback)
		if playback == Enum.PlaybackState.Completed then
			settle(target)
		end
	end)
end

-- Close: a quick shrink toward the centre, then `after`.
function Motion.close(target: GuiObject, after: (() -> ())?)
	local step = if Motion.reduced() then nil else pivot(target)
	if not Motion.reduced() then
		Motion.tween(
			target,
			"Open",
			0.9,
			TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			step
		)
	end
	task.delay(if Motion.reduced() then 0 else CLOSE_TIME, function()
		if after then
			after()
		end
	end)
end

-- ── The house button feel ───────────────────────────────────────────────────────────────────────────────────────
-- The skin a button is drawn with: its own SkinRoot (Skin.button) or the one on a drawn child such as a dock tile's
-- Face (Skin.frame). Returns the layer folder and the shape's corner radius.
local function skinOf(b: GuiObject): (Instance?, UDim)
	local root = b:FindFirstChild("SkinRoot")
	if not root then
		local best = 0
		for _, c in ipairs(b:GetChildren()) do
			if c:IsA("GuiObject") and c:FindFirstChild("SkinRoot") then
				local a = c.AbsoluteSize.X * c.AbsoluteSize.Y
				if a > best then
					best, root = a, c:FindFirstChild("SkinRoot")
				end
			end
		end
	end
	local radius = UDim.new(0, 8)
	if root then
		local shape = root:FindFirstChild("SkinFace") or root:FindFirstChild("SkinFill")
		local corner = shape and shape:FindFirstChildOfClass("UICorner")
		if corner then
			radius = corner.CornerRadius
		end
	end
	return root, radius
end

local function overlay(b: GuiObject): (Frame?, Frame?)
	-- a light layer and a shine band in the skin's own shape, above its gloss and under the label / icon
	local root, radius = skinOf(b)
	if not root then
		return nil, nil
	end
	local glow = Instance.new("Frame")
	glow.Name = "MotionGlow"
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Size = UDim2.fromScale(1, 1)
	glow.ZIndex = -5
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = glow
	glow.Parent = root
	local clip = Instance.new("Frame")
	clip.Name = "MotionShine"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = -5
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = radius
	c2.Parent = clip
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.new(0.35, 0, 1.6, 0)
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(-0.4, 0.5)
	band.Rotation = 18
	band.ZIndex = -5
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = band
	band.Parent = clip
	clip.Parent = root
	return glow, band
end

export type ButtonOpts = {
	hoverSound: boolean?, -- play UiHover on hover (default true)
	tilt: boolean?, -- tilt on hover (default: square-ish buttons only)
	visual: GuiObject?, -- what moves, when the button is an invisible hit box over it (default: the button)
}

-- Give a button the house feel. Safe to call twice (the second call does nothing).
function Motion.button(b: GuiButton, opts: ButtonOpts?)
	if b:GetAttribute("Alive") then
		return
	end
	b:SetAttribute("Alive", true)
	local o = opts or {}
	local v: GuiObject = o.visual or b
	local glow: Frame?, band: Frame? = nil, nil
	local made = false
	local hovered, down = false, false
	local lastShine = 0
	local baseRot = v.Rotation

	-- the bigger the button, the smaller the relative move (≈6 px of growth either way)
	local function amounts(): (number, number)
		local m = math.max(v.AbsoluteSize.X, v.AbsoluteSize.Y, 1) / math.max(Motion.get(v, "Hover"), 1e-3)
		return 1 + math.clamp(12 / m, 0.03, 0.08), 1 - math.clamp(14 / m, 0.04, 0.09)
	end
	local function square(): boolean
		if o.tilt ~= nil then
			return o.tilt
		end
		local s = v.AbsoluteSize
		return s.Y > 0 and s.X / s.Y < 1.35 and s.Y / math.max(s.X, 1) < 1.35
	end
	local function ensure()
		if not made then
			made = true
			glow, band = overlay(v)
		end
	end
	local function settleTo(hover: boolean)
		local up = amounts()
		local reduce = Motion.reduced()
		Motion.tween(
			v,
			"Hover",
			if hover and not reduce then up else 1,
			TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		)
		if square() and not reduce then
			TweenService:Create(v, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Rotation = baseRot + (if hover then -3 else 0),
			}):Play()
		end
		local g = glow
		if g then
			TweenService:Create(g, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
				BackgroundTransparency = if hover then 0.86 else 1,
			}):Play()
		end
	end
	local function shine()
		local bd = band
		if not bd or Motion.reduced() or os.clock() - lastShine < 0.7 then
			return
		end
		lastShine = os.clock()
		bd.Position = UDim2.fromScale(-0.4, 0.5)
		TweenService:Create(bd, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(1.4, 0.5),
		}):Play()
	end

	local function enter()
		ensure()
		hovered = true
		if not down then
			settleTo(true)
		end
		shine()
		if o.hoverSound ~= false and b.Active then
			Sfx.play("UiHover")
		end
	end
	local function leave()
		hovered, down = false, false
		settleTo(false)
	end
	b.MouseEnter:Connect(enter)
	b.MouseLeave:Connect(leave)
	-- a gamepad / keyboard moving onto the button reads exactly like the mouse
	b.SelectionGained:Connect(enter)
	b.SelectionLost:Connect(leave)
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			ensure()
			down = true
			local _, press = amounts()
			Motion.tween(v, "Hover", press, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			local g = glow
			if g then
				g.BackgroundTransparency = 0.8
			end
		end
	end)
	b.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and down then
			down = false
			-- touch has no hover: bounce back to rest
			settleTo(hovered and t ~= Enum.UserInputType.Touch)
		end
	end)
end

-- A press-and-bounce with no pointer (a keyboard shortcut or a gamepad button activating `b`).
function Motion.tap(b: GuiObject)
	local m = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y, 1)
	local tw = Motion.tween(
		b,
		"Hover",
		1 - math.clamp(14 / m, 0.04, 0.09),
		TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	)
	tw.Completed:Connect(function(playback)
		if playback == Enum.PlaybackState.Completed then
			Motion.tween(b, "Hover", 1, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		end
	end)
end

return Motion
