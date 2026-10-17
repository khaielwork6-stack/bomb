"""FUSE VALLEY — the in-house VFX textures (Asset Bible §5, the Quality Bar: hand-designed, no stock, no AI).

Procedural, deterministic (seeded) numpy generators, written as PNGs with Blender's image API:
  vfx_flash.png        512²  a 6-point star flash (white; the emitter tints it)
  vfx_fireball.png     1024² 4×4 flipbook: a toon fireball — white core → Spark → Fuse bands inside an Ink outline,
                             growing, then breaking up into holes as it burns out (colours baked in)
  vfx_smoke.png        1024² 4×4 flipbook: a cel-shaded smoke puff cluster (lit rim, dark core, thin outline),
                             billowing and eroding away (grey; the emitter tints it)
  vfx_streak.png       128×512 a tapered spark streak (velocity-aligned particles)
  vfx_ring.png         512²  the crisp double shockwave ring
  vfx_scorch.png       512²  a starburst scorch decal for the floor (dark, alpha)
  vfx_ember.png        64²   a soft ember dot
Then writes a preview sheet (art/out/Vfx/preview.png) of every texture on dark and light.

Run: blender -b --python-exit-code 1 --python art/vfx/make_vfx.py
"""

import math
import os

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Vfx")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261017)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


INK = hexc("#16121C")
SPARK = hexc("#FFD84A")
FUSE = hexc("#FF6A1F")
EMBER = hexc("#FF9442")
WHITE = np.array([1.0, 0.98, 0.9])


def save(name, rgba):
    """rgba: H×W×4 float array, row 0 at the top."""
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = np.flipud(np.clip(rgba, 0, 1)).astype(np.float32).ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("wrote", name, flush=True)
    return rgba


def grid(n, m=None):
    m = m or n
    y, x = np.mgrid[0:n, 0:m].astype(np.float64)
    return (x + 0.5) / m * 2 - 1, (y + 0.5) / n * 2 - 1


def smooth(t):
    return t * t * (3 - 2 * t)


def value_noise(x, y, cells, seed):
    """Smooth value noise on a periodic lattice: seamless for any input (no wrap seams)."""
    rng = np.random.default_rng(seed)
    lat = rng.random((cells, cells))
    gx = (x * 0.5 + 0.5) * cells
    gy = (y * 0.5 + 0.5) * cells
    x0 = np.floor(gx).astype(int) % cells
    y0 = np.floor(gy).astype(int) % cells
    x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
    fx, fy = smooth(gx - np.floor(gx)), smooth(gy - np.floor(gy))
    a, b = lat[y0, x0], lat[y0, x1]
    c, d = lat[y1, x0], lat[y1, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def burn_holes(x, y, amount, seed, count=14):
    """Round holes that grow from scattered points with wobbly edges (a cartoon puff breaking apart).
    amount 0..1; returns the signed distance to the nearest hole (> 0 where the surface survives)."""
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2)) * 1.6 - 0.8
    sizes = 0.35 + rng.random(count) * 0.65
    wob = fbm(x * 2.0, y * 2.0, 4, seed + 5, 3) - 0.5
    d = np.full_like(x, 9.0)
    for (px, py), sz in zip(pts, sizes):
        d = np.minimum(d, np.hypot(x - px, y - py) - amount * sz * 0.55)
    return d + wob * 0.32 * amount


