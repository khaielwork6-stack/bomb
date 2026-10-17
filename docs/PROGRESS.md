# PROGRESS — FUSE VALLEY
Phase plan and Definitions of Done: GDD §26. Tick a task only when its DoD passes (CLAUDE.md).

## P0 Setup — "the foundations run"
- [x] P0-01 Repo skeleton (Rojo project, Rokit, StyLua, Selene, .gitignore) copied from Chase Game
- [x] P0-02 Transfer movement (MovementCore, MovementController, Input, Camera, Validator, Config.Movement); Spring ability and Dash Course stripped; Bombers get the full moveset (GDD §9.3)
- [x] P0-03 Extract the movement remotes from Chase's Combat into `MoveService`
- [x] P0-04 Transfer animations (Locomotion with self-heal, PoseController, FootstepController, `tools/anim` baker)
- [x] P0-05 Transfer plumbing (Net, Types, Util, ClientState, GameState, Participants, PlayerService, PositionHistory, DataService, AdminService, Settings, Sfx, Dev tools)
- [x] P0-06 Role rename Catcher → Bomber; FUSE VALLEY match stats; Config index trimmed (`tools/checkrequires.ps1` clean)
- [x] P0-07 Temporary map plumbing (Arena, MapKit/MapMeadow builders, Config.Maps = Meadow only) + P0 `Sandbox` service
- [x] P0-08 Place "FUSE VALLEY 💣" (placeId 80312213445237, group 3774675); `rojo serve --port 34873` from `Desktop\Fuse Valey`
- [x] P0-09 Meadow + Environment built in the place; default SpawnLocation removed (`CharacterAutoLoads` is now off in code). **Human: publish/save the place** so the map persists
- [x] P0-10 Studio check (2026-10-17): run 24, dash 48, slide 34.8 glide, hard stop + juke, strafe 20.4, backpedal 22.1 studs/s; Idle/Run/Strafe/Walk/Dash/Slide/HardStop/Brake clips all play; 0 script errors. Added `MoveFxController` (technique clips + sounds; Chase's FeedbackController didn't transfer)
- [x] P0-11 `Assets.luau` / `Net.luau` trimmed to the movement set; the Brave-boost popup listener removed
- [x] P0-12 GitHub: https://github.com/khaielwork6-stack/bomb

## P1 Core loop — "a playable round"
- [x] P1-01 `Types.Phase` → the GDD §5.2 phases; `Config.Round`, `Config.Bomb`
- [x] P1-02 RoundService state machine (§5) + ending conditions (§5.3) + mid-round joins as Bomber
- [x] P1-03 Arena adaptation: Safe Strip line walls (Bombers out, safe Runners in), `bomberBand`
- [x] P1-04 `Logic/BombRules` (pure) + 15 specs: eligibility, no-passback, receive grace, closest target, revenge, locked bombs on Bombers, every §7.7 edge case — **53/53 specs pass** (with the transferred MovementCore specs)
- [x] P1-05 BombService: tag, pass, fuse, boom (Runner → Bomber after 1.6 s, Bomber stunned 3 s), splash shove, defuse/clutch, leaver rules (§7)
- [x] P1-06 Field Fuse (in RoundService): per-crossing lengths, 5 s warning, detonation of everyone not in the destination strip, ALL CLEAR (§6.2)
- [x] P1-07 Last Stand (§8.2) + win conditions (§8.1): verified LastStand → Bombers win with MVP
- [x] P1-08 Client: the bomb on every Carrier's back (12-segment fuse that burns as the true time, LIT/HOT/CRITICAL lamps + glowing seams, sprung clamp, stick slam, pass arc), overhead fuse ring, FX (booms, defuse, field detonation, camera shake), round HUD (crossing chip, HUD fuse, team counter in the phone top-bar row, headlines, MOVE!, carrier vignette)
- [~] P1-09 DoD: full rounds verified end to end in Studio with 1 human + 9 Studio dummies (tag → pass → defuse → boom → get up as Bomber → field detonation → Last Stand → results), 0 script errors. **Pending: a 2-human Team Test** (needs a second person)

Studio test tools: `CG_Debug:Invoke("dummies", n)`, `"bomb", id, seconds`, `"role", id, Runner|Bomber`, `"tp", id, x, y, z, lookX, lookZ`, `"skip"`, `"state"`, `"cfg", Section, KEY, value`.

