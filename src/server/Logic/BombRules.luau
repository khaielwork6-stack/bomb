--!strict
-- The bomb's rules as pure functions over plain data (GDD §7). BombService feeds it snapshots of the participants
-- ("bodies") and applies the decisions; the specs in Tests/BombRules.spec cover every rule and §7.7 edge case.
-- Implements: F-BOMB-02 (tag), F-BOMB-03..05 (pass), F-BOMB-06/07 (who it blows on), F-BOMB-09 (clutch),
-- F-FLOW-09/§5.4 (starting Bombers), F-FUSE-01 (field fuse lengths), F-MOD-04 (the Mole's strike is a tag),
-- F-BOMB-11..13 (the Hand-Off: the stage reach, the lunge, the reject).

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
	masked: boolean?, -- READ THE FACE (F-MOD-02): clients don't get the boom time while it's LIT
	shown: boolean?, -- …and it has turned HOT, so they do
	rejectedBy: { [string]: boolean }?, -- F-BOMB-13: who already rejected this bomb (once each)
	flying: number?, -- THROW MODE (GDD §7.4c): the flight it's in (still the thrower's: a miss reels it back)
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
	reach: number?, -- extra contact reach (the MEGA BOMBER's size, GDD §16): its tags, and passes onto it
	mega: boolean?, -- the MEGA BOMBER
	striker: boolean?, -- a Runner whose touch tags right now: the Mole's armed STRIKE (F-MOD-04)
	lungeDir: Vector3?, -- F-BOMB-12: a Carrier mid-dash, its flat dash direction (unit)
	rejectReady: boolean?, -- F-BOMB-13: a Hard Stop inside the reject window, off cooldown
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
	return (bomber.role == "Bomber" or bomber.striker == true)
		and target.id ~= bomber.id
		and bomber.active
		and now >= bomber.tagReadyAt
		and target.role == "Runner"
		and target.active
		and not target.safe -- F-CROSS-03: nobody is tagged inside a Safe Strip
		and not target.carrying -- one bomb per Runner; a touch on a Carrier does nothing
		and BombRules.inReach(bomber.pos, target.pos, B.TAG_RANGE + (bomber.reach or 0))
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
		if ok(b) and BombRules.inReach(from, b.pos, range + (b.reach or 0)) then
			local d = flatDist(from, b.pos)
			if d < bestD then
				best, bestD = b, d
			end
		end
	end
	return best
end

-- F-BOMB-11: the pass reach for this bomb right now (it grows with the fuse stage; the Danger Ring draws it).
function BombRules.passRange(bomb: Bomb, now: number): number
	return (B.PASS_RANGE_STAGE :: any)[BombRules.stage(BombRules.remaining(bomb, now))] or B.PASS_RANGE
end

-- F-BOMB-12: is `pos` inside a lunging Carrier's stretched reach (in the cone, within base + LUNGE_REACH)?
function BombRules.inLunge(carrier: Body, pos: Vector3, base: number, extra: number?): boolean
	local dir = carrier.lungeDir
	if not dir or math.abs(pos.Y - carrier.pos.Y) > B.VERTICAL_REACH then
		return false
	end
	local d = (pos - carrier.pos) * Vector3.new(1, 0, 1)
	if d.Magnitude < 1e-3 then
		return true
	end
	return d.Unit:Dot(dir) >= math.cos(math.rad(B.LUNGE_CONE))
		and d.Magnitude <= base + B.LUNGE_REACH + (extra or 0) + B.LAG_SLACK
end

-- The receiver of a pass right now (the closest eligible body in reach), and whether it's a SLAM PASS (made
-- lunging, F-BOMB-12).
function BombRules.pickReceiver(bomb: Bomb, carrier: Body, bodies: { Body }, now: number): (Body?, boolean)
	if not BombRules.canPass(bomb, carrier, now) then
		return nil, false
	end
	local range = BombRules.passRange(bomb, now)
	local best, bestD = nil, math.huge
	for _, b in ipairs(bodies) do
		if BombRules.canReceive(bomb, b, now) then
			local reach = range + (b.reach or 0)
			if BombRules.inReach(carrier.pos, b.pos, reach) or BombRules.inLunge(carrier, b.pos, reach) then
				local d = flatDist(carrier.pos, b.pos)
				if d < bestD then
					best, bestD = b, d
				end
			end
		end
	end
	return best, best ~= nil and carrier.lungeDir ~= nil
