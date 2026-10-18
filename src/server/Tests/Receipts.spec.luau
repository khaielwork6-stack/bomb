--!strict
-- Specs for idempotent Robux receipts (GDD §22.2 F-SEC-04, Logic/Receipts): one grant per purchase id, granted only
-- once a save holding it succeeded, retries after a failed save never grant twice, the id history stays capped.

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ServerScriptService.Server.Logic.ProfileSchema)
local Receipts = require(ServerScriptService.Server.Logic.Receipts)

local KEEP = 200

return function(t)
	t.it("a new purchase grants once and is granted after the save", function()
		local d = ProfileSchema.new()
		local grants, saves = 0, 0
		local ok = Receipts.process(d, "P1", KEEP, function()
			grants += 1
		end, function()
			saves += 1
			return true
		end)
		t.expect(ok).truthy()
		t.expect(grants).toBe(1)
		t.expect(saves).toBe(1)
		t.expect(table.find(d.receipts, "P1") ~= nil).truthy()
	end)

	t.it("a retry of a granted purchase never grants again", function()
		local d = ProfileSchema.new()
		local grants = 0
		local function grant()
			grants += 1
		end
		local function save()
			return true
		end
		Receipts.process(d, "P1", KEEP, grant, save)
		t.expect(Receipts.process(d, "P1", KEEP, grant, save)).truthy()
		t.expect(Receipts.process(d, "P1", KEEP, grant, save)).truthy()
		t.expect(grants).toBe(1)
	end)

	t.it("a failed save reports not processed; the retry saves again without a second grant", function()
		local d = ProfileSchema.new()
		local grants, saveOk = 0, false
		local function grant()
			grants += 1
		end
		local function save()
			return saveOk
		end
		t.expect(Receipts.process(d, "P1", KEEP, grant, save)).falsy()
		t.expect(Receipts.process(d, "P1", KEEP, grant, save)).falsy()
		saveOk = true
		t.expect(Receipts.process(d, "P1", KEEP, grant, save)).truthy()
		t.expect(grants).toBe(1)
	end)

	t.it("a profile reloaded without the receipt (the save never landed) grants on the retry", function()
		local d = ProfileSchema.new()
		local grants = 0
		local function grant()
			grants += 1
		end
		Receipts.process(d, "P1", KEEP, grant, function()
			return false
		end)
		local reloaded = ProfileSchema.new() -- what the store still holds
		t.expect(Receipts.process(reloaded, "P1", KEEP, grant, function()
			return true
		end)).truthy()
		t.expect(grants).toBe(2) -- once per copy; only the saved one counts
	end)

	t.it("different purchases of the same product each grant", function()
		local d = ProfileSchema.new()
		local grants = 0
		for i = 1, 5 do
			Receipts.process(d, "P" .. i, KEEP, function()
				grants += 1
			end, function()
				return true
			end)
		end
		t.expect(grants).toBe(5)
	end)

	t.it("the receipt history keeps the newest ids, capped", function()
		local d = ProfileSchema.new()
		for i = 1, KEEP + 25 do
			Receipts.process(d, "P" .. i, KEEP, function() end, function()
				return true
			end)
		end
		t.expect(#d.receipts).toBe(KEEP)
		t.expect(d.receipts[#d.receipts]).toBe("P" .. (KEEP + 25))
		t.expect(table.find(d.receipts, "P1") == nil).truthy()
	end)

	t.it("receipts survive a reconcile (the saved profile keeps them)", function()
		local d = ProfileSchema.new()
		Receipts.process(d, "P9", KEEP, function() end, function()
			return true
		end)
		local again = ProfileSchema.reconcile(d)
		t.expect(table.find(again.receipts, "P9") ~= nil).truthy()
	end)
end
