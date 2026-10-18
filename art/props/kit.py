"""FUSE VALLEY — shared helpers for the headless-Blender prop builds (Asset Bible §1 Quality Bar, §2 house style).

Factored out of the approved Spark Crate build (art/crate/build.py) so every prop is made the same way:
bevelled primitives -> procedural Cycles materials -> per-group join -> Smart-UV + baked PBR maps
(COLOR / ROUGHNESS / NORMAL / METAL, metal kept <= 0.35 so Roblox doesn't render it dark) -> one FBX whose
objects Studio splits into MeshParts by name -> review renders.

A build script does:
    import kit
    kit.setup("Prop.Thing", bake=["Body", "Trim"], glow=["Light"])
    ... kit.box(...), kit.cylinder(..., group="Trim") ...
    parts = kit.finalize()
    kit.render_setup(target=(0, 0, 1)); kit.shoot("hero", (x, y, z))
    maps = kit.bake_all(parts, {"Body": 1024, "Trim": 1024})
    kit.export_fbx(parts); kit.write_manifest({...})

Units: 1 Blender unit = 1 stud, Z up, front = -Y. In Studio the FBX arrives x100 (scale 0.01) and turned 180 deg about
up: a Blender point (x, y, z) is Roblox model space (-x, z, y) (verified on the Spark Crate's hinge and latch fuse).
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


def flag(name):
    return name in argv


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def srgb(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [a])


class _State:
    key = ""
    out = ren = exp = tex = ""
    groups = {}
    bake = []
    glow = []
    scene = None
    cam = None
    cam_d = None
    floor = None
    target = Vector((0, 0, 1))


S = _State()


def setup(key, bake, glow):
    S.key = key
    S.out = os.path.join(ROOT, "art", "out", key)
    S.ren = os.path.join(S.out, "renders")
    S.exp = os.path.join(S.out, "export")
    S.tex = os.path.join(S.exp, "textures")
    for d in (S.ren, S.exp, S.tex):
        os.makedirs(d, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    S.scene = bpy.context.scene
    S.scene.unit_settings.system = "NONE"
    S.bake = list(bake)
    S.glow = list(glow)
    S.groups = {g: [] for g in S.bake + S.glow}
    return S


# ── Geometry ─────────────────────────────────────────────────────────────────────────────────────────────────────


def link(o, group):
    if o.name not in S.scene.collection.objects:
        S.scene.collection.objects.link(o)
    S.groups[group].append(o)
    return o


def mesh_obj(name, bm, group):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me), group)


def bevel(o, width, segs=3, angle=40):
    m = o.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segs
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
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


def orient(bm, normal, center):
    """Rotate local +Z onto `normal` (keeping local +Y as 'up' where possible) and move to `center`."""
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1)) if abs(n.z) < 0.99 else Vector((0, 1, 0))
    x = up.cross(n).normalized()
    if x.length < 1e-6:
        x = Vector((1, 0, 0))
    y = n.cross(x).normalized()
    rot = Matrix((x, y, n)).transposed()
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)


def box(name, size, loc, mat, group, bev=0.035, rot=None, segs=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if rot:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    o = mesh_obj(name, bm, group)
    give(o, mat)
    if bev:
        bevel(o, bev, segs)
    return smooth(o)


def hollow_box(name, size, loc, wall, depth, mat, group, open_side="top", bev=0.1, segs=4, inner_mat=None, rim_weight=0.25, inner_weight=0.25):
    """A box with a cavity `depth` deep opened on its top (or bottom) face, walls `wall` thick. Outer edges get the
    full bevel `bev`; the rim around the opening and the cavity edges get bev * rim_weight / inner_weight."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    want = 1 if open_side == "top" else -1
    f = max(bm.faces, key=lambda f: f.normal.z * want)
    r = bmesh.ops.inset_region(bm, faces=[f], thickness=wall, depth=0.0)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, -want * depth), verts=nv)
    bmesh.ops.delete(bm, geom=[f], context="FACES_ONLY") if f.is_valid else None
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.faces.index_update()
    # Bevel weights: full radius on the outer shell, a small one on the thin rim around the opening (so the rim
    # doesn't clamp the whole bevel down).
    wl = bm.edges.layers.float.new("bevel_weight_edge")
    rim_z = want * size[2] / 2
    for e in bm.edges:
        on_rim = all(abs(v.co.z - rim_z) < 1e-4 for v in e.verts)
        inner = all(abs(v.co.x) < size[0] / 2 - wall * 0.5 and abs(v.co.y) < size[1] / 2 - wall * 0.5 for v in e.verts)
        e[wl] = rim_weight if on_rim else (inner_weight if inner else 1.0)
    inner_faces = set()
    if inner_mat is not None:
        for fc in bm.faces:
            if all(abs(v.co.x) < size[0] / 2 - wall * 0.5 and abs(v.co.y) < size[1] / 2 - wall * 0.5 for v in fc.verts):
                inner_faces.add(fc.index)
    del r
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    o = mesh_obj(name, bm, group)
    give(o, mat)
    if inner_mat is not None:
        o.data.materials.append(inner_mat)
        for p in o.data.polygons:
            if p.index in inner_faces:
                p.material_index = 1
    if bev:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bev
        m.segments = segs
        m.limit_method = "WEIGHT"
        m.use_clamp_overlap = False
        m.harden_normals = False
    return smooth(o)


