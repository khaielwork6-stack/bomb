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
-- nobody to pass to) runs for the strip anyway. `speed` is its likely pace (studs/s). The Hand-Off (GDD §7.4b): a
-- body within OPPORTUNITY_RANGE is a free hand-off (one lunge away), so it's taken even when the strip is reachable,
-- as a player would.
function BombBrain.carrierChoice(
	remaining: number,
	stripDist: number,
	speed: number,
	hasTarget: boolean,
	targetDist: number?
): string
	if hasTarget and targetDist and targetDist <= BC.OPPORTUNITY_RANGE then
		return "pass"
	end
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

-- D-BOT-01: a Bomber behind a Runner (relative to the Runner's goal) doesn't tail it; it runs for a point ahead of it
-- on its way to the strip, up to `maxLead` studs, so the Runner has to turn or juke. Otherwise nil (plain pursuit).
function BombBrain.cutoff(
	targetPos: Vector3,
	goal: Vector3,
	bomberPos: Vector3,
	minDist: number,
	maxLead: number
): Vector3?
	local flat = Vector3.new(1, 0, 1)
	local toGoal = (goal - targetPos) * flat
	local toTarget = (targetPos - bomberPos) * flat
	if toGoal.Magnitude < 1e-3 or toTarget.Magnitude < minDist then
		return nil
	end
	local g = toGoal.Unit
	if toTarget:Dot(g) <= 0 then
		return nil -- already goal-side of the Runner: chase it
	end
	return targetPos + g * math.min(maxLead, toTarget.Magnitude * 0.5, toGoal.Magnitude)
end

-- Where to aim at a moving target: its position led by `lead` seconds of its velocity (flattened).
function BombBrain.intercept(targetPos: Vector3, targetVel: Vector3, lead: number): Vector3
	return targetPos + targetVel * Vector3.new(1, 0, 1) * lead
end

export type Obstacle = { pos: Vector3, r: number }

-- Steer `dir` round the map's cover (crates, hand-trucks): an obstacle on the path within `lookahead` bends the line
-- to the side it's already slipping past, harder the closer and more central it is; inside the clearance ring it
-- also pushes straight out. With nothing in the way `dir` comes back unchanged (flat, unit).
function BombBrain.avoid(
	pos: Vector3,
	dir: Vector3,
	obstacles: { Obstacle },
	clearance: number,
	lookahead: number
): Vector3
	local flat = dir * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.05 then
		return dir
	end
	local d = flat.Unit
	local out = d
	for _, o in ipairs(obstacles) do
		local to = (o.pos - pos) * Vector3.new(1, 0, 1)
		local reach = o.r + clearance
		local along = to:Dot(d)
		if along > -reach and along < lookahead + reach then
			local lateral = to - d * along -- from the path to the obstacle's centre, across the path
			local miss = lateral.Magnitude
			if miss < reach and along > 0 then
				local side = if miss > 1e-3 then -lateral.Unit else Vector3.new(-d.Z, 0, d.X)
				local w = (1 - miss / reach) * math.clamp(1 - along / (lookahead + reach), 0, 1)
				out += side * w * 2.2
			end
			local dist = to.Magnitude
			if dist > 1e-3 and dist < reach then
				out -= to.Unit * (1 - dist / reach) * 1.5
			end
		end
	end
	local m = out * Vector3.new(1, 0, 1)
	return if m.Magnitude > 1e-3 then m.Unit else d
end

-- A Runner's start delay this crossing (F-BOT-02): some go at once, some wait for a gap, none past the cap.
function BombBrain.startDelay(fuse: number, r: number): number
	if r < 0.45 then
		return 0
	end
	return (r - 0.45) / 0.55 * fuse * BC.START_DELAY_MAX
end

return BombBrain
