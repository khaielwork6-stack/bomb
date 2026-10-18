"""FUSE VALLEY — effects polish textures, drawn in code (Asset Bible §5.2 defuse, §5.3 pass, ART_BACKLOG "Effects polish";
no AI art). Toy-arcade look: soft shading, a thin ink edge, bright readable shapes.

  vfx_steam_curl.png   1024²  4×4 flipbook (OneShot, 16 frames): a white steam wisp that rises, curls over into a
                              spiral and thins away — the defuse's snuff (replaces the reused Smoke sheet)
  vfx_rays.png          512²  a soft 12-ray light burst, white (tinted gold in game) — the clutch defuse's ray burst
  vfx_pass_ribbon.png  512×64 the pass arc's ribbon: a hot white core in a gold→orange band with spark dots, fading
                              out toward the tail (U = 0 is the head)

Run: python -I art/vfx/make_polish.py  →  art/out/VfxPolish/
"""

import math
import os
import struct
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "VfxPolish")
os.makedirs(OUT, exist_ok=True)
INK = np.array([0.08, 0.07, 0.11])


def save_png(path, rgba):
    h, w, _ = rgba.shape
    data = np.clip(rgba * 255 + 0.5, 0, 255).astype(np.uint8)
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)
    print("wrote", os.path.basename(path))


def aa(d, px=1.2):
    return np.clip(0.5 - d / px, 0, 1)


def over(dst, rgb, a):
    """Composite colour `rgb` (3,) or (h,w,3) with coverage `a` over premultiplied-free RGBA `dst`."""
    a = a[..., None]
    out_a = a + dst[..., 3:4] * (1 - a)
    col = (np.broadcast_to(rgb, dst[..., :3].shape) * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-6)
    dst[..., :3] = col
    dst[..., 3:4] = out_a


# ── 1. The steam curl flipbook ──────────────────────────────────────────────────────────────────────────────────
def steam_frame(t):
    """One 256² frame at time t in [0, 1]: a puffy cloud column that billows up, rolls over into a curl at the top and
    thins away (lumpy cumulus lobes along a rising path, lit from the top-left, a soft cool edge)."""
    N = 256
    y, x = np.mgrid[0:N, 0:N].astype(float) + 0.5
    img = np.zeros((N, N, 4))
    rng = np.random.default_rng(11)
    lobes = []
    S = 26
    for i in range(S):
        u = i / (S - 1)
        if u < 0.5:
            k = u / 0.5
            px, py = 118 + 8 * math.sin(k * 2.5), 222 - k * 104
        else:
            k = (u - 0.5) / 0.5
            ang = math.pi + k * 1.35 * math.pi
            rad = 38 * (1 - 0.35 * k)
            px, py = 118 + 38 + math.cos(ang) * rad, 112 - math.sin(ang) * rad
        base = 20 + 18 * u
        lobes.append((px, py, base, u))
        for _ in range(2):  # side lobes make it lumpy
            a = rng.uniform(0, 2 * math.pi)
            lobes.append((px + math.cos(a) * base * 0.55, py + math.sin(a) * base * 0.55, base * rng.uniform(0.45, 0.7), u))
    reveal = min(1.0, 0.15 + t * 1.6)  # the column billows up its path…
    fade = max(0.0, (t - 0.5) / 0.5)  # …then dissolves from the bottom up and shrinks
    d_min = np.full((N, N), 1e9)
    shade = np.zeros((N, N))
    grow = 0.55 + 0.45 * min(1.0, t * 3)
    for px, py, base, u in lobes:
        if u > reveal or u < fade * 1.05 - 0.05:
            continue
        r = base * grow * (1 - 0.45 * fade)
        d = np.hypot(x - px, y - py) - r
        closer = d < d_min
        d_min = np.where(closer, d, d_min)
        lx = (x - px + r * 0.4) / max(r, 1)
        ly = (y - py + r * 0.4) / max(r, 1)
        shade = np.where(closer, np.clip(1 - np.hypot(lx, ly) * 0.5, 0, 1), shade)
    body = aa(d_min, 1.6)
    edge = aa(np.abs(d_min + 2) - 2, 1.2) * 0.5
    col = np.stack([0.78 + 0.22 * shade, 0.84 + 0.16 * shade, 0.91 + 0.09 * shade], -1)
    a = 0.95 * (1 - fade) ** 0.7
    over(img, col, body * a)
    over(img, np.array([0.58, 0.66, 0.78]), edge * a)
    return img


sheet = np.zeros((1024, 1024, 4))
for f in range(16):
    fr = steam_frame(f / 15)
    r, c = divmod(f, 4)
    sheet[r * 256 : (r + 1) * 256, c * 256 : (c + 1) * 256] = fr
save_png(os.path.join(OUT, "vfx_steam_curl.png"), sheet)

# ── 2. The light-ray burst ──────────────────────────────────────────────────────────────────────────────────────
N = 512
y, x = np.mgrid[0:N, 0:N].astype(float) + 0.5
dx, dy = x - N / 2, y - N / 2
r = np.hypot(dx, dy) / (N / 2)
ang = np.arctan2(dy, dx)
rays = np.clip(np.cos(ang * 12) * 0.5 + 0.5, 0, 1) ** 6  # 12 sharp rays
rays = np.maximum(rays, 0.65 * np.clip(np.cos(ang * 12 + math.pi) * 0.5 + 0.5, 0, 1) ** 14)  # 12 thinner between
a = rays * np.clip(1 - r, 0, 1) ** 1.4 + np.clip(1 - r * 3.2, 0, 1) ** 2  # a hot core
img = np.zeros((N, N, 4))
img[..., :3] = 1.0
img[..., 3] = np.clip(a, 0, 1)
save_png(os.path.join(OUT, "vfx_rays.png"), img)

# ── 3. The pass ribbon ──────────────────────────────────────────────────────────────────────────────────────────
W, H = 512, 64
y, x = np.mgrid[0:H, 0:W].astype(float) + 0.5
u, v = x / W, np.abs(y - H / 2) / (H / 2)  # u: head → tail; v: centre → edge
width = 0.95 - 0.55 * u  # tapers toward the tail
band = aa((v - width) * H / 2, 1.5)
core = aa((v - width * 0.38) * H / 2, 2.0)
gold = np.array([1.0, 0.82, 0.25])
orange = np.array([1.0, 0.42, 0.12])
col = gold[None, None, :] * (1 - v[..., None]) + orange[None, None, :] * v[..., None]
img = np.zeros((H, W, 4))
over(img, col, band * np.clip(1 - u, 0, 1) ** 0.8)
over(img, np.array([1.0, 0.98, 0.9]), core * np.clip(1 - u * 1.2, 0, 1))
rng = np.random.default_rng(7)
for _ in range(26):  # spark dots shed along it
    sx, sy = rng.uniform(40, W - 20), rng.uniform(6, H - 6)
    rad = rng.uniform(1.5, 3.2) * (1 - sx / W * 0.6)
    over(img, np.array([1.0, 0.9, 0.5]), aa(np.hypot(x - sx, y - sy) - rad, 1.0) * (1 - sx / W))
save_png(os.path.join(OUT, "vfx_pass_ribbon.png"), img)
