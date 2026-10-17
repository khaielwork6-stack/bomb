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
