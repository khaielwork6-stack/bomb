-- Single source of truth for every color, font and texture the builders use.
-- To reskin the game: change values here, then re-run the builders (see builders/README.md).

local rgb = Color3.fromRGB

local Theme = {}

Theme.StudTexture = "rbxassetid://140680613862301"
Theme.StudTile = 2 -- studs per texture tile on large surfaces

Theme.Map = {
	Grass = rgb(88, 196, 96),
	GrassAlt = rgb(74, 182, 86),
	FieldA = rgb(92, 200, 102),
	FieldB = rgb(78, 186, 90),
	Stone = rgb(132, 130, 160),
	StoneDark = rgb(104, 102, 134),
	Water = rgb(52, 176, 238),
	Foam = rgb(132, 214, 250),
	Line = rgb(250, 250, 255),
	Wood = rgb(168, 112, 70),
	WoodDark = rgb(124, 80, 50),
	Trunk = rgb(122, 84, 56),
	Leaf = rgb(70, 176, 80),
	LeafLight = rgb(104, 204, 96),
	LeafDeep = rgb(52, 146, 70),
	Cloud = rgb(255, 255, 255),
	Flowers = { rgb(255, 120, 150), rgb(255, 214, 90), rgb(170, 140, 255), rgb(255, 255, 255) },
	Lantern = rgb(255, 196, 110),
	-- Second map (Blossom Court)
	Plank = rgb(214, 160, 108),
	PlankAlt = rgb(198, 144, 94),
	Blossom = rgb(255, 170, 200),
	BlossomLight = rgb(255, 204, 222),
	BlossomDeep = rgb(240, 128, 170),
	Temple = rgb(214, 70, 64),
	TempleRoof = rgb(64, 60, 92),
	TempleWall = rgb(246, 232, 210),
	Path = rgb(176, 172, 190),
	Gold = rgb(255, 200, 80),
	-- Map 3 "Skull's Revenge" (pirate galleon, 2026-10-09 grey box).
	ShipDeckA = rgb(198, 148, 94),
	ShipDeckB = rgb(184, 134, 84),
	ShipHull = rgb(96, 60, 40),
	ShipHullDark = rgb(66, 40, 28),
	ShipRail = rgb(150, 98, 58),
	ShipTrim = rgb(226, 178, 72),
	ShipIron = rgb(52, 54, 62),
	ShipRope = rgb(214, 186, 132),
	ShipSail = rgb(244, 232, 204),
	ShipMark = rgb(196, 52, 48),
	ShipGlass = rgb(70, 120, 170),
	ShipKraken = rgb(46, 118, 112),
	ShipBronze = rgb(176, 120, 52),
	SafeGreen = rgb(104, 184, 84),
	SafeTint = rgb(90, 230, 120),
}
-- Ship art (2026-10-09): textures from tools/make_ship_textures.py; the kraken from Studio's AI 3D.
Theme.ShipSkullSail = "rbxassetid://106256601224148"
Theme.ShipSkullDecal = "rbxassetid://121362833962749"
Theme.ShipKrakenAsset = 127513383508970

