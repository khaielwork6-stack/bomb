# Cosmetic VFX: textures and wiring recipes

Asset Bible §5.6 (explosions) and §8.1–8.3 (Fuse Sparks, Trails, Victory Booms). The item ids are the ones in
`src/shared/Config/Store.luau`.

The textures come from `art/vfx/make_cosmetics.py`, which writes them to `art/out/VfxCosmetics/`. They are procedural, made in-house, and use no AI or stock material. To rebuild them, run:

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --python-exit-code 1 --python art/vfx/make_cosmetics.py [-- boom spark trail victory]
```

The review sheets are the `_sheet_<category>.png` files in that folder. They show every texture on both a dark and a light background.

The ids come from two files:
- **Decal ids:** `ids.json`.
- **Image ids:** `image_ids.json`. These were resolved with `InsertService:LoadAsset(decal).Decal.Texture`. The image id is the one that goes in `ParticleEmitter.Texture`, `Trail.Texture`, `Decal.Texture` or `ImageLabel.Image`.

---

## 0. Conventions (they apply to every recipe below)

| Topic | Rule |
|---|---|
| Firing | The emitters are `Enabled = false` and are fired with `:Emit(n)` at the stack time `t` shown. "Rate" means the emitter is `Enabled` for that window. |
| Lighting | Every emitter uses `LightInfluence = 0`, so particles stay unlit and keep their baked colours under all three lighting presets. |
| Glow vs solid | **Glow textures** (sparks, fireworks, neon, plasma, bubbles) use `LightEmission = 1` (additive). **Solid, ink-outlined textures** (confetti, ink, ice, foil, pixel cubes, dragon) use `LightEmission = 0`. With additive blending the black Ink outline disappears, so a solid texture must never be additive. |
| Colour | Baked-colour textures use `Color = white`. Only the textures marked **tint** are greyscale or white and take their colour from `Color`. |
| Size notation | `Size 2→0` means `NumberSequence` keypoints {0: 2, 1: 0}. `Size 1.2–1.8` means one envelope value of 0.3 around 1.5 (`NumberSequenceKeypoint.new(t, 1.5, 0.3)`). Units are studs. |
| Animated flipbooks | `FlipbookLayout = Grid4x4` or `Grid2x2` and `FlipbookMode = OneShot`, so the animation plays exactly once over each particle's lifetime. Frames run left→right, then top→bottom. |
| Pick-a-frame sheets | These are the confetti, foil, streamers, pixie and gold-leaf sheets. Each particle should show one random frame and hold it. Set `FlipbookLayout = Grid4x4` or `Grid2x2`, `FlipbookMode = Loop`, `FlipbookStartRandom = true` and `FlipbookFramerate = NumberRange.new(0)`. The engine accepts a framerate of 0 (checked in Studio). That each particle then holds its random frame is expected but **not yet confirmed on screen**: check it on the first wire-up. If particles all show frame 1, use `FlipbookMode = Random` with `FlipbookFramerate = NumberRange.new(0.5)` instead. |
| Velocity-aligned sprites | `Orientation = VelocityParallel`. The texture's head is at the **top** (row 0), the same as the default `Assets.Vfx.Streak`. |
| Flat floor sprites | `Orientation = VelocityPerpendicular`, `EmissionDirection = Top`, `Speed = 0.01`, `Acceleration = 0`, `Rotation = 0–360`. The emitter sits 0.05 studs above the floor, so the sprite lies flat facing up. |
| Splash ring | Every explosion keeps the default 7-stud splash ring and its timing (GDD §10.4, Asset Bible §5.6). Keep the Classic `Assets.Vfx.Ring` shockwave layer exactly as specified in §5.1. Only its `Color` changes, as noted per item. |
| Budget | ≤ 220 particles at peak per explosion. The **light variant** (more than 3 booms at once) is listed per item. |

### Texture table

| Texture | Size, layout | Decal id | Image id |
|---|---|---|---|
| `boom_blackhole_ring` | 512², single | 96116746326350 | 74012319291455 |
| `boom_blackhole_swirl` | 1024², Grid4x4 animated | 139877847238279 | 94603259630119 |
| `boom_champagne_bubble` | 256², single | 74314695129114 | 108590224467995 |
| `boom_champagne_cork` | 512², single | 114866340245525 | 129835115080989 |
| `boom_champagne_foil` | 1024², Grid4x4 pick-a-frame | 103590356522599 | 71002971616390 |
| `boom_confetti_pieces` | 1024², Grid4x4 pick-a-frame | 94964872539722 | 133839444630040 |
| `boom_confetti_pop` | 512², single | 121553824813154 | 82657620827570 |
| `boom_confetti_streamers` | 1024², Grid2x2 pick-a-frame | 123473619594868 | 105584442191021 |
| `boom_frost_flake` | 128², single | 76438156646645 | 123713561910197 |
| `boom_frost_ring` | 512², single (floor) | 131210799875611 | 78947485137854 |
| `boom_frost_shard` | 256², single, head up | 86383010058218 | 132519090735861 |
| `boom_ink_droplet` | 128×256, head up | 120050392494961 | 104891357247999 |
| `boom_ink_floor` | 512², single (floor) | 106703861537846 | 95418496628336 |
| `boom_ink_splash` | 1024², Grid4x4 animated | 125683810468466 | 87563157479918 |
| `boom_peony_burst` | 1024², Grid4x4 animated | 78992661006219 | 97593159657535 |
| `boom_peony_star` | 128×512, head up | 135306903721532 | 140259328287920 |
| `boom_pixel_cube` | 256², single, **tint** (greyscale) | 77574098892025 | 121788670120094 |
| `boom_pixel_pop` | 1024², Grid4x4 animated | 77538552526564 | 88161556788368 |
| `boom_pixel_ring` | 512², single | 137785159095553 | 104871342390333 |
| `spark_electric_arc` | 512², Grid2x2 animated (4 frames) | 114131771786790 | 80319198992331 |
| `spark_ember_dot` | 128², single | 118248942223662 | 137985735661411 |
| `spark_goldleaf_flake` | 512², Grid2x2 (flutter cycle) | 73897630517998 | 91207548804801 |
| `spark_insignia_star` | 256², single | 84692219104967 | 134357421299771 |
| `spark_pixie_glitter` | 512², Grid2x2 pick-a-frame | 102703488109687 | 92659390708043 |
| `spark_plasma_ball` | 256², single | 123945136128972 | 88415554217520 |
| `spark_plasma_mote` | 128², single | 103943398776215 | 76944516231491 |
| `spark_sparkler_needle` | 64×256, head up | 130428981207004 | 82147137767204 |
| `spark_sparkler_star` | 256², single | 121358737247429 | 99709791689216 |
| `trail_aurora` | 512×64 strip | 119308178846318 | 86428051780259 |
| `trail_comet` | 512×64 strip | 76600782276794 | 127165983709043 |
| `trail_neon` | 512×64 strip | 103896733384757 | 94286118742332 |
| `trail_rocket` | 512×64 strip | 128905291693672 | 137794285575421 |
| `trail_soot` | 512×64 strip | 120787392850319 | 137718441351708 |
| `trail_sparkline` | 512×64 strip | 122280005296887 | 137470485399495 |
| `trail_streamers` | 512×64 strip | 111338329393043 | 110441562654784 |
| `trail_victorylap` | 512×64 strip | 128084491924327 | 94994531007321 |
| `victory_champagne_bubble` | 256², single | 127023501133611 | 97792458033497 |
| `victory_confetti_pieces` | 1024², Grid4x4 pick-a-frame | 93426391053547 | 138830246567560 |
| `victory_dragon_head` | 512², single | 82762269109022 | 132054825225172 |
| `victory_dragon_segment` | 256², single | 111543678556563 | 87910256914684 |
| `victory_finale_peony` | 1024², Grid4x4 animated | 91653377162604 | 130318736066398 |
| `victory_fountain_glint` | 256², single | 121223254550465 | 107499627113011 |
| `victory_fountain_spark` | 128×512, head up | 106058467154851 | 94714427761399 |

**For the scripter:** add an `Assets.VfxCosmetic` block next to `Assets.Vfx`, keyed by texture name, with values `"rbxassetid://<Image id>"`. This file doesn't edit `src/`.

---

## 1. Explosions (`Boom_*`)

Every explosion keeps the Classic pre-swell (0.00), the PointLight flash (0.08) and the shockwave ring (0.08). The tables list what **replaces** the Classic flash sprite, fireball, sparks, smoke, soot and embers. The debris meshes stay unless a row says otherwise.

### Boom_Confetti — Confetti Cannon (Common)

Textures: `boom_confetti_pop`, `boom_confetti_pieces`, `boom_confetti_streamers`. Ring tint: `#FF5CA8`. PointLight colour: `#FFD84A`.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.08 | Party pop (replaces the flash) | `confetti_pop` | 1 | 8→10 | 0.14 | 0 | `LightEmission 0`, `Rotation` −15 to 15, `Transparency 0→0` until 0.7, then →1 |
| 0.08 | Confetti burst (replaces the fireball and sparks) | `confetti_pieces`, pick-a-frame | 70 | 0.7–1.0 | 1.6–2.2 | 30–48, `SpreadAngle` 70 upward cone, `Acceleration (0,-30,0)`, `Drag 3` | `RotSpeed` −360 to 360, `Rotation` 0–360, `LightEmission 0` |
| 0.10 | Streamers | `confetti_streamers`, pick-a-frame (2x2) | 10 | 2.2–2.8 | 1.8 | 22–32, upward cone 50, `Acceleration (0,-18,0)`, `Drag 2.5` | `RotSpeed` −120 to 120 |
| 0.15 | Smoke | Classic `Assets.Vfx.Smoke` | 4 | 5→7 | 0.9 | Classic | `Color #FFF3E2` (paper puff) |
| 0.15 | Soot decal | Classic `Assets.Vfx.Scorch` | 1 | Classic | Classic | | `Transparency` 0.4 (lighter scorch) |

