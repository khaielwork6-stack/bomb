"""FUSE VALLEY — The Quarry's sandstone boulders for the field edges, ledges and the low +Z side
(docs/maps/QUARRY_BRIEF.md "Backdrop": rocks; GDD §19 maps, Asset Bible §4 props, §1 Quality Bar).

Two props from one script, chunky faceted toy boulders in terracotta sandstone with wavy cream strata and a sandy top:
  • Prop.Rock1 (--which 1, default): a stepped boulder, a broad faceted base with a smaller block sat skew on top;
  • Prop.Rock2 (--which 2): a low wide boulder with a small rock tumbled against its front-right.

MeshPart groups: Rock.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_rock.py -- [--which 1|2] [--samples 64] [--no-render]
Out:  art/out/Prop.Rock1/ or art/out/Prop.Rock2/  (renders/, export/*.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
import qkit  # noqa: E402
from kit import srgb  # noqa: E402

WHICH = kit.arg("--which", "1")
KEY = f"Prop.Rock{WHICH}"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Rock"], glow=[])

SAND_BASE, SAND_HI, SAND_CREAM, SAND_SEAM = srgb("#D0663A"), srgb("#F08E58"), srgb("#F6D9A6"), srgb("#9A4426")
M_ROCK = qkit.mat_sandstone("Sandstone", SAND_BASE, SAND_HI, SAND_CREAM, SAND_SEAM, strata=0.85, light=srgb("#F29A5E"), lines=0.5, seed_offset=float(WHICH) * 3.1)

if WHICH == "1":
    qkit.hull_rock("Base", (4.0, 3.7, 1.95), (0, 0, 0), M_ROCK, "Rock", seed=101, n=26, jitter=0.15, bev=0.12, corner=(0.5, 0.85))
    qkit.hull_rock("Top", (2.9, 2.6, 1.25), (0.25, 0.15, 1.72), M_ROCK, "Rock", seed=102, n=20, jitter=0.15, bev=0.1, rot_z=math.radians(14), corner=(0.5, 0.85))
else:
    qkit.hull_rock("Main", (3.8, 3.2, 2.15), (-0.3, 0.2, 0), M_ROCK, "Rock", seed=201, n=26, jitter=0.15, bev=0.12, rot_z=math.radians(-8), squash_top=0.15, corner=(0.5, 0.85))
    qkit.hull_rock("Pebble", (1.5, 1.35, 1.15), (1.65, -1.15, 0), M_ROCK, "Rock", seed=202, n=14, jitter=0.15, bev=0.1, rot_z=math.radians(30), corner=(0.5, 0.85))

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, 0, 1.3), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (7.0, -10.0, 6.0), lens=50, target=(0, 0, 1.2))
    kit.shoot("front", (0, -13.0, 1.6), lens=50, target=(0, 0, 1.3))

maps = kit.bake_all(parts, {"Rock": 1024}) if BAKE else {}
ups = qkit.export(parts)
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Backdrop (rocks on the ledges and the low +Z side); GDD §19; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "front_note": "Front = -Y in Blender (the model's LookVector in Roblox); turn freely, it reads from every side.",
    }
)
