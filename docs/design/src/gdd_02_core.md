## 5. Match flow & state machine

### 5.1 The loop at a glance
```
LOBBY/INTERMISSION (12 s) ─► INTRO (4 s) ─► CROSSING 1 ─► CROSSING 2 ─► … ─► CROSSING 8
                                              │                 (ends early: 0 Runners, or 1 Runner → LAST STAND)
                                              ▼
                                         LAST STAND ─► RESULTS (8 s) ─► INTERMISSION
```
A full round takes **2–3 minutes** [TUNE]. There is no map vote at launch (one map). This keeps the time between rounds at 20 seconds total (F-FLOW-01).

### 5.2 Phases (server state machine)
`Types.Phase`:
| ID | Phase | Duration | What happens | Exit |
|---|---|---|---|---|
| F-FLOW-02 | `INTERMISSION` | 12 s [TUNE] | Everyone in the lobby. The shop, quests and gifts are open, and the MEGA BOMB clock is visible. A 3-2-1 plays in the last 3 s. | Timer |
| F-FLOW-03 | `INTRO` | 4 s | Teleport to the start Safe Strip. A camera sweep shows the Bombers in the middle with role chips. The bombers are revealed with a "BOMBERS" stinger. | Timer |
| F-FLOW-04 | `READY` | 2 s | Runners stand behind the start line (a holding barrier), and the Field Fuse appears at full time. "3, 2, 1, GO" (shortened to "2, 1, GO" from crossing 2). | Timer |
| F-FLOW-05 | `CROSSING` | Field Fuse (§6.2) | Barrier drops. Runners run; Bombers tag; bombs pass and boom. | All Runners safe, OR Field Fuse = 0, OR Runners ≤ 1 |
| F-FLOW-06 | `RESOLVE` | 1.5 s | Field detonation (if the fuse hit 0), pending booms finish, and the turn-over stinger plays ("+2 BOMBERS"). | Timer |
| F-FLOW-07 | `LAST_STAND` | Intro 3 s + Field Fuse 12 s | §8.2 | Runner safe or boomed |
| F-FLOW-08 | `RESULTS` | 8 s | Winner reveal, podiums, the XP bar, quest ticks (§8.4) | Timer |

**Who plays what (F-FLOW-09):**
- **Bombers** spawn in the middle of the field at each `READY` and are held there until `GO`.
- **Runners** who reached the other side stay safe until the crossing ends.
- **Players joining mid-round** land in The Depot (§19.1) and drop in as **Bombers** at the next `READY` [OURS] (D-LOBBY-01). "YOU'RE UP NEXT" shows while they wait. Nobody waits a whole round, which is pillar P3.

### 5.3 Ending conditions (F-FLOW-10)
Checked continuously during `CROSSING`, in this order:
1. **0 Runners left** → Bombers win → `RESULTS`.
2. **1 Runner left**, and the round started with ≥ 4 Runners → finish the current crossing, then `LAST_STAND`.

   If the last Runner is already standing in a Safe Strip when they become the last one, the Last Stand starts after `RESOLVE`.
3. **The crossing completes** (every Runner safe or boomed, or the Field Fuse = 0):
   - If this was crossing 8 → the survivors win → `RESULTS`.
   - Otherwise, the next crossing starts in the other direction.

### 5.4 Round sizing
| Participants | Starting Bombers | Field width | Notes |
|---|---|---|---|
| 2–7 | 1 | narrow (map variant) | With fewer than 4 Runners at the start, there is no Last Stand |
| 8–15 | 1–2 | standard | |
| 16 (bot fill) | 2 | standard | The default case |
| 17–23 | 2 | standard | |
| 24–30 | 3 | standard | Bots stop filling at 16; above that every participant is a real player |

Formula: `bombers = clamp(floor(n / BOMBERS_PER), 1, BOMBERS_MAX)`. The starting Bombers are chosen at random, but nobody starts as a Bomber two rounds in a row (`Config.Round.BOMBER_REPEAT_GUARD`).

---

## 6. Crossings & the Field Fuse

### 6.1 Crossing rules [PARITY]
- **F-CROSS-01:** Runners must leave the start Safe Strip when `GO` sounds.
  - A Runner still inside the start strip **5 s** after GO gets a red "MOVE!" warning (`Config.Round.IDLE_WARN`).
  - At the Field Fuse's end, **anyone not in the destination strip is on the field**, so they detonate (§6.2).
  - This covers anyone who stays behind in the start strip too. You cannot wait out a crossing.
