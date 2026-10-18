# FUSE VALLEY — Master Game Design Document

**Version 1.0 · 2026-10-17 · Name: FUSE VALLEY (rename = change `Config.Game.NAME` + store page)**

> A 20-player Roblox tag game with a ticking bomb. Runners sprint across a field to the opposite safe side while Bombers hunt them. A Bomber's touch sticks a live bomb to your back. You can pass it on with a bump, but **the fuse never resets**. If it blows on you, you join the Bombers. The last runner standing wins.
>
> The crossing formula is the playground-tag loop players already know from *Huss Valley*. The bomb, the fuses, the presentation, the progression and every asset are ours.

---

## 0. How to use this document (read first — humans and Claude Code)

1. **This document is the single source of truth.** If something is not written here, do not build it. If two sections disagree, the more specific one wins, and the conflict is logged in `docs/DECISIONS.md`.
2. **Every feature has an ID**, for example `F-BOMB-04`. Code header comments, commits and tests reference these IDs.
3. **No magic numbers.** Every number lives in a `Config` module (Appendix A). Code reads the config and never hard-codes values.
4. **Tags tell you where a rule comes from:**
   - **[PARITY]**: the proven crossing-tag rules, kept one-for-one.
   - **[OURS]**: our addition or decision.
   - **[TUNE]**: a starting value expected to change after playtests.
5. **Build in phase order (§26).** Each phase has a Definition of Done. Never start phase N+1 until phase N's DoD passes.
6. **Assets** (models, sounds, UI art, VFX) are specified in the companion **ASSET BIBLE**. Code references assets only through `Shared/Assets.luau` keys, never raw IDs.
7. **The premium bar is not optional.** Read Asset Bible §1 ("The Quality Bar") before making *anything* players can see or hear. If an asset fails the checklist there, it does not ship, not even as a placeholder.
8. **Simplicity test.** Every feature must pass both checks:
   - (a) It uses the existing controls.
   - (b) It can be explained in one line of on-screen text.

   If a feature fails either check, it is cut or redesigned.

### 0.1 Document map
| § | Section | § | Section |
|---|---|---|---|
| 1 | Vision, pillars, non-goals | 14 | Daily systems: quests, login streak, playtime gifts |
| 2 | Locked decisions | 15 | Streaks, leaderboards, social |
| 3 | Glossary | 16 | MEGA BOMB event |
| 4 | Parity map | 17 | Store, cosmetics, crates |
| 5 | Match flow & state machine | 18 | Bots |
| 6 | Crossings & the Field Fuse | 19 | Lobby & intermission |
| 7 | The Bomb (core mechanic) | 20 | Onboarding & first session |
| 8 | Winning, Last Stand, results | 21 | HUD & UI |
| 9 | Movement & controls | 22 | Technical architecture |
| 10 | Game feel: the panic loop | 23 | Transfer plan (from Chase Game) |
| 11 | Callouts & the reward drip | 24 | Security, performance, data |
| 12 | Progression: XP & levels | 25 | Analytics, KPIs, QA |
| 13 | Economy: Stars | 26 | Build phases & Definition of Done |
| | | A | Config appendix |

---

## 1. Vision

### 1.1 The one-liner
**Tag, but you're holding a bomb.** Get tagged and a bomb sticks to your back, beeping faster and faster. Bump someone to pass it, but the clock never resets.

### 1.2 Pillars (every decision is checked against these)
| # | Pillar | What it means in practice |
|---|---|---|
| P1 | **Panic you can see** | The danger is always physical and visible: a real bomb on a real back, a fuse that visibly burns down, a field that glows before it blows. Nobody ever has to read a number to feel the danger. |
| P2 | **Three-second stories** | Every pass, defuse and explosion is a tiny story with a twist (betrayal, revenge, clutch). We design for those moments and celebrate every one of them. |
| P3 | **Never wait, never empty-handed** | Blown up? You're a Bomber instantly and still playing. Every round pays something. There's a reward beat every ~10 seconds, a level-up every ~10 minutes, and a gift every ~15 minutes. |
| P4 | **Premium or nothing** | Every model, sound, effect and screen is crafted to the Quality Bar (Asset Bible §1). No toolbox models, no AI-generated art, no generic gradients, no emoji icons, no stock "game UI kit" look. |
| P5 | **Simple to learn, deep to master** | Four rules for the bomb. Mastery comes from movement (dash, slide, hard stop), pass timing, reading the fuse and positioning, never from extra buttons. |
| P6 | **Mobile-first** | Most players are on phones. Every rule works with a thumbstick and auto-pass on contact. Every HUD element is laid out for a 844×390 screen first. |

### 1.3 Non-goals (do not build)
- No pay-to-win of any kind. Nothing purchasable changes speed, fuse time, hitbox or anything else that affects the outcome of a round.
- No weapons, health bars, abilities or items in the standard round. The bomb *is* the game.
- No guns, gore or realistic violence. Explosions are cartoon pyrotechnics: puffs, sparks, confetti-adjacent debris and soot. Bodies fling and tumble; they never break.
- No trading at launch.
- No custom chat.

### 1.4 Target experience
| Moment | Player feeling | Delivered by |
|---|---|---|
| First 10 seconds | "I get it." | Bombs are visible on backs, the 4-rule tutorial card (§20) and the first crossing |
| First tag on you | Pure panic, then a choice | Heartbeat, red vignette, fuse spark, the pass prompt (§10) |
| A pass with 0.5 s left | Laughter or rage, both shareable | Slow-mo, callout, kill-cam replay (§10.5) |
| Last Stand | Everyone watching one person | Spotlight, drumroll, crowd chant (§8.2) |
| Results | "One more." | XP bar, quest ticks, "1 more round to level up" (§8.4) |

---

## 2. Locked decisions (2026-10-17)
These were the open questions before writing this GDD. The user said "go" with the recommended picks; each is changeable through the noted config key.

| # | Decision | Value | Config |
|---|---|---|---|
| D1 | Name | **FUSE VALLEY** (was the working title FUSE VALLEY; the user named the place on 2026-10-17) | `Config.Game.NAME` |
| D2 | Max players per server | **20** | `Config.Game.MAX_PLAYERS` |
| D3 | Bots fill each round to | **16 participants** | `Config.Bots.FILL_TARGET` |
| D4 | Starting Bombers | **1 per 8 participants** (min 1, max 3) → 2 in a 16-player round | `Config.Round.BOMBERS_PER` |
| D5 | Bomb fuse | **4.0 s** | `Config.Bomb.FUSE` |
| D6 | Max crossings | **8** | `Config.Round.MAX_CROSSINGS` |
| D7 | Engine plumbing (networking, saving, participants, game state) | **Transferred** from Chase Game | §23 |
| D8 | Bots | **Yes**: Chase Game's bot movement, new bomb-aware brains | §18 |
| D9 | Roblox owner | **Same group as Chase Game** (keeps published animations and map props working) | §23.4 |
| D10 | Team split | User: gameplay scripting · Partner: art, UI, maps · Claude Code builds both from this document | `docs/INTEGRATION.md` |
| D11 | Art direction | **New: "Arcade Pyrotechnic"** (Asset Bible §2). It does not use Chase Game's studded look. | Asset Bible |

