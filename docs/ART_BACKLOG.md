# ART & UI BACKLOG — FUSE VALLEY
Everything players see or hear that is still to build, from the Asset Bible (AB) and GDD, checked against the code on 2026-10-17.
**Owner:** the art / UI / maps side (the partner owns gameplay scripting). Every item still has to pass the Quality Bar (AB §1.3).

**Tiers:**
- **FREE**: pure art or client work; we can start now.
- **HOOKED**: client-only; the server already sends the data.
- **BLOCKED**: needs new server/gameplay code from the partner first (the request is noted).

> **Shared files:** the partner also edits `BombController`, `StoreController`, `QuestTrackerController`, `Assets.luau`, `Config/init` and `init.client.luau`. Before touching them, merge the latest `main` into `fallenbomb`, keep the changes small, and merge back the same day.

---

## 1. Must-fix first
- [ ] **Mobile action buttons** (HOOKED · GDD §21.2, AB §6.6). DASH 110 px, SLIDE and STOP 78 px in an arc, with a cooldown drain ring and a ready ping. **Phones currently can't dash, slide or stop at all**: `InputController` binds with no touch buttons, and nothing calls `InputController.trigger`. Needs the Dash / Slide / Stop icons (§4).
- [ ] **Nametag + level badge** (HOOKED · GDD §12.3). The humanoid name display is off, so nobody has a name over their head. The `Level` attribute is already sent. Badge frames: bronze → silver → gold → platinum → obsidian, one per 10 levels.
- [ ] **Title plate under the nametag** (HOOKED · AB §8.4, P5-06). A brass plate whose frame takes the title's rarity colour; reads `Eq_Title`.

## 2. Screens & sequences
- [x] **Crate opening** (HOOKED · AB §7.4, P5-05). `Reward{kind="Crate"}` already carries the item, rarity and duplicate refund; the client ignores it today. Needs a crate model (Spark / Inferno / Gift Box), a workshop table, a lid-seam rarity glow, a pop VFX, an item-on-a-beam reveal, a skip option, and EQUIP / OPEN ANOTHER buttons.
- [x] **Loading screen** (FREE · AB §7.1, F-ONB-01). Needs a ReplicatedFirst script plus a Rojo mapping, the **logo** (hero sign-off), the fuse burning as the game loads, rotating tips and a wipe out.
- [x] **Starter Bundle offer card** (HOOKED · F-STORE-11). `starter.endsIn` is already in the store snapshot. The product id is 0 (hidden) until it's made on the Creator Dashboard.
- [x] **Menu button + Settings screen** (mostly HOOKED · GDD §21.3). Needs: music, SFX and UI volume; camera sensitivity; shift-lock default; reduced motion; colour-blind team-chip patterns; and a "rules card" reopen (`OnboardingController.showRules` exists).
  - **Request for partner:** send saved settings back on join (`Settings.apply` is never called).
  - **Request for partner:** make AudioController and Sfx read the volumes.
- [x] **Results 3D podium** (HOOKED · AB §7.2). Top 3 avatars on brass podiums; the 1st gets a crown and a confetti cannon. For a Bomber win, the MVP on a stage with soot. The receipt card needs paper art and a printer sound. *(fallenbomb 2026-10-18: UI/Podium on the modelled Prop.Podium; receipt paper art + printer sound still open)*
- [x] **Level-up: what's still missing** (HOOKED · AB §7.3). A 3D turntable for level-track items and a choir hit.
  - **BLOCKED:** the firework others see over your head. **Request for partner:** a LevelUp broadcast.
- [x] **Daily calendar polish** (HOOKED · AB §7.5). A corkboard with pins, and a big Day-7 card showing the Streak Bomb.
- [ ] **Shop / Locker: what's still missing** (HOOKED · §17.3). Stars and Emotes tabs, explosion-on-dummy previews, the featured-rotation countdown, and "Preview in game".
- [ ] **Emote wheel** (BLOCKED · AB §8.5). Needs the 8 clips (§6).
  - **Request for partner:** add Emote to StoreService's equip slots, plus a lobby-only phase check.
- [ ] **MEGA BOMB chip, lobby clock, Event Card** (BLOCKED · GDD §16, AB §7.6). The whole MEGA mode is P6 server work. The art (violet poster, Mega icon, chip) can be drawn ahead of it.
- [ ] **Moment of the Round card** (BLOCKED · GDD §10.5). **Request for partner:** a highlight buffer plus a replay payload.

