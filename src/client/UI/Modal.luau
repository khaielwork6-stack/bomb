--!strict
-- One modal at a time (GDD §21.1: nothing fights for the centre): the rules card, the Daily screens and the level-up
-- celebration register here while they're up, and automatic popups (the calendar's first-visit open, a queued
-- level-up) wait until nothing else is showing.
-- Implements: F-UI-01 (one focus at a time).

local Modal = {}

local open: { [string]: boolean } = {}

function Modal.set(name: string, on: boolean)
	open[name] = if on then true else nil
end

-- Anything up other than `except`?
function Modal.busy(except: string?): boolean
	for name in pairs(open) do
		if name ~= except then
			return true
		end
	end
	return false
end

-- The full-attention screens (the rules card, a level-up, a crate opening, the wheel, an offer): while one is up the
-- dock's tiles and shortcuts don't open another panel over or under it.
local BLOCKING = { Rules = true, LevelUp = true, Crate = true, Wheel = true, Offer = true }
function Modal.blocking(): boolean
	for name in pairs(open) do
		if BLOCKING[name] then
			return true
		end
	end
	return false
end

return Modal
