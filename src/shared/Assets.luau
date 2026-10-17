--!strict
-- Every asset reference goes through this table (Asset Bible §8-12). Swap placeholders here only.
-- Audio status "candidate" = exists and is free on the Creator Store (2026-10-06) but not auditioned yet;
-- each has alternates. src: R = Roblox official, PSE = ProSoundEffects, APM = APMOfficial, C = verified community, BI = built-in.

type Sound = {
	id: string,
	volume: number,
	pitch: { number }?,
	looped: boolean?,
	src: string,
	alt: { string }?,
	region: { number }?, -- play only this slice of the file (seconds)
}

local function s(id: number | string, volume: number, src: string, extra: { [string]: any }?): Sound
	local entry: any = {
		id = if type(id) == "number" then "rbxassetid://" .. tostring(id) else id,
		volume = volume,
		src = src,
	}
	if extra then
		for k, v in pairs(extra) do
			entry[k] = v
		end
	end
	return entry
end

local Assets = {}

-- The partner's stud tile (builders/Theme.luau), for runtime-built geometry that must match the lobby.
Assets.StudTexture = "rbxassetid://140680613862301"

Assets.SFX = {
	-- UI
	UIClick = s(15675059323, 0.6, "R"),
	UIHover = s(10066931761, 0.35, "R"),
	UISelect = s(10066968815, 0.6, "R"),
	UIOpen = s(15674975792, 0.5, "R"),
	UIClose = s(15675028888, 0.45, "R"),
	UIPop = s(15675055424, 0.6, "R"),
	UIStinger = s(15675043410, 0.7, "R"),
	UIPaper = s(15675037413, 0.5, "R"),
	UIToast = s(17208204604, 0.5, "R"),
	UIPurchase = s(10066947742, 0.8, "R"),
	UIError = s(9113085623, 0.35, "PSE", { pitch = { 1.2, 1.2 } }),
	UITick = s(12221990, 0.5, "R"),
	-- Countdown + wheel (2026-10-07, measured with AudioAnalyzer: sharp attack, short tail, one hit each).
	CountBeep = s(9113867159, 0.75, "PSE"), -- synth hit, bright: 21 ms attack, 0.14 s tail
	CountTone = s(9119143270, 0.35, "PSE"), -- clean single tone under the hit (body)
	WheelClack = s(9126261241, 0.7, "PSE", { region = { 0.085, 0.2 } }), -- one wooden-ratchet clack: the flapper
	WheelWhoosh = s(9126229255, 0.55, "PSE"),
	WheelPrize = s(10066947742, 0.8, "R"),
	-- Movement & combat
	Swing = s(12222200, 0.7, "R", { pitch = { 0.95, 1.1 }, alt = { "rbxassetid://9126283592" } }),
	Catch = s(121281067238166, 0.9, "C", { alt = { "rbxassetid://3765689841", "rbxassetid://12222054" } }),
	Squeak = s(15725545250, 0.6, "C"),
	BodyThud = s(9113480915, 0.7, "PSE"),
	Dive = s(9113080188, 0.7, "PSE"),
	Dash = s(9126229255, 0.7, "PSE", { alt = { "rbxassetid://9114157695" } }),
	HardStop = s(9118740493, 0.7, "PSE"),
	-- (2026-10-08: was 16480576404, an impact up front that died before the slide did.) A ground slide that hits
	-- at 0.12 s and holds through the 0.65 s slide before tailing off (AudioAnalyzer); alt: a softer, longer one.
	Slide = s(114100466629000, 0.55, "C", { alt = { "rbxassetid://105544173943722" } }),
	-- Footsteps (2026-10-08): four soft single-hit steps (≈50 ms, measured), one picked at random per footfall;
	-- FootstepController sets volume and pitch from the pace.
	Footstep1 = s(123224557798023, 0.5, "C"),
	Footstep2 = s(131412978408311, 0.42, "C"),
	Footstep3 = s(114768473003662, 0.45, "C"),
	Footstep4 = s(91882016473062, 0.7, "C"),
	NearMiss = s(9125959352, 0.5, "PSE"),
	PerfectDodge = s(9125805579, 0.7, "PSE", { pitch = { 0.8, 0.8 } }),
	RecordScratch = s(112792997660073, 0.8, "C"),
	Revive = s(9116394545, 0.7, "PSE"),
	Safe = s(18448089848, 0.6, "C"),
	StarPickup = s(6493135129, 0.6, "C"),
	Tumble = s(9113480917, 0.6, "PSE"),
	GetUp = s("rbxasset://sounds/action_get_up.mp3", 0.5, "BI"),
	Land = s("rbxasset://sounds/action_jump_land.mp3", 0.6, "BI"),
	-- Round flow
	Whistle = s(9117261163, 0.7, "PSE"),
	CountTick = s(12221990, 0.5, "R"),
	CleanEscape = s(9047103106, 0.8, "APM"),
	StreakBroken = s(1836245036, 0.7, "APM"),
	WinSting = s(1841980129, 0.9, "APM"),
	LoseSting = s(1839303737, 0.8, "APM"),
	DrumRoll = s(4718483268, 0.8, "C"),
	Heartbeat = s(135925258529833, 0.8, "C"),
	LevelUp = s(112485797063762, 0.8, "C", { alt = { "rbxassetid://1839997894" } }),
	Confetti = s(137940311591228, 0.7, "C"),
	ComboPop = s(15675055424, 0.8, "R"),
	CrowdCheer = s(9120974378, 0.6, "PSE"),
	CrowdBoo = s(9114010280, 0.5, "PSE"),
	CrowdGasp = s(9114013354, 0.6, "PSE"),
	CrowdLoop = s(9120974094, 0.25, "PSE", { looped = true }),
	SlotSpin = s(9118047781, 0.5, "PSE", { pitch = { 1.3, 1.3 } }),
	SlotLand = s(15675043410, 0.7, "R"),
	BlockGrind = s(4331052561, 0.6, "C", { alt = { "rbxassetid://16480551414" } }),
	-- (2026-10-07: was 16480577565, a harsh screech the user flagged.) Positive sting: Double Brave, Brave boost, Foam.
	TierUp = s(10066947742, 0.6, "R"),
	-- Tier banners ("Catchers −3 % speed"): a deep, smooth whoosh instead of a sting.
	TierWarn = s(9126229255, 0.6, "PSE", { pitch = { 0.75, 0.75 } }),
	-- Modifiers / themes
	ModGiant = s(9125404769, 0.7, "PSE"),
	ModLightsOut = s(9117872887, 0.7, "PSE"),
	ModFog = s(9113080102, 0.5, "PSE", { pitch = { 0.7, 0.7 } }),
	ModWind = s(110536638811166, 0.7, "C"),
	ModIce = s(9125611419, 0.6, "PSE"),
	ModLowGrav = s(9125648149, 0.6, "PSE"),
	ModTiny = s(96569598878843, 0.7, "C"),
	ModRush = s(9125805781, 0.7, "PSE"),
	ModGolden = s(117011707307950, 0.7, "C"),
	ModMud = s(9125703162, 0.6, "PSE"),
	ThemeFreeze = s(15749927835, 0.7, "C"),
	ThemeShatter = s(103951468240244, 0.7, "C"),
	ThemeGhost = s(114989963690677, 0.7, "C"),
	-- Hazards
	HazRollRumble = s(16480554368, 0.7, "R", { looped = true }),
	HazSprinkler = s(9120591369, 0.4, "PSE", { looped = true }),
	HazSoak = s("rbxasset://sounds/impact_water.mp3", 0.5, "BI"),
	HazStampede = s(9120987613, 0.8, "PSE"),
	HazCrumbleWarn = s(9125869504, 0.6, "PSE"),
	HazCrumbleDrop = s(9118689425, 0.7, "PSE"),
	HazConveyor = s(9113910422, 0.35, "PSE", { looped = true }),
	HazTelegraph = s(12221990, 0.5, "R", { pitch = { 1.4, 1.4 } }),
	-- Abilities
	AbSmoke = s(9125640290, 0.8, "PSE"),
	AbSpring = s(12222124, 0.8, "R"),
	AbBubbleUp = s(9112752910, 0.7, "PSE"),
	AbBubblePop = s(9113263649, 0.8, "PSE"),
	AbMarbles = s(18520505457, 0.7, "C"),
	AbCutoutPlace = s(9113578540, 0.7, "PSE"),
	AbCutoutPop = s(83133904966909, 0.8, "C"),
	AbWhistle = s(9118113825, 0.8, "PSE"),
	AbNetThrow = s(9126283592, 0.7, "PSE"),
	AbNetHit = s(9113817566, 0.8, "PSE"),
	AbTrapPlace = s(9119990528, 0.6, "PSE"),
	AbTrapTrigger = s(75221355097604, 0.8, "C"),
	AbFlare = s(113248727573901, 0.7, "C"),
	AbPound = s(74149238738530, 0.9, "C", { alt = { "rbxassetid://16480557599" } }),

	-- TITAN HUNT (licensed libraries: Pro Sound Effects / APM; the horn is a Creator Store upload)
	TitanHorn = s(122391463645938, 0.75, "C"), -- the event warning + the rise
	TitanRoar = s(9113980319, 1, "PSE"), -- giant creature roar
	TitanSlamBoom = s(91288569991875, 1, "C"), -- the hammer's impact (layered over AbPound)
	TitanSlamHit = s(1843023322, 0.8, "APM"), -- cinematic hit under the impact
	TitanRumble = s(9113218938, 0.7, "PSE"), -- rock crumble after the slam
	TitanQuake = s(9112775165, 0.55, "PSE"), -- low earthquake drone (looped while it rises)
	TitanStep = s(115163143171771, 0.7, "C"), -- giant footstep
	TitanCrystalHit = s(9114604477, 0.8, "PSE"), -- weak spot struck
	TitanBodyHit = s(9113524242, 0.9, "PSE"), -- the weak spot hit's thump
	TitanThump = s(1837830314, 0.8, "APM"), -- deep thump (countdown, kneel)
	TitanFall = s(9113470802, 1, "PSE"), -- the Titan hits the floor
}

