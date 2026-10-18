# FUSE VALLEY — Asset Bible

**Version 1.0 · 2026-10-17 · Companion to the Master GDD**

> Every model, texture, effect, sound and screen in FUSE VALLEY is specified here. The user's standard is the rule this document enforces: **"EVERY ASSET, EVEN THE BOMB, HAS TO BE EXTREMELY RICH, PREMIUM AND HIGH QUALITY. ABSOLUTELY ZERO AI SLOP."**

### 0.1 Document map
| § | Section |
|---|---|
| 1 | The Quality Bar (read before making anything) |
| 2 | Art direction: "Arcade Pyrotechnic" |
| 3 | The Bomb (hero asset) and its skins |
| 4 | World: maps, lobby, props, lighting |
| 5 | VFX: explosions, fuses, defuses, feedback |
| 6 | UI: system, HUD components, callouts, icons, motion |
| 7 | Screens & sequences |
| 8 | Launch cosmetic catalogue |
| 9 | Audio |
| 10 | Pipeline: authoring, review, import, naming |

---

## 1. The Quality Bar

### 1.1 What "premium" means here
An asset is premium when **someone who has never seen the game could screenshot it, and the screenshot would sell the game.** In practice, every asset has all of these:
1. **Intent:** it was designed for this game, for a specific moment, by a decision someone can explain.
2. **A strong silhouette:** it reads as itself in pure black at 40 px tall.
3. **Material truth:** iron looks like iron, brass like brass, ceramic like ceramic. Surfaces have wear, edges catch light, and nothing is flat plastic by default.
4. **Three reads:** it works far away (shape and colour), mid-range (main details) and close up (fine detail, wear, texture).
5. **Life:** it moves, reacts or responds. The bomb breathes, buttons squash, numbers count, lights pulse.
6. **Sound pairing:** anything that moves or changes state has a matching sound designed for it.
7. **Consistency:** it uses the palette, materials, lighting and motion rules of §2. One asset done "differently" breaks the whole look.

### 1.2 Banned ("AI slop" and its cousins)
| Never | Why | Instead |
|---|---|---|
| **AI-generated images, textures, icons, 3D or audio**, as finals *or* placeholders | Generic, inconsistent, and players spot it instantly | Hand-authored procedural Blender scripts, hand-drawn vectors, the licensed Roblox audio library, layered and processed |
| **Toolbox or free models** | Wrong style, unknown scripts, other people's work | Our own models (§10) |
| **Default `SmoothPlastic` everywhere on hero assets** | Reads as unfinished | PBR `SurfaceAppearance` (colour, normal, roughness, metalness maps) |
| **Emoji as icons** | Inconsistent across platforms; looks cheap | The custom icon set (§6.4) |
| **Generic two-stop gradients as decoration**, glassmorphism, frosted panels | The "template UI" look | The panel system in §6.2: solid layered fills, bevel highlight, crisp ink outline |
| **Default fonts** (Arial, SourceSans, Gotham as display) | Looks like a default game | The type scale in §2.6 |
| **"Coming soon" tiles**, lorem ipsum, placeholder text, dead buttons | Broken promise | Ship fewer items, all finished |
| **Static pop-in UI** | Feels dead | Every appear, press and change is animated (§6.5) |
| **Unmatched stock sounds** (one generic "click" for everything) | No identity | A designed sound for each action (§9) |
| **Stretched, blurry or upscaled textures** | Looks cheap on retina phones | Authored at 2× display size, power-of-two |
| **Particle soup** (huge counts, no shape) | Noisy and slow | Designed stacks with timing (§5); budgets in GDD §24.2 |

### 1.3 The checklist — every asset passes before it ships
| # | Check | How |
|---|---|---|
| 1 | Designed for a named moment in the GDD | Cite the GDD feature ID in the asset manifest |
| 2 | Silhouette test | A black fill render at 40 px tall is recognisable |
| 3 | Three-distance test | In-game captures at 6, 25 and 60 studs |
| 4 | Phone test | A 844×390 Studio emulator capture; detail and text legible |
| 5 | Palette | Only §2.3 tokens or their documented tints |
| 6 | Materials | PBR maps present; roughness varies across the surface (no uniform values) |
| 7 | Wear and imperfection | Edge wear, soot, scuffs or hand-made irregularity where the material would have it |
| 8 | Lighting | Checked under all 3 lighting presets (§4.4) |
| 9 | Motion | Idle or response animation defined and implemented |
| 10 | Sound | A paired sound exists and is mixed (§9) |
| 11 | Budgets | Tris, parts, textures and particles within GDD §24.2 |
| 12 | Readability rules | GDD §10.4 holds (team colours, fuse truth, silhouette) |
| 13 | Review renders | A turntable contact sheet in `art/out/<Asset>/` |
| 14 | Hero sign-off | The bomb, the explosion, the logo, the lobby and the launch map need the **user's explicit approval** |

**An asset that fails any check does not ship**, not even as a placeholder. A placeholder is a *simpler* version of the final asset that passes this checklist, **never** a lower-quality one.

---

## 2. Art direction: "Arcade Pyrotechnic"

### 2.1 One sentence
**A hand-crafted fireworks workshop at golden hour:** warm iron, polished brass, glazed ceramic and braided fuse cord, lit by sparks. It's stylised and chunky like a premium arcade game, but every surface is made of a real material.

