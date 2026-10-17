"""One-off repair for the first Bomb.ClassicIron export (2026-10-17): its NORMAL / ROUGHNESS / METAL maps were saved
through the sRGB transform (the images were only flagged Non-Color after baking — export.py now flags them first), so
flat normals came out (188, 188, 255) instead of (128, 128, 255) and every surface read as tilted in Studio.
This decodes each data map back to linear and re-saves it raw, in place.

Run: blender -b --python-exit-code 1 --python art/bomb/fix_linear_maps.py
"""

import glob
import os

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "export", "textures")


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


for path in sorted(glob.glob(os.path.join(TEX, "*.png"))):
    kind = path.rsplit("_", 1)[1][:-4]
    if kind == "COLOR":
        continue
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"  # read the stored bytes as they are
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    before = px[..., :3].mean(axis=(0, 1))
    px[..., :3] = srgb_to_linear(px[..., :3])
    img.pixels = px.astype(np.float32).ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print(f"fixed {os.path.basename(path)}: mean {before.round(3)} -> {px[..., :3].mean(axis=(0, 1)).round(3)}", flush=True)
print("DONE", flush=True)
