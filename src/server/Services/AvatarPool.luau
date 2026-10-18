--!strict
-- Real avatars for bots and the crowd (2026-10-06). Never someone who is in this server. Candidates:
--   • friends of the players in this server (Players:GetFriendsAsync) — the crowd AND the bots draw from these first;
--   • random Roblox users: random user ids, kept only when the avatar is actually dressed (clothes + hair or a hat),
--     the filler once friends run out;
--   • people who recently played FUSE VALLEY in any server (a shared MemoryStore list, kept for a week);
--   • nothing: callers fall back to the generated look.
-- A crowd template is built once per look; the stands reuse templates (2026-10-07) so every seat is a real avatar.
-- Everything slow happens in the background: descriptions are fetched and R6 rigs are built ahead of time, so a
-- match never waits on the avatar service. Rigs are tidied for gameplay: no scripts, at most MAX_ACCESSORIES
-- accessories (hair first), nothing oversized (giant wings or props would hide the field or the bot's role).
-- Bots keep their generated names, so nobody is impersonated: only the look is borrowed.
-- D-LOBBY-02 (the user's call): friends are kept per player and every look remembers whose friend it is (`owner`),
-- so BotService can split the bots evenly between the humans here (2 players → half wear each one's friends).
-- Random fillers waiting in the pool make room as soon as friends can replace them.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local AvatarPool = {}

local STORE_NAME = "FV_RecentAvatars_v1"
local STORE_TTL = 7 * 24 * 3600
local RECENT_READ = 200 -- most recent players read back from the shared list
local MAX_FRIENDS = 150 -- friends read per player
local READY_RIGS = 18 -- bot rigs kept built and waiting
local CROWD_TEMPLATES = 0 -- FUSE VALLEY has no stands (the Last Stand crowd is audio, GDD §8.2): bots only
local RANDOM_MIN, RANDOM_MAX = 20_000_000, 4_000_000_000 -- random user id range (older accounts dress up more)
local MAX_ACCESSORIES = 4
local MAX_ACCESSORY_SIZE = 4.5 -- studs, any dimension of an accessory's handle
local FETCH_GAP = 0.35 -- seconds between avatar-service calls (stay well inside the rate limits)

type Entry = { userId: number, desc: HumanoidDescription, forCrowd: boolean, owner: number? }

local friendsOf: { [number]: { number } } = {} -- player userId → their friends' ids, shuffled, not yet tried
local recent: { number } = {}
local tried: { [number]: boolean } = {} -- fetched (or failed) this session
local inUse: { [number]: boolean } = {} -- worn by a live bot / crowd template right now
local descs: { Entry } = {} -- fetched, not built yet
type Rig = { userId: number, model: Model, desc: HumanoidDescription, owner: number? }
local rigs: { Rig } = {}
local store: MemoryStoreSortedMap? = nil
local rigFolder: Folder
local crowdFolder: Folder

local function shuffle(list: { number })
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function inServer(userId: number): boolean
	return Players:GetPlayerByUserId(userId) ~= nil
end

local randomRng = Random.new()
local function usable(id: number): boolean
	return id > 0 and not tried[id] and not inUse[id] and not inServer(id)
end

-- A random user id worth trying (one per call; the fetch decides whether it's a real, dressed avatar).
local function randomCandidate(): number?
	for _ = 1, 8 do
		local id = randomRng:NextInteger(RANDOM_MIN, RANDOM_MAX)
		if usable(id) then
			return id
		end
	end
	return nil
end

-- Worth showing: some clothing and some hair or headwear (default avatars and blank accounts are skipped).
local function dressed(desc: HumanoidDescription): boolean
	local clothes = desc.Shirt ~= 0 or desc.Pants ~= 0 or desc.GraphicTShirt ~= 0
	local head = desc.HairAccessory ~= "" or desc.HatAccessory ~= ""
	return clothes and head
end

-- Not a blank rig: classic clothing or hair / headwear (friends' looks count with less; layered clothing doesn't
-- show on R6, and a default, undressed avatar would read as a placeholder in the stands).
local function wearsSomething(desc: HumanoidDescription): boolean
	return desc.Shirt ~= 0
		or desc.Pants ~= 0
		or desc.GraphicTShirt ~= 0
		or desc.HairAccessory ~= ""
		or desc.HatAccessory ~= ""
end

local function pop(list: { number }): number?
	while #list > 0 do
		local id = table.remove(list, #list) :: number
		if id > 0 and not tried[id] and not inUse[id] and not inServer(id) then
			return id
		end
	end
	return nil
end

-- Looks of each player's friends that are built or being fetched (balances the next fetch).
local function pending(owner: number): number
	local n = 0
	for _, r in ipairs(rigs) do
		if r.owner == owner then
			n += 1
		end
	end
	for _, e in ipairs(descs) do
		if e.owner == owner then
			n += 1
		end
	end
	return n
end

-- Next candidate: a friend of the player here with the fewest looks waiting (so every player's friends are ready
-- in equal numbers), then recent players. Returns the id and whose friend it is.
local function nextCandidate(): (number?, number?)
	local best: number? = nil
	local bestN = math.huge
	for owner, list in pairs(friendsOf) do
		if inServer(owner) and #list > 0 then
			local n = pending(owner)
			if n < bestN then
				best, bestN = owner, n
			end
		end
	end
	if best then
		local id = pop(friendsOf[best])
		if id then
			return id, best
		end
	end
	return pop(recent), nil
end

local function hasFriendCandidates(): boolean
	for owner, list in pairs(friendsOf) do
		if inServer(owner) and #list > 0 then
			return true
		end
	end
	return false
end

local function readFriends(player: Player)
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		return
	end
	local found = {}
	while #found < MAX_FRIENDS do
		for _, item in ipairs((pages :: FriendPages):GetCurrentPage()) do
			if type(item.Id) == "number" then
				table.insert(found, item.Id)
			end
		end
		if (pages :: FriendPages).IsFinished then
			break
		end
		local advanced = pcall(function()
			(pages :: FriendPages):AdvanceToNextPageAsync()
		end)
		if not advanced then
			break
		end
	end
	shuffle(found)
	friendsOf[player.UserId] = found
end

local function readRecent()
	if not store then
		return
	end
	local ok, items = pcall(function()
		return (store :: MemoryStoreSortedMap):GetRangeAsync(Enum.SortDirection.Descending, RECENT_READ)
	end)
	if not ok or type(items) ~= "table" then
		return
	end
	local found = {}
	for _, item in ipairs(items :: any) do
		local id = tonumber(item.value)
		if id then
			table.insert(found, id)
		end
	end
	shuffle(found)
	recent = found
end

local function recordPlayer(player: Player)
	if not store or player.UserId <= 0 then
		return
	end
	pcall(function()
		(store :: MemoryStoreSortedMap):SetAsync(tostring(player.UserId), player.UserId, STORE_TTL, os.time())
	end)
end

-- Gameplay-safe rig: scripts out, accessories capped and nothing huge, every accessory massless and inert.
function AvatarPool.tidy(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local keep = {}
	for _, acc in ipairs(model:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local big = not handle
				or not handle:IsA("BasePart")
				or math.max(handle.Size.X, handle.Size.Y, handle.Size.Z) > MAX_ACCESSORY_SIZE
			if big then
				acc:Destroy()
			else
				table.insert(keep, acc)
			end
		end
	end
	-- Hair reads as "who this is"; keep it first, then hats, then the rest.
	local rank = { [Enum.AccessoryType.Hair] = 0, [Enum.AccessoryType.Hat] = 1, [Enum.AccessoryType.Face] = 2 }
	table.sort(keep, function(a: Accessory, b: Accessory)
		return (rank[a.AccessoryType] or 3) < (rank[b.AccessoryType] or 3)
	end)
	for i, acc in ipairs(keep) do
		if i > MAX_ACCESSORIES then
			acc:Destroy()
		else
			local handle = acc:FindFirstChild("Handle") :: BasePart
			handle.Massless = true
			handle.CanCollide = false
			handle.CanQuery = false
			handle.CanTouch = false
		end
	end
end

-- A rig built outside the workspace never runs its welds: the body's Motor6Ds come out exact, but accessory
-- handles stay wherever they were made (tens to hundreds of studs off). Crowd templates are anchored as they are,
-- so their hair and hats would float over the map. Put each handle where its weld says (Part0·C0 = Part1·C1).
local function seatAccessories(model: Model)
	for _, acc in ipairs(model:GetChildren()) do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		local joint = handle and handle:FindFirstChildWhichIsA("JointInstance") :: any
		if handle and handle:IsA("BasePart") and joint then
			if joint.Part0 == handle and joint.Part1 then
				handle.CFrame = joint.Part1.CFrame * joint.C1 * joint.C0:Inverse()
			elseif joint.Part1 == handle and joint.Part0 then
				handle.CFrame = joint.Part0.CFrame * joint.C0 * joint.C1:Inverse()
			end
		end
	end
end

local function build(entry: Entry): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(entry.desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		return nil
	end
	AvatarPool.tidy(model :: Model)
	seatAccessories(model :: Model)
	return model :: Model
end

-- Crowd template: a still, inert copy for clients to place in the stands (CrowdController moves the parts).
local function asCrowdTemplate(model: Model, userId: number)
	-- Never a blank rig in the stands: a build that came out wearing nothing is dropped (another avatar is fetched).
	if
		not (
			model:FindFirstChildOfClass("Shirt")
			or model:FindFirstChildOfClass("Pants")
			or model:FindFirstChildOfClass("ShirtGraphic")
			or model:FindFirstChildOfClass("Accessory")
		)
	then
		model:Destroy()
		return
	end
	model.Name = "Fan_" .. userId
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.EvaluateStateMachine = false
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy()
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	model.Parent = crowdFolder
end

local crowdBuilding = 0 -- crowd templates being built right now (two workers)

-- One step of background work (two workers run this). Wanted: READY_RIGS bot rigs and CROWD_TEMPLATES crowd
-- avatars. One build or one fetch per call. Bots are served first; the crowd draws random dressed avatars first and the
-- bots friends / recent players first, each falling back to the other source.
local function work(): boolean
	-- a random filler waiting in the pool makes room for a friend's look (D-LOBBY-02)
	if #rigs >= READY_RIGS and hasFriendCandidates() then
		for i, r in ipairs(rigs) do
			if not r.owner then
				r.model:Destroy()
				table.remove(rigs, i)
				break
			end
		end
	end
	local rigsShort = READY_RIGS - #rigs
	local crowdShort = CROWD_TEMPLATES - #crowdFolder:GetChildren() - crowdBuilding
	if rigsShort <= 0 and crowdShort <= 0 then
		return false
	end
	local forCrowd = rigsShort <= 0
	for i, entry in ipairs(descs) do
		if entry.forCrowd == forCrowd then
			table.remove(descs, i)
			if forCrowd then
				crowdBuilding += 1
			end
			local model = build(entry)
			if forCrowd then
				crowdBuilding -= 1
			end
			if model then
				inUse[entry.userId] = true
				if forCrowd then
					asCrowdTemplate(model, entry.userId)
				else
					model.Name = "Avatar_" .. entry.userId
					model.Parent = rigFolder
					table.insert(rigs, { userId = entry.userId, model = model, desc = entry.desc, owner = entry.owner })
					inUse[entry.userId] = nil -- reserved again when a bot takes it
				end
			end
			return true
		end
	end
	-- friends of the players here first (balanced between them), recent players, then dressed random players
	local id, owner = nextCandidate()
	local random = false
	if not id then
		id, random = randomCandidate(), true
	end
	if not id then
		return false
	end
	tried[id] = true
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(id)
	end)
	local keep = ok
		and desc
		and (
			if random
				then dressed(desc :: HumanoidDescription)
				else not forCrowd or wearsSomething(desc :: HumanoidDescription)
		)
	if keep then
		table.insert(descs, { userId = id, desc = desc :: HumanoidDescription, forCrowd = forCrowd, owner = owner })
	end
	return true
end

-- A built rig wearing a real avatar for a new bot (nil = none ready: use the generated look). `prefer` = a player
-- whose friends' look is wanted (D-LOBBY-02); otherwise any friend's look before a random one. Returns the model, its
-- description (Cardboard Cutout and replays copy it), the avatar's user id and whose friend it is (nil = a filler).
function AvatarPool.takeRig(prefer: number?): (Model?, HumanoidDescription?, number?, number?)
	-- (2026-10-07, the user saw a bot wearing their own avatar.) A rig built before its owner joined (a friend's
	-- friend list, the recent-players list) is never handed out once they're here.
	for i = #rigs, 1, -1 do
		if inServer(rigs[i].userId) then
			rigs[i].model:Destroy()
			table.remove(rigs, i)
		end
	end
	local pick: number? = nil
	for i, r in ipairs(rigs) do
		if prefer then
			if r.owner == prefer then
				pick = i
				break
			end
		elseif r.owner and inServer(r.owner) then
			pick = i
			break
		end
	end
	if not pick and not prefer and #rigs > 0 then
		pick = 1
	end
	if not pick then
		return nil, nil, nil, nil
	end
	local r = table.remove(rigs, pick) :: Rig
	inUse[r.userId] = true
	return r.model, r.desc, r.userId, r.owner
end

-- Does this player have friends' looks to give (some left to fetch, or built and waiting)? A player with no friends
-- (or a private list) has none, and BotService gives their share of the bots to the others (D-LOBBY-02).
function AvatarPool.hasFriends(owner: number): boolean
	local list = friendsOf[owner]
	if list and #list > 0 then
		return true
	end
	for _, r in ipairs(rigs) do
		if r.owner == owner then
			return true
		end
	end
	return false
end

-- How many built looks of this player's friends are waiting.
function AvatarPool.readyFor(owner: number): number
	local n = 0
	for _, r in ipairs(rigs) do
		if r.owner == owner and not inServer(r.userId) then
			n += 1
		end
	end
	return n
end

-- Someone joined: drop every look of theirs waiting in the pool (fetched, built, or in the stands).
function AvatarPool.forget(userId: number)
	tried[userId] = true
	for i = #descs, 1, -1 do
		if descs[i].userId == userId then
			table.remove(descs, i)
		end
	end
	for i = #rigs, 1, -1 do
		if rigs[i].userId == userId then
			rigs[i].model:Destroy()
			table.remove(rigs, i)
		end
	end
	local fan = crowdFolder and crowdFolder:FindFirstChild("Fan_" .. userId)
	if fan then
		fan:Destroy()
	end
end

-- A bot wearing this avatar left: the look may be borrowed again later.
function AvatarPool.release(userId: number?)
	if userId then
		inUse[userId] = nil
		tried[userId] = nil
	end
end

function AvatarPool.readyCount(): number
	return #rigs
end

function AvatarPool.init()
	rigFolder = Instance.new("Folder")
	rigFolder.Name = "CG_AvatarRigs"
	rigFolder.Parent = ServerStorage
	crowdFolder = Instance.new("Folder")
	crowdFolder.Name = "CG_CrowdAvatars"
	crowdFolder.Parent = game:GetService("ReplicatedStorage")
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(STORE_NAME)
	end)
	store = if ok then map else nil
end

function AvatarPool.start()
	local function joined(player: Player)
		AvatarPool.forget(player.UserId)
		task.spawn(recordPlayer, player)
		task.spawn(readFriends, player)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	task.spawn(function()
		readRecent()
		while true do
			task.wait(120)
			readRecent()
		end
	end)
	-- Two workers: fetching and building both wait on the network, so this halves the time to a full pool. For the
	-- first minute two more help (2026-10-08: a fresh server's first players should meet real-looking bots, which
	-- BotService.fillLobby waits for).
	for w = 1, 4 do
		task.spawn(function()
			task.wait(w * 0.2)
			local startup = w > 2
			local t0 = os.clock()
			while not startup or os.clock() - t0 < 60 do
				local busy = false
				local ok, err = pcall(function()
					busy = work()
				end)
				if not ok then
					warn("[AvatarPool]", err)
				end
				task.wait(if busy then FETCH_GAP else 2)
			end
		end)
	end
end

return AvatarPool
