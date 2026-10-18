--!strict
-- The moment system (GDD §10.5): PositionHistory is the 6-second highlight buffer. When a top-tier moment happens — a
-- Clutch Defuse, a 4+ Chain (CalloutService.Fired) or a Last Stand finish (RoundService) — it's flagged and its 4 s
-- of every nearby participant (bots included) are cut from the buffer. At RESULTS, RoundService sends the best
-- moment of the round with the results (Net "RoundFx" Results → `moment`); MomentController replays it.
-- Implements: F-FEEL-06.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local AdminService = require(script.Parent.AdminService)
local CalloutService = require(script.Parent.CalloutService)
local Participants = require(script.Parent.Participants)
local PositionHistory = require(script.Parent.PositionHistory)

type Participant = Participants.Participant
type Sample = PositionHistory.Sample

-- One participant's track: positions, facings (yaw, radians) and flags (FLAG_BOMB | FLAG_TUMBLED) per frame.
export type Actor = { id: string, pos: { Vector3 }, yaw: { number }, flags: { number } }
export type Moment = {
	kind: string, -- "ClutchDefuse" | "Chain" | "LastStandWin" | "LastStand"
	id: string, -- the featured participant
	name: string,
	n: number?, -- the Chain's length
	at: number, -- server time of the moment itself
	t0: number, -- server time of the replay's first frame
	hz: number,
	actors: { Actor },
}

type Flagged = { kind: string, p: Participant, n: number?, at: number, score: number, moment: Moment? }

local F = Config.Feel
local FLAG_BOMB, FLAG_TUMBLED = 1, 2

local MomentService = {}

local flagged: { Flagged } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- One track resampled at `hz` from t0 (clamped to the samples it has).
local function resample(samples: { Sample }, t0: number, hz: number, frames: number): Actor?
	if #samples == 0 then
		return nil
	end
	local pos, yaw, flags = table.create(frames), table.create(frames), table.create(frames)
	local j = 1
	for i = 1, frames do
		local t = t0 + (i - 1) / hz
		while j < #samples and samples[j + 1].t <= t do
			j += 1
		end
		local a = samples[j]
		local b = samples[math.min(j + 1, #samples)]
		local span = b.t - a.t
		local k = if span > 0 then math.clamp((t - a.t) / span, 0, 1) else 0
		local s = if k < 0.5 then a else b
		local look = s.look
		pos[i] = a.pos:Lerp(b.pos, k)
		yaw[i] = math.atan2(-look.X, -look.Z)
		flags[i] = (if s.bomb then FLAG_BOMB else 0) + (if s.state == Types.State.Tumbled then FLAG_TUMBLED else 0)
	end
	return { id = "", pos = pos, yaw = yaw, flags = flags }
end

-- Cut the moment's replay out of the highlight buffer (ending MOMENT_AFTER past it, or now if that's still to come).
local function capture(f: Flagged): Moment
	local hz = F.MOMENT_HZ
	local t1 = math.min(f.at + F.MOMENT_AFTER, now())
	local t0 = t1 - F.MOMENT_REPLAY
	local frames = math.floor(F.MOMENT_REPLAY * hz) + 1
	local centre = PositionHistory.at(f.p, f.at)
	local near = {}
	for _, p in ipairs(Participants.all()) do
		local here = PositionHistory.at(p, f.at)
		if p == f.p or (centre and here and (here - centre).Magnitude <= F.MOMENT_RADIUS) then
			table.insert(
				near,
				{ p = p, d = if p == f.p or not centre or not here then -1 else (here - centre).Magnitude }
			)
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local actors = {}
	for _, e in ipairs(near) do
		if #actors >= F.MOMENT_MAX_ACTORS then
			break
		end
		local track = resample(PositionHistory.since(e.p, t0 - 1 / hz), t0, hz, frames)
		if track then
			track.id = e.p.id
			table.insert(actors, track)
		end
	end
	return {
		kind = f.kind,
		id = f.p.id,
		name = f.p.name,
		n = f.n,
		at = f.at,
		t0 = t0,
		hz = hz,
		actors = actors,
	}
end

local function flag(kind: string, p: Participant, n: number?)
	local t = now()
	-- A Chain calls every Carrier at once: one moment, featuring the last one called.
	local last = flagged[#flagged]
	if last and last.kind == kind and kind == "Chain" and last.n == n and t - last.at < 0.1 then
		last.p = p
		return
	end
	local score = F.MOMENT_SCORE[kind] or 0
	if kind == "Chain" then
		score += (n or 0) * F.MOMENT_CHAIN_LINK
	end
	local f: Flagged = { kind = kind, p = p, n = n, at = t, score = score, moment = nil }
	table.insert(flagged, f)
	-- the replay includes the reaction: cut it once that has happened (the buffer still holds the build-up)
	task.delay(F.MOMENT_AFTER, function()
		if table.find(flagged, f) and not f.moment then
			f.moment = capture(f)
		end
	end)
end

-- RoundService: a new round — forget the last one's moments.
function MomentService.reset()
	table.clear(flagged)
end

-- RoundService: the Last Stand is over (`won` = its Runner made it across).
function MomentService.lastStandEnded(runner: Participant, won: boolean)
	flag(if won then "LastStandWin" else "LastStand", runner)
end

-- RoundService, at RESULTS: the best moment of the round (nil if none was top-tier).
function MomentService.best(): Moment?
	local best: Flagged? = nil
	for _, f in ipairs(flagged) do
		if best == nil or f.score >= best.score then
			best = f
		end
	end
	if not best then
		return nil
	end
	if not best.moment then
		best.moment = capture(best)
	end
	return best.moment
end

function MomentService.start()
	CalloutService.Fired:Connect(function(p: Participant, key: string, n: number?)
		if key == "ClutchDefuse" then
			flag("ClutchDefuse", p)
		elseif key == "Chain" and (n or 0) >= F.MOMENT_CHAIN_MIN then
			flag("Chain", p, n)
		end
	end)
	-- Studio: `moment <kind> [participantId]` flags a moment now (try the card without waiting for a clutch);
	-- `moments` lists this round's.
	AdminService.register("moment", function(args)
		local kind = args[1] or "ClutchDefuse"
		local p = Participants.get(args[2] or "") or Participants.all()[1]
		if not RunService:IsStudio() or not p or F.MOMENT_SCORE[kind] == nil then
			return "usage: moment <ClutchDefuse|Chain|LastStandWin|LastStand> [participantId]"
		end
		flag(kind, p, if kind == "Chain" then F.MOMENT_CHAIN_MIN else nil)
		return `flagged {kind} for {p.id}`
	end)
	AdminService.register("moments", function()
		local out = {}
		for _, f in ipairs(flagged) do
			table.insert(out, `{f.kind}:{f.p.id}:{f.score}`)
		end
		return if #out > 0 then table.concat(out, " ") else "no moments this round"
	end)
end

return MomentService
