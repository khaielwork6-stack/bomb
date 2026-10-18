"""FUSE VALLEY — the Fireworks Yard's hand-truck (Asset Bible §4.2 / §4.4 Yard props: field cover).

A red-orange steel hand-truck standing on its nose plate: one continuous bent tube (two rails, a loop handle bent back
at the top with a black rubber grip), three cross bars, a steel nose plate with gussets, an axle on brackets and two
chunky rubber wheels with yellow hubs. It carries a small closed firework crate (orange planks, dark battens, a red
"FIREWORKS" label) held on with a yellow ratchet strap. Footprint ~2.2 x 1.8, ~4.3 tall.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_hand_truck.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.HandTruck/  (renders/, export/Prop.HandTruck.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import glob
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.HandTruck"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Frame", "Wheels", "Load"], glow=[])


def display_font():
    hits = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\LuckiestGuy-Regular.ttf")))
    if hits:
        return bpy.data.fonts.load(hits[-1])
    print("WARNING: LuckiestGuy-Regular.ttf not found, using Blender's built-in font", flush=True)
    return None


def round_path(pts, r, steps=5):
    """Round the interior corners of a 3D polyline with quadratic arcs reaching `r` along each segment."""
    P = [Vector(p) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, b, c = P[i - 1], P[i], P[i + 1]
        ra = min(r, (b - a).length * 0.45)
        rc = min(r, (c - b).length * 0.45)
        s = b + (a - b).normalized() * ra
        e = b + (c - b).normalized() * rc
        for k in range(steps + 1):
            t = k / steps
            out.append(s * (1 - t) ** 2 + b * 2 * t * (1 - t) + e * t * t)
    out.append(P[-1])
    return out


def tube(name, pts, radius, mat, group, bres=2):
    """A round tube along a 3D polyline (poly spline, so straight runs stay straight), capped."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = bres
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for pt, p in zip(sp.points, pts):
        pt.co = (p[0], p[1], p[2], 1)
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    return kit.link(o, group)


# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
STEEL, STEEL_HI, STEEL_EDGE = srgb("#EE4A26"), srgb("#FF7B42"), srgb("#FFB08A")
PLATE_LO, PLATE, PLATE_HI = srgb("#5A6070"), srgb("#8E97A8"), srgb("#DCE4F0")
RUBBER, RUBBER_HI = srgb("#2B2B34"), srgb("#4A4A58")
HUB, HUB_HI = srgb("#FFC21E"), srgb("#FFE47A")
WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN = srgb("#E58B3A"), srgb("#FFB25E"), srgb("#FFD7A0"), srgb("#9A4E1C")
WOOD2, WOOD2_HI = srgb("#D97A2E"), srgb("#F7A350")
DARK, DARK_HI, DARK_BARE, DARK_GRAIN = srgb("#6B3A1E"), srgb("#8E5129"), srgb("#B9784A"), srgb("#3E200E")
CREAM, CREAM_HI = srgb("#FFEFD2"), srgb("#FFFFFF")
RED, RED_HI, RED_EDGE = srgb("#D62430"), srgb("#FF4A4A"), srgb("#FF8C84")
STRAP, STRAP_HI = srgb("#FFC21E"), srgb("#FFE27A")

M_STEEL = kit.mat_gloss("SteelPaint", STEEL, STEEL_HI, edge=STEEL_EDGE, rough=0.28, grad=0.45)
M_PLATE = kit.mat_metal("Plate", PLATE_LO, PLATE, PLATE_HI, rough=(0.25, 0.4), metal=0.3, bump=0.15)
M_RUBBER = kit.mat_gloss("Rubber", RUBBER, RUBBER_HI, rough=0.72, grad=0.35, ao=0.6)
M_HUB = kit.mat_gloss("Hub", HUB, HUB_HI, edge=srgb("#FFF2B0"), rough=0.3, grad=0.4)
M_WOOD = kit.mat_paint_wood("Planks", WOOD, WOOD_HI, WOOD_BARE, WOOD_GRAIN, chip=0.46, grain=0.2, rough=(0.5, 0.75))
M_WOOD2 = kit.mat_paint_wood("Planks2", WOOD2, WOOD2_HI, WOOD_BARE, WOOD_GRAIN, chip=0.46, grain=0.2, rough=(0.5, 0.75))
M_DARK = kit.mat_paint_wood("Battens", DARK, DARK_HI, DARK_BARE, DARK_GRAIN, chip=0.44, grain=0.16, rough=(0.5, 0.72))
M_CREAM = kit.mat_gloss("Cream", CREAM, CREAM_HI, rough=0.5, grad=0.3, ao=0.4)
M_RED = kit.mat_gloss("Red", RED, RED_HI, edge=RED_EDGE, rough=0.35, grad=0.4)
M_STRAP = kit.mat_carpet("Strap", STRAP, STRAP_HI, srgb("#C8901A"))

