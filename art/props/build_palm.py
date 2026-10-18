"""FUSE VALLEY — the Fireworks Yard's toy palm (MapYardToy "Palm"; Asset Bible §2 "Toy Arcade" world dressing, §4.2).

A chunky toy palm ~15 studs tall: a leaning trunk of eight stacked "pineapple" rings in two warm browns, a green crown
bulb, nine broad drooping fronds (and two young ones standing up) with zig-zag toothed edges, a V-fold and a pale midrib (two greens, alternating), and
three glossy coconuts under the crown. The trunk leans toward the front (-Y), so the builder can keep each old palm's
lean direction by turning the model.

MeshPart groups: Trunk (rings, crown bulb, coconuts), Fronds.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_palm.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Palm/  (renders/, export/Prop.Palm.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the lean). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.Palm"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Trunk", "Fronds"], glow=[])
rng = random.Random(7)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
BARK_A, BARK_A_HI = srgb("#B8743A"), srgb("#E6A866")
BARK_B, BARK_B_HI = srgb("#94582A"), srgb("#C88A50")
LEAF_A, LEAF_A_HI = srgb("#3AAE36"), srgb("#86E25C")
LEAF_B, LEAF_B_HI = srgb("#2A9A3A"), srgb("#6CD058")
RIB, RIB_HI = srgb("#A6E25A"), srgb("#E4FFA0")
NUT, NUT_HI = srgb("#6A3E1C"), srgb("#B07A44")
BULB, BULB_HI = srgb("#4E8A2A"), srgb("#8AC452")

M_BARK_A = kit.mat_gloss("BarkA", BARK_A, BARK_A_HI, edge=srgb("#F4C890"), rough=0.55, grad=0.4, speckle=0.18)
M_BARK_B = kit.mat_gloss("BarkB", BARK_B, BARK_B_HI, edge=srgb("#E0A870"), rough=0.6, grad=0.4, speckle=0.18)
M_LEAF_A = kit.mat_gloss("LeafA", LEAF_A, LEAF_A_HI, rough=0.42, grad=0.55, ao=0.55)
M_LEAF_B = kit.mat_gloss("LeafB", LEAF_B, LEAF_B_HI, rough=0.42, grad=0.55, ao=0.55)
M_RIB = kit.mat_gloss("Rib", RIB, RIB_HI, rough=0.4, grad=0.4, ao=0.5)
M_NUT = kit.mat_gloss("Coconut", NUT, NUT_HI, edge=srgb("#D09A60"), rough=0.32, grad=0.5, speckle=0.12)
M_BULB = kit.mat_gloss("Bulb", BULB, BULB_HI, rough=0.5, grad=0.5)

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
H = 13.6  # trunk top height
LEAN = 2.8  # how far the trunk top leans toward the front (-Y)
RINGS = 8


def trunk_at(t):
    return Vector((0.0, -LEAN * t**1.8, H * t))


def radius_at(t):
    return 0.86 - 0.32 * t


# ── The trunk: stacked rings, each a closed lathe with a flared lip over the next ───────────────────────────────
for i in range(RINGS):
    t0, t1 = i / RINGS, (i + 1) / RINGS
    a, b = trunk_at(t0), trunk_at(t1)
    d = b - a
    ln = d.length + 0.12
    r = radius_at(t0)
    prof = [(0.0, 0.0), (r * 0.88, 0.0), (r * 0.93, 0.1 * ln), (r * 1.0, 0.55 * ln), (r * 1.16, 0.86 * ln), (r * 1.13, 0.96 * ln), (r * 0.86, ln), (0.0, ln)]
    o = kit.lathe(f"Ring{i}", prof, M_BARK_A if i % 2 == 0 else M_BARK_B, "Trunk", segs=14)
    o.matrix_world = Matrix.Translation(a) @ Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()

TOP = trunk_at(1.0)
kit.sphere("CrownBulb", 0.78, tuple(TOP + Vector((0, 0, 0.12))), M_BULB, "Trunk", scale=(1, 1, 0.8), u=14, v=8)

# ── Coconuts under the crown ─────────────────────────────────────────────────────────────────────────────────────
for k in range(3):
    a = math.radians(30 + 120 * k)
    p = TOP + Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, -0.55 - 0.12 * (k % 2)))
    kit.sphere(f"Coconut{k}", 0.48, tuple(p), M_NUT, "Trunk", scale=(1, 1, 0.92), u=12, v=8)


# ── Fronds ───────────────────────────────────────────────────────────────────────────────────────────────────────
def width_at(u, wmax):
    if u < 0.38:
        return 0.16 + (wmax - 0.16) * math.sin(math.pi / 2 * u / 0.38)
    return 0.05 + (wmax - 0.05) * (1 - ((u - 0.38) / 0.62) ** 1.5)


def frond(name, yaw, length, rise, droop, wmax, mat_idx, stations=18):
    dvec = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
    base = TOP + Vector((0, 0, 0.35)) + dvec * 0.35

    def spine(u):
        return base + dvec * (length * u) + Vector((0, 0, length * (rise * u - droop * u * u)))

    th = 0.09
    wm = 0.11
    bm = bmesh.new()
    rows = []
    for i in range(stations + 1):
        u = i / stations
        p = spine(u)
        du = 1e-3
        tg = (spine(min(1, u + du)) - spine(max(0, u - du))).normalized()
        nrm = tg.cross(side).normalized()
        w = width_at(u, wmax)
        if i % 2 == 1 and 0.1 < u < 0.97:
            w *= 0.6  # the zig-zag teeth
        fold = w * 0.3
        tops = [p - side * w - nrm * fold, p - side * wm + nrm * 0.02, p + nrm * 0.05, p + side * wm + nrm * 0.02, p + side * w - nrm * fold]
        bots = [v - nrm * th for v in tops]
        bots[0] = tops[0] - nrm * th * 0.4
        bots[4] = tops[4] - nrm * th * 0.4
        rows.append(([bm.verts.new(v) for v in tops], [bm.verts.new(v) for v in bots]))
    faces = []
    for i in range(stations):
        (ta, ba), (tb, bb) = rows[i], rows[i + 1]
        for j in range(4):
            rib = j in (1, 2)
            faces.append((bm.faces.new((ta[j], ta[j + 1], tb[j + 1], tb[j])), rib))
            faces.append((bm.faces.new((bb[j], bb[j + 1], ba[j + 1], ba[j])), False))
        faces.append((bm.faces.new((ba[0], ta[0], tb[0], bb[0])), False))
        faces.append((bm.faces.new((bb[4], tb[4], ta[4], ba[4])), False))
    t0, b0 = rows[0]
    t1, b1 = rows[-1]
    faces.append((bm.faces.new(t0[::-1] + b0), False))
    faces.append((bm.faces.new(t1 + b1[::-1]), False))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.faces.index_update()
    rib_set = {f.index for f, rib in faces if rib}
    o = kit.mesh_obj(name, bm, "Fronds")
    o.data.materials.append(M_LEAF_A if mat_idx == 0 else M_LEAF_B)
    o.data.materials.append(M_RIB)
    for poly in o.data.polygons:
        if poly.index in rib_set:
            poly.material_index = 1
    return kit.smooth(o)


N_FRONDS = 9
for k in range(N_FRONDS):
    yaw = math.radians(k * 360 / N_FRONDS + 12 + rng.uniform(-9, 9))
    big = k % 2 == 0
    frond(
        f"Frond{k}",
        yaw,
        length=7.0 if big else 6.0,
        rise=0.5 if big else 0.62,
        droop=0.95 if big else 0.9,
        wmax=1.6 if big else 1.35,
        mat_idx=k % 2,
    )
# two young fronds standing up in the middle
for k in range(2):
    yaw = math.radians(70 + 180 * k)
    frond(f"Young{k}", yaw, length=3.4, rise=1.15, droop=0.75, wmax=0.8, mat_idx=0, stations=10)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, -1.5, 8.0), floor_color="#6CC24A")
if DO_RENDER:
    kit.shoot("hero", (19.0, -30.0, 13.0), lens=45, target=(0, -1.5, 8.5))
    kit.shoot("side", (34.0, -1.5, 9.0), lens=45, target=(0, -1.5, 8.5))
    kit.shoot("crown", (6.0, -14.0, 20.0), lens=40, target=(0, -2.4, 12.6))

maps = kit.bake_all(parts, {"Trunk": 1024, "Fronds": 1024}) if BAKE else {}
kit.export_fbx(parts)
foot = Vector((0, 0, 0))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "Asset Bible §2 Toy Arcade world dressing, §4.2 Yard (MapYardToy palms)",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "glow": [],
        "markers": {
            "TrunkBase": {"blender": kit.blend(foot), "roblox_from_pivot": kit.rbx(foot, pivot)},
            "TrunkTop": {"blender": kit.blend(TOP), "roblox_from_pivot": kit.rbx(TOP, pivot)},
        },
        "front_note": "The trunk leans toward the front (-Y in Blender = the model's LookVector in Roblox).",
    }
)
