"""FUSE VALLEY — The Quarry's mine cart, the field's waist-high cover (docs/maps/QUARRY_BRIEF.md "Cover"; GDD §19 maps,
Asset Bible §4 props, §1 Quality Bar).

A chunky toy ore tub on a short rail stub: a rounded, flared steel tub (painted blue-grey steel, worn bare on the
edges) with a rolled iron rim, riveted iron straps down its sides and ends, sitting on an iron chassis with timber
bumpers at both ends; four chunky wheels (dark iron tyres with flanges, red-painted discs, gold hub caps) on iron
axles in bearing blocks; a heap of gold ore (an amber mound with faceted gold nuggets) piled in the tub. The rail stub
is two steel rails on four timber sleepers with spike heads, running along the cart's length.

MeshPart groups: Tub, Trim (rim, straps, rivets, chassis, axles, bearing blocks, bumpers), Wheels, Ore, Rails.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_mine_cart.py -- [--samples 64] [--no-render]
Out:  art/out/Prop.MineCart/  (renders/, export/Prop.MineCart.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the cart's long side). The rails run along Blender X (= the model's
right/left axis in Roblox). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import kit  # noqa: E402
import qkit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.MineCart"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Tub", "Trim", "Wheels", "Ore", "Rails"], glow=[])
rng = random.Random(2026)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
STEEL, STEEL_HI, STEEL_EDGE, STEEL_BARE = srgb("#4F6E9E"), srgb("#86AEE0"), srgb("#C4DCFF"), srgb("#C2C6D0")
IRON, IRON_HI, IRON_EDGE, IRON_BARE = srgb("#33363F"), srgb("#5C6070"), srgb("#8E94A6"), srgb("#9EA2AE")
IRON_LO, IRON_M, IRON_MHI = srgb("#24262E"), srgb("#4A4E5C"), srgb("#B4BCD0")
RED, RED_HI, RED_EDGE = srgb("#D8302A"), srgb("#FF6A50"), srgb("#FFA890")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
AMBER_LO, AMBER, AMBER_HI = srgb("#A8640E"), srgb("#E09A22"), srgb("#FFD060")
TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK = srgb("#B8683A"), srgb("#E09058"), srgb("#F0C090"), srgb("#5E3018")

M_TUB = kit.mat_paint_metal("TubSteel", STEEL, STEEL_HI, STEEL_EDGE, STEEL_BARE, rough=0.34, chip=0.42, spots=0.74)
M_IRON = kit.mat_paint_metal("Iron", IRON, IRON_HI, IRON_EDGE, IRON_BARE, rough=0.38, chip=0.45, spots=0.8)
M_BRIGHT = kit.mat_metal("BrightIron", IRON_LO, IRON_M, IRON_MHI, rough=(0.22, 0.36), metal=0.3)
M_RED = kit.mat_paint_metal("WheelRed", RED, RED_HI, RED_EDGE, srgb("#8A8C98"), rough=0.3, chip=0.5)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_ORE = qkit.mat_ore("Nuggets")
M_MOUND = kit.mat_metal("OreMound", AMBER_LO, AMBER, AMBER_HI, rough=(0.3, 0.5), metal=0.25, edge_gain=3.0, bump=0.45)


def timber(axis):
    return qkit.mat_timber("Timber", TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK, axis=axis)


# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
SLEEPER_H, FLANGE_H, HEAD_H = 0.16, 0.05, 0.16
RAIL_TOP = SLEEPER_H + FLANGE_H + HEAD_H  # 0.37
GAUGE = 0.9  # rail centre lines at y = ±GAUGE
RAIL_L = 5.4
WHEEL_R, WHEEL_W, WHEEL_X = 0.42, 0.2, 1.05
AXLE_Z = RAIL_TOP + WHEEL_R
TUB_Z0, TUB_Z1 = 1.05, 2.28  # tub bottom / top (rim)
ORE_FLOOR = 1.95

# ── Rails: two steel rails on four timber sleepers, spike heads at every crossing ───────────────────────────────
for i, x in enumerate((-2.1, -0.7, 0.7, 2.1)):
    x += rng.uniform(-0.05, 0.05)
    yaw = Matrix.Rotation(math.radians(rng.uniform(-3, 3)), 3, "Z")
    kit.box(f"Sleeper{i}", (0.6, 2.7, SLEEPER_H), (x, 0, SLEEPER_H / 2), timber((0, 1, 0)), "Rails", bev=0.05, segs=1, rot=yaw)
    for s in (-1, 1):
        for e in (1,):
            kit.rivet(f"Spike{i}{s}{e}", (x, s * GAUGE + s * 0.24, SLEEPER_H + 0.01), (0, 0, 1), M_BRIGHT, "Rails", r=0.07, squash=0.45, segs=5)
for s in (-1, 1):
    y = s * GAUGE
    kit.box(f"RailFoot{s}", (RAIL_L, 0.34, FLANGE_H), (0, y, SLEEPER_H + FLANGE_H / 2), M_BRIGHT, "Rails", bev=0.02, segs=1)
    kit.box(f"RailWeb{s}", (RAIL_L, 0.1, HEAD_H * 0.6), (0, y, SLEEPER_H + FLANGE_H + HEAD_H * 0.3), M_BRIGHT, "Rails", bev=0.02, segs=1)
    kit.box(f"RailHead{s}", (RAIL_L, 0.2, HEAD_H * 0.55), (0, y, RAIL_TOP - HEAD_H * 0.275), M_BRIGHT, "Rails", bev=0.035, segs=1)

# ── Wheels and axles ─────────────────────────────────────────────────────────────────────────────────────────────
for wx in (-WHEEL_X, WHEEL_X):
    kit.cylinder(f"Axle{wx}", 0.075, 2 * GAUGE + 0.5, (wx, 0, AXLE_Z), M_BRIGHT, "Trim", axis="Y", segs=10, bev=0.02, bev_segs=1)
    for s in (-1, 1):
        y = s * GAUGE
        kit.cylinder(f"Tyre{wx}{s}", WHEEL_R, WHEEL_W, (wx, y, AXLE_Z), M_IRON, "Wheels", axis="Y", segs=22, bev=0.05, bev_segs=1)
        kit.cylinder(f"Flange{wx}{s}", WHEEL_R + 0.09, 0.07, (wx, y - s * (WHEEL_W / 2 + 0.02), AXLE_Z), M_IRON, "Wheels", axis="Y", segs=22, bev=0.025, bev_segs=1)
        kit.cylinder(f"Disc{wx}{s}", WHEEL_R - 0.1, WHEEL_W + 0.06, (wx, y + s * 0.01, AXLE_Z), M_RED, "Wheels", axis="Y", segs=18, bev=0.03, bev_segs=1)
        kit.cylinder(f"Hub{wx}{s}", 0.13, 0.16, (wx, y + s * (WHEEL_W / 2 + 0.08), AXLE_Z), M_GOLD, "Wheels", axis="Y", segs=12, bev=0.04, bev_segs=1)
        for k in range(4):
            a = math.radians(45 + 90 * k)
            p = Vector((wx + math.cos(a) * 0.21, y + s * (WHEEL_W / 2 + 0.04), AXLE_Z + math.sin(a) * 0.21))
            kit.rivet(f"WheelBolt{wx}{s}{k}", tuple(p), (0, s, 0), M_GOLD, "Wheels", r=0.045, squash=0.6, segs=4)
        # bearing block on the chassis rail, inboard of the wheel
        kit.box(f"Bearing{wx}{s}", (0.42, 0.24, 0.42), (wx, s * 0.62, AXLE_Z + 0.08), M_IRON, "Trim", bev=0.06, segs=1)

# ── Chassis: two iron rails under the tub, timber bumpers at both ends ───────────────────────────────────────────
for s in (-1, 1):
    kit.box(f"Chassis{s}", (3.3, 0.22, 0.24), (0, s * 0.62, TUB_Z0 - 0.05), M_IRON, "Trim", bev=0.05, segs=1)
for e in (-1, 1):
    kit.box(f"Bumper{e}", (0.34, 1.7, 0.4), (e * 1.72, 0, TUB_Z0 - 0.02), timber((0, 1, 0)), "Trim", bev=0.08, segs=2)
    for s in (-1, 1):
        kit.rivet(f"BumperBolt{e}{s}", (e * 1.89, s * 0.55, TUB_Z0 - 0.02), (e, 0, 0), M_BRIGHT, "Trim", r=0.06, segs=6)
    # a coupling hook in the middle of each bumper
    kit.torus(f"Hook{e}", 0.12, 0.04, (e * 1.95, 0, TUB_Z0 - 0.08), M_BRIGHT, "Trim", axis="Y", major=10, minor=5)


# ── The tub: a flared rounded box lofted ring by ring, open at the top, inner wall down to the ore ───────────────
def loft(name, rings, mat, group, steps=5, cap_bottom=True, cap_top=True):
    bm = bmesh.new()
    loops = []
    for w, l, r, z in rings:
        loops.append([bm.verts.new(p) for p in qkit.rounded_rect3(w, l, r, z, steps=steps)])
    n = len(loops[0])
    for a, b in zip(loops, loops[1:]):
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap_bottom:
        bm.faces.new(list(reversed(loops[0])))
    if cap_top:
        bm.faces.new(list(loops[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = kit.give(kit.mesh_obj(name, bm, group), mat)
    kit.bevel(o, 0.05, 2, angle=35)
    return kit.smooth(o)


def tub_size(z):
    """Outer (w, l, r) of the tub at height z (linear flare from the bottom to the rim)."""
    t = (z - 1.13) / (TUB_Z1 - 1.13)
    return 2.6 + (3.42 - 2.6) * t, 1.9 + (2.84 - 1.9) * t, 0.35 + 0.2 * t


TUB_RINGS = [
    (2.42, 1.72, 0.26, TUB_Z0),
    (2.6, 1.9, 0.35, 1.13),
    (*tub_size(1.7), 1.7),
    (3.42, 2.84, 0.55, TUB_Z1),
    (3.16, 2.58, 0.45, TUB_Z1),
    (2.94, 2.36, 0.41, ORE_FLOOR),
]
loft("Tub", TUB_RINGS, M_TUB, "Tub")
qkit.loop_tube("Rim", qkit.rounded_rect3(3.36, 2.78, 0.52, TUB_Z1 + 0.02, steps=5), 0.12, M_IRON, "Trim", bres=2)


def strap(name, side, at, width):
    """An iron strap down the tub's flared side `side` ((0,±1) long side, (±1,0) end), at offset `at` along it."""
    sx, sy = side
    z0, z1 = 1.18, TUB_Z1 - 0.1
    w0, l0, _ = tub_size(z0)
    w1, l1, _ = tub_size(z1)
    if sy:
        p0 = Vector((at, sy * l0 / 2, z0))
        p1 = Vector((at, sy * l1 / 2, z1))
    else:
        p0 = Vector((sx * w0 / 2, at, z0))
        p1 = Vector((sx * w1 / 2, at, z1))
    d = (p1 - p0).normalized()
    out = Vector((sx, sy, 0))
    nrm = (out - d * out.dot(d)).normalized()
    across = d.cross(nrm).normalized()
    rot = Matrix((across, nrm, d)).transposed()
    mid = (p0 + p1) / 2 + nrm * 0.035
    kit.box(name, (width, 0.07, (p1 - p0).length + 0.12), tuple(mid), M_IRON, "Trim", bev=0.03, segs=1, rot=rot)
    for k, t in enumerate((0.12, 0.88)):
        p = p0 + (p1 - p0) * t + nrm * 0.075
        kit.rivet(f"{name}Rivet{k}", tuple(p), tuple(nrm), M_BRIGHT, "Trim", r=0.07, segs=6)