# ── Frame ────────────────────────────────────────────────────────────────────────────────────────────────────────
RX = 0.66  # rail half-spacing
RY = 0.62  # rail line (behind the load)
TR = 0.1  # tube radius
frame = [
    (-RX, RY, 0.14),
    (-RX, RY, 3.45),
    (-RX, RY + 0.22, 3.95),
    (-RX + 0.05, RY + 0.3, 4.22),
    (RX - 0.05, RY + 0.3, 4.22),
    (RX, RY + 0.22, 3.95),
    (RX, RY, 3.45),
    (RX, RY, 0.14),
]
tube("Rails", round_path(frame, 0.28, steps=5), TR, M_STEEL, "Frame")
for z in (1.05, 2.05, 3.05):
    kit.cylinder(f"Cross{z}", 0.07, 2 * RX, (0, RY, z), M_STEEL, "Frame", axis="X", segs=10, bev=0.0)
# Nose plate with two gussets up the rails.
kit.box("Nose", (1.66, 1.42, 0.1), (0, -0.07, 0.05), M_PLATE, "Frame", bev=0.03, segs=2)
kit.box("NoseLip", (1.66, 0.06, 0.12), (0, -0.75, 0.1), M_PLATE, "Frame", bev=0.02, segs=1)
for s in (-1, 1):
    kit.prism(f"Gusset{s}", [(-0.3, 0), (0.12, 0), (0.12, 0.5), (0.02, 0.5)], 0.06, (s * RX - 0.03, RY - 0.04, 0.1), (1, 0, 0), M_PLATE, "Frame", bev=0.015, bev_segs=1)
    kit.box(f"Bracket{s}", (0.1, 0.36, 0.56), (s * RX, RY + 0.1, 0.48), M_STEEL, "Frame", bev=0.025, segs=1)
WZ, WY, WR = 0.52, RY + 0.14, 0.52  # wheel centre height, line, radius
kit.cylinder("Axle", 0.07, 2 * (RX + 0.3), (0, WY, WZ), M_PLATE, "Frame", axis="X", segs=10, bev=0.0)

# ── Wheels (rubber tyre, yellow hub, cap) and the grip ───────────────────────────────────────────────────────────
for s in (-1, 1):
    wx = s * (RX + 0.3)
    tyre = kit.lathe(
        f"Tyre{s}",
        [(0.24, -0.16), (0.4, -0.17), (WR - 0.04, -0.15), (WR, -0.08), (WR + 0.008, 0.0), (WR, 0.08), (WR - 0.04, 0.15), (0.4, 0.17), (0.24, 0.16)],
        M_RUBBER,
        "Wheels",
        segs=24,
    )
    tyre.matrix_world = Matrix.Translation((wx, WY, WZ)) @ Matrix.Rotation(math.radians(90), 4, "Y")
    hub = kit.lathe(f"Hub{s}", [(0, -0.15), (0.27, -0.15), (0.3, -0.12), (0.3, 0.12), (0.27, 0.15), (0.12, 0.18), (0, 0.18)], M_HUB, "Wheels", segs=20)
    hub.matrix_world = Matrix.Translation((wx, WY, WZ)) @ Matrix.Rotation(math.radians(90 * s), 4, "Y")
    for k in range(5):  # lug bolts
        a = 2 * math.pi * k / 5
        kit.rivet(f"Lug{s}{k}", (wx + s * 0.165, WY + math.cos(a) * 0.19, WZ + math.sin(a) * 0.19), (s, 0, 0), M_PLATE, "Wheels", r=0.035, squash=0.6, segs=6)
