"""FUSE VALLEY — the cosmetic VFX textures (Asset Bible §5.6, §8.1–8.3; Store ids in src/shared/Config/Store.luau).

Hand-designed procedural sprites in the house style of art/vfx/make_vfx.py: signed-distance shapes with toon tone bands,
a chunky Ink outline where the shape is a solid object (paper, ink, ice, foil, cubes), and hard-banded glow (white core →
colour band → rim, then a low soft halo) where the shape is light (sparks, fireworks, neon). Deterministic (seeded).
No AI, no stock. Every sprite / sheet / strip is written to art/out/VfxCosmetics/ as a transparent power-of-two PNG.

  Explosions   boom_*     (Boom_Confetti, Boom_InkSplat, Boom_Peony, Boom_Pixel, Boom_Frost, Boom_BlackHole,
                           Boom_Champagne)
  Fuse Sparks  spark_*    (Spark_Sparkler, Spark_EmberDrift, Spark_Electric, Spark_Pixie, Spark_Plasma,
                           Spark_GoldLeaf, Spark_Insignia)
  Trails       trail_*    512×64 strips, the head (attachment end) on the LEFT, alpha fading to the tail on the right
  Victory      victory_*  (Victory_Confetti, Victory_Fountain, Victory_Finale, Victory_Dragon, Victory_ChampagneTower)

Flipbooks are square grids (Roblox ParticleEmitter.FlipbookLayout Grid2x2 / Grid4x4), frames left→right, top→bottom.
Review sheets (_sheet_<category>.png, every texture on dark and light) are written next to them; the leading underscore
keeps them out of tools/upload_assets.py. The wiring recipes live in art/vfx/COSMETICS.md.

Run: blender -b --python-exit-code 1 --python art/vfx/make_cosmetics.py [-- boom spark trail victory]
"""

import math
import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
from texlib import fbm, grid, hexc, poly_dist, save, seg_dist  # noqa: E402

OUT = os.path.join(ROOT, "art", "out", "VfxCosmetics")

# ── palette (Asset Bible §2.3 tokens, plus the documented tints each cosmetic uses) ─────────────────────────────────
INK = hexc("#16121C")
INK2 = hexc("#241D2E")
SMOKE = hexc("#3B3447")
PAPER = hexc("#FFF3E2")
WHITE = np.array([1.0, 1.0, 1.0])
FUSE = hexc("#FF6A1F")
EMBER = hexc("#FF9442")
SPARK = hexc("#FFD84A")
GOLD = hexc("#F2B13A")
BRASS = hexc("#C9973F")
DETONATE = hexc("#E8322B")
SAFE = hexc("#3BE48C")
MEGA = hexc("#B04CFF")
EPIC = hexc("#A65BFF")
PINK = hexc("#FF5CA8")  # a warm tint between Detonate and Mega (party pink)
MAGENTA = hexc("#E83CFF")  # Mega pushed toward pink (plasma, neon)
GOLD_HI = hexc("#FFE9A6")
GOLD_LO = hexc("#A8701E")
ICE_HI = hexc("#F4FBFF")
ICE = hexc("#BFDDFF")
ICE_MID = hexc("#86A9F2")  # periwinkle, never Runner cyan
ICE_LO = hexc("#4A63B8")
ICE_INK = hexc("#1C2350")
ELEC = hexc("#8FB4FF")
ELEC_DEEP = hexc("#6A5CFF")
LAVENDER = hexc("#CDB8FF")

ASSETS = []  # (category, name, fn)


def asset(cat, name):
    def deco(fn):
        ASSETS.append((cat, name, fn))
        return fn

    return deco


# ── SDF toolkit ──────────────────────────────────────────────────────────────────────────────────────────────────────
def cover(sd, px):
    return np.clip(0.5 - sd / px, 0, 1)


class Cv:
    """A straight-alpha RGBA canvas over coordinate arrays x, y (y down) with pixel size px."""

    def __init__(self, x, y, px):
        self.x, self.y, self.px = x, y, px
        self.c = np.zeros(x.shape + (3,))
        self.a = np.zeros(x.shape)

    def over(self, col, cov):
        cov = np.clip(cov, 0, 1)
        col = np.asarray(col, float)
        if col.ndim == 1:
            col = np.broadcast_to(col, self.c.shape)
        na = cov + self.a * (1 - cov)
        old = self.a * (1 - cov)
        self.c = (col * cov[..., None] + self.c * old[..., None]) / np.maximum(na, 1e-6)[..., None]
        self.a = na

    def fill(self, sd, col, alpha=1.0, soft=1.0):
        self.over(col, cover(sd, self.px * soft) * alpha)

    def halo(self, sd, col, radius, strength):
        """A soft glow outside a shape (draw it first, under the shape)."""
        self.over(col, np.exp(-np.maximum(sd, 0) / radius) * strength)

    def rgba(self):
        return np.dstack([self.c, self.a])


def tile(n, m=None, scale=1.0):
    """A canvas on -1..1 (times scale) along its longer side, isotropic."""
    m = m or n
    big = max(n, m)
    y, x = np.mgrid[0:n, 0:m].astype(np.float64)
    x = ((x + 0.5) - m / 2) / big * 2 * scale
    y = ((y + 0.5) - n / 2) / big * 2 * scale
    return Cv(x, y, 2 * scale / big)


def rot(x, y, a):
    c, s = math.cos(a), math.sin(a)
    return x * c + y * s, -x * s + y * c


def sd_circle(cx, cy, r):
    return lambda x, y: np.hypot(x - cx, y - cy) - r


def sd_ellipse(cx, cy, rx, ry, ang=0.0):
    def f(x, y):
        u, v = rot(x - cx, y - cy, ang)
        k = np.hypot(u / rx, v / ry)
        return (k - 1) * min(rx, ry)

    return f


def sd_box(cx, cy, hw, hh, ang=0.0, r=0.0, sx=1.0):
    def f(x, y):
        u, v = rot(x - cx, y - cy, ang)
        u = u / sx
        qx = np.abs(u) - hw + r
        qy = np.abs(v) - hh + r
        return (np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r) * min(sx, 1)

    return f


def inside_poly(x, y, pts):
    inside = np.zeros(x.shape, bool)
    n = len(pts)
    for i in range(n):
        (xi, yi), (xj, yj) = pts[i], pts[(i + 1) % n]
        if yi == yj:
            continue
        cond = ((yi > y) != (yj > y)) & (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        inside ^= cond
    return inside


def sd_poly(pts, r=0.0):
    """Signed distance to a closed polygon; r > 0 rounds it (grow the shape by r: pass pre-shrunk points)."""
    pts = [tuple(p) for p in pts]

    def f(x, y):
        d = poly_dist(x, y, pts + [pts[0]])
        return np.where(inside_poly(x, y, pts), -d, d) - r

    return f


def star_pts(cx, cy, n, ro, ri, a0=-math.pi / 2, sx=1.0, ang=0.0):
    pts = []
    for k in range(n * 2):
        a = a0 + k * math.pi / n
        r = ro if k % 2 == 0 else ri
        if callable(r):
            r = r(k)
        u, v = math.cos(a) * r * sx, math.sin(a) * r
        c, s = math.cos(ang), math.sin(ang)
        pts.append((cx + u * c - v * s, cy + u * s + v * c))
    return pts


def sd_seg(a, b, r):
    return lambda x, y: seg_dist(x, y, a, b) - r


def sd_taper(a, b, ra, rb):
    """A capsule whose radius goes ra (at a) → rb (at b)."""
    ax, ay = a
    bx, by = b

    def f(x, y):
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy + 1e-12
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / l2, 0, 1)
        return np.hypot(x - (ax + t * dx), y - (ay + t * dy)) - (ra + (rb - ra) * t)

    return f


def sd_path(pts, r_fn):
    """Distance to a polyline with a radius that varies along it: r_fn(s) for s in 0..1. Returns (sd, s, side)."""

    def f(x, y):
        best = np.full(x.shape, 9.0)
        bs = np.zeros(x.shape)
        side = np.zeros(x.shape)
        n = len(pts) - 1
        for i in range(n):
            (ax, ay), (bx, by) = pts[i], pts[i + 1]
            dx, dy = bx - ax, by - ay
            l2 = dx * dx + dy * dy + 1e-12
            t = np.clip(((x - ax) * dx + (y - ay) * dy) / l2, 0, 1)
            d = np.hypot(x - (ax + t * dx), y - (ay + t * dy))
            m = d < best
            best = np.where(m, d, best)
            bs = np.where(m, (i + t) / n, bs)
            cr = dx * (y - ay) - dy * (x - ax)
            side = np.where(m, np.sign(cr), side)
        return best - r_fn(bs), bs, side

    return f


def union(*fs):
    return lambda x, y: np.min(np.stack([f(x, y) for f in fs]), axis=0)


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smooth_union(fs, k):
    def f(x, y):
        d = fs[0](x, y)
        for g in fs[1:]:
            d = smin(d, g(x, y), k)
        return d

    return f


def shade(c, k):
    """Darker (k < 0, toward Ink) or lighter (k > 0, toward white) tint of a colour."""
    return c * (1 + k) - INK * k if k < 0 else c * (1 - k) + WHITE * k


def toon(cv, f, base, dark=None, light=None, ink=INK, ow=0.05, sh=0.09, lw=0.05, hl=None):
    """A solid cartoon shape: Ink outline, base fill, a dark crescent bottom-right, a light crescent top-left."""
    x, y = cv.x, cv.y
    d = f(x, y)
    if ink is not None and ow > 0:
        cv.fill(d - ow, ink)
    cv.fill(d, base)
    if dark is not None:
        cv.fill(np.maximum(d, -f(x + sh, y + sh)), dark)
    if light is not None:
        cv.fill(np.maximum(d + lw * 0.5, -f(x - lw, y - lw)), light)
    if hl is not None:
        cv.fill(hl(x, y), WHITE)
    return d


def glow_dot(cv, cx, cy, r, core, mid, rim, halo=None, halo_r=None, halo_k=0.35, alpha=1.0):
    """A hard-banded glowing dot: white core, colour band, rim; then a low soft halo."""
    d = np.hypot(cv.x - cx, cv.y - cy)
    if halo is not None:
        cv.halo(d - r, halo, halo_r or r * 1.4, halo_k * alpha)
    cv.fill(d - r, rim, alpha)
    cv.fill(d - r * 0.72, mid, alpha)
    cv.fill(d - r * 0.4, core, alpha)


def twinkle(cv, cx, cy, r, w, col, ang=0.0, n=4):
    """A thin n-point twinkle (cross of tapered needles)."""
    for k in range(n):
        a = ang + k * 2 * math.pi / n
        tip = (cx + math.cos(a) * r, cy + math.sin(a) * r)
        cv.fill(sd_taper((cx, cy), tip, w, 0.0)(cv.x, cv.y), col)


