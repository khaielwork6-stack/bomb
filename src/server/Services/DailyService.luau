--!strict
-- Daily systems (GDD §14): three quests a day (drawn, rerolled, counted from callouts and round results, paid on
-- completion, the Daily Crate when all three are done), the login streak calendar and playtime gifts. Days are UTC
-- and roll over live at midnight. Every claim is a tap on the client (DailyAction) and is validated here. The
-- state rides in the Progress snapshot (ProgressionService section "daily").
-- Crates and items won before the P5 store exists are kept on the profile (crates / owed) and granted by the store.
-- Implements: F-DAILY-01..10.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Logic = ServerScriptService.Server.Logic
local Daily = require(Logic.Daily)
local Quests = require(Logic.Quests)
local AdminService = require(script.Parent.AdminService)
local BombService = require(script.Parent.BombService)
local CalloutService = require(script.Parent.CalloutService)
local DataService = require(script.Parent.DataService)
local GameState = require(script.Parent.GameState)
local Participants = require(script.Parent.Participants)
local ProgressionService = require(script.Parent.ProgressionService)

type Participant = Participants.Participant

local D = Config.Daily

local DailyService = {
	-- (p, questId) a quest just completed
	QuestDone = Signal.new(),
	-- (p, kind, data?) a client-reported onboarding moment (RulesSeen, Tip, QuestsOpened…)
	ClientMoment = Signal.new(),
}

local rng = Random.new()

local function today(): number
	return Daily.dayOf(os.time())
end

-- A month tag for the Streak Bomb that rotates monthly ("2026-10").
local function monthTag(): string
	return os.date("!%Y-%m", os.time()) :: string
end

-- Roll the profile's daily block over to today (new quests, fresh gifts and counters).
local function ensureDay(d: { [string]: any }): boolean
	local t = today()
	local daily = d.daily
	if daily.day == t then
		return false
	end
	local last = {}
	for _, e in ipairs(daily.quests) do
		table.insert(last, e.id)
	end
	daily.lastIds = last
	daily.quests = Quests.draw(D.FEATURES, last, rng)
	daily.day = t
	daily.rerolls = 0
	daily.crateClaimed = false
	daily.playSec = 0
	daily.giftsClaimed = {}
	daily.firstWin = false
	return true
end

-- What a reward kind gives. Stars go through ProgressionService; crates and items wait on the profile for P5.
local function give(p: Participant, d: { [string]: any }, kind: string, amount: number?, source: string)
	if kind == "Stars" then
		ProgressionService.grant(p, 0, amount or 0, source)
	elseif kind == "SparkCrate" then
		d.crates.Spark += 1
	elseif kind == "GiftBox" then
		d.crates.GiftBox += 1
	elseif kind == "RareItem" then
		table.insert(d.owed, "RareItem")
	elseif kind == "StreakBomb" then
		table.insert(d.owed, "StreakBomb:" .. monthTag())
	end
end

-- ── Quests ──────────────────────────────────────────────────────────────────────────────────────────────────────
local function count(p: Participant, event: string, amount: number?)
	if p.isBot then
		return
	end
	local d = DataService.get(p)
	if not d then
		return
	end
	ensureDay(d)
	local done = Quests.progress(d.daily.quests, event, amount)
	for _, i in ipairs(done) do
		local e = d.daily.quests[i]
		local q = Quests.def(e.id)
		if q and not e.paid then
			e.paid = true
			local r = D.TIER_REWARD[q.tier]
			ProgressionService.grant(p, r.xp, r.stars, "Quest:" .. e.id)
			if p.player then
				Net.fire(p.player, "Reward", {
					kind = "Quest",
					id = e.id,
					tier = q.tier,
					xp = r.xp,
					stars = r.stars,
					all = Quests.allDone(d.daily.quests),
				})
			end
			DailyService.QuestDone:Fire(p, e.id)
		end
	end
	ProgressionService.push(p)
end

local CALLOUT_EVENTS: { [string]: { string } } = {
	Pass = { "Pass" },
	CloseOne = { "Pass" },
	RevengePass = { "Pass", "RevengePass" },
	Tagged = { "Tag" },
	Defused = { "Defuse" },
	ClutchDefuse = { "Defuse", "Clutch" },
	Boom = { "Boom" },
	Betrayal = { "Betrayal" },
	TripleBoom = { "TripleBoom" },
	LastStand = { "LastStandReached" },
	Survived = { "Survive" },
	Dodge = { "Dodge" },
	AllClear = { "Survive" },
}

