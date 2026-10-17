--!strict
-- Player data (GDD §24.3). Profiles are session-locked DataStore entries.

return {
	STORE = "FV_Profiles_v1", -- FUSE VALLEY's own store (the transferred schema's test saves stay in Profiles_v1)
	KEY_PREFIX = "u_",
	LOCK_TTL = 300, -- seconds; a lock left by a crashed server expires after this
	AUTOSAVE = 60, -- seconds between background saves
	LOAD_ATTEMPTS = 6, -- tries while another server still holds a fresh lock
	RETRY_WAIT = 3, -- seconds between tries
	RECEIPT_HISTORY = 200, -- purchase ids kept for idempotent ProcessReceipt (§24.3)
}
