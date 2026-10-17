--!strict
-- String helpers: {placeholder} substitution and timers.

local Format = {}

function Format.fill(template: string, args: { [string]: any }?): string
	if not args then
		return template
	end
	return (
		string.gsub(template, "{(%w+)}", function(key)
			local v = args[key]
			if v == nil then
				return "{" .. key .. "}"
			end
			return tostring(v)
		end)
	)
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
