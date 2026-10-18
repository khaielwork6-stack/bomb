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
CYAN = srgb("#16A8EE")
CYAN_LT = srgb("#40BCF4")
FIG_RED = srgb("#D8300E")
RED = srgb("#C8121A")
FLAME_RED = srgb("#DC340A")
FLAME_ORANGE = srgb("#EE6A0C")
FLAME_YELLOW = srgb("#F7C422")
FLAME_CORE = srgb("#FFE070")
GREEN_LT = srgb("#138A2E")
GREEN_DK = srgb("#0A6422")
CREAM = srgb("#D9AE80")
HAND = srgb("#E6C6A6")
INK = srgb("#15121A")
DUST = srgb("#D9B88C")
BUTTON = srgb("#2A2834")
EYE_WHITE = srgb("#D8C8B4")
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
    poly = [(0.0, right[-1][1])] + list(reversed(right[1:-1])) + [(0.0, tip)] + [(-x, z) for x, z in right[1:-1]]
    radii = [0.0] * len(poly)
    radii[0] = 0.07
    radii[len(right) - 1] = 0.16
    return rounded(poly, radii, 8)


def blob_outline(circles, k=0.06, res=0.02):
    """The outline of a soft union of circles [(x, z, r)] (smooth-min fillets of size k) — a scalloped cloud/puff
    silhouette, traced with marching squares; returns the longest closed loop."""
    x0 = min(c[0] - c[2] for c in circles) - 3 * res
    x1 = max(c[0] + c[2] for c in circles) + 3 * res
    z0 = min(c[1] - c[2] for c in circles) - 3 * res
    z1 = max(c[1] + c[2] for c in circles) + 3 * res
    nx, nz = int((x1 - x0) / res) + 2, int((z1 - z0) / res) + 2

    def field(x, z):
        d = None
        for cx, cz, r in circles:
            e = math.hypot(x - cx, z - cz) - r
            if d is None:
                d = e
            else:  # polynomial smooth-min
                h = max(0.0, min(1.0, 0.5 + 0.5 * (e - d) / k))
                d = e * (1 - h) + d * h - k * h * (1 - h)
        return d

    f = [[field(x0 + i * res, z0 + j * res) for j in range(nz)] for i in range(nx)]

    def pt(key):
        kind, i, j = key
        a = f[i][j]
        b = f[i + 1][j] if kind == "h" else f[i][j + 1]
        t = a / (a - b)
        return (x0 + (i + t) * res, z0 + j * res) if kind == "h" else (x0 + i * res, z0 + (j + t) * res)

    adj = {}
    for i in range(nx - 1):
        for j in range(nz - 1):
            corners = [f[i][j], f[i + 1][j], f[i + 1][j + 1], f[i][j + 1]]
            edges = [("h", i, j), ("v", i + 1, j), ("h", i, j + 1), ("v", i, j)]
            cut = [edges[e] for e in range(4) if (corners[e] < 0) != (corners[(e + 1) % 4] < 0)]
            pairs = [(cut[0], cut[1])] if len(cut) == 2 else ([(cut[0], cut[1]), (cut[2], cut[3])] if len(cut) == 4 else [])
            for a, b in pairs:
                adj.setdefault(a, []).append(b)
                adj.setdefault(b, []).append(a)
    seen, loops = set(), []
    for start in adj:
        if start in seen:
            continue
        loop, prev, cur = [], None, start
        while cur not in seen:
            seen.add(cur)
            loop.append(pt(cur))
            nxt = [n for n in adj[cur] if n != prev and n not in seen]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
        loops.append(loop)
    return max(loops, key=len)


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


