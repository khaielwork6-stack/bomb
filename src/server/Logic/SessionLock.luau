--!strict
-- Session locking for profile entries (GDD §22.4), as pure UpdateAsync transforms.
-- A stored entry is { data = <profile>?, lock = { job = string, at = number }? }. A server may load a profile only
-- if nobody else holds a fresh lock (younger than ttl); a save only lands while we still hold the lock, so a
-- server that lost its lock can never overwrite newer data from the server that took over.

export type Lock = { job: string, at: number }
export type Entry = { data: any?, lock: Lock? }

local SessionLock = {}

local function held(entry: Entry?, job: string, now: number, ttl: number): boolean
	local lock = entry and entry.lock
	return lock ~= nil and lock.job ~= job and now - lock.at < ttl
end

-- Load: take the lock. Returns (newEntry, acquired). newEntry is nil when the write must be cancelled
-- (someone else holds a fresh lock).
function SessionLock.acquire(entry: Entry?, job: string, now: number, ttl: number): (Entry?, boolean)
	if held(entry, job, now, ttl) then
		return nil, false
	end
	local e: Entry = { data = entry and entry.data, lock = { job = job, at = now } }
	return e, true
end

-- Save: write data (and keep or release the lock). Returns (newEntry, ok). ok is false, and the write is
-- cancelled, when another server holds a fresh lock: our session is over and our copy is stale.
function SessionLock.write(
	entry: Entry?,
	job: string,
	now: number,
	ttl: number,
	data: any,
	release: boolean
): (Entry?, boolean)
	if held(entry, job, now, ttl) then
		return nil, false
	end
	local lock = entry and entry.lock
	if lock and lock.job ~= job then
		-- Their lock expired and nobody refreshed it; ours had lapsed too. Only write if the stored data isn't newer
		-- than ours (a later session's data carries a higher saveCount).
		local theirs = entry and entry.data
		if type(theirs) == "table" and type(data) == "table" and (theirs.saveCount or 0) > (data.saveCount or 0) then
			return nil, false
		end
	end
	local e: Entry = { data = data, lock = if release then nil else { job = job, at = now } }
	return e, true
end

return SessionLock
