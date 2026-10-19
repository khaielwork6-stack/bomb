--!strict
-- The Carrier's toolkit (GDD §10.2): while you carry, every eligible pass target within 25 studs gets a soft outline
-- in its team colour and the nearest one a bobbing "BUMP!" arrow; a chevron at the screen edge points to the
-- nearest Safe Strip with an honest estimate (distance ÷ your current speed) in green when you can make it on the
-- current fuse, or "TOO FAR" in red. The fresh pass you just received flashes the giver's name for a second.
-- READ THE FACE (GDD §6.4): while the bomb's time is hidden the chevron shows only the run time, in neutral paper.
-- Implements: F-FEEL-02, F-MOD-02.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Theme.Palette
local S = Config.Strings
local new = Theme.new
local player = Players.LocalPlayer

local CarrierController = {}

local OUTLINE_RANGE = 25
local FLAT = Vector3.new(1, 0, 1)

local gui: ScreenGui
local arrow: BillboardGui
local chevron: Frame
local chevronLabel: TextLabel
local chevronArrow: ImageLabel
local highlights: { [Model]: Highlight } = {}

local function gs(): Configuration
	return ReplicatedStorage:FindFirstChild("GameState") :: Configuration
end

local function build()
	gui = new("ScreenGui", {
		Name = "FV_Carrier",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- BUMP! arrow over the nearest target.
	arrow = new("BillboardGui", {
		Name = "FV_BumpArrow",
		Size = UDim2.fromOffset(160, 80),
		StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = gui,
	})
	-- the baked 3D title word (art/titles), its glow behind; the drawn word only until the art is uploaded
	local art = (Assets.Title :: any).Bump
	if art then
		local h = 38
		local w = math.floor(h * art.size.X / art.size.Y)
		new("ImageLabel", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 20),
			Size = UDim2.fromOffset(math.floor(w * art.glowScale.X), math.floor(h * art.glowScale.Y)),
			BackgroundTransparency = 1,
			Image = art.glow,
			ImageColor3 = P.Spark,
			ImageTransparency = 0.45,
			Parent = arrow,
		})
		new("ImageLabel", {
			Name = "Word",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 20),
			Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1,
			Image = art.id,
			ScaleType = Enum.ScaleType.Fit,
			Parent = arrow,
		})
	else
		Theme.display(arrow, {
			Text = S.Ui.BumpWord,
			TextSize = 26,
			color = P.Spark,
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.new(1, 0, 0, 28),
		})
	end
	-- the chunky 3D arrow (art/icons), pointing down at the target
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(36, 36),
		Rotation = 90,
		BackgroundTransparency = 1,
		Image = Assets.Icon.Arrow or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = arrow,
	})
	-- Defuse chevron at the screen edge.
	local face = Theme.panel(gui, { Name = "Chevron", Size = UDim2.fromOffset(170, 46), radius = 999 })
	chevron = face.Parent :: Frame
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Visible = false
	chevronLabel = new("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -10, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Display,
		TextSize = 22,
		TextColor3 = P.Safe,
		Text = "",
		ZIndex = 3,
		Parent = face,
	})
	new("UIStroke", { Color = P.Ink, Thickness = 2.5, Parent = chevronLabel })
	-- the arrow rides the pill's outer edge and turns toward the strip
	chevronArrow = new("ImageLabel", {
		Name = "Point",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		Image = Assets.Icon.Arrow or "",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Parent = chevron,
	})
end

local function setOutline(model: Model, color: Color3?)
	local h = highlights[model]
	if color == nil then
		if h then
			h:Destroy()
			highlights[model] = nil
		end
		return
	end
	if not h then
		h = new("Highlight", {
			FillTransparency = 1,
			OutlineTransparency = 0.25,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			Adornee = model,
			Parent = gui,
		})
		highlights[model] = h :: Highlight
	end
	local outline = h :: Highlight
	outline.OutlineColor = color
end

local function bodies(): { { model: Model, host: Instance } }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			table.insert(out, { model = p.Character, host = p })
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then
				table.insert(out, { model = m, host = m })
			end
		end
	end
	return out
end

local function clearAll()
	for model in pairs(highlights) do
		setOutline(model, nil)
	end
	arrow.Enabled = false
	chevron.Visible = false
end

