-- Titan hammer plant solver:  lune run tools/anim/titansolve.luau <Clip> <from> <to> <dt> [target studs]
-- For each time in [from, to], finds the rArm (world swing) that puts the hammer head's lowest point at `target`
-- studs (default -0.45, the same tiny sink as the feet) with everything else as the clip has it. Prints track points.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local env = setmetatable(
	{ CFrame = roblox.CFrame, Vector3 = Vector3, Enum = roblox.Enum, Instance = roblox.Instance },
	{ __index = _G }
)
local function load(file)
	return luau.load(fs.readFile("tools/anim/" .. file), { debugName = file, environment = env })()
end
local B = load("bake.luau")
local clip = load(process.args[1] .. ".luau")
local from, to, dt = tonumber(process.args[2]), tonumber(process.args[3]), tonumber(process.args[4])
local target = (tonumber(process.args[5]) or -0.45) / 4
local HC = Vector3.new(0.35, -1.883, -2.2875)
local HX = Vector3.new(0.1134, 0.9326, -0.3426)
local HY = Vector3.new(-0.9835, 0.0563, -0.1722)
local HZ = Vector3.new(0.1413, -0.3565, -0.9235)
local curves = B.curves(clip)
local base = curves.rArm
local function lowAt(t, r)
	curves.rArm = function()
		return r
	end
	local _, _, _, cf = B.frame(clip, curves, t)
	curves.rArm = base
	local arm = cf["Right Arm"]
	local low = math.huge
	for _, sx in ipairs({ -1.05, 1.05 }) do
		for _, sy in ipairs({ -0.6, 0.6 }) do
			for _, sz in ipairs({ -0.6, 0.6 }) do
				low = math.min(low, (arm * (HC + HX * sx + HY * sy + HZ * sz)).Y)
			end
		end
	end
	return low
end
local out = {}
local t = from
while t <= to + 1e-6 do
	-- scan for the bracket, then bisect (height rises with rArm over the useful range)
	local lo, hi = -40, 90
	local flo, fhi = lowAt(t, lo) - target, lowAt(t, hi) - target
	if flo * fhi > 0 then
		table.insert(out, ("-- t=%.2f no solution (lo %.2f hi %.2f)"):format(t, flo * 4, fhi * 4))
	else
		for _ = 1, 30 do
			local mid = (lo + hi) / 2
			local fm = lowAt(t, mid) - target
			if (fm > 0) == (fhi > 0) then
				hi, fhi = mid, fm
			else
				lo, flo = mid, fm
			end
		end
		table.insert(out, ("{ %.2f, %.1f },"):format(t, (lo + hi) / 2))
	end
	t += dt
end
print(table.concat(out, " "))
