--!strict
-- The store (GDD §17): buying with Stars, equipping (shown to everyone as Eq_* attributes), crate openings (Stars,
-- free crate rewards, Robux; odds, pity, duplicates, the paid-random-items policy), the daily featured rotation, the
-- rewards owed from P4 (level track, streak bomb, rare item, group spark), level and achievement titles, Robux
-- products (idempotent ProcessReceipt that grants only after the profile saves) and game passes (VIP). Bots wear a
-- few random cosmetics so lobbies show what exists. State rides in the Progress snapshot (section "store").
-- Implements: F-STORE-01..11, F-SEC-04.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Logic = ServerScriptService.Server.Logic
local CrateRoll = require(Logic.CrateRoll)
local Daily = require(Logic.Daily)
local Receipts = require(Logic.Receipts)
local StarterOffer = require(Logic.StarterOffer)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local Participants = require(script.Parent.Participants)
local ProgressionService = require(script.Parent.ProgressionService)

type Participant = Participants.Participant

local St = Config.Store
local SLOTS = { "BombSkin", "Explosion", "FuseSpark", "Trail", "VictoryBoom", "Title" }

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local StoreService = {}
StoreService.ProductGranted = Signal.new() -- (participant, product key) after a Robux product is granted

local rng = Random.new()
local restricted: { [Player]: boolean } = {}
local vipCache: { [Player]: boolean } = {}
local pendingItem: { [Player]: string } = {} -- the item a Robux item-product purchase is for
local starterPopped: { [Player]: boolean } = {} -- the Starter Bundle card already popped up this session

-- ── Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function owns(d: { [string]: any }, id: string): boolean
	local item = St.ById[id]
	return item ~= nil and (item.rarity == "Default" or d.inventory[id] == true)
end

local function applyEquipped(p: Participant, d: { [string]: any }?)
	for _, slot in ipairs(SLOTS) do
		local id = if d then d.equipped[slot] else nil
		if (id == nil or id == "") and St.DEFAULTS[slot] then
			id = St.DEFAULTS[slot]
		end
		p.attrs:SetAttribute(Cosmetics.attr(slot), if id ~= "" then id else nil)
	end
end

local function grantItem(p: Participant, d: { [string]: any }, id: string, why: string): boolean
	if not St.ById[id] or d.inventory[id] then
		return false
	end
	d.inventory[id] = true
	if p.player then
		Net.fire(p.player, "Reward", { kind = "Item", id = id, why = why })
	end
	return true
end

-- Event rewards (the MEGA BOMB): an item (once) and a free crate opening, saved and announced.
function StoreService.grantItem(p: Participant, id: string, why: string): boolean
	local d = DataService.get(p)
	return d ~= nil and grantItem(p, d, id, why)
end

function StoreService.grantCrate(p: Participant, kind: string, why: string)
	local d = DataService.get(p)
	if not d then
		return
	end
	d.crates[kind] = (d.crates[kind] or 0) + 1
	if p.player then
		Net.fire(p.player, "Reward", { kind = "CrateToken", crate = kind, why = why })
	end
end

-- Items of each rarity that can drop from crates (ready, sellable).
local function cratePool(): { [string]: { string } }
	local pool: { [string]: { string } } = {}
	for _, it in ipairs(St.Items) do
		if Cosmetics.sellable(it.id) then
			pool[it.rarity] = pool[it.rarity] or {}
			table.insert(pool[it.rarity], it.id)
		end
	end
	return pool
end