def cylinder(name, r, depth, loc, mat, group, axis="Z", segs=32, bev=0.02, r2=None, bev_segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    if axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)
    elif axis == "-Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"), verts=bm.verts)
    elif axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    o = give(mesh_obj(name, bm, group), mat)
    if bev:
        bevel(o, bev, bev_segs)
    return smooth(o)


def rivet(name, loc, normal, mat, group, r=0.085, squash=0.55, segs=16):
    """A domed rivet head sitting on a surface with the given outward normal."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=max(6, segs // 2), radius=r)
    bmesh.ops.scale(bm, vec=(1, 1, squash), verts=bm.verts)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(normal)).to_matrix()
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return smooth(give(mesh_obj(name, bm, group), mat))


def sphere(name, r, loc, mat, group, scale=(1, 1, 1), u=32, v=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return smooth(give(mesh_obj(name, bm, group), mat))


def prism(name, pts, depth, center, normal, mat, group, bev=0.03, bev_segs=3, smooth_it=True):
    """A flat 2D outline (local XY, CCW) extruded `depth` along local +Z, laid on a surface: local +Z -> `normal`,
    local +Y -> as close to world up as possible. The back face sits on `center`."""
    bm = bmesh.new()
    vs = [bm.verts.new((p[0], p[1], 0.0)) for p in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0, depth), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    orient(bm, normal, center)
    o = give(mesh_obj(name, bm, group), mat)
    if bev:
        bevel(o, bev, bev_segs, angle=30)
    return smooth(o) if smooth_it else o


def star_pts(points, r_out, r_in, rot=0.0, jitter=0.0, seed=3):
    rr = random.Random(seed)
    out = []
    for i in range(points * 2):
        a = math.pi / 2 + rot + math.pi * i / points + (rr.uniform(-jitter, jitter) if jitter else 0)
        r = r_out if i % 2 == 0 else r_in
        if jitter:
            r *= rr.uniform(0.85, 1.08)
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def rounded_rect_pts(w, h, r, steps=6):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, -h / 2 + r, -90), (w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def catmull(pts, n=6, closed=True):
    """Smooth a 2D control polygon with a Catmull-Rom spline (passes through every control point)."""
    out = []
    m = len(pts)
    rng_ = range(m) if closed else range(m - 1)
    for i in rng_:
        p0 = Vector(pts[(i - 1) % m] if closed or i > 0 else pts[0])
        p1 = Vector(pts[i])
        p2 = Vector(pts[(i + 1) % m])
        p3 = Vector(pts[(i + 2) % m] if closed or i + 2 < m else pts[-1])
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append((v.x, v.y))
    if not closed:
        out.append(tuple(pts[-1]))
    return out


def outline(ctrl, sharp, n=6):
    """A closed 2D outline through `ctrl`, smooth everywhere except at the indices in `sharp` (pointed tips)."""
    m = len(ctrl)
    sharp = sorted(sharp)
    out = []
    for si, s in enumerate(sharp):
        e = sharp[(si + 1) % len(sharp)]
        idx = list(range(s, e + 1)) if e > s else list(range(s, m)) + list(range(0, e + 1))
        piece = catmull([ctrl[i] for i in idx], n=n, closed=False)
        out += piece[:-1]
    return out


def lathe(name, profile, mat, group, segs=64, bev=0.0):
    """Revolve a (radius, z) profile (bottom -> top, open polyline) around Z. Caps the ends at r = 0 if the profile
    starts/ends there."""
    bm = bmesh.new()
    rings = []
    for k in range(segs):
        a = 2 * math.pi * k / segs
        ca, sa = math.cos(a), math.sin(a)
        rings.append([bm.verts.new((r * ca, r * sa, z)) for r, z in profile])
    n = len(profile)
    for k in range(segs):
        a, b = rings[k], rings[(k + 1) % segs]
        for i in range(n - 1):
            if profile[i][0] < 1e-6 and profile[i + 1][0] < 1e-6:
                continue
            if profile[i][0] < 1e-6:
                bm.faces.new((a[i], b[i + 1], a[i + 1]))
            elif profile[i + 1][0] < 1e-6:
                bm.faces.new((a[i], b[i], a[i + 1]))
            else:
                bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = give(mesh_obj(name, bm, group), mat)
    if bev:
        bevel(o, bev, 2)
    return smooth(o)


def torus(name, R, r, loc, mat, group, axis="Z", major=64, minor=16, scale=(1, 1, 1)):
    bm = bmesh.new()
    for i in range(major):
        a = 2 * math.pi * i / major
        for j in range(minor):
            b = 2 * math.pi * j / minor
            rr = R + r * math.cos(b)
            bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
    bm.verts.ensure_lookup_table()
    for i in range(major):
        for j in range(minor):
            a = i * minor + j
            b = ((i + 1) % major) * minor + j
            c = ((i + 1) % major) * minor + (j + 1) % minor
            d = i * minor + (j + 1) % minor
            bm.faces.new((bm.verts[a], bm.verts[b], bm.verts[c], bm.verts[d]))
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    if axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)
    elif axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return smooth(give(mesh_obj(name, bm, group), mat))


def rope(name, pts, radius, mat, group, res=16, bres=6):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = bres
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    return link(o, group)


def fillet_path(pts, r, steps=6):
    """Round the interior corners of an open 2D polyline with radius `r`."""
    P = [Vector(p) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        A, B, C = P[i - 1], P[i], P[i + 1]
        u, v = (A - B).normalized(), (C - B).normalized()
        th = u.angle(v)
        if th > math.pi - 1e-3:
            out.append(B)
            continue
        t = r / math.tan(th / 2)
        s, e = B + u * t, B + v * t
        c = B + (u + v).normalized() * (r / math.sin(th / 2))
        a0 = math.atan2(s.y - c.y, s.x - c.x)
        a1 = math.atan2(e.y - c.y, e.x - c.x)
        da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        for k in range(steps + 1):
            a = a0 + da * k / steps
            out.append(Vector((c.x + math.cos(a) * r, c.y + math.sin(a) * r)))
    out.append(P[-1])
    return [(p.x, p.y) for p in out]


def ribbon(name, pts2d, width, edge, mat, group, matrix, closed=False, res=12, poly=False):
    """A flat ribbon (`width` wide, rounded `edge`) following a 2D path drawn in the object's local XY plane; the
    ribbon's width runs along local Z. `matrix` places it in the world (must be a proper rotation)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "NONE"
    cu.extrude = max(0.0, width / 2 - edge)
    cu.bevel_depth = edge
    cu.bevel_resolution = 3
    cu.resolution_u = res
    if poly:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts2d) - 1)
        for pt, p in zip(sp.points, pts2d):
            pt.co = (p[0], p[1], 0, 1)
    else:
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts2d) - 1)
        for bp, p in zip(sp.bezier_points, pts2d):
            bp.co = (p[0], p[1], 0)
            bp.handle_left_type = bp.handle_right_type = "AUTO"
    sp.use_cyclic_u = closed
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    o.matrix_world = matrix
    return link(o, group)