- Peak: about 90 particles.
- Light variant: the pop, 20 pieces and 2 streamers.
- Debris: drop the iron shards and keep the 2 rivets.

### Boom_InkSplat — Ink Splat (Rare)

Textures: `boom_ink_splash`, `boom_ink_droplet`, `boom_ink_floor`. Ring tint: `#16121C` at 50 % (Transparency 0.5). PointLight: brightness 3, colour `#FFF3E2`.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.08 | Splash (replaces the flash and fireball) | `ink_splash`, Grid4x4 OneShot | 2 | 7.5–8.5 | 0.55 | 0 | `Rotation` 0–360, `LightEmission 0`, `ZOffset 1` |
| 0.10 | Flung droplets (replace the sparks) | `ink_droplet`, VelocityParallel | 20 | 0.5→0.25 (height doubles automatically from the 1:2 texture) | 0.5–0.7 | 30–50, sphere, `Acceleration (0,-60,0)`, `Drag 2` | `LightEmission 0` |
| 0.15 | Floor splat (replaces the soot) | `ink_floor`, flat floor sprite | 1 | 9 | 6 | 0.01 | `Transparency {0:0, 0.8:0, 1:1}`, `LightEmission 0` |

- Smoke and embers: none. The ink is the whole read.
- Peak: about 25 particles.
- Light variant: the splash ×1 and 8 droplets.

