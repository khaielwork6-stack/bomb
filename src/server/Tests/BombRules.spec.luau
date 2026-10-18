--!strict
-- Specs for Logic/BombRules (GDD §7, §5.4, §6.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local BombRules = require(ServerScriptService.Server.Logic.BombRules)

local B = Config.Bomb

local function body(id: string, role: string, x: number, extra: { [string]: any }?): BombRules.Body
	local b: any = {
		id = id,
		role = role,
		pos = Vector3.new(x, 3, 0),
		active = true,
		safe = false,
		carrying = false,
		tagReadyAt = 0,
	}
	if extra then
		for k, v in pairs(extra) do
			b[k] = v
		end
	end
	return b
end

return function(t)
	local NOW = 100

	t.it("a Bomber's touch sticks a fresh FUSE-second bomb", function()
		local bomber, runner = body("B1", "Bomber", 0), body("R1", "Runner", 3)
		t.expect(BombRules.canTag(bomber, runner, NOW)).truthy()
		local bomb = BombRules.newBomb(1, bomber, runner, NOW)
		t.expect(bomb.carrier).toBe("R1")
		t.expect(bomb.origin).toBe("B1")
		t.expect(BombRules.remaining(bomb, NOW)).near(B.FUSE)
	end)

	t.it("no tag out of reach, on cooldown, in a Safe Strip, or on a Carrier", function()
		local bomber = body("B1", "Bomber", 0)
		t.expect(BombRules.canTag(bomber, body("R1", "Runner", B.TAG_RANGE + B.LAG_SLACK + 0.5), NOW)).falsy()
		t.expect(BombRules.canTag(body("B2", "Bomber", 0, { tagReadyAt = NOW + 0.5 }), body("R1", "Runner", 2), NOW))
			.falsy()
		t.expect(BombRules.canTag(bomber, body("R1", "Runner", 2, { safe = true }), NOW)).falsy()
		t.expect(BombRules.canTag(bomber, body("R1", "Runner", 2, { carrying = true }), NOW)).falsy()
		t.expect(BombRules.canTag(bomber, body("B3", "Bomber", 2), NOW)).falsy()
	end)

	t.it("the Mole's armed STRIKE tags like a Bomber; an unarmed Runner never tags (F-MOD-04)", function()
		local mole = body("M", "Runner", 0, { striker = true })
		local runner = body("R1", "Runner", 2)
		t.expect(BombRules.canTag(mole, runner, NOW)).truthy()
		t.expect(BombRules.canTag(mole, mole, NOW)).falsy()
		t.expect(BombRules.canTag(mole, body("R2", "Runner", 2, { safe = true }), NOW)).falsy()
		t.expect(BombRules.canTag(body("R3", "Runner", 0), runner, NOW)).falsy()
		local target = BombRules.pickTagTarget(mole, { mole, runner, body("B1", "Bomber", 1) }, NOW)
		t.expect(target and target.id).toBe("R1")
	end)

	t.it("the Danger Ring: the pass reach grows LIT → HOT → CRITICAL (F-BOMB-11)", function()
		local bomb = BombRules.newBomb(1, body("B1", "Bomber", 50), body("A", "Runner", 0), NOW)
		t.expect(BombRules.passRange(bomb, NOW)).near(B.PASS_RANGE_STAGE.LIT)
		t.expect(BombRules.passRange(bomb, NOW + B.FUSE - B.STAGE_HOT + 0.01)).near(B.PASS_RANGE_STAGE.HOT)
		t.expect(BombRules.passRange(bomb, NOW + B.FUSE - B.STAGE_CRITICAL + 0.01)).near(B.PASS_RANGE_STAGE.CRITICAL)
		-- a body just past the LIT reach is out of reach at LIT and in reach at CRITICAL
		local a = body("A", "Runner", 0)
		local far = body("C", "Runner", B.PASS_RANGE_STAGE.LIT + B.LAG_SLACK + 0.3)
		local late = NOW + B.FUSE - B.STAGE_CRITICAL + 0.01
		t.expect(BombRules.pickReceiver(bomb, a, { a, far }, NOW + 0.5)).toBe(nil)
		t.expect((BombRules.pickReceiver(bomb, a, { a, far }, late))).toBe(far)
	end)

	t.it("the Lunge reaches further only in front, and makes a SLAM PASS (F-BOMB-12)", function()
		local bomb = BombRules.newBomb(1, body("B1", "Bomber", 50), body("A", "Runner", 0), NOW)
		local later = NOW + 0.5
		local d = B.PASS_RANGE_STAGE.LIT + B.LAG_SLACK + B.LUNGE_REACH * 0.8 -- past normal reach, inside the lunge
		local carrier = body("A", "Runner", 0, { lungeDir = Vector3.new(1, 0, 0) })
		local ahead, behind = body("F", "Runner", d), body("R", "Runner", -d)
		local to, slam = BombRules.pickReceiver(bomb, carrier, { carrier, ahead, behind }, later)
		t.expect(to).toBe(ahead)
		t.expect(slam).truthy()
		local still = body("A", "Runner", 0)
		local to2, slam2 = BombRules.pickReceiver(bomb, still, { still, ahead, behind }, later)
		t.expect(to2).toBe(nil)
		t.expect(slam2).falsy()
		-- only a lunge at somebody can whiff: the target in the cone, nobody behind
		t.expect(BombRules.lungeTarget(bomb, carrier, { carrier, behind }, later)).toBe(nil)
		t.expect(BombRules.lungeTarget(bomb, carrier, { carrier, ahead }, later)).toBe(ahead)
	end)

	t.it("the Reject: a timed Hard Stop bounces it back, once per bomb per player (F-BOMB-13)", function()
		local bomb = BombRules.newBomb(1, body("B1", "Bomber", 50), body("A", "Runner", 0), NOW)
		local ready = body("C", "Runner", 2, { rejectReady = true })
		t.expect(BombRules.rejects(bomb, ready)).truthy()
		t.expect(BombRules.rejects(bomb, body("D", "Runner", 2))).falsy()
		bomb.rejectedBy = { C = true }
		t.expect(BombRules.rejects(bomb, ready)).falsy()
		t.expect(BombRules.rejects(bomb, body("M", "Bomber", 2, { rejectReady = true, mega = true }))).falsy()
	end)

	t.it("a pass keeps the remaining time (the fuse never resets)", function()
		local bomber, a, b = body("B1", "Bomber", 50), body("A", "Runner", 1), body("C", "Runner", 3)
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		local later = NOW + 2.7
		local to = BombRules.pickReceiver(bomb, a, { bomber, a, b }, later)
		t.expect(to and to.id).toBe("C")
		BombRules.pass(bomb, a, b, later)
		t.expect(bomb.carrier).toBe("C")
		t.expect(BombRules.remaining(bomb, later)).near(B.FUSE - 2.7)
	end)

	t.it("no pass inside the receive grace", function()
		local bomber, a, b = body("B1", "Bomber", 0), body("A", "Runner", 1), body("C", "Runner", 3)
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		t.expect(BombRules.pickReceiver(bomb, a, { b }, NOW + B.RECEIVE_GRACE * 0.5)).toBe(nil)
		t.expect(BombRules.pickReceiver(bomb, a, { b }, NOW + B.RECEIVE_GRACE + 0.01)).truthy()
	end)

	t.it("no pass-back to the giver within NO_PASSBACK, allowed after", function()
		local bomber, a, b = body("B1", "Bomber", 0), body("A", "Runner", 1), body("C", "Runner", 3)
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		BombRules.pass(bomb, a, b, NOW + 0.5)
		t.expect(BombRules.canReceive(bomb, a, NOW + 0.5 + B.NO_PASSBACK * 0.5)).falsy()
		t.expect(BombRules.canReceive(bomb, a, NOW + 0.5 + B.NO_PASSBACK + 0.01)).truthy()
	end)

	t.it("revenge: the Bomber who tagged you takes it back once NO_PASSBACK is over", function()
		local bomber, a = body("B1", "Bomber", 0), body("A", "Runner", 1)
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		t.expect(BombRules.pickReceiver(bomb, a, { bomber }, NOW + B.NO_PASSBACK * 0.5)).toBe(nil)
		local to = BombRules.pickReceiver(bomb, a, { bomber }, NOW + B.NO_PASSBACK + 0.05)
		t.expect(to and to.id).toBe("B1")
	end)

	t.it("two in reach: the closest one gets it", function()
		local bomber = body("B1", "Bomber", 50)
		local a, near, far = body("A", "Runner", 0), body("N", "Runner", 1.5), body("F", "Runner", 3.5)
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		local to = BombRules.pickReceiver(bomb, a, { far, near, a }, NOW + 1)
		t.expect(to and to.id).toBe("N")
	end)

	t.it("two Carriers touching: nothing happens", function()
		local bomber, a, b =
			body("B1", "Bomber", 50), body("A", "Runner", 0), body("C", "Runner", 1, { carrying = true })
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		t.expect(BombRules.pickReceiver(bomb, a, { b }, NOW + 1)).toBe(nil)
	end)

	t.it("nobody in a Safe Strip receives; a Carrier in one can't pass", function()
		local bomber, a = body("B1", "Bomber", 50), body("A", "Runner", 0)
		local bomb = BombRules.newBomb(1, bomber, a, NOW)
		t.expect(BombRules.pickReceiver(bomb, a, { body("S", "Runner", 1, { safe = true }) }, NOW + 1)).toBe(nil)
		local inSafe = body("A", "Runner", 0, { safe = true })
		t.expect(BombRules.canPass(bomb, inSafe, NOW + 1)).falsy()
	end)

	t.it("a bomb passed onto a Bomber locks: the Bomber can't pass it on", function()
		local tagger, a, victim = body("B1", "Bomber", 50), body("A", "Runner", 0), body("B2", "Bomber", 1)
		local bomb = BombRules.newBomb(1, tagger, a, NOW)
		BombRules.pass(bomb, a, victim, NOW + 1)
		t.expect(bomb.locked).truthy()
		t.expect(BombRules.canPass(bomb, victim, NOW + 3)).falsy()
	end)

	t.it("stages follow the remaining time", function()
		t.expect(BombRules.stage(4)).toBe("LIT")
		t.expect(BombRules.stage(B.STAGE_HOT)).toBe("HOT")
		t.expect(BombRules.stage(B.STAGE_CRITICAL)).toBe("CRITICAL")
		t.expect(BombRules.stage(0)).toBe("CRITICAL")
	end)

	t.it("clutch window and chain length count distinct Carriers", function()
		t.expect(BombRules.isClutch(B.CLUTCH_WINDOW)).truthy()
		t.expect(BombRules.isClutch(B.CLUTCH_WINDOW + 0.01)).falsy()
		local bomb = BombRules.newBomb(1, body("B1", "Bomber", 9), body("A", "Runner", 0), NOW)
		BombRules.pass(bomb, body("A", "Runner", 0), body("C", "Runner", 1), NOW + 1)
		BombRules.pass(bomb, body("C", "Runner", 1), body("D", "Runner", 2), NOW + 2)
		BombRules.pass(bomb, body("D", "Runner", 2), body("A", "Runner", 0), NOW + 3.5)
		t.expect(BombRules.chainLength(bomb)).toBe(3)
	end)

	t.it("an inactive (ragdolled / stunned) body neither tags, passes nor receives", function()
		local bomber = body("B1", "Bomber", 0, { active = false })
		t.expect(BombRules.canTag(bomber, body("R1", "Runner", 2), NOW)).falsy()
		local bomb = BombRules.newBomb(1, body("B2", "Bomber", 9), body("A", "Runner", 0), NOW)
		t.expect(BombRules.canReceive(bomb, body("C", "Runner", 1, { active = false }), NOW + 1)).falsy()
	end)

	t.it("starting Bombers: 1 per 8, min 1, max 3", function()
		t.expect(BombRules.bomberCount(2)).toBe(1)
		t.expect(BombRules.bomberCount(7)).toBe(1)
		t.expect(BombRules.bomberCount(16)).toBe(2)
		t.expect(BombRules.bomberCount(20)).toBe(2)
		t.expect(BombRules.bomberCount(24)).toBe(3)
		t.expect(BombRules.bomberCount(60)).toBe(3)
	end)

	t.it("the field fuse shortens per crossing and holds its last value", function()
		t.expect(BombRules.fieldFuse(1)).toBe(Config.Round.FIELD_FUSE[1])
		t.expect(BombRules.fieldFuse(3)).toBe(Config.Round.FIELD_FUSE[3])
		t.expect(BombRules.fieldFuse(99)).toBe(Config.Round.FIELD_FUSE[#Config.Round.FIELD_FUSE])
	end)
end