### 2.2 Pillars
| Pillar | Means | Doesn't mean |
|---|---|---|
| **Chunky & readable** | Big, simple primary shapes. 60 % big forms, 30 % medium, 10 % small detail. Rounded bevels everywhere (no razor edges). | Low effort or low detail |
| **Material-rich** | Iron, brass, copper, ceramic, painted wood, canvas, rope, glass: each with PBR maps and wear | Realism. Proportions stay stylised |
| **Warm vs cool** | Warm light from fire and sparks against cool dusk shadows. The bomb is always the warmest, brightest thing near it | Muddy all-orange scenes |
| **Crafted, not manufactured** | Rivets, stitching, stencils, hand-painted signage, chalk marks, tool marks | Sterile "clean 3D" |
| **Pyro joy** | Explosions are celebrations: colourful, shaped, satisfying | Violence, gore, grim realism |

### 2.3 Palette (tokens) — `Theme.Palette`
| Token | Hex | Use |
|---|---|---|
| `Ink` | `#16121C` | Outlines, darkest UI, text on light |
| `Ink2` | `#241D2E` | Panels (dark) |
| `Smoke` | `#3B3447` | Panel bevels, disabled |
| `Ash` | `#8C8498` | Secondary text |
| `Paper` | `#FFF3E2` | Light panels, body text on dark |
| `Fuse` | `#FF6A1F` | **Brand primary**: logo, primary buttons, fuse |
| `Ember` | `#FF9442` | Highlights on Fuse |
| `Spark` | `#FFD84A` | Sparks, rewards, Stars |
| `Gold` | `#F2B13A` | Premium, VIP, Legendary |
| `Detonate` | `#E8322B` | Danger, the CRITICAL stage, boom |
| `Runner` | `#2FD3FF` | **Reserved:** the Runner team |
| `Bomber` | `#FF4A2E` | **Reserved:** the Bomber team |
| `Safe` | `#3BE48C` | Safe Strips, success, defuse |
| `Mega` | `#B04CFF` | The MEGA BOMB event |
| `Iron` | `#2E2C33` | Bomb body base |
| `Brass` | `#C9973F` | Bands, trims |
| `Porcelain` | `#F4EFE6` | Fuse socket, ceramic |

Rarity frames: Common `#A9B1C2` · Rare `#33B6FF` · Epic `#A65BFF` · Legendary `#FFB627` · Exclusive: obsidian `#1E1A24` with an iridescent foil texture.

### 2.4 Materials library (`art/lib/materials.py` → SurfaceAppearance sets)
| Material | Colour | Roughness | Metal | Signature detail |
|---|---|---|---|---|
| Cast iron | `Iron` with 6 % hue noise | 0.55–0.8 | 0.85 | Hammered dimples (normal), soot gradient toward the top, polished wear on the equator |
| Brass | `Brass` | 0.25–0.45 | 1.0 | Edge brightening, fingerprint smudges (roughness), darker patina in recesses |
| Copper | `#B8643A` | 0.3–0.5 | 1.0 | A verdigris tint in crevices |
| Glazed porcelain | `Porcelain` | 0.08–0.15 | 0 | Crackle-glaze normal, a slight blue cast in the glaze pools |
| Braided cord | `#D9B98A` → charred `#2A1F1A` | 0.85 | 0 | A real braid pattern in normal and colour; charring along the burn |
| Painted steel | Any token | 0.4–0.6 | 0.3 | Chipped paint at edges showing the metal under it |
| Canvas & leather | `#6B4A32` | 0.7–0.9 | 0 | Stitching, stretch creases |
| Glass lens | Tinted | 0.05 | 0 | An inner emissive element (a Neon sub-part) |

Texture size: **1024²** for hero assets (the bomb, the lobby centrepiece), **512²** for props, and trim sheets for architecture.

### 2.5 Lighting presets (`Config.Lighting`)
| Preset | Use | Setup |
|---|---|---|
| **Golden Fuse** (default) | Maps and lobby | Future lighting; the sun is warm `#FFC58A` at a low angle (ClockTime 17.4); cool ambient `#5D6A8F`; Atmosphere density 0.32 with a warm haze; Bloom 0.6 / threshold 1.6; ColorCorrection saturation +0.08, contrast +0.06 |
| **Night Show** | MEGA BOMB rounds | ClockTime 19.8, deep blue ambient, every emissive and spark brightened, fireworks in the skybox |
| **Spotlight** | Last Stand | Global brightness × 0.35, a SpotLight on the Runner, a warm rim light on the Bombers |

### 2.6 Typography (Roblox fonts)
| Role | Font | Weight | Use |
|---|---|---|---|
| Display / callouts | **Luckiest Guy** | Regular | CLUTCH DEFUSE!, VICTORY, titles, logo lockups |
| UI headings & numbers | **Builder Sans** | ExtraBold / Heavy | Counters, prices, tabs, timers (tabular figures) |
| Body | **Builder Sans** | Medium / Bold | Descriptions, tips |

**Rules:**
- Display text always has a 3 px `Ink` stroke plus a 4 px drop shadow (`Ink` at 40 %), offset straight down. Never a glow-only outline.
- Mobile minimum sizes: body 14 px, numbers 16 px, buttons 18 px.