## 3. HUD upgrades (all HOOKED; the data is sent)
- [x] Crossing chip: add the 8 fuse dots.
- [x] HUD Field Fuse bar: braided-fuse texture, steel gutter frame, hazard stripes at 5 s, and a particle spark at the burn point.
- [x] Team counter: Runner and Bomber icons, and a split-flap flip when a count changes.
- [x] Defuse chevron: a real chevron shape and art; today it's a text pill.
- [x] BUMP! arrow: chunky arrow art.
- [x] Carrier vignette: a radial edge texture with a hazard-stripe hint.
- [ ] Hot Streak flame: a 6-frame flipbook. Gift ring: a real progress ring (today it's dots).
- [x] UI sounds: add `UI.Hover` (with a MouseEnter hook) and `UI.Release`.

## 4. Icons (FREE · AB §6.4): 11 of ≈40 done, ≈24 to draw in `art/ui/make_icons.py`
- [x] Fuse · Spark · Crown · Trophy · Runner · Bomber · Inferno Crate · Gear · Lock · Arrow · Close · Plus · R$ price badge
- [x] Dash · Slide · Stop (needed for §1)
- [ ] Categories: Bomb Skin · Explosion · Spark · Trail · Victory · Title · Emote
- [ ] Mega (art can go ahead of the MEGA mode)

## 5. Cosmetics art (P5-07)
The store already lists these but hides them until their art exists (`Cosmetics.ready()`).
**Client wiring needed:** FxController and BombController don't read `Eq_Explosion`, `Eq_FuseSpark` or `Eq_Trail` yet, and there's no trail emitter. That's client work on our side, but it touches files the partner is editing, so pull first.
- [x] **Explosions (7)** AB §5.6: Confetti Cannon · Ink Splat · Firework Peony · Pixel Burst · Frost Nova · Black Hole · Champagne. All keep the same timing and the 7-stud ring. *(fallenbomb 2026-10-18: art + client wiring in; still to eyeball on screen: trail direction, pick-a-frame flipbooks, non-square sprites)*
- [x] **Fuse Sparks (7)** AB §8.1: Sparkler · Ember Drift · Electric · Pixie · Plasma · Gold Leaf · Insignia.
- [x] **Trails (8)** AB §8.2: Soot Streak · Paper Streamers · Spark Line · Rocket Exhaust · Comet · Neon Tube · Aurora · Victory Lap. No team colours.
- [x] **Victory Booms (5)** AB §8.3: Confetti Rain · Golden Fountain · Grand Finale · Dragon Dance · Champagne Tower.
- [ ] **Obsidian Crown** cosmetic (level 50, AB §8.6).

## 6. Animations (FREE to author with `tools/anim`; the user publishes them to the group)
- [x] **8 emotes** (AB §8.5): Wave · Fuse Dance · Juggle · Bow · Shrug · Victory Pose · Kaboom · Sit & Sip.
- [ ] Titan clips for the MEGA giant: TitanFall / Hit / Kneel / Rise / Roar / Slam exist but aren't published (only for P6).

## 7. VFX polish (AB §5)
- [ ] Defuse: a 6-frame steam-curl flipbook (today it reuses Smoke), and the clutch light-ray burst (FREE).
- [ ] Pass-arc ribbon trail (HOOKED).
- [ ] Tag-ready hand glow on Bombers (HOOKED).
- [ ] Bomber stun: spinning sparks and a soot face; reads `StunnedUntil` (HOOKED).
- [ ] Ragdoll soot overlay and smoke wisps (HOOKED).
- [ ] Bomb HOT smoke wisps; CRITICAL seam sprays and heat shimmer (verify first, then HOOKED).
- [ ] MEGA giant bomb and the violet STOMP ring (BLOCKED, P6).

## 8. Maps & world
- [ ] **Fireworks Yard: Blender hero props** (FREE · AB §4.4, P3-08). Every prop is built from parts today (0 MeshParts). Priority: firework crates (3 sizes) → hand-truck → floodlight → rocket bundle → sandbags → shutter → dock bumper. Then bunting sway. *(fallenbomb 2026-10-18: firework crate, hand-truck, pallet, gas bottle, floodlight, rocket bundle modelled and swapped in by builders/MapYardProps; sandbags, shutter, dock bumper still part-built)*
- [ ] Yard lighting: the bible's Golden Fuse is ClockTime 17.4, but MapYard sets 15.4. Pick one, and add a `Config.Lighting` preset table (FREE).
- [x] **The Depot lobby** (static art is FREE · AB §4.3, needs hero sign-off): spawn plaza, clock tower, shop kiosk, quest board, leaderboard wall + statue plinths, Fuse Range, VIP balcony. There's no lobby builder yet. *(fallenbomb 2026-10-18: builders/LobbyDepot, with the modelled crate stands + spin wheel)*
  - **Request for partner:** lobby spawn and teleport (`Characters.lobbyReady` only checks for `workspace.Lobby`), the leaderboard boards' data (`LeaderboardService.top()` exists), the Fuse Range dummies, and the clock tower timer once MEGA exists.
- [ ] Spring dummy prop (Fuse Range) (FREE art; needs partner code to work).
- [ ] Night Show lighting preset (BLOCKED until MEGA rounds).
- [ ] Clean up: `builders/README.md` and `src/shared/LobbyLayout.luau` are stale Chase Game leftovers.

## 9. Audio (AB §9.2): missing registry keys
The moment exists in game for all of these unless noted, so they can be added now:
- [x] `Bomb.Ignite` · `Bomb.Critical` (whine) · `Boom.Far` · `Fuse.Snuff` · `Bomb.Release` · `Bomb.Drop` · `Clutch.Choir` · `Field.Detonate` · `Crowd.Chant` · `Crowd.Groan` · `Stinger.Bombers` · `Stinger.BombersWin` · `UI.Hover` · `UI.Release`
- [ ] Replace these stand-ins with designed stacks:
  - Movement SFX from Chase Game (Dash, HardStop, Slide, Land, Footstep1-4)
  - Defuse and PassWhoosh (both the Dash whoosh repitched)
  - UiPress and CoinTick (bomb ticks pitched up)
  - UiDeny and Stamp (the clamp pitched down)
  - LevelUp (reuses WinSting), QuestDone (reuses Clutch), Claim (reuses Safe)
- [x] `Reward.Crate*` rattle / pop by rarity (with the crate opening).
- [ ] MEGA BOMB music theme (BLOCKED, P6).

## 10. Human-only (needs you in Studio or the Creator Dashboard)
- [ ] Save + publish the place (the bomb, skin folders and Yard live in the place file).
- [ ] Create the developer products and game passes, then paste their ids into `Config.Store`.
- [ ] Test on a real mid-range phone (P3-09).
