"""FUSE VALLEY — the Fireworks Yard's in-house textures (Asset Bible §4.2: concrete with expansion joints, oil stains
and chalk marks, painted hazard lanes; the yard's floor roundel). Procedural and seeded; no stock, no AI.

  yard_grime.png   512²     tileable concrete grime: dirt blotches, speckle and hairline cracks (dark, alpha)
  yard_oil.png     512²     an oil stain with a darker dried rim and a couple of drips (dark, alpha)
  yard_chalk.png   1024×512 hand-drawn chalk marks: a tally, an arrow, a circled cross, a star (white, alpha)
  yard_hazard.png  256²     tileable worn hazard stripes, yellow / ink (colours baked in, worn spots clear)
  yard_emblem.png  1024²    the painted floor roundel: the bomb on a Fuse-orange disc in a Paper ring, worn

Run: blender -b --python-exit-code 1 --python art/yard/make_textures.py
"""

import math
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
from texlib import (  # noqa: E402
    aa,
    fbm,
    grid,
    hexc,
    mix,
    poly_dist,
    preview,
    random_walk,
    save,
    specks,
    value_noise,
    wrapped_poly_dist,
)

OUT = os.path.join(ROOT, "art", "out", "Yard")
INK = hexc("#16121C")
PAPER = hexc("#FFF3E2")
FUSE = hexc("#FF6A1F")
SPARK = hexc("#FFD84A")
HAZARD = hexc("#F5BE2C")
CONCRETE = np.array([0.56, 0.54, 0.5])

# ── grime (tileable) ─────────────────────────────────────────────────────────────────────────────────────────────
x, y = grid(512)
blot = fbm(x, y, 4, 101, 5)
grit = specks(x, y, 96, 7, 0.74)
crng = np.random.default_rng(55)
cracks = np.zeros_like(x)
for i in range(5):  # a few jagged hairline cracks with the odd branch, wrapping across the tile edges
    walk = random_walk(crng, (crng.uniform(-1, 1), crng.uniform(-1, 1)), 26, 0.035, 0.45)
    cracks = np.maximum(cracks, aa(wrapped_poly_dist(x, y, walk), 0.0035, 2 / 512) * crng.uniform(0.5, 0.9))
    k = crng.integers(6, 20)
    branch = random_walk(crng, walk[k], 9, 0.03, 0.6)
    cracks = np.maximum(cracks, aa(wrapped_poly_dist(x, y, branch), 0.0025, 2 / 512) * 0.5)
a = np.clip((blot - 0.5) * 1.8, 0, 1) * 0.32 + grit * 0.22 + cracks * 0.6
col = mix(np.array([0.2, 0.17, 0.14]), np.array([0.1, 0.09, 0.08]), cracks)
grime = save(OUT, "yard_grime", np.dstack([col, np.clip(a, 0, 1)]))
preview(OUT, "yard_grime", grime, CONCRETE)

# ── oil stain ────────────────────────────────────────────────────────────────────────────────────────────────────
x, y = grid(512)
wx = (fbm(x * 0.8, y * 0.8, 3, 21, 4) - 0.5) * 0.55
wy = (fbm(x * 0.8 + 0.5, y * 0.8, 3, 22, 4) - 0.5) * 0.55
r = np.hypot(x + wx, y * 1.15 + wy) / 0.62
for cx, cy, cr in [(0.62, 0.38, 0.1), (0.7, 0.52, 0.06), (-0.55, -0.48, 0.08)]:  # drips and splashes
    r = np.minimum(r, np.hypot(x - cx + wx * 0.3, y - cy + wy * 0.3) / cr)
body = aa(r, 1.0, 0.012)
rim = np.exp(-((r - 0.93) / 0.06) ** 2)
inner = np.clip(1 - r, 0, 1)
mottle = fbm(x * 2, y * 2, 6, 31, 3)
a = body * (0.42 + 0.22 * inner + 0.18 * (mottle - 0.5)) + rim * 0.22 * body
col = mix(np.array([0.07, 0.06, 0.05]), np.array([0.03, 0.025, 0.02]), np.clip(inner * 1.5, 0, 1))
oil = save(OUT, "yard_oil", np.dstack([col, np.clip(a, 0, 1)]))
preview(OUT, "yard_oil", oil, CONCRETE)

# ── chalk marks (hand-drawn) ─────────────────────────────────────────────────────────────────────────────────────
H, W = 512, 1024
x, y = grid(H, W)
u, v = x * 2, y  # drawing space: u -2..2, v -1..1 (square units)
rng = np.random.default_rng(5)


def wobble(pts, amt=0.012):
    """Resample a polyline and bend it like a hand-held stroke: a slow, smooth drift (never a zig-zag)."""
    out = []
    ph1, ph2 = rng.uniform(0, 6.28, 2)
    total = 0.0
    for a_, b_ in zip(pts[:-1], pts[1:]):
        seg = math.hypot(b_[0] - a_[0], b_[1] - a_[1])
        n = max(2, int(seg / 0.02))
        for i in range(n):
            t = i / n
            s = total + seg * t
            out.append((
                a_[0] + (b_[0] - a_[0]) * t + amt * math.sin(s * 5.0 + ph1),
                a_[1] + (b_[1] - a_[1]) * t + amt * math.sin(s * 4.3 + ph2),
            ))
        total += seg
    out.append(pts[-1])
    return out


strokes = []
# a tally of five (four uprights and a slash)
for i in range(4):
    x0 = -1.75 + i * 0.13
    strokes.append(wobble([(x0, -0.42 + rng.normal(0, 0.02)), (x0 + 0.03, 0.38 + rng.normal(0, 0.02))]))