### 2.7 Shape language
- **Circles = the bomb, danger, timers.** Rings, fuses, dials.
- **Rounded rectangles with a chunky bevel = UI and safe things.**
- **Diagonal hazard stripes = the field**, warnings and the Field Fuse.
- **Starbursts = rewards**, only on reward moments, so they stay special.

## 3. The Bomb — "The Tick" (hero asset)
The bomb is on screen more than anything else in the game, and it's the face of the brand: logo, icon, thumbnails. **It gets more care than any other asset.**

### 3.1 Design brief
> A hand-forged cast-iron fireworks bomb from an old pyrotechnics workshop: heavy, round and honest. A riveted brass belt with two glass indicator lamps, a glazed porcelain fuse socket, and a thick braided fuse that really burns. When it's about to blow, the welded seams glow white-hot from inside, as if it can barely hold the blast in.

**Why this design:**
- The round black bomb is the most universally readable "bomb" shape there is. We keep that instant read (pillar P1) and make it premium through **materials and mechanisms**, not a weird shape.
- The lamps, glowing seams and burning fuse give us **three independent timer signals** that work at any distance:
  - **Far:** the colour of the seam glow
  - **Mid:** the lamp pulse rate
  - **Close:** the fuse length

### 3.2 Anatomy & dimensions (for a 5-stud R6 character)
| Part | Spec | Size (studs) | Material |
|---|---|---|---|
| **Body** | A slightly squashed sphere (Y × 0.96), 24 rings, smooth-shaded. Subtle hand-forged irregularity (±1.5 % radial noise, low frequency). | Ø 2.2 | Cast iron (§2.4): hammered dimples, a soot gradient on the top third, polished wear on the belt line |
| **Belt** | An equatorial band, slightly proud of the surface, with chamfered edges | 0.30 tall, 0.05 proud | Brass: edge brightening, darker patina between the rivets |
| **Rivets** | 14 domed rivets, evenly spaced on the belt | Ø 0.09 | Brass, brighter polished caps |
| **Indicator lamps** | 2 glass lenses (front and back) in brass bezels. Each has an inner Neon element whose colour and brightness pulse with the tick | Ø 0.26 | Glass lens + Neon core (`Spark` → `Detonate` by stage) |
| **Seams** | 2 meridian weld seams (an X when seen from the top), sunk 0.02 into the body. A separate **SeamGlow** MeshPart (an inset strip) carries the glow | 0.05 wide | Body: iron with a weld bead normal. SeamGlow: Neon, transparency driven by stage |
| **Collar** | A brass neck ring with a knurled band | Ø 0.62, 0.22 tall | Brass, knurl normal |
| **Fuse socket** | A glazed porcelain cup sitting in the collar | Ø 0.42, 0.18 tall | Porcelain with crackle glaze; a soot ring at the rim |
| **Fuse** | A braided cord in **12 segments**, gently curved (an S-bend), tapering 0.11 → 0.08 | 1.25 long at full | A braided cord texture (real 3-strand braid normal), charring along the burn |
| **Spark** | At the burning tip: a ParticleEmitter, a PointLight and a tiny bright core sprite | — | §5.2 |
| **Stencil** | A small stencilled "FV" mark and the hazard pictogram on the back, low contrast (painted, chipped) | 0.35 | A decal baked into the colour map |
| **Clamp** | A sprung steel claw that grips the bomb, with a **visible coil spring** to a small leather-and-buckle back plate | Plate 0.9 × 1.1 | Painted steel (`Ink2`, chipped), leather, a brass buckle |

**Mount:** the back plate sits on the Torso back, 0.4 studs out. The bomb hangs on the claw, centred 0.15 studs above the torso's centre line.

### 3.3 States & behaviour (implemented in `BombController`)
| State | Duration | Visual | Audio (§9) |
|---|---|---|---|
| **Stick** | 0.22 s | The bomb slams in from the tagger's hand direction. Squash 1.15 × 0.85 → overshoot → settle. The claw snaps shut, and a dust puff comes off the back. | `Bomb.Clamp` (a metal clank) + `Bomb.Ignite` (fuse catches) |
| **LIT** (4.0–2.5 s) | — | The spark is steady and the lamps glow `Spark` with a slow sine pulse (2 Hz). The seams are dark. **Secondary motion:** spring jiggle driven by the character's acceleration (k = 180, damping 0.35), ±8° wobble. | `Bomb.Tick` at 2 Hz, `Fuse.Hiss` loop |
| **HOT** (2.5–1.0 s) | — | The seams fade in orange (`Ember`, transparency 0.7 → 0.3). The lamps turn orange and pulse at 4 Hz. Smoke wisps rise from the fuse socket. | Tick at 4 Hz with pitch +2 semitones; the hiss gets louder |
| **CRITICAL** (1.0–0 s) | — | The seams go white-hot (`Spark` → white core). The lamps turn `Detonate` and strobe at 10 Hz. **The body swells 8 % and shakes** (±0.04 studs). Sparks spray from the seams, a PointLight (range 10, orange) switches on, and heat shimmer appears if the device allows. | Tick at 10 Hz rising into a whine (`Bomb.Critical`), plus the heartbeat (Carrier only) |
| **Pass flight** | 0.18 s | The bomb pops off the back, flies a 2-stud-high arc with 1.5 spins and a short warm motion trail, then lands on the receiver (Stick, pitched up). | `Bomb.Whoosh` + `Bomb.Clamp` (pitched +3 semitones) |
| **Boom** | — | A pre-swell over 0.08 s (× 1.25), then the explosion stack (§5.1). The bomb mesh is hidden at the flash; brass fragments are part of the debris. | `Boom.*` stack |
| **Defuse** | 0.9 s | The fuse snuffs (the spark dies with a steam curl). The lamps fade to dark, the claw releases with a click, and the bomb drops, bounces twice with a heavy iron clunk and rolls, then fades out after 1.5 s. | `Fuse.Snuff` + `Bomb.Release` + `Bomb.Drop` |
| **Locked** (on a stunned Bomber) | — | Same stages, but the claw is red-painted to show it can't be passed | — |

