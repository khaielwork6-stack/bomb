--!strict
-- What a player has unlocked so far (Config.Onboarding): the dock and side tiles arrive a few at a time over the first
-- rounds instead of all at once. `has(name)` answers now; `Unlocked` fires once for each tile the moment its round
-- count is reached, so the tile can spring in.
-- Implements: F-ONB-01, DECISIONS 2026-10-19.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progress = require(script.Parent.Parent.Progress)

local O = Config.Onboarding

local Unlocks = {}

local event = Instance.new("BindableEvent")
Unlocks.Unlocked = event.Event -- (name)

local function rounds(): number?
	local s = Progress.get()
	return if s and type(s.rounds) == "number" then s.rounds else nil
end

-- Lifetime rounds played (0 before the profile arrives).
function Unlocks.rounds(): number
	return rounds() or 0
end

function Unlocks.has(name: string): boolean
	local need = O.UNLOCK_AFTER[name]
	if need == nil or need <= 0 then
		return true
	end
	local r = rounds()
	return r ~= nil and r >= need
end

local seen: { [string]: boolean } = {}
local started = false
function Unlocks.start()
	if started then
		return
	end
	started = true
	Progress.start()
	local function check(initial: boolean)
		for name in pairs(O.UNLOCK_AFTER) do
			if not seen[name] and Unlocks.has(name) then
				seen[name] = true
				if not initial then
					event:Fire(name)
				end
			end
		end
	end
	local first = true
	Progress.Changed:Connect(function()
		check(first)
		first = false
	end)
	if Progress.get() then
		check(true)
		first = false
	end
end

return Unlocks
