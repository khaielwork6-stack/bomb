"""FUSE VALLEY — the Fireworks Yard's sandbag wall (Asset Bible §4.2 Yard: "sandbag walls at the sides" of the docks;
§4.4 props kit: "Sandbags — canvas, stitched").

A short stacked wall of fifteen plump toy sandbags in a 6 / 5 / 4 bond, the size of MapYard's part-built piles
(~13 long, ~2.6 tall, ~1.7 deep; each row steps back a little). Every bag is its own pillow: a squarish loaf with a
rounder top and a flatter, squashed bottom, pinched "ears" at the four corners where the seam closes, a welted seam
round its middle with a running stitch either side of it (shader, driven by a per-bag seam UV so the stitches follow
each bag), canvas grain, three tan dye lots. Upper bags sag at the ends over the bags below.
Two MeshParts so each gets a full 1024 texture: "Bags" (the bottom row) and "BagsTop" (the two rows above).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_sandbags.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Sandbags/  (renders/, export/Prop.Sandbags.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.Sandbags"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Bags", "BagsTop"], glow=[])
rng = random.Random(2207)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
TANS = [
    (srgb("#E6BD78"), srgb("#FFE0A6")),
    (srgb("#D9AC66"), srgb("#F8D190")),
    (srgb("#EDC98A"), srgb("#FFEBBE")),
]
SEAM_DARK = srgb("#9A6A34")
THREAD = srgb("#7A4A22")


def mat_canvas(name, base, hi):
    """Toy canvas: top-lit tan, a fine woven grain, the welted seam darkened in its groove, a dashed running stitch
    either side of it (SeamUV.x = studs round the bag's middle, SeamUV.y = studs above / below the seam)."""
    m, nt, b = kit.new_mat(name)
    nd = kit.nd
    uv = nd(nt, "ShaderNodeUVMap", uv_map="SeamUV")
    sep = nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs["Vector"])
    s, t = sep.outputs["X"], sep.outputs["Y"]
    at = nd(nt, "ShaderNodeMath", operation="ABSOLUTE")
    nt.links.new(t, at.inputs[0])
    # the seam groove: 1 at the seam, 0 by 0.05 studs away
    groove = nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    groove.inputs["From Min"].default_value = 0.0
    groove.inputs["From Max"].default_value = 0.05
    groove.inputs["To Min"].default_value = 1.0
    groove.inputs["To Max"].default_value = 0.0
    nt.links.new(at.outputs[0], groove.inputs["Value"])
    # the stitch lines at |t| = 0.11, dashes along s
    off = nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    off.inputs[1].default_value = 0.11
    nt.links.new(at.outputs[0], off.inputs[0])
    aoff = nd(nt, "ShaderNodeMath", operation="ABSOLUTE")
    nt.links.new(off.outputs[0], aoff.inputs[0])
    line = nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    line.inputs["From Min"].default_value = 0.014
    line.inputs["From Max"].default_value = 0.026
    line.inputs["To Min"].default_value = 1.0
    line.inputs["To Max"].default_value = 0.0
    nt.links.new(aoff.outputs[0], line.inputs["Value"])
    per = nd(nt, "ShaderNodeMath", operation="DIVIDE")
    per.inputs[1].default_value = 0.2
    nt.links.new(s, per.inputs[0])
    fr = nd(nt, "ShaderNodeMath", operation="FRACT")
    nt.links.new(per.outputs[0], fr.inputs[0])
    # a soft-ended dash: 1 across the middle 60% of each period
    tri = nd(nt, "ShaderNodeMath", operation="PINGPONG")
    tri.inputs[1].default_value = 0.5
    nt.links.new(fr.outputs[0], tri.inputs[0])
    dash = nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    dash.inputs["From Min"].default_value = 0.14
    dash.inputs["From Max"].default_value = 0.22
    nt.links.new(tri.outputs[0], dash.inputs["Value"])
    stitch = nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(line.outputs["Result"], stitch.inputs[0])
    nt.links.new(dash.outputs["Result"], stitch.inputs[1])

    weave = kit.noise_tex(nt, 70.0, 8.0)
    grain = kit.map_range(nt, weave.outputs["Fac"], 0.3, 0.7, 0.0, 0.14)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.4, 1.0, 0.5), base, hi)
    col = kit.mix_rgb(nt, grain, col, SEAM_DARK)
    blot = kit.noise_tex(nt, 3.0, 3.0)
    col = kit.mix_rgb(nt, kit.map_range(nt, blot.outputs["Fac"], 0.45, 0.75, 0.0, 0.12), col, SEAM_DARK)
    gmix = nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    gmix.inputs[1].default_value = 0.55
    nt.links.new(groove.outputs["Result"], gmix.inputs[0])
    col = kit.mix_rgb(nt, gmix.outputs[0], col, SEAM_DARK)
    col = kit.mix_rgb(nt, stitch.outputs[0], col, THREAD)
    col = kit.ao_mult(nt, col, 0.75, dist=0.5)
    nt.links.new(col, b.inputs["Base Color"])
    rough = kit.map_range(nt, weave.outputs["Fac"], 0.0, 1.0, 0.56, 0.7)
    nt.links.new(rough, b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    # height: canvas weave, stitches raised, the groove sunk
    h1 = nd(nt, "ShaderNodeMath", operation="MULTIPLY_ADD")
    h1.inputs[1].default_value = 0.25
    nt.links.new(weave.outputs["Fac"], h1.inputs[0])
    nt.links.new(stitch.outputs[0], h1.inputs[2])
    h2 = nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    nt.links.new(h1.outputs[0], h2.inputs[0])
    nt.links.new(groove.outputs["Result"], h2.inputs[1])
    bump = nd(nt, "ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.45
    bump.inputs["Distance"].default_value = 0.012
    nt.links.new(h2.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


M_CANVAS = [mat_canvas(f"Canvas{i}", a, h) for i, (a, h) in enumerate(TANS)]


# The bag's lattice on the unit box (then pushed out onto a rounded superellipsoid): no poles, so the plump top
# shades clean; rows bunched round the seam so the welt and the pinched corners have the vertices to read.
QX = [-1 + 2 * i / 8 for i in range(9)]
QY = [-1 + 2 * i / 4 for i in range(5)]
QZ = [-1, -0.62, -0.3, -0.1, 0.0, 0.1, 0.3, 0.62, 1]


def box_lattice():
    """Quads of a box surface sampled at QX x QY x QZ: a list of faces, each 4 (qx, qy, qz) corners, outward."""
    faces = []
    for sgn in (-1, 1):
        for ax in range(3):
            o1, o2 = [(1, 2), (0, 2), (0, 1)][ax]
            g = [QX, QY, QZ]
            A, B = g[o1], g[o2]
            for i in range(len(A) - 1):
                for j in range(len(B) - 1):
                    quad = []
                    for di, dj in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        q = [0.0, 0.0, 0.0]
                        q[ax] = float(sgn)
                        q[o1] = A[i + di]
                        q[o2] = B[j + dj]
                        quad.append(tuple(q))
                    faces.append(quad)
    return faces


LATTICE = box_lattice()


def bag(name, L, D, H, place, mat, group, sag=0.0, seed=0):
    """One plump sandbag centred on the origin (length L on X, depth D on Y, height H on Z), placed by `place`."""
    r = random.Random(seed)
    a, b, c = L / 2, D / 2, H / 2
    e_h = 0.4  # footprint: a rounded rectangle
    e_top, e_bot = 0.62, 0.46  # a plump rounded top, a flatter, squashed bottom
    ph = [r.uniform(0, 6.28) for _ in range(4)]

    def point(q):
        qx, qy, qz = q
        e_v = e_top if qz >= 0 else e_bot
        # the superellipsoid's surface along the direction q (inside-outside function is homogeneous)
        f = ((abs(qx) ** (2 / e_h) + abs(qy) ** (2 / e_h)) ** (e_h / e_v) + abs(qz) ** (2 / e_v)) if (qx or qy or qz) else 1
        t = f ** (-e_v / 2)
        x, y, z = qx * t, qy * t, qz * t
        zn = z  # -1..1, 0 on the seam
        # the corner "ears": where the seam closes the corners poke out a little and the bag thins toward them
        phi = math.atan2(y, x)
        corner = abs(math.sin(2 * phi)) ** 4 * min(1.0, (x * x + y * y) ** 2)
        near = math.exp(-((zn / 0.22) ** 2))
        k = 1 + 0.07 * corner * near + 0.028 * math.exp(-((zn / 0.07) ** 2))  # + the welt right on the seam
        x, y = x * k, y * k
        z *= 1 - 0.32 * corner
        z *= 1.0 if z >= 0 else 0.9
        x, y, z = x * a, y * b, z * c
        # ends a touch slimmer than the middle (the fill settles to the centre)
        e = (x / a) ** 4
        y *= 1 - 0.08 * e
        z *= 1 - 0.16 * e
        # hand-made lumps, and the sag at the ends
        z += 0.022 * math.sin(2.1 * x + ph[0]) * max(0.0, zn) + 0.012 * math.sin(3.3 * y + ph[1])
        y += 0.018 * math.sin(1.7 * x + ph[2])
        z -= sag * (x / a) ** 2
        return Vector((x, y, z)), zn * c

    # SeamUV.x: arc length round the seam, looked up by the footprint angle of each lattice point
    table = []
    acc, prev = 0.0, None
    for k in range(721):
        ang = -math.pi + 2 * math.pi * k / 720
        qx, qy = math.cos(ang), math.sin(ang)
        p, _ = point((qx, qy, 0.0))
        if prev is not None:
            acc += (p - prev).length
        table.append((ang, acc))
        prev = p
    perim = acc

    def s_of(q):
        ang = math.atan2(q[1], q[0])
        i = min(719, max(0, int((ang + math.pi) / (2 * math.pi) * 720)))
        (a0, s0), (a1, s1) = table[i], table[i + 1]
        return s0 + (s1 - s0) * ((ang - a0) / (a1 - a0) if a1 != a0 else 0)

    bm = bmesh.new()
    uv_main = bm.loops.layers.uv.new("UVMap")
    uv_seam = bm.loops.layers.uv.new("SeamUV")
    cache = {}

    def vert(q):
        key = tuple(round(v, 5) for v in q)
        if key not in cache:
            p, t = point(q)
            cache[key] = (bm.verts.new(p), t, s_of(q))
        return cache[key]

    for quad in LATTICE:
        vs = [vert(q) for q in quad]
        ss = [v[2] for v in vs]
        if max(ss) - min(ss) > perim / 2:  # the face straddles the seam UV's wrap
            ss = [x + perim if x < perim / 2 else x for x in ss]
        f = bm.faces.new([v[0] for v in vs])
        for lp, sv, v in zip(f.loops, ss, vs):
            lp[uv_seam].uv = (sv, v[1])
            lp[uv_main].uv = (sv / perim, (v[1] + c) / (2 * c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.transform(place)
    o = kit.mesh_obj(name, bm, group)
    o.data.uv_layers.active_index = 0
    kit.give(o, mat)
    return kit.smooth(o)


# ── The wall: 6 / 5 / 4 in a running bond, each row stepped back ─────────────────────────────────────────────────
BL, BD, BH = 2.3, 1.32, 0.98  # bag size
PITCH = 2.13
ROW_Z = 0.8
ROW_BACK = 0.16
n = 0
for row, count in enumerate((6, 5, 4)):
    for i in range(count):
        x = (i - (count - 1) / 2) * PITCH + rng.uniform(-0.06, 0.06)
        y = row * ROW_BACK + rng.uniform(-0.05, 0.05)
        sx = rng.uniform(0.96, 1.04)
        z = 0.5 + row * ROW_Z  # the flattened bottom sits ~0.42 below the centre
        rot = Matrix.Rotation(rng.uniform(-0.06, 0.06), 4, "Z") @ Matrix.Rotation(rng.uniform(-0.035, 0.035), 4, "X")
        if row:
            rot = Matrix.Rotation(rng.uniform(-0.03, 0.03), 4, "Y") @ rot
        place = Matrix.Translation((x, y, z)) @ rot
        bag(
            f"Bag{row}{i}",
            BL * sx,
            BD * rng.uniform(0.97, 1.03),
            BH * rng.uniform(0.96, 1.03),
            place,
            M_CANVAS[(n * 2 + row) % 3],
            "Bags" if row == 0 else "BagsTop",
            sag=0.07 if row else 0.0,
            seed=n,
        )
        n += 1

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
# sit the wall on z = 0 (the flattened bottoms)
lo0, _ = kit.bounds(parts)
for o in parts.values():
    o.data.transform(Matrix.Translation((0, 0, -lo0.z)))
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "pivot", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, 0, 1.2))
if DO_RENDER:
    kit.shoot("hero", (4.0, -13.0, 9.8), lens=40, target=(0.2, 0, 0.8))
    kit.shoot("front", (0, -22, 2.0), lens=55)
    kit.shoot("close", (2.6, -5.2, 3.2), lens=50, target=(0.6, 0, 1.2))

if BAKE:
    maps = kit.bake_all(parts, {"Bags": 1024, "BagsTop": 1024})
    for o in parts.values():  # the seam UV only drives the shader; Studio gets the baked UVMap alone
        o.data.uv_layers.remove(o.data.uv_layers["SeamUV"])
else:
    maps = {}
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
_ = bpy
