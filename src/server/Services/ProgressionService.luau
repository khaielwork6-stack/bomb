--!strict
-- XP, levels, Stars and the round payout (GDD §11.1, §12, §13, §15.1, §15.3). The single place a human's profile
-- gains XP or Stars: callouts pay the instant they fire (CalloutService.payer), RESULTS pays the round keys plus the
-- Hot Streak and squad bonus (capped by the balance rule), level-ups pay their Stars and celebrate. Every change is
-- pushed to the owner as one "Progress" snapshot (other services add their sections, e.g. DailyService), and the
-- server's `leaderstats` show Level and Wins. Bots earn nothing (they have no profile).
-- Implements: F-PROG-01..03, F-ECO-01..03, F-SOC-01, F-SOC-02 (in-server), F-SOC-03, F-SOC-05, F-CALL-02, F-KPI-02
-- (economy events).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Logic = ServerScriptService.Server.Logic
local Daily = require(Logic.Daily)
local HotStreak = require(Logic.HotStreak)
local LevelCurve = require(Logic.LevelCurve)
local Rewards = require(Logic.Rewards)
local AdminService = require(script.Parent.AdminService)
local CalloutService = require(script.Parent.CalloutService)
local DataService = require(script.Parent.DataService)
local GameState = require(script.Parent.GameState)
local Participants = require(script.Parent.Participants)
local RoundService = require(script.Parent.RoundService)

type Participant = Participants.Participant

local E = Config.Economy
local R = Types.Role
local PASS_KEYS = { Pass = true, SlamPass = true, CloseOne = true, RevengePass = true } -- one anti-farm for all passes

local ProgressionService = {
	-- (p, summary) after a human's round is paid: { outcome, won, mvp, reached, keys } (quests, leaderboards)
	RoundPaid = Signal.new(),
	-- (p, level) each level reached
	LeveledUp = Signal.new(),
}

-- Other services add fields to the snapshot: fn(p, data) -> (key, value).
local sections: { (Participant, { [string]: any }) -> (string, any) } = {}
local pushQueued: { [Participant]: boolean } = {}
local friendCache: { [string]: boolean } = {} -- "a:b" (user ids, a < b) -> friends?

-- Economy soak (Config.Debug.ECON_SIM, Studio): what each bot would have earned.
local econ: {
	[string]: { stars: number, xp: number, rounds: number, cStars: number, cXp: number, bonus: number, first: number },
} =
	{}
local econStart = 0
local function econSim(p: Participant): boolean
	return p.isBot and RunService:IsStudio() and Config.Debug.ECON_SIM == true
end
local function econAdd(p: Participant, xp: number, stars: number, round: boolean)
	local e = econ[p.id] or { stars = 0, xp = 0, rounds = 0, cStars = 0, cXp = 0, bonus = 0, first = 0 }
	e.stars += stars
	e.xp += xp
	if round then
		e.rounds += 1
	else
		e.cStars += stars
		e.cXp += xp
	end
	econ[p.id] = e
end

function ProgressionService.addSection(fn: (Participant, { [string]: any }) -> (string, any))
	table.insert(sections, fn)
end

-- ── The snapshot ────────────────────────────────────────────────────────────────────────────────────────────────
local function snapshot(p: Participant, d: { [string]: any }): { [string]: any }
	local s: { [string]: any } = {
		level = d.level,
		xp = d.xp,
		xpToNext = LevelCurve.xpToNext(d.level),
		stars = d.stars,
		badge = LevelCurve.badge(d.level),
		hotStreak = d.hotStreak,
		streakMult = HotStreak.mult(d.hotStreak),
		crates = d.crates,
		rounds = d.stats.rounds,
		wins = d.stats.wins,
		saving = DataService.isSaving(p),
	}
	for _, fn in ipairs(sections) do
		local ok, key, value = pcall(fn, p, d)
		if ok and key then
			s[key] = value
		end
	end
	return s
end

-- Send p's snapshot (coalesced: many changes in one frame send once).
function ProgressionService.push(p: Participant)
	if p.isBot or not p.player or pushQueued[p] then
		return
	end
	pushQueued[p] = true
	task.defer(function()
		pushQueued[p] = nil
		local d = DataService.get(p)
		if d and p.player and p.player.Parent == Players then
			Net.fire(p.player, "Progress", snapshot(p, d))
		end
	end)
end

