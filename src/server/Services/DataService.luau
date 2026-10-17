--!strict
-- Player profiles (GDD §24.3): one session-locked DataStore entry per player, loaded on join, saved every
-- AUTOSAVE seconds, released on leave and on shutdown (BindToClose). The lock and schema rules are pure modules
-- (Logic/SessionLock, Logic/ProfileSchema) with specs.
-- Backend: the real DataStore, or, when Studio has no API access, an in-memory store with the same UpdateAsync
-- semantics (profiles then last only for the play session; SETUP_NOTES explains how to enable real saves).
-- Other services read and change `DataService.get(p)` directly and register a collector to copy live state into
-- the profile right before each save.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Participants = require(script.Parent.Participants)
local PlayerService = require(script.Parent.PlayerService)
local AdminService = require(script.Parent.AdminService)
local SessionLock = require(script.Parent.Parent.Logic.SessionLock)
local ProfileSchema = require(script.Parent.Parent.Logic.ProfileSchema)

type Participant = Participants.Participant

local D = Config.Data

local DataService = {
	Loaded = Signal.new(), -- (p, data)
}

type Profile = {
	key: string,
	data: { [string]: any },
	unsaved: boolean, -- true: this session can't write (load failed / lock lost); progress is session-only
	saving: boolean,
	released: boolean,
}

type Backend = { name: string, update: (key: string, transform: (any) -> any) -> () }

local profiles: { [string]: Profile } = {} -- participant id -> profile
local loading: { [string]: boolean } = {}
local collectors: { (Participant, { [string]: any }) -> () } = {}
local backend: Backend
local job = if game.JobId ~= "" then game.JobId else ("studio-" .. tostring(math.random(1, 2 ^ 30)))

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deepCopy(x)
	end
	return out
end

local function realBackend(): Backend
	local store = DataStoreService:GetDataStore(D.STORE)
	return {
		name = "DataStore",
		update = function(key, transform)
			store:UpdateAsync(key, transform)
		end,
	}
end

-- Same contract as UpdateAsync: the transform sees a copy of the stored value; returning nil cancels the write.
local function memoryBackend(): Backend
	local mem: { [string]: any } = {}
	return {
		name = "memory",
		update = function(key, transform)
			local new = transform(deepCopy(mem[key]))
			if new ~= nil then
				mem[key] = deepCopy(new)
			end
		end,
	}
end

local function pickBackend(): Backend
	if RunService:IsStudio() then
		local ok = pcall(function()
			DataStoreService:GetDataStore(D.STORE):GetAsync("__probe")
		end)
		if not ok then
			warn("[Data] Studio has no DataStore access: profiles are kept in memory for this play session only.")
			return memoryBackend()
		end
	end
	return realBackend()
end

function DataService.get(p: Participant): { [string]: any }?
	local prof = profiles[p.id]
	return prof and prof.data
end

function DataService.isLoaded(p: Participant): boolean
	return profiles[p.id] ~= nil
end

-- True when Studio has no API access and profiles live in memory (other stores should fall back too).
function DataService.usingMemory(): boolean
	return backend ~= nil and backend.name == "memory"
end

-- True if this session's progress for p will be saved.
function DataService.isSaving(p: Participant): boolean
	local prof = profiles[p.id]
	return prof ~= nil and not prof.unsaved
end

-- Wait (up to `timeout` s) for p's profile. Returns it, or nil.
function DataService.waitFor(p: Participant, timeout: number?): { [string]: any }?
	local t0 = os.clock()
	while not profiles[p.id] and os.clock() - t0 < (timeout or 20) do
		if not loading[p.id] and not Participants.get(p.id) then
			return nil
		end
		task.wait(0.2)
	end
	return DataService.get(p)
end

-- Copy live state into the profile right before every save (and at release).
function DataService.addCollector(fn: (Participant, { [string]: any }) -> ())
	table.insert(collectors, fn)
end

