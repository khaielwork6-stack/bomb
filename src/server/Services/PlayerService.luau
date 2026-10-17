--!strict
-- Player lifecycle: join -> participant + R6 lobby character; leave -> cleanup. Kill-plane rescue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Participants = require(script.Parent.Participants)
local Characters = require(script.Parent.Characters)

local PlayerService = {
	Joined = Signal.new(),
	Leaving = Signal.new(),
	SettingsChanged = Signal.new(), -- (participant, settings)
}

-- Where should a (re)spawning human go? Match services override this.
PlayerService.spawnResolver = function(_p: Participants.Participant): CFrame
	return Characters.lobbyCFrame()
end

local LOBBY_WAIT = 8 -- seconds a join waits for the lobby to be arranged (it takes a moment at server start)

local function onPlayerAdded(player: Player)
	if Participants.fromPlayer(player) then
		return
	end
	-- Shift is Hard Stop; the camera controller owns mouse lock (D-07: code enforces place settings).
	player.DevEnableMouseLock = false
	local p = Participants.addHuman(player)
	p.data.joinedAt = os.clock() -- (Match counts them once loaded: ClientReady, Config.Game CLIENT_READY_TIMEOUT)
	-- Never place anyone before the lobby is in its final spot (LobbyArranger raises it at server start).
	Characters.waitLobby(LOBBY_WAIT)
	if player.Parent == Players then
		Characters.spawnHuman(p, PlayerService.spawnResolver(p))
	end
	PlayerService.Joined:Fire(p)
end

local function onPlayerRemoving(player: Player)
	local p = Participants.fromPlayer(player)
	if p then
		PlayerService.Leaving:Fire(p)
		Participants.remove(p)
	end
end

function PlayerService.init()
	-- We spawn every character ourselves (Characters.spawnHuman). Code enforces it, so a new place's default
	-- CharacterAutoLoads (spawn on the SpawnLocation first) never matters.
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PlayerService.start()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	-- Settings (GDD §20.5): validated and kept on the participant; DataService persists them in P6.
	local SETTING_TYPES = {
		musicVolume = "number",
		sfxVolume = "number",
		cameraSensitivity = "number",
		reduceMotion = "boolean",
		showTips = "boolean",
		crowdVisible = "boolean",
		mobileButtonSize = "string",
		colourBlindOutlines = "boolean",
	}
	Net.on("SaveSettings", function(player, data)
		local p = Participants.fromPlayer(player)
		if not p or type(data) ~= "table" then
			return
		end
		local clean = {}
		for key, kind in pairs(SETTING_TYPES) do
			local v = data[key]
			if type(v) == kind and (kind ~= "number" or (v == v and math.abs(v) <= 1000)) then
				if kind ~= "string" or (v == "S" or v == "M" or v == "L") then
					clean[key] = v
				end
			end
		end
		p.data.settings = clean
		PlayerService.SettingsChanged:Fire(p, clean)
	end)
	Net.on("ClientReady", function(player)
		local p = Participants.fromPlayer(player)
		if p and not p.data.clientReady then
			p.data.clientReady = true
			p.data.readyAt = os.clock()
		end
		if p and not p.model and Characters.lobbyReady() then
			Characters.spawnHuman(p, PlayerService.spawnResolver(p))
		end
	end)
	-- Kill plane + lost-character rescue (GDD E14).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, p in ipairs(Participants.all()) do
			local model = p.model
			if
				not p.isBot
				and (model == nil or model.Parent == nil)
				and Participants.isHumanOnline(p)
				and Characters.lobbyReady()
			then
				Characters.spawnHuman(p, PlayerService.spawnResolver(p))
			elseif p.root and p.root.Position.Y < Config.Game.KILL_PLANE_Y then
				Characters.pivot(p, PlayerService.spawnResolver(p))
			end
		end
	end)
end

return PlayerService
