--!strict
-- Tagged logging. Errors and warnings always print; info only when Debug.VERBOSE.

local Debug = require(script.Parent.Parent.Config.Debug)

local Log = {}

function Log.info(tag: string, ...: any)
	if Debug.VERBOSE then
		print(`[{tag}]`, ...)
	end
end

function Log.warn(tag: string, ...: any)
	warn(`[{tag}]`, ...)
end

function Log.error(tag: string, ...: any)
	warn(`[{tag}] ERROR`, ...)
end

return Log
