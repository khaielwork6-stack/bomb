# Map 2 "The Quarry": brief (the contract a second FUSE VALLEY map must meet)

Measured from the built Fireworks Yard and the code on 2026-10-18. Every number is a hard rule unless it says [TUNE].
Theme: chosen by the owner (see the end).

## How a map loads
- A map is a Model at `Workspace.Maps.<Name>` (or parked in `ServerStorage.Maps.<Name>`), built by a re-runnable
  edit-time builder in `builders/Map<Name>.luau` (destroys its old output first, like `MapYard`).
- `Arena.load(name)` activates one map and parks the rest in `ServerStorage.Maps`; it lowers each map once by
  `Config.Arena.DROP` = 6 studs (`CG_Dropped`). Build at the Yard's height; the drop happens at runtime.
- Today the server loads only `Config.Maps.Order[1]` at boot. **Rotation / the map vote is partner request #1.**
  Until then a map is play-tested by putting it first in `Order` locally (not committed).
- Clone-at-runtime pieces go in the map's `Templates` folder (Arena moves them to `ReplicatedStorage.CG_MapTemplates`).
- Gameplay objects the server spawns live in `<Map>.Gameplay` (made at runtime; never build into it).

## Required parts (Arena reads these; a map without them doesn't load)
| Part | Position / size (the Yard, edit-time) | Notes |
|---|---|---|
| `Zones/Field` | centre (-3, 94, -38), size 140 × 12 × 90, unrotated | the field between the lines; floor top at y = 88 |
| `Zones/StartZone` | centre (-80, 94, -38), 14 × 12 × 90 | the start Safe Strip (side -1) |
| `Zones/FinishZone` | centre (74, 94, -38), 14 × 12 × 90 | the finish Safe Strip (side +1) |
| `StartLine` | (-73, 88.01, -38), 1 × 0.05 × 90 | |
| `FinishLine` | (67, 88.01, -38), 1 × 0.05 × 90 | |

**Map 2 uses the exact same field frame** (same centre, orientation and sizes): the lobby (`Workspace.Lobby`, centred
(-3, 100, 76), the +Z side) was built relative to the Yard's field and looks down onto whichever map is active.
- Field 140 long (X) × 90 wide (Z) between the lines; Safe Strips 14 deep beyond each line; Arena adds invisible
  line walls, back walls at ±(70 + 14 + 1) from the centre, and side walls at ±45 (the field shrinks inward from there).
- Keep the floor flat and walkable over the whole field + both strips (y = 88, ±0.6 for a raised dock edge).
- The +Z side (toward the lobby) stays low so the lobby and the spectator camera see the field.

## Optional hooks the Yard uses (give map 2 its own versions)
- `FuseCords/Cord` parts (one along each long edge): YardController races the Field Fuse spark along them.
- `HazardLanes/LaneGlow` parts across the field: they pulse red in the fuse warning and flash on detonation.
- `Cover` attribute (true) on waist-high cover parts: BotService steers round them. The Yard has 6 (4 crates of
  3 × 3, 2 hand-trucks). Movement-friendly: rounded, no snags, nothing taller than waist height on the field.
- `map:SetAttribute("DisplayName", "…")`; a `Config.Maps.List.<Name>` entry with `displayName`, `sockets`
  (SOCKETS_4x4), `hazards = {}` and a `thumbnail` (the vote card picture).

## Scale and feel
- R15 avatars (~5.5 studs), Runner speed ~ the Yard's; a crossing is 140 studs.
- Look: the owner's reference video wins: bright, sunny, toy-like, studded blocks, saturated colours, chunky
  modelled props (art/props pipeline, `MapYardToy` / `MapYardProps` patterns). No glare: mid-tone floors.
- Readability on phones: a calm floor so characters pop; lines and Safe Strips obvious at a glance.
- Lighting: a per-map preset in `Config.Lighting` (the Yard uses `ToyMidday`).

## Theme: "The Quarry" (the owner, 2026-10-18)
A sunny sandstone canyon quarry, toy-like and bright: the same chunky studded style as the restyled Yard, in warm
sand, terracotta and green against a deep blue sky.
- **Safe Strips** = two mine-entrance loading platforms: timber decks raised 0.6 with yellow-black bumper edges, a
  green safe strip, "SAFE" stencilled, a timber-framed mine tunnel mouth behind each (lanterns, rails running in).
- **Field** = packed sand and big sandstone slabs with seams; 4 mine-rail lines crossing the field lengthwise are
  the hazard lanes (`HazardLanes/LaneGlow`, flush with the floor, nothing to trip on).
- **Fuse cords** along both long edges in timber troughs (`FuseCords/Cord`).
- **Cover** (6, waist-high, `Cover`): 4 mine carts (on short rail stubs) and 2 stacks of dynamite crates.
- **Backdrop** (out of bounds): layered sandstone cliffs and mesas on the far side (-Z) with a waterfall and a pool,
  a timber head-frame / ore crane, conveyor chutes, a water tower, cacti and green scrub on the ledges; the +Z side
  (toward the lobby) stays low: a timber rail, rocks, crates.
- **Light:** bright midday desert sun, warm, mid-tone floor (no glare), a new `Config.Lighting` preset.
