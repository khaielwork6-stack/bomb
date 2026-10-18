"""FUSE VALLEY — The Quarry's big title sign on the far cliffs, "FUSE VALLEY / QUARRY" (docs/maps/QUARRY_BRIEF.md
"Backdrop", the concept art art/ref/quarry/concept_1_hero.jpg; GDD §19 maps, Asset Bible §4 props, §1 Quality Bar).

A big hand-built plank sign: five orange-timber planks (each a touch different in length and tilt) in a dark timber
frame with iron corner plates and bolts, on two thick posts with caps and iron bands. Modelled lettering in the game's
display face (Luckiest Guy): cream-gold glossy letters standing proud of a thick dark-ink outline, "FUSE VALLEY" over
"QUARRY", with a pair of crossed pickaxes (timber handles, steel heads) either side of "QUARRY".

MeshPart groups: Board (planks), Frame (frame, posts, caps), Letters (letters and their outline), Picks (pickaxes,
plates, bolts).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_quarry_sign.py -- [--samples 64] [--no-render]
Out:  art/out/Prop.QuarrySign/  (renders/, export/Prop.QuarrySign.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the lettering). Exports at 10 FBX units per stud (the board is 30
wide): studio_import_props.luau scales it by 0.1. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import glob
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import kit  # noqa: E402
import qkit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.QuarrySign"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Board", "Frame", "Letters", "Picks"], glow=[])
rng = random.Random(2610)


def display_font():
    hits = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\LuckiestGuy-Regular.ttf")))
    if hits:
        return bpy.data.fonts.load(hits[-1])
    print("WARNING: LuckiestGuy-Regular.ttf not found, using Blender's built-in font", flush=True)
    return None


# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
PLANK, PLANK_HI, PLANK_BARE, PLANK_DK = srgb("#C87438"), srgb("#F0A060"), srgb("#FFD7A0"), srgb("#7A3A14")
PLANK2, PLANK2_HI = srgb("#B8662E"), srgb("#E49050")
FRAME, FRAME_HI, FRAME_BARE, FRAME_DK = srgb("#5E3218"), srgb("#86502A"), srgb("#B9784A"), srgb("#2E160A")
CREAM, CREAM_HI, CREAM_EDGE = srgb("#FFDF96"), srgb("#FFF6D8"), srgb("#FFFFFF")
INK, INK_HI = srgb("#2A160C"), srgb("#4E3020")
IRON, IRON_HI, IRON_EDGE, IRON_BARE = srgb("#33363F"), srgb("#5C6070"), srgb("#8E94A6"), srgb("#9EA2AE")
STEEL_LO, STEEL, STEEL_HI = srgb("#4A5262"), srgb("#8A96AE"), srgb("#E8F0FF")
HANDLE, HANDLE_HI = srgb("#D08A48"), srgb("#F8BC78")


def plank(axis, alt=False):
    return qkit.mat_timber("Plank2" if alt else "Plank", PLANK2 if alt else PLANK, PLANK2_HI if alt else PLANK_HI, PLANK_BARE, PLANK_DK, axis=axis, chip=0.46)


def frame(axis):
    return qkit.mat_timber("Frame", FRAME, FRAME_HI, FRAME_BARE, FRAME_DK, axis=axis, chip=0.44, grain=0.16)


def handle(axis):
    return qkit.mat_timber("Handle", HANDLE, HANDLE_HI, srgb("#FFE0B0"), PLANK_DK, axis=axis, chip=0.5, grain=0.14)


M_CREAM = kit.mat_gloss("Letter", CREAM, CREAM_HI, edge=CREAM_EDGE, rough=0.3, grad=0.5, ao=0.5)
M_INK = kit.mat_gloss("Outline", INK, INK_HI, rough=0.45, grad=0.4, ao=0.5)
M_IRON = kit.mat_paint_metal("Iron", IRON, IRON_HI, IRON_EDGE, IRON_BARE, rough=0.4, chip=0.45, spots=0.8)
M_STEEL = kit.mat_metal("Steel", STEEL_LO, STEEL, STEEL_HI, rough=(0.2, 0.34), metal=0.3, edge_gain=5.0)
FONT = display_font()

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
W, H, D = 30.0, 9.0, 0.9  # the board incl. frame
Z0 = 3.0  # board bottom (the posts carry it)
FR = 0.65  # frame rail width
FRONT = -D / 2
POST_X, POST = 10.0, 1.35

# ── Posts ────────────────────────────────────────────────────────────────────────────────────────────────────────
for s in (-1, 1):
    x = s * POST_X
    kit.box(f"Post{s}", (POST, POST, Z0 + H + 0.6), (x, D / 2 + POST / 2 - 0.1, (Z0 + H + 0.6) / 2), frame((0, 0, 1)), "Frame", bev=0.12, segs=2)
    kit.box(f"PostCap{s}", (POST + 0.35, POST + 0.35, 0.35), (x, D / 2 + POST / 2 - 0.1, Z0 + H + 0.75), frame((1, 0, 0)), "Frame", bev=0.1, segs=2)
    for z in (0.9, Z0 - 0.6):
        kit.box(f"PostBand{s}{z}", (POST + 0.1, POST + 0.1, 0.22), (x, D / 2 + POST / 2 - 0.1, z), M_IRON, "Picks", bev=0.04, segs=1)

# ── The board: planks in a frame ─────────────────────────────────────────────────────────────────────────────────
N = 5
inner_h = H - 2 * FR
ph = inner_h / N
for k in range(N):
    z = Z0 + FR + ph * (k + 0.5)
    tilt = Matrix.Rotation(math.radians(rng.uniform(-0.5, 0.5)), 3, "Y")
    kit.box(f"Plank{k}", (W - 2 * FR + 0.3 + rng.uniform(-0.1, 0.1), D - 0.25, ph - 0.1), (rng.uniform(-0.05, 0.05), 0.05, z), plank((1, 0, 0), alt=k % 2 == 1), "Board", bev=0.08, segs=2, rot=tilt)
# a dark backing behind the planks, so the seams read as shadow, not sky
kit.box("Backing", (W - 2 * FR + 0.2, 0.12, H - 2 * FR + 0.2), (0, D / 2 - 0.12, Z0 + H / 2), M_INK, "Board", bev=0.0)
for zc, name in ((Z0 + FR / 2, "FrameBot"), (Z0 + H - FR / 2, "FrameTop")):
    kit.box(name, (W, D, FR), (0, 0, zc), frame((1, 0, 0)), "Frame", bev=0.12, segs=2)
for s in (-1, 1):
    kit.box(f"FrameSide{s}", (FR, D, H - 2 * FR + 0.02), (s * (W / 2 - FR / 2), 0, Z0 + H / 2), frame((0, 0, 1)), "Frame", bev=0.12, segs=2)
    for zs in (-1, 1):
        c = Vector((s * (W / 2 - 0.55), FRONT - 0.04, Z0 + H / 2 + zs * (H / 2 - 0.55)))
        kit.box(f"CornerPlate{s}{zs}", (0.95, 0.08, 0.95), tuple(c), M_IRON, "Picks", bev=0.03, segs=1)
        kit.rivet(f"CornerBolt{s}{zs}", tuple(c + Vector((0, -0.05, 0))), (0, -1, 0), M_STEEL, "Picks", r=0.16, segs=6)
for s in (-1, 1):
    for k in range(N):
        z = Z0 + FR + ph * (k + 0.5)
        kit.rivet(f"PlankNail{s}{k}", (s * POST_X, FRONT + 0.1, z), (0, -1, 0), M_STEEL, "Picks", r=0.11, segs=5)


# ── Lettering: cream-gold letters on a thick dark outline ────────────────────────────────────────────────────────
def word(name, body, size, z, spacing=1.04):
    out = kit.text(f"{name}Out", body, size, 0.12, M_INK, "Letters", (0, FRONT - 0.04, z), normal=(0, -1, 0), bold=0.0, bev=0.0)
    let = kit.text(f"{name}Let", body, size, 0.34, M_CREAM, "Letters", (0, FRONT - 0.27, z), normal=(0, -1, 0), bold=0.0, bev=0.07, bev_res=0)
    for t in (out, let):
        if FONT:
            t.data.font = FONT
        t.data.resolution_u = 2
        t.data.space_character = spacing
    out.data.offset = 0.055 * size
    out.data.fill_mode = "FRONT"
    return let


word("Line1", "FUSE VALLEY", 4.3, Z0 + H * 0.705)
word("Line2", "QUARRY", 4.3, Z0 + H * 0.285)


# ── Crossed pickaxes either side of "QUARRY" ─────────────────────────────────────────────────────────────────────
def pickaxe(name, center, angle_deg):
    """A pickaxe lying flat on the board (in the XZ plane), its handle along local +Z from `center`, rotated
    angle_deg about Y; the head across the handle's top end."""
    R = Matrix.Rotation(math.radians(angle_deg), 4, "Y")
    T = Matrix.Translation(Vector(center))
    M = T @ R @ Matrix.Scale(0.84, 4)
    L = 5.2
    hnd = kit.cylinder(f"{name}Handle", 0.22, L, (0, 0, 0), handle((0, 0, 1)), "Picks", segs=8, bev=0.06, bev_segs=1, r2=0.26)
    hnd.matrix_world = M @ Matrix.Translation((0, 0, L / 2 - 1.2))
    grip = kit.cylinder(f"{name}Grip", 0.27, 1.1, (0, 0, 0), M_IRON, "Picks", segs=8, bev=0.04, bev_segs=1)
    grip.matrix_world = M @ Matrix.Translation((0, 0, -0.6))
    top = L - 1.2
    # the head: a curved, double-pointed steel bar swept along an arc, thickest in the middle
    arc = [(x, 0, top + 0.55 - 0.16 * x * x) for x in (-1.9, -1.0, 0.0, 1.0, 1.9)]
    head = qkit.sweep(f"{name}Head", arc, 0.36, M_STEEL, "Picks", segs=8, n=3, cap_rings=2, taper=lambda t: max(0.12, 1.0 - abs(2 * t - 1) ** 1.6 * 0.88))
    head.matrix_world = M
    eye = kit.box(f"{name}Eye", (0.7, 0.62, 0.8), (0, 0, 0), M_IRON, "Picks", bev=0.08, segs=1)
    eye.matrix_world = M @ Matrix.Translation((0, 0, top + 0.5))
    return M


