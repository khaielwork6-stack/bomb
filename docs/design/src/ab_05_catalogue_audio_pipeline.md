## 8. Launch cosmetic catalogue
Bomb skins are in §3.7 and explosions in §5.6. Every item passes the Quality Bar with its own review renders.

### 8.1 Fuse Sparks (8)
These change the fuse spark sprite and the overhead ring's spark. They never change the ring's stage colours.

| Spark | Rarity | Concept |
|---|---|---|
| Classic | Default | §5.2 |
| Sparkler | Common | A wedding-sparkler burst, long thin streaks |
| Ember Drift | Common | Lazy floating embers, a low-key glow |
| Electric | Rare | Blue-white arcs crackling around the tip |
| Pixie | Rare | A soft pastel glitter that trails |
| Plasma | Epic | A magenta plasma ball with orbiting motes |
| Gold Leaf | Legendary | Gold flakes that peel off and flutter down |
| Insignia | Exclusive (group perk) | The group colours, a star-shaped spark |

### 8.2 Trails (8)
These show on Dash, Slide and the Last Stand sprint. Ribbon Trails, 0.25 s lifetime, never in Runner cyan or Bomber red-orange.

| Trail | Rarity | Concept |
|---|---|---|
| Soot Streak | Common | Charcoal smoke ribbon |
| Paper Streamers | Common | Twisting confetti ribbons |
| Spark Line | Rare | A gold dotted spark line |
| Rocket Exhaust | Rare | A firework-rocket flame trail with sparkle |
| Comet | Epic | A star head with a dust tail |
| Neon Tube | Epic | Bent neon-sign glass, flickering |
| Aurora | Legendary | Layered aurora curtains |
| Victory Lap | Exclusive (level 30) | Chequered flag ribbons |

### 8.3 Victory Booms (6)
These play on your podium spot and when you win the Last Stand.

| Victory Boom | Rarity | Concept |
|---|---|---|
| Firework Volley | Default | Three peony shells over you |
| Confetti Rain | Common | Confetti cannons from both sides |
| Golden Fountain | Rare | Ground fountains of gold sparks |
| Grand Finale | Epic | A full skyline firework show (5 s) |
| Dragon Dance | Legendary | A paper dragon of sparks circling you |
| Champagne Tower | Exclusive (VIP) | Gold bubbles and foil |

### 8.4 Titles (20)
| Source | Titles |
|---|---|
| Level track | Fresh Fuse (starter) · Spark Plug · Short Fuse · Hot Potato · Pass Master · Fuse Whisperer · Demolitionist · Blast Radius · Living Legend · Big Bang |
| Achievements (stats) | Clutch King/Queen (100 clutches) · Revenge Served (100 revenge passes) · Chain Reaction (25 ×5 chains) · Last One Standing (10 Last Stand wins) · Unboomable (50 wins) |
| Events & special | Mega Bomber · Mega Survivor · Dethroner · Weekly Champion · VIP |

**Title plate:** the text is shown on a brass plate under the nametag. The plate's rarity frame follows the title's rarity.

### 8.5 Emotes (8, lobby and podium)
Wave · Fuse Dance · Juggle (juggling three mini bombs) · Bow · Shrug · Victory Pose · Kaboom (mimes an explosion) · Sit & Sip.

All emotes are animated with Chase Game's `tools/anim` baker pipeline (our own clips).

### 8.6 Level track (exclusives, every 5 levels)
| Level | Reward |
|---|---|
| 5 | Ember Drift spark |
| 10 | Copper Kettle skin (the earned variant: a bronze plate) |
| 15 | Title "Pass Master" |
| 20 | Spark Line trail |
| 25 | **Tempered** bomb skin (exclusive: blued steel with heat-tint rainbow bands) |
| 30 | Victory Lap trail |
| 40 | **Meteorite** bomb skin (exclusive) |
| 50 | **Obsidian Crown** title plus a crown cosmetic |

---

## 9. Audio
**Sources:** the Roblox licensed audio library (SFX and music), **layered and processed in-engine**:
- `SoundGroup`s with EQ, compression and reverb
- pitch randomisation
- multi-layer stacks

There are no AI-generated sounds or voices. Every key sound is a stack of 2–4 layers, so ours sounds like no other game.

### 9.1 Mix groups
| Group | Contents | Volume | Effects |
|---|---|---|---|
| Music | Round theme, lobby theme, stingers | 0.55 | Ducks −6 dB under Big callouts and booms near you |
| SFX.World | 3D sounds: bombs, booms, footsteps | 0.9 | A shared reverb send (yard) |
| SFX.Self | Your own bomb, heartbeat | 1.0 | No reverb, centred |
| UI | Buttons, rewards | 0.7 | Light compression |
| Crowd | The Last Stand crowd | 0.6 | Reverb |

