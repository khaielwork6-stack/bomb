"""FUSE VALLEY — The Quarry's dynamite stack, waist-high field cover (docs/maps/QUARRY_BRIEF.md "Cover"; GDD §19 maps,
Asset Bible §4 props, §1 Quality Bar).

A big flat timber crate (3.2 x 1.6 x 3.2) with a smaller crate set skew on top at the back, a bundle of seven red
dynamite sticks standing on the big crate's front corner (two rope ties and a knot, a braided fuse curling up out of
the middle stick), a pair of loose sticks lying on the small crate, and a red "TNT" stencil on the big crate's front
and right side and on the small crate's front. The crates are the Yard's toy crate language: orange planks with seams,
dark corner battens and rails, iron nails, chipped edges.

MeshPart groups: Crate (planks, lids, cores), Trim (battens, rails, nails, stencils), Dynamite (sticks, ties, fuses).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_dynamite_stack.py -- [--samples 64] [--no-render]
Out:  art/out/Prop.DynamiteStack/  (renders/, export/Prop.DynamiteStack.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the big "TNT"). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
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

KEY = "Prop.DynamiteStack"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Crate", "Trim", "Dynamite"], glow=[])
rng = random.Random(1912)


def display_font():
    """Luckiest Guy (OFL), the game's display face, from the local Roblox install; Blender's font if it's missing."""
    hits = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\LuckiestGuy-Regular.ttf")))
    if hits:
        return bpy.data.fonts.load(hits[-1])
    print("WARNING: LuckiestGuy-Regular.ttf not found, using Blender's built-in font", flush=True)
    return None


# ── Palette (the Yard crate's woods) ─────────────────────────────────────────────────────────────────────────────
WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN = srgb("#E58B3A"), srgb("#FFB25E"), srgb("#FFD7A0"), srgb("#9A4E1C")
WOOD2, WOOD2_HI = srgb("#D97A2E"), srgb("#F7A350")
DARK, DARK_HI, DARK_BARE, DARK_GRAIN = srgb("#6B3A1E"), srgb("#8E5129"), srgb("#B9784A"), srgb("#3E200E")
CORE = srgb("#3A2012")
RED, RED_HI, RED_EDGE = srgb("#D62430"), srgb("#FF5A4E"), srgb("#FF9C90")
PAPER, PAPER_HI = srgb("#F2DCB0"), srgb("#FFF4DC")
STENCIL = srgb("#C8202A")
IRON_LO, IRON, IRON_HI = srgb("#2A2C34"), srgb("#4A4E5C"), srgb("#9AA2B8")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")
ROPE, ROPE_HI = srgb("#D8B070"), srgb("#F8DCA0")


def wood(axis, alt=False):
    return qkit.mat_timber("Plank2" if alt else "Plank", WOOD2 if alt else WOOD, WOOD2_HI if alt else WOOD_HI, WOOD_BARE, WOOD_GRAIN, axis=axis, chip=0.46)


def dark(axis):
    return qkit.mat_timber("Batten", DARK, DARK_HI, DARK_BARE, DARK_GRAIN, axis=axis, chip=0.44, grain=0.16)


M_CORE = kit.mat_flat("Core", CORE, 0.85, ao=0.8)
M_IRON = kit.mat_metal("Iron", IRON_LO, IRON, IRON_HI, rough=(0.25, 0.4), metal=0.3)
M_STENCIL = kit.mat_flat("Stencil", STENCIL, 0.55, ao=0.5)
M_LABEL = kit.mat_gloss("Label", PAPER, PAPER_HI, rough=0.5, grad=0.3, ao=0.4)
M_LABEL_RIM = kit.mat_gloss("LabelRim", RED, RED_HI, edge=RED_EDGE, rough=0.35, grad=0.4)
M_RED = kit.mat_gloss("DynRed", RED, RED_HI, edge=RED_EDGE, rough=0.36, grad=0.45)
M_PAPER = kit.mat_gloss("Paper", PAPER, PAPER_HI, rough=0.6, grad=0.3, ao=0.5)
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))
M_ROPE = kit.mat_carpet("Rope", ROPE, ROPE_HI, srgb("#9A7038"))
M_BURNT = kit.mat_flat("Burnt", srgb("#2A2224"), 0.7, ao=0.4)
FONT = display_font()