def sheet(frames, side, n, fn):
    """A side×side flipbook of n² tiles: fn(cv, frame_index, t) draws one tile."""
    out = np.zeros((n * side, n * side, 4))
    for f in range(frames):
        cv = tile(n)
        fn(cv, f, f / max(frames - 1, 1))
        r, c = f // side, f % side
        out[r * n:(r + 1) * n, c * n:(c + 1) * n] = cv.rgba()
    return out


def ease_out(t, p=2.0):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** p


def clamp01(t):
    return min(max(t, 0.0), 1.0)


# ── shared designs ───────────────────────────────────────────────────────────────────────────────────────────────────
def paper_piece(cv, kind, col, ang, squash, seed, ow=0.055, foil=False):
    """One piece of confetti (or foil) mid-tumble: squash < 1 foreshortens it (the flip), the back face shows darker."""
    rng = np.random.default_rng(seed)
    dark = shade(col, -0.3)
    light = shade(col, 0.45)
    s = 1.38
    if kind == "strip":
        f = sd_box(0, 0, 0.62 * s, 0.2 * s, ang, 0.05, squash)
    elif kind == "square":
        f = sd_box(0, 0, 0.4 * s, 0.4 * s, ang, 0.06, squash)
    elif kind == "circle":
        f = sd_ellipse(0, 0, 0.44 * s * squash, 0.44 * s, ang)
    elif kind == "tri":
        pts = star_pts(0, 0, 3, 0.48 * s, 0.48 * s, ang=ang, sx=squash)[::2]
        f = sd_poly(pts, 0.06)
    elif kind == "star":
        f = sd_poly(star_pts(0, 0, 5, 0.6 * s, 0.27 * s, ang=ang, sx=squash), 0.04)
    elif kind == "diamond":
        f = sd_poly([(0, -0.6 * s), (0.34 * s, 0), (0, 0.6 * s), (-0.34 * s, 0)], 0.04)
        f0 = f
        f = lambda x, y, f0=f0: f0(*rot(x, y, ang))  # noqa: E731
    elif kind == "heart":
        def f(x, y):
            u, v = rot(x, y, ang)
            u = u / squash
            a = np.hypot(u - 0.2, v + 0.12) - 0.27
            b = np.hypot(u + 0.2, v + 0.12) - 0.27
            c = sd_poly([(-0.44, -0.0), (0.44, -0.0), (0, 0.52)], 0.02)(u, v)
            return np.minimum(np.minimum(a, b), c) * min(squash, 1)
    else:  # curl: a curled ribbon
        a0 = rng.uniform(0, 2 * math.pi)
        pts = []
        for i in range(40):
            s_ = i / 39
            th = a0 + s_ * 4.4
            rr = 0.66 - 0.36 * s_
            u, v = math.cos(th) * rr * squash, math.sin(th) * rr
            pts.append(rot(np.array(u), np.array(v), -ang))
        pts = [(float(p[0]), float(p[1])) for p in pts]
        path = sd_path(pts, lambda s_: 0.15 - 0.04 * s_)
        d, sp, side = path(cv.x, cv.y)
        cv.fill(d - ow, INK)
        cv.fill(d, col)
        twist = np.cos(sp * 9.0)  # noqa: F841
        cv.fill(np.maximum(d, np.where(twist < -0.2, -0.5, 0.5)), dark)
        cv.fill(np.maximum(d + 0.035, (side * (twist > 0) < 0.5) * 1.0 - 0.5), light)
        return
    if foil:
        foil_fill(cv, f, col, ang, seed, ow)
        return
    d = toon(cv, f, col, dark if squash > 0.55 else None, light, ow=ow, sh=0.1, lw=0.06)
    if squash <= 0.55:  # nearly edge-on: the back face is showing
        cv.fill(np.maximum(d, 0.0 + (cv.x * math.cos(ang) + cv.y * math.sin(ang) < 0.05) * 1.0 - 0.5), dark)
    if kind in ("strip", "square") and squash > 0.55:  # a crease across the paper
        u, v = rot(cv.x, cv.y, ang + 0.4)
        cv.fill(np.maximum(d + 0.03, np.abs(u) - 0.012), dark)


def foil_fill(cv, f, col, ang, seed, ow, crinkle=5.0, freq=7.0, dark_at=-0.35, light_at=0.55):
    """Metal foil: Ink outline, then anisotropic crinkle bands (dark / base / light / spec) across the piece."""
    x, y = cv.x, cv.y
    d = f(x, y)
    cv.fill(d - ow, INK)
    u, v = rot(x, y, ang + 0.7)
    crk = fbm(x * 1.2, y * 1.2, 3, seed, 3) - 0.5
    band = np.sin(u * freq + crk * crinkle + seed)
    lo = shade(col, -0.4)
    hi = shade(col, 0.55)
    colr = np.where((band < dark_at)[..., None], lo, np.where((band > light_at)[..., None], hi, col))
    colr = np.where((band > 0.9)[..., None], WHITE, colr)
    cv.over(colr, cover(d, cv.px))
    cv.fill(np.maximum(d + 0.03, -f(x - 0.06, y - 0.06)), hi, 0.8)


def confetti_sheet(spec, seed0):
    def fn(cv, f, t):
        kind, col, ang, sq = spec[f]
        paper_piece(cv, kind, col, ang, sq, seed0 + f)

    return sheet(16, 4, 256, fn)


def peony_tile(cv, t, seed, scheme):
    """One frame of a spherical firework burst: stars fly out on a sphere, trail, droop and twinkle out."""
    rng = np.random.default_rng(seed)
    n = 44
    gold_ang = math.pi * (3 - math.sqrt(5))
    x, y = cv.x, cv.y
    rad = 0.84 * ease_out(t / 0.7, 2.6)
    lag = 0.08 + 0.26 * clamp01(t / 0.5) - 0.2 * clamp01((t - 0.55) / 0.45)
    rad_tail = 0.84 * ease_out(max(t - lag, 0) / 0.7, 2.6)
    droop = 0.22 * t * t
    fade = 1 - clamp01((t - 0.72) / 0.28)
    # the opening flash
    if t < 0.2:
        k = 1 - t / 0.2
        glow_dot(cv, 0, 0, 0.32 * k + 0.05, WHITE, scheme(0, 0)[1], scheme(0, 0)[0], scheme(0, 0)[0], 0.25, 0.4)
    stars = []
    for i in range(n):
        zz = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - zz * zz)
        th = gold_ang * i + rng.uniform(-0.15, 0.15)
        px_, py_ = math.cos(th) * rr, math.sin(th) * rr
        stars.append((zz, px_, py_, i))
    stars.sort()  # back to front
    for zz, px_, py_, i in stars:
        rr = math.sqrt(1 - zz * zz)
        depth = 0.75 + 0.25 * (zz + 1) / 2
        hx, hy = px_ * rad, py_ * rad + droop
        tx, ty = px_ * rad_tail, py_ * rad_tail + droop * 0.6
        trail_c, head_c = scheme(i, rr)
        if math.hypot(hx - tx, hy - ty) > 0.01 and fade > 0:
            path = sd_taper((tx, ty), (hx, hy), 0.0, 0.03 * depth)
            dd = path(x, y)
            cv.halo(dd, trail_c, 0.03, 0.22 * fade)
            cv.fill(dd, trail_c, fade)
            cv.fill(sd_taper((tx, ty), (hx, hy), 0.0, 0.013 * depth)(x, y), head_c, fade)
        on = True
        if t > 0.6:
            on = (i + int(t * 40)) % 3 != 0
        if on and fade > 0:
            hr = 0.04 * depth * (1 - 0.5 * clamp01((t - 0.6) / 0.4))
            glow_dot(cv, hx, hy, hr, WHITE, head_c, trail_c, trail_c, hr * 1.6, 0.35, alpha=min(1.0, fade * 1.6))
            if (i % 4 == 0) and t > 0.3:
                twinkle(cv, hx, hy, hr * 2.6, hr * 0.32, WHITE, ang=0.3 * i)


def peony_scheme_violet(i, rr):
    return (MEGA if i % 2 else MAGENTA), SPARK


def peony_scheme_multi(i, rr):
    ring = [SAFE, MEGA, PINK, SPARK, EMBER]
    if rr < 0.55:
        return GOLD, WHITE
    return ring[i % len(ring)], shade(ring[i % len(ring)], 0.55)


# ═════════════════════════════════════════════ EXPLOSIONS ═══════════════════════════════════════════════════════════
CONF_COLS = [SPARK, SAFE, MEGA, PINK, PAPER, FUSE]


@asset("boom", "boom_confetti_pieces")
def boom_confetti_pieces():
    kinds = ["strip", "square", "circle", "tri", "strip", "star", "curl", "square",
             "circle", "strip", "diamond", "curl", "tri", "strip", "square", "star"]
    rng = np.random.default_rng(11)
    spec = []
    for i, k in enumerate(kinds):
        col = CONF_COLS[(i * 5) % len(CONF_COLS)]
        spec.append((k, col, rng.uniform(-1.2, 1.2), [1.0, 0.8, 0.6, 0.42][i % 4] if k not in ("curl",) else 1.0))
    return confetti_sheet(spec, 100)


@asset("boom", "boom_confetti_streamers")
def boom_confetti_streamers():
    cols = [SPARK, PINK, SAFE, MEGA]

    def fn(cv, f, t):
        rng = np.random.default_rng(300 + f)
        col = cols[f]
        dark, light = shade(col, -0.32), shade(col, 0.45)
        a = (-0.78, 0.7)
        b = (0.74, -0.72)
        ph, k = rng.uniform(0, 6.3), rng.uniform(1.6, 2.1)
        tw = rng.uniform(2.5, 3.4)
        pts = []
        for i in range(90):
            s = i / 89
            px_ = a[0] + (b[0] - a[0]) * s
            py_ = a[1] + (b[1] - a[1]) * s
            off = 0.3 * math.sin(2 * math.pi * k * s + ph) * (0.4 + 0.6 * math.sin(math.pi * s))
            pts.append((px_ + off * 0.707, py_ + off * 0.707))
        hw = 0.11

        def width(s):
            return hw * (0.18 + 0.82 * np.abs(np.cos(2 * math.pi * tw * s + 0.5)))

        d, sp, side = sd_path(pts, width)(cv.x, cv.y)
        cv.fill(d - 0.04, INK)
        cv.fill(d, col)
        back = np.cos(2 * math.pi * tw * sp + 0.5) * np.sin(2 * math.pi * tw * sp * 0.5 + 1.0) < 0
        cv.fill(np.maximum(d, 0.5 - back * 1.0), dark)
        edge = (side > 0) & ~back
        cv.fill(np.maximum(d + 0.03, 0.5 - edge * 1.0), light)

    return sheet(4, 2, 512, fn)