local function step()
	local explodeAt = player:GetAttribute("BombExplodeAt")
	local masked = player:GetAttribute("BombMasked") == true and type(explodeAt) ~= "number"
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carrying = type(explodeAt) == "number" or (masked and player:GetAttribute("BombId") ~= nil)
	if not carrying or not root or not ClientState.runLive() or player:GetAttribute("BombLocked") then
		clearAll()
		return
	end
	local remaining = if type(explodeAt) == "number" then explodeAt - workspace:GetServerTimeNow() else math.huge
	local pos = root.Position
	-- Pass targets: active, not carrying, not in a Safe Strip (State Safe = made it this crossing).
	local nearest: Model? = nil
	local nearestD = math.huge
	local seen = {}
	for _, b in ipairs(bodies()) do
		local r = b.model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local role = b.host:GetAttribute("Role")
		local eligible = r ~= nil
			and (role == "Runner" or role == "Bomber")
			and b.host:GetAttribute("State") == "Active"
			and b.host:GetAttribute("BombId") == nil
		if eligible and r then
			local d = ((r.Position - pos) * FLAT).Magnitude
			if d <= OUTLINE_RANGE then
				seen[b.model] = true
				setOutline(b.model, Theme.roleColor(role))
				if d < nearestD then
					nearest, nearestD = b.model, d
				end
			end
		end
	end
	for model in pairs(highlights) do
		if not seen[model] then
			setOutline(model, nil)
		end
	end
	-- in slap reach the tether takes over (HandOffController, F-BOMB-15): one marker at a time
	local stage = if remaining <= Config.Bomb.STAGE_CRITICAL
		then "CRITICAL"
		elseif remaining <= Config.Bomb.STAGE_HOT then "HOT"
		else "LIT"
	local slapReach = (Config.Bomb.PASS_RANGE_STAGE :: any)[stage]
		+ Config.Bomb.PASS_SLAP_REACH
		+ Config.Bomb.LAG_SLACK * 0.75
	if nearestD <= slapReach or ClientState.get("ThrowMode") == true then
		nearest = nil -- (THROW MODE: the aim arc is the marker)
	end
	arrow.Adornee = nearest
	arrow.Enabled = nearest ~= nil
	if nearest then
		arrow.StudsOffsetWorldSpace = Vector3.new(0, 4.6 + math.sin(os.clock() * 8) * 0.25, 0)
	end
	-- Defuse chevron: the nearer Safe Strip (field frame from GameState), an estimate at the current pace.
	local state = gs()
	local frame = state and state:GetAttribute("FieldCFrame")
	local halfLen = state and state:GetAttribute("FieldHalfLen")
	local cam = workspace.CurrentCamera
	if typeof(frame) ~= "CFrame" or type(halfLen) ~= "number" or not cam then
		chevron.Visible = false
		return
	end
	local l = frame:PointToObjectSpace(pos)
	local z = -l.Z -- along the field, +1 side positive
	local side = if z >= 0 then 1 else -1
	local dist = math.max(0, halfLen - z * side + 0.5)
	local speed = math.max((root.AssemblyLinearVelocity * FLAT).Magnitude, 16)
	local eta = dist / speed
	local goal = (frame * CFrame.new(l.X, 0, -side * (halfLen + 3))).Position
	local ok = eta <= remaining
	chevronLabel.Text = if ok then string.format(S.Ui.SafeIn, eta) else S.Ui.TooFar
	chevronLabel.TextColor3 = if masked then P.Paper elseif ok then P.Safe else P.Detonate
	-- Place it on the screen edge in the strip's direction (or over the strip when it's on screen).
	local vp = cam.ViewportSize
	local sp, onScreen = cam:WorldToViewportPoint(goal)
	local center = vp / 2
	local dir2 = Vector2.new(sp.X, sp.Y) - center
	if sp.Z < 0 then
		dir2 = -dir2
	end
	if onScreen and sp.Z > 0 then
		chevron.Position = UDim2.fromOffset(sp.X, math.clamp(sp.Y, 90, vp.Y - 140))
	else
		local unit = if dir2.Magnitude > 1 then dir2.Unit else Vector2.new(0, -1)
		local edge = Vector2.new(vp.X / 2 - 110, vp.Y / 2 - 90)
		local k = math.min(edge.X / math.max(math.abs(unit.X), 1e-3), edge.Y / math.max(math.abs(unit.Y), 1e-3))
		local at = center + unit * k
		chevron.Position = UDim2.fromOffset(at.X, at.Y)
	end
	chevronArrow.Rotation = math.deg(math.atan2(dir2.Y, dir2.X))
	chevron.Visible = dist > 0.5
end

function CarrierController.start()
	build()
	RunService.RenderStepped:Connect(step)
	-- (no "from <name>" line any more: one voice at a time, DECISIONS 2026-10-18)
end

return CarrierController
