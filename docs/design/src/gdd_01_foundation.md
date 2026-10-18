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
| D10 | Team split | **Changed 2026-10-17:** Partner: all gameplay scripting · User: UI, maps, assets (art, VFX, audio, models) · Claude Code builds both from this document | `docs/ART_BACKLOG.md` |
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
