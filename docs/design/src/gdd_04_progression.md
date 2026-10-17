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
