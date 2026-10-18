# FUSE VALLEY — dash + momentum animation brief

**Reference:** `movement_reference.mp4` (54 s, 900×1000). Each move plays at real speed, then at ¼ speed with the
source frame number burned in. "WATCH THE ARMS" marks the momentum swing. `sheets/*.jpg` show every frame of each move
(30 fps), with the arm-swing frames numbered in orange.

**The look we want:** the clips should feel alive, heavy and loose, like the capture. The body leads, the arms trail,
and **when the speed dies, one arm swings out wide and settles back**. That arm swing is the signature and matters
more than anything else.

> Animate it by hand from the reference. **Never extract, copy or re-time another game's animation data or assets**:
> the motion has to be ours, made in our rig.

## Rig and format
- **R6** (the game is R6). Animate on a plain R6 dummy: `Torso`, `Head`, `Left/Right Arm`, `Left/Right Leg` and the
  `HumanoidRootPart` root joint.
- **30 fps** or higher (60 fps is welcome), **not looping**, priority **Action**.
- Deliver each clip as **a Roblox Animation uploaded to the group "99 Dreams Studio" (3774675)**, so the ids work in the
  game, **plus** the `.rbxm` KeyframeSequence source. Send us the asset ids and we'll drop them into `Assets.Anim`.
- Keep the **root at the origin**: the game moves the character, so no root motion and no travel baked into the clip.
- Add a keyframe **marker named `Recover`** where the run cycle may start blending back in.

## The files we need (exact names)
| # | Clip name (Assets.Anim key) | Replaces | Reference frames | Length guide | Notes |
|---|---|---|---|---|---|
| 1 | **`Dash`** (front dash) | the current procedural Dash | **306–352** (move 3) | ≈ 1.4 s: anticipation 4 f · low lunge 10 f · rise 6 f · arm swing-through + settle 23 f | Body pitches far forward and low; speed lines in the capture mark the burst. `Recover` at the start of the settle (≈ f 330). |
| 2 | **`DashLeft`** | current DashLeft | **350–394** (move 4) | ≈ 1.5 s: lunge 11 f · rise 6 f · big arm swing + settle 25 f | **Keeps facing forward** while travelling left (strafe dash). Hips and torso lean into the move; the trailing arm flings out on the recovery (f 370–379). |
| 3 | **`DashRight`** | current DashRight | mirror of #2 | same as #2 | A true mirror is fine; small asymmetry is welcome. |
| 4 | **`DashBack`** | current DashBack | **393–419** (move 5) and the back step in **18–30** (move 1) | ≈ 0.9 s | Keeps facing forward while hopping **backward**. A crouch-lunge, then recovery. |
| 5 | **`Brake`** (momentum slow-down) | current Brake | **18–70** (move 1), the arm swing at **50–61** | ≈ 1.4 s: decel 21 f · **arm swing out wide 12 f** · settle 9 f | **The one you love.** It plays when running speed drops to a stop. The arm swing has to read from behind the character at 15–20 studs. |
| 6 | **`TurnFlareLeft`** / **`TurnFlareRight`** (new, upper body only) | — | **70–176** (move 2): flares at **90–95, 105–108, 114–117, 136–138** | ≈ 0.4 s each | A short arm flare and counter-lean on a sharp direction change, layered over the run (arms and torso keys only). |

## Timing in our game
Our dash burst is fast: 48 studs/s for 0.13 s, gliding back to run speed by 0.34 s (`Config.Movement`). So **the lunge
pose should be hit by about frame 4 at 30 fps**, and everything after it is recovery (the part that sells the
momentum). The game blends the run back in at `Recover`.

## How we'll check them
Clips drop straight into `Assets.Anim` (same names), so the game plays them with no code changes. The checks:
1. Studio play-test at 1× and at ¼ speed against `movement_reference.mp4`.
2. The arm swing reads from the default camera.
3. The clips loop cleanly back into Idle and Run.
4. No foot sliding at the start and end poses.
