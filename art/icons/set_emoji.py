"""FUSE VALLEY icons — set Emoji: the taunt faces (EmojiLaugh, EmojiCool, EmojiAngry, EmojiCry, EmojiLove, EmojiShock,
EmojiSilly, EmojiSkull, EmojiFire). Every face is real geometry built here — no emoji font, no stock art.

A face is a glossy toy-plastic ball with a soft vertical colour ramp (`grad`). Its features (eyes, brows, mouths,
teeth, tongues, tears, glasses) are drawn as 2D outlines in camera space, pillow-inflated (set_c.inflate) into soft
low bumps and then wrapped onto the ball (`wrap`: each vertex is dropped onto the surface along the view axis and
lifted along the surface normal by its bump height), so they hug the face like moulded-in decals. Strokes (`stroke`)
give the brows, closed eyes and smirks round caps. Features are drawn big and thick: the faces are shown at 70-120 px.
"""

import math

import bpy
import lib
from lib import glossy, icon, srgb
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from set_c import ball, blob_outline, chaikin, heart_pts, inflate, toy

# ── Palette ─────────────────────────────────────────────────────────────────────────────────────────────────────
FACE_TOP = srgb("#FFD21C")
FACE_MID = srgb("#FFB80E")
FACE_BOT = srgb("#FF8A06")
RED_TOP = srgb("#E8241C")
RED_MID = srgb("#F2441A")
RED_BOT = srgb("#FF7A10")
FEAR_TOP = srgb("#4A7CF0")
FEAR_MID = srgb("#9AB0E8")
INK = srgb("#3A1606")
MOUTH = srgb("#5C0C12")
TONGUE = srgb("#FF4E78")
TONGUE_DK = srgb("#C8244E")
TEETH = srgb("#FFF8EE")
WHITE = srgb("#FFFFFF")
TEAR = srgb("#2EA8FF")
TEAR_LT = srgb("#7FD4FF")
HEART = srgb("#E8102A")
BLUSH = srgb("#FF6E5A")
LENS = srgb("#141018")
STEAM = srgb("#F4F2F8")
BONE_TOP = srgb("#FFF6E2")
BONE_BOT = srgb("#E9D6B4")
SOCKET = srgb("#2A1830")
FLAME_RED = srgb("#E8360A")
FLAME_ORANGE = srgb("#FF7A0C")
FLAME_YELLOW = srgb("#FFC81E")

R = 1.0  # face radius
TILT = (-14, 7)


