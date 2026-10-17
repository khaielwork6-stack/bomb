--!strict
-- Pure momentum movement math shared by human clients and server bots, so physics are identical.
-- Implements: F-MOVE-03 (locomotion), F-MOVE-04 (dash), F-MOVE-05 (hard stop + juke window), F-MOVE-06 (slide).
-- No Instances here: step() takes an input direction and returns speed + heading; callers drive the Humanoid.
-- Omnimovement (2026-10-07, the player): `heading` is where the body MOVES, `facing` where it LOOKS. Given an `aim`
-- (the camera's flat look), the body faces it while moving and every direction is its own pace: a full run ahead,
-- a strafe sideways (A / D: the body keeps facing ahead), a slow backpedal behind whose pace builds up. Turns curve
-- round with momentum; a reversal carries the pace straight into the new way, except into a backpedal, which plants
-- for a moment first (Config.Movement's momentum timeline). Bots pass no aim: they face their motion as before.

local M = require(script.Parent.Config.Movement)
local C = require(script.Parent.Config.Movement) -- (the dive keys live in Config.Movement)

export type State = {
	speed: number,
	heading: Vector3,
	dashT: number,
	dashCD: number,
	dashDir: Vector3,
	dashSide: string?, -- "Left" / "Right": a dash across the body, "Back": a backward hop (both keep facing ahead); nil: forward dash
	stopT: number,
	jukeT: number,
	stopCD: number,
	slideT: number,
	slideCD: number,
	slideStart: number,
	boostT: number,
	diveT: number,
	diveCD: number,
	diveDir: Vector3,
	recoverT: number,
	lastTech: string?,
	lastTechAge: number,
	reversed: boolean,
	facing: Vector3, -- where the body looks (turns toward its target at FACE_RATE_LOW..HIGH)
	backing: boolean, -- omnimovement: steering back relative to the facing (latched; the slow backpedal pace)
	faceWant: Vector3?, -- this step's facing target (nil = hold)
	faceSnap: boolean, -- techniques face their direction at once
	reverseBraking: boolean, -- this step planted against a reversal (the Brake clip plays)
	carry: boolean, -- out of a reversal: the new way builds on from the current pace (no jog kick, no restart)
	idleT: number, -- seconds since the input was let go (players: the pace holds for RELEASE_GRACE first)
	-- The movement state this step ended in (one source of truth; MovementController layers Locked / Caught /
	-- Ragdolled / Falling / Landing on top): Idle, Accelerating, Running, Braking, ReverseBraking, Dashing,
	-- DashRecovery, HardStop, JukeWindow, Sliding, Diving, DiveRecovery.
	mode: string,
}

export type Params = {
	speedMult: number, -- tier handicap, statuses, modifiers (product, already floored by caller)
	accelMult: number,
	decelMult: number,
	turnMult: number,
	dashMult: number,
	lobby: boolean?,
}

local MovementCore = {}

local FLAT = Vector3.new(1, 0, 1)

local function flat(v: Vector3): Vector3
	local f = v * FLAT
	if f.Magnitude < 1e-4 then
		return Vector3.zero
	end
	return f.Unit
end
MovementCore.flat = flat

function MovementCore.newState(heading: Vector3?): State
	return {
		speed = 0,
		heading = (heading and flat(heading)) or Vector3.new(0, 0, -1),
		dashT = 0,
		dashCD = 0,
		dashDir = Vector3.new(0, 0, -1),
		dashSide = nil,
		stopT = 0,
		jukeT = 0,
		stopCD = 0,
		slideT = 0,
		slideCD = 0,
		slideStart = 0,
		boostT = 0,
		diveT = 0,
		diveCD = 0,
		diveDir = Vector3.new(0, 0, -1),
		recoverT = 0,
		lastTech = nil,
		lastTechAge = math.huge,
		reversed = false,
		facing = (heading and flat(heading)) or Vector3.new(0, 0, -1),
		backing = false,
		faceWant = nil,
		faceSnap = false,
		reverseBraking = false,
		carry = false,
		idleT = 0,
		mode = "Idle",
	}
end

-- Role profile multipliers (Config.Movement.Profiles) folded into params. role: "Runner" / "Bomber" / anything
-- else = "Lobby". Call after the params were filled from statuses; returns the profile's speed multiplier.
function MovementCore.applyProfile(p: Params, role: string?): number
	local prof = (M.Profiles :: any)[if role == "Runner" or role == "Bomber" then role else "Lobby"]
	if not prof then
		return 1
	end
	p.speedMult *= prof.speed or 1
	p.accelMult *= prof.accel or 1
	p.decelMult *= prof.decel or 1
	p.turnMult *= prof.turn or 1
	p.dashMult *= prof.dash or 1
	return prof.speed or 1
end

-- End every technique at once (caught, ragdolled, locked, stunned): no dash, slide, stop or dive carries on
-- under a state that took the body away. Momentum then brakes out normally.
function MovementCore.cancelTechniques(s: State)
	s.dashT, s.stopT, s.jukeT, s.slideT, s.diveT = 0, 0, 0, 0, 0
end

function MovementCore.defaultParams(): Params
	return { speedMult = 1, accelMult = 1, decelMult = 1, turnMult = 1, dashMult = 1, lobby = false }
end

function MovementCore.maxSpeed(p: Params): number
	local base = if p.lobby then M.LOBBY_SPEED else M.MAX_SPEED
	return base * p.speedMult
end

-- Rotate unit vector a toward unit vector b by at most maxRad (XZ plane).
local function rotateToward(a: Vector3, b: Vector3, maxRad: number): Vector3
	if b.Magnitude < 1e-4 then
		return a
	end
	local dot = math.clamp(a:Dot(b), -1, 1)
	local angle = math.acos(dot)
	if angle <= maxRad or angle < 1e-4 then
		return b
	end
	-- Positive r rotates X toward Z below, so rotate positively when b lies on the +cross side of a.
	local cross = a.X * b.Z - a.Z * b.X
	local sign = if cross >= 0 then 1 else -1
	local r = sign * maxRad
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(a.X * c - a.Z * s, 0, a.X * s + a.Z * c).Unit
end
MovementCore.rotateToward = rotateToward

local function markTech(s: State, kind: string)
	s.lastTech = kind
	s.lastTechAge = 0
end

function MovementCore.canDash(s: State): boolean
	return s.dashCD <= 0 and s.slideT <= 0
end

-- dir: the steering direction. With none, the dash goes the way the body faces (Config DASH_FROM_STANDSTILL; off:
-- a standing press does nothing and costs no cooldown). backKeepsFacing (players, DASH_BACK_KEEPS_FACING): a dash
-- straight behind the body is a backward hop that keeps facing ahead ("Back"); bots leave it off.
function MovementCore.dash(s: State, dir: Vector3, backKeepsFacing: boolean?): boolean
	if not MovementCore.canDash(s) then
		return false
	end
	local d = flat(dir)
	if d == Vector3.zero then
		if not M.DASH_FROM_STANDSTILL then
			return false
		end
		d = s.facing
	end
	s.dashDir = d
	-- Across the body (≈55°–125° off the facing): a side dash that keeps facing ahead; straight behind: a backward
	-- hop that keeps facing ahead (players); ahead: the forward dash, turning to face it.
	local f = s.facing
	local across = f.Z * d.X - f.X * d.Z -- + = to the body's left
	local ahead = f:Dot(d)
	if ahead < 0.6 and math.abs(across) >= 0.6 then
		s.dashSide = if across > 0 then "Left" else "Right"
	elseif backKeepsFacing and ahead <= -0.6 then
		s.dashSide = "Back"
	else
		s.dashSide = nil
	end
	s.heading = d
	s.dashT = M.DASH_TIME
	s.dashCD = M.DASH_CD
	s.stopT = 0
	markTech(s, "Dash")
	return true
end

function MovementCore.hardStop(s: State, p: Params): boolean
	if s.stopCD > 0 or s.slideT > 0 or s.dashT > 0 then
		return false
	end
	if s.speed < MovementCore.maxSpeed(p) * M.HARDSTOP_MIN_FRAC then
		return false
	end
	s.stopT = M.HARDSTOP_TIME
	s.stopCD = M.HARDSTOP_CD
	s.speed = 0 -- planted at once: no slide, no coast
	markTech(s, "HardStop")
	return true
end

function MovementCore.slide(s: State, p: Params): boolean
	if s.slideCD > 0 or s.slideT > 0 or s.dashT > 0 then
		return false
	end
	local max = MovementCore.maxSpeed(p)
	s.slideT = M.SLIDE_TIME
	s.slideCD = M.SLIDE_CD
	s.slideStart = math.max(s.speed, M.SLIDE_MIN_FRAC * max) * M.SLIDE_MULT
	s.stopT = 0
	markTech(s, "Slide")
	return true
end

-- Catcher dive: fixed-direction lunge of DIVE_DIST over DIVE_TIME, then a slow recovery.
function MovementCore.canDive(s: State): boolean
	return s.diveCD <= 0 and s.diveT <= 0 and s.recoverT <= 0
end

function MovementCore.dive(s: State, dir: Vector3): boolean
	if not MovementCore.canDive(s) then
		return false
	end
	local d = flat(dir)
	if d == Vector3.zero then
		d = s.heading
	end
	s.diveDir = d
	s.heading = d
	s.diveT = C.DIVE_TIME
	s.diveCD = C.DIVE_CD
	s.stopT = 0
	s.dashT = 0
	s.slideT = 0
	markTech(s, "Dive")
	return true
end

function MovementCore.isDiving(s: State): boolean
	return s.diveT > 0
end

function MovementCore.boost(s: State, seconds: number)
	s.boostT = math.max(s.boostT, seconds)
end

function MovementCore.isSliding(s: State): boolean
	return s.slideT > 0
end

-- The dash in progress (or the last one): "Left" / "Right" / "Back" (keeps facing ahead), nil for a forward one.
function MovementCore.dashSide(s: State): string?
	return s.dashSide
end

function MovementCore.isBacking(s: State): boolean
	return s.backing
end

function MovementCore.isReverseBraking(s: State): boolean
	return s.reverseBraking
end

local function advance(s: State, input: Vector3, dt: number, p: Params, aim: Vector3?): (number, Vector3)
	s.dashCD = math.max(0, s.dashCD - dt)
	s.stopCD = math.max(0, s.stopCD - dt)
	s.slideCD = math.max(0, s.slideCD - dt)
	s.boostT = math.max(0, s.boostT - dt)
	s.diveCD = math.max(0, s.diveCD - dt)
	s.lastTechAge += dt

	local boostMult = if s.boostT > 0 then M.BRAVE_BOOST_MULT else 1
	local max = MovementCore.maxSpeed(p) * boostMult
	local dir = flat(input)
	local hasInput = dir ~= Vector3.zero

	-- Dive: constant lunge speed, then recovery at reduced speed.
	if s.diveT > 0 then
		s.diveT = math.max(0, s.diveT - dt)
		s.speed = C.DIVE_DIST / C.DIVE_TIME
		s.heading = s.diveDir
		s.faceWant, s.faceSnap = s.diveDir, true
		s.backing = false
		s.mode = "Diving"
		if s.diveT == 0 then
			s.recoverT = C.DIVE_RECOVERY
			s.speed = max * C.DIVE_RECOVERY_SPEED
		end
		return s.speed, s.heading
	end
	if s.recoverT > 0 then
		s.recoverT = math.max(0, s.recoverT - dt)
		max *= C.DIVE_RECOVERY_SPEED
	end

	-- Dash: fixed direction; the burst holds for DASH_HOLD, then glides back down to max (smoothstep: no jolt at
	-- either end, so it flows straight back into the run).
	if s.dashT > 0 then
		s.dashT = math.max(0, s.dashT - dt)
		local elapsed = M.DASH_TIME - s.dashT
		local peak = math.max(M.DASH_SPEED * p.dashMult * p.speedMult, max)
		s.mode = if elapsed <= M.DASH_HOLD then "Dashing" else "DashRecovery"
		if elapsed <= M.DASH_HOLD then
			s.speed = peak
		else
			local u = math.clamp((elapsed - M.DASH_HOLD) / (M.DASH_TIME - M.DASH_HOLD), 0, 1)
			s.speed = peak + (max - peak) * (u * u * (3 - 2 * u))
		end
		s.heading = s.dashDir
		if not s.dashSide then
			s.faceWant, s.faceSnap = s.dashDir, true -- (a side dash holds its facing)
		end
		s.backing = false
		return s.speed, s.heading
	end

	-- Hard stop: planted (speed 0, input ignored), then the juke window opens.
	if s.stopT > 0 then
		s.stopT = math.max(0, s.stopT - dt)
		s.speed = 0
		s.mode = "HardStop"
		if s.stopT == 0 then
			s.jukeT = M.JUKE_WINDOW
		end
		return s.speed, s.heading
	end

	-- Slide: the burst holds for SLIDE_HOLD, then glides down to the floor (smoothstep: no jolt at either end);
	-- steering limited.
	if s.slideT > 0 then
		s.slideT = math.max(0, s.slideT - dt)
		local elapsed = M.SLIDE_TIME - s.slideT
		local floor = M.SLIDE_MIN_FRAC * max
		if elapsed <= M.SLIDE_HOLD then
			s.speed = s.slideStart
		else
			local u = math.clamp((elapsed - M.SLIDE_HOLD) / (M.SLIDE_TIME - M.SLIDE_HOLD), 0, 1)
			s.speed = s.slideStart + (floor - s.slideStart) * (u * u * (3 - 2 * u))
		end
		if hasInput then
			s.heading = rotateToward(s.heading, dir, math.rad(M.SLIDE_STEER * p.turnMult) * dt)
		end
		s.faceWant, s.faceSnap = s.heading, true
		s.backing = false
		s.mode = "Sliding"
		return s.speed, s.heading
	end

	local juking = s.jukeT > 0
	s.jukeT = math.max(0, s.jukeT - dt)

	if not hasInput then
		s.reversed = false
		s.carry = false
		s.idleT += dt
		-- Players: the pace holds a moment after letting go (switching keys never bleeds it), then the brake.
		if aim and s.idleT <= M.RELEASE_GRACE and s.speed > 0 then
			s.speed = math.max(0, s.speed - M.RELEASE_COAST * dt)
			s.mode = "Braking"
			return s.speed, s.heading
		end
		-- Coasting to a stop holds the body's facing (a backward coast still faces ahead).
		if p.decelMult < 0.999 then
			-- Slippery (Ice, Marbles): the long linear coast those effects are tuned around.
			s.speed = math.max(0, s.speed - (max / M.DECEL_TIME) * p.decelMult * dt)
		else
			-- Plant and brake: fast at first, settling onto zero (≈0.3 s / ≈2.3 studs from full speed).
			s.speed = math.max(0, s.speed - (s.speed / M.STOP_TAU + M.STOP_LINEAR) * dt)
		end
		if s.speed <= 0 then
			s.backing = false
		end
		s.mode = if s.speed > 0 then "Braking" elseif s.jukeT > 0 then "JukeWindow" else "Idle"
		return s.speed, s.heading
	end
	s.idleT = 0

	-- Turning: fast when slow, slower at full speed; unlimited during the juke window.
	local frac = math.clamp(s.speed / math.max(max, 1e-3), 0, 1)
	local alpha = math.clamp((frac - M.LOW_SPEED_FRAC) / (1 - M.LOW_SPEED_FRAC), 0, 1)
	local rate = (M.TURN_RATE_LOW + (M.TURN_RATE_HIGH - M.TURN_RATE_LOW) * alpha) * p.turnMult
	local angle = math.deg(math.acos(math.clamp(s.heading:Dot(dir), -1, 1)))

	-- This direction's pace (bots: always the full run).
	local target = max
	if aim then
		s.faceWant = aim
		local d = dir:Dot(aim)
		if s.backing then
			s.backing = d < -M.BACK_LEAVE
		else
			s.backing = d < -M.BACK_ENTER
		end
		target = if s.backing
			then max * M.BACK_SPEED_FRAC
			else max * (M.SIDE_SPEED_FRAC + (1 - M.SIDE_SPEED_FRAC) * math.max(d, 0))
		-- A reversal (any flip past REVERSAL_ANGLE; the momentum timeline in Config.Movement), always straight back
		-- and forth, never a U-turn, the body facing ahead throughout:
		if s.speed > 0.5 and angle > M.REVERSAL_ANGLE and not juking then
			if s.backing then
				-- Into a backpedal: a short plant along the old way (the Brake clip plays), then it builds fast.
				s.speed = math.max(0, s.speed - M.BACK_PLANT_DECEL * p.decelMult * dt)
				s.reverseBraking = true
				s.carry = true
				s.mode = "ReverseBraking"
				return s.speed, s.heading
			end
			-- Anything else (A↔D, S→W): straight off the new way, keeping most of the pace.
			s.heading = dir
			s.speed *= M.LATERAL_CARRY
			s.carry = true
			angle = 0
		end
	else
		s.faceWant = dir
	end

	if juking or s.speed < 0.5 then
		-- The cut: out of the plant at nearly full pace in a NEW direction (≥ 35° off the old heading; holding
		-- straight on just sets off normally). The window closes once used.
		local cut = juking and s.heading:Dot(dir) < math.cos(math.rad(35))
		s.heading = dir
		if cut and s.speed < target * M.JUKE_START then
			s.speed = target * M.JUKE_START
			s.jukeT = 0
			markTech(s, "Juke")
		end
	else
		if not aim and angle > M.REVERSAL_ANGLE and frac > M.REVERSAL_MIN_FRAC and not s.reversed then
			s.speed *= (1 - M.REVERSAL_PENALTY)
			s.reversed = true
		end
		s.heading = rotateToward(s.heading, dir, math.rad(rate) * dt)
	end
	if angle < 45 then
		s.reversed = false
	end
	if s.speed < target then
		if s.backing then
			-- Backpedal: the pace builds smoothly and quickly from whatever speed we have (BACK_ACCEL), so a run
			-- turned into a backwalk flows straight on (reference: a fast, momentum-carrying backwalk).
			s.speed = math.min(target, s.speed + M.BACK_ACCEL * p.accelMult * boostMult * dt)
		else
			-- First step: set off at a jog at once (less on ice: the accel multiplier scales it), then build to
			-- full speed on an ease-out curve: df/dt = (2/T)·√((1−S)(1−f)) runs f from S to 1 in exactly T.
			-- Brave Boost lifts acceleration by the same factor as top speed (GDD §6.3).
			-- (Out of a reversal there's no kick: the new way builds on smoothly from the plant.)
			local kick = target * M.START_FRAC * math.min(p.accelMult, 1)
			if s.speed < kick and not s.carry then
				s.speed = kick
			end
			local f = math.clamp(s.speed / target, 0, 1)
			local ease = (2 / M.ACCEL_TIME) * math.sqrt(math.max(0, (1 - M.START_FRAC) * (1 - f)))
			local scale = p.accelMult * boostMult * (if juking then M.JUKE_ACCEL_MULT else 1)
			s.speed = math.min(target, s.speed + math.max(ease, M.ACCEL_FLOOR) * target * scale * dt)
		end
	else
		-- Above this direction's pace (a run turned into a strafe, a boost ended): settle down to it (players
		-- gently, so a change of route keeps its momentum a moment).
		local settle = if aim then M.SETTLE_DECEL else max / M.DECEL_TIME
		s.speed = math.max(target, s.speed - settle * p.decelMult * dt)
	end

	if s.speed >= target - 0.01 then
		s.carry = false
	end
	s.mode = if s.recoverT > 0 then "DiveRecovery" elseif s.speed < target - 0.01 then "Accelerating" else "Running"
	return s.speed, s.heading
end

-- Advance one frame. input: desired world direction (any length; zero = no input). aim: the player's camera look
-- (omnimovement: the body faces it while moving, each direction its own pace); bots leave it nil.
-- The frame is integrated in equal sub-steps of at most SUBSTEP seconds. Returns the end-of-frame speed and heading,
-- plus the AVERAGE speed over the frame: drive the Humanoid with that one, so the ground covered is the same at 30
-- or 144 FPS (holding the end speed for a whole frame undercounts a stop by ≈15 % at 30 FPS). A spike is clamped
-- to 0.1 s first.
function MovementCore.step(s: State, input: Vector3, dt: number, p: Params, aim: Vector3?): (number, Vector3, number)
	dt = math.clamp(dt, 0, 0.1)
	local a = if aim then flat(aim) else nil
	if a == Vector3.zero then
		a = nil
	end
	local n = math.max(1, math.ceil(dt / M.SUBSTEP - 1e-6))
	local h = dt / n
	local speed, heading = s.speed, s.heading
	local total = 0
	for _ = 1, n do
		s.faceWant, s.faceSnap, s.reverseBraking = nil, false, false
		speed, heading = advance(s, input, h, p, a)
		total += speed
		local want = s.faceWant
		if want and want.Magnitude > 1e-3 then
			local w = flat(want)
			if s.faceSnap then
				s.facing = w
			else
				-- Quick from a walk, a little heavier at full pace.
				local frac = math.clamp(speed / math.max(MovementCore.maxSpeed(p), 1e-3), 0, 1)
				local rate = M.FACE_RATE_LOW + (M.FACE_RATE_HIGH - M.FACE_RATE_LOW) * frac
				s.facing = rotateToward(s.facing, w, math.rad(rate * p.turnMult) * h)
			end
		end
	end
	return speed, heading, total / n
end

return MovementCore
