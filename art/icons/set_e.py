"""FUSE VALLEY icons — set E: Explosion, Trail, Firework, Plate, Wave, Palette, XP (art/ref/icons/icons_sheet2.png
cells 12-18; references only — every icon here is real geometry)."""

import math

import bmesh
import bpy
import lib
from lib import cyl, glossy, icon, prism, sphere, srgb, star_pts, torus
from mathutils import Matrix, Vector

# ── Palette ─────────────────────────────────────────────────────────────────────────────────────────────────────
RED = srgb("#E8322B")
DEEP_RED = srgb("#B8141C")
AMBER = srgb("#FFA51F")
PALE = srgb("#FFF4B8")
SMOKE = srgb("#6F6670")
SOOT = srgb("#4A3C3E")
BRASS = srgb("#C98F22")
BRASS_LT = srgb("#E9B544")
HAND = srgb("#FFB810")
WOOD_LT = srgb("#D9913F")


# ── Local helpers ───────────────────────────────────────────────────────────────────────────────────────────────
def _link_active(o):
    bpy.context.scene.collection.objects.link(o)
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)


def meta(name, elems, mat, res=0.04, thresh=0.6, outline=0.03, stiff=2.0):
    """A fused puffy blob from metaball elements (co, radius[, scale xyz]) converted to a smooth mesh. Names must not
    share a base name (Blender merges metaball families by name)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = thresh
    for e in elems:
        el = mb.elements.new()
        el.co = Vector(e[0])
        el.radius = e[1]
        el.stiffness = stiff
        if len(e) > 2:
            el.type = "ELLIPSOID"
            el.size_x, el.size_y, el.size_z = e[2]
    o = bpy.data.objects.new(name, mb)
    _link_active(o)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.select_set(False)
    o.data.materials.clear()
    o.data.materials.append(mat)
    return lib.finish(o, 0, outline=outline)


def capsule(name, r, length, mat, base, angle, ry=None, outline=0.03, taper=1.0):
    """A rounded capsule of radius r and straight length `length`, starting at `base` (x, y, z) and pointing at `angle`
    degrees from +Z toward +X in the picture plane."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=r)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= taper
            v.co.y *= taper
            v.co.z = v.co.z * taper + length
    if ry:
        bmesh.ops.scale(bm, vec=(1, ry, 1), verts=bm.verts)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(angle), 3, "Y"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(base), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return lib.finish(o, 0, outline=outline)


def squircle(name, size, mat, loc, power=0.6, outline=0.03):
    """A rounded box: a sphere pushed toward its bounding cube (|c|**power), then scaled to `size` half-extents."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
    for v in bm.verts:
        v.co = Vector([math.copysign(abs(c) ** power, c) * k for c, k in zip(v.co, size)])
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return lib.finish(o, 0, outline=outline)


def raw_prism(name, pts2d, depth, mat, loc=(0, 0, 0)):
    """Like lib.prism but without finishing, so booleans can be applied before the bevel."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -depth / 2, z)) for x, z in pts2d]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, depth, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def cut(o, cutters):
    """Boolean-difference each cutter (x, z, r) cylinder (along Y) out of `o` and bake the result."""
    tmp = []
    for i, (x, z, r) in enumerate(cutters):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=r, radius2=r, depth=3.0)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(x, 0, z), verts=bm.verts)
        me = bpy.data.meshes.new(f"Cut{i}")
        bm.to_mesh(me)
        bm.free()
        c = bpy.data.objects.new(f"Cut{i}", me)
        bpy.context.scene.collection.objects.link(c)
        m = o.modifiers.new(f"Bool{i}", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = c
        tmp.append(c)
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(deps), depsgraph=deps)
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.data = me
    for c in tmp:
        bpy.data.objects.remove(c, do_unlink=True)
    return o


def turn(objs, axis, deg, pivot=(0, 0, 0)):
    """Rotate objects about a pivot in world space (object-space shading coordinates are kept)."""
    p = Vector(pivot)
    rot = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p)
    for o in objs:
        o.matrix_world = rot @ o.matrix_world


