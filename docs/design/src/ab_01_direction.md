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

## 2. Art direction: the reference-video look ("Toy Arcade"), 2026-10-17

> **Supersedes the original "Arcade Pyrotechnic" direction where they conflict** (DECISIONS 2026-10-17: the owner's
> reference video wins for UI layout, colours, buttons, motion and world brightness; the fireworks / bomb theme stays).
> The rest of this section (2.1–2.7) is the original direction, kept for the bomb's materials and everything the video
> doesn't cover.

| Area | The rule now | Where it lives |
|---|---|---|
| World | Bright, sunny, toy-like: studded plastic surfaces (Theme.StudTexture), saturated toy colours, palms and voxel trees, puffy clouds, crisp midday light | `builders/MapYardToy.luau` (the Yard restyle pass), concept `art/ref/map/yard_concept_overview.png` |
| UI panels | Flat rounded bodies with a soft vertical gradient and a gloss band, a coloured border ring, a thick ink outline; screen headers are a gradient strip (rainbow for the Shop) with the title in big round type and its 3D icon breaking out over the corner; a red square close button | `src/client/UI/Skin.luau`, `DailyController.panel` |
| Buttons | Bright arcade buttons: lighter top, darker lip, gloss band, ink outline, white text with an ink stroke; green = buy / play, red = close, a colour per tab | `Skin.button`, `Skin.Preset` |
| Cards | Rarity-gradient cards (Common grey-white, Rare blue, Epic purple, Legendary gold, Exclusive pink) with a white border, halftone wash, the item's art large | `StoreController` |
| Type | Fredoka One everywhere (display, numbers, labels), Builder Sans Bold only for long body copy; Luckiest Guy for the logo | `Theme.Font`, `Skin.Font` |
| Icons | Glossy, chunky 3D icons modelled and rendered in Blender (art/icons/set_*.py) after ChatGPT style sheets (art/ref/icons — references only) | `Assets.Icon` |
| HUD | Left dock of square tiles (icon, name, shortcut key, "!" badge), the Stars wallet bottom-left (under the top bar on phones), the gear menu in the top-bar row | `UI/Dock.luau`, `ProgressController`, `SettingsController` |
| Screens | Video-style join screen (logo + PLAY!), STARTER PACK rainbow card, crate opening with rays and confetti | `src/first`, `OfferController`, `CrateController` |
| Sound | The in-house UI pack and SFX set (art/audio/make_ui.py, make_sfx.py) + the licensed library | `Assets.SFX` |

The Quality Bar (§1) is unchanged: no AI-generated finals, no Toolbox models, everything crafted, animated and paired
with a sound. "Generic two-stop gradients" stay banned *as decoration on dark panels*; the reference's bright gradient
cards, tabs and headers are the house style now.

## 2b. The original direction: "Arcade Pyrotechnic"

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