Assets.Music = {
	Lobby = s(1843404009, 0.5, "APM", { looped = true }),
	["Match.Classic"] = s(1847683499, 0.45, "APM", { looped = true }),
	["Match.Foam"] = s(1847851024, 0.45, "APM", { looped = true }),
	["Match.Snow"] = s(9046740461, 0.45, "APM", { looped = true }),
	["Match.Ghost"] = s(1836271798, 0.45, "APM", { looped = true }),
	["Match.Titan"] = s(128007000574959, 0.5, "DK", { looped = true }), -- Epic Boss Battle
	Showdown = s(1848090337, 0.5, "APM", { looped = true }),
	LastStand = s(1836391539, 0.5, "APM", { looped = true }),
	Results = s(1842802498, 0.45, "APM"),
}

local P = "rbxasset://textures/particles/"
Assets.Particles = {
	Sparkle = P .. "sparkles_main.dds",
	Smoke = P .. "smoke_main.dds",
	Fire = P .. "fire_main.dds",
	FireSpark = P .. "fire_sparks_main.dds",
	Shockwave = P .. "explosion01_shockwave_main.dds",
	Core = P .. "explosion01_core_main.dds",
	Glow = P .. "forcefield_glow_main.dds",
	Vortex = P .. "forcefield_vortex_main.dds",
	Square = P .. "SquareParticle.png",
	-- The ability VFX set (2026-10-08, tools/make_vfx_textures.py → assets/textures/vfx, group-owned images): white
	-- shapes the emitter's Color tints. Crack is a dark decal for the floor, not a particle.
	SoftGlow = "rbxassetid://113432815538291",
	Twinkle = "rbxassetid://110894814058370",
	Ring = "rbxassetid://113119465337008",
	Streak = "rbxassetid://109779237884641",
	Puff = "rbxassetid://81455231479631",
	Bubble = "rbxassetid://79301950018261",
	Blob = "rbxassetid://98407470978232",
	Note = "rbxassetid://126220104233197",
	Flake = "rbxassetid://82958539555744",
	Pebble = "rbxassetid://107937743686383",
	Crack = "rbxassetid://114128473895872",
	DizzyStar = "rbxassetid://119088900411600",
}

