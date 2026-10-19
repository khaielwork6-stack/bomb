"""FUSE VALLEY — the live layers behind title art (Client/UI/TitleArt): a soft glow, a lens streak and a four-point
sparkle. White, so the game tints them per colour family; drawn from maths (no AI art).

Run: blender -b --factory-startup --python art/titles/fx.py      Out: art/out/Titles/fx_{glow,streak,sparkle}.png
"""

import os

import bpy
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "Titles")
os.makedirs(OUT, exist_ok=True)


def save(name, alpha):
    h, w = alpha.shape
    px = np.ones((h, w, 4), dtype=np.float32)
    px[..., 3] = np.clip(alpha, 0, 1)
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = px.ravel()
    img.filepath_raw = os.path.abspath(os.path.join(OUT, name + ".png"))
    img.file_format = "PNG"
    img.save()
    print("FX", name, w, h, flush=True)


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1


# glow: a soft ellipse (2:1), gaussian-ish falloff reaching zero at the edge
x, y = grid(1024, 512)
r = np.sqrt(x * x + y * y)
glow = np.exp(-(r**2) * 3.2) * np.clip(1 - r, 0, 1) ** 0.6
save("fx_glow", glow / glow.max())

# streak: a thin horizontal flare — a hot core line and a wider soft halo, both fading toward the ends
x, y = grid(1024, 64)
along = np.clip(1 - np.abs(x), 0, 1) ** 1.6
core = np.exp(-((y / 0.07) ** 2))
halo = np.exp(-((y / 0.38) ** 2)) * 0.35
save("fx_streak", (core + halo) * along)

# sparkle: a four-point star (long vertical/horizontal rays, short diagonals) with a round hot core
x, y = grid(256, 256)
ax, ay = np.abs(x), np.abs(y)
ray_v = np.exp(-((ax / 0.035) ** 2)) * np.clip(1 - ay, 0, 1) ** 2.2
ray_h = np.exp(-((ay / 0.035) ** 2)) * np.clip(1 - ax, 0, 1) ** 2.2
d1, d2 = np.abs(x - y) / 1.414, np.abs(x + y) / 1.414
rr = np.sqrt(x * x + y * y)
diag = (np.exp(-((d1 / 0.025) ** 2)) + np.exp(-((d2 / 0.025) ** 2))) * np.clip(1 - rr / 0.55, 0, 1) ** 2 * 0.6
core = np.exp(-((rr / 0.09) ** 2))
save("fx_sparkle", np.clip(ray_v + ray_h + diag + core, 0, 1))

# ring: a clean anti-aliased band (the carrier badge's fuse countdown fills it radially in game)
x, y = grid(256, 256)
r = np.sqrt(x * x + y * y)
px = 2.0 / 256
band = np.clip((0.98 - r) / px, 0, 1) * np.clip((r - 0.74) / px, 0, 1)
save("fx_ring", band)

# disc: a soft-edged dark backing for small badges
save("fx_disc", np.clip((1.0 - r) / 0.14, 0, 1) ** 1.4)
