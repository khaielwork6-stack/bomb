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
- **Looks (D-LOBBY-02):** the bots wear the avatars of the humans' friends, split evenly between the humans in the server (with 2 players, half the bots wear each one's friends), rebalanced at every intermission. Random dressed avatars fill in only when friends run out. Bots keep generated names, so only the look is borrowed.

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
