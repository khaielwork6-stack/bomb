"""FUSE VALLEY — the lobby Crate Stand (GDD §17.4 F-STORE-10 lobby crate displays, Asset Bible §7.4).

A round, chunky display pedestal for a loot crate (the crate itself is not included): a gold rounded plinth, a glossy
red drum with a recessed soft light strip (Neon "RimLight"), a gold top rim with studs, a red velvet top, and a small
gold sign post at the front right holding a red sign with a blank cream face ("SignFace", for a SurfaceGui with the
crate's name / price). The manifest records where the crate sits and the sign face's centre / normal / size.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_crate_stand.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.CrateStand/  (renders/, export/Prop.CrateStand.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.CrateStand"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Pedestal", "Trim", "Sign", "SignFace"], glow=["RimLight"])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
RED, RED_HI, RED_EDGE = srgb("#D81E2C"), srgb("#FF4A4A"), srgb("#FF8A80")
VELVET, VELVET_HI, VELVET_DK = srgb("#B0102A"), srgb("#E0384E"), srgb("#6A0618")
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
CREAM, CREAM_HI = srgb("#FFE9C4"), srgb("#FFF7E6")
LIGHT = srgb("#FFC85A")

M_RED = kit.mat_gloss("RedGloss", RED, RED_HI, edge=RED_EDGE, rough=0.3, grad=0.5)
M_VELVET = kit.mat_carpet("Velvet", VELVET, VELVET_HI, VELVET_DK)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_CREAM = kit.mat_gloss("Cream", CREAM, CREAM_HI, rough=0.55, grad=0.3, ao=0.4)
M_LIGHT = kit.mat_emit("RimLight", LIGHT, 1.6)

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
R = 3.0  # plinth radius (6 studs wide)
H = 1.2  # total height
SEG = 96

# Gold plinth: a rounded ring under the drum.
kit.lathe("Plinth", [(0, 0), (2.96, 0), (3.02, 0.03), (3.0 + 0.05, 0.1), (3.02, 0.17), (2.96, 0.21), (2.8, 0.22), (0, 0.22)], M_GOLD, "Trim", segs=SEG)
# Red drum with a recessed groove for the light strip.
kit.lathe(
    "Drum",
    [(0, 0.21), (2.86, 0.21), (2.88, 0.24), (2.88, 0.45), (2.86, 0.47), (2.76, 0.48), (2.76, 0.64), (2.86, 0.65), (2.88, 0.67), (2.86, 0.97), (0, 0.97)],
    M_RED,
    "Pedestal",
    segs=SEG,
)
kit.torus("RimLight", 2.775, 0.062, (0, 0, 0.56), M_LIGHT, "RimLight", major=SEG, minor=12, scale=(1, 1, 1.15))
# Gold top rim and the velvet top.
kit.lathe("TopRim", [(2.5, 0.95), (2.9, 0.95), (2.95, 0.98), (2.97, 1.04), (2.95, 1.1), (2.9, 1.13), (2.5, 1.13), (2.5, 0.95)], M_GOLD, "Trim", segs=SEG)
kit.lathe("Top", [(0, 1.1), (2.56, 1.1), (2.6, 1.13), (2.6, 1.17), (2.57, 1.2), (0, 1.2)], M_VELVET, "Pedestal", segs=SEG)
# A thin gold inlay ring on the velvet, around where the crate stands.
kit.torus("Inlay", 2.2, 0.035, (0, 0, 1.2), M_GOLD, "Trim", major=SEG, minor=8, scale=(1, 1, 0.6))
# Studs: on the top rim and around the drum's upper band.
for i in range(20):
    a = 2 * math.pi * (i + 0.5) / 20
    kit.rivet(f"StudTop{i}", (math.cos(a) * 2.75, math.sin(a) * 2.75, 1.13), (0, 0, 1), M_GOLD, "Trim", r=0.08, squash=0.6)
for i in range(16):
    a = 2 * math.pi * i / 16
    n = Vector((math.cos(a), math.sin(a), 0))
    kit.rivet(f"StudDrum{i}", n * 2.875 + Vector((0, 0, 0.815)), n, M_GOLD, "Trim", r=0.085, squash=0.6)
    # A gold diamond plate between the studs on the lower band.
    b = a + math.pi / 16
    nb = Vector((math.cos(b), math.sin(b), 0))
    kit.prism(f"Diamond{i}", [(0, -0.09), (0.11, 0), (0, 0.09), (-0.11, 0)], 0.03, nb * 2.875 + Vector((0, 0, 0.335)), nb, M_GOLD, "Trim", bev=0.012, bev_segs=2)

# ── Sign post (front right) ──────────────────────────────────────────────────────────────────────────────────────
POST = Vector((2.45, -2.85, 0))
SIGN_YAW = math.radians(28)  # turned to face the front-right approach
SIGN_N = Matrix.Rotation(SIGN_YAW, 3, "Z") @ Vector((0, -1, 0))
kit.cylinder("PostFoot", 0.32, 0.12, POST + Vector((0, 0, 0.06)), M_GOLD, "Sign", segs=40, bev=0.04, bev_segs=3)
kit.cylinder("PostFoot2", 0.2, 0.1, POST + Vector((0, 0, 0.16)), M_GOLD, "Sign", segs=32, bev=0.03)
kit.cylinder("Post", 0.075, 2.2, POST + Vector((0, 0, 1.25)), M_GOLD, "Sign", segs=24, bev=0.0)
for z in (0.55, 1.2):
    kit.torus(f"PostRing{z}", 0.085, 0.035, POST + Vector((0, 0, z)), M_GOLD, "Sign", major=24, minor=8)
kit.sphere("PostCap", 0.13, POST + Vector((0, 0, 2.44)), M_GOLD, "Sign", u=24, v=12)

SIGN_C = POST + Vector((0, 0, 1.88))
SW, SH = 1.55, 0.9
kit.prism("SignBack", kit.rounded_rect_pts(SW + 0.14, SH + 0.14, 0.2), 0.08, SIGN_C + SIGN_N * 0.06, SIGN_N, M_GOLD, "Sign", bev=0.035, bev_segs=3)
kit.prism("SignBoard", kit.rounded_rect_pts(SW, SH, 0.16), 0.1, SIGN_C + SIGN_N * 0.12, SIGN_N, M_RED, "Sign", bev=0.035, bev_segs=3)
FACE_W, FACE_H = SW - 0.26, SH - 0.26
FACE_BACK = SIGN_C + SIGN_N * 0.215
kit.prism("SignFace", kit.rounded_rect_pts(FACE_W, FACE_H, 0.09), 0.025, FACE_BACK, SIGN_N, M_CREAM, "SignFace", bev=0.01, bev_segs=2)
for s in (-1, 1):
    for t in (-1, 1):
        corner = SIGN_C + Matrix.Rotation(SIGN_YAW, 3, "Z") @ Vector((s * (SW / 2 - 0.068), 0, 0)) + Vector((0, 0, t * (SH / 2 - 0.068))) + SIGN_N * 0.218
        kit.rivet(f"SignRiv{s}{t}", corner, SIGN_N, M_GOLD, "Sign", r=0.045)

CRATE_SPOT = Vector((0, 0, H))

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, -0.6, 0.9))
if DO_RENDER:
    kit.shoot("hero", (8.2, -10.6, 5.6), lens=50)
    kit.shoot("front", (0, -14, 1.8), lens=55)
    kit.shoot("top", (5.0, -6.5, 13.0), lens=45, target=(0, -0.4, 0.6))

face_c = FACE_BACK + SIGN_N * 0.025
maps = kit.bake_all(parts, {"Pedestal": 1024, "Trim": 1024, "Sign": 1024, "SignFace": 512}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "crate_spot_blender": kit.blend(CRATE_SPOT),
        "crate_spot_roblox_from_pivot": kit.rbx(CRATE_SPOT, pivot),
        "sign_face": {
            "part": "SignFace",
            "centre_blender": kit.blend(face_c),
            "centre_roblox_from_pivot": kit.rbx(face_c, pivot),
            "normal_blender": kit.blend(SIGN_N),
            "normal_roblox": kit.rbx_dir(SIGN_N),
            "size_studs": [round(FACE_W, 3), round(FACE_H, 3)],
        },
        "parts": maps,
        "glow": ["RimLight"],
        "glow_colors": {"RimLight": "#FFC85A"},
    }
)
