"""Shared numpy helpers for the procedural texture generators (art/vfx, art/yard). Run inside Blender's Python:
images are written with Blender's image API (no Pillow in the toolchain).

Coordinates: grid() returns x, y in -1..1 with y DOWN (row 0 at the top), matching the saved image.
"""

import math
import os

import bpy
import numpy as np


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def save(out_dir, name, rgba):
    """rgba: H×W×4 float array, row 0 at the top."""
    os.makedirs(out_dir, exist_ok=True)
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = np.flipud(np.clip(rgba, 0, 1)).astype(np.float32).ravel()
    img.filepath_raw = os.path.join(out_dir, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("wrote", name, flush=True)
    return rgba


def preview(out_dir, name, rgba, bg):
    """The texture composited over a flat colour, for review (white-on-transparent hides in a white viewer)."""
    a = rgba[..., 3:4]
    comp = rgba[..., :3] * a + np.asarray(bg) * (1 - a)
    return save(out_dir, "preview_" + name, np.dstack([comp, np.ones(a.shape[:2])]))


def grid(n, m=None):
    m = m or n
    y, x = np.mgrid[0:n, 0:m].astype(np.float64)
    return (x + 0.5) / m * 2 - 1, (y + 0.5) / n * 2 - 1


def smooth(t):
    return t * t * (3 - 2 * t)


def value_noise(x, y, cells, seed):
    """Smooth value noise on a periodic lattice: x, y in -1..1 tile seamlessly at `cells` cells."""
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


def fbm(x, y, cells, seed, octaves=4):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + value_noise(x, y, cells * 2 ** o, seed + o * 97) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def seg_dist(x, y, a, b):
    """Distance from every pixel to the segment a–b."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy + 1e-12
    t = np.clip(((x - ax) * dx + (y - ay) * dy) / l2, 0, 1)
    return np.hypot(x - (ax + t * dx), y - (ay + t * dy))


def poly_dist(x, y, pts):
    d = np.full_like(x, 9.0)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, seg_dist(x, y, a, b))
    return d


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


def aa(d, width, px):
    """Anti-aliased coverage of a stroke: 1 inside `width` of the centre line, soft over one pixel."""
    return np.clip((width - d) / px + 0.5, 0, 1)


def specks(x, y, cells, seed, threshold):
    """Small round flecks (paint chips, grit): two lattices of different sizes blended, so the flecks aren't
    grid-aligned squares. Integer cell counts keep it tileable. Returns 0..1 coverage."""
    n = value_noise(x, y, cells, seed) * 0.5 + value_noise(x, y, int(cells * 1.37) + 1, seed + 1) * 0.5
    return np.clip((n - threshold) * 14, 0, 1)


def random_walk(rng, start, steps, step, turn):
    """A jagged crack-like polyline."""
    pts = [start]
    ang = rng.uniform(0, 2 * math.pi)
    for _ in range(steps):
        ang += rng.normal(0, turn)
        px_, py_ = pts[-1]
        pts.append((px_ + math.cos(ang) * step, py_ + math.sin(ang) * step))
    return pts


def wrapped_poly_dist(x, y, pts):
    """poly_dist on a tile that repeats every 2 units (x, y in -1..1): the shape wraps across the edges."""
    d = np.full_like(x, 9.0)
    for ox in (-2, 0, 2):
        for oy in (-2, 0, 2):
            d = np.minimum(d, poly_dist(x, y, [(p[0] + ox, p[1] + oy) for p in pts]))
    return d