-- Today's featured items (F-STORE-03): 4 sellable items picked by the day number; the first is the DEAL.
function StoreService.featured(): { string }
	local day = Daily.dayOf(os.time())
	local pick = Random.new(day * 7919)
	local all = {}
	for _, it in ipairs(St.Items) do
		if Cosmetics.sellable(it.id) and it.category ~= "Title" then
			table.insert(all, it.id)
		end
	end
	table.sort(all)
	local out = {}
	while #out < St.FEATURED and #all > 0 do
		table.insert(out, table.remove(all, pick:NextInteger(1, #all)))
	end
	return out
end

local function priceOf(id: string): number?
	local item = St.ById[id]
	local base = item and St.PRICE[item.rarity]
	if not base then
		return nil
	end
	local feat = StoreService.featured()
	if feat[1] == id then
		return math.floor(base * (1 - St.DEAL_OFF) + 0.5)
	end
	return base
end

-- Seconds left on the Starter Bundle offer (F-STORE-11), or nil when it isn't on sale: no product id yet, its art
-- isn't in the game, never started, bought or expired.
local function starterLeft(d: { [string]: any }): number?
	local prod = St.PRODUCTS.StarterBundle
	if prod.id == 0 then
		return nil
	end
	for _, id in ipairs(prod.items) do
		if not Cosmetics.ready(id) then
			return nil
		end
	end
	return StarterOffer.endsIn(d.flags, St.STARTER_OFFER_HOURS, os.time())
end

-- ── Owed rewards, titles, VIP ───────────────────────────────────────────────────────────────────────────────────
local function settle(p: Participant, d: { [string]: any })
	-- rewards won before their items existed
	local keep = {}
	for _, entry in ipairs(d.owed) do
		local done = false
		local level = tonumber(string.match(entry, "^Track:(%d+)$"))
		local month = string.match(entry, "^StreakBomb:(.+)$")
		if level then
			local id = St.LEVEL_TRACK[level]
			if id and Cosmetics.ready(id) then
				grantItem(p, d, id, "Level")
				done = true
			elseif not id then
				done = true
			end
		elseif month then
			-- the month's Streak Bomb, or the newest one listed when that month has none (never stuck in `owed`)
			local id = St.STREAK_BOMBS[month]
			if not id then
				local newest = ""
				for m, skin in pairs(St.STREAK_BOMBS) do
					if m > newest then
						newest, id = m, skin
					end
				end
				if id and owns(d, id) then
					id = nil -- they already have the newest: nothing new to give, drop the entry
					done = true
				end
			end
			if id and Cosmetics.ready(id) then
				grantItem(p, d, id, "Streak")
				done = true
			end
		elseif entry == "Insignia" then
			if Cosmetics.ready("Spark_Insignia") then
				grantItem(p, d, "Spark_Insignia", "Group")
				done = true
			end
		elseif entry == "RareItem" then
			local pool = cratePool().Rare or {}
			local unowned = {}
			for _, id in ipairs(pool) do
				if not d.inventory[id] then
					table.insert(unowned, id)
				end
			end
			if #unowned > 0 then
				grantItem(p, d, unowned[rng:NextInteger(1, #unowned)], "Streak")
				done = true
			end
		else
			done = true -- unknown: drop it
		end
		if not done then
			table.insert(keep, entry)
		end
	end
	d.owed = keep
	-- level titles and achievement titles
	for level, id in pairs(St.LEVEL_TITLES) do
		if d.level >= level then
			grantItem(p, d, id, "Level")
		end
	end
	for _, a in ipairs(St.ACHIEVEMENTS) do
		if (d.stats[a.stat] or 0) >= a.at then
			grantItem(p, d, a.id, "Achievement")
		end
	end
	-- VIP (game pass): its items
	if vipCache[p.player :: Player] then
		for _, id in ipairs(St.PASSES.VIP.items) do
			grantItem(p, d, id, "VIP")
		end
	end
end

local function checkVip(p: Participant)
	local player = p.player
	local pass = St.PASSES.VIP
	if not player or pass.id == 0 then
		return
	end
	local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
	vipCache[player] = ok and has == true
	p.attrs:SetAttribute("VIP", vipCache[player] or nil)
end

function StoreService.isVip(p: Participant): boolean
	return p.player ~= nil and vipCache[p.player :: Player] == true
end

-- ── Crates ──────────────────────────────────────────────────────────────────────────────────────────────────────
-- source: "Stars" (pay), "Token" (a free crate won from the daily systems), "Robux" (a paid product receipt).
local function openCrate(p: Participant, d: { [string]: any }, kind: string, source: string): (boolean, string?)
	local crate = St.CRATES[kind]
	local player = p.player
	if not crate or not player then
		return false, "bad"
	end
	local limited = restricted[player] == true
	if limited and source ~= "Token" then
		return false, "region" -- F-STORE-09: buying random items is off here
	end
	if source == "Stars" then
		if crate.free or d.stars < crate.stars then
			return false, "stars"
		end
	elseif source == "Token" then
		if (d.crates[kind] or 0) <= 0 then
			return false, "none"
		end
	end
	local pool = cratePool()
	local any = false
	for _, l in pairs(pool) do
		if #l > 0 then
			any = true
		end
	end
	if not any then
		return false, "empty"
	end
	if source == "Stars" then
		ProgressionService.spend(p, crate.stars, "Crate:" .. kind)
	elseif source == "Token" then
		d.crates[kind] -= 1
	end
	d.pity.opened += 1
	local res = if limited
		then CrateRoll.fixed(pool, crate, d.pity.opened)
		else CrateRoll.open(crate, pool, d.inventory, if kind == "Inferno" then d.pity.Inferno else 0, rng)
	if kind == "Inferno" and not limited then
		d.pity.Inferno = res.pity
	end
	local dupe = d.inventory[res.item] == true
	local refund = if dupe then math.floor((St.PRICE[res.rarity] or 0) * St.DUPLICATE_REFUND) else 0
	if dupe then
		ProgressionService.grant(p, 0, refund, "CrateDuplicate")
	else
		d.inventory[res.item] = true
	end
	Net.fire(player, "Reward", {
		kind = "Crate",
		crate = kind,
		item = res.item,
		rarity = res.rarity,
		duplicate = dupe,
		refund = refund,
	})
	return true
end

-- ── Snapshot section ────────────────────────────────────────────────────────────────────────────────────────────
local function section(p: Participant, d: { [string]: any }): (string, any)
	local player = p.player
	local owned = {}
	for id in pairs(d.inventory) do
		table.insert(owned, id)
	end
	local products = {}
	for key, prod in pairs(St.PRODUCTS) do
		if prod.id ~= 0 then
			products[key] = true
		end
	end
	local starter = nil
	local left = starterLeft(d)
	if left then
		local prod = St.PRODUCTS.StarterBundle
		starter = {
			endsIn = left,
			popup = StarterOffer.popup(
				d.flags,
				St.STARTER_OFFER_HOURS,
				os.time(),
				player ~= nil and starterPopped[player] == true
			),
			robux = prod.robux,
			stars = prod.stars,
			items = prod.items,
		}
	end
	return "store",
		{
			owned = owned,
			equipped = d.equipped,
			crates = d.crates,
			pity = d.pity.Inferno,
			featured = StoreService.featured(),
			featuredIn = Daily.untilReset(os.time()),
			restricted = player ~= nil and restricted[player] == true,
			vip = StoreService.isVip(p),
			products = products,
			starter = starter,
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
	local kind = msg.kind
	local id = if type(msg.id) == "string" then msg.id else ""
	if kind == "Buy" then
		local price = priceOf(id)
		if not price or not Cosmetics.sellable(id) then
			return deny(player, kind, "bad")
		end
		if owns(d, id) then
			return deny(player, kind, "owned")
		end
		if d.stars < price then
			return deny(player, kind, "stars")
		end
		ProgressionService.spend(p, price, "Item:" .. id)
		d.inventory[id] = true
		Net.fire(player, "Reward", { kind = "Bought", id = id, price = price })
	elseif kind == "Equip" then
		local item = St.ById[id]
		if not item or not owns(d, id) or not Cosmetics.ready(id) then
			return deny(player, kind, "bad")
		end
		d.equipped[item.category] = if item.rarity == "Default" then "" else id
		applyEquipped(p, d)
		Net.fire(player, "Reward", { kind = "Equipped", id = id })
	elseif kind == "Unequip" then
		local slot = if type(msg.slot) == "string" then msg.slot else ""
		if d.equipped[slot] == nil or slot == "Emotes" then
			return deny(player, kind, "bad")
		end
		d.equipped[slot] = ""
		applyEquipped(p, d)
	elseif kind == "OpenCrate" then
		local crateKind = if type(msg.crate) == "string" then msg.crate else ""
		local source = if msg.source == "Token" then "Token" else "Stars"
		local ok, why = openCrate(p, d, crateKind, source)
		if not ok then
			return deny(player, kind, why or "bad")
		end
	elseif kind == "BuyRobux" then
		-- a direct Robux item: remember which item, then prompt the tier's product
		local item = St.ById[id]
		local product = item and St.PRODUCTS["Item" .. item.rarity]
		if not item or not product or product.id == 0 or not Cosmetics.sellable(id) or owns(d, id) then
			return deny(player, kind, "bad")
		end
		pendingItem[player] = id
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif kind == "BuyProduct" then
		local key = if type(msg.product) == "string" then msg.product else ""
		local product = St.PRODUCTS[key]
		if not product or product.id == 0 then
			return deny(player, kind, "bad")
		end
		if product.crate and restricted[player] then
			return deny(player, kind, "region")
		end
		if key == "StarterBundle" and not starterLeft(d) then
			return deny(player, kind, "bad") -- once per account, and only while the offer runs
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif kind == "StarterSeen" then
		-- the full-screen offer card was shown (once ever; never twice a session)
		if not starterLeft(d) then
			return
		end
		d.flags.starterOffered = true
		starterPopped[player] = true
	elseif kind == "BuyPass" then
		local key = if type(msg.pass) == "string" then msg.pass else ""
		local pass = St.PASSES[key]
		if not pass or pass.id == 0 then
			return deny(player, kind, "bad")
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	else
		return
	end
	ProgressionService.push(p)
end

-- ── Robux (F-SEC-04: idempotent; grants only once the profile saved) ────────────────────────────────────────────
local productByIdCache: { [number]: string } = {}
local function productKey(productId: number): string?
	if productByIdCache[productId] then
		return productByIdCache[productId]
	end
	for key, prod in pairs(St.PRODUCTS) do
		if prod.id == productId and prod.id ~= 0 then
			productByIdCache[productId] = key
			return key
		end
	end
	return nil
end

-- One receipt for product `key`; `save` saves the profile (a Studio test can make it fail).
local function receive(
	buyer: Player?,
	key: string?,
	purchaseId: string,
	save: ((Participant) -> boolean)?
): Enum.ProductPurchaseDecision
	local who = buyer and Participants.fromPlayer(buyer)
	local data = who and DataService.get(who)
	local prod = key and St.PRODUCTS[key]
	if not buyer or not who or not data or not key or not prod or not DataService.isSaving(who) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player: Player, p: Participant, d: { [string]: any }, k: string = buyer, who, data, key
	local function grant()
		if prod.stars then
			ProgressionService.grant(p, 0, prod.stars, "Robux:" .. k)
		end
		if prod.items then
			for _, id in ipairs(prod.items) do
				d.inventory[id] = true
			end
		end
		if k == "StarterBundle" then
			d.flags.starterBought = true
		end
		-- the perks (PerkService applies them: the wheel's spins, the next round's Lead Bomber, a Revive)
		if prod.spins then
			d.wheel.spins = (d.wheel.spins or 0) + prod.spins
		end
		if prod.lead then
			d.flags.leadBomber = true
		end
		if prod.revive then
			d.revives = (d.revives or 0) + 1
		end
		task.defer(function()
			StoreService.ProductGranted:Fire(p, k)
		end)
		if prod.crate then
			d.crates[prod.crate] = (d.crates[prod.crate] or 0) + 1
			openCrate(p, d, prod.crate, "Token")
		end
		if string.match(k, "^Item") then
			local id = pendingItem[player]
			pendingItem[player] = nil
			if id and Cosmetics.sellable(id) then
				d.inventory[id] = true
				Net.fire(player, "Reward", { kind = "Bought", id = id })
			end
		end
	end
	-- granted once per purchase id; reported granted only after a save holding the grant and its id succeeded
	local saved = Receipts.process(d, purchaseId, Config.Data.RECEIPT_HISTORY, grant, function()
		return if save then save(p) else DataService.save(p, false)
	end)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ProgressionService.push(p)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	return receive(Players:GetPlayerByUserId(info.PlayerId), productKey(info.ProductId), tostring(info.PurchaseId))
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────────────────────────────────────────
local function onLoaded(p: Participant, d: { [string]: any })
	local player = p.player
	if player then
		task.spawn(function()
			local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
			restricted[player] = ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == true
			checkVip(p)
			settle(p, d)
			ProgressionService.push(p)
		end)
	end
	applyEquipped(p, d)
end

-- Bots wear a few random ready cosmetics (the lobby shows what exists).
local function dressBot(p: Participant)
	local fake = { equipped = {} :: { [string]: string } }
	for _, slot in ipairs(SLOTS) do
		if slot ~= "Title" and rng:NextNumber() < 0.45 then
			local choices = {}
			for _, it in ipairs(St.Items) do
				if it.category == slot and Cosmetics.sellable(it.id) then
					table.insert(choices, it.id)
				end
			end
			if #choices > 0 then
				fake.equipped[slot] = choices[rng:NextInteger(1, #choices)]
			end
		end
	end
	applyEquipped(p, fake :: any)
end

function StoreService.start()
	ProgressionService.addSection(section)
	DataService.Loaded:Connect(onLoaded)
	for _, p in ipairs(Participants.humans()) do
		local d = DataService.get(p)
		if d then
			onLoaded(p, d)
		end
	end
	Participants.Added:Connect(function(p: Participant)
		if p.isBot then
			dressBot(p)
		end
	end)
	for _, p in ipairs(Participants.all()) do
		if p.isBot then
			dressBot(p)
		end
	end
	ProgressionService.LeveledUp:Connect(function(p: Participant)
		local d = DataService.get(p)
		if d then
			settle(p, d)
		end
	end)
	ProgressionService.RoundPaid:Connect(function(p: Participant)
		local d = DataService.get(p)
		if not d then
			return
		end
		settle(p, d)
		-- the Starter Bundle offer's 48 h clock starts at the 3rd round's results (F-STORE-11); the card pops up when
		-- the results close (StoreController)
		if StarterOffer.start(d.flags, d.stats.rounds, St.STARTER_OFFER_AFTER_ROUNDS, os.time()) then
			ProgressionService.push(p)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		restricted[player] = nil
		vipCache[player] = nil
		pendingItem[player] = nil
		starterPopped[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		local p = Participants.fromPlayer(player)
		local d = p and DataService.get(p)
		if bought and p and d and passId == St.PASSES.VIP.id then
			vipCache[player] = true
			p.attrs:SetAttribute("VIP", true)
			settle(p, d)
			ProgressionService.push(p)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	Net.on("StoreAction", onAction)
	AdminService.register("grant", function(args)
		-- grant <id> <itemId|crate:Spark>: Studio test grants
		local p = Participants.get(args[1] or "")
		local d = p and DataService.get(p)
		if not p or not d or type(args[2]) ~= "string" then
			return "usage: grant <participantId> <itemId | crate:Spark | crate:Inferno>"
		end
		local crate = string.match(args[2], "^crate:(%a+)$")
		if crate then
			d.crates[crate] = (d.crates[crate] or 0) + 1
		else
			grantItem(p, d, args[2], "Admin")
		end
		ProgressionService.push(p)
		return "ok"
	end)
	if not RunService:IsStudio() then
		return
	end
	AdminService.register("receipt", function(args)
		-- receipt <id> <productKey> <purchaseId> [failsave]: run a Robux receipt through the real grant path (Studio
		-- tests; product ids may still be 0). "failsave" makes the profile save fail, as a DataStore outage would.
		local p = Participants.get(args[1] or "")
		if not p or not p.player or type(args[2]) ~= "string" or args[3] == nil then
			return "usage: receipt <playerId> <productKey> <purchaseId> [failsave]"
		end
		local fail = if args[4] == "failsave"
			then function(_: Participant): boolean
				return false
			end
			else nil
		return receive(p.player, args[2], tostring(args[3]), fail).Name
	end)
	AdminService.register("storepolicy", function(args)
		-- storepolicy <id> on|off: force the paid-random-items restriction (F-STORE-09) for a Studio test
		local p = Participants.get(args[1] or "")
		local player = p and p.player
		if not p or not player or (args[2] ~= "on" and args[2] ~= "off") then
			return "usage: storepolicy <playerId> on|off"
		end
		restricted[player] = args[2] == "on"
		ProgressionService.push(p)
		return "restricted = " .. tostring(restricted[player])
	end)
end

return StoreService
