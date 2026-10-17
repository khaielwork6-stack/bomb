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
