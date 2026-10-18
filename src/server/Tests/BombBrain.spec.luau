--!strict
-- Specs for Logic/BombBrain (GDD §18.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local BombBrain = require(ServerScriptService.Server.Logic.BombBrain)

local BC = Config.Bots

return function(t)
	t.it("strip distance is zero inside, grows toward the middle", function()
		t.expect(BombBrain.stripDistance(60, 1, 50)).toBe(0)
		t.expect(BombBrain.stripDistance(40, 1, 50)).near(10.5)
		t.expect(BombBrain.stripDistance(40, -1, 50)).near(90.5)
	end)

	t.it("a Bomber behind a Runner cuts it off; one goal-side of it chases", function()
		local goal = Vector3.new(0, 0, 100)
		local aim = BombBrain.cutoff(Vector3.new(0, 0, 20), goal, Vector3.new(0, 0, 0), BC.CUTOFF_MIN, BC.CUTOFF_LEAD)
		t.expect(aim ~= nil).toBe(true)
		t.expect((aim :: Vector3).Z).near(30) -- 10 ahead (half of 20, capped by the lead)
		t.expect(BombBrain.cutoff(Vector3.new(0, 0, 20), goal, Vector3.new(0, 0, 40), BC.CUTOFF_MIN, BC.CUTOFF_LEAD))
			.toBe(nil)
		t.expect(BombBrain.cutoff(Vector3.new(0, 0, 20), goal, Vector3.new(0, 0, 15), BC.CUTOFF_MIN, BC.CUTOFF_LEAD))
			.toBe(nil)
	end)

	t.it("the nearest strip is on the near side", function()
		local side, d = BombBrain.nearestStrip(-30, 50)
		t.expect(side).toBe(-1)
		t.expect(d).near(20.5)
	end)

	t.it("a Carrier defuses when the strip is in reach with margin", function()
		t.expect(BombBrain.carrierChoice(3, 24, 24, true)).toBe("defuse") -- 1 s away, 3 s left
	end)

	t.it("a Carrier passes when the strip is too far and someone is near", function()
		t.expect(BombBrain.carrierChoice(1.2, 40, 24, true)).toBe("pass")
	end)

	t.it("a Carrier with nobody to pass to runs for the strip anyway", function()
		t.expect(BombBrain.carrierChoice(1.2, 40, 24, false)).toBe("defuse")
		-- the Hand-Off: somebody right there is a free hand-off, even with the strip in reach
		t.expect(BombBrain.carrierChoice(3, 24, 24, true, BC.OPPORTUNITY_RANGE - 1)).toBe("pass")
		t.expect(BombBrain.carrierChoice(3, 24, 24, true, BC.OPPORTUNITY_RANGE + 6)).toBe("defuse")
	end)

	t.it("the margin decides the borderline case", function()
		local speed = 24
		local dist = speed * 1.0 -- exactly 1 s away
		t.expect(BombBrain.carrierChoice(1.0 + BC.DEFUSE_MARGIN + 0.01, dist, speed, true)).toBe("defuse")
		t.expect(BombBrain.carrierChoice(1.0 + BC.DEFUSE_MARGIN - 0.05, dist, speed, true)).toBe("pass")
	end)

	t.it("threats push away, closer pushes harder, far ones not at all", function()
		local me = Vector3.new(0, 0, 0)
		local near = BombBrain.threatPush(me, { Vector3.new(2, 0, 0) }, 10)
		local far = BombBrain.threatPush(me, { Vector3.new(8, 0, 0) }, 10)
		t.expect(near.X < 0).truthy()
		t.expect(near.Magnitude > far.Magnitude).truthy()
		t.expect(BombBrain.threatPush(me, { Vector3.new(30, 0, 0) }, 10).Magnitude).toBe(0)
	end)

	t.it("Bombers spread out: a shared target scores worse", function()
		t.expect(BombBrain.targetScore(10, 1) > BombBrain.targetScore(20, 0)).truthy()
	end)

	t.it("start delays: about half go at once, the rest wait at most the cap", function()
		t.expect(BombBrain.startDelay(20, 0.2)).toBe(0)
		t.expect(BombBrain.startDelay(20, 1)).near(20 * BC.START_DELAY_MAX)
	end)

	t.it("cover in the way bends the line round it, still heading forward", function()
		local crate = { { pos = Vector3.new(0, 0, -8), r = 2.2 } }
		local out = BombBrain.avoid(Vector3.new(0.3, 0, 0), Vector3.new(0, 0, -1), crate, 1.5, 10)
		t.expect(out.Z < 0).truthy() -- still going forward
		t.expect(out.X > 0.2).truthy() -- slips past on the side it was already on (+X)
	end)

	t.it("cover behind or well off the line changes nothing", function()
		local fwd = Vector3.new(0, 0, -1)
		local behind = { { pos = Vector3.new(0, 0, 8), r = 2.2 } }
		local aside = { { pos = Vector3.new(9, 0, -6), r = 2.2 } }
		t.expect(BombBrain.avoid(Vector3.zero, fwd, behind, 1.5, 10).Z).near(-1)
		t.expect(BombBrain.avoid(Vector3.zero, fwd, aside, 1.5, 10).Z).near(-1)
	end)
end
