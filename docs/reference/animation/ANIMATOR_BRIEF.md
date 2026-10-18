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

## Two more clips: the slap (added 2026-10-18)
The tag is now a **slap**: every ready Bomber holds a small bomb in their right hand and slaps it onto the Runner's back. We made in-house first versions (`tools/anim/Slap.luau`, `Stumble.luau`). Please make the final versions by hand, with the same rules as above (R6, Action, no root motion, upload to the group).

| File (Assets.Anim key) | Body | Plays when | Length | Notes |
|---|---|---|---|---|
| **`Slap`** | **Upper body only** (`Torso`, `Head`, both arms; legs unkeyed) | A Bomber tags someone | **0.30–0.36 s** | A tight overhand slap with the **right** hand: cock up and back, whip over and down through the target, follow through past the hip. **Contact at 0.11 s** (the game freezes on that frame). The torso drives the hit, the free arm snaps back, and the head leads in |
| **`Stumble`** | **Upper body only** | The Runner who got slapped | **0.45–0.55 s** | Slapped on the back and shoved forward: the chest snaps back, the arms fling up and splay, then the body pitches forward catching its balance with the arms windmilling. Funny, not painful |
