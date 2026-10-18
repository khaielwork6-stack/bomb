--!strict
-- The results podium (Asset Bible §7.2; ART_BACKLOG "Results 3D podium"): up to three winners' real avatars standing
-- on gold / silver / bronze toy blocks in a ViewportFrame above the results card. The blocks rise 3rd → 2nd → 1st with a
-- stamp each, then the avatars drop on; the 1st gets the crown and a confetti burst. A Bombers win puts the MVP alone
-- on the top block (sooty). Bots stand as themselves (their workspace model). The prop model art/props Prop.Podium
-- is used when it is in ReplicatedStorage.FV_Art.Props.Podium (Attachments Spot1 / Spot2 / Spot3 give each
-- step's standing spot); otherwise the steps are built from studded blocks.
-- ViewportFrames draw no SurfaceGuis or particles, so the step numbers, names and confetti are 2D labels placed with
-- the viewport camera's projection.
-- Implements: F-RES-01 (winners shown), Asset Bible §7.2 (podium).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local new = Theme.new
local P = Theme.Palette

local Podium = {}

export type Entry = { model: Model?, name: string, rank: number }

local SIZE = Vector2.new(600, 250)
local FOV = 30
local STEP = { -- rank → x, height, colour
	[1] = { x = 0, h = 3.0, color = Color3.fromRGB(255, 196, 46) },
	[2] = { x = -4.6, h = 2.1, color = Color3.fromRGB(150, 196, 236) },
	[3] = { x = 4.6, h = 1.4, color = Color3.fromRGB(222, 132, 70) },
}
local W, D = 4.2, 4
local CAM = CFrame.lookAt(Vector3.new(0, 6.6, 25), Vector3.new(0, 4.3, 0)) -- frames a 5-stud avatar on the top step

local function project(world: Vector3): Vector2
	local p = CAM:PointToObjectSpace(world)
	local t = math.tan(math.rad(FOV) / 2)
	local aspect = SIZE.X / SIZE.Y
	local x = p.X / (-p.Z * t * aspect)
	local y = p.Y / (-p.Z * t)
	return Vector2.new((x + 1) / 2 * SIZE.X, (1 - y) / 2 * SIZE.Y)
end

-- A clean, anchored copy of a character to stand in the viewport (no scripts, sounds, tools or welded bombs).
local function standIn(model: Model): Model?
	local was = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	model.Archivable = was
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("Tool")
			or d:IsA("ParticleEmitter")
			or (d:IsA("Model") and d.Name == "Bomb")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return copy
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = new("Part", {
		Name = name,
		Anchored = true,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	}) :: Part
	return p
end

-- Build the podium inside `parent` (a GuiObject; the viewport is anchored bottom-centre at its top edge).
-- `soot` = the Bombers' MVP stage. Returns the root frame (destroyed with its parent).
function Podium.build(parent: GuiObject, entries: { Entry }, soot: boolean?): Frame
	local root = new("Frame", {
		Name = "Podium",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -30),
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = parent,
	})
	local vp = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 246, 228),
		LightDirection = Vector3.new(-0.45, -1, -0.6),
		ZIndex = 2,
		Parent = root,
	}) :: ViewportFrame
	local world = new("WorldModel", { Parent = vp })
	local cam = new("Camera", { CFrame = CAM, FieldOfView = FOV, Parent = vp }) :: Camera
	vp.CurrentCamera = cam

	-- the steps: the prop model when it is in, else studded toy blocks with an ink base
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local props = art and art:FindFirstChild("Props")
	local prop = props and props:FindFirstChild("Podium")
	local tops: { [number]: number } = {}
	local steps: { [number]: Instance } = {}
	if prop and prop:IsA("Model") then
		local m = prop:Clone()
		m:PivotTo(CFrame.new())
		m.Parent = world
		for r = 1, 3 do
			-- each step's standing spot: an Attachment Spot<r> (studio_import from the manifest's spots)
			local spot = m:FindFirstChild("Spot" .. r, true)
			if spot and spot:IsA("Attachment") then
				tops[r] = spot.WorldPosition.Y
				STEP[r].x = spot.WorldPosition.X
			end
		end
		steps[0] = m
	end
	if not next(tops) then
		for r = 1, 3 do
			local s = STEP[r]
			local m = new("Model", { Name = "Step" .. r, Parent = world }) :: Model
			block(m, "Block", Vector3.new(W, s.h, D), CFrame.new(s.x, s.h / 2, 0), s.color)
			block(
				m,
				"Lip",
				Vector3.new(W + 0.3, 0.3, D + 0.3),
				CFrame.new(s.x, s.h - 0.15, 0),
				s.color:Lerp(Color3.new(1, 1, 1), 0.3)
			)
			block(m, "Base", Vector3.new(W + 0.2, 0.25, D + 0.2), CFrame.new(s.x, 0.125, 0), P.Ink)
			tops[r] = s.h
			steps[r] = m
		end
	end

	-- 2D overlay: the step numbers on the fronts, the names under them
	local overlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = root,
	})
	local used = {}
	for _, e in ipairs(entries) do
		used[e.rank] = e
	end
	local order = { 3, 2, 1 }
	local function label(r: number, e: Entry?)
		local s = STEP[r]
		local front = project(Vector3.new(s.x, (tops[r] or s.h) * 0.5, D / 2))
		if not steps[0] then -- the prop has its own numerals
			local num = Widgets.label(overlay, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(front.X, front.Y),
				Size = UDim2.fromOffset(60, 50),
				TextSize = if r == 1 then 44 else 36,
				font = Theme.Font.Display,
				stroke = 3,
				Text = tostring(r),
				ZIndex = 5,
			})
			Widgets.springIn(num, 0.4)
		end
		if e then
			local base = project(Vector3.new(s.x, 0, D / 2 + 0.4))
			local n = Widgets.label(overlay, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(base.X, base.Y + 2),
				Size = UDim2.fromOffset(150, 22),
				TextSize = 18,
				font = Theme.Font.Display,
				stroke = 2.5,
				color = if r == 1 then P.Gold else P.Paper,
				Text = e.name,
				ZIndex = 5,
			})
			n.TextTruncate = Enum.TextTruncate.AtEnd
		end
	end

	-- the rise: each step grows up from the floor, 3rd → 2nd → 1st
	local function grow(r: number, after: () -> ())
		local m = steps[r]
		if not m or not m:IsA("Model") then
			after()
			return
		end
		local parts: { [BasePart]: CFrame } = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				parts[d] = d.CFrame
				d.CFrame = d.CFrame - Vector3.new(0, tops[r] + 0.4, 0)
			end
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / 0.28, 0, 1)
			local e = 1 - (1 - a) ^ 3
			for p, cf in pairs(parts) do
				p.CFrame = cf - Vector3.new(0, (tops[r] + 0.4) * (1 - e), 0)
			end
			if a >= 1 then
				conn:Disconnect()
				after()
			end
		end)
	end

	local function drop(e: Entry)
		local model = e.model and standIn(e.model)
		if not model then
			return
		end
		local s = STEP[e.rank]
		local bcf, bsize = model:GetBoundingBox()
		local feet = model:GetPivot().Y - (bcf.Y - bsize.Y / 2)
		local scale = 1
		if bsize.Y > 6.5 then -- an oversized rig still fits its step
			scale = 5.5 / bsize.Y
			model:ScaleTo(model:GetScale() * scale)
			feet *= scale
		end
		local yaw = if e.rank == 2 then math.rad(-14) elseif e.rank == 3 then math.rad(14) else 0
		local rest = CFrame.new(s.x, (tops[e.rank] or s.h) + feet, 0) * CFrame.Angles(0, math.pi + yaw, 0)
		model:PivotTo(rest + Vector3.new(0, 4, 0))
		if soot then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = d.Color:Lerp(Color3.fromRGB(40, 36, 40), 0.35)
				end
			end
		end
		model.Parent = world
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / 0.32, 0, 1)
			local y = 4 * (1 - a * a)
			model:PivotTo(rest + Vector3.new(0, y, 0))
			if a >= 1 then
				conn:Disconnect()
				Sfx.play("Land", 0.6)
			end
		end)
		if e.rank == 1 then
			task.delay(0.35, function()
				if root.Parent == nil then
					return
				end
				local head = project(rest.Position + Vector3.new(0, bsize.Y * scale - feet + 0.6, 0))
				local crown = Widgets.icon(overlay, "Crown", 54, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromOffset(head.X, head.Y),
					ZIndex = 6,
				})
				Widgets.springIn(crown.Parent :: GuiObject, 0.3)
				Sfx.play("Claim")
				for _ = 1, 26 do
					local f = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(head.X, head.Y),
						Size = UDim2.fromOffset(10, 6),
						Rotation = math.random(0, 360),
						BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1),
						BorderSizePixel = 0,
						ZIndex = 6,
						Parent = overlay,
					})
					local a = math.rad(math.random(200, 340))
					local d = 90 + math.random() * 140
					TweenService:Create(f, TweenInfo.new(0.9 + math.random() * 0.5, Enum.EasingStyle.Quad), {
						Position = UDim2.fromOffset(head.X + math.cos(a) * d, head.Y + math.sin(a) * d + 150),
						Rotation = f.Rotation + 300,
						BackgroundTransparency = 1,
					}):Play()
					task.delay(1.5, function()
						f:Destroy()
					end)
				end
			end)
		end
	end

	task.spawn(function()
		for i, r in ipairs(order) do
			if root.Parent == nil then
				return
			end
			local done = false
			grow(r, function()
				done = true
			end)
			task.delay(0.12, function()
				Sfx.play("Stamp", 0.7, 0.9 + i * 0.08)
			end)
			while not done do
				task.wait()
			end
			label(r, used[r])
		end
		for _, r in ipairs(order) do
			local e = used[r]
			if e and root.Parent then
				drop(e)
				task.wait(0.22)
			end
		end
	end)
	return root
end

Podium.HEIGHT = SIZE.Y

return Podium