Assets.Anim = {
	-- TITAN HUNT boss (tools/anim/Titan*.luau → published to the group 2026-10-15). Live servers keep the event off
	-- unless all eight are set (Config.Titan.REQUIRE_ANIMS).
	TitanIdle = "rbxassetid://98326586787465",
	TitanWalk = "rbxassetid://90675009643945",
	TitanRoar = "rbxassetid://74252607821700",
	TitanSlam = "rbxassetid://85616979931548",
	TitanKneel = "rbxassetid://129346793265824",
	TitanHit = "rbxassetid://85416438974709",
	TitanRise = "rbxassetid://135486020843970",
	TitanFall = "rbxassetid://105076624543324",
	-- Gameplay actions (tools/anim/*.luau → published to the group). Empty = procedural pose fallback.
	Dash = "rbxassetid://75704029009727",
	-- Side dashes (2026-10-07): a dash to the left / right of where the body faces (A / D, omnimovement) keeps
	-- facing ahead and plays these instead of the forward dash.
	DashLeft = "rbxassetid://135292503614941",
	DashRight = "rbxassetid://86994402870442",
	-- The user's movement set (2026-10-08): DashBack = the backward hop (S + dash, keeps facing ahead); Land = the dip
	-- after a real fall (Config LAND_MIN_AIR); Fall = the airborne loop (Locomotion; was Roblox's stock fall);
	-- StrafeLeft / StrafeRight = sideways run cycles the Locomotion layer blends in as the line of travel swings
	-- across the body (A / D, omnimovement); Equip = drawing the weapon when it appears in the hand.
	DashBack = "rbxassetid://110857346305282",
	Land = "rbxassetid://94922193663467",
	Fall = "rbxassetid://94527633937528",
	StrafeLeft = "rbxassetid://86125662963794",
	StrafeRight = "rbxassetid://130974800371567",
	Equip = "rbxassetid://86228175142812",
	-- Slide / Dive / Brake: the user's second set (2026-10-06, 0.917 s each, exported as looping Movement clips; the
	-- game plays them once at Action priority, paced to each move's real duration, see PoseController / Locomotion).
	Slide = "rbxassetid://97050214215297",
	Swing = "rbxassetid://88795122086918", -- the catcher's swing (2026-10-08, the user's clip)
	Dive = "rbxassetid://82619140581322",
	HardStop = "rbxassetid://78047444691420",
	RunnerReady = "rbxassetid://110889767444388", -- loop: runners' stance through GET READY
	-- Locomotion layer (Shared/Locomotion): Idle + the Run cycle (one clip for every running speed, its cadence driven
	-- by ground speed) + the Brake settle when a run stops.
	Idle = "rbxassetid://114189129096906",
	Run = "rbxassetid://75779803985231",
	Jog = "rbxassetid://75779803985231", -- = Run (the first set's separate Jog / Sprint were replaced by Run)
	Sprint = "rbxassetid://75779803985231",
	Brake = "rbxassetid://93549571432720", -- (2026-10-07, the user's id; the same 0.92 s clip re-uploaded)
	-- Walk (the user's clip, 2026-10-07, a 1.33 s cycle): slow steps, and the omnimovement backpedal plays it reversed.
	Walk = "rbxassetid://77433291886179",

	-- R6 default emotes as victory-emote placeholders (verify in Studio)
	EmoteCheer = "rbxassetid://129423030",
	EmoteWave = "rbxassetid://128777973",
	EmoteLaugh = "rbxassetid://129423131",
	EmotePoint = "rbxassetid://128853357",
	EmoteDance = "rbxassetid://182435998",
	EmoteRobot = "rbxassetid://182436935",
}

-- Reference UI art (assets/ui/*.png, supplied by the user 2026-10-06; the newest, highest-quality files listed).
-- Upload each image (Studio: Asset Manager → Bulk Import) and paste its id below as "rbxassetid://<id>". Every
-- screen picks it up automatically (Arcade.img / Arcade.star): the shop and HUD Stars, the spin wheel and pointer,
-- the spin / crate / results rewards, the reward hammers. Until then the screens draw a fallback (★ glyph, drawn 3D
-- wheel, part-built hammer preview).
Assets.UI = {
	Star = "", -- star.png: single gold star (currency pill, shop, results, round pips)
	Stars3 = "", -- "3 star.png": three stars (small Stars reward)
	StarPile = "", -- "multi star.png": star pile (big Stars reward)
	HammerParty = "", -- hammer.png: pink/teal hammer (invite reward)
	HammerToy = "", -- "hammer 2.png": blue/yellow toy hammer (group reward)
	HammerStar = "", -- "hammer 3.png": purple/gold star hammer (spin jackpot)
	Wheel = "", -- "wheel spin.png": 6-segment spin wheel (orange at the top, clockwise like Config.Social.Spin)
	Pointer = "", -- "wheel spin triangle.png": gold pointer
}

return Assets
