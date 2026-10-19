--!strict
-- Impact & punctuation (GDD §10.3, §10.4 F-FEEL-04): the hit-stop, the pass flight, the impact freeze and the
-- presentation slow-mo; the moment system (§10.5 F-FEEL-06). Times in seconds, distances in studs. [TUNE]

return {
	-- Tag / pass (§10.3): both rigs freeze for HITSTOP; the bomb pops on landing; your own camera kicks.
	HITSTOP = 0.09, -- D-PASS-02: a pass's freeze lands with the bomb (60 ms read as nothing)
	HITSTOP_CHAIN = 0.012, -- …longer for every Carrier the bomb has been through…
	HITSTOP_MAX = 0.15, -- …up to this
	HITSTOP_TAG = 0.09, -- the slap's freeze on the contact pose (F-BOMB-10)
	-- The Hand-Off (GDD §7.4b, HandOffController)
	HITSTOP_SLAM = 0.1, -- a SLAM PASS
	HITSTOP_REJECT = 0.08, -- a REJECTED! pass
	RICOCHET_TIME = 0.34, -- the rejected bomb's out-and-back
	RING_ALPHA = 0.02, -- the Danger Ring's transparency at the bottom of its beat…
	RING_BRIGHTNESS = 1.35, -- the unlit ring's glow (SurfaceGui.Brightness)
	RING_PULSE = 0.2, -- …plus this at the top
	RING_SPIN = { 25, 55, 130 }, -- °/s the links crawl at LIT / HOT / CRITICAL
	RING_LUNGE_SPEED = 1.4, -- × MAX_SPEED: moving this fast is a dash, so the ring stretches into the lunge
	RING_SPRING = 260, -- the stretch's spring (stiff: it snaps out with the dash, and back)
	RING_POP = 0.12, -- the overshoot of a pop (a new Carrier, a stage change)
	RING_POP_TIME = 0.24,
	RING_FADE = 0.14, -- a ring shrinking away when the bomb leaves
	RING_RAY = 12, -- studs down to look for the floor
	RING_FEET_BELOW = 3, -- an R6 root's centre to its feet
	RING_AIRBORNE = 1, -- feet this far above the ray's floor = in the air (the ring stays on the floor)
	RING_LIFT = 0.06, -- studs above the floor (no z-fighting)
	CHAIN_TAG_HEIGHT = 3.6, -- studs above the head: the ×N tag (over the fuse ring)
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
	-- THROW MODE's body (tools/anim ThrowCoil / ThrowHold / Throw, GDD §7.4c)
	THROW_COIL_TIME = 0.26, -- ThrowCoil's length (less a blend): then ThrowHold loops
	THROW_HOLD_SPEED = { 1, 2.6 }, -- ThrowHold plays faster as the power builds (the strain trembles harder)
	THROW_CLIP_FROM = 0.05, -- Throw starts here on release…
	THROW_RELEASE_AT = 0.105, -- …and the bomb leaves the hand on this frame (the whip's `hit`)
	THROW_RELEASE_FREEZE = 0.05, -- the thrower holds the release pose for a beat
	THROW_REMOTE_FROM = 0.09, -- other players' Throw starts here (the server already let it go)
	CARRY_HAND_SCALE = 0.62, -- a Carrier's own bomb in the hand while winding up (a Bomber's hand bomb is HAND_BOMB_SCALE)
	PASS_TIME = 0.26, -- D-PASS-02: long enough to see it fly (0.18 was a blur between two touching bodies)
	PASS_ARC = 3.2, -- studs of lift at the middle of the arc
	PASS_SPINS = 1.5, -- full turns in flight
	PASS_TRAIL_CHAIN = 0.18, -- the trail widens by this × per Carrier in the chain
	-- The landing (D-PASS-02, HandOffController): a burst on the receiver's back that grows with the chain, the
	-- receiver flashes white and stumbles, and your screen edge flashes in the stage colour when it's you.
	PASS_BURST = 2.6, -- burst size at a chain of 1…
	PASS_BURST_CHAIN = 0.45, -- …plus this per Carrier
	PASS_FLASH_TIME = 0.16, -- the receiver's white flash
	PASS_EDGE_TIME = 0.45, -- your screen edge when it lands on you
	PASS_EDGE_PX = 26,
	PASS_RECEIVE_FOV = 5, -- degrees of FOV punch when it lands on you (KICK_FOV is the giver's)
	CHAIN_RAYS_FROM = 3, -- a light-ray burst behind the receiver from this chain length
	CHAIN_GASP_FROM = 4, -- the crowd gasps from here (and on a CLOSE ONE)
	CHAIN_SLOWMO_FROM = 5, -- presentation slow-mo from here (F-FEEL-04 budget rules still apply)
	-- The reach tether (F-BOMB-15): while you carry, a crackling arc from your bomb to whoever a slap would hit.
	TETHER_WIDTH = 1.1,
	TETHER_SPEED = 3,

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