- **F-CROSS-02:** Safe Strips block Bombers with a soft wall: they slide along it, with no hard bounce.
- **F-CROSS-03:** Inside a Safe Strip you **can't be tagged and can't receive a pass**. Bombs carried in are defused (§7.6).
- **F-CROSS-04:** A Runner who reaches the destination strip is **safe for the rest of the crossing**. They can't walk back onto the field (soft wall) until the next `READY`.

### 6.2 The Field Fuse (F-FUSE-01..05) [OURS]
The crossing's own timer is a **physical fuse**: a burning cord runs along both edges of the field, with a spark racing toward the far end. This is pillar P1: the timer is something you can see in the world, not just a number.

| ID | Rule |
|---|---|
| F-FUSE-01 | The Field Fuse lengths per crossing are `20, 16, 13, 11, 10, 10, 10, 10` s [TUNE] (`Config.Round.FIELD_FUSE`). The Last Stand uses `12` s. |
| F-FUSE-02 | **Warning at 5 s:** the field floor's hazard lines glow, a klaxon plays and the HUD fuse turns red. **At 3 s:** the glow pulses and the music drops to a heartbeat. |
| F-FUSE-03 | **At 0, the field detonates.** A rolling chain of blasts runs across the field over 0.6 s. Every participant still on the field booms: Runners join the Bombers, and Bombers are only flung (they respawn in the middle at `READY`). |
| F-FUSE-04 | When every Runner is safe or boomed before the fuse ends, the crossing ends early and the remaining fuse fizzles out. You get a "ALL CLEAR" sting. |
| F-FUSE-05 | Field detonation booms award **no** Bomber credit. The callout is "FUSE OUT" in grey; it's the field's kill, not a person's. |
| F-FUSE-06 | **The hurry-up** (D-PACE-01): once half the Runners still in play are safe, or only idlers are left in the start strip, the Field Fuse cuts to its last **4 s** (`HURRY_SHARE`, `HURRY_LEFT`). "HURRY!" slams in and the 5-second warning fires at once. The Runners who made it never stand around waiting on stragglers, and the last ones get a scramble. The Last Stand keeps its full fuse. |

### 6.3 Why the Field Fuse matters
- It removes the one bad pattern of crossing-tag games: Runners hugging the safe edge and waiting.
- It shortens every crossing as the round goes on, so the pace climbs exactly as the Bomber crowd grows.

### 6.4 Round modifiers (F-MOD-01..05) [OURS]
Some rounds bend one rule. A modifier has to pass all six of these tests, or it doesn't ship:
1. It makes tag, pass and defuse matter **more**, and never replaces them.
2. Every role gets new decisions, and nobody idles.
3. No death comes without a tell and a counter.
4. It can be explained in one line in 2 seconds at INTRO.
5. It keeps the Runner / Bomber balance, as measured by the pace probe.
6. It needs no new art.

| ID | Rule |
|---|---|
| F-MOD-01 | **Rotation:** every **3rd** round is a modifier round (`Config.Modifiers.EVERY`). The modifier is picked at random from the pool, never the same one twice in a row. **Never on a MEGA BOMB round:** MEGA wins, and the modifier waits for the next round. A modifier that needs more players (the Mole) is skipped when there aren't enough. INTRO announces it as the headline, with the modifier's name and its one-line rule. A small chip under the team counter names it for the whole round. Studio: `Config.Debug.FORCE_MODIFIER`. |
| F-MOD-02 | **READ THE FACE**: *"No timers. Watch the bomb."* While a bomb is LIT, nothing shows its time: no overhead ring count, no burning braid, no tick speed-up, no faster Carrier vignette, no SAFE / TOO FAR verdict (the chevron shows only the run time). Every fuse is a random **3.0–5.0 s**, so the average stays 4.0. **The face never lies:** from **2.5 s left** (HOT) everything shows as usual. The face goes UHOH, and PANIC is always the last **1.0 s**. The server doesn't send the boom time to any client until the bomb turns HOT. Bots act on the same view: while a bomb is LIT, they assume the shortest fuse. |
| F-MOD-03 | **LIGHTS OUT**: *"The Yard goes dark. Bombs are the only light."* The Yard goes to night, never pitch black: silhouettes still read on a phone. Every live bomb is a lamp in its stage colour, **16 / 20 / 24 studs** at LIT / HOT / CRITICAL. Every Runner has a soft **6-stud** glow. Bombers have no glow, only two red eye glints that fade in within **28 studs**. The Safe Strips glow. A Carrier lights up the Bombers around them, and themselves too. Bots see the same: bot Runners see a Bomber only within 28 studs or inside a bomb's light. |
| F-MOD-04 | **THE MOLE**: *"One Runner is secretly a Bomber."* At INTRO, one Runner becomes the Mole, and only they are told. It needs **4+** starting Runners and is never a player in their first **5** rounds. The Mole plays and scores as a Runner. **STRIKE** (Q / gamepad X / the on-screen button) arms them for **3 s**: the next Runner they touch outside a Safe Strip gets a normal bomb, under the same rules as a tag. The Mole can't strike while carrying a bomb or standing in a Safe Strip, and a missed strike can be retried after **5 s**. A strike **reveals** the Mole: "IT WAS THE MOLE: name" goes to everyone, and the Mole is a Bomber from then on. The Mole is also revealed if they boom, at the end of crossing **3**, or once only one other Runner is left, so a Last Stand is never against a hidden Bomber. The strike counts as a tag, and its boom credits the Mole. |
| F-MOD-05 | **Rewards and records:** modifiers change no payout table. Every Star still comes from the normal callouts and round payouts (F-ECO-03 cap). The pace probe reports every modifier separately (passes per bomb, boom %, who won). |

