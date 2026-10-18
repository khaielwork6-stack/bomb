"""FUSE VALLEY icons — set C: Flame, Shield, Runner, Bomber, Dash, Slide, Stop, Wheel, Eye, Heart
(art/ref/icons/icons_sheet1.png #14-#19, icons_sheet2.png #1-#3 and #20 — references only, every icon is geometry).

Local helpers: `inflate` (a pillow-inflated 2D outline — Poisson dome on a constrained Delaunay mesh, for the soft
organic shapes: heart, flame layers, palm, eye white), `capsule`, `limb` (bent bezier tube with round ends, for the
chunky toy figures), plus 2D outline tools (`chaikin`, `rounded`).
"""

import math

import bmesh
import lib
from lib import box, cyl, glossy, gold, icon, prism, sphere, srgb, star_pts, torus, tube
from mathutils import Vector, kdtree
from mathutils.geometry import delaunay_2d_cdt

# ── Palette (kept a touch darker than the reference swatches: the house key light is bright, so lit faces land on
# the reference colour instead of clipping toward white) ──────────────────────────────────────────────────────────
CYAN = srgb("#0B8EE0")
CYAN_LT = srgb("#2AB0F0")
FIG_RED = srgb("#D8300E")
RED = srgb("#C8121A")
FLAME_RED = srgb("#D42A0C")
FLAME_ORANGE = srgb("#F07A0E")
FLAME_YELLOW = srgb("#F7C422")
FLAME_CORE = srgb("#FFF0A0")
GREEN_LT = srgb("#1FA63C")
GREEN_DK = srgb("#0E7A2A")
CREAM = srgb("#EBC9A0")
HAND = srgb("#F3DCC4")
INK = srgb("#15121A")
DUST = srgb("#D9B88C")
DUST_DK = srgb("#BF9A68")
BUTTON = srgb("#26242E")
EYE_WHITE = srgb("#EFE6DA")
IRIS_DK = srgb("#163FA8")
IRIS = srgb("#2B78EE")
HEART = srgb("#C80C16")
STAND = srgb("#25232A")


def toy(name, color, emit=0.0):
    """Saturated toy plastic: a smooth body with a lowered specular level plus a light clear coat — the area lights
    read as crisp white highlights instead of a broad milky sheen, so the colour stays deep."""
    m = glossy(name, color, 0.14, 0.0, 0.3, emit)
    b = m.node_tree.nodes["Principled BSDF"]
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.35
    return m


# ── 2D outline tools ────────────────────────────────────────────────────────────────────────────────────────────
def chaikin(pts, sharp=(), iters=4, closed=True):
    """Corner-cutting smoothing; indices in `sharp` stay as hard corners (flame tips, shield points)."""
    sharp = set(sharp)
    for _ in range(iters):
        out, ns = [], set()
        n = len(pts)
        if not closed:
            ns.add(0)
            out.append(pts[0])
        for i in range(n if closed else n - 1):
            a, b = pts[i], pts[(i + 1) % n]
            if i in sharp and (closed or i != 0):
                ns.add(len(out))
                out.append(a)
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        if not closed:
            ns.add(len(out))
            out.append(pts[-1])
        pts, sharp = out, ns
    return pts


def rounded(pts, r, n=6):
    """Fillet every corner of a closed polygon with a quadratic arc of size `r` (number or per-corner list)."""
    out = []
    N = len(pts)
    for i in range(N):
        p, v, q = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % N])
        rr = r[i] if isinstance(r, (list, tuple)) else r
        d = min(rr, (p - v).length * 0.48, (q - v).length * 0.48)
        if d <= 1e-6:
            out.append((v.x, v.y))
            continue
        a = v + (p - v).normalized() * d
        b = v + (q - v).normalized() * d
        for k in range(n + 1):
            t = k / n
            c = a * (1 - t) ** 2 + v * 2 * (1 - t) * t + b * t * t
            out.append((c.x, c.y))
    return out