@asset("boom", "boom_confetti_pop")
def boom_confetti_pop():
    cv = tile(512)
    rng = np.random.default_rng(5)
    n = 14
    outer = [0.94 if k % 2 == 0 else 0.74 for k in range(n)]
    outer = [o * rng.uniform(0.92, 1.0) for o in outer]

    def burst(scale, inner):
        pts = []
        for k in range(n * 2):
            a = -math.pi / 2 + k * math.pi / n
            r = outer[k // 2] * scale if k % 2 == 0 else inner * scale
            pts.append((math.cos(a) * r, math.sin(a) * r))
        return sd_poly(pts, 0.015)

    f1 = burst(1.0, 0.56)
    d1 = f1(cv.x, cv.y)
    cv.fill(d1 - 0.035, INK)
    cv.fill(d1, PINK)
    cv.fill(np.maximum(d1, -f1(cv.x + 0.05, cv.y + 0.05)), shade(PINK, -0.25))
    f2 = burst(0.68, 0.5)
    cv.fill(f2(cv.x, cv.y), SPARK)
    cv.fill(sd_circle(0, 0, 0.3)(cv.x, cv.y), PAPER)
    cv.fill(sd_circle(-0.08, -0.08, 0.12)(cv.x, cv.y), WHITE)
    # confetti specks thrown off the points
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.6, 0.85)
        col = CONF_COLS[k % 4]
        f = sd_box(math.cos(a) * r, math.sin(a) * r, 0.035, 0.018, a, 0.008)
        cv.fill(f(cv.x, cv.y) - 0.015, INK)
        cv.fill(f(cv.x, cv.y), col)
    return cv.rgba()


def ink_shape(t, seed, arms=10, sats=12, splat=False):
    """The ink splash as one SDF at time t (0 = impact, 1 = gone): a core, tapered arms ending in drops, satellites."""
    rng = np.random.default_rng(seed)
    g = ease_out(t / 0.32, 2.2)
    detach = clamp01((t - 0.34) / 0.3)
    shrink = clamp01((t - 0.5) / 0.42) ** 0.8
    if splat:  # the floor decal is the splash at rest: fully spread, nothing detached or shrunk
        g, detach, shrink = 1.0, 0.0, 0.0
    parts = []
    core_r = (0.2 + 0.12 * g) * (1 - shrink) * (1 - 0.35 * detach)
    if splat:
        core_r = 0.36
    if core_r > 0.005:
        if True:
            def core(x, y, seed=seed):
                a = np.arctan2(y, x)
                wob = 1 + (0.16 if splat else 0.1) * (fbm(np.cos(a) * 1.5, np.sin(a) * 1.5, 4, seed, 3) - 0.5) * 2 + 0.05 * np.sin(a * 7)
                return np.hypot(x, y) - core_r * wob
            parts.append(core)
        else:
            parts.append(sd_circle(0, 0, core_r))
    for i in range(arms):
        a = (i + rng.uniform(-0.3, 0.3)) * 2 * math.pi / arms
        length = rng.uniform(0.42, 0.78)
        w = rng.uniform(0.05, 0.085)
        drop = rng.uniform(0.06, 0.1)
        if splat:
            w *= 1.5
            drop *= 1.35
            ext = length * 0.92
            tip_d = ext
            neck = w * 0.62
        else:
            ext = length * g * (1 - 0.45 * detach)
            tip_d = length * g + 0.22 * detach
            neck = w * (1 - detach)
        ca, sa = math.cos(a), math.sin(a)
        dr = drop * (1 - shrink) * (1 if splat else (0.5 + 0.5 * g))
        if neck > 0.004 and ext > 0.02:
            parts.append(sd_taper((0, 0), (ca * ext, sa * ext), neck * 1.6, neck * 0.55))
        if dr > 0.005:
            parts.append(sd_circle(ca * tip_d, sa * tip_d, dr))
    sat_parts = []
    for i in range(sats):
        a = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.45, 0.9)
        r = rng.uniform(0.022, 0.048) * (1 - shrink)
        dd = dist * (g if not splat else 1.0) + 0.12 * detach
        if r > 0.004 and dd > 0.05:
            sat_parts.append(sd_circle(math.cos(a) * dd, math.sin(a) * dd, r))
    body = smooth_union(parts, 0.07) if parts else (lambda x, y: np.full(x.shape, 9.0))
    if sat_parts:
        return union(body, *sat_parts)
    return body


def ink_draw(cv, f, rim=0.035):
    x, y = cv.x, cv.y
    d = f(x, y)
    cv.fill(d - rim, PAPER)  # the Paper rim reads on dark ground
    cv.fill(d, INK)
    cv.fill(np.maximum(d, -f(x + 0.05, y + 0.05)), INK2)
    gloss = np.maximum(d + 0.022, -f(x - 0.03, y - 0.03))
    cv.fill(gloss, PAPER)


@asset("boom", "boom_ink_splash")
def boom_ink_splash():
    def fn(cv, f, t):
        if t >= 0.999:
            return
        ink_draw(cv, ink_shape(t * 0.98, 41, sats=8))

    return sheet(16, 4, 256, fn)


@asset("boom", "boom_ink_floor")
def boom_ink_floor():
    cv = tile(512)
    f = ink_shape(1.0, 77, arms=11, sats=16, splat=True)
    ink_draw(cv, lambda x, y: f(x * 1.02, y * 1.02) / 1.02, rim=0.02)
    return cv.rgba()


@asset("boom", "boom_ink_droplet")
def boom_ink_droplet():
    cv = tile(256, 128)  # x -0.5..0.5, y -1..1 ; head at the top
    f = smooth_union([sd_circle(0, -0.58, 0.3), sd_taper((0, -0.5), (0, 0.9), 0.22, 0.02)], 0.06)
    d = f(cv.x, cv.y)
    cv.fill(d - 0.045, PAPER)
    cv.fill(d, INK)
    cv.fill(np.maximum(d, -f(cv.x + 0.06, cv.y + 0.03)), INK2)
    cv.fill(sd_ellipse(-0.1, -0.66, 0.07, 0.11, 0.4)(cv.x, cv.y), PAPER)
    return cv.rgba()


@asset("boom", "boom_peony_burst")
def boom_peony_burst():
    return sheet(16, 4, 256, lambda cv, f, t: peony_tile(cv, t, 7, peony_scheme_violet))


def trailing_star(h, w, head, band1, band2, tail_c, seed, glint=True):
    """A velocity-aligned star: a hard-banded head at the top, a tapered banded tail and detached sparkles below."""
    sc = h / w
    cv = tile(h, w, scale=sc)  # x -1..1 across, y -sc..sc along
    top = -sc + 0.95
    bot = sc - 0.15
    x, y = cv.x, cv.y
    cv.halo(sd_taper((0, top), (0, bot), 0.5, 0.0)(x, y), tail_c, 0.12, 0.3)
    cv.fill(sd_taper((0, top), (0, bot), 0.42, 0.0)(x, y), tail_c)
    cv.fill(sd_taper((0, top), (0, bot * 0.7 + top * 0.3), 0.36, 0.0)(x, y), band2)
    cv.fill(sd_taper((0, top), (0, bot * 0.4 + top * 0.6), 0.28, 0.0)(x, y), band1)
    rng = np.random.default_rng(seed)
    for k in range(5):
        yy = top + (bot - top) * (0.55 + 0.1 * k)
        xx = rng.uniform(-0.35, 0.35)
        rr = 0.12 * (1 - 0.15 * k)
        glow_dot(cv, xx, yy + 0.25, rr, WHITE, band1, tail_c)
    glow_dot(cv, 0, top, 0.62, WHITE, band1, head, head, 0.35, 0.4)
    if glint:
        twinkle(cv, 0, top, 0.98, 0.1, WHITE, ang=0.0)
    return cv.rgba()


@asset("boom", "boom_peony_star")
def boom_peony_star():
    return trailing_star(512, 128, MAGENTA, SPARK, PINK, MEGA, 9)


def pixel_upscale(idx, palette, scale):
    """Index image (0 = transparent) → RGBA, nearest-neighbour upscaled (crisp 8-bit pixels)."""
    pal = np.array([[0, 0, 0, 0]] + [list(c) + [1.0] for c in palette], float)
    img = pal[idx]
    return np.kron(img, np.ones((scale, scale, 1)))


def outline_idx(idx, ink_index):
    """Mark every empty pixel 8-neighbouring a filled one with the ink index."""
    m = idx > 0
    pad = np.pad(m, 1)
    nb = np.zeros_like(m)
    h, w = m.shape
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nb |= pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
    out = idx.copy()
    out[nb & ~m] = ink_index
    return out


@asset("boom", "boom_pixel_cube")
def boom_pixel_cube():
    g = 32
    yy, xx = np.mgrid[0:g, 0:g] + 0.5
    c = (16, 16.5)
    s = 10.5
    top = [(c[0], c[1] - s), (c[0] + s * 0.95, c[1] - s / 2), (c[0], c[1]), (c[0] - s * 0.95, c[1] - s / 2)]
    left = [(c[0] - s * 0.95, c[1] - s / 2), (c[0], c[1]), (c[0], c[1] + s), (c[0] - s * 0.95, c[1] + s / 2)]
    right = [(c[0], c[1]), (c[0] + s * 0.95, c[1] - s / 2), (c[0] + s * 0.95, c[1] + s / 2), (c[0], c[1] + s)]
    idx = np.zeros((g, g), int)
    idx[inside_poly(xx, yy, right)] = 3
    idx[inside_poly(xx, yy, left)] = 2
    idx[inside_poly(xx, yy, top)] = 1
    # 8-bit highlight pixels on the top face's front corner and the left edge
    idx[(idx == 1) & (np.abs(xx - (c[0] - s * 0.55)) < 1.6) & (np.abs(yy - (c[1] - s * 0.5)) < 1.1)] = 4
    idx = outline_idx(idx, 5)
    # greyscale (the emitter tints it): top / left / right / highlight / ink
    pal = [np.array([0.94] * 3), np.array([0.74] * 3), np.array([0.52] * 3), WHITE, INK]
    return pixel_upscale(idx, pal, 8)