def text(name, body, size, depth, mat, group, loc, normal=(0, -1, 0), bold=0.0, bev=0.04, bev_res=3):
    """Raised text (Blender's built-in font, emboldened with `bold`), front face toward `normal` (default -Y)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.offset = bold
    cu.extrude = depth / 2
    cu.bevel_depth = bev
    cu.bevel_resolution = bev_res
    cu.resolution_u = 10
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    n = Vector(normal).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
    if abs(n.z) < 0.99:
        # Keep the glyphs upright: after aiming +Z at the normal, spin about the normal so local +Y points up.
        y_now = (rot @ Vector((0, 1, 0, 0))).to_3d()
        want = (Vector((0, 0, 1)) - n * n.z).normalized()
        ang = y_now.angle(want)
        if y_now.cross(want).dot(n) < 0:
            ang = -ang
        rot = Matrix.Rotation(ang, 4, n) @ rot
    o.matrix_world = Matrix.Translation(Vector(loc)) @ rot
    return link(o, group)


def stroke(name, splines, radius, mat, group, matrix, flat=0.55, caps=True):
    """Puffy 'balloon' strokes (numerals, lettering): each spline is a 2D polyline in local XY, swept with a round
    profile of `radius`, flattened along local Z by `flat`, with round end caps. `matrix` places it (local Z = out)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    for pts in splines:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for pt, p in zip(sp.points, pts):
            pt.co = (p[0], p[1], 0, 1)
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    m = matrix @ Matrix.Diagonal((1, 1, flat, 1))
    o.matrix_world = m
    link(o, group)
    if caps:
        for i, pts in enumerate(splines):
            for j, p in enumerate((pts[0], pts[-1])):
                s = sphere(f"{name}_cap{i}{j}", radius, (p[0], p[1], 0), mat, group, u=24, v=12)
                s.matrix_world = m
    return o


