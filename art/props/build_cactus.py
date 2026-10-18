"""FUSE VALLEY — The Quarry's cacti for the ledges and the low +Z side (docs/maps/QUARRY_BRIEF.md "Backdrop": cacti and
green scrub on the ledges; GDD §19 maps, Asset Bible §4 props, §1 Quality Bar).

Two props from one script:
  • Prop.Cactus (default): a chunky cartoon saguaro, a ribbed trunk ~7 tall with two upturned arms at different
    heights, glossy toy green with deep rib grooves and a scatter of cream spine dots;
  • Prop.CactusSmall (--small): a round ribbed barrel cactus ~1.6 across with a pink flower (six petals and a yellow
    heart) on top.

MeshPart groups: Cactus (the body); CactusSmall also Flower.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_cactus.py -- [--small] [--samples 64] [--no-render]
Out:  art/out/Prop.Cactus/ or art/out/Prop.CactusSmall/  (renders/, export/*.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
import qkit  # noqa: E402
from kit import Vector, srgb  # noqa: E402

SMALL = kit.flag("--small")
KEY = "Prop.CactusSmall" if SMALL else "Prop.Cactus"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Cactus", "Flower"] if SMALL else ["Cactus"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
GREEN, GREEN_HI, GREEN_DK, SPINE = srgb("#2E9C46"), srgb("#86E070"), srgb("#14602C"), srgb("#FFF2C8")
PINK, PINK_HI, PINK_EDGE = srgb("#FF5A9E"), srgb("#FF9CC8"), srgb("#FFD0E4")
YELLOW, YELLOW_HI = srgb("#FFC21E"), srgb("#FFE88A")

M_CACTUS = qkit.mat_cactus("Cactus", GREEN, GREEN_HI, GREEN_DK, SPINE, dots=6.0 if SMALL else 4.0)
M_PINK = kit.mat_gloss("Petal", PINK, PINK_HI, edge=PINK_EDGE, rough=0.38, grad=0.5)
M_YELLOW = kit.mat_gloss("Heart", YELLOW, YELLOW_HI, rough=0.5, grad=0.4)

markers = {}
if not SMALL:
    TR = 0.8
    TOP = 6.2  # trunk path top (the dome adds ~0.7)
    qkit.sweep("Trunk", [(0, 0, 0), (0, 0, TOP * 0.5), (0.04, 0.02, TOP)], TR, M_CACTUS, "Cactus", segs=40, ribs=10, rib_depth=0.2, n=4, cap_start=False, cap_rings=6, taper=lambda t: 1.0 - 0.06 * t)
    # left arm: out low, then up
    qkit.sweep("ArmL", [(-0.2, 0, 2.5), (-0.95, 0.0, 2.62), (-1.38, 0.02, 3.15), (-1.45, 0.04, 4.55)], 0.5, M_CACTUS, "Cactus", segs=32, ribs=8, rib_depth=0.2, n=5, cap_start=False, cap_rings=5)
    # right arm: higher, shorter, turned a little toward the front
    qkit.sweep("ArmR", [(0.2, 0, 3.55), (0.88, -0.1, 3.68), (1.22, -0.18, 4.15), (1.26, -0.2, 5.15)], 0.45, M_CACTUS, "Cactus", segs=32, ribs=8, rib_depth=0.2, n=5, cap_start=False, cap_rings=5)
    target, cams = (0, 0, 3.4), {"hero": ((7.5, -11.5, 6.0), 50), "front": ((0, -16.0, 3.6), 50)}
else:
    R, H = 0.8, 0.72
    qkit.sweep("Barrel", [(0, 0, 0), (0, 0, H * 0.5), (0, 0, H)], R, M_CACTUS, "Cactus", segs=48, ribs=14, rib_depth=0.17, n=3, cap_start=False, cap_rings=7, taper=lambda t: 0.84 + 0.16 * math.sin(math.pi * (0.2 + 0.6 * t)))
    top = Vector((0, 0, H + R * 0.9 * (0.84 + 0.16 * math.sin(math.pi * 0.8)) - 0.06))
    for k in range(6):
        a = math.radians(60 * k + 10)
        d = Vector((math.cos(a), math.sin(a), 0))
        p = top + d * 0.2 + Vector((0, 0, 0.08))
        petal = kit.sphere(f"Petal{k}", 0.2, (0, 0, 0), M_PINK, "Flower", scale=(1.25, 0.72, 0.36), u=12, v=6)
        rot = d.to_track_quat("X", "Z").to_matrix().to_4x4()
        tilt = kit.Matrix.Rotation(math.radians(-28), 4, "Y")
        petal.matrix_world = kit.Matrix.Translation(p) @ rot @ tilt
    kit.sphere("FlowerHeart", 0.13, tuple(top + Vector((0, 0, 0.14))), M_YELLOW, "Flower", scale=(1, 1, 0.7), u=12, v=8)
    markers["FlowerTop"] = kit.blend(top)
    target, cams = (0, 0, 0.85), {"hero": ((2.8, -4.4, 2.6), 50), "front": ((0, -6.0, 1.0), 50)}

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=target, floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    for name, (loc, lens) in cams.items():
        kit.shoot(name, loc, lens=lens)

maps = kit.bake_all(parts, {"Cactus": 1024, "Flower": 512} if SMALL else {"Cactus": 1024}) if BAKE else {}
ups = qkit.export(parts)
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Backdrop (cacti on the ledges, the low +Z side); GDD §19; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "markers": markers,
        "front_note": "Front = -Y in Blender (the model's LookVector in Roblox); turn freely, it reads from every side.",
    }
)
