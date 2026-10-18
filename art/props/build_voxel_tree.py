"""FUSE VALLEY — the Fireworks Yard's voxel tree (MapYardToy "VoxelTree"; Asset Bible §2 "Toy Arcade" world dressing, §4.2).

A chunky toy-brick tree ~14 studs tall, the concept art's blocky studded trees: a square plank trunk with four root
blocks, a canopy of three stacked rounded blocks turned a little against each other (dark, mid and light green,
lighter toward the top), four smaller cubes poking out of the canopy at different heights for a lumpy voxel
silhouette, and toy studs on every exposed top face.

MeshPart groups: Leaves (canopy blocks, cubes, studs), Trunk (trunk, roots).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_voxel_tree.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.VoxelTree/  (renders/, export/Prop.VoxelTree.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.VoxelTree"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Leaves", "Trunk"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
G_DARK, G_DARK_HI = srgb("#23903A"), srgb("#4CB848")
G_MID, G_MID_HI = srgb("#43B83C"), srgb("#7ADC56")
G_LIGHT, G_LIGHT_HI = srgb("#78D44A"), srgb("#B6F27A")
BARK, BARK_HI, BARK_BARE, BARK_DK = srgb("#9A5C30"), srgb("#C88A52"), srgb("#D8A878"), srgb("#5E3418")

M_DARK = kit.mat_gloss("LeafDark", G_DARK, G_DARK_HI, edge=srgb("#8EE070"), rough=0.4, grad=0.55, ao=0.6)
M_MID = kit.mat_gloss("LeafMid", G_MID, G_MID_HI, edge=srgb("#A8F080"), rough=0.4, grad=0.55, ao=0.6)
M_LIGHT = kit.mat_gloss("LeafLight", G_LIGHT, G_LIGHT_HI, edge=srgb("#C8FF9A"), rough=0.4, grad=0.55, ao=0.6)
M_BARK = kit.mat_paint_wood("Bark", BARK, BARK_HI, BARK_BARE, BARK_DK, chip=0.5, grain=0.2)

STUD_PITCH, STUD_R, STUD_H, STUD_INSET = 1.8, 0.5, 0.32, 0.72

# (name, centre x, centre y, bottom z, width, depth, height, yaw deg, material) — the canopy, biggest first
BLOCKS = [
    ("CanopyA", 0.0, 0.0, 5.0, 8.6, 8.6, 3.2, 0, M_DARK),
    ("CanopyB", 0.15, -0.1, 8.0, 6.4, 6.4, 3.0, 15, M_MID),
    ("CanopyC", 0.0, 0.1, 10.8, 4.4, 4.4, 2.9, 35, M_LIGHT),
    ("CubeA", 3.3, -3.55, 4.2, 2.4, 2.4, 2.4, 0, M_MID),
    ("CubeE", -4.05, -1.2, 5.7, 2.2, 2.2, 2.2, 0, M_LIGHT),
    ("CubeB", -3.7, 2.2, 7.1, 2.6, 2.6, 2.6, 15, M_LIGHT),
    ("CubeC", 2.8, 2.6, 9.6, 2.2, 2.2, 2.2, 30, M_DARK),
    ("CubeD", -2.1, -2.3, 11.5, 1.8, 1.8, 1.8, 35, M_MID),
]


def inside(p, blk, pad=0.0):
    _, cx, cy, bz, w, d, h, yaw, _ = blk
    q = Matrix.Rotation(math.radians(-yaw), 3, "Z") @ Vector((p.x - cx, p.y - cy, 0))
    return abs(q.x) < w / 2 + pad and abs(q.y) < d / 2 + pad and bz - 0.01 < p.z < bz + h + 0.01


# ── The trunk and its roots ──────────────────────────────────────────────────────────────────────────────────────
kit.box("Trunk", (1.8, 1.8, 5.6), (0, 0, 2.8), M_BARK, "Trunk", bev=0.12, segs=2)
for k in range(4):
    a = math.radians(90 * k)
    d = Vector((math.cos(a), math.sin(a), 0))
    kit.box(f"Root{k}", (0.9, 0.9, 0.7), tuple(d * 1.1 + Vector((0, 0, 0.35))), M_BARK, "Trunk", bev=0.1, segs=2, rot=Matrix.Rotation(a, 3, "Z"))

# ── The canopy blocks, then studs on whatever top faces nothing covers ──────────────────────────────────────────
for name, cx, cy, bz, w, d, h, yaw, mat in BLOCKS:
    kit.box(name, (w, d, h), (cx, cy, bz + h / 2), mat, "Leaves", bev=0.22 if w > 3 else 0.16, segs=2, rot=Matrix.Rotation(math.radians(yaw), 3, "Z"))

studs = 0
for bi, blk in enumerate(BLOCKS):
    name, cx, cy, bz, w, d, h, yaw, mat = blk
    rot = Matrix.Rotation(math.radians(yaw), 3, "Z")
    # an even grid inset STUD_INSET from the block's edges, about STUD_PITCH apart
    nx, ny = max(1, round((w - 2 * STUD_INSET) / STUD_PITCH) + 1), max(1, round((d - 2 * STUD_INSET) / STUD_PITCH) + 1)
    sx = (w - 2 * STUD_INSET) / max(1, nx - 1)
    sy = (d - 2 * STUD_INSET) / max(1, ny - 1)
    for i in range(nx):
        for j in range(ny):
            lx = (i - (nx - 1) / 2) * sx
            ly = (j - (ny - 1) / 2) * sy
            p = Vector((cx, cy, 0)) + rot @ Vector((lx, ly, 0))
            p.z = bz + h + STUD_H / 2 - 0.02
            covered = any(inside(Vector((p.x, p.y, p.z + 0.1)), o, pad=0.05) for k, o in enumerate(BLOCKS) if k != bi)
            if covered:
                continue
            kit.cylinder(f"Stud{bi}_{i}_{j}", STUD_R, STUD_H, tuple(p), mat, "Leaves", segs=10, bev=0.06, bev_segs=1)
            studs += 1
print("STUDS", studs, flush=True)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, 0, 7.5), floor_color="#6CC24A")
if DO_RENDER:
    kit.shoot("hero", (20.0, -30.0, 14.0), lens=45, target=(0, 0, 7.5))
    kit.shoot("front", (0, -36.0, 7.0), lens=45, target=(0, 0, 7.0))
    kit.shoot("top", (8.0, -14.0, 22.0), lens=40, target=(0, 0, 11.0))

maps = kit.bake_all(parts, {"Leaves": 1024, "Trunk": 512}) if BAKE else {}
kit.export_fbx(parts)
foot = Vector((0, 0, 0))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "Asset Bible §2 Toy Arcade world dressing, §4.2 Yard (MapYardToy voxel trees)",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "glow": [],
        "markers": {"TrunkBase": {"blender": kit.blend(foot), "roblox_from_pivot": kit.rbx(foot, pivot)}},
    }
)
