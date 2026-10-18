"""FUSE VALLEY — the winners' Podium (GDD round-end winners / lobby display, Asset Bible §7 lobby props).

A 3-step podium ~14 studs wide: 1st in the centre (tallest), 2nd on the left, 3rd on the right as seen from the front.
Glossy royal-blue steps with gold top lips and base bands, gold studs, red velvet carpet tops with gold piping, and
big raised numerals on the fronts (gold 1, silver 2, bronze 3) with a cream outline. The manifest records the three
standing spots (top centre of each carpet).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_podium.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Podium/  (renders/, export/Prop.Podium.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, box, srgb  # noqa: E402

KEY = "Prop.Podium"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Steps", "Trim", "Carpet", "Numerals"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
BLUE, BLUE_HI, BLUE_EDGE = srgb("#2550D8"), srgb("#4C7CFF"), srgb("#9DB8FF")
VELVET, VELVET_HI, VELVET_DK = srgb("#C0142E"), srgb("#EE4258"), srgb("#700618")
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
SILV_LO, SILV, SILV_HI = srgb("#8E9AAD"), srgb("#D6DEE8"), srgb("#FFFFFF")
BRON_LO, BRON, BRON_HI = srgb("#9A4E20"), srgb("#E08A4A"), srgb("#FFD2A8")
CREAM, CREAM_HI = srgb("#FFF1D8"), srgb("#FFFFFF")

M_BLUE = kit.mat_gloss("BlueGloss", BLUE, BLUE_HI, edge=BLUE_EDGE, rough=0.3, grad=0.45)
M_VELVET = kit.mat_carpet("Velvet", VELVET, VELVET_HI, VELVET_DK)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_SILVER = kit.mat_metal("Silver", SILV_LO, SILV, SILV_HI, rough=(0.18, 0.3), metal=0.3)
M_BRONZE = kit.mat_metal("Bronze", BRON_LO, BRON, BRON_HI, rough=(0.2, 0.34), metal=0.3)
M_CREAM = kit.mat_gloss("Cream", CREAM, CREAM_HI, rough=0.4, grad=0.3, ao=0.3)
M_NAVY = kit.mat_gloss("Navy", srgb("#152C86"), srgb("#2443B8"), rough=0.3, grad=0.4)

# Chunky balloon numerals: centre-line strokes in a unit-high box (x right, y up).
DIGITS = {
    "1": [[(-0.22, 0.25), (0.04, 0.46), (0.04, -0.44)], [(-0.24, -0.46), (0.3, -0.46)]],
    "2": [kit.catmull([(-0.28, 0.22), (-0.13, 0.43), (0.08, 0.47), (0.26, 0.34), (0.26, 0.12), (0.1, -0.1)], n=6, closed=False) + [(-0.28, -0.46), (0.3, -0.46)]],
    "3": [
        kit.catmull([(-0.27, 0.33), (-0.08, 0.47), (0.17, 0.45), (0.27, 0.27), (0.14, 0.07), (-0.06, 0.03)], n=6, closed=False),
        kit.catmull([(-0.06, 0.03), (0.19, -0.02), (0.3, -0.22), (0.19, -0.43), (-0.04, -0.48), (-0.28, -0.36)], n=6, closed=False),
    ],
}


def numeral(place, centre, height, mat):
    m = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Scale(height, 4)
    kit.stroke(f"Num{place}", DIGITS[place], 0.105, mat, "Numerals", m, flat=0.55)
    back = Matrix.Translation(Vector(centre) + Vector((0, 0.07, 0))) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Scale(height, 4)
    kit.stroke(f"NumOutline{place}", DIGITS[place], 0.105 + 0.05 / height * 1.2, M_CREAM, "Numerals", back, flat=0.3)

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
SW = 4.4  # step width
D = 4.0  # depth
CARPET_T = 0.12
STEPS = [  # place, x, height, numeral material, numeral size, band overhang (different per step so faces never coincide)
    ("1", 0.0, 3.0, M_GOLD, 1.12, 0.07),
    ("2", -SW, 2.2, M_SILVER, 0.8, 0.05),
    ("3", SW, 1.6, M_BRONZE, 0.53, 0.05),
]
spots = {}
for place, x, h, m_num, rm, ov in STEPS:
    w = SW if place == "1" else SW - 0.02
    box(f"Body{place}", (w, D, h), (x, 0, h / 2), M_BLUE, "Steps", bev=0.14, segs=4)
    # Gold lip at the top and band at the bottom, a row of studs on the lip.
    box(f"Lip{place}", (w + 2 * ov, D + 2 * ov, 0.24), (x, 0, h - 0.12), M_GOLD, "Trim", bev=0.07, segs=3)
    box(f"Band{place}", (w + 2 * ov, D + 2 * ov, 0.2), (x, 0, 0.1), M_GOLD, "Trim", bev=0.06, segs=3)
    for k in range(5):
        sx = x - w / 2 + 0.45 + k * (w - 0.9) / 4
        kit.rivet(f"LipStud{place}{k}", (sx, -D / 2 - ov, h - 0.12), (0, -1, 0), M_GOLD, "Trim", r=0.07)
    # Carpet top with gold piping.
    cw, cd = w - 0.34, D - 0.34
    box(f"Carpet{place}", (cw, cd, CARPET_T), (x, 0, h + CARPET_T / 2 - 0.01), M_VELVET, "Carpet", bev=0.05, segs=3)
    for sgn in (-1, 1):
        kit.cylinder(f"PipeX{place}{sgn}", 0.045, cw, (x, sgn * cd / 2, h + 0.02), M_GOLD, "Trim", axis="X", segs=12, bev=0)
        kit.cylinder(f"PipeY{place}{sgn}", 0.045, cd, (x + sgn * cw / 2, 0, h + 0.02), M_GOLD, "Trim", axis="Y", segs=12, bev=0)
    # A gold-rimmed navy medallion on the front carrying the big balloon numeral (cream outline behind it).
    zc = (0.2 + h - 0.24) / 2
    front = -D / 2
    kit.cylinder(f"Medal{place}", rm, 0.12, (x, front - 0.04, zc), M_NAVY, "Steps", axis="Y", segs=64, bev=0.03)
    kit.torus(f"MedalRim{place}", rm, 0.075, (x, front - 0.1, zc), M_GOLD, "Trim", axis="Y", major=64, minor=12)
    numeral(place, (x, front - 0.2, zc), rm * 1.48, m_num)
    # Gold pilasters on the exposed front corners.
    for sgn in (-1, 1):
        if (place == "2" and sgn == 1) or (place == "3" and sgn == -1):
            continue
        box(f"Pilaster{place}{sgn}", (0.2, 0.2, h - 0.42), (x + sgn * (w / 2 - 0.03), front + 0.03, h / 2), M_GOLD, "Trim", bev=0.06, segs=3)
    spots[place] = Vector((x, 0, h + CARPET_T - 0.01))

# Gold stars on the exposed side faces.
for name, xs, sgn, zc, r in (("2", -6.59, -1, 1.1, 0.5), ("3", 6.59, 1, 0.8, 0.36), ("1L", -SW / 2, -1, 2.48, 0.22), ("1R", SW / 2, 1, 2.18, 0.4)):
    kit.prism(f"SideStar{name}", kit.star_pts(5, r, r * 0.46), 0.06, (xs + sgn * 0.004, 0, zc), (sgn, 0, 0), M_GOLD, "Trim", bev=0.03, bev_segs=2)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 1.5))
if DO_RENDER:
    kit.shoot("hero", (11.0, -16.5, 8.0), lens=45)
    kit.shoot("front", (0, -24, 2.0), lens=50)
    kit.shoot("high", (-8.0, -14.0, 14.0), lens=40)

maps = kit.bake_all(parts, {"Steps": 1024, "Trim": 1024, "Carpet": 1024, "Numerals": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "spots": {
            p: {"blender": kit.blend(v), "roblox_from_pivot": kit.rbx(v, pivot)} for p, v in spots.items()
        },
        "spots_note": "Top centre of each carpet: '1' centre (tallest), '2' left, '3' right as seen from the front (-Y in Blender, -Z in Roblox).",
        "parts": maps,
        "glow": [],
    }
)
