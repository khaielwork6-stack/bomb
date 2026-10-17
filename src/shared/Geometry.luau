--!strict
-- Pure geometry for hit tests and layout. Implements: F-BONK-04 (reach/arc/vertical), F-ARENA-03 (lane BFS).

local Geometry = {}

local FLAT = Vector3.new(1, 0, 1)

-- Is target within a horizontal cone of `arcDeg` around `facing`, within `reach` (horizontal) and `vertTol` (vertical)?
function Geometry.inCone(
	origin: Vector3,
	facing: Vector3,
	target: Vector3,
	reach: number,
	arcDeg: number,
	vertTol: number
): (boolean, number)
	local delta = target - origin
	if math.abs(delta.Y) > vertTol then
		return false, math.huge
	end
	local flatDelta = delta * FLAT
	local dist = flatDelta.Magnitude
	if dist > reach then
		return false, dist
	end
	if dist < 1.0 then
		return true, dist -- overlapping: always counts
	end
	local f = facing * FLAT
	if f.Magnitude < 1e-4 then
		return false, dist
	end
	local cosHalf = math.cos(math.rad(arcDeg / 2))
	return f.Unit:Dot(flatDelta.Unit) >= cosHalf, dist
end

function Geometry.flatDist(a: Vector3, b: Vector3): number
	return ((a - b) * FLAT).Magnitude
end

-- Flat (XZ) distance from p to the segment a-b, and p's height above the segment at the closest point. Used for
-- body-contact checks (a diving catcher is a capsule from hips to hands, swept between samples).
function Geometry.segmentFlatDist(a: Vector3, b: Vector3, p: Vector3): (number, number)
	local ab = (b - a) * FLAT
	local ap = (p - a) * FLAT
	local len2 = ab:Dot(ab)
	local t = if len2 > 1e-6 then math.clamp(ap:Dot(ab) / len2, 0, 1) else 0
	local closest = a + (b - a) * t
	return ((p - closest) * FLAT).Magnitude, p.Y - closest.Y
end

-- Lane BFS: grid of cols (along length) x rows (along width); blocked[c][r] = true.
-- Returns true if every row can reach the last column from the first column (no lane fully walled).
function Geometry.lanesOpen(cols: number, rows: number, blocked: { [number]: { [number]: boolean } }): boolean
	local function isBlocked(c: number, r: number): boolean
		return blocked[c] ~= nil and blocked[c][r] == true
	end
	local function key(c: number, r: number): number
		return c * 1000 + r
	end
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	-- Every open start cell (each lane) must be able to reach the far column.
	local anyStart = false
	for startRow = 1, rows do
		if isBlocked(1, startRow) then
			continue
		end
		anyStart = true
		local seen: { [number]: boolean } = { [key(1, startRow)] = true }
		local queue: { { number } } = { { 1, startRow } }
		local head = 1
		local reached = false
		while head <= #queue do
			local cell = queue[head]
			head += 1
			if cell[1] == cols then
				reached = true
				break
			end
			for _, d in ipairs(dirs) do
				local nc, nr = cell[1] + d[1], cell[2] + d[2]
				if nc >= 1 and nc <= cols and nr >= 1 and nr <= rows then
					local k = key(nc, nr)
					if not seen[k] and not isBlocked(nc, nr) then
						seen[k] = true
						table.insert(queue, { nc, nr })
					end
				end
			end
		end
		if not reached then
			return false
		end
	end
	return anyStart
end

return Geometry
