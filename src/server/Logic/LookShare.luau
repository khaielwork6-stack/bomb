--!strict
-- How many bots wear each human's friends (D-LOBBY-02), as a pure function; Tests/LookShare.spec covers it.
-- The bots are split evenly between the humans who have friends to show; a human with none (no friends, or a private
-- list) gets no share and their part goes to the others. When the split isn't exact, the extra bots go to `rotate`'s
-- turn in the list, so the same player doesn't always get the bigger share.
-- Implements: F-BOT-01 (looks), D-LOBBY-02.

local LookShare = {}

-- owners: the humans here (user ids, in a stable order); bots: how many bots; canShow[owner]: they have friends' looks
-- to give; rotate: a counter that moves the remainder round (e.g. the round number). Returns owner → bot count.
function LookShare.shares(
	owners: { number },
	bots: number,
	canShow: { [number]: boolean },
	rotate: number
): { [number]: number }
	local eligible = {}
	for _, o in ipairs(owners) do
		if canShow[o] then
			table.insert(eligible, o)
		end
	end
	local out: { [number]: number } = {}
	for _, o in ipairs(owners) do
		out[o] = 0
	end
	local n = #eligible
	if n == 0 or bots <= 0 then
		return out
	end
	local base = bots // n
	local extra = bots % n
	for i, o in ipairs(eligible) do
		-- the remainder goes to `extra` players starting at this rotation's turn
		local turn = (i - 1 - rotate) % n
		out[o] = base + (if turn < extra then 1 else 0)
	end
	return out
end

return LookShare
