"""FUSE VALLEY — a bundle of big standing rockets (Asset Bible §4.2 / §4.4 Yard props: near-side dressing).

Four glossy rockets on a round wooden tub base: a tall red one in the middle (wick out of its white nose cone, like the
crate rockets) and three shorter ones round it (blue, yellow, purple) with white stripes, gold bands, white nose cones
and fins, the cluster strapped together with two brass bands with rivet buckles. ~2 studs wide, ~4.5 tall.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_rocket_bundle.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.RocketBundle/  (renders/, export/Prop.RocketBundle.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.RocketBundle"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Rockets", "Trim"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
COLS = [
    (srgb("#E8303A"), srgb("#FF6A5E")),  # centre: red
    (srgb("#2F7BEA"), srgb("#64A8FF")),
    (srgb("#FFC21E"), srgb("#FFE47A")),
    (srgb("#8E46E6"), srgb("#B886FF")),
]
WHITE, WHITE_HI = srgb("#F4F1EC"), srgb("#FFFFFF")
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN = srgb("#E58B3A"), srgb("#FFB25E"), srgb("#FFD7A0"), srgb("#9A4E1C")
DARK, DARK_HI, DARK_BARE, DARK_GRAIN = srgb("#6B3A1E"), srgb("#8E5129"), srgb("#B9784A"), srgb("#3E200E")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")

M_ROCK = [kit.mat_gloss(f"Rocket{i}", a, b, edge=b, rough=0.26, grad=0.45) for i, (a, b) in enumerate(COLS)]
M_WHITE = kit.mat_gloss("White", WHITE, WHITE_HI, rough=0.3, grad=0.3, ao=0.5)
M_GOLD = kit.mat_metal("Brass", GOLD_LO, GOLD, GOLD_HI)
M_WOOD = kit.mat_paint_wood("Tub", WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN, chip=0.46, grain=0.2, rough=(0.5, 0.75))
M_DARK = kit.mat_paint_wood("TubBand", DARK, DARK_HI, DARK_BARE, DARK_GRAIN, chip=0.44, grain=0.16, rough=(0.5, 0.72))
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))

# ── Base: a round wooden tub ─────────────────────────────────────────────────────────────────────────────────────
BR, BH = 0.98, 0.42
kit.lathe("Tub", [(0, 0.0), (BR - 0.06, 0.0), (BR - 0.02, 0.02), (BR, 0.06), (BR - 0.03, BH - 0.04), (BR - 0.07, BH), (0, BH)], M_WOOD, "Trim", segs=32)
for z in (0.1, BH - 0.1):
    kit.torus(f"Hoop{z}", BR - 0.015 - (z / BH) * 0.03, 0.035, (0, 0, z), M_DARK, "Trim", major=32, minor=6, scale=(1, 1, 1.4))

# ── Rockets ──────────────────────────────────────────────────────────────────────────────────────────────────────
OUT_R = 0.5  # the outer rockets' ring radius
SPOTS = [  # (x, y, radius, body top, material index)
    (0.0, 0.0, 0.34, 3.55, 0),
]
for k in range(3):
    a = math.radians(-30 + 120 * k)  # two at the front, one at the back: the red centre shows between
    SPOTS.append((math.cos(a) * OUT_R, math.sin(a) * OUT_R, 0.27, [2.55, 2.85, 2.7][k], k + 1))

for i, (x, y, r, top, mi) in enumerate(SPOTS):
    z0 = BH - 0.02
    L = top - z0
    c = Vector((x, y, 0))
    kit.cylinder(f"Tube{i}", r, L, c + Vector((0, 0, z0 + L / 2)), M_ROCK[mi], "Rockets", segs=16, bev=0.03)
    kit.cylinder(f"Stripe{i}a", r + 0.012, 0.16, c + Vector((0, 0, top - 0.75)), M_WHITE, "Rockets", segs=16, bev=0.02, bev_segs=1)
    kit.cylinder(f"Stripe{i}b", r + 0.012, 0.16, c + Vector((0, 0, z0 + 0.55)), M_WHITE, "Rockets", segs=16, bev=0.02, bev_segs=1)
    kit.cylinder(f"Band{i}", r + 0.02, 0.1, c + Vector((0, 0, top - 0.24)), M_GOLD, "Rockets", segs=16, bev=0.015, bev_segs=1)
    nose_h = r * 2.6
    nose = kit.lathe(
        f"Nose{i}",
        [(0, top - 0.03), (r + 0.05, top - 0.03), (r + 0.05, top + 0.05), (r * 0.78, top + nose_h * 0.38), (r * 0.42, top + nose_h * 0.78), (0.06, top + nose_h * 0.98), (0, top + nose_h)],
        M_WHITE,
        "Rockets",
        segs=16,
    )
    nose.matrix_world = Matrix.Translation(c)
    if i > 0:  # fins on the outside of the outer rockets
        out = Vector((x, y, 0)).normalized()
        for da in (-50, 0, 50):
            n = Matrix.Rotation(math.radians(da), 3, "Z") @ out
            side = Vector((0, 0, 1)).cross(n)
            kit.prism(
                f"Fin{i}{da}",
                [(-0.02, 0.0), (0.28, 0.0), (0.28, 0.12), (-0.02, 0.62)],
                0.05,
                c + n * (r - 0.03) + side * 0.025 + Vector((0, 0, z0 + 0.02)),
                -side,
                M_ROCK[mi],
                "Rockets",
                bev=0.018,
                bev_segs=1,
            )
    else:
        kit.rope("Wick", [(0, 0, top + nose_h - 0.04), (0.04, 0.0, top + nose_h + 0.2), (0.2, 0.04, top + nose_h + 0.38), (0.34, 0.0, top + nose_h + 0.42)], 0.04, M_CORD, "Rockets", res=4, bres=1)

# ── Brass straps round the outer three ──────────────────────────────────────────────────────────────────────────
# The strap follows the cluster's outline (the convex hull of the three outer tubes): a 120-degree arc round each
# tube's outside, joined by straight runs across the gaps, so it hugs the rockets instead of floating as a hoop.
SR = 0.27 + 0.02
hull = []
for k in range(3):
    th = math.radians(-30 + 120 * k)
    cx, cy = math.cos(th) * OUT_R, math.sin(th) * OUT_R
    for t in range(9):
        a = th - math.radians(60) + math.radians(120) * t / 8
        hull.append((cx + math.cos(a) * SR, cy + math.sin(a) * SR))
for j, z in enumerate((1.25, 2.15)):
    kit.ribbon(f"Strap{j}", hull, 0.18, 0.018, M_GOLD, "Trim", Matrix.Translation((0, 0, z)), closed=True, poly=True)
    # Buckle and rivets on the straight front run, between the two front rockets.
    yb = -(OUT_R * 0.5 + SR) - 0.02
    kit.box(f"Buckle{j}", (0.34, 0.06, 0.24), (0, yb, z), M_GOLD, "Trim", bev=0.025, segs=2)
    for dx in (-0.1, 0.1):
        kit.rivet(f"Rivet{j}{dx}", (dx, yb - 0.03, z), (0, -1, 0), M_GOLD, "Trim", r=0.04, squash=0.6, segs=8)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 2.2))
if DO_RENDER:
    kit.shoot("hero", (6.4, -8.6, 5.6), lens=50)
    kit.shoot("front", (0, -11.5, 2.4), lens=50)

maps = kit.bake_all(parts, {"Rockets": 1024, "Trim": 1024}) if BAKE else {}
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
