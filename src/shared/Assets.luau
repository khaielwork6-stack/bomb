--!strict
-- Every asset reference goes through this table (Asset Bible §10.5): code uses keys, never raw ids.
-- src: R = Roblox official, PSE = ProSoundEffects, APM = APMOfficial, C = verified community, BI = built-in,
-- FV = sound-designed in-house (art/audio), MA = the licensed MA BG pack (art/audio/in → master_licensed.py).
-- An id of "" means the in-house file is waiting to be uploaded; code falls back until it lands.
-- P0: only what the transferred movement uses (from Chase Game). The FUSE VALLEY sound stacks (Asset Bible §9) and
-- the bomb's assets are added as their phases land.

type Sound = {
	id: string,
	volume: number,
	pitch: { number }?,
	looped: boolean?,
	src: string,
	alt: { string }?, -- other takes of the same sound, picked at random (a frequent moment never repeats exactly)
	fallback: string?, -- an in-house (FV) upload's licensed stand-in, played if the upload fails to load (moderation)
	region: { number }?, -- play only this slice of the file (seconds)
	gap: number?, -- minimum seconds between two plays of this key (spam guard for hover / deny)
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

Assets.SFX = {
	-- Movement (Chase Game's tuned set; replaced by designed stacks in the P3 audio pass, Asset Bible §9)
	-- In-house (art/audio/make_sfx.py) since 2026-10-17; `alt` = the licensed sound Sfx falls back to if the in-house
	-- upload fails to load (moderation).
	Dash = s(122478519337941, 0.5, "FV", { pitch = { 0.92, 1.08 }, fallback = "rbxassetid://9126229255" }),
	HardStop = s(97594064286635, 0.55, "FV", { pitch = { 0.95, 1.05 }, fallback = "rbxassetid://9118740493" }),
	Slide = s(75023722365729, 0.45, "FV", { pitch = { 0.92, 1.06 }, fallback = "rbxassetid://114100466629000" }),
	Land = s(
		132981043048107,
		0.55,
		"FV",
		{ pitch = { 0.92, 1.06 }, fallback = "rbxasset://sounds/action_jump_land.mp3" }
	),
	-- Footsteps: four recorded concrete heel-toe steps (MA pack, level-matched by master_licensed.py), one picked at
	-- random per footfall, never the same twice (FootstepController sets the pace). `fallback` = the in-house steps.
	Footstep1 = s(120537674142798, 0.45, "MA", { pitch = { 0.97, 1.03 }, fallback = "rbxassetid://83118919801898" }),
	Footstep2 = s(124641044387047, 0.45, "MA", { pitch = { 0.97, 1.03 }, fallback = "rbxassetid://132859876751182" }),
	Footstep3 = s(134717983508465, 0.45, "MA", { pitch = { 0.97, 1.03 }, fallback = "rbxassetid://117564083525822" }),
	Footstep4 = s(75329618622008, 0.45, "MA", { pitch = { 0.97, 1.03 }, fallback = "rbxassetid://131466290951841" }),

	-- The bomb (Asset Bible §9.2; licensed APM / Pro Sound Effects / Roblox, most already shipped by Chase Game).
	-- Each moment is a STACK of layers (AudioController), never one stock sound.
	FuseHiss = s(1841092807, 0.32, "APM", { looped = true }), -- "Burning Fuse (a)": the cord's loop on every bomb
	BombTick = s(12221990, 0.55, "R"), -- fallback single tick (until the in-house set below is uploaded)
	-- The in-house escapement (art/audio/make_ticks.py): tick / tock alternate like a real movement; the HOT pair is
	-- brighter and tighter for CRITICAL, so escalation changes timbre instead of pitching one sample up.
	BombTickA = s(91973479747444, 0.6, "FV"), -- bomb_tick.wav
	BombTickB = s(81248435015876, 0.6, "FV"), -- bomb_tock.wav
	BombTickHotA = s(132119182630967, 0.62, "FV"), -- bomb_tick_hot.wav
	BombTickHotB = s(114523246396813, 0.62, "FV"), -- bomb_tock_hot.wav (ids matched by spectrum: the uploads were renamed)
	BombClamp = s(9125782643, 0.6, "PSE", { pitch = { 1.05, 1.2 } }), -- a heavy metal lid set down: the clamp biting
	PassWhoosh = s(127131729161867, 0.5, "FV", { pitch = { 0.9, 1.1 }, fallback = "rbxassetid://9126229255" }), -- the flight between backs
	-- The slap (GDD F-BOMB-10): PSE "Hand Slap, Sharp Smacking" takes (the deep thud tail trimmed), layered over the
	-- clamp; the arm's swing is the pass whoosh, high and quick.
	Slap = s(9114772395, 0.8, "PSE", {
		pitch = { 0.97, 1.08 },
		region = { 0, 0.4 },
		alt = { "rbxassetid://9114772607", "rbxassetid://9114773010", "rbxassetid://9114773206" },
	}),
	SlapSwing = s(9126229255, 0.32, "PSE", { pitch = { 1.75, 1.95 } }),
	-- The Chain Song (GDD F-BOMB-14): one in-house mallet note tuned to C5 (art/audio/make_chain_note.py →
	-- chain_note.wav, uploaded by tools/upload.py), pitched by semitones up a major scale.
	ChainNote = s(120312887696662, 0.7, "FV"),
	BoomHit = s(1843023322, 0.9, "APM"), -- cinematic hit: the boom's punch
	BoomBody = s(9113470802, 0.75, "PSE"), -- a giant thud: the body of the boom
	BoomDebris = s(9113218938, 0.45, "PSE", { region = { 0, 2.2 } }), -- rock crumble: debris + tail (first 2.2 s of a 16 s file)
	Defuse = s(81997207354999, 0.45, "FV", { pitch = { 0.95, 1.08 }, fallback = "rbxassetid://9126229255" }), -- the snuff whoosh
	Safe = s(18448089848, 0.55, "C"), -- the defuse chime
	Clutch = s(9047103106, 0.8, "APM"), -- the CLUTCH DEFUSE sting
	Klaxon = s(9119662934, 0.5, "PSE"), -- the Field Fuse at 5 s
	Heartbeat = s(9043365842, 0.7, "APM", { looped = true }), -- the Carrier's heartbeat (96 BPM, sped up by stage)
	DrumRoll = s(4718483268, 0.75, "C"), -- the Last Stand reveal
	CrowdLoop = s(9120974094, 0.3, "PSE", { looped = true }),
	CrowdCheer = s(9120974378, 0.6, "PSE"),
	CrowdGasp = s(9114013354, 0.6, "PSE"),
	WinSting = s(1841980129, 0.85, "APM"),
	-- UI (Asset Bible §6.3, §6.5). The licensed MA pack where it fits (each placed by meaning, not just sound):
	-- the click (press + release in one, so UiRelease is no longer played) on every button and, pitched up, on tabs;
	-- a soft no-attack swell on hover; a rising "on" and a falling "off" for settings toggles, the "off" doubling as
	-- the gentle deny; "earn" on every claim; "purchase" on every buy; "notify" only on rare attention moments (the
	-- map vote opening, a NEW ITEM toast), never on callouts. `fallback` = the in-house sound while moderation runs.
	-- The rest stays in-house (art/audio/make_ui.py) until licensed replacements arrive.
	UiPress = s(103221186174166, 0.7, "MA", { pitch = { 0.98, 1.02 }, fallback = "rbxassetid://81143391231439" }),
	UiRelease = s(84273825969787, 0.3, "FV", { pitch = { 0.97, 1.03 } }),
	UiHover = s(
		81336814545607,
		0.1,
		"MA",
		{ pitch = { 0.97, 1.03 }, gap = 0.08, fallback = "rbxassetid://88139694011190" }
	),
	UiDeny = s(89291088515971, 0.55, "MA", { gap = 0.25, fallback = "rbxassetid://120904740098220" }),
	ToggleOn = s(128576867211606, 0.55, "MA", { fallback = "rbxassetid://81143391231439" }),
	ToggleOff = s(89291088515971, 0.55, "MA", { fallback = "rbxassetid://84273825969787" }),
	Purchase = s(89949934133752, 0.8, "MA", { fallback = "rbxassetid://72019982036724" }),
	Notify = s(120568784950730, 0.6, "MA", { fallback = "rbxassetid://78051789530604" }),
	UiOpen = s(84771068236030, 0.35, "FV"),
	UiClose = s(136899153333162, 0.3, "FV"),
	UiTab = s(103221186174166, 0.5, "MA", { pitch = { 1.1, 1.14 }, fallback = "rbxassetid://74212251876794" }),
	CoinTick = s(136647661605856, 0.22, "FV", { pitch = { 1.0, 1.06 } }),
	Claim = s(115339350198039, 0.8, "MA", { fallback = "rbxassetid://72019982036724" }),
	Stamp = s(88717870625190, 0.6, "FV", { pitch = { 0.95, 1.05 }, fallback = "rbxassetid://9125782643" }),
	LevelUp = s(106482575046928, 0.7, "FV", { fallback = "rbxassetid://1841980129" }),
	QuestDone = s(115339350198039, 0.75, "MA", { fallback = "rbxassetid://78051789530604" }),
	LoseSting = s(1839303737, 0.75, "APM"),
	-- The rest of the Asset Bible §9.2 registry, sound-designed in-house (art/audio/make_sfx.py).
	BombIgnite = s(94650004025445, 0.6, "FV", { pitch = { 0.96, 1.04 } }), -- match strike + fuse catch: a fresh bomb
	BombCritical = s(113418011279575, 0.3, "FV", { looped = true }), -- the CRITICAL whine (sped up by stage)
	BoomFar = s(79037341690022, 0.7, "FV", { pitch = { 0.9, 1.05 } }), -- a low-passed boom tail beyond 40 studs
	FuseSnuff = s(82135849064349, 0.55, "FV", { pitch = { 0.95, 1.08 } }), -- the defuse: steam cut-off + "pft"
	BombRelease = s(131148544816507, 0.5, "FV", { pitch = { 0.95, 1.05 } }), -- the clamp's latch click
	BombDrop = s(129735512963271, 0.7, "FV", { pitch = { 0.92, 1.05 } }), -- iron clunk + roll on the floor
	ClutchChoir = s(117818951825637, 0.75, "FV"), -- the CLUTCH DEFUSE choir hit
	FieldDetonate = s(93733623616015, 0.9, "FV", { pitch = { 0.97, 1.03 } }), -- rolling firecracker chain + big boom
	CrowdChant = s(108507572630659, 0.35, "FV", { looped = true }), -- the Last Stand chant (120 BPM)
	CrowdGroan = s(129180994528762, 0.55, "FV", { pitch = { 0.97, 1.03 } }),
	StingerBombers = s(139980643414565, 0.8, "FV"), -- the BOMBERS reveal
	StingerBombersWin = s(122361568603534, 0.85, "FV"),
	CrateRattle = s(96106308068627, 0.45, "FV", { looped = true, pitch = { 0.97, 1.03 } }),
	CratePop = s(114428817474077, 0.6, "FV", { pitch = { 0.95, 1.05 } }),
	CrateLegendary = s(87602496884973, 0.75, "FV"),
	-- Emoji taunts (art/audio/make_taunts.py, art/out/Audio/Taunt): one funny sound per emoji (Config.Taunt)
	TauntLaugh = s(109865111885089, 0.8, "FV"),
	TauntCool = s(81466277295426, 0.8, "FV"),
	TauntAngry = s(125100758853148, 0.8, "FV"),
	TauntCry = s(71787502872704, 0.8, "FV"),
	TauntLove = s(126845671449662, 0.8, "FV"),
	TauntShock = s(79354411626426, 0.8, "FV"),
	TauntSilly = s(98176614675969, 0.8, "FV"),
	TauntSkull = s(83364544413961, 0.8, "FV"),
	TauntFire = s(133477966480256, 0.8, "FV"),
}

-- Music (licensed APM, from Chase Game's vetted list). AudioController crossfades by phase.
Assets.Music = {
	Lobby = s(1843404009, 0.45, "APM", { looped = true }),
	Round = s(1847683499, 0.4, "APM", { looped = true }),
	LastStand = s(1836391539, 0.45, "APM", { looped = true }),
	Results = s(1842802498, 0.42, "APM"),
}

-- Animations (tools/anim → published to the group; GDD §23.4: same group, so these ids work here).
Assets.Anim = {
	-- Techniques. Side dashes / backward hop keep facing ahead (omnimovement).
	Dash = "rbxassetid://75704029009727",
	DashLeft = "rbxassetid://135292503614941",
	DashRight = "rbxassetid://86994402870442",
	DashBack = "rbxassetid://110857346305282",
	Slide = "rbxassetid://97050214215297",
	HardStop = "rbxassetid://78047444691420",
	Land = "rbxassetid://94922193663467",
	-- Locomotion layer (Shared/Locomotion): Idle, one Run cycle for every speed, Brake, Fall, strafes, Walk (the
	-- backpedal plays it reversed).
	Idle = "rbxassetid://114189129096906",
	Run = "rbxassetid://75779803985231",
	Jog = "rbxassetid://75779803985231",
	Sprint = "rbxassetid://75779803985231",
	Brake = "rbxassetid://93549571432720",
	Fall = "rbxassetid://94527633937528",
	StrafeLeft = "rbxassetid://86125662963794",
	StrafeRight = "rbxassetid://130974800371567",
	Walk = "rbxassetid://77433291886179",
	-- The giant's walk set (Locomotion "Titan" variant), kept for the MEGA BOMBER (GDD §16, P6).
	TitanIdle = "rbxassetid://98326586787465",
	TitanWalk = "rbxassetid://90675009643945",
	-- Emotes (AB §8.5): tools/anim/Emote*.luau, baked by tools/anim/analyse.luau, published to the group through Open
	-- Cloud (tools/upload_assets.py, art/out/Anim/Emotes/ids.json). Played by the emote wheel (partner request #8).
	EmoteWave = "rbxassetid://130167640637477",
	EmoteFuseDance = "rbxassetid://135659766749255",
	EmoteJuggle = "rbxassetid://125731412786111",
	EmoteBow = "rbxassetid://130948412471725",
	EmoteShrug = "rbxassetid://91396877096563",
	EmoteVictory = "rbxassetid://93590265471803",
	EmoteKaboom = "rbxassetid://71279048772759",
	EmoteSitSip = "rbxassetid://130206929426189",
	-- the T taunt (tools/anim/Taunt.luau, baked offline by tools/anim/analyse.luau, art/out/Anim/Taunt)
	Taunt = "rbxassetid://70986811548741",
	-- The free emote page (the owner, 2026-10-18: good emotes for everyone, for now): Roblox's own R6 emotes from the
	-- default Animate script. They're Roblox-owned, so any game may play them (third-party toolbox animations can't
	-- play outside their owner's games). Checked on our R6 rig in Studio.
	FreeEmotes = {
		Wave = "rbxassetid://128777973",
		Point = "rbxassetid://128853357",
		Cheer = "rbxassetid://129423030",
		Laugh = "rbxassetid://129423131",
		Dance = "rbxassetid://182435998",
		Dance2 = "rbxassetid://182436842",
		Dance3 = "rbxassetid://182436935",
	},
	-- The slap (GDD F-BOMB-10), tools/anim/Slap + Stumble (in-house v1; uploaded by tools/upload.py, 2026-10-18).
	Slap = "rbxassetid://81555655127047",
	Stumble = "rbxassetid://95261557468863",
}

-- In-house VFX textures (Asset Bible §5), generated by art/vfx/make_vfx.py. White ones are tinted by the emitter;
-- Fireball has its colours baked in. Fireball and Smoke are 4×4 flipbooks (ParticleFlipbookLayout.Grid4x4).
Assets.Vfx = {
	Flash = "rbxassetid://103354150966713",
	Fireball = "rbxassetid://86017380944194",
	Smoke = "rbxassetid://98967284678053",
	Streak = "rbxassetid://121843210075045",
	Ring = "rbxassetid://72815615246237",
	Scorch = "rbxassetid://78443805189538",
	Ember = "rbxassetid://135076496021372",
	Smack = "rbxassetid://95072891972199", -- art/vfx/make_smack.py: the slap's comic burst (4×4 flipbook, OneShot)
	-- art/vfx/make_polish.py (effects polish)
	Steam = "rbxassetid://117250311396596", -- the defuse's steam curl (4×4 flipbook, OneShot)
	Rays = "rbxassetid://103682645214075", -- a 12-ray light burst (the clutch defuse)
	PassRibbon = "rbxassetid://71312280389111", -- the pass arc's ribbon (U = 0 at the head)
	JukeBolt = "rbxassetid://78003748823248", -- art/vfx/make_juke.py: the juke's yellow floor zigzag (arrow at +U)
	DangerRing = "rbxassetid://70459732327420", -- art/vfx/make_danger_ring.py: the Carrier's pass reach (GDD F-BOMB-11)
}

-- Cosmetic VFX textures (Asset Bible §5.6, §8.1–8.3), generated by art/vfx/make_cosmetics.py (recipes in
-- art/vfx/COSMETICS.md, wired by Client/VfxCosmetic). Image ids, keyed by texture name.
Assets.VfxCosmetic = {
	boom_blackhole_ring = "rbxassetid://74012319291455",
	boom_blackhole_swirl = "rbxassetid://94603259630119",
	boom_champagne_bubble = "rbxassetid://108590224467995",
	boom_champagne_cork = "rbxassetid://129835115080989",
	boom_champagne_foil = "rbxassetid://71002971616390",
	boom_confetti_pieces = "rbxassetid://133839444630040",
	boom_confetti_pop = "rbxassetid://82657620827570",
	boom_confetti_streamers = "rbxassetid://105584442191021",
	boom_frost_flake = "rbxassetid://123713561910197",
	boom_frost_ring = "rbxassetid://78947485137854",
	boom_frost_shard = "rbxassetid://132519090735861",
	boom_ink_droplet = "rbxassetid://104891357247999",
	boom_ink_floor = "rbxassetid://95418496628336",
	boom_ink_splash = "rbxassetid://87563157479918",
	boom_peony_burst = "rbxassetid://97593159657535",
	boom_peony_star = "rbxassetid://140259328287920",
	boom_pixel_cube = "rbxassetid://121788670120094",
	boom_pixel_pop = "rbxassetid://88161556788368",
	boom_pixel_ring = "rbxassetid://104871342390333",
	spark_electric_arc = "rbxassetid://80319198992331",
	spark_ember_dot = "rbxassetid://137985735661411",
	spark_goldleaf_flake = "rbxassetid://91207548804801",
	spark_insignia_star = "rbxassetid://134357421299771",
	spark_pixie_glitter = "rbxassetid://92659390708043",
	spark_plasma_ball = "rbxassetid://88415554217520",
	spark_plasma_mote = "rbxassetid://76944516231491",
	spark_sparkler_needle = "rbxassetid://82147137767204",
	spark_sparkler_star = "rbxassetid://99709791689216",
	trail_aurora = "rbxassetid://86428051780259",
	trail_comet = "rbxassetid://127165983709043",
	trail_neon = "rbxassetid://94286118742332",
	trail_rocket = "rbxassetid://137794285575421",
	trail_soot = "rbxassetid://137718441351708",
	trail_sparkline = "rbxassetid://137470485399495",
	trail_streamers = "rbxassetid://110441562654784",
	trail_victorylap = "rbxassetid://94994531007321",
	victory_champagne_bubble = "rbxassetid://97792458033497",
	victory_confetti_pieces = "rbxassetid://138830246567560",
	victory_dragon_head = "rbxassetid://132054825225172",
	victory_dragon_segment = "rbxassetid://87910256914684",
	victory_finale_peony = "rbxassetid://130318736066398",
	victory_fountain_glint = "rbxassetid://107499627113011",
	victory_fountain_spark = "rbxassetid://94714427761399",
} :: { [string]: string }

-- The 3D icon set (Asset Bible §6.4; DECISIONS 2026-10-17): every icon modelled and rendered in headless Blender
-- (art/icons/set_*.py, after the style sheets in art/ref/icons — references only), glossy and outlined like the
-- owner's reference video. Person and Badge are the older code-drawn grey masks, kept because they're tinted
-- (team colours, level-badge tiers) with ImageColor3.
Assets.Icon = {
	Arrow = "rbxassetid://117821840125144",
	Bomb = "rbxassetid://133060197792626",
	Bomber = "rbxassetid://78292183197315",
	Calendar = "rbxassetid://119147142908840",
	Camera = "rbxassetid://95897549537511",
	Check = "rbxassetid://111909409752577",
	Crate = "rbxassetid://95736964594049",
	CrateInferno = "rbxassetid://126599454962777",
	Crown = "rbxassetid://73831516682897",
	Dash = "rbxassetid://77716305483055",
	Explosion = "rbxassetid://133798276626021",
	Eye = "rbxassetid://78613970613513",
	Firework = "rbxassetid://120178461771701",
	Flame = "rbxassetid://121353708207412",
	Fuse = "rbxassetid://133620617581489",
	Gear = "rbxassetid://94166283617853",
	Gift = "rbxassetid://119214784967147",
	GiftBox = "rbxassetid://87537234097896",
	Heart = "rbxassetid://115099220022993",
	Items = "rbxassetid://71574508886078",
	LevelBadge = "rbxassetid://85443510497395",
	Lock = "rbxassetid://75991450465135",
	Mega = "rbxassetid://108548366590411",
	Palette = "rbxassetid://128000908560093",
	Plate = "rbxassetid://73991703226036",
	Plus = "rbxassetid://126591425858560",
	Runner = "rbxassetid://140092981769182",
	Scroll = "rbxassetid://133086287758831",
	Shield = "rbxassetid://93157874356560",
	Shop = "rbxassetid://79037630864503",
	Sleep = "rbxassetid://83997006799839",
	Slide = "rbxassetid://95001239078553",
	Sparkler = "rbxassetid://91909837127058",
	Star = "rbxassetid://76421262472403",
	-- the Gems currency (art/icons/set_gems.py; the owner's red-gem reference, 2026-10-18)
	Gem = "rbxassetid://103736628816473",
	GemPile = "rbxassetid://124746684251508",
	GemHeap = "rbxassetid://138626535327336",
	GemBag = "rbxassetid://92419500414344",
	GemChest = "rbxassetid://113263053316327",
	-- the taunt emojis (art/icons/set_emoji.py; Config.Taunt)
	EmojiLaugh = "rbxassetid://136191901910969",
	EmojiCool = "rbxassetid://110692736749554",
	EmojiAngry = "rbxassetid://74872258389210",
	EmojiCry = "rbxassetid://77481192382942",
	EmojiLove = "rbxassetid://134131045027310",
	EmojiShock = "rbxassetid://130938820354401",
	EmojiSilly = "rbxassetid://93012767096565",
	EmojiSkull = "rbxassetid://106015956131315",
	EmojiFire = "rbxassetid://127367490123475",
	Stop = "rbxassetid://129830810379344",
	Ticket = "rbxassetid://81430764809824",
	Trail = "rbxassetid://72488857407891",
	Trophy = "rbxassetid://78299309985766",
	Wave = "rbxassetid://110302433371344",
	Wheel = "rbxassetid://113936272928102",
	XP = "rbxassetid://123617985400792",
	-- code-drawn grey masks (tinted in game)
	Person = "rbxassetid://101797418040884",
	Badge = "rbxassetid://75057395762995",
} :: { [string]: string }

-- Round-HUD textures drawn in code by art/ui/make_hud.py: the braided fuse cord tile (HUD Field Fuse), the hazard
-- stripe tile (the 5 s warning) and the white radial edge mask tinted for the Carrier vignette (Asset Bible §6.6).
Assets.Ui = {
	Logo = "rbxassetid://84708770315035", -- art/logo/build.py (Blender), the loading screen + store art
	WheelFace = "rbxassetid://138733559405649", -- art/ui/make_wheel.py: the spin wheel's 8 segments + studded rim
	Braid = "rbxassetid://76185158058247",
	Hazard = "rbxassetid://96079488241147",
	Vignette = "rbxassetid://114254801837399",
}

-- The bomb's face rig (Asset Bible §3.8): three shared PBR sets baked by art/bomb/face.py from the review materials.
-- The meshes themselves live in the place (ReplicatedStorage.FV_Art.Bomb.Face), published from art/out/Bomb.Face/export.
Assets.Face = {
	Porcelain = {
		color = "rbxassetid://99613289323150",
		normal = "rbxassetid://114221080722735",
		rough = "rbxassetid://73177527461945",
		metal = "rbxassetid://80308395174292",
	},
	Brass = {
		color = "rbxassetid://87599637802447",
		normal = "rbxassetid://97479904250481",
		rough = "rbxassetid://129369884450640",
		metal = "rbxassetid://77446420113603",
	},
	Ink = {
		color = "rbxassetid://119113277598508",
		normal = "rbxassetid://97479904250481",
		rough = "rbxassetid://102141463810933",
		metal = "rbxassetid://80308395174292",
	},
} :: { [string]: { color: string, normal: string, rough: string, metal: string } }

-- Bomb skin texture sets (Asset Bible §3.6), baked by art/bomb/skins.py. Each part: { color, normal, rough, metal }.
-- SurfaceAppearance maps cannot be set at runtime, so these are built into ReplicatedStorage.FV_Art.Skins in Studio.
Assets.Skins = {
	Skin_CopperKettle = {
		Body = {
			color = "rbxassetid://106609049632912",
			normal = "rbxassetid://120556367717243",
			rough = "rbxassetid://73329947394555",
			metal = "rbxassetid://131596460259219",
		},
		Brass = {
			color = "rbxassetid://113575132944567",
			normal = "rbxassetid://80662401340048",
			rough = "rbxassetid://108030313300519",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://109603502568152",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://121018052132242",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://120317075566784",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_RookieBrass = {
		Body = {
			color = "rbxassetid://116113316587764",
			normal = "rbxassetid://98192474602634",
			rough = "rbxassetid://108017181595671",
			metal = "rbxassetid://128440482522492",
		},
		Brass = {
			color = "rbxassetid://97521357654583",
			normal = "rbxassetid://137346094286781",
			rough = "rbxassetid://97287496773811",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://123324203516341",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://121018052132242",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://120317075566784",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Watermelon = {
		Body = {
			color = "rbxassetid://80736682340730",
			normal = "rbxassetid://84513089958585",
			rough = "rbxassetid://122897080085626",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://83663960754841",
			normal = "rbxassetid://93448637900424",
			rough = "rbxassetid://85020939959129",
			metal = "rbxassetid://71920310683255",
		},
		Clamp = {
			color = "rbxassetid://136550447779784",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://138247463892679",
			metal = "rbxassetid://100027963931407",
		},
		Socket = {
			color = "rbxassetid://114691316229863",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://80104843955863",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Clockwork = {
		Body = {
			color = "rbxassetid://89989126463492",
			normal = "rbxassetid://129474811620826",
			rough = "rbxassetid://88004014817394",
			metal = "rbxassetid://128440482522492",
		},
		Brass = {
			color = "rbxassetid://74458909808918",
			normal = "rbxassetid://129650849198625",
			rough = "rbxassetid://121074705633821",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://106998507168831",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://137066501712699",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://72497606022908",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Delft = {
		Body = {
			color = "rbxassetid://134798372861854",
			normal = "rbxassetid://133760821193740",
			rough = "rbxassetid://122762333012186",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://131512853839054",
			normal = "rbxassetid://115145050855897",
			rough = "rbxassetid://86891168428141",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://140169166133187",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://125653093237979",
			metal = "rbxassetid://125653093237979",
		},
		Socket = {
			color = "rbxassetid://120317075566784",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Disco = {
		Body = {
			color = "rbxassetid://101510860476893",
			normal = "rbxassetid://126585097549375",
			rough = "rbxassetid://121372652304303",
			metal = "rbxassetid://75894075999696",
		},
		Brass = {
			color = "rbxassetid://113575132944567",
			normal = "rbxassetid://139478592018336",
			rough = "rbxassetid://139486171081381",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://120516351676964",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://117952128291405",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://120317075566784",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_DragonEgg = {
		Body = {
			color = "rbxassetid://74975175334148",
			normal = "rbxassetid://95746353599925",
			rough = "rbxassetid://78086858276675",
			metal = "rbxassetid://87827013798753",
		},
		Brass = {
			color = "rbxassetid://80526336904624",
			normal = "rbxassetid://74712055390209",
			rough = "rbxassetid://86891168428141",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://111436224686684",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://137066501712699",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://84412865744173",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://80104843955863",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Frostbite = {
		Body = {
			color = "rbxassetid://91288882030011",
			normal = "rbxassetid://89182415021895",
			rough = "rbxassetid://110436578355930",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://115930022518294",
			normal = "rbxassetid://115145050855897",
			rough = "rbxassetid://121074705633821",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://90995186986712",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://85206954204422",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://116485293601201",
			normal = "rbxassetid://131732672524269",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Galaxy = {
		Body = {
			color = "rbxassetid://134233655923853",
			normal = "rbxassetid://78773354470847",
			rough = "rbxassetid://134649737480433",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://92153747927654",
			normal = "rbxassetid://113649115232392",
			rough = "rbxassetid://103007937978251",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://86360029539779",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://102399066706967",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://115115366080437",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Gilded = {
		Body = {
			color = "rbxassetid://130724799117511",
			normal = "rbxassetid://85130256980415",
			rough = "rbxassetid://132961935204789",
			metal = "rbxassetid://128440482522492",
		},
		Brass = {
			color = "rbxassetid://121040563889230",
			normal = "rbxassetid://83498420863694",
			rough = "rbxassetid://138632665660305",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://79356435718856",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://121018052132242",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://120317075566784",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Gumball = {
		Body = {
			color = "rbxassetid://71565834298055",
			normal = "rbxassetid://77778008814157",
			rough = "rbxassetid://103178710317367",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://75126586845477",
			normal = "rbxassetid://75496281220704",
			rough = "rbxassetid://73390170138149",
			metal = "rbxassetid://86562060599954",
		},
		Clamp = {
			color = "rbxassetid://121932342154533",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://125653093237979",
			metal = "rbxassetid://76515368952838",
		},
		Socket = {
			color = "rbxassetid://116863392861430",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://135596118486715",
			metal = "rbxassetid://77393583835028",
		},
	},
	Skin_JackOFuse = {
		Body = {
			color = "rbxassetid://106601739978074",
			normal = "rbxassetid://79825100459180",
			rough = "rbxassetid://108116028480497",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://90093899593807",
			normal = "rbxassetid://91104953821631",
			rough = "rbxassetid://137538118201995",
			metal = "rbxassetid://71920310683255",
		},
		Clamp = {
			color = "rbxassetid://103272798408483",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://108352840391960",
			metal = "rbxassetid://80308395174292",
		},
		Socket = {
			color = "rbxassetid://112559716435315",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://81204930831354",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_LavaForge = {
		Body = {
			color = "rbxassetid://94502687701854",
			normal = "rbxassetid://116456232841522",
			rough = "rbxassetid://74387367641536",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://87153881522195",
			normal = "rbxassetid://117010285059244",
			rough = "rbxassetid://78282050709427",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://125895833283730",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://119615214774022",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://117364727329915",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://115364691133129",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Meteorite = {
		Body = {
			color = "rbxassetid://106152831175962",
			normal = "rbxassetid://91120063712577",
			rough = "rbxassetid://76877856013902",
			metal = "rbxassetid://128440482522492",
		},
		Brass = {
			color = "rbxassetid://78003520833558",
			normal = "rbxassetid://131988847021862",
			rough = "rbxassetid://75317718410187",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://104253099179932",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://119615214774022",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://86101986319806",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://108744940356802",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_PaperLantern = {
		Body = {
			color = "rbxassetid://126936632358562",
			normal = "rbxassetid://106801606746232",
			rough = "rbxassetid://94915187645254",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://118546104835379",
			normal = "rbxassetid://86360489768525",
			rough = "rbxassetid://105748091670428",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://129464882502610",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://76515368952838",
			metal = "rbxassetid://80308395174292",
		},
		Socket = {
			color = "rbxassetid://130647089754503",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_Tempered = {
		Body = {
			color = "rbxassetid://85117167779377",
			normal = "rbxassetid://133972725714845",
			rough = "rbxassetid://122897080085626",
			metal = "rbxassetid://128440482522492",
		},
		Brass = {
			color = "rbxassetid://78680544757148",
			normal = "rbxassetid://115145050855897",
			rough = "rbxassetid://121074705633821",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://71344413291613",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://85206954204422",
			metal = "rbxassetid://83465893820549",
		},
		Socket = {
			color = "rbxassetid://120317075566784",
			normal = "rbxassetid://91735717445721",
			rough = "rbxassetid://113979126153655",
			metal = "rbxassetid://80308395174292",
		},
	},
	Skin_ThunderEgg = {
		Body = {
			color = "rbxassetid://123227827148684",
			normal = "rbxassetid://127880611258545",
			rough = "rbxassetid://74403304965957",
			metal = "rbxassetid://71920310683255",
		},
		Brass = {
			color = "rbxassetid://74353038708390",
			normal = "rbxassetid://117010285059244",
			rough = "rbxassetid://110564543404651",
			metal = "rbxassetid://135226285995404",
		},
		Clamp = {
			color = "rbxassetid://92351600589518",
			normal = "rbxassetid://115941181932741",
			rough = "rbxassetid://98339927263720",
			metal = "rbxassetid://100027963931407",
		},
		Socket = {
			color = "rbxassetid://114880402361492",
			normal = "rbxassetid://119955831408299",
			rough = "rbxassetid://115364691133129",
			metal = "rbxassetid://80308395174292",
		},
	},
} :: { [string]: { [string]: { color: string, normal: string, rough: string, metal: string } } }

-- Title word art (art/titles/build.py: 3D glossy toy letters + one outline + drop shadow, ≤1024 px wide). `size` is
-- the PNG's pixel size, so Client/UI/TitleArt keeps the aspect; `mask` is the letters-only mask the live shine sweeps
-- inside; `glow` is the word's silhouette blurred wide (tinted live for the halo and the dark backing), `glowScale` its
-- size relative to the word; `family` picks the live tints.
Assets.Title =
	{
		AllClear = { -- ALL CLEAR!
			id = "rbxassetid://92892353383515",
			mask = "rbxassetid://138876367950736",
			glow = "rbxassetid://73607927945569",
			glowScale = Vector2.new(1.234, 1.838),
			size = Vector2.new(1067, 298),
			family = "Green",
		},
		Betrayal = { -- BETRAYAL!
			id = "rbxassetid://103094475619687",
			mask = "rbxassetid://81450972807581",
			glow = "rbxassetid://119656623320907",
			glowScale = Vector2.new(1.235, 1.838),
			size = Vector2.new(1065, 298),
			family = "Purple",
		},
		Bomber = { -- BOMBER!
			id = "rbxassetid://138897080912916",
			mask = "rbxassetid://81308169852518",
			glow = "rbxassetid://93576873957174",
			glowScale = Vector2.new(1.29, 1.841),
			size = Vector2.new(1080, 372),
			family = "Red",
		},
		BombersWin = { -- BOMBERS WIN!
			id = "rbxassetid://80163388423671",
			mask = "rbxassetid://105491106630305",
			glow = "rbxassetid://80532375740367",
			glowScale = Vector2.new(1.172, 1.824),
			size = Vector2.new(1047, 218),
			family = "Red",
		},
		Boom = { -- BOOM!
			id = "rbxassetid://86826916374978",
			mask = "rbxassetid://129896615547326",
			glow = "rbxassetid://123146981492766",
			glowScale = Vector2.new(1.377, 1.838),
			size = Vector2.new(833, 376),
			family = "Fire",
		},
		Chain = { -- CHAIN!
			id = "rbxassetid://94069436359763",
			mask = "rbxassetid://127286028108970",
			glow = "rbxassetid://130405197430866",
			glowScale = Vector2.new(1.359, 1.838),
			size = Vector2.new(887, 379),
			family = "Gold",
		},
		CloseOne = { -- CLOSE ONE!
			id = "rbxassetid://92335398311736",
			mask = "rbxassetid://101866801591003",
			glow = "rbxassetid://140178462925035",
			glowScale = Vector2.new(1.228, 1.833),
			size = Vector2.new(1062, 290),
			family = "Fire",
		},
		ClutchDefuse = { -- CLUTCH DEFUSE!
			id = "rbxassetid://113977043813008",
			mask = "rbxassetid://97708583850646",
			glow = "rbxassetid://80482526065148",
			glowScale = Vector2.new(1.158, 1.825),
			size = Vector2.new(1042, 200),
			family = "Gold",
		},
		Defused = { -- DEFUSED!
			id = "rbxassetid://111684498522555",
			mask = "rbxassetid://125290011414646",
			glow = "rbxassetid://137873772437881",
			glowScale = Vector2.new(1.272, 1.839),
			size = Vector2.new(1070, 347),
			family = "Green",
		},
		Dodge = { -- DODGE!
			id = "rbxassetid://80501666488138",
			mask = "rbxassetid://95717460885497",
			glow = "rbxassetid://135803134840458",
			glowScale = Vector2.new(1.346, 1.839),
			size = Vector2.new(912, 376),
			family = "Blue",
		},
		DoubleBoom = { -- DOUBLE BOOM!
			id = "rbxassetid://111999687038588",
			mask = "rbxassetid://133287170472298",
			glow = "rbxassetid://133426196795259",
			glowScale = Vector2.new(1.177, 1.831),
			size = Vector2.new(1046, 222),
			family = "Fire",
		},
		Go = { -- GO!
			id = "rbxassetid://88764791680305",
			mask = "rbxassetid://75789790947078",
			glow = "rbxassetid://107800880285928",
			glowScale = Vector2.new(1.076, 1.843),
			size = Vector2.new(675, 530),
			family = "Green",
		},
		Hurry = { -- HURRY!
			id = "rbxassetid://94203369887513",
			mask = "rbxassetid://110304311177941",
			glow = "rbxassetid://83313587710495",
			glowScale = Vector2.new(1.334, 1.837),
			size = Vector2.new(942, 376),
			family = "Red",
		},
		LastStand = { -- LAST STAND
			id = "rbxassetid://122227012040544",
			mask = "rbxassetid://90759087752935",
			glow = "rbxassetid://128980891761291",
			glowScale = Vector2.new(1.208, 1.83),
			size = Vector2.new(1056, 265),
			family = "Gold",
		},
		LevelUp = { -- LEVEL UP!
			id = "rbxassetid://84794559397527",
			mask = "rbxassetid://139784054420288",
			glow = "rbxassetid://128602171209312",
			glowScale = Vector2.new(1.262, 1.84),
			size = Vector2.new(1071, 334),
			family = "Gold",
		},
		LightsOut = { -- LIGHTS OUT
			id = "rbxassetid://72867581499348",
			mask = "rbxassetid://108128831685865",
			glow = "rbxassetid://108796142054429",
			glowScale = Vector2.new(1.222, 1.837),
			size = Vector2.new(1056, 279),
			family = "Purple",
		},
		MegaBomb = { -- MEGA BOMB!
			id = "rbxassetid://97152800917301",
			mask = "rbxassetid://119031931307280",
			glow = "rbxassetid://112745019105890",
			glowScale = Vector2.new(1.202, 1.835),
			size = Vector2.new(1054, 255),
			family = "Purple",
		},
		ReadTheFace = { -- READ THE FACE
			id = "rbxassetid://87315710200536",
			mask = "rbxassetid://123968242261985",
			glow = "rbxassetid://135644071288666",
			glowScale = Vector2.new(1.169, 1.825),
			size = Vector2.new(1048, 214),
			family = "Gold",
		},
		Rejected = { -- REJECTED!
			id = "rbxassetid://109207599815212",
			mask = "rbxassetid://130591478827799",
			glow = "rbxassetid://100971206380914",
			glowScale = Vector2.new(1.248, 1.84),
			size = Vector2.new(1068, 315),
			family = "Blue",
		},
		Revenge = { -- REVENGE!
			id = "rbxassetid://98473674394487",
			mask = "rbxassetid://106667182681538",
			glow = "rbxassetid://134690019646549",
			glowScale = Vector2.new(1.266, 1.836),
			size = Vector2.new(1070, 341),
			family = "Red",
		},
		ReviveSaved = { -- REVIVE SAVED
			id = "rbxassetid://94665801021446",
			mask = "rbxassetid://113254533067110",
			glow = "rbxassetid://89711337979314",
			glowScale = Vector2.new(1.179, 1.833),
			size = Vector2.new(1046, 224),
			family = "Gold",
		},
		Revived = { -- REVIVED!
			id = "rbxassetid://122581779871187",
			mask = "rbxassetid://96201695598891",
			glow = "rbxassetid://107732454623267",
			glowScale = Vector2.new(1.277, 1.84),
			size = Vector2.new(1071, 353),
			family = "Green",
		},
		Safe = { -- SAFE!
			id = "rbxassetid://129795733028755",
			mask = "rbxassetid://80603078921981",
			glow = "rbxassetid://76169531644089",
			glowScale = Vector2.new(1.4, 1.839),
			size = Vector2.new(747, 378),
			family = "Green",
		},
		SlamPass = { -- SLAM PASS!
			id = "rbxassetid://94285696568395",
			mask = "rbxassetid://140170174795777",
			glow = "rbxassetid://106600671998675",
			glowScale = Vector2.new(1.207, 1.834),
			size = Vector2.new(1054, 261),
			family = "Gold",
		},
		SurvivorsWin = { -- SURVIVORS WIN!
			id = "rbxassetid://124551338340470",
			mask = "rbxassetid://133901537064447",
			glow = "rbxassetid://84795937567178",
			glowScale = Vector2.new(1.153, 1.823),
			size = Vector2.new(1044, 194),
			family = "Blue",
		},
		Tagged = { -- TAGGED!
			id = "rbxassetid://81994905122401",
			mask = "rbxassetid://84188361563018",
			glow = "rbxassetid://96535221953366",
			glowScale = Vector2.new(1.301, 1.838),
			size = Vector2.new(1051, 377),
			family = "Red",
		},
		TheMole = { -- THE MOLE
			id = "rbxassetid://134568817675226",
			mask = "rbxassetid://76448709179261",
			glow = "rbxassetid://75673250362591",
			glowScale = Vector2.new(1.265, 1.836),
			size = Vector2.new(1066, 338),
			family = "Purple",
		},
		TripleBoom = { -- TRIPLE BOOM!
			id = "rbxassetid://75761710161693",
			mask = "rbxassetid://86021630626834",
			glow = "rbxassetid://121176612538830",
			glowScale = Vector2.new(1.191, 1.832),
			size = Vector2.new(1051, 241),
			family = "Red",
		},
		Victory = { -- VICTORY!
			id = "rbxassetid://119344869317205",
			mask = "rbxassetid://124404990651416",
			glow = "rbxassetid://95506503715713",
			glowScale = Vector2.new(1.266, 1.836),
			size = Vector2.new(1065, 338),
			family = "Gold",
		},
		YouWon = { -- YOU WON!
			id = "rbxassetid://99232275611992",
			mask = "rbxassetid://81295939469698",
			glow = "rbxassetid://80976136651630",
			glowScale = Vector2.new(1.244, 1.834),
			size = Vector2.new(1063, 310),
			family = "Gold",
		},
		YoureTheMole = { -- YOU'RE THE MOLE
			id = "rbxassetid://79799182283831",
			mask = "rbxassetid://121583141456754",
			glow = "rbxassetid://130667999081216",
			glowScale = Vector2.new(1.151, 1.821),
			size = Vector2.new(1044, 192),
			family = "Red",
		},
	} :: { [string]: { id: string, mask: string, glow: string, glowScale: Vector2, size: Vector2, family: string } }

-- The live layers behind a title (art/titles/fx.py): white, tinted per family in game.
Assets.TitleFx = {
	Glow = "rbxassetid://129578054124525",
	Streak = "rbxassetid://129842641617198",
	Sparkle = "rbxassetid://83291190481928",
}

return Assets
