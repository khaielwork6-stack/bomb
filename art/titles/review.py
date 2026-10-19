"""Review sheet for the title art: each title over a blurred in-game frame (how players see it), optionally under a
reference image. Run: blender -b --factory-startup --python art/titles/review.py -- <bg.png> <out.png> [ref.png]"""
import os
import sys

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1 :]
BG, OUTP = argv[0], argv[1]
REF = argv[2] if len(argv) > 2 else None
TITLES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "Titles")


def load(p):
    img = bpy.data.images.load(os.path.abspath(p))
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return a


def resize(a, w, h):
    ys = (np.arange(h) * a.shape[0] / h).astype(int)
    xs = (np.arange(w) * a.shape[1] / w).astype(int)
    return a[ys][:, xs]


def blur(m, r):
    out = m.copy()
    for _ in range(3):
        for axis in (0, 1):
            pad = [(r + 1, r) if i == axis else (0, 0) for i in range(out.ndim)]
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            sl = [slice(None)] * out.ndim
            sl2 = [slice(None)] * out.ndim
            sl[axis] = slice(2 * r + 1, None)
            sl2[axis] = slice(None, -2 * r - 1)
            out = (c[tuple(sl)] - c[tuple(sl2)]) / (2 * r + 1)
    return out


W = 1100
panels = []
if REF:
    r = load(REF)
    panels.append(resize(r, W, int(r.shape[0] * W / r.shape[1]))[..., :3])
bg = load(BG)[..., :3]
for f in sorted(os.listdir(TITLES)):
    if not f.endswith(".png") or f.startswith("_"):
        continue
    t = load(os.path.join(TITLES, f))
    th, tw = t.shape[:2]
    scale = min(1.0, (W * 0.8) / tw)
    t = resize(t, int(tw * scale), int(th * scale))
    th, tw = t.shape[:2]
    H = th + 120
    b = blur(resize(bg, W, H), 9) * 0.85
    y0, x0 = (H - th) // 2, (W - tw) // 2
    al = t[..., 3:4]
    b[y0 : y0 + th, x0 : x0 + tw] = t[..., :3] * al + b[y0 : y0 + th, x0 : x0 + tw] * (1 - al)
    panels.append(b)
sheet = np.concatenate(panels[::-1], axis=0)  # Blender rows are bottom-up: reverse so the first panel is on top
h = sheet.shape[0]
out = np.ones((h, W, 4), dtype=np.float32)
out[..., :3] = sheet
img = bpy.data.images.new("sheet", W, h, alpha=True)
img.pixels = out.ravel()
img.filepath_raw = os.path.abspath(OUTP)
img.file_format = "PNG"
img.save()
print("SHEET", OUTP, flush=True)
