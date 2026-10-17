--!strict
-- Footsteps (2026-10-08, the user: "a very pleasing footstep each time your foot touches the ground, matching your
-- speed whether walking or running"). Every R6 character near the camera (you, other players, bots) gets a soft step
-- on each real footfall: a footfall is the lowest point of a leg's swing (the leg's bottom, measured in the root's
-- space, stops going down and starts coming up), so steps stay on the animation whatever is playing: walk, run,
-- strafe, backpedal. Volume and pitch follow the pace; one of four recordings at random so it never machine-guns.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Sfx = require(script.Parent.Parent.Sfx)

local FootstepController = {}

local KEYS = { "Footstep1", "Footstep2", "Footstep3", "Footstep4" }
local RANGE = 45 -- studs from the camera: characters further away are silent
local MAX_TRACKED = 10 -- nearest characters that step at all (bots crowd the lobby)
local MIN_SPEED = 2.5 -- studs/s of ground speed before steps sound
local MIN_GAP = 0.16 -- s between two steps of the same foot (no double triggers on a wobble)
local DEPTH = 0.12 -- studs the foot must have dropped since its last high point to count as a real step
local OTHERS = 0.7 -- other characters are a little quieter than you

type Foot = { last: number, falling: boolean, high: number, lastStep: number }
type Track = { model: Model, root: BasePart, hum: Humanoid, legs: { [BasePart]: Foot }, prev: Vector3?, speed: number }
local tracks: { [Model]: Track } = {}
local lastKey = 0

local function footHeight(root: BasePart, leg: BasePart): number
	local bottom = leg.CFrame * Vector3.new(0, -leg.Size.Y / 2, 0)
	return root.CFrame:PointToObjectSpace(bottom).Y
end

local function step(t: Track, leg: BasePart, speed: number, isMe: boolean)
	-- Walk (≈6 studs/s) soft and low, a full run brighter and a touch louder; a little random pitch each time.
	local pace = math.clamp((speed - MIN_SPEED) / 20, 0, 1)
	local vol = (0.45 + 0.55 * pace) * (if isMe then 1 else OTHERS)
	local pitch = (0.92 + 0.16 * pace) * (0.96 + math.random() * 0.08)
	local k = math.random(1, #KEYS - 1)
	if k >= lastKey then
		k += 1 -- never the same recording twice in a row
	end
	lastKey = k
	local pos = leg.CFrame * Vector3.new(0, -leg.Size.Y / 2, 0)
	Sfx.at(KEYS[k], pos, vol, pitch)
	local _ = t
end

local function candidates(): { Model }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(out, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then
				table.insert(out, m)
			end
		end
	end
	return out
end

-- Which characters are tracked: the nearest few within RANGE (rebuilt a few times a second).
local function refresh()
	local cam = workspace.CurrentCamera.CFrame.Position
	local near: { { m: Model, d: number } } = {}
	for _, m in ipairs(candidates()) do
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = (root.Position - cam).Magnitude
			if d <= RANGE then
				table.insert(near, { m = m, d = d })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(#near, MAX_TRACKED) do
		local m = near[i].m
		keep[m] = true
		if not tracks[m] then
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = m:FindFirstChildOfClass("Humanoid")
			local l, r = m:FindFirstChild("Left Leg"), m:FindFirstChild("Right Leg")
			if root and hum and l and r and l:IsA("BasePart") and r:IsA("BasePart") then
				local legs: { [BasePart]: Foot } = {}
				for _, leg in ipairs({ l, r }) do
					local h = footHeight(root, leg)
					legs[leg] = { last = h, falling = false, high = h, lastStep = 0 }
				end
				tracks[m] = { model = m, root = root, hum = hum, legs = legs, prev = nil, speed = 0 }
			end
		end
	end
	for m in pairs(tracks) do
		if not keep[m] then
			tracks[m] = nil
		end
	end
end

function FootstepController.start()
	local acc = 1
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			refresh()
		end
		local now = os.clock()
		local me = Players.LocalPlayer.Character
		for m, t in pairs(tracks) do
			if not (m.Parent and t.root.Parent) then
				tracks[m] = nil
				continue
			end
			-- Pace and airborne-ness from how the root actually moved (remote characters' velocities aren't reliable
			-- on this client, and some bots are driven by CFrame), smoothed over a few frames.
			local pos = t.root.Position
			local vy = 0
			if t.prev and dt > 0 then
				local d = pos - t.prev
				t.speed += (Vector3.new(d.X, 0, d.Z).Magnitude / dt - t.speed) * math.min(1, dt * 12)
				vy = d.Y / dt
			end
			t.prev = pos
			local speed = t.speed
			local grounded = if m == me then t.hum.FloorMaterial ~= Enum.Material.Air else math.abs(vy) < 6
			grounded = grounded and t.hum:GetState() ~= Enum.HumanoidStateType.Physics
			for leg, f in pairs(t.legs) do
				local h = footHeight(t.root, leg)
				local dh = h - f.last
				if dh < -1e-3 then
					if not f.falling then
						f.high = f.last -- top of the swing
					end
					f.falling = true
				elseif dh > 1e-3 then
					-- The foot just turned upward: it was planted at the bottom of the swing.
					if
						f.falling
						and grounded
						and speed >= MIN_SPEED
						and f.high - f.last >= DEPTH
						and now - f.lastStep >= MIN_GAP
					then
						f.lastStep = now
						step(t, leg, speed, m == me)
					end
					f.falling = false
				end
				f.last = h
			end
		end
	end)
end

return FootstepController