strokes.append(wobble([(-1.86, 0.18), (-1.22, -0.2)]))
# an arrow
strokes.append(wobble([(-0.85, 0.3), (-0.2, -0.05), (0.32, -0.12)]))
strokes.append(wobble([(0.32, -0.12), (0.1, -0.32)]))
strokes.append(wobble([(0.32, -0.12), (0.14, 0.1)]))
# a circled cross
circle = [(0.95 + 0.33 * math.cos(t), 0.05 + 0.31 * math.sin(t)) for t in np.linspace(0.3, 0.3 + 2 * math.pi * 1.06, 40)]
strokes.append(wobble(circle, 0.008))
strokes.append(wobble([(0.78, -0.12), (1.12, 0.22)]))
strokes.append(wobble([(1.12, -0.12), (0.78, 0.22)]))
# a five-point star
star = []
for k in range(6):
    t = -math.pi / 2 + k * 4 * math.pi / 5
    star.append((1.68 + 0.26 * math.cos(t), 0.0 + 0.26 * math.sin(t)))
strokes.append(wobble(star, 0.01))

d = np.full_like(u, 9.0)
for s in strokes:
    d = np.minimum(d, poly_dist(u, v, s))
px = 4.0 / W
line = aa(d, 0.016, px)
grain = np.clip((value_noise(x, y, 220, 9) * 0.6 + value_noise(x, y, 64, 10) * 0.4 - 0.28) * 2.2, 0, 1)
a = line * grain * 0.9
chalk = save(OUT, "yard_chalk", np.dstack([np.ones_like(a) * PAPER[0], np.ones_like(a) * PAPER[1], np.ones_like(a) * PAPER[2], a]))
preview(OUT, "yard_chalk", chalk, CONCRETE * 0.8)

# ── hazard stripes (tileable, worn) ──────────────────────────────────────────────────────────────────────────────
x, y = grid(256)
uu, vv = (x + 1) / 2, (y + 1) / 2
phase = (uu + vv) * 2  # two stripe pairs across the tile: integer periods both ways, so it tiles
f = phase - np.floor(phase)
yellow = aa(np.abs(f - 0.25), 0.25, 2 / 256 * 2)
col = mix(INK, HAZARD, yellow)
wear = fbm(x, y, 6, 61, 5)
chips = specks(x, y, 48, 62, 0.76)
alive = np.clip((0.75 - wear) * 12, 0, 1) * (1 - chips)
col = col * (0.9 + 0.1 * fbm(x, y, 8, 63, 3))[..., None]
hazard = save(OUT, "yard_hazard", np.dstack([col, alive * 0.95]))
preview(OUT, "yard_hazard", hazard, CONCRETE)

# ── the floor roundel ────────────────────────────────────────────────────────────────────────────────────────────
N = 1024
x, y = grid(N)
px = 2 / N
r = np.hypot(x, y)
ring = aa(np.abs(r - 0.93), 0.045, px)
disc = aa(r, 0.84, px)
inner_ring = aa(np.abs(r - 0.79), 0.012, px)
# the bomb: body, socket, fuse, spark
bx, by, br = -0.04, 0.1, 0.4
body = aa(np.hypot(x - bx, y - by), br, px)
ang = math.radians(-40)
ca, sa = math.cos(ang), math.sin(ang)
sx, sy = bx + math.sin(math.radians(40)) * (br + 0.02), by - math.cos(math.radians(40)) * (br + 0.02)
lx = (x - sx) * ca - (y - sy) * sa
ly = (x - sx) * sa + (y - sy) * ca
socket = aa(np.maximum(np.abs(lx) - 0.1, np.abs(ly) - 0.07), 0.025, px)
p0 = (sx + 0.03, sy - 0.08)
p1 = (sx + 0.22, sy - 0.32)
p2 = (sx + 0.08, sy - 0.46)
curve = [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in np.linspace(0, 1, 24)]
fuse = aa(poly_dist(x, y, curve), 0.022, px)
tip = curve[-1]
ta = np.arctan2(y - tip[1], x - tip[0])
tr = np.hypot(x - tip[0], y - tip[1])
star_r = 0.07 + 0.08 * np.abs(np.cos(ta * 4)) ** 3
star = aa(tr - star_r, 0, px)
# the highlight crescent on the body (lit from the upper left)
hl = aa(np.hypot(x - (bx - 0.12), y - (by - 0.12)), 0.24, px) * (1 - aa(np.hypot(x - (bx - 0.06), y - (by - 0.06)), 0.25, px))
col = np.zeros((N, N, 3))
a = np.zeros((N, N))


def paint(mask, c):
    global col, a
    col = mix(col, np.asarray(c), mask)
    a = np.maximum(a, mask)


paint(ring, PAPER)
paint(disc, FUSE)
paint(inner_ring * disc, PAPER)
paint(body, INK)
paint(socket, INK)
paint(fuse * (1 - body), INK)
paint(hl * body, PAPER * 0.92)
paint(star, SPARK)
# wear: the paint is scuffed by boots and wheels, never uniformly
wear = fbm(x, y, 6, 71, 5)
chips = specks(x, y, 140, 72, 0.77)
scuffed = np.clip((wear - 0.6) * 6, 0, 1)  # worn-thin patches: the paint fades there, it doesn't vanish
keep = (1 - scuffed * 0.55) * (1 - chips)
emblem = save(OUT, "yard_emblem", np.dstack([col, a * keep * 0.95]))
preview(OUT, "yard_emblem", emblem, CONCRETE)
print("DONE", OUT, flush=True)