local function leaderstats(p: Participant, d: { [string]: any })
	local player = p.player
	if not player then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		assert(ls, "leaderstats folder")
		ls.Name = "leaderstats"
		local level = Instance.new("IntValue")
		level.Name = "Level"
		level.Parent = ls
		local wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Parent = ls
		ls.Parent = player
	end
	(ls:FindFirstChild("Level") :: IntValue).Value = d.level;
	(ls:FindFirstChild("Wins") :: IntValue).Value = d.stats.wins
	p.level, p.wins = d.level, d.stats.wins
	p.attrs:SetAttribute("Level", d.level)
	p.attrs:SetAttribute("Wins", d.stats.wins)
	p.attrs:SetAttribute("Badge", LevelCurve.badge(d.level))
end

local function economyEvent(p: Participant, amount: number, balance: number, source: string)
	local player = p.player
	if not player or amount == 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			if amount > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Stars",
			math.abs(amount),
			balance,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			source
		)
	end)
end

-- ── Granting ────────────────────────────────────────────────────────────────────────────────────────────────────
-- Add XP and Stars to a human's profile (level-ups pay their own Stars and fire LevelUp). Returns the levels reached.
function ProgressionService.grant(p: Participant, xp: number, stars: number, source: string): { number }
	local d = if p.isBot then nil else DataService.get(p)
	if not d then
		return {}
	end
	stars = math.floor(stars)
	if stars ~= 0 then
		d.stars = math.max(0, d.stars + stars)
		economyEvent(p, stars, d.stars, source)
	end
	local level, into, ups = LevelCurve.add(d.level, d.xp, xp)
	d.level, d.xp = level, into
	for _, l in ipairs(ups) do
		local pay = LevelCurve.levelStars(l)
		d.stars += pay
		if LevelCurve.trackLevel(l) then
			table.insert(d.owed, "Track:" .. tostring(l)) -- the Level Track cosmetic, granted by the P5 catalogue
		end
		economyEvent(p, pay, d.stars, "LevelUp")
		if p.player then
			Net.fire(p.player, "Reward", {
				kind = "LevelUp",
				level = l,
				stars = pay,
				badge = LevelCurve.badge(l),
				track = LevelCurve.trackLevel(l),
			})
		end
		ProgressionService.LeveledUp:Fire(p, l)
	end
	if #ups > 0 then
		leaderstats(p, d)
	end
	ProgressionService.push(p)
	return ups
end

-- Spend Stars (quest rerolls, P5 store). False when the balance is short.
function ProgressionService.spend(p: Participant, stars: number, sink: string): boolean
	local d = DataService.get(p)
	if not d or d.stars < stars then
		return false
	end
	d.stars -= stars
	economyEvent(p, -stars, d.stars, sink)
	ProgressionService.push(p)
	return true
end

-- ── Callouts (paid as they fire) ────────────────────────────────────────────────────────────────────────────────
local function smallPrivate(): boolean
	return game.PrivateServerId ~= "" and #Participants.humans() < E.PRIVATE_SMALL_HUMANS
end

local function payCallout(p: Participant, key: string, n: number?, other: Participant?): (number, number)
	local sim = econSim(p)
	if not sim and (p.isBot or not DataService.get(p)) then
		return 0, 0
	end
	local st = p.stats
	if PASS_KEYS[key] then
		local pair = p.id .. ">" .. (if other then other.id else "?") .. "#" .. tostring(GameState.get("Crossing") or 0)
		if not Rewards.passPays(st.passesPaid, st.paidPairs, pair) then
			st.lastPassPaid = false
			return 0, 0
		end
		st.paidPairs[pair] = true
		st.passesPaid += 1
		st.lastPassPaid = true
	elseif key == "Revenge" and not st.lastPassPaid then
		return 0, 0 -- the bonus rides on a paid REVENGE PASS
	end
	local pay = Rewards.callout(key, n, other ~= nil and other.isBot, smallPrivate())
	-- the balance rule counts callout Stars toward the round's cap
	local stars = math.max(0, math.min(pay.stars, E.ROUND_STARS_CAP - st.starsPaid))
	st.starsPaid += stars
	st.xpPaid += pay.xp
	if sim then
		econAdd(p, pay.xp, stars, false)
		return 0, 0
	end
	ProgressionService.grant(p, pay.xp, stars, "Callout:" .. key)
	return pay.xp, stars
end

