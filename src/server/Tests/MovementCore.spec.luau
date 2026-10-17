--!strict
-- Specs for MovementCore (GDD §7.3-7.6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementCore = require(ReplicatedStorage.Shared.MovementCore)
local M = require(ReplicatedStorage.Shared.Config.Movement)

local FWD = Vector3.new(0, 0, -1)

local function run(s, input, seconds, p)
	local dt = 1 / 60
	local n = math.floor(seconds / dt + 0.5)
	local speed, heading = 0, s.heading
	for _ = 1, n do
		speed, heading = MovementCore.step(s, input, dt, p)
	end
	return speed, heading
end

return function(t)
	local P = MovementCore.defaultParams()

	t.it("sets off at a jog, then eases up to max by ACCEL_TIME", function()
		local s = MovementCore.newState(FWD)
		local first = MovementCore.step(s, FWD, 1 / 60, P)
		t.expect(first).atLeast(M.MAX_SPEED * M.START_FRAC)
		local half = run(s, FWD, M.ACCEL_TIME / 2, P)
		t.expect(half).atLeast(M.MAX_SPEED * 0.75)
		t.expect(half).atMost(M.MAX_SPEED * 0.95)
		local full = run(s, FWD, M.ACCEL_TIME / 2 + 0.05, P)
		t.expect(full).near(M.MAX_SPEED, 1e-3)
	end)

	t.it("eases out: the build-up slows as it nears full speed", function()
		local s = MovementCore.newState(FWD)
		MovementCore.step(s, FWD, 1 / 60, P)
		local a = s.speed
		local b = run(s, FWD, 0.2, P)
		local c = run(s, FWD, 0.2, P)
		local d = run(s, FWD, 0.2, P)
		t.expect(b - a > c - b and c - b > d - c).truthy()
	end)

	t.it("brakes to zero quickly without input (≈0.3 s, short slide)", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1.5, P)
		local dist, time = 0, 0
		while s.speed > 0 and time < 2 do
			dist += MovementCore.step(s, Vector3.zero, 1 / 60, P) / 60
			time += 1 / 60
		end
		t.expect(time).atMost(0.36)
		t.expect(dist).atMost(2.6)
		t.expect(dist).atLeast(1.2)
	end)

	t.it("slippery decel (ice) keeps the long linear coast", function()
		local s = MovementCore.newState(FWD)
		local ice = MovementCore.defaultParams()
		ice.decelMult = 0.25
		run(s, FWD, 1.5, P)
		local speed = run(s, Vector3.zero, M.DECEL_TIME / ice.decelMult * 0.5, ice)
		t.expect(speed).near(M.MAX_SPEED * 0.5, 0.6)
	end)

	t.it("turns slower at full speed than when slow", function()
		local s1 = MovementCore.newState(FWD)
		run(s1, FWD, 1, P)
		local right = Vector3.new(1, 0, 0)
		local _, h1 = run(s1, right, 0.1, P)
		local s2 = MovementCore.newState(FWD)
		local _, h2 = run(s2, right, 0.1, P)
		local a1 = math.deg(math.acos(math.clamp(h1:Dot(FWD), -1, 1)))
		local a2 = math.deg(math.acos(math.clamp(h2:Dot(FWD), -1, 1)))
		t.expect(a2 > a1).truthy()
		t.expect(a1).near(M.TURN_RATE_HIGH * 0.1, 8)
	end)

	t.it("rotateToward always moves closer to the target (both directions)", function()
		local dirs = {
			Vector3.new(1, 0, 0),
			Vector3.new(-1, 0, 0),
			Vector3.new(0, 0, 1),
			Vector3.new(0.6, 0, -0.8),
			Vector3.new(-0.6, 0, 0.8),
		}
		for _, a in ipairs(dirs) do
			for _, b in ipairs(dirs) do
				local before = a:Dot(b)
				local r = MovementCore.rotateToward(a, b, math.rad(10))
				t.expect(r:Dot(b) >= before - 1e-6).truthy()
			end
		end
	end)

	t.it("heading converges onto a reversed input at full speed", function()
		for _, target in ipairs({ -FWD, Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0.7, 0, 0.7).Unit }) do
			local s = MovementCore.newState(FWD)
			run(s, FWD, 1, P)
			local _, h = run(s, target, 1.0, P)
			t.expect(h:Dot(target)).near(1, 1e-3)
		end
	end)

	t.it("applies reversal penalty once on a sharp turn at speed", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1, P)
		local before = s.speed
		MovementCore.step(s, -FWD, 1 / 60, P)
		t.expect(s.speed).atMost(before * (1 - M.REVERSAL_PENALTY) + 1)
	end)

	t.it("dash bursts to DASH_SPEED then settles, with cooldown", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1, P)
		t.expect(MovementCore.dash(s, FWD)).truthy()
		local sp = MovementCore.step(s, FWD, 1 / 60, P)
		t.expect(sp).atLeast(M.DASH_SPEED * 0.9)
		t.expect(MovementCore.dash(s, FWD)).falsy()
		run(s, FWD, M.DASH_TIME + 0.05, P)
		t.expect(s.speed).near(M.MAX_SPEED, 0.5)
		run(s, FWD, M.DASH_CD, P)
		t.expect(MovementCore.canDash(s)).truthy()
	end)

	t.it("dash wins clearly more ground than running over the same time", function()
		local function distance(dash: boolean): number
			local s = MovementCore.newState(FWD)
			run(s, FWD, 1.5, P)
			if dash then
				MovementCore.dash(s, FWD)
			end
			local d = 0
			for _ = 1, math.floor(M.DASH_TIME * 60 + 0.5) do
				d += MovementCore.step(s, FWD, 1 / 60, P) / 60
			end
			return d
		end
		local ran, dashed = distance(false), distance(true)
		-- Worth it, not broken (2026-10-07 nerf): ≈5.5 studs gained.
		t.expect(dashed - ran).atLeast(4.5)
		t.expect(dashed - ran).atMost(7)
		t.expect(dashed / ran).atLeast(1.5)
	end)

	t.it("hard stop plants you dead, then a cut launches you out at near full speed", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1.5, P)
		t.expect(MovementCore.hardStop(s, P)).truthy()
		t.expect(s.speed).toBe(0) -- planted at once
		-- Input is ignored during the plant.
		local sp = run(s, Vector3.new(1, 0, 0), M.HARDSTOP_TIME * 0.5, P)
		t.expect(sp).toBe(0)
		run(s, FWD * 0, M.HARDSTOP_TIME * 0.5 + 0.02, P)
		t.expect(s.jukeT > 0).truthy()
		-- The cut: instant turn and straight out at JUKE_START of top speed.
		local speed, h = MovementCore.step(s, Vector3.new(1, 0, 0), 1 / 60, P)
		t.expect(h:Dot(Vector3.new(1, 0, 0))).near(1, 1e-3)
		t.expect(speed).atLeast(M.MAX_SPEED * M.JUKE_START - 0.01)
	end)

	t.it("holding straight on through a stop just sets off normally (no forward launch)", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1.5, P)
		MovementCore.hardStop(s, P)
		run(s, FWD, M.HARDSTOP_TIME + 0.02, P)
		local speed = MovementCore.step(s, FWD, 1 / 60, P)
		t.expect(speed).atMost(M.MAX_SPEED * 0.6)
	end)

	t.it("hard stop requires speed", function()
		local s = MovementCore.newState(FWD)
		t.expect(MovementCore.hardStop(s, P)).falsy()
	end)

	t.it("slide keeps speed above floor and limits steering", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1, P)
		t.expect(MovementCore.slide(s, P)).truthy()
		local sp, h = run(s, Vector3.new(1, 0, 0), M.SLIDE_TIME * 0.5, P)
		t.expect(sp).atLeast(M.MAX_SPEED * M.SLIDE_MIN_FRAC - 0.01)
		local ang = math.deg(math.acos(math.clamp(h:Dot(FWD), -1, 1)))
		t.expect(ang).atMost(M.SLIDE_STEER * M.SLIDE_TIME * 0.5 + 2)
		t.expect(MovementCore.slide(s, P)).falsy()
	end)

	t.it("slide is a real burst: more ground than running for the same time", function()
		local a = MovementCore.newState(FWD)
		run(a, FWD, 1.5, P)
		local b = MovementCore.newState(FWD)
		run(b, FWD, 1.5, P)
		t.expect(MovementCore.slide(b, P)).truthy()
		local runD, slideD = 0, 0
		for _ = 1, math.floor(M.SLIDE_TIME * 60 + 0.5) do
			runD += MovementCore.step(a, FWD, 1 / 60, P) / 60
			slideD += MovementCore.step(b, FWD, 1 / 60, P) / 60
		end
		t.expect(slideD).atLeast(runD * 1.15)
	end)

	t.it("a standing dash goes the way the body faces (DASH_FROM_STANDSTILL), or does nothing with it off", function()
		local s = MovementCore.newState(FWD)
		if M.DASH_FROM_STANDSTILL then
			t.expect(MovementCore.dash(s, Vector3.zero)).truthy()
			t.expect(s.dashDir:Dot(FWD)).near(1, 1e-3)
			local moved = run(s, Vector3.zero, 0.1, P)
			t.expect(moved).atLeast(M.MAX_SPEED) -- a real burst from a standstill
		else
			t.expect(MovementCore.dash(s, Vector3.zero)).falsy()
			t.expect(s.dashCD).toBe(0)
			t.expect(MovementCore.dash(s, FWD)).truthy()
		end
	end)

	t.it("speedMult scales max speed (tier handicap)", function()
		local s = MovementCore.newState(FWD)
		local p2 = MovementCore.defaultParams()
		p2.speedMult = 0.95
		local sp = run(s, FWD, 1.5, p2)
		t.expect(sp).near(M.MAX_SPEED * 0.95, 1e-3)
	end)

	-- Omnimovement (2026-10-07): the player passes the camera's look as `aim` -------------------------------------
	local BACK = -FWD
	local LEFT = Vector3.new(-1, 0, 0)
	local RIGHT = Vector3.new(1, 0, 0)
	local function omni(s, input, seconds, aim)
		local dt = 1 / 60
		for _ = 1, math.floor(seconds / dt + 0.5) do
			MovementCore.step(s, input, dt, P, aim or FWD)
		end
		return s.speed
	end

	t.it("omni: strafing (A / D) keeps the body facing ahead, at the strafe pace", function()
		local s = MovementCore.newState(FWD)
		local sp = omni(s, LEFT, 2)
		t.expect(sp).near(M.MAX_SPEED * M.SIDE_SPEED_FRAC, 0.05)
		t.expect(s.heading:Dot(LEFT)).near(1, 1e-3)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3)
		t.expect(MovementCore.isBacking(s)).falsy()
	end)

	t.it("omni: the body turns to the camera when it moves, and holds its facing standing still", function()
		local s = MovementCore.newState(BACK) -- standing, facing the camera
		omni(s, Vector3.zero, 0.5)
		t.expect(s.facing:Dot(BACK)).near(1, 1e-3) -- idle: no turn
		omni(s, FWD, 0.2)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3) -- moving: faces the camera's way within ≈0.15 s (180°)
	end)

	t.it("omni: backpedal walks back facing ahead, slower than a run", function()
		local s = MovementCore.newState(FWD)
		local sp = omni(s, BACK, 2)
		t.expect(sp).near(M.MAX_SPEED * M.BACK_SPEED_FRAC, 0.05)
		t.expect(sp).atLeast(M.MAX_SPEED * 0.8 - 0.01) -- no more than 20 % slower than the run
		t.expect(s.heading:Dot(BACK)).near(1, 1e-3)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3)
		t.expect(MovementCore.isBacking(s)).truthy()
	end)

	t.it("omni: backpedal pace builds up fast but not in one frame", function()
		local s = MovementCore.newState(FWD)
		local bmax = M.MAX_SPEED * M.BACK_SPEED_FRAC
		local a = omni(s, BACK, 1 / 60)
		local b = omni(s, BACK, 0.1)
		local c = omni(s, BACK, 0.2)
		t.expect(a).atMost(bmax * 0.15)
		t.expect(b > a + 1 and c > b + 1).truthy()
		t.expect(c).atLeast(bmax * 0.95) -- full pace within ≈0.3 s
	end)

	t.it("omni: a run reversing into a backpedal plants along the run first, facing ahead throughout", function()
		local s = MovementCore.newState(FWD)
		omni(s, FWD, 1.5)
		local minFace, braked, planted = 1, false, false
		for _ = 1, 60 do
			MovementCore.step(s, BACK, 1 / 60, P, FWD)
			minFace = math.min(minFace, s.facing:Dot(FWD))
			planted = planted or MovementCore.isReverseBraking(s)
			if s.heading:Dot(FWD) > 0.99 and s.speed > 0 then
				braked = true -- still moving forward while slowing
			end
		end
		t.expect(braked and planted).truthy()
		t.expect(minFace).atLeast(0.99)
		t.expect(s.heading:Dot(BACK)).near(1, 1e-3) -- and is now walking back
		t.expect(MovementCore.isReverseBraking(s)).falsy()
	end)

	t.it(
		"omni: a strafe reversal (A → D) carries its momentum straight into the new way, no plant, no U-turn",
		function()
			local s = MovementCore.newState(FWD)
			local pace = omni(s, LEFT, 1.5)
			local maxAhead, minSpeed = 0, math.huge
			for _ = 1, 90 do
				MovementCore.step(s, RIGHT, 1 / 60, P, FWD)
				maxAhead = math.max(maxAhead, math.abs(s.heading:Dot(FWD)) * s.speed)
				minSpeed = math.min(minSpeed, s.speed)
			end
			t.expect(maxAhead).atMost(0.6) -- never curved off the line
			t.expect(minSpeed).atLeast(pace * M.LATERAL_CARRY - 0.01) -- the momentum was never killed
			t.expect(MovementCore.isReverseBraking(s)).falsy()
			t.expect(s.heading:Dot(RIGHT)).near(1, 1e-3)
			t.expect(s.facing:Dot(FWD)).near(1, 1e-3)
		end
	)

	t.it("omni: letting go between two keys keeps the pace; holding off longer brakes", function()
		local s = MovementCore.newState(FWD)
		local pace = omni(s, LEFT, 1.5)
		omni(s, Vector3.zero, M.RELEASE_GRACE * 0.7) -- a key swap's gap
		t.expect(s.speed).atLeast(pace - M.RELEASE_COAST * M.RELEASE_GRACE - 0.01)
		omni(s, RIGHT, 1 / 60)
		t.expect(s.speed).atLeast(pace * M.LATERAL_CARRY * 0.9)
		local s2 = MovementCore.newState(FWD)
		omni(s2, FWD, 1.5)
		omni(s2, Vector3.zero, 0.6)
		t.expect(s2.speed).toBe(0) -- really let go: stopped
	end)

	t.it("omni: a run turning into a strafe curves round with momentum, keeping most of its pace", function()
		local s = MovementCore.newState(FWD)
		omni(s, FWD, 1.5)
		omni(s, LEFT, 0.1)
		t.expect(s.heading:Dot(LEFT)).atMost(0.8) -- still carrying round…
		t.expect(s.speed).atLeast(M.MAX_SPEED * M.SIDE_SPEED_FRAC - 0.01) -- …without losing the run
		omni(s, LEFT, 0.5)
		t.expect(s.heading:Dot(LEFT)).near(1, 1e-3)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3)
	end)

	t.it("omni: out of a backpedal into a run plants, then sets off at a jog facing ahead", function()
		local s = MovementCore.newState(FWD)
		omni(s, BACK, 1.5)
		omni(s, FWD, 1)
		t.expect(s.heading:Dot(FWD)).near(1, 1e-3)
		t.expect(MovementCore.isBacking(s)).falsy()
		t.expect(s.speed).atLeast(M.MAX_SPEED * M.START_FRAC)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3)
	end)

	t.it("omni: a dash across the body (A / D) is a side dash that keeps facing ahead", function()
		local s = MovementCore.newState(FWD)
		omni(s, RIGHT, 0.5)
		t.expect(MovementCore.dash(s, RIGHT)).truthy()
		t.expect(MovementCore.dashSide(s)).toBe("Right")
		omni(s, RIGHT, 0.2)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3) -- never turned to face the dash
		t.expect(s.heading:Dot(RIGHT)).near(1, 1e-3)
		local s2 = MovementCore.newState(FWD)
		omni(s2, LEFT, 0.5)
		MovementCore.dash(s2, LEFT)
		t.expect(MovementCore.dashSide(s2)).toBe("Left")
		local s3 = MovementCore.newState(FWD)
		omni(s3, FWD, 0.5)
		MovementCore.dash(s3, FWD)
		t.expect(MovementCore.dashSide(s3)).toBe(nil) -- ahead: the forward dash
	end)

	t.it("bots (no aim): face their motion, full pace any way", function()
		local s = MovementCore.newState(FWD)
		run(s, RIGHT, 1.5, P)
		t.expect(s.facing:Dot(RIGHT)).near(1, 1e-3)
		t.expect(s.speed).near(M.MAX_SPEED, 1e-3)
	end)

	t.it("brave boost raises max temporarily", function()
		local s = MovementCore.newState(FWD)
		MovementCore.boost(s, M.BRAVE_BOOST_TIME)
		local sp = run(s, FWD, 1.0, P)
		t.expect(sp).near(M.MAX_SPEED * M.BRAVE_BOOST_MULT, 0.05)
		run(s, FWD, M.BRAVE_BOOST_TIME + 1, P)
		t.expect(s.speed).near(M.MAX_SPEED, 0.05)
	end)

	-- ── 2026-10-08 movement polish ─────────────────────────────────────────────────────────────────────────────
	-- Ground covered by a scenario at a given frame rate, driving with step()'s frame-average speed (as the
	-- controllers do).
	local function distanceAt(fps: number, scenario: string): number
		local dt = 1 / fps
		local s = MovementCore.newState(FWD)
		local d = 0
		local function go(input, seconds, aim)
			for _ = 1, math.floor(seconds / dt + 0.5) do
				local _, _, avg = MovementCore.step(s, input, dt, P, aim)
				d += avg * dt
			end
		end
		if scenario == "accel" then
			go(FWD, 1)
		elseif scenario == "stop" then
			go(FWD, 2)
			d = 0
			go(Vector3.zero, 1)
		elseif scenario == "dash" then
			go(FWD, 2)
			d = 0
			MovementCore.dash(s, FWD)
			go(FWD, 0.6)
		elseif scenario == "slide" then
			go(FWD, 2)
			d = 0
			MovementCore.slide(s, P)
			go(FWD, 0.8)
		elseif scenario == "backpedal" then
			go(-FWD, 1, FWD)
		elseif scenario == "juke" then
			go(FWD, 2)
			d = 0
			MovementCore.hardStop(s, P)
			go(Vector3.new(1, 0, 0), 0.8)
		end
		return d
	end

	t.it(
		"frame-rate independent: run, stop, dash, slide, backpedal, juke cover the same ground at 30-144 FPS",
		function()
			for _, scenario in ipairs({ "accel", "stop", "dash", "slide", "backpedal", "juke" }) do
				local ref = distanceAt(240, scenario)
				for _, fps in ipairs({ 30, 60, 120, 144 }) do
					local d = distanceAt(fps, scenario)
					t.expect(math.abs(d / ref - 1)).atMost(0.01) -- within 1 % (was up to 28 % for a stop at 30 FPS)
				end
			end
		end
	)

	t.it("step() returns the frame's average speed alongside the end speed", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 2, P)
		local endSpeed, _, avg = MovementCore.step(s, Vector3.zero, 1 / 30, P)
		t.expect(avg).atLeast(endSpeed) -- braking: the average sits above the end of the frame
		t.expect(avg).atMost(M.MAX_SPEED)
	end)

	t.it("a backward dash (players) hops back still facing ahead; bots (flag off) turn to it", function()
		local s = MovementCore.newState(FWD)
		omni(s, FWD, 0.5)
		t.expect(MovementCore.dash(s, BACK, true)).truthy()
		t.expect(MovementCore.dashSide(s)).toBe("Back")
		omni(s, BACK, 0.2)
		t.expect(s.facing:Dot(FWD)).near(1, 1e-3) -- never turned round
		t.expect(s.heading:Dot(BACK)).near(1, 1e-3)
		local bot = MovementCore.newState(FWD)
		run(bot, FWD, 0.5, P)
		MovementCore.dash(bot, BACK)
		t.expect(MovementCore.dashSide(bot)).toBe(nil)
		run(bot, BACK, 0.05, P)
		t.expect(bot.facing:Dot(BACK)).near(1, 1e-3)
	end)

	t.it("cancelTechniques ends a dash at once (caught / locked mid-dash)", function()
		local s = MovementCore.newState(FWD)
		run(s, FWD, 1, P)
		MovementCore.dash(s, FWD)
		run(s, FWD, 0.05, P)
		MovementCore.cancelTechniques(s)
		t.expect(s.dashT).toBe(0)
		-- No burst is held: the momentum brakes out like any stop (from dash pace, below running pace in 0.15 s).
		local sp = run(s, Vector3.zero, 0.15, P)
		t.expect(sp).atMost(M.MAX_SPEED * 0.6)
	end)

	t.it("movement state names follow the model", function()
		local s = MovementCore.newState(FWD)
		run(s, Vector3.zero, 0.1, P)
		t.expect(s.mode).toBe("Idle")
		run(s, FWD, 0.1, P)
		t.expect(s.mode).toBe("Accelerating")
		run(s, FWD, 1.5, P)
		t.expect(s.mode).toBe("Running")
		MovementCore.dash(s, FWD)
		run(s, FWD, 0.05, P)
		t.expect(s.mode).toBe("Dashing")
		run(s, FWD, M.DASH_HOLD + 0.05, P)
		t.expect(s.mode).toBe("DashRecovery")
		run(s, FWD, 1, P)
		run(s, Vector3.zero, 0.05, P)
		t.expect(s.mode).toBe("Braking")
	end)

	t.it("into a backpedal: a plant of about 0.1 s, then straight back at once, no jog kick", function()
		local s = MovementCore.newState(FWD)
		omni(s, FWD, 1.5)
		local dt = 1 / 60
		local planted, prev, maxJump = 0, s.speed, 0
		for _ = 1, 60 do
			MovementCore.step(s, BACK, dt, P, FWD)
			if MovementCore.isReverseBraking(s) then
				planted += dt
			else
				maxJump = math.max(maxJump, s.speed - prev)
			end
			prev = s.speed
		end
		t.expect(planted).atLeast(0.05)
		t.expect(planted).atMost(0.15) -- a tiny fraction, not a stop
		t.expect(maxJump).atMost(M.BACK_ACCEL * dt * 1.05) -- builds on smoothly
		t.expect(s.speed).near(M.MAX_SPEED * M.BACK_SPEED_FRAC, 0.05)
	end)

	t.it("out of a backpedal into a run carries the pace straight on (no plant)", function()
		local s = MovementCore.newState(FWD)
		local pace = omni(s, BACK, 1.5)
		MovementCore.step(s, FWD, 1 / 60, P, FWD)
		t.expect(MovementCore.isReverseBraking(s)).falsy()
		t.expect(s.heading:Dot(FWD)).near(1, 1e-3)
		t.expect(s.speed).atLeast(pace * M.LATERAL_CARRY - 0.01)
	end)

	t.it("the backpedal is quick: near full pace within ≈0.25 s from a standstill", function()
		local s = MovementCore.newState(FWD)
		local sp = omni(s, BACK, 0.25)
		t.expect(sp).atLeast(M.MAX_SPEED * M.BACK_SPEED_FRAC * 0.9)
	end)

	t.it("role profiles fold into params (defaults leave tuning unchanged)", function()
		local p2 = MovementCore.defaultParams()
		local speed = MovementCore.applyProfile(p2, "Runner")
		local prof = (M.Profiles :: any).Runner
		t.expect(speed).near(prof.speed, 1e-6)
		t.expect(p2.speedMult).near(prof.speed, 1e-6)
		t.expect(p2.accelMult).near(prof.accel, 1e-6)
		t.expect(p2.dashMult).near(prof.dash, 1e-6)
		local p3 = MovementCore.defaultParams()
		MovementCore.applyProfile(p3, "None")
		t.expect(p3.turnMult).near((M.Profiles :: any).Lobby.turn, 1e-6)
	end)
end
