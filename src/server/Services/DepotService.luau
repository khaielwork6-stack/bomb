--!strict
-- The lobby "The Depot" on the server (GDD §19.1): the leaderboard wall's weekly boards (published to GameState as
-- LB_Wins / LB_Clutches / LB_Booms, JSON lists of { name, value }) and the weekly Wins champions as statues on the
-- plinths (their real avatars, rendered in stone, the #1 in gold), refreshed every BOARD_REFRESH; and the VIP
-- lounge's firework button (VIP pass owners only, one firework per FIREWORK_COOLDOWN for the whole server). The
-- Fuse Range, kiosks, clock tower and plinths are client-side (DepotController). Idle when the place has no lobby.
-- Friend dummies (D-LOBBY-01): each player's Fuse Range dummies wear that player's friends. Avatars can only be built
-- on the server, so it builds them into a ScreenGui in that player's PlayerGui (which replicates to them alone);
-- their DepotController moves them into the world over the padded dummies. Nobody else sees them.
-- Implements: F-LOBBY-01 (leaderboard wall, statues, VIP lounge, Fuse Range dummies), F-SOC-02 (the in-world boards).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local GameState = require(script.Parent.GameState)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Participants = require(script.Parent.Participants)
local StoreService = require(script.Parent.StoreService)

local LC = Config.Lobby
local BOARDS = { "Wins", "Clutches", "Booms" }

local DepotService = {}

local names: { [number]: string } = {}
local statueIds: { number } = {}
local lastFirework = -math.huge

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and type(n) == "string" then n else "Player"
	return names[userId]
end

local function stone(model: Model, gold: boolean)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.Material = if gold then Enum.Material.Foil else Enum.Material.Marble
			d.Color = if gold then Color3.fromRGB(242, 177, 58) else Color3.fromRGB(214, 206, 196)
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Script") then
			d:Destroy()
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
end

-- The weekly Wins champions on the plinths (rebuilt only when the top 3 change).
local function statues(lobby: Model, top: { { userId: number, value: number } })
	local ids = {}
	for i = 1, math.min(LC.STATUES, #top) do
		ids[i] = top[i].userId
	end
	if table.concat(ids, ",") == table.concat(statueIds, ",") then
		return
	end
	statueIds = ids
	local wall = lobby:FindFirstChild("LeaderboardWall")
	if not wall then
		return
	end
	for rank = 1, LC.STATUES do
		local plinth = wall:FindFirstChild("StatuePlinth" .. rank) :: BasePart?
		if plinth then
			local old = plinth:FindFirstChild("Statue")
			if old then
				old:Destroy()
			end
			local id = ids[rank]
			if id then
				local ok, model = pcall(function()
					local desc = Players:GetHumanoidDescriptionFromUserId(id)
					return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
				end)
				if ok and model then
					model.Name = "Statue"
					stone(model, rank == 1)
					local face = Vector3.new(0, 0, -1) -- toward the plaza
					local stand = plinth.Position + Vector3.new(0, plinth.Size.Y / 2 + 3, 0)
					model:PivotTo(CFrame.lookAt(stand, stand + face))
					model.Parent = plinth
				end
			end
		end
	end
end

local function refresh(lobby: Model)
	for _, key in ipairs(BOARDS) do
		local ok, list = pcall(LeaderboardService.top, key, "Week", LC.BOARD_ROWS)
		local rows = {}
		if ok and type(list) == "table" then
			for _, e in ipairs(list) do
				table.insert(rows, { name = nameOf(e.userId), value = e.value })
			end
			if key == "Wins" then
				statues(lobby, list)
			end
		end
		GameState.set("LB_" .. key, HttpService:JSONEncode(rows))
	end
end

-- The player's friends, online ones first, as R6 avatar models in their own PlayerGui (D-LOBBY-01).
local function friendDummies(player: Player)
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	if not ok or not pages then
		return
	end
	local online, offline = {}, {}
	local seen = 0
	while seen < LC.FRIEND_POOL do
		for _, f in ipairs(pages:GetCurrentPage()) do
			seen += 1
			table.insert(if f.IsOnline then online else offline, f)
		end
		if pages.IsFinished or seen >= LC.FRIEND_POOL then
			break
		end
		local more = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not more then
			break
		end
	end
	local function shuffle(list: { any })
		for i = #list, 2, -1 do
			local j = math.random(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	shuffle(online)
	shuffle(offline)
	local picks = {}
	for _, list in ipairs({ online, offline }) do
		for _, f in ipairs(list) do
			if #picks < LC.FRIEND_DUMMIES then
				table.insert(picks, f)
			end
		end
	end
	if #picks == 0 or not player.Parent then
		return
	end
	local holder = Instance.new("ScreenGui")
	holder.Name = "FV_FriendDummies"
	holder.ResetOnSpawn = false
	holder.Enabled = false
	for slot, f in ipairs(picks) do
		local made, model = pcall(function()
			local desc = Players:GetHumanoidDescriptionFromUserId(f.Id)
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
		end)
		if made and model then
			model.Name = "Friend" .. slot
			model:SetAttribute("Slot", slot)
			model:SetAttribute("DisplayName", f.DisplayName or f.Username)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			model.Parent = holder
		end
	end
	if #holder:GetChildren() > 0 and player.Parent then
		holder.Parent = player:WaitForChild("PlayerGui")
	else
		holder:Destroy()
	end
end

function DepotService.start()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby or not lobby:IsA("Model") then
		return
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(friendDummies, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(friendDummies, player)
	end
	task.spawn(function()
		while lobby.Parent do
			refresh(lobby)
			task.wait(LC.BOARD_REFRESH)
		end
	end)
	-- The VIP firework button (GDD §19.1): VIP pass owners only, one at a time for the whole server.
	local vip = lobby:FindFirstChild("VipLounge")
	local button = vip and vip:FindFirstChild("VipFirework")
	local prompt = button and button:FindFirstChildOfClass("ProximityPrompt")
	if prompt and button and button:IsA("BasePart") then
		prompt.Triggered:Connect(function(player: Player)
			local p = Participants.fromPlayer(player)
			local t = os.clock()
			if not p or not StoreService.isVip(p) or t - lastFirework < LC.FIREWORK_COOLDOWN then
				return
			end
			lastFirework = t
			Net.fireAll("RoundFx", { kind = "VipFirework", who = p.id, pos = button.Position, at = GameState.now() })
		end)
	end
end

return DepotService