-- ── The round payout ────────────────────────────────────────────────────────────────────────────────────────────
local function friendsInServer(p: Participant): number
	local player = p.player
	if not player then
		return 0
	end
	local n = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local a, b = math.min(player.UserId, other.UserId), math.max(player.UserId, other.UserId)
			local key = a .. ":" .. b
			local cached = friendCache[key]
			if cached == nil then
				local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
				cached = ok and yes == true
				friendCache[key] = cached
			end
			if cached then
				n += 1
			end
		end
	end
	return n
end

local function payRound(p: Participant, outcome: string, won: boolean, isMvp: boolean)
	local d = DataService.get(p)
	if not d then
		return
	end
	local today = Daily.dayOf(os.time())
	local firstWin = won and not (d.daily.day == today and d.daily.firstWin)
	local keys = Rewards.roundKeys(outcome, won, isMvp, firstWin)
	local lines = {}
	local xp, stars = 0, 0
	for _, key in ipairs(keys) do
		local r = E.Rounds[key]
		table.insert(lines, { key = key, xp = r.xp, stars = r.stars })
		xp += r.xp
		stars += r.stars
	end
	if won and GameState.get("MegaRound") then
		stars *= Config.Mega.REWARD_MULT -- F-MEGA-08: a MEGA BOMB win pays ×3 round Stars
	end
	local st = p.stats
	-- Hot Streak: a win, or reaching crossing STREAK_CROSSING as a Runner (crossings survived + the one you're on)
	local reached = if st.crossings > 0 then st.crossings + 1 else 0
	local before = d.hotStreak
	d.hotStreak = HotStreak.after(d.hotStreak, won, reached)
	local mult = HotStreak.mult(d.hotStreak)
	local squad = Rewards.squad(friendsInServer(p))
	-- the VIP pass adds its Stars bonus on top of the squad bonus (StoreService sets the VIP attribute)
	local vip = if p.attrs:GetAttribute("VIP") then Config.Store.PASSES.VIP.starsBonus else 0
	-- the cap covers the whole round: callouts already paid + the round keys + the multipliers' bonus
	local room = math.max(0, E.ROUND_STARS_CAP - st.starsPaid)
	stars = math.min(stars, room)
	local base = st.starsPaid + stars
	local bonus = math.max(0, Rewards.roundStars(st.starsPaid, stars, mult, squad + vip) - base)
	if firstWin then
		d.daily.firstWin = true
	end
	-- lifetime stats
	local s = d.stats
	s.rounds += 1
	s.crossings += st.crossings
	s.passes += st.passes
	s.defuses += st.defuses
	s.clutches += st.clutches
	s.booms += st.booms
	s.revenge += st.revenges
	if st.bestChain >= 5 then
		s.chains5 += 1
	end
	if won then
		s.wins += 1
		if outcome == "LastStand" then
			s.lastStandWins += 1
		elseif outcome == "Bombers" then
			s.bomberWins += 1
		end
	end
	local levelBefore, xpBefore = d.level, d.xp
	ProgressionService.grant(p, xp, stars + bonus, "Round")
	leaderstats(p, d)
	if p.player then
		Net.fire(p.player, "Reward", {
			kind = "Round",
			lines = lines,
			calloutXp = st.xpPaid,
			calloutStars = st.starsPaid,
			streak = d.hotStreak,
			streakBefore = before,
			mult = mult,
			squad = squad,
			vip = vip,
			bonus = bonus,
			levelBefore = levelBefore,
			xpBefore = xpBefore,
			xpToNextBefore = LevelCurve.xpToNext(levelBefore),
			level = d.level,
			xp = d.xp,
			xpToNext = LevelCurve.xpToNext(d.level),
			stars = d.stars,
		})
	end
	ProgressionService.RoundPaid:Fire(p, {
		outcome = outcome,
		won = won,
		mvp = isMvp,
		reached = reached,
		keys = keys,
	})
end

-- ── Join: apply the profile, the group perk ─────────────────────────────────────────────────────────────────────
local function applyProfile(p: Participant, d: { [string]: any })
	leaderstats(p, d)
	local player = p.player
	if player and not d.flags.groupPerk then
		task.spawn(function()
			local ok, member = pcall(player.IsInGroup, player, E.GROUP_ID)
			if ok and member and not d.flags.groupPerk and DataService.get(p) == d then
				d.flags.groupPerk = true
				table.insert(d.owed, "Insignia") -- the group-only fuse spark, granted once the P5 catalogue exists
				ProgressionService.grant(p, 0, E.GROUP_STARS, "GroupPerk")
				Net.fire(player, "Reward", { kind = "Group", stars = E.GROUP_STARS })
			end
		end)
	end
	ProgressionService.push(p)
end

function ProgressionService.start()
	CalloutService.payer = payCallout
	DataService.Loaded:Connect(applyProfile)
	for _, p in ipairs(Participants.humans()) do
		local d = DataService.get(p)
		if d then
			applyProfile(p, d)
		end
	end
	RoundService.Ended:Connect(function(outcome: string, winners: { Participant }, mvp: Participant?)
		local won: { [Participant]: boolean } = {}
		for _, w in ipairs(winners) do
			won[w] = true
		end
		for _, p in ipairs(Participants.humans()) do
			if p.role == R.Runner or p.role == R.Bomber then
				local ok, err = pcall(payRound, p, outcome, won[p] == true, mvp == p)
				if not ok then
					warn("[Progression] round payout failed for", p.id, err)
				end
			end
		end
		-- the economy soak: the same round maths for every bot that played
		for _, p in ipairs(Participants.all()) do
			if econSim(p) and (p.role == R.Runner or p.role == R.Bomber) then
				local today = Daily.dayOf(os.time())
				local w = won[p] == true
				local firstWin = w and p.data.simWinDay ~= today
				if firstWin then
					p.data.simWinDay = today
				end
				local xp, stars = 0, 0
				for _, key in ipairs(Rewards.roundKeys(outcome, w, mvp == p, firstWin)) do
					xp += E.Rounds[key].xp
					stars += E.Rounds[key].stars
				end
				local first = if firstWin then E.Rounds.FirstWinOfDay.stars else 0
				local st = p.stats
				local reached = if st.crossings > 0 then st.crossings + 1 else 0
				p.data.simStreak = HotStreak.after(p.data.simStreak or 0, w, reached)
				stars = math.min(stars, math.max(0, E.ROUND_STARS_CAP - st.starsPaid))
				local base = st.starsPaid + stars
				local bonus =
					math.max(0, Rewards.roundStars(st.starsPaid, stars, HotStreak.mult(p.data.simStreak), 0) - base)
				econAdd(p, xp, stars + bonus, true)
				econ[p.id].bonus += bonus
				econ[p.id].first += first
			end
		end
	end)
	Participants.Removed:Connect(function(p: Participant)
		pushQueued[p] = nil
	end)
	AdminService.register("econ", function(args)
		-- econ start: begin a soak (bots earn on paper) · econ: the Stars/hour report
		if args[1] == "start" then
			table.clear(econ)
			econStart = os.clock()
			Config.Debug.ECON_SIM = true
			return "economy soak started"
		end
		local hours = (os.clock() - econStart) * math.clamp(Config.Debug.TIME_SCALE, 0.25, 4) / 3600
		if econStart == 0 or hours <= 0 then
			return "run `econ start` first"
		end
		local n, stars, xp, rounds, cStars, cXp, bonus, first = 0, 0, 0, 0, 0, 0, 0, 0
		for _, e in pairs(econ) do
			bonus += e.bonus
			first += e.first
			n += 1
			stars += e.stars
			xp += e.xp
			rounds += e.rounds
			cStars += e.cStars
			cXp += e.cXp
		end
		if n == 0 then
			return "no payouts yet"
		end
		-- FirstWinOfDay pays once a day, so a short soak overstates it: it's also reported on its own
		return ("%d bots · %.2f game-hours · avg %.0f Stars/h (callouts %.0f, Hot Streak bonus %.0f, first win %.0f), %.0f XP/h (callouts %.0f) · %.1f rounds each, %.1f min/round · quests, gifts, logins and level-ups come on top"):format(
			n,
			hours,
			stars / n / hours,
			cStars / n / hours,
			bonus / n / hours,
			first / n / hours,
			xp / n / hours,
			cXp / n / hours,
			rounds / n,
			if rounds > 0 then hours * 60 / (rounds / n) else 0
		)
	end)
	AdminService.register("give", function(args)
		-- give <id> <xp> <stars>: Studio test payouts (through the real grant path: level-ups, events, snapshot).
		local p = Participants.get(args[1] or "")
		if not p then
			return "usage: give <participantId> <xp> <stars>"
		end
		local ups = ProgressionService.grant(p, tonumber(args[2]) or 0, tonumber(args[3]) or 0, "Admin")
		local d = DataService.get(p)
		return ("%s Lv %d (%d xp) · %d stars · +%d levels"):format(
			p.id,
			d and d.level or 0,
			d and d.xp or 0,
			d and d.stars or 0,
			#ups
		)
	end)
end

return ProgressionService
