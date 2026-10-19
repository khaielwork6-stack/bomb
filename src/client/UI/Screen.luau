--!strict
-- The screen the HUD lays out for: the viewport size and Roblox's top bar, in one place, with one change signal.
-- Studio only: Dev/MobileSim can stand in a device (LocalPlayer attributes CG_SimViewport = Vector2 size and
-- CG_SimTopbar = top bar height), so phone / tablet layouts are checked at their real sizes on a desktop.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Motion)

local Screen = {}

local changed = Instance.new("BindableEvent")
Screen.Changed = changed.Event

local studio = RunService:IsStudio()

local function sim(): Vector2?
	if not studio then
		return nil
	end
	local lp = Players.LocalPlayer
	local v = lp and lp:GetAttribute("CG_SimViewport")
	return if typeof(v) == "Vector2" and v.X > 0 and v.Y > 0 then v else nil
end

-- Probes measured in GUI space (2026-10-07): on some phones (display scaling) the camera's ViewportSize is NOT in
-- the units GUIs are laid out in, so a safe-area margin worked out against it came out hundreds of pixels wide and
-- shoved everything that hugs the right edge (counters, feed, the touch buttons) towards the middle. The screen
-- and its safe area are now both measured as GUIs: a full-screen probe and a device-safe-area probe.
local probes: { [string]: ScreenGui } = {}
local function probeGui(name: string, insets: Enum.ScreenInsets): ScreenGui?
	local g = probes[name]
	if g and g.Parent then
		return g
	end
	local lp = Players.LocalPlayer
	local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local n = Instance.new("ScreenGui")
	n.Name = name
	n.ResetOnSpawn = false
	n.ScreenInsets = insets
	pcall(function()
		(n :: any).SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	end)
	n.Parent = pg
	probes[name] = n
	return n
end

-- Screen size in GUI pixels (points on phones).
function Screen.size(): Vector2
	local s = sim()
	if s then
		return s
	end
	local full = probeGui("CG_FullProbe", Enum.ScreenInsets.None)
	if full and full.AbsoluteSize.X > 0 and full.AbsoluteSize.Y > 0 then
		return full.AbsoluteSize
	end
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1920, 1080)
end

function Screen.simulated(): boolean
	return sim() ~= nil
end

-- Roblox's top bar: the strip developer UI may share (Min.X = right of the core buttons on the left, Max.X = left of
-- any on the right), in screen pixels.
function Screen.topbar(): Rect
	local v = Screen.size()
	if sim() then
		local h = Players.LocalPlayer:GetAttribute("CG_SimTopbar")
		local height = if type(h) == "number" then h else 58
		-- The core buttons on the left (Roblox menu + chat) take about two bar-heights.
		return Rect.new(height * 2 + 16, 0, v.X - 12, height)
	end
	local ok, inset = pcall(function()
		return (GuiService :: any).TopbarInset
	end)
	if ok and typeof(inset) == "Rect" and inset.Height > 0 then
		return inset
	end
	return Rect.new(130, 0, v.X - 12, 58)
end

-- Short screens (landscape phones): the HUD packs tighter there.
function Screen.compact(): boolean
	return Screen.size().Y < 560
end

local function fire()
	changed:Fire(Screen.size())
end

-- Touch layout on? (Components owns device detection and reports it here, so the scalers can read it without a
-- require cycle.)
local touch = false
function Screen.touch(): boolean
	return touch
end
function Screen.setTouch(on: boolean)
	if on ~= touch then
		touch = on
		fire()
	end
end