def resample(pts, sp):
    """Uniform arc-length resample of a closed polygon."""
    P = [Vector(p) for p in pts]
    segs = [(P[i], P[(i + 1) % len(P)]) for i in range(len(P))]
    total = sum((b - a).length for a, b in segs)
    n = max(8, round(total / sp))
    step = total / n
    out, acc, k = [], 0.0, 0
    for a, b in segs:
        L = (b - a).length
        while k < n and k * step <= acc + L + 1e-9:
            t = (k * step - acc) / L if L > 0 else 0
            c = a.lerp(b, max(0.0, min(1.0, t)))
            out.append((c.x, c.y))
            k += 1
        acc += L
    return out


def _inside(x, z, poly):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            c = not c
        j = i
    return c


def mirror_half(right):
    """`right` runs top-centre → bottom-centre on x >= 0; returns the full closed outline (clockwise from top)."""
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    return list(right) + left


def offset_poly(pts, d):
    """Inset a closed polygon by `d` (mitred; positive = inward)."""
    area = sum(pts[i - 1][0] * pts[i][1] - pts[i][0] * pts[i - 1][1] for i in range(len(pts)))
    sgn = 1.0 if area > 0 else -1.0
    out = []
    N = len(pts)
    for i in range(N):
        p, v, q = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % N])
        e1, e2 = (v - p).normalized(), (q - v).normalized()
        n1 = Vector((-e1.y, e1.x)) * sgn
        n2 = Vector((-e2.y, e2.x)) * sgn
        n = (n1 + n2).normalized()
        c = v + n * (d / max(0.35, n.dot(n1)))
        out.append((c.x, c.y))
    return out


def clip_x(poly, positive=True):
    """Sutherland-Hodgman clip of a closed polygon to the x >= 0 (or x <= 0) half-plane."""
    s = 1.0 if positive else -1.0
    out = []
    N = len(poly)
    for i in range(N):
        a, b = poly[i - 1], poly[i]
        ia, ib = a[0] * s >= 0, b[0] * s >= 0
        if ib:
            if not ia:
                t = a[0] / (a[0] - b[0])
                out.append((0.0, a[1] + (b[1] - a[1]) * t))
            out.append(b)
        elif ia:
            t = a[0] / (a[0] - b[0])
            out.append((0.0, a[1] + (b[1] - a[1]) * t))
    return out


def heart_pts(cx=0.5, cz=0.3, r=0.53, tip=-0.98, n=40):
    """A plump heart: two lobe circles joined by tangent lines to a softly rounded tip."""
    T = Vector((0.0, tip))
    C = Vector((cx, cz))
    v = C - T
    th = math.atan2(v.y, v.x) - math.asin(r / v.length)
    P = T + Vector((math.cos(th), math.sin(th))) * math.sqrt(v.length**2 - r * r)
    a0 = math.atan2(P.y - C.y, P.x - C.x)
    a1 = math.atan2(math.sqrt(r * r - cx * cx), -cx)  # where the lobe meets x = 0 (the top notch)
    right = [(0.0, tip)]
    for k in range(1, 6):
        c = T.lerp(P, k / 6)
        right.append((c.x, c.y))
    for k in range(n + 1):
        a = a0 + (a1 - a0) * k / n
        right.append((C.x + math.cos(a) * r, C.y + math.sin(a) * r))
    poly =[(0.0, right[-1][1])] + list(reversed(right[1:-1])) + [(0.0, tip)] + [(-x, z) for x, z in right[1:-1]]
    radii = [0.0] * len(poly)
    radii[0] = 0.07
    radii[len(right) - 1] = 0.16
    return rounded(poly, radii, 8)


