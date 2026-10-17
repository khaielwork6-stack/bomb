--!strict
-- Server sanity check for client-owned movement (speed hacks / teleports / hovering). GDD §22.2.
-- Soft correction: 3 violations within 2 s -> snap back to the last valid position. 10 in a match -> kick.
-- `plausible(p)` lets gameplay refuse to act on a position the validator hasn't accepted yet (a one-tick teleport
-- into a safe zone, onto a runner for a swing), since a single violation is never corrected on its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Participants = require(script.Parent.Participants)
local Characters = require(script.Parent.Characters)

local M = Config.Movement
local C = Config.Movement

local MovementValidator = {}

-- Extra horizontal speed allowed right now (wind gusts, conveyors), set by modifiers/hazards.
MovementValidator.extraSpeed = 0

local HOVER_HEIGHT = 7 -- studs of feet-to-ground gap that count as hovering (jumping is disabled in this game)
local HOVER_TIME = 0.8 -- seconds of hovering (not falling) before it's a strike
local STRIKE_FRESH = 0.6 -- a strike this recent makes the current position untrusted

type Track = { pos: Vector3, t: number, strikes: { number }, total: number, hoverSince: number? }
local tracks: { [string]: Track } = {}

local function reset(p: Participants.Participant)
	if p.root then
		tracks[p.id] =
			{ pos = p.root.Position, t = os.clock(), strikes = {}, total = (tracks[p.id] and tracks[p.id].total) or 0 }
	end
end

function MovementValidator.resetAll()
	for _, p in ipairs(Participants.humans()) do
		reset(p)
	end
end

function MovementValidator.resetStrikes()
	for _, tr in pairs(tracks) do
		tr.total = 0
		tr.strikes = {}
	end
end

-- A one-off allowance of `studs` extra displacement for the next `seconds` (server knock-backs, gate bonks), instead
-- of a full reset (which would accept any position as the new valid point).
function MovementValidator.allowExtra(p: Participants.Participant, studs: number, seconds: number)
	local now = workspace:GetServerTimeNow()
	p.data.extraSlack = math.max(if (p.data.extraSlackUntil or 0) > now then p.data.extraSlack or 0 else 0, studs)
	p.data.extraSlackUntil = now + seconds
end

-- Horizontal studs a participant may legitimately cover in `dt` seconds right now.
local function allowance(p: Participants.Participant, dt: number): number
	local serverT = workspace:GetServerTimeNow()
	-- Role profile (Config.Movement.Profiles): the same speed / dash multipliers the clients and bots move with.
	local prof = (M.Profiles :: any)[if p.role == "Runner" or p.role == "Bomber" then p.role else "Lobby"] or {}
	local mult = ((p.attrs:GetAttribute("SpeedMult") :: number?) or 1) * (prof.speed or 1)
	local base = if p.role == "None" then M.LOBBY_SPEED else M.MAX_SPEED
	local rate = base * math.max(mult, 1) * M.BRAVE_BOOST_MULT
	-- Dash and dive each get a short window at their own speed (server-cooldown-gated in Combat).
	if serverT - (p.data.lastDashAt or -math.huge) < M.DASH_TIME + 0.35 then
		local dashMult = math.max(((p.attrs:GetAttribute("MoveDashMult") :: number?) or 1) * (prof.dash or 1), 1)
		rate = math.max(rate, M.DASH_SPEED * 1.15 * math.max(mult, 1) * dashMult)
	end
	-- Slide burst (SLIDE_MULT × up to max, held then gliding down) for the slide plus a little latency.
	if serverT - (p.data.lastSlideAt or -math.huge) < M.SLIDE_TIME + 0.35 then
		rate = math.max(rate, base * math.max(mult, 1) * M.BRAVE_BOOST_MULT * M.SLIDE_MULT)
	end
	if serverT - (p.data.lastDiveAt or -math.huge) < C.DIVE_TIME + 0.35 then
		rate = math.max(rate, C.DIVE_DIST / C.DIVE_TIME * 1.15)
	end
	local slack = M.VALIDATE_SLACK
	if (p.data.extraSlackUntil or 0) > serverT then
		slack += p.data.extraSlack or 0
	end
	return (rate * M.VALIDATE_TOLERANCE + MovementValidator.extraSpeed) * dt + slack
end

local function exempt(p: Participants.Participant, root: BasePart): boolean
	return root.Anchored
		or Characters.isRagdolled(p)
		or workspace:GetServerTimeNow() - (p.data.teleportAt or -math.huge) < 0.75
end

