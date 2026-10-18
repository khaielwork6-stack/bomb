"""FUSE VALLEY — the slap's "smack" burst (GDD F-BOMB-10, Asset Bible §5: hand-designed, no stock, no AI).

vfx_smack.png  1024² 4×4 flipbook (ParticleFlipbookLayout.Grid4x4, OneShot): a comic impact star in the explosion
stack's toon language (white core → Spark → Fuse bands inside a thick Ink outline). Nine uneven spikes pop in with an
overshoot, a ring of thin speed strokes flies out between them, then the spikes pull in and the whole star snaps shut
into its hot core and is gone (a clean exit: no holes or leftovers). Colours baked in. A slight turn across the frames keeps it from looking stamped.
Every frame is drawn at 4× and box-filtered down (premultiplied), so the Ink edges are anti-aliased, never jagged.
Also writes art/out/Vfx/preview_vfx_smack.png (on a dark and a light ground) for review.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python art/vfx/make_smack.py
"""

import math
import os

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Vfx")
os.makedirs(OUT, exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


INK = hexc("#16121C")
SPARK = hexc("#FFD84A")
FUSE = hexc("#FF6A1F")
WHITE = np.array([1.0, 0.98, 0.9])


def save(name, rgba):
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = np.flipud(np.clip(rgba, 0, 1)).astype(np.float32).ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("wrote", name, flush=True)


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


RNG = np.random.default_rng(20261018)
SPIKES = 9
amp = 0.55 + RNG.random(SPIKES) * 0.45  # every spike its own length…
lean = (RNG.random(SPIKES) - 0.5) * 0.35  # …and a slight lean, so the star is drawn, not stamped

N = 256
SS = 4  # supersampling: draw at N*SS, filter down to N
fx, fy = grid(N * SS)
sheet = np.zeros((N * 4, N * 4, 4))
for f in range(16):
    t = f / 15
    # pop in with an overshoot (frames 0–3), settle, then pull in
    pop = np.interp(f, [0, 1, 2, 3, 4, 9, 12, 14, 15], [0.35, 0.95, 1.12, 1.02, 1.0, 0.94, 0.62, 0.26, 0.0])
    retract = smooth((t - 0.3) / 0.6)  # the spikes pull in and thin from ~frame 5
    turn = math.radians(-6 + 10 * t)
    ca, sa = math.cos(turn), math.sin(turn)
    x = fx * ca - fy * sa
    y = fx * sa + fy * ca
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    # star radius: a round body plus sharp triangular spikes
    seg = (th / (2 * math.pi) % 1.0) * SPIKES
    k = np.floor(seg).astype(int) % SPIKES
    u = seg - np.floor(seg)
    u = np.clip(u + lean[k] * (1 - np.abs(2 * u - 1)), 0, 1)
    peak = (1 - np.abs(2 * u - 1)) ** 2.2
    body_r = 0.34 * pop * (1 - 0.25 * retract)
    spike_r = 0.5 * pop * amp[k] * (1 - 0.8 * retract)
    edge = body_r + spike_r * peak
    re = r / np.maximum(edge, 1e-3)
    # toon bands: white core → Spark → Fuse, the core shrinking as it cools
    c_core = 0.42 * (1 - 0.6 * t)
    c_mid = 0.7 * (1 - 0.25 * t)
    col = np.where((re < c_core)[..., None], WHITE, np.where((re < c_mid)[..., None], SPARK, FUSE))
    body = re < 1.0
    outline = (re >= 1.0) & (re < 1.0 + 0.11 + 0.05 * (1 - pop))
    col = np.where(outline[..., None], INK, col)
    shape = body | outline
    if pop <= 0:
        shape = np.zeros_like(body)
    # speed dashes: short white wedges with an Ink rim, flying out between the spikes (frames 1–9)
    dash_t = np.clip((f - 1) / 8, 0, 1)
    if 0 < dash_t < 1:
        for j in range(SPIKES):
            a = (j + 0.5) / SPIKES * 2 * math.pi + turn
            along = fx * math.cos(a) + fy * math.sin(a)
            perp = -fx * math.sin(a) + fy * math.cos(a)
            start = 0.52 + 0.36 * smooth(dash_t)
            length = 0.26 * (1 - dash_t) + 0.05
            v = (along - start) / length  # 0..1 along the stroke, thick at the inner end
            width = 0.022 * np.clip(1 - v, 0, 1) ** 0.8 * (1 - 0.5 * dash_t)
            inside = (v > 0) & (v < 1) & (np.abs(perp) < width)
            rimmed = (v > -0.05) & (v < 1.04) & (np.abs(perp) < width + 0.014) & ~inside
            col = np.where(inside[..., None], WHITE, col)
            col = np.where((rimmed & ~shape)[..., None], INK, col)
            shape = shape | inside | rimmed
    a = shape.astype(float)
    # box-filter the supersampled frame down (premultiplied, so edges blend into the Ink, not into black)
    pm = np.dstack([col * a[..., None], a]).reshape(N, SS, N, SS, 4).mean(axis=(1, 3))
    alpha = pm[..., 3:4]
    rgb = np.where(alpha > 1e-4, pm[..., :3] / np.maximum(alpha, 1e-4), 0)
    row, cl = f // 4, f % 4
    sheet[row * N:(row + 1) * N, cl * N:(cl + 1) * N] = np.dstack([rgb, alpha])
save("vfx_smack", sheet)

# review preview: the sheet on a dark ground (left) and a light ground (right)
h, w = sheet.shape[:2]
pv = np.zeros((h, w * 2, 3))
for i, bg in enumerate((np.array([0.16, 0.15, 0.2]), np.array([0.86, 0.84, 0.8]))):
    pv[:, i * w:(i + 1) * w] = sheet[..., :3] * sheet[..., 3:4] + bg * (1 - sheet[..., 3:4])
img = bpy.data.images.new("preview_vfx_smack", w * 2, h, alpha=False)
img.pixels = np.flipud(np.dstack([pv, np.ones((h, w * 2))])).astype(np.float32).ravel()
img.filepath_raw = os.path.join(OUT, "preview_vfx_smack.png")
img.file_format = "PNG"
img.save()
print("DONE", flush=True)
