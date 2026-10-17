--!strict
-- Specs for the Phase 4 pure modules (GDD §25.3): LevelCurve, HotStreak, Rewards, Quests, Daily, ProfileSchema.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Logic = ServerScriptService.Server.Logic
local Daily = require(Logic.Daily)
local HotStreak = require(Logic.HotStreak)
local LevelCurve = require(Logic.LevelCurve)
local ProfileSchema = require(Logic.ProfileSchema)
local Quests = require(Logic.Quests)
local Rewards = require(Logic.Rewards)

local E, D = Config.Economy, Config.Daily

return function(t)
	-- ── LevelCurve (§12.2) ──────────────────────────────────────────────────────────────────────────────────────
	t.it("level curve: 150 + 50 per level, capped at 2000", function()
		t.expect(LevelCurve.xpToNext(1)).toBe(150)
		t.expect(LevelCurve.xpToNext(5)).toBe(350)
		t.expect(LevelCurve.xpToNext(100)).toBe(2000)
	end)

	t.it("the GDD's cumulative table: level 5 at 900, level 10 at 3150 total XP", function()
		t.expect(LevelCurve.total(5, 0)).toBe(900)
		t.expect(LevelCurve.total(10, 0)).toBe(3150)
	end)

	t.it("adding XP crosses several levels and keeps the remainder", function()
		local l, x, ups = LevelCurve.add(1, 100, 400) -- 500 total: 150 to L2, 200 to L3, 150 left
		t.expect(l).toBe(3)
		t.expect(x).toBe(150)
		t.expect(#ups).toBe(2)
		t.expect(ups[2]).toBe(3)
	end)

	t.it("level-up Stars are 40 + 10 x L, capped", function()
		t.expect(LevelCurve.levelStars(2)).toBe(60)
		t.expect(LevelCurve.levelStars(40)).toBe(E.LEVEL_STARS_CAP)
	end)

	t.it("badges change every 10 levels and stop at obsidian", function()
		t.expect(LevelCurve.badge(1)).toBe("Bronze")
		t.expect(LevelCurve.badge(11)).toBe("Silver")
		t.expect(LevelCurve.badge(999)).toBe("Obsidian")
	end)

	-- ── HotStreak (§15.1) ───────────────────────────────────────────────────────────────────────────────────────
	t.it("the streak grows on a win or on reaching crossing 5, else resets", function()
		t.expect(HotStreak.after(2, true, 1)).toBe(3)
		t.expect(HotStreak.after(2, false, E.STREAK_CROSSING)).toBe(3)
		t.expect(HotStreak.after(4, false, 2)).toBe(0)
	end)

	t.it("streak multipliers: 1, 1.25, 1.5, 2 and 2 beyond", function()
		t.expect(HotStreak.mult(1)).toBe(1)
		t.expect(HotStreak.mult(2)).toBe(1.25)
		t.expect(HotStreak.mult(3)).toBe(1.5)
		t.expect(HotStreak.mult(9)).toBe(2)
	end)

	-- ── Rewards (§11.1, §13.3, §15.3, F-CALL-02) ────────────────────────────────────────────────────────────────
	t.it("a callout pays its table value; a chain pays per link", function()
		local c = Rewards.callout("ClutchDefuse")
		t.expect(c.xp).toBe(40)
		t.expect(c.stars).toBe(8)
		t.expect(Rewards.callout("Chain", 4).xp).toBe(40)
	end)

	t.it("bot credit halves TAGGED / PASS / BOOM only", function()
		t.expect(Rewards.callout("Boom", nil, true).xp).toBe(10)
		t.expect(Rewards.callout("Defused", nil, true).xp).toBe(15)
	end)

	t.it("small private servers halve callout Stars, not XP", function()
		local c = Rewards.callout("RevengePass", nil, false, true)
		t.expect(c.xp).toBe(20)
		t.expect(c.stars).toBe(3) -- 5 x 0.5 rounds to 3
	end)

	t.it("passes stop paying at the cap and repeat pairs pay once per crossing", function()
		t.expect(Rewards.passPays(E.PASS_PAID_PER_ROUND, {}, "a>b#1")).toBe(false)
		t.expect(Rewards.passPays(0, { ["a>b#1"] = true }, "a>b#1")).toBe(false)
		t.expect(Rewards.passPays(0, { ["a>b#1"] = true }, "a>b#2")).toBe(true)
	end)

	t.it("the squad bonus is +10 % per friend up to +30 %", function()
		t.expect(Rewards.squad(2)).near(0.2)
		t.expect(Rewards.squad(7)).near(E.SQUAD_CAP)
	end)

	t.it("round Stars obey the balance cap (F-ECO-03)", function()
		t.expect(Rewards.roundStars(100, 1.5, 0.2)).toBe(180)
		t.expect(Rewards.roundStars(500, 2, 0.3)).toBe(E.ROUND_STARS_CAP)
	end)

	t.it("round keys: a Last Stand win pays its own key plus the first win of the day", function()
		local keys = Rewards.roundKeys("LastStand", true, false, true)
		t.expect(table.find(keys, "LastStandWin") ~= nil).truthy()
		t.expect(table.find(keys, "FirstWinOfDay") ~= nil).truthy()
		t.expect(#Rewards.roundKeys("Bombers", false, false, true)).toBe(1)
	end)

	-- ── Quests (§14.1) ──────────────────────────────────────────────────────────────────────────────────────────
	t.it("a draw has one quest per tier and never one whose feature is missing", function()
		local list = Quests.draw({}, {}, Random.new(1))
		t.expect(#list).toBe(3)
		for i, e in ipairs(list) do
			local q = Quests.def(e.id)
			t.expect(q ~= nil and q.tier == D.TIERS[i]).truthy()
			t.expect(q ~= nil and q.requires == nil).truthy()
		end
	end)

	t.it("yesterday's quests are not drawn again", function()
		for seed = 1, 20 do
			local first = Quests.draw({}, {}, Random.new(seed))
			local ids = {}
			for _, e in ipairs(first) do
				table.insert(ids, e.id)
			end
			for _, e in ipairs(Quests.draw({}, ids, Random.new(seed + 100))) do
				t.expect(table.find(ids, e.id) == nil).truthy()
			end
		end
	end)

	t.it("progress counts the matching event and completes at the target", function()
		local list = { { id = "E_Pass", progress = 9, done = false, paid = false } }
		t.expect(#Quests.progress(list, "Tag")).toBe(0)
		local done = Quests.progress(list, "Pass")
		t.expect(done[1]).toBe(1)
		t.expect(list[1].done).truthy()
		t.expect(#Quests.progress(list, "Pass")).toBe(0) -- no double completion
	end)

	t.it("a reroll swaps for a different quest of the same tier", function()
		local list = Quests.draw({}, {}, Random.new(3))
		local before = list[2].id
		t.expect(Quests.reroll(list, 2, {}, Random.new(4))).truthy()
		t.expect(list[2].id ~= before).truthy()
		t.expect((Quests.def(list[2].id) :: any).tier).toBe("Medium")
	end)

	-- ── Daily (§14.2, §14.3) ────────────────────────────────────────────────────────────────────────────────────
	t.it("login: consecutive days climb, a missed day drops back 2", function()
		t.expect(Daily.loginDay(0, 0, 500)).toBe(1)
		t.expect(Daily.loginDay(499, 3, 500)).toBe(4)
		local day, missed = Daily.loginDay(497, 5, 500)
		t.expect(day).toBe(4)
		t.expect(missed).truthy()
		t.expect(Daily.loginDay(400, 1, 500)).toBe(1) -- never below day 1
	end)

	t.it("calendar rewards loop days 4-7 after day 7", function()
		t.expect(Daily.rewardIndex(7)).toBe(7)
		t.expect(Daily.rewardIndex(8)).toBe(D.LOOP_FROM)
		t.expect(Daily.rewardIndex(11)).toBe(7)
		t.expect(Daily.rewardIndex(12)).toBe(D.LOOP_FROM)
	end)

	t.it("playtime gifts: the next unclaimed milestone and its countdown", function()
		local i, ready, left = Daily.nextGift(4 * 60, {})
		t.expect(i).toBe(1)
		t.expect(ready).toBe(false)
		t.expect(left).toBe(60)
		local i2, ready2 = Daily.nextGift(31 * 60, { ["1"] = true, ["2"] = true })
		t.expect(i2).toBe(3)
		t.expect(ready2).truthy()
		local m = Daily.gift(#D.GIFTS + 2)
		t.expect(m).toBe(D.GIFTS[#D.GIFTS].minutes + 2 * D.REPEAT_EVERY)
	end)

	-- ── ProfileSchema (§24.3) ───────────────────────────────────────────────────────────────────────────────────
	t.it("a garbage profile becomes a fresh v1 one", function()
		local d = ProfileSchema.reconcile("nonsense")
		t.expect(d.version).toBe(1)
		t.expect(d.level).toBe(1)
		t.expect(type(d.daily.quests)).toBe("table")
	end)

	t.it("reconcile keeps valid data and repairs the rest", function()
		local d = ProfileSchema.reconcile({ level = 7, stars = "lots", stats = { wins = 3 }, inventory = { A = true } })
		t.expect(d.level).toBe(7)
		t.expect(d.stars).toBe(0)
		t.expect(d.stats.wins).toBe(3)
		t.expect(d.stats.defuses).toBe(0)
		t.expect(d.inventory.A).truthy()
	end)
end
