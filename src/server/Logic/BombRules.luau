--!strict
-- The bomb's rules as pure functions over plain data (GDD §7). BombService feeds it snapshots of the participants
-- ("bodies") and applies the decisions; the specs in Tests/BombRules.spec cover every rule and §7.7 edge case.
-- Implements: F-BOMB-02 (tag), F-BOMB-03..05 (pass), F-BOMB-06/07 (who it blows on), F-BOMB-09 (clutch),
-- F-FLOW-09/§5.4 (starting Bombers), F-FUSE-01 (field fuse lengths).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local B = Config.Bomb
local R = Config.Round

export type Bomb = {
	id: number,
	carrier: string, -- participant id of the current Carrier
	explodeAt: number, -- server time; never moves (the fuse never resets, F-BOMB-04)
	origin: string?, -- the Bomber who started it (boom credit, F-BOMB-06); nil = no credit
	chain: { string }, -- every Carrier in order (CHAIN callouts, §11.1)
	lastGiver: string?, -- who passed it to the current Carrier (no pass-back)
	receivedAt: number,
	locked: boolean, -- on a Bomber: can't be passed on (F-BOMB-07)
}

-- A participant as the rules see it, snapshotted each step.
export type Body = {
	id: string,
	role: string, -- "Runner" | "Bomber"
	pos: Vector3,
	active: boolean, -- in play and able to act (not ragdolled / stunned / locked)
	safe: boolean, -- inside a Safe Strip
	carrying: boolean,
	tagReadyAt: number, -- Bombers: server time their tag cooldown ends
}

local BombRules = {}

function BombRules.remaining(bomb: Bomb, now: number): number
	return math.max(0, bomb.explodeAt - now)
end

function BombRules.stage(remaining: number): string
	if remaining <= B.STAGE_CRITICAL then
		return "CRITICAL"
	elseif remaining <= B.STAGE_HOT then
		return "HOT"
	end
	return "LIT"
end

-- Body contact: flat distance within `range` (+ the lag slack) and roughly the same height.
function BombRules.inReach(a: Vector3, b: Vector3, range: number): boolean
	if math.abs(a.Y - b.Y) > B.VERTICAL_REACH then
		return false
	end
	local d = (a - b) * Vector3.new(1, 0, 1)
	return d.Magnitude <= range + B.LAG_SLACK
end

local function flatDist(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

-- F-BOMB-02: may this Bomber stick a fresh bomb on this target right now?
function BombRules.canTag(bomber: Body, target: Body, now: number): boolean
	return bomber.role == "Bomber"
		and bomber.active
		and now >= bomber.tagReadyAt
		and target.role == "Runner"
		and target.active
		and not target.safe -- F-CROSS-03: nobody is tagged inside a Safe Strip
		and not target.carrying -- one bomb per Runner; a touch on a Carrier does nothing
		and BombRules.inReach(bomber.pos, target.pos, B.TAG_RANGE)
end

-- F-BOMB-03/05: can this Carrier pass its bomb at all right now?
function BombRules.canPass(bomb: Bomb, carrier: Body, now: number): boolean
	return not bomb.locked
		and carrier.role == "Runner"
		and carrier.active
		and not carrier.safe
		and now - bomb.receivedAt >= B.RECEIVE_GRACE
end

-- F-BOMB-05: is `target` an eligible receiver for this bomb?
function BombRules.canReceive(bomb: Bomb, target: Body, now: number): boolean
	if target.id == bomb.carrier or not target.active or target.safe or target.carrying then
		return false
	end
	if target.id == bomb.lastGiver and now - bomb.receivedAt < B.NO_PASSBACK then
		return false -- no ping-pong
	end
	return target.role == "Runner" or target.role == "Bomber"
end

-- The closest eligible body within `range` of `from` (F-BOMB-03: two in reach → the closest wins).
local function closest(from: Vector3, bodies: { Body }, range: number, ok: (Body) -> boolean): Body?
	local best, bestD = nil, math.huge
	for _, b in ipairs(bodies) do
		if ok(b) and BombRules.inReach(from, b.pos, range) then
			local d = flatDist(from, b.pos)
			if d < bestD then
				best, bestD = b, d
			end
		end
	end
	return best
end

function BombRules.pickReceiver(bomb: Bomb, carrier: Body, bodies: { Body }, now: number): Body?
	if not BombRules.canPass(bomb, carrier, now) then
		return nil
	end
	return closest(carrier.pos, bodies, B.PASS_RANGE, function(b)
		return BombRules.canReceive(bomb, b, now)
	end)
end

function BombRules.pickTagTarget(bomber: Body, bodies: { Body }, now: number): Body?
	if bomber.role ~= "Bomber" or not bomber.active or now < bomber.tagReadyAt then
		return nil
	end
	return closest(bomber.pos, bodies, B.TAG_RANGE, function(b)
		return b.id ~= bomber.id and BombRules.canTag(bomber, b, now)
	end)
end

-- A fresh bomb from a tag.
function BombRules.newBomb(id: number, bomber: Body, target: Body, now: number): Bomb
	return {
		id = id,
		carrier = target.id,
		explodeAt = now + B.FUSE,
		origin = bomber.id,
		chain = { target.id },
		lastGiver = bomber.id,
		receivedAt = now,
		locked = false,
	}
end

-- Apply a pass (mutates `bomb`): the remaining time is untouched (F-BOMB-04).
function BombRules.pass(bomb: Bomb, from: Body, to: Body, now: number)
	bomb.lastGiver = from.id
	bomb.carrier = to.id
	bomb.receivedAt = now
	bomb.locked = to.role == "Bomber"
	if bomb.chain[#bomb.chain] ~= to.id then
		table.insert(bomb.chain, to.id)
	end
end

-- Distinct Carriers this bomb has been through (a CHAIN ×3 needs 3 people, GDD §11.1).
function BombRules.chainLength(bomb: Bomb): number
	local seen, n = {}, 0
	for _, id in ipairs(bomb.chain) do
		if not seen[id] then
			seen[id] = true
			n += 1
		end
	end
	return n
end

function BombRules.isClutch(remaining: number): boolean
	return remaining <= B.CLUTCH_WINDOW
end

-- §5.4: starting Bombers for `n` participants.
function BombRules.bomberCount(n: number): number
	return math.clamp(math.floor(n / R.BOMBERS_PER), 1, R.BOMBERS_MAX)
end

-- F-FUSE-01: the Field Fuse for crossing `k` (1-based); past the list, its last value.
function BombRules.fieldFuse(k: number): number
	local list = R.FIELD_FUSE
	return list[math.clamp(k, 1, #list)]
end

return BombRules
