--!strict
-- Callouts (GDD §11.1, Asset Bible §6.7): the word, its tier and its colour token for every moment. The XP / Stars
-- each one pays live in Config.Economy.Rewards (P4) under the same key. [TUNE]

export type Callout = { text: string, tier: string, color: string, title: string?, priority: number?, moment: boolean? }

return {
	-- text / tier / color: the word and its old treatment (the floating "+N" tag and the results list still use them).
	-- title: the Assets.Title word art the announcer shows in the middle of the screen (Client/UI/Announcer); nil =
	-- no centre word (too frequent, or another moment already says it). priority: higher replaces lower (Callout ≈ 2,
	-- Moment 3); moment = the big treatment (streaks, bigger). DECISIONS 2026-10-18: one voice at a time.
	List = {
		Tagged = { text = "TAGGED!", tier = "Small", color = "Bomber", title = "Tagged", priority = 2 },
		Pass = { text = "PASS!", tier = "Small", color = "Paper" }, -- frequent: the "+N" tag is enough
		SlamPass = { text = "SLAM PASS!", tier = "Medium", color = "Spark", title = "SlamPass", priority = 2.1 },
		Rejected = { text = "REJECTED!", tier = "Big", color = "Runner", title = "Rejected", priority = 2.4 },
		CloseOne = { text = "CLOSE ONE!", tier = "Medium", color = "Ember", title = "CloseOne", priority = 2.2 },
		Defused = { text = "DEFUSED", tier = "Medium", color = "Safe", title = "Defused", priority = 2.2 },
		ClutchDefuse = {
			text = "CLUTCH DEFUSE!",
			tier = "Big",
			color = "Gold",
			title = "ClutchDefuse",
			priority = 2.8,
			moment = true,
		},
		RevengePass = { text = "REVENGE PASS!", tier = "Medium", color = "Bomber", title = "Revenge", priority = 2.3 },
		Revenge = { text = "REVENGE!", tier = "Medium", color = "Detonate" }, -- rides on REVENGE PASS (same word)
		Betrayal = { text = "BETRAYAL!", tier = "Medium", color = "Mega", title = "Betrayal", priority = 2.2 },
		Chain = { text = "CHAIN ×%d", tier = "Medium", color = "Spark", title = "Chain", priority = 1.8 }, -- %d = links
		Boom = { text = "BOOM!", tier = "Medium", color = "Fuse", title = "Boom", priority = 2.3 },
		DoubleBoom = { text = "DOUBLE BOOM!", tier = "Big", color = "Fuse", title = "DoubleBoom", priority = 2.6 },
		TripleBoom = {
			text = "TRIPLE BOOM!",
			tier = "Big",
			color = "Detonate",
			title = "TripleBoom",
			priority = 2.9,
			moment = true,
		},
		Survived = { text = "SURVIVED", tier = "Small", color = "Runner", title = "Safe", priority = 1.5 },
		AllClear = { text = "ALL CLEAR", tier = "Small", color = "Safe", title = "AllClear", priority = 1.6 },
		LastStand = { text = "LAST STAND!", tier = "Big", color = "Gold" }, -- the LAST STAND moment says it
		Dodge = { text = "DODGE!", tier = "Small", color = "Runner", title = "Dodge", priority = 1.9 },
	} :: { [string]: Callout },
	CHAIN_BIG = 5, -- a chain this long is a Big callout
	MULTI_BOOM_WINDOW = 4, -- seconds: booms of yours this close together make a DOUBLE / TRIPLE
}
