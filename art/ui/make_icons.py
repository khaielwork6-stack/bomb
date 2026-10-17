"""FUSE VALLEY — the custom icon set (Asset Bible §6.4), drawn in code: signed-distance shapes rendered at 256²
with the house style — a chunky Ink outline (8 px at 256, the spec's 4 px at 128), a two-tone fill (base + a lighter
top-left plane), one specular dot, a consistent 10° tilt on objects. No emoji, no stock, no AI.

  icon_star  icon_gift  icon_scroll  icon_calendar  icon_flame  icon_crate  icon_check
  icon_bomb  icon_person (grey: tinted per team)  icon_shield  icon_badge (grey: tinted per badge tier)

Run: blender -b --python-exit-code 1 --python art/ui/make_icons.py
"""

import math
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
from texlib import grid, hexc, mix, poly_dist, preview, save  # noqa: E402

OUT = os.path.join(ROOT, "art", "out", "Icons")
N = 256
PX = 2 / N
INK = hexc("#16121C")
PAPER = hexc("#FFF3E2")
FUSE = hexc("#FF6A1F")
EMBER = hexc("#FF9442")
SPARK = hexc("#FFD84A")
GOLD = hexc("#F2B13A")
SAFE = hexc("#3BE48C")
BOMBER = hexc("#FF4A2E")
IRON = hexc("#2E2C33")
BRASS = hexc("#C9973F")
WOOD = hexc("#B67E4E")
WOOD_D = hexc("#74503A")
STEEL = hexc("#8088A0")
OUTLINE = 0.062  # the Ink outline half-width (≈8 px at 256)
INNER = 0.024  # lines between parts inside the silhouette


def lighter(c, k=0.35):
    return c + (1 - c) * k


# ── signed distances (negative inside) ──────────────────────────────────────────────────────────────────────────
def sd_circle(x, y, cx, cy, r):
    return np.hypot(x - cx, y - cy) - r


def sd_ellipse(x, y, cx, cy, rx, ry, rot=0.0):
    """An ellipse (approximate SDF, good near the edge, which is all the painter needs)."""
    u = (x - cx) * math.cos(rot) + (y - cy) * math.sin(rot)
    v = -(x - cx) * math.sin(rot) + (y - cy) * math.cos(rot)
    k = np.hypot(u / rx, v / ry)
    return (k - 1.0) * min(rx, ry)


def sd_box(x, y, cx, cy, hw, hh, r=0.0):
    qx = np.abs(x - cx) - hw + r
    qy = np.abs(y - cy) - hh + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def sd_poly(x, y, pts):
    """Exact polygon SDF (even-odd sign)."""
    d = poly_dist(x, y, pts + [pts[0]])
    inside = np.zeros_like(x, dtype=bool)
    n = len(pts)
    for i in range(n):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
        cond = ((y1 > y) != (y2 > y)) & (x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1)
        inside ^= cond
    return np.where(inside, -d, d)