### Boom_Peony — Firework Peony (Rare)

Textures: `boom_peony_burst`, `boom_peony_star`. Ring tint: `#B04CFF`. PointLight colour: `#E83CFF`, range 30.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.08 | Flash | Classic `Assets.Vfx.Flash` | 1 | 9→0 | 0.06 | | `Color #FFD84A` |
| 0.08 | Burst (replaces the fireball) | `peony_burst`, Grid4x4 OneShot | 1 | 11–12 | 0.9 | 0 | `LightEmission 1`, `Brightness 1.5`, `ZOffset 1` |
| 0.10 | Trailing stars (replace the sparks) | `peony_star`, VelocityParallel | 26 | 0.9→0.4 | 0.6–0.9 | 34–50, sphere, `Drag 4`, `Acceleration (0,-12,0)` | `LightEmission 1` |
| 0.30 | Twinkle embers | Classic `Assets.Vfx.Ember` | 14 | 0.35 | 1.2 | 2–4, `Acceleration (0,-4,0)` | `Color #FFD84A → #E83CFF`, `Transparency` flickering {0:0, 0.3:0.6, 0.5:0, 0.8:0.7, 1:1} |
| 0.15 | Smoke | Classic | 3 | 6→8 | 1.0 | Classic | `Color #3B3447` (night-sky smoke) |

- Peak: about 45 particles.
- Light variant: the burst and 8 stars.

### Boom_Pixel — Pixel Burst (Epic)

