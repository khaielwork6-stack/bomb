--!strict
-- The lobby spin wheel (the owner's reference video; DECISIONS 2026-10-17 "extras"; prizes, odds, timer and prices
-- set 2026-10-18 by the owner's go-ahead: "decide the prices… we could change this later"). Segments run clockwise
-- from 12 o'clock, matching art/ui/make_wheel.py's colours (red, orange, yellow, green, cyan, blue, purple, pink).
-- Every prize respects F-ECO-03 (no single gift above ~550 Gems). Server: PerkService (the roll, the free timer); the
-- +1 / +5 spin products live in Config.Store.PRODUCTS (Spin1 / Spin5).

return {
	SEGMENTS = {
		{ kind = "Stars", amount = 50, weight = 20 },
		{ kind = "Crate", crate = "Spark", weight = 8 },
		{ kind = "Stars", amount = 25, weight = 24 },
		{ kind = "Stars", amount = 100, weight = 12 },
		{ kind = "Stars", amount = 75, weight = 16 },
		{ kind = "Crate", crate = "GiftBox", weight = 4 },
		{ kind = "Stars", amount = 250, weight = 2 },
		{ kind = "Stars", amount = 40, weight = 14 },
	},
	FREE_EVERY = 8 * 3600, -- seconds between free spins
	SPIN_TIME = 4.2, -- seconds of spin animation
	SPIN_TURNS = 5, -- full turns before landing
}
