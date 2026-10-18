--!strict
-- Specs for Logic/LookShare (D-LOBBY-02): the bots split evenly between the humans' friends.

local ServerScriptService = game:GetService("ServerScriptService")

local LookShare = require(ServerScriptService.Server.Logic.LookShare)

local function all(owners: { number }): { [number]: boolean }
	local t = {}
	for _, o in ipairs(owners) do
		t[o] = true
	end
	return t
end

local function total(s: { [number]: number }): number
	local n = 0
	for _, v in pairs(s) do
		n += v
	end
	return n
end

return function(t)
	t.it("4 players, 12 bots: 3 each", function()
		local owners = { 1, 2, 3, 4 }
		local s = LookShare.shares(owners, 12, all(owners), 0)
		for _, o in ipairs(owners) do
			t.expect(s[o]).toBe(3)
		end
	end)

	t.it("2 players, 14 bots: half each", function()
		local s = LookShare.shares({ 1, 2 }, 14, all({ 1, 2 }), 0)
		t.expect(s[1]).toBe(7)
		t.expect(s[2]).toBe(7)
	end)

	t.it("an uneven split differs by at most one, and the extra bot rotates", function()
		local owners = { 1, 2, 3, 4 }
		local got: { [number]: number } = {}
		for round = 0, 3 do
			local s = LookShare.shares(owners, 13, all(owners), round)
			t.expect(total(s)).toBe(13)
			local hi, lo = 0, math.huge
			for _, o in ipairs(owners) do
				hi, lo = math.max(hi, s[o]), math.min(lo, s[o])
				if s[o] == 4 then
					got[o] = (got[o] or 0) + 1
				end
			end
			t.expect(hi - lo <= 1).truthy()
		end
		for _, o in ipairs(owners) do
			t.expect(got[o]).toBe(1) -- over 4 rounds, everyone gets the bigger share once
		end
	end)

	t.it("a player with no friends to show gives their share to the others", function()
		local s = LookShare.shares({ 1, 2, 3, 4 }, 12, { [1] = true, [2] = true, [3] = true }, 0)
		t.expect(s[4]).toBe(0)
		t.expect(s[1]).toBe(4)
		t.expect(s[2]).toBe(4)
		t.expect(s[3]).toBe(4)
	end)

	t.it("nobody with friends, or no bots: nothing assigned", function()
		local s = LookShare.shares({ 1, 2 }, 12, {}, 0)
		t.expect(total(s)).toBe(0)
		t.expect(total(LookShare.shares({ 1, 2 }, 0, all({ 1, 2 }), 0))).toBe(0)
	end)
end