### 9.2 Registry (`Assets.Sound.*`)
| Key | Moment | Layers (design) |
|---|---|---|
| `Bomb.Clamp` | A bomb sticks or is passed | A heavy metal clank + a spring "boing" tail + a leather slap |
| `Bomb.Ignite` | A fresh bomb lights | A match strike + a fuse catch whoosh |
| `Bomb.Tick` | Each tick | A wooden clock tick + a tiny metal ping (pitch steps by stage) |
| `Fuse.Hiss` | Loop while lit | A sparkler hiss, filtered; it gets brighter by stage |
| `Bomb.Critical` | The CRITICAL whine | A rising whistle + a kettle overtone |
| `Bomb.Whoosh` | Pass flight | A short air whoosh + a doppler |
| `Boom.Core` | Explosion | A punchy kick-transient + a cartoon boom body + a debris rattle + a long tail |
| `Boom.Far` | Distant explosion | A low-passed boom tail (more than 40 studs away) |
| `Fuse.Snuff` | Defuse | A steam hiss cut-off + a "pft" |
| `Bomb.Release` / `Bomb.Drop` | Defuse clamp, bomb on floor | A latch click / a heavy iron clunk + a roll |
| `Clutch.Choir` | Clutch Defuse | A choir "aah" hit + a gold shimmer |
| `Field.Klaxon` | Field Fuse at 5 s | A factory klaxon, 2 pulses |
| `Field.Detonate` | Field detonation | A rolling firecracker chain + a big low boom |
| `Heartbeat` | Carrier, synced | A low double-thump (SFX.Self) |
| `Crowd.Chant` / `Crowd.Cheer` / `Crowd.Groan` | Last Stand | Stadium crowd beds |
| `Stinger.Bombers` / `Stinger.Victory` / `Stinger.BombersWin` | Phase beats | Brass and percussion hits |
| `UI.Hover` / `Press` / `Release` / `Deny` | Buttons | Mechanical arcade switch clicks; deny = a muted buzz |
| `Reward.Coin` / `Reward.Level` / `Reward.Crate*` | Rewards | Coin chimes (pitch-up per coin), a level fanfare, crate rattle/pop by rarity |

### 9.3 Music
| Track | Use |
|---|---|
| Lobby theme | A relaxed, swung, upbeat tune (licensed library) |
| Round theme | Driving percussion. The escalation (GDD §10.1) is done with SoundGroup filters, a hi-hat layer, a drum cut and the heartbeat layer |
| MEGA BOMB theme | A heavier version for event rounds |
| Last Stand | The drumroll bed, plus the crowd |

---

## 10. Pipeline

### 10.1 Folder layout (new repo)
```
art/
  lib/            materials.py, shapes.py, kit.py (bevels, trims), render.py (turntables), export.py
  bomb/           build.py (the hero bomb), skins/<Skin>.py
  props/          one build.py per prop family
  vfx/            texture generators (flipbooks, sprites) + Blender sims rendered to sheets
  out/<Asset>/    FBX, .blend, textures (PNG), manifest.json, contact sheet
ui/
  icons/          SVG sources + exported PNG @2x
  textures/       panel grain, vignette, ring masks
audio/            layer recipes (JSON): which library sounds, pitch, gain, effects
```

### 10.2 Authoring rules
1. **Deterministic scripts.**
   - Every 3D asset is a Blender 4.5 Python build script, so it can be rebuilt and tweaked by parameters.
   - This is the same approach as Chase Game's `art3d` library, which proved that it works.
   - Run with `blender -b --python-exit-code 1 --python art/<path>/build.py`.
2. **Real modelling:**
   - Bevels on every hard edge, supporting loops and smooth shading.
   - Detail goes in the geometry where it affects the silhouette, and in the normal map where it doesn't.
3. **Textures are baked in Blender** from procedural materials into 1024² (hero) or 512² (props) PNG sets: colour, normal, roughness, metalness.
4. **Scale:** 1 Blender unit = 1 stud. Check against the 5-stud R6 reference figure in every render.
5. **Orientation:** export as Roblox −Z forward, +Y up. Pivots go where the gameplay needs them (the bomb's pivot is the clamp mount).

### 10.3 Review (the gate for "premium")
Every asset produces a **contact sheet**:
- the hero shot
- 8 turntable angles
- a material close-up
- a black silhouette
- the R6 scale view
- **for the bomb:** all 3 ticking stages, plus on-back views at 6, 25 and 60 studs

Rendered with Cycles under the three lighting presets.

**A hero asset doesn't move to integration until the user approves its sheet.**

### 10.4 Import to Roblox
| Asset type | Process |
|---|---|
| Meshes | Studio 3D Importer: Merge Meshes **off**, pivot to scene origin, Scale Unit = Studs; verify against `manifest.json` |
| Textures | SurfaceAppearance (ColorMap, NormalMap, RoughnessMap, MetalnessMap), uploaded to the group |
| UI images | Uploaded to the group; the ids go in `Assets.luau` |
| Animations | Chase Game's `tools/anim` baker; published to the group by the user |

**Everything is referenced only through `Shared/Assets.luau` keys.**

### 10.5 Naming
`<Category>.<Name>[.<Variant>]`, for example:
- `Bomb.ClassicIron`
- `Bomb.Skin.Delft`
- `Prop.Crate.Large`
- `Vfx.Fireball.Classic`
- `Icon.Star`
- `Sound.Boom.Core`

Code, manifests, review sheets and the store catalogue all use the same key.