tube("Grip", [(-0.42, RY + 0.3, 4.22), (0.42, RY + 0.3, 4.22)], TR + 0.03, M_RUBBER, "Wheels")
for x in (-0.42, 0.42):
    kit.torus(f"GripRing{x}", TR + 0.03, 0.02, (x, RY + 0.3, 4.22), M_RUBBER, "Wheels", axis="X", major=12, minor=6)

# ── The load: a small closed firework crate, strapped on ─────────────────────────────────────────────────────────
CW, CD, CH = 1.6, 1.2, 2.2
CY = RY - TR - CD / 2 - 0.01  # touching the rails
CZ0 = 0.1  # sits on the nose plate
core = (CW - 0.2, CD - 0.2, CH - 0.04)
kit.box("CrateCore", core, (0, CY, CZ0 + CH / 2), M_DARK, "Load", bev=0.03, segs=1)
PL_H = (CH - 0.08) / 3
for k in range(3):
    z = CZ0 + 0.04 + PL_H * (k + 0.5)
    for s in (-1, 1):
        kit.box(f"PlankF{s}{k}", (CW - 0.36, 0.08, PL_H - 0.05), (0, CY + s * (core[1] / 2 + 0.04), z), M_WOOD if (k + s) % 2 else M_WOOD2, "Load", bev=0.03, segs=1)
        kit.box(f"PlankS{s}{k}", (0.08, CD - 0.36, PL_H - 0.05), (s * (core[0] / 2 + 0.04), CY, z), M_WOOD2 if (k + s) % 2 else M_WOOD, "Load", bev=0.03, segs=1)
kit.box("Lid", (CW - 0.12, CD - 0.12, 0.14), (0, CY, CZ0 + CH - 0.03), M_WOOD, "Load", bev=0.04, segs=2)
for sx in (-1, 1):
    for sy in (-1, 1):
        kit.box(f"Batten{sx}{sy}", (0.28, 0.28, CH + 0.06), (sx * (CW / 2 - 0.14), CY + sy * (CD / 2 - 0.14), CZ0 + CH / 2 + 0.02), M_DARK, "Load", bev=0.05, segs=2)
FONT = display_font()
n = Vector((0, -1, 0))
lb = Vector((0, CY - core[1] / 2 - 0.08, CZ0 + 1.45))
kit.prism("LabelBack", kit.rounded_rect_pts(1.06, 0.46, 0.09, steps=3), 0.04, lb, n, M_RED, "Load", bev=0.015, bev_segs=1)
kit.prism("LabelFace", kit.rounded_rect_pts(0.98, 0.38, 0.06, steps=3), 0.025, lb + n * 0.04, n, M_CREAM, "Load", bev=0.01, bev_segs=1)
t = kit.text("Word", "FIREWORKS", 0.2, 0.0, M_RED, "Load", lb + n * 0.075 + Vector((0, 0, -0.005)), normal=n, bev=0.0)
if FONT:
    t.data.font = FONT
t.data.resolution_u = 3
t.data.fill_mode = "FRONT"
# The strap: round the crate and behind the rails, with a buckle at the front.
SZ = CZ0 + 0.7
x0, x1 = CW / 2 + 0.02, RY + TR + 0.03
strap_pts = kit.fillet_path([(0, CY - CD / 2 - 0.02), (x0, CY - CD / 2 - 0.02), (x0, x1), (-x0, x1), (-x0, CY - CD / 2 - 0.02), (0, CY - CD / 2 - 0.02)], 0.06, steps=3)
kit.ribbon("Strap", strap_pts, 0.16, 0.012, M_STRAP, "Load", Matrix.Translation((0, 0, SZ)), closed=False, poly=True)
kit.box("Buckle", (0.26, 0.06, 0.22), (0.3, CY - CD / 2 - 0.05, SZ), M_PLATE, "Load", bev=0.02, segs=1)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 2.0))
if DO_RENDER:
    kit.shoot("hero", (6.4, -9.2, 6.2), lens=55)
    kit.shoot("front", (0, -14, 2.4), lens=55)
    kit.shoot("back", (-6.2, 8.8, 5.8), lens=55)

maps = kit.bake_all(parts, {"Frame": 1024, "Wheels": 512, "Load": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "glow": [],
    }
)