local function load(p: Participant)
	local player = p.player
	if not player or profiles[p.id] or loading[p.id] then
		return
	end
	loading[p.id] = true
	local key = D.KEY_PREFIX .. tostring(player.UserId)
	local data: any = nil
	local acquired = false
	for attempt = 1, D.LOAD_ATTEMPTS do
		local got, stored = false, nil
		local ok, err = pcall(backend.update, key, function(entry)
			-- Studio: a lock left by an earlier Studio play session (stopping play doesn't always get to release it)
			-- is taken over. Only one Studio test runs for you at a time; otherwise the profile loaded "unsaved" and
			-- every test purchase was refused (NotProcessedYet) — "Robux gives nothing".
			if
				RunService:IsStudio()
				and type(entry) == "table"
				and type(entry.lock) == "table"
				and type(entry.lock.job) == "string"
				and string.sub(entry.lock.job, 1, 7) == "studio-"
				and entry.lock.job ~= job
			then
				entry.lock = nil
			end
			local e, took = SessionLock.acquire(entry, job, os.time(), D.LOCK_TTL)
			got, stored = took, e and e.data
			return e
		end)
		if not Participants.get(p.id) then
			-- Left while loading: hand the lock straight back.
			if ok and got then
				pcall(backend.update, key, function(entry)
					if type(entry) == "table" and entry.lock and entry.lock.job == job then
						entry.lock = nil -- only drop our lock; the stored data is untouched
						return entry
					end
					return nil
				end)
			end
			loading[p.id] = nil
			return
		end
		if ok and got then
			acquired, data = true, stored
			break
		end
		if not ok then
			warn(`[Data] load {key} attempt {attempt} failed:`, err)
		end
		task.wait(D.RETRY_WAIT)
	end
	local profile: Profile = {
		key = key,
		data = ProfileSchema.reconcile(data),
		unsaved = not acquired,
		saving = false,
		released = false,
	}
	if not acquired then
		warn(`[Data] could not lock {key}; this session's progress won't be saved`)
	end
	local now = os.time()
	if profile.data.createdAt == 0 then
		profile.data.createdAt = now
	end
	if profile.data.firstJoin == 0 then
		profile.data.firstJoin = now
	end
	profile.data.lastJoin = now
	profiles[p.id] = profile
	loading[p.id] = nil
	DataService.Loaded:Fire(p, profile.data)
end

-- Save p's profile. `release` gives the lock back (leaving / shutdown). Saves for one profile never overlap.
function DataService.save(p: Participant, release: boolean?): boolean
	local prof = profiles[p.id]
	if not prof or prof.released then
		return false
	end
	while prof.saving do
		task.wait(0.1)
	end
	if prof.released then
		return false
	end
	if release then
		prof.released = true
	end
	if prof.unsaved then
		return false
	end
	prof.saving = true
	for _, fn in ipairs(collectors) do
		local ok, err = pcall(fn, p, prof.data)
		if not ok then
			warn("[Data] collector failed:", err)
		end
	end
	prof.data.saveCount += 1
	local snapshot = deepCopy(prof.data)
	local wrote = false
	local ok, err = pcall(backend.update, prof.key, function(entry)
		local e, w = SessionLock.write(entry, job, os.time(), D.LOCK_TTL, snapshot, release == true)
		wrote = w
		return e
	end)
	prof.saving = false
	if not ok then
		warn(`[Data] save {prof.key} failed:`, err)
		return false
	end
	if not wrote then
		-- Another server owns this profile now; never overwrite it.
		prof.unsaved = true
		warn(`[Data] lost the session lock for {prof.key}; stopped saving`)
		return false
	end
	return true
end

function DataService.init()
	backend = pickBackend()
end

function DataService.start()
	PlayerService.Joined:Connect(function(p)
		task.spawn(load, p)
	end)
	for _, p in ipairs(Participants.humans()) do
		task.spawn(load, p)
	end
	Participants.Removed:Connect(function(p)
		if p.isBot then
			return
		end
		task.spawn(function()
			DataService.save(p, true)
			profiles[p.id] = nil
		end)
	end)
	-- Autosave, staggered so a full server doesn't hit the store at once.
	task.spawn(function()
		while true do
			task.wait(D.AUTOSAVE)
			for _, p in ipairs(Participants.humans()) do
				if profiles[p.id] then
					task.spawn(DataService.save, p, false)
					task.wait(0.5)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for id, prof in pairs(profiles) do
			local p = Participants.get(id)
			if p and not prof.released then
				pending += 1
				task.spawn(function()
					DataService.save(p, true)
					pending -= 1
				end)
			end
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
	AdminService.register("data", function(args)
		-- data [id]: profile summary (Studio / admins).
		local lines = { "backend " .. backend.name .. " · job " .. job }
		for _, p in ipairs(Participants.humans()) do
			if args[1] == nil or args[1] == p.id then
				local prof = profiles[p.id]
				local d = prof and prof.data
				table.insert(
					lines,
					if d
						then ("%s Lv %d (%d xp) · %d stars · %d wins · saves %d%s"):format(
							p.id,
							d.level,
							d.xp,
							d.stars,
							d.stats.wins,
							d.saveCount,
							if prof.unsaved then " · UNSAVED" else ""
						)
						else p.id .. " (loading)"
				)
			end
		end
		return table.concat(lines, "\n")
	end)
	if RunService:IsStudio() then
		-- datareload <id>: save + release, forget, load again (a leave + rejoin without leaving).
		AdminService.register("datareload", function(args)
			local p = Participants.get(args[1])
			if not p or p.isBot then
				return "need a player id"
			end
			DataService.save(p, true)
			profiles[p.id] = nil
			load(p)
			return "reloaded " .. p.id
		end)
		-- dataset <id> <field> <number>: change a number for tests: top-level (level / xp / stars / hotStreak) or a
		-- nested number (stats.wins, daily.playSec, login.lastDay…), so a play-test's progress can be put back exactly.
		AdminService.register("dataset", function(args)
			local p = Participants.get(args[1])
			local d = p and DataService.get(p)
			local key = tostring(args[2])
			local tbl: any = d
			local stat = string.match(key, "^stats%.(.+)$")
			local daily = string.match(key, "^daily%.(.+)$")
			local login = string.match(key, "^login%.(.+)$")
			if d and stat then
				tbl, key = d.stats, stat
			elseif d and daily then
				tbl, key = d.daily, daily -- e.g. daily.playSec 1790 (a gift about to unlock)
			elseif d and login then
				tbl, key = d.login, login -- e.g. login.lastDay 0 (a fresh calendar)
			end
			if not tbl or type(tbl[key]) ~= "number" or not tonumber(args[3]) then
				return "usage: dataset <playerId> <level|xp|stars|hotStreak|stats.<n>|daily.<n>|login.<n>> <number>"
			end
			tbl[key] = tonumber(args[3])
			DataService.Loaded:Fire(p, d) -- re-apply to the live participant
			return ("%s.%s = %s"):format(p.id, tostring(args[2]), tostring(tbl[key]))
		end)
	end
end

return DataService