**Why these three:** each one bends a different axis, so the rotation never feels like the same round again.
- READ THE FACE bends **timing**, and turns the hero bomb's face into the gameplay.
- LIGHTS OUT bends **what you can see**, and turns every bomb into a moving light.
- THE MOLE bends **who you trust**: Runners need each other to pass, and now they can't be sure of each other.

---

## 7. The Bomb (core mechanic)

### 7.1 The four rules (this is the whole on-screen tutorial)
> 1. **A Bomber's touch sticks a bomb on you.**
> 2. **Bump anyone to pass it.**
> 3. **The fuse never resets.**
> 4. **Reach a safe side to defuse it.**

### 7.2 The physical bomb (F-BOMB-01)
- A real 3D bomb model (Asset Bible §3) is **mounted on the Carrier's back** on a sprung clamp. It sits 0.4 studs off the torso, so it jiggles with movement.
- The fuse **is** the timer:
  - The braided fuse cord on top visibly burns down from full length to the cap.
  - The fuse length shown always equals the remaining time.
  - A spark travels down it.
- **Ticking stages**, by remaining time:

| Stage | Remaining | Visual | Audio |
|---|---|---|---|
| `LIT` | 4.0–2.5 s | Steady spark, slow pulse of the band lights | Tick at 2 Hz |
| `HOT` | 2.5–1.0 s | The seams start to glow orange; faster pulse | Tick at 4 Hz, pitch rising |
| `CRITICAL` | 1.0–0 s | White-hot seams, the body swells 8 %, it shakes, sparks spray | Tick at 10 Hz becomes a whine |

- **Everyone sees every bomb.** The Carrier also gets an **overhead fuse ring**: a circular timer above the head, visible through walls within 60 studs.
- **Carrier-only feedback:**
  - a red pulsing vignette
  - a heartbeat in sync with the tick
  - the PASS prompt (§10.2)

