--!strict
-- Server side of the transferred movement (GDD §9, §23.1): the dash / slide / hard-stop / head-look remotes, lifted
-- out of Chase Game's Combat.luau. Records techniques (cooldowns, validator windows) and relays them to other
-- clients as ActionFx so PoseController can pose the move on that body. Implements: F-MOVE-01, F-MOVE-03.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local AdminService = require(script.Parent.AdminService)
local Participants = require(script.Parent.Participants)

type Participant = Participants.Participant

local R, S = Types.Role, Types.State
local M = Config.Movement

local MoveService = {
	-- (participant, kind) for every recorded technique: "Dash" | "Slide" | "HardStop" (DODGE! callout, GDD §11.1).
	Action = Signal.new(),
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function inRound(p: Participant): boolean
	return p.state == S.Active and (p.role == R.Runner or p.role == R.Bomber)
end

-- Record a technique (also used by bots, which never send remotes).
function MoveService.recordTech(p: Participant, kind: string)
	local t = now()
	p.data.lastTech = kind
	p.data.lastTechAt = t
	if kind == "Slide" then
		p.data.slideUntil = t + M.SLIDE_TIME
	end
	p.stats.acted = true
	MoveService.Action:Fire(p, kind)
end

function MoveService.start()
	Net.on("RequestDash", function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local p = Participants.fromPlayer(player)
		if not p then
			return
		end
		local t = now()
		-- One cooldown everywhere (spamming can't hold the validator's dash window open).
		if t - (p.data.lastDashAt or -math.huge) < M.DASH_CD - 0.1 then
			return
		end
		p.data.lastDashAt = t
		if inRound(p) then
			MoveService.recordTech(p, "Dash")
			local side = payload.side
			if side ~= "Left" and side ~= "Right" and side ~= "Back" then
				side = nil
			end
			Net.fireExcept(
				player,
				"ActionFx",
				{ who = p.id, kind = "Dash", pos = p.root and p.root.Position, side = side }
			)
		end
	end)
	-- Head look: the client's camera look relative to its body, relayed as a character attribute for PoseController.
	Net.on("Look", function(player, payload)
		if type(payload) ~= "table" or type(payload.y) ~= "number" or type(payload.p) ~= "number" then
			return
		end
		if payload.y ~= payload.y or payload.p ~= payload.p then
			return -- NaN
		end
		local char = player.Character
		if not char then
			return
		end
		local yaw = math.clamp(math.round(payload.y), -M.HEAD_YAW_MAX, M.HEAD_YAW_MAX)
		local pitch = math.clamp(math.round(payload.p), -M.HEAD_PITCH_DOWN, M.HEAD_PITCH_UP)
		char:SetAttribute("CG_Look", Vector2.new(yaw, pitch))
	end)
	Net.on("MovementTech", function(player, payload)
		if type(payload) ~= "table" or (payload.kind ~= "HardStop" and payload.kind ~= "Slide") then
			return
		end
		local p = Participants.fromPlayer(player)
		if not p then
			return
		end
		local t = now()
		-- The slide's burst gets a validator window anywhere, on the slide's own cooldown.
		if payload.kind == "Slide" and t - (p.data.lastSlideAt or -math.huge) >= M.SLIDE_CD - 0.1 then
			p.data.lastSlideAt = t
		end
		if not inRound(p) then
			return
		end
		local key = if payload.kind == "Slide" then "lastSlideTechAt" else "lastStopTechAt"
		local cd = if payload.kind == "Slide" then M.SLIDE_CD else M.HARDSTOP_CD
		if t - (p.data[key] or -math.huge) < cd - 0.1 then
			return
		end
		p.data[key] = t
		MoveService.recordTech(p, payload.kind)
		Net.fireExcept(player, "ActionFx", { who = p.id, kind = payload.kind, pos = p.root and p.root.Position })
	end)
	-- Studio: "tech <id> <Slide|HardStop|Dash>" records a technique for a participant (bots never send remotes).
	AdminService.register("tech", function(args)
		local p = Participants.get(args[1])
		if
			not RunService:IsStudio()
			or not p
			or (args[2] ~= "Slide" and args[2] ~= "HardStop" and args[2] ~= "Dash")
		then
			return "usage: tech <participantId> <Slide|HardStop|Dash>"
		end
		MoveService.recordTech(p, args[2])
		Net.fireAll("ActionFx", { who = p.id, kind = args[2], pos = p.root and p.root.Position })
		return p.id .. " " .. args[2]
	end)
end

return MoveService
