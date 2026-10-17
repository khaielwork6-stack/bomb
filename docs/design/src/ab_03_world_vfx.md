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
