--!strict
-- Specs for Shared/ThrowPhysics (GDD §7.4c THROW MODE).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ThrowPhysics = require(ReplicatedStorage.Shared.ThrowPhysics)

local T = Config.Throw

-- a flat floor at y = 0
local function floor(a: Vector3, b: Vector3): (Vector3?, Vector3?)
	if b.Y <= 0 and a.Y > 0 then
		local k = a.Y / (a.Y - b.Y)
		return a:Lerp(b, k), Vector3.yAxis
	end
	return nil, nil
end

local function nothing(_a: Vector3, _b: Vector3): (Vector3?, Vector3?)
	return nil, nil
end

-- the flat distance it travels until its first bounce on the floor
local function firstBounce(power: number): number
	local s = ThrowPhysics.new(Vector3.new(0, 4, 0), ThrowPhysics.launch(Vector3.new(0, 0, -1), power))
	for _ = 1, 400 do
		if ThrowPhysics.step(s, 1 / 120, floor) then
			return (s.pos * Vector3.new(1, 0, 1)).Magnitude
		end
	end
	return math.huge
end

return function(t)
	t.it("more power throws further, inside sane ranges", function()
		local short, long = firstBounce(0), firstBounce(1)
		t.expect(short > 10 and short < 25).truthy()
		t.expect(long > 35 and long < 60).truthy()
		t.expect(long > short).truthy()
	end)

	t.it("only the aim's flat direction counts (the arc comes from the power)", function()
		local up = ThrowPhysics.launch(Vector3.new(1, 5, 0), 0.5)
		local level = ThrowPhysics.launch(Vector3.new(1, 0, 0), 0.5)
		t.expect((up - level).Magnitude).near(0)
	end)

	t.it("it bounces off the floor, loses speed, and lands", function()
		local s = ThrowPhysics.new(Vector3.new(0, 4, 0), ThrowPhysics.launch(Vector3.new(0, 0, -1), 1))
		local bounces = 0
		for _ = 1, 2000 do
			if ThrowPhysics.step(s, 1 / 120, floor) then
				bounces += 1
				t.expect(s.vel.Y >= 0).truthy() -- it leaves the floor going up (or rolls)
				t.expect(s.pos.Y >= 0).truthy()
			end
			if s.rest then
				break
			end
		end
		t.expect(s.rest).truthy()
		t.expect(bounces >= 1 and bounces <= T.MAX_BOUNCES + 1).truthy()
	end)

	t.it("a body is hit through its middle, missed over a slide and beside it", function()
		local root = Vector3.new(0, 3, 0)
		t.expect(ThrowPhysics.hitsBody(Vector3.new(-1, 3, 0), Vector3.new(1, 3, 0), root, T.BODY_HIGH)).truthy()
		-- chest height over a sliding body: over its head
		t.expect(ThrowPhysics.hitsBody(Vector3.new(-1, 3.5, 0), Vector3.new(1, 3.5, 0), root, T.SLIDE_HIGH)).falsy()
		t.expect(ThrowPhysics.hitsBody(Vector3.new(-1, 3, 4), Vector3.new(1, 3, 4), root, T.BODY_HIGH)).falsy()
		-- the MEGA giant is wider
		t.expect(ThrowPhysics.hitsBody(Vector3.new(-1, 3, 4), Vector3.new(1, 3, 4), root, T.BODY_HIGH, 3)).truthy()
	end)

	t.it("the solve leads a moving target and lands on it", function()
		local origin = Vector3.new(0, 4.6, 0)
		local target = Vector3.new(0, 3, -20)
		local vel = Vector3.new(16, 0, 0)
		local aim, power, time = ThrowPhysics.solve(origin, target, vel)
		t.expect(aim ~= nil and power ~= nil and time ~= nil).truthy()
		local a, p = aim :: Vector3, power :: number
		t.expect(a.X > 0.05).truthy() -- led to the side it's running
		-- fly it: it passes through where the target will be
		local s = ThrowPhysics.new(origin, ThrowPhysics.launch(a, p))
		local hit = false
		local clock = 0
		for _ = 1, 240 do
			local before = s.pos
			ThrowPhysics.step(s, 1 / 120, nothing)
			clock += 1 / 120
			if ThrowPhysics.hitsBody(before, s.pos, target + vel * clock, T.BODY_HIGH) then
				hit = true
				break
			end
		end
		t.expect(hit).truthy()
		-- and nothing beyond MAX_RANGE
		t.expect((ThrowPhysics.solve(origin, Vector3.new(0, 3, -(T.MAX_RANGE + 20)), Vector3.zero))).toBe(nil)
	end)
end