-- Map 1 v2 "The Meadow" (2026-10-09, the home map rebuilt to the user's ChatGPT concept set): palette + props
-- (tools/blender/meadow_props.py → assets/models/meadow/ids.json; the scarecrow from Studio's AI 3D).
Theme.Farm = {
	GrassA = rgb(120, 198, 80),
	GrassB = rgb(106, 184, 72),
	Lawn = rgb(98, 178, 74),
	Hill = rgb(110, 190, 86),
	HillDark = rgb(86, 168, 72),
	Stone = rgb(150, 144, 186),
	StoneDark = rgb(118, 112, 158),
	Kerb = rgb(176, 170, 206),
	BarnRed = rgb(198, 50, 44),
	BarnDark = rgb(150, 36, 34),
	Roof = rgb(96, 58, 50),
	Trim = rgb(248, 244, 234),
	Wood = rgb(150, 98, 58),
	WoodDark = rgb(110, 70, 40),
	Hay = rgb(232, 190, 92),
	Cream = rgb(244, 232, 210),
	Silo = rgb(186, 192, 204),
	SiloBand = rgb(132, 138, 154),
	Pond = rgb(70, 170, 220),
	Path = rgb(214, 190, 146),
	Awning = rgb(214, 54, 50),
	Blossom = rgb(255, 176, 206),
	Duck = rgb(250, 246, 236),
	Props = {
		Balloon = 113369488200433,
		HayBale = 89212110121343,
		OakTree = 94853671455982,
		Picket = 128696767181271,
		Pumpkin = 115161513577083,
		RoundBale = 76049846597519,
		Sails = 131449897323532,
		Tractor = 89719871794006,
		Lantern = 117566897223821, -- the Ship's
		Fern = 89791451718031, -- the Temple's, as bushes
		Scarecrow = 74125952566110, -- Studio AI 3D
	},
}

-- Map 4 "Temple of the Jade Jaguar" (2026-10-09): palette + textures (tools/make_temple_textures.py) + props
-- (tools/blender/temple_props.py → assets/models/temple/ids.json; the jaguar head and the monkey from Studio's AI 3D).
Theme.Jungle = {
	SandA = rgb(218, 186, 138),
	SandB = rgb(206, 172, 126),
	SandC = rgb(226, 194, 148),
	Stone = rgb(196, 162, 118),
	StoneDark = rgb(150, 118, 82),
	Walk = rgb(170, 140, 102),
	Cliff = rgb(140, 118, 94),
	CliffDark = rgb(108, 92, 76),
	Moss = rgb(92, 150, 62),
	Leaf = rgb(64, 158, 72),
	LeafDark = rgb(40, 118, 58),
	Trunk = rgb(140, 98, 62),
	Jade = rgb(60, 230, 200),
	Gold = rgb(246, 196, 72),
	GoldDark = rgb(196, 140, 40),
	Red = rgb(168, 36, 40),
	Flame = rgb(255, 170, 60),
	Spirit = rgb(90, 200, 255),
	Fall = rgb(170, 228, 248),
	Glyph = "rbxassetid://118890679367293",
	Paw = "rbxassetid://84419458620875",
	SunWheel = "rbxassetid://135320323008242",
	Banner = "rbxassetid://78321544961454",
	Props = {
		Boulder = 120584668537983,
		Fern = 89791451718031,
		Moon = 79422822994269,
		Palm = 79447607135214,
		SunDisc = 74330308524173,
		TorchBowl = 134327349408393,
		GlyphBlock = 140397364602573,
		JaguarHead = 122901840141712, -- Studio AI 3D
		Monkey = 102458477962909, -- Studio AI 3D
	},
}

-- Map 5 "The Grand Museum" (2026-10-09): tools/make_museum_textures.py, tools/blender/museum_props.py (+ the T-rex
-- skeleton, the marble lions and the baby dino from Studio's AI 3D).
Theme.Museum = {
	Cream = rgb(248, 232, 210),
	Rose = rgb(238, 188, 178),
	Seam = rgb(214, 170, 90),
	Marble = rgb(242, 234, 222),
	MarbleWarm = rgb(232, 218, 196),
	MarbleDark = rgb(196, 182, 162),
	Black = rgb(40, 38, 46),
	Gold = rgb(240, 190, 70),
	GoldDark = rgb(176, 124, 40),
	Red = rgb(176, 30, 44),
	RedDark = rgb(120, 18, 30),
	Velvet = rgb(150, 20, 36),
	Wall = rgb(236, 214, 182),
	WallDark = rgb(204, 176, 140),
	Glass = rgb(180, 214, 236),
	Iron = rgb(70, 74, 86),
	Bone = rgb(236, 226, 200),
	Lamp = rgb(255, 200, 120),
	Ghost = rgb(110, 255, 170),
	Compass = "rbxassetid://71075885679582",
	Banner = "rbxassetid://140396807216362",
	Crown = "rbxassetid://98254780266025",
	Paintings = {
		"rbxassetid://88952872941303",
		"rbxassetid://126346668383221",
		"rbxassetid://81607855469943",
	},
	Props = {
		Column = 139306431233511,
		Crown = 103794307338819,
		Globe = 112881677379817,
		PlinthCrown = 136069886340692,
		PlinthMask = 114056656007853,
		PlinthSkull = 138970233197096,
		PlinthVase = 88106677554843,
		Stanchion = 104720547952705,
		TorchBowl = 134327349408393, -- the Temple's, recoloured
		Palm = 79447607135214, -- the Temple's, in a pot
		TRex = 70746538740401, -- Studio AI 3D
		Lion = 82923880143601, -- Studio AI 3D
		BabyDino = 120171340383620, -- Studio AI 3D
	},
}

-- Map 6 "Sugar Rush Factory" (2026-10-09): tools/make_factory_textures.py, tools/blender/factory_props.py (+ the
-- gummy bear from Studio's AI 3D).
Theme.Factory = {
	Pink = rgb(242, 172, 194),
	Mint = rgb(178, 228, 198),
	Seam = rgb(214, 214, 224),
	Cream = rgb(250, 238, 222),
	CreamDark = rgb(232, 214, 192),
	Choc = rgb(92, 52, 34),
	ChocLight = rgb(130, 78, 48),
	ChocGloss = rgb(110, 60, 36),
	Wafer = rgb(232, 196, 140),
	Red = rgb(226, 40, 52),
	White = rgb(250, 246, 240),
	Gold = rgb(240, 190, 70),
	Chrome = rgb(196, 204, 216),
	Neon = rgb(255, 90, 170),
	Glass = rgb(210, 236, 248),
	Frosting = rgb(255, 150, 196),
	Gums = { rgb(236, 52, 64), rgb(60, 160, 240), rgb(250, 200, 50), rgb(90, 200, 90), rgb(180, 90, 220) },
	Labels = { rgb(246, 120, 170), rgb(90, 190, 240), rgb(250, 200, 60), rgb(130, 210, 110), rgb(186, 130, 236) },
	Swirl = "rbxassetid://102641875589193",
	Hills = "rbxassetid://96947839997596",
	Props = {
		CanePillar = 114900044104105,
		CaneRail = 138487069595500,
		GumballMachine = 93263956994921,
		Lollipop = 109197067143317,
		RailPost = 107206810871345,
		SyrupTank = 102802214331083,
		WaferBlock = 113371545003803,
		GummyBear = 90802066828450, -- Studio AI 3D
	},
}

-- Map 7 "The Toy Box" (2026-10-09): tools/make_toy_textures.py, tools/blender/toy_props.py (+ the teddy bear, the
-- toy soldier and the sleeping cat from Studio's AI 3D).
Theme.Toy = {
	Mat = rgb(214, 232, 244),
	MatAlt = rgb(236, 240, 228),
	MatSeam = rgb(196, 210, 222),
	Boards = rgb(196, 140, 92),
	BoardsDark = rgb(164, 112, 70),
	Rug = rgb(120, 150, 210),
	Wood = rgb(236, 204, 150),
	WoodDark = rgb(176, 128, 80),
	Shelf = rgb(176, 120, 72),
	ShelfDark = rgb(132, 86, 50),
	Wall = rgb(250, 234, 206),
	WallDark = rgb(232, 210, 176),
	Red = rgb(220, 50, 50),
	Blue = rgb(50, 110, 220),
	Yellow = rgb(250, 200, 50),
	Green = rgb(70, 170, 80),
	Orange = rgb(236, 130, 40),
	Purple = rgb(150, 90, 210),
	Cream = rgb(248, 238, 220),
	Felt = rgb(70, 64, 60),
	Stitch = rgb(255, 214, 70),
	Board = rgb(46, 52, 50),
	Sun = rgb(255, 214, 150),
	Letters = {
		{ "rbxassetid://104028305951060", rgb(220, 50, 50) }, -- A, red
		{ "rbxassetid://121145614210061", rgb(50, 110, 220) }, -- B, blue
		{ "rbxassetid://124796129145196", rgb(236, 130, 40) }, -- C, orange
		{ "rbxassetid://110280779891096", rgb(250, 200, 50) }, -- star, yellow
	},
	Playmat = "rbxassetid://114308071196655",
	Props = {
		AlphaBlock = 99041286842056,
		BeachBall = 128698303487018,
		Brick = 94972831422885,
		CastleTower = 71842832113203,
		Crayon = 90808248429264,
		Rocket = 102704443516181,
		TrainCar = 110112069104291,
		Teddy = 75890653060273, -- Studio AI 3D
		Soldier = 138441585746669, -- Studio AI 3D
		Cat = 95667307506997, -- Studio AI 3D
	},
}

Theme.Crates = {
	Solar = {
		Name = "SOLAR CRATE",
		Body = rgb(255, 112, 72),
		BodyDark = rgb(214, 70, 92),
		Trim = rgb(255, 214, 92),
		Gem = rgb(120, 255, 240),
		Glow = rgb(255, 160, 70),
		LabelTop = rgb(255, 230, 120),
		LabelBottom = rgb(255, 110, 80),
	},
	Aurora = {
		Name = "AURORA CRATE",
		Body = rgb(52, 70, 150),
		BodyDark = rgb(36, 46, 110),
		Trim = rgb(110, 250, 210),
		Gem = rgb(200, 140, 255),
		Glow = rgb(90, 240, 220),
		LabelTop = rgb(150, 255, 230),
		LabelBottom = rgb(170, 130, 255),
	},
}

Theme.UI = {
	Panel = rgb(255, 250, 238),
	Surface = rgb(255, 255, 255),
	Surface2 = rgb(224, 235, 248),
	Stroke = rgb(27, 31, 59),
	StrokeSoft = rgb(180, 195, 216),
	Text = rgb(27, 31, 59),
	TextMuted = rgb(78, 91, 120),
	TextDim = rgb(98, 108, 133),
	Accent = rgb(61, 183, 255),
	Accent2 = rgb(138, 92, 255),
	Coin = rgb(255, 210, 63),
	Gem = rgb(59, 227, 139),
	GemButton = rgb(30, 86, 74),
	RobuxButton = rgb(98, 70, 30),
	Danger = rgb(255, 75, 75),
	Success = rgb(59, 227, 139),
	Rarity = {
		Common = rgb(183, 195, 208),
		Rare = rgb(61, 183, 255),
		Epic = rgb(138, 92, 255),
		Legendary = rgb(255, 176, 32),
		Exclusive = rgb(255, 95, 162),
	},
	-- Accent color per menu tile / tab
	Tile = {
		Shop = rgb(255, 194, 61),
		Knives = rgb(92, 225, 230),
		Journey = rgb(176, 124, 255),
		AFK = rgb(255, 138, 61),
		Settings = rgb(200, 196, 230),
		Music = rgb(75, 227, 176),
	},
	Radius = { Panel = 24, Card = 18, Button = 16 },
	Font = {
		Display = Enum.Font.FredokaOne,
		Bold = Enum.Font.BuilderSansExtraBold,
		Semi = Enum.Font.BuilderSansBold,
		Body = Enum.Font.BuilderSansMedium,
	},
}

return Theme
