# FUSE VALLEY — slow-down + side dash animation brief

**Reference:** `movement_reference.mp4` (35 s): the momentum slow-down, then 3 takes of the side dash. Each plays at
real speed, then at ¼ speed with the source frame number burned in. "WATCH THE ARMS" marks the arm swing.
`sheets/*.jpg` show every frame of each move (30 fps), with the arm-swing frames numbered in orange.

There is **no front dash**: dashes are sideways only. The signature is **the arms when the momentum dies: one arm
swings out wide and settles back.**

> Animate by hand from the reference. Never extract, copy or re-time another game's animation data.

## How the game plays these clips
The character always runs a base layer: **Idle / Run / Strafe** loops at priority **Movement**. The clips below play
**on top** at priority **Action**. In Roblox a higher-priority clip only overrides the joints it has keyframes for:
- a joint you **key** is taken over by your clip;
- a joint you **leave unkeyed** keeps playing the run underneath.

That is how a clip can be "alone" (full body) or "combined with running" (upper body only).

## The 5 files (exact names)
| File (Assets.Anim key) | Body | Plays when | Length | Must start / end |
|---|---|---|---|---|
| **`Brake`** | **Full body, standalone** (key every joint) | You let go of the keys from a run of 14+ studs/s, while the body is still sliding to a stop | **0.9–1.2 s** of authored motion | Starts from the **Run** pose mid-stride. Ends in **exactly the Idle pose**: its last 0.36 s dissolves into Idle |
| **`DashLeft`** | **Full body** (the burst) | A dash with A / turning left | **0.45 s** max | Starts from Run; drop low, lunge sideways, rise. Ends in a **run-ready** pose, because the player is running again 0.34 s after pressing |
| **`DashRight`** | Full body | A dash with D / turning right | 0.45 s | A mirror of `DashLeft` |
| **`DashLeftArms`** | **Upper body only**: key `Torso` (root joint), `Head`, `Left Arm`, `Right Arm`. **Leave both legs unkeyed** | Straight after `DashLeft`, **over the run** | **0.8–1.0 s** | The momentum arm swing-out and settle (reference frames 324–335, 370–379), ending in the run's arm pose |
| **`DashRightArms`** | Upper body only | Straight after `DashRight` | 0.8–1.0 s | A mirror of `DashLeftArms` |

**Why the dash is split in two:** the player is running again 0.34 s after the dash. A 1.4 s full-body clip would
freeze the legs while the character moves, so the feet slide. The `…Arms` clip leaves the legs to the run and owns
the arms, which is exactly the Huss Valley look: the legs run on while the arms swing out and settle.

Reference frames:
- slow-down: **18–70**, arm swing at **50–61**;
- side dash: take 1 **306–352**, take 2 **350–394**, take 3 **393–419**. All three are the same move, so use the best
  read of each part.

## Format
- **R6**, 30 fps or higher (60 is welcome), **not looping**, priority **Action**.
- Keep the root still: **no root motion**. The game moves the character.
- Upload as Roblox Animations to the group **"99 Dreams Studio" (3774675)** and send us the 5 asset ids, plus the
  `.rbxm` KeyframeSequence sources.
