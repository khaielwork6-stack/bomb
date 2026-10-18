--!strict
-- Debug switches. Only honoured in Studio (RunService:IsStudio()) or for ADMIN_IDS. GDD §23.2.

return {
	SIM_MODE = false, -- allow bot-only matches with 0 humans (Studio only)
	TIME_SCALE = 1, -- 0.25..4, multiplies all phase timers (Studio only)
	RUN_TESTS = false, -- run Tests/*.spec on server start (Studio only)
	SHOW_OVERLAY = false,
	FORCE_THEME = nil :: string?,
	FORCE_MAP = nil :: string?,
	FORCE_MODIFIER = nil :: string?,
	FORCE_HAZARD = nil :: string?,
	BOT_SEED = nil :: number?, -- pin the bot population mix order (A/B balance soaks)
	UNLOCK_ALL = false,
	RIVAL_BOTS = false, -- let bots count as rivals (Studio only; humans-only otherwise, §18.2)
	ADMIN_IDS = {} :: { number },
	VERBOSE = false,
	-- Economy soak (GDD §25.3): bots "earn" on paper through the real payout maths (callouts + rounds) so a bot-only
	-- soak prints Stars/hour (`econ start` / `econ` admin commands). Studio only.
	ECON_SIM = false,
	-- Studio only: keep profiles in memory even when Studio has DataStore access, so a play-test can buy, equip and
	-- open crates without touching the real dev profile (every play session then starts from a fresh profile).
	MEMORY_DATA = false,
}