for s in (-1, 1):
    for x in (-0.78, 0.78):
        strap(f"SideStrap{s}{x}", (0, s), x, 0.3)
    strap(f"EndStrap{s}", (s, 0), 0.0, 0.3)

# ── The ore: an amber mound heaped above the rim, gold nuggets on it ─────────────────────────────────────────────
MOUND_C, MOUND_R = Vector((0, 0, ORE_FLOOR + 0.02)), Vector((1.62, 1.32, 0.55))
mb = bmesh.new()
bmesh.ops.create_icosphere(mb, subdivisions=2, radius=1.0)
mrng = random.Random(77)
for v in mb.verts:
    v.co *= mrng.uniform(0.93, 1.06)
    if v.co.z < 0:
        v.co.z *= 0.3
bmesh.ops.scale(mb, vec=tuple(MOUND_R), verts=mb.verts)
bmesh.ops.translate(mb, vec=MOUND_C, verts=mb.verts)
kit.give(kit.mesh_obj("Mound", mb, "Ore"), M_MOUND)


def mound_z(x, y):
    q = 1 - (x / MOUND_R.x) ** 2 - (y / MOUND_R.y) ** 2
    return MOUND_C.z + MOUND_R.z * math.sqrt(max(q, 0.0))


spots = [(0.05, 0.05, 0.36), (0.62, 0.24, 0.32), (-0.58, -0.22, 0.33), (-0.2, 0.55, 0.3), (0.32, -0.5, 0.3), (-1.0, 0.28, 0.27), (1.0, -0.2, 0.27), (-0.72, 0.68, 0.23), (0.78, 0.66, 0.24), (-1.08, -0.5, 0.22), (0.05, -0.85, 0.24), (-0.4, -0.75, 0.2), (1.18, 0.38, 0.2), (0.45, 0.95, 0.19), (-0.35, 0.95, 0.19), (1.0, -0.75, 0.2)]
for i, (x, y, r) in enumerate(spots):
    z = mound_z(x, y) + r * 0.15
    qkit.nugget(f"Nugget{i}", r, (x, y, z), M_ORE, "Ore", seed=100 + i)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, 0, 1.3), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (6.4, -9.0, 5.6), lens=50, target=(0, 0, 1.25))
    kit.shoot("front", (0, -12.5, 1.6), lens=50, target=(0, 0, 1.3))
    kit.shoot("top", (2.4, -4.4, 7.4), lens=45, target=(0, 0, 1.9))

