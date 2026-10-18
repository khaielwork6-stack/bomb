"""FUSE VALLEY — the Fireworks Yard's gas bottle (Asset Bible §4.2 / §4.4 Yard props: factory-strip dressing).

A 1.1-stud-wide gas cylinder, ~4.1 tall like the part-built one: a glossy body with a rounded shoulder (its albedo is
kept near-white so Roblox can tint it with SurfaceAppearance.Color: red, steel-blue, ...), a dark steel foot ring, a
white shoulder band, a threaded neck collar, a brass valve with a side outlet and hex nut, a red handwheel, and an
open guard ring on two posts round the valve.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_gas_bottle.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.GasBottle/  (renders/, export/Prop.GasBottle.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, srgb  # noqa: E402

KEY = "Prop.GasBottle"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
PREVIEW_TINT = "--tint" in kit.argv  # review renders only: show the body red, as the Yard tints it
kit.setup(KEY, bake=["Body", "Trim"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
BODY, BODY_HI, BODY_EDGE = srgb("#DCDDE2"), srgb("#FFFFFF"), srgb("#FFFFFF")
if PREVIEW_TINT:
    BODY, BODY_HI, BODY_EDGE = srgb("#D8232E"), srgb("#FF5A52"), srgb("#FF9C94")
STEEL_LO, STEEL, STEEL_HI = srgb("#2C303C"), srgb("#4C5466"), srgb("#A8B2C8")
BRASS_LO, BRASS, BRASS_HI = srgb("#C07A18"), srgb("#F4B53A"), srgb("#FFEFA0")
WHITE, WHITE_HI = srgb("#F4F2EE"), srgb("#FFFFFF")
WHEEL, WHEEL_HI = srgb("#D8232E"), srgb("#FF5A52")

M_BODY = kit.mat_gloss("BodyPaint", BODY, BODY_HI, edge=BODY_EDGE, rough=0.26, grad=0.35, ao=0.55)
M_STEEL = kit.mat_metal("Steel", STEEL_LO, STEEL, STEEL_HI, rough=(0.25, 0.4), metal=0.3)
M_BRASS = kit.mat_metal("Brass", BRASS_LO, BRASS, BRASS_HI)
M_WHITE = kit.mat_gloss("Band", WHITE, WHITE_HI, rough=0.32, grad=0.3, ao=0.5)
M_WHEEL = kit.mat_gloss("Handwheel", WHEEL, WHEEL_HI, edge=srgb("#FF9C94"), rough=0.3, grad=0.4)

R = 0.55
# Body: flat bottom inside the foot ring, straight wall, a rounded shoulder up to the neck.
kit.lathe(
    "Shell",
    [(0, 0.14), (R - 0.06, 0.14), (R - 0.01, 0.18), (R, 0.26), (R, 2.9), (R - 0.01, 3.06), (R - 0.05, 3.24), (R - 0.12, 3.4), (R - 0.22, 3.53), (R - 0.33, 3.61), (0.17, 3.65), (0, 3.66)],
    M_BODY,
    "Body",
    segs=32,
)
# Foot ring, shoulder band, neck collar.
kit.lathe("Foot", [(R - 0.06, 0.0), (R + 0.02, 0.0), (R + 0.04, 0.03), (R + 0.04, 0.27), (R + 0.02, 0.3), (R - 0.04, 0.3), (R - 0.04, 0.0)], M_STEEL, "Trim", segs=32)
for i, (z0, z1) in enumerate(((2.5, 2.7), (2.78, 2.86))):
    kit.lathe(f"Band{i}", [(R - 0.005, z0), (R + 0.008, z0 + 0.008), (R + 0.014, z0 + 0.025), (R + 0.014, z1 - 0.025), (R + 0.008, z1 - 0.008), (R - 0.005, z1)], M_WHITE, "Trim", segs=32)
kit.lathe("Collar", [(0.15, 3.6), (0.22, 3.6), (0.24, 3.63), (0.24, 3.7), (0.21, 3.72), (0.21, 3.75), (0.24, 3.77), (0.24, 3.83), (0.22, 3.85), (0.12, 3.85)], M_STEEL, "Trim", segs=20)
# Guard: an open ring on two posts round the valve.
for s in (-1, 1):
    kit.cylinder(f"Post{s}", 0.035, 0.42, (s * 0.31, 0, 3.75), M_STEEL, "Trim", segs=8, bev=0.0)
    kit.cylinder(f"PostFoot{s}", 0.06, 0.06, (s * 0.31, 0, 3.53), M_STEEL, "Trim", segs=8, bev=0.015, bev_segs=1)
kit.torus("Guard", 0.31, 0.04, (0, 0, 3.97), M_STEEL, "Trim", major=28, minor=8)
# Brass valve: body, side outlet with hex nut (to the front), stem, red handwheel.
kit.cylinder("Valve", 0.12, 0.26, (0, 0, 3.98), M_BRASS, "Trim", segs=14, bev=0.025)
kit.cylinder("Outlet", 0.06, 0.22, (0, -0.2, 3.96), M_BRASS, "Trim", axis="Y", segs=10, bev=0.012, bev_segs=1)
kit.cylinder("Nut", 0.09, 0.08, (0, -0.3, 3.96), M_BRASS, "Trim", axis="Y", segs=6, bev=0.012, bev_segs=1)
kit.cylinder("Stem", 0.035, 0.12, (0, 0, 4.15), M_BRASS, "Trim", segs=8, bev=0.0)
kit.torus("Wheel", 0.15, 0.035, (0, 0, 4.2), M_WHEEL, "Trim", major=20, minor=8)
for k in range(3):
    a = 2 * math.pi * k / 3
    sp = kit.box(f"Spoke{k}", (0.3, 0.05, 0.04), (0, 0, 0), M_WHEEL, "Trim", bev=0.012, segs=1)
    sp.matrix_world = Matrix.Translation((0, 0, 4.2)) @ Matrix.Rotation(a, 4, "Z")
kit.sphere("Cap", 0.055, (0, 0, 4.23), M_BRASS, "Trim", scale=(1, 1, 0.7), u=10, v=6)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 2.1))
if DO_RENDER:
    suffix = "_tint" if PREVIEW_TINT else ""
    kit.shoot("hero" + suffix, (6.0, -8.6, 5.4), lens=50)
    kit.shoot("front" + suffix, (0, -11.5, 2.2), lens=50)

if PREVIEW_TINT:
    sys.exit(0)
maps = kit.bake_all(parts, {"Body": 512, "Trim": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "tintable": ["Body"],
        "glow": [],
    }
)