---

## 3. Glossary
| Term | Meaning |
|---|---|
| **Runner** | A player trying to cross. Starts as the majority team. |
| **Bomber** | A hunter. Their touch sticks a bomb onto a Runner. Bombers win if every Runner is blown up. |
| **Crossing** | One run from one Safe Strip to the other. A round has up to 8 crossings, alternating direction. |
| **Safe Strip** | The zone at each end of the field. Runners inside can't be tagged or bumped. A bomb carried in is defused. |
| **Field** | The play area between the two Safe Strips. Bombers can't leave it. |
| **Bomb** | The live explosive stuck to a player's back. It has a fuse with a remaining time in seconds. |
| **Carrier** | The player currently holding the bomb. |
| **Pass** | A Carrier bumps another player and the bomb jumps to them, keeping its remaining time. |
| **Fuse** | The bomb's remaining time. It never resets on a pass. |
| **Field Fuse** | The crossing's own timer. At 0 the whole field detonates. |
| **Boom** | A bomb exploding on its Carrier. |
| **Defuse** | Carrying a bomb into a Safe Strip. It fizzles harmlessly. |
| **Clutch Defuse** | A defuse with ≤ 1.0 s left on the fuse. |
| **Revenge Pass** | Passing a bomb onto a Bomber. |
| **Betrayal** | Passing a bomb to a Runner who then booms with it. |
| **Chain** | One bomb passing through 3+ Carriers before it booms or is defused. |
| **Last Stand** | The final solo crossing of the last Runner. |
| **MEGA BOMB** | The 15-minute scheduled event (§16). |
| **Stars** | The soft currency (§13). |
| **Participant** | A human or bot in the round. Every gameplay function takes a Participant. |

---

## 4. Parity map — what we keep vs what is ours
| Area | Rule | Source |
|---|---|---|
| Field | Two Safe Strips, a field between them, crossings alternate direction | [PARITY] |
| Hunters | Hunters start in the middle and can't enter the Safe Strips | [PARITY] |
| Elimination | A caught Runner joins the hunters and keeps playing | [PARITY] |
| Win | Last Runner standing wins | [PARITY] |
| Elimination method | Not instant. The tag sticks a 4 s bomb that can be passed or defused | [OURS] |
| Stalling | The Field Fuse detonates the field when the crossing timer ends | [OURS] |
| Hunters getting hit | A bomb passed onto a Bomber stuns them for 3 s | [OURS] |
| Finale | The Last Stand solo crossing with spotlight | [OURS] |
| Movement | Dash, slide, hard stop, omnimovement (from Chase Game) | [OURS] |
| Event | MEGA BOMB every 15 minutes | [OURS] |
| Progression, store, art, audio, UI | Original | [OURS] |

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
- **Players joining mid-round** spawn as **Bombers** at the next `READY` [OURS]. Nobody waits a whole round, which is pillar P3.

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
| 17–20 | 2 | standard | |
| 24 (MAX_PLAYERS raised later) | 3 | standard | |

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
- **A Runner can carry only one bomb.** A Bomber touching a Carrier does nothing; the touch is ignored, no new bomb.
- There is **no limit on bombs in play**: every Bomber can create one with each tag.

