--!strict
-- P0 only (GDD §23.3 step 5): until RoundService lands in P1, the temporary map (Meadow) is loaded and every player
-- spawns on its start strip as an active Runner, so the whole transferred moveset (dash, slide, hard stop,
-- omnimovement) and the animations can be tested on the real field. Delete this service when RoundService exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local Participants = require(script.Parent.Participants)
local PlayerService = require(script.Parent.PlayerService)

local Sandbox = {}

function Sandbox.start()
	local mapName = Config.Maps.Order[1]
	if not Arena.load(mapName) then
		warn("[Sandbox] no map; players stay at the spawn")
		return
	end
	local rng = Random.new()
	PlayerService.spawnResolver = function(_p)
		return Arena.runnerLine(-1, 1, rng)[1]
	end
	local function activate(p: Participants.Participant)
		Participants.setRole(p, Types.Role.Runner)
		Participants.setState(p, Types.State.Active)
		Characters.applyGroup(p)
	end
	Participants.CharacterChanged:Connect(activate)
	for _, p in ipairs(Participants.humans()) do
		if p.model then
			activate(p)
			Characters.pivot(p, Arena.runnerLine(-1, 1, rng)[1])
		end
	end
	print(`[Sandbox] P0 sandbox on {mapName}: everyone is an active Runner`)
end

return Sandbox
