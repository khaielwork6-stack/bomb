"""FUSE VALLEY icons — set D: Plus, Check, Arrow, Crate, CrateInferno, GiftBox, Mega, Fuse, Sparkler, Badge
(art/ref/icons/icons_sheet2.png; Crate after the approved Spark Crate in art/out/Crate.Spark). The sheets are references
only: every icon here is real geometry."""

import math
import random

import bmesh
import bpy
import lib
from lib import box, cyl, glossy, gold, icon, prism, sphere, srgb, star_pts
from mathutils import Matrix, Vector

# ── Palette ─────────────────────────────────────────────────────────────────────────────────────────────────────
GREEN = srgb("#14B00A")
GREEN_SIDE = srgb("#0E7A0A")
ARROW = srgb("#FFB300")
ARROW_SIDE = srgb("#F07C00")
CRATE = srgb("#E2501A")
CRATE_DK = srgb("#5E1E0C")
IRON = srgb("#2C2C34")
ROCK = srgb("#2A0E0A")
LAVA = srgb("#FFB21E")
PURPLE = srgb("#5E12C8")
PURPLE_LID = srgb("#6C1CDC")
PINK = srgb("#E0107E")
STARGOLD = srgb("#FFC81E")
BOMB_PURPLE = srgb("#3A1C68")
RUBY = srgb("#B8001A")
ROPE = srgb("#8C4800")
ROPE_DK = srgb("#3A1A08")
BRONZE = srgb("#B8661F")
BRONZE_IN = srgb("#6E3510")
SPARK_OUT = srgb("#FF6A00")
SPARK_IN = srgb("#FFF2A0")
TWINKLE = srgb("#FFB51C")


# ── Local helpers ───────────────────────────────────────────────────────────────────────────────────────────────
def emissive(name, color, strength=1.0):
    """Pure emission (no diffuse/specular, so it stays saturated under the studio lights). The Principled node stays in
    the tree, unlinked, because the hull outline reads its base colour."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = color
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def ball(name, r, mat, loc=(0, 0, 0), segs=16, outline=0.0):
    """A low-poly sphere for rivets and small knobs (lib.sphere is 48x24, too heavy for dozens of rivets)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=r)
    lib.xform(bm, loc)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def two_tone(o, side_mat):
    """Give an extruded (prism) shape a darker side wall, like the reference's chunky buttons."""
    o.data.materials.append(side_mat)
    for p in o.data.polygons:
        if abs(p.normal.y) < 0.7:
            p.material_index = 1
    return o


def tilt_m(yaw, pitch):
    """The same matrix lib.group_tilt applies, for placing camera-facing bits after the tilt."""
    return Matrix.Rotation(math.radians(pitch), 4, "X") @ Matrix.Rotation(math.radians(yaw), 4, "Z")


def place(objs, m):
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def catmull(pts, n=8, closed=False):
    """Densify a control polyline with a Catmull-Rom spline."""
    p = [Vector(x) for x in pts]
    m = len(p)
    out = []
    for i in range(m if closed else m - 1):
        p0 = p[(i - 1) % m] if closed else p[max(i - 1, 0)]
        p1, p2 = p[i % m], p[(i + 1) % m]
        p3 = p[(i + 2) % m] if closed else p[min(i + 2, m - 1)]
        for j in range(n):
            t = j / n
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))
    if not closed:
        out.append(p[-1].copy())
    return out


