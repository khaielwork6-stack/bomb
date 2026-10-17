--!strict
-- Specs for the store maths (GDD §25.3 CrateRoll): odds over 100k rolls within ±0.5 %, the Inferno pity, duplicates,
-- the policy branch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateRoll = require(ServerScriptService.Server.Logic.CrateRoll)

local St = Config.Store

local POOL = {
	Common = { "C1", "C2" },
	Rare = { "R1", "R2" },
	Epic = { "E1" },
	Legendary = { "L1" },
}

return function(t)
	t.it("Spark Crate odds hold over 100k rolls (±0.5 %)", function()
		local rng = Random.new(42)
		local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0 }
		local n = 100000
		for _ = 1, n do
			local r = CrateRoll.rarity(St.CRATES.Spark.odds, rng:NextNumber())
			counts[r] += 1
		end
		for k, p in pairs(St.CRATES.Spark.odds) do
			t.expect(math.abs(counts[k] / n - p) < 0.005).truthy()
		end
	end)

	t.it("Inferno never rolls a Common", function()
		local rng = Random.new(7)
		for _ = 1, 5000 do
			t.expect(CrateRoll.rarity(St.CRATES.Inferno.odds, rng:NextNumber()) ~= "Common").truthy()
		end
	end)

	t.it("Inferno pity: an Epic or better within any 8 openings", function()
		local crate = St.CRATES.Inferno
		for seed = 1, 200 do
			local rng = Random.new(seed)
			local pity, sinceEpic = 0, 0
			for _ = 1, 40 do
				local res = CrateRoll.open(crate, POOL, {}, pity, rng)
				pity = res.pity
				if res.rarity == "Epic" or res.rarity == "Legendary" then
					sinceEpic = 0
				else
					sinceEpic += 1
				end
				t.expect(sinceEpic < crate.pity).truthy()
			end
		end
	end)

	t.it("a duplicate refunds half the item's Stars price", function()
		local res = CrateRoll.open(St.CRATES.Spark, { Common = { "C1" } }, { C1 = true }, 0, Random.new(1))
		t.expect(res.duplicate).truthy()
		t.expect(res.refund).toBe(math.floor(St.PRICE.Common * St.DUPLICATE_REFUND))
	end)

	t.it("a rarity with nothing in the pool falls back instead of rolling empty", function()
		local res = CrateRoll.open(St.CRATES.Spark, { Rare = { "R1" } }, {}, 0, Random.new(3))
		t.expect(res.item).toBe("R1")
	end)

	t.it("policy branch: the fixed list is deterministic and cycles", function()
		local a = CrateRoll.fixed(POOL, St.CRATES.Spark, 0)
		local b = CrateRoll.fixed(POOL, St.CRATES.Spark, 0)
		local c = CrateRoll.fixed(POOL, St.CRATES.Spark, 1)
		t.expect(a.item).toBe(b.item)
		t.expect(a.item ~= c.item).truthy()
	end)
end