@asset("boom", "boom_pixel_ring")
def boom_pixel_ring():
    g = 64
    yy, xx = np.mgrid[0:g, 0:g] + 0.5
    r = np.hypot(xx - 32, yy - 32)
    a = np.arctan2(yy - 32, xx - 32)
    dash = (np.floor((a + math.pi) / (2 * math.pi) * 16) % 2) == 0
    idx = np.zeros((g, g), int)
    ring = (r > 25.5) & (r < 30.0)
    idx[ring & dash] = 1
    idx[(r > 25.5) & (r < 27.2) & dash] = 2
    # small plus-shaped pixel sparks in the gaps
    for k in range(8):
        ang = (k + 0.5) * 2 * math.pi / 8 + math.pi / 16
        px_, py_ = int(32 + math.cos(ang) * 22), int(32 + math.sin(ang) * 22)
        idx[py_, px_ - 1:px_ + 2] = 1
        idx[py_ - 1:py_ + 2, px_] = 1
    idx = outline_idx(idx, 3)
    return pixel_upscale(idx, [WHITE, SPARK, INK], 8)


@asset("boom", "boom_pixel_pop")
def boom_pixel_pop():
    g = 32
    pal = [WHITE, SPARK, FUSE, MEGA, INK]

    def fn_idx(f, t):
        yy, xx = np.mgrid[0:g, 0:g] + 0.5
        dx, dy = xx - 16, yy - 16
        l1 = np.abs(dx) + np.abs(dy)
        linf = np.maximum(np.abs(dx), np.abs(dy))
        idx = np.zeros((g, g), int)
        if f <= 4:
            r = 3 + f * 2.6
            shape_ = (l1 < r) | ((np.minimum(np.abs(dx), np.abs(dy)) < 1.1) & (linf < r * 1.25))
            idx[shape_] = 3
            idx[shape_ & (l1 < r * 0.75)] = 2
            idx[shape_ & (l1 < r * 0.45)] = 1
            if f >= 2:
                diag = (np.abs(np.abs(dx) - np.abs(dy)) < 1.1) & (linf < r * 0.85)
                idx[diag & (idx == 0)] = 4
        elif f <= 9:
            k = (f - 5) / 4
            r_out = 12 + k * 2.5
            r_in = 4 + k * 8
            ring = (l1 < r_out) & (l1 > r_in)
            idx[ring] = 4 if k > 0.5 else 3
            idx[ring & (l1 < r_in + 2.2)] = 2
            idx[ring & (l1 > r_out - 1.6)] = 1 if k < 0.5 else 3
        else:
            k = (f - 10) / 5
            for i in range(8):
                ang = i * math.pi / 4
                rr = 13 + k * 2.5
                cx, cy = 16 + math.cos(ang) * rr, 16 + math.sin(ang) * rr
                size = 2.2 * (1 - k * 0.7)
                blink = (f + i) % 2 == 0 or k < 0.3
                if blink and size > 0.4:
                    m = (np.abs(xx - cx) < size) & (np.abs(yy - cy) < size)
                    idx[m] = [1, 2, 3, 4][i % 4]
        return outline_idx(idx, 5)

    out = np.zeros((1024, 1024, 4))
    for f in range(16):
        img = pixel_upscale(fn_idx(f, f / 15), pal, 8)
        r, c = f // 4, f % 4
        out[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256] = img
    return out


def ice_shard(cv, cx, cy, ln, wd, ang, ow=0.045):
    """A faceted ice crystal pointing along ang (light left facet, mid right facet, ridge, Ice-Ink outline)."""
    def local(x, y):
        return rot(x - cx, y - cy, ang)

    pts = [(0, -ln), (wd, -ln * 0.42), (wd * 0.85, ln * 0.62), (0, ln), (-wd * 0.85, ln * 0.62), (-wd, -ln * 0.42)]
    fp = sd_poly(pts, 0.01)

    def f(x, y):
        return fp(*local(x, y))

    x, y = cv.x, cv.y
    d = f(x, y)
    u, v = local(x, y)
    cv.fill(d - ow, ICE_INK)
    cv.fill(d, ICE_MID)
    ridge = u - (0.12 * wd) * (v / ln)
    cv.fill(np.maximum(d, ridge), ICE_HI)  # the lit left facet
    cv.fill(np.maximum(d, np.maximum(-ridge, -(v + ln * 0.42) * 0.6 - 0.0)), ICE)  # the top-right facet
    cv.fill(np.maximum(d, np.maximum(-ridge, v - ln * 0.55)), ICE_LO)  # the shadowed bottom-right
    cv.fill(np.maximum(np.abs(ridge) - 0.008, d + 0.02), ICE_INK, 0.55)
    return d


@asset("boom", "boom_frost_shard")
def boom_frost_shard():
    cv = tile(256)
    ice_shard(cv, 0.0, 0.02, 0.9, 0.3, 0.12, ow=0.055)
    twinkle(cv, -0.12, -0.62, 0.3, 0.045, WHITE, ang=0.2)
    return cv.rgba()


@asset("boom", "boom_frost_ring")
def boom_frost_ring():
    cv = tile(512)
    x, y = cv.x, cv.y
    rng = np.random.default_rng(23)
    r = np.hypot(x, y)
    # the frozen floor inside: a pale sheen with fern-crack lines
    disc = r - 0.7
    cv.fill(disc, ICE, 0.32)
    cracks = np.full(x.shape, 9.0)
    for k in range(9):
        a = k * 2 * math.pi / 9 + rng.uniform(-0.2, 0.2)
        pts = [(math.cos(a) * 0.08, math.sin(a) * 0.08)]
        ang = a
        for _ in range(7):
            ang += rng.normal(0, 0.35)
            px_, py_ = pts[-1]
            pts.append((px_ + math.cos(ang) * 0.085, py_ + math.sin(ang) * 0.085))
        cracks = np.minimum(cracks, poly_dist(x, y, pts))
        for j in (2, 4):  # fern branches
            bx, by = pts[j]
            for sgn in (-1, 1):
                ba = ang + sgn * 0.8
                cracks = np.minimum(cracks, seg_dist(x, y, (bx, by), (bx + math.cos(ba) * 0.09, by + math.sin(ba) * 0.09)))
    cv.fill(np.maximum(cracks - 0.006, disc), ICE_HI, 0.7)
    # crystals pointing out of the ring, and smaller ones pointing in
    n = 26
    for k in range(n):
        a = k * 2 * math.pi / n + rng.uniform(-0.06, 0.06)
        big = k % 2 == 0
        ln = rng.uniform(0.1, 0.15) if big else rng.uniform(0.06, 0.09)
        rr = 0.74 + ln * 0.8
        ice_shard(cv, math.cos(a) * rr, math.sin(a) * rr, ln, ln * 0.33, a + math.pi / 2, ow=0.018)
    for k in range(18):
        a = (k + 0.5) * 2 * math.pi / 18
        ln = 0.06
        rr = 0.66 - ln * 0.6
        ice_shard(cv, math.cos(a) * rr, math.sin(a) * rr, ln, ln * 0.35, a - math.pi / 2, ow=0.015)
    band = np.abs(r - 0.7) - 0.04
    cv.fill(band - 0.018, ICE_INK)
    cv.fill(band, ICE)
    cv.fill(np.maximum(band, (r - 0.7) + 0.012), ICE_HI)
    return cv.rgba()


@asset("boom", "boom_frost_flake")
def boom_frost_flake():
    cv = tile(128)
    x, y = cv.x, cv.y
    parts = []
    for k in range(6):
        a = k * math.pi / 3 - math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        parts.append(sd_seg((0, 0), (ca * 0.78, sa * 0.78), 0.07))
        for t_, l_ in ((0.42, 0.26), (0.66, 0.17)):
            bx, by = ca * 0.8 * t_, sa * 0.8 * t_
            for sgn in (-1, 1):
                b = a + sgn * 0.95
                parts.append(sd_seg((bx, by), (bx + math.cos(b) * l_, by + math.sin(b) * l_), 0.055))
    f = union(*parts, sd_poly(star_pts(0, 0, 6, 0.22, 0.14, a0=-math.pi / 2)))
    d = f(x, y)
    cv.fill(d - 0.07, ICE_INK)
    cv.fill(d, ICE_HI)
    cv.fill(np.maximum(d, -f(x + 0.05, y + 0.05)), ICE)
    return cv.rgba()


@asset("boom", "boom_blackhole_ring")
def boom_blackhole_ring():
    cv = tile(512)
    x, y = cv.x, cv.y
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    cv.halo(r - 0.95, MEGA, 0.08, 0.0)
    cv.over(MEGA, np.clip(np.exp(-((r - 0.62) / 0.3) ** 2) * 0.28, 0, 1))
    beam = 0.5 + 0.5 * np.cos(a + 2.4)  # one side of the lensed light is brighter (Doppler)
    for rad, w, col, colhi in ((0.9, 0.012, LAVENDER, WHITE), (0.77, 0.022, EPIC, LAVENDER), (0.6, 0.034, MEGA, MAGENTA)):
        rr = r / (1 + 0.05 * np.cos(2 * a))
        band = np.abs(rr - rad) - w * (0.6 + 0.6 * beam)
        cv.fill(band, col)
        cv.fill(np.maximum(band + w * 0.5, 0.55 - beam), colhi)
    # the accretion disk: an ellipse band, its back half hidden by the hole, its front half over it
    e = np.hypot(x / 0.86, y / 0.2)
    disk = np.abs(e - 1) * 0.2 - 0.022
    back = y < 0
    cv.fill(np.maximum(disk, 0.5 - back * 1.0), MAGENTA)
    cv.fill(np.maximum(disk + 0.012, 0.5 - back * 1.0), PINK)
    # the photon ring and the event horizon
    cv.fill(np.abs(r - 0.355) - 0.03, MAGENTA)
    cv.fill(np.abs(r - 0.35) - 0.014, WHITE)
    cv.fill(r - 0.33, INK)
    cv.fill(np.maximum(r - 0.33, -(r - 0.28)), INK2)
    front = y >= 0
    cv.fill(np.maximum(disk, 0.5 - front * 1.0), MAGENTA)
    cv.fill(np.maximum(disk + 0.011, 0.5 - front * 1.0), PINK)
    cv.fill(np.maximum(disk + 0.019, 0.5 - front * 1.0), WHITE)
    return cv.rgba()


