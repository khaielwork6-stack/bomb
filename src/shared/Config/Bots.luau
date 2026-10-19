--!strict
-- Bots (GDD §18, Appendix A). [TUNE]

return {
	FILL_TARGET = 16, -- D3: bots fill each round to this many participants (at INTERMISSION)
	DECIDE_HZ = 10, -- brain decisions per second (steering is every frame)
	-- Skill tiers (F-BOT-05): reaction = seconds before a bot acts on what it sees; error = chance a decision is off;
	-- dash = how readily it uses techniques.
	TIERS = {
		-- reject: the chance a bot tries a timed Hard Stop as a Carrier closes in (GDD §7.4b F-BOMB-13)
		Rookie = { reaction = 0.35, error = 0.25, dash = 0.3, pace = 0.9, reject = 0.1 },
		Regular = { reaction = 0.22, error = 0.12, dash = 0.6, pace = 0.96, reject = 0.28 },
		Pro = { reaction = 0.12, error = 0.05, dash = 0.9, pace = 1.0, reject = 0.5 },
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
	OPPORTUNITY_RANGE = 7, -- a body this close is a free hand-off: a Carrier takes it even when it could defuse (§7.4b)
	PASS_DASH_RANGE = 9, -- dash into the pass target from this close (the dash is the Lunge, GDD §7.4b)
	REJECT_LOOK = 1.2, -- studs past a Carrier's reach at which a bot decides on a Reject
	REJECT_CLOSING = 6, -- studs/s the Carrier must be closing in
	REJECT_RETRY = 1.0, -- seconds between a bot's Reject rolls (one per approach)
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
	-- Names (Logic/BotNames, DECISIONS 2026-10-19): bots get names that read like real Roblox usernames, built from
	-- these fragments (a look may be borrowed from a real avatar, never a name). Kid-gamer words, common first names
	-- (no famous people), prefixes / suffixes players actually use; BLOCK filters any accidental bad combination.
	Names = {
		WORDS = {
			"shadow",
			"ghost",
			"blaze",
			"frost",
			"pixel",
			"nova",
			"storm",
			"hyper",
			"turbo",
			"venom",
			"slime",
			"noob",
			"epic",
			"dark",
			"lil",
			"mega",
			"ultra",
			"sky",
			"moon",
			"star",
			"toxic",
			"glitch",
			"lava",
			"ice",
			"neon",
			"zap",
			"rex",
			"wolf",
			"fox",
			"cat",
			"dino",
			"bear",
			"panda",
			"kitty",
			"bunny",
			"ninja",
			"cookie",
			"boba",
			"mochi",
			"peach",
			"cherry",
			"berry",
			"honey",
			"sugar",
			"salty",
			"crispy",
			"sleepy",
			"sneaky",
			"lazy",
			"crazy",
			"silly",
			"goofy",
			"chunky",
			"smol",
			"tiny",
			"king",
			"queen",
			"boss",
			"gamer",
			"sniper",
			"dude",
			"kid",
			"boi",
			"bro",
			"sis",
			"void",
			"flame",
			"spark",
			"comet",
			"orbit",
			"pickle",
			"nugget",
			"taco",
			"waffle",
			"tofu",
			"milk",
			"soda",
			"candy",
			"gummy",
			"jelly",
			"snow",
			"rain",
			"cloud",
			"thunder",
			"drift",
			"blitz",
			"rogue",
			"chaos",
			"frosty",
			"wavy",
			"lucky",
			"zoom",
			"speedy",
			"jumpy",
			"bouncy",
			"fluffy",
		},
		FIRST = {
			"ethan",
			"maya",
			"liam",
			"ava",
			"noah",
			"emma",
			"jayden",
			"zoe",
			"kai",
			"luna",
			"leo",
			"mia",
			"owen",
			"lily",
			"max",
			"ella",
			"finn",
			"ruby",
			"eli",
			"nora",
			"jack",
			"aria",
			"theo",
			"ivy",
			"lucas",
			"chloe",
			"mason",
			"sofia",
			"logan",
			"grace",
			"aiden",
			"hazel",
			"jaxon",
			"stella",
			"ryan",
			"emily",
			"dylan",
			"sara",
			"tyler",
			"amir",
			"omar",
			"layla",
			"ali",
			"yusuf",
			"hana",
			"diego",
			"mateo",
			"lucia",
			"nico",
			"jonah",
			"kenji",
			"aiko",
			"minh",
			"priya",
			"arjun",
			"olu",
			"ade",
			"tomas",
			"anya",
			"milo",
		},
		PREFIX = { "its", "Its", "iam", "The", "TheReal", "not", "Mr", "Lil", "Real" },
		SUFFIX = { "YT", "TTV", "Plays", "Playz", "Gaming", "XD", "Official", "Rblx", "Pro" },
		YEAR_MIN = 2008,
		YEAR_MAX = 2016,
		BLOCK = {
			"fuck",
			"shit",
			"sex",
			"nazi",
			"kill",
			"dead",
			"rape",
			"porn",
			"dick",
			"ass",
			"nig",
			"fag",
			"cum",
			"tit",
		},
	},
}
