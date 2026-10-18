"""FUSE VALLEY — the Fireworks Yard's roll-up warehouse shutter (Asset Bible §4.2 Yard: "roll-up shutter doors behind"
the docks; §4.4 props kit: "Shutter door — corrugated, painted, chipped").

Sized to MapYard's dock doors (one size: a 14-stud opening, 11 tall, the roll box above): 14.4 wide (it fills the
door frame's 14.4 opening), 12.2 tall, 1.6 deep (the roll box's depth; the panel sits at the back).
  • "Panel": eleven bright blue interlocking slats, each a bulged profile with a raised centre rib and a dark V joint,
    painted steel with chipped edges, the shade alternating a touch slat to slat;
  • "BottomBar": the chunky bottom rail in yellow-and-black hazard stripes on a black rubber seal, two steel pull
    handles and a lock plate (its own MeshPart, so the open door can lift it up under the hood);
  • "Housing": the slate-blue roll hood (flat top, rounded front) with steel end plates and axle bosses, and the two
    steel guide rails down the sides with bolt heads and foot plates.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_shutter.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Shutter/  (renders/, export/Prop.Shutter.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit  # noqa: E402
from kit import Vector, srgb  # noqa: E402

KEY = "Prop.Shutter"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Panel", "BottomBar", "Housing"], glow=[])


def strip(name, profile, x0, x1, mat, group, closed=True):
    """A profile (y, z points) swept straight along X from x0 to x1, without end caps (the ends hide in the rails or
    behind the end plates). Smooth-shaded."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profile]
    b = [bm.verts.new((x1, y, z)) for y, z in profile]
    n = len(profile)
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return kit.smooth(kit.give(kit.mesh_obj(name, bm, group), mat))


def tube(name, pts, radius, mat, group, bres=2):
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