@asset("boom", "boom_blackhole_swirl")
def boom_blackhole_swirl():
    def fn(cv, f, t):
        x, y = cv.x, cv.y
        r = np.hypot(x, y) + 1e-6
        a = np.arctan2(y, x)
        reach = 0.95 * (1 - t ** 1.6) + 0.04
        spin = t * 5.0
        b = 0.32
        psi = a + np.log(r / 0.3) / b + spin
        arm = np.cos(3 * psi)
        env = np.clip(1 - r / reach, 0, 1) ** 0.6 * np.clip(r / 0.06, 0, 1)
        k = arm * (0.35 + 0.65 * env)
        live = r < reach
        if reach > 0.08:
            cv.over(MEGA, np.clip(np.exp(-(r / (reach * 0.7)) ** 2) * 0.25, 0, 1))
            cv.fill(np.where(live, 0.3 - k, 1.0) * 0.03, INK2, 0.6)
            cv.fill(np.where(live, 0.45 - k, 1.0) * 0.03, MEGA)
            cv.fill(np.where(live, 0.66 - k, 1.0) * 0.03, MAGENTA)
            cv.fill(np.where(live, 0.86 - k, 1.0) * 0.03, WHITE)
            # debris dashes being pulled in along the arms
            rng = np.random.default_rng(3)
            for i in range(14):
                th0 = rng.uniform(0, 2 * math.pi)
                rr0 = rng.uniform(0.45, 0.8) * reach
                th = th0 + spin * 1.3
                p1 = (math.cos(th) * rr0, math.sin(th) * rr0)
                p2 = (math.cos(th - 0.25) * rr0 * 1.12, math.sin(th - 0.25) * rr0 * 1.12)
                cv.fill(sd_taper(p1, p2, 0.018, 0.0)(x, y), LAVENDER)
            cv.fill(r - 0.12 * (1 - t), INK)
        if t > 0.75:
            k2 = (t - 0.75) / 0.25
            glow_dot(cv, 0, 0, 0.05 + 0.1 * k2, WHITE, MAGENTA, MEGA, MEGA, 0.12, 0.5)

    return sheet(16, 4, 256, fn)


@asset("boom", "boom_champagne_foil")
def boom_champagne_foil():
    kinds = ["strip", "square", "diamond", "strip", "circle", "strip", "square", "tri",
             "strip", "diamond", "square", "strip", "circle", "tri", "strip", "square"]
    rng = np.random.default_rng(61)
    champ = shade(GOLD, 0.45)

    def fn(cv, f, t):
        col = GOLD if f % 4 != 3 else champ
        paper_piece(cv, kinds[f], col, rng.uniform(-1.3, 1.3), [1.0, 0.72, 0.5, 0.85][f % 4], 600 + f, foil=True)

    return sheet(16, 4, 256, fn)


def bubble(cv, fill_col, fill_a, rim_col, line_col, glint=False):
    x, y = cv.x, cv.y
    r = np.hypot(x, y)
    cv.fill(r - 0.8, fill_col, fill_a)
    cv.fill(np.abs(r - 0.78) - 0.035, line_col, 0.85)
    cv.fill(np.abs(r - 0.76) - 0.03, rim_col)
    # the window highlight (top-left crescent) and a dot, the warm reflection bottom-right
    cres = np.maximum(-sd_circle(0.1, 0.1, 0.6)(x, y), sd_circle(0, 0, 0.66)(x, y))
    cv.fill(np.maximum(cres, (x + y) * 0.5 + 0.12), WHITE, 0.95)
    cv.fill(sd_circle(-0.12, -0.5, 0.06)(x, y), WHITE)
    cres2 = np.maximum(-sd_circle(-0.07, -0.07, 0.62)(x, y), sd_circle(0, 0, 0.66)(x, y))
    cv.fill(np.maximum(cres2, -(x + y) * 0.5 + 0.22), rim_col, 0.85)
    if glint:
        twinkle(cv, 0.48, -0.5, 0.36, 0.055, WHITE, ang=0.0)


@asset("boom", "boom_champagne_bubble")
def boom_champagne_bubble():
    cv = tile(256)
    bubble(cv, GOLD_HI, 0.18, GOLD_HI, BRASS)
    return cv.rgba()