### 3.4 The fuse: how it burns (technical)
- The 12 segments are separate small MeshParts, welded in a chain.
- **Burn progress** `p = 1 − remaining / FUSE`:
  - Every segment with an index below `floor(p × 12)` is hidden.
  - The current segment scales along its length by the fractional part, and its colour lerps to charred.
  - The spark attachment follows the current tip.
- **This makes the fuse length always the true time** (GDD §10.4).
- **A fresh bomb from a pass keeps its burn state.** The fuse is short on arrival, which visibly tells the receiver "you have no time".

### 3.5 The overhead fuse ring (UI, every Carrier)
- A BillboardGui ring above the head: 64 px on phones, 72 px on PC. AlwaysOnTop within 60 studs.
- **Its design:** a circular braided-fuse ring that burns away clockwise, with a spark at the burn point. The remaining arc is coloured by stage (`Spark` → `Ember` → `Detonate`).
- **At CRITICAL** the ring shakes and pulses.
- **The skin's Fuse Spark cosmetic** changes the spark sprite, never the arc colours.

### 3.6 Skins — rules
1. **Same mesh, same silhouette, same parts.** Skins are *texture sets* (colour, normal, roughness, metalness) plus a lamp colour and an optional emissive accent. One SurfaceAppearance swap per part; the geometry is shared.
2. **The fuse, seams and lamp stages are never changed** by a skin. The stage colours always read the same.
3. **No dominant Runner cyan or Bomber red-orange** on the body.
4. **Every skin passes the Quality Bar on its own**, with turntable renders.
5. **The face rig (§3.8) is shared by every skin.** Skins never paint eyes or mouths on the front face zone.