BAT, PL_T = 0.36, 0.1


def crate(tag, w, d, h, at, yaw_deg, planks, stencil=None, stencil_sides=((0, -1),), label_x=0.0):
    """A closed toy crate w (X) x d (Y) x h, bottom centre at `at`, turned yaw_deg about Z."""
    R = Matrix.Rotation(math.radians(yaw_deg), 3, "Z")
    T = Vector(at)

    def P(v):
        return tuple(T + R @ Vector(v))

    def A(v):
        return tuple(R @ Vector(v))

    hx, hy = w / 2, d / 2
    lid_t = 0.13
    body_h = h - lid_t
    kit.box(f"{tag}Core", (w - 0.42, d - 0.42, body_h - 0.04), P((0, 0, body_h / 2)), M_CORE, "Crate", bev=0.03, segs=1, rot=R)
    # planks on the four faces, between the corner battens
    for side, (nx, ny) in enumerate(((0, -1), (0, 1), (-1, 0), (1, 0))):
        L = (w if nx == 0 else d) - 2 * BAT + 0.06
        off = (hy if nx == 0 else hx) - 0.21 + PL_T / 2
        ph = (body_h - 0.06) / planks
        for k in range(planks):
            z = 0.03 + ph * (k + 0.5)
            alt = (k + side) % 2 == 1
            if nx == 0:
                kit.box(f"{tag}Plank{side}{k}", (L, PL_T, ph - 0.05), P((0, ny * off, z)), wood(A((1, 0, 0)), alt), "Crate", bev=0.035, segs=1, rot=R)
            else:
                kit.box(f"{tag}Plank{side}{k}", (PL_T, L, ph - 0.05), P((nx * off, 0, z)), wood(A((0, 1, 0)), alt), "Crate", bev=0.035, segs=1, rot=R)
        # top and bottom rails
        rail_off = (hy if nx == 0 else hx) - 0.21 + PL_T + 0.05
        rh = min(0.3, body_h * 0.24)
        for zc in (rh / 2 + 0.01, body_h - rh / 2 - 0.01):
            if nx == 0:
                kit.box(f"{tag}Rail{side}{zc}", (L, 0.1, rh), P((0, ny * rail_off, zc)), dark(A((1, 0, 0))), "Trim", bev=0.035, segs=1, rot=R)
            else:
                kit.box(f"{tag}Rail{side}{zc}", (0.1, L, rh), P((nx * rail_off, 0, zc)), dark(A((0, 1, 0))), "Trim", bev=0.035, segs=1, rot=R)
            for e in (-1, 1):
                along = e * (L / 2 - 0.15)
                v = (along, ny * (rail_off + 0.05), zc) if nx == 0 else (nx * (rail_off + 0.05), along, zc)
                kit.rivet(f"{tag}Nail{side}{zc}{e}", P(v), A((nx, ny, 0)), M_IRON, "Trim", r=0.05, squash=0.5, segs=4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.box(f"{tag}Batten{sx}{sy}", (BAT, BAT, body_h), P((sx * (hx - BAT / 2), sy * (hy - BAT / 2), body_h / 2)), dark((0, 0, 1)), "Trim", bev=0.06, segs=1, rot=R)
    # the lid: planks along X with seams, nailed at the ends
    n_lid = max(2, round(d / 0.8))
    lw = (d - 0.04) / n_lid
    for k in range(n_lid):
        y = -hy + 0.02 + lw * (k + 0.5)
        kit.box(f"{tag}Lid{k}", (w - 0.02, lw - 0.05, lid_t), P((0, y, body_h + lid_t / 2)), wood(A((1, 0, 0)), alt=k % 2 == 1), "Crate", bev=0.04, segs=1, rot=R)
        for e in (-1, 1):
            kit.rivet(f"{tag}LidNail{k}{e}", P((e * (hx - 0.18), y, h)), (0, 0, 1), M_IRON, "Trim", r=0.05, squash=0.5, segs=4)
    # a cream label plate with a red rim on the planks, "TNT" painted on it
    if stencil:
        size, z, lw_, lh_ = stencil
        for nx, ny in stencil_sides:
            face = (hy if nx == 0 else hx) - 0.21 + PL_T
            n = Vector(A((nx, ny, 0)))
            c = Vector(P((nx * face + (label_x if nx == 0 else 0), ny * face, z)))
            kit.prism(f"{tag}LabelRim{nx}{ny}", kit.rounded_rect_pts(lw_, lh_, 0.12, steps=3), 0.05, c, tuple(n), M_LABEL_RIM, "Trim", bev=0.02, bev_segs=1)
            kit.prism(f"{tag}Label{nx}{ny}", kit.rounded_rect_pts(lw_ - 0.12, lh_ - 0.12, 0.08, steps=3), 0.03, c + n * 0.05, tuple(n), M_LABEL, "Trim", bev=0.012, bev_segs=1)
            t = kit.text(f"{tag}TNT{nx}{ny}", "TNT", size, 0.0, M_STENCIL, "Trim", tuple(c + n * 0.092 + Vector((0, 0, -0.02))), normal=tuple(n), bev=0.0)
            if FONT:
                t.data.font = FONT
            t.data.resolution_u = 3
            t.data.fill_mode = "FRONT"
            t.data.space_character = 1.1
    return P, A


# ── The crates ───────────────────────────────────────────────────────────────────────────────────────────────────
BIG_W, BIG_H = 3.2, 1.6
crate("Big", BIG_W, BIG_W, BIG_H, (0, 0, 0), 0.0, 2, stencil=(0.62, 0.78, 1.7, 0.72), stencil_sides=((0, -1), (1, 0), (0, 1), (-1, 0)))
SM_W, SM_D, SM_H = 2.0, 1.5, 1.0
SM_AT = (-0.5, 0.62, BIG_H)
P_sm, A_sm = crate("Small", SM_W, SM_D, SM_H, SM_AT, 9.0, 1, stencil=(0.4, 0.44, 1.1, 0.48), stencil_sides=((0, -1),), label_x=-0.32)


# ── Dynamite ─────────────────────────────────────────────────────────────────────────────────────────────────────
def stick(name, base, axis, length, r=0.15):
    """A red paper dynamite stick from `base` along `axis`: crimped paper ends, a cream paper band."""
    ax = Vector(axis).normalized()
    rot = qkit.frame_from(ax) @ Matrix.Rotation(math.radians(90), 3, "Y")  # local Z -> ax
    rot4 = rot.to_4x4()

    def at(z):
        return Matrix.Translation(Vector(base) + ax * z) @ rot4

    o = kit.cylinder(f"{name}Body", r, length - 0.08, (0, 0, 0), M_RED, "Dynamite", segs=12, bev=0.02, bev_segs=1)
    o.matrix_world = at(length / 2)
    for k, z in enumerate((0.03, length - 0.03)):
        c = kit.cylinder(f"{name}End{k}", r * 0.86, 0.08, (0, 0, 0), M_PAPER, "Dynamite", segs=12, bev=0.0)
        c.matrix_world = at(z)
    band = kit.cylinder(f"{name}Band", r + 0.012, 0.16, (0, 0, 0), M_PAPER, "Dynamite", segs=12, bev=0.0)
    band.matrix_world = at(length * 0.62)
    return Vector(base) + ax * length


# the standing bundle on the big crate's front-right corner
B_C = Vector((0.82, -0.66, BIG_H))
STICK_L, STICK_R = 1.05, 0.15
tops = []
for k in range(7):
    if k == 0:
        p = B_C.copy()
    else:
        a = math.radians(60 * k + 15)
        p = B_C + Vector((math.cos(a), math.sin(a), 0)) * (2 * STICK_R + 0.005)
    lean = Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 1))
    tops.append(stick(f"Bundle{k}", p + Vector((0, 0, rng.uniform(0.0, 0.03))), lean, STICK_L - (0.06 if k % 2 else 0.0), STICK_R))
