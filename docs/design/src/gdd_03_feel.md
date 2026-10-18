## 9. Movement & controls

### 9.1 Transferred as-is (F-MOVE-01)
Movement is the game's foundation, and Chase Game's system is already tuned to the user's standard. It transfers **unchanged** (§23): `MovementCore`, `MovementController`, `InputController`, `MovementValidator`, `CameraController` and `Config.Movement`.

| Technique | Behaviour (Chase Game tuning, kept) |
|---|---|
| **Run** | Max speed 24 studs/s. The first step jumps straight to 42 % of top speed, then eases up to full over 0.95 s. |
| **Omnimovement** | The body faces the camera. W runs, A/D strafe at 85 % pace, S backpedals at 92 % with momentum. |
| **Momentum** | Letting go holds your pace for 0.14 s; a left↔right flip carries 85 % of your pace; a reversal into a backpedal plants then pushes off. |
| **Dash** | A burst covering ≈14 studs in 0.34 s, 2.2 s cooldown. Works from standstill, and backward while still facing forward. |
| **Hard Stop + Juke** | Stop dead in 0.16 s, then a 0.45 s window to snap out in any direction at 95 % speed. 0.7 s cooldown. |
| **Slide** | 1.45× burst, then a glide; ≈22 % more ground than running. 2.5 s cooldown. |
| **Slopes** | Uphill −15 % at 30°, downhill +6 %. |

### 9.2 Why the moveset matters more here (F-MOVE-02) [OURS]
The bomb turns every technique into a decision:
- **Hard Stop + Juke:** make a Bomber overshoot, or stop dead so a Carrier running at you overshoots its pass.
- **Dash:**
  - toward a Runner to pass the bomb before it blows (a "dash pass")
  - away from a Carrier to dodge it
  - toward the strip for a clutch defuse
- **Slide:** under a crowd, through a gap between two Bombers.

### 9.3 Role differences (F-MOVE-03)
| | Runner | Bomber |
|---|---|---|
| Speed | 1.00 × | 1.00 × [TUNE] |
| Dash / Slide / Hard Stop | ✔ | ✔ |
| Tag | — | Touch, 1.5 s cooldown |
| Profile key | `Profiles.Runner` | `Profiles.Bomber` |
| While carrying a bomb | Normal speed. No slow-down: panic should feel fast, not sluggish | Can't move while stunned |

### 9.4 Controls (F-MOVE-04)
There is **no jump**. Space is Dash. The bomb never needs a button: contact passes it.

| Action | PC | Mobile | Console |
|---|---|---|---|
| Move | WASD | Thumbstick (dynamic) | Left stick |
| Camera | Mouse (shift-lock on by default during rounds) | Drag on the right half | Right stick |
| Dash | Space | DASH button (big, bottom right) | A / Cross |
| Slide | C or Ctrl | SLIDE button | X / Square |
| Hard Stop | Shift | STOP button | B / Circle |
| Emote wheel (lobby) | G | Lobby button | D-pad up |

Mobile button layout and sizes are in §21.3.

---

## 10. Game feel: the panic loop

### 10.1 The escalation ladder (F-FEEL-01)
Tension climbs on four layers at once, so players *feel* the clock without reading it:

| Layer | Calm (no bomb near) | A bomb within 15 studs | You're carrying (LIT → HOT → CRITICAL) |
|---|---|---|---|
| **Music** | Round theme at full mix | Hi-hat layer added | The drums cut out; the heartbeat syncs with the tick |
| **Sound** | Footsteps, crowd | The nearby bomb's tick (3D, positional) | Your own tick, panned center, rising pitch; the fuse hiss |
| **Screen** | Clean | Faint warm edge glow on the bomb's side | A red vignette pulsing with the tick, growing 20 % → 45 % → 70 % |
| **Camera** | Normal | — | FOV +4° at HOT, +8° at CRITICAL; micro-shake at CRITICAL |

### 10.2 The Carrier's toolkit (F-FEEL-02)
When you're carrying, the HUD helps you make the 1-second decision:
- **Pass targets glow:** every eligible player within 25 studs gets a soft outline (team-coloured). The nearest one gets a pulsing arrow and the word **"BUMP!"**.
- **Defuse distance:** a chevron on the screen edge points at the nearest Safe Strip. It shows a **live estimate** ("2.1 s away") in green if you can make it on the current fuse, or red if you can't.

  The estimate is your distance ÷ your current speed, a simple and honest rule of thumb. It's still a decision, not a guarantee.
- **The pass you just received** flashes the giver's name ("from Kyle") for 1 s, which seeds a revenge storyline.

