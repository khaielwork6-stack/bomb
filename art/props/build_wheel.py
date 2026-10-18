"""FUSE VALLEY — the lobby Prize Wheel (Asset Bible §7 lobby props): a big spin-to-win wheel ~10 studs tall.

A gold studded rim with gold pegs and divider spokes, 8 glossy rainbow segments (separate MeshParts Seg1..Seg8 so each
can be highlighted), a gold hub with a red cap and gold star, a gold pointer (separate part "Pointer", a red jewel in
it) hanging from a mast at the top, and a chunky dark navy stand with gold trim. The disc parts (Rim, Hub, Seg1..Seg8)
form the "Disc" group, which spins about the axle recorded in the manifest. Style reference: icons_sheet1.png #19.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_wheel.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.SpinWheel/  (renders/, export/Prop.SpinWheel.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import Matrix, Vector, box, srgb  # noqa: E402

KEY = "Prop.SpinWheel"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
SEGS = [f"Seg{i}" for i in range(1, 9)]
kit.setup(KEY, bake=["Rim", "Hub"] + SEGS + ["Pointer", "Stand"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
NAVY, NAVY_HI, NAVY_EDGE = srgb("#262A44"), srgb("#3F4670"), srgb("#6C76A8")
RED, RED_HI = srgb("#E5222E"), srgb("#FF5A5A")
SEG_COLORS = ["#FF3B3B", "#FF8A1F", "#FFD21F", "#3CD656", "#1FC8E0", "#3B6BFF", "#9B4DFF", "#FF4FB8"]


def lighten(hexs, k):
    h = hexs.lstrip("#")
    c = [int(h[i : i + 2], 16) for i in (0, 2, 4)]
    c = [round(x + (255 - x) * k) for x in c]
    return "#%02X%02X%02X" % tuple(c)


M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_NAVY = kit.mat_gloss("Navy", NAVY, NAVY_HI, edge=NAVY_EDGE, rough=0.34, grad=0.5)
M_RED = kit.mat_gloss("RedGloss", RED, RED_HI, edge=srgb("#FFA0A0"), rough=0.25, grad=0.5)
M_GEM = kit.mat_gloss("Ruby", srgb("#C40E2A"), srgb("#FF5470"), edge=srgb("#FFC0CC"), rough=0.12, grad=0.7)
M_SEG = [kit.mat_gloss(f"Seg{i + 1}", srgb(c), srgb(lighten(c, 0.3)), edge=srgb(lighten(c, 0.55)), rough=0.28, grad=0.0) for i, c in enumerate(SEG_COLORS)]

# ── Disc (built in a local frame: axle = local Z toward the viewer, local +Y = up) ──────────────────────────────
AXLE = Vector((0, 0, 5.4))
DISC_M = Matrix.Translation(AXLE) @ Matrix.Rotation(math.radians(90), 4, "X")  # local +Z -> world -Y, +Y -> +Z
RO, RI = 4.05, 3.3  # rim outer / inner radius
RH = 0.95  # hub radius
disc_objs = []


def disc(o):
    disc_objs.append(o)
    return o


# Rim: a chunky rounded gold ring, its front face carrying 24 studs, with gold pegs at the segment borders.
disc(kit.lathe("RimRing", [(RI, -0.3), (RO - 0.08, -0.3), (RO, -0.22), (RO + 0.03, 0.0), (RO, 0.22), (RO - 0.08, 0.3), (RI + 0.04, 0.3), (RI - 0.02, 0.24), (RI - 0.02, -0.24), (RI, -0.3)], M_GOLD, "Rim", segs=128))
disc(kit.torus("RimBead", (RI + RO) / 2 + 0.02, 0.07, (0, 0, 0.3), M_GOLD, "Rim", major=128, minor=10, scale=(1, 1, 0.8)))
for i in range(24):
    a = math.pi / 2 + 2 * math.pi * (i + 0.5) / 24
    disc(kit.rivet(f"Stud{i}", (math.cos(a) * 3.84, math.sin(a) * 3.84, 0.3), (0, 0, 1), M_GOLD, "Rim", r=0.16, squash=0.8))
for i in range(8):
    a = math.pi / 2 + 2 * math.pi * (i + 0.5) / 8  # segment borders (segment centres sit on multiples of 45 deg from top)
    p = Vector((math.cos(a), math.sin(a), 0))
    disc(kit.cylinder(f"Peg{i}", 0.085, 0.42, p * (RI - 0.12) + Vector((0, 0, 0.36)), M_GOLD, "Rim", segs=16, bev=0.03))
    disc(kit.sphere(f"PegCap{i}", 0.12, p * (RI - 0.12) + Vector((0, 0, 0.6)), M_GOLD, "Rim", u=16, v=8))
    # Divider spoke over the seam between two segments.
    ln = RI - RH + 0.1
    mid = p * ((RI + RH) / 2)
    rot = Matrix.Rotation(a - math.pi / 2, 3, "Z")
    disc(box(f"Spoke{i}", (0.12, ln, 0.1), mid + Vector((0, 0, 0.2)), M_GOLD, "Rim", bev=0.04, rot=rot))

# Segments: annular sectors, each its own part.
SEG_T = 0.36
for i in range(8):
    c = math.pi / 2 - 2 * math.pi * i / 8  # Seg1 at the top, then clockwise as seen from the front
    a0, a1 = c - math.pi / 8, c + math.pi / 8
    outer = [(math.cos(a0 + (a1 - a0) * k / 16) * (RI + 0.02), math.sin(a0 + (a1 - a0) * k / 16) * (RI + 0.02)) for k in range(17)]
    inner = [(math.cos(a1 - (a1 - a0) * k / 6) * (RH - 0.05), math.sin(a1 - (a1 - a0) * k / 6) * (RH - 0.05)) for k in range(7)]
    disc(kit.prism(f"Seg{i + 1}", outer + inner, SEG_T, (0, 0, -SEG_T / 2), (0, 0, 1), M_SEG[i], SEGS[i], bev=0.06, bev_segs=3))

# Hub: a gold dome, a red cap and a gold star.
disc(kit.lathe("HubDome", [(0, 0.62), (0.55, 0.6), (0.85, 0.5), (RH + 0.04, 0.32), (RH + 0.06, 0.16), (RH, 0.0), (0, 0.0)], M_GOLD, "Hub", segs=64))
disc(kit.lathe("HubCap", [(0, 0.76), (0.42, 0.74), (0.56, 0.68), (0.6, 0.6), (0.55, 0.56), (0, 0.56)], M_RED, "Hub", segs=64))
disc(kit.prism("HubStar", kit.star_pts(5, 0.42, 0.19), 0.1, (0, 0, 0.72), (0, 0, 1), M_GOLD, "Hub", bev=0.035, bev_segs=3))
for i in range(8):
    a = math.pi / 2 + 2 * math.pi * (i + 0.5) / 8
    disc(kit.rivet(f"HubRiv{i}", (math.cos(a) * 0.78, math.sin(a) * 0.78, 0.47), (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.85), M_GOLD, "Hub", r=0.07))

for o in disc_objs:
    o.matrix_world = DISC_M @ o.matrix_world

# ── Stand ────────────────────────────────────────────────────────────────────────────────────────────────────────
SY = 0.85  # the stand's frame sits behind the disc
box("Plinth", (6.4, 3.0, 0.55), (0, SY * 0.5, 0.275), M_NAVY, "Stand", bev=0.16, segs=4)
box("PlinthTrim", (6.5, 3.1, 0.14), (0, SY * 0.5, 0.58), M_GOLD, "Stand", bev=0.05)
box("PlinthTop", (5.4, 2.4, 0.3), (0, SY * 0.5, 0.78), M_NAVY, "Stand", bev=0.12, segs=4)
for s in (-1, 1):
    # Legs: A-frame from the plinth up to the axle block.
    p0, p1 = Vector((s * 2.0, SY, 0.85)), Vector((s * 0.42, SY, AXLE.z))
    mid = (p0 + p1) / 2
    ang = math.atan2(p1.x - p0.x, p1.z - p0.z)
    box(f"Leg{s:+d}", (0.55, 0.5, (p1 - p0).length + 0.2), mid, M_NAVY, "Stand", bev=0.12, segs=3, rot=Matrix.Rotation(ang, 3, "Y"))
    kit.box(f"LegFoot{s:+d}", (0.95, 0.85, 0.22), (s * 2.0, SY, 0.98), M_GOLD, "Stand", bev=0.07)
    for z in (2.2, 3.6):
        t = (z - p0.z) / (p1.z - p0.z)
        q = p0.lerp(p1, t)
        kit.rivet(f"LegRiv{s:+d}{z}", (q.x, SY - 0.26, q.z), (0, -1, 0), M_GOLD, "Stand", r=0.09)
box("AxleBlock", (1.25, 0.6, 1.25), (0, SY, AXLE.z), M_NAVY, "Stand", bev=0.18, segs=4)
kit.cylinder("Axle", 0.26, 1.1, (0, 0.25, AXLE.z), M_GOLD, "Stand", axis="Y", segs=32, bev=0.03)
kit.cylinder("AxleBoss", 0.42, 0.14, (0, SY - 0.33, AXLE.z), M_GOLD, "Stand", axis="Y", segs=40, bev=0.04)
# Mast up the back to the pointer bracket.
MAST_TOP = 9.95
box("Mast", (0.46, 0.46, MAST_TOP - AXLE.z), (0, SY, (MAST_TOP + AXLE.z) / 2), M_NAVY, "Stand", bev=0.1, segs=3)
box("Bracket", (0.46, SY + 1.0, 0.42), (0, (SY - 1.0) / 2, MAST_TOP - 0.21), M_NAVY, "Stand", bev=0.12, segs=3)
box("BracketTrim", (0.52, SY + 1.06, 0.08), (0, (SY - 1.0) / 2, MAST_TOP - 0.02), M_GOLD, "Stand", bev=0.03)
kit.sphere("MastCap", 0.2, (0, SY, MAST_TOP + 0.06), M_GOLD, "Stand", u=24, v=12)

# ── Pointer: a gold arrow hanging from the bracket front, tip down into the top segment ────────────────────────
PY = -0.92  # in front of the pegs' caps, so they pass behind it
PIN = Vector((0, PY + 0.02, MAST_TOP - 0.24))
TIP_Z = AXLE.z + RI - 0.2
ptr = [(0, TIP_Z - PIN.z), (0.26, -0.62), (0.46, -0.3), (0.46, 0.02), (0.3, 0.24), (0, 0.32), (-0.3, 0.24), (-0.46, 0.02), (-0.46, -0.3), (-0.26, -0.62)]
ptr = kit.outline(ptr, sharp=[0], n=5)
kit.prism("PointerPlate", ptr, 0.2, PIN + Vector((0, 0.1, 0)), (0, -1, 0), M_GOLD, "Pointer", bev=0.07, bev_segs=4)
kit.cylinder("PointerPin", 0.11, 0.44, PIN + Vector((0, 0.1, 0)), M_GOLD, "Pointer", axis="Y", segs=24, bev=0.03)
kit.sphere("PointerGem", 0.2, PIN + Vector((0, -0.12, -0.2)), M_GEM, "Pointer", scale=(1, 0.5, 1.1), u=24, v=12)
kit.torus("PointerGemRim", 0.2, 0.04, PIN + Vector((0, -0.11, -0.2)), M_GOLD, "Pointer", axis="Y", major=32, minor=8, scale=(1, 1.1, 1))

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 5.0))
if DO_RENDER:
    kit.shoot("hero", (11.0, -19.0, 8.5), lens=50)
    kit.shoot("front", (0, -26, 5.2), lens=55)
    kit.shoot("back", (19.0, 17.0, 8.0), lens=50)
    kit.rotate_parts(parts, ["Rim", "Hub"] + SEGS, AXLE, (0, 1, 0), 22.5)
    kit.shoot("spun", (11.0, -19.0, 8.5), lens=50)
    kit.rotate_parts(parts, ["Rim", "Hub"] + SEGS, AXLE, (0, 1, 0), 0)

res = {"Rim": 1024, "Hub": 512, "Pointer": 512, "Stand": 1024}
res.update({s: 512 for s in SEGS})
maps = kit.bake_all(parts, res) if BAKE else {}
kit.export_fbx(parts)
AXIS = Vector((0, -1, 0))
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "disc": {
            "parts": ["Rim", "Hub"] + SEGS,
            "axle_blender": kit.blend(AXLE),
            "axle_roblox_from_pivot": kit.rbx(AXLE, pivot),
            "axis_blender": kit.blend(AXIS),
            "axis_roblox": kit.rbx_dir(AXIS),
            "segments": {
                s: {"color": SEG_COLORS[i], "centre_deg_clockwise_from_top": i * 45}
                for i, s in enumerate(SEGS)
            },
            "note": "Seg1 is centred under the pointer at rest; segments run clockwise as seen from the front, 45 deg each.",
        },
        "pointer": {
            "part": "Pointer",
            "pin_blender": kit.blend(PIN),
            "pin_roblox_from_pivot": kit.rbx(PIN, pivot),
            "tip_blender": kit.blend((0, PY, TIP_Z)),
            "tip_roblox_from_pivot": kit.rbx((0, PY, TIP_Z), pivot),
            "note": "Swings about the pin on the disc's axle axis (a flapper tick).",
        },
        "parts": maps,
        "glow": [],
    }
)
