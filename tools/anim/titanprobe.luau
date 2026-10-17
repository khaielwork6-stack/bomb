-- Titan frame checker (TITAN HUNT boss):  lune run tools/anim/titanprobe.luau <Clip> [step] [from] [to]
-- Per frame (studs at the Titan's 4x scale): hammer head lowest point (0 = touching the floor), weak-spot crystal
-- height, lowest foot, torso pitch. Then: hammer below the floor (penetration), crystal min height, pops.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local env = setmetatable(
	{ CFrame = CFrame, Vector3 = Vector3, Enum = roblox.Enum, Instance = roblox.Instance },
	{ __index = _G }
)
local function load(file)
	return luau.load(fs.readFile("tools/anim/" .. file), { debugName = file, environment = env })()
end
local B = load("bake.luau")
local clip = load(process.args[1] .. ".luau")
local step = tonumber(process.args[2]) or 3
local from = tonumber(process.args[3]) or 0
local to = tonumber(process.args[4]) or clip.length
local S = 4
-- Hammer head box in Right Arm space (unscaled), measured in Studio.
local HC = Vector3.new(0.35, -1.883, -2.2875)
local HX = Vector3.new(0.1134, 0.9326, -0.3426) -- long axis (striking faces at the ends)
local HY = Vector3.new(-0.9835, 0.0563, -0.1722)
local HZ = Vector3.new(0.1413, -0.3565, -0.9235) -- along the handle
local CRYSTAL = Vector3.new(0, -0.42, 0.76) -- torso space (lower back)
local curves = B.curves(clip)
local n = math.floor(clip.length * B.FPS + 0.5)
local minHammer, minHammerT, minCrystal, minCrystalT = math.huge, 0, math.huge, 0
local prevHead
local maxHeadSpeed, maxHeadSpeedT = 0, 0
for f = 0, n do
	local t = f / B.FPS
	local _, drop, v, cf = B.frame(clip, curves, t)
	local arm = cf["Right Arm"]
	local low = math.huge
	for _, sx in ipairs({ -1.05, 1.05 }) do
		for _, sy in ipairs({ -0.6, 0.6 }) do
			for _, sz in ipairs({ -0.6, 0.6 }) do
				local p = arm * (HC + HX * sx + HY * sy + HZ * sz)
				low = math.min(low, p.Y)
			end
		end
	end
	local head = arm * HC
	if prevHead then
		local sp = (head - prevHead).Magnitude * B.FPS * S
		if sp > maxHeadSpeed then
			maxHeadSpeed, maxHeadSpeedT = sp, t
		end
	end
	prevHead = head
	local crystal = (cf.Torso * CRYSTAL).Y
	local _, _, per = B.extent(cf, { "Right Leg", "Left Leg" })
	local foot = math.min(per["Right Leg"], per["Left Leg"])
	if low < minHammer then
		minHammer, minHammerT = low, t
	end
	if crystal < minCrystal then
		minCrystal, minCrystalT = crystal, t
	end
	if f % step == 0 and t >= from - 1e-6 and t <= to + 1e-6 then
		print(
			("%.3f  hammer %6.2f  crystal %5.2f  foot %5.2f  RL %5.2f LL %5.2f  pitch %5.1f  rArm %6.1f"):format(
				t,
				low * S,
				crystal * S,
				foot * S,
				per["Right Leg"] * S,
				per["Left Leg"] * S,
				v.pitch,
				v.rArm
			)
		)
	end
end
print(("hammer lowest %.2f studs at %.3f s (below about -0.5 = buried in the floor)"):format(minHammer * S, minHammerT))
print(("crystal lowest %.2f studs at %.3f s"):format(minCrystal * S, minCrystalT))
print(("hammer head fastest %.0f studs/s at %.3f s"):format(maxHeadSpeed, maxHeadSpeedT))
