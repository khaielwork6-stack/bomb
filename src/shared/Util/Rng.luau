--!strict
-- Seeded RNG helpers. Same seed => same results on server and clients (modifier placements).

local Rng = {}

function Rng.new(seed: number?): Random
	return Random.new(seed or os.clock() * 1e6)
end

function Rng.pick<T>(r: Random, list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[r:NextInteger(1, #list)]
end

-- entries: { {item, weight}... } or map item -> weight via weighted(r, map)
function Rng.weighted<T>(r: Random, entries: { [T]: number }): T?
	local total = 0
	for _, w in pairs(entries) do
		total += math.max(w, 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = r:NextNumber() * total
	local last: T? = nil
	for item, w in pairs(entries) do
		if w > 0 then
			last = item
			roll -= w
			if roll <= 0 then
				return item
			end
		end
	end
	return last
end

function Rng.shuffle<T>(r: Random, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = r:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