QX = 11.3  # pickaxe pair centres, either side of QUARRY
PZ = Z0 + FR + 1.25
for s in (-1, 1):
    c = (s * QX, FRONT - 0.42, PZ)
    pickaxe(f"Pick{s}A", c, 34)
    pickaxe(f"Pick{s}B", (c[0], c[1] - 0.45, c[2]), -34)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), "LO", kit.blend(lo), "HI", kit.blend(hi), flush=True)

kit.render_setup(target=(0, 0, 7.5), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (22.0, -44.0, 16.0), lens=50, target=(0, 0, 7.3))
    kit.shoot("front", (0, -62.0, 8.0), lens=50, target=(0, 0, 7.6))
    kit.shoot("close", (6.0, -14.0, 6.0), lens=40, target=(8.0, 0, 5.5))

maps = kit.bake_all(parts, {"Board": 2048, "Frame": 2048, "Letters": 2048, "Picks": 1024}) if BAKE else {}
ups = qkit.export(parts)
board_c = Vector((0, FRONT, Z0 + H / 2))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Backdrop (the concept's FUSE VALLEY QUARRY title sign); GDD §19; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "markers": {
            "BoardCentre": {"blender": kit.blend(board_c), "roblox_from_pivot": kit.rbx(board_c, pivot), "board_size_studs": [W, H, D]},
            "BoardBottom": {"height_from_pivot": round(Z0 - lo.z, 4), "note": "sink the posts up to this to sit the board on a ledge"},
        },
        "front_note": "The lettering faces the front (-Y in Blender = the model's LookVector in Roblox).",
    }
)
