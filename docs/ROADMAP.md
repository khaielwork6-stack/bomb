# FUSE VALLEY — Roadmap to launch

The one list everyone works from. `docs/PROGRESS.md` keeps the detail of what's done; this file says **what's next,
in order, and who owns it**. Tick an item here when it's done, and add the detail to PROGRESS.

**Owners**
- **CODE**: Claude sessions (gameplay, systems, wiring, tests)
- **PARTNER**: art, UI, map, lobby build (in their Studio)
- **YOU**: things only a human can do (publish, dashboards, play-tests with people)
- **ANIMATOR**: the movement clips

**Rules**
- Pull before you start, and commit + push when you finish.
- Anything that lives in the place file (art, maps, the bomb, the face, skins) → **File → Publish to Roblox** right
  after the change.
- The GDD is law. New ideas go in `docs/DECISIONS.md` first.

---

## Stage 1: Lock in what's built (now)
Nothing new until this is solid.

- [ ] **YOU**: Publish the place: the bomb face, 17 skins and StreamingEnabled live in it.
- [ ] **YOU + PARTNER**: The first **2-player Team Test** (Studio → Test → Team Test, 2 players).
  - Play 5 rounds and write down what felt boring, confusing or unfair.
  - This closes P1-09 and is the only real "is it fun?" check we have.
- [ ] **CODE**: The Studio tests still open (each needs Studio free):
  - the moment-of-the-round replay card
  - buy / equip / crates in memory mode
  - the face live on a Carrier (eyes track, blink, stage poses)
  - MEGA BOMB with a human giant (stomp feel)
- [ ] **CODE**: The full 30-round bot soak (P2-06): 0 errors, flat memory.
- [ ] **YOU**: Creator Dashboard: create the developer products and game passes from GDD §17.2 and send the ids;
  CODE puts them in `Config.Store`.

## Stage 2: The lobby, "The Depot" (GDD §19, Asset Bible §4.3)
Players spawn here, wait through intermission here, and come back here after every round.

The order matters:
1. **PARTNER whiteboxes** the layout with named parts.
2. **CODE wires** against those names.
3. **PARTNER** does the art pass on top.

- [x] **CODE** built the whitebox instead (`builders/MapDepot`, P6-03), so the partner can go straight to the art pass. The partner skips the whitebox step.
  - Name these parts: `SpawnPlaza`, `ClockTower`, `ShopKiosk`, `QuestBoard`, `LeaderboardWall` (3 boards + 3 statue
    plinths), `FuseRange`, `VipLounge`.
- [x] **CODE**: The lobby flow. (P6-03, code done; a first-pass Depot is built by `builders/MapDepot`)
  - Spawn in the Depot, and spend intermission there.
  - Teleport to the Yard at INTRO, and back to the Depot at RESULTS.
  - Menus close gracefully at round start (§19.2).
- [x] **CODE**: The kiosks.
  - Walking up opens the Shop or Quests.
  - The featured items spin on plinths, and today's quests show as cards on the board.
- [x] **CODE**: The leaderboard wall: weekly Wins / Clutches / Booms from `LeaderboardService.top()`, with the champion
  statues wearing the top players' avatars.
- [x] **CODE**: The **clock tower**: a giant fuse burning down to the next MEGA BOMB (`MegaNextAt`).
- [x] **CODE**: The **Fuse Range**, the practice area ("Preview in game" still to do).
  - Dummies to tag and pass to, a practice-bomb dispenser and a defuse pad.
  - "Preview in game" for shop items (F-STORE-05).
- [x] **CODE**: The VIP lounge: a gate for VIP pass owners and the VIP firework button.
- [ ] **PARTNER**: The art pass on the whole Depot (Asset Bible quality bar).
- [ ] **YOU**: Publish.

## Stage 3: Movement animation + feel
- [ ] **ANIMATOR**: The 5 clips in `docs/reference/animation/ANIMATOR_BRIEF.md`: `Brake`, `DashLeft`, `DashRight`,
  `DashLeftArms`, `DashRightArms`.
- [ ] **CODE**: Wire them.
  - The arms clips layer over the run.
  - `Brake` and the dashes play at their real speed.
  - A dash with no direction held picks the side you're turning toward (there's no front dash).
- [ ] **CODE**: The Last Stand finish slow-mo (the last missing piece of GDD §10.3).
- [ ] **CODE**: Settings and accessibility (§21.3): volumes, camera sensitivity, the shift-lock default, Reduce
  motion, colour-blind mode. **PARTNER** styles the screen.

## Stage 4: Art and UI polish (PARTNER, with CODE hooks)
- [ ] **PARTNER**: Restyle the functional UI added so far: the MEGA clock chip, the "HURRY!" headline, the Moment of
  the Round card, the Starter Bundle offer card.
- [ ] **PARTNER + CODE**: The crate opening sequence (P5-05, Asset Bible §7.4). CODE handles the reveal logic and
  timing; PARTNER the visuals.
- [ ] **PARTNER + CODE**: The title plate under the nametag (P5-06).
- [ ] **PARTNER + CODE**: Cosmetic art for sparks, trails, explosions and victory booms (P5-07), with CODE applying
  them in game.
- [ ] **PARTNER**: The Yard's final pass (P3-08): hero props, debris, and the MEGA BOMB stomp ring and giant-bomb
  polish.
- [ ] **PARTNER**: Store page assets: the icon, 5 thumbnails, trailer frames.

## Stage 5: Launch prep
- [ ] **CODE**: The performance pass and a **real mid-range phone test** (P3-09, 60 FPS target). **YOU** need a
  phone for it.
- [ ] **CODE**: Analytics dashboards (§25): the new-player funnel, economy and retention.
- [ ] **CODE**: The "Summon the MEGA BOMB" product (F-MEGA-09), after the Stage 1 dashboard ids.
- [ ] **ALL**: The launch checklist (GDD §25.3 QA), then **soft launch**, then watching the KPIs (§25.1).

---

### Where things stand (2026-10-17)
- **Done:** core loop, bots, callouts, sound, explosions, hero bomb + face + 17 skins, progression, quests, daily
  rewards, economy (821 Stars/h), Shop / Locker, Starter Bundle, impact juice, hurry-up fuse, MEGA BOMB event, moment
  replay.
- **Not built yet:** the lobby (players wait on the Yard's start strip for now), the crate opening visuals,
  cosmetic art beyond bomb skins, settings, the final map pass.