Textures: `boom_pixel_pop`, `boom_pixel_cube` (**tint**), `boom_pixel_ring`. Ring: use `boom_pixel_ring` as the **air ring** billboard, and keep the Classic floor ring tinted `#FFD84A`.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.08 | 8-bit pop (replaces the flash and fireball) | `pixel_pop`, Grid4x4 OneShot | 1 | 9 | 0.5 | 0 | `LightEmission 0`, `Rotation 0` (keep it axis-aligned: pixel art), `ZOffset 1` |
| 0.08 | Air ring | `pixel_ring` | 1 | 2→10 | 0.25 | 0 | `Transparency {0:0, 0.7:0, 1:1}`, `LightEmission 0` |
| 0.10 | Voxel cubes (replace the sparks and debris) | `pixel_cube` | 4 emitters × 9 | 0.9–1.3 | 0.7–1.0 | 28–44, sphere, `Acceleration (0,-50,0)`, `Drag 1.5` | One emitter per colour: `#FFD84A`, `#3BE48C`, `#B04CFF`, `#FF5CA8`. `Rotation 0`, `RotSpeed 0`. Blink out with `Transparency {0:0, 0.6:0, 0.65:1, 0.72:0, 0.8:1, 0.86:0, 1:1}` |
| 0.15 | Soot | Classic scorch | 1 | | | | unchanged |

- Peak: about 40 particles.
- Light variant: the pop and 12 cubes (3 per colour).

### Boom_Frost — Frost Nova (Epic)

Textures: `boom_frost_shard`, `boom_frost_ring`, `boom_frost_flake`. Ring tint: `#BFDDFF`. PointLight colour: `#BFDDFF`.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.08 | Flash | Classic Flash | 1 | 9→0 | 0.06 | | `Color #F4FBFF` |
| 0.08 | Shard burst (replaces the fireball and sparks) | `frost_shard`, VelocityParallel | 18 | 1.4→1.0 | 0.45–0.6 | 36–56, sphere (Y ≥ 0 bias via SpreadAngle 80 upward), `Drag 5`, `Acceleration (0,-20,0)` | `LightEmission 0` |
| 0.10 | Snow flakes | `frost_flake` | 16 | 0.5–0.8 | 1.2–1.6 | 6–12, sphere, `Acceleration (0,-3,0)`, `Drag 1` | `RotSpeed` −90 to 90, `LightEmission 0.3` |
| 0.15 | Frozen floor (replaces the soot) | `frost_ring`, flat floor sprite | 1 | 12 at t 0 → 14 at t 0.1, then held | 2.5 | 0.01 | `Transparency {0:0, 0.7:0, 1:1}`. This is the decal that "freezes the floor briefly" |
| 0.15 | Cold mist | Classic Smoke | 4 | 5→7 | 1.0 | Classic | `Color #DDEBFF` |

- Peak: about 40 particles.
- Light variant: the frozen floor, 8 shards and 4 flakes.

### Boom_BlackHole — Black Hole (Legendary)

Textures: `boom_blackhole_swirl`, `boom_blackhole_ring`. Ring tint: `#A65BFF`. The timing is the one exception, as specified: a 0.15 s implosion, then the pop.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.00 | Implosion swirl (runs during the pre-swell) | `blackhole_swirl`, Grid4x4 OneShot | 1 | 9→3 | 0.2 | 0 | `RotSpeed −360`, `LightEmission 0` (the dark core must stay dark), `ZOffset 1` |
| 0.00 | Suck-in streaks | Classic `Assets.Vfx.Streak`, VelocityParallel | 20 | 0.5 | 0.15 | emitted on a shell (`Shape = Sphere`, `ShapeStyle = Surface`, radius 6), `ShapeInOut = Inward`, speed 40 | `Color #CDB8FF`, `LightEmission 1` |
| 0.15 | Violet pop flash | Classic Flash | 1 | 10→0 | 0.08 | | `Color #E83CFF`, PointLight `#B04CFF` |
| 0.15 | Lensing ring | `blackhole_ring` | 1 | 3→12 | 0.45 | 0 | `Transparency {0:0, 0.6:0.1, 1:1}`, `LightEmission 0` |
| 0.17 | Scatter | Classic Streak | 16 | 0.6→0.2 | 0.35 | 40–60, sphere | `Color #E83CFF → #B04CFF`, `LightEmission 1` |
| 0.20 | Soot | Classic scorch | 1 | | | | `Color #241D2E` |

- Peak: about 40 particles.
- Light variant: the swirl, the ring and the pop.

### Boom_Champagne — Champagne (Exclusive, VIP)

