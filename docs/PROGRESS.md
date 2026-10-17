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
- [ ] P1-01 `Types.Phase` → the GDD §5.2 phases; `Config.Round`, `Config.Bomb`
- [ ] P1-02 RoundService state machine (§5) + ending conditions (§5.3) + mid-round joins as Bomber
- [ ] P1-03 ArenaService adaptation: Safe Strip soft walls (§6.1), Bomber band
- [ ] P1-04 `Logic/BombRules` (pure) + specs: eligibility, no-passback, receive grace, closest target, every §7.7 edge case
- [ ] P1-05 BombService: tag, pass, fuse, boom (Runner → Bomber, Bomber stun), splash, defuse (§7)
- [ ] P1-06 FieldFuseService: per-crossing fuse, warnings, field detonation (§6.2)
- [ ] P1-07 Last Stand (§8.2) + win conditions (§8.1)
- [ ] P1-08 Grey-box client: the bomb on backs (simple, but to the Quality Bar), fuse ring, HUD fuse, team counter
- [ ] P1-09 DoD: a full round end to end with 2+ players (Studio Team Test); specs pass

## P2 Bots · P3 Feel & hero assets · P4 Retention · P5 Store · P6 Event & launch
See GDD §26.1. Tasks get broken down at the start of each phase.