# ── 3D helpers ──────────────────────────────────────────────────────────────────────────────────────────────────
def inflate(name, pts, mat, front=0.3, back=None, sp=0.035, loc=(0, 0, 0), rot=None, outline=0.035, power=0.5):
    """Pillow-inflate a closed XZ outline: a Poisson dome (h=0 on the rim) on a constrained Delaunay mesh, height =
    h^power, so the rim is round and narrow parts (tips, tongues) come out thinner — a soft, toy-like solid."""
    back = front * 0.6 if back is None else back
    poly = resample(pts, sp)
    area = sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly))) / 2
    if area < 0:
        poly.reverse()
    nb = len(poly)
    kd = kdtree.KDTree(nb)
    for i, (x, z) in enumerate(poly):
        kd.insert((x, z, 0), i)
    kd.balance()
    verts = list(poly)
    for i in range(nb):  # a close inner ring so the steep rim is well resolved
        p, v, q = Vector(poly[i - 1]), Vector(poly[i]), Vector(poly[(i + 1) % nb])
        t = q - p
        if t.length < 1e-9:
            continue
        c = v + Vector((-t.y, t.x)).normalized() * sp * 0.4
        if _inside(c.x, c.y, poly) and kd.find((c.x, c.y, 0))[2] > sp * 0.3:
            verts.append((c.x, c.y))
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    h = sp * 0.866
    z, row = min(zs) + h * 0.5, 0
    while z < max(zs):
        x = min(xs) + (sp * 0.5 if row % 2 else 0.0)
        while x < max(xs):
            if _inside(x, z, poly) and kd.find((x, z, 0))[2] > sp * 0.85:
                verts.append((x, z))
            x += sp
        z += h
        row += 1
    ov, _oe, of, orig, _a, _b = delaunay_2d_cdt([Vector(v) for v in verts], [], [list(range(nb))], 1, 1e-7, True)
    n = len(ov)
    isb = [any(o < nb for o in orig[i]) for i in range(n)]
    nbr = [set() for _ in range(n)]
    for f in of:
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            nbr[a].add(b)
            nbr[b].add(a)
    nbr = [list(s) for s in nbr]
    hv = [0.0] * n
    interior = [i for i in range(n) if not isb[i] and nbr[i]]
    for _ in range(int(60 + 4.0 * (max(max(xs) - min(xs), max(zs) - min(zs)) / sp))):
        for i in interior:
            nl = nbr[i]
            s = 0.0
            for j in nl:
                s += hv[j]
            hv[i] += 1.85 * ((s + 1.0) / len(nl) - hv[i])
    hmax = max(hv) or 1.0
    bm = bmesh.new()
    F, B = {}, {}
    for i, c in enumerate(ov):
        if isb[i]:
            F[i] = B[i] = bm.verts.new((c.x, 0.0, c.y))
        else:
            s = max(hv[i], 0.0) / hmax
            s = s**power
            F[i] = bm.verts.new((c.x, -front * s, c.y))
            B[i] = bm.verts.new((c.x, back * s, c.y))
    for f in of:
        a, b, c = f[0], f[1], f[2]
        (x1, z1), (x2, z2), (x3, z3) = ov[a], ov[b], ov[c]
        if (x2 - x1) * (z3 - z1) - (z2 - z1) * (x3 - x1) < 0:
            b, c = c, b
        try:
            bm.faces.new((F[a], F[b], F[c]))
        except ValueError:
            pass
        if not (isb[a] and isb[b] and isb[c]):
            try:
                bm.faces.new((B[a], B[c], B[b]))
            except ValueError:
                pass
    lib.xform(bm, loc, rot)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def capsule(name, p1, p2, r, mat, outline=0.035, segs=32):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 1, radius=r)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z += d.length
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=q.to_matrix(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=p1, verts=bm.verts)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def limb(name, pts, r, mat, y=0.0, outline=0.04):
    """A bent limb: a bezier tube through XZ points (at depth y) with ball ends."""
    vs = [Vector((x, y, z)) for x, z in pts]
    if len(vs) == 2:
        return capsule(name, vs[0], vs[1], r, mat, outline)
    tube(name, vs, r, mat, outline=outline, caps=False)
    sphere(name + "_a", r, mat, loc=vs[0], outline=outline)
    sphere(name + "_b", r, mat, loc=vs[-1], outline=outline)


