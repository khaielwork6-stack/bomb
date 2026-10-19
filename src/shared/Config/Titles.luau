--!strict
-- Title word art on screen (Client/UI/TitleArt, Asset Bible §6.2 / §6.5). Two tiers: a MOMENT (LAST STAND, the role
-- reveal, WINNER — rare, big, with streaks and sparkles) and a CALLOUT (BOOM!, TAGGED! — smaller, quicker, calmer).
-- Sizes are fractions of the screen height. [TUNE]

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

return {
	Tiers = {
		Moment = { height = 0.15, maxWidth = 0.84, hold = 2.6, sparkles = 7, streaks = true, slam = 1.75 },
		Callout = { height = 0.105, maxWidth = 0.7, hold = 1.35, sparkles = 3, streaks = false, slam = 1.45 },
	},
	IN_TIME = 0.17, -- the slam: big → a little under size
	SETTLE_TIME = 0.32, -- then a soft overshoot to rest
	OUT_TIME = 0.24, -- lift + fade away
	SLAM_TILT = 7, -- degrees it lands from
	SHINE_DELAY = 0.22,
	SHINE_TIME = 0.6,
	GLOW_BREATH = 0.16, -- the idle breath while it holds: the glow eases this much fainter and back (no pixel float: it
	-- would step a pixel at a time and read as a low frame rate)
	GLOW_REST = 0.04, -- glow transparency at rest (it flashes brighter on the slam)
	BACKING = 0.66, -- a dark soft halo under the glow, so a title pops on a bright, busy frame (transparency)
	-- The announcer (Client/UI/Announcer): one title in the middle of the screen at a time.
	Y = 0.3, -- where it sits (fraction of the screen height): above the character, under the top HUD
	WAIT = 1.0, -- a less important word waits this long for the slot, then is dropped
	MERGE_HOLD = 1.2, -- the same word again: stay up this much longer (and count ×N)
	DEDUPE = 0.8, -- the same word inside this window is one moment told twice (a headline + a callout): said once
	DISPLAY_ORDER = 25, -- above the HUD, under modal panels
	TIP_HOLD = 3, -- a first-time tip (the calm pill low on the screen) stays this long
	-- per colour family: the glow behind the word and the sparkle / streak tint
	Families = {
		Gold = { glow = hex("#FFB52E"), spark = hex("#FFF2B0") },
		Red = { glow = hex("#FF3B2F"), spark = hex("#FFD2C4") },
		Fire = { glow = hex("#FF7A1A"), spark = hex("#FFE7A0") },
		Blue = { glow = hex("#2FA8FF"), spark = hex("#D2F3FF") },
		Green = { glow = hex("#4FDB3A"), spark = hex("#E4FFC8") },
		Purple = { glow = hex("#A45CFF"), spark = hex("#F0DDFF") },
	} :: { [string]: { glow: Color3, spark: Color3 } },
}
