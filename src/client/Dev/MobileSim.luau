--!strict
-- Studio-only device simulator for checking HUD layouts at phone / tablet sizes on a desktop.
--   LocalPlayer:SetAttribute("CG_Sim", "844x390")      -- landscape iPhone 14 (top bar 58 by default)
--   LocalPlayer:SetAttribute("CG_Sim", "667x375@44")   -- WxH@topbarHeight
--   LocalPlayer:SetAttribute("CG_Sim", "")             -- off
-- It sets CG_SimViewport / CG_SimTopbar (read by UI/Screen, so every scaler lays out for that device), moves each
-- ScreenGui's content into a frame of that size in the middle of the window (scaled down if the device is bigger
-- than the window), masks the rest, and draws Roblox's top bar and the thumbstick's resting ring as a guide.
-- Pair it with CG_ForceDevice = "Touch" for the touch layout. Never runs outside Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MobileSim = {}

local SIM_ROOT = "CG_SimRoot"
local OVERLAY = "CG_SimOverlay"

local active: { size: Vector2, scale: number }? = nil
local conns: { RBXScriptConnection } = {}

local function windowSize(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

local function rootFor(gui: ScreenGui): Frame
	local existing = gui:FindFirstChild(SIM_ROOT)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local sim = active :: { size: Vector2, scale: number }
	local f = Instance.new("Frame")
	f.Name = SIM_ROOT
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(sim.size.X, sim.size.Y)
	f.BackgroundTransparency = 1
	f.ClipsDescendants = true
	f.ZIndex = 1
	local s = Instance.new("UIScale")
	s.Scale = sim.scale
	s.Parent = f
	f.Parent = gui
	return f
end

local function adopt(gui: ScreenGui)
	if gui.Name == OVERLAY or not active then
		return
	end
	local root = rootFor(gui)
	for _, c in ipairs(gui:GetChildren()) do
		if c ~= root and c:IsA("GuiObject") then
			c.Parent = root
		end
	end
	table.insert(
		conns,
		gui.ChildAdded:Connect(function(c)
			task.defer(function()
				if active and c.Parent == gui and c:IsA("GuiObject") and c.Name ~= SIM_ROOT then
					c.Parent = rootFor(gui)
				end
			end)
		end)
	)
end

local function release(gui: ScreenGui)
	local root = gui:FindFirstChild(SIM_ROOT)
	if root then
		for _, c in ipairs(root:GetChildren()) do
			if c:IsA("GuiObject") then
				c.Parent = gui
			end
		end
		root:Destroy()
	end
end

local function overlay(pg: PlayerGui)
	local sim = active :: { size: Vector2, scale: number }
	local g = Instance.new("ScreenGui")
	g.Name = OVERLAY
	g.IgnoreGuiInset = true
	g.DisplayOrder = 10000
	g.ResetOnSpawn = false
	local win = windowSize()
	local w, h = sim.size.X * sim.scale, sim.size.Y * sim.scale
	local x0, y0 = (win.X - w) / 2, (win.Y - h) / 2
	local function mask(px: number, py: number, sx: number, sy: number)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(px, py)
		f.Size = UDim2.fromOffset(sx, sy)
		f.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
		f.BorderSizePixel = 0
		f.Parent = g
	end
	mask(0, 0, win.X, y0)
	mask(0, y0 + h, win.X, win.Y - y0 - h)
	mask(0, y0, x0, h)
	mask(x0 + w, y0, win.X - x0 - w, h)
	-- Device frame guides (in device pixels, scaled like the content).
	local dev = Instance.new("Frame")
	dev.AnchorPoint = Vector2.new(0.5, 0.5)
	dev.Position = UDim2.fromScale(0.5, 0.5)
	dev.Size = UDim2.fromOffset(sim.size.X, sim.size.Y)
	dev.BackgroundTransparency = 1
	local ds = Instance.new("UIScale")
	ds.Scale = sim.scale
	ds.Parent = dev
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 200)
	stroke.Thickness = 2
	stroke.Parent = dev
	dev.Parent = g
	local barH = Players.LocalPlayer:GetAttribute("CG_SimTopbar")
	local bh = if type(barH) == "number" then barH else 58
	-- Roblox's two core buttons on the left of the top bar.
	for i = 0, 1 do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, 0.5)
		b.Position = UDim2.fromOffset(12 + i * (bh * 0.8 + 6), bh / 2)
		b.Size = UDim2.fromOffset(bh * 0.8, bh * 0.8)
		b.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		b.BackgroundTransparency = 0.3
		b.Parent = dev
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
	end
	-- The dynamic thumbstick's resting ring, bottom-left.
	local ring = Instance.new("Frame")
	local r = if sim.size.Y < 500 then 50 else 70
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(r + 40, sim.size.Y - r - 30)
	ring.Size = UDim2.fromOffset(r * 2, r * 2)
	ring.BackgroundTransparency = 1
	ring.Parent = dev
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Color = Color3.fromRGB(255, 255, 255)
	rs.Transparency = 0.4
	rs.Thickness = 3
	rs.Parent = ring
	g.Parent = pg
end

local function stop()
	local lp = Players.LocalPlayer
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	active = nil
	if pg then
		local o = pg:FindFirstChild(OVERLAY)
		if o then
			o:Destroy()
		end
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") then
				release(g)
			end
		end
	end
	lp:SetAttribute("CG_SimViewport", nil)
	lp:SetAttribute("CG_SimTopbar", nil)
end

local function start(spec: string)
	stop()
	local w, h, bar = string.match(spec, "^(%d+)x(%d+)@?(%d*)$")
	if not (w and h) then
		return
	end
	local lp = Players.LocalPlayer
	local pg = lp:WaitForChild("PlayerGui") :: PlayerGui
	local size = Vector2.new(tonumber(w) :: number, tonumber(h) :: number)
	local win = windowSize()
	active = { size = size, scale = math.min(1, (win.X - 16) / size.X, (win.Y - 16) / size.Y) }
	lp:SetAttribute("CG_SimTopbar", if bar and bar ~= "" then tonumber(bar) else 58)
	lp:SetAttribute("CG_SimViewport", size)
	for _, g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") then
			adopt(g)
		end
	end
	table.insert(
		conns,
		pg.ChildAdded:Connect(function(g)
			if g:IsA("ScreenGui") then
				task.defer(adopt, g)
			end
		end)
	)
	overlay(pg)
end

function MobileSim.start()
	if not RunService:IsStudio() then
		return
	end
	local lp = Players.LocalPlayer
	lp:GetAttributeChangedSignal("CG_Sim"):Connect(function()
		local spec = lp:GetAttribute("CG_Sim")
		if type(spec) == "string" and spec ~= "" then
			start(spec)
		else
			stop()
		end
	end)
end

return MobileSim