def figure(prefix, mat, head, torso, limbs, ol=0.06):
    """A chunky toy stick figure: head (x, z, r), torso ((p1, p2), r), limbs [(pts, r, y)]."""
    sphere(prefix + "Head", head[2], mat, loc=(head[0], 0, head[1]), outline=ol)
    limb(prefix + "Torso", torso[0], torso[1], mat, 0.0, ol)
    for i, (pts, r, y) in enumerate(limbs):
        limb(f"{prefix}Limb{i}", pts, r, mat, y, ol)


def spark(name, loc, size=0.3):
    prism(name, star_pts(8, size, size * 0.42), 0.07, glossy("Spark", srgb("#FFD84A"), emit=5), loc=loc, bevel=0.012, outline=0.02)
    sphere(name + "Core", size * 0.28, glossy("SparkCore", srgb("#FFF7D0"), emit=8), loc=(loc[0], loc[1] - 0.05, loc[2]), outline=0)


# ── Icons ───────────────────────────────────────────────────────────────────────────────────────────────────────
@icon
def Flame():
    outer = [
        (0.07, 0.0), (-0.47, 0.05), (-0.83, 0.3), (-0.99, 0.73), (-0.92, 1.1), (-0.73, 1.4),
        (-0.47, 1.78), (-0.39, 1.5), (-0.32, 1.87), (-0.2, 2.15), (0.1, 2.01), (0.32, 1.7),
        (0.43, 1.37), (0.47, 1.12), (0.72, 1.42), (0.88, 1.07), (0.97, 0.7), (0.88, 0.33), (0.57, 0.08),
    ]
    inflate("Outer", chaikin(outer, sharp=(6, 7, 9, 13, 14)), toy("FlameR", FLAME_RED, 0.25), front=0.42, back=0.3, sp=0.03, outline=0.04)
    mid = [
        (0.07, 0.16), (-0.42, 0.22), (-0.68, 0.48), (-0.7, 0.82), (-0.52, 1.1), (-0.25, 1.32),
        (-0.12, 1.5), (0.04, 1.18), (0.2, 0.98), (0.42, 1.14), (0.6, 0.82), (0.64, 0.48), (0.46, 0.24),
    ]
    inflate("Mid", chaikin(mid, sharp=(6, 8, 9)), toy("FlameO", FLAME_ORANGE, 0.35), front=0.22, back=0.05, sp=0.03, loc=(0, -0.26, 0), outline=0)
    core = [(-0.04, 1.06), (0.2, 0.74), (0.36, 0.48), (0.27, 0.25), (0.0, 0.2), (-0.27, 0.25), (-0.38, 0.48), (-0.3, 0.74)]
    inflate("Core", chaikin(core, sharp=(0,)), toy("FlameY", FLAME_YELLOW, 0.8), front=0.14, back=0.04, sp=0.025, loc=(0, -0.44, 0), outline=0)
    glow = rounded([(-0.2, 0.28), (0.2, 0.28), (0.24, 0.55), (0.0, 0.72), (-0.24, 0.55)], 0.12, 6)
    inflate("Glow", glow, glossy("FlameW", FLAME_CORE, 0.3, emit=2.0), front=0.08, back=0.02, sp=0.025, loc=(0, -0.55, 0), outline=0)
    lib.group_tilt(-14, 6)


