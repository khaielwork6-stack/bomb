"""FUSE VALLEY — round-HUD textures, drawn in code (Asset Bible §6.6; DECISIONS 2026-10-17: no AI art).

  hud_braid.png     128 x 32  a tileable braided fuse cord (3-strand braid, lit from above, charred edge lines)
  hud_hazard.png    64 x 64   a tileable yellow / ink hazard-stripe tile (45°), with a soft bevel on each stripe
  hud_vignette.png  512 x 512 a white radial edge mask (soft inside, a faint hazard-stripe hint at the very edge);
                    tinted Detonate red in game for the Carrier vignette

Run: python -I art/ui/make_hud.py   →  art/out/Hud/
"""

import os
import struct
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Hud")
os.makedirs(OUT, exist_ok=True)


def save_png(path, rgba):
    h, w, _ = rgba.shape
    data = np.clip(rgba * 255 + 0.5, 0, 255).astype(np.uint8)
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", os.path.basename(path), w, "x", h)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])


# ── braid: strands as sine bands crossing, each a rounded tube shaded by its local normal ────────────────────────
W, H = 128, 32
y, x = np.mgrid[0:H, 0:W].astype(float)
v = (y + 0.5) / H * 2 - 1  # -1 top .. 1 bottom
img = np.zeros((H, W, 4))
base = hexc("#E2C08A")
dark = hexc("#8C6236")
best_depth = np.full((H, W), -9.0)
for k in range(3):
    phase = 2 * np.pi * k / 3
    centre = 0.55 * np.sin(2 * np.pi * x / W * 2 + phase)  # 2 waves per tile → tileable
    depth = np.cos(2 * np.pi * x / W * 2 + phase)  # which strand is on top
    d = np.abs(v - centre) / 0.42
    inside = d < 1
    shade = np.sqrt(np.clip(1 - d**2, 0, 1))  # tube profile
    top = inside & (depth > best_depth)
    col = base * (0.55 + 0.45 * shade[..., None]) + np.array([0.08, 0.06, 0.03]) * (v[..., None] < centre[..., None])
    # fibre streaks along the strand
    fib = 0.06 * np.sin((x + y * 3 + k * 40) * 1.7)
    col = np.clip(col + fib[..., None], 0, 1)
    img[top, :3] = col[top]
    img[top, 3] = 1
    best_depth = np.where(top, depth, best_depth)
gaps = img[..., 3] == 0
img[gaps, :3] = dark * 0.7
img[gaps, 3] = 1
# a charred line at the top and bottom edge
edge = (np.abs(v) > 0.86)[..., None]
img[..., :3] = np.where(edge, img[..., :3] * 0.55, img[..., :3])
save_png(os.path.join(OUT, "hud_braid.png"), img)

# ── hazard stripes ───────────────────────────────────────────────────────────────────────────────────────────────
N = 64
y, x = np.mgrid[0:N, 0:N].astype(float)
t = ((x + y) / N * 2) % 1.0  # 2 stripes per tile along the diagonal → tileable
yellow = hexc("#FFD23A")
ink = hexc("#1A1622")
s = t < 0.5
band = np.where(s, t / 0.5, (t - 0.5) / 0.5)
bevel = 1 - 0.18 * np.abs(band - 0.5) * 2
col = np.where(s[..., None], yellow * bevel[..., None], ink * (0.9 + 0.2 * bevel[..., None]))
img = np.dstack([col, np.ones((N, N))])
save_png(os.path.join(OUT, "hud_hazard.png"), img)

# ── vignette mask ────────────────────────────────────────────────────────────────────────────────────────────────
N = 512
y, x = np.mgrid[0:N, 0:N].astype(float)
u = (x + 0.5) / N * 2 - 1
w = (y + 0.5) / N * 2 - 1
# a rounded-rectangle distance (superellipse) so it hugs the screen edges, not a circle
r = (np.abs(u) ** 4 + np.abs(w) ** 4) ** 0.25
a = np.clip((r - 0.62) / 0.4, 0, 1) ** 1.6
stripes = ((x + y) / 22) % 1.0 < 0.5
hint = np.where((r > 0.95) & stripes, 0.25, 0.0)
alpha = np.clip(a + hint, 0, 1)
img = np.dstack([np.ones((N, N)), np.ones((N, N)), np.ones((N, N)), alpha])
save_png(os.path.join(OUT, "hud_vignette.png"), img)
