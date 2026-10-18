"""FUSE VALLEY — the dock canopy's stadium floodlight head (Asset Bible §4.2 Safe Strips: "a cantilevered canopy with
floodlights").

A chunky yellow rounded housing with a visor, a steel bezel and a wire guard over a separate glass lens ("Lens": Neon in
Roblox, with the SpotLight), cooling fins on the back, hung in a steel U-yoke with big pivot knobs and a round mounting
plate on top. ~1.6 wide x 1.2 tall x 1 deep; the lens faces front (-Y; Roblox -Z, the model's LookVector).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_floodlight.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Floodlight/  (renders/, export/Prop.Floodlight.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.Floodlight"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Housing", "Trim"], glow=["Lens"])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
YEL, YEL_HI, YEL_EDGE = srgb("#FFB81C"), srgb("#FFDC5A"), srgb("#FFF0A0")
STEEL_LO, STEEL, STEEL_HI = srgb("#3A4050"), srgb("#68728A"), srgb("#C4CDE0")
DARK_LO, DARK, DARK_HI = srgb("#22252E"), srgb("#3A3F4C"), srgb("#8A92A8")
LENS = srgb("#FFF0D2")

M_YEL = kit.mat_gloss("YellowPaint", YEL, YEL_HI, edge=YEL_EDGE, rough=0.28, grad=0.45)
M_STEEL = kit.mat_metal("Steel", STEEL_LO, STEEL, STEEL_HI, rough=(0.22, 0.36), metal=0.3)
M_DARK = kit.mat_metal("DarkSteel", DARK_LO, DARK, DARK_HI, rough=(0.3, 0.45), metal=0.25)
M_LENS = kit.mat_emit("Lens", LENS, 3.0)

HW, HD, HH = 1.3, 0.62, 0.92  # housing width, depth, height
HZ = 0.52  # housing centre height
FRONT = -HD / 2  # the housing's front face (y)

kit.box("Housing", (HW, HD, HH), (0, 0, HZ), M_YEL, "Housing", bev=0.16, segs=4)
# Visor over the lens, tilted down a touch.
vis = kit.box("Visor", (HW + 0.04, 0.34, 0.05), (0, 0, 0), M_YEL, "Housing", bev=0.02, segs=2)
vis.matrix_world = Matrix.Translation((0, FRONT - 0.12, HZ + HH / 2 - 0.03)) @ Matrix.Rotation(math.radians(-14), 4, "X")
for s in (-1, 1):
    kit.prism(f"VisorCheek{s}", [(0.0, 0.0), (0.0, -0.22), (-0.3, 0.0)], 0.04, (s * (HW / 2 + 0.0) - (0.04 if s > 0 else 0.0), FRONT + 0.04, HZ + HH / 2 - 0.02), (1, 0, 0), M_YEL, "Housing", bev=0.012, bev_segs=1)

# Bezel ring round the lens, the lens, and a wire guard over it.
LW, LH = HW - 0.22, HH - 0.24
ring = kit.fillet_path([(-LW / 2, -LH / 2), (LW / 2, -LH / 2), (LW / 2, LH / 2), (-LW / 2, LH / 2), (-LW / 2, -LH / 2), (LW / 2, -LH / 2)], 0.12, steps=4)
# Ribbon local XY = the face plane (x right, y up), width along local Z = depth (towards -Y).
kit.ribbon("Bezel", ring[1:-1], 0.12, 0.05, M_STEEL, "Trim", kit.plane_matrix((0, FRONT - 0.03, HZ), (0, -1, 0), (1, 0, 0)), closed=True, poly=True)
kit.prism("Lens", kit.rounded_rect_pts(LW - 0.02, LH - 0.02, 0.1, steps=4), 0.05, (0, FRONT + 0.01, HZ), (0, -1, 0), M_LENS, "Lens", bev=0.03, bev_segs=2)
for z in (-0.16, 0.0, 0.16):
    kit.cylinder(f"Guard{z}", 0.022, LW + 0.06, (0, FRONT - 0.1, HZ + z), M_DARK, "Trim", axis="X", segs=6, bev=0.0)
kit.cylinder("GuardV", 0.022, LH + 0.04, (0, FRONT - 0.1, HZ), M_DARK, "Trim", segs=6, bev=0.0)

# Cooling fins on the back.
for i in range(6):
    x = -0.5 + i * 0.2
    kit.box(f"Fin{i}", (0.06, 0.16, HH - 0.3), (x, HD / 2 + 0.06, HZ), M_DARK, "Trim", bev=0.02, segs=1)

# U-yoke with pivot knobs, and the mounting plate on top.
YX = HW / 2 + 0.1
for s in (-1, 1):
    kit.box(f"Arm{s}", (0.08, 0.24, 0.66), (s * YX, 0.0, HZ + 0.3), M_STEEL, "Trim", bev=0.03, segs=2)
    kit.cylinder(f"Knob{s}", 0.13, 0.1, (s * (YX + 0.08), 0.0, HZ), M_DARK, "Trim", axis="X", segs=14, bev=0.03)
    kit.cylinder(f"Boss{s}", 0.1, 0.06, (s * (YX - 0.06), 0.0, HZ), M_STEEL, "Trim", axis="X", segs=12, bev=0.015, bev_segs=1)
kit.box("YokeTop", (2 * YX + 0.08, 0.24, 0.08), (0, 0.0, HZ + 0.62), M_STEEL, "Trim", bev=0.03, segs=2)
kit.cylinder("Mount", 0.08, 0.12, (0, 0, HZ + 0.72), M_STEEL, "Trim", segs=12, bev=0.02, bev_segs=1)
kit.cylinder("MountPlate", 0.26, 0.06, (0, 0, HZ + 0.8), M_DARK, "Trim", segs=20, bev=0.02)
for k in range(4):
    a = math.pi / 4 + k * math.pi / 2
    kit.rivet(f"Bolt{k}", (math.cos(a) * 0.18, math.sin(a) * 0.18, HZ + 0.83), (0, 0, 1), M_STEEL, "Trim", r=0.035, squash=0.6, segs=6)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
lens_c = Vector((0, FRONT - 0.04, HZ))

kit.render_setup(target=(0, 0, 0.6))
if DO_RENDER:
    kit.shoot("hero", (3.2, -4.4, 2.4), lens=50)
    kit.shoot("front", (0, -6.2, 0.7), lens=50)
    kit.shoot("back", (-3.2, 4.2, 2.4), lens=50)

maps = kit.bake_all(parts, {"Housing": 512, "Trim": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "lens_centre_roblox_from_pivot": kit.rbx(lens_c, pivot),
        "lens_normal_roblox": kit.rbx_dir((0, -1, 0)),
        "parts": maps,
        "glow": ["Lens"],
        "glow_colors": {"Lens": "#FFF0D2"},
    }
)
