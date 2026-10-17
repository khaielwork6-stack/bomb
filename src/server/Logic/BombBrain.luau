--!strict
-- Bot decision rules as pure functions (GDD §18.2). BotService gathers what a bot can see and steers by the answers;
-- the specs in Tests/BombBrain.spec cover the choices that matter most (defuse vs pass, threat avoidance, targets).
-- Field-local coordinates as Arena.toLocal: x lateral, z along the field (side +1 at z = +halfLen).
-- Implements: F-BOT-02 (Runner lanes + threats), F-BOT-03 (Carrier: defuse or pass), F-BOT-04 (Bomber targets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BC = Config.Bots

local BombBrain = {}

-- Studs from local z to inside the Safe Strip on `side` (0 when already in it).
function BombBrain.stripDistance(z: number, side: number, halfLen: number): number
	return math.max(0, halfLen - z * side + 0.5)
end

-- The nearer Safe Strip and the distance to it (either strip defuses, GDD §7.6).
function BombBrain.nearestStrip(z: number, halfLen: number): (number, number)
	local dPos = BombBrain.stripDistance(z, 1, halfLen)
	local dNeg = BombBrain.stripDistance(z, -1, halfLen)
	if dPos <= dNeg then
		return 1, dPos
	end
	return -1, dNeg
end

-- F-BOT-03: a Carrier runs for the strip only when it can make it with margin; otherwise it passes, or (with
-- nobody to pass to) runs for the strip anyway. `speed` is its likely pace (studs/s).
function BombBrain.carrierChoice(remaining: number, stripDist: number, speed: number, hasTarget: boolean): string
	local timeToStrip = stripDist / math.max(speed, 1)
	if timeToStrip + BC.DEFUSE_MARGIN <= remaining then
		return "defuse"
	end
	if hasTarget then
		return "pass"
	end
	return "defuse"
end

-- A push away from every threat within `radius`, stronger the closer it is (unit-ish; zero when nothing's near).
function BombBrain.threatPush(selfPos: Vector3, threats: { Vector3 }, radius: number): Vector3
	local push = Vector3.zero
	for _, t in ipairs(threats) do
		local d = (selfPos - t) * Vector3.new(1, 0, 1)
		local m = d.Magnitude
		if m > 1e-3 and m < radius then
			push += d.Unit * ((radius - m) / radius) ^ 1.5
		end
	end
	return push
end

-- F-BOT-04: lower = a better target. Distance, plus a penalty per other Bomber already on it.
function BombBrain.targetScore(dist: number, othersChasing: number): number
	return dist + othersChasing * BC.SHARE_PENALTY
end

-- Where to aim at a moving target: its position led by `lead` seconds of its velocity (flattened).
function BombBrain.intercept(targetPos: Vector3, targetVel: Vector3, lead: number): Vector3
	return targetPos + targetVel * Vector3.new(1, 0, 1) * lead
end

-- A Runner's start delay this crossing (F-BOT-02): some go at once, some wait for a gap, none past the cap.
function BombBrain.startDelay(fuse: number, r: number): number
	if r < 0.45 then
		return 0
	end
	return (r - 0.45) / 0.55 * fuse * BC.START_DELAY_MAX
end

return BombBrain
