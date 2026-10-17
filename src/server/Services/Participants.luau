--!strict
-- Uniform participant objects for humans and bots (one gameplay code path). Transferred from Chase Game (GDD §23.1).
-- Attributes are written to the Player (humans) or the bot Model, so clients see Role/State/IsLead/etc.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

-- One round's numbers (GDD §11.1 callouts, §8.4 results, §24.3 lifetime stats).
export type MatchStats = {
	crossings: number, -- crossings survived
	tags: number, -- bombs stuck on Runners (as a Bomber)
	passes: number,
	passesPaid: number, -- PASS rewards paid this round (capped, F-CALL-02)
	paidPairs: { [string]: boolean }, -- "giver>receiver#crossing" passes already paid (F-CALL-02)
	lastPassPaid: boolean, -- the latest pass paid (a REVENGE bonus rides on it)
	starsPaid: number, -- callout Stars paid this round (the round cap counts them, F-ECO-03)
	xpPaid: number, -- callout XP paid this round (the results receipt)
	defuses: number,
	clutches: number,
	revenges: number,
	betrayals: number,
	booms: number, -- Bomber credit (bombs you started that boomed on a Runner)
	bestChain: number,
	dodges: number,
	survivalStart: number,
	survival: number,
	inputSeconds: number,
	acted: boolean,
	joinedMidMatch: boolean,
	xp: { [string]: number },
	stars: { [string]: number },
}

export type Participant = {
	id: string,
	isBot: boolean,
	player: Player?,
	name: string,
	attrs: Instance,
	model: Model?,
	root: BasePart?,
	humanoid: Humanoid?,
	role: string,
	state: string,
	isLead: boolean,
	afk: boolean,
	stats: MatchStats,
	data: { [string]: any }, -- scratch for services (bot brain, timers...)
	level: number,
	wins: number,
	matchesPlayed: number,
}

local Participants = {
	Added = Signal.new(),
	Removed = Signal.new(),
	RoleChanged = Signal.new(),
	StateChanged = Signal.new(),
	CharacterChanged = Signal.new(), -- (p) a new body (spawn / respawn)
}

local byId: { [string]: Participant } = {}
local order: { Participant } = {}

function Participants.newStats(): MatchStats
	return {
		crossings = 0,
		tags = 0,
		passes = 0,
		passesPaid = 0,
		paidPairs = {},
		lastPassPaid = false,
		starsPaid = 0,
		xpPaid = 0,
		defuses = 0,
		clutches = 0,
		revenges = 0,
		betrayals = 0,
		booms = 0,
		bestChain = 0,
		dodges = 0,
		survivalStart = 0,
		survival = 0,
		inputSeconds = 0,
		acted = false,
		joinedMidMatch = false,
		xp = {},
		stars = {},
	}
end

local function writeAttrs(p: Participant)
	local a = p.attrs
	a:SetAttribute("ParticipantId", p.id)
	a:SetAttribute("IsBot", p.isBot)
	a:SetAttribute("Role", p.role)
	a:SetAttribute("State", p.state)
	a:SetAttribute("IsLead", p.isLead)
	a:SetAttribute("Level", p.level)
	a:SetAttribute("Wins", p.wins)
	a:SetAttribute("DisplayName", p.name)
end

local function add(p: Participant)
	byId[p.id] = p
	table.insert(order, p)
	writeAttrs(p)
	Participants.Added:Fire(p)
end

function Participants.addHuman(player: Player): Participant
	local p: Participant = {
		id = "P" .. tostring(player.UserId),
		isBot = false,
		player = player,
		name = player.DisplayName,
		attrs = player,
		model = nil,
		root = nil,
		humanoid = nil,
		role = Types.Role.None,
		state = Types.State.Lobby,
		isLead = false,
		afk = false,
		stats = Participants.newStats(),
		data = {},
		level = 1,
		wins = 0,
		matchesPlayed = 0,
	}
	add(p)
	return p
end

function Participants.addBot(id: string, name: string, model: Model, level: number, wins: number): Participant
	local p: Participant = {
		id = id,
		isBot = true,
		player = nil,
		name = name,
		attrs = model,
		model = model,
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart?,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		role = Types.Role.None,
		state = Types.State.Lobby,
		isLead = false,
		afk = false,
		stats = Participants.newStats(),
		data = {},
		level = level,
		wins = wins,
		matchesPlayed = 99,
	}
	add(p)
	return p
end

function Participants.remove(p: Participant)
	if not byId[p.id] then
		return
	end
	byId[p.id] = nil
	local i = table.find(order, p)
	if i then
		table.remove(order, i)
	end
	Participants.Removed:Fire(p)
end

function Participants.get(id: string): Participant?
	return byId[id]
end

function Participants.fromPlayer(player: Player): Participant?
	return byId["P" .. tostring(player.UserId)]
end

function Participants.fromModel(model: Instance): Participant?
	for _, p in ipairs(order) do
		if p.model == model then
			return p
		end
	end
	return nil
end

function Participants.all(): { Participant }
	return table.clone(order)
end

function Participants.humans(): { Participant }
	local out = {}
	for _, p in ipairs(order) do
		if not p.isBot then
			table.insert(out, p)
		end
	end
	return out
end

function Participants.bots(): { Participant }
	local out = {}
	for _, p in ipairs(order) do
		if p.isBot then
			table.insert(out, p)
		end
	end
	return out
end

-- In the current match (runner or catcher), regardless of downed/safe.
function Participants.inMatch(): { Participant }
	local out = {}
	for _, p in ipairs(order) do
		if p.role ~= Types.Role.None then
			table.insert(out, p)
		end
	end
	return out
end

function Participants.withRole(role: string): { Participant }
	local out = {}
	for _, p in ipairs(order) do
		if p.role == role then
			table.insert(out, p)
		end
	end
	return out
end

function Participants.setCharacter(p: Participant, model: Model?)
	p.model = model
	p.root = if model then model:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	p.humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	Participants.CharacterChanged:Fire(p)
end

function Participants.setRole(p: Participant, role: string)
	if p.role == role then
		return
	end
	p.role = role
	p.attrs:SetAttribute("Role", role)
	Participants.RoleChanged:Fire(p, role)
end

function Participants.setState(p: Participant, state: string)
	if p.state == state then
		return
	end
	p.state = state
	p.attrs:SetAttribute("State", state)
	Participants.StateChanged:Fire(p, state)
end

function Participants.setLead(p: Participant, isLead: boolean)
	p.isLead = isLead
	p.attrs:SetAttribute("IsLead", isLead)
end

function Participants.setAttr(p: Participant, key: string, value: any)
	p.attrs:SetAttribute(key, value)
end

function Participants.isHumanOnline(p: Participant): boolean
	return p.player ~= nil and p.player.Parent == Players
end

function Participants.refreshAttrs(p: Participant)
	writeAttrs(p)
end

return Participants
