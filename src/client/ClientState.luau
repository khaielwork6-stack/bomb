--!strict
-- Read-only view of replicated state for client controllers: GameState attributes + local participant attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local player = Players.LocalPlayer
local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration

local ClientState = {}

ClientState.player = player
ClientState.gs = gs

function ClientState.get(key: string): any
	return gs:GetAttribute(key)
end

function ClientState.changed(key: string, fn: () -> ()): RBXScriptConnection
	return gs:GetAttributeChangedSignal(key):Connect(fn)
end

function ClientState.my(key: string): any
	return player:GetAttribute(key)
end

function ClientState.myChanged(key: string, fn: () -> ()): RBXScriptConnection
	return player:GetAttributeChangedSignal(key):Connect(fn)
end

function ClientState.phase(): string
	return gs:GetAttribute("Phase") or Types.Phase.Boot
end

function ClientState.sub(): string
	return gs:GetAttribute("SubPhase") or Types.Sub.None
end

function ClientState.role(): string
	return player:GetAttribute("Role") or Types.Role.None
end

function ClientState.state(): string
	return player:GetAttribute("State") or Types.State.Lobby
end

function ClientState.myId(): string
	return player:GetAttribute("ParticipantId") or ("P" .. tostring(player.UserId))
end

-- Is the run live (catching/dashing matters)?
-- Is a crossing being run right now? (a normal crossing, or the Last Stand's run, GDD §5.2)
function ClientState.runLive(): boolean
	local phase = ClientState.phase()
	return phase == Types.Phase.Crossing or (phase == Types.Phase.LastStand and ClientState.sub() == Types.Sub.Run)
end

-- Am I currently controlling an active Runner / Bomber on the field?
function ClientState.activeInRun(): boolean
	return ClientState.runLive()
		and ClientState.role() ~= Types.Role.None
		and ClientState.state() == Types.State.Active
		and player:GetAttribute("Locked") ~= true
end

-- Is this client part of the match's world right now? (2026-10-07, the user: a Fog round fogged the lobby —
-- nothing that happens in a match may touch people in the lobby.) Playing, or watching it through Spectate.
ClientState.spectating = false
function ClientState.watchingMatch(): boolean
	return ClientState.role() ~= Types.Role.None or ClientState.spectating
end

function ClientState.timeLeft(): number
	local ends = gs:GetAttribute("PhaseEndsAt") or 0
	return math.max(0, ends - workspace:GetServerTimeNow())
end

-- Find a participant's attribute host + character by participant id.
function ClientState.byId(id: string): (Instance?, Model?)
	if string.sub(id, 1, 1) == "P" then
		local uid = tonumber(string.sub(id, 2))
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == uid then
				return p, p.Character
			end
		end
		return nil, nil
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:GetAttribute("ParticipantId") == id then
				return m, m :: Model
			end
		end
	end
	return nil, nil
end

function ClientState.nameOf(id: string): string
	local host = ClientState.byId(id)
	if host then
		return host:GetAttribute("DisplayName") or host.Name
	end
	return "?"
end

-- All participant attribute hosts (players + bot models) currently in the game.
function ClientState.participants(): { { host: Instance, model: Model? } }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("ParticipantId") then
			table.insert(out, { host = p :: Instance, model = p.Character })
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("ParticipantId") then
				table.insert(out, { host = m :: Instance, model = m })
			end
		end
	end
	return out
end

return ClientState
