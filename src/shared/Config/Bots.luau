--!strict
-- Bots (GDD §18, Appendix A). [TUNE]

return {
	FILL_TARGET = 16, -- D3: bots fill each round to this many participants (at INTERMISSION)
	DECIDE_HZ = 10, -- brain decisions per second (steering is every frame)
	-- Skill tiers (F-BOT-05): reaction = seconds before a bot acts on what it sees; error = chance a decision is off;
	-- dash = how readily it uses techniques.
	TIERS = {
		Rookie = { reaction = 0.35, error = 0.25, dash = 0.3, pace = 0.9 },
		Regular = { reaction = 0.22, error = 0.12, dash = 0.6, pace = 0.96 },
		Pro = { reaction = 0.12, error = 0.05, dash = 0.9, pace = 1.0 },
	},
	TIER_MIX = { Rookie = 0.3, Regular = 0.5, Pro = 0.2 },
	NEWBIE_MIX = { Rookie = 0.6, Regular = 0.4, Pro = 0 }, -- a new player's first 2 rounds (F-BOT-05, F-ONB-03)
	-- Runners
	START_DELAY_MAX = 0.4, -- of the Field Fuse: the latest a Runner waits in the start strip for a gap
	THREAT_RADIUS = 18, -- Bombers closer than this push a Runner's line away
	CARRIER_AVOID = 12, -- Runners steer clear of Carriers within this
	DODGE_RADIUS = 7, -- a committed Bomber this close triggers a dodge (dash / hard stop + juke)
	-- Carriers (F-BOT-03)
	DEFUSE_MARGIN = 0.45, -- seconds of slack a Carrier wants before it trusts a run to the strip
	PASS_DASH_RANGE = 9, -- dash into the pass target from this close
	REVENGE_WINDOW = 2.2, -- with less than this left, a Bomber in reach is the preferred target
	-- Bombers (F-BOT-04)
	LEAD_TIME = 0.35, -- seconds of target motion a Bomber leads by
	TAG_DASH_RANGE = 7, -- dash to close the last stretch
	SHARE_PENALTY = 14, -- studs added to a target another Bomber already chases (spreads them out)
	CARRIER_FEAR = 6, -- Bombers keep this far from a Carrier (no revenge passes)
	-- Playing like people (D-BOT-01, from the fun audit: bot Bombers stood idle 26 % of the time)
	LINE_DEPTH = 2.5, -- with nobody on the field, a Bomber guards the start line this far in, facing a waiting Runner
	CUTOFF_MIN = 8, -- a Bomber behind its target (relative to the Runner's goal) cuts it off instead of tailing it…
	CUTOFF_LEAD = 10, -- …aiming up to this far ahead of the Runner on its way to the strip
	JUKE_RANGE = 10, -- inside this a Bomber sways side to side to bait a dodge
	JUKE = 0.35, -- how hard (share of its heading), scaled by the tier's technique rate
	JUKE_HZ = 1.1,
	COVER_CLEARANCE = 1.6, -- studs bots keep off a map's cover (crates, hand-trucks), beyond its radius
	COVER_LOOKAHEAD = 10, -- how far ahead a bot starts bending its line round cover
	-- Names: bots keep generated names (an avatar's look may be borrowed, never its name).
	NAME_A = {
		"Rocket",
		"Sunny",
		"Pixel",
		"Turbo",
		"Lucky",
		"Mighty",
		"Bubbly",
		"Cosmic",
		"Spicy",
		"Snappy",
		"Fizzy",
		"Sneaky",
		"Jolly",
		"Zippy",
		"Brave",
		"Dizzy",
	},
	NAME_B = {
		"Turtle",
		"Mango",
		"Ninja",
		"Pickle",
		"Panda",
		"Comet",
		"Taco",
		"Sloth",
		"Otter",
		"Waffle",
		"Badger",
		"Noodle",
		"Falcon",
		"Muffin",
		"Gecko",
		"Raccoon",
	},
}
