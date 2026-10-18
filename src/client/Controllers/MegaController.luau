--!strict
-- The MEGA BOMB on every client (GDD §16): the event clock (F-MEGA-10: "MEGA BOMB IN 4:12" between rounds, the Mega
-- Fuse "MEGA 1:12" during the round), the giant's huge bomb on its back — the hero bomb at the giant's scale, its fuse
-- burning as the true Mega Fuse and its face going SMUG → UH-OH → PANIC as it runs down — the STOMP's telegraph ring,
-- the feed beat ("−6 s!"), and the whole-map detonation. The clock is functional styling only (the UI pass restyles
-- it; Asset Bible §6).
-- Implements: F-MEGA-04 (telegraph), F-MEGA-05 (the clock + detonation), F-MEGA-06 (feed feedback), F-MEGA-10.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local BombFace = require(script.Parent.Parent.BombFace)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local FxController = require(script.Parent.FxController)

local MG = Config.Mega
local S = Config.Strings.Round
local P = Theme.Palette
local Ph = Types.Phase
local new = Theme.new

local MegaController = {}

local gs: Configuration
local chip: Frame
local chipLabel: TextLabel
local bomb: { model: Model, mount: BasePart, face: BombFace.Rig?, fuse: { BasePart }, host: Instance }? = nil

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

-- The giant's back bomb: the hero bomb scaled to the giant, welded to its torso (clamp toward it, face backward).
local function buildBomb(host: Instance, char: Model)
	local torso = char:FindFirstChild("Torso") :: BasePart?
	local art = ReplicatedStorage:FindFirstChild("FV_Art")
	local template = art and art:FindFirstChild("Bomb") :: Model?
	if not torso or not template then
		return
	end
	local model = template:Clone()
	model.Name = "FV_MegaBomb"
	local mount =
		new("Part", { Name = "Mount", Size = Vector3.one * 0.2, Transparency = 1, CanCollide = false, Parent = model })
	model.PrimaryPart = mount
	mount.CFrame = CFrame.new()
	model:ScaleTo(MG.GIANT_SCALE) -- about the mount (the body centre), before anything is welded
	local face = BombFace.attach(model, mount, MG.GIANT_SCALE)
	local fuse = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= mount and not BombFace.isFace(d) then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			new("WeldConstraint", { Part0 = mount, Part1 = d, Parent = d })
			local n = string.match(d.Name, "^Fuse(%d+)$")
			if n then
				fuse[tonumber(n) :: number] = d
			elseif d.Name == "LampF" or d.Name == "LampB" then
				d.Material = Enum.Material.Neon
				d.Color = P.Detonate
			end
		end
	end
	mount.Anchored = false
	local back = MG.GIANT_SCALE * (0.5 + 0.4 + 1.1) -- the same mount as a Carrier's bomb (BombController), at scale
	new("Weld", { Part0 = torso, Part1 = mount, C0 = CFrame.new(0, 0.15 * MG.GIANT_SCALE, back), Parent = mount })
	model.Parent = char
	bomb = { model = model, mount = mount, face = face, fuse = fuse, host = host }
end

local function clearBomb()
	if bomb then
		bomb.model:Destroy()
		bomb = nil
	end
end

local function step(dt: number)
	local t = workspace:GetServerTimeNow()
	local phase = ClientState.phase()
	local megaId = gs:GetAttribute("MegaId")
	local ends = gs:GetAttribute("MegaEndsAt")
	-- the clock
	if type(megaId) == "string" then
		local left = if type(ends) == "number" then ends - t else MG.FUSE
		chipLabel.Text = S.MegaLeft:format(clock(left))
		chip.Visible = true
	elseif phase == Ph.Intermission or phase == Ph.Results or phase == "" then
		local nextAt = gs:GetAttribute("MegaNextAt")
		chip.Visible = type(nextAt) == "number"
		if type(nextAt) == "number" then
			chipLabel.Text = S.MegaNext:format(clock(nextAt - t))
		end
	else
		chip.Visible = false
	end
	-- the giant's bomb
	local host, char = nil, nil
	if type(megaId) == "string" then
		host, char = ClientState.byId(megaId)
	end
	if bomb and (not host or bomb.host ~= host or not bomb.model.Parent) then
		clearBomb()
	end
	if not bomb and host and char then
		buildBomb(host, char)
	end
	local b = bomb
	if b then
		local left = if type(ends) == "number" then math.max(0, ends - t) else MG.FUSE
		local frac = math.clamp(left / MG.FUSE, 0, 1)
		local burnt = math.floor((1 - frac) * 12)
		for i, seg in pairs(b.fuse) do
			seg.Transparency = if (12 - i) < burnt then 1 else 0
		end
		if b.face then
			local pose = if left <= 10 then "PANIC" elseif left <= 30 then "UHOH" else "SMUG"
			BombFace.update(
				b.face,
				dt,
				pose,
				nil,
				pose == "SMUG",
				if pose == "PANIC" then Config.Feel.FACE_SHAKE else 0
			)
		end
	end
end

-- F-MEGA-04: the STOMP's ring grows over the telegraph, then the slam.
local function stompRing(pos: Vector3, radius: number)
	local ring = new("Part", {
		Name = "FV_StompRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = CFrame.new(pos - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = P.Mega,
		Transparency = 0.35,
		Parent = workspace,
	})
	TweenService:Create(ring, TweenInfo.new(MG.STOMP_TELEGRAPH, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
	}):Play()
	task.delay(MG.STOMP_TELEGRAPH, function()
		ring:Destroy()
		Sfx.at("BoomBody", pos, 0.9, 0.6)
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - pos).Magnitude < radius * 3 then
			FxController.shake(0.45)
		end
	end)
end

function MegaController.start()
	gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local gui = new("ScreenGui", {
		Name = "FV_Mega",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"),
	})
	local face = Theme.panel(gui, {
		Name = "MegaClock",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 112),
		Size = UDim2.fromOffset(200, 40),
		color = P.Ink2,
		border = P.Mega,
		border2 = P.Ink,
		radius = 999,
	})
	chip = face.Parent :: Frame
	chipLabel = Theme.display(face, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 20,
		TextColor3 = P.Paper,
	}) :: TextLabel
	chip.Visible = false
	RunService.RenderStepped:Connect(step)
	Net.listen("RoundFx", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.kind == "MegaStomp" and typeof(p.pos) == "Vector3" then
			stompRing(p.pos, if type(p.radius) == "number" then p.radius else MG.STOMP_RADIUS)
		elseif p.kind == "MegaFeed" then
			Sfx.play("Clutch", 0.8, 1.2)
			if bomb then
				FxController.boom(bomb.mount.Position, 0.6, true)
			end
		elseif p.kind == "MegaDetonate" then
			local at = if bomb then bomb.mount.Position else nil
			if at then
				FxController.boom(at, MG.GIANT_SCALE, false)
			end
			FxController.shake(1)
			Sfx.play("BoomBody", 1.3, 0.6)
			Sfx.play("BoomDebris", 1.3, 0.7)
		end
	end)
end

return MegaController
