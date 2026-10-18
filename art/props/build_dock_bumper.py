"""FUSE VALLEY — the Fireworks Yard's dock bumper (Asset Bible §4.2 Yard: the loading docks' "yellow-black bumper"
dressing beside the shutter doors; §4.4 props kit: "Dock bumper — rubber, yellow/black stripes").

MapYard's bumper block exactly (1.6 wide, 2.2 tall, 1.0 deep off the wall), as a chunky laminated one: a slate steel
mounting plate on the wall with a hex bolt in each corner, six thick black rubber pads stacked on it (soft bevels,
the seams between them dark), and a steel face plate painted in yellow-and-black hazard stripes, bolted through the
rubber at its four corners.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_dock_bumper.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.DockBumper/  (renders/, export/Prop.DockBumper.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import srgb  # noqa: E402

KEY = "Prop.DockBumper"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Rubber", "Plate"], glow=[])
rng = random.Random(3301)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
RUBBER, RUBBER_HI = srgb("#272731"), srgb("#4C4C5C")
SLATE, SLATE_HI, SLATE_EDGE = srgb("#41558F"), srgb("#6A80C4"), srgb("#9AAEE6")
BARE = srgb("#AEB8CA")
STEEL_LO, STEEL, STEEL_HI = srgb("#5A6478"), srgb("#9AA6BC"), srgb("#E4ECF8")

M_RUBBER = kit.mat_gloss("Rubber", RUBBER, RUBBER_HI, edge=srgb("#5A5A6C"), rough=0.6, grad=0.4, ao=0.7, speckle=0.18)
M_SLATE = kit.mat_paint_metal("Slate", SLATE, SLATE_HI, SLATE_EDGE, BARE, chip=0.42)
M_STEEL = kit.mat_metal("Steel", STEEL_LO, STEEL, STEEL_HI, rough=(0.22, 0.36), metal=0.3)
M_HAZARD = kit.mat_hazard("Hazard", width=0.2)

# ── Dimensions (studs): 1.6 wide (X), 1.0 deep (Y: -0.5 front .. +0.5 the wall), 2.2 tall (Z) ────────────────────
W, D, H = 1.6, 1.0, 2.2
MOUNT_T = 0.12
MOUNT_Y = D / 2 - MOUNT_T / 2  # the mounting plate against the wall
PAD_Y0, PAD_Y1 = -0.36, D / 2 - MOUNT_T  # the rubber, front .. back
PADS, PAD_Z0, PAD_Z1 = 6, 0.28, H - 0.28
FACE_T = 0.08

# Mounting plate with a hex bolt (on a washer) in each corner, above and below the rubber.
kit.box("Mount", (W, MOUNT_T, H), (0, MOUNT_Y, H / 2), M_SLATE, "Plate", bev=0.04, segs=2)
for sx in (-1, 1):
    for z in (0.14, H - 0.14):
        y = MOUNT_Y - MOUNT_T / 2
        kit.cylinder(f"Washer{sx}{z}", 0.1, 0.03, (sx * 0.58, y - 0.015, z), M_STEEL, "Plate", axis="Y", segs=12, bev=0.008, bev_segs=1)
        kit.cylinder(f"MountBolt{sx}{z}", 0.075, 0.07, (sx * 0.58, y - 0.065, z), M_STEEL, "Plate", axis="Y", segs=6, bev=0.015, bev_segs=1)

# The rubber: six thick pads, each a hair different, their soft bevels making the dark seams between them.
ph = (PAD_Z1 - PAD_Z0) / PADS
for k in range(PADS):
    w = 1.36 + rng.uniform(-0.02, 0.02)
    dy = rng.uniform(-0.012, 0.012)
    kit.box(f"Pad{k}", (w, PAD_Y1 - PAD_Y0, ph + 0.01), (0, (PAD_Y0 + PAD_Y1) / 2 + dy, PAD_Z0 + ph * (k + 0.5)), M_RUBBER, "Rubber", bev=0.075, segs=3)

# Face plate in hazard stripes, bolted through at the corners.
FY = PAD_Y0 - FACE_T / 2
FW, FH = 1.22, 1.38
kit.box("Face", (FW, FACE_T, FH), (0, FY, H / 2), M_HAZARD, "Plate", bev=0.03, segs=2)
for sx in (-1, 1):
    for sz in (-1, 1):
        x, z = sx * (FW / 2 - 0.14), H / 2 + sz * (FH / 2 - 0.14)
        kit.cylinder(f"FaceWasher{sx}{sz}", 0.085, 0.025, (x, FY - FACE_T / 2 - 0.0125, z), M_STEEL, "Plate", axis="Y", segs=12, bev=0.006, bev_segs=1)
        kit.cylinder(f"FaceBolt{sx}{sz}", 0.065, 0.05, (x, FY - FACE_T / 2 - 0.035, z), M_STEEL, "Plate", axis="Y", segs=6, bev=0.014, bev_segs=1)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "pivot", kit.blend(pivot), "lo", kit.blend(lo), "hi", kit.blend(hi), flush=True)

kit.render_setup(target=(0, 0, 1.1))
if DO_RENDER:
    kit.shoot("hero", (3.6, -5.4, 3.3), lens=50)
    kit.shoot("front", (0, -7.5, 1.2), lens=50)

maps = kit.bake_all(parts, {"Rubber": 512, "Plate": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "glow": [],
    }
)