### 7.3 Getting a bomb — the tag (F-BOMB-02)
- A Bomber's **touch** on a Runner who isn't carrying (hitbox overlap; see `Config.Bomb.TAG_RANGE`) sticks a **fresh 4.0 s bomb** on that Runner.
- **Bomber tag cooldown:** 1.5 s after any tag [TUNE] (`TAG_COOLDOWN`). Their hand glows again when it's ready.
- **The slap (F-BOMB-10, D-FEEL-01):** every ready Bomber holds a small copy of the bomb (the hero bomb, its face and the Bomber's skin) in their right hand. The face looks at the nearest Runner. A tag is a **slap**: a quick lunge and an overhand slap, and the hand bomb clamps onto the Runner's back. The hand is empty while the tag cools down, then a fresh bomb grows back and its fuse lights when the tag is ready. So **anyone can read at a glance whether a Bomber is loaded**.
- **The stumble:** the slap shoves the tagged Runner **6 studs** forward, away from the Bomber, over 0.25 s (`TAG_SHOVE`, `TAG_SHOVE_TIME`), with a stumble. The new Carrier lands among the other Runners instead of next to the Bomber who just tagged them.
- **A Runner can carry only one bomb.** A Bomber touching a Carrier does nothing; the touch is ignored, no new bomb.
- There is **no limit on bombs in play**: every Bomber can create one with each tag.

### 7.4 Passing (F-BOMB-03..05)
| ID | Rule |
|---|---|
| F-BOMB-03 | **Contact passes.** When a Carrier's hitbox overlaps another eligible player, the bomb jumps to them **instantly** (server-authoritative). A 0.18 s visual arc plays from back to back. There is no button: contact is the pass. This makes it mobile-first, and it means accidents are part of the comedy.<br><br>**The bump (D-FEEL-01):** a pass knocks the two bodies apart, **3 studs** each, away from each other (`PASS_BUMP`), so "BUMP SOMEONE!" is literally what you see. |
| F-BOMB-04 | **The fuse keeps its remaining time.** It never resets, never extends. |
| F-BOMB-05 | **Eligible receivers:** anyone *not in a Safe Strip* and *not already carrying*. That includes Runners and Bombers.<br><br>**No pass-back for 1.0 s:** you can't pass a bomb straight back to the player who just gave it to you (`NO_PASSBACK`). This kills ping-pong.<br><br>**Receive grace of 0.2 s:** a fresh Carrier can't pass in the first 0.2 s (`RECEIVE_GRACE`). This stops same-frame bounces and gives the receiver one frame of "oh no". |

### 7.5 Booms (F-BOMB-06..08)
| ID | Case | Result |
|---|---|---|
| F-BOMB-06 | **It blows on a Runner** | The Runner booms: they're flung by an explosion impulse, ragdoll for 1.6 s, then **become a Bomber** (respawning in the middle at the next `READY`, or getting up where they landed if the crossing is still running and the field is clear). Credit goes to the **last Bomber who tagged this bomb's chain** (`bomb.origin`). |
| F-BOMB-07 | **It blows on a Bomber** (they received a pass) | Revenge: the Bomber is flung and **stunned for 3.0 s** (`BOMBER_STUN`); they can't tag or move. They stay a Bomber. A Bomber **can't pass a bomb on**: bombs on Bombers are locked, and they just blow. |
| F-BOMB-08 | **Blast splash** | Everyone else within 7 studs (`SPLASH_RADIUS`) gets a knockback shove (`Characters.push`, no ragdoll, no elimination). This is comedy and chaos, and lets you blow a crowd apart. [TUNE] |

### 7.6 Defusing (F-BOMB-09)
- A Carrier who enters a Safe Strip **defuses** the bomb.
  - The fuse snuffs with a hiss and a smoke curl.
  - The bomb pops off the clamp and clatters to the ground, then fades.
- **With ≤ 1.0 s left** it's a **CLUTCH DEFUSE**: slow-mo, a big callout and a big reward (§11).
- A defuse doesn't make the Runner immune to new tags on the next crossing. It's a fresh start.

### 7.7 Edge cases (all server rules)
| Case | Rule |
|---|---|
| Two Carriers touch | Nothing happens: neither is eligible (both carrying). |
| A Carrier touches two players in the same frame | The pass goes to the **closest** one. |
| A Carrier leaves the game | The bomb booms in place at their last position: splash only, no credit. |
| A Bomber leaves while their bomb is in play | Credit falls back to "the field"; no Bomber gets credit. |
| A Carrier falls off the map | The bomb booms at the kill plane. They become a Bomber (respawn middle). |
| The crossing ends while bombs are live | Bombs on Runners in Safe Strips are defused. Bombs on the field boom with the field detonation. |
| The last Runner is carrying when they become last | The bomb keeps ticking. If it booms, the Bombers win immediately. If they defuse it, the Last Stand begins. |

### 7.8 The bomb's numbers (Config.Bomb)
| Key | Value | Meaning |
|---|---|---|
| `FUSE` | 4.0 | Seconds on a fresh bomb [TUNE] |
| `STAGE_HOT` / `STAGE_CRITICAL` | 2.5 / 1.0 | Stage thresholds |
| `TAG_RANGE` | 3.5 | Studs, root-to-root (Bomber reach) [TUNE]. Was 4.5: with the lag slack, tags landed from 6.5 studs and never looked like a touch (D-FEEL-01) |
| `TAG_SHOVE` / `TAG_SHOVE_TIME` | 6 / 0.25 | studs / s: the slap's stumble (F-BOMB-10) |
| `PASS_BUMP` | 3 | studs each: the pass knock-apart (F-BOMB-03) |
| `PASS_RANGE` | 4.0 | Studs, root-to-root (body contact) [TUNE] |
| `TAG_COOLDOWN` | 1.5 | s |
| `NO_PASSBACK` | 1.0 | s |
| `RECEIVE_GRACE` | 0.2 | s |
| `BOMBER_STUN` | 3.0 | s |
| `SPLASH_RADIUS` / `SPLASH_PUSH` | 7 / 14 | studs / studs of shove |
| `BOOM_IMPULSE_H` / `_V` | 70 / 55 | studs/s fling [TUNE] |
| `CLUTCH_WINDOW` | 1.0 | s left for CLUTCH DEFUSE |
| `LAG_SLACK` | 2.0 | Extra studs of server tolerance for contact checks (§24.1) |

---

## 8. Winning, Last Stand, results

### 8.1 Win conditions (F-WIN-01..03)
| ID | Situation | Winner | Reward key |
|---|---|---|---|
| F-WIN-01 | The last Runner completes the Last Stand | **That Runner** (solo win, biggest reward in the game) | `LastStandWin` |
| F-WIN-02 | Every Runner booms | **The Bombers.** The top Bomber by booms is MVP | `BomberWin` + `MVP` |
| F-WIN-03 | 2+ Runners survive crossing 8 | **All survivors** (shared win) | `SurvivorWin` |

### 8.2 The Last Stand (F-LAST-01..05) [OURS]
| ID | Beat |
|---|---|
| F-LAST-01 | **Lights down.** The world dims to 35 %, a spotlight locks onto the last Runner, and a drumroll starts. A banner reads "LAST STAND — <NAME>" with their avatar headshot. 3 s. |
| F-LAST-02 | **Everyone's a Bomber now.** Every Bomber lines up in the middle. A crowd chant (the audience SFX loop) builds. |
| F-LAST-03 | **The run:** a 12 s Field Fuse. The Runner gets **+8 % speed** (`LAST_STAND_SPEED`, the "adrenaline" boost), shown as a light-streak trail. Bombers' tag cooldown stays 1.5 s. |
| F-LAST-04 | **Win:** they reach the strip → the world snaps to full light, a fireworks volley, "VICTORY" in gold, and the camera orbits the winner. **Lose:** the boom gets a 0.5 s slow-mo, a "BOMBERS WIN" stinger, and the camera cuts to the credited Bomber. |
| F-LAST-05 | Spectating players (every Bomber) get a **picture-in-picture** of the Runner's face cam on mobile. On PC the camera auto-follows the Runner if the player stops giving input for 2 s. |

### 8.3 The WINNER crown (F-WIN-04)
- **Anyone who wins** (any of the three ways) wears a **gold crown with a lit sparkler** above their head for the whole next round.
- It's visible to everyone, which brings social status and earns the "Dethrone" quest (§14).

### 8.4 Results screen (F-RES-01..04)
| ID | Element |
|---|---|
| F-RES-01 | **The headline:** the winner reveal (a 3D podium with the top 3 and their avatars), or "BOMBERS WIN" with the MVP. |
| F-RES-02 | **Your round, line by line**, counting up: crossings survived, defuses, clutches, passes, booms, win. Every line pays Stars and XP with a coin-burst. |
| F-RES-03 | **The XP bar fills** with sound ramps. If a level-up happens it **interrupts the screen** with the full level-up celebration (§12.3). |
| F-RES-04 | **The "next" hooks** (pick the 2 most relevant): "1 more round to level up", "Quest 2/3: Pass 7/10", "Gift in 3:12", "MEGA BOMB in 4:30". |

### 8.5 A full round, as a player sees it (reference walkthrough)
> **16 players: 14 Runners, 2 Bombers.**
> **Crossing 1 (20 s):** Bombers tag 5 Runners. Two pass their bomb to someone else, one sprints home and defuses, and two boom. *14 → 12 Runners, 4 Bombers.*
> **Crossing 2 (16 s):** More Bombers, more bombs in play. A Runner gets tagged, bumps a Bomber (REVENGE PASS!) and the Bomber gets stunned. Five Runners boom. *→ 7 Runners, 9 Bombers.*
> **Crossings 3–5 (13 → 10 s):** It's chaos, and the field fuse forces everyone to run. *→ 1 Runner left.*
> **LAST STAND:** Lights down, spotlight, drumroll. You run alone against 15 Bombers. You're tagged halfway with 4 s left, nobody is near enough to pass it to, so you sprint. **3… 2… 1…** You dive into the strip. **CLUTCH DEFUSE → VICTORY.** Crown on your head next round.
