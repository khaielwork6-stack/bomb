--!strict
-- Global leaderboards (GDD §15.2): Wins, Clutch Defuses and Booms, weekly (Monday 00:00 UTC) and all-time, in
-- OrderedDataStores. A human's values are written after their rounds (throttled) and when they leave; weekly
-- values are lifetime stats minus the profile's base at the week's start. LeaderboardService.top() serves the
-- lobby boards (P6) and the weekly statues. The in-server boards are ProgressionService's leaderstats.
-- Implements: F-SOC-02 (data).

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local Daily = require(ServerScriptService.Server.Logic.Daily)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local Participants = require(script.Parent.Participants)
local ProgressionService = require(script.Parent.ProgressionService)

type Participant = Participants.Participant

local LeaderboardService = {}

-- board -> lifetime stat
local BOARDS = { Wins = "wins", Clutches = "clutches", Booms = "booms" }
local WRITE_EVERY = 60 -- seconds between a player's writes (DataStore budget)

local lastWrite: { [string]: number } = {}
local stores: { [string]: OrderedDataStore } = {}

-- The week number: weeks start on Monday 00:00 UTC (day 0 of the epoch was a Thursday).
function LeaderboardService.week(t: number?): number
	return (Daily.dayOf(t or os.time()) + 3) // 7
end

local function store(board: string, scope: string): OrderedDataStore?
	if DataService.usingMemory() then
		return nil -- Studio without API access: nothing to write to
	end
	local name = ("FV_LB_%s_%s"):format(board, scope)
	if not stores[name] then
		local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		if not ok then
			return nil
		end
		stores[name] = s
	end
	return stores[name]
end

-- Start a new week's base for this profile if the week changed.
local function rollWeek(d: { [string]: any })
	local w = LeaderboardService.week()
	if d.weekly.week ~= w then
		d.weekly.week = w
		local base = {}
		for _, stat in pairs(BOARDS) do
			base[stat] = d.stats[stat]
		end
		d.weekly.base = base
	end
end

local function write(p: Participant, force: boolean?)
	local d = DataService.get(p)
	local player = p.player
	if not d or not player or not DataService.isSaving(p) then
		return
	end
	local t = os.clock()
	if not force and lastWrite[p.id] and t - lastWrite[p.id] < WRITE_EVERY then
		return
	end
	lastWrite[p.id] = t
	rollWeek(d)
	local key = tostring(player.UserId)
	local week = "W" .. tostring(d.weekly.week)
	for board, stat in pairs(BOARDS) do
		local all = d.stats[stat]
		local weekly = all - (d.weekly.base[stat] or all)
		for scope, value in pairs({ All = all, [week] = weekly }) do
			local s = store(board, scope)
			if s and value > 0 then
				task.spawn(function()
					local ok, err = pcall(s.SetAsync, s, key, value)
					if not ok then
						warn("[Leaderboard] write failed:", board, scope, err)
					end
				end)
			end
		end
	end
end

-- The top `n` of a board: scope "All" or "Week" (this week). Returns { { userId, value } } best first.
function LeaderboardService.top(board: string, scope: string, n: number): { { userId: number, value: number } }
	local name = if scope == "Week" then "W" .. tostring(LeaderboardService.week()) else "All"
	local s = store(board, name)
	local out = {}
	if not s then
		return out
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, math.clamp(n, 1, 100))
	if ok and pages then
		for _, entry in ipairs((pages :: DataStorePages):GetCurrentPage()) do
			table.insert(out, { userId = tonumber(entry.key) or 0, value = entry.value })
		end
	end
	return out
end

function LeaderboardService.start()
	DataService.Loaded:Connect(function(_p: Participant, d: { [string]: any })
		rollWeek(d)
	end)
	ProgressionService.RoundPaid:Connect(function(p: Participant)
		write(p)
	end)
	Participants.Removed:Connect(function(p: Participant)
		if not p.isBot then
			write(p, true)
		end
		lastWrite[p.id] = nil
	end)
	AdminService.register("top", function(args)
		-- top <Wins|Clutches|Booms> <All|Week>: read a board
		local list = LeaderboardService.top(args[1] or "Wins", args[2] or "All", 10)
		local out = {}
		for i, e in ipairs(list) do
			table.insert(out, ("%d. %d = %d"):format(i, e.userId, e.value))
		end
		return if #out > 0 then table.concat(out, "\n") else "(empty)"
	end)
end

return LeaderboardService
