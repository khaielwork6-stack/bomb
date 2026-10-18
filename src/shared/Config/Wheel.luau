--!strict
-- The lobby spin wheel (the owner's reference video; DECISIONS 2026-10-17 "extras"). PROPOSED values — the prizes,
-- odds, free-spin timer and the spin products are the owner's call (monetisation): logged in docs/DECISIONS.md as
-- pending. Segments run clockwise from 12 o'clock, matching art/ui/make_wheel.py's colours (red, orange, yellow,
-- green, cyan, blue, purple, pink). Every prize respects F-ECO-03 (no single gift above ~550 Stars).
-- Server side (rolling, the timer, the products) is the partner's: docs/PARTNER_REQUESTS.md #2.

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
	FREE_EVERY = 12 * 3600, -- seconds between free spins
	PRODUCTS = { -- Robux developer products (id 0 = not created yet: the buttons are hidden)
		Spin1 = { id = 0, robux = 25, spins = 1 },
		Spin5 = { id = 0, robux = 99, spins = 5 },
	},
	SPIN_TIME = 4.2, -- seconds of spin animation
	SPIN_TURNS = 5, -- full turns before landing
}
