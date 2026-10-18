"""FUSE VALLEY — The Quarry's ore head-frame / crane tower, a backdrop landmark on the far cliffs
(docs/maps/QUARRY_BRIEF.md "Backdrop"; GDD §19 maps, Asset Bible §4 props, §1 Quality Bar).

A tall toy timber tower: four splayed legs on sandstone footings, girts every six studs, X cross-braces in every
panel, iron plates and bolts at the joints, a plank deck on top carrying two posts and the big red sheave wheel
(eight spokes, a grooved rim, a gold hub) that faces the front; a jib beam reaching out to the right with a pulley at
its tip, the cable running from the wheel over the pulley and down to a hanging iron ore bucket (bail, hook, gold ore
heaped in it).

MeshPart groups: Timber (legs, girts, braces, deck, posts, jib), Trim (footings, plates, bolts, cable, pulley),
Wheel (the red sheave wheel and its hub), Bucket (the bucket, bail, ore).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_head_frame.py -- [--samples 64] [--no-render]
Out:  art/out/Prop.HeadFrame/  (renders/, export/Prop.HeadFrame.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the wheel's face). Exports at 10 FBX units per stud (parts over
20 studs): studio_import_props.luau scales it by 0.1. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
import qkit  # noqa: E402
from kit import Vector, srgb  # noqa: E402

KEY = "Prop.HeadFrame"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Timber", "Trim", "Wheel", "Bucket"], glow=[])
rng = random.Random(30)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK = srgb("#8E4C24"), srgb("#C27A44"), srgb("#E8B07C"), srgb("#3E1E0C")
DECK, DECK_HI = srgb("#B0683A"), srgb("#DE9860")
IRON, IRON_HI, IRON_EDGE, IRON_BARE = srgb("#33363F"), srgb("#5C6070"), srgb("#8E94A6"), srgb("#9EA2AE")
IRON_LO, IRON_M, IRON_MHI = srgb("#24262E"), srgb("#4A4E5C"), srgb("#B4BCD0")
RED, RED_HI, RED_EDGE = srgb("#D8302A"), srgb("#FF6A50"), srgb("#FFA890")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
STONE, STONE_HI, STONE_CREAM, STONE_SEAM = srgb("#C8784A"), srgb("#E89C68"), srgb("#F6D9A6"), srgb("#9A4E2E")
CABLE, CABLE_HI = srgb("#6A6258"), srgb("#9A9284")


def timber(axis):
    return qkit.mat_timber("Tower", TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK, axis=axis, chip=0.45)


def deck(axis):
    return qkit.mat_timber("Deck", DECK, DECK_HI, TIMBER_BARE, TIMBER_DK, axis=axis, chip=0.45)


M_IRON = kit.mat_paint_metal("Iron", IRON, IRON_HI, IRON_EDGE, IRON_BARE, rough=0.4, chip=0.45, spots=0.8)
M_BRIGHT = kit.mat_metal("BrightIron", IRON_LO, IRON_M, IRON_MHI, rough=(0.22, 0.36), metal=0.3)
M_RED = kit.mat_paint_metal("WheelRed", RED, RED_HI, RED_EDGE, srgb("#8A8C98"), rough=0.3, chip=0.48)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_STONE = qkit.mat_sandstone("Footing", STONE, STONE_HI, STONE_CREAM, STONE_SEAM, strata=0.7, lines=0.6)
M_CABLE = kit.mat_carpet("Cable", CABLE, CABLE_HI, srgb("#3A3430"))
M_ORE = qkit.mat_ore("Ore")
M_BUCKET = kit.mat_paint_metal("Bucket", srgb("#4F6E9E"), srgb("#86AEE0"), srgb("#C4DCFF"), srgb("#C2C6D0"), rough=0.34, chip=0.42)

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
BASE_X, BASE_Y = 4.1, 3.6  # leg feet at (±BASE_X, ±BASE_Y)
TOP_X, TOP_Y = 1.5, 1.7  # leg tops at (±TOP_X, ±TOP_Y)
FOOT_H = 0.9
TOP_Z = 22.0
LEG = 1.1
GIRTS = (5.8, 11.2, 16.6, TOP_Z - 0.3)
WHEEL_R = 3.1
WHEEL_C = Vector((0, 0, TOP_Z + 0.9 + 0.5 + WHEEL_R))  # deck top + post foot + clearance
JIB_TIP = Vector((5.7, 0, TOP_Z + 0.45))
BUCKET_TOP = 13.4


def leg_at(sx, sy, z):
    t = (z - FOOT_H) / (TOP_Z - FOOT_H)
    return Vector((sx * (BASE_X + (TOP_X - BASE_X) * t), sy * (BASE_Y + (TOP_Y - BASE_Y) * t), z))


# ── Legs on sandstone footings ───────────────────────────────────────────────────────────────────────────────────
for sx in (-1, 1):
    for sy in (-1, 1):
        a, b = leg_at(sx, sy, FOOT_H - 0.1), leg_at(sx, sy, TOP_Z + 0.5)
        qkit.beam(f"Leg{sx}{sy}", a, b, LEG, LEG, timber, "Timber", bev=0.09, segs=2, up=(sx, sy, 0))
        f = leg_at(sx, sy, 0)
        kit.box(f"Footing{sx}{sy}", (1.7, 1.7, FOOT_H), (f.x, f.y, FOOT_H / 2), M_STONE, "Trim", bev=0.14, segs=2)
        kit.box(f"FootPlate{sx}{sy}", (1.1, 1.1, 0.12), (f.x + sx * -0.05, f.y + sy * -0.05, FOOT_H + 0.06), M_IRON, "Trim", bev=0.03, segs=1)

# ── Girts round all four sides, X braces in every panel ──────────────────────────────────────────────────────────
SIDES = [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]  # front, right, back, left
for gi, z in enumerate(GIRTS):
    for si, (p, q) in enumerate(SIDES):
        a, b = leg_at(*p, z), leg_at(*q, z)
        n = Vector((p[0] + q[0], p[1] + q[1], 0)).normalized() * 0.55
        qkit.beam(f"Girt{gi}{si}", a + n, b + n, 0.6, 0.65, timber, "Timber", bev=0.06, segs=1, ext=0.35)
for gi in range(len(GIRTS) - 1):
    z0, z1 = GIRTS[gi] + 0.3, GIRTS[gi + 1] - 0.3
    for si, (p, q) in enumerate(SIDES):
        n = Vector((p[0] + q[0], p[1] + q[1], 0)).normalized()
        for k, (u, v) in enumerate(((p, q), (q, p))):
            a, b = leg_at(*u, z0), leg_at(*v, z1)
            off = n * (0.36 + 0.16 * k)
            qkit.beam(f"Brace{gi}{si}{k}", a + off, b + off, 0.46, 0.36, timber, "Timber", bev=0.05, segs=1, up=tuple(n))
        # bolt where the X crosses
        mid = (leg_at(*p, (z0 + z1) / 2) + leg_at(*q, (z0 + z1) / 2)) / 2 + n * 0.78
        kit.rivet(f"CrossBolt{gi}{si}", tuple(mid), tuple(n), M_BRIGHT, "Trim", r=0.14, segs=6)
# iron plates on the front legs at each girt
for gi, z in enumerate(GIRTS[:-1]):
    for sx in (-1, 1):
        c = leg_at(sx, -1, z) + Vector((0, -LEG / 2 - 0.62, 0))
        kit.box(f"GirtPlate{gi}{sx}", (0.9, 0.08, 0.9), tuple(c), M_IRON, "Trim", bev=0.03, segs=1)
        kit.rivet(f"GirtBolt{gi}{sx}", tuple(c + Vector((0, -0.05, 0))), (0, -1, 0), M_BRIGHT, "Trim", r=0.11, segs=6)

# ── The deck, the wheel posts, the jib ───────────────────────────────────────────────────────────────────────────
DECK_Z = TOP_Z + 0.5
for i in range(5):
    y = -2.4 + i * 1.2
    kit.box(f"DeckPlank{i}", (5.2, 1.12, 0.3), (rng.uniform(-0.05, 0.05), y, DECK_Z + 0.15), deck((1, 0, 0)), "Timber", bev=0.06, segs=1)
for s in (-1, 1):
    kit.box(f"DeckBeam{s}", (0.6, 6.4, 0.5), (s * 2.1, 0, DECK_Z - 0.2), timber((0, 1, 0)), "Timber", bev=0.07, segs=1)
DECK_TOP = DECK_Z + 0.3
for s in (-1, 1):
    y = s * 0.75
    # an A-shaped post pair each side of the wheel, holding its axle
    for e in (-1, 1):
        qkit.beam(f"WheelPost{s}{e}", (e * 1.9, y, DECK_TOP), (e * 0.25, y, WHEEL_C.z + 0.25), 0.42, 0.42, timber, "Timber", bev=0.06, segs=1, up=(0, s, 0))
    kit.box(f"Bearing{s}", (0.9, 0.36, 0.8), (0, y, WHEEL_C.z), M_IRON, "Trim", bev=0.06, segs=1)
    qkit.beam(f"PostTie{s}", (-1.05, y, DECK_TOP + 1.3), (1.05, y, DECK_TOP + 1.3), 0.3, 0.3, timber, "Timber", bev=0.04, segs=1)
kit.cylinder("Axle", 0.16, 2.1, tuple(WHEEL_C), M_BRIGHT, "Trim", axis="Y", segs=12, bev=0.03, bev_segs=1)
# the jib: a beam out to the right with a diagonal strut under it, a pulley at the tip
qkit.beam("Jib", (-1.6, 0, JIB_TIP.z), (JIB_TIP.x + 0.5, 0, JIB_TIP.z), 0.55, 0.62, timber, "Timber", bev=0.07, segs=2)
qkit.beam("JibStrut", leg_at(1, -1, 17.8), (4.2, 0, JIB_TIP.z - 0.3), 0.4, 0.4, timber, "Timber", bev=0.05, segs=1)
qkit.beam("JibStrutB", leg_at(1, 1, 17.8), (4.2, 0, JIB_TIP.z - 0.3), 0.4, 0.4, timber, "Timber", bev=0.05, segs=1)
PULLEY = JIB_TIP + Vector((0, 0, -0.75))
for s in (-1, 1):
    kit.box(f"PulleyCheek{s}", (0.9, 0.08, 1.1), tuple(PULLEY + Vector((0, s * 0.2, 0.3))), M_IRON, "Trim", bev=0.03, segs=1)
kit.cylinder("Pulley", 0.42, 0.24, tuple(PULLEY), M_RED, "Trim", axis="Y", segs=16, bev=0.05, bev_segs=1)
kit.cylinder("PulleyHub", 0.14, 0.5, tuple(PULLEY), M_GOLD, "Trim", axis="Y", segs=10, bev=0.03, bev_segs=1)

# ── The big red sheave wheel (faces the front) ───────────────────────────────────────────────────────────────────
RIM_IN = WHEEL_R - 0.62
rim = kit.lathe(
    "WheelRim",
    [(RIM_IN, -0.3), (WHEEL_R + 0.1, -0.3), (WHEEL_R + 0.1, -0.16), (WHEEL_R - 0.14, -0.08), (WHEEL_R - 0.14, 0.08), (WHEEL_R + 0.1, 0.16), (WHEEL_R + 0.1, 0.3), (RIM_IN, 0.3), (RIM_IN, -0.3)],
    M_RED,
    "Wheel",
    segs=40,
    bev=0.05,
)
rim.rotation_euler = (math.radians(90), 0, 0)
rim.location = tuple(WHEEL_C)
for k in range(8):
    a = math.radians(22.5 + 45 * k)
    d = Vector((math.cos(a), 0, math.sin(a)))
    qkit.beam(f"Spoke{k}", WHEEL_C + d * 0.5, WHEEL_C + d * (RIM_IN + 0.08), 0.34, 0.42, lambda _d: M_RED, "Wheel", bev=0.07, segs=1, up=(0, 1, 0))
kit.cylinder("Hub", 0.75, 0.6, tuple(WHEEL_C), M_GOLD, "Wheel", axis="Y", segs=20, bev=0.1, bev_segs=2)
kit.cylinder("HubCap", 0.36, 0.9, tuple(WHEEL_C), M_GOLD, "Wheel", axis="Y", segs=14, bev=0.08, bev_segs=1)
for k in range(6):
    a = math.radians(60 * k)
    for s in (-1, 1):
        kit.rivet(f"HubBolt{k}{s}", tuple(WHEEL_C + Vector((math.cos(a) * 0.56, s * 0.31, math.sin(a) * 0.56))), (0, s, 0), M_BRIGHT, "Wheel", r=0.09, segs=5)

# ── The cable: off the wheel's right side, over the jib pulley, down to the bucket ───────────────────────────────
c_wheel = WHEEL_C + Vector((WHEEL_R - 0.42, 0, 0))
c_top = PULLEY + Vector((0, 0, 0.42))
c_down = PULLEY + Vector((0.42, 0, 0))
qkit.loop_tube("CableA", [tuple(c_wheel), tuple(c_wheel + (c_top - c_wheel) * 0.5 + Vector((0, 0, -0.15))), tuple(c_top + Vector((-0.2, 0, 0.0)))], 0.07, M_CABLE, "Trim", bres=1, closed=False)
qkit.loop_tube("CableB", [tuple(c_down), tuple(Vector((c_down.x, 0, BUCKET_TOP + 1.25)))], 0.07, M_CABLE, "Trim", bres=1, closed=False)
qkit.loop_tube("CableC", [tuple(WHEEL_C + Vector((-(WHEEL_R - 0.42), 0, 0))), tuple(Vector((-(WHEEL_R - 0.42), 0, DECK_TOP)))], 0.07, M_CABLE, "Trim", bres=1, closed=False)

# ── The ore bucket ───────────────────────────────────────────────────────────────────────────────────────────────
BX = c_down.x
B_H, B_R0, B_R1 = 2.3, 1.15, 1.5
bz0 = BUCKET_TOP - B_H
bucket = kit.lathe("Bucket", [(0.0, bz0), (B_R0 - 0.12, bz0), (B_R0, bz0 + 0.1), (B_R1, BUCKET_TOP - 0.1), (B_R1 + 0.06, BUCKET_TOP), (B_R1 - 0.1, BUCKET_TOP + 0.02), (B_R1 - 0.16, BUCKET_TOP - 0.3), (0.0, BUCKET_TOP - 0.3)], M_BUCKET, "Bucket", segs=24)
bucket.location = (BX, 0, 0)
for bi, z in enumerate((bz0 + 0.35, BUCKET_TOP - 0.2)):
    r = B_R0 + (B_R1 - B_R0) * (z - bz0) / B_H
    kit.torus(f"BucketBand{bi}", r + 0.02, 0.07, (BX, 0, z), M_IRON, "Bucket", major=24, minor=5, scale=(1, 1, 1.8))
# the bail (a half ring over the top) and its lugs
bail = kit.torus("Bail", B_R1 + 0.08, 0.07, (0, 0, 0), M_IRON, "Bucket", axis="Y", major=28, minor=5)
bail.location = (BX, 0, BUCKET_TOP)
for s in (-1, 1):
    kit.box(f"BailLug{s}", (0.18, 0.3, 0.45), (BX + s * (B_R1 + 0.06), 0, BUCKET_TOP - 0.1), M_IRON, "Bucket", bev=0.04, segs=1)
kit.torus("Hook", 0.2, 0.06, (BX, 0, BUCKET_TOP + B_R1 + 0.25), M_BRIGHT, "Bucket", axis="Y", major=12, minor=5)
for i, (x, y, r) in enumerate(((0, 0, 0.48), (0.6, 0.25, 0.4), (-0.55, -0.2, 0.42), (0.15, -0.68, 0.36), (-0.2, 0.68, 0.36), (0.75, -0.45, 0.32), (-0.8, 0.4, 0.32))):
    qkit.nugget(f"Ore{i}", r, (BX + x, y, BUCKET_TOP - 0.15 + r * 0.6 - 0.1 * (abs(x) + abs(y))), M_ORE, "Bucket", seed=300 + i)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), "LO", kit.blend(lo), "HI", kit.blend(hi), flush=True)

kit.render_setup(target=(0, 0, 15.0), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (42.0, -62.0, 30.0), lens=50, target=(0.5, 0, 15.0))
    kit.shoot("front", (0, -80.0, 15.0), lens=50, target=(0.5, 0, 15.0))
    kit.shoot("top", (12.0, -22.0, 31.0), lens=45, target=(1.5, 0, 23.5))

maps = kit.bake_all(parts, {"Timber": 2048, "Trim": 1024, "Wheel": 1024, "Bucket": 1024}) if BAKE else {}
ups = qkit.export(parts)
bucket_c = Vector((BX, 0, BUCKET_TOP - B_H / 2))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Backdrop (a timber head-frame / ore crane); GDD §19; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "markers": {
            "WheelCentre": {"blender": kit.blend(WHEEL_C), "roblox_from_pivot": kit.rbx(WHEEL_C, pivot), "radius": WHEEL_R, "axis": "model Z (front-back)"},
            "BucketCentre": {"blender": kit.blend(bucket_c), "roblox_from_pivot": kit.rbx(bucket_c, pivot)},
            "DeckTop": {"height_from_pivot": round(DECK_TOP - lo.z, 4)},
        },
        "front_note": "The wheel faces the front (-Y in Blender = the model's LookVector in Roblox); the jib and bucket "
        "reach out to the model's left in Roblox (Blender +X).",
    }
)
