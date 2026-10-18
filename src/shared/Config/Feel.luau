--!strict
-- Impact & punctuation (GDD §10.3, §10.4 F-FEEL-04): the hit-stop, the pass flight, the impact freeze and the
-- presentation slow-mo; the moment system (§10.5 F-FEEL-06). Times in seconds, distances in studs. [TUNE]

return {
	-- Tag / pass (§10.3): both rigs freeze for HITSTOP; the bomb pops on landing; your own camera kicks.
	HITSTOP = 0.06,
	HITSTOP_TAG = 0.09, -- the slap's freeze on the contact pose (F-BOMB-10)
	-- The slap (F-BOMB-10, SlapController): the Slap clip's contact frame, and how far before it the clip starts when
	-- the Stick lands (the contact, and everything on it, comes SLAP_LEAD after the event)
	SLAP_CONTACT = 0.11,
	SLAP_LEAD = 0.06,
	SMACK_LIFE = 0.32, -- the smack flipbook's 16 frames
	SMACK_SIZE = 2.8,
	-- the hand bomb: the hero bomb at this scale in the right fist (arm space: below the fist, a touch forward)
	HAND_BOMB_SCALE = 0.42,
	HAND_BOMB_GRIP = CFrame.new(0.12, -1.22, -0.4),
	HAND_BOMB_TILT = 40, -- degrees the fuse leans out to the side, so its spark shows past the fist
	HAND_REGROW = 0.22, -- the pop-in when the tag is ready again
	HITSTOP_RANGE = 80, -- only rigs this close to the camera freeze (no point animating what nobody sees)
	LAND_POP = 1.18, -- the bomb's scale at the top of its landing pop…
	LAND_POP_TIME = 0.16, -- …and how long the pop takes to settle
	KICK_SHAKE = 0.22, -- camera trauma when a bomb lands on you / leaves you
	KICK_FOV = 3, -- degrees of FOV punch when a bomb lands on you

	-- The pass flight (§7.4, §10.3): the real bomb (the giver's skin) flies back to back with a motion trail.
	PASS_TIME = 0.18,
	PASS_ARC = 2, -- studs of lift at the middle of the arc
	PASS_SPINS = 1.5, -- full turns in flight

	-- Boom on you (§10.3): the camera holds while the explosion expands, then a whoosh as you fly.
	IMPACT_FREEZE = 0.35,

	-- Presentation slow-mo (F-FEEL-04): the local camera, VFX and audio run slow; gameplay never pauses.
	SLOWMO_TIME = 0.5,
	SLOWMO_SCALE = 0.3,
	SLOWMO_COOLDOWN = 4, -- at most once per this many seconds per client
	SLOWMO_PASS_LEFT = 0.5, -- a pass with this little fuse left earns it
	SLOWMO_RANGE = 45, -- only moments this close to the camera (or your own)
	SLOWMO_FOV = -6, -- the camera leans in

	-- The moment system (§10.5, MomentService / MomentController): top-tier moments are flagged, the best one of the
	-- round replays at RESULTS. Score: the higher wins; a tie goes to the later moment.
	MOMENT_SCORE = {
		LastStandWin = 100, -- the Last Stand's Runner made it across
		ClutchDefuse = 80,
		LastStand = 60, -- the Last Stand ended in a boom
		Chain = 40, -- + MOMENT_CHAIN_LINK per Carrier
	} :: { [string]: number },
	MOMENT_CHAIN_LINK = 10,
	MOMENT_CHAIN_MIN = 4, -- a 4+ Chain is top-tier (CHAIN callouts start at 3)
	MOMENT_REPLAY = 4, -- seconds of replay
	MOMENT_AFTER = 0.6, -- of which this many follow the moment itself (the reaction)
	MOMENT_HZ = 15, -- replay frames per second sent to clients (the client interpolates)
	MOMENT_RADIUS = 60, -- participants this close to the featured one at the moment are in the shot
	MOMENT_MAX_ACTORS = 12,
	MOMENT_GAP = 0.6, -- seconds the replay holds its last frame before it loops
	MOMENT_CAM_OFFSET = Vector3.new(0, 16, 24), -- the replay camera, from the featured participant (world space)
	MOMENT_CAM_FOV = 50,
	MOMENT_CAM_SMOOTH = 6, -- 1/s: how fast the camera follows
	MOMENT_TUMBLE_TILT = 80, -- degrees a tumbled (ragdolled) puppet lies over

	-- The bomb's face (Asset Bible §3.8, art/bomb/face.py). Poses in degrees, as reviewed on the contact sheet:
	--   lid    + swings back into the body (open), 0 = half-lidded, −95 closed     slant: + droops the outer corner
	--   raise  + lifts the brow up the body                                         tilt:  + inner end down (angry)
	--   pupil  scale of the pupils; mouth: which mouth shows
	FACE_POSES = {
		SMUG = { lid = 8, slant = -10, raise = 0, tilt = 14, pupil = 1.0, mouth = "Smirk" }, -- LIT
		UHOH = { lid = 38, slant = 12, raise = 2, tilt = -18, pupil = 0.9, mouth = "Grimace" }, -- HOT
		PANIC = { lid = 72, slant = 0, raise = 4, tilt = -24, pupil = 0.7, mouth = "Panic" }, -- CRITICAL
		GOTCHA = { lid = 14, slant = -18, raise = -1, tilt = 22, pupil = 1.0, mouth = "Grin" }, -- it just stuck to someone
		WHEE = { lid = 76, slant = 0, raise = 5, tilt = -8, pupil = 0.72, mouth = "Ooh" }, -- pass flight
	} :: {
		[string]: { lid: number, slant: number, raise: number, tilt: number, pupil: number, mouth: string },
	},
	FACE_BLEND = 16, -- 1/s: how fast one pose eases into the next
	FACE_BLINK_EVERY = { 2, 4 }, -- seconds between blinks while LIT (random in the range)
	FACE_BLINK_TIME = 0.12,
	FACE_BLINK_LID = -95,
	FACE_GOTCHA_TIME = 0.6,
	FACE_GAZE_RANGE = 45, -- studs: the nearest player inside this is the one it stares at
	FACE_GAZE_MAX = 32, -- degrees the pupils can turn from straight out
	FACE_GAZE_RATE = 0.2, -- seconds between target picks
	FACE_GAZE_IDLE = Vector3.new(0, 1, -0.15), -- eye space: straight out, a touch down, when nobody is near
	FACE_SHAKE = 3, -- degrees of pupil jitter at CRITICAL (off with Reduce motion)
	FACE_PUPIL_LIFT = 0.018, -- studs a pupil rises per unit it shrinks, so a pin pupil stays proud of the eye
	FACE_GLINT_OFFSET = 9, -- degrees the glint sits up and across from the pupil's centre (face.py glint_axis)
}
