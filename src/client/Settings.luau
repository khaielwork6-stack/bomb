--!strict
-- Player settings (GDD §20.5). Local values with change signals; persisted to the profile via SaveSettings
-- once data lands (P6). Until then they last for the session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Settings = {
	Changed = Signal.new(), -- (key, value)
}

export type Values = {
	musicVolume: number, -- 0..100
	sfxVolume: number, -- 0..100
	cameraSensitivity: number, -- 0.2..2.0
	reduceMotion: boolean,
	showTips: boolean,
	crowdVisible: boolean,
	mobileButtonSize: string, -- "S" | "M" | "L"
	colourBlindOutlines: boolean,
}

local values: Values = {
	musicVolume = 70,
	sfxVolume = 90,
	cameraSensitivity = 1.0,
	reduceMotion = false,
	showTips = true,
	crowdVisible = true,
	mobileButtonSize = "M",
	colourBlindOutlines = false,
}

local LIMITS: { [string]: { number } } = {
	musicVolume = { 0, 100 },
	sfxVolume = { 0, 100 },
	cameraSensitivity = { 0.2, 2.0 },
}

function Settings.get(key: string): any
	return (values :: any)[key]
end

function Settings.all(): Values
	return table.clone(values)
end

local saveQueued = false
function Settings.set(key: string, value: any)
	local current = (values :: any)[key]
	if current == nil or type(current) ~= type(value) then
		return
	end
	local lim = LIMITS[key]
	if lim and type(value) == "number" then
		value = math.clamp(value, lim[1], lim[2])
	end
	if current == value then
		return
	end
	(values :: any)[key] = value
	Settings.Changed:Fire(key, value)
	-- Coalesce saves (sliders fire many changes).
	if not saveQueued then
		saveQueued = true
		task.delay(1.5, function()
			saveQueued = false
			Net.send("SaveSettings", Settings.all())
		end)
	end
end

-- Server pushes saved settings on join (ProfileSync, P6).
function Settings.apply(saved: { [string]: any })
	for k, v in pairs(saved) do
		local current = (values :: any)[k]
		if current ~= nil and type(current) == type(v) and current ~= v then
			(values :: any)[k] = v
			Settings.Changed:Fire(k, v)
		end
	end
end

return Settings