def fbm(x, y, cells, seed, octaves=4):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + value_noise(x, y, cells * 2 ** o, seed + o * 97) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def open_mask(mask, r):
    """Morphological opening with a disk of radius r px (erode then dilate): removes thin slivers and specks."""
    if r <= 0:
        return mask
    offs = [(dy, dx) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= r * r]
    pad = np.pad(mask, r)
    h, w = mask.shape
    er = np.ones_like(mask)
    for dy, dx in offs:
        er &= pad[r + dy:r + dy + h, r + dx:r + dx + w]
    pad = np.pad(er, r)
    out = np.zeros_like(mask)
    for dy, dx in offs:
        out |= pad[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def band(v, lo, hi, soft=0.01):
    return np.clip((v - lo) / soft, 0, 1) * np.clip((hi - v) / soft, 0, 1)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


# ── flash: a 6-point star ────────────────────────────────────────────────────────────────────────────────────────
x, y = grid(512)
r = np.hypot(x, y)
ang = np.arctan2(y, x)
core = np.exp(-(r / 0.16) ** 2)
rays = np.zeros_like(r)
for k in range(6):
    a = k * math.pi / 3 + math.pi / 12
    along = x * math.cos(a) + y * math.sin(a)
    perp = -x * math.sin(a) + y * math.cos(a)
    rays += np.exp(-(perp / (0.018 + 0.05 * np.clip(along, 0, 1))) ** 2) * np.exp(-np.clip(along, 0, None) * 2.6) * (along > 0)
glow = np.exp(-(r / 0.42) ** 2) * 0.35
alpha = np.clip(core + rays * 0.9 + glow, 0, 1)
save("vfx_flash", np.dstack([np.ones_like(r)] * 3 + [alpha]))

# ── fireball: 4×4 flipbook ───────────────────────────────────────────────────────────────────────────────────────
N = 256
fx, fy = grid(N)
fr = np.hypot(fx, fy)
fa = np.arctan2(fy, fx)
sheet = np.zeros((N * 4, N * 4, 4))
for f in range(16):
    t = f / 15
    grow = 0.3 + 0.42 * (1 - (1 - t) ** 2.2)  # stays inside its tile (lumps reach ≈1.2× this)
    # a lumpy, billowing silhouette: radius warped by noise around the angle (moves with t)
    wob = fbm(np.cos(fa) * 0.9 + t * 0.6, np.sin(fa) * 0.9 - t * 0.4, 3, 11 + f // 4, 3)
    lumps = 1 + 0.22 * (wob - 0.5) * 2 + 0.06 * np.sin(fa * 5 + t * 4)
    re = fr / (grow * lumps)
    inner_n = fbm(fx * 1.3 + t, fy * 1.3 - t * 0.7, 4, 33, 4)
    # tone bands (toon): white core → spark → fuse, the core shrinking as it cools
    heat = 1 - t * 0.85
    c_core = 0.38 * heat + 0.08 * (inner_n - 0.5)
    c_mid = 0.68 * (0.7 + 0.3 * heat) + 0.06 * (inner_n - 0.5)
    col = np.where((re < c_core)[..., None], WHITE, np.where((re < c_mid)[..., None], SPARK, FUSE))
    # cooling: late frames darken toward ember-brown smoke
    col = mix(col, EMBER * 0.45, np.clip((t - 0.55) / 0.45, 0, 1) * np.clip(re * 1.2, 0, 1))
    body = re < 1.0
    outline = (re >= 1.0) & (re < 1.0 + 0.07 + 0.03 * t)
    col = np.where(outline[..., None], INK, col)
    # break-up: holes open from the inside out as it burns out
    erode = np.clip((t - 0.45) / 0.55, 0, 1)
    hole = burn_holes(fx, fy, erode ** 1.2, 71)
    # every hole gets the same Ink rim as the silhouette, so it reads as drawn, not cut out (the rim grows in with
    # the hole, so the full-body frames stay clean)
    rim = min(0.045, erode ** 1.2 * 0.15) if erode > 0.06 else 0.0
    col = np.where(((hole < rim) & body)[..., None], INK, col)
    # the burn-out leaves chunky pieces, never slivers: a morphological opening drops anything thinner than ~5%
    shape = open_mask((body | outline) & (hole > 0), 7 if erode > 0 else 0)
    a = shape.astype(float)
    a *= np.clip(1.0 - (t - 0.8) / 0.2, 0, 1) if t > 0.8 else 1.0
    tile = np.dstack([col, a])
    row, cl = f // 4, f % 4
    sheet[row * N:(row + 1) * N, cl * N:(cl + 1) * N] = tile
save("vfx_fireball", sheet)

# ── smoke: 4×4 flipbook, cel-shaded puff cluster ─────────────────────────────────────────────────────────────────
# A cluster of distinct puffs (x, y, radius, drift dx, drift dy, how early it dissolves 0..1). Cartoon smoke
# dissipates by its puffs drifting apart and shrinking away one by one (never by holes punched through).
blobs = [
    (-0.30, 0.12, 0.30, -0.10, 0.02, 0.55),
    (0.20, 0.16, 0.28, 0.12, 0.04, 0.35),
    (-0.02, -0.18, 0.34, 0.00, -0.10, 0.85),
    (-0.10, 0.36, 0.22, -0.04, 0.10, 0.15),
    (0.32, -0.16, 0.22, 0.10, -0.06, 0.45),
    (-0.34, -0.20, 0.20, -0.10, -0.06, 0.25),
    (0.10, 0.02, 0.30, 0.02, 0.00, 0.70),
]
K = 16.0  # smooth-union sharpness: high enough that each puff keeps its own round bump
sheet = np.zeros((N * 4, N * 4, 4))
for f in range(16):
    t = f / 15
    s = 0.7 + 0.32 * (1 - (1 - t) ** 2)  # the cluster billows out, then holds
    drift = 1 - (1 - t) ** 1.6

    def radius(order, br):
        # each puff swells a touch, then shrinks to nothing in its own window (order = when it goes)
        start = 0.25 + order * 0.5
        gone = np.clip((t - start) / 0.28, 0, 1)
        return br * s * (1 - smooth(gone))

    def union(dx, dy, rs):
        # smooth union of the puffs (normalised distance: < 1 inside)
        acc = np.zeros_like(fr)
        for bx, by, br, ddx, ddy, order in blobs:
            rad = radius(order, br) * rs
            if rad < 1e-3:
                continue
            cx = bx * s + ddx * drift + dx
            cy = by * s + ddy * drift - t * 0.1 + dy
            rr = np.hypot(fx - cx, fy - cy) / rad
            acc += np.exp(-K * (rr - 1.0))
        return 1.0 - np.log(np.maximum(acc, 1e-12)) / K

    warp = (fbm(fx * 1.6 + t * 0.5, fy * 1.6 + t * 0.3, 4, 5, 3) - 0.5) * 0.08
    d = union(0, 0, 1.0) * (1 + warp)
    lit = union(-0.05 * s, -0.07 * s, 0.86) * (1 + warp) < 1.0  # toward the light (top-left)
    high = union(-0.09 * s, -0.12 * s, 0.6) * (1 + warp) < 1.0  # the crescent highlight
    tone = np.where(high, 0.97, np.where(lit, 0.8, 0.55))
    col = np.dstack([tone] * 3)
    outline = (d >= 1.0) & (d < 1.06)
    col = np.where(outline[..., None], np.array([0.24, 0.22, 0.28]), col)
    a = ((d < 1.0) | outline).astype(float) * (1 - np.clip((t - 0.6) / 0.4, 0, 1) * 0.45)
    row, cl = f // 4, f % 4
    sheet[row * N:(row + 1) * N, cl * N:(cl + 1) * N] = np.dstack([col, a])
save("vfx_smoke", sheet)

# ── streak ───────────────────────────────────────────────────────────────────────────────────────────────────────
sx, sy = grid(512, 128)
taper = np.clip(1 - (sy + 1) / 2, 0, 1)  # bright head at the top
width = 0.12 + 0.6 * (1 - taper) ** 2
a = np.exp(-(sx / np.maximum(width, 1e-3) * 2.2) ** 2) * np.clip(1 - np.abs(sy) ** 3, 0, 1) * (0.35 + 0.65 * (1 - taper))
save("vfx_streak", np.dstack([np.ones_like(sx)] * 3 + [a]))

# ── shockwave ring ───────────────────────────────────────────────────────────────────────────────────────────────
x, y = grid(512)
r = np.hypot(x, y)
ring = np.exp(-((r - 0.93) / 0.025) ** 2) + 0.55 * np.exp(-((r - 0.8) / 0.015) ** 2)
save("vfx_ring", np.dstack([np.ones_like(r)] * 3 + [np.clip(ring, 0, 1)]))

# ── scorch decal ─────────────────────────────────────────────────────────────────────────────────────────────────
ang = np.arctan2(y, x)
spikes = 0.55 + 0.25 * fbm(np.cos(ang) * 2, np.sin(ang) * 2, 6, 19, 3) + 0.18 * np.abs(np.sin(ang * 7)) ** 6
burn = np.clip(1 - r / spikes, 0, 1)
grain = fbm(x * 3, y * 3, 6, 23, 4)
a = np.clip(burn ** 0.6 * (0.75 + 0.35 * grain), 0, 1) * 0.92
col = mix(np.array([0.08, 0.06, 0.05]), np.array([0.2, 0.13, 0.08]), np.clip(r * 1.2, 0, 1))
save("vfx_scorch", np.dstack([col, a]))

# ── ember ────────────────────────────────────────────────────────────────────────────────────────────────────────
x, y = grid(64)
r = np.hypot(x, y)
save("vfx_ember", np.dstack([np.ones_like(r)] * 3 + [np.clip(np.exp(-(r / 0.45) ** 2) * 1.2, 0, 1)]))

# ── review previews: the flipbooks over a dark sky-ish grey (white-on-transparent hides on a white viewer) ─────────
BG = np.array([0.22, 0.24, 0.3])
for name in ("vfx_fireball", "vfx_smoke"):
    img = bpy.data.images[name]
    w, h = img.size
    px = np.flipud(np.array(img.pixels[:]).reshape(h, w, 4))
    comp = px[..., :3] * px[..., 3:4] + BG * (1 - px[..., 3:4])
    pv = bpy.data.images.new("preview_" + name, w, h, alpha=False)
    pv.pixels = np.flipud(np.dstack([comp, np.ones((h, w))])).astype(np.float32).ravel()
    pv.filepath_raw = os.path.join(OUT, "preview_" + name + ".png")
    pv.file_format = "PNG"
    pv.save()
print("DONE", OUT, flush=True)