@icon
def Shield():
    right = [(0.0, 1.06), (0.42, 0.97), (0.88, 0.78), (0.9, 0.3), (0.8, -0.3), (0.52, -0.78), (0.0, -1.18)]
    full = chaikin(mirror_half(right), sharp=(2, 6, 10), iters=4)
    prism("Rim", full, 0.32, gold(), bevel=0.07, segs=4)
    inner = offset_poly(full, 0.19)
    prism("GreenR", clip_x(inner, True), 0.16, toy("GreenD", GREEN_DK), loc=(0, -0.16, 0), rot=[("Z", 10)], bevel=0.04, outline=0.02)
    prism("GreenL", clip_x(inner, False), 0.16, toy("GreenL", GREEN_LT), loc=(0, -0.16, 0), rot=[("Z", -10)], bevel=0.04, outline=0.02)
    for i, (x, z) in enumerate([(0, 0.95), (0.75, 0.7), (-0.75, 0.7), (0.79, 0.08), (-0.79, 0.08), (0.52, -0.58), (-0.52, -0.58), (0, -1.0)]):
        sphere(f"Stud{i}", 0.065, gold("Stud"), loc=(x, -0.17, z), outline=0.015)
    lib.group_tilt(-20, 8)


@icon
def Runner():
    mat = toy("Cyan", CYAN)
    for i, (x0, x1, z) in enumerate([(-0.7, 0.3, 1.7), (-1.25, -0.25, 1.15), (-1.6, -0.55, 0.52), (-1.45, -0.5, -0.1)]):
        capsule(f"Streak{i}", (x0, 0.45, z), (x1, 0.45, z), 0.13, toy("Streak", CYAN_LT), outline=0.055)
    figure(
        "R", mat,
        head=(0.95, 1.45, 0.47),
        torso=([(0.5, 0.8), (0.12, 0.0)], 0.35),
        limbs=[
            ([(0.6, 0.7), (1.2, 0.42), (1.6, 0.85)], 0.19, -0.3),
            ([(0.35, 0.75), (-0.15, 0.55), (-0.5, 0.38)], 0.19, 0.3),
            ([(0.2, -0.05), (0.85, -0.2), (0.75, -0.85), (1.02, -0.95)], 0.22, -0.18),
            ([(0.0, -0.1), (-0.35, -0.5), (-0.95, -0.62)], 0.22, 0.22),
        ],
    )
    lib.group_tilt(-10, 6)


@icon
def Bomber():
    mat = toy("FigRed", FIG_RED)
    figure(
        "B", mat,
        head=(0.31, 1.25, 0.47),
        torso=([(0.1, 0.72), (-0.28, -0.08)], 0.35),
        limbs=[
            ([(0.3, 0.58), (0.85, 0.38), (1.15, 0.85)], 0.19, -0.3),
            ([(-0.05, 0.68), (-0.6, 0.72), (-0.9, 0.38)], 0.19, 0.3),
            ([(-0.2, -0.1), (0.45, -0.25), (0.6, -0.8), (0.88, -0.9)], 0.22, -0.18),
            ([(-0.35, -0.15), (-0.65, -0.45), (-1.0, -0.8)], 0.22, 0.22),
        ],
    )
    bx, bz, by = 1.48, 1.2, -0.4
    sphere("Bomb", 0.48, glossy("Iron", srgb("#26232C"), 0.3, 0.2, 0.7), loc=(bx, by, bz), outline=0.055)
    cyl("Collar", 0.13, 0.14, gold(), loc=(bx + 0.17, by, bz + 0.43), rot=[("Y", 22)], outline=0.03)
    fuse = [Vector((bx + 0.2, by, bz + 0.49)), Vector((bx + 0.26, by, bz + 0.62)), Vector((bx + 0.38, by, bz + 0.68))]
    tube("Fuse", fuse, 0.05, glossy("Cord", srgb("#C99A5A"), 0.8, coat=0), outline=0.03)
    spark("Spark", (bx + 0.46, by - 0.04, bz + 0.72), 0.27)
    lib.group_tilt(-10, 6)


