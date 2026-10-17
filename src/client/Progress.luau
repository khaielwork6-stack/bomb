--!strict
-- The player's progression on the client: the latest "Progress" snapshot from the server (ProgressionService +
-- DailyService sections) and a Changed signal, so the HUD, dock, quest tracker and screens all read one source.
-- Server pushes are authoritative; the client never computes rewards. `receivedAt` lets countdowns tick locally.
-- Implements: F-UI-03 (data feed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Progress = {}

local changed = Instance.new("BindableEvent")
Progress.Changed = changed.Event -- (snapshot, previous?)

local current: { [string]: any }? = nil
local receivedAt = 0
local started = false

function Progress.get(): { [string]: any }?
	return current
end

-- Seconds since the snapshot arrived (for local countdowns: gift, quest reset).
function Progress.age(): number
	return os.clock() - receivedAt
end

function Progress.start()
	if started then
		return
	end
	started = true
	Net.listen("Progress", function(s)
		if type(s) ~= "table" then
			return
		end
		local prev = current
		current = s
		receivedAt = os.clock()
		changed:Fire(s, prev)
	end)
end

-- Ask the server to do something daily (claims, rerolls, onboarding flags). The server validates everything.
function Progress.action(kind: string, extra: { [string]: any }?)
	local msg: { [string]: any } = { kind = kind }
	if extra then
		for k, v in pairs(extra) do
			msg[k] = v
		end
	end
	Net.send("DailyAction", msg)
end

return Progress
