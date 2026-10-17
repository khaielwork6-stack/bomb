--!nocheck
-- Offline check of a clip with the real baker (Lune 0.10+):  lune run tools/anim/analyse.luau <Clip> [step]
-- Prints, every `step` frames (default 3): solved drop, highest point, torso pitch and the lowest corner of every part
-- (≈ -0.12 = touching the floor; a planted limb should stay there), then the peak joint speed and the largest
-- frame-to-frame speed change per part (a big jump = a pop). Also writes tools/anim/out/<Clip>.rbxm.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local dir = "tools/anim/"
local env = setmetatable({
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
}, { __index = _G })
local function load(file: string)
	return luau.load(fs.readFile(dir .. file), { debugName = file, environment = env })()
end

local name = process.args[1] or error("usage: lune run tools/anim/analyse.luau <Clip> [step]")
local step = tonumber(process.args[2]) or 3
local B = load("bake.luau")
local clip = load(name .. ".luau")
local curves = B.curves(clip)
local short =
	{ Torso = "T", Head = "H", ["Right Arm"] = "RA", ["Left Arm"] = "LA", ["Right Leg"] = "RL", ["Left Leg"] = "LL" }

local n = math.floor(clip.length * B.FPS + 0.5)
local prev, prevSp, peak, jump, jumpAt = nil, {}, {}, {}, {}
local topMax = { -math.huge, 0 }
local prevDrop, rise, fall = nil, { 0, 0 }, { 0, 0 }
for f = 0, n do
	local t = f / B.FPS
	local j, drop, v, cf = B.frame(clip, curves, t)
	local _, high, per = B.extent(cf, B.ALL)
	local topPart = ""
	for _, p in ipairs(B.ALL) do
		local _, h = B.extent(cf, { p })
		if h >= high - 1e-6 then
			topPart = short[p]
		end
	end
	if high > topMax[1] then
		topMax = { high, t }
	end
	if prev then
		for part, c in pairs(j) do
			local _, ang = (prev[part]:Inverse() * c):ToAxisAngle()
			local sp = math.deg(ang) * B.FPS
			peak[part] = math.max(peak[part] or 0, sp)
			if prevSp[part] and math.abs(sp - prevSp[part]) > (jump[part] or 0) then
				jump[part] = math.abs(sp - prevSp[part])
				jumpAt[part] = t
			end
			prevSp[part] = sp
		end
	end
	prev = j
	if prevDrop then
		local vy = (prevDrop - drop) * B.FPS -- studs/s, + = body rising
		if vy > rise[1] then
			rise = { vy, t }
		elseif -vy > fall[1] then
			fall = { -vy, t }
		end
	end
	prevDrop = drop
	if f % step == 0 or f == n then
		local parts = {}
		for _, p in ipairs(B.ALL) do
			table.insert(parts, ("%s%5.2f"):format(short[p], per[p]))
		end
		print(
			("%.3f drop%5.2f top%5.2f(%-2s) pitch%4d | %s"):format(
				t,
				drop,
				high,
				topPart,
				math.floor(v.pitch + 0.5),
				table.concat(parts, " ")
			)
		)
	end
end
print(("highest point %.2f at %.2f s"):format(topMax[1], topMax[2]))
print(
	("fastest body rise %.1f studs/s at %.3f s, fastest fall %.1f studs/s at %.3f s (above ~8 reads as a pop)"):format(
		rise[1],
		rise[2],
		fall[1],
		fall[2]
	)
)
for _, p in ipairs(B.ALL) do
	if peak[p] then
		print(
			("  %-10s peak %5d deg/s   max speed change %4d deg/s per frame @%.3f"):format(
				p,
				peak[p],
				jump[p] or 0,
				jumpAt[p] or 0
			)
		)
	end
end

fs.writeDir(dir .. "out")
fs.writeFile(dir .. "out/" .. name .. ".rbxm", roblox.serializeModel({ B.bake(clip) }))
