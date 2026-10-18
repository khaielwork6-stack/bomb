"""FUSE VALLEY — the Spark Crate (GDD §17.4 F-STORE-10, Asset Bible §7.4): the loot crate players open.

Deterministic Blender 4.5 build from the approved-style reference sheet (art/ref/crate/SparkCrate_reference.jpg):
a chunky orange-painted plank chest with a barrel lid, a brass band, two brass straps, 8 brass corner caps with
rivets, a round brass bomb latch with a keyhole and its own little fuse, a braided fuse in a brass grommet on the
lid, and a cream starburst stencil on both ends. Every edge is bevelled; materials are procedural (painted wood
with grain and chipped edges, brass with edge highlights, braided cord) and baked to PBR maps.

The lid is its own pair of parts (LidWood / LidBrass + Spark) hinged on the back top edge, so the crate-opening
sequence can swing it open; InnerGlow is the gold light that shows when it does.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/crate/build.py -- [--samples 64] [--no-bake]
Out:  art/out/Crate.Spark/  (renders/, export/Crate.Spark.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. In Studio the FBX arrives Y up, front -Z, x100 (scale 0.01).
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


KEY = "Crate.Spark"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", KEY)
REN = os.path.join(OUT, "renders")
EXP = os.path.join(OUT, "export")
TEX = os.path.join(EXP, "textures")
for d in (REN, EXP, TEX):
    os.makedirs(d, exist_ok=True)
SAMPLES = int(arg("--samples", "64"))
BAKE = "--no-bake" not in argv
rng = random.Random(7)


def srgb(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [a])


# ── Palette (the reference sheet, inside Asset Bible §2.3) ──────────────────────────────────────────────────────
PAINT = srgb("#F2580E")  # crate orange
PAINT_HI = srgb("#FF7E2A")
BARE = srgb("#F7C9A0")  # bare wood under chipped paint
DARKWOOD = srgb("#7A3414")
BRASS = srgb("#FFC437")
BRASS_HI = srgb("#FFF0A8")
BRASS_LO = srgb("#D08A1C")
CREAM = srgb("#FFE2C2")
INK = srgb("#2A160E")
CORD = srgb("#E3C595")
CORD_DK = srgb("#9C7448")
SPARK = srgb("#FFD84A")

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
W, D = 4.4, 2.5  # width (X), depth (Y)
HB = 1.5  # body height = lid seam
LR = 0.95  # lid rise above the seam
PT = 0.10  # plank thickness
STRAP_X = 1.12  # the two straps' centres
STRAP_W = 0.40
BAND_Z, BAND_H = 1.32, 0.26

# ── Scene ────────────────────────────────────────────────────────────────────────────────────────────────────────
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "NONE"
GROUPS = {"BodyWood": [], "BodyBrass": [], "LidWood": [], "LidBrass": [], "Glow": []}


def link(o, group):
    if o.name not in scene.collection.objects:
        scene.collection.objects.link(o)
    GROUPS[group].append(o)
    return o


def mesh_obj(name, bm, group):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me), group)


def bevel(o, width, segs=3):
    m = o.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segs
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(40)
    m.harden_normals = False
    return o


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def give(o, mat):
    o.data.materials.clear()
    o.data.materials.append(mat)
    return o


def box(name, size, loc, mat, group, bev=0.035, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if rot:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    o = mesh_obj(name, bm, group)
    give(o, mat)
    if bev:
        bevel(o, bev)
    return smooth(o)


def cylinder(name, r, depth, loc, mat, group, axis="Z", segs=32, bev=0.02):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=depth)
    if axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)
    elif axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    o = give(mesh_obj(name, bm, group), mat)
    if bev:
        bevel(o, bev, 2)
    return smooth(o)


def rivet(name, loc, normal, mat, group, r=0.085):
    """A domed rivet head sitting on a surface with the given outward normal."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=r)
    bmesh.ops.scale(bm, vec=(1, 1, 0.55), verts=bm.verts)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(normal)).to_matrix()
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return smooth(give(mesh_obj(name, bm, group), mat))


def lid_point(t, grow=0.0):
    """The lid's outer elliptical arc: t = 0 at the front seam, pi at the back seam."""
    return Vector((0.0, -math.cos(t) * (D / 2 + grow), HB + math.sin(t) * (LR + grow)))