local function onCallout(p: Participant, key: string, n: number?)
	for _, event in ipairs(CALLOUT_EVENTS[key] or {}) do
		count(p, event)
	end
	if key == "Chain" and (n or 0) >= 5 then
		count(p, "Chain5")
	end
	if key == "Survived" or key == "AllClear" then
		-- a crossing finished without being tagged in it
		if p.data.taggedCrossing ~= GameState.get("Crossing") then
			count(p, "CleanCrossing")
		end
	end
end

local function onRoundPaid(p: Participant, s: { [string]: any })
	count(p, "Round")
	if s.reached >= 4 then
		count(p, "Reach4")
	end
	if s.won then
		count(p, "Win")
		if s.outcome == "Bombers" then
			count(p, "BomberWin")
		elseif s.outcome == "LastStand" then
			count(p, "LastStandWin")
		end
	end
end

-- ── The snapshot section ────────────────────────────────────────────────────────────────────────────────────────
local function section(_p: Participant, d: { [string]: any }): (string, any)
	ensureDay(d)
	local t = today()
	local daily = d.daily
	local quests = {}
	for _, e in ipairs(daily.quests) do
		local q = Quests.def(e.id)
		if q then
			table.insert(quests, { id = e.id, tier = q.tier, target = q.target, progress = e.progress, done = e.done })
		end
	end
	local login = d.login
	local claimable = login.claimedDay ~= t
	local loginDay, missed = Daily.loginDay(login.lastDay, login.streakDay, t)
	if not claimable then
		loginDay, missed = login.streakDay, false
	end
	local gi, ready, left = Daily.nextGift(daily.playSec, daily.giftsClaimed)
	local _, gkind, gamount = Daily.gift(gi)
	return "daily",
		{
			resetIn = Daily.untilReset(os.time()),
			quests = quests,
			rerolls = daily.rerolls,
			freeRerolls = D.FREE_REROLLS,
			rerollCost = D.REROLL_COST,
			crateReady = Quests.allDone(daily.quests) and not daily.crateClaimed,
			crateClaimed = daily.crateClaimed,
			login = {
				claimable = claimable,
				day = loginDay,
				index = Daily.rewardIndex(loginDay),
				missed = missed and claimable,
				streakDay = login.streakDay,
			},
			gift = { index = gi, ready = ready, left = left, kind = gkind, amount = gamount, playSec = daily.playSec },
			flags = { tutorial = d.flags.tutorial, questsIntro = d.flags.questsIntro, tips = d.flags.tips },
		}
end

-- ── Client actions ──────────────────────────────────────────────────────────────────────────────────────────────
local function deny(player: Player, kind: string, why: string)
	Net.fire(player, "Reward", { kind = "Denied", action = kind, why = why })
end

