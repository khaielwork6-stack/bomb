--!strict
-- Specs for Logic/BotNames: bot names follow Roblox's username rules, never repeat, and look like real names (a mix
-- of digits, underscores and casing — not one adjective-noun template).

local ServerScriptService = game:GetService("ServerScriptService")

local BotNames = require(ServerScriptService.Server.Logic.BotNames)

return function(t)
	local rng = Random.new(7)
	local names: { string } = {}
	local taken: { [string]: boolean } = {}
	for _ = 1, 2000 do
		local n = BotNames.generate(rng, taken)
		taken[string.lower(n)] = true
		table.insert(names, n)
	end

	t.it("every name is a legal Roblox username (3-20, letters/digits, ≤1 underscore, not at the ends)", function()
		local bad = 0
		for _, n in ipairs(names) do
			if not BotNames.legal(n) then
				bad += 1
			end
		end
		t.expect(bad).toBe(0)
	end)

	t.it("2000 names never repeat (ignoring case)", function()
		local seen: { [string]: boolean } = {}
		local dupes = 0
		for _, n in ipairs(names) do
			local k = string.lower(n)
			if seen[k] then
				dupes += 1
			end
			seen[k] = true
		end
		t.expect(dupes).toBe(0)
	end)

	t.it("a realistic mix: some digits, some underscores, some capitals, some all lower-case", function()
		local digits, under, caps, lower = 0, 0, 0, 0
		for _, n in ipairs(names) do
			if string.find(n, "%d") then
				digits += 1
			end
			if string.find(n, "_", 1, true) then
				under += 1
			end
			if string.find(n, "%u") then
				caps += 1
			end
			if n == string.lower(n) then
				lower += 1
			end
		end
		t.expect(digits > 600 and digits < 1700).toBe(true)
		t.expect(under > 100 and under < 900).toBe(true)
		t.expect(caps > 600).toBe(true)
		t.expect(lower > 200).toBe(true)
	end)

	t.it("the filter rejects illegal or blocked names", function()
		t.expect(BotNames.legal("_kai")).toBe(false)
		t.expect(BotNames.legal("kai_")).toBe(false)
		t.expect(BotNames.legal("a_b_c")).toBe(false)
		t.expect(BotNames.legal("ab")).toBe(false)
		t.expect(BotNames.legal("kai!x")).toBe(false)
		t.expect(BotNames.legal("ghostwolf2012")).toBe(true)
	end)
end
