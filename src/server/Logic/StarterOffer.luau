--!strict
-- The Starter Bundle offer clock (GDD §17.5 F-STORE-11), pure: the offer starts after the new player's Nth round
-- results and lasts `hours`; it pops up full-screen at most once per session, and only until the player has seen it
-- once (afterwards it lives in the shop with its countdown until it expires or is bought).
-- Implements: F-STORE-11.

export type Flags = { starterAt: number, starterBought: boolean, starterOffered: boolean }

local StarterOffer = {}

-- Start the clock once `rounds` reaches `after`. Returns true when this call started it.
function StarterOffer.start(flags: Flags, rounds: number, after: number, now: number): boolean
	if flags.starterAt ~= 0 or flags.starterBought or rounds < after then
		return false
	end
	flags.starterAt = now
	return true
end

-- Seconds left on a live offer, or nil (not started, bought or expired).
function StarterOffer.endsIn(flags: Flags, hours: number, now: number): number?
	if flags.starterAt == 0 or flags.starterBought then
		return nil
	end
	local left = flags.starterAt + hours * 3600 - now
	return if left > 0 then left else nil
end

-- Should the full-screen offer card show now? Never twice in one session, never after it was seen once.
function StarterOffer.popup(flags: Flags, hours: number, now: number, poppedThisSession: boolean): boolean
	return not poppedThisSession and not flags.starterOffered and StarterOffer.endsIn(flags, hours, now) ~= nil
end

return StarterOffer
