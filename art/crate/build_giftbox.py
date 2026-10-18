"""FUSE VALLEY — the Gift Box crate (GDD §17.4 F-STORE-10, Asset Bible §7.4): the gift loot-crate variant.

A chunky glossy purple gift box with a separate cap lid, a satin pink ribbon crossing the body and the lid, a big
pink bow on top and gold star stickers. Part split matches the Spark Crate so the crate-opening code works:
BodyWood (purple box) / BodyBrass (body ribbon, stars, gold seal) / LidWood (purple lid) / LidBrass (lid ribbon, bow,
stars) baked to PBR, plus Neon InnerGlow (inside), Spark (the star in the bow's knot, swings with the lid) and
LatchSpark (the star in the front seal). The lid hinges on its back bottom edge (the manifest gives it), so the skirt
swings clear of the box. Style reference: icons_sheet2.png #8.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/crate/build_giftbox.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Crate.GiftBox/  (renders/, export/Crate.GiftBox.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "props"))

import kit  # noqa: E402
from kit import Matrix, Vector, box, srgb  # noqa: E402

KEY = "Crate.GiftBox"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["BodyWood", "BodyBrass", "LidWood", "LidBrass"], glow=["InnerGlow", "Spark", "LatchSpark"])
rng = random.Random(21)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
PURPLE, PURPLE_HI, PURPLE_EDGE = srgb("#7F35E0"), srgb("#A060FF"), srgb("#C59AFF")
INSIDE = srgb("#4A1D8C")
PINK, PINK_HI, PINK_EDGE = srgb("#FF3FA6"), srgb("#FF7CC6"), srgb("#FFC2E4")
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
STAR_GLOW = srgb("#FFE066")

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
W = D = 3.2  # body footprint
HT = 2.3  # body top
BEV = 0.16  # body corner radius
LO = 0.18  # lid overhang (skirt thickness 0.16 + 0.02 clearance)
SKIRT = 0.5  # how far the lid skirt comes down over the body
LTOP = 0.24  # lid top thickness above the body
LW = W + 2 * LO
LZ0, LZ1 = HT - SKIRT, HT + LTOP  # lid bottom / top
LBEV = 0.14
RIB_W = 0.62  # ribbon width
RIB_T = 0.06  # ribbon thickness

# ── Materials ────────────────────────────────────────────────────────────────────────────────────────────────────
M_PURPLE = kit.mat_gloss("PurpleGloss", PURPLE, PURPLE_HI, edge=PURPLE_EDGE, rough=0.3, grad=0.5, speckle=0.08)
M_INSIDE = kit.mat_flat("Inside", INSIDE, 0.7, ao=0.7)
M_PINK = kit.mat_gloss("SatinPink", PINK, PINK_HI, edge=PINK_EDGE, rough=0.26, grad=0.55)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_GLOW = kit.mat_emit("InnerGlow", srgb("#FFD27A"), 3.0)
M_STAR = kit.mat_emit("StarGlow", STAR_GLOW, 3.0)

# ── Body: a hollow rounded box ──────────────────────────────────────────────────────────────────────────────────
kit.hollow_box("Body", (W, D, HT), (0, 0, HT / 2), 0.22, 1.3, M_PURPLE, "BodyWood", bev=BEV, segs=5, inner_mat=M_INSIDE)
box("InnerGlow", (W - 0.36, D - 0.36, 0.02), (0, 0, HT - 0.3), M_GLOW, "InnerGlow", 0)

X_TO_RIBBON = Matrix.Rotation(math.radians(90), 4, "X")  # local XY -> world XZ (width along -Y)
Y_TO_RIBBON = Matrix.Rotation(math.radians(90), 4, "Z") @ X_TO_RIBBON  # local XY -> world YZ (width along X)


def u_band(name, half, z_top, z_bot, r, off, group, matrix, width=RIB_W, lift=0.0):
    """A ribbon band running up one side, across (under or over) and down the other: drawn in the local XY plane as
    (across, up), offset `off` outside a rounded box of half-width `half` and corner radius r."""
    h = half + off
    pts = [(-h, z_top), (-h, z_bot), (h, z_bot), (h, z_top)] if z_bot < z_top else [(-h, z_top), (-h, z_bot), (h, z_bot), (h, z_top)]
    pts = kit.fillet_path(pts, r + off, steps=8)
    return kit.ribbon(name, pts, width, RIB_T / 2, M_PINK, group, matrix @ Matrix.Translation((0, 0, lift)), poly=True)


# Body ribbon: two bands that cross under the box, each covering the visible body below the lid skirt.
u_band("RibbonBodyX", W / 2, HT - 0.03, -RIB_T / 2, BEV, RIB_T / 2, "BodyBrass", X_TO_RIBBON)
u_band("RibbonBodyY", D / 2, HT - 0.03, -RIB_T / 2 - 0.004, BEV, RIB_T / 2 + 0.004, "BodyBrass", Y_TO_RIBBON)

# Front seal: a gold medallion on the ribbon with a glowing star (LatchSpark).
SEAL_Z = 1.0
kit.cylinder("Seal", 0.42, 0.12, (0, -D / 2 - RIB_T - 0.05, SEAL_Z), M_GOLD, "BodyBrass", axis="Y", segs=40, bev=0.045, bev_segs=3)
kit.torus("SealRim", 0.40, 0.045, (0, -D / 2 - RIB_T - 0.12, SEAL_Z), M_GOLD, "BodyBrass", axis="Y", major=48, minor=10)
kit.prism("SealStar", kit.star_pts(5, 0.27, 0.12), 0.05, (0, -D / 2 - RIB_T - 0.11, SEAL_Z), (0, -1, 0), M_STAR, "LatchSpark", bev=0.015, bev_segs=2)


# Gold star stickers on the body faces, either side of the ribbon.
def stickers(prefix, face_normal, along, centre_off, spots, group, z_range):
    n = Vector(face_normal)
    a = Vector(along)
    for i, (u, z, r) in enumerate(spots):
        c = n * centre_off + a * u + Vector((0, 0, z))
        pts = kit.star_pts(5, r, r * 0.46, rot=rng.uniform(-0.35, 0.35))
        kit.prism(f"{prefix}{i}", pts, 0.035, c, n, M_GOLD, group, bev=0.02, bev_segs=2)


BODY_SPOTS = [(-0.98, 1.22, 0.25), (-0.82, 0.42, 0.18), (-1.2, 0.8, 0.12), (0.92, 1.18, 0.2), (1.08, 0.48, 0.26), (0.7, 0.8, 0.12)]
for k, (nrm, along) in enumerate((((0, -1, 0), (1, 0, 0)), ((0, 1, 0), (-1, 0, 0)), ((1, 0, 0), (0, 1, 0)), ((-1, 0, 0), (0, -1, 0)))):
    spots = [((-u if k % 2 else u), z + (0.06 if k % 2 else 0.0), r) for u, z, r in BODY_SPOTS]
    stickers(f"StarB{k}", nrm, along, W / 2 - 0.004, spots, "BodyBrass", None)

# ── Lid: a hollow cap whose skirt covers the top of the box ─────────────────────────────────────────────────────
kit.hollow_box("Lid", (LW, LW, LZ1 - LZ0), (0, 0, (LZ0 + LZ1) / 2), LO - 0.02, SKIRT, M_PURPLE, "LidWood", open_side="bottom", bev=LBEV, segs=5, inner_mat=M_INSIDE)


def n_band(name, matrix, lift):
    """A ribbon band over the lid: up the skirt, across the top, down the other side."""
    h = LW / 2 + RIB_T / 2 + lift
    zt = LZ1 + RIB_T / 2 + lift
    pts = kit.fillet_path([(-h, LZ0 + 0.01), (-h, zt), (h, zt), (h, LZ0 + 0.01)], LBEV + RIB_T / 2 + lift, steps=8)
    return kit.ribbon(name, pts, RIB_W, RIB_T / 2, M_PINK, "LidBrass", matrix, poly=True)


n_band("RibbonLidX", X_TO_RIBBON, 0.0)
n_band("RibbonLidY", Y_TO_RIBBON, 0.006)

# The bow: a knot, two big loops (X), two smaller loops (Y), two tails with notched ends.
TOP = LZ1 + RIB_T + 0.006
BOW_W = 0.6


def loop(name, length, height, spin_deg, tilt):
    pts = [(0.05, 0.02), (length * 0.45, height * 0.95), (length * 0.95, height * 0.85 + tilt), (length * 1.02, height * 0.35 + tilt * 0.6), (length * 0.55, 0.06), (0.12, -0.02)]
    m = Matrix.Translation((0, 0, TOP + 0.06)) @ Matrix.Rotation(math.radians(spin_deg), 4, "Z") @ X_TO_RIBBON
    return kit.ribbon(name, pts, BOW_W, 0.07, M_PINK, "LidBrass", m, closed=True, res=12)


loop("LoopR", 1.3, 0.95, -8, 0.15)
loop("LoopL", 1.3, 0.95, 188, 0.15)
loop("LoopR2", 0.95, 0.7, 28, 0.05)
loop("LoopL2", 0.95, 0.7, 152, 0.05)
box("Knot", (0.62, 0.56, 0.5), (0, -0.04, TOP + 0.27), M_PINK, "LidBrass", bev=0.19, segs=5)
# Tails: flat notched strips draped toward the front corners, lying on the lid top.
TAIL = [(-0.2, 0), (0.2, 0), (0.24, 1.25), (0.0, 1.05), (-0.24, 1.25)]
for s in (-1, 1):
    pts = [(x, y) for x, y in TAIL]
    o = kit.prism(f"Tail{s:+d}", pts, 0.05, (0, 0, 0), (0, 0, 1), M_PINK, "LidBrass", bev=0.02, bev_segs=2)
    o.matrix_world = Matrix.Translation((s * 0.12, -0.1, TOP - 0.004)) @ Matrix.Rotation(math.radians(180 + s * 35), 4, "Z")
# The knot's glowing star (Spark — swings with the lid).
kit.prism("KnotStar", kit.star_pts(5, 0.2, 0.09), 0.04, (0, -0.315, TOP + 0.29), (0, -1, 0.3), M_STAR, "Spark", bev=0.012, bev_segs=2)

# Stars on the lid skirt and the lid top corners.
for nrm, along in (((0, -1, 0), (1, 0, 0)), ((0, 1, 0), (-1, 0, 0)), ((1, 0, 0), (0, 1, 0)), ((-1, 0, 0), (0, -1, 0))):
    stickers(f"StarLS{along}", nrm, along, LW / 2 - 0.004, [(-1.05, LZ0 + 0.36, 0.15), (1.0, LZ0 + 0.34, 0.13)], "LidBrass", None)
for i, (x, y, r) in enumerate([(-1.1, -1.1, 0.22), (1.12, -1.05, 0.18), (1.08, 1.1, 0.22), (-1.05, 1.12, 0.16)]):
    kit.prism(f"StarTop{i}", kit.star_pts(5, r, r * 0.46, rot=rng.uniform(-0.4, 0.4)), 0.035, (x, y, LZ1 - 0.004), (0, 0, 1), M_GOLD, "LidBrass", bev=0.02, bev_segs=2)

HINGE = Vector((0, LW / 2, LZ0))
LID_PARTS = ["LidWood", "LidBrass", "Spark"]

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 1.6))
if DO_RENDER:
    kit.shoot("hero", (8.0, -10.2, 6.0))
    kit.shoot("front", (0, -15, 1.9), lens=70)
    kit.shoot("side", (15, 0, 1.9), lens=70)
    kit.rotate_parts(parts, LID_PARTS, HINGE, (1, 0, 0), -105)
    kit.shoot("open", (7.4, -10.5, 7.0), target=(0, 0.6, 2.0))
    kit.rotate_parts(parts, LID_PARTS, HINGE, (1, 0, 0), 0)

maps = kit.bake_all(parts, {"BodyWood": 1024, "BodyBrass": 1024, "LidWood": 1024, "LidBrass": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "hinge": [HINGE.x, HINGE.z, -HINGE.y],
        "hinge_blender": kit.blend(HINGE),
        "hinge_axis": "X (lid swings about the model's X axis; open = front up/back)",
        "hinge_roblox_from_pivot": kit.rbx(HINGE, pivot),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "lid_parts": LID_PARTS,
        "parts": maps,
        "glow": ["InnerGlow", "Spark", "LatchSpark"],
        "glow_colors": {"InnerGlow": "#FFD27A", "Spark": "#FFE066", "LatchSpark": "#FFE066"},
        "notes": "Hinge is the lid's back BOTTOM edge (skirt edge), so the skirt swings clear of the box.",
    }
)