## P2 Bots — "a solo player gets a full round"
- [x] P2-01 `Config.Bots` (fill target, tiers, brain tuning, generated names)
- [x] P2-02 `Logic/BombBrain` (pure) + 9 specs: strip distances, defuse-vs-pass with margin, threat push, target spreading, start delays — **62/62 specs pass**
- [x] P2-03 `BotService`: fill to 16 at every INTERMISSION (trims for humans), real avatars from AvatarPool (generated names), MovementCore steering + Locomotion animation, techniques recorded and shown via ActionFx
- [x] P2-04 Brains: Runners (lanes, fuse-aware start delay, threat + Carrier avoidance, dodge dash / hard stop), Carriers (defuse when reachable with margin, else pass to the nearest — a Bomber when time is short), Bombers (intercept lead, spread across targets, keep clear of Carriers, dash to close)
- [x] P2-05 The Field Fuse scales with the map's length (`FUSE_REF_LENGTH = 140`)
- [~] P2-06 DoD soak (2026-10-17): 4 consecutive bot rounds (≈8 min, 14 crossings) — **0 errors**, memory flat/down (2306 → 1863 MB), bots made 278 tags / 267 passes / 65 defuses (21 clutch) / 172 booms; outcomes Bombers ×3, a bot Last Stand win ×1. The full 30-round soak (≈1 h of Studio time) is still to run.

## P3 Feel & hero assets · P4 Retention · P5 Store · P6 Event & launch
See GDD §26.1. Tasks get broken down at the start of each phase.
- [x] P3-02 Callouts: `CalloutService` detects every §11.1 moment on the server (TAGGED, PASS, CLOSE ONE, DEFUSED, CLUTCH DEFUSE, REVENGE PASS, REVENGE, BETRAYAL, CHAIN ×n, BOOM, DOUBLE/TRIPLE BOOM, SURVIVED, ALL CLEAR, LAST STAND) — its `Fired` signal is what P4 rewards pay from; `CalloutController` shows them in their Small / Medium / Big treatments (max 3 stacked)
- [~] P3-01 Hero bomb "The Tick": `art/bomb/build.py` (Blender 4.5, deterministic) → review contact sheet → **approved by the user 2026-10-17** → next: bake + FBX export, user imports, swap the part-built bomb
- [x] P3-03 The partner's premium UI kit (`UI/Skin`) ported and recoloured; every `Theme.panel` uses it
- [x] P3-04 Carrier toolkit (§10.2) and the Last Stand presentation (§8.2)
- [x] P3-05 Sound design (GDD §10.1): `AudioController` phase music, carrier muffle + heartbeat + paced tick, layered stacks; 30 licensed library sounds, all load. 2026-10-17: the user rejected the library tick; in-house escapement ticks (`art/audio/make_ticks.py`, tick/tock + CRITICAL pair) are wired with a fallback — **human: upload `art/out/Audio/bomb_*.wav`**, then fill `Assets.SFX.BombTick*`
- [x] P3-06 Explosion stack (Asset Bible §5) on in-house textures: `art/vfx/make_vfx.py` → 7 PNGs uploaded (`Assets.Vfx`) → `FxController` flash / fireball flipbook / ring / streaks / embers / smoke flipbook / scorch; verified in Studio 2026-10-17 (screens in-session), 0 script errors; + debris (4 iron shards cooling from white-hot, 2 brass rivets, kinematic bounce) and the detonation dust sheet + haze (2026-10-17)
- [ ] P3-07 Hero bomb in game: **human** imports `art/out/Bomb.ClassicIron/export/Bomb.ClassicIron.glb` (Studio → Import 3D) → move to `ReplicatedStorage.FV_Art.Bomb` → verify scale ≈2.2 studs, orientation, fuse segments
- [~] P3-08 Launch map first pass (Asset Bible §4.2): `builders/MapYard` built into `Workspace.Maps.Yard` (2 925 parts, Meadow parked in `ServerStorage.Maps`), Golden Fuse lighting (sun 22° over the near side), in-house yard textures, `YardController` (cord spark + lanes), bots steer round cover; verified in Studio 2026-10-17 (screens in-session, 64/64 specs, 0 errors). **Human: save + publish the place** (the map lives in the place file). Next pass: Blender hero props (crates, hand-truck, floodlights), debris, the dust sheet for the detonation
- [ ] P3-09 Performance: 60 FPS on a mid-range phone (particle counts at the field detonation, bomb texture sizes)
