--!strict
-- Every asset reference goes through this table (Asset Bible §10.5): code uses keys, never raw ids.
-- src: R = Roblox official, PSE = ProSoundEffects, APM = APMOfficial, C = verified community, BI = built-in,
-- FV = sound-designed in-house (art/audio).
-- An id of "" means the in-house file is waiting to be uploaded; code falls back until it lands.
-- P0: only what the transferred movement uses (from Chase Game). The FUSE VALLEY sound stacks (Asset Bible §9) and
-- the bomb's assets are added as their phases land.

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

Assets.SFX = {
	-- Movement (Chase Game's tuned set; replaced by designed stacks in the P3 audio pass, Asset Bible §9)
	Dash = s(9126229255, 0.7, "PSE", { alt = { "rbxassetid://9114157695" } }),
	HardStop = s(9118740493, 0.7, "PSE"),
	Slide = s(114100466629000, 0.55, "C", { alt = { "rbxassetid://105544173943722" } }),
	Land = s("rbxasset://sounds/action_jump_land.mp3", 0.6, "BI"),
	-- Footsteps: four soft single-hit steps, one picked at random per footfall (FootstepController sets the pace).
	Footstep1 = s(123224557798023, 0.5, "C"),
	Footstep2 = s(131412978408311, 0.42, "C"),
	Footstep3 = s(114768473003662, 0.45, "C"),
	Footstep4 = s(91882016473062, 0.7, "C"),

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
	PassWhoosh = s(9126229255, 0.55, "PSE", { pitch = { 1.25, 1.4 } }), -- the flight between backs
	BoomHit = s(1843023322, 0.9, "APM"), -- cinematic hit: the boom's punch
	BoomBody = s(9113470802, 0.75, "PSE"), -- a giant thud: the body of the boom
	BoomDebris = s(9113218938, 0.45, "PSE", { region = { 0, 2.2 } }), -- rock crumble: debris + tail (first 2.2 s of a 16 s file)
	Defuse = s(9126229255, 0.35, "PSE", { pitch = { 2.1, 2.3 } }), -- a short high whoosh: the snuff
	Safe = s(18448089848, 0.55, "C"), -- the defuse chime
	Clutch = s(9047103106, 0.8, "APM"), -- the CLUTCH DEFUSE sting
	Klaxon = s(9119662934, 0.5, "PSE"), -- the Field Fuse at 5 s
	Heartbeat = s(9043365842, 0.7, "APM", { looped = true }), -- the Carrier's heartbeat (96 BPM, sped up by stage)
	DrumRoll = s(4718483268, 0.75, "C"), -- the Last Stand reveal
	CrowdLoop = s(9120974094, 0.3, "PSE", { looped = true }),
	CrowdCheer = s(9120974378, 0.6, "PSE"),
	CrowdGasp = s(9114013354, 0.6, "PSE"),
	WinSting = s(1841980129, 0.85, "APM"),
	-- UI (Asset Bible §6.3, §6.5), built from sounds already in the set: the in-house escapement pitched up is a crisp
	-- mechanical button click and a coin-counter tick; the clamp low is the deny thunk and the calendar's stamp.
	UiPress = s(91973479747444, 0.32, "FV", { pitch = { 1.7, 1.8 } }),
	UiDeny = s(9125782643, 0.3, "PSE", { pitch = { 0.62, 0.66 } }),
	CoinTick = s(132119182630967, 0.18, "FV", { pitch = { 2.1, 2.3 } }),
	Claim = s(18448089848, 0.6, "C"),
	Stamp = s(9125782643, 0.75, "PSE", { pitch = { 0.8, 0.86 } }),
	LevelUp = s(1841980129, 0.9, "APM"),
	QuestDone = s(9047103106, 0.6, "APM"),
	LoseSting = s(1839303737, 0.75, "APM"),
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
}

-- The custom icon set (Asset Bible §6.4), drawn in code by art/ui/make_icons.py (Skin.icon). Person and Badge are
-- grey: tint them (team colours, badge tiers) with ImageColor3.
Assets.Icon = {
	Star = "rbxassetid://86093237979583",
	Gift = "rbxassetid://121335451303695",
	Scroll = "rbxassetid://71911946865623",
	Calendar = "rbxassetid://89162593444268",
	Flame = "rbxassetid://96666900794298",
	Crate = "rbxassetid://121054222520468",
	Check = "rbxassetid://133209889740447",
	Bomb = "rbxassetid://134063506701775",
	Person = "rbxassetid://101797418040884",
	Shield = "rbxassetid://80516751356640",
	Badge = "rbxassetid://75057395762995",
} :: { [string]: string }

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
} :: { [string]: { [string]: { color: string, normal: string, rough: string, metal: string } } }

return Assets