def capsule(name, p1, p2, r, mat, outline=0.035, segs=32, r2=None):
    """A capsule from p1 to p2; with `r2` it tapers (radius r at p1 to r2 at p2) — the chunky figure torso."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 1, radius=r)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z += L
    if r2 is not None:
        for v in bm.verts:
            k = 1.0 + (r2 / r - 1.0) * min(1.0, max(0.0, (v.co.z + r) / (L + 2 * r)))
            v.co.x *= k
            v.co.y *= k
            v.co.z = (v.co.z - L) * (r2 / r) + L if v.co.z > L else v.co.z
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=q.to_matrix(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=p1, verts=bm.verts)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def ball(name, r, mat, loc=(0, 0, 0), segs=32, outline=0.035):
    """A UV sphere with a chosen resolution (studs and limb ends don't need lib.sphere's 48x24)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=r)
    lib.xform(bm, loc)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def limb(name, pts, r, mat, y=0.0, outline=0.04):
    """A bent limb: a bezier tube through XZ points (at depth y) with ball ends."""
    vs = [Vector((x, y, z)) for x, z in pts]
    if len(vs) == 2:
        return capsule(name, vs[0], vs[1], r, mat, outline)
    tube(name, vs, r, mat, outline=outline, caps=False)
    ball(name + "_a", r, mat, loc=vs[0], outline=outline)
    ball(name + "_b", r, mat, loc=vs[-1], outline=outline)


def figure(prefix, mat, head, torso, limbs, ol=0.07):
    """A chunky toy stick figure: head (x, z, r), torso ((chest, hips), r_chest, r_hips), limbs [(pts, r, y)]."""
    sphere(prefix + "Head", head[2], mat, loc=(head[0], 0, head[1]), outline=ol)
    (cx, cz), (hx, hz) = torso[0]
    capsule(prefix + "Torso", (cx, 0, cz), (hx, 0, hz), torso[1], mat, ol, r2=torso[2])
    for i, (pts, r, y) in enumerate(limbs):
        limb(f"{prefix}Limb{i}", pts, r, mat, y, ol)


def spark(name, loc, size=0.3):
    """A lit-fuse spark: a hot orange burst with a smaller yellow burst and a white-hot core."""
    x, y, z = loc
    prism(name, star_pts(8, size, size * 0.45), 0.06, glossy("SparkO", srgb("#FF7A12"), emit=3), loc=loc, bevel=0.012, outline=0.025)
    prism(name + "In", star_pts(8, size * 0.62, size * 0.3, 112.5), 0.06, glossy("SparkY", srgb("#FFD23A"), emit=5), loc=(x, y - 0.04, z), bevel=0.01, outline=0)
    sphere(name + "Core", size * 0.22, glossy("SparkCore", srgb("#FFF7D0"), emit=8), loc=(x, y - 0.08, z), outline=0)


# ── Icons ───────────────────────────────────────────────────────────────────────────────────────────────────────
@icon
def Flame():
    outer = [
        (0.07, 0.0), (-0.47, 0.05), (-0.83, 0.3), (-0.99, 0.73), (-0.92, 1.1), (-0.73, 1.4),
        (-0.47, 1.78), (-0.36, 1.4), (-0.32, 1.87), (-0.2, 2.15), (0.1, 2.01), (0.32, 1.7),
        (0.43, 1.32), (0.5, 1.0), (0.74, 1.42), (0.88, 1.07), (0.97, 0.7), (0.88, 0.33), (0.57, 0.08),
    ]
    inflate("Outer", chaikin(outer, sharp=(6, 7, 9, 13, 14)), toy("FlameR", FLAME_RED, 0.25), front=0.42, back=0.3, sp=0.03, outline=0.04)
    mid = [(x * 0.74, z * 0.7 + 0.15) for x, z in outer]
    inflate("Mid", chaikin(mid, sharp=(6, 7, 9, 13, 14)), toy("FlameO", FLAME_ORANGE, 0.35), front=0.22, back=0.05, sp=0.03, loc=(0, -0.26, 0), outline=0)
    core = [(-0.1, 1.3), (0.2, 0.96), (0.44, 0.62), (0.4, 0.34), (0.04, 0.24), (-0.34, 0.3), (-0.48, 0.6), (-0.34, 0.96)]
    inflate("Core", chaikin(core, sharp=(0,)), toy("FlameY", FLAME_YELLOW, 0.8), front=0.14, back=0.04, sp=0.025, loc=(0, -0.44, 0), outline=0)
    glow = [(-0.06, 0.78), (0.2, 0.56), (0.26, 0.4), (0.04, 0.32), (-0.22, 0.38), (-0.24, 0.56)]
    inflate("Glow", chaikin(glow, sharp=(0,)), toy("FlameW", FLAME_CORE, 0.4), front=0.06, back=0.02, sp=0.025, loc=(0, -0.55, 0), outline=0)
    lib.group_tilt(-14, 6)