### 7.4 Passing (F-BOMB-03..05)
| ID | Rule |
|---|---|
| F-BOMB-03 | **Contact passes.** When a Carrier's hitbox overlaps another eligible player, the bomb jumps to them **instantly** (server-authoritative). A 0.18 s visual arc plays from back to back. There is no button: contact is the pass. This makes it mobile-first, and it means accidents are part of the comedy. |
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
| `TAG_RANGE` | 4.5 | Studs, root-to-root (Bomber reach) [TUNE] |
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
| **Tag lands** | 60 ms hit-stop on both rigs (Chase Game's fixed hit-stop registry), a metallic "CLANK" as the clamp bites, and the bomb slams onto the back with squash-stretch. |
| **Pass** | A 0.18 s arc with a whistle and a motion trail. The receiver's bomb lands with the same CLANK, pitched up. |
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

## 12. Progression: XP & levels

### 12.1 XP sources (F-PROG-01)
XP comes from the callouts (§11.1) plus the round payouts below (`Config.Economy.Rewards`):

| Key | When | XP | Stars |
|---|---|---|---|
| `RoundComplete` | You finish a round (any role, any result) | 15 | 3 |
| `SurvivorWin` | You survive crossing 8 (a shared win) | 60 | 15 |
| `LastStandWin` | You win the Last Stand | 150 | 50 |
| `BomberWin` | You're a Bomber when the Bombers win | 40 | 8 |
| `MVP` | The top Bomber by booms in a Bomber win | 30 | 10 |
| `FirstWinOfDay` | Your first win of any kind today | 100 | 25 |

**Expected average:** ≈ 120 XP and ≈ 30 Stars per 2.5-minute round [TUNE, verify in P4 soak].

### 12.2 Level curve (F-PROG-02)
`xpToNext(L) = 150 + 50 × (L − 1)`, capped at 2,000. There's no level cap; levels past 50 are shown with prestige stars.

| Level | XP to next | Cumulative | ≈ Time to reach (avg player) |
|---|---|---|---|
| 2 | 150 | 150 | 1 round |
| 5 | 300 | 900 | ~20 min |
| 10 | 550 | 3,150 | ~65 min |
| 20 | 1,100 | 11,650 | ~4 h |
| 35 | 1,850 | 30,900 | ~11 h |

Early levels come every ~5 minutes. That's the hook during the first session, when retention is decided.

### 12.3 Level-up rewards & celebration (F-PROG-03)
- **Every level:** `40 + 10 × L` Stars (capped at 300).
- **Every 5 levels:** a guaranteed cosmetic from the **Level Track**: bomb skins, fuse sparks, trails and titles that can't be bought, only earned (Asset Bible §8).
- **Celebration:**
  - A full-width banner: the level number slams in with a shockwave ring, firework pops and a choir.
  - The reward card flips over.
  - Everyone nearby sees a level-up firework on your character.
- **Level badge:** a bronze → silver → gold → platinum → obsidian frame shown on the nametag and leaderboard. It changes every 10 levels.

---

## 13. Economy: Stars

### 13.1 One soft currency (F-ECO-01)
**Stars** buy every cosmetic in the store and every crate opening. There's no second premium currency: Robux buy Stars packs or items directly (§17).

### 13.2 Faucets and sinks (F-ECO-02)
| Faucets (per average player) | Stars/hour |
|---|---|
| Rounds and callouts | ≈ 720 |
| Daily quests (3) | ≈ 230 per day |
| Playtime gifts | ≈ 330 per day + 1–2 crates |
| Login streak | ≈ 100–400 per day |
| Level-ups | ≈ 150 per hour early, falling later |

| Sinks | Price (Stars) |
|---|---|
| Common item | 400 |
| Rare item | 1,000 |
| Epic item | 2,500 |
| Legendary item | 6,000 |
| Spark Crate | 600 |
| Inferno Crate | 1,500 |
| Quest reroll | 50 |

### 13.3 The balance rule (F-ECO-03) — the lesson from Chase Game
> **No single round, event or gift may pay more than ~45 minutes of normal play's worth of Stars (≈ 550).**

In Chase Game, one Titan Hunt paid ~1,650 Stars, more than three of the cheapest Stars packs, so nobody bought Stars. Every reward table in this document respects the cap.

The P4 soak test (§26) prints the measured Stars/hour; it must land in 600–900.

---

## 14. Daily systems

### 14.1 Daily quests (F-DAILY-01..04)
| ID | Rule |
|---|---|
| F-DAILY-01 | Each day (00:00 UTC) every player gets **3 quests**: one Easy, one Medium, one Hard, drawn from the pool below without repeating yesterday's. |
| F-DAILY-02 | **Rewards:** Easy 40 ★ + 60 XP · Medium 70 ★ + 100 XP · Hard 120 ★ + 160 XP. **All three done → a free Spark Crate opening** (the "Daily Crate"). |
| F-DAILY-03 | **One free reroll a day.** Extra rerolls cost 50 ★. |
| F-DAILY-04 | Progress shows live in the HUD quest tracker (§21.2) and ticks with a sound and a +1 pop. A completion fires a banner and a coin shower. |

**Quest pool (the targets are [TUNE]; designed so all three take ~30 minutes):**
| Easy | Medium | Hard |
|---|---|---|
| Pass the bomb 10 times | Defuse 3 bombs | Get 2 Clutch Defuses |
| Survive 8 crossings | Make 3 Revenge Passes | Win 1 round (any way) |
| Tag 8 Runners | Get 5 Booms as a Bomber | Be part of a ×5 Chain |
| Play 5 rounds | Survive to crossing 4 three times | Get a Triple Boom |
| Dodge 5 tags | Win as a Bomber twice | Reach a Last Stand |
| Finish 3 crossings without being tagged | Make 2 Betrayals | Feed the MEGA BOMB 3 bombs (§16) |
| Play a MEGA BOMB round | Dethrone a crowned winner (boom them) | Win a Last Stand |

### 14.2 Login streak (F-DAILY-05..07)
| Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Reward | 100 ★ | 150 ★ | Spark Crate | 250 ★ | Rare item (random, from an unowned pool) | 400 ★ | **This month's Streak Bomb skin** (Epic, exclusive, rotates monthly) |

- **F-DAILY-06:** The calendar opens automatically on your first join each day. You claim by tapping, and the tap pays out with an animated stamp.
- **F-DAILY-07:** **A missed day drops you back 2 days**, not to day 1 (`Config.Daily.STREAK_MISS_PENALTY`). After day 7 it loops, and days 8+ repeat days 4–7.

### 14.3 Playtime gifts (F-DAILY-08..10)
| ID | Rule |
|---|---|
| F-DAILY-08 | Gifts unlock on **total minutes played today** (UTC day, saved), so leaving and rejoining doesn't reset progress or farm it. |
| F-DAILY-09 | **Milestones:** 5 min → 40 ★ · 15 min → 100 ★ · **30 min → a free Spark Crate** · 45 min → 150 ★ · 60 min → a Gift Box (Rare guaranteed, 15 % Epic). After that, every 30 min → 100 ★. |
| F-DAILY-10 | The HUD gift icon shows a ring that fills as you play, and a countdown to the next gift. When a gift is ready, the icon bounces and glows. You claim by tapping, and **claiming is never automatic**, because the tap is the reward moment. |

---

## 15. Streaks, leaderboards, social

### 15.1 Hot Streak (F-SOC-01)
- **Your streak +1** for every round you either **win** (any way) or **survive to crossing 5+**. Otherwise it resets to 0.
- **The Stars multiplier for that round's payout** (the round payouts paid at RESULTS, §12.1; callouts are not multiplied — DECISIONS D-ECO-02): streak 2 → ×1.25 · 3 → ×1.5 · 4+ → ×2.0 (`Config.Economy.STREAK_MULT`).
- **The HUD streak flame** (§21.2) grows with the streak and roars when the multiplier rises. When the streak breaks, the flame gutters out with a sad fizz. Loss aversion is the point.

### 15.2 Leaderboards (F-SOC-02)
| Board | Scope | Stat | Reset |
|---|---|---|---|
| In-server | The player list (`leaderstats`) | Level, Wins | — |
| Lobby boards (3 physical boards) | Global, `OrderedDataStore` | Wins · Clutch Defuses · Booms | Weekly (Monday 00:00 UTC) + all-time tab |
| Top 3 weekly | Lobby | A golden statue of each top player's avatar on a plinth | Weekly |

### 15.3 Social (F-SOC-03..05)
| ID | Feature |
|---|---|
| F-SOC-03 | **Squad bonus:** +10 % Stars for each Roblox friend in the same server, up to +30 %. Shown on the results screen as "SQUAD +20 %". |
| F-SOC-04 | **Invite prompt:** after your first win of a session, a "Show your friends" button opens `SocialService:PromptGameInvite`. It's never forced or spammed (once per session). |
| F-SOC-05 | **Group perk:** members of the game's Roblox group get the exclusive **"Insignia" fuse spark** (cosmetic) and a one-time 150 ★. Checked with `Player:IsInGroup`. **Likes and favourites are never rewarded**: incentivising votes or favourites breaks Roblox's rules. |

---

## 16. MEGA BOMB event (F-MEGA-01..08) [OURS]
The scheduled event, rebuilt from Chase Game's Titan Hunt framework (schedule, giant rig scaling, cinematics, event clock, summon product). The design is new.

| ID | Rule |
|---|---|
| F-MEGA-01 | **Schedule:** every 15 minutes on the UTC wall clock (`:00 :15 :30 :45`). The first round to start after a slot opens is a MEGA BOMB round. The same moment applies on every server. |
| F-MEGA-02 | **Roles:** one player becomes the **MEGA BOMBER**, a 3× giant with a huge bomb on its back and a crown fuse. Humans are weighted 3× over bots. Everyone else is a Runner. There are no regular Bombers at the start. |
| F-MEGA-03 | **Mega tag:** the giant's touch sticks a **3.0 s** bomb (shorter than normal). Runners who boom become regular Bombers on the Mega team. |
| F-MEGA-04 | **STOMP** (the Mega's Dash button): a ground slam, telegraphed by a ring for 0.6 s. It flings Runners within 12 studs (no bomb, no elimination; it scatters them). 6 s cooldown. |
| F-MEGA-05 | **The Mega Fuse:** the giant bomb on its back has a 90 s fuse, which is the event clock. When it burns out, **the MEGA BOMB detonates**: a whole-map blast, and every Runner not in a Safe Strip booms. Runners in a Strip at that moment **win**. |
| F-MEGA-06 | **Feed it bombs:** a Runner who passes their bomb onto the MEGA BOMBER **staggers it for 1.5 s and burns 6 s off the Mega Fuse** (the fuse visibly jumps). So the Runners' play is: get tagged on purpose, then feed it. It uses the existing pass mechanic, with no new controls. |
| F-MEGA-07 | **Crossings continue as normal** during the event (the Field Fuse still runs), so Runners must keep crossing *and* time the finale. |
| F-MEGA-08 | **Rewards:** Runners who win get ×3 round Stars (capped by F-ECO-03) and a free Spark Crate. If every Runner booms before the Mega Fuse ends, the MEGA BOMBER wins: ×3 Stars and the "Mega" title track. |

**Summon (F-MEGA-09):** a "Summon the MEGA BOMB" developer product (§17.2) makes the next round a MEGA BOMB round with the buyer as the giant. Only one is queued per server; extra buyers queue for later rounds, and their place in the queue is shown.

**The lobby and HUD event clock (F-MEGA-10)** is the same widget pattern as Chase Game's Titan clock: a compact lobby card, plus a compact in-round chip in the top bar row on phones (§21.2).

## 17. Store, cosmetics, crates

### 17.1 Cosmetic categories (F-STORE-01)
Everything is cosmetic. Nothing changes the outcome of a round (§1.3). Every category is something **other players see during the most-watched moments**, because that's what sells.

| Category | Shows when | Launch count | Readability rule |
|---|---|---|---|
| **Bomb Skins** (hero category) | Every time you carry, all round long | 16 | Same silhouette and fuse; materials and trims only (§10.4) |
| **Explosions** | Every boom you cause *and* your own boom | 8 | Same timing, same 7-stud ring |
| **Fuse Sparks** | Your bomb's spark plus your overhead fuse ring | 8 | The ring keeps the true time |
| **Trails** | Dash, slide and Last Stand | 8 | No team colours dominant |
| **Victory Booms** | Your win celebration and the podium | 6 | — |
| **Titles** | Nametag, leaderboard, results | 20 | — |
| **Emotes** | Lobby and results podium | 8 | Lobby only |

Full item list, art briefs and rarity: Asset Bible §8.

### 17.2 Prices (F-STORE-02)
| Rarity | Stars | Robux (direct) | Visual tier (frame, glow, reveal) |
|---|---|---|---|
| Common | 400 | 29 | Slate frame |
| Rare | 1,000 | 99 | Cyan frame and shimmer |
| Epic | 2,500 | 249 | Violet frame, particles |
| Legendary | 6,000 | 449 | Gold frame, animated foil, unique reveal music |
| Exclusive | — | — | Obsidian frame. Earned only (level track, streak, events, VIP) |

**Developer products:**
| Product | Robux | Contents |
|---|---|---|
| 500 Stars | 49 | 500 ★ |
| 1,200 Stars | 99 | 1,200 ★ (+20 %), tagged **BEST VALUE** |
| 3,000 Stars | 229 | 3,000 ★ (+30 %) |
| 7,000 Stars | 479 | 7,000 ★ (+45 %) |
| **Starter Bundle** (once per account) | 99 | 1,500 ★ + the **"Rookie Brass" Rare bomb skin** + the title "Fresh Fuse" (≈ 3× value) |
| Common / Rare / Epic / Legendary Item | 29 / 99 / 249 / 449 | The chosen item (one product per tier; the server remembers which item) |
| Spark Crate | 49 | One opening |
| Inferno Crate | 129 | One opening |
| Summon the MEGA BOMB | 99 | §16 |

**Game passes:**
| Pass | Robux | Contents |
|---|---|---|
| **VIP** | 299 | Gold nametag and chat tag, +10 % Stars, the exclusive "Gilded" bomb skin and "Champagne" explosion, and the VIP lounge in the lobby |
| **Bomb Workshop** | 149 | Recolour any owned bomb skin's trim and band lights from 16 curated swatches. Team colours are excluded; the swatches are tested for readability |

### 17.3 The shop screen (F-STORE-03..05)
| ID | Rule |
|---|---|
| F-STORE-03 | **Featured (daily rotation):** 4 items rotate at 00:00 UTC, with one "DEAL" at 20 % off. A countdown shows the next rotation. |
| F-STORE-04 | **Every item has a 3D preview:** a turntable in a ViewportFrame on a pedestal. Bomb skins show the full ticking cycle (LIT → HOT → CRITICAL) on a loop, and explosions play on a test dummy. **No flat icons for hero items.** |
| F-STORE-05 | **Try before you buy:** "Preview in game" equips the item for one round in the practice range (§19) without owning it. |

### 17.4 Crates (F-STORE-06..09)
| Crate | Price | Common | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| **Spark Crate** | 600 ★ / 49 R$ | 60 % | 30 % | 9 % | 1 % |
| **Inferno Crate** | 1,500 ★ / 129 R$ | — | 55 % | 35 % | 10 % |

| ID | Rule |
|---|---|
| F-STORE-06 | **The odds are always shown** on the crate card before purchase. This is a Roblox requirement for paid random items. |
| F-STORE-07 | **Duplicates** refund 50 % of the item's Stars price, with "+500 ★ (duplicate)" on the reveal. |
| F-STORE-08 | **Pity:** the Inferno Crate guarantees an Epic or better within any 8 openings. The counter shows on the card ("Epic+ in 3"). |
| F-STORE-09 | **Policy:** the server checks `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted`. Where it's true, **buying crates (with Robux or Stars) is disabled**: the crate shows "Not available in your region". Free crate rewards still open, but give the same item from a fixed list instead of rolling. |

**The crate opening (F-STORE-10)** is a premium reveal sequence: Asset Bible §7.4. The design has three beats:
1. The crate's fuse lights.
2. A rarity-coloured flare escapes through the lid seams (this is the tension beat; the colour hints at rarity).
3. The crate blows open with confetti-sparks, and the item rises on a beam.

### 17.5 The Starter Bundle offer (F-STORE-11)
- **The first session:** after the new player's **3rd round results**, show a one-time full-screen offer card with a 48 h countdown ("New Player Offer").
- **After that,** it lives in the shop with its countdown until it expires or is bought.
- **It's never shown more than once per session as a popup.**

---

## 18. Bots

### 18.1 Fill rules (F-BOT-01)
- **Bots fill each round to 16 participants** at `INTERMISSION`.
- **When a human joins mid-round**, a bot is removed at the next round boundary, never mid-round.
- **Bots use Chase Game's `AvatarPool`** (varied, realistic avatars) and natural names.

### 18.2 Brains (F-BOT-02..05) — new, bomb-aware
Bots steer with Chase Game's `MovementCore` (the same physics as players) and run new decision logic in `BombBrain`:

| ID | Role | Behaviour |
|---|---|---|
| F-BOT-02 | **Runner** | Picks a lane using a threat map (Bombers' positions and speeds). Times its start (some go straight, some wait for a gap, but never past the Field Fuse's 50 % point). Uses dash, slide and hard stop to dodge when a Bomber commits. **Steers away from Carriers.** |
| F-BOT-03 | **Runner carrying a bomb** | Each 0.1 s: if `timeToStrip < fuse − margin`, sprint to defuse. Otherwise pick the best pass target: the nearest reachable player, preferring a Bomber (revenge) when one is within reach. Then dash at them. |
| F-BOT-04 | **Bomber** | Picks a target (the reachable Runner with the best intercept angle; spreads out from other Bombers); cuts off lanes; dashes to close the last 6 studs. **Avoids Carriers** (doesn't want a revenge pass). |
| F-BOT-05 | **Skill tiers** | Rookie / Regular / Pro: reaction delay 0.35 / 0.22 / 0.12 s, decision error 25 / 12 / 5 %, and dash usage. Mix per round: 30 / 50 / 20 %. **A new player's first 2 rounds** get a 60 / 40 / 0 mix. |

### 18.3 Fairness (F-BOT-06)
- Bots never get information players don't have: no seeing through walls, and the same reaction delays.
- Bots never get movement advantages: the server validates the same speeds.

---

## 19. Lobby & intermission

### 19.1 The lobby: "The Depot" (F-LOBBY-01)
A compact, premium lobby island built in the new art direction (Asset Bible §4.3). Everything is reachable in under 6 seconds of running:

| Spot | Purpose |
|---|---|
| **Spawn plaza** | Where you land. The MEGA BOMB **clock tower** stands here: a giant fuse burns down the tower toward the next event (the world-space version of the event clock). |
| **Shop kiosk** | Opens the Shop. The featured items rotate on 3D plinths outside. |
| **Quest board** | Opens Quests. Shows today's 3 quests as physical cards pinned to the board. |
| **Leaderboard wall** | 3 boards + 3 weekly champion statues. |
| **Fuse Range** (practice) | Training dummies to tag and pass to. There's a "practice bomb" dispenser and a defuse pad. New players learn here safely, and AFK players have something to do. |
| **VIP lounge** | A gold-trimmed balcony with a better view and a VIP-only firework button. |

### 19.2 Intermission (F-LOBBY-02)
- **Length:** 12 s.
- **The HUD shows** "NEXT ROUND IN 12" and the MEGA BOMB chip.
- **When a menu is open at round start:** the menu closes gracefully, with a 0.3 s slide-out, before the teleport. No hard cuts.

---

## 20. Onboarding & the first session (F-ONB-01..07)
The first 5 minutes decide retention. Every step is measured (§25.2).

| ID | Step | Detail |
|---|---|---|
| F-ONB-01 | **Load** | A premium loading screen (Asset Bible §7.1): the game logo with a lit fuse that burns as assets load. The goal is under 6 s to playable. |
| F-ONB-02 | **The 4 rules card** | Shown once, on first join. Four animated panels, one per rule (§7.1), each with a 2 s looping illustration. One "GOT IT" button. It can be reopened from the menu. |
| F-ONB-03 | **First round** | A new player is **never a starting Bomber** in their first 2 rounds, and the bots lean easy (§18.2). |
| F-ONB-04 | **Contextual tips** (once each) | First carry: "BUMP someone — or run to a safe side!" First time becoming a Bomber: "Touch Runners to stick bombs!" First Field Fuse warning: "Get across before it blows!" Big, centered, and they fade after 2.5 s. |
| F-ONB-05 | **First results** | The XP bar fills and the player is guaranteed **level 2 by the end of round 1 or 2** (`xpToNext(1) = 150`). |
| F-ONB-06 | **Gift and quests intro** | After round 2: the quest tracker slides in, plus "Daily quests: earn Stars!" with a tap to view. |
| F-ONB-07 | **Starter Bundle** | After round 3 (§17.5). |

---

## 21. HUD & UI

### 21.1 Principles (F-UI-01)
- **Mobile-first:** design at 844×390, then check at 1920×1080, 1280×720 and the 2732×2048 iPad.
- **The HUD stays out of the field of play.** Nothing in the centre third except callouts, and they fade in under 2 s.
- **Every element moves:** spring-in on appear, press-squash on tap, count-up on numbers. Specs: Asset Bible §6.
- **No emoji anywhere.** Every icon is from the custom icon set (Asset Bible §6.4).

### 21.2 Round HUD layout (F-UI-02)
| Zone | Phone (844×390) | PC |
|---|---|---|
| **Top-left** | Roblox buttons; our menu button below them | Same |
| **Top-centre** | The **crossing chip** ("3/8") above the **HUD Field Fuse**: a horizontal burning-fuse bar, 220 px wide, with a spark at its tip | Same, 300 px |
| **Top-right** | **In Roblox's top bar row** (lesson from Chase Game): the team counter (runners / bombers icons + counts) and the MEGA BOMB chip | Under the top bar |
| **Left edge** | The quest tracker (collapsed to 3 small rings; tap to expand) | Expanded by default |
| **Centre** | Callouts (stacked, max 3); the defuse chevron at the screen edge | Same |
| **Bottom-right** | DASH (110 px), SLIDE and STOP (78 px) in an arc | Key hints on hover only |
| **Bottom-left** | The thumbstick zone (no art; Roblox's) | — |
| **Carrier layer** | Red vignette, heartbeat pulse, BUMP! arrows | Same |

**Lobby HUD (F-UI-03):** Stars (top-right), level badge and XP bar, the Hot Streak flame, the gift ring, and the quest, shop and calendar buttons in a right-side dock. The same top-bar-row rule applies on phones.

### 21.3 Screens (F-UI-04)
| Screen | Notes |
|---|---|
| Shop | Featured, Bomb Skins, Explosions, Sparks, Trails, Victory, Titles, Emotes, Crates and Stars tabs. 3D previews. |
| Locker | Equip each category, with live 3D previews on your own avatar. |
| Quests | 3 cards, progress bars, reroll, the daily crate chest. |
| Daily Calendar | 7 stamps, the claim animation, the streak count. |
| Crate Opening | Full-screen reveal (§17.4). |
| Results | §8.4. |
| Level Up | The interrupt celebration (§12.3). |
| Event Card | MEGA BOMB info, rewards and the summon button. |
| Settings | Music/SFX/UI volume, camera sensitivity, shift-lock default, reduced motion (turns off shake, slow-mo and vignette pulse), colour-blind mode (adds patterns to team chips). |

### 21.4 Copy tone (F-UI-05)
- **Headlines:** short, loud, ALL CAPS ("CLUTCH DEFUSE!").
- **Body:** sentence case and friendly ("Bump anyone to pass it.").
- **Words:** never "kill" or "die". We say **boom**, **blown up**, **out**.
- **Every string** lives in `Config.Strings`.

## 22. Technical architecture

### 22.1 Toolchain (F-TECH-01)
| Area | Setup |
|---|---|
| Sync | Rojo 7 (via Rokit), same mapping as Chase Game:<br>`src/shared` → `ReplicatedStorage.Shared`<br>`src/server` → `ServerScriptService.Server`<br>`src/client` → `StarterPlayer.StarterPlayerScripts.Client`<br>`builders` → `ServerStorage.Builders` |
| Format and lint | StyLua and Selene. `--!strict` in every file. |
| Tests | Studio MCP play-tests, plus the spec runner (`src/server/Tests`). |
| Rojo server | The user runs `rojo serve`; agents never start a second one. |
| Assets | 3D assets are authored as deterministic Blender 4.5 scripts in `art/` (Asset Bible §9). Audio sources go in `audio/`. UI art goes in `ui/`. |

### 22.2 Server-authoritative model (F-TECH-02)
- **The server owns all gameplay truth:**
  - phases
  - roles
  - who carries which bomb, plus the bomb's `explodeAt` (server time)
  - contact checks
  - booms
  - rewards
- **Contact is detected on the server** every `Heartbeat`: an all-pairs distance check, about 120 pairs at 16 participants.
  - The client sends **no "pass" or "tag" remote**, so there's nothing to spoof.
  - The ranges include `LAG_SLACK` for replication delay (§24.1).
- **Bomb visuals are client-side.** Each client builds the bomb model locally on every Carrier from the replicated participant attributes `BombId`, `BombExplodeAt` and `BombSkin`. The fuse length is `explodeAt − workspace:GetServerTimeNow()`.
  - Nothing physical replicates.
  - Every client shows the same time.
  - The fuse burns smoothly at 60 FPS.

### 22.3 Modules (F-TECH-04)
**Server services (`src/server/Services`):**
| Service | Status | Job |
|---|---|---|
| Net, GameState, Participants, PlayerService, DataService, AdminService, PositionHistory | **Transfer** | Plumbing (§23) |
| Characters | **Transfer, trimmed** | Spawn, ragdoll, push, settle, scale |
| MovementValidator | **Transfer** | Speed and teleport checks |
| MoveService | **New, extracted** | The Dash / Dive / Look / MovementTech remote handlers, lifted out of Chase's Combat.luau |
| ArenaService | **Transfer, adapted** | The map contract: Safe Strips, Field, lines (from Chase's `Arena`) |
| RoundService | New | The state machine (§5) and win conditions (§8) |
| BombService | New | Tag, pass, fuse, boom, defuse and every edge case (§7). Pure rules live in `Logic/BombRules.luau` |
| FieldFuseService | New | The crossing timer and field detonation (§6.2) |
| RewardService | New | Callouts → XP/Stars, anti-farm, multipliers (§11, §15.1) |
| ProgressionService | Adapted | Levels and level rewards (§12) |
| QuestService, DailyService | New | Quests, login streak, playtime gifts (§14) |
| LeaderboardService | Adapted | Global and weekly boards, statues (§15.2) |
| StoreService, CosmeticService, CrateService, ProductService | Adapted (Chase patterns) | Shop, inventory, crates with pity and policy, receipts (§17) |
| MegaBombService | New (built from TitanService's schedule, scaling and cinematics) | §16 |
| BotService + `Logic/BombBrain` | New brain; movement transferred | §18 |
| AnalyticsService | Adapted | §25 |

**Client controllers (`src/client/Controllers`):**
| Controller | Status | Job |
|---|---|---|
| Movement, Input, Camera, Pose, Footstep | **Transfer** | Feel (§9) |
| BombController | New | The bomb model on backs, fuse burn, stages, pass arcs, the overhead ring, carrier toolkit (§7.2, §10.2) |
| FuseController | New | The world fuse cords and HUD Field Fuse (§6.2) |
| FxController | New | Explosions, defuses, field detonation, slow-mo budget (§10.3) |
| CalloutController | New | §11.1 |
| AudioController | New | Layered music and escalation (§10.1) |
| HudController, LobbyHudController | New | §21 |
| Results, Shop, Locker, Quests, Daily, Crate, MegaBomb, Onboarding, Settings | New | §8.4, §17, §14, §16, §20, §21 |

### 22.4 Remotes (F-TECH-03)
Declared in `Shared/Net.luau`:
| Remote | Direction | Payload |
|---|---|---|
| `RequestDash`, `RequestSlide`, `RequestHardStop`, `Look`, `MovementTech` | C→S | Transferred movement intents |
| `BombFx` | S→C | `{kind = "Stick" \| "Pass" \| "Boom" \| "Defuse", bomb, from, to, pos, at, clutch?}` |
| `FieldFx` | S→C | `{kind = "Warn" \| "Detonate" \| "Clear", crossing, at}` |
| `Callout` | S→C (one player) | `{key, xp, stars, mult}` |
| `RoundFx` | S→C | Intro, Last Stand and results beats |
| `ClaimGift`, `ClaimLogin`, `RerollQuest`, `Equip`, `BuyStars`, `BuyRobux`, `OpenCrate`, `MegaSummon` | C→S | Every one is validated and rate-limited |

---

## 23. Transfer plan (from Chase Game)
The user's rule: bring over **movement, animations and the map (temporary)**; everything visible is new. Plumbing and bot movement are transferred too (decisions D7, D8).

### 23.1 Transfer list
| System | Files (Chase Game paths) | Notes |
|---|---|---|
| **Movement** | `src/shared/MovementCore.luau`, `src/shared/AbilityMotion.luau`, `src/shared/Config/Movement.luau`, `src/client/Controllers/{MovementController, InputController, CameraController}.luau`, `src/server/Services/MovementValidator.luau`, `src/server/Tests/MovementCore.spec.luau` | Strip `DashCourseLayout` and the Spring ability references. Rename `Profiles.Catcher` to `Bomber`. |
| **Movement remote handlers** | From `src/server/Services/Combat.luau` (≈ lines 502–600) | Extract into the new `MoveService`. Chase's Combat file itself does **not** transfer. |
| **Animations** | `src/shared/Locomotion.luau` (with the 2026-10-15 self-heal), `src/client/Controllers/{PoseController, FootstepController}.luau`, the `Assets.Anim` movement ids, `tools/anim/` (the whole baker pipeline) | Drop the Titan variant until MEGA BOMB (P6). **The "ANIM PACK" in Chase's place is a competitor rip: never copy, port or upload it.** |
| **Hit-stop** | The fixed `hitStop` registry from Chase's `FeedbackController` | Only that function. It's the overlap-safe version from 2026-10-15. |
| **Ragdoll** | The `ragdoll`, `push`, `settle`, `unragdoll` and `setScale` parts of `src/server/Services/Characters.luau`; `CosmeticLooks` stubbed | |
| **Map (temporary)** | `builders/{MapKit, MapMeadow, Util, Environment}.luau`, Theme (only the map colours), `src/server/Services/Arena.luau`, `Config/{Arena, Maps}.luau` | A placeholder until the launch map (Asset Bible §4) |
| **Plumbing** | `src/shared/{Net, Types}.luau`, `src/shared/Util/{Signal, Trove, Rng, Log, Format}.luau`, `src/client/ClientState.luau`, `src/server/Services/{GameState, Participants, PlayerService, PositionHistory, DataService, AdminService}.luau`, `src/server/Logic/{SessionLock, ProfileSchema}.luau`, `src/server/Tests/Runner.luau`, both `init` scripts | Trim the `ORDER` lists and `Config/init` to the transferred modules. The profile schema starts fresh (§24.3). |
| **Bots (movement + avatars)** | `src/server/Services/AvatarPool.luau`, the steering parts of `BotService.luau` | The brains are rewritten (§18) |
| **MEGA BOMB base** (P6) | `TitanService` schedule, giant scaling and summon queue; `TitanController` clock widgets | Rebuilt with the new design and new art |

### 23.2 Not transferred
Combat rules, Titan Hunt (as designed), abilities, modifiers, hazards, blocks, Brave or Bail, the cosmetics catalogue, the store UI, the crates' content, Theme/Style UI tokens, every UI controller, every texture and model, the Art3D library, the studded look.

### 23.3 Transfer procedure (Phase P0)
1. Create the new place (Studio → New → Baseplate) and save it as "FUSE VALLEY".
2. Copy the files in §23.1 into the new repo with the **same relative paths**.
3. Trim the ORDER lists, `Config/init`, `Net` remote names and `Assets` to what exists. Run `selene` and fix every unresolved require.
4. Run the map builders in the new place (builders/README snippet), then save.
5. **Studio check:** join, run, dash, slide, hard stop and strafe on the Meadow field. Animations play, and there are 0 console errors.

### 23.4 Ownership (decision D9)
- **The game lives under the same Roblox group as Chase Game.** The published animation ids and map prop assets are group-owned and work there without re-uploading.
- **If the owner ever changes,** re-publish the clips from `tools/anim/out` and update `Assets.Anim`.

---

## 24. Security, performance, data

### 24.1 Security (F-SEC-01..05)
| ID | Rule |
|---|---|
| F-SEC-01 | **No client remote can cause a tag, pass, boom or reward.** These come only from server contact checks and server timers. |
| F-SEC-02 | **The contact range** is `TAG_RANGE` / `PASS_RANGE` + `LAG_SLACK` (2 studs), measured on server-side positions. The movement validator rejects teleports and speed hacks, so the slack can't be abused for long-range passes. |
| F-SEC-03 | **Every C→S remote** goes through `Net`'s type check and token-bucket rate limits (transferred). |
| F-SEC-04 | **Receipts are idempotent** (`ProcessReceipt` + a stored `purchaseId` set, Chase Game's pattern). Purchases grant only after the profile save succeeds. |
| F-SEC-05 | **Anti-farm** (§11.1 F-CALL-02): the pair limit is `(giver, receiver, crossing)`; the PASS pay cap is 10 per round; a bot-credit halving applies. Private servers with fewer than 4 humans: Stars from callouts are halved. |

### 24.2 Performance budgets (F-PERF-01)
| Budget | Limit |
|---|---|
| Target device | 60 FPS on a mid-range phone (iPhone 11 / Galaxy A52 class) |
| Bomb model | ≤ 2,500 tris, ≤ 4 MeshParts, 1 SurfaceAppearance set (shared by skins via texture swaps), 1 PointLight (CRITICAL only) |
| A full explosion | ≤ 220 particles at peak, ≤ 1.2 s of emission, 1 light flash |
| Simultaneous full explosions | 3. Beyond that, the "light" variant (40 % particles) plays |
| Screen-space UI | ≤ 2 nested ViewportFrames visible at once (shop previews paginate) |
| Map | ≤ 8,000 parts, `StreamingEnabled` off (small map, instant visibility matters for a tag game) |
| Server | ≤ 4 ms per Heartbeat at 20 humans + bots (contact checks are ~120 distance checks) |

### 24.3 Data (F-DATA-01)
The session-locked profile (transferred DataService) uses a fresh schema `v1`:
```
profile = {
  version = 1, createdAt,
  level, xp, stars,
  inventory = { [itemId] = true },
  equipped = { BombSkin, Explosion, FuseSpark, Trail, VictoryBoom, Title, Emotes = {…} },
  stats = { rounds, wins, lastStandWins, defuses, clutches, passes, booms, revenge, chains5 },
  daily = { day, quests = {{id, progress, done}}, rerolls, playSec, giftsClaimed = {} },
  login = { lastDay, streakDay },
  hotStreak, pity = { Inferno = 0 },
  flags = { tutorial, starterOffered, starterBought, groupPerk },
  receipts = { [purchaseId] = true },   -- trimmed to the last 200
}
```

---

## 25. Analytics, KPIs, QA

### 25.1 KPI targets (F-KPI-01)
These are our goals (not industry facts). They're used to decide **when to buy ads**:

| KPI | Soft launch target | Before buying ads |
|---|---|---|
| D1 retention | ≥ 15 % | **≥ 20 %** |
| D7 retention | ≥ 4 % | ≥ 6 % |
| Average session length | ≥ 15 min | **≥ 25 min** (goal 30+) |
| Rounds per session | ≥ 6 | ≥ 10 |
| Payer conversion (of DAU) | ≥ 0.5 % | ≥ 1.5 % |

**The ad rule:** no paid ads until the "before buying ads" column is met in organic play. This is the lesson from Chase Game's $50 test.

### 25.2 Events (F-KPI-02)
Built on Roblox `AnalyticsService`:
- **The onboarding funnel** (`LogOnboardingFunnelStepEvent`), in order:
  1. Loaded
  2. Rules card closed
  3. Round 1 started
  4. First carry
  5. First pass or defuse
  6. Round 1 finished
  7. Level 2
  8. Round 3 finished
  9. Quest tracker opened
  10. Round 5 finished
- **Economy** (`LogEconomyEvent`): every Stars source and sink, with the transaction type.
- **Custom** (`LogCustomEvent`): round length, crossings, booms per round, clutches, Last Stand reached/won, starter offer shown/bought, MEGA BOMB participation, playtime gift claimed (per milestone).

### 25.3 QA (F-QA-01)
**Specs (pure modules), run with `RUN_TESTS`:**
- `BombRules`: eligibility, no-passback, receive grace, closest-target tie-break, every §7.7 edge case.
- `FieldFuse` timings.
- `Rewards` math with multipliers and caps.
- `LevelCurve`.
- `Quests` progress.
- `HotStreak`.
- `CrateRoll`: odds over 100k rolls within ±0.5 %, pity, policy branch.
- `ProfileSchema` migration.

**Other checks:**
- **The soak test** (from P2): `SIM_MODE`, 15 bots, `TIME_SCALE 2`, 30 rounds. Pass = 0 errors and < 10 % memory growth. From P4 it also prints Stars/hour, which must land in 600–900.
- **Device pass** (from P3): a phone at 844×390 (Studio emulator + `CG_ForceDevice`) and a real-device test before each phase gate.

---

## 26. Build phases & Definition of Done

### 26.1 Phases
| Phase | Goal | Contents | Definition of Done |
|---|---|---|---|
| **P0 Setup** | The foundations run | §23 transfer, repo, place, Rojo, temporary map | Full movement and animations on the Meadow field; 0 console errors; `selene` clean |
| **P1 Core loop** | A playable round | RoundService, ArenaService, BombService (all of §7), FieldFuse, Last Stand, win conditions, a grey-box HUD, ragdoll booms | A full round plays end to end with 2+ players in Studio Team Test; every §7.7 edge case passes its spec |
| **P2 Bots** | A solo player gets a full round | BombBrain (Runner, Carrier, Bomber), fill rules, skill tiers | A solo round is lively; bots defuse and pass sensibly; the soak test passes |
| **P3 Feel & hero assets** | It feels incredible | **The hero bomb** (Asset Bible §3), the explosion stack (§5), the audio escalation (§10.1), callouts (§11), Last Stand presentation, results screen, the launch map's first pass | Every shipped asset passes the Quality Bar checklist (Asset Bible §1.3); 60 FPS on a mid-range phone; the user signs off on the bomb |
| **P4 Retention** | The 30-minute loop | XP and levels, Stars, quests, login streak, playtime gifts, Hot Streak, leaderboards, squad bonus, onboarding | Economy soak lands at 600–900 Stars/hour; every funnel event fires; a new player hits level 2 within 2 rounds |
| **P5 Store** | People can pay | Shop, Locker, crates (pity, policy), products, passes, Starter Bundle, the launch catalogue (all premium) | Studio test purchases work end to end; receipts are idempotent; odds are shown; the policy branch is tested |
| **P6 Event & launch** | Ship | MEGA BOMB, final lobby, final map, moment replay, settings and accessibility, analytics dashboards, performance pass, store page (icon, thumbnails, trailer frames) | The launch checklist passes, and soft launch begins (KPIs in §25.1) |

### 26.2 Working rules (same discipline as Chase Game)
- Every task ends with:
  - `stylua src`
  - `selene src`
  - `rojo build`
  - a Studio play-test with 0 errors
  - `docs/PROGRESS.md` ticked
  - a commit `P<n> <TaskID>: <summary>`
- **Pull before work**; the partner works in the same repo.
- **Play-tests that touch the real profile:** record the profile with `data` first and restore it afterwards (the Chase Game lesson).

---

## Appendix A. Config index
| Module | Key values (defaults in this document) |
|---|---|
| `Config.Game` | `NAME = "FUSE VALLEY"`, `MAX_PLAYERS = 20` |
| `Config.Round` | `INTERMISSION = 12`, `INTRO = 4`, `READY = 2`, `RESOLVE = 1.5`, `RESULTS = 8`, `MAX_CROSSINGS = 8`, `FIELD_FUSE = {20,16,13,11,10,10,10,10}`, `LAST_STAND_FUSE = 12`, `LAST_STAND_SPEED = 1.08`, `LAST_STAND_MIN_RUNNERS = 4`, `BOMBERS_PER = 8`, `BOMBERS_MAX = 3`, `BOMBER_REPEAT_GUARD = true`, `IDLE_WARN = 5`, `FUSE_WARN = 5`, `FUSE_PULSE = 3` |
| `Config.Bomb` | §7.8 |
| `Config.Movement` | Transferred unchanged (§9.1); `Profiles.Bomber` |
| `Config.Economy` | `Rewards` (§11.1, §12.1), `PASS_PAY_CAP = 10`, `BOT_CREDIT_MULT = 0.5`, `STREAK_MULT = {[2]=1.25,[3]=1.5,[4]=2.0}`, `SQUAD_BONUS = 0.1`, `SQUAD_MAX = 0.3`, `ROUND_STAR_CAP = 550`, `RARITY_PRICES = {Common=400, Rare=1000, Epic=2500, Legendary=6000}`, `VIP_STARS_MULT = 1.10` |
| `Config.Progression` | `XP_BASE = 150`, `XP_STEP = 50`, `XP_CAP = 2000`, `LEVEL_STARS = {base=40, per=10, cap=300}`, `TRACK_EVERY = 5` |
| `Config.Daily` | `QUESTS` (pool, §14.1), `QUEST_REWARDS`, `REROLL_COST = 50`, `LOGIN_REWARDS` (§14.2), `STREAK_MISS_PENALTY = 2`, `GIFTS` (§14.3) |
| `Config.Mega` | `SCALE = 3`, `HUMAN_WEIGHT = 3`, `TAG_FUSE = 3.0`, `STOMP_RADIUS = 12`, `STOMP_TELEGRAPH = 0.6`, `STOMP_CD = 6`, `MEGA_FUSE = 90`, `FEED_BURN = 6`, `FEED_STAGGER = 1.5`, `REWARD_MULT = 3` |
| `Config.Store` | `Products` (§17.2), `Passes`, `Crates` (odds, pity = 8), `FEATURED = 4`, `DEAL_DISCOUNT = 0.2`, `STARTER_OFFER_ROUND = 3`, `STARTER_OFFER_HOURS = 48` |
| `Config.Bots` | `FILL_TARGET = 16`, `TIERS` (§18.2), `TIER_MIX = {0.3,0.5,0.2}`, `NEWBIE_MIX = {0.6,0.4,0}` |
| `Config.Strings` | Every player-facing string |
