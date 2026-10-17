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
