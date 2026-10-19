--!strict
-- The thrown bomb's flight (GDD §7.4c THROW MODE): one physics for the server's authority, every client's drawing, the
-- thrower's aim preview and the bots' aim, so all of them see the same arc. Pure: the caller passes the raycast.
-- Implements: F-THROW-02 (flight, bounces, landing), F-THROW-03 (the body hit test), F-THROW-07 / -08 (the aim solve).

local Config = require(script.Parent.Config)

local T = Config.Throw
local FLAT = Vector3.new(1, 0, 1)

local ThrowPhysics = {}

export type State = {
	pos: Vector3,
	vel: Vector3,
	bounces: number,
	rest: boolean, -- it has landed (too slow after a bounce, or out of bounces)
}

-- A raycast: the first surface between two points (its position and normal), or nil.
export type Cast = (from: Vector3, to: Vector3) -> (Vector3?, Vector3?)

local function flatUnit(v: Vector3): Vector3
	local f = v * FLAT
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- The launch velocity for an aim (only its flat direction counts) and a power 0..1.
function ThrowPhysics.launch(aim: Vector3, power: number): Vector3
	local p = math.clamp(power, 0, 1)
	local speed = T.SPEED_MIN + (T.SPEED_MAX - T.SPEED_MIN) * p
	local lift = T.LIFT_MIN + (T.LIFT_MAX - T.LIFT_MIN) * p
	return flatUnit(aim) * speed + Vector3.new(0, lift, 0)
end

function ThrowPhysics.new(pos: Vector3, vel: Vector3): State
	return { pos = pos, vel = vel, bounces = 0, rest = false }
end

-- Advance `dt` seconds. Returns true when it bounced this step (state is updated in place).
function ThrowPhysics.step(s: State, dt: number, cast: Cast): boolean
	if s.rest then
		return false
	end
	local v = s.vel + Vector3.new(0, -T.GRAVITY * dt, 0)
	local move = (s.vel + v) * 0.5 * dt
	local to = s.pos + move
	local reach = if move.Magnitude > 1e-4 then to + move.Unit * T.RADIUS else to
	local hit, n = cast(s.pos, reach)
	if hit and n then
		local into = v:Dot(n)
		if into < 0 then
			local normal = n * into
			local tangent = v - normal
			v = tangent * T.FRICTION - normal * T.RESTITUTION
		end
		s.pos = hit + n * T.RADIUS
		s.vel = v
		s.bounces += 1
		if v.Magnitude < T.REST_SPEED or s.bounces > T.MAX_BOUNCES then
			s.rest = true
		end
		return true
	end
	s.pos = to
	s.vel = v
	return false
end

-- Does the flight segment a → b pass through a body standing at `root` (a vertical axis from BODY_LOW under it to
-- `high` over it)? `extra` widens the body (the MEGA giant's reach).
function ThrowPhysics.hitsBody(a: Vector3, b: Vector3, root: Vector3, high: number, extra: number?): boolean
	local r = T.HIT_RADIUS + (extra or 0)
	for _, k in ipairs({ 0, 0.5, 1 }) do
		local p = a:Lerp(b, k)
		if
			((p - root) * FLAT).Magnitude <= r
			and p.Y >= root.Y - T.BODY_LOW - T.RADIUS
			and p.Y <= root.Y + high + T.RADIUS
		then
			return true
		end
	end
	return false
end

-- The closest the segment a → b comes to a body's axis, flat (for DODGE! near misses).
function ThrowPhysics.flatDistance(a: Vector3, b: Vector3, root: Vector3): number
	local best = math.huge
	for _, k in ipairs({ 0, 0.5, 1 }) do
		best = math.min(best, ((a:Lerp(b, k) - root) * FLAT).Magnitude)
	end
	return best
end

-- The aim preview: the points the bomb will pass through (fixed steps), up to its first landing or `seconds`.
function ThrowPhysics.predict(origin: Vector3, vel: Vector3, cast: Cast, seconds: number, n: number): { Vector3 }
	local s = ThrowPhysics.new(origin, vel)
	local out = { origin }
	local dt = seconds / n
	for _ = 1, n do
		local bounced = ThrowPhysics.step(s, dt, cast)
		table.insert(out, s.pos)
		if bounced or s.rest then
			break -- the first landing ends the preview (that's where it comes down)
		end
	end
	return out
end

-- Flight time from `y0` to come down to `y1` with an initial lift (nil if it never gets there).
local function fallTime(y0: number, y1: number, lift: number): number?
	local disc = lift * lift + 2 * T.GRAVITY * (y0 - y1)
	if disc < 0 then
		return nil
	end
	return (lift + math.sqrt(disc)) / T.GRAVITY
end

-- The aim that hits a body at `target` moving at `vel` from `origin`: the flat aim (led), the power, the flight time.
-- `power` fixes the power (a charged throw) and only the lead is solved; otherwise the best power for the distance is
-- picked. Nil when it's out of range.
function ThrowPhysics.solve(
	origin: Vector3,
	target: Vector3,
	vel: Vector3,
	power: number?
): (Vector3?, number?, number?)
	local aimAt = target
	local bestP, bestT = nil, nil
	for _ = 1, 3 do -- lead → the flight time → lead again
		local dist = ((aimAt - origin) * FLAT).Magnitude
		local chosenP, chosenT, err = nil, nil, math.huge
		local steps = if power then 0 else 20
		for i = 0, steps do
			local p = power or i / steps
			local speed = T.SPEED_MIN + (T.SPEED_MAX - T.SPEED_MIN) * p
			local lift = T.LIFT_MIN + (T.LIFT_MAX - T.LIFT_MIN) * p
			-- it hits on its way down through the body's middle; the flat distance it covers by then
			local tFall = fallTime(origin.Y, aimAt.Y, lift)
			if tFall then
				local e = math.abs(speed * tFall - dist)
				if e < err then
					chosenP, chosenT, err = p, tFall, e
				end
			end
		end
		if not chosenP or not chosenT then
			return nil, nil, nil
		end
		bestP, bestT = chosenP, chosenT
		aimAt = target + vel * FLAT * chosenT
	end
	local reach = ((aimAt - origin) * FLAT).Magnitude
	if not bestP or not bestT or reach > T.MAX_RANGE then
		return nil, nil, nil
	end
	-- a charged throw that falls short or long still goes where it's aimed (the player's power is the skill)
	return flatUnit(aimAt - origin), bestP, bestT
end

return ThrowPhysics
