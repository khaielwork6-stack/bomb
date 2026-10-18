"""FUSE VALLEY â€” the Fireworks Yard's giant corner rockets (MapYardToy "GiantRocket"; Asset Bible Â§4.2 Yard dressing).

A fat toy firework rocket ~28.7 studs tall standing on four swept fins: a glossy body wrapped in two candy-spiral
stripes, an ogive nose cone with a gold ball tip, gold collars top and bottom, a dark steel nozzle bell and a braided
fuse running out of the nozzle along the ground to a lit spark.
Per-instance colours: the "Body" (colour A) and "Stripes" (colour B: the spirals, fins and nose) groups keep a near-white
albedo, so the builder tints each with SurfaceAppearance.Color (as Prop.GasBottle). "Trim" is untinted (gold, steel,
cord); "Spark" is a Neon glow part.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_giant_rocket.py -- [--samples 64] [--no-bake] [--no-render] [--tint]
      --tint: review renders only (hero/front in red-and-white, plus the four Yard colourways side by side); no export.
Out:  art/out/Prop.GiantRocket/  (renders/, export/Prop.GiantRocket.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the fuse runs out to the front). Studio: Blender (x, y, z) -> Roblox (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.GiantRocket"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
PREVIEW_TINT = "--tint" in kit.argv
kit.setup(KEY, bake=["Body", "Stripes", "Trim"], glow=["Spark"])

# â”€â”€ Palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
WHITE, WHITE_HI = srgb("#DCDDE3"), srgb("#FFFFFF")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
IRON_LO, IRON, IRON_HI = srgb("#22242C"), srgb("#3E4250"), srgb("#8A92A8")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")
# MapYardToy's four rockets: (A body, B stripes / fins / nose)
YARD = [("#E83830", "#FFFFFF"), ("#3478EC", "#FFFFFF"), ("#FFC41E", "#E83830"), ("#9646E6", "#FFD23C")]


def lighten(c, t):
    return tuple(c[i] + (1 - c[i]) * t if i < 3 else c[i] for i in range(4))


def paint(name, hexcol=None):
    if hexcol is None:
        return kit.mat_gloss(name, WHITE, WHITE_HI, edge=WHITE_HI, rough=0.26, grad=0.4, ao=0.55)
    c = srgb(hexcol)
    return kit.mat_gloss(name, tuple(x * 0.9 if i < 3 else x for i, x in enumerate(c)), lighten(c, 0.35), edge=lighten(c, 0.6), rough=0.26, grad=0.4, ao=0.55)


M_BODY = paint("BodyPaint", YARD[0][0] if PREVIEW_TINT else None)
M_STRIPE = paint("StripePaint", YARD[0][1] if PREVIEW_TINT else None)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_IRON = kit.mat_metal("Iron", IRON_LO, IRON, IRON_HI, rough=(0.25, 0.4), metal=0.3)
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))
M_SPARK = kit.mat_emit("Spark", srgb("#FFD84A"), 6.0)

# â”€â”€ Dimensions (studs) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
R = 2.9  # body radius (fatter than the part-built one: a chunky toy)
K = R / 2.4  # radial scale for the nose / fins (drawn for R = 2.4)
Z0, Z1 = 1.05, 22.7  # body bottom / top
SEG = 40  # lathe segments

# Body: a tube with a rounded bottom shoulder (the top hides under the nose collar).
kit.lathe("Tube", [(0, Z0), (R - 0.5, Z0), (R - 0.15, Z0 + 0.12), (R, Z0 + 0.45), (R, Z1)], M_BODY, "Body", segs=SEG)

# Nozzle bell under it: dark steel, flared, hollow-looking (a dark inner throat).
kit.lathe(
    "Nozzle",
    [(0, 0.55), (1.05, 0.55), (1.35, 0.25), (1.6, 0.06), (1.72, 0.0), (1.82, 0.06), (1.7, 0.4), (1.45, 0.75), (1.4, 1.1), (0, 1.1)],
    M_IRON,
    "Trim",
    segs=SEG,
)


# Gold collars: rounded bands round the bottom and the top of the tube.
def collar(name, z0, z1, r_in, r_out):
    e = 0.12
    kit.lathe(
        name,
        [(r_in, z0), (r_out - e, z0), (r_out - e * 0.3, z0 + e * 0.3), (r_out, z0 + e), (r_out, z1 - e), (r_out - e * 0.3, z1 - e * 0.3), (r_out - e, z1), (r_in, z1)],
        M_GOLD,
        "Trim",
        segs=SEG,
    )


collar("CollarLow", Z0 + 0.35, Z0 + 1.15, R - 0.1, R + 0.2)
collar("CollarTop", Z1 - 0.6, Z1 + 0.25, R - 0.1, R + 0.22)
collar("CollarMid", 11.6, 12.1, R - 0.1, R + 0.16)

# Two candy-spiral stripes round the tube (between the collars), proud of the paint, edges rounded.
H_LO, H_HI, TURNS, W = Z0 + 0.75, Z1 - 0.2, 2.0, 2.3
PROF = [(-0.06, -1), (0.05, -1), (0.1, -0.97), (0.13, -0.9), (0.13, 0.9), (0.1, 0.97), (0.05, 1), (-0.06, 1)]
STEPS = 72
for s_i, a0 in enumerate((0.0, math.pi)):
    bm = bmesh.new()
    rings = []
    for k in range(STEPS + 1):
        t = k / STEPS
        a = a0 + 2 * math.pi * TURNS * t
        zc = H_LO - W / 2 + (H_HI - H_LO + W) * t  # the band runs on under both collars...
        d = Vector((math.cos(a), math.sin(a), 0))
        # ...and is clamped flat against them there, so its ends never show
        rings.append([bm.verts.new(d * (R + dr) + Vector((0, 0, min(H_HI, max(H_LO, zc + dz * W / 2))))) for dr, dz in PROF])
    n = len(PROF)
    for k in range(STEPS):
        for j in range(n - 1):
            bm.faces.new((rings[k][j], rings[k + 1][j], rings[k + 1][j + 1], rings[k][j + 1]))
        bm.faces.new((rings[k][n - 1], rings[k + 1][n - 1], rings[k + 1][0], rings[k][0]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    kit.smooth(kit.give(kit.mesh_obj(f"Spiral{s_i}", bm, "Stripes"), M_STRIPE))

# Nose cone: an ogive from the top collar to a gold ball tip.
NZ = Z1 + 0.15
kit.lathe(
    "Nose",
    [(R + 0.05, NZ), (R + 0.02, NZ + 0.7), (2.28 * K, NZ + 1.6), (1.95 * K, NZ + 2.6), (1.5 * K, NZ + 3.5), (0.98 * K, NZ + 4.3), (0.5 * K, NZ + 4.9), (0.2 * K, NZ + 5.2), (0, NZ + 5.28)],
    M_STRIPE,
    "Stripes",
    segs=SEG,
)
kit.sphere("Tip", 0.5, (0, 0, NZ + 5.45), M_GOLD, "Trim", u=20, v=12)
kit.torus("TipRing", 0.42, 0.13, (0, 0, NZ + 5.05), M_GOLD, "Trim", major=20, minor=6)

# Four swept toy fins at 45 deg (the front stays clear for the fuse).
FIN = kit.outline(
    [(1.9, 8.6), (2.9, 7.4), (4.0, 4.6), (4.75, 1.9), (5.0, 0.35), (4.75, 0.0), (4.0, 0.05), (3.0, 0.75), (1.9, 1.5)],
    [0, 5, 8],
    n=4,
)
for k in range(4):
    a = math.radians(45 + 90 * k)
    d = Vector((math.cos(a), math.sin(a), 0))
    tng = Vector((-math.sin(a), math.cos(a), 0))
    # prism draws in local XY with +Y as near world-up as possible; local X must run outward along d
    pts = [(x * K, y) for x, y in FIN]
    bm = bmesh.new()
    vs = [bm.verts.new((p[0], 0.0, p[1])) for p in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0.8, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.translate(bm, vec=(0, -0.4, 0), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    rot = Matrix((d, tng, (0, 0, 1))).transposed()
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    fo = kit.give(kit.mesh_obj(f"Fin{k}", bm, "Stripes"), M_STRIPE)
    kit.bevel(fo, 0.22, 3, angle=30)
    kit.smooth(fo)
    # a gold rivet pair near the root on both faces
    for side in (-1, 1):
        for zz in (2.6, 5.2):
            x = (2.75 if zz < 4 else 2.55) * K
            kit.rivet(f"FinRivet{k}{side}{zz}", d * x + tng * side * 0.41 + Vector((0, 0, zz)), tng * side, M_GOLD, "Trim", r=0.17, squash=0.5, segs=8)

# The fuse: a braided cord out of the nozzle, along the ground to the front, ending in a lit spark.
FUSE = [(0, 0, 0.75), (0, -0.7, 0.3), (0.15, -2.3, 0.26), (0.9, -3.8, 0.26), (0.3, -5.2, 0.28), (-0.4, -6.2, 0.5), (-0.2, -6.9, 1.05)]
kit.rope("Fuse", FUSE, 0.24, M_CORD, "Trim", res=5, bres=2)
kit.sphere("FuseEnd", 0.28, FUSE[-1], M_CORD, "Trim", u=10, v=6)
SPARK_AT = Vector(FUSE[-1]) + Vector((0, -0.1, 0.35))
kit.prism("Spark", kit.star_pts(8, 0.95, 0.36), 0.16, SPARK_AT, (0, -1, 0), M_SPARK, "Spark", bev=0.05, bev_segs=1)

# â”€â”€ Finalize â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), flush=True)

kit.render_setup(target=(0, 0, 12.5))
if DO_RENDER:
    sfx = "" if PREVIEW_TINT else "_white"
    kit.shoot("hero" + sfx, (30.0, -48.0, 19.0), lens=45, target=(0, 0, 13.5))
    kit.shoot("front" + sfx, (0, -52.0, 12.0), lens=45, target=(0, 0, 13.5))
    kit.shoot("base" + sfx, (9.0, -15.0, 6.0), lens=40, target=(0, -1.5, 2.5))
    if PREVIEW_TINT:
        # the four Yard colourways side by side
        for i, (ca, cb) in enumerate(YARD[1:], start=1):
            mb, ms = paint(f"Body{i}", ca), paint(f"Stripe{i}", cb)
            for name, o in parts.items():
                c = o.copy()
                c.data = o.data.copy()
                for j, m in enumerate(c.data.materials):
                    if m is M_BODY:
                        c.data.materials[j] = mb
                    elif m is M_STRIPE:
                        c.data.materials[j] = ms
                c.matrix_world = Matrix.Translation((i * 13.0, i * 4.0, 0))
                bpy.context.scene.collection.objects.link(c)
        kit.shoot("lineup", (40.0, -75.0, 22.0), lens=40, target=(20.0, 6.0, 13.0), res=(1600, 900))

if PREVIEW_TINT:
    sys.exit(0)
maps = kit.bake_all(parts, {"Body": 1024, "Stripes": 1024, "Trim": 1024}) if BAKE else {}
kit.export_fbx(parts, scale=0.1)  # over 20.48 studs tall: see kit.export_fbx
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "tintable": {"Body": "colour A (MapYardToy rocket colA)", "Stripes": "colour B (colB: spirals, fins, nose)"},
        "glow": ["Spark"],
        "markers": {"Spark": {"blender": kit.blend(SPARK_AT), "roblox_from_pivot": kit.rbx(SPARK_AT, pivot)}},
        "front_note": "The fuse runs out to the front (-Y in Blender = the model's LookVector in Roblox).",
    }
)
