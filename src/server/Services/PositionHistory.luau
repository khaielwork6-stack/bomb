--!strict
-- Ring buffer (Config.Movement.HISTORY_HZ, HISTORY_SECONDS) of every participant's position, facing, state, role and
-- whether they carry a bomb: lag-tolerant contact checks (GDD §24.1) and the moment system's highlight buffer
-- (MomentService, GDD §10.5).
-- Implements: F-FEEL-06 (the highlight buffer).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Participants = require(script.Parent.Participants)

export type Sample = { t: number, pos: Vector3, look: Vector3, state: string, role: string, bomb: boolean }

local C = Config.Movement
local CAP = math.ceil(C.HISTORY_HZ * C.HISTORY_SECONDS) + 2

local PositionHistory = {}

local buffers: { [string]: { samples: { Sample }, head: number, count: number } } = {}

local function record(now: number)
	for _, p in ipairs(Participants.all()) do
		local root = p.root
		if root and root.Parent then
			local b = buffers[p.id]
			if not b then
				b = { samples = table.create(CAP), head = 0, count = 0 }
				buffers[p.id] = b
			end
			b.head = (b.head % CAP) + 1
			b.samples[b.head] = {
				t = now,
				pos = root.Position,
				look = root.CFrame.LookVector,
				state = p.state,
				role = p.role,
				bomb = p.attrs:GetAttribute("BombId") ~= nil,
			}
			b.count = math.min(b.count + 1, CAP)
		end
	end
end

function PositionHistory.start()
	local acc = 0
	local step = 1 / C.HISTORY_HZ
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= step then
			acc %= step
			record(workspace:GetServerTimeNow())
		end
	end)
	Participants.Removed:Connect(function(p)
		buffers[p.id] = nil
	end)
end

-- Interpolated position at server time `t` (clamped to the buffer). Falls back to the live root.
function PositionHistory.at(p: Participants.Participant, t: number): Vector3?
	local b = buffers[p.id]
	if not b or b.count == 0 then
		return p.root and p.root.Position or nil
	end
	local newest = b.samples[b.head]
	if t >= newest.t then
		return p.root and p.root.Position or newest.pos
	end
	local idx = b.head
	for _ = 1, b.count - 1 do
		local prevIdx = if idx == 1 then CAP else idx - 1
		local cur, prev = b.samples[idx], b.samples[prevIdx]
		if not prev then
			break
		end
		if t >= prev.t then
			local span = cur.t - prev.t
			local a = if span > 0 then (t - prev.t) / span else 1
			return prev.pos:Lerp(cur.pos, a)
		end
		idx = prevIdx
	end
	return b.samples[idx].pos
end

-- All samples newer than `since` (oldest first), for replays.
function PositionHistory.since(p: Participants.Participant, since: number): { Sample }
	local b = buffers[p.id]
	local out = {}
	if not b then
		return out
	end
	local idx = b.head
	for _ = 1, b.count do
		local s = b.samples[idx]
		if s and s.t >= since then
			table.insert(out, 1, s)
		else
			break
		end
		idx = if idx == 1 then CAP else idx - 1
	end
	return out
end

function PositionHistory.clear(p: Participants.Participant)
	buffers[p.id] = nil
end

return PositionHistory