local function onAction(player: Player, msg: any)
	local p = Participants.fromPlayer(player)
	local d = p and DataService.get(p)
	if not p or not d or type(msg) ~= "table" or type(msg.kind) ~= "string" then
		return
	end
	ensureDay(d)
	local t = today()
	local kind = msg.kind
	if kind == "ClaimLogin" then
		local login = d.login
		if login.claimedDay == t then
			return deny(player, kind, "claimed")
		end
		local day = Daily.loginDay(login.lastDay, login.streakDay, t)
		local idx = Daily.rewardIndex(day)
		local reward = D.LOGIN[idx]
		login.lastDay, login.streakDay, login.claimedDay = t, day, t
		give(p, d, reward.kind, reward.amount, "Login")
		Net.fire(
			player,
			"Reward",
			{ kind = "Login", day = day, index = idx, reward = reward.kind, amount = reward.amount }
		)
	elseif kind == "ClaimGift" then
		local i, ready = Daily.nextGift(d.daily.playSec, d.daily.giftsClaimed)
		if not ready then
			return deny(player, kind, "notReady")
		end
		d.daily.giftsClaimed[tostring(i)] = true
		local _, gkind, amount = Daily.gift(i)
		give(p, d, gkind, amount, "Gift")
		Net.fire(player, "Reward", { kind = "Gift", index = i, reward = gkind, amount = amount })
	elseif kind == "Reroll" then
		local index = tonumber(msg.index)
		if not index or index < 1 or index > #d.daily.quests or d.daily.quests[index].done then
			return deny(player, kind, "bad")
		end
		local free = d.daily.rerolls < D.FREE_REROLLS
		if not free and d.stars < D.REROLL_COST then
			return deny(player, kind, "stars")
		end
		if not Quests.reroll(d.daily.quests, index, D.FEATURES, rng) then
			return deny(player, kind, "none")
		end
		if not free then
			ProgressionService.spend(p, D.REROLL_COST, "QuestReroll")
		end
		d.daily.rerolls += 1
		Net.fire(player, "Reward", { kind = "Reroll", index = index })
	elseif kind == "ClaimDailyCrate" then
		if not Quests.allDone(d.daily.quests) or d.daily.crateClaimed then
			return deny(player, kind, "notReady")
		end
		d.daily.crateClaimed = true
		give(p, d, "SparkCrate", nil, "DailyCrate")
		Net.fire(player, "Reward", { kind = "DailyCrate" })
	elseif kind == "RulesSeen" then
		d.flags.tutorial = true
		DailyService.ClientMoment:Fire(p, kind)
	elseif kind == "QuestsIntro" then
		d.flags.questsIntro = true
		DailyService.ClientMoment:Fire(p, kind)
	elseif kind == "Tip" and type(msg.id) == "string" and #msg.id <= 24 then
		d.flags.tips[msg.id] = true
	elseif kind == "QuestsOpened" then
		DailyService.ClientMoment:Fire(p, kind)
	else
		return
	end
	ProgressionService.push(p)
end

function DailyService.start()
	ProgressionService.addSection(section)
	DataService.Loaded:Connect(function(p: Participant, d: { [string]: any })
		ensureDay(d)
		ProgressionService.push(p)
	end)
	CalloutService.Fired:Connect(onCallout)
	ProgressionService.RoundPaid:Connect(onRoundPaid)
	-- Dethrone (§8.3): a bomb you started booms a crowned winner
	BombService.RunnerBoomed:Connect(function(boomed: Participant, _bomb: any, credit: Participant?)
		if credit and boomed.attrs:GetAttribute("Crowned") then
			count(credit, "Dethrone")
		end
	end)
	BombService.Tagged:Connect(function(_bomber: Participant, target: Participant)
		target.data.taggedCrossing = GameState.get("Crossing")
	end)
	Net.on("DailyAction", onAction)
	-- Playtime (F-DAILY-08): minutes played today, saved; AFK time doesn't count. Midnight rolls everyone over.
	task.spawn(function()
		local sinceUpdate = 0
		while true do
			task.wait(D.PLAYTIME_TICK)
			sinceUpdate += D.PLAYTIME_TICK
			for _, p in ipairs(Participants.humans()) do
				local d = DataService.get(p)
				if d and p.player and p.player.Parent == Players then
					local rolled = ensureDay(d)
					local before = select(2, Daily.nextGift(d.daily.playSec, d.daily.giftsClaimed))
					if not p.afk then
						d.daily.playSec += D.PLAYTIME_TICK
					end
					local after = select(2, Daily.nextGift(d.daily.playSec, d.daily.giftsClaimed))
					if rolled or (after and not before) or sinceUpdate >= 30 then
						ProgressionService.push(p)
					end
				end
			end
			if sinceUpdate >= 30 then
				sinceUpdate = 0
			end
		end
	end)
	AdminService.register("quest", function(args)
		-- quest <id> <event> [n]: count a quest event (Studio tests), e.g. quest P1 Pass 10
		local p = Participants.get(args[1] or "")
		if not p or type(args[2]) ~= "string" then
			return "usage: quest <participantId> <event> [n]"
		end
		count(p, args[2], tonumber(args[3]) or 1)
		local d = DataService.get(p)
		local out = {}
		for _, e in ipairs(d and d.daily.quests or {}) do
			table.insert(out, ("%s %d%s"):format(e.id, e.progress, if e.done then " done" else ""))
		end
		return table.concat(out, " · ")
	end)
end

return DailyService