def strip_on_plane(name, pts2d, widths, thick, mat, group, matrix):
    """A tapered flat strip (lava crack, painted line) along a 2D polyline in local XY, `thick` up local +Z;
    `matrix` places it. Mitred joints."""
    bm = bmesh.new()
    P = [Vector((p[0], p[1])) for p in pts2d]
    left, right = [], []
    for i, p in enumerate(P):
        if i == 0:
            d = (P[1] - P[0]).normalized()
        elif i == len(P) - 1:
            d = (P[-1] - P[-2]).normalized()
        else:
            d = ((P[i] - P[i - 1]).normalized() + (P[i + 1] - P[i]).normalized()).normalized()
        nrm = Vector((-d.y, d.x))
        w = widths[i] / 2
        left.append(p + nrm * w)
        right.append(p - nrm * w)
    # Quads segment by segment (robust where a jagged line turns sharply; no ngon triangulation).
    Lb = [bm.verts.new((v.x, v.y, 0)) for v in left]
    Rb = [bm.verts.new((v.x, v.y, 0)) for v in right]
    Lt = [bm.verts.new((v.x, v.y, thick)) for v in left]
    Rt = [bm.verts.new((v.x, v.y, thick)) for v in right]
    for i in range(len(P) - 1):
        bm.faces.new((Lt[i], Rt[i], Rt[i + 1], Lt[i + 1]))
        bm.faces.new((Lb[i + 1], Rb[i + 1], Rb[i], Lb[i]))
        bm.faces.new((Lb[i], Lt[i], Lt[i + 1], Lb[i + 1]))
        bm.faces.new((Rb[i + 1], Rt[i + 1], Rt[i], Rb[i]))
    bm.faces.new((Lb[0], Rb[0], Rt[0], Lt[0]))
    bm.faces.new((Lt[-1], Rt[-1], Rb[-1], Lb[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.transform(matrix)
    return give(mesh_obj(name, bm, group), mat)


def plane_matrix(origin, normal, x_axis):
    """Local XY drawing plane at `origin`: local X -> x_axis, local Z -> normal."""
    n = Vector(normal).normalized()
    x = Vector(x_axis).normalized()
    y = n.cross(x).normalized()
    m = Matrix((x, y, n)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


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
    if isinstance(fac, (float, int)):
        m.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, m.inputs["Factor"])
    for idx, v in ((6, a), (7, b)):
        if isinstance(v, tuple):
            m.inputs[idx].default_value = v
        else:
            nt.links.new(v, m.inputs[idx])
    return m.outputs[2]


def up_gradient(nt, lo=-1.0, hi=1.0, to_max=1.0):
    geo = nd(nt, "ShaderNodeNewGeometry")
    sep = nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    up = nd(nt, "ShaderNodeMapRange")
    up.inputs["From Min"].default_value = lo
    up.inputs["From Max"].default_value = hi
    up.inputs["To Min"].default_value = 0.0
    up.inputs["To Max"].default_value = to_max
    nt.links.new(sep.outputs["Z"], up.inputs["Value"])
    return up.outputs["Result"]


def noise_tex(nt, scale, detail=4.0, coord="Object"):
    tc = nd(nt, "ShaderNodeTexCoord")
    n = nd(nt, "ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    nt.links.new(tc.outputs[coord], n.inputs["Vector"])
    return n


def map_range(nt, src, fmin, fmax, tmin, tmax):
    r = nd(nt, "ShaderNodeMapRange")
    r.inputs["From Min"].default_value = fmin
    r.inputs["From Max"].default_value = fmax
    r.inputs["To Min"].default_value = tmin
    r.inputs["To Max"].default_value = tmax
    nt.links.new(src, r.inputs["Value"])
    return r.outputs["Result"]


def mat_flat(name, color, rough, metal=0.0, ao=0.6):
    m, nt, b = new_mat(name)
    rgb = nd(nt, "ShaderNodeRGB")
    rgb.outputs[0].default_value = color
    c = ao_mult(nt, rgb.outputs[0], ao)
    nt.links.new(c, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def mat_emit(name, color, strength):
    m, nt, b = new_mat(name)
    b.inputs["Base Color"].default_value = color
    b.inputs["Emission Color"].default_value = color
    b.inputs["Emission Strength"].default_value = strength
    return m


def mat_metal(name, lo, base, hi, rough=(0.16, 0.3), metal=0.35, edge_gain=4.0, ao=0.75, bump=0.0):
    """Toy brass / gold / iron: top-lit gradient lo -> base, bright bevelled edges, low metalness."""
    m, nt, b = new_mat(name)
    edge = edge_mask(nt, 0.04, edge_gain)
    col = mix_rgb(nt, up_gradient(nt), lo, base)
    col = mix_rgb(nt, edge, col, hi)
    col = ao_mult(nt, col, ao)
    nt.links.new(col, b.inputs["Base Color"])
    n = noise_tex(nt, 14.0)
    nt.links.new(map_range(nt, n.outputs["Fac"], 0, 1, rough[0], rough[1]), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = metal
    if bump:
        bn = nd(nt, "ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.02
        n2 = noise_tex(nt, 9.0, 8.0)
        nt.links.new(n2.outputs["Fac"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_gloss(name, base, hi, edge=None, rough=0.32, ao=0.65, grad=0.45, speckle=0.0, metal=0.0):
    """Glossy painted toy plastic: soft top-lit gradient base -> hi, a light bevel highlight, gentle noise."""
    m, nt, b = new_mat(name)
    col = mix_rgb(nt, up_gradient(nt, -0.6, 1.0, grad), base, hi)
    if edge:
        col = mix_rgb(nt, edge_mask(nt, 0.05, 2.5), col, edge)
    if speckle:
        n = noise_tex(nt, 22.0, 6.0)
        col = mix_rgb(nt, map_range(nt, n.outputs["Fac"], 0.35, 0.75, 0.0, speckle), col, hi)
    col = ao_mult(nt, col, ao)
    nt.links.new(col, b.inputs["Base Color"])
    n2 = noise_tex(nt, 9.0)
    nt.links.new(map_range(nt, n2.outputs["Fac"], 0, 1, rough - 0.06, rough + 0.06), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = metal
    return m


def mat_carpet(name, base, hi, dark):
    """Plush carpet / velvet: fine fibre noise, a sheen toward the light, matte."""
    m, nt, b = new_mat(name)
    n = noise_tex(nt, 60.0, 8.0)
    fib = map_range(nt, n.outputs["Fac"], 0.3, 0.7, 0.0, 1.0)
    col = mix_rgb(nt, fib, dark, base)
    col = mix_rgb(nt, up_gradient(nt, -0.2, 1.0, 0.35), col, hi)
    col = ao_mult(nt, col, 0.7)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.88
    b.inputs["Metallic"].default_value = 0.0
    bump = nd(nt, "ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.01
    nt.links.new(n.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_paint_wood(name, paint, paint_hi, bare, dark, chip=0.42, grain=0.12, rough=(0.55, 0.8), bump=0.25):
    """The Spark Crate's painted planks: stretched-wave grain, top-lit paint, edge chips showing `bare`."""
    m, nt, b = new_mat(name)
    tc = nd(nt, "ShaderNodeTexCoord")
    mapg = nd(nt, "ShaderNodeMapping")
    mapg.inputs["Scale"].default_value = (0.6, 6.0, 6.0)
    nt.links.new(tc.outputs["Object"], mapg.inputs["Vector"])
    wave = nd(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    wave.inputs["Scale"].default_value = 2.2
    wave.inputs["Distortion"].default_value = 7.0
    wave.inputs["Detail"].default_value = 3.0
    nt.links.new(mapg.outputs["Vector"], wave.inputs["Vector"])
    grain_c = map_range(nt, wave.outputs["Fac"], 0.2, 1.0, 0.0, grain)
    col = mix_rgb(nt, up_gradient(nt, -0.2, 1.0, 0.35), paint, paint_hi)
    col = mix_rgb(nt, grain_c, col, dark)
    noise = nd(nt, "ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.0
    noise.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    edge = edge_mask(nt, 0.05, 3.0)
    ch = nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(edge, ch.inputs[0])
    nt.links.new(noise.outputs["Fac"], ch.inputs[1])
    cht = nd(nt, "ShaderNodeMath", operation="GREATER_THAN")
    cht.inputs[1].default_value = chip
    nt.links.new(ch.outputs[0], cht.inputs[0])
    col = mix_rgb(nt, cht.outputs[0], col, bare)
    col = ao_mult(nt, col, 0.7)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(map_range(nt, cht.outputs[0], 0, 1, rough[0], rough[1]), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    bn = nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = bump
    bn.inputs["Distance"].default_value = 0.02
    nt.links.new(wave.outputs["Fac"], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_paint_metal(name, paint, hi, edge, bare, rough=0.3, chip=0.4, chip_scale=6.0, spots=0.71):
    """Glossy painted steel (mat_gloss's top-lit gradient and edge light) with chips on the edges and a sparse
    scatter of small knocks on the faces, both showing `bare`."""
    m, nt, b = new_mat(name)
    col = mix_rgb(nt, up_gradient(nt, -0.6, 1.0, 0.45), paint, hi)
    col = mix_rgb(nt, edge_mask(nt, 0.05, 2.5), col, edge)
    noise = noise_tex(nt, chip_scale, 6.0)
    em = edge_mask(nt, 0.04, 3.0)
    ch = nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(em, ch.inputs[0])
    nt.links.new(noise.outputs["Fac"], ch.inputs[1])
    cht = nd(nt, "ShaderNodeMath", operation="GREATER_THAN")
    cht.inputs[1].default_value = chip
    nt.links.new(ch.outputs[0], cht.inputs[0])
    knock = noise_tex(nt, 5.5, 6.0)
    kt = nd(nt, "ShaderNodeMath", operation="GREATER_THAN")
    kt.inputs[1].default_value = spots
    nt.links.new(knock.outputs["Fac"], kt.inputs[0])
    both = nd(nt, "ShaderNodeMath", operation="MAXIMUM")
    nt.links.new(cht.outputs[0], both.inputs[0])
    nt.links.new(kt.outputs[0], both.inputs[1])
    cht = both
    col = mix_rgb(nt, cht.outputs[0], col, bare)
    col = ao_mult(nt, col, 0.65)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(map_range(nt, cht.outputs[0], 0, 1, rough, 0.5), b.inputs["Roughness"])
    nt.links.new(map_range(nt, cht.outputs[0], 0, 1, 0.0, 0.3), b.inputs["Metallic"])
    bn = nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.25
    bn.inputs["Distance"].default_value = 0.01
    nt.links.new(cht.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_hazard(name, width=0.42):
    """Painted yellow-and-black diagonal hazard stripes (object space x + z, `width` studs each), glossy, with a light
    edge highlight."""
    m, nt, b = new_mat(name)
    tc = nd(nt, "ShaderNodeTexCoord")
    sep = nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    add = nd(nt, "ShaderNodeMath", operation="ADD")
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Z"], add.inputs[1])
    per = nd(nt, "ShaderNodeMath", operation="DIVIDE")
    per.inputs[1].default_value = width * 2
    nt.links.new(add.outputs[0], per.inputs[0])
    fr = nd(nt, "ShaderNodeMath", operation="FRACT")
    nt.links.new(per.outputs[0], fr.inputs[0])
    pp = nd(nt, "ShaderNodeMath", operation="PINGPONG")
    pp.inputs[1].default_value = 0.5
    nt.links.new(fr.outputs[0], pp.inputs[0])
    stripe = nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    stripe.inputs["From Min"].default_value = 0.24
    stripe.inputs["From Max"].default_value = 0.26
    nt.links.new(pp.outputs[0], stripe.inputs["Value"])
    yel = mix_rgb(nt, up_gradient(nt, -0.6, 1.0, 0.45), srgb("#FFC21E"), srgb("#FFE47A"))
    blk = mix_rgb(nt, up_gradient(nt, -0.6, 1.0, 0.45), srgb("#24242E"), srgb("#4A4A5A"))
    col = mix_rgb(nt, stripe.outputs["Result"], blk, yel)
    col = mix_rgb(nt, edge_mask(nt, 0.04, 2.0), col, srgb("#FFF2B0"), blend="SCREEN")
    col = ao_mult(nt, col, 0.6)
    nt.links.new(col, b.inputs["Base Color"])
    n2 = noise_tex(nt, 9.0)
    nt.links.new(map_range(nt, n2.outputs["Fac"], 0, 1, 0.26, 0.36), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    return m


# ── Evaluate into plain meshes, join per group ───────────────────────────────────────────────────────────────────


def _evaluated_copy(o, deps):
    ev = o.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=deps)
    me.transform(o.matrix_world)
    c = bpy.data.objects.new(o.name + "_x", me)
    S.scene.collection.objects.link(c)
    return c


def _join(name, objs):
    base = objs[0]
    if len(objs) > 1:
        with bpy.context.temp_override(active_object=base, selected_editable_objects=objs, object=base):
            bpy.ops.object.join()
    base.name = name
    base.data.name = name
    return base


def finalize():
    """Bake every group's modifiers/curves into one plain mesh per group, named after the group (= MeshPart name)."""
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    copies = {g: [_evaluated_copy(o, deps) for o in objs] for g, objs in S.groups.items() if objs}
    for objs in S.groups.values():
        for o in objs:
            bpy.data.objects.remove(o)
    parts = {g: _join(g, cs) for g, cs in copies.items()}
    for o in parts.values():
        o.matrix_world = Matrix.Identity(4)
    return parts


def tris_of(parts):
    return {n: sum(len(p.vertices) - 2 for p in o.data.polygons) for n, o in parts.items()}


def bounds(parts):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in parts.values():
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def pivot_of(parts):
    """The Studio importer's pivot: the bottom centre of the whole model's bounding box."""
    lo, hi = bounds(parts)
    return Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)), lo, hi


def rbx(v, pivot=None):
    """Blender point/vector -> Roblox model space (-x, z, y), optionally relative to the pivot."""
    v = Vector(v) - (Vector(pivot) if pivot is not None else Vector())
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def rbx_size(lo, hi):
    """Bounding-box size in Roblox axes (X, Y up, Z)."""
    d = Vector(hi) - Vector(lo)
    return [round(d.x, 4), round(d.z, 4), round(d.y, 4)]


def rbx_dir(v):
    v = Vector(v)
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def blend(v):
    return [round(c, 4) for c in v]


# ── Review renders (Golden Fuse-ish, Asset Bible §2.5) ───────────────────────────────────────────────────────────


def render_setup(target, samples=None, floor_color="#8E97A8", world_color="#9AA7C4"):
    sc = S.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = int(samples or arg("--samples", "64"))
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = srgb(world_color)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sc.world = world

    def light(kind, loc, rot, energy, color, size=2.0):
        ld = bpy.data.lights.new(kind + str(len(bpy.data.lights)), kind)
        ld.energy = energy
        ld.color = color[:3]
        if kind == "AREA":
            ld.size = size
        lo = bpy.data.objects.new(ld.name, ld)
        lo.location = loc
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
        return lo

    t = Vector(target)
    k = max(1.0, t.z / 1.15)
    light("SUN", (0, 0, 10), (math.radians(48), math.radians(12), math.radians(-38)), 3.2, srgb("#FFE2BE"))
    light("AREA", (-6 * k, -5 * k, 4 * k), (math.radians(65), 0, math.radians(-50)), 260 * k * k, srgb("#BFD2FF"), 6 * k)
    light("AREA", (5 * k, 5 * k, 5 * k), (math.radians(-55), 0, math.radians(140)), 180 * k * k, srgb("#FFF0DA"), 5 * k)

    fme = bpy.data.meshes.new("Floor")
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=60)
    fb.to_mesh(fme)
    S.floor = bpy.data.objects.new("Floor", fme)
    sc.collection.objects.link(S.floor)
    fm, fnt, fbsdf = new_mat("FloorMat")
    fbsdf.inputs["Base Color"].default_value = srgb(floor_color)
    fbsdf.inputs["Roughness"].default_value = 0.9
    S.floor.data.materials.append(fm)

    S.cam_d = bpy.data.cameras.new("Cam")
    S.cam = bpy.data.objects.new("Cam", S.cam_d)
    sc.collection.objects.link(S.cam)
    sc.camera = S.cam
    S.target = t


def shoot(name, loc, lens=60, res=(1200, 900), target=None):
    tgt = Vector(target) if target is not None else S.target
    S.cam.location = loc
    S.cam.rotation_euler = (tgt - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    S.cam_d.lens = lens
    S.scene.render.resolution_x, S.scene.render.resolution_y = res
    S.scene.render.filepath = os.path.join(S.ren, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name, flush=True)


def rotate_parts(parts, names, pivot, axis, angle_deg):
    rot = Matrix.Translation(Vector(pivot)) @ Matrix.Rotation(math.radians(angle_deg), 4, Vector(axis)) @ Matrix.Translation(-Vector(pivot))
    for n in names:
        parts[n].matrix_world = rot


# ── Bake PBR maps per group, export ──────────────────────────────────────────────────────────────────────────────


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


def _bsdf_of(mat):
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def _route_to_emission(o, input_name):
    undo = []
    for mat in o.data.materials:
        b = _bsdf_of(mat)
        nt = mat.node_tree
        prev = (b.inputs["Emission Strength"].default_value, tuple(b.inputs["Emission Color"].default_value))
        for lk in [lk for lk in nt.links if lk.to_socket == b.inputs["Emission Color"]]:
            nt.links.remove(lk)
        src = b.inputs[input_name]
        if src.is_linked:
            nt.links.new(src.links[0].from_socket, b.inputs["Emission Color"])
        else:
            v = src.default_value
            b.inputs["Emission Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1)
        b.inputs["Emission Strength"].default_value = 1.0
        undo.append((mat, b, prev))
    return undo


def _restore(undo):
    for mat, b, prev in undo:
        nt = mat.node_tree
        for lk in [lk for lk in nt.links if lk.to_socket == b.inputs["Emission Color"]]:
            nt.links.remove(lk)
        b.inputs["Emission Strength"].default_value, b.inputs["Emission Color"].default_value = prev


def _bake(o, img, kind):
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


def bake_maps(o, label, res, kinds=("COLOR", "ROUGHNESS", "NORMAL", "METAL"), uv=True):
    """Bake `kinds` for object `o` into export/textures/<Key>_<label>_<KIND>.png; returns {KIND: filename}."""
    S.scene.cycles.samples = 16
    if S.floor:
        S.floor.hide_render = True
    if uv:
        smart_uv(o)
    maps = {}
    for kind in kinds:
        img = bpy.data.images.new(f"{label}_{kind}", res, res, alpha=False, float_buffer=(kind == "NORMAL"))
        if kind != "COLOR":
            img.colorspace_settings.name = "Non-Color"
        if kind in ("COLOR", "METAL"):
            u = _route_to_emission(o, "Base Color" if kind == "COLOR" else "Metallic")
            _bake(o, img, "EMIT")
            _restore(u)
        else:
            _bake(o, img, kind)
        path = os.path.join(S.tex, f"{S.key.replace('.', '_')}_{label}_{kind}.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        maps[kind] = os.path.basename(path)
        print("baked", label, kind, flush=True)
    return maps


def bake_all(parts, res):
    return {name: bake_maps(parts[name], name, r) for name, r in res.items()}


def export_fbx(parts, scale=1.0):
    """Export the parts as one FBX. Roblox caps each imported mesh at 2048 units on its longest axis, and an FBX in the
    default centimetres puts 1 stud at 100 units, so any part over 20.48 studs gets shrunk on its own (the assembly
    breaks). Tall props export at scale=0.1 (1 stud = 10 units) and studio_import_props.luau scales them by 0.1."""
    for o in S.scene.objects:
        o.select_set(False)
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(parts.values()))
    fbx = os.path.join(S.exp, S.key + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        apply_unit_scale=True,
        global_scale=scale,
        bake_space_transform=True,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        path_mode="STRIP",
    )
    print("EXPORTED", fbx, flush=True)
    return fbx


def write_manifest(data):
    path = os.path.join(S.out, "manifest.json")
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2)
    print("MANIFEST", path, flush=True)
