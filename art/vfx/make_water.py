"""FUSE VALLEY — the Quarry's flowing water textures (Asset Bible §5, the Quality Bar: hand-designed, procedural).

Toon water for Roblox Beams (a Beam scrolls its texture on its own: TextureSpeed), all tileable along V (the flow):
  water_fall_body.png    256×512  the falling sheet: soft vertical bands, posterized to 3 tones, mostly opaque
                                  (greyscale; the Beam's Color tints it blue)
  water_fall_streaks.png 256×512  bright foam streaks running down the sheet (white on alpha)
  water_foam.png         256×256  cartoon foam blobs with a thin dark-blue outline (the splash and the pool's foam)
  water_ripple.png       256×256  wavy foam lines across the flow (the pool / stream surface)
Plus a preview sheet (art/out/Water/preview.png) on dark and light.

Run (system Python, numpy + Pillow): python -I art/vfx/make_water.py
"""

import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Water")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261018)


def periodic_noise(w, h, octaves, rng, px=1, py=1, vertical=False):
    """Smooth noise that tiles: a sum of sines with integer periods across the image."""
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        for _ in range(3):
            fx = rng.integers(1, 3 + o * 3) * px
            fy = rng.integers(0, 2) if vertical else rng.integers(1, 3 + o * 3) * py
            ph = rng.uniform(0, math.tau)
            out += amp * np.sin(math.tau * (fx * u + fy * v) + ph)
        amp *= 0.5
    out -= out.min()
    return out / max(out.max(), 1e-6)


def save(name, rgba):
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    path = os.path.join(OUT, name)
    img.save(path)
    print("WROTE", path)
    return img


def fall_body():
    w, h = 256, 512
    # columns of water: noise stretched along V (low V frequency → long vertical bands), posterized to 3 tones
    n = periodic_noise(w, h, 3, RNG, px=3, py=1, vertical=True)
    tone = np.where(n > 0.66, 1.0, np.where(n > 0.33, 0.86, 0.72))
    rgba = np.zeros((h, w, 4))
    rgba[..., 0:3] = tone[..., None]
    # thin bright edges where the tone steps (a toon highlight)
    edge = np.abs(np.diff(tone, axis=1, prepend=tone[:, :1])) > 0
    rgba[edge, 0:3] = 1.0
    xx = np.arange(w) / (w - 1)
    side = np.clip(np.minimum(xx, 1 - xx) / 0.08, 0, 1)  # soft at the sheet's sides
    rgba[..., 3] = (0.82 + 0.12 * n) * side[None, :]
    return save("water_fall_body.png", rgba)


def fall_streaks():
    w, h = 256, 512
    rgba = np.zeros((h, w, 4))
    rgba[..., 0:3] = 1.0
    alpha = np.zeros((h, w))
    yy = np.arange(h)
    for _ in range(40):
        x0 = RNG.uniform(10, w - 10)
        width = RNG.uniform(3.0, 9.0)
        length = RNG.uniform(0.25, 0.7) * h
        start = RNG.uniform(0, h)
        xs = np.arange(w)
        across = np.clip(1 - np.abs(xs - x0) / width, 0, 1)
        # along: a soft dash that wraps vertically (tileable), brightest at its head
        d = (yy - start) % h
        along = np.where(d < length, np.clip(1 - d / length, 0, 1) ** 0.6, 0)
        alpha = np.maximum(alpha, along[:, None] * across[None, :])
    alpha = np.where(alpha > 0.55, 1.0, np.where(alpha > 0.2, 0.55, 0.0))  # toon steps
    rgba[..., 3] = alpha
    return save("water_fall_streaks.png", rgba)


def foam():
    w = h = 256
    yy, xx = np.mgrid[0:h, 0:w]
    field = np.zeros((h, w))
    for _ in range(34):
        cx, cy = RNG.uniform(0, w), RNG.uniform(0, h)
        r = RNG.uniform(10, 30)
        # wrap distances so blobs tile
        dx = np.minimum(np.abs(xx - cx), w - np.abs(xx - cx))
        dy = np.minimum(np.abs(yy - cy), h - np.abs(yy - cy))
        field = np.maximum(field, 1 - np.hypot(dx, dy) / r)
    inside = field > 0.25
    rim = (field > 0.18) & ~inside
    rgba = np.zeros((h, w, 4))
    rgba[inside] = [1.0, 1.0, 1.0, 1.0]
    rgba[rim] = [0.55, 0.85, 0.95, 1.0]  # a light blue outline
    shade = inside & (field < 0.45)
    rgba[shade, 0:3] = [0.86, 0.95, 1.0]
    return save("water_foam.png", rgba)


def ripple():
    w = h = 256
    yy, xx = np.mgrid[0:h, 0:w]
    rgba = np.zeros((h, w, 4))
    rgba[..., 0:3] = 1.0
    alpha = np.zeros((h, w))
    for k in range(5):
        base = (k + 0.5) * h / 5
        amp = RNG.uniform(4, 9)
        freq = RNG.integers(1, 4)
        ph = RNG.uniform(0, math.tau)
        y = base + amp * np.sin(math.tau * freq * xx / w + ph)
        d = np.abs(yy - y)
        d = np.minimum(d, h - d)
        line = np.clip(1 - d / 4.2, 0, 1)
        # break the lines into dashes so they read as moving foam, not stripes
        dash = (np.sin(math.tau * RNG.integers(2, 5) * xx / w + RNG.uniform(0, math.tau)) > -0.3).astype(float)
        alpha = np.maximum(alpha, line * dash)
    rgba[..., 3] = np.where(alpha > 0.5, 0.9, np.where(alpha > 0.15, 0.4, 0))
    return save("water_ripple.png", rgba)


def preview(imgs):
    tiles = [i.convert("RGBA").resize((160, 160 if i.height == i.width else 320)) for i in imgs]
    W = sum(t.width for t in tiles) + 20 * (len(tiles) + 1)
    H = 2 * 340 + 30
    sheet = Image.new("RGBA", (W, H), (40, 44, 70, 255))
    x = 20
    for t in tiles:
        for row, bg in enumerate([(40, 44, 70, 255), (56, 140, 200, 255)]):
            y = 10 + row * 350
            cell = Image.new("RGBA", (t.width, t.height), bg)
            cell.alpha_composite(t)
            sheet.alpha_composite(cell, (x, y))
        x += t.width + 20
    path = os.path.join(OUT, "_preview.png")
    sheet.save(path)
    print("WROTE", path)


if __name__ == "__main__":
    preview([fall_body(), fall_streaks(), foam(), ripple()])
