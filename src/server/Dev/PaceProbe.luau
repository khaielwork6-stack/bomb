--!strict
-- Studio only: the round-pace probe (GDD §11.2 "something good is always about to happen", §25.3 QA). "pace start"
-- begins sampling every bot twice a second; "pace" reports where their time went and how each crossing played out:
--   Runners  HOT (carrying, or a Bomber / Carrier within HOT_RANGE) · RUN (on the field, nothing near) ·
--            SAFE (waiting in a Safe Strip while the crossing runs) · DOWN (ragdolled) · BETWEEN (not a live phase)
--   Bombers  HOT (a Runner within HOT_RANGE, or carrying) · HUNT (one within HUNT_RANGE) · IDLE · DOWN · BETWEEN
-- plus the longest stretch a bot went without a HOT moment, and per crossing: its length, when the first Runner
-- reached safety, how long the safe ones then waited, and how it ended. Bots only (an idle Studio tester would skew
-- it). Never runs in a live server.

local RunService = game:GetService("RunService")

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local AdminService = require(script.Parent.Parent.Services.AdminService)
local BombService = require(script.Parent.Parent.Services.BombService)
local GameState = require(script.Parent.Parent.Services.GameState)
local Participants = require(script.Parent.Parent.Services.Participants)

local R, S, Ph = Types.Role, Types.State, Types.Phase

local PaceProbe = {}

local STEP = 0.5
local HOT_RANGE = 14
local HUNT_RANGE = 35

type Tally = { [string]: number }
type Crossing = { start: number, firstSafe: number?, finish: number?, how: string?, runners: number }

local running = false
local started = 0
local tally: { Runner: Tally, Bomber: Tally } = { Runner = {}, Bomber = {} }
local phaseTime: Tally = {}
local sinceHot: { [string]: number } = {}
local longestCold: { [string]: number } = {}
local crossings: { Crossing } = {}
local current: Crossing? = nil
local rounds = 0

local function live(phase: string): boolean
	return phase == Ph.Crossing or phase == Ph.LastStand
end

local function nearest(p: Participants.Participant, pred: (Participants.Participant) -> boolean): number
	local best = math.huge
	if not p.root then
		return best
	end
	for _, o in ipairs(Participants.inMatch()) do
		if o ~= p and o.root and pred(o) then
			best = math.min(best, (o.root.Position - p.root.Position).Magnitude)
		end
	end
	return best
end

local function classify(p: Participants.Participant, phase: string): string
	if not live(phase) then
		return "BETWEEN"
	end
	if p.state == S.Downed or p.state == S.Tumbled then
		return "DOWN"
	end
	local carrying = BombService.bombOf(p) ~= nil
	if p.role == R.Runner then
		if carrying then
			return "HOT"
		end
		if p.state == S.Safe then
			return "SAFE"
		end
		local d = nearest(p, function(o)
			return (o.role == R.Bomber and o.state == S.Active) or BombService.bombOf(o) ~= nil
		end)
		return if d <= HOT_RANGE then "HOT" else "RUN"
	end
	local d = nearest(p, function(o)
		return o.role == R.Runner and o.state == S.Active
	end)
	if carrying or d <= HOT_RANGE then
		return "HOT"
	end
	return if d <= HUNT_RANGE then "HUNT" else "IDLE"
end

local function sample()
	local phase = GameState.get("Phase") or ""
	phaseTime[phase] = (phaseTime[phase] or 0) + STEP
	-- crossing bookkeeping
	if phase == Ph.Crossing and not current then
		local n = 0
		for _, p in ipairs(Participants.inMatch()) do
			if p.role == R.Runner and (p.state == S.Active or p.state == S.Safe) then
				n += 1
			end
		end
		current = { start = os.clock(), runners = n }
		table.insert(crossings, current :: Crossing)
	end
	local c = current
	if c and phase == Ph.Crossing then
		local safe, active = 0, 0
		for _, p in ipairs(Participants.inMatch()) do
			if p.role == R.Runner then
				if p.state == S.Safe then
					safe += 1
				elseif p.state == S.Active then
					active += 1
				end
			end
		end
		if safe > 0 and not c.firstSafe then
			c.firstSafe = os.clock()
		end
		c.how = if active == 0 then "all safe / out" else "fuse"
	elseif c and phase ~= Ph.Crossing then
		c.finish = os.clock()
		current = nil
	end
	if phase == Ph.Results and (phaseTime.__lastResults or 0) == 0 then
		rounds += 1
	end
	phaseTime.__lastResults = if phase == Ph.Results then 1 else 0
	for _, p in ipairs(Participants.bots()) do
		if p.role == R.Runner or p.role == R.Bomber then
			local k = classify(p, phase)
			local t = tally[p.role :: "Runner" | "Bomber"]
			t[k] = (t[k] or 0) + STEP
			if live(phase) then
				if k == "HOT" then
					sinceHot[p.id] = 0
				else
					sinceHot[p.id] = (sinceHot[p.id] or 0) + STEP
					longestCold[p.id] = math.max(longestCold[p.id] or 0, sinceHot[p.id])
				end
			end
		end
	end
end

local function pct(t: Tally): string
	local total = 0
	for _, v in pairs(t) do
		total += v
	end
	if total == 0 then
		return "-"
	end
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return t[a] > t[b]
	end)
	local parts = {}
	for _, k in ipairs(keys) do
		table.insert(parts, ("%s %.0f%%"):format(k, t[k] / total * 100))
	end
	return table.concat(parts, " · ")
end

local function report(): string
	local lines = { ("%.1f min sampled, %d rounds"):format((os.clock() - started) / 60, rounds) }
	local wall: Tally = {}
	for k, v in pairs(phaseTime) do
		if k ~= "__lastResults" then
			wall[k] = v
		end
	end
	table.insert(lines, "phases: " .. pct(wall))
	table.insert(lines, "Runners: " .. pct(tally.Runner))
	table.insert(lines, "Bombers: " .. pct(tally.Bomber))
	local sum, n, worst = 0, 0, 0
	for _, v in pairs(longestCold) do
		sum += v
		n += 1
		worst = math.max(worst, v)
	end
	table.insert(
		lines,
		("longest live stretch without a HOT moment: avg %.0f s, worst %.0f s"):format(
			if n > 0 then sum / n else 0,
			worst
		)
	)
	for i, c in ipairs(crossings) do
		if c.finish then
			local len = c.finish - c.start
			local wait = if c.firstSafe then c.finish - c.firstSafe else 0
			table.insert(
				lines,
				("crossing %d: %.1f s, %d runners, first safe at %.1f s, safe ones waited up to %.1f s, ended by %s"):format(
					i,
					len,
					c.runners,
					if c.firstSafe then c.firstSafe - c.start else -1,
					wait,
					c.how or "?"
				)
			)
		end
	end
	return table.concat(lines, "\n")
end

function PaceProbe.start()
	if not RunService:IsStudio() then
		return
	end
	AdminService.register("pace", function(args)
		if args[1] == "start" then
			tally = { Runner = {}, Bomber = {} }
			phaseTime, sinceHot, longestCold, crossings, current, rounds = {}, {}, {}, {}, nil, 0
			started = os.clock()
			if not running then
				running = true
				task.spawn(function()
					while running do
						sample()
						task.wait(STEP)
					end
				end)
			end
			return "pace probe started"
		end
		return report()
	end)
end

return PaceProbe