@icon
def Shield():
    right = [(0.0, 1.06), (0.46, 0.97), (0.96, 0.78), (0.98, 0.3), (0.87, -0.3), (0.56, -0.78), (0.0, -1.18)]
    full = chaikin(mirror_half(right), sharp=(2, 6, 10), iters=4)
    prism("Rim", full, 0.32, gold(), bevel=0.07, segs=4)
    inner = [(0.0, 0.85), (0.36, 0.78), (0.76, 0.62), (0.77, 0.26), (0.68, -0.24), (0.44, -0.6), (0.0, -0.93)]
    rhalf = chaikin(inner, sharp=(2,), iters=4, closed=False)
    lhalf = [(-x, z) for x, z in reversed(rhalf)]
    prism("GreenR", rhalf, 0.24, toy("GreenD", GREEN_DK), loc=(0, -0.26, 0), rot=[("Z", 8)], bevel=0.1, outline=0.02)
    prism("GreenL", lhalf, 0.24, toy("GreenL", GREEN_LT), loc=(0, -0.26, 0), rot=[("Z", -8)], bevel=0.1, outline=0.02)
    for i, (x, z) in enumerate([(0, 0.95), (0.83, 0.7), (-0.83, 0.7), (0.87, 0.08), (-0.87, 0.08), (0.57, -0.6), (-0.57, -0.6), (0, -1.02)]):
        ball(f"Stud{i}", 0.065, gold("Stud"), loc=(x, -0.17, z), segs=20, outline=0.015)
    lib.group_tilt(-20, 8)


@icon
def Runner():
    mat = toy("Cyan", CYAN)
    for i, (x0, x1, z) in enumerate([(-0.72, 0.22, 1.3), (-1.3, -0.6, 0.88), (-1.55, -0.45, 0.2), (-1.42, -0.6, -0.36)]):
        capsule(f"Streak{i}", (x0, 0.45, z), (x1, 0.45, z), 0.15, toy("Streak", CYAN_LT), outline=0.06)
    figure(
        "R", mat,
        head=(0.7, 1.1, 0.47),
        torso=([(0.3, 0.55), (-0.05, -0.12)], 0.31, 0.26),
        limbs=[
            ([(0.45, 0.42), (0.95, 0.08), (1.25, 0.55)], 0.18, -0.3),
            ([(0.2, 0.68), (-0.5, 0.55), (-0.68, 0.3)], 0.18, 0.3),
            ([(0.08, -0.1), (0.85, -0.25), (0.52, -0.95)], 0.21, -0.15),
            ([(-0.15, -0.2), (-0.55, -0.52), (-1.02, -0.75)], 0.21, 0.2),
        ],
    )
    lib.group_tilt(-10, 6)