def lid_normal(t):
    # Normal of the ellipse (a = D/2 along y, b = LR along z), outward.
    n = Vector((0.0, -math.cos(t) / (D / 2), math.sin(t) / LR))
    return n.normalized()


def sweep_arc(name, x0, x1, t0, t1, grow, thick, mat, group, steps=28, bev=0.03):
    """A strip following the lid arc between x0..x1, from t0 to t1, `thick` deep, sitting `grow` outside the lid."""
    bm = bmesh.new()
    rows = []
    for i in range(steps + 1):
        t = t0 + (t1 - t0) * i / steps
        p_in = lid_point(t, grow)
        p_out = lid_point(t, grow + thick)
        rows.append([bm.verts.new((x, p.y, p.z)) for p in (p_in, p_out) for x in (x0, x1)])
    for a, b in zip(rows, rows[1:]):
        # order: in-x0, in-x1, out-x0, out-x1
        bm.faces.new((a[2], a[3], b[3], b[2]))  # outer
        bm.faces.new((a[1], a[0], b[0], b[1]))  # inner
        bm.faces.new((a[0], a[2], b[2], b[0]))  # side x0
        bm.faces.new((a[3], a[1], b[1], b[3]))  # side x1
    bm.faces.new((rows[0][0], rows[0][1], rows[0][3], rows[0][2]))
    bm.faces.new((rows[-1][2], rows[-1][3], rows[-1][1], rows[-1][0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = give(mesh_obj(name, bm, group), mat)
    bevel(o, bev, 2)
    return smooth(o)


def half_ellipse_disc(name, x, thick, grow, mat, group, steps=40, bev=0.03):
    """A lid end cap: the half-ellipse under the arc, `thick` along X centred at x."""
    bm = bmesh.new()
    pts = [lid_point(math.pi * i / steps, grow) for i in range(steps + 1)]
    a = [bm.verts.new((x - thick / 2, p.y, p.z)) for p in pts]
    b = [bm.verts.new((x + thick / 2, p.y, p.z)) for p in pts]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(steps):
        bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
    bm.faces.new((a[-1], b[-1], b[0], a[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = give(mesh_obj(name, bm, group), mat)
    bevel(o, bev, 2)
    return smooth(o)


def star_prism(name, center, normal, r_out, r_in, points, depth, mat, group, seed=3):
    """A hand-cut starburst stencil (uneven points) lying on a surface."""
    rr = random.Random(seed)
    bm = bmesh.new()
    verts = []
    for i in range(points * 2):
        a = math.pi * i / points + rr.uniform(-0.08, 0.08)
        r = (r_out * rr.uniform(0.72, 1.08)) if i % 2 == 0 else r_in * rr.uniform(0.85, 1.1)
        verts.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0)))
    f = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0, depth), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(normal)).to_matrix()
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return give(mesh_obj(name, bm, group), mat)


def rope(name, pts, radius, mat, group):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.resolution_u = 16
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    return link(o, group)


# ── Materials (procedural; Cycles) ───────────────────────────────────────────────────────────────────────────────


def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    return m, nt, b


def nd(nt, kind, **props):
    n = nt.nodes.new(kind)
    for k, v in props.items():
        if k in n.inputs:
            n.inputs[k].default_value = v
        else:
            setattr(n, k, v)
    return n


def edge_mask(nt, radius, gain):
    """1 on bevelled edges, 0 on flat faces (Bevel-node normal vs the true normal)."""
    bev = nd(nt, "ShaderNodeBevel", samples=8)
    bev.inputs["Radius"].default_value = radius
    geo = nd(nt, "ShaderNodeNewGeometry")
    dot = nd(nt, "ShaderNodeVectorMath", operation="DOT_PRODUCT")
    nt.links.new(bev.outputs["Normal"], dot.inputs[0])
    nt.links.new(geo.outputs["Normal"], dot.inputs[1])
    inv = nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(dot.outputs["Value"], inv.inputs[1])
    mul = nd(nt, "ShaderNodeMath", operation="MULTIPLY", use_clamp=True)
    mul.inputs[1].default_value = gain
    nt.links.new(inv.outputs[0], mul.inputs[0])
    return mul.outputs[0]


def ao_mult(nt, color_socket, strength, dist=0.35):
    ao = nd(nt, "ShaderNodeAmbientOcclusion", samples=16)
    ao.inputs["Distance"].default_value = dist
    mix = nd(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
    mix.inputs["Factor"].default_value = strength
    nt.links.new(color_socket, mix.inputs[6])
    nt.links.new(ao.outputs["AO"], mix.inputs[7])
    return mix.outputs[2]


def mix_rgb(nt, fac, a, b, blend="MIX"):
    m = nd(nt, "ShaderNodeMix", data_type="RGBA", blend_type=blend)
    if isinstance(fac, float):
        m.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, m.inputs["Factor"])
    for idx, v in ((6, a), (7, b)):
        if isinstance(v, tuple):
            m.inputs[idx].default_value = v
        else:
            nt.links.new(v, m.inputs[idx])
    return m.outputs[2]


def mat_paint_wood(name="PaintWood"):
    m, nt, b = new_mat(name)
    tc = nd(nt, "ShaderNodeTexCoord")
    # Grain: stretched wave bands along the plank (X for front/back/lid, Y for the ends: both via object coords).
    mapg = nd(nt, "ShaderNodeMapping")
    mapg.inputs["Scale"].default_value = (0.6, 6.0, 6.0)
    nt.links.new(tc.outputs["Object"], mapg.inputs["Vector"])
    wave = nd(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    wave.inputs["Scale"].default_value = 2.2
    wave.inputs["Distortion"].default_value = 7.0
    wave.inputs["Detail"].default_value = 3.0
    nt.links.new(mapg.outputs["Vector"], wave.inputs["Vector"])
    grain_c = nd(nt, "ShaderNodeMapRange")
    grain_c.inputs["From Min"].default_value = 0.2
    grain_c.inputs["From Max"].default_value = 1.0
    grain_c.inputs["To Min"].default_value = 0.0
    grain_c.inputs["To Max"].default_value = 0.12
    nt.links.new(wave.outputs["Fac"], grain_c.inputs["Value"])
    # Paint with a soft top-lit gradient (toy look) and grain showing through.
    sep = nd(nt, "ShaderNodeSeparateXYZ")
    geo = nd(nt, "ShaderNodeNewGeometry")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    up = nd(nt, "ShaderNodeMapRange")
    up.inputs["From Min"].default_value = -0.2
    up.inputs["From Max"].default_value = 1.0
    up.inputs["To Min"].default_value = 0.0
    up.inputs["To Max"].default_value = 0.35
    nt.links.new(sep.outputs["Z"], up.inputs["Value"])
    paint = mix_rgb(nt, up.outputs["Result"], PAINT, PAINT_HI)
    paint = mix_rgb(nt, grain_c.outputs["Result"], paint, DARKWOOD)
    # Chipped paint on the edges, broken up by noise → bare wood.
    noise = nd(nt, "ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.0
    noise.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    edge = edge_mask(nt, 0.05, 3.0)
    chip = nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(edge, chip.inputs[0])
    nt.links.new(noise.outputs["Fac"], chip.inputs[1])
    chipt = nd(nt, "ShaderNodeMath", operation="GREATER_THAN")
    chipt.inputs[1].default_value = 0.42
    nt.links.new(chip.outputs[0], chipt.inputs[0])
    col = mix_rgb(nt, chipt.outputs[0], paint, BARE)
    col = ao_mult(nt, col, 0.7)
    nt.links.new(col, b.inputs["Base Color"])
    rough = nd(nt, "ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.55
    rough.inputs["To Max"].default_value = 0.8
    nt.links.new(chipt.outputs[0], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    bump = nd(nt, "ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.02
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_flat(name, color, rough, metal=0.0, ao=0.6):
    m, nt, b = new_mat(name)
    rgb = nd(nt, "ShaderNodeRGB")
    rgb.outputs[0].default_value = color
    c = ao_mult(nt, rgb.outputs[0], ao)
    nt.links.new(c, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def mat_brass():
    m, nt, b = new_mat("Brass")
    edge = edge_mask(nt, 0.04, 4.0)
    geo = nd(nt, "ShaderNodeNewGeometry")
    sep = nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    up = nd(nt, "ShaderNodeMapRange")
    up.inputs["From Min"].default_value = -1.0
    up.inputs["From Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], up.inputs["Value"])
    base = mix_rgb(nt, up.outputs["Result"], BRASS_LO, BRASS)
    col = mix_rgb(nt, edge, base, BRASS_HI)
    col = ao_mult(nt, col, 0.75)
    nt.links.new(col, b.inputs["Base Color"])
    noise = nd(nt, "ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 14.0
    r = nd(nt, "ShaderNodeMapRange")
    r.inputs["To Min"].default_value = 0.16
    r.inputs["To Max"].default_value = 0.3
    nt.links.new(noise.outputs["Fac"], r.inputs["Value"])
    nt.links.new(r.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.35  # the house style keeps metal low so Roblox doesn't render it dark
    return m


def mat_cord():
    m, nt, b = new_mat("Cord")
    tc = nd(nt, "ShaderNodeTexCoord")
    mp = nd(nt, "ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(35))
    mp.inputs["Scale"].default_value = (22.0, 22.0, 22.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = nd(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
    wave.inputs["Scale"].default_value = 1.0
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    col = mix_rgb(nt, wave.outputs["Fac"], CORD_DK, CORD)
    col = ao_mult(nt, col, 0.6, 0.1)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    bump = nd(nt, "ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_emit(name, color, strength):
    m, nt, b = new_mat(name)
    b.inputs["Base Color"].default_value = color
    b.inputs["Emission Color"].default_value = color
    b.inputs["Emission Strength"].default_value = strength
    return m


M_PAINT = mat_paint_wood()
M_DARK = mat_flat("DarkWood", DARKWOOD, 0.85, ao=0.8)
M_BRASS = mat_brass()
M_CREAM = mat_flat("Cream", CREAM, 0.7, ao=0.3)
M_INK = mat_flat("Ink", INK, 0.6, ao=0.2)
M_CORD = mat_cord()
M_SPARK = mat_emit("Spark", SPARK, 12.0)
M_GLOW = mat_emit("InnerGlow", srgb("#FFC23A"), 6.0)

# ── Body ─────────────────────────────────────────────────────────────────────────────────────────────────────────
core_inset = PT
box("Core", (W - 2 * core_inset, D - 2 * core_inset, HB - 0.12), (0, 0, (HB - 0.12) / 2), M_DARK, "BodyWood", 0.02)
box("Base", (W - 0.06, D - 0.06, 0.10), (0, 0, 0.05), M_DARK, "BodyWood", 0.03)

ROWS = [(0.08, 0.52), (0.54, 0.98), (0.99, 1.47)]


def plank_row(prefix, length, along, z0, z1, outer, normal_sign, splits, mat):
    """Planks on a face whose outer surface is at `outer`: `along` = 'x' (front/back) or 'y' (ends); brick-staggered
    seams."""
    gap = 0.035
    edges = [-length / 2] + splits + [length / 2]
    for i in range(len(edges) - 1):
        a, b_ = edges[i] + (gap / 2 if i else 0), edges[i + 1] - (gap / 2 if i < len(edges) - 2 else 0)
        mid = (a + b_) / 2
        ln = b_ - a
        h = z1 - z0
        if along == "x":
            size = (ln, PT, h)
            loc = (mid, outer - normal_sign * PT / 2, (z0 + z1) / 2)
        else:
            size = (PT, ln, h)
            loc = (outer - normal_sign * PT / 2, mid, (z0 + z1) / 2)
        box(f"{prefix}_{i}", size, loc, mat, "BodyWood", 0.045)


for r, (z0, z1) in enumerate(ROWS):
    stagger = [[-0.7, 1.05], [-1.35, 0.35], [-0.2, 1.5]][r]
    plank_row(f"Front{r}", W - 0.02, "x", z0, z1, -D / 2, -1, stagger, M_PAINT)
    plank_row(f"Back{r}", W - 0.02, "x", z0, z1, D / 2, 1, [s * -1 for s in stagger][::-1], M_PAINT)
    estag = [[0.25], [-0.45], [0.5]][r]
    plank_row(f"EndL{r}", D - 2 * PT - 0.02, "y", z0, z1, -W / 2, -1, estag, M_PAINT)
    plank_row(f"EndR{r}", D - 2 * PT - 0.02, "y", z0, z1, W / 2, 1, [-s for s in estag], M_PAINT)

# Brass band around the body at the lid seam.
BT = 0.07
box("BandF", (W + 0.02, BT, BAND_H), (0, -D / 2 - BT / 2 + 0.01, BAND_Z), M_BRASS, "BodyBrass", 0.025)
box("BandB", (W + 0.02, BT, BAND_H), (0, D / 2 + BT / 2 - 0.01, BAND_Z), M_BRASS, "BodyBrass", 0.025)
box("BandL", (BT, D + 0.02, BAND_H), (-W / 2 - BT / 2 + 0.01, 0, BAND_Z), M_BRASS, "BodyBrass", 0.025)
box("BandR", (BT, D + 0.02, BAND_H), (W / 2 + BT / 2 - 0.01, 0, BAND_Z), M_BRASS, "BodyBrass", 0.025)

# Straps down the front and back of the body (the lid carries the arc above the seam).
ST = 0.09
for sx in (-STRAP_X, STRAP_X):
    for side in (-1, 1):
        y = side * (D / 2 + ST / 2 + 0.02)
        box(f"StrapBody{sx:+.0f}{side:+d}", (STRAP_W, ST, HB - 0.02), (sx, y, (HB - 0.02) / 2 + 0.01), M_BRASS, "BodyBrass", 0.03)
        for z in (0.32, 0.86):
            rivet(f"RivS{sx:+.0f}{side:+d}{z}", (sx, side * (D / 2 + ST + 0.03), z), (0, side, 0), M_BRASS, "BodyBrass")

# Corner caps: chunky brass blocks wrapping each body corner, bottom and top, a rivet on each outer face.
CAP = 0.5
for cx in (-1, 1):
    for cy in (-1, 1):
        for cz, zc in (("lo", CAP / 2), ("hi", BAND_Z)):
            loc = (cx * (W / 2 - CAP / 2 + 0.07), cy * (D / 2 - CAP / 2 + 0.07), zc)
            box(f"Cap{cx:+d}{cy:+d}{cz}", (CAP, CAP, CAP if cz == "lo" else BAND_H + 0.16), loc, M_BRASS, "BodyBrass", 0.07)
            rivet(f"RivCapF{cx:+d}{cy:+d}{cz}", (loc[0] - cx * 0.06, cy * (D / 2 + 0.075), zc), (0, cy, 0), M_BRASS, "BodyBrass", 0.075)
            rivet(f"RivCapS{cx:+d}{cy:+d}{cz}", (cx * (W / 2 + 0.075), loc[1] - cy * 0.06, zc), (cx, 0, 0), M_BRASS, "BodyBrass", 0.075)

# The bomb latch: a flattened brass sphere over the band, a collar, a keyhole and its own little fuse + spark.
LZ = 1.08
LY = -D / 2 - 0.2
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=24, radius=0.46)
bmesh.ops.scale(bm, vec=(1, 0.55, 1), verts=bm.verts)
bmesh.ops.translate(bm, vec=(0, LY, LZ), verts=bm.verts)
smooth(give(mesh_obj("LatchBall", bm, "BodyBrass"), M_BRASS))
cylinder("LatchCollar", 0.15, 0.16, (0.1, LY, LZ + 0.47), M_BRASS, "BodyBrass", segs=24, bev=0.02)
cylinder("LatchHasp", 0.13, 0.16, (0, -D / 2 - 0.05, LZ), M_BRASS, "BodyBrass", axis="Y", segs=24)
# Keyhole: a dark circle + tapered slot, sitting just proud of the ball's front.
kb = bmesh.new()
pts = []
for i in range(24):
    a = math.pi / 2 + 2 * math.pi * i / 24
    if -0.55 < math.sin(a) - 0.0 and i not in (11, 12, 13):
        pts.append((math.cos(a) * 0.1, math.sin(a) * 0.1 + 0.05))
pts += [(0.055, -0.07), (0.075, -0.2), (-0.075, -0.2), (-0.055, -0.07)]
fv = [kb.verts.new((x, 0, z)) for x, z in sorted(pts, key=lambda p: math.atan2(p[1] + 0.02, p[0]))]
f = kb.faces.new(fv)
ext = bmesh.ops.extrude_face_region(kb, geom=[f])
bmesh.ops.translate(kb, vec=(0, 0.04, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
bmesh.ops.recalc_face_normals(kb, faces=kb.faces)
bmesh.ops.translate(kb, vec=(0, LY - 0.46 * 0.55 - 0.005, LZ - 0.04), verts=kb.verts)
give(mesh_obj("Keyhole", kb, "BodyBrass"), M_INK)
rope("LatchFuse", [Vector((0.16, LY, LZ + 0.53)), Vector((0.26, LY, LZ + 0.68)), Vector((0.4, LY, LZ + 0.72))], 0.045, M_CORD, "BodyBrass")

# Cream starburst stencils on both ends, with two little paint flecks.
for sx in (-1, 1):
    star_prism(f"Star{sx:+d}", (sx * (W / 2 + 0.002), 0.0, 0.66), (sx, 0, 0), 0.5, 0.2, 8, 0.012, M_CREAM, "BodyWood", seed=5 + sx)
    for k, (dy, dz, r) in enumerate(((0.62, 0.95, 0.05), (-0.58, 0.3, 0.04))):
        cylinder(f"Fleck{sx:+d}{k}", r, 0.012, (sx * (W / 2 + 0.006), dy, dz), M_CREAM, "BodyWood", axis="X", segs=12, bev=0)

# The gold glow inside (only seen when the lid opens).
box("InnerGlow", (W - 2 * core_inset - 0.1, D - 2 * core_inset - 0.1, 0.02), (0, 0, HB - 0.11), M_GLOW, "Glow", 0)

# ── Lid ──────────────────────────────────────────────────────────────────────────────────────────────────────────
# Inner core (dark) so the plank seams never show daylight.
half_ellipse_disc("LidCore", 0, W - 2 * PT, -PT, M_DARK, "LidWood", bev=0.01)
# Staves: 6 curved planks along the arc, brick-staggered along X.
N = 6
for i in range(N):
    t0 = math.pi * i / N + (0.012 if i else 0.0)
    t1 = math.pi * (i + 1) / N - (0.012 if i < N - 1 else 0.0)
    cuts = [[-0.9], [0.6], [-1.4, 1.2], [-0.3], [1.0], [-1.1, 0.8]][i]
    xs = [-W / 2 + 0.01] + cuts + [W / 2 - 0.01]
    for j in range(len(xs) - 1):
        a = xs[j] + (0.018 if j else 0)
        b_ = xs[j + 1] - (0.018 if j < len(xs) - 2 else 0)
        sweep_arc(f"Stave{i}_{j}", a, b_, t0, t1, -PT, PT, M_PAINT, "LidWood", steps=6, bev=0.04)
# End caps (painted) with a brass rim along the arc.
for sx in (-1, 1):
    half_ellipse_disc(f"LidEnd{sx:+d}", sx * (W / 2 - 0.06), 0.12, -0.02, M_PAINT, "LidWood")
    sweep_arc(f"LidRim{sx:+d}", sx * (W / 2 - 0.02) - 0.07, sx * (W / 2 - 0.02) + 0.07, 0.0, math.pi, -0.05, 0.12, M_BRASS, "LidBrass", steps=40)
# Strap arcs over the lid with rivets.
for sx in (-STRAP_X, STRAP_X):
    sweep_arc(f"StrapLid{sx:+.0f}", sx - STRAP_W / 2, sx + STRAP_W / 2, -0.02, math.pi + 0.02, 0.0, ST, M_BRASS, "LidBrass", steps=36)
    for t in (0.42, math.pi / 2, math.pi - 0.42):
        p = lid_point(t, ST + 0.005)
        rivet(f"RivL{sx:+.0f}{t:.2f}", (sx, p.y, p.z), lid_normal(t), M_BRASS, "LidBrass")
# Lid lip (dark trim along the front/back seam edge of the lid).
for side in (-1, 1):
    box(f"LidLip{side:+d}", (W - 0.1, 0.12, 0.08), (0, side * (D / 2 - 0.04), HB + 0.04), M_DARK, "LidWood", 0.02)

# Fuse on top: a brass grommet and a braided cord curling up, the spark at its tip.
top = lid_point(math.pi / 2)
gb = bmesh.new()
bmesh.ops.create_cone(gb, cap_ends=True, segments=32, radius1=0.24, radius2=0.2, depth=0.14)
bmesh.ops.translate(gb, vec=(0, 0.0, top.z + 0.05), verts=gb.verts)
smooth(bevel(give(mesh_obj("Grommet", gb, "LidBrass"), M_BRASS), 0.03, 3))
cord_pts = [Vector((0, 0.0, top.z + 0.08)), Vector((0.02, 0.02, top.z + 0.32)), Vector((0.16, 0.04, top.z + 0.56)), Vector((0.4, 0.05, top.z + 0.66))]
rope("Fuse", cord_pts, 0.075, M_CORD, "LidBrass")
spark_at = cord_pts[-1] + Vector((0.06, 0, 0.02))

# Spark cores (Neon in game): a small 6-point star.
for name, at, r, group in (("Spark", spark_at, 0.17, "Glow"), ("LatchSpark", Vector((0.44, LY, LZ + 0.74)), 0.1, "Glow")):
    sb = bmesh.new()
    vs = []
    for i in range(12):
        a = math.pi * i / 6
        rr = r if i % 2 == 0 else r * 0.42
        vs.append(sb.verts.new((math.cos(a) * rr, 0, math.sin(a) * rr)))
    f = sb.faces.new(vs)
    e = bmesh.ops.extrude_face_region(sb, geom=[f])
    bmesh.ops.translate(sb, vec=(0, 0.05, 0), verts=[v for v in e["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.translate(sb, vec=at - Vector((0, 0.025, 0)), verts=sb.verts)
    bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
    give(mesh_obj(name, sb, group), M_SPARK)

LID_PARTS = set(o.name for g in ("LidWood", "LidBrass") for o in GROUPS[g]) | {"Spark"}
HINGE = Vector((0, D / 2, HB))

# ── Evaluate into plain meshes, join per group ───────────────────────────────────────────────────────────────────
deps = bpy.context.evaluated_depsgraph_get()


def evaluated_copy(o):
    ev = o.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=deps)
    me.transform(o.matrix_world)
    c = bpy.data.objects.new(o.name + "_x", me)
    scene.collection.objects.link(c)
    return c


def join(name, objs):
    base = objs[0]
    with bpy.context.temp_override(active_object=base, selected_editable_objects=objs, object=base):
        bpy.ops.object.join()
    base.name = name
    base.data.name = name
    return base


deps.update()
parts = {}
glow_copies = []
for g, objs in GROUPS.items():
    if g == "Glow":
        glow_copies = [(o.name, evaluated_copy(o)) for o in objs]
    else:
        parts[g] = join(g, [evaluated_copy(o) for o in objs])
for g, objs in GROUPS.items():
    for o in objs:
        bpy.data.objects.remove(o)
for name, c in glow_copies:
    c.name = name
    c.data.name = name
    parts[name] = c

tris = {n: sum(len(p.vertices) - 2 for p in o.data.polygons) for n, o in parts.items()}
print("TRIS", tris, "total", sum(tris.values()), flush=True)

# ── Lighting + cameras for review renders (Golden Fuse-ish, Asset Bible §2.5) ───────────────────────────────────
scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = srgb("#9AA7C4")
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world


def light(kind, loc, rot, energy, color, size=2.0):
    ld = bpy.data.lights.new(kind + str(len(bpy.data.lights)), kind)
    ld.energy = energy
    ld.color = color[:3]
    if kind == "AREA":
        ld.size = size
    lo = bpy.data.objects.new(ld.name, ld)
    lo.location = loc
    lo.rotation_euler = rot
    scene.collection.objects.link(lo)
    return lo


light("SUN", (0, 0, 10), (math.radians(48), math.radians(12), math.radians(-38)), 3.2, srgb("#FFE2BE"))
light("AREA", (-6, -5, 4), (math.radians(65), 0, math.radians(-50)), 260, srgb("#BFD2FF"), 6)
light("AREA", (5, 5, 5), (math.radians(-55), 0, math.radians(140)), 180, srgb("#FFF0DA"), 5)

floor_me = bpy.data.meshes.new("Floor")
fb = bmesh.new()
bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=30)
fb.to_mesh(floor_me)
floor = bpy.data.objects.new("Floor", floor_me)
scene.collection.objects.link(floor)
fm, fnt, fbsdf = new_mat("FloorMat")
fbsdf.inputs["Base Color"].default_value = srgb("#8E97A8")
fbsdf.inputs["Roughness"].default_value = 0.9
floor.data.materials.append(fm)

cam_d = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam
TARGET = Vector((0, 0, 1.15))


def shoot(name, loc, lens=60, res=(1200, 900), target=TARGET):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam_d.lens = lens
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = os.path.join(REN, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name, flush=True)


def set_lid(angle_deg):
    rot = Matrix.Translation(HINGE) @ Matrix.Rotation(math.radians(-angle_deg), 4, "X") @ Matrix.Translation(-HINGE)
    for n in ("LidWood", "LidBrass", "Spark"):
        parts[n].matrix_world = rot


DO_RENDER = "--no-render" not in argv
if DO_RENDER:
    shoot("hero", (7.2, -9.2, 4.6))
    shoot("front", (0, -14, 1.3), lens=70)
    shoot("side", (14, 0, 1.3), lens=70)
    shoot("back", (-7.5, 9.0, 4.2))
    set_lid(105)
    parts["InnerGlow"].hide_render = False
    shoot("open", (6.6, -9.4, 5.6))
    set_lid(0)

# ── Bake PBR maps per group, then export the FBX ─────────────────────────────────────────────────────────────────
RES = {"BodyWood": 1024, "BodyBrass": 1024, "LidWood": 1024, "LidBrass": 1024}


def select_only(o):
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def smart_uv(o):
    select_only(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def bsdf_of(mat):
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def route_to_emission(o, input_name):
    undo = []
    for mat in o.data.materials:
        b = bsdf_of(mat)
        nt = mat.node_tree
        prev = (b.inputs["Emission Strength"].default_value, tuple(b.inputs["Emission Color"].default_value))
        for l in [l for l in nt.links if l.to_socket == b.inputs["Emission Color"]]:
            nt.links.remove(l)
        src = b.inputs[input_name]
        if src.is_linked:
            nt.links.new(src.links[0].from_socket, b.inputs["Emission Color"])
        else:
            v = src.default_value
            b.inputs["Emission Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1)
        b.inputs["Emission Strength"].default_value = 1.0
        undo.append((mat, b, prev))
    return undo


def restore(undo):
    for mat, b, prev in undo:
        nt = mat.node_tree
        for l in [l for l in nt.links if l.to_socket == b.inputs["Emission Color"]]:
            nt.links.remove(l)
        b.inputs["Emission Strength"].default_value, b.inputs["Emission Color"].default_value = prev


def bake(o, img, kind):
    for mat in o.data.materials:
        n = mat.node_tree.nodes.new("ShaderNodeTexImage")
        n.image = img
        n.name = "BAKE_TARGET"
        mat.node_tree.nodes.active = n
    select_only(o)
    if kind == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True, margin=8)
    elif kind == "ROUGHNESS":
        bpy.ops.object.bake(type="ROUGHNESS", use_clear=True, margin=8)
    else:
        bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
    for mat in o.data.materials:
        n = mat.node_tree.nodes.get("BAKE_TARGET")
        if n:
            mat.node_tree.nodes.remove(n)


manifest = {"key": KEY, "tris": tris, "hinge": [HINGE.x, HINGE.z, -HINGE.y], "parts": {}}
if BAKE:
    scene.cycles.samples = 16
    floor.hide_render = True
    for name in RES:
        o = parts[name]
        smart_uv(o)
        maps = {}
        for kind in ("COLOR", "ROUGHNESS", "NORMAL", "METAL"):
            img = bpy.data.images.new(f"{name}_{kind}", RES[name], RES[name], alpha=False, float_buffer=(kind == "NORMAL"))
            if kind != "COLOR":
                img.colorspace_settings.name = "Non-Color"
            if kind in ("COLOR", "METAL"):
                u = route_to_emission(o, "Base Color" if kind == "COLOR" else "Metallic")
                bake(o, img, "EMIT")
                restore(u)
            else:
                bake(o, img, kind)
            path = os.path.join(TEX, f"{KEY.replace('.', '_')}_{name}_{kind}.png")
            img.filepath_raw = path
            img.file_format = "PNG"
            img.save()
            maps[kind] = os.path.basename(path)
            print("baked", name, kind, flush=True)
        manifest["parts"][name] = maps

# Export every part (baked groups + glow pieces) as one FBX; Studio splits it into MeshParts by object name.
for o in scene.objects:
    o.select_set(False)
for o in parts.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = parts["BodyWood"]
fbx = os.path.join(EXP, KEY + ".fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx,
    use_selection=True,
    apply_unit_scale=True,
    bake_space_transform=True,
    object_types={"MESH"},
    mesh_smooth_type="FACE",
    path_mode="STRIP",
)
manifest["glow"] = [n for n in parts if n not in RES]
with open(os.path.join(OUT, "manifest.json"), "w") as fh:
    json.dump(manifest, fh, indent=2)
print("EXPORTED", fbx, flush=True)