end

-- F-BOMB-15: the Slap-Pass receiver: the closest eligible body in front of `aim` (within PASS_SLAP_CONE°), up to the
-- stage reach + PASS_SLAP_REACH (+ the lag slack). A body right on top of the Carrier counts whatever the aim.
function BombRules.slapReceiver(bomb: Bomb, carrier: Body, aim: Vector3, bodies: { Body }, now: number): Body?
	if not BombRules.canPass(bomb, carrier, now) then
		return nil
	end
	local flatAim = aim * Vector3.new(1, 0, 1)
	if flatAim.Magnitude < 1e-3 then
		return nil
	end
	flatAim = flatAim.Unit
	local range = BombRules.passRange(bomb, now) + B.PASS_SLAP_REACH + B.LAG_SLACK
	local cosCone = math.cos(math.rad(B.PASS_SLAP_CONE))
	local best, bestD = nil, math.huge
	for _, b in ipairs(bodies) do
		if BombRules.canReceive(bomb, b, now) and math.abs(b.pos.Y - carrier.pos.Y) <= B.VERTICAL_REACH then
			local d = (b.pos - carrier.pos) * Vector3.new(1, 0, 1)
			local dist = d.Magnitude
			if dist <= range + (b.reach or 0) and (dist < 1.5 or d.Unit:Dot(flatAim) >= cosCone) and dist < bestD then
				best, bestD = b, dist
			end
		end
	end
	return best
end

-- F-BOMB-13: does this receiver bounce the bomb back (a Hard Stop just before it landed, off cooldown, and they
-- haven't rejected this bomb yet)? A MEGA BOMBER never rejects a feed.
function BombRules.rejects(bomb: Bomb, receiver: Body): boolean
	return receiver.rejectReady == true and not receiver.mega and not (bomb.rejectedBy and bomb.rejectedBy[receiver.id])
end

-- F-BOMB-12: a lunge that's going for someone: an eligible body in the cone within the stretched reach + WHIFF_AIM
-- (the closest one is the target a whiff "dodged"). A dash with nobody in front is an escape, never a whiff.
function BombRules.lungeTarget(bomb: Bomb, carrier: Body, bodies: { Body }, now: number): Body?
	if not carrier.lungeDir then
		return nil
	end
	local range = BombRules.passRange(bomb, now)
	local best, bestD = nil, math.huge
	for _, b in ipairs(bodies) do
		if
			b.id ~= carrier.id
			and b.active
			and not b.safe
			and not b.carrying
			and BombRules.inLunge(carrier, b.pos, range + (b.reach or 0), B.WHIFF_AIM)
		then
			local d = flatDist(carrier.pos, b.pos)
			if d < bestD then
				best, bestD = b, d
			end
		end
	end
	return best
end

-- DODGE! geometry (GDD §11.1): just outside the Bomber's reach — within DODGE_MARGIN of it.
function BombRules.nearMiss(a: Vector3, b: Vector3): boolean
	if math.abs(a.Y - b.Y) > B.VERTICAL_REACH then
		return false
	end
	local d = ((a - b) * Vector3.new(1, 0, 1)).Magnitude
	local reach = B.TAG_RANGE + B.LAG_SLACK
	return d > reach and d <= reach + B.DODGE_MARGIN
end

-- …and clear of it again (the Runner got away).
function BombRules.clearOf(a: Vector3, b: Vector3): boolean
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude > B.TAG_RANGE + B.LAG_SLACK + B.DODGE_CLEAR
end

function BombRules.pickTagTarget(bomber: Body, bodies: { Body }, now: number): Body?
	if (bomber.role ~= "Bomber" and not bomber.striker) or not bomber.active or now < bomber.tagReadyAt then
		return nil
	end
	return closest(bomber.pos, bodies, B.TAG_RANGE + (bomber.reach or 0), function(b)
		return BombRules.canTag(bomber, b, now)
	end)
end

-- A fresh bomb from a tag.
function BombRules.newBomb(id: number, bomber: Body, target: Body, now: number, fuse: number?): Bomb
	return {
		id = id,
		carrier = target.id,
		explodeAt = now + (fuse or B.FUSE),
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