@icon
def Bomber():
    mat = toy("FigRed", FIG_RED)
    figure(
        "B", mat,
        head=(0.03, 0.83, 0.47),
        torso=([(-0.1, 0.3), (-0.28, -0.45)], 0.3, 0.26),
        limbs=[
            ([(0.0, 0.16), (0.62, 0.0), (0.92, 0.32)], 0.19, -0.3),
            ([(-0.22, 0.3), (-0.85, 0.5), (-1.3, 0.2)], 0.19, 0.3),
            ([(-0.2, -0.45), (0.5, -0.62), (0.68, -1.3)], 0.22, -0.15),
            ([(-0.36, -0.5), (-0.78, -0.8), (-1.32, -1.05)], 0.22, 0.2),
        ],
    )
    bx, bz, by = 1.08, 0.66, -0.42
    sphere("Bomb", 0.45, glossy("Iron", srgb("#26232C"), 0.3, 0.2, 0.7), loc=(bx, by, bz), outline=0.06)
    cyl("Collar", 0.13, 0.13, gold(), loc=(bx + 0.05, by, bz + 0.44), rot=[("Y", 8)], outline=0.03)
    fuse = [Vector((bx + 0.06, by, bz + 0.5)), Vector((bx + 0.08, by, bz + 0.62)), Vector((bx + 0.12, by, bz + 0.72))]
    tube("Fuse", fuse, 0.05, glossy("Cord", srgb("#C99A5A"), 0.8, coat=0), outline=0.03)
    spark("Spark", (bx + 0.12, by - 0.04, bz + 0.82), 0.32)
    lib.group_tilt(-10, 6)


@icon
def Dash():
    arrow = [(-0.45, 0.34), (0.15, 0.34), (0.15, 1.0), (1.3, 0.0), (0.15, -1.0), (0.15, -0.34), (-0.45, -0.34)]
    prism("Arrow", rounded(arrow, [0.18, 0.1, 0.2, 0.26, 0.2, 0.1, 0.18], 8), 0.46, toy("Cyan", CYAN), bevel=0.17, segs=6, outline=0.05)
    st = toy("Streak", CYAN_LT)
    for i, (x0, x1, z) in enumerate([(-0.85, 0.0, 0.68), (-1.5, -0.4, 0.0), (-1.15, -0.2, -0.68)]):
        capsule(f"Streak{i}", (x0, 0.08, z), (x1, 0.08, z), 0.15, st, outline=0.05)
    lib.group_tilt(-16, 8)