for k, z in enumerate((0.28, 0.76)):
    kit.torus(f"Tie{k}", 3 * STICK_R + 0.02, 0.05, tuple(B_C + Vector((0, 0, z))), M_ROPE, "Dynamite", major=22, minor=5)
    kit.sphere(f"Knot{k}", 0.09, tuple(B_C + Vector((0.02, -(3 * STICK_R + 0.06), z))), M_ROPE, "Dynamite", u=8, v=6)
    kit.rope(f"TieEnd{k}", [tuple(B_C + Vector((0.02, -(3 * STICK_R + 0.08), z))), tuple(B_C + Vector((0.1, -(3 * STICK_R + 0.16), z - 0.14))), tuple(B_C + Vector((0.08, -(3 * STICK_R + 0.18), z - 0.26)))], 0.032, M_ROPE, "Dynamite", res=3, bres=1)
F0 = tops[0]
FUSE = [tuple(F0 + Vector((0, 0, -0.02))), tuple(F0 + Vector((0.02, 0.0, 0.16))), tuple(F0 + Vector((-0.08, -0.06, 0.3))), tuple(F0 + Vector((-0.22, -0.04, 0.32)))]
kit.rope("BundleFuse", FUSE, 0.04, M_CORD, "Dynamite", res=6, bres=2)
kit.sphere("BundleFuseTip", 0.045, FUSE[-1], M_BURNT, "Dynamite", u=8, v=6)