@icon
def Dash():
    arrow = [(-0.55, 0.32), (0.15, 0.32), (0.15, 1.0), (1.3, 0.0), (0.15, -1.0), (0.15, -0.32), (-0.55, -0.32)]
    prism("Arrow", rounded(arrow, [0.14, 0.1, 0.16, 0.2, 0.16, 0.1, 0.14], 8), 0.4, toy("Cyan", CYAN), bevel=0.14, segs=5, outline=0.045)
    st = toy("Streak", CYAN_LT)
    for i, (x0, x1, z) in enumerate([(-0.85, 0.0, 0.66), (-1.45, -0.5, 0.0), (-1.15, -0.2, -0.66)]):
        capsule(f"Streak{i}", (x0, 0.05, z), (x1, 0.05, z), 0.14, st, outline=0.045)
    lib.group_tilt(-16, 8)


@icon
def Slide():
    mat = toy("Cyan", CYAN)
    figure(
        "S", mat,
        head=(1.0, 0.92, 0.47),
        torso=([(0.5, 0.38), (-0.12, -0.2)], 0.35),
        limbs=[
            ([(0.4, 0.5), (-0.35, 0.7), (-1.05, 0.88)], 0.19, 0.25),
            ([(0.5, 0.3), (1.0, -0.05), (1.45, -0.3)], 0.19, -0.3),
            ([(-0.15, -0.28), (0.5, -0.64), (1.35, -0.76)], 0.22, -0.1),
        ],
    )
    dust = glossy("Dust", DUST, 0.55, coat=0.15)
    dust2 = glossy("DustDk", DUST_DK, 0.55, coat=0.15)
    puffs = [
        (-0.4, -0.72, 0.32), (-0.82, -0.62, 0.36), (-1.25, -0.6, 0.3), (-1.6, -0.72, 0.24), (-1.0, -0.22, 0.28),
        (-1.42, -0.25, 0.22), (-0.6, -0.3, 0.24), (-1.75, -0.4, 0.17), (-0.05, -0.88, 0.22), (-1.2, -0.92, 0.2),
    ]
    for i, (x, z, r) in enumerate(puffs):
        sphere(f"Puff{i}", r, dust if i % 3 else dust2, loc=(x, 0.1 - r * 0.3, z), outline=0.05)
    for i, (x, z, r) in enumerate([(-1.1, 0.28, 0.11), (-1.6, 0.12, 0.08), (-1.95, -0.9, 0.09)]):
        sphere(f"Bit{i}", r, dust, loc=(x, 0.0, z), outline=0.035)
    capsule("Ground", (-0.2, 0.1, -1.02), (1.75, 0.1, -1.02), 0.04, dust, outline=0.025)
    lib.group_tilt(-10, 6)


@icon
def Stop():
    def octa(r):
        return [(math.cos(math.radians(22.5 + 45 * k)) * r, math.sin(math.radians(22.5 + 45 * k)) * r) for k in range(8)]

    red = toy("Red", RED)
    prism("Edge", rounded(octa(1.0), 0.07, 3), 0.3, red, bevel=0.05)
    prism("Band", rounded(octa(0.93), 0.06, 3), 0.3, toy("Cream", CREAM), loc=(0, -0.03, 0), bevel=0.05, outline=0.015)
    prism("Face", rounded(octa(0.76), 0.05, 3), 0.3, red, loc=(0, -0.06, 0), bevel=0.05, outline=0.02)
    hand = toy("Hand", HAND)
    palm = rounded([(-0.38, -0.6), (0.36, -0.6), (0.42, 0.02), (-0.42, 0.02)], [0.24, 0.24, 0.12, 0.12])
    inflate("Palm", palm, hand, front=0.12, back=0.04, sp=0.03, loc=(0, -0.23, -0.04), outline=0.03)
    for i, (x, tip, ang) in enumerate([(-0.3, 0.3, 7), (-0.1, 0.44, 2), (0.1, 0.42, -2), (0.3, 0.28, -7)]):
        top = (x - math.sin(math.radians(ang)) * 0.5, tip)
        capsule(f"Finger{i}", (x, -0.27, -0.12), (top[0], -0.27, top[1]), 0.105, hand, outline=0.03)
    capsule("Thumb", (0.28, -0.27, -0.42), (0.6, -0.27, -0.12), 0.11, hand, outline=0.03)
    lib.group_tilt(-18, 8)