@icon
def Slide():
    mat = toy("Cyan", CYAN)
    figure(
        "S", mat,
        head=(0.9, 0.6, 0.47),
        torso=([(0.15, 0.28), (-0.3, -0.35)], 0.31, 0.27),
        limbs=[
            ([(0.2, 0.35), (-0.45, 0.53), (-1.1, 0.7)], 0.18, 0.25),
            ([(0.3, -0.1), (0.9, -0.25), (1.4, -0.4)], 0.19, -0.3),
            ([(-0.2, -0.5), (0.5, -0.68), (1.05, -0.8)], 0.2, -0.05),
        ],
    )
    dust = glossy("Dust", DUST, 0.55, coat=0.15)
    puffs = [
        (-1.55, -0.1, 0.3), (-1.2, -0.3, 0.3), (-0.95, -0.6, 0.28), (-0.55, -0.45, 0.3), (-0.2, -0.62, 0.25),
        (0.1, -0.77, 0.2), (0.4, -0.86, 0.14), (-1.4, -0.6, 0.27), (-0.75, -0.8, 0.22), (-1.72, -0.42, 0.2),
        (-1.1, -0.05, 0.2),
    ]
    inflate("Cloud", blob_outline(puffs, k=0.07), dust, front=0.32, back=0.18, sp=0.03, loc=(0, -0.3, 0), outline=0.05)
    for i, (x, z, r) in enumerate([(-1.45, -0.18, 0.17), (-0.6, -0.42, 0.18), (-1.05, -0.62, 0.15)]):
        sphere(f"Lump{i}", r, dust, loc=(x, -0.48, z), scale=(1, 0.55, 1), outline=0.03)
    for i, (x, z, r) in enumerate([(-0.83, 0.02, 0.12), (-1.38, -0.92, 0.1)]):
        ball(f"Bit{i}", r, dust, loc=(x, -0.2, z), segs=24, outline=0.04)
    capsule("Ground", (-0.1, -0.1, -0.98), (1.45, -0.1, -0.98), 0.045, dust, outline=0.03)
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
    palm = rounded([(-0.3, -0.52), (0.3, -0.52), (0.36, 0.0), (-0.36, 0.0)], [0.2, 0.2, 0.1, 0.1])
    inflate("Palm", palm, hand, front=0.11, back=0.04, sp=0.025, loc=(0, -0.23, -0.06), outline=0.03)
    for i, (x, tip, ang) in enumerate([(-0.255, 0.2, 6), (-0.085, 0.32, 2), (0.085, 0.3, -2), (0.255, 0.18, -6)]):
        top = (x - math.sin(math.radians(ang)) * 0.4, tip)
        capsule(f"Finger{i}", (x, -0.27, -0.12), (top[0], -0.27, top[1]), 0.088, hand, outline=0.028)
    capsule("Thumb", (0.22, -0.27, -0.4), (0.5, -0.27, -0.14), 0.095, hand, outline=0.028)
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
        ball(f"Stud{i}", 0.06, gold("Stud"), loc=(math.cos(a) * 0.885, -0.14, math.sin(a) * 0.885), segs=20, outline=0.012)
    sphere("Hub", 0.15, g, loc=(0, -0.22, 0), scale=(1, 0.8, 1))
    torus("HubRing", 0.16, 0.045, g, rot=[("X", 90)], loc=(0, -0.2, 0))
    prism("Pointer", rounded([(-0.22, 1.12), (0.22, 1.12), (0.0, 0.6)], [0.06, 0.06, 0.05], 4), 0.16, g, loc=(0, -0.26, 0), bevel=0.04)
    sphere("PointerCap", 0.085, g, loc=(0, -0.34, 1.02))
    st = toy("Stand", STAND)
    prism("Base", rounded([(-0.9, -1.3), (0.9, -1.3), (0.7, -1.06), (-0.7, -1.06)], 0.05, 3), 0.6, st, loc=(0, 0.1, 0), bevel=0.04)
    box("Neck", (0.5, 0.3, 0.4), st, loc=(0, 0.2, -0.92), bevel=0.04)
    lib.group_tilt(-20, 8)


@icon
def Eye():
    b = box("Button", (2.0, 0.55, 2.0), toy("Button", BUTTON), bevel=0.32)
    b.modifiers["Bevel"].segments = 6
    xs = [0.84 * math.cos(math.radians(a)) for a in range(180, -1, -6)]
    up = [(x, 0.5 * (1 - (x / 0.84) ** 2) ** 0.75) for x in xs]
    lo = [(x, -0.47 * (1 - (x / 0.84) ** 2) ** 0.75) for x in reversed(xs[1:-1])]
    inflate("White", up + lo, toy("EyeW", EYE_WHITE), front=0.1, back=0.02, sp=0.025, loc=(0, -0.27, 0), outline=0.035)
    sphere("Iris", 0.41, toy("IrisD", IRIS_DK), loc=(0, -0.345, 0), scale=(1, 0.22, 1), outline=0.015)
    sphere("IrisIn", 0.31, toy("Iris", IRIS), loc=(0, -0.375, 0), scale=(1, 0.2, 1), outline=0)
    sphere("Pupil", 0.18, toy("Pupil", INK), loc=(0, -0.41, 0), scale=(1, 0.2, 1), outline=0)
    sphere("Glint", 0.075, glossy("Glint", srgb("#FFFFFF"), 0.2, emit=1.5), loc=(-0.12, -0.45, 0.12), scale=(1, 0.4, 1), outline=0)
    lib.group_tilt(-20, 10)


@icon
def Heart():
    inflate("Heart", heart_pts(), toy("Heart", HEART), front=0.5, back=0.3, sp=0.03, outline=0.04)
    lib.group_tilt(-18, 8)