-- Is the participant's current position one the validator would accept? (Bots and untracked players: yes.)
function MovementValidator.plausible(p: Participants.Participant): boolean
	local root = p.root
	local tr = tracks[p.id]
	if p.isBot or not root or not tr or exempt(p, root) then
		return true
	end
	local nowC = os.clock()
	for _, s in ipairs(tr.strikes) do
		if nowC - s < STRIKE_FRESH then
			return false
		end
	end
	local disp = ((root.Position - tr.pos) * Vector3.new(1, 0, 1)).Magnitude
	return disp <= allowance(p, nowC - tr.t)
end

-- Feet-to-ground gap below a root (characters and effects ignored); math.huge over the void.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function heightAboveGround(root: BasePart, scale: number): number
	local ignore: { Instance } = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		table.insert(ignore, bots)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rayParams)
	return if hit then root.Position.Y - hit.Position.Y - 3 * scale else math.huge -- (R6 hips: 3 studs up per unit of scale)
end

local function strike(p: Participants.Participant, tr: Track, root: BasePart, nowC: number, why: string, now: boolean?)
	table.insert(tr.strikes, nowC)
	tr.total += 1
	local recent = {}
	for _, s in ipairs(tr.strikes) do
		if nowC - s <= M.VALIDATE_STRIKE_WINDOW then
			table.insert(recent, s)
		end
	end
	tr.strikes = recent
	if now or #recent >= M.VALIDATE_STRIKES then
		warn(`[MovementValidator] correcting {p.name}: {why}`)
		local look = root.CFrame.LookVector
		Characters.pivot(p, CFrame.lookAt(tr.pos, tr.pos + Vector3.new(look.X, 0, look.Z)))
		tr.strikes = {}
		tr.hoverSince = nil
		if tr.total >= M.VALIDATE_KICK_STRIKES and p.player then
			p.player:Kick("Movement desync detected. Please rejoin.")
		end
	end
	tr.t = nowC -- don't advance the valid position on a violation
end

local function check(p: Participants.Participant)
	local root = p.root
	if not root or root.Parent == nil then
		tracks[p.id] = nil
		return
	end
	local tr = tracks[p.id]
	local nowC = os.clock()
	if not tr or exempt(p, root) then
		reset(p)
		return
	end
	local dt = nowC - tr.t
	if dt < M.VALIDATE_INTERVAL then
		return
	end
	-- Hovering: holding height above the ground without falling makes a runner uncatchable (hit cones are ±4.5).
	local serverT = workspace:GetServerTimeNow()
	local springing = serverT - (p.data.lastSpringAt or -math.huge) < 2.0 or p.data.airborneImmune == true
	local airborne = not springing and heightAboveGround(root, p.data.scale or 1) > HOVER_HEIGHT
	if airborne and root.AssemblyLinearVelocity.Y > -8 then
		tr.hoverSince = tr.hoverSince or nowC
		if nowC - (tr.hoverSince :: number) > HOVER_TIME then
			tr.hoverSince = nowC
			local gap = heightAboveGround(root, p.data.scale or 1)
			local why = string.format(
				"hovering (%.1f studs up at %.0f, %.0f, %.0f, falling %.1f)",
				gap,
				root.Position.X,
				root.Position.Y,
				root.Position.Z,
				-root.AssemblyLinearVelocity.Y
			)
			strike(p, tr, root, nowC, why, true) -- unambiguous after HOVER_TIME: correct at once
			return
		end
	else
		tr.hoverSince = nil
	end
	local disp = ((root.Position - tr.pos) * Vector3.new(1, 0, 1)).Magnitude
	if disp > allowance(p, dt) then
		strike(p, tr, root, nowC, ("moved %d studs in %.2f s"):format(math.floor(disp), dt))
		return
	end
	-- Only a grounded (or legitimately airborne) spot becomes the place corrections snap back to; while airborne
	-- the reference (position and time) stays put, so the distance allowance keeps growing with the time in the air.
	if not airborne then
		tr.pos = root.Position
		tr.t = nowC
	end
end

function MovementValidator.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		for _, p in ipairs(Participants.humans()) do
			check(p)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks["P" .. tostring(player.UserId)] = nil
	end)
	if RunService:IsStudio() then
		-- tp <id> <x> <y> <z> [lookX lookZ]: a validator-approved teleport for testing (raw PivotTo calls get corrected).
		require(script.Parent.AdminService).register("tp", function(args)
			local p = Participants.get(args[1])
			local x, y, z = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
			if not p or not x or not y or not z then
				return "usage: tp <id> <x> <y> <z> [lookX lookZ]"
			end
			local pos = Vector3.new(x, y, z)
			local lx, lz = tonumber(args[5]), tonumber(args[6])
			local look = if lx and lz then Vector3.new(lx, y, lz) else pos + Vector3.new(0, 0, -1)
			Characters.pivot(p, CFrame.lookAt(pos, look))
			reset(p)
			return ("%s -> %s"):format(p.id, tostring(pos))
		end)
	end
end

return MovementValidator
