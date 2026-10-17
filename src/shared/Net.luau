--!strict
-- Remote contract. GDD §21.4 / §22.1. Server creates remotes at boot; clients wait for them.
-- Client->server handlers are rate-limited per player with a token bucket (rate = events/sec, burst = 2x rate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- name -> events per second allowed
Net.ClientToServer = {
	ClientReady = 1,
	RequestSwing = 4,
	RequestDive = 1.5,
	RequestDash = 2,
	Look = 12, -- head look (camera vs body), ≈10 / s while it changes
	MovementTech = 6,
	RequestAbility = 2,
	PickRunner = 2,
	ChooseBraveBail = 2,
	VoteMap = 2,
	SetAFK = 3,
	CrowdReact = 1.34,
	EquipItem = 5,
	BuyWithStars = 1,
	CourseEvent = 2,
	TipSeen = 2,
	BuyRobux = 1,
	SkipCinematic = 2,
	SaveSettings = 1,
	Admin = 4,
	Spin = 1,
	RewardClaim = 1,
	RewardCheck = 0.5,
	CrateOpen = 1,
	TitanSlam = 3, -- the Titan's slam request (TitanService)
	TitanStomp = 3, -- the Titan's stomp request (TitanService)
	TitanCharge = 15, -- the Titan's charge request + steering while it runs (TitanService)
	TitanDev = 1, -- dev button: summon a hunt now (allowlisted)
}

Net.ServerToClient = {
	"Feed",
	"Headline",
	"Popup",
	"Toast",
	"CatchConfirmed",
	"ActionFx",
	"AbilityFx",
	"StatusChanged",
	"Ragdoll",
	"ModifierRevealed",
	"HazardSchedule",
	"TierChanged",
	"Cinematic",
	"ModifierEvent",
	"ReplayData",
	"Results",
	"ProfileSync",
	"PickerOpen",
	"ChooserOpen",
	"Sfx",
	"Stars",
	"Leaderboards",
	"Rival",
	"DashCourse",
	"Onboarding",
	"Spin",
	"Rewards",
	"Crate",
	"BotChat", -- a bot says a line (BotChatService): { id, text }
	"TitanFx", -- TITAN HUNT moments: { kind, ... } (TitanService → TitanController)
}

local FOLDER_NAME = "Net"
local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if not f then
			f = Instance.new("Folder")
			assert(f, "folder")
			f.Name = FOLDER_NAME
			f.Parent = ReplicatedStorage
		end
		folder = f
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	return folder :: Folder
end

function Net.init()
	assert(RunService:IsServer(), "Net.init is server-only")
	local f = getFolder()
	local function make(name: string)
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
	end
	for name in pairs(Net.ClientToServer) do
		make(name)
	end
	for _, name in ipairs(Net.ServerToClient) do
		make(name)
	end
end

function Net.get(name: string): RemoteEvent
	local f = getFolder()
	if RunService:IsServer() then
		local r = f:FindFirstChild(name) :: RemoteEvent?
		assert(r, "Unknown remote " .. name)
		return r
	end
	return f:WaitForChild(name) :: RemoteEvent
end

-- Server: listen with rate limiting. Handler receives (player, ...).
local buckets: { [Player]: { [string]: { tokens: number, last: number, violations: number, windowStart: number } } } =
	{}

-- Several services may handle one remote (EquipItem: cosmetics + abilities). They share ONE connection, so one
-- event spends one token and every handler sees it.
local serverHandlers: { [string]: { (Player, ...any) -> () } } = {}

function Net.on(name: string, handler: (Player, ...any) -> ())
	assert(RunService:IsServer())
	local rate = Net.ClientToServer[name]
	assert(rate, "Remote not declared client->server: " .. name)
	local list = serverHandlers[name]
	if list then
		table.insert(list, handler)
		return
	end
	list = { handler }
	serverHandlers[name] = list
	local burst = math.max(2, rate * 2)
	Net.get(name).OnServerEvent:Connect(function(player: Player, ...)
		local pb = buckets[player]
		if not pb then
			pb = {}
			buckets[player] = pb
		end
		local now = os.clock()
		local b = pb[name]
		if not b then
			b = { tokens = burst, last = now, violations = 0, windowStart = now }
			pb[name] = b
		end
		b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
		b.last = now
		if b.tokens < 1 then
			if now - b.windowStart > 60 then
				b.windowStart = now
				b.violations = 0
			end
			b.violations += 1
			if b.violations == 5 then
				warn(`[Net] {player.Name} is spamming {name}`)
			end
			return
		end
		b.tokens -= 1
		for _, fn in ipairs(list :: { (Player, ...any) -> () }) do
			local ok, err = pcall(fn, player, ...)
			if not ok then
				warn(`[Net] handler {name} error:`, err)
			end
		end
	end)
end

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

function Net.fire(player: Player, name: string, ...)
	-- Leavers can still be referenced by in-flight match code; firing to them would throw.
	if player.Parent == nil then
		return
	end
	Net.get(name):FireClient(player, ...)
end

function Net.fireAll(name: string, ...)
	Net.get(name):FireAllClients(...)
end

function Net.fireExcept(except: Player?, name: string, ...)
	local r = Net.get(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= except then
			r:FireClient(p, ...)
		end
	end
end

-- Client
function Net.send(name: string, ...)
	Net.get(name):FireServer(...)
end

function Net.listen(name: string, fn: (...any) -> ()): RBXScriptConnection
	return Net.get(name).OnClientEvent:Connect(fn)
end

-- Validation helpers (server)
function Net.isVec3(v: any, maxMag: number?): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local m = v.Magnitude
	if m ~= m or m == math.huge then
		return false
	end
	return maxMag == nil or m <= maxMag
end

function Net.isNum(v: any, min: number?, max: number?): boolean
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return false
	end
	if min and v < min then
		return false
	end
	if max and v > max then
		return false
	end
	return true
end

function Net.isStr(v: any, maxLen: number?): boolean
	return type(v) == "string" and #v <= (maxLen or 64)
end

return Net
