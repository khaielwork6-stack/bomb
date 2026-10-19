--!strict
-- The one voice in the middle of the screen (the owner, 2026-10-18: "there should never be 2 text showing at the same
-- time"). Every big word the game says goes through here as title art (UI/TitleArt): one slot, ranked.
--   · something more important arriving replaces what's up (it leaves in a blink)
--   · the same word again while it's up MERGES: the plate counts it (×2, ×3), it pops, and it stays a little longer
--   · something less important waits a moment for the slot, then is dropped (never stacked, never queued long)
-- Priorities: Moment 3 (LAST STAND, the role reveal, a win), Callout 2 (BOOM!, TAGGED!…), Info 1.
-- Implements: F-UI-01 (one message at a time), Asset Bible §6.2 / §6.5.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local TitleArt = require(script.Parent.TitleArt)

local A = Config.Titles

local Announcer = {}

export type Say = {
	key: string, -- an Assets.Title key
	tier: TitleArt.Tier?, -- default Callout
	priority: number?, -- default by tier (Moment 3, Callout 2)
	sub: string?, -- the nameplate (a player's name)
	icon: string?,
	hold: number?,
	merge: boolean?, -- default true: the same key while it's up counts ×N instead of re-showing
}

local gui: ScreenGui? = nil
local current: {
	handle: TitleArt.Handle,
	key: string,
	priority: number,
	count: number,
	sub: string?,
	extra: string?, -- a label riding on the plate (a CHAIN ×4)
	at: number, -- when this word was last said (a repeat inside A.DEDUPE is the same moment, not a ×2)
}? =
	nil
local pending: { say: Say, at: number }? = nil

local function screen(): ScreenGui
	local g = gui
	if g and g.Parent then
		return g
	end
	local ng = Instance.new("ScreenGui")
	ng.Name = "FV_Announce"
	ng.IgnoreGuiInset = true
	ng.ResetOnSpawn = false
	ng.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ng.DisplayOrder = A.DISPLAY_ORDER
	ng.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	gui = ng
	return ng
end

-- The plate under the word: the name it came with, the ×N count, and anything riding on it — together.
local function plateOf(cur: { sub: string?, count: number, extra: string? }): string
	local parts = {}
	if cur.sub then
		table.insert(parts, cur.sub)
	end
	if cur.count > 1 then
		table.insert(parts, "×" .. cur.count)
	end
	if cur.extra then
		table.insert(parts, cur.extra)
	end
	return table.concat(parts, "  ·  ")
end

local function priorityOf(s: Say): number
	return s.priority or (if s.tier == "Moment" then 3 else 2)
end

local show: (s: Say) -> ()

local function onGone(h: TitleArt.Handle)
	local cur = current
	if cur and cur.handle == h then
		current = nil
		local p = pending
		pending = nil
		if p and os.clock() - p.at <= A.WAIT then
			show(p.say)
		end
	end
end

show = function(s: Say)
	local h = TitleArt.show(screen(), s.key, {
		tier = s.tier or "Callout",
		sub = s.sub,
		icon = s.icon,
		hold = s.hold,
		y = A.Y,
	})
	if not h then
		return
	end
	local handle = h :: TitleArt.Handle
	current = { handle = handle, key = s.key, priority = priorityOf(s), count = 1, sub = s.sub, at = os.clock() }
	handle.frame.Destroying:Connect(function()
		onGone(handle)
	end)
end

-- Say a word (title art). Returns true when it's on screen now (or merged into what's up).
function Announcer.say(s: Say): boolean
	if not TitleArt.has(s.key) then
		warn("[Announcer] no title art for", s.key)
		return false
	end
	local p = priorityOf(s)
	local cur = current
	if cur and cur.handle.frame.Parent then
		if cur.key == s.key and os.clock() - cur.at < A.DEDUPE then
			return true -- the same moment told twice (e.g. a headline and a callout): say it once
		end
		if cur.key == s.key and s.merge ~= false then
			-- the same word again: count it, pop it, keep it up a little longer
			cur.at = os.clock()
			cur.count += 1
			cur.handle.setSub(plateOf(cur))
			cur.handle.punch()
			cur.handle.extend(A.MERGE_HOLD)
			return true
		end
		if p > cur.priority then
			-- more important: it takes the slot
			current = nil
			cur.handle.dismiss()
			show(s)
			return true
		end
		-- equal or less: wait a moment for the slot, then give up
		local pd = pending
		if not pd or priorityOf(pd.say) <= p then
			pending = { say = s, at = os.clock() }
		end
		return false
	end
	show(s)
	return true
end

-- Put a short label on the plate of the word that's up (a CHAIN ×4 riding on DEFUSED!). False when nothing is up.
function Announcer.attach(label: string): boolean
	local cur = current
	if not cur or not cur.handle.frame.Parent then
		return false
	end
	cur.extra = label
	cur.handle.setSub(plateOf(cur))
	cur.handle.punch()
	cur.handle.extend(A.MERGE_HOLD)
	return true
end

-- Clear the slot (a phase change that makes whatever is up stale).
function Announcer.clear()
	pending = nil
	local cur = current
	if cur then
		current = nil
		cur.handle.dismiss()
	end
end

-- Is something up right now (other UI can stay quiet while it is)?
function Announcer.busy(): boolean
	local cur = current
	return cur ~= nil and cur.handle.frame.Parent ~= nil
end

return Announcer
