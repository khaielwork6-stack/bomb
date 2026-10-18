"""FUSE VALLEY — the Depot's Fuse Range practice-bomb dispenser (GDD §19 lobby, Asset Bible §4.3 / §7 lobby props).

A chunky toy vending machine the size of MapDepot's part-built "Dispenser" (2.4 x 3.4 x 2.4) with its practice bomb on
top (the "DispenserBomb" ball, 1.5 across, centred 4.1 up): a glossy red cabinet with rounded corners on a navy plinth,
a yellow-and-black hazard band, a gold top lip with a cradle the bomb sits in, a round cream badge on the front with a
bomb icon, a dark dispensing chute with a gold frame and a pull-out tray, and a gumball-machine crank on the right
side. The bomb is a glossy black iron ball with a brass cap and a curled fuse ending in a lit spark (glow part).

MeshPart groups: Body (cabinet, plinth), Trim (gold, hazard band, chute, crank, badge), Bomb (the ball, cap, fuse),
Spark (Neon glow).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_dispenser.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Dispenser/  (renders/, export/Prop.Dispenser.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the chute). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, box, srgb  # noqa: E402

KEY = "Prop.Dispenser"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Body", "Trim", "Bomb"], glow=["Spark"])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
RED, RED_HI, RED_EDGE = srgb("#D8202C"), srgb("#FF5048"), srgb("#FF9A90")
NAVY, NAVY_HI = srgb("#1E3480"), srgb("#3456C0")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
CREAM, CREAM_HI = srgb("#FFEFD2"), srgb("#FFFFFF")
INK, INK_HI = srgb("#1A1822"), srgb("#4A4658")
CHUTE = srgb("#120E16")
IRON_LO, IRON, IRON_HI = srgb("#14131A"), srgb("#2A2834"), srgb("#8A86A0")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")
ORANGE, ORANGE_HI = srgb("#FF8A1E"), srgb("#FFC060")

M_RED = kit.mat_gloss("Cabinet", RED, RED_HI, edge=RED_EDGE, rough=0.28, grad=0.45)
M_NAVY = kit.mat_gloss("Plinth", NAVY, NAVY_HI, edge=srgb("#7A9AFF"), rough=0.3, grad=0.4)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_HAZ = kit.mat_hazard("Hazard", width=0.32)
M_CREAM = kit.mat_gloss("Cream", CREAM, CREAM_HI, rough=0.4, grad=0.3, ao=0.4)
M_INK = kit.mat_gloss("Ink", INK, INK_HI, rough=0.3, grad=0.4)
M_CHUTE = kit.mat_flat("Chute", CHUTE, 0.8, ao=0.9)
M_ORANGE = kit.mat_gloss("Orange", ORANGE, ORANGE_HI, rough=0.35, grad=0.4)
M_IRON = kit.mat_metal("BombIron", IRON_LO, IRON, IRON_HI, rough=(0.16, 0.26), metal=0.2, edge_gain=1.0)
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))
M_SPARK = kit.mat_emit("Spark", srgb("#FFD84A"), 6.0)

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
W = 2.4  # cabinet width / depth (MapDepot's Dispenser)
PL_H = 0.32  # plinth height
TOP = 3.2  # cabinet top
LIP_T = 0.22
FRONT = -W / 2
BOMB_Z, BOMB_R = 4.1, 0.75

box("Plinth", (W + 0.36, W + 0.36, PL_H), (0, 0, PL_H / 2), M_NAVY, "Body", bev=0.1, segs=3)
box("Cabinet", (W, W, TOP - PL_H + 0.05), (0, 0, PL_H + (TOP - PL_H) / 2 - 0.02), M_RED, "Body", bev=0.22, segs=4)
# hazard band round the bottom, gold lip on top
box("HazardBand", (W + 0.06, W + 0.06, 0.32), (0, 0, PL_H + 0.3), M_HAZ, "Trim", bev=0.06, segs=2)
box("Lip", (W + 0.2, W + 0.2, LIP_T), (0, 0, TOP + LIP_T / 2 - 0.02), M_GOLD, "Trim", bev=0.08, segs=3)
for sx in (-1, 1):
    for sy in (-1, 1):
        kit.rivet(f"LipStud{sx}{sy}", (sx * (W / 2 - 0.18), sy * (W / 2 + 0.1), TOP + 0.09), (0, sy, 0), M_GOLD, "Trim", r=0.06, segs=10)
# the cradle the bomb sits in
kit.cylinder("Cradle", 0.62, 0.12, (0, 0, TOP + LIP_T + 0.04), M_GOLD, "Trim", segs=32, bev=0.04)
kit.torus("CradleRing", 0.56, 0.09, (0, 0, TOP + LIP_T + 0.12), M_GOLD, "Trim", major=32, minor=8)

# Front badge: a gold ring round a cream disc carrying a bomb icon.
BZ = 2.35
kit.cylinder("BadgeDisc", 0.5, 0.06, (0, FRONT - 0.02, BZ), M_CREAM, "Trim", axis="Y", segs=32, bev=0.02)
kit.torus("BadgeRing", 0.52, 0.065, (0, FRONT - 0.04, BZ), M_GOLD, "Trim", axis="Y", major=32, minor=8)
ICON_C = Vector((-0.04, FRONT - 0.05, BZ - 0.06))
kit.cylinder("IconBomb", 0.24, 0.06, tuple(ICON_C), M_INK, "Trim", axis="Y", segs=24, bev=0.02)
kit.box("IconCap", (0.12, 0.06, 0.08), tuple(ICON_C + Vector((0.12, -0.01, 0.2))), M_INK, "Trim", bev=0.02, segs=1, rot=Matrix.Rotation(math.radians(-35), 3, "Y"))
kit.rope("IconFuse", [tuple(ICON_C + Vector((0.16, -0.02, 0.25))), tuple(ICON_C + Vector((0.24, -0.02, 0.36))), tuple(ICON_C + Vector((0.3, -0.02, 0.33)))], 0.022, M_CORD, "Trim", res=4, bres=1)
kit.prism("IconSpark", kit.star_pts(6, 0.11, 0.045), 0.03, ICON_C + Vector((0.33, -0.02, 0.36)), (0, -1, 0), M_ORANGE, "Trim", bev=0.008, bev_segs=1)
kit.sphere("IconShine", 0.05, tuple(ICON_C + Vector((-0.09, -0.04, 0.09))), M_CREAM, "Trim", scale=(1, 0.4, 1), u=10, v=6)

# The chute: a gold frame round a dark opening, a tray sticking out under it.
CZ, CW, CH = 1.2, 1.2, 0.72
kit.prism("ChuteFrame", kit.rounded_rect_pts(CW + 0.22, CH + 0.22, 0.16, steps=4), 0.07, (0, FRONT + 0.01, CZ), (0, -1, 0), M_GOLD, "Trim", bev=0.03, bev_segs=2)
kit.prism("ChuteHole", kit.rounded_rect_pts(CW, CH, 0.1, steps=4), 0.03, (0, FRONT - 0.06, CZ), (0, -1, 0), M_CHUTE, "Trim", bev=0.0)
kit.prism("ChuteFlap", kit.rounded_rect_pts(CW - 0.1, CH * 0.45, 0.06, steps=3), 0.05, (0, FRONT - 0.07, CZ + CH * 0.24), (0, -1, 0), M_RED, "Trim", bev=0.015, bev_segs=1)
kit.cylinder("FlapHinge", 0.04, CW - 0.06, (0, FRONT - 0.11, CZ + CH * 0.45), M_GOLD, "Trim", axis="X", segs=10, bev=0.01, bev_segs=1)
# tray: a rounded gold scoop lip
kit.box("Tray", (CW + 0.1, 0.42, 0.1), (0, FRONT - 0.2, CZ - CH / 2 - 0.08), M_GOLD, "Trim", bev=0.045, segs=2)
kit.box("TrayLip", (CW + 0.1, 0.08, 0.2), (0, FRONT - 0.38, CZ - CH / 2 - 0.0), M_GOLD, "Trim", bev=0.035, segs=2)

# Rivets on the cabinet's front corners.
for sx in (-1, 1):
    for z in (0.95, 2.95):
        kit.rivet(f"FrontRivet{sx}{z}", (sx * (W / 2 - 0.2), FRONT, z), (0, -1, 0), M_GOLD, "Trim", r=0.07, segs=10)

# The crank on the right side (+X): a gold hub plate, an arm, a red knob.
HZ = 2.0
SX = W / 2
kit.cylinder("CrankPlate", 0.42, 0.08, (SX + 0.02, 0, HZ), M_GOLD, "Trim", axis="X", segs=28, bev=0.03)
kit.cylinder("CrankHub", 0.17, 0.2, (SX + 0.14, 0, HZ), M_GOLD, "Trim", axis="X", segs=16, bev=0.04)
arm = kit.box("CrankArm", (0.12, 0.14, 0.6), (0, 0, 0), M_GOLD, "Trim", bev=0.04, segs=2)
arm.matrix_world = Matrix.Translation((SX + 0.24, 0, HZ)) @ Matrix.Rotation(math.radians(-40), 4, "X") @ Matrix.Translation((0, 0, 0.26))
knob_at = Matrix.Translation((SX + 0.24, 0, HZ)) @ Matrix.Rotation(math.radians(-40), 4, "X") @ Vector((0, 0, 0.52))
kit.cylinder("KnobStem", 0.06, 0.24, (knob_at.x + 0.12, knob_at.y, knob_at.z), M_GOLD, "Trim", axis="X", segs=10, bev=0.01, bev_segs=1)
kit.sphere("Knob", 0.13, (knob_at.x + 0.28, knob_at.y, knob_at.z), M_RED, "Trim", scale=(1.15, 1, 1), u=16, v=10)

# The bomb: a glossy black iron ball, a brass cap, a curled fuse and its spark.
kit.sphere("BombBall", BOMB_R, (0, 0, BOMB_Z), M_IRON, "Bomb", u=40, v=24)
kit.cylinder("BombCap", 0.24, 0.2, (0, 0, BOMB_Z + BOMB_R + 0.02), M_GOLD, "Bomb", segs=20, bev=0.05)
kit.torus("BombCapRing", 0.25, 0.04, (0, 0, BOMB_Z + BOMB_R - 0.06), M_GOLD, "Bomb", major=20, minor=6)
FUSE = [(0, 0, BOMB_Z + BOMB_R + 0.08), (0.02, 0.0, BOMB_Z + BOMB_R + 0.3), (0.18, -0.06, BOMB_Z + BOMB_R + 0.48), (0.4, -0.1, BOMB_Z + BOMB_R + 0.52)]
kit.rope("BombFuse", FUSE, 0.055, M_CORD, "Bomb", res=6, bres=2)
SPARK_AT = Vector(FUSE[-1]) + Vector((0.08, -0.02, 0.03))
kit.prism("Spark", kit.star_pts(8, 0.26, 0.1), 0.06, SPARK_AT, (0, -1, 0), M_SPARK, "Spark", bev=0.015, bev_segs=1)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), flush=True)

kit.render_setup(target=(0, 0, 2.8))
if DO_RENDER:
    kit.shoot("hero", (6.4, -9.8, 5.6), lens=50)
    kit.shoot("front", (0, -13.0, 2.9), lens=50)

maps = kit.bake_all(parts, {"Body": 1024, "Trim": 1024, "Bomb": 512}) if BAKE else {}
kit.export_fbx(parts)
bomb_c = Vector((0, 0, BOMB_Z))
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "cabinet_size_studs": [W, TOP + LIP_T, W],
        "parts": maps,
        "glow": ["Spark"],
        "markers": {
            "BombCentre": {"blender": kit.blend(bomb_c), "roblox_from_pivot": kit.rbx(bomb_c, pivot)},
            "Spark": {"blender": kit.blend(SPARK_AT), "roblox_from_pivot": kit.rbx(SPARK_AT, pivot)},
        },
        "front_note": "The chute faces the front (-Y in Blender = the model's LookVector in Roblox); the crank is on the right.",
    }
)