@asset("boom", "boom_champagne_cork")
def boom_champagne_cork():
    cv = tile(512)
    x, y = cv.x, cv.y
    n = 10
    rng = np.random.default_rng(8)

    def burst(scale, ri):
        return sd_poly(star_pts(0, 0, n, lambda k: scale * (0.95 if (k // 2) % 2 == 0 else 0.7), ri * scale), 0.01)

    f = burst(1.0, 0.42)
    cv.halo(f(x, y), GOLD, 0.06, 0.35)
    cv.fill(f(x, y), GOLD)
    cv.fill(burst(0.72, 0.5)(x, y), SPARK)
    cv.fill(sd_circle(0, 0, 0.3)(x, y), GOLD_HI)
    cv.fill(sd_circle(0, 0, 0.2)(x, y), WHITE)
    # fizz: bubbles flung out between the points
    for k in range(n):
        a = (k + 0.5) * 2 * math.pi / n - math.pi / 2
        for j, (rr, s) in enumerate(((0.62, 0.045), (0.78, 0.035), (0.9, 0.025))):
            jitter = rng.uniform(-0.08, 0.08)
            cx, cy = math.cos(a + jitter) * rr, math.sin(a + jitter) * rr
            d = np.hypot(x - cx, y - cy)
            cv.fill(np.abs(d - s) - 0.009, GOLD_HI)
            cv.fill(d - s * 0.4, WHITE, 0.0 if j else 1.0)
    return cv.rgba()


# ═════════════════════════════════════════════ FUSE SPARKS ══════════════════════════════════════════════════════════
@asset("spark", "spark_sparkler_star")
def spark_sparkler_star():
    cv = tile(256)
    x, y = cv.x, cv.y
    rng = np.random.default_rng(31)
    cv.over(SPARK, np.clip(np.exp(-(np.hypot(x, y) / 0.35) ** 2) * 0.45, 0, 1))
    n = 22
    for k in range(n):
        a = k * 2 * math.pi / n + rng.uniform(-0.08, 0.08)
        ln = rng.uniform(0.55, 0.97) if k % 2 == 0 else rng.uniform(0.3, 0.55)
        tip = (math.cos(a) * ln, math.sin(a) * ln)
        cv.fill(sd_taper((0, 0), tip, 0.03, 0.002)(x, y), EMBER)
        cv.fill(sd_taper((0, 0), tip, 0.016, 0.0)(x, y), SPARK)
        if k % 3 == 0:  # the sparkler's forked tips
            fx_, fy_ = math.cos(a) * ln * 0.78, math.sin(a) * ln * 0.78
            for sgn in (-1, 1):
                b = a + sgn * 0.5
                cv.fill(sd_taper((fx_, fy_), (fx_ + math.cos(b) * 0.14, fy_ + math.sin(b) * 0.14), 0.011, 0.0)(x, y), SPARK)
    glow_dot(cv, 0, 0, 0.2, WHITE, SPARK, EMBER)
    return cv.rgba()


@asset("spark", "spark_sparkler_needle")
def spark_sparkler_needle():
    cv = tile(256, 64)  # x -0.25..0.25, y -1..1 ; head at the top
    x, y = cv.x, cv.y
    cv.fill(sd_taper((0, -0.8), (0, 0.95), 0.05, 0.0)(x, y), EMBER)
    cv.fill(sd_taper((0, -0.8), (0, 0.6), 0.025, 0.0)(x, y), SPARK)
    for sgn in (-1, 1):
        cv.fill(sd_taper((0, -0.78), (sgn * 0.18, -0.98), 0.018, 0.0)(x, y), SPARK)
    glow_dot(cv, 0, -0.8, 0.075, WHITE, SPARK, EMBER)
    return cv.rgba()


@asset("spark", "spark_ember_dot")
def spark_ember_dot():
    cv = tile(128)
    x, y = cv.x, cv.y
    a = np.arctan2(y, x)
    r = np.hypot(x, y) / (1 + 0.07 * np.sin(5 * a + 0.6))
    cv.over(EMBER, np.clip(np.exp(-(r / 0.62) ** 2) * 0.55, 0, 1))
    cv.fill(r - 0.42, FUSE)
    cv.fill(r - 0.32, EMBER)
    cv.fill(r - 0.2, SPARK)
    cv.fill(np.hypot(x + 0.06, y + 0.06) - 0.09, PAPER)
    return cv.rgba()


def bolt(rng, a, b, depth, rough):
    pts = [a, b]
    for _ in range(depth):
        nxt = [pts[0]]
        for p, q in zip(pts[:-1], pts[1:]):
            mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
            dx, dy = q[0] - p[0], q[1] - p[1]
            ln = math.hypot(dx, dy)
            off = rng.normal(0, rough) * ln
            nxt += [(mx - dy / ln * off, my + dx / ln * off), q]
        pts = nxt
    return pts


@asset("spark", "spark_electric_arc")
def spark_electric_arc():
    def fn(cv, f, t):
        x, y = cv.x, cv.y
        rng = np.random.default_rng(900 + f * 13)
        d = np.full(x.shape, 9.0)
        dthin = np.full(x.shape, 9.0)
        for k in range(3):
            a = (k + rng.uniform(-0.25, 0.25)) * 2 * math.pi / 3 + f * 0.9
            ln = rng.uniform(0.72, 0.92)
            pts = bolt(rng, (0, 0), (math.cos(a) * ln, math.sin(a) * ln), 3, 0.32)
            d = np.minimum(d, poly_dist(x, y, pts))
            j = rng.integers(2, 6)
            bx, by = pts[j]
            ba = a + rng.choice([-1, 1]) * rng.uniform(0.5, 0.9)
            bl = rng.uniform(0.2, 0.35)
            br = bolt(rng, (bx, by), (bx + math.cos(ba) * bl, by + math.sin(ba) * bl), 2, 0.3)
            dthin = np.minimum(dthin, poly_dist(x, y, br))
        cv.halo(d - 0.07, ELEC_DEEP, 0.08, 0.35)
        cv.fill(dthin - 0.05, ELEC_DEEP)
        cv.fill(d - 0.08, ELEC_DEEP)
        cv.fill(dthin - 0.03, ELEC)
        cv.fill(d - 0.052, ELEC)
        cv.fill(dthin - 0.012, WHITE)
        cv.fill(d - 0.024, WHITE)
        glow_dot(cv, 0, 0, 0.16, WHITE, ELEC, ELEC_DEEP, ELEC_DEEP, 0.12, 0.4)

    return sheet(4, 2, 256, fn)


PASTELS = [hexc("#FFB3DA"), hexc("#CDB6FF"), hexc("#A6F0CE"), hexc("#FFE79E")]


@asset("spark", "spark_pixie_glitter")
def spark_pixie_glitter():
    def fn(cv, f, t):
        x, y = cv.x, cv.y
        col = PASTELS[f]
        deep = shade(col, -0.35)
        cv.over(col, np.clip(np.exp(-(np.hypot(x, y) / 0.5) ** 2) * 0.4, 0, 1))
        big = sd_poly(star_pts(0, 0, 4, 0.86, 0.17), 0.01)
        small = sd_poly(star_pts(0, 0, 4, 0.48, 0.12, a0=-math.pi / 4), 0.01)
        cv.fill(small(x, y) - 0.03, deep)
        cv.fill(small(x, y), col)
        cv.fill(big(x, y) - 0.03, deep)
        cv.fill(big(x, y), col)
        cv.fill(sd_poly(star_pts(0, 0, 4, 0.55, 0.1), 0.01)(x, y), WHITE)
        cv.fill(sd_circle(0, 0, 0.12)(x, y), WHITE)
        rng = np.random.default_rng(70 + f)
        for _ in range(4):  # glitter specks
            a, rr = rng.uniform(0, 2 * math.pi), rng.uniform(0.5, 0.8)
            cv.fill(sd_circle(math.cos(a + 0.4) * rr, math.sin(a + 0.4) * rr, 0.045)(x, y) - 0.02, deep)
            cv.fill(sd_circle(math.cos(a + 0.4) * rr, math.sin(a + 0.4) * rr, 0.045)(x, y), WHITE)

    return sheet(4, 2, 256, fn)


@asset("spark", "spark_plasma_ball")
def spark_plasma_ball():
    cv = tile(256)
    x, y = cv.x, cv.y
    r = np.hypot(x, y)
    rng = np.random.default_rng(44)
    cv.over(MAGENTA, np.clip(np.exp(-(r / 0.75) ** 2) * 0.5, 0, 1))
    wob = (fbm(x * 1.5, y * 1.5, 4, 9, 3) - 0.5) * 0.08
    cv.fill(r + wob - 0.66, MEGA)
    cv.fill(r + wob - 0.56, MAGENTA)
    cv.fill(r - 0.36, PINK)
    # filaments from the core to the shell
    for k in range(7):
        a = k * 2 * math.pi / 7 + rng.uniform(-0.3, 0.3)
        pts = bolt(rng, (0, 0), (math.cos(a) * 0.6, math.sin(a) * 0.6), 4, 0.18)
        dd = poly_dist(x, y, pts)
        cv.fill(dd - 0.026, shade(PINK, 0.4))
        cv.fill(dd - 0.011, WHITE)
        tx, ty = pts[-1]
        cv.fill(sd_circle(tx, ty, 0.045)(x, y), WHITE)
    cv.fill(r - 0.2, shade(PINK, 0.5))
    cv.fill(r - 0.12, WHITE)
    cv.fill(np.maximum(np.abs(r - 0.6) - 0.02, (x + y) + 0.25), shade(MAGENTA, 0.55))
    return cv.rgba()


@asset("spark", "spark_plasma_mote")
def spark_plasma_mote():
    cv = tile(128)
    x, y = cv.x, cv.y
    r = np.hypot(x, y)
    cv.over(MAGENTA, np.clip(np.exp(-(r / 0.55) ** 2) * 0.5, 0, 1))
    cv.fill(np.abs(r - 0.56) - 0.05, MEGA)
    cv.fill(np.abs(r - 0.56) - 0.022, shade(MAGENTA, 0.5))
    glow_dot(cv, 0, 0, 0.34, WHITE, PINK, MAGENTA)
    return cv.rgba()


@asset("spark", "spark_goldleaf_flake")
def spark_goldleaf_flake():
    base = [(0.0, -0.78), (0.2, -0.6), (0.42, -0.62), (0.5, -0.3), (0.7, -0.1), (0.55, 0.12), (0.62, 0.42),
            (0.3, 0.5), (0.12, 0.76), (-0.12, 0.55), (-0.42, 0.62), (-0.5, 0.3), (-0.72, 0.08), (-0.55, -0.2),
            (-0.6, -0.5), (-0.28, -0.52)]
    rng = np.random.default_rng(5)
    base = [(px_ * rng.uniform(0.9, 1.08), py_ * rng.uniform(0.9, 1.08)) for px_, py_ in base]

    def fn(cv, f, t):
        sx = [1.0, 0.62, 0.16, 0.66][f]
        ang = [0.2, 0.55, 0.9, 1.3][f]
        pts = []
        for px_, py_ in base:
            u, v = px_ * sx, py_
            c, s = math.cos(ang), math.sin(ang)
            pts.append((u * c - v * s, u * s + v * c))
        f_ = sd_poly(pts, 0.02)
        col = GOLD if f != 3 else shade(GOLD, -0.18)  # frame 3 shows the back face
        foil_fill(cv, f_, col, ang, 800 + f, 0.05, crinkle=2.2, freq=5.0, dark_at=-0.7, light_at=0.25)
        if f == 0:
            twinkle(cv, 0.3, -0.38, 0.3, 0.05, WHITE, ang=0.0)

    return sheet(4, 2, 256, fn)


@asset("spark", "spark_insignia_star")
def spark_insignia_star():
    cv = tile(256)
    x, y = cv.x, cv.y
    for k in range(5):  # needle rays between the points
        a = -math.pi / 2 + (k + 0.5) * 2 * math.pi / 5
        cv.fill(sd_taper((0, 0), (math.cos(a) * 0.95, math.sin(a) * 0.95), 0.05, 0.0)(x, y), SPARK)
    cv.over(FUSE, np.clip(np.exp(-(np.hypot(x, y) / 0.6) ** 2) * 0.3, 0, 1))
    f = sd_poly(star_pts(0, 0.04, 5, 0.66, 0.3), 0.05)
    toon(cv, f, FUSE, shade(FUSE, -0.25), EMBER, ow=0.06, sh=0.07, lw=0.05)
    cv.fill(sd_poly(star_pts(0, 0.04, 5, 0.34, 0.16), 0.03)(x, y), SPARK)
    cv.fill(sd_circle(-0.03, -0.0, 0.08)(x, y), WHITE)
    twinkle(cv, -0.1, -0.06, 0.2, 0.03, WHITE, ang=0.0)
    return cv.rgba()


# ═════════════════════════════════════════════ TRAILS ═══════════════════════════════════════════════════════════════
TW, TH = 512, 64


def trail_cv():
    """Trail canvas: X 0..16 along the strip (head at X = 0), Y -1..1 across it; 32 px per unit."""
    y, x = np.mgrid[0:TH, 0:TW].astype(np.float64)
    return Cv((x + 0.5) / 32, (y + 0.5) / 32 - 1, 1 / 32)


def trail_fade(cv, power=1.3, lead=0.25):
    """Alpha fades to 0 at the tail; a quarter-unit soft start at the head so the strip never shows a hard edge."""
    k = np.clip(1 - cv.x / 16, 0, 1) ** power * np.clip(cv.x / lead, 0, 1) ** 0.5
    cv.a = cv.a * k


@asset("trail", "trail_soot")
def trail_soot():
    cv = trail_cv()
    rng = np.random.default_rng(12)
    puffs = []
    xx = 0.3
    while xx < 16.5:
        p = xx / 16
        r = 0.42 + 0.34 * p
        puffs.append(sd_circle(xx, rng.uniform(-0.25, 0.25) * (0.3 + p), r))
        if rng.random() < 0.7:
            puffs.append(sd_circle(xx + r * 0.6, rng.uniform(-0.45, 0.45), r * 0.7))
        xx += r * (0.9 + 0.9 * p)
    f = smooth_union(puffs, 0.06)
    x, y = cv.x, cv.y
    d = f(x, y)
    cv.fill(d - 0.07, INK)
    cv.fill(d, hexc("#5A526A"))
    cv.fill(np.maximum(d, -f(x + 0.1, y + 0.18)), hexc("#383143"))
    cv.fill(np.maximum(d + 0.07, -f(x - 0.08, y - 0.16)), hexc("#8A8299"))
    trail_fade(cv, 1.1)
    return cv.rgba()


@asset("trail", "trail_streamers")
def trail_streamers():
    cv = trail_cv()
    x, y = cv.x, cv.y
    for i, (col, lam, ph, amp, tw) in enumerate(((MEGA, 5.2, 0.0, 0.5, 3.1), (SAFE, 6.1, 2.1, 0.45, 2.6), (SPARK, 4.6, 4.0, 0.55, 3.6))):
        yc = amp * np.sin(2 * math.pi * x / lam + ph)
        slope = amp * 2 * math.pi / lam * np.cos(2 * math.pi * x / lam + ph)
        dist = np.abs(y - yc) / np.sqrt(1 + slope ** 2)
        twist = np.cos(2 * math.pi * x / tw + i)
        hw = 0.07 + 0.17 * np.abs(twist)
        # the ribbons tear into pieces toward the tail
        tear = (x > 9) & (np.mod(x * 0.9 + i * 0.37, 1.0) < 0.12 + 0.05 * (x - 9))
        d = np.where(tear, 9.0, dist - hw)
        cv.fill(d - 0.06, INK)
        cv.fill(d, col)
        cv.fill(np.maximum(d, 0.5 - (twist < 0) * 1.0), shade(col, -0.3))
        cv.fill(np.maximum(d + 0.05, 0.5 - ((y < yc) & (twist >= 0)) * 1.0), shade(col, 0.45))
    trail_fade(cv, 1.2)
    return cv.rgba()


@asset("trail", "trail_sparkline")
def trail_sparkline():
    cv = trail_cv()
    x, y = cv.x, cv.y
    cv.fill(np.abs(y) - 0.045, GOLD, 0.65)
    xx = 0.45
    k = 0
    while xx < 16:
        p = xx / 16
        r = 0.4 * (1 - 0.6 * p)
        glow_dot(cv, xx, 0, r, WHITE, SPARK, GOLD, GOLD, r * 0.9, 0.35)
        if k % 3 == 0:
            twinkle(cv, xx, 0, r * 2.3, r * 0.22, WHITE, ang=0.0)
        xx += 0.95 * (1 - 0.35 * p)
        k += 1
    trail_fade(cv, 1.0)
    return cv.rgba()


@asset("trail", "trail_rocket")
def trail_rocket():
    cv = trail_cv()
    x, y = cv.x, cv.y
    wob = (fbm(x / 8 - 1, y * 0.25, 6, 3, 3) - 0.5) * 0.35
    s = np.clip(x / 5.5, 0, 1)
    hw = (0.3 + 0.62 * np.sin(math.pi * np.clip(s * 0.85 + 0.15, 0, 1)) ** 0.8) * (1 - s ** 3) + wob * s
    d = np.abs(y) - hw
    d = np.where(x > 5.5, 9.0, d)
    cv.fill(d - 0.06, INK)
    cv.fill(d, FUSE)
    for frac, end, col in ((0.72, 5.3, EMBER), (0.5, 4.6, SPARK), (0.26, 3.4, WHITE)):
        k = np.clip((end - x) / (end * 0.45), 0, 1) ** 0.5
        cv.fill(np.where(x < end, np.abs(y) - hw * frac * k, 9.0), col)
    rng = np.random.default_rng(17)
    for i in range(30):
        px_ = rng.uniform(4.2, 15.5)
        py_ = rng.uniform(-0.7, 0.7) * min(1, px_ / 7)
        p = px_ / 16
        rr = rng.uniform(0.09, 0.17) * (1.2 - p)
        if i % 3 == 0:
            twinkle(cv, px_, py_, rr * 2.4, rr * 0.3, SPARK, ang=0.0)
            glow_dot(cv, px_, py_, rr * 0.7, WHITE, SPARK, EMBER)
        else:
            glow_dot(cv, px_, py_, rr * 0.6, WHITE, SPARK, EMBER)
    trail_fade(cv, 1.0)
    return cv.rgba()


@asset("trail", "trail_comet")
def trail_comet():
    cv = trail_cv()
    x, y = cv.x, cv.y
    head = 0.75
    s = np.clip((x - head) / (16 - head), 0, 1)
    wob = (fbm(x / 8, y * 0.3, 8, 21, 3) - 0.5) * 0.2
    for wfrac, col in ((0.82, LAVENDER), (0.56, GOLD_HI), (0.3, WHITE)):
        hw = wfrac * (1 - s) ** 0.9 + wob * s
        cv.fill(np.where(x < head, 9.0, np.abs(y) - hw), col)
    rng = np.random.default_rng(40)
    for _ in range(70):
        px_ = rng.uniform(1.5, 15.5)
        sp = (px_ - head) / (16 - head)
        py_ = rng.uniform(-1, 1) * 0.9 * (1 - sp * 0.6)
        rr = rng.uniform(0.03, 0.07)
        cv.fill(sd_circle(px_, py_, rr)(x, y), WHITE if rng.random() < 0.5 else GOLD_HI)
    glow_dot(cv, head, 0, 0.62, WHITE, GOLD_HI, LAVENDER, LAVENDER, 0.3, 0.4)
    twinkle(cv, head, 0, 0.98, 0.09, WHITE, ang=0.0)
    trail_fade(cv, 1.1, lead=0.05)
    return cv.rgba()


@asset("trail", "trail_neon")
def trail_neon():
    cv = trail_cv()
    x, y = cv.x, cv.y
    pts = []
    for i in range(14):
        pts.append((0.3 + i * 1.2, 0.45 * (1 if i % 2 else -1)))
    for _ in range(3):  # Chaikin rounds the bends like bent glass
        new = [pts[0]]
        for p, q in zip(pts[:-1], pts[1:]):
            new += [(0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]), (0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1])]
        new.append(pts[-1])
        pts = new
    d, sp, _ = sd_path(pts, lambda s: 0.0)(x, y)
    pos = sp * (pts[-1][0] - pts[0][0]) + pts[0][0]
    # flicker: a few dead sections (unlit glass, no glow) and electrode caps either side of them
    dead = ((pos > 6.1) & (pos < 7.0)) | ((pos > 10.4) & (pos < 11.6)) | ((pos > 13.3) & (pos < 13.9))
    lit = ~dead
    neon, glass_off = MAGENTA, hexc("#6E4A78")
    cv.over(neon, np.exp(-np.maximum(d - 0.15, 0) / 0.18) * 0.45 * lit)
    cv.fill(np.where(lit, d - 0.17, 9.0), shade(neon, -0.15))
    cv.fill(np.where(lit, d - 0.12, 9.0), shade(neon, 0.25))
    cv.fill(np.where(lit, d - 0.05, 9.0), WHITE)
    cv.fill(np.where(dead, d - 0.15, 9.0), INK)
    cv.fill(np.where(dead, d - 0.11, 9.0), glass_off)
    cv.fill(np.where(dead, np.maximum(d - 0.035, 0.0), 9.0), hexc("#A88AB4"))
    for e in (6.1, 7.0, 10.4, 11.6, 13.3, 13.9):
        cap = (np.abs(pos - e) < 0.09) & (d < 0.2)
        cv.fill(np.where(cap, d - 0.19, 9.0), INK)
    trail_fade(cv, 1.0)
    return cv.rgba()


@asset("trail", "trail_aurora")
def trail_aurora():
    cv = trail_cv()
    x, y = cv.x, cv.y
    for layer, (lo, hi, ph, k) in enumerate(((SAFE, MEGA, 0.0, 0.95), (hexc("#7CF2B0"), PINK, 2.0, 0.7))):
        # a curtain: a bright, wavy lower hem and folds rising from it, posterised into three tone steps
        edge = 0.55 - 0.3 * layer + 0.22 * np.sin(x * 0.85 + ph) + 0.08 * np.sin(x * 2.1 + ph * 2)
        fold = 0.5 + 0.5 * np.sin(x * 3.2 + 1.8 * np.sin(x * 0.7 + ph))
        height = 0.7 + 0.55 * fold
        v = (edge - y) / height  # 0 at the hem .. 1 at the faint top
        hem = cover(y - edge, cv.px)  # above the hem
        steps = (0.95 * cover(v - 0.18, cv.px / height) + 0.6 * cover(v - 0.5, cv.px / height)
                 + 0.3 * cover(v - 1.0, cv.px / height)) / 1.85
        col = np.where((v < 0.18)[..., None], shade(lo, 0.5), np.where((v < 0.5)[..., None], lo, hi))
        cv.over(col, steps * hem * k * (0.75 + 0.25 * fold))
    trail_fade(cv, 1.2)
    return cv.rgba()


@asset("trail", "trail_victorylap")
def trail_victorylap():
    cv = trail_cv()
    x, y = cv.x, cv.y
    yc = 0.18 * np.sin(2 * math.pi * x / 4.0)
    slope = 0.18 * 2 * math.pi / 4.0 * np.cos(2 * math.pi * x / 4.0)
    hw = 0.74 * (1 - 0.2 * np.clip((x - 12) / 4, 0, 1))
    v = (y - yc) / hw
    d = (np.abs(y - yc) - hw) / np.sqrt(1 + slope ** 2)
    cv.fill(d - 0.06, INK)
    sq = 0.36
    chk = (np.floor(x / sq) + np.floor((v * hw + 0.72) / sq)) % 2 == 0
    col = np.where(chk[..., None], PAPER, INK2)
    lit = np.clip(0.5 + slope * 1.5, 0, 1)
    col = np.where((lit < 0.35)[..., None], col * 0.72, col)
    cv.over(col, cover(d, cv.px))
    trim = np.abs(v) > 0.8
    tcol = np.where((lit < 0.35)[..., None], GOLD_LO, np.where((lit > 0.75)[..., None], GOLD_HI, GOLD))
    cv.over(tcol, cover(d, cv.px) * trim)
    cv.fill(np.maximum(d + 0.0, np.abs(np.abs(v) - 0.8) * hw - 0.02), INK)
    trail_fade(cv, 1.1)
    return cv.rgba()


# ═════════════════════════════════════════════ VICTORY BOOMS ════════════════════════════════════════════════════════
@asset("victory", "victory_confetti_pieces")
def victory_confetti_pieces():
    kinds = ["star", "curl", "circle", "strip", "heart", "square", "star", "strip",
             "curl", "diamond", "circle", "star", "strip", "tri", "curl", "square"]
    cols = [GOLD, PINK, SAFE, MEGA, SPARK, PAPER, FUSE, GOLD]
    rng = np.random.default_rng(220)
    spec = []
    for i, k in enumerate(kinds):
        spec.append((k, cols[(i * 3) % len(cols)], rng.uniform(-1.0, 1.0), [1.0, 0.75, 0.55, 0.9][i % 4] if k != "curl" else 1.0))
    return confetti_sheet(spec, 2000)


@asset("victory", "victory_fountain_spark")
def victory_fountain_spark():
    return trailing_star(512, 128, GOLD, SPARK, GOLD, FUSE, 19)


@asset("victory", "victory_fountain_glint")
def victory_fountain_glint():
    cv = tile(256)
    x, y = cv.x, cv.y
    cv.over(GOLD, np.clip(np.exp(-(np.hypot(x, y) / 0.45) ** 2) * 0.5, 0, 1))
    small = sd_poly(star_pts(0, 0, 4, 0.5, 0.1, a0=-math.pi / 4), 0.005)
    big = sd_poly(star_pts(0, 0, 4, 0.95, 0.13), 0.005)
    cv.fill(small(x, y), GOLD)
    cv.fill(big(x, y), GOLD)
    cv.fill(sd_poly(star_pts(0, 0, 4, 0.7, 0.08), 0.005)(x, y), SPARK)
    glow_dot(cv, 0, 0, 0.2, WHITE, SPARK, GOLD)
    return cv.rgba()


@asset("victory", "victory_finale_peony")
def victory_finale_peony():
    return sheet(16, 4, 256, lambda cv, f, t: peony_tile(cv, t, 15, peony_scheme_multi))


@asset("victory", "victory_dragon_head")
def victory_dragon_head():
    cv = tile(512)
    x, y = cv.x, cv.y
    rng = np.random.default_rng(88)
    # the mane: a ring of flame tufts behind the head, sparks at the tips
    tufts = []
    for k in range(13):
        a = math.pi * (1.05 + k / 12 * 0.9) + (k % 2) * 0.02
        a = -math.pi / 2 + (k - 6) * 0.42
        ln = 0.88 if k % 2 == 0 else 0.74
        tip = (math.cos(a) * ln, math.sin(a) * ln * 0.92 + 0.04)
        tufts.append(sd_taper((0, 0.08), tip, 0.2, 0.025))
    mane = union(*tufts)
    toon(cv, mane, FUSE, shade(FUSE, -0.28), EMBER, ow=0.035, sh=0.05, lw=0.04)
    for k in range(13):
        a = -math.pi / 2 + (k - 6) * 0.42
        ln = 0.88 if k % 2 == 0 else 0.74
        glow_dot(cv, math.cos(a) * (ln + 0.03), math.sin(a) * (ln + 0.03) * 0.92 + 0.04, 0.035, WHITE, SPARK, EMBER)
    # horns: curved antlers sweeping up and out
    for sgn in (-1, 1):
        pts = []
        for i in range(24):
            s = i / 23
            pts.append((sgn * (0.2 + 0.3 * s + 0.1 * s * s), -0.32 - 0.42 * s + 0.12 * s * s))
        horn = sd_path(pts, lambda s: 0.075 - 0.05 * s)
        hd, _, _ = horn(x, y)
        cv.fill(hd - 0.035, INK)
        cv.fill(hd, GOLD)
        cv.fill(hd + 0.03, GOLD_HI, 1.0)
        bx, by = pts[11]
        branch = sd_taper((bx, by), (bx + sgn * 0.16, by - 0.02), 0.04, 0.012)
        cv.fill(branch(x, y) - 0.035, INK)
        cv.fill(branch(x, y), GOLD)
    # the head: a wide rounded lantern shape with paper ribs
    head = smooth_union([sd_ellipse(0, -0.06, 0.44, 0.36), sd_ellipse(0, 0.26, 0.33, 0.25)], 0.12)
    d = toon(cv, head, GOLD, shade(GOLD, -0.28), GOLD_HI, ow=0.045, sh=0.07, lw=0.05)
    for k in range(5):  # paper lantern ribs following the head's curve
        yy0 = -0.3 + k * 0.13
        rib = np.abs(y - (yy0 + 0.12 * (x / 0.44) ** 2)) - 0.008
        cv.fill(np.maximum(rib, d + 0.05), shade(GOLD, -0.35), 0.7)
    # brows (Safe green, flame-shaped) and the big eyes
    for sgn in (-1, 1):
        brow = sd_poly([(sgn * 0.06, -0.2), (sgn * 0.36, -0.36), (sgn * 0.44, -0.24), (sgn * 0.3, -0.18)], 0.03)
        toon(cv, brow, SAFE, shade(SAFE, -0.3), shade(SAFE, 0.45), ow=0.03, sh=0.035, lw=0.03)
        ex, ey = sgn * 0.19, -0.09
        eye = sd_ellipse(ex, ey, 0.12, 0.1)
        cv.fill(eye(x, y) - 0.03, INK)
        cv.fill(eye(x, y), PAPER)
        cv.fill(sd_circle(ex + sgn * 0.025, ey + 0.01, 0.062)(x, y), INK)
        cv.fill(sd_circle(ex + sgn * 0.025 - 0.025, ey - 0.02, 0.022)(x, y), WHITE)
    # snout with nostrils, an open grin with Paper fangs
    snout = sd_ellipse(0, 0.16, 0.27, 0.14)
    toon(cv, snout, shade(GOLD, 0.2), shade(GOLD, -0.2), GOLD_HI, ow=0.03, sh=0.05, lw=0.035)
    for sgn in (-1, 1):
        cv.fill(sd_ellipse(sgn * 0.09, 0.15, 0.04, 0.028, sgn * 0.5)(x, y), INK)
    mouth = sd_ellipse(0, 0.38, 0.24, 0.095)
    mouth_cut = lambda x_, y_: np.maximum(mouth(x_, y_), -(y_ - 0.33))  # noqa: E731
    md = mouth_cut(x, y)
    cv.fill(md - 0.03, INK)
    cv.fill(md, hexc("#7A1E2A"))
    cv.fill(np.maximum(md, -(sd_ellipse(0, 0.47, 0.1, 0.05)(x, y))), DETONATE)  # tongue
    for sgn in (-1, 1):
        fang = sd_poly([(sgn * 0.1, 0.33), (sgn * 0.17, 0.33), (sgn * 0.135, 0.41)], 0.008)
        cv.fill(fang(x, y), PAPER)
    # whiskers: long curls from the snout, a spark at each end
    for sgn in (-1, 1):
        pts = []
        for i in range(30):
            s = i / 29
            pts.append((sgn * (0.26 + 0.55 * s), 0.18 + 0.32 * math.sin(s * 3.2) * s - 0.05 * s))
        wd, _, _ = sd_path(pts, lambda s: 0.026 - 0.016 * s)(x, y)
        cv.fill(wd - 0.025, INK)
        cv.fill(wd, SAFE)
        ex_, ey_ = pts[-1]
        glow_dot(cv, ex_, ey_, 0.05, WHITE, SPARK, EMBER, EMBER, 0.06, 0.35)
        twinkle(cv, ex_, ey_, 0.11, 0.018, WHITE)
    # sparks crackling off the outline
    for _ in range(14):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.82, 0.96)
        glow_dot(cv, math.cos(a) * rr, math.sin(a) * rr * 0.95, rng.uniform(0.012, 0.022), WHITE, SPARK, EMBER)
    return cv.rgba()


@asset("victory", "victory_dragon_segment")
def victory_dragon_segment():
    cv = tile(256)
    x, y = cv.x, cv.y
    # the dorsal fin: three Safe-green flame spikes on top
    fins = union(*[sd_taper((sx_, -0.25), (sx_ * 1.4, -0.92 + abs(sx_) * 0.5), 0.13, 0.02) for sx_ in (-0.3, 0.0, 0.3)])
    toon(cv, fins, SAFE, shade(SAFE, -0.3), shade(SAFE, 0.45), ow=0.045, sh=0.05, lw=0.04)
    # sparks fringe underneath
    for k in range(7):
        a = math.pi * (0.2 + 0.6 * k / 6)
        glow_dot(cv, math.cos(a) * 0.78, math.sin(a) * 0.72 + 0.06, 0.05, WHITE, SPARK, EMBER, EMBER, 0.05, 0.3)
    body = sd_ellipse(0, 0.05, 0.62, 0.55)
    d = toon(cv, body, GOLD, shade(GOLD, -0.28), GOLD_HI, ow=0.06, sh=0.1, lw=0.07)
    band = np.abs(y - 0.05) - 0.16
    cv.fill(np.maximum(band, d + 0.0), FUSE)
    cv.fill(np.maximum(np.maximum(band, d), -(y - 0.05) - 0.0 + 0.0 - 0.1), shade(FUSE, -0.25))
    cv.fill(np.maximum(np.abs(np.abs(y - 0.05) - 0.16) - 0.012, d), INK)
    for k in range(4):  # paper ribs
        yy0 = -0.33 + k * 0.25
        if abs(yy0 - 0.05) < 0.17:
            continue
        rib = np.abs(y - yy0 - 0.08 * (x / 0.6) ** 2) - 0.012
        cv.fill(np.maximum(rib, d + 0.06), shade(GOLD, -0.35), 0.75)
    # a paper zigzag trim across the band
    zz = 0.05 + 0.09 * (2 * np.abs(np.mod(x * 3.2, 1.0) - 0.5) * 2 - 1)
    cv.fill(np.maximum(np.maximum(band + 0.02, d), np.abs(y - zz) - 0.035), SPARK)
    cv.fill(np.maximum(np.maximum(band + 0.02, d), np.abs(np.abs(y - zz) - 0.035) - 0.008), INK, 0.8)
    return cv.rgba()


@asset("victory", "victory_champagne_bubble")
def victory_champagne_bubble():
    cv = tile(256)
    x, y = cv.x, cv.y
    cv.over(GOLD, np.clip(np.exp(-(np.hypot(x, y) / 0.9) ** 2) * 0.3, 0, 1))
    r = np.hypot(x, y)
    cv.fill(r - 0.8, GOLD_HI, 0.3)
    cv.fill(np.abs(r - 0.68) - 0.12, GOLD, 0.6)  # the gold glass thickening toward the rim
    # a caustic crescent glowing inside the bottom-right
    cv.fill(np.maximum(sd_circle(0.12, 0.14, 0.52)(x, y), -sd_circle(-0.02, -0.04, 0.54)(x, y)), SPARK, 0.9)
    bubble(cv, GOLD, 0.0, SPARK, GOLD_LO, glint=True)
    cv.fill(sd_circle(0.3, 0.42, 0.05)(x, y), WHITE, 0.8)
    return cv.rgba()


# ═════════════════════════════════════════════ REVIEW SHEETS ════════════════════════════════════════════════════════
SHEET_CSS = """
*{box-sizing:border-box} body{margin:0;background:#16121C;color:#FFF3E2;font:600 15px 'Segoe UI',sans-serif;width:%dpx}
.wrap{padding:24px} h1{font:800 40px 'Segoe UI';margin:0} .bar{height:4px;background:#FF6A1F;margin:10px 0 20px}
.g{display:grid;grid-template-columns:repeat(%d,1fr);gap:18px}
.t{background:#241D2E;border-radius:12px;padding:8px} .t b{display:block;padding:6px 4px 0;font-size:15px}
.p{display:grid;grid-template-columns:1fr 1fr;gap:6px}
.p div{border-radius:8px;aspect-ratio:%s;background-size:contain;background-repeat:no-repeat;background-position:center}
.d{background-color:#2A2F45} .l{background-color:#E7E1D6}
"""


def write_sheet(cat, names):
    trails = cat == "trail"
    width = 2400
    cols = 2 if trails else 4
    aspect = "8/1" if trails else "1/1"
    tiles = []
    for nm in names:
        uri = Path(OUT, nm + ".png").as_uri()
        if trails:
            panel = f'<div class="d" style="background-image:url({uri})"></div><div class="l" style="background-image:url({uri})"></div>'
            tiles.append(f'<div class="t"><div class="p" style="grid-template-columns:1fr">{panel}</div><b>{nm}</b></div>')
        else:
            panel = f'<div class="d" style="background-image:url({uri})"></div><div class="l" style="background-image:url({uri})"></div>'
            tiles.append(f'<div class="t"><div class="p">{panel}</div><b>{nm}</b></div>')
    rows = math.ceil(len(names) / cols)
    html = (f'<!doctype html><html><head><meta charset="utf-8"><style>{SHEET_CSS % (width, cols, aspect)}</style></head>'
            f'<body><div class="wrap"><h1>FUSE VALLEY · cosmetic VFX · {cat.upper()}</h1><div class="bar"></div>'
            f'<div class="g">{"".join(tiles)}</div></div></body></html>')
    height = int(110 + rows * (370 if trails else 340) + 30)
    hp = Path(OUT, f"_sheet_{cat}.html")
    hp.write_text(html, encoding="utf-8")
    edge = next((p for p in (r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                             r"C:\Program Files\Microsoft\Edge\Application\msedge.exe") if os.path.exists(p)), None)
    if not edge:
        return
    png = Path(OUT, f"_sheet_{cat}.png")
    profile = Path(tempfile.gettempdir()) / f"edgesheet_{uuid.uuid4().hex}"
    subprocess.run([edge, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={profile}",
                    f"--window-size={width},{height}", "--virtual-time-budget=6000", "--allow-file-access-from-files",
                    f"--screenshot={png}", hp.as_uri()], check=False, timeout=120,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    hp.unlink(missing_ok=True)
    print("sheet", png, flush=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    cats = [a for a in argv if a in ("boom", "spark", "trail", "victory")] or ["boom", "spark", "trail", "victory"]
    only = [a for a in argv if a not in cats]
    os.makedirs(OUT, exist_ok=True)
    for cat in cats:
        names = []
        for c, name, fn in ASSETS:
            if c != cat:
                continue
            names.append(name)
            if only and name not in only:
                continue
            save(OUT, name, fn())
        write_sheet(cat, names)
    print("DONE", OUT, flush=True)


main()