Textures: `boom_champagne_cork`, `boom_champagne_foil`, `boom_champagne_bubble`. Ring tint: `#F2B13A`. PointLight colour: `#FFE9A6`.

| t | Layer | Texture | Count | Size | Lifetime | Speed, motion | Notes |
|---|---|---|---|---|---|---|---|
| 0.08 | Cork pop flash (replaces the flash and fireball) | `champagne_cork` | 1 | 7→10 | 0.16 | 0 | `LightEmission 1`, `Transparency {0:0, 0.5:0, 1:1}` |
| 0.10 | Gold foil confetti | `champagne_foil`, pick-a-frame | 60 | 0.6–0.9 | 1.6–2.2 | 28–44, upward cone 65, `Acceleration (0,-26,0)`, `Drag 3` | `RotSpeed` −400 to 400, `LightEmission 0` (the foil's spec bands do the shine) |
| 0.12 | Bubble fizz | `champagne_bubble` | 30 | 0.3–0.6 | 1.2–1.8 | 4–9 upward, `Acceleration (0,6,0)`, `Drag 1.5` | `LightEmission 0.6`, `Transparency {0:0.1, 0.8:0.2, 1:1}` |
| 0.30 | Gold embers | Classic Ember | 10 | 0.3 | 1.4 | Classic | `Color #F2B13A` |

- Smoke: none. The soot decal is replaced by nothing (a celebration, not a scorch).
- Peak: about 100 particles.
- Light variant: the pop, 18 foil and 8 bubbles.

---

## 2. Fuse Sparks (`Spark_*`)

These follow the Classic spark spec (§5.2), with one change per spark: the **core sprite** emitter at the fuse tip, plus a **shed** emitter.

| Attribute | Value (unless a row says otherwise) |
|---|---|
| Core sprite | `Rate 30`, `Lifetime 0.08`, `Speed 0`, `LockedToPart = true`, size flickering 0.3–0.45 |
| CRITICAL stage | The shed rate ×3, and a sputter `Emit(6)` of the shed every 0.2 s |
| PointLight | Range 4. The colour is given per spark |
| Overhead fuse ring spark | Use the same texture as the core, in an `ImageLabel`. For Grid2x2 textures, show frame 1 (`ImageRectSize = 256²`). Never change the ring's stage colours |

| Spark | Core | Shed emitter | Light |
|---|---|---|---|
| **Spark_Sparkler** | `spark_sparkler_star`, size 0.45–0.6, `RotSpeed` random −720 to 720, `LightEmission 1` | `spark_sparkler_needle`, VelocityParallel, `Rate 18`, `Lifetime 0.25–0.4`, `Speed 8–14`, `SpreadAngle 180`, `Acceleration (0,-25,0)`, `Size 0.35→0.1`, `LightEmission 1` | `#FFD84A` |
| **Spark_EmberDrift** | `spark_ember_dot`, size 0.35–0.45, `LightEmission 1` | `spark_ember_dot`, `Rate 4`, `Lifetime 1.4–2.0`, `Speed 0.5–1.5`, `Acceleration (0,1.5,0)` (drifts up), `Size 0.22→0.05`, `Transparency {0:0, 0.7:0.3, 1:1}`, `LightEmission 1` | `#FF9442`, brightness 0.6 (low-key) |
| **Spark_Electric** | `spark_electric_arc`, Grid2x2, `FlipbookMode Loop`, `FlipbookFramerate 24`, `FlipbookStartRandom true`, size 0.55–0.7, `Rotation 0–360`, `LightEmission 1` | Same texture, `Rate 5`, `Lifetime 0.08`, `Size 0.8–1.0`, `Speed 0`, Rotation random (crackle bursts around the tip) | `#8FB4FF`, flickered by script (brightness 1 ↔ 2.5 every 0.05 s) |
| **Spark_Pixie** | `spark_pixie_glitter`, pick-a-frame (Grid2x2), size 0.4–0.55, `RotSpeed` −90 to 90, `LightEmission 1` | Same texture, pick-a-frame, `Rate 10`, `Lifetime 0.6–0.9`, `Speed 0.5–1`, `Acceleration (0,-1.5,0)`, `Size 0.3→0`, `LockedToPart = false` (it trails behind as the Carrier runs), `LightEmission 1` | `#FFB3DA` |
| **Spark_Plasma** | `spark_plasma_ball`, size 0.45–0.55, `RotSpeed 180`, `LightEmission 1` | `spark_plasma_mote`: 3 motes orbiting the tip, script-driven Attachments on a 0.6-stud circle at 2 rev/s with a ±0.15 bob, each with a 1-particle `Rate 30`, `Lifetime 0.1` emitter of size 0.18. Plus a shed of motes at `Rate 6`, `Lifetime 0.4`, `Speed 2–4`, `Size 0.15→0` | `#E83CFF` |
| **Spark_GoldLeaf** | The Classic `Assets.Vfx.Flash` tinted `#FFE9A6`, size 0.35–0.45, `LightEmission 1` (the flakes are the signature) | `spark_goldleaf_flake`, Grid2x2, `FlipbookMode Loop`, `FlipbookFramerate 6–10`, `FlipbookStartRandom true` (the 4 frames are a flutter cycle), `Rate 5`, `Lifetime 1.6–2.2`, `Speed 1–2`, `Acceleration (0,-2.5,0)`, `Drag 1.2`, `Size 0.3–0.4`, `RotSpeed` −60 to 60, `LightEmission 0` | `#F2B13A` |
| **Spark_Insignia** | `spark_insignia_star`, size 0.45–0.55, `RotSpeed 90`, `LightEmission 0` (it is ink-outlined) | The Classic streak tinted `#FFD84A → #FF6A1F`, `Rate 8`, the Classic shed spec | `#FF6A1F` |

---

## 3. Trails (`Trail_*`)

The trails show on Dash, Slide and the Last Stand sprint (§8.2).

**Trail settings shared by all eight:**

| Property | Value |
|---|---|
| `Attachment0` / `Attachment1` | On the HumanoidRootPart at (0, −0.8, 0.4) and (0, 0.8, 0.4) (1.6 studs apart, vertical) |
| `TextureMode` | `Stretch` |
| `Lifetime` | 0.25 |
| `MinLength` | 0.05 |
| `FaceCamera` | `true` |
| `LightInfluence` | 0 |
| `Color` | white (baked) |
| `Transparency` | {0: 0, 1: 0.35}. The texture already fades to the tail |
| `WidthScale` | {0: 1, 1: 0.6} unless the trail's row says otherwise |

**Strip orientation:** the attachment (head) end is drawn on the strip's **left** side, and the tail fades out on the right. **Verify the direction on the first wire-up.** If Roblox maps it reversed, the generator can mirror all eight strips with a one-line change.

| Trail | Texture | LightEmission | Extra |
|---|---|---|---|
| **Trail_Soot** | `trail_soot` | 0 | `WidthScale {0:0.9, 1:1.3}` (the smoke billows out) |
| **Trail_Streamers** | `trail_streamers` | 0 | |
| **Trail_SparkLine** | `trail_sparkline` | 1 | `WidthScale {0:0.7, 1:0.5}` |
| **Trail_Rocket** | `trail_rocket` | 0.6 | `WidthScale {0:1, 1:0.8}` |
| **Trail_Comet** | `trail_comet` | 1 | `WidthScale {0:1.1, 1:0.5}` |
| **Trail_Neon** | `trail_neon` | 1 | Flicker by script while the trail is active: every 0.06–0.18 s, set `Transparency` to {0:0, 1:0.35} or (one time in six) {0:0.6, 1:0.8} |
| **Trail_Aurora** | `trail_aurora` | 1 | `Transparency {0:0.05, 1:0.45}`, `WidthScale {0:1.2, 1:1.4}` |
| **Trail_VictoryLap** | `trail_victorylap` | 0 | |

None of the trails uses Runner cyan or Bomber red-orange as its dominant colour:

| Trail | Dominant colours |
|---|---|
| Soot | Charcoal |
| Streamers | Violet, green and yellow |
| SparkLine | Gold |
| Rocket | White and yellow; orange only at the flame rim |
| Comet | Gold and lavender |
| Neon | Magenta |
| Aurora | Green and violet |
| VictoryLap | Ink, Paper and gold |

---

## 4. Victory Booms (`Victory_*`)

These play on the podium spot, or on the Last Stand winner (§8.3). The duration is about 4 s unless stated. They are not bound by the explosion budget, but each stays at ≤ 250 particles at peak.

### Victory_Confetti — Confetti Rain (Common)

Two cannons, 6 studs either side of the player, 1 stud up, each aimed 35° inward and 60° up.

| Layer | Spec |
|---|---|
| Volleys | Each cannon fires 3 volleys (t 0, 0.6, 1.2 s) of `victory_confetti_pieces` (pick-a-frame): `Emit(40)`, Size 0.8–1.2, Lifetime 2.6–3.4, Speed 40–55, `SpreadAngle 18`, `Acceleration (0,-20,0)`, `Drag 2.2`, `RotSpeed` −360 to 360, `LightEmission 0` |
| Muzzle | `boom_confetti_streamers`, `Emit(4)` at each volley: Size 2.5, Lifetime 2, the same speeds |

### Victory_Fountain — Golden Fountain (Rare)

Four ground fountains at the corners of a 6-stud square around the player. Each runs for 4 s.

| Layer | Spec |
|---|---|
| Spray | `victory_fountain_spark`, VelocityParallel, `Rate 45`, Lifetime 0.9–1.2, Speed 26–34, `SpreadAngle 12` (straight up), `Acceleration (0,-38,0)`, `Size 0.9→0.5`, `LightEmission 1` |
| Glints | `victory_fountain_glint`, `Rate 10`, Lifetime 0.4, Speed 20–30, the same cone and gravity, Size 0.6–0.9, `RotSpeed 180`, `LightEmission 1` |
| Light | One PointLight per fountain: `#F2B13A`, range 10, brightness 2 |

### Victory_Finale — Grand Finale (Epic, 5 s)

Shells launch from behind the player at a 4–10-stud spread, 18–26 studs up, on a script timeline.

| Element | Spec |
|---|---|
| Shells | 9 shells at t = 0, 0.4, 0.8, 1.3, 1.7, 2.2, 2.8, 3.3 and 3.6 s, then the finale triple at 4.1 s |
| Rise | The Classic streak, VelocityParallel, `Emit(1)`, speed 45, lifetime 0.45, `Color #FFE9A6` |
| Burst | `victory_finale_peony` (Grid4x4 OneShot), `Emit(1)`, size 16–20, lifetime 1.1, `LightEmission 1`, `Brightness 1.6` |
| Trailing stars | Half the shells add `boom_peony_star` ×16, speed 30–40, lifetime 0.8 |
| Light | PointLight flash per shell: range 40, 0.2 s |

### Victory_Dragon — Dragon Dance (Legendary)

**Structure:**
- The dragon is a head plus 9 body segments, each a `BillboardGui` (`AlwaysOnTop = false`, `LightInfluence = 0`) on its own Attachment.
- The head is `victory_dragon_head` at 3.6×3.6 studs.
- Each segment is `victory_dragon_segment`, shrinking from 2.4 studs (nearest the head) to 1.4 studs (the last).
- Draw order: head on top, then the segments in order.

**Motion (script-driven):**
- The head circles the player at radius 5 studs, at a height of 3 + 0.8·sin(2πt·1.2) studs, at 0.45 revolutions per second.
- Segment *k* follows the same path, delayed by k·0.11 s.

**Sparks on each segment:**

| Emitter | Spec |
|---|---|
| Glints | `victory_fountain_glint`, `Rate 5`, Lifetime 0.5, Speed 1–2, Size 0.4–0.6, `LightEmission 1` |
| Embers | `spark_ember_dot`, `Rate 8`, Lifetime 0.8, `Acceleration (0,-4,0)`, Size 0.2→0, `LightEmission 1` |

**Timing:** the dragon flies for 4.5 s, then the head shoots up 12 studs over 0.4 s and pops in a `victory_finale_peony` burst (size 14).

### Victory_ChampagneTower — Champagne Tower (Exclusive, VIP)

| Layer | Spec |
|---|---|
| Bubble column | Around the player (a cylinder shape of radius 3, at the feet): `victory_champagne_bubble`, `Rate 40` for 4 s, Lifetime 2–2.8, Speed 5–8 up, `Acceleration (0,3,0)`, `Size 0.5–1.1` (envelope), `Transparency {0:0.2, 0.85:0.1, 1:1}`, `LightEmission 0.5` |
| Foil bursts | At t = 0, 1.5 and 3 s, from 7 studs above the player: `boom_champagne_foil` (pick-a-frame), `Emit(45)`, Size 0.7–1.0, Lifetime 2.5, Speed 18–28 in a sphere, `Acceleration (0,-14,0)`, `Drag 2.5`, `RotSpeed` −400 to 400 |
| Pop | `boom_champagne_cork`, size 6, with each foil burst |
| Light | PointLight `#FFE9A6`, range 14 |