### 3.7 Launch skin line-up (16)
| Skin | Rarity | Concept & material notes |
|---|---|---|
| **Classic Iron** | Default | The hero design above |
| **Rookie Brass** | Rare (Starter Bundle) | A full brass body with copper rivets, polished; gentle fingerprints |
| **Copper Kettle** | Common | Hammered copper with verdigris in the rivets; a tea-kettle charm |
| **Delft** | Rare | Glazed white porcelain with hand-painted cobalt-blue floral patterns (vector-painted, then baked); gold belt |
| **Watermelon** | Common | A glossy rind-green body with stripes, a pink "flesh" belt with seed rivets |
| **Gumball Machine** | Rare | A clear glass body (two-layer: a glass shell plus a coloured gumball cluster inside), a red-painted metal belt |
| **Lava Forge** | Epic | Obsidian body with magma cracks (an emissive accent along the crack geometry baked in the normal), pulsing slowly |
| **Frostbite** | Epic | A frosted-ice body with an inner rime layer, a silver belt, breath-frost particles |
| **Clockwork** | Epic | A brass and glass body showing turning gears inside (an animated inner part), a dial on the belt |
| **Thunder Egg** | Epic | A geode shell cracked open on one side showing amethyst crystals (normal and colour), stone texture |
| **Disco Night** | Rare | A mirror-tile body (a mosaic normal plus high metalness) that catches the world light |
| **Paper Lantern** | Common | Red lacquered paper over ribs, a gold-leaf belt, a soft inner glow |
| **Galaxy** | Legendary | Deep space inside a glass sphere: parallax nebula layers (two nested shells), drifting star particles, a chrome belt |
| **Dragon Egg** | Legendary | Scaled, iridescent shell plates (normal plus a colour shift), a gold claw belt; the lamps are dragon eyes that blink |
| **Gilded** | Exclusive (VIP) | Gold leaf over iron with engraved scrollwork; champagne-gold lamps |
| **Streak Bomb (monthly)** | Exclusive (7-day streak) | A new design every month (October: **Jack-o'-Fuse**, a carved pumpkin with candle glow inside) |

### 3.8 The face rig (character) — awaiting the user's sign-off
**Brief:** the bomb is the star of the game, so it gets a personality. It is cocky while it ticks, nervous at HOT, and screaming at CRITICAL, and it watches its next victim. Players should feel that the bomb *wants* to go off on someone, and the Carrier should see it panicking on their own back.

**Placement.** The face sits on the front (+Y, away from the clamp), between the two front weld seams. The eyes are above the brass belt and the mouth below it, so the front indicator lamp sits between them like a little glowing nose. Because the bomb hangs facing backward, everyone behind the Carrier sees the face, including the Carrier's own third-person camera.

| Part | Spec | Material | Moves |
|---|---|---|---|
| **Eyes** | 2 domes, Ø 0.52, centred 21.5° either side of the front and 26° above the belt, 0.09 proud | Porcelain (the fuse socket's crackle glaze) | Fixed |
| **Pupils + glints** | An ink cap (25° of the eye) with a 6.5° porcelain glint | Ink enamel, emissive glint | Rotate about the eye centre (gaze) |
| **Lids** | An upper half-shell over each eye, 0.016 thick | Ink enamel | Rotate about the eye's horizontal axis (blink, squint) and its out axis (slant) |
| **Brows** | Forged bars, 0.46 long and 0.115 tall, tapering, at 47.5° elevation | Brass (the belt's) | Rotate about the body centre (raise, tilt) |
| **Mouths** | One mesh per shape, wrapped onto the body 33° below the belt: **Smirk** (LIT), **Grimace** (HOT, clenched porcelain teeth), **Panic** (CRITICAL, a white-hot core matching the seams), **Ooh** (pass flight), **Grin** (a tag) | Brass lips, porcelain teeth, emissive core | Shown one at a time |

**Expressions** (driven by `BombController` from the bomb's state):

| Moment | Lids | Brows | Pupils | Mouth |
|---|---|---|---|---|
| **LIT** · smug | Half-lidded, slanted in | Down at the inner end | Track the nearest player | Smirk |
| **HOT** · uh-oh | Open, outer corners droop | Up at the inner end | Track, slightly down | Grimace |
| **CRITICAL** · panic | Wide | Up at the inner end | Pinned (×0.7), shaking with the body | Panic (glowing) |
| **Blink** | Closed for 0.12 s every 2–4 s while LIT | — | — | — |
| **Gotcha** (a tag) | Narrow, wicked slant | Hard down | On the victim | Grin, 0.6 s |
| **Whee** (pass flight) | Wide | Up | Up | Ooh |

**Rules.**
1. **One face for every skin** (§3.6). Skins never paint features on the front face zone.
2. The fuse, seams, lamps and stage colours are untouched (GDD §10.4). The face adds at most 0.09 studs at the front.
3. Every part is rigid and only rotates, so the game drives exactly the rig that was reviewed (`art/bomb/face.py`, contact sheet `art/out/Bomb.Face/contact_sheet.png`).
4. Reduce motion (GDD §21.3) stops the pupil shake. The expressions stay, since they carry the timer read.

## 4. World

### 4.1 Temporary map (P0–P2): Meadow
Chase Game's Meadow field transfers unchanged as a playable placeholder for the core loop. **It never ships to players.** The launch map replaces it in P3, before any public build.

### 4.2 Launch map: "The Fireworks Yard"
**Brief:** the loading yard of an old fireworks factory at golden hour. Two loading docks face each other across a painted concrete yard. Crates of fireworks are stacked everywhere, bunting hangs from the cranes, and the factory chimneys glow behind it all.

| Zone | Design | Gameplay contract (`Arena`) |
|---|---|---|
| **Safe Strips** = the two **loading docks** | A raised concrete dock (0.6 studs) with yellow-black bumper edges, roll-up shutter doors behind, and sandbag walls at the sides. A green floodlight strip marks the safe edge; the floor is stencilled "SAFE". | `Zones/StartZone`, `Zones/FinishZone`; the soft wall for Bombers is an invisible collider following the dock edge |
| **The field** = **the yard** | Weathered concrete slabs (a trim sheet with expansion joints, oil stains and chalk marks), plus painted hazard lanes that light up during the Field Fuse warning. | `Zones/Field`, 140 × 90 studs [TUNE] |
| **Field Fuse cords** | Two thick fuses run in steel gutters along both long edges, with a spark racing along them. | Driven by FuseController |
| **Cover & lanes** | 4–6 low firework crate stacks (waist-high, 3 × 3 studs) and 2 hand-trucks. Movement-friendly: rounded corners, no snags. | `Gameplay/` folder; collision boxes simplified |
| **Backdrop** (non-playable) | The factory facade with a hand-painted "FUSE VALLEY FIREWORKS Co." sign in neon tubes, two chimneys with a warm glow, a gantry crane with bunting, a water tower, distant hills. Fireworks pop in the sky on round wins. | Out of bounds |

**Signature moment — field detonation:** the hazard lanes flash in sequence from one end, then a rolling chain of small charges pops up through the concrete joints (VFX §5.4). It's the yard "going off".

**Post-launch maps (backlog):** "Rooftop Pier" (a night boardwalk with neon) and "The Quarry" (sandstone, mine carts).

### 4.3 Lobby: "The Depot"
A cosy railway goods depot beside the factory:
- **Spawn plaza:** cobbles, string lights, and the **MEGA BOMB clock tower**. The tower is wrapped in a giant spiral fuse, and the spark climbs toward a huge bomb at the top as the next event nears. When the event starts, the top bomb pops in a firework shower.
- **Shop kiosk:** a striped-awning firework stall with the featured items spinning on brass plinths.
- **Quest board:** a corkboard with three printed quest cards and pins.
- **Leaderboard wall:** three chalkboard-framed boards, plus the weekly statue plinths.
- **Fuse Range:** a practice yard with padded dummies on springs, a practice-bomb dispenser and a defuse pad.
- **VIP lounge:** a gold-trimmed balcony above the stall.

### 4.4 Props kit (shared by the map and lobby)
Every prop is built in the `art/` pipeline (§10) with the materials library:

| Prop | Notes |
|---|---|
| Firework crate (3 sizes) | Wood with stencilled labels, rope handles, fireworks poking out |
| Rocket bundle | Paper tubes with twisted fuses (decor only) |
| Hand-truck | Painted steel, rubber wheels |
| Sandbags | Canvas, stitched |
| Dock bumper | Rubber, yellow/black stripes |
| Shutter door | Corrugated, painted, chipped |
| Floodlight | Steel, with a SpotLight |
| String lights | Bulbs with warm emissive cores |
| Bunting | Triangular flags in the palette, animated sway |
| Spring dummy | A padded canvas body on a coil spring (Fuse Range) |

### 4.5 Lighting
| Context | Preset (§2.5) |
|---|---|
| Rounds | Golden Fuse |
| MEGA BOMB rounds | Night Show |
| Last Stand | Spotlight (a tween from the current preset) |

---

## 5. VFX
**All textures are authored in-house** (Blender renders or procedural Python generators in `art/vfx/`), stylised with cel-shaded smoke and hand-designed shapes. None are AI-generated, and none are stock.

### 5.1 The explosion stack — "Classic Kaboom" (default)
| t (s) | Layer | Spec |
|---|---|---|
| 0.00 | **Pre-swell** | The bomb scales up 1.25 over 0.08 s (the anticipation beat) |
| 0.08 | **Flash** | A white-yellow core sprite (a 512² radial with a star-shaped falloff). Size 9 studs → 0 over 0.06 s. A PointLight (range 26, brightness 6) for 0.15 s |
| 0.08 | **Fireball** | A flipbook of 16 frames (a 4×4 sheet, 1024²) of a toon-shaded fireball: 3 tone bands (white core → `Spark` → `Fuse`) with an `Ink` outline edge. 3 particles at 6–8 studs, lifetime 0.35 s |
| 0.08 | **Shockwave** | A floor decal ring (a crisp double ring, `Paper` at 60 %) expanding 0 → 14 studs over 0.25 s and fading. Plus an air-ring billboard expanding to 10 studs |
| 0.10 | **Sparks** | 24 streak particles (velocity-aligned), `Spark` → `Fuse`, speed 40–70, with drag, lifetime 0.4 s |
| 0.10 | **Debris** | 6 meshes: 4 iron shell shards and 2 brass rivets. Real parts with physics, CanCollide off with the players, bouncing on the floor, gone after 1.2 s |
| 0.15 | **Smoke** | 8 toon smoke puffs (a flipbook of 8 frames: dark core → light rim, with an outline), rising and expanding to 7 studs, lifetime 1.1 s |
| 0.15 | **Soot decal** | A starburst scorch decal on the floor, fading over 6 s |
| 0.30 | **Embers** | 12 slow, floating `Ember` particles drifting up, lifetime 1.5 s |

- **Total:** ≤ 220 particles at peak.
- **The light variant** (more than 3 booms at once): flash + fireball + 8 sparks + 3 smoke puffs.

### 5.1b The slap (GDD F-BOMB-10)
The tag's beat, in the same toon language as the explosion stack. It plays on the contact frame, `SLAP_LEAD` after the server's Stick.

| Layer | What it is |
|---|---|
| **Smack** | `art/vfx/make_smack.py`: a 4×4 flipbook (1024², 16 frames, drawn at 4× and filtered down, so its edges are anti-aliased). A comic impact star: 9 uneven spikes, white core → `Spark` → `Fuse` inside a thick `Ink` outline. It pops in with an overshoot, thin speed strokes fly out between the spikes, and it snaps shut into its core. One particle, 2.8 studs, lifetime 0.32 s, on the Runner's back |
| **Flash** | The 6-point star flash, 2.6 → 0.6 studs over 0.09 s |
| **Spray** | 7 velocity-aligned streaks, `Paper` → `Spark`, sprayed the way the slap travels |
| **The hand bomb** | The hero bomb at 0.42× in every ready Bomber's right fist: the Bomber's skin, the face watching the nearest Runner, the fuse leaning out so its spark shows. It pops back in (a 0.22 s swell) when the tag is ready again |
| **Sound** | Pro Sound Effects "Hand Slap, Sharp Smacking" (4 takes, thud tail trimmed) over the clamp, plus a quick high whoosh on the swing |
| **Motion** | `tools/anim/Slap` (Bomber, upper body) and `Stumble` (Runner, upper body), in-house v1. The animator's brief has the final versions |

### 5.2 Fuse spark (default "Classic")
- A core sprite (a 6-point star, flickering size 0.3–0.45) plus 6–10 tiny streak sparks per second, falling with gravity.
- A PointLight (range 4, warm).
- **At CRITICAL:** the rate triples and a sputter pops every 0.2 s.

### 5.3 Defuse
- **Steam curl:** a 6-frame flipbook rising from the socket.
- A **"snuff" pop**: a small grey puff.
- A soft green ring on the floor (`Safe`) for 0.4 s.
- **Clutch Defuse adds** a gold flash, gold star sparks, and a 0.5 s light ray burst behind the player.

### 5.4 Field detonation
- The hazard lanes flash in sequence along the field (0.05 s per lane).
- Then a **rolling chain** of 30 small charges pops up through the concrete joints over 0.6 s, each a mini fireball and smoke.
- Plus a dust sheet across the whole field, then a lingering haze for 2 s.

### 5.5 Feedback VFX
| Effect | Spec |
|---|---|
| Tag-ready hand glow | A soft `Bomber` glow on the Bomber's hands when the cooldown is ready |
| Pass arc trail | A warm ribbon trail behind the flying bomb, 0.18 s |
| Ragdoll soot | The flung body gets a soot overlay and drifts small smoke wisps for 3 s |
| Bomber stun | Cartoon spinning sparks over the head with a soot face for 3 s |
| Level-up firework | A personal firework above the player's head; the colours follow their equipped Fuse Spark |
| Win crown | A gold crown with a lit sparkler, rotating slowly |
| MEGA BOMB | A giant version of the bomb with an animated crown fuse. Its STOMP telegraph ring is `Mega` violet with hazard dashes |

### 5.6 Explosion cosmetics (launch)
Same timing and 7-stud splash ring as the default (GDD §10.4):

| Explosion | Rarity | Concept |
|---|---|---|
| Classic Kaboom | Default | §5.1 |
| Confetti Cannon | Common | A paper confetti burst with streamers and a party-horn layer |
| Ink Splat | Rare | A comic ink splash with a floor splat decal; black and `Paper` |
| Firework Peony | Rare | A spherical firework burst with trailing stars |
| Pixel Burst | Epic | Voxel cubes bursting and blinking out; an 8-bit pop layer |
| Frost Nova | Epic | Ice shards and a frost ring that freezes the floor decal briefly |
| Black Hole | Legendary | A 0.15 s implosion (it sucks particles in) then a violet pop with lensing rings |
| Champagne | Exclusive (VIP) | A gold foil cork pop, bubbles and gold confetti |

## 6. UI

### 6.1 The look: "Workshop Arcade"
- **Chunky, tactile and lit.** Panels feel like painted enamel signs with brass fittings.
- **Buttons feel like real arcade buttons:** they physically sink when pressed.
- **Everything has an `Ink` outline and a solid offset shadow**, so it reads on any background, bright or dark.

### 6.2 Panel system (`UIKit.panel`)
| Layer (back → front) | Spec |
|---|---|
| Drop shadow | A solid `Ink` at 45 %, offset 0, +6 px (straight down), with the same corner radius |
| Outline | A 3 px `Ink` UIStroke |
| Base fill | `Ink2` (dark panels) or `Paper` (light cards) |
| Bevel highlight | A 2 px inner top highlight (`Paper` at 12 % on dark, white at 60 % on light) |
| Surface texture | A subtle enamel grain (a 256² tiled noise at 4 % opacity): it reads as "material", not "flat" |
| Header plate (optional) | A brass-coloured strip with rivet dots at the corners, holding the title in Luckiest Guy |

**Corner radius:** 14 px on panels, 12 px on buttons, 999 px on pills.

### 6.3 Buttons (`UIKit.button`)
| State | Visual | Motion | Sound |
|---|---|---|---|
| Idle | A 2-tone face (top 55 % lighter): primary = `Fuse`/`Ember`, secondary = `Smoke`. A 6 px base "skirt" in a darker shade under the face | — | — |
| Hover (PC) | Face +6 % brightness; a 1.03 scale spring | Spring 0.12 s | `UI.Hover` (very soft) |
| Press | **The face sinks 4 px into the skirt**; scale 0.96 | 0.06 s down | `UI.Press` (a mechanical click) |
| Release | Springs back with a small overshoot | Spring (stiffness 400, damping 22) | `UI.Release` |
| Disabled | `Smoke` face, `Ash` text, no skirt shine | — | `UI.Deny` on tap, with a horizontal shake |

### 6.4 Icon set (custom, `ui/icons/`)
- **Authoring:** hand-drawn vectors (SVG), exported at 2×: 128² and 256² PNG.
- **Style:**
  - a 4 px `Ink` outline
  - a 2-tone fill (base plus a lighter top-left plane)
  - one specular dot
  - a consistent 10° tilt on objects
- **The launch set (≈ 40):**
  - Star (currency)
  - Bomb, Fuse, Spark, Shield (safe), Runner, Bomber, Crown, Flame (streak)
  - Gift, Calendar, Quest scroll, Crate (Spark and Inferno), Trophy
  - Gear (settings), Lock, Check, Arrow, Close, Plus
  - Robux-safe "R$" price badge (our own frame around Roblox's official Robux glyph, per their brand rules)
  - Category icons (Bomb skin, Explosion, Spark, Trail, Victory, Title, Emote)
  - Dash, Slide, Stop (action buttons)
  - Mega
- **No emoji anywhere.** Not in strings, chips, buttons or callouts.

### 6.5 Motion system (`UIKit.motion`)
| Interaction | Spec |
|---|---|
| Panel open | Scale 0.85 → 1 with a spring (stiffness 320, damping 24); fade 0 → 1 over 0.12 s; content staggers in at 0.03 s per item |
| Panel close | Scale 1 → 0.92, fade out over 0.12 s (no spring) |
| Number change | Counts up over 0.4 s (ease-out); a small 1.08 scale bump at the end; a tick sound every few steps |
| Reward pop | The value flies from its source to the Stars counter in a bezier arc. The counter does a punch scale, then counts up |
| Attention | A gentle 2 s breathing pulse (1.0 ↔ 1.04) on claimable items (gift, quest done, calendar) |
| Text | Never scaled continuously; only discrete tweens, so whole-pixel snapping doesn't look choppy (the Chase Game lesson) |
| Reduced motion (setting) | Springs become fades; no shake, no pulse |

### 6.6 HUD components
| Component | Spec |
|---|---|
| **Crossing chip** | A pill "CROSSING 3/8" in Builder Sans Heavy with 8 small fuse dots (lit = done) |
| **HUD Field Fuse** | A horizontal braided-fuse bar inside a steel gutter frame. The remaining fuse shortens from the left, with a spark (particles) at the burn point. At 5 s the frame flashes hazard stripes; at 3 s it shakes |
| **Team counter** | A pill: Runner icon + count (cyan) · divider · Bomber icon + count (red-orange). When a count changes, the number flips like a split-flap display |
| **MEGA BOMB chip** | A pill: the Mega bomb face badge + "MEGA BOMB 4:12"; violet accents |
| **Quest tracker** | Collapsed: 3 small progress rings. Expanded: 3 rows (icon, text, progress bar). On a tick: a bar fill plus a +1 pop |
| **Hot Streak flame** | An animated flame icon (a 6-frame flipbook) whose size steps with the streak; the multiplier sits on a brass tag |
| **Gift ring** | The gift icon inside a progress ring with "3:12" under it; when ready it bounces and shows "CLAIM" |
| **Carrier vignette** | A full-screen ImageLabel: a radial red edge texture (soft inside, a hazard-stripe hint at the very edge), pulsing with the tick |
| **BUMP! arrow** | A chunky arrow pointing at the nearest pass target with "BUMP!"; it bobs |
| **Defuse chevron** | An edge-of-screen green chevron with "2.1 s" (green) or a red "TOO FAR" |
| **Action buttons** (mobile) | Circular arcade buttons, 110 px (Dash) and 78 px (Slide, Stop), each with its custom icon. The cooldown shows as a draining ring and a "ready" ping |

### 6.7 Callouts
| Tier | Spec |
|---|---|
| **Small** | Luckiest Guy 28 px, `Paper` with an `Ink` stroke. Pops in at 1.3 → 1 (spring) and floats up 20 px over 0.8 s, then fades. Shows "+5 XP · +1 ★" in Builder Sans below |
| **Medium** | 40 px, with a coloured fill by type (gold = defuse, red-orange = revenge, violet = betrayal). A starburst plate behind it rotates slowly. Holds 1.2 s |
| **Big** | 60 px, full-width with a banner plate. Light rays behind, a camera kick, a choir or brass hit. Holds 1.6 s. Max one at a time |

---

## 7. Screens & sequences

### 7.1 Loading screen
- **Background:** dusk sky.
- **Centre:** the logo, "FUSE VALLEY". The F's crossbar is a lit fuse cord and the V cradles the bomb; the fuse spark burns along the lettering.
- **The fuse burns as loading progresses**, and the spark races to the bomb as it finishes.
- **Below:** a rotating tip.
- **Exit:** the bomb "pops" into the game camera with a wipe.

### 7.2 Results
**The headline:**
- **Podium:** a 3D stage with the top 3 avatars on brass podiums (1st gets a crown and a confetti cannon).
- **Bomber win:** the MVP stands alone on a stage, with soot smoke and a bomber chant.

**Your round:**
- A paper "receipt" card prints line by line with a printer sound. Each line pays out in a coin burst.
- Then the XP bar fills, possibly into a level-up.
- Then 2 "next" hook chips (GDD §8.4).

### 7.3 Level up
- **The background dims.**
- **The level number** smashes in (scale 3 → 1 with a shockwave), and a firework burst plays behind it.
- **The reward card spins in** and flips to reveal the reward.
- **A level-track item** (every 5 levels) gets its own 3D turntable reveal.

### 7.4 Crate opening
1. **The crate drops** onto a workshop table (a heavy thud with dust).
2. **The crate's fuse lights**, and the camera pushes in.
3. **Tension:** light leaks through the lid seams in the **rarity colour** (the hint). The crate rattles harder.
4. **POP:** the lid blows off with a rarity-coloured burst (confetti-sparks; Legendary adds a light-ray fan and a brass fanfare).
5. **The item rises** on a beam, rotating, with its name plate and rarity banner. Then the buttons: **EQUIP** · **OPEN ANOTHER**.

**Skip:** tapping during steps 1–3 jumps to step 4. Never force the long version on repeat openings.

### 7.5 Daily calendar
- **A wall calendar:** 7 paper day cards pinned on a corkboard.
- **The current day pulses.**
- **Claiming:** an ink stamp slams "CLAIMED" with a thud, and the reward flies to the counter.
- **Day 7** is a big gift card showing this month's Streak Bomb.

### 7.6 Event card (MEGA BOMB)
- **A violet poster:** the Mega Bomber silhouette, a countdown, the rules in 3 lines, and the rewards.
- **Two buttons:**
  - "SUMMON — R$ 99"
  - "GOT IT"

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
