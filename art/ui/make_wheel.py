"""FUSE VALLEY — the spin wheel's face and pointer, drawn in code (the owner's reference video's prize wheel; no AI art).

  wheel_face.png     1024²  8 bright segments (top segment centred at 12 o'clock), white dividers with an ink line,
                             a soft inner shading per segment, a gold studded rim with an ink outline, a white hub ring
  wheel_pointer.png  256²   a gold pointer (a rounded downward wedge with a gem) with an ink outline

Run: python -I art/ui/make_wheel.py  →  art/out/Wheel/
"""

import math
import os
import struct
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Wheel")
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
    open(path, "wb").write(png)
    print("wrote", os.path.basename(path))


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])


def aa(d, px):
    """Anti-aliased coverage of a signed distance (inside < 0)."""
    return np.clip(0.5 - d / px, 0, 1)


N = 1024
y, x = np.mgrid[0:N, 0:N].astype(float)
cx = cy = N / 2
dx, dy = x + 0.5 - cx, y + 0.5 - cy
r = np.hypot(dx, dy)
ang = (np.degrees(np.arctan2(dx, -dy)) + 360 + 22.5) % 360  # 0° = 12 o'clock, segment 0 centred on it
SEG = ["#FF4F5E", "#FFA22E", "#FFE04A", "#5BD65B", "#38B6FF", "#4F6BFF", "#B05CFF", "#FF6FC8"]
INK = hexc("#14121C")
R_OUT, R_RIM, R_HUB = 500, 448, 70

img = np.zeros((N, N, 4))
# segments with soft radial shading (lighter toward the rim, darker toward the hub) and a gloss band
seg_i = (ang // 45).astype(int) % 8
cols = np.stack([hexc(SEG[i]) for i in range(8)])[seg_i]
shade = 0.78 + 0.22 * np.clip(r / R_RIM, 0, 1)
gloss = 0.12 * np.clip(1 - np.abs((ang % 45) - 14) / 14, 0, 1) * np.clip((r - 140) / 200, 0, 1)
face = np.clip(cols * shade[..., None] + gloss[..., None], 0, 1)
inside = aa(r - R_RIM, 1.5)
img[..., :3] = face
img[..., 3] = inside
# dividers: white lines with a thin ink edge
local = (ang % 45)
dist_line = np.minimum(local, 45 - local) * np.pi / 180 * r  # px from the nearest divider ray
line_w = 9
white = aa(dist_line - line_w / 2, 1.2) * (r < R_RIM) * (r > R_HUB)
ink_l = aa(dist_line - line_w / 2 - 3, 1.2) * (r < R_RIM) * (r > R_HUB) * (1 - white)
img[..., :3] = img[..., :3] * (1 - ink_l[..., None]) + INK * ink_l[..., None]
img[..., :3] = img[..., :3] * (1 - white[..., None]) + 1.0 * white[..., None]
# the gold rim: a band from R_RIM to R_OUT with a bevel, studs, ink outlines
rim = aa(r - R_OUT, 1.5) * (1 - aa(r - R_RIM, 1.5))
t = np.clip((r - R_RIM) / (R_OUT - R_RIM), 0, 1)
gold = hexc("#FFC437")[None, None, :] * (0.8 + 0.35 * np.sin(t * np.pi))[..., None] + np.array([0.12, 0.08, 0.0])[None, None, :] * (dy < 0)[..., None]
gold = np.clip(gold, 0, 1)
img[..., :3] = img[..., :3] * (1 - rim[..., None]) + gold * rim[..., None]
img[..., 3] = np.maximum(img[..., 3], rim)
for k in range(24):  # studs on the rim
    a = math.radians(k * 15)
    sx, sy = cx + math.sin(a) * (R_RIM + R_OUT) / 2, cy - math.cos(a) * (R_RIM + R_OUT) / 2
    d = np.hypot(x + 0.5 - sx, y + 0.5 - sy) - 13
    stud = aa(d, 1.2)
    hl = aa(np.hypot(x + 0.5 - sx + 4, y + 0.5 - sy + 4) - 5, 1.2)
    img[..., :3] = img[..., :3] * (1 - stud[..., None]) + hexc("#FFF2B0") * stud[..., None]
    img[..., :3] = img[..., :3] * (1 - hl[..., None]) + 1.0 * hl[..., None]
    ring = aa(np.abs(d + 1) - 2, 1.0)
    img[..., :3] = img[..., :3] * (1 - ring[..., None]) + hexc("#B07A10") * ring[..., None]
# ink outlines on the rim's outer and inner edge and round the hub
for rr, wd in ((R_OUT - 4, 8), (R_RIM, 5)):
    o = aa(np.abs(r - rr) - wd / 2, 1.2)
    img[..., :3] = img[..., :3] * (1 - o[..., None]) + INK * o[..., None]
hub = aa(r - R_HUB, 1.5)
img[..., :3] = img[..., :3] * (1 - hub[..., None]) + hexc("#FFFFFF") * hub[..., None]
o = aa(np.abs(r - R_HUB) - 3, 1.2)
img[..., :3] = img[..., :3] * (1 - o[..., None]) + INK * o[..., None]
img[..., 3] = np.clip(img[..., 3] + aa(r - R_OUT, 1.5), 0, 1)
save_png(os.path.join(OUT, "wheel_face.png"), img)

# ── the pointer: a rounded gold wedge pointing down, with a red gem ─────────────────────────────────────────────
M = 256
y, x = np.mgrid[0:M, 0:M].astype(float)
px, py = x + 0.5 - M / 2, y + 0.5
# wedge: inside if below the top cap and within the narrowing sides
half = 70 * (1 - np.clip((py - 40) / 190, 0, 1))
d_side = np.abs(px) - half
d_top = 40 - py
d_bot = py - 236
cap = np.hypot(px, py - 70) - 70
d = np.maximum(np.minimum(np.maximum(d_side, d_top), cap), d_bot)
cov = aa(d, 1.5)
outline = aa(d - 9, 1.5)
pimg = np.zeros((M, M, 4))
shadeP = np.clip(1.1 - py / 300 + px / 600, 0.6, 1.2)
pimg[..., :3] = INK
pimg[..., 3] = outline
gcol = np.clip(hexc("#FFC437")[None, None, :] * shadeP[..., None], 0, 1)
pimg[..., :3] = pimg[..., :3] * (1 - cov[..., None]) + gcol * cov[..., None]
gem = aa(np.hypot(px, py - 82) - 26, 1.2)
gring = aa(np.abs(np.hypot(px, py - 82) - 26) - 3, 1.2)
pimg[..., :3] = pimg[..., :3] * (1 - gem[..., None]) + hexc("#E8322B") * gem[..., None]
gl = aa(np.hypot(px + 8, py - 74) - 7, 1.2)
pimg[..., :3] = pimg[..., :3] * (1 - gl[..., None]) + 1.0 * gl[..., None]
pimg[..., :3] = pimg[..., :3] * (1 - gring[..., None]) + INK * gring[..., None]
save_png(os.path.join(OUT, "wheel_pointer.png"), pimg)