### 10.3 Impact & punctuation (F-FEEL-03)
| Moment | Treatment |
|---|---|
| **Tag lands** | **The slap (F-BOMB-10):** the Bomber lunges and slaps the hand bomb onto the Runner's back. A 90 ms hit-stop on both rigs, the in-house "smack" burst at the contact point (Asset Bible §5), a slap layered over the metallic "CLANK" as the clamp bites, and the bomb slams onto the back with squash-stretch, its face snapping to GOTCHA. The Runner stumbles forward. On the Bomber's own screen: a small camera punch. |
| **Pass** | A 0.18 s arc with a whistle and a motion trail. The receiver's bomb lands with the same CLANK, pitched up. The two bodies bump apart. |
| **Boom** | Full explosion stack (Asset Bible §5). Camera shake scales with distance: 0.6 within 10 studs, 0.25 within 30. A ragdoll fling with a soot-stained body for 3 s. |
| **Boom on you** | 0.35 s **impact freeze** (the camera holds while the explosion expands), then a whoosh as you fly. Then "YOU'RE A BOMBER" slams in with your new red role chip. You are back in control the moment you land. |
| **Field detonation** | A rolling blast wave across the field. Every on-field client gets the shake; Safe Strip players get a heavy rumble and a glass-rattle SFX. |
| **Defuse** | The fuse snuffs with a hiss and a steam curl, the clamp releases with a CLICK, and the bomb drops and rolls. Then a soft chime. |
| **Clutch Defuse** | Everything above, plus a 0.5 s **presentation slow-mo** (the local camera, VFX and audio run at 0.3×; gameplay doesn't pause), a golden flash, and a choir hit. |

**Slow-mo budget (F-FEEL-04):** presentation slow-mo only fires for:
- a Clutch Defuse
- a pass with ≤ 0.5 s left
- the Last Stand's end

It fires at most once every 4 s per client, so it never becomes noise.

### 10.4 Readability rules (F-FEEL-05) — never break these
1. **The bomb silhouette is the same for every skin.** Skins change materials, colours and trims, never the size or outline (Asset Bible §3.6).
2. **The fuse and the overhead fuse ring always show the true remaining time**, on every skin.
3. **Team colours are reserved:** Runner cyan `#2FD3FF`, Bomber red-orange `#FF4A2E`. Nothing cosmetic may use them as a dominant colour on a body.
4. **Explosion cosmetics** can change colour and shape, but keep the same timing and the same 7-stud splash ring.

### 10.5 The "moment" system (F-FEEL-06)
- The server keeps a 6-second **highlight buffer** of every participant's position and state, using `PositionHistory`.
- When a top-tier moment happens (Clutch Defuse, a 4+ Chain, a Last Stand finish), it's flagged.
- At `RESULTS`, the **best moment of the round** plays as a 4 s replay in the corner card ("MOMENT OF THE ROUND"), with the player's name.
- This ships in Phase P6. It reuses Chase Game's Final Moment Replay approach (§23).

---

## 11. Callouts & the reward drip

### 11.1 Callouts (F-CALL-01)
Every notable action pays out **instantly**, with a word, a sound and a number. Callouts stack on screen (a max of 3 at once, newest on top). Visual specs are in Asset Bible §6.

| Callout | Trigger | XP | Stars | Tier |
|---|---|---|---|---|
| **TAGGED!** | You (a Bomber) stick a bomb on a Runner | 5 | 1 | Small |
| **PASS!** | You pass a bomb (capped at 10 paid per round) | 5 | 1 | Small |
| **CLOSE ONE!** | You pass with ≤ 1.0 s left | 15 | 3 | Medium |
| **DEFUSED** | You defuse with > 1.0 s left | 15 | 3 | Medium |
| **CLUTCH DEFUSE!** | You defuse with ≤ 1.0 s left | 40 | 8 | Big (slow-mo) |
| **REVENGE PASS!** | You pass a bomb onto a Bomber | 20 | 5 | Medium |
| **REVENGE!** | You pass to the exact Bomber who tagged you | +10 bonus | +3 | Medium |
| **BETRAYAL!** | A Runner you passed to booms with it | 10 | 2 | Medium (comic sting) |
| **CHAIN ×3 / ×4 / ×5+** | A bomb you touched passes through 3+ Carriers | 10 per link | 2 per link | Big at ×5 |
| **BOOM!** | A bomb you started booms on a Runner (Bomber credit) | 20 | 3 | Medium |
| **DOUBLE BOOM / TRIPLE BOOM** | 2 or 3 of your bombs boom within 4 s | +25 / +60 | +5 / +12 | Big |
| **SURVIVED** | You end a crossing safe | 10 | 2 | Small |
| **ALL CLEAR** | Every Runner made it safe this crossing | 5 | 1 | Small (team) |
| **DODGE!** | A Bomber's tag reach passes within 1 stud of you and misses | 5 | 0 | Small |
| **LAST STAND!** | You're the last Runner | 30 | 5 | Big |

**Reward keys:** `Config.Economy.Rewards` uses the callout name in PascalCase (e.g. `ClutchDefuse`).

**Anti-farm (F-CALL-02):**
- The PASS rewards cap at 10 per round.
- Passes between the same two players pay only the first time per crossing.
- Bots grant **half** XP and Stars for TAGGED, PASS and BOOM credit, so lobbies stay fair without feeling punishing.
- Exactly how this is enforced: §24.2.

### 11.2 The reward drip (design target, F-CALL-03)
The point of the systems in §11–§16 is that **something good is always about to happen**. Targets for an average player:

| Interval | Something rewarding | Source |
|---|---|---|
| ~10 s | A callout with a Stars or XP pop | §11.1 |
| ~2.5 min | Round results: a bar fill, a quest tick | §8.4 |
| ~5–10 min | A level-up (fast early, slower later) | §12 |
| 5 / 15 / 30 / 45 / 60 min | A playtime gift (the 30-min gift is a free crate) | §14.3 |
| Every 15 min | A MEGA BOMB event | §16 |
| ~30 min | All 3 daily quests done → the bonus crate | §14.1 |
| Daily | The login streak calendar | §14.2 |

**The 30-minute session target** is designed to be hit three ways at once:
- the 30-minute playtime crate
- the ~30-minute daily quest set
- two MEGA BOMB events inside any 30-minute window

They are *aligned on purpose*.
