--!strict
-- Callouts (GDD §11.1, Asset Bible §6.7): the word, its tier and its colour token for every moment. The XP / Stars
-- each one pays live in Config.Economy.Rewards (P4) under the same key. [TUNE]

export type Callout = { text: string, tier: string, color: string }

return {
	-- tier: "Small" | "Medium" | "Big" (Asset Bible §6.7); color: a Theme.Palette token
	List = {
		Tagged = { text = "TAGGED!", tier = "Small", color = "Bomber" },
		Pass = { text = "PASS!", tier = "Small", color = "Paper" },
		CloseOne = { text = "CLOSE ONE!", tier = "Medium", color = "Ember" },
		Defused = { text = "DEFUSED", tier = "Medium", color = "Safe" },
		ClutchDefuse = { text = "CLUTCH DEFUSE!", tier = "Big", color = "Gold" },
		RevengePass = { text = "REVENGE PASS!", tier = "Medium", color = "Bomber" },
		Revenge = { text = "REVENGE!", tier = "Medium", color = "Detonate" },
		Betrayal = { text = "BETRAYAL!", tier = "Medium", color = "Mega" },
		Chain = { text = "CHAIN ×%d", tier = "Medium", color = "Spark" }, -- %d = links; Big from ×5
		Boom = { text = "BOOM!", tier = "Medium", color = "Fuse" },
		DoubleBoom = { text = "DOUBLE BOOM!", tier = "Big", color = "Fuse" },
		TripleBoom = { text = "TRIPLE BOOM!", tier = "Big", color = "Detonate" },
		Survived = { text = "SURVIVED", tier = "Small", color = "Runner" },
		AllClear = { text = "ALL CLEAR", tier = "Small", color = "Safe" },
		LastStand = { text = "LAST STAND!", tier = "Big", color = "Gold" },
		Dodge = { text = "DODGE!", tier = "Small", color = "Runner" },
	} :: { [string]: Callout },
	CHAIN_BIG = 5, -- a chain this long is a Big callout
	MULTI_BOOM_WINDOW = 4, -- seconds: booms of yours this close together make a DOUBLE / TRIPLE
	MAX_ON_SCREEN = 3,
}