-- The device's safe area (notch / rounded corners / home bar), as insets from each edge in GUI pixels. HUD that
-- hugs an edge adds these. Studio simulation: LocalPlayer attribute CG_SimSafe = Vector3(left, right, bottom).
function Screen.safe(): { left: number, right: number, bottom: number }
	if sim() then
		local v = Players.LocalPlayer:GetAttribute("CG_SimSafe")
		if typeof(v) == "Vector3" then
			return { left = v.X, right = v.Y, bottom = v.Z }
		end
		return { left = 0, right = 0, bottom = 0 }
	end
	local g = probeGui("CG_SafeProbe", Enum.ScreenInsets.DeviceSafeInsets)
	local f = probeGui("CG_FullProbe", Enum.ScreenInsets.None)
	if not (g and f) or g.AbsoluteSize.X <= 0 or f.AbsoluteSize.X <= 0 then
		return { left = 0, right = 0, bottom = 0 }
	end
	-- Both in GUI space; a real notch / home bar inset is never more than a fifth of the screen.
	local fp, fs = f.AbsolutePosition, f.AbsoluteSize
	local pos, size = g.AbsolutePosition, g.AbsoluteSize
	local capX, capY = fs.X * 0.2, fs.Y * 0.2
	return {
		left = math.clamp(pos.X - fp.X, 0, capX),
		right = math.clamp((fp.X + fs.X) - (pos.X + size.X), 0, capX),
		bottom = math.clamp((fp.Y + fs.Y) - (pos.Y + size.Y), 0, capY),
	}
end

-- Edge to edge (2026-10-07): every one of our screens (CG_*) covers the WHOLE display. Roblox's default
-- SafeAreaCompatibility (FullscreenExtension) otherwise squeezes a full-screen ScreenGui into the notch-safe area
-- on phones and stretches full-screen frames into bars at the sides, so banners stopped short of the edges and the
-- HUD, which adds the safe area itself (Screen.safe), was inset twice. The safe area now applies exactly once.
local function fullscreen(g: Instance)
	if g:IsA("ScreenGui") and string.sub(g.Name, 1, 3) == "CG_" and g.Name ~= "CG_SafeProbe" then
		if g.ScreenInsets ~= Enum.ScreenInsets.None then
			g.ScreenInsets = Enum.ScreenInsets.None
		end
		pcall(function()
			(g :: any).SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
		end)
	end
end
task.spawn(function()
	local lp = Players.LocalPlayer
	while not lp do
		task.wait()
		lp = Players.LocalPlayer
	end
	local pg = lp:WaitForChild("PlayerGui")
	for _, g in ipairs(pg:GetChildren()) do
		fullscreen(g)
	end
	pg.ChildAdded:Connect(function(g)
		fullscreen(g)
		task.defer(fullscreen, g) -- (a screen named after it was parented)
	end)
end)

local camConn: RBXScriptConnection? = nil
local function watchCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fire)
	end
	fire()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
-- Belt and braces (2026-10-07: on a phone the touch buttons once stayed where a first, smaller size put them): the
-- size is also polled, so a missed resize / rotation can never strand the HUD.
task.spawn(function()
	local last = Screen.size()
	while true do
		task.wait(0.25)
		local now = Screen.size()
		if now ~= last then
			last = now
			fire()
		end
	end
end)
pcall(function()
	(GuiService :: any):GetPropertyChangedSignal("TopbarInset"):Connect(fire)
end)
if studio then
	task.spawn(function()
		local lp = Players.LocalPlayer
		while not lp do
			task.wait()
			lp = Players.LocalPlayer
		end
		lp:GetAttributeChangedSignal("CG_SimViewport"):Connect(fire)
		lp:GetAttributeChangedSignal("CG_SimTopbar"):Connect(fire)
		lp:GetAttributeChangedSignal("CG_SimSafe"):Connect(fire)
	end)
end

-- A "Fit" UIScale on `holder` that keeps `rule(screen size)` applied while the holder lives, so a panel re-fits when
-- a phone turns or the window is resized.
-- The fit is the Base channel of the holder's one UIScale (UI/Motion): a second UIScale would be ignored by Roblox,
-- which is how every fitted panel once lost its open spring.
function Screen.fit(holder: Instance, rule: (Vector2) -> number): UIScale
	local g = holder :: GuiObject
	local function apply()
		Motion.set(g, "Base", rule(Screen.size()))
	end
	apply()
	local sc = Motion.scaleOf(g)
	local conn = changed.Event:Connect(apply)
	holder.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return sc
end

return Screen
