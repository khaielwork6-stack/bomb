"""FUSE VALLEY — the Fireworks Yard's firework crate (Asset Bible §4.2 / §4.4 Yard props: field cover + dressing).

A waist-high cover crate, 3.2 x 3.2 footprint, 2.6 tall: chunky orange planks over a dark core (the gaps read as
seams), dark corner battens and top / bottom rails with nail heads, rope handles on both sides, a cream "FIREWORKS"
label panel with a red border and modelled red letters (Luckiest Guy, the game's display face) on the front and the
back, and five glossy rockets (white nose cones, gold bands, cord wicks) standing in a straw-packed open top.
The rockets are their own MeshPart ("Rockets"), so a builder can delete them for a closed / stacked crate.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_firework_crate.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.FireworkCrate/  (renders/, export/Prop.FireworkCrate.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import glob
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.FireworkCrate"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Body", "Trim", "Label", "Rockets"], glow=[])
rng = random.Random(1077)


def display_font():
    """Luckiest Guy (OFL), the game's display face, from the local Roblox install; Blender's font if it's missing."""
    pats = [os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\LuckiestGuy-Regular.ttf")]
    for p in pats:
        hits = sorted(glob.glob(p))
        if hits:
            return bpy.data.fonts.load(hits[-1])
    print("WARNING: LuckiestGuy-Regular.ttf not found, using Blender's built-in font", flush=True)
    return None


# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN = srgb("#E58B3A"), srgb("#FFB25E"), srgb("#FFD7A0"), srgb("#9A4E1C")
WOOD2, WOOD2_HI = srgb("#D97A2E"), srgb("#F7A350")
DARK, DARK_HI, DARK_BARE, DARK_GRAIN = srgb("#6B3A1E"), srgb("#8E5129"), srgb("#B9784A"), srgb("#3E200E")
CORE = srgb("#3A2012")
STRAW, STRAW_HI = srgb("#E8C46A"), srgb("#FFE6A0")
CREAM, CREAM_HI = srgb("#FFEFD2"), srgb("#FFFFFF")
RED, RED_HI, RED_EDGE = srgb("#D62430"), srgb("#FF4A4A"), srgb("#FF8C84")
IRON_LO, IRON, IRON_HI = srgb("#2A2C34"), srgb("#4A4E5C"), srgb("#9AA2B8")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
ROCKET_COLS = [
    (srgb("#E8303A"), srgb("#FF6A5E")),
    (srgb("#2F7BEA"), srgb("#64A8FF")),
    (srgb("#FFC21E"), srgb("#FFE47A")),
    (srgb("#8E46E6"), srgb("#B886FF")),
    (srgb("#2DB84E"), srgb("#6EE884")),
]

M_WOOD = kit.mat_paint_wood("Planks", WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN, chip=0.46, grain=0.2, rough=(0.5, 0.75))
M_WOOD2 = kit.mat_paint_wood("Planks2", WOOD2, WOOD2_HI, WOOD_BARE, WOOD_GRAIN, chip=0.46, grain=0.2, rough=(0.5, 0.75))
M_DARK = kit.mat_paint_wood("Battens", DARK, DARK_HI, DARK_BARE, DARK_GRAIN, chip=0.44, grain=0.16, rough=(0.5, 0.72))
M_CORE = kit.mat_flat("Core", CORE, 0.85, ao=0.8)
M_STRAW = kit.mat_carpet("Straw", STRAW, STRAW_HI, srgb("#B88A36"))
M_CREAM = kit.mat_gloss("Cream", CREAM, CREAM_HI, rough=0.5, grad=0.3, ao=0.4)
M_RED = kit.mat_gloss("Red", RED, RED_HI, edge=RED_EDGE, rough=0.35, grad=0.4)
M_IRON = kit.mat_metal("Iron", IRON_LO, IRON, IRON_HI, rough=(0.25, 0.4), metal=0.3)
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_WHITE = kit.mat_gloss("White", srgb("#F4F1EC"), CREAM_HI, rough=0.3, grad=0.3, ao=0.5)
M_ROCKETS = [kit.mat_gloss(f"Rocket{i}", a, b, edge=b, rough=0.28, grad=0.45) for i, (a, b) in enumerate(ROCKET_COLS)]

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
W, H = 3.2, 2.6  # footprint W x W, height H
HALF = W / 2
CORE_H = 1.36  # the core's outer half-width (planks sit on it)
PL_T = 0.1  # plank thickness
RAIL_T = 0.1
BAT = 0.4  # batten section
BAT_C = HALF - BAT / 2
FILL_Z = H - 0.36  # straw level inside the open top

# The core: an open-top box with a dark inside; the plank gaps show it as seams.
kit.hollow_box("Core", (CORE_H * 2, CORE_H * 2, H - 0.06), (0, 0, (H - 0.06) / 2 + 0.03), 0.16, H - 0.06 - (FILL_Z - 0.03), M_CORE, "Body", bev=0.03, segs=2)
kit.box("Fill", (CORE_H * 2 - 0.3, CORE_H * 2 - 0.3, 0.24), (0, 0, FILL_Z - 0.06), M_STRAW, "Body", bev=0.08, segs=2)
# Straw tufts, so the packing reads as loose shredded paper rather than a flat lid.
for i, (x, y, s) in enumerate(((-0.75, -0.8, 0.42), (0.8, -0.85, 0.38), (0.85, 0.1, 0.44), (-0.85, 0.05, 0.4), (-0.05, 0.85, 0.42))):
    kit.sphere(f"Tuft{i}", s, (x, y, FILL_Z + 0.02), M_STRAW, "Body", scale=(1.15, 1.0, 0.32), u=8, v=5)

# Planks: three per side, running between the battens, a hair of gap between them.
PL_H = (H - 0.08) / 3
for side, (nx, ny) in enumerate(((0, -1), (0, 1), (-1, 0), (1, 0))):
    for k in range(3):
        z = 0.04 + PL_H * (k + 0.5)
        mat = M_WOOD if (k + side) % 2 == 0 else M_WOOD2
        d = CORE_H + PL_T / 2
        length = 2 * (BAT_C - 0.02)
        if nx == 0:
            kit.box(f"Plank{side}{k}", (length, PL_T, PL_H - 0.05), (0, ny * d, z), mat, "Body", bev=0.035, segs=1)
        else:
            kit.box(f"Plank{side}{k}", (PL_T, length, PL_H - 0.05), (nx * d, 0, z), mat, "Body", bev=0.035, segs=1)

# Corner battens (full height) and the top / bottom rails between them, nails at the rail ends.
for sx in (-1, 1):
    for sy in (-1, 1):
        kit.box(f"Batten{sx}{sy}", (BAT, BAT, H), (sx * BAT_C, sy * BAT_C, H / 2), M_DARK, "Trim", bev=0.06, segs=2)
RAIL_D = CORE_H + PL_T + RAIL_T / 2
RAIL_L = 2 * (BAT_C - BAT / 2) + 0.04
for zc in (0.2, H - 0.2):
    for s in (-1, 1):
        kit.box(f"RailF{s}{zc}", (RAIL_L, RAIL_T, 0.32), (0, s * RAIL_D, zc), M_DARK, "Trim", bev=0.035, segs=2)
        kit.box(f"RailS{s}{zc}", (RAIL_T, RAIL_L, 0.32), (s * RAIL_D, 0, zc), M_DARK, "Trim", bev=0.035, segs=2)
        for e in (-1, 1):
            off = e * (RAIL_L / 2 - 0.16)
            kit.rivet(f"NailF{s}{zc}{e}", (off, s * (RAIL_D + RAIL_T / 2), zc), (0, s, 0), M_IRON, "Trim", r=0.05, squash=0.5, segs=6)
            if zc > 1:  # the sides only get nails on the top rail (the rope handles carry the bottom half)
                kit.rivet(f"NailS{s}{zc}{e}", (s * (RAIL_D + RAIL_T / 2), off, zc), (s, 0, 0), M_IRON, "Trim", r=0.05, squash=0.5, segs=6)

# Rope handles on the two sides: iron eyelets and a drooping cord loop.
for s in (-1, 1):
    x = s * (CORE_H + PL_T)
    for e in (-1, 1):
        kit.cylinder(f"Eye{s}{e}", 0.075, 0.08, (x + s * 0.04, e * 0.5, 1.72), M_IRON, "Trim", axis="X", segs=8, bev=0.015, bev_segs=1)
    kit.rope(
        f"Rope{s}",
        [(x + s * 0.06, -0.5, 1.72), (x + s * 0.13, -0.32, 1.5), (x + s * 0.15, 0.0, 1.44), (x + s * 0.13, 0.32, 1.5), (x + s * 0.06, 0.5, 1.72)],
        0.055,
        M_CORD,
        "Trim",
        res=4,
        bres=1,
    )
    for e in (-1, 1):
        kit.sphere(f"Knot{s}{e}", 0.085, (x + s * 0.07, e * 0.5, 1.72), M_CORD, "Trim", u=6, v=4)

# Label panels front (-Y) and back (+Y): red border plate, cream face, modelled "FIREWORKS".
FONT = display_font()
LBL_W, LBL_H, LBL_Z = 2.2, 0.7, 1.3
for s in (-1, 1):
    n = Vector((0, s, 0))
    base = Vector((0, s * (CORE_H + PL_T), LBL_Z))
    kit.prism(f"LabelBack{s}", kit.rounded_rect_pts(LBL_W, LBL_H, 0.12, steps=4), 0.05, base, n, M_RED, "Label", bev=0.02, bev_segs=2)
    kit.prism(f"LabelFace{s}", kit.rounded_rect_pts(LBL_W - 0.12, LBL_H - 0.12, 0.08, steps=4), 0.03, base + n * 0.05, n, M_CREAM, "Label", bev=0.012, bev_segs=1)
    # Flat painted letters a hair proud of the face (stencil paint; no extruded sides to spend triangles on).
    t = kit.text(f"Word{s}", "FIREWORKS", 0.4, 0.0, M_RED, "Label", base + n * 0.095 + Vector((0, 0, -0.01)), normal=n, bev=0.0)
    if FONT:
        t.data.font = FONT
    t.data.resolution_u = 3
    t.data.fill_mode = "FRONT"
    t.data.space_character = 1.04

# Rockets standing in the straw.
SPOTS = [(-0.6, -0.42, 1.05), (0.52, -0.55, 0.85), (0.05, 0.3, 1.35), (-0.62, 0.58, 0.8), (0.66, 0.46, 1.05)]
for i, (x, y, h) in enumerate(SPOTS):
    r = rng.uniform(0.17, 0.2)
    lean = Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 1)).normalized()
    base = Vector((x, y, FILL_Z - 0.15))
    top_len = (H - FILL_Z) + h
    rot = Vector((0, 0, 1)).rotation_difference(lean).to_matrix().to_4x4()
    place = Matrix.Translation(base) @ rot
    mat = M_ROCKETS[i % len(M_ROCKETS)]
    body = kit.cylinder(f"Tube{i}", r, top_len, (0, 0, top_len / 2), mat, "Rockets", segs=12, bev=0.025)
    body.matrix_world = place
    band = kit.cylinder(f"Band{i}", r + 0.018, 0.09, (0, 0, top_len - 0.2), M_GOLD, "Rockets", segs=12, bev=0.015, bev_segs=1)
    band.matrix_world = place
    stripe = kit.cylinder(f"Stripe{i}", r + 0.012, 0.12, (0, 0, top_len - 0.5), M_WHITE, "Rockets", segs=12, bev=0.02, bev_segs=1)
    stripe.matrix_world = place
    nose = kit.lathe(
        f"Nose{i}",
        [(0, top_len - 0.02), (r + 0.04, top_len - 0.02), (r + 0.04, top_len + 0.04), (r * 0.72, top_len + 0.2), (r * 0.36, top_len + 0.36), (0.05, top_len + 0.43), (0, top_len + 0.44)],
        M_WHITE,
        "Rockets",
        segs=12,
    )
    nose.matrix_world = place
    wick = kit.rope(
        f"Wick{i}",
        [(0, 0, top_len + 0.4), (0.05, 0.01, top_len + 0.6), (0.2, 0.03, top_len + 0.74)],
        0.03,
        M_CORD,
        "Rockets",
        res=3,
        bres=1,
    )
    wick.matrix_world = place

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 1.75))
if DO_RENDER:
    kit.shoot("hero", (7.0, -9.2, 6.0), lens=50)
    kit.shoot("front", (0, -13, 2.0), lens=55)

maps = kit.bake_all(parts, {"Body": 1024, "Trim": 1024, "Label": 1024, "Rockets": 1024}) if BAKE else {}
kit.export_fbx(parts)
# The crate body (no rockets) for the collision box.
body_h = H
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "hit_size_studs": [W, body_h, W],
        "parts": maps,
        "removable": ["Rockets"],
        "glow": [],
    }
)