@icon
def Wheel():
    g = gold()
    cyl("Disc", 1.0, 0.26, g, rot=[("X", 90)], segs=96, bevel=0.04)
    cyl("Back", 0.96, 0.2, toy("Back", STAND), loc=(0, 0.1, 0), rot=[("X", 90)], segs=96, bevel=0.03, outline=0)
    cols = ["#D0141E", "#F0640C", "#F5B812", "#1EA83C", "#14A8CC", "#1C62E0", "#7A2CD6", "#E0246E"]
    for k, c in enumerate(cols):
        a0 = math.radians(90 - 22.5 + 45 * k)
        arc = [a0 + math.radians(45) * t / 12 for t in range(13)]
        pts = [(0.0, 0.0)] + [(math.cos(a) * 0.76, math.sin(a) * 0.76) for a in arc]
        prism(f"Wedge{k}", pts, 0.08, toy(f"W{k}", srgb(c)), loc=(0, -0.15, 0), bevel=0.02, outline=0.012)
    for i in range(12):
        a = 2 * math.pi * i / 12 + math.pi / 12
        sphere(f"Stud{i}", 0.06, gold("Stud"), loc=(math.cos(a) * 0.885, -0.14, math.sin(a) * 0.885), outline=0.012)
    sphere("Hub", 0.19, g, loc=(0, -0.22, 0), scale=(1, 0.75, 1))
    torus("HubRing", 0.2, 0.05, g, rot=[("X", 90)], loc=(0, -0.2, 0))
    prism("Pointer", rounded([(-0.2, 1.22), (0.2, 1.22), (0.0, 0.74)], 0.04, 3), 0.16, g, loc=(0, -0.24, 0), bevel=0.035)
    sphere("PointerCap", 0.085, g, loc=(0, -0.32, 1.14))
    st = toy("Stand", STAND)
    prism("Base", rounded([(-0.9, -1.3), (0.9, -1.3), (0.7, -1.06), (-0.7, -1.06)], 0.05, 3), 0.6, st, loc=(0, 0.1, 0), bevel=0.04)
    box("Neck", (0.5, 0.3, 0.4), st, loc=(0, 0.2, -0.92), bevel=0.04)
    lib.group_tilt(-20, 8)


@icon
def Eye():
    b = box("Button", (2.0, 0.55, 2.0), toy("Button", BUTTON), bevel=0.32)
    b.modifiers["Bevel"].segments = 6
    xs = [0.78 * math.cos(math.radians(a)) for a in range(180, -1, -6)]
    up = [(x, 0.46 * (1 - (x / 0.78) ** 2) ** 0.75) for x in xs]
    lo = [(x, -0.44 * (1 - (x / 0.78) ** 2) ** 0.75) for x in reversed(xs[1:-1])]
    inflate("White", up + lo, toy("EyeW", EYE_WHITE), front=0.1, back=0.02, sp=0.025, loc=(0, -0.27, 0), outline=0.035)
    sphere("Iris", 0.38, toy("IrisD", IRIS_DK), loc=(0, -0.345, 0), scale=(1, 0.22, 1), outline=0.015)
    sphere("IrisIn", 0.29, toy("Iris", IRIS), loc=(0, -0.375, 0), scale=(1, 0.2, 1), outline=0)
    sphere("Pupil", 0.16, toy("Pupil", INK), loc=(0, -0.41, 0), scale=(1, 0.2, 1), outline=0)
    sphere("Glint", 0.075, glossy("Glint", srgb("#FFFFFF"), 0.2, emit=1.5), loc=(-0.12, -0.45, 0.12), scale=(1, 0.4, 1), outline=0)
    lib.group_tilt(-20, 10)


@icon
def Heart():
    inflate("Heart", heart_pts(), toy("Heart", HEART), front=0.5, back=0.3, sp=0.03, outline=0.04)
    lib.group_tilt(-18, 8)