maps = kit.bake_all(parts, {"Tub": 1024, "Trim": 1024, "Wheels": 512, "Ore": 1024, "Rails": 1024}) if BAKE else {}
ups = qkit.export(parts)
cart_top = max((o.matrix_world @ v.co).z for n, o in parts.items() if n != "Rails" for v in o.data.vertices)
wheel_c = Vector((WHEEL_X, -GAUGE, AXLE_Z))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Cover (waist-high, Cover attribute); GDD §19 maps; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "markers": {
            "RailTop": {"height_from_pivot": round(RAIL_TOP - lo.z, 4), "note": "top of the rail heads (the wheels sit on it)"},
            "RailStub": {"length_studs": RAIL_L, "gauge_centres_studs": 2 * GAUGE, "axis": "Blender X = Roblox model X"},
            "CartTop": {"height_from_pivot": round(cart_top - lo.z, 4)},
            "TubRim": {"height_from_pivot": round(TUB_Z1 - lo.z, 4)},
            "WheelCentre": {"blender": kit.blend(wheel_c), "roblox_from_pivot": kit.rbx(wheel_c, pivot)},
        },
        "front_note": "The cart's long side faces the front (-Y in Blender = the model's LookVector in Roblox); the rails "
        "run along the model's X axis.",
    }
)
