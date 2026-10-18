"""FUSE VALLEY — the juke's floor burst, drawn in code (docs/VIDEO2_NOTES.md §4; the reference's yellow lightning
zigzags that splash across the floor on a juke; no AI art).

  vfx_juke_bolt.png  512×256  a chunky yellow lightning zigzag ending in an arrowhead (pointing +U), a white hot core
                             down its middle and a soft orange edge; laid flat on the floor in game, tinted / faded there

Run: python -I art/vfx/make_juke.py  →  art/out/VfxJuke/
"""

import os
import struct
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "VfxJuke")
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


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def tri_dist(px, py, a, b, c):
    """Signed distance to a triangle (negative inside)."""
    def edge(p0, p1):
        return (px - p0[0]) * (p1[1] - p0[1]) - (py - p0[1]) * (p1[0] - p0[0])
    e0, e1, e2 = edge(a, b), edge(b, c), edge(c, a)
    inside = ((e0 <= 0) & (e1 <= 0) & (e2 <= 0)) | ((e0 >= 0) & (e1 >= 0) & (e2 >= 0))
    d = np.minimum(np.minimum(seg_dist(px, py, *a, *b), seg_dist(px, py, *b, *c)), seg_dist(px, py, *c, *a))
    return np.where(inside, -d, d)


def aa(d, px=1.4):
    return np.clip(0.5 - d / px, 0, 1)


W, H = 512, 256
y, x = np.mgrid[0:H, 0:W].astype(float) + 0.5
# the zigzag: tail (left) → head (right), thickening toward the head
pts = [(20, 150), (130, 92), (170, 160), (290, 82), (330, 150), (410, 112)]
d = np.full((H, W), 1e9)
width = np.zeros((H, W))
for i in range(len(pts) - 1):
    (ax, ay), (bx, by) = pts[i], pts[i + 1]
    dd = seg_dist(x, y, ax, ay, bx, by)
    w = 10 + 7 * i  # thicker toward the head
    closer = dd - w < d
    d = np.where(closer, dd - w, d)
    width = np.where(closer, w, width)
head = tri_dist(x, y, (392, 52), (500, 120), (420, 190))
body = np.minimum(d, head)
core = np.minimum(d + width * 0.55, head + 18)

img = np.zeros((H, W, 4))
orange = np.array([1.0, 0.62, 0.12])
yellow = np.array([1.0, 0.86, 0.18])
white = np.array([1.0, 0.98, 0.86])
edge_a = aa(body - 5, 2.0)  # a soft orange rim just outside
img[..., :3] = orange
img[..., 3] = edge_a * 0.7
fill = aa(body, 1.4)
img[..., :3] = img[..., :3] * (1 - fill[..., None]) + yellow * fill[..., None]
img[..., 3] = np.maximum(img[..., 3], fill)
c = aa(core, 2.0)
img[..., :3] = img[..., :3] * (1 - c[..., None]) + white * c[..., None]
save_png(os.path.join(OUT, "vfx_juke_bolt.png"), img)
