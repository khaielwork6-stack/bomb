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
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Logic = ServerScriptService.Server.Logic
local CrateRoll = require(Logic.CrateRoll)
local Daily = require(Logic.Daily)
local ProfileSchema = require(Logic.ProfileSchema)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local Participants = require(script.Parent.Participants)
local ProgressionService = require(script.Parent.ProgressionService)

type Participant = Participants.Participant

local St = Config.Store
local SLOTS = { "BombSkin", "Explosion", "FuseSpark", "Trail", "VictoryBoom", "Title" }

local StoreService = {}

local rng = Random.new()
local restricted: { [Player]: boolean } = {}
local vipCache: { [Player]: boolean } = {}
local pendingItem: { [Player]: string } = {} -- the item a Robux item-product purchase is for

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
			local id = St.STREAK_BOMBS[month]
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
	if
		St.PRODUCTS.StarterBundle.id ~= 0
		and not d.flags.starterBought
		and d.flags.starterAt > 0
		and os.time() < d.flags.starterAt + St.STARTER_OFFER_HOURS * 3600
	then
		starter = { endsIn = d.flags.starterAt + St.STARTER_OFFER_HOURS * 3600 - os.time() }
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
		MarketplaceService:PromptProductPurchase(player, product.id)
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

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local p = player and Participants.fromPlayer(player)
	local d = p and DataService.get(p)
	if not player or not p or not d or not DataService.isSaving(p) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if table.find(d.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (a retry)
	end
	local key = productKey(info.ProductId)
	local prod = key and St.PRODUCTS[key]
	if not key or not prod then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- grant
	if prod.stars then
		ProgressionService.grant(p, 0, prod.stars, "Robux:" .. key)
	end
	if prod.items then
		for _, id in ipairs(prod.items) do
			d.inventory[id] = true
		end
	end
	if key == "StarterBundle" then
		d.flags.starterBought = true
	end
	if prod.crate then
		d.crates[prod.crate] = (d.crates[prod.crate] or 0) + 1
		openCrate(p, d, prod.crate, "Token")
	end
	if string.match(key, "^Item") then
		local id = pendingItem[player]
		pendingItem[player] = nil
		if id and Cosmetics.sellable(id) then
			d.inventory[id] = true
			Net.fire(player, "Reward", { kind = "Bought", id = id })
		end
	end
	ProfileSchema.addReceipt(d, purchaseId, Config.Data.RECEIPT_HISTORY)
	if not DataService.save(p, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- the next retry finds it un-recorded only if the save failed
	end
	ProgressionService.push(p)
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
		-- the Starter Bundle offer starts after the 3rd round (F-STORE-11)
		if d.stats.rounds >= St.STARTER_OFFER_AFTER_ROUNDS and d.flags.starterAt == 0 and not d.flags.starterBought then
			d.flags.starterAt = os.time()
			d.flags.starterOffered = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		restricted[player] = nil
		vipCache[player] = nil
		pendingItem[player] = nil
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
end

return StoreService