def sd_star(x, y, cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    pts = []
    for k in range(n * 2):
        a = rot + k * math.pi / n
        r = ro if k % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return sd_poly(x, y, pts)


def sd_union(*ds):
    out = ds[0]
    for d in ds[1:]:
        out = np.minimum(out, d)
    return out


def rounded(d, r):
    return d - r


# ── the painter ─────────────────────────────────────────────────────────────────────────────────────────────────
def cover(d):
    return np.clip(0.5 - d / PX, 0, 1)


class Icon:
    def __init__(self, tilt=10.0):
        x, y = grid(N)
        a = math.radians(tilt)
        # rotate the drawing space so every object leans the same 10°
        self.x = x * math.cos(a) + y * math.sin(a)
        self.y = -x * math.sin(a) + y * math.cos(a)
        self.col = np.zeros((N, N, 3))
        self.alpha = np.zeros((N, N))
        self.sil = np.full((N, N), 9.0)  # the union silhouette (for the outer outline)
        self.lines = np.zeros((N, N))

    def fill(self, d, base, light=None, plane=0.0, line=True):
        """Paint a part: base colour, a lighter top-left plane (split along x + y = plane), an inner Ink line."""
        c = cover(d)
        lit = light if light is not None else lighter(base)
        side = np.clip(((plane - (self.x + self.y)) / 0.02), 0, 1)  # 1 on the top-left side
        part = mix(base, lit, side)
        self.col = mix(self.col, part, c)
        self.alpha = np.maximum(self.alpha, c)
        self.sil = np.minimum(self.sil, d)
        if line:
            self.lines = np.maximum(self.lines, cover(np.abs(d) - INNER) * (d > -INNER * 3))

    def ink(self, d):
        """An Ink-filled detail (stroke drawn as a shape)."""
        c = cover(d)
        self.col = mix(self.col, INK, c)
        self.alpha = np.maximum(self.alpha, c)
        self.sil = np.minimum(self.sil, d)

    def spec(self, cx, cy, rx=0.07, ry=0.045, rot=-0.6):
        x, y = self.x - cx, self.y - cy
        u = x * math.cos(rot) + y * math.sin(rot)
        v = -x * math.sin(rot) + y * math.cos(rot)
        c = cover(np.hypot(u / rx, v / ry) - 1.0) * self.alpha
        self.col = mix(self.col, np.array([1.0, 1.0, 1.0]), c * 0.9)

    def done(self, name, bg=np.array([0.17, 0.14, 0.22])):
        outline = cover(self.sil - OUTLINE) * (1 - cover(self.sil))
        col = mix(self.col, INK, np.maximum(self.lines * self.alpha, outline))
        alpha = np.maximum(self.alpha, cover(self.sil - OUTLINE))
        # a solid offset shadow is drawn by the UI (Asset Bible §6.1); the icon itself stays clean
        rgba = np.dstack([col, alpha])
        save(OUT, name, rgba)
        preview(OUT, name, rgba, bg)


# ── the icons ───────────────────────────────────────────────────────────────────────────────────────────────────
def star():
    ic = Icon()
    d = rounded(sd_star(ic.x, ic.y, 0, 0.04, 0.74, 0.34), 0.06)
    ic.fill(d, SPARK, lighter(SPARK, 0.55), plane=-0.05)
    inner = rounded(sd_star(ic.x, ic.y, 0, 0.04, 0.36, 0.17), 0.03)
    ic.fill(inner, lighter(SPARK, 0.4), lighter(SPARK, 0.75), plane=0.0, line=False)
    ic.spec(-0.2, -0.28)
    ic.done("icon_star")


def gift():
    ic = Icon()
    box = sd_box(ic.x, ic.y, 0, 0.22, 0.6, 0.48, 0.06)
    lid = sd_box(ic.x, ic.y, 0, -0.27, 0.7, 0.14, 0.05)
    ic.fill(box, FUSE, EMBER, plane=-0.2)
    ic.fill(lid, FUSE, lighter(FUSE, 0.45), plane=-0.3)
    rib_v = sd_box(ic.x, ic.y, 0, 0.1, 0.11, 0.62, 0.0)
    ic.fill(rib_v, SPARK, lighter(SPARK, 0.5), plane=0.0)
    for s in (-1, 1):
        # a ribbon loop: an ellipse leaning out from the knot, with the shaded inside of the fold
        loop = sd_ellipse(ic.x, ic.y, s * 0.27, -0.5, 0.27, 0.13, s * -0.45)
        ic.fill(loop, SPARK, lighter(SPARK, 0.5), plane=-0.7)
        fold = sd_ellipse(ic.x, ic.y, s * 0.3, -0.5, 0.13, 0.045, s * -0.45)
        ic.fill(fold, GOLD, GOLD, plane=-0.7, line=False)
    ic.fill(sd_circle(ic.x, ic.y, 0, -0.44, 0.12), GOLD, SPARK, plane=-0.4)
    ic.spec(-0.38, 0.0)
    ic.done("icon_gift")


def scroll():
    ic = Icon()
    body = sd_box(ic.x, ic.y, 0, 0.02, 0.5, 0.62, 0.04)
    ic.fill(body, PAPER, lighter(PAPER, 0.5), plane=-0.2)
    for cy in (-0.62, 0.66):
        roll = sd_box(ic.x, ic.y, 0, cy, 0.62, 0.11, 0.1)
        ic.fill(roll, hexc("#E8D6B8"), PAPER, plane=cy * 2 - 0.4)
        for s in (-1, 1):
            ic.fill(sd_circle(ic.x, ic.y, s * 0.64, cy, 0.09), WOOD, lighter(WOOD), plane=s * 0.6 + cy * 2)
    for k, w in enumerate((0.62, 0.5, 0.56)):
        y0 = -0.32 + k * 0.24
        ic.ink(sd_box(ic.x, ic.y, -0.32 + w * 0.5 - 0.08, y0, w * 0.5 - 0.06, 0.035, 0.035))
    ic.fill(sd_circle(ic.x, ic.y, 0.26, 0.42, 0.13), FUSE, EMBER, plane=0.5)  # the seal
    ic.spec(-0.3, -0.42, 0.06, 0.035)
    ic.done("icon_scroll")


def calendar():
    ic = Icon()
    page = sd_box(ic.x, ic.y, 0, 0.1, 0.66, 0.6, 0.1)
    ic.fill(page, PAPER, lighter(PAPER, 0.5), plane=-0.3)
    head = np.maximum(page, ic.y - (-0.22))  # the top band
    ic.fill(head, BOMBER, lighter(BOMBER, 0.35), plane=-0.6)
    for s in (-1, 1):
        ic.fill(sd_box(ic.x, ic.y, s * 0.32, -0.56, 0.07, 0.18, 0.07), STEEL, lighter(STEEL, 0.5), plane=-0.8)
    for r in range(2):
        for c in range(3):
            cell = sd_box(ic.x, ic.y, -0.36 + c * 0.36, 0.04 + r * 0.3, 0.11, 0.09, 0.03)
            if r == 1 and c == 2:
                ic.fill(cell, SAFE, lighter(SAFE), plane=0.6)
            else:
                ic.fill(cell, hexc("#E6D7C0"), lighter(hexc("#E6D7C0")), plane=0.0, line=False)
    ic.spec(-0.45, -0.38, 0.06, 0.035)
    ic.done("icon_calendar")


def flame():
    ic = Icon(tilt=0)
    # an upside-down teardrop with a lick: circle base + pointed top
    outer = sd_union(
        sd_circle(ic.x, ic.y, 0, 0.3, 0.46),
        sd_poly(ic.x, ic.y, [(-0.44, 0.22), (0.02, -0.86), (0.18, -0.35), (0.44, 0.2)]),
        sd_poly(ic.x, ic.y, [(0.12, -0.1), (0.5, -0.5), (0.42, 0.18)]),
    )
    outer = rounded(outer, 0.04)
    ic.fill(outer, FUSE, EMBER, plane=-0.1)
    mid = rounded(sd_union(sd_circle(ic.x, ic.y, 0.02, 0.38, 0.28), sd_poly(ic.x, ic.y, [(-0.26, 0.3), (0.0, -0.38), (0.28, 0.3)])), 0.03)
    ic.fill(mid, SPARK, lighter(SPARK, 0.5), plane=0.1)
    core = sd_union(sd_circle(ic.x, ic.y, 0.03, 0.48, 0.13), sd_poly(ic.x, ic.y, [(-0.1, 0.44), (0.03, 0.08), (0.16, 0.44)]))
    ic.fill(core, PAPER, np.array([1.0, 1.0, 1.0]), plane=0.5, line=False)
    ic.spec(-0.2, 0.12, 0.05, 0.08, 0.3)
    ic.done("icon_flame")


def crate():
    ic = Icon()
    body = sd_box(ic.x, ic.y, 0, 0.12, 0.66, 0.56, 0.06)
    ic.fill(body, WOOD, lighter(WOOD, 0.3), plane=-0.3)
    for cx in (-0.48, 0.48):
        ic.fill(sd_box(ic.x, ic.y, cx, 0.12, 0.1, 0.56, 0.03), WOOD_D, WOOD, plane=-0.3)
    for cy in (-0.32, 0.56):
        ic.fill(sd_box(ic.x, ic.y, 0, cy, 0.66, 0.08, 0.03), WOOD_D, WOOD, plane=-0.3)
    ic.fill(sd_box(ic.x, ic.y, 0, 0.12, 0.2, 0.14, 0.04), FUSE, EMBER, plane=0.0)  # the stencilled plate
    # a fuse poking out of the lid, with its spark
    pts = [(0.18, -0.4), (0.24, -0.62), (0.38, -0.74)]
    ic.fill(poly_dist(ic.x, ic.y, pts) - 0.05, hexc("#D9B98A"), PAPER, plane=-1.0)
    ic.fill(rounded(sd_star(ic.x, ic.y, 0.42, -0.78, 0.2, 0.08, 6), 0.01), SPARK, PAPER, plane=-1.2)
    ic.spec(-0.42, -0.2, 0.06, 0.035)
    ic.done("icon_crate")


def check():
    ic = Icon(tilt=0)
    ic.fill(sd_circle(ic.x, ic.y, 0, 0, 0.74), SAFE, lighter(SAFE, 0.4), plane=-0.1)
    tick = poly_dist(ic.x, ic.y, [(-0.36, 0.0), (-0.1, 0.28), (0.4, -0.3)]) - 0.11
    ic.fill(tick, PAPER, np.array([1.0, 1.0, 1.0]), plane=0.0)
    ic.spec(-0.34, -0.42)
    ic.done("icon_check")


def bomb():
    ic = Icon()
    body = sd_circle(ic.x, ic.y, -0.04, 0.16, 0.6)
    ic.fill(body, IRON, hexc("#5A5868"), plane=-0.25)
    band = np.maximum(body - 0.0, np.abs(ic.y - 0.2) - 0.1)
    ic.fill(band, BRASS, lighter(BRASS, 0.4), plane=-0.2)
    sock = sd_box(ic.x, ic.y, 0.3, -0.42, 0.13, 0.11, 0.03)
    ic.fill(sock, BRASS, lighter(BRASS, 0.4), plane=-0.4)
    ic.fill(poly_dist(ic.x, ic.y, [(0.32, -0.5), (0.4, -0.66), (0.56, -0.76)]) - 0.05, hexc("#D9B98A"), PAPER, plane=-1.0)
    ic.fill(rounded(sd_star(ic.x, ic.y, 0.6, -0.8, 0.22, 0.08, 6), 0.01), SPARK, PAPER, plane=-1.0)
    ic.spec(-0.3, -0.14, 0.1, 0.06)
    ic.done("icon_bomb")


def person():
    ic = Icon(tilt=0)
    grey, light = np.array([0.78, 0.78, 0.8]), np.array([1.0, 1.0, 1.0])
    body = rounded(sd_poly(ic.x, ic.y, [(-0.5, 0.78), (-0.36, 0.06), (0.36, 0.06), (0.5, 0.78)]), 0.08)
    ic.fill(body, grey, light, plane=-0.2)
    ic.fill(sd_circle(ic.x, ic.y, 0, -0.38, 0.32), grey, light, plane=-0.5)
    ic.spec(-0.14, -0.52, 0.07, 0.045)
    ic.done("icon_person")


def shield():
    ic = Icon(tilt=0)
    pts = [(-0.6, -0.62), (0.6, -0.62), (0.6, 0.06), (0.0, 0.8), (-0.6, 0.06)]
    d = rounded(sd_poly(ic.x, ic.y, pts), 0.08)
    ic.fill(d, SAFE, lighter(SAFE, 0.4), plane=-0.1)
    tick = poly_dist(ic.x, ic.y, [(-0.3, -0.04), (-0.06, 0.22), (0.32, -0.28)]) - 0.1
    ic.fill(tick, PAPER, np.array([1.0, 1.0, 1.0]), plane=0.0)
    ic.spec(-0.36, -0.4)
    ic.done("icon_shield")


def badge():
    ic = Icon(tilt=0)
    grey, light = np.array([0.72, 0.72, 0.75]), np.array([1.0, 1.0, 1.0])
    hexa = [(0.74 * math.cos(math.pi / 6 + k * math.pi / 3), 0.74 * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)]
    outer = rounded(sd_poly(ic.x, ic.y, hexa), 0.06)
    inner = rounded(sd_poly(ic.x, ic.y, [(p[0] * 0.72, p[1] * 0.72) for p in hexa]), 0.04)
    ic.fill(np.maximum(outer, -inner), grey, light, plane=-0.1)
    ic.fill(inner, np.array([0.3, 0.28, 0.34]), np.array([0.4, 0.38, 0.44]), plane=-0.3)  # the dark well the number sits in
    ic.spec(-0.4, -0.42)
    ic.done("icon_badge")


for fn in (star, gift, scroll, calendar, flame, crate, check, bomb, person, shield, badge):
    fn()
print("DONE", OUT, flush=True)