# ── Materials ───────────────────────────────────────────────────────────────────────────────────────────────────
def grad(name, stops, z0=-1.0, z1=1.0, emit=0.0):
    """Toy plastic with a vertical colour ramp in object space: stops [(t, colour)], t = 0 at z0 to 1 at z1. The
    flat Base Color stays at the middle stop so the outline hull (lib.add_hulls) still picks its dark edge from it."""
    m = toy(name, stops[len(stops) // 2][1], emit)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = z0
    mr.inputs["From Max"].default_value = z1
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = stops[0]
    els[1].position, els[1].color = stops[-1]
    for t, c in stops[1:-1]:
        e = els.new(t)
        e.color = c
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    if emit:
        nt.links.new(ramp.outputs["Color"], b.inputs["Emission Color"])
    return m


def face_mat():
    return grad("Face", [(0.0, FACE_BOT), (0.45, FACE_MID), (0.85, FACE_TOP), (1.0, FACE_TOP)])


def shine(name="Glint"):
    return glossy(name, WHITE, 0.2, emit=1.2)


# ── 2D outline tools (camera space: x right, z up) ──────────────────────────────────────────────────────────────
def ellipse(cx, cz, rx, rz, n=48, rot=0.0):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, z = rx * math.cos(a), rz * math.sin(a)
        out.append((cx + x * c - z * s, cz + x * s + z * c))
    return out


def arc(cx, cz, rx, rz, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + rz * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def qbez(p0, p1, p2, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(tuple((1 - t) ** 2 * p0[k] + 2 * (1 - t) * t * p1[k] + t * t * p2[k] for k in range(2)))
    return out


def stroke(path, w, wfun=None, cap=10):
    """The closed outline of a round-capped stroke of width w along an open path; wfun(t) scales the width."""
    P = [Vector(p) for p in path]
    n = len(P)
    L, R_ = [], []
    for i in range(n):
        t = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        nn = Vector((-t.y, t.x))
        h = w * 0.5 * (wfun(i / (n - 1)) if wfun else 1.0)
        L.append(P[i] + nn * h)
        R_.append(P[i] - nn * h)

    def capc(p, t, nn, h, sign):
        return [p + (nn * math.cos(a) + t * math.sin(a)) * h * sign for a in [math.pi * k / cap for k in range(1, cap)]]

    t1 = (P[-1] - P[-2]).normalized()
    n1 = Vector((-t1.y, t1.x))
    t0 = (P[1] - P[0]).normalized()
    n0 = Vector((-t0.y, t0.x))
    h1 = w * 0.5 * (wfun(1.0) if wfun else 1.0)
    h0 = w * 0.5 * (wfun(0.0) if wfun else 1.0)
    out = L + capc(P[-1], t1, n1, h1, 1) + list(reversed(R_))
    out += [P[0] + (-n0 * math.cos(a) - t0 * math.sin(a)) * h0 for a in [math.pi * k / cap for k in range(1, cap)]]
    return [(v.x, v.y) for v in out]


def region(lo, hi, x0, x1, n=40):
    """The area between two curves z = lo(x) and z = hi(x) for x in [x0, x1] (a mouth, a band of teeth, a tongue)."""
    xs = [x0 + (x1 - x0) * i / n for i in range(n + 1)]
    return [(x, hi(x)) for x in xs] + [(x, lo(x)) for x in reversed(xs[1:-1])]


def drop_pts(r=0.1, tip=0.22, n=32):
    """A teardrop: round end centred on the origin, tip at (0, tip)."""
    al = math.asin(r / tip)  # the tangent points seen from the tip sit at angles al and pi - al
    return [(0.0, tip)] + [(r * math.cos(al - (math.pi + 2 * al) * k / n), r * math.sin(al - (math.pi + 2 * al) * k / n)) for k in range(n + 1)]


def moved(pts, dx=0.0, dz=0.0, s=1.0, rot=0.0):
    c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    return [(dx + s * (x * c - z * sn), dz + s * (x * sn + z * c)) for x, z in pts]


def mirrored(pts):
    return [(-x, z) for x, z in reversed(pts)]


# ── 3D: features wrapped onto the face ──────────────────────────────────────────────────────────────────────────
class Surface:
    """Where the features land: an analytic ball (centre, radius) or mesh objects (ray-cast along +y, the nearest
    hit wins, so a feature can run across two touching parts)."""

    def __init__(self, center=(0, 0, 0), radius=R, objs=None):
        self.c = Vector(center)
        self.r = radius
        self.bvhs = []
        deps = bpy.context.evaluated_depsgraph_get()
        for o in objs or []:
            self.bvhs.append(BVHTree.FromObject(o.evaluated_get(deps), deps))

    def at(self, x, z):
        if self.bvhs:
            hits = [b.ray_cast(Vector((x, -50.0, z)), Vector((0, 1, 0))) for b in self.bvhs]
            hits = [h for h in hits if h[0] is not None]
            if hits:
                h = min(hits, key=lambda h: h[3])
                return h[0], h[1].normalized()
            return Vector((x, 0.0, z)), Vector((0, -1, 0))
        dx, dz = x - self.c.x, z - self.c.z
        q = max(self.r * self.r * 0.995 - dx * dx - dz * dz, 0.0)
        p = Vector((x, self.c.y - math.sqrt(q), z))
        return p, (p - self.c).normalized()


def bake(o, loc=(0, 0, 0), scale=(1, 1, 1)):
    """Move / scale an object's mesh itself (lib.group_tilt overwrites object transforms, and the ray-cast surfaces
    work in mesh space)."""
    for v in o.data.vertices:
        v.co = Vector((v.co.x * scale[0] + loc[0], v.co.y * scale[1] + loc[1], v.co.z * scale[2] + loc[2]))
    o.data.update()
    return o


def wrap(o, surf, lift=-0.008, extra=None):
    """Drop an inflated XZ feature onto the surface: (x, y, z) → surface(x, z) + normal * (lift - y [+ extra(x, z)])."""
    for v in o.data.vertices:
        x, y, z = v.co
        p, nrm = surf.at(x, z)
        h = lift - y + (extra(x, z) if extra else 0.0)
        v.co = p + nrm * h
    o.data.update()
    return o


def feat(name, pts, mat, surf, front=0.04, lift=-0.008, sp=0.016, outline=0.0, power=0.45, extra=None, back=0.03):
    o = inflate(name, pts, mat, front=front, back=back, sp=sp, outline=outline, power=power)
    return wrap(o, surf, lift, extra)


def glint(name, x, z, rx, rz, surf, lift, rot=0.0):
    return feat(name, ellipse(x, z, rx, rz, 24, rot), shine(), surf, front=0.012, lift=lift, sp=0.008)


def face(mat=None):
    ball("Face", R, mat or face_mat(), segs=96, outline=0.035)
    return Surface()


def open_eye(name, x, z, surf, rx=0.105, rz=0.16, rot=0.0):
    feat(name, ellipse(x, z, rx, rz, 48, rot), toy("Ink", INK), surf, front=0.05)
    glint(name + "G", x - rx * 0.32, z + rz * 0.42, rx * 0.34, rz * 0.26, surf, 0.035, rot)


def ink_stroke(name, path, w, surf, wfun=None, front=0.045, lift=-0.008):
    feat(name, stroke(path, w, wfun), toy("Ink", INK), surf, front=front, lift=lift, sp=min(0.016, w / 4))


def tear(name, x, z, s, rot, y=-0.6):
    """A loose tear drop (not on the face): blue glass-candy with a highlight."""
    pts = moved(drop_pts(0.1, 0.24), 0, 0, s, rot)
    o = inflate(name, pts, toy("Tear", TEAR, 0.15), front=0.1 * s * 1.4, back=0.08 * s * 1.4, sp=0.012, outline=0.022)
    bake(o, (x, y, z))
    gl = moved(ellipse(-0.035, 0.0, 0.03, 0.05, 20), 0, 0, s, rot)
    g = inflate(name + "G", gl, shine(), front=0.02, back=0.0, sp=0.008, outline=0)
    bake(g, (x, y - 0.1 * s * 1.4 + 0.004, z))
    return o


def open_mouth(surf, top, bot, x0, x1, teeth=0.0, tongue=None, name="Mouth", tongue_mat=None):
    """A moulded open mouth between z = bot(x) and z = top(x): dark cavity, an optional band of upper teeth (height
    `teeth`) and an optional tongue (z = tongue(x), clipped to the cavity)."""
    feat(name, chaikin(region(bot, top, x0, x1), iters=2), toy("Mouth", MOUTH), surf, front=0.045, power=0.3, outline=0.0)
    inset = 0.028
    if teeth:
        ts = x0 + (x1 - x0) * 0.1
        te = x1 - (x1 - x0) * 0.1
        feat(name + "Teeth", chaikin(region(lambda x: top(x) - inset - teeth, lambda x: top(x) - inset, ts, te), iters=2), toy("Teeth", TEETH), surf, front=0.03, lift=0.03, power=0.4)
    if tongue:
        # the tongue spans where its hump is above the cavity floor
        xs = [x0 + (x1 - x0) * i / 400 for i in range(401)]
        inside = [x for x in xs if tongue(x) > bot(x) + inset + 0.02]
        if inside:
            a, b = inside[0], inside[-1]
            feat(name + "Tongue", chaikin(region(lambda x: bot(x) + inset, lambda x: max(min(tongue(x), top(x) - inset), bot(x) + inset), a, b), iters=2), tongue_mat or toy("Tongue", TONGUE), surf, front=0.035, lift=0.03, power=0.45)


def done():
    lib.group_tilt(*TILT)


# ── The faces ───────────────────────────────────────────────────────────────────────────────────────────────────
@icon
def EmojiLaugh():
    s = face()
    # eyes squeezed shut: > <
    for side in (-1, 1):
        x0 = side * 0.52
        ink_stroke(f"Eye{side}", qbez((x0, 0.42), (side * 0.14, 0.27), (x0, 0.14), 20), 0.12, s)
        ink_stroke(f"Brow{side}", qbez((side * 0.62, 0.58), (side * 0.42, 0.7), (side * 0.2, 0.62), 16), 0.075, s)
    w = 0.6
    open_mouth(s, lambda x: -0.06 + 0.06 * (x / w) ** 2, lambda x: -0.06 - 0.56 * max(0.0, 1 - (x / w) ** 2) ** 0.62, -w, w, teeth=0.11, tongue=lambda x: -0.5 + 0.2 * max(0.0, 1 - (x / 0.34) ** 2))
    for side in (-1, 1):
        tear(f"Tear{side}", side * 1.06, 0.26, 1.75, side * 60)
    done()


@icon
def EmojiCool():
    s = face()
    lens = toy("Lens", LENS)
    lens.node_tree.nodes["Principled BSDF"].inputs["Coat Weight"].default_value = 1.0
    lens.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.6
    for side in (-1, 1):
        # a chunky aviator-ish lens: wide flat top, round belly
        pts = [(0.08, 0.36), (0.74, 0.4), (0.74, 0.26), (0.66, 0.06), (0.48, -0.04), (0.28, -0.02), (0.13, 0.1), (0.08, 0.26)]
        pts = [(side * x, z) for x, z in pts]
        if side < 0:
            pts.reverse()
        feat(f"Lens{side}", chaikin(pts, iters=4), lens, s, front=0.07, lift=0.0, power=0.35, outline=0.02)
        # two diagonal glints per lens
        gx = side * 0.4
        feat(f"Gl{side}", stroke([(gx - 0.12, 0.08), (gx + 0.0, 0.3)], 0.07), shine(), s, front=0.012, lift=0.068, sp=0.01)
        feat(f"Gl2{side}", stroke([(gx + 0.08, 0.1), (gx + 0.15, 0.22)], 0.04), shine(), s, front=0.012, lift=0.068, sp=0.008)
    feat("Bridge", stroke(qbez((-0.12, 0.3), (0.0, 0.36), (0.12, 0.3), 10), 0.09), lens, s, front=0.05, lift=0.0, outline=0.0)
    feat("Bar", stroke([(-0.76, 0.36), (0.76, 0.36)], 0.07), lens, s, front=0.05, lift=0.02, outline=0.0)
    # smug one-sided grin with a dimple at the high end
    smile = qbez((-0.36, -0.4), (0.12, -0.56), (0.42, -0.26), 28)
    ink_stroke("Smile", smile, 0.125, s, wfun=lambda t: 0.75 + 0.35 * math.sin(math.pi * t))
    ink_stroke("Dimple", qbez((0.37, -0.17), (0.48, -0.25), (0.47, -0.36), 10), 0.085, s)
    done()


@icon
def EmojiAngry():
    s = face(grad("FaceRed", [(0.0, RED_BOT), (0.4, RED_MID), (0.8, RED_TOP), (1.0, RED_TOP)]))
    for side in (-1, 1):
        # brows slam down to the middle, eyes tucked under them
        ink_stroke(f"Brow{side}", [(side * 0.62, 0.56), (side * 0.36, 0.44), (side * 0.12, 0.3)], 0.15, s, wfun=lambda t: 0.8 + 0.3 * t)
        feat(f"Eye{side}", chaikin([(side * 0.48, 0.32), (side * 0.18, 0.18), (side * 0.2, 0.06), (side * 0.32, 0.0), (side * 0.46, 0.06), (side * 0.52, 0.2)], iters=3), toy("Ink", INK), s, front=0.045)
        glint(f"EyeG{side}", side * 0.4, 0.17, 0.035, 0.03, s, 0.034)
    # gritted teeth: a frowning slot of teeth in a dark frame
    w = 0.46
    top2 = lambda x: -0.3 - 0.1 * (x / w) ** 2  # frown: corners drop  # noqa: E731
    bot2 = lambda x: -0.6 - 0.06 * (x / w) ** 2 + 0.04  # noqa: E731
    feat("Mouth", chaikin(region(bot2, top2, -w, w), iters=3), toy("Mouth", MOUTH), s, front=0.045, power=0.3)
    ins = 0.035
    feat("Teeth", chaikin(region(lambda x: bot2(x) + ins, lambda x: top2(x) - ins, -w + 0.04, w - 0.04), iters=3), toy("Teeth", TEETH), s, front=0.035, lift=0.03, power=0.35)
    mid = lambda x: (top2(x) + bot2(x)) / 2  # noqa: E731
    xs = [-w + 0.08 + (2 * w - 0.16) * i / 20 for i in range(21)]
    feat("Gap", stroke([(x, mid(x)) for x in xs], 0.03), toy("Mouth", MOUTH), s, front=0.012, lift=0.062, sp=0.007)
    for i, x in enumerate((-0.27, -0.09, 0.09, 0.27)):
        feat(f"Gap{i}", stroke([(x, top2(x) - 0.03), (x, bot2(x) + 0.03)], 0.03), toy("Mouth", MOUTH), s, front=0.012, lift=0.062, sp=0.007)
    # steam puffs off the top corner
    for i, (x, z, k) in enumerate(((0.8, 0.8, 1.25), (1.1, 1.06, 0.85))):
        circles = [(0.0, 0.0, 0.17 * k), (0.16 * k, 0.04 * k, 0.13 * k), (-0.14 * k, 0.03 * k, 0.12 * k), (0.03 * k, 0.13 * k, 0.12 * k)]
        p = inflate(f"Steam{i}", blob_outline(circles, 0.05 * k, 0.012), toy("Steam", STEAM), front=0.12 * k, back=0.08 * k, sp=0.014, outline=0.025)
        bake(p, (x, -0.3, z))
    done()


@icon
def EmojiCry():
    s = face()
    tear_m = toy("Stream", TEAR, 0.12)
    for side in (-1, 1):
        # eyes shut tight in sad arcs, brows tilted up in the middle
        ink_stroke(f"Eye{side}", arc(side * 0.33, 0.12, 0.17, 0.12, 180, 0, 20), 0.1, s)
        ink_stroke(f"Brow{side}", [(side * 0.6, 0.48), (side * 0.38, 0.54), (side * 0.16, 0.66)], 0.08, s)
        # a fat stream from under the eye, widening as it runs down the cheek and off the chin side
        path = qbez((side * 0.33, 0.05), (side * 0.38, -0.35), (side * 0.52, -0.66), 24)
        feat(f"Stream{side}", stroke(path, 0.17, wfun=lambda t: 0.8 + 0.4 * t), tear_m, s, front=0.05, lift=0.0, power=0.4, outline=0.0)
        feat(f"StreamG{side}", stroke(qbez((side * 0.3, -0.04), (side * 0.34, -0.28), (side * 0.44, -0.5), 14), 0.04), shine(), s, front=0.01, lift=0.05, sp=0.008)
        tear(f"Drop{side}", side * 0.66, -1.0, 1.1, side * 160)
    w = 0.29
    open_mouth(s, lambda x: -0.17 - 0.14 * (x / w) ** 2, lambda x: -0.7 + 0.12 * (x / w) ** 2, -w, w, teeth=0.075, tongue=lambda x: -0.56 + 0.07 * max(0.0, 1 - (x / 0.22) ** 2))
    done()


@icon
def EmojiLove():
    s = face()
    hm = toy("HeartEye", HEART)
    for side in (-1, 1):
        pts = moved(heart_pts(), side * 0.34, 0.22, 0.25, side * -8)
        feat(f"Heart{side}", pts, hm, s, front=0.11, lift=0.0, sp=0.014, power=0.5, outline=0.02)
        glint(f"HeartG{side}", side * 0.34 - 0.11, 0.3, 0.05, 0.035, s, 0.1, 30)
        feat(f"Blush{side}", ellipse(side * 0.6, -0.16, 0.14, 0.08, 32), toy("Blush", BLUSH), s, front=0.012, lift=-0.002, sp=0.014)
    w = 0.46
    open_mouth(s, lambda x: -0.2 + 0.07 * (x / w) ** 2, lambda x: -0.2 - 0.42 * max(0.0, 1 - (x / w) ** 2) ** 0.6, -w, w, teeth=0.08, tongue=lambda x: -0.55 + 0.17 * max(0.0, 1 - (x / 0.28) ** 2))
    done()


@icon
def EmojiShock():
    s = face(grad("FaceFear", [(0.0, FACE_BOT), (0.4, FACE_MID), (0.62, FACE_TOP), (0.78, FEAR_MID), (1.0, FEAR_TOP)]))
    for side in (-1, 1):
        x, z = side * 0.31, 0.16
        feat(f"White{side}", ellipse(x, z, 0.19, 0.24, 48), toy("EyeW", WHITE), s, front=0.05, lift=-0.004, outline=0.016)
        feat(f"Pupil{side}", ellipse(x, z - 0.02, 0.07, 0.085, 32), toy("Ink", INK), s, front=0.02, lift=0.044, sp=0.01)
        glint(f"PupilG{side}", x - 0.025, z + 0.02, 0.022, 0.022, s, 0.062)
        ink_stroke(f"Brow{side}", arc(side * 0.33, 0.48, 0.17, 0.12, 25, 155, 16), 0.075, s)
    feat("Mouth", ellipse(0.0, -0.5, 0.18, 0.24, 48), toy("Mouth", MOUTH), s, front=0.05, power=0.3)
    feat("MouthIn", ellipse(0.0, -0.56, 0.11, 0.12, 32), toy("Throat", srgb("#36060A")), s, front=0.012, lift=0.042, sp=0.01)
    # a cold sweat drop on the temple
    tear("Sweat", -0.86, 0.5, 0.9, 12, y=-0.55)
    done()


@icon
def EmojiSilly():
    s = face()
    # left: a tight wink; right: wide open eye
    ink_stroke("Wink", qbez((-0.5, 0.2), (-0.32, 0.34), (-0.14, 0.2), 16), 0.1, s)
    ink_stroke("WinkL", [(-0.48, 0.22), (-0.6, 0.3)], 0.06, s)
    open_eye("Eye", 0.32, 0.22, s, 0.11, 0.17)
    ink_stroke("BrowR", arc(0.32, 0.5, 0.16, 0.1, 30, 150, 14), 0.07, s)
    # big grin, tongue lolling out and down past the lip
    w = 0.5
    top = lambda x: -0.18 + 0.1 * (x / w) ** 2  # noqa: E731
    bot = lambda x: -0.18 - 0.28 * max(0.0, 1 - (x / w) ** 2) ** 0.6  # noqa: E731
    open_mouth(s, top, bot, -w, w, teeth=0.075)
    tongue = []
    for x, z in arc(0.07, -0.56, 0.2, 0.26, 0, -180, 28):
        tongue.append((x, z))
    tongue = [(0.27, -0.3)] + tongue + [(-0.13, -0.3)]
    tongue = chaikin(tongue, iters=3)
    feat("Tongue", tongue, toy("Tongue", TONGUE), s, front=0.06, lift=0.035, power=0.45, outline=0.016, extra=lambda x, z: max(0.0, -0.36 - z) * 0.45)
    feat("Groove", stroke(qbez((0.07, -0.38), (0.08, -0.5), (0.07, -0.6), 8), 0.035), toy("TongueDk", TONGUE_DK), s, front=0.012, lift=0.09, sp=0.008, extra=lambda x, z: max(0.0, -0.36 - z) * 0.45)
    done()


@icon
def EmojiSkull():
    bone = grad("Bone", [(0.0, BONE_BOT), (0.5, BONE_TOP), (1.0, BONE_TOP)], -1.2, 1.0)
    head = ball("Cranium", R, bone, segs=96, outline=0.035)
    bake(head, (0, 0, 0.12), (1.0, 0.92, 0.9))
    jaw = lib.box("Jaw", (0.86, 0.9, 0.5), bone, loc=(0, -0.12, -0.7), bevel=0.22)
    jaw.modifiers["Bevel"].segments = 6
    s = Surface(objs=[head, jaw])
    sock = toy("Socket", SOCKET)
    for side in (-1, 1):
        feat(f"Socket{side}", ellipse(side * 0.34, 0.04, 0.24, 0.27, 48, side * -12), sock, s, front=0.03, lift=-0.01, power=0.25)
        glint(f"SockG{side}", side * 0.34 - 0.08, 0.14, 0.055, 0.055, s, 0.02)
        glint(f"SockG2{side}", side * 0.34 + 0.07, -0.06, 0.028, 0.028, s, 0.02)
    feat("Nose", moved(heart_pts(), 0.0, -0.3, 0.1, 180), sock, s, front=0.025, lift=-0.008, sp=0.01, power=0.3)
    # teeth: four chunky blocks on a dark backing across the jaw front, so the gaps read at small size
    feat("Gums", chaikin([(-0.36, -0.52), (0.36, -0.52), (0.36, -0.86), (-0.36, -0.86)], iters=3), sock, s, front=0.02, lift=-0.006, power=0.3)
    for i in range(4):
        x = -0.255 + 0.17 * i
        pts = chaikin([(x - 0.072, -0.55), (x + 0.072, -0.55), (x + 0.072, -0.83), (x - 0.072, -0.83)], iters=3)
        feat(f"Tooth{i}", pts, toy("Tooth", TEETH), s, front=0.045, lift=0.0, sp=0.012, power=0.4, outline=0.0)
    lib.group_tilt(-16, 9)


@icon
def EmojiFire():
    outer = [
        (0.0, -0.95), (0.55, -0.88), (0.88, -0.55), (0.98, -0.1), (0.9, 0.3), (0.72, 0.62),
        (0.78, 1.0), (0.45, 0.72), (0.32, 1.06), (0.12, 1.5),
        (-0.18, 1.18), (-0.36, 0.86), (-0.58, 1.12), (-0.72, 0.62), (-0.92, 0.3), (-0.98, -0.1), (-0.88, -0.55), (-0.55, -0.88),
    ]
    sharp = (6, 9, 12)
    inflate("Outer", chaikin(outer, sharp=sharp), toy("FlameR", FLAME_RED, 0.25), front=0.5, back=0.36, sp=0.03, outline=0.04)
    mid = [(x * 0.8, z * 0.78 - 0.1) for x, z in outer]
    o = inflate("Mid", chaikin(mid, sharp=sharp), toy("FlameO", FLAME_ORANGE, 0.35), front=0.32, back=0.05, sp=0.03, outline=0)
    bake(o, (0, -0.24, 0))
    core = [(x * 0.6, z * 0.5 - 0.3) for x, z in outer]
    o = inflate("Core", chaikin(core, sharp=sharp), toy("FlameY", FLAME_YELLOW, 0.4), front=0.2, back=0.05, sp=0.025, outline=0)
    bake(o, (0, -0.46, 0))
    # features on the merged front: ray-cast onto the yellow core
    s = Surface(objs=[o])
    open_eye("EyeL", -0.22, -0.1, s, 0.09, 0.145)
    open_eye("EyeR", 0.2, -0.08, s, 0.09, 0.145)
    ink_stroke("BrowL", qbez((-0.36, 0.13), (-0.24, 0.19), (-0.1, 0.13), 10), 0.07, s)
    ink_stroke("BrowR", qbez((0.08, 0.19), (0.2, 0.27), (0.34, 0.27), 10), 0.07, s)
    ink_stroke("Grin", qbez((-0.26, -0.42), (0.02, -0.6), (0.32, -0.36), 20), 0.1, s, wfun=lambda t: 0.75 + 0.35 * math.sin(math.pi * t))
    lib.group_tilt(-16, 8)