def sweep(name, pts, r, mat, n=14, side=None, flat=1.0, closed=False, caps=True, rfun=None, outline=0.02):
    """Sweep an (elliptical) cross-section along a polyline. `side` fixes the cross-section's first axis (radius r);
    the second axis gets r*flat. Open ends get rounded caps. Built as a mesh so it can take a hull outline."""
    pts = [Vector(x) for x in pts]
    m = len(pts)
    tans = []
    for i in range(m):
        a = pts[(i - 1) % m] if closed else pts[max(i - 1, 0)]
        b = pts[(i + 1) % m] if closed else pts[min(i + 1, m - 1)]
        tans.append((b - a).normalized())
    frames = []
    if side is not None:
        s = Vector(side).normalized()
        for t in tans:
            b = (s - t * s.dot(t)).normalized()
            frames.append((b, t.cross(b)))
    else:
        ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
        b = (ref - tans[0] * ref.dot(tans[0])).normalized()
        for t in tans:
            b = (b - t * b.dot(t)).normalized()
            frames.append((b, t.cross(b)))
    bm = bmesh.new()

    def rad(i):
        return r * (rfun(i / (m - 1)) if rfun else 1.0)

    def ring(p, b, nn, rr):
        return [bm.verts.new(p + b * math.cos(2 * math.pi * j / n) * rr + nn * math.sin(2 * math.pi * j / n) * rr * flat) for j in range(n)]

    def bridge(a, c):
        for j in range(n):
            bm.faces.new((a[j], a[(j + 1) % n], c[(j + 1) % n], c[j]))

    rings = [ring(p, b, nn, rad(i)) for i, (p, (b, nn)) in enumerate(zip(pts, frames))]
    for i in range(m - 1):
        bridge(rings[i], rings[i + 1])
    if closed:
        bridge(rings[-1], rings[0])
    elif caps:
        for end, sgn in ((0, -1), (m - 1, 1)):
            p, t = pts[end], tans[end] * sgn
            d = rad(end) * min(1.0, flat)
            prev = rings[end]
            for j in (1, 2, 3):
                phi = j / 4 * math.pi / 2
                cur = [bm.verts.new(p + (v.co - p) * math.cos(phi) + t * math.sin(phi) * d) for v in rings[end]]
                bridge(prev, cur)
                prev = cur
            c = bm.verts.new(p + t * d)
            for j in range(n):
                bm.faces.new((prev[j], prev[(j + 1) % n], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def offset_path(cpts, h):
    """A closed outline of half-width h round an open 2D polyline (mitred joints, square ends)."""
    p = [Vector(x) for x in cpts]

    def nrm(a, b):
        d = (b - a).normalized()
        return Vector((-d.y, d.x))

    left, right = [], []
    for i, q in enumerate(p):
        if i == 0:
            v, k = nrm(p[0], p[1]), h
        elif i == len(p) - 1:
            v, k = nrm(p[-2], p[-1]), h
        else:
            n1, n2 = nrm(p[i - 1], q), nrm(q, p[i + 1])
            v = (n1 + n2).normalized()
            k = h / v.dot(n1)
        left.append(q + v * k)
        right.append(q - v * k)
    return [(v.x, v.y) for v in left + right[::-1]]


def jag_star(points, r_out, r_in, seed, jitter=0.3, rot=90.0):
    rng = random.Random(seed)
    out = []
    for i in range(points * 2):
        a = math.radians(rot) + math.pi * i / points
        r = r_out * (1 - jitter * rng.random()) if i % 2 == 0 else r_in * (1 - 0.2 * rng.random())
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def spark(name, loc, r, seed=1):
    """A two-layer camera-facing spark burst (emissive), added after the tilt."""
    loc = Vector(loc)
    prism(name + "O", jag_star(10, r, r * 0.45, seed), 0.04, emissive("SparkO", SPARK_OUT, 1.15), loc=loc, bevel=0.006, outline=0.018)
    prism(name + "I", star_pts(8, r * 0.62, r * 0.28, 80), 0.04, emissive("SparkI", SPARK_IN, 1.6), loc=loc + Vector((0, -0.03, 0)), bevel=0.006, outline=0)
    sphere(name + "C", r * 0.16, emissive("SparkC", srgb("#FFFFFF"), 2.0), loc=loc + Vector((0, -0.08, 0)), outline=0)


def sparkle(name, loc, r, mat, outline=0.012):
    """A four-point twinkle star facing the camera."""
    prism(name, star_pts(4, r, r * 0.3), 0.03, mat, loc=loc, bevel=0.004, outline=outline)


def flame_pts(w, h, lean=0.0, wig=0.08, n=20):
    pts_r, pts_l = [], []
    for i in range(n + 1):
        t = i / n
        hw = w * (math.sqrt(t) * (1 - t) ** 1.25) / 0.36
        c = lean * t * t * w + math.sin(t * math.pi * 2.2) * wig * w
        pts_r.append((c + hw, h * t))
        pts_l.append((c - hw, h * t))
    return pts_r + pts_l[-2:0:-1]


def flame(name, loc, w, h, lean=0.0, outline=0.016):
    """A three-tone emissive flame tongue facing the camera, plus a smaller side tongue."""
    loc = Vector(loc)
    for k, (sx, sw, sh, sl) in enumerate(((0.0, 1.0, 1.0, lean), (-0.45 * w * (1 if lean >= 0 else -1), 0.6, 0.55, lean * 1.6))):
        o = loc + Vector((sx, 0.08 * k, 0))
        ww, hh, ll = w * sw, h * sh, sl
        prism(f"{name}{k}A", flame_pts(ww, hh, ll), 0.04, emissive("FlameA", srgb("#E8300A"), 1.1), loc=o, bevel=0.006, segs=1, outline=outline)
        prism(f"{name}{k}B", flame_pts(ww * 0.68, hh * 0.74, ll * 0.8), 0.04, emissive("FlameB", srgb("#FF8410"), 1.15), loc=o + Vector((0, -0.02, 0.0)), bevel=0.005, segs=1, outline=0)
        prism(f"{name}{k}C", flame_pts(ww * 0.38, hh * 0.46, ll * 0.5), 0.04, emissive("FlameC", srgb("#FFE25A"), 1.3), loc=o + Vector((0, -0.04, 0.0)), bevel=0.004, segs=1, outline=0)


def clip(poly, d, c):
    """Sutherland-Hodgman: keep the part of a 2D polygon with p.d <= c."""
    out = []
    for k in range(len(poly)):
        a, b = poly[k], poly[(k + 1) % len(poly)]
        da, db = a.dot(d) - c, b.dot(d) - c
        if da <= 0:
            out.append(a)
        if (da <= 0) != (db <= 0):
            out.append(a.lerp(b, da / (da - db)))
    return out


def voronoi_cells(seeds, lo_u, hi_u, lo_v, hi_v, gap):
    """Voronoi cells of `seeds` in a rectangle, each inset by gap/2 from its bisectors (uniform cracks between them)."""
    cells = []
    for i, si in enumerate(seeds):
        poly = [Vector((lo_u, lo_v)), Vector((hi_u, lo_v)), Vector((hi_u, hi_v)), Vector((lo_u, hi_v))]
        for j, sj in enumerate(seeds):
            if i != j and len(poly) >= 3:
                d = (sj - si).normalized()
                poly = clip(poly, d, ((si + sj) / 2).dot(d) - gap / 2)
        if len(poly) >= 3:
            cells.append([(p.x, p.y) for p in poly])
    return cells


# ── Icons ───────────────────────────────────────────────────────────────────────────────────────────────────────
@icon
def Plus():
    a, w = 1.0, 0.37
    pts = [(w, a), (w, w), (a, w), (a, -w), (w, -w), (w, -a), (-w, -a), (-w, -w), (-a, -w), (-a, w), (-w, w), (-w, a)]
    o = prism("Plus", pts, 0.46, glossy("Green", GREEN, 0.25, coat=0.5), bevel=0.13, segs=4)
    two_tone(o, glossy("GreenSide", GREEN_SIDE, 0.3, coat=0.4))
    lib.group_tilt(-20, 12)


@icon
def Check():
    pts = offset_path([(-0.85, 0.05), (-0.3, -0.55), (0.92, 0.78)], 0.25)
    o = prism("Check", pts, 0.46, glossy("Green", GREEN, 0.25, coat=0.5), bevel=0.13, segs=4)
    two_tone(o, glossy("GreenSide", GREEN_SIDE, 0.3, coat=0.4))
    lib.group_tilt(-20, 12)


@icon
def Arrow():
    pts = [(-1.0, 0.33), (0.05, 0.33), (0.05, 0.82), (1.0, 0.0), (0.05, -0.82), (0.05, -0.33), (-1.0, -0.33)]
    o = prism("Arrow", pts, 0.46, glossy("ArrowGold", ARROW, 0.24, 0.1, 0.5), bevel=0.13, segs=4)
    two_tone(o, glossy("ArrowSide", ARROW_SIDE, 0.28, 0.1, 0.4))
    lib.group_tilt(-20, 12)


@icon
def Badge():
    bronze = glossy("Bronze", BRONZE, 0.28, 0.6, 0.5)
    cyl("Disc", 0.95, 0.26, bronze, rot=[("X", 90)], bevel=0.07, segs=64)
    # raised rim: an annulus standing proud of the face, then a dark groove and the recessed inner disc
    ring = [(math.cos(2 * math.pi * i / 64) * 0.93, math.sin(2 * math.pi * i / 64) * 0.93) for i in range(64)]
    rim = prism("Rim", ring, 0.1, bronze, loc=(0, -0.14, 0), bevel=0.05, outline=0)
    hole = rim.modifiers.new("Hole", "BOOLEAN")
    cutter = cyl("Cut", 0.7, 1.0, bronze, rot=[("X", 90)], loc=(0, -0.14, 0), bevel=0, outline=0)
    hole.object = cutter
    rim.modifiers.move(len(rim.modifiers) - 1, 0)
    cutter.hide_render = True
    cutter.hide_viewport = True
    cyl("Groove", 0.71, 0.03, glossy("Groove", srgb("#3A1A06"), 0.5), rot=[("X", 90)], loc=(0, -0.14, 0), bevel=0, outline=0, segs=64)
    cyl("Inner", 0.69, 0.04, glossy("BronzeIn", BRONZE_IN, 0.35, 0.5, 0.4), rot=[("X", 90)], loc=(0, -0.15, 0), bevel=0.01, outline=0, segs=64)
    prism("Star", star_pts(5, 0.58, 0.28), 0.24, gold(), loc=(0, -0.21, -0.02), bevel=0.09, segs=4)
    lib.group_tilt(-18, 8)


@icon
def Fuse():
    ctrl = [(0.5, 0.0, -0.72), (-0.15, 0.05, -0.85), (-0.72, 0.0, -0.55), (-0.88, -0.05, 0.0), (-0.62, 0.0, 0.48), (-0.1, 0.05, 0.62), (0.32, 0.0, 0.5), (0.58, -0.05, 0.68), (0.74, 0.0, 0.98)]
    path = catmull(ctrl, 40)
    s = [0.0]
    for a, b in zip(path, path[1:]):
        s.append(s[-1] + (b - a).length)
    tans = [(path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized() for i in range(len(path))]
    sweep("Core", path[6:], 0.13, glossy("RopeCore", ROPE_DK, 0.8, coat=0), n=10, side=(0, 1, 0), outline=0)
    rope = glossy("Rope", ROPE, 0.55, coat=0.15)
    rope.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.2
    pitch, a_off = 0.8, 0.13
    for k in range(3):
        pts = []
        for p, t, sl in zip(path, tans, s):
            bv = Vector((0, 1, 0))
            bv = (bv - t * bv.dot(t)).normalized()
            nv = t.cross(bv)
            th = 2 * math.pi * sl / pitch + 2 * math.pi * k / 3
            pts.append(p + (bv * math.cos(th) + nv * math.sin(th)) * a_off)
        sweep(f"Strand{k}", pts, 0.11, rope, n=10, outline=0.024)
    yaw, pitch_t = -8, 6
    lib.group_tilt(yaw, pitch_t)
    m = tilt_m(yaw, pitch_t)
    tip = m @ (path[-1] + tans[-1] * 0.12)
    spark("Spark", tip + Vector((0, -0.4, 0)), 0.55, seed=3)
    gl = emissive("Twinkle", TWINKLE, 1.1)
    for i, (dx, dz, r) in enumerate(((-0.5, 0.25, 0.1), (0.48, 0.12, 0.08), (0.18, -0.5, 0.08), (-0.25, 0.52, 0.06))):
        sparkle(f"Tw{i}", tip + Vector((dx, -0.3, dz)), r, gl)


@icon
def Sparkler():
    yaw, pitch = -10, 6
    a, b, c = Vector((-0.95, 0, -1.05)), Vector((-0.42, 0, -0.5)), Vector((0.22, 0, 0.18))
    sweep("Handle", [a, b], 0.055, glossy("Wire", srgb("#7A4A1E"), 0.45, 0.2), n=12)
    sweep("Coat", [b + (b - c).normalized() * 0.02, c], 0.082, glossy("Coat", srgb("#B87A1E"), 0.45, 0.4), n=14)
    sweep("Band", [b + (b - c).normalized() * 0.04, b + (c - b).normalized() * 0.05], 0.092, glossy("BandDk", srgb("#3A2210"), 0.5), n=14, outline=0.012)
    lib.group_tilt(yaw, pitch)
    m = tilt_m(yaw, pitch)
    ctr = m @ (c + (c - b).normalized() * 0.08) + Vector((0, -0.4, 0))
    # streaks: thin emissive needles radiating from the hot tip
    rng = random.Random(7)
    streak = emissive("Streak", srgb("#FFB020"), 1.2)
    for i in range(14):
        ang = 2 * math.pi * i / 14 + rng.uniform(-0.15, 0.15)
        ln = rng.uniform(0.55, 0.85)
        pts = [(0, 0.035), (ln * 0.5, 0.014), (ln, 0), (ln * 0.5, -0.014), (0, -0.035)]
        prism(f"Ray{i}", pts, 0.02, streak, loc=ctr + Vector((0, 0.05, 0)), rot=[("Y", -math.degrees(ang))], bevel=0, outline=0.012)
    prism("BurstO", jag_star(14, 0.52, 0.18, 11, 0.35), 0.04, emissive("SparkO", SPARK_OUT, 1.15), loc=ctr, bevel=0.006, outline=0.018)
    prism("BurstI", jag_star(10, 0.36, 0.14, 5, 0.25, 72), 0.04, emissive("SparkI", SPARK_IN, 1.6), loc=ctr + Vector((0, -0.03, 0)), bevel=0.006, outline=0)
    sphere("Core", 0.1, emissive("Hot", srgb("#FFFFFF"), 2.0), loc=ctr + Vector((0, -0.08, 0)), outline=0)
    gl = emissive("Twinkle", TWINKLE, 1.1)
    for i, (dx, dz, r) in enumerate(((-0.75, 0.45, 0.17), (0.55, 0.62, 0.14), (0.82, -0.12, 0.15), (-0.55, -0.15, 0.11), (0.15, 0.95, 0.12), (0.45, -0.62, 0.12), (-0.95, -0.62, 0.09), (-0.25, 0.82, 0.08), (0.95, 0.35, 0.08))):
        sparkle(f"Tw{i}", ctr + Vector((dx, -0.02, dz)), r, gl, outline=0.016)


@icon
def GiftBox():
    body = glossy("Purple", PURPLE, 0.32, coat=0.4)
    rib = glossy("Ribbon", PINK, 0.25, coat=0.6)
    box("Box", (1.5, 1.5, 1.18), body, loc=(0, 0, -0.11), bevel=0.08)
    box("Lid", (1.66, 1.66, 0.38), glossy("PurpleLid", PURPLE_LID, 0.3, coat=0.4), loc=(0, 0, 0.62), bevel=0.08)
    box("RibX", (0.32, 1.54, 1.2), rib, loc=(0, 0, -0.11), bevel=0.03, outline=0.015)
    box("RibY", (1.54, 0.32, 1.2), rib, loc=(0, 0, -0.11), bevel=0.03, outline=0.015)
    box("RibXL", (0.34, 1.7, 0.42), rib, loc=(0, 0, 0.62), bevel=0.04, outline=0.015)
    box("RibYL", (1.7, 0.34, 0.42), rib, loc=(0, 0, 0.62), bevel=0.04, outline=0.015)
    top = Vector((0, -0.05, 0.92))
    for sd in (-1, 1):
        d = Vector((sd * math.cos(math.radians(34)), 0, math.sin(math.radians(34))))
        nn = Vector((-d.z, 0, d.x)) * sd
        lean = Matrix.Rotation(math.radians(-28), 3, "X")  # loops lean back so their inner face shows
        pts = [top + lean @ (d * 0.46 * (1 - math.cos(u)) + nn * 0.34 * math.sin(u)) for u in (2 * math.pi * i / 48 for i in range(48))]
        sweep(f"Loop{sd}", pts, 0.075, rib, n=18, side=lean @ Vector((0, 1, 0)), flat=2.2, closed=True)
        tail = [top + Vector((0, -0.05, -0.02)), top + Vector((sd * 0.2, -0.42, -0.08)), top + Vector((sd * 0.3, -0.78, -0.16)), top + Vector((sd * 0.36, -0.9, -0.44))]
        dirv = (tail[2] - tail[0]).normalized()
        sweep(f"Tail{sd}", catmull(tail, 8), 0.17, rib, n=14, side=(-dirv.y, dirv.x, 0), flat=0.22)
    sphere("Knot", 0.2, rib, loc=top + Vector((0, -0.04, 0.02)), scale=(1.1, 0.9, 0.95))
    sm = glossy("StarDeco", STARGOLD, 0.3, 0.3, emit=0.3)
    for i, (x, z, r) in enumerate(((-0.42, 0.05, 0.14), (0.42, -0.3, 0.16), (-0.45, -0.48, 0.1), (0.48, 0.14, 0.09))):
        sparkle(f"FS{i}", (x, -0.765, z), r, sm, outline=0.008)
    for i, (y, z, r) in enumerate(((-0.4, -0.05, 0.14), (0.42, -0.42, 0.12), (0.4, 0.15, 0.09))):
        prism(f"SS{i}", star_pts(4, r, r * 0.3), 0.03, sm, loc=(0.765, y, z), rot=[("Z", 90)], bevel=0.004, outline=0.008)
    lib.group_tilt(-28, 14)


@icon
def Mega():
    yaw, pitch = -18, 4
    sphere("Body", 0.85, glossy("BombPurple", BOMB_PURPLE, 0.26, 0.15, 0.8))
    g = gold("CrownGold")
    # crown band: a flared ring of points, solidified
    ns, per = 9, 14
    r0, r1, h, sp = 0.9, 1.02, 0.42, 0.34
    bm = bmesh.new()
    nseg = ns * per
    rows = []
    for k in range(4):
        row = []
        for i in range(nseg):
            a = 2 * math.pi * i / nseg
            f = (i % per) / per
            z = (h + sp * (1 - abs(f - 0.5) * 2)) * k / 3
            rr = r0 + (r1 - r0) * z / (h + sp)
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rows.append(row)
    for k in range(3):
        for i in range(nseg):
            bm.faces.new((rows[k][i], rows[k][(i + 1) % nseg], rows[k + 1][(i + 1) % nseg], rows[k + 1][i]))
    band = lib._obj("Crown", bm, g)
    so = band.modifiers.new("Solid", "SOLIDIFY")
    so.thickness = 0.09
    so.offset = 0
    lib.finish(band, 0.02, segs=2)
    crown = [band, lib.torus("CrownRim", r0 + 0.01, 0.07, g, outline=0.02)]
    ruby = glossy("Ruby", RUBY, 0.12, 0.1, 0.9)
    for j in range(ns):
        a = 2 * math.pi * (j + 0.5) / ns
        crown.append(ball(f"Ball{j}", 0.08, g, segs=24, loc=(math.cos(a) * (r1 + 0.005), math.sin(a) * (r1 + 0.005), h + sp + 0.05), outline=0.016))
        zg = h * 0.5 + sp * 0.1
        rg = r0 + (r1 - r0) * zg / (h + sp) + 0.05
        gem = prism(f"Gem{j}", [(0, 0.22), (0.16, 0), (0, -0.22), (-0.16, 0)], 0.07, ruby, bevel=0.025, segs=2, outline=0.012)
        gem.matrix_world = Matrix.Translation((math.cos(a) * rg, math.sin(a) * rg, zg)) @ Matrix.Rotation(a + math.pi / 2, 4, "Z") @ Matrix.Rotation(math.radians(-8), 4, "X")
        crown.append(gem)
    place(crown, Matrix.Translation((0.02, -0.03, -0.02)) @ Matrix.Rotation(math.radians(-14), 4, "Y") @ Matrix.Rotation(math.radians(8), 4, "X"))
    # fuse from the top, behind the crown
    up = Vector((0.22, 0.3, 0.93)).normalized()
    base = up * 0.84
    cyl("Collar", 0.17, 0.2, g, loc=base, rot=[("X", -math.degrees(math.atan2(up.y, up.z))), ("Y", math.degrees(math.asin(up.x)))])
    fp = catmull([base + up * 0.05, base + up * 0.25 + Vector((0.04, 0, 0)), base + up * 0.4 + Vector((0.2, 0, 0)), base + up * 0.45 + Vector((0.4, 0, 0))], 10)
    sweep("FuseCord", fp, 0.07, glossy("Cord", ROPE, 0.6, coat=0.1), n=12)
    lib.group_tilt(yaw, pitch)
    m = tilt_m(yaw, pitch)
    spark("Spark", m @ fp[-1] + Vector((0.08, -1.5, 0.05)), 0.38, seed=4)


@icon
def Crate():
    W, D, R = 1.7, 1.06, 0.53
    wood = glossy("Wood", CRATE, 0.45, coat=0.25)
    g = gold("Brass")
    box("Core", (W - 0.1, D - 0.1, 0.76), glossy("WoodDk", CRATE_DK, 0.7, coat=0), loc=(0, 0, -0.39), outline=0)
    # body: three rows of staggered planks
    splits = ((-0.25,), (0.3,), (-0.05,))
    for row, zc in enumerate((-0.13, -0.39, -0.65)):
        xs = [-W / 2 + 0.03] + list(splits[row]) + [W / 2 - 0.03]
        for i in range(len(xs) - 1):
            box(f"Plank{row}{i}", (xs[i + 1] - xs[i] - 0.02, D - 0.04, 0.24), wood, loc=((xs[i] + xs[i + 1]) / 2, 0, zc), bevel=0.04, outline=0.012)
    # barrel lid: staves round a half-disc core
    half = [(math.cos(math.pi * i / 24) * 0.47, math.sin(math.pi * i / 24) * 0.47) for i in range(25)]
    prism("LidCore", half, W - 0.1, wood, rot=[("Z", 90)], loc=(0, 0, 0.02), bevel=0.02, outline=0.012)
    for k in range(5):
        a0, a1 = math.pi * k / 5 + 0.012, math.pi * (k + 1) / 5 - 0.012
        arc = [(math.cos(a0 + (a1 - a0) * i / 6) * R, math.sin(a0 + (a1 - a0) * i / 6) * R) for i in range(7)]
        arc += [(math.cos(a1 - (a1 - a0) * i / 6) * 0.43, math.sin(a1 - (a1 - a0) * i / 6) * 0.43) for i in range(7)]
        prism(f"Stave{k}", arc, W - 0.16, wood, rot=[("Z", 90)], loc=(0, 0, 0.02), bevel=0.03, outline=0.012)

    def arc_band(name, r_in, r_out, width, x):
        pts = [(math.cos(math.pi * i / 24) * r_out, math.sin(math.pi * i / 24) * r_out) for i in range(25)]
        pts += [(math.cos(math.pi * (24 - i) / 24) * r_in, math.sin(math.pi * (24 - i) / 24) * r_in) for i in range(25)]
        return prism(name, pts, width, g, rot=[("Z", 90)], loc=(x, 0, 0.02), bevel=0.025, outline=0.018)

    for sd in (-1, 1):
        arc_band(f"Rim{sd}", 0.44, 0.58, 0.1, sd * (W / 2 - 0.04))
        arc_band(f"Strap{sd}", 0.5, 0.6, 0.17, sd * 0.45)
        for fb in (-1, 1):
            box(f"StrapV{sd}{fb}", (0.17, 0.07, 0.8), g, loc=(sd * 0.45, fb * (D / 2 + 0.01), -0.4), bevel=0.025, outline=0.018)
            for z in (-0.22, -0.62):
                ball(f"Rv{sd}{fb}{z}", 0.035, g, loc=(sd * 0.45, fb * (D / 2 + 0.05), z), outline=0)
            box(f"Corner{sd}{fb}", (0.26, 0.26, 0.26), g, loc=(sd * (W / 2 - 0.08), fb * (D / 2 - 0.08), -0.7), bevel=0.05, outline=0.018)
        for a in (0.55, 1.57, 2.6):
            ball(f"RvL{sd}{a}", 0.035, g, loc=(sd * 0.45, math.cos(a) * 0.61, math.sin(a) * 0.61 + 0.02), outline=0)
    box("Belt", (W + 0.04, D + 0.04, 0.12), g, loc=(0, 0, 0.0), bevel=0.03, outline=0.018)
    # bomb-shaped latch with a keyhole and a tiny fuse
    lz, ly = -0.06, -D / 2 - 0.1
    sphere("Latch", 0.22, g, loc=(0, ly, lz), scale=(1, 0.65, 1.08))
    kh = [(math.cos(math.pi * i / 10) * 0.06, 0.03 + math.sin(math.pi * i / 10) * 0.06) for i in range(-2, 13)] + [(-0.045, -0.12), (0.045, -0.12)]
    kh = [kh[-1]] + kh[:-1]
    prism("Keyhole", kh, 0.06, glossy("Hole", srgb("#24140C"), 0.6), loc=(0, ly - 0.13, lz - 0.01), bevel=0.008, outline=0)
    cyl("LatchCollar", 0.06, 0.07, g, loc=(0, ly, lz + 0.25), outline=0.012)
    sweep("LatchFuse", catmull([(0, ly, lz + 0.27), (0.03, ly, lz + 0.36), (0.1, ly, lz + 0.41)], 6), 0.024, glossy("Cord", ROPE, 0.6, coat=0.1), n=10, outline=0.01)
    # lid fuse
    cyl("TopCollar", 0.13, 0.08, g, loc=(0, 0, R + 0.04))
    fp = catmull([(0, 0, R + 0.06), (0.02, 0, R + 0.26), (0.12, 0, R + 0.42), (0.3, 0, R + 0.5)], 8)
    sweep("TopFuse", fp, 0.05, glossy("Cord", ROPE, 0.6, coat=0.1), n=12)
    prism("Decal", star_pts(8, 0.2, 0.08), 0.02, glossy("Decal", srgb("#FFF0D6"), 0.4), loc=(W / 2 - 0.005, 0.18, -0.45), rot=[("Z", 90)], bevel=0.004, outline=0)
    yaw, pitch = -28, 14
    lib.group_tilt(yaw, pitch)
    m = tilt_m(yaw, pitch)
    spark("Spark", m @ fp[-1] + Vector((0.05, -1.5, 0.03)), 0.28, seed=2)
    spark("LSpark", m @ Vector((0.12, ly, lz + 0.42)) + Vector((0, -1.5, 0)), 0.12, seed=5)


@icon
def CrateInferno():
    hx, hy, hz = 0.76, 0.76, 0.64
    dims = (hx, hy, hz)
    iron = glossy("Iron", IRON, 0.35, 0.45, 0.5)
    rock = glossy("Rock", ROCK, 0.75, 0.0, 0.0)
    rock.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.15
    ember = emissive("Ember", srgb("#B8160A"), 1.0)
    t = 0.2
    box("Core", (2 * hx - 0.1, 2 * hy - 0.1, 2 * hz - 0.1), glossy("CoreDk", srgb("#120808"), 0.8, coat=0), outline=0)
    # each visible face: an emissive lava plate under a Voronoi of bevelled rock slabs (the gaps glow as cracks)
    rng = random.Random(21)
    lava = emissive("Lava", LAVA, 1.25)
    faces = (
        ("F", (hx, hz), [], (0, -hy, 0)),
        ("R", (hy, hz), [("Z", 90)], (hx, 0, 0)),
        ("T", (hx, hy), [("X", -90)], (0, 0, hz)),
    )
    for fk, (eu, ev), rot, ctr in faces:
        nrm = Vector(ctr).normalized()
        plate = [(-eu + 0.05, -ev + 0.05), (eu - 0.05, -ev + 0.05), (eu - 0.05, ev - 0.05), (-eu + 0.05, ev - 0.05)]
        prism(f"Lava{fk}", plate, 0.04, lava, rot=rot, loc=Vector(ctr) - nrm * 0.045, bevel=0, outline=0)
        qu, qv = eu - t, ev - t
        seeds = []
        for i in range(3):
            for j in range(3):
                seeds.append(Vector((-qu + (i + 0.5) * 2 * qu / 3 + rng.uniform(-0.12, 0.12), -qv + (j + 0.5) * 2 * qv / 3 + rng.uniform(-0.1, 0.1))))
        # a red-hot layer just under the rock, so each crack reads yellow core -> red rim -> dark rock
        for ci, cell in enumerate(voronoi_cells(seeds, -eu + 0.06, eu - 0.06, -ev + 0.06, ev - 0.06, 0.035)):
            prism(f"Ember{fk}{ci}", cell, 0.04, ember, rot=rot, loc=Vector(ctr) - nrm * 0.03, bevel=0, outline=0)
        for ci, cell in enumerate(voronoi_cells(seeds, -eu + 0.06, eu - 0.06, -ev + 0.06, ev - 0.06, 0.095)):
            prism(f"Slab{fk}{ci}", cell, 0.07, rock, rot=rot, loc=Vector(ctr) - nrm * 0.005, bevel=0.022, segs=2, outline=0)
    for ax in range(3):
        o1, o2 = [i for i in range(3) if i != ax]
        for s1 in (-1, 1):
            for s2 in (-1, 1):
                loc, size = [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]
                loc[o1], loc[o2] = s1 * (dims[o1] - t / 2 + 0.02), s2 * (dims[o2] - t / 2 + 0.02)
                size[ax], size[o1], size[o2] = 2 * dims[ax] - 0.1, t, t
                box(f"Bar{ax}{s1}{s2}", size, iron, loc=loc, bevel=0.045, outline=0.022)
    g = gold("CornerGold")
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                c = Vector((sx * (hx - 0.1), sy * (hy - 0.1), sz * (hz - 0.1)))
                box(f"Cap{sx}{sy}{sz}", (0.33, 0.33, 0.33), g, loc=c, bevel=0.06, outline=0.022)
                for ax in range(3):
                    n = Vector((0, 0, 0))
                    n[ax] = (sx, sy, sz)[ax]
                    ball(f"Rv{sx}{sy}{sz}{ax}", 0.045, g, loc=c + n * 0.17, outline=0)
    yaw, pitch = -30, 12
    lib.group_tilt(yaw, pitch)
    m = tilt_m(yaw, pitch)
    # flames licking up from behind the top edges and out of the sides (camera-facing)
    for i, (corner, dx, dz, w, hh, lean, y) in enumerate(
        (
            ((-1, 1, 1), 0.12, -0.12, 0.2, 0.42, -0.5, 3),
            ((1, 1, 1), -0.15, -0.12, 0.2, 0.46, 0.5, 3),
            ((0, 1, 1), 0.05, -0.12, 0.17, 0.36, 0.3, 3),
            ((0, -1, 1), -0.2, -0.12, 0.17, 0.34, -0.3, 3),
            ((-1, -1, -1), -0.02, 0.15, 0.17, 0.5, -0.7, 3),
            ((-1, -1, 0), -0.02, 0.0, 0.15, 0.36, -0.7, 3),
            ((1, 1, -1), 0.02, 0.18, 0.17, 0.5, 0.7, 3),
            ((1, 1, 0), 0.02, 0.0, 0.15, 0.36, 0.7, 3),
        )
    ):
        p = m @ Vector((corner[0] * hx, corner[1] * hy, corner[2] * hz))
        flame(f"Flame{i}", (p.x + dx, y, p.z + dz), w * 1.35, hh * 1.4, lean)