def round_path(pts, r, steps=4):
    P = [Vector(p) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, b, c = P[i - 1], P[i], P[i + 1]
        s = b + (a - b).normalized() * min(r, (b - a).length * 0.45)
        e = b + (c - b).normalized() * min(r, (c - b).length * 0.45)
        for k in range(steps + 1):
            t = k / steps
            out.append(s * (1 - t) ** 2 + b * 2 * t * (1 - t) + e * t * t)
    out.append(P[-1])
    return out


# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
BLUE, BLUE_HI, BLUE_EDGE = srgb("#2E96E2"), srgb("#6CC4FF"), srgb("#A6DCFF")
BLUE2, BLUE2_HI = srgb("#2788D4"), srgb("#5CB6F6")
SLATE, SLATE_HI, SLATE_EDGE = srgb("#41558F"), srgb("#6A80C4"), srgb("#9AAEE6")
BARE = srgb("#AEB8CA")
STEEL_LO, STEEL, STEEL_HI = srgb("#5A6478"), srgb("#9AA6BC"), srgb("#E4ECF8")
RUBBER, RUBBER_HI = srgb("#24242C"), srgb("#44444F")

M_BLUE = kit.mat_paint_metal("Blue", BLUE, BLUE_HI, BLUE_EDGE, BARE)
M_BLUE2 = kit.mat_paint_metal("Blue2", BLUE2, BLUE2_HI, BLUE_EDGE, BARE)
M_SLATE = kit.mat_paint_metal("Slate", SLATE, SLATE_HI, SLATE_EDGE, BARE, chip=0.45)
M_STEEL = kit.mat_metal("Steel", STEEL_LO, STEEL, STEEL_HI, rough=(0.22, 0.36), metal=0.3, bump=0.1)
M_RUBBER = kit.mat_gloss("Rubber", RUBBER, RUBBER_HI, rough=0.7, grad=0.35, ao=0.6)
M_HAZARD = kit.mat_hazard("Hazard")

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
HW = 7.2  # half the overall width (the frame's opening)
DEPTH = 1.6  # the roll box's depth = the prop's depth; y = -0.8 front, +0.8 back (the wall)
HOOD_Z0, HOOD_Z1 = 10.6, 12.2
RAIL_W, RAIL_Y0, RAIL_Y1 = 0.46, 0.12, 0.8
BAR_Z1 = 0.62  # top of the bottom rail
SLATS = 11
SLAT_H = (HOOD_Z0 + 0.1 - BAR_Z1) / SLATS
SLAT_Y = 0.56  # the slats' centre line (depth)
SLAT_X = HW - RAIL_W + 0.2  # slat ends run 0.2 into the rails

# ── Panel: the slats ─────────────────────────────────────────────────────────────────────────────────────────────
h = SLAT_H
front = [
    (0.03, 0.0),
    (-0.07, 0.05),
    (-0.13, 0.13),
    (-0.155, 0.25),
    (-0.155, h * 0.5 - 0.09),
    (-0.2, h * 0.5 - 0.05),
    (-0.21, h * 0.5),
    (-0.2, h * 0.5 + 0.05),
    (-0.155, h * 0.5 + 0.09),
    (-0.155, h - 0.25),
    (-0.13, h - 0.13),
    (-0.07, h - 0.05),
    (0.03, h),
]
front = kit.catmull(front, n=3, closed=False)
SLAT_PROFILE = front + [(0.16, h - 0.02), (0.17, h * 0.5), (0.16, 0.02)]
for k in range(SLATS):
    z0 = BAR_Z1 + k * h
    prof = [(SLAT_Y + y, z0 + z) for y, z in SLAT_PROFILE]
    strip(f"Slat{k}", prof, -SLAT_X, SLAT_X, M_BLUE if k % 2 == 0 else M_BLUE2, "Panel")

# ── Bottom bar: hazard-striped rail on a rubber seal, pull handles, lock ─────────────────────────────────────────
bar = kit.rounded_rect_pts(0.5, BAR_Z1 - 0.12, 0.12, steps=3)
strip("Bar", [(SLAT_Y - 0.05 + x, 0.12 + (BAR_Z1 - 0.12) / 2 + y) for x, y in bar], -SLAT_X, SLAT_X, M_HAZARD, "BottomBar")
for s in (-1, 1):  # bar end caps (inside the rails)
    kit.box(f"BarEnd{s}", (0.06, 0.5, BAR_Z1 - 0.12), (s * (SLAT_X - 0.03), SLAT_Y - 0.05, 0.12 + (BAR_Z1 - 0.12) / 2), M_HAZARD, "BottomBar", bev=0.02, segs=1)
seal = kit.rounded_rect_pts(0.34, 0.16, 0.07, steps=3)
strip("Seal", [(SLAT_Y - 0.05 + x, 0.08 + y) for x, y in seal], -SLAT_X, SLAT_X, M_RUBBER, "BottomBar")
BAR_FRONT = SLAT_Y - 0.05 - 0.25
for hx in (-3.6, 3.6):
    pts = round_path([(hx - 0.42, BAR_FRONT + 0.02, 0.4), (hx - 0.42, BAR_FRONT - 0.2, 0.4), (hx + 0.42, BAR_FRONT - 0.2, 0.4), (hx + 0.42, BAR_FRONT + 0.02, 0.4)], 0.1)
    tube(f"Handle{hx}", pts, 0.055, M_STEEL, "BottomBar")
    for e in (-1, 1):
        kit.box(f"HandleFoot{hx}{e}", (0.16, 0.05, 0.26), (hx + e * 0.42, BAR_FRONT - 0.005, 0.4), M_STEEL, "BottomBar", bev=0.015, segs=1)
kit.prism("Lock", kit.rounded_rect_pts(0.42, 0.36, 0.08, steps=3), 0.05, (0, BAR_FRONT, 0.38), (0, -1, 0), M_STEEL, "BottomBar", bev=0.015, bev_segs=1)
kit.cylinder("Keyhole", 0.07, 0.05, (0, BAR_FRONT - 0.07, 0.4), M_RUBBER, "BottomBar", axis="Y", segs=10, bev=0.0)

# ── Housing: guide rails, the roll hood and its end plates ───────────────────────────────────────────────────────
for s in (-1, 1):
    rx = s * (HW - RAIL_W / 2)
    ry = (RAIL_Y0 + RAIL_Y1) / 2
    kit.box(f"Rail{s}", (RAIL_W, RAIL_Y1 - RAIL_Y0, HOOD_Z0 + 0.1), (rx, ry, (HOOD_Z0 + 0.1) / 2), M_STEEL, "Housing", bev=0.05, segs=2)
    kit.box(f"RailFoot{s}", (RAIL_W, RAIL_Y1 - RAIL_Y0 + 0.1, 0.16), (rx, ry - 0.05, 0.08), M_SLATE, "Housing", bev=0.04, segs=2)
    for k in range(5):
        z = 1.2 + k * 2.1
        kit.rivet(f"RailBolt{s}{k}", (rx, RAIL_Y0, z), (0, -1, 0), M_SLATE, "Housing", r=0.085, squash=0.55, segs=8)
# the hood: flat top, rounded front, a lip underneath
hood = [
    (0.8, HOOD_Z1 - 0.06),
    (0.74, HOOD_Z1),
    (-0.3, HOOD_Z1),
    (-0.58, HOOD_Z1 - 0.08),
    (-0.76, HOOD_Z1 - 0.34),
    (-0.8, HOOD_Z1 - 0.7),
    (-0.8, HOOD_Z0 + 0.2),
    (-0.76, HOOD_Z0 + 0.04),
    (-0.68, HOOD_Z0),
    (-0.5, HOOD_Z0),
    (-0.5, HOOD_Z0 + 0.12),
    (0.8, HOOD_Z0 + 0.12),
]
hood_s = kit.outline(hood, sharp=[0, 8, 9, 10, 11], n=3)
EP = 0.2  # end plate thickness
strip("Hood", hood_s, -HW + EP - 0.02, HW - EP + 0.02, M_SLATE, "Housing")
# the hood's front: a raised band with bolts along it
for k in range(9):
    x = -HW + 1.0 + k * (2 * HW - 2.0) / 8
    kit.rivet(f"HoodBolt{k}", (x, -0.8, HOOD_Z0 + 0.42), (0, -1, 0), M_STEEL, "Housing", r=0.07, squash=0.5, segs=8)
plate = [(y, z) for y, z in kit.outline(hood, sharp=[0, 8, 9, 10, 11], n=2)]
for s in (-1, 1):
    # the prism's local x runs along world +Y for s = +1 and -Y for s = -1 (local +Z = the outward normal)
    pts = [(s * y, z - (HOOD_Z0 + HOOD_Z1) / 2) for y, z in plate]
    kit.prism(
        f"EndPlate{s}",
        pts,
        EP,
        (s * (HW - EP), 0, (HOOD_Z0 + HOOD_Z1) / 2),
        (s, 0, 0),
        M_STEEL,
        "Housing",
        bev=0.04,
        bev_segs=2,
    )

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "pivot", kit.blend(pivot), "lo", kit.blend(lo), "hi", kit.blend(hi), flush=True)

kit.render_setup(target=(0, 0, 6.0), floor_color="#8E97A8")
if DO_RENDER:
    kit.shoot("hero", (12.0, -26.0, 13.0), lens=45, target=(0, 0, 5.6))
    kit.shoot("front", (0, -34, 6.2), lens=50, target=(0, 0, 6.1))
    kit.shoot("close", (3.2, -5.2, 2.2), lens=45, target=(4.6, 0, 1.0))

maps = kit.bake_all(parts, {"Panel": 1024, "BottomBar": 512, "Housing": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "panel_top_z": round(BAR_Z1 + SLATS * SLAT_H, 4),
        "bar_height": BAR_Z1,
        "hood_bottom_z": HOOD_Z0,
        "glow": [],
    }
)
_ = math