# two loose sticks lying on the small crate's lid, with short fuses
SM_TOP = BIG_H + SM_H
for k, (x, y, yaw) in enumerate(((-0.25, -0.12, 12.0), (-0.12, 0.2, 4.0))):
    yaw += 9.0
    d = Vector((math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0))
    base = Vector(P_sm((x, y, SM_H + STICK_R - 0.02))) - Vector((0, 0, BIG_H)) * 0 - d * 0.52
    end = stick(f"Loose{k}", base, d, 1.04, STICK_R)
    kit.rope(f"LooseFuse{k}", [tuple(end - d * 0.02), tuple(end + d * 0.12 + Vector((0, 0, 0.06))), tuple(end + d * 0.24 + Vector((0, -0.05, 0.02)))], 0.03, M_CORD, "Dynamite", res=3, bres=1)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, 0, 1.4), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (6.6, -9.0, 5.8), lens=50, target=(0, 0, 1.35))
    kit.shoot("front", (0, -12.5, 1.6), lens=50, target=(0, 0, 1.45))
    kit.shoot("back", (-7.0, 8.0, 5.0), lens=50, target=(0, 0, 1.35))

maps = kit.bake_all(parts, {"Crate": 1024, "Trim": 1024, "Dynamite": 1024}) if BAKE else {}
ups = qkit.export(parts)
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Cover (waist-high, Cover attribute); GDD §19 maps; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "markers": {
            "BigCrate": {"size_studs": [BIG_W, BIG_H, BIG_W], "note": "the collision body: 3.2 x 1.6 x 3.2 from the pivot"},
            "SmallCrateTop": {"height_from_pivot": round(SM_TOP - lo.z, 4)},
        },
        "front_note": "The big TNT stencil faces the front (-Y in Blender = the model's LookVector in Roblox); the bundle "
        "stands on the front-right corner, the small crate sits at the back-left.",
    }
)
