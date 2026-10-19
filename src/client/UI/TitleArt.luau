--!strict
-- Title word art, live (Asset Bible §6.2 display type, §6.5 motion): the baked 3D word (Assets.Title, art/titles)
-- with what can't be baked because it moves — a soft glow in the word's colour family that flashes on the slam and
-- breathes while it holds, a shine that sweeps across the LETTERS only (the baked face mask), sparkles twinkling round
-- the edges, lens streaks shooting out on a big moment, an optional icon above (a crown) and a nameplate below (a
-- player's name: a dark pill, gold rim, crisp white type).
-- Motion: it slams in from big and tilted, lands a touch under size, settles with a soft overshoot, floats very
-- slightly while it holds, then lifts and fades. Reduce Motion: it simply fades in and out.
-- Tiers (Config.Titles): Moment (rare, big, streaks + sparkles) and Callout (smaller, quicker, calmer).
-- Implements: F-UI-01, Asset Bible §6.2 / §6.5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Motion = require(script.Parent.Motion)
local Screen = require(script.Parent.Screen)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local T = Config.Titles
local P = Theme.Palette
local new = Theme.new

local TitleArt = {}

export type Tier = "Moment" | "Callout"
export type Opts = {
	tier: Tier?,
	sub: string?, -- nameplate text under the word
	icon: string?, -- an Assets.Icon key shown above (e.g. "Crown")
	y: number?, -- the word's centre, as a fraction of the screen height (default 0.3)
	hold: number?, -- seconds on screen before it leaves (default: the tier's); 0 = stays until dismissed
	zIndex: number?,
}
export type Handle = {
	key: string,
	frame: Frame,
	dismiss: () -> (), -- leave now
	extend: (seconds: number) -> (), -- stay this long from now (0 = until dismissed)
	setSub: (text: string) -> (), -- set / change the nameplate (e.g. "×3" when a callout repeats)
	punch: () -> (), -- a quick pop (the same callout again)
}

function TitleArt.has(key: string): boolean
	return (Assets.Title :: any)[key] ~= nil
end

local function tween(
	o: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tw =
		TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Show title `key` (an Assets.Title key) on `gui`. Returns a handle; the title removes itself after its hold.
function TitleArt.show(gui: Instance, key: string, opts: Opts?): Handle?
	local art = (Assets.Title :: any)[key]
	if not art then
		warn("[TitleArt] no title art for", key)
		return nil
	end
	local o: Opts = opts or {}
	local tier = (T.Tiers :: any)[o.tier or "Callout"]
	local fam = T.Families[art.family] or T.Families.Gold
	local reduce = Motion.reduced()
	local z = o.zIndex or 20
	local v = Screen.size()
	-- size: the tier's height, never wider than the tier allows
	local h = v.Y * tier.height
	local w = h * art.size.X / art.size.Y
	local maxW = v.X * tier.maxWidth
	if w > maxW then
		w = maxW
		h = w * art.size.Y / art.size.X
	end

	local holder = new("Frame", {
		Name = "Title_" .. key,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, o.y or 0.3, 0),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = gui,
	}) :: Frame
	local scale = new("UIScale", { Parent = holder }) :: UIScale
	local alive = true
	local fades: { { inst: Instance, prop: string, rest: number } } = {}
	local function fadeable(inst: Instance, prop: string, rest: number)
		table.insert(fades, { inst = inst, prop = prop, rest = rest });
		(inst :: any)[prop] = 1
	end

	-- the backing and the glow: the word's own silhouette blurred wide (art/titles), so the halo hugs the letters —
	-- dark underneath (the title reads on a bright or busy frame), the family colour on top
	local gs: Vector2 = art.glowScale
	local backing = new("ImageLabel", {
		Name = "Backing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(gs.X * 1.04, gs.Y * 1.1),
		BackgroundTransparency = 1,
		Image = art.glow,
		ImageColor3 = P.Ink,
		ZIndex = z,
		Parent = holder,
	}) :: ImageLabel
	fadeable(backing, "ImageTransparency", T.BACKING)
	local glow = new("ImageLabel", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(gs.X, gs.Y),
		BackgroundTransparency = 1,
		Image = art.glow,
		ImageColor3 = fam.glow,
		ZIndex = z,
		Parent = holder,
	}) :: ImageLabel
	glow.ImageTransparency = 1

	-- streaks (moments): two lens lines through the word's middle, shooting outward
	local streaks: { ImageLabel } = {}
	if tier.streaks and not reduce then
		for i, spec in ipairs({ { 2.3, 0.2, 0.15 }, { 1.7, 0.36, 0.45 } }) do
			local s = new("ImageLabel", {
				Name = "Streak" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.2, spec[2]),
				BackgroundTransparency = 1,
				Image = Assets.TitleFx.Streak,
				ImageColor3 = fam.spark,
				ImageTransparency = 1,
				ZIndex = z + 1,
				Parent = holder,
			}) :: ImageLabel
			s:SetAttribute("Width", spec[1])
			s:SetAttribute("Rest", spec[3])
			table.insert(streaks, s)
		end
	end

	-- the word itself
	local word = new("ImageLabel", {
		Name = "Word",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = art.id,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z + 2,
		Parent = holder,
	}) :: ImageLabel
	fadeable(word, "ImageTransparency", 0)

	-- the shine: a bright band sweeping across the letters' faces only (the baked mask)
	local shine = new("ImageLabel", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = art.mask,
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z + 3,
		Parent = holder,
	}) :: ImageLabel
	local band = new("UIGradient", {
		Rotation = 18,
		Offset = Vector2.new(-1.2, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	}) :: UIGradient

	-- an icon above (a crown on the big moments): sitting on the word, tilted a touch, bobbing gently
	if o.icon then
		local isz = math.floor(h * 0.95)
		local ic = Widgets.icon(holder, o.icon, isz, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, h * 0.3),
			Rotation = -6,
			ZIndex = z + 4,
		})
		fadeable(ic, "ImageTransparency", 0)
		local iconHolder = ic.Parent :: GuiObject
		local shadow = iconHolder:FindFirstChild("Shadow")
		if shadow then
			fadeable(shadow, "ImageTransparency", 0.55)
		end
		if not reduce then
			task.spawn(function()
				local base = iconHolder.Position
				local t0 = os.clock()
				while alive and iconHolder.Parent do
					local t = os.clock() - t0
					iconHolder.Position = base + UDim2.fromOffset(0, math.sin(t * 3) * h * 0.035)
					iconHolder.Rotation = -6 + math.sin(t * 1.7) * 3
					RunService.RenderStepped:Wait()
				end
			end)
		end
	end

	-- the nameplate below: dark pill, gold rim, white type
	local plate: Frame? = nil
	local plateLabel: TextLabel? = nil
	local function makePlate(text: string, entering: boolean)
		local ph = math.max(26, h * 0.3)
		local p = new("Frame", {
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -h * 0.04),
			Size = UDim2.fromOffset(0, ph),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = P.Ink2,
			ZIndex = z + 4,
			Parent = holder,
		}) :: Frame
		new("UICorner", { CornerRadius = UDim.new(0, math.floor(ph * 0.32)), Parent = p })
		local rim = new("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = math.max(2, ph * 0.09),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = p,
		}) :: UIStroke
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(214, 140, 30)),
			Rotation = 90,
			Parent = rim,
		})
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(58, 50, 78), Color3.fromRGB(26, 22, 38)),
			Rotation = 90,
			Parent = p,
		})
		new("UIPadding", {
			PaddingLeft = UDim.new(0, ph * 0.75),
			PaddingRight = UDim.new(0, ph * 0.75),
			Parent = p,
		})
		local label = new("TextLabel", {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Display,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = math.floor(ph * 0.66),
			ZIndex = z + 5,
			Parent = p,
		}) :: TextLabel
		new("UIStroke", { Color = P.Ink, Thickness = math.max(1.5, ph * 0.06), Parent = label })
		if entering then
			fadeable(p, "BackgroundTransparency", 0)
			fadeable(rim, "Transparency", 0)
			fadeable(label, "TextTransparency", 0)
		else
			table.insert(fades, { inst = p, prop = "BackgroundTransparency", rest = 0 })
			table.insert(fades, { inst = rim, prop = "Transparency", rest = 0 })
			table.insert(fades, { inst = label, prop = "TextTransparency", rest = 0 })
			Widgets.springIn(p, 0.6)
		end
		plate, plateLabel = p, label
	end
	if o.sub and o.sub ~= "" then
		makePlate(o.sub, true)
	end

	-- sparkles: twinkling round the word's edges (none under Reduce Motion)
	if not reduce then
		local rng = Random.new()
		for i = 1, tier.sparkles do
			local side = if i % 2 == 0 then 1 else -1
			local px = 0.5 + side * rng:NextNumber(0.3, 0.56)
			local py = rng:NextNumber(-0.05, 1.05)
			local size = h * rng:NextNumber(0.16, 0.3)
			local sp = new("ImageLabel", {
				Name = "Sparkle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(px, py),
				Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 1,
				Image = Assets.TitleFx.Sparkle,
				ImageColor3 = fam.spark,
				ZIndex = z + (if rng:NextNumber() < 0.5 then 1 else 4),
				Parent = holder,
			}) :: ImageLabel
			local ss = new("UIScale", { Scale = 0, Parent = sp }) :: UIScale
			task.spawn(function()
				task.wait(0.08 + i * 0.07)
				while alive and sp.Parent do
					sp.Rotation = rng:NextNumber(-20, 20)
					tween(ss, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
					tween(sp, 0.5, { Rotation = sp.Rotation + 45 }, Enum.EasingStyle.Sine)
					task.wait(rng:NextNumber(0.25, 0.45))
					tween(ss, 0.3, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.wait(rng:NextNumber(0.5, 1.2))
				end
			end)
		end
	end

	-- ── the entrance ────────────────────────────────────────────────────────────────────────────────────────────
	for _, f in ipairs(fades) do
		tween(f.inst, if reduce then 0.2 else T.IN_TIME, { [f.prop] = f.rest })
	end
	if reduce then
		tween(glow, 0.3, { ImageTransparency = T.GLOW_REST })
	else
		scale.Scale = tier.slam
		holder.Rotation = -T.SLAM_TILT
		local land = tween(scale, T.IN_TIME, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(holder, T.IN_TIME, { Rotation = 1.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		land.Completed:Connect(function()
			tween(scale, T.SETTLE_TIME, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(holder, T.SETTLE_TIME, { Rotation = 0 }, Enum.EasingStyle.Back)
			-- the impact: the glow flashes and settles, the streaks shoot out
			glow.ImageTransparency = 0.05
			tween(glow, 0.5, { ImageTransparency = T.GLOW_REST })
			for _, s in ipairs(streaks) do
				s.ImageTransparency = 0
				tween(
					s,
					0.45,
					{ Size = UDim2.fromScale(s:GetAttribute("Width") :: number, s.Size.Y.Scale) },
					Enum.EasingStyle.Quint
				)
				tween(s, 0.9, { ImageTransparency = s:GetAttribute("Rest") :: number })
			end
		end)
		task.delay(T.SHINE_DELAY, function()
			if shine.Parent then
				band.Offset = Vector2.new(-1.2, 0)
				tween(
					band,
					T.SHINE_TIME,
					{ Offset = Vector2.new(1.2, 0) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.InOut
				)
			end
		end)
		-- the idle breath: a slow float and a glow pulse while it holds
		local t0 = os.clock()
		local base = holder.Position
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			if not alive or not holder.Parent then
				conn:Disconnect()
				return
			end
			local t = os.clock() - t0
			if t > T.IN_TIME + T.SETTLE_TIME then
				holder.Position = base + UDim2.fromOffset(0, math.sin(t * 2.2) * T.FLOAT_PX)
			end
		end)
	end

	-- ── the exit ────────────────────────────────────────────────────────────────────────────────────────────────
	local gone = false
	local function dismiss()
		if gone then
			return
		end
		gone = true
		local t = if reduce then 0.2 else T.OUT_TIME
		for _, f in ipairs(fades) do
			tween(f.inst, t, { [f.prop] = 1 })
		end
		tween(glow, t, { ImageTransparency = 1 })
		tween(backing, t, { ImageTransparency = 1 })
		for _, s in ipairs(streaks) do
			tween(s, t, { ImageTransparency = 1 })
		end
		shine.Visible = false
		if not reduce then
			tween(scale, t, { Scale = 1.08 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(holder, t, { Position = holder.Position - UDim2.fromOffset(0, h * 0.12) })
		end
		task.delay(t, function()
			alive = false
			holder:Destroy()
		end)
	end
	-- the hold timer (restartable: a repeat of the same callout keeps it up)
	local token = 0
	local function extend(seconds: number)
		token += 1
		local mine = token
		if seconds > 0 then
			task.delay(seconds, function()
				if mine == token then
					dismiss()
				end
			end)
		end
	end
	local hold = if o.hold ~= nil then o.hold else tier.hold
	extend(if hold > 0 then T.IN_TIME + T.SETTLE_TIME + hold else 0)

	local function setSub(text: string)
		if gone then
			return
		end
		local l = plateLabel
		if l then
			l.Text = text
		else
			makePlate(text, false)
		end
	end
	local function punch()
		if gone or reduce then
			return
		end
		local up = tween(scale, 0.07, { Scale = 1.12 }, Enum.EasingStyle.Quad)
		up.Completed:Connect(function()
			tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		band.Offset = Vector2.new(-1.2, 0)
		tween(band, T.SHINE_TIME, { Offset = Vector2.new(1.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end
	local _ = plate
	return { key = key, frame = holder, dismiss = dismiss, extend = extend, setSub = setSub, punch = punch }
end

return TitleArt
