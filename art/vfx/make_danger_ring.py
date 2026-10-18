"""FUSE VALLEY — the Danger Ring (GDD F-BOMB-11, Asset Bible §5: hand-designed, no stock, no AI).

vfx_danger_ring.png  1024² ground decal, white (the Decal's Color3 tints it to the bomb's stage colour):
  • the band: 20 chunky fuse-link segments with rounded ends (they crawl round the ring in game, like a fuse burning),
  • each link has a crisp Ink rim (the game's sticker outline, like the smack burst) and casts its own tight, soft
    Ink shadow (the gaps stay clear), so the ring reads on any floor, even an orange logo under a HOT ring,
  • a hairline inner ring at 0.84 r and a faint zone tint inside it (the danger area has volume, never a hard disc),
  • four inward notches on the cardinal points (a sight: "this is the line").
Drawn at 4× and box-filtered down (premultiplied), so every edge is anti-aliased.
Also writes art/out/Vfx/preview_vfx_danger_ring.png: the ring tinted LIT / HOT / CRITICAL on concrete and on night.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python art/vfx/make_danger_ring.py
"""

import math
import os

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Vfx")
os.makedirs(OUT, exist_ok=True)

INK = np.array([0x16, 0x12, 0x1C]) / 255
N = 1024
SS = 4


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def write(name, rgba):
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = np.flipud(np.clip(rgba, 0, 1)).astype(np.float32).ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("wrote", name, flush=True)


# Drawn in horizontal strips at SS× so the supersampled canvas never sits in memory all at once.
BAND_IN, BAND_OUT = 0.855, 0.975  # the link band (radius as a fraction of the half-size): bold enough for a phone
SEGMENTS = 20
GAP = 0.3  # fraction of each segment's arc left open
HAIR_R, HAIR_W = 0.8, 0.009
NOTCH_DEPTH, NOTCH_W = 0.1, 0.06

out = np.zeros((N, N, 4))
STRIP = 64  # output rows per strip
for r0 in range(0, N, STRIP):
    rows = np.arange(r0 * SS, (r0 + STRIP) * SS)
    cols = np.arange(N * SS)
    yy, xx = np.meshgrid(rows, cols, indexing="ij")
    x = (xx + 0.5) / (N * SS) * 2 - 1
    y = (yy + 0.5) / (N * SS) * 2 - 1
    r = np.hypot(x, y)
    th = np.arctan2(y, x)

    # the links: a rounded-capsule profile in (angle, radius) space
    seg = (th / (2 * math.pi) % 1.0) * SEGMENTS
    u = seg - np.floor(seg)  # 0..1 along this link's arc
    half = (1 - GAP) / 2
    du = np.abs(u - 0.5)  # distance from the link's centre, in arc units
    mid = (BAND_IN + BAND_OUT) / 2
    thick = (BAND_OUT - BAND_IN) / 2
    arc_len = 2 * math.pi * mid / SEGMENTS  # link length in radius units
    along = np.maximum(du - (half - thick / arc_len), 0) * arc_len  # past the straight part → into the round cap
    dist = np.hypot(along, r - mid)  # capsule distance
    link = dist < thick
    rim = (dist >= thick) & (dist < thick + 0.016)  # the Ink outline round every link

    # each link's own soft shadow: the capsule grown by a few % and feathered (the gaps between links stay clear)
    shadow = smoothstep(thick + 0.035, thick, dist) * 0.55

    hair = np.abs(r - HAIR_R) < HAIR_W
    # zone tint: faint inside the hairline, strongest near it, never a hard disc
    zone = smoothstep(0.0, HAIR_R, r) ** 2.4 * 0.2 * (r < HAIR_R)

    # four inward notches (small triangles pointing at the centre) between the hairline and the band
    notch = np.zeros_like(r, dtype=bool)
    for k in range(4):
        a = k * math.pi / 2
        al = x * math.cos(a) + y * math.sin(a)  # along the spoke
        pe = -x * math.sin(a) + y * math.cos(a)  # across it
        tip = HAIR_R - NOTCH_DEPTH
        t = (al - tip) / NOTCH_DEPTH  # 0 at the tip, 1 at the hairline
        notch |= (t > 0) & (t < 1) & (np.abs(pe) < NOTCH_W * t)

    white = link | hair | notch
    a = np.where(white, 1.0, np.where(rim, 0.92, np.maximum(shadow, zone)))
    col = np.where(
        white[..., None], np.ones(3), np.where((rim | (shadow > zone))[..., None], INK, np.ones(3))
    )
    pm = np.dstack([col * a[..., None], a]).reshape(STRIP, SS, N, SS, 4).mean(axis=(1, 3))
    alpha = pm[..., 3:4]
    rgb = np.where(alpha > 1e-4, pm[..., :3] / np.maximum(alpha, 1e-4), 0)
    out[r0:r0 + STRIP] = np.dstack([rgb, alpha])
    print("strip", r0, flush=True)

write("vfx_danger_ring", out)

# review: the ring tinted LIT / HOT / CRITICAL on concrete (top) and at night (bottom), as the game's Decal does
STAGES = [np.array([0xFF, 0xD8, 0x4A]), np.array([0xFF, 0x94, 0x42]), np.array([0xE8, 0x32, 0x2B])]
GROUNDS = [np.array([0.62, 0.6, 0.58]), np.array([0.09, 0.09, 0.14])]
small = out[::2, ::2]
h, w = small.shape[:2]
pv = np.zeros((h * 2, w * 3, 3))
for gi, g in enumerate(GROUNDS):
    for si, s in enumerate(STAGES):
        tint = small[..., :3] * (s / 255)
        a = small[..., 3:4]
        pv[gi * h:(gi + 1) * h, si * w:(si + 1) * w] = tint * a + g * (1 - a)
img = bpy.data.images.new("preview_vfx_danger_ring", w * 3, h * 2, alpha=False)
img.pixels = np.flipud(np.dstack([pv, np.ones((h * 2, w * 3))])).astype(np.float32).ravel()
img.filepath_raw = os.path.join(OUT, "preview_vfx_danger_ring.png")
img.file_format = "PNG"
img.save()
print("DONE", flush=True)