def meshes():
    return {o for o in bpy.context.scene.objects if o.type == "MESH"}


def sparkle(name, x, z, r, mat, y=-0.3, points=4):
    return prism(name, star_pts(points, r, r * (0.3 if points == 4 else 0.45)), r * 0.25, mat, loc=(x, y, z), bevel=r * 0.08, outline=r * 0.08)


def stripe_mat(name, c1, c2, freq, turns):
    """Helical candy stripes (object space, around Z): c1 glossy enamel, c2 metallic gold."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = c1
    b.inputs["Roughness"].default_value = 0.25
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = 0.6
        b.inputs["Coat Roughness"].default_value = 0.08
    g = nt.nodes.new("ShaderNodeBsdfPrincipled")
    g.inputs["Base Color"].default_value = c2
    g.inputs["Roughness"].default_value = 0.24
    g.inputs["Metallic"].default_value = 0.4
    if "Coat Weight" in g.inputs:
        g.inputs["Coat Weight"].default_value = 0.6
        g.inputs["Coat Roughness"].default_value = 0.08
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])

    def math_node(op, a=None, bval=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate((a, bval)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                nt.links.new(v, n.inputs[i])
        return n.outputs[0]

    ang = math_node("ARCTAN2", sep.outputs["Y"], sep.outputs["X"])
    s = math_node("ADD", math_node("MULTIPLY", ang, turns / (2 * math.pi)), math_node("MULTIPLY", sep.outputs["Z"], freq))
    fac = math_node("GREATER_THAN", math_node("FRACT", s), 0.5)
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(fac, mix.inputs["Fac"])
    nt.links.new(b.outputs[0], mix.inputs[1])
    nt.links.new(g.outputs[0], mix.inputs[2])
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def orb_mat(name, core, rim, emit=0.9):
    """Glassy orb: deep blue facing the camera, bright cyan toward the rim (layer-weight driven emission)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = core
    b.inputs["Roughness"].default_value = 0.08
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = 1.0
        b.inputs["Coat Roughness"].default_value = 0.03
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = core
    ramp.color_ramp.elements[1].color = rim
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[1].position = 0.85
    nt.links.new(lw.outputs["Facing"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = emit
    return m


def brushed_mat(name, color, metal=0.6, rough=0.3):
    """Brushed brass: horizontal streaks in roughness and a faint bump."""
    m = glossy(name, color, rough, metal, 0.5)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.5, 1.5, 60.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 4.0
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = rough - 0.12
    ramp.inputs["To Max"].default_value = rough + 0.12
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Value"])
    nt.links.new(ramp.outputs["Result"], b.inputs["Roughness"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def blob_pts(r, lobes=7, wob=0.08, seed=0.0, n=40, sx=1.0, sz=1.0):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * (1 + wob * math.sin(lobes * a + seed) + wob * 0.5 * math.sin((lobes + 3) * a + seed * 2.3))
        pts.append((math.cos(a) * rr * sx, math.sin(a) * rr * sz))
    return pts


def swoosh_pts(cx, cz, rx, rz, a0, a1, width, rot=0.0, n=56, peak=0.5, ex=0.7):
    """A tapered swoosh outline: the outer edge runs along an ellipse (rx, rz, rotated `rot` degrees) from angle a0 to
    a1 (degrees); the inner edge is pulled in by a width that swells to `width` at `peak` and tapers to points."""
    c, s_ = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def at(a, k):
        x, z = math.cos(a) * (rx - k), math.sin(a) * (rz - k)
        return (cx + x * c - z * s_, cz + x * s_ + z * c)

    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        u = t / peak * 0.5 if t < peak else 0.5 + (t - peak) / (1 - peak) * 0.5
        w = width * math.sin(math.pi * u) ** ex
        outer.append(at(a, 0))
        if 0 < i < n:
            inner.append(at(a, w))
    return outer + inner[::-1]


# ── Icons ───────────────────────────────────────────────────────────────────────────────────────────────────────
@icon
def Explosion():
    def lobe(name, r, mat, loc, sy=0.72, outline=0.022, segs=28):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=r)
        lib.xform(bm, loc, None, (1, sy, 1))
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(mat)
        return lib.finish(o, 0, outline=outline)

    def ring(tag, n, rad, r, y, mats, phase=0.0, cx=0.0, cz=0.0, outline=0.022):
        for i in range(n):
            a = 2 * math.pi * i / n + phase
            rr = rad * (1 + 0.07 * math.sin(i * 2.7))
            deg = math.degrees(a) % 360
            lobe(f"{tag}{i}", r * (1 + 0.16 * math.sin(i * 1.9 + 0.5)), mats(deg), (cx + math.cos(a) * rr, y - 0.02 * i, cz + math.sin(a) * rr), outline=outline)

    smoke = glossy("Smoke", SMOKE, 0.62, coat=0.08)
    red = glossy("FireRed", srgb("#E0301C"), 0.45, coat=0.15, emit=0.25)
    dark = glossy("FireDark", srgb("#B3161A"), 0.45, coat=0.15, emit=0.15)
    hot = glossy("FireHot", srgb("#F2561C"), 0.45, coat=0.15, emit=0.35)
    orange = glossy("FireOrange", srgb("#FF8116"), 0.45, coat=0.15, emit=0.5)
    yellow = glossy("FireYellow", srgb("#FFC930"), 0.45, coat=0.15, emit=0.7)
    core = glossy("FireCore", srgb("#FFEE9A"), 0.45, coat=0.15, emit=0.6)

    # back smoke, upper corners
    for i, (x, z, r) in enumerate(((-0.62, 0.8, 0.36), (-0.25, 1.0, 0.32), (-0.92, 0.5, 0.27), (0.72, 0.62, 0.35), (1.0, 0.36, 0.26), (0.46, 0.9, 0.27))):
        lobe(f"SmokeT{i}", r, smoke, (x, 0.6 + 0.03 * i, z))
    # fire: back filler, outer lobes coloured by angle, then orange, yellow and the hot core
    lobe("Fill", 0.82, red, (0, 0.35, 0), sy=0.5, outline=0.02)
    ring("Outer", 9, 0.72, 0.42, 0.15, lambda d: hot if 40 < d < 140 else (dark if 220 < d < 320 else red))
    ring("Mid", 7, 0.44, 0.35, -0.12, lambda d: orange, phase=0.35, outline=0.014)
    lobe("MidFill", 0.5, orange, (0, -0.1, 0), outline=0)
    ring("Inner", 5, 0.24, 0.27, -0.34, lambda d: yellow, phase=0.8, cx=-0.04, cz=0.06, outline=0.008)
    ring("Core", 4, 0.11, 0.18, -0.52, lambda d: core, phase=0.3, cx=-0.06, cz=0.1, outline=0)
    lobe("CoreC", 0.2, core, (-0.06, -0.55, 0.1), outline=0)
    # front smoke, lower corners
    for i, (x, z, r) in enumerate(((-0.74, -0.76, 0.33), (-0.38, -0.98, 0.28), (-1.02, -0.52, 0.24), (-0.98, -0.94, 0.23), (0.76, -0.76, 0.32), (1.03, -0.52, 0.23), (0.44, -0.98, 0.26), (0.98, -0.94, 0.22))):
        lobe(f"SmokeB{i}", r, smoke, (x, -0.7 - 0.03 * i, z))
    soot = glossy("Soot", SOOT, 0.35)
    for i, (x, z, r) in enumerate(((-1.22, 0.05, 0.09), (-1.28, -0.22, 0.06), (1.27, 0.08, 0.08), (0.12, 1.26, 0.08), (-1.0, 1.0, 0.07), (0.2, -1.3, 0.08))):
        lobe(f"Debris{i}", r, soot, (x, -0.9, z), sy=1.0, outline=0.015, segs=16)
    lib.group_tilt(-10, 6)


@icon
def Trail():
    amber = glossy("TrailAmber", srgb("#FF8C12"), 0.3, emit=1.0)
    yel = glossy("TrailYellow", srgb("#FFD43A"), 0.3, emit=1.2)
    core = glossy("TrailCore", srgb("#FFF3B8"), 0.3, emit=1.15)
    e = dict(cx=-0.25, cz=-0.1, rot=18)
    prism("Swoosh", swoosh_pts(rx=1.08, rz=0.88, a0=170, a1=-118, width=0.62, peak=0.48, **e), 0.16, amber, bevel=0.035, outline=0.03)
    prism("SwooshMid", swoosh_pts(rx=1.02, rz=0.82, a0=150, a1=-100, width=0.42, peak=0.47, **e), 0.16, yel, loc=(0, -0.05, 0), bevel=0.03, outline=0.012)
    prism("SwooshCore", swoosh_pts(rx=0.97, rz=0.77, a0=120, a1=-70, width=0.2, peak=0.45, **e), 0.16, core, loc=(0, -0.09, 0), bevel=0.02, outline=0)
    prism("Inner", swoosh_pts(rx=0.55, rz=0.45, a0=160, a1=-95, width=0.15, peak=0.45, **e), 0.12, yel, loc=(0, -0.02, 0), bevel=0.02, outline=0.018)
    prism("Streak", swoosh_pts(rx=1.3, rz=1.08, a0=150, a1=62, width=0.08, peak=0.6, **e), 0.08, amber, bevel=0.012, outline=0.014)
    prism("Streak2", swoosh_pts(rx=1.22, rz=0.98, a0=-60, a1=-125, width=0.07, peak=0.4, **e), 0.08, amber, bevel=0.012, outline=0.014)
    star = glossy("SparkGold", srgb("#FFE45C"), 0.25, emit=1.5)
    sparkle("StarBig", 0.98, 1.05, 0.34, star)
    sparkle("StarR", 1.22, -0.2, 0.22, star)
    sparkle("StarL", -0.55, -0.12, 0.14, star)
    sparkle("StarB", 0.88, -0.8, 0.15, star)
    sparkle("StarL2", -0.9, -0.42, 0.1, star)
    for i, (x, z) in enumerate(((1.3, 0.55), (1.32, 0.2), (0.55, -1.05))):
        sphere(f"Mote{i}", 0.045, star, loc=(x, -0.3, z), outline=0.01)
    lib.group_tilt(-12, 8)


@icon
def Firework():
    before = meshes()
    cyl("Body", 0.34, 1.15, stripe_mat("Stripes", RED, srgb("#F7B21E"), 2.4, 3), bevel=0.02)
    cyl("Base", 0.37, 0.14, glossy("RimRed", DEEP_RED, 0.3), loc=(0, 0, -0.62), bevel=0.04)
    cyl("Nozzle", 0.25, 0.12, glossy("Nozzle", srgb("#5A2A1E"), 0.4), loc=(0, 0, -0.72), bevel=0.03, outline=0.02)
    torus("Collar", 0.37, 0.065, lib.gold("CollarGold"), loc=(0, 0, 0.6))
    cone = glossy("ConeRed", RED, 0.25)
    cyl("Cone", 0.44, 0.74, cone, loc=(0, 0, 0.99), r2=0.02, bevel=0.03)
    sphere("Tip", 0.05, cone, loc=(0, 0, 1.35), outline=0.015)
    # exhaust: three nested flame tongues (outline in XZ, pointing down)
    fl = [(0.22, 0), (0.34, -0.2), (0.38, -0.44), (0.46, -0.74), (0.2, -0.6), (0.05, -1.12), (-0.13, -0.62), (-0.36, -0.86), (-0.33, -0.46), (-0.32, -0.2), (-0.22, 0)]

    def sc(k, kz):
        return [(x * k, z * kz) for x, z in fl]

    prism("FlameOuter", sc(1.0, 1.0), 0.12, glossy("FlameO", srgb("#FF6A14"), 0.3, emit=1.3), loc=(0, 0, -0.74), bevel=0.025, outline=0.025)
    prism("FlameMid", sc(0.68, 0.72), 0.12, glossy("FlameY", srgb("#FFC21E"), 0.3, emit=1.5), loc=(0, -0.05, -0.74), bevel=0.02, outline=0)
    prism("FlameCore", sc(0.36, 0.45), 0.12, glossy("FlameC", PALE, 0.3, emit=2.0), loc=(0, -0.09, -0.74), bevel=0.015, outline=0)
    turn(meshes() - before, "Y", 40)
    star = glossy("SparkGold", srgb("#FFE45C"), 0.25, emit=1.5)
    sparkle("S1", -1.0, 0.1, 0.2, star)
    sparkle("S2", -0.05, -1.3, 0.17, star, points=5)
    sparkle("S3", -1.3, -0.8, 0.12, star)
    for i, (x, z) in enumerate(((-0.62, -0.2), (-1.15, -1.3), (-0.45, -1.45), (-1.0, -0.4))):
        sphere(f"Ember{i}", 0.045, glossy("Ember", AMBER, 0.3, emit=1.4), loc=(x, -0.3, z), outline=0.01)
    lib.group_tilt(-16, 8)


@icon
def Plate():
    def chamfer_rect(w, h, c):
        x, z = w / 2, h / 2
        return [(-x + c, -z), (x - c, -z), (x, -z + c), (x, z - c), (x - c, z), (-x + c, z), (-x, z - c), (-x, -z + c)]

    prism("Frame", chamfer_rect(2.4, 1.2, 0.2), 0.24, glossy("BrassDark", BRASS, 0.3, 0.55, 0.5), bevel=0.07, segs=2)
    prism("Panel", chamfer_rect(2.12, 0.92, 0.13), 0.08, brushed_mat("BrassBrushed", BRASS_LT), loc=(0, -0.14, 0), bevel=0.025, outline=0.012)
    rivet = glossy("Rivet", srgb("#B07A1C"), 0.22, 0.6, 0.6)
    for sx in (-1, 1):
        for sz in (-1, 1):
            sphere(f"Rivet{sx}{sz}", 0.085, rivet, loc=(sx * 0.88, -0.18, sz * 0.26), scale=(1, 0.65, 1), outline=0.014)
    lib.group_tilt(-18, 10)


@icon
def Wave():
    skin = glossy("Hand", HAND, 0.3, coat=0.6)
    before = meshes()
    squircle("Palm", (0.6, 0.24, 0.54), skin, (0, 0, -0.04))
    # fingers fan from inside the palm: (base x, base z, length, angle, radius); pinky on the left, behind the palm
    for i, (x, z, ln, ang, r) in enumerate(((-0.42, 0.14, 0.46, -40, 0.16), (-0.19, 0.28, 0.64, -16, 0.172), (0.08, 0.3, 0.7, 0, 0.178), (0.34, 0.24, 0.58, 17, 0.17))):
        capsule(f"Finger{i}", r, ln, skin, (x, 0.06, z), ang, taper=0.95, ry=0.92)
    capsule("Thumb", 0.19, 0.34, skin, (0.5, -0.1, -0.24), 46, taper=0.95, ry=0.9)
    w = cyl("Wrist", 0.29, 0.34, skin, loc=(0.06, 0.06, -0.66), bevel=0.09)
    w.data.transform(Matrix.Diagonal((1, 0.58, 1, 1)))
    turn(meshes() - before, "Y", -20)
    arc = glossy("Motion", srgb("#FFB21E"), 0.3, emit=0.7)
    for i, (rx, a0, a1, wd) in enumerate(((1.08, 14, 60, 0.1), (1.27, 20, 54, 0.085), (1.04, 198, 244, 0.1), (1.22, 204, 238, 0.085))):
        prism(f"Arc{i}", swoosh_pts(0.0, 0.05, rx, rx, a0, a1, wd, peak=0.5, ex=0.6), 0.08, arc, loc=(0, -0.1, 0), bevel=0.015, outline=0.016)
    lib.group_tilt(-12, 8)


@icon
def Palette():
    wood = glossy("Wood", WOOD_LT, 0.4, coat=0.5)
    pal = raw_prism("Palette", blob_pts(1.0, lobes=3, wob=0.04, seed=0.6, n=72, sx=1.12, sz=0.86), 0.2, wood)
    cut(pal, [(1.12, -0.42, 0.34), (0.55, -0.1, 0.16)])
    lib.finish(pal, 0.07, segs=4, outline=0.035)
    blobs = ((-0.12, 0.5, "#2BC24A", 0.24), (-0.66, 0.22, "#2F6BFF", 0.23), (0.34, 0.24, "#FFC21A", 0.2), (-0.62, -0.3, "#E8322B", 0.23), (-0.12, -0.5, "#8A3BFF", 0.22))
    for i, (x, z, c, r) in enumerate(blobs):
        prism(f"Paint{i}", blob_pts(r, lobes=3, wob=0.07, seed=i * 1.7, n=40, sx=1.15, sz=0.9), 0.16, glossy(f"Paint{i}", srgb(c), 0.16, coat=0.85), loc=(x, -0.17, z), bevel=0.075, segs=5, outline=0.02)
    # brush across the front, bottom-centre to top-right, overhanging the palette at both ends
    ang = 36
    d = Vector((math.sin(math.radians(ang)), 0, math.cos(math.radians(ang))))
    o = Vector((0.2, -0.45, -0.2))
    handle = glossy("Handle", srgb("#8A4A22"), 0.32)
    cyl("Handle", 0.085, 1.5, handle, loc=o - d * 0.3, rot=[("Y", ang)], r2=0.12, bevel=0.03)
    sphere("HandleEnd", 0.088, handle, loc=o - d * 1.05, outline=0.02)
    cyl("Ferrule", 0.13, 0.3, lib.silver("Ferrule"), loc=o + d * 0.58, rot=[("Y", ang)], bevel=0.03)
    capsule("Bristles", 0.2, 0.14, glossy("Bristle", srgb("#B9773A"), 0.55, coat=0.1), tuple(o + d * 0.86), ang, taper=0.78)
    capsule("BrushPaint", 0.165, 0.14, glossy("BrushBlue", srgb("#2F9BFF"), 0.15, coat=0.8), tuple(o + d * 1.1), ang, taper=0.3)
    lib.group_tilt(-14, 12)


@icon
def XP():
    sphere("Orb", 1.0, orb_mat("Orb", srgb("#0F55F0"), srgb("#6FE6FF"), emit=1.0), outline=0.022)
    bolt = [(0.14, 0.7), (-0.44, -0.06), (-0.05, -0.06), (-0.22, -0.7), (0.44, 0.12), (0.05, 0.12), (0.28, 0.7)]
    prism("Bolt", bolt, 0.16, glossy("Bolt", srgb("#DDF7FF"), 0.2, emit=1.2), loc=(0, -0.98, 0), bevel=0.04, outline=0.018)
    # wispy swirls hugging the left and right of the orb
    swirl = glossy("Swirl", srgb("#4CCBFF"), 0.2, emit=1.3)
    prism("SwirlL", swoosh_pts(0.0, 0.0, 1.2, 1.12, 105, 235, 0.11, rot=-10, peak=0.55), 0.06, swirl, loc=(0, -0.5, 0), bevel=0.012, outline=0.012)
    prism("SwirlR", swoosh_pts(0.0, 0.0, 1.2, 1.12, -75, 50, 0.11, rot=-10, peak=0.45), 0.06, swirl, loc=(0, -0.5, 0), bevel=0.012, outline=0.012)
    bub = glossy("Bubble", srgb("#7FD8FF"), 0.08, coat=1.0, emit=0.5)
    for i, (x, z, r) in enumerate(((0.55, 1.15, 0.11), (1.26, 0.62, 0.07), (1.28, -0.4, 0.09), (-1.16, -0.62, 0.08), (-0.9, -1.04, 0.11), (-1.28, 0.32, 0.06), (0.45, -1.22, 0.07))):
        sphere(f"Bubble{i}", r, bub, loc=(x, -0.2, z), outline=0.012)
    lib.group_tilt(-12, 8)
