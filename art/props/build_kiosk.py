"""FUSE VALLEY — the Depot's fireworks stall (MapDepot "ShopKiosk"; GDD §19.1 lobby shop, Asset Bible §4.3).

The modelled stall on MapDepot's part-built ShopKiosk, 1:1 (1 Blender unit = 1 stud): a glossy blue counter on a navy
kick base with four inset panels each carrying a gold star, a gold counter top with two little stacks of firework
boxes at its ends, a navy back wall with two orange-wood shelves of firework boxes and rocket bundles on gold brackets,
a red-and-white striped awning of seven puffy stripes on the old slats' slope with a scalloped valance hanging from a
gold rod along its front edge, two gold poles holding the awning's front corners, and a gold frame (with a star either
side) round the game's own "ShopSign" board, which keeps its "FIREWORKS & SKINS" SurfaceGui.
NOT in the mesh (MapDepot's parts, which the code reads): ShopSign, ShopPromptPart, PlinthBase / Plinth1..4.

MeshPart groups: Counter (body, kick, panels, stars, top, the counter-top goods), Back (wall, shelves, goods),
Awning (stripes, valance), Trim (rod, poles, sign frame and stars, shelf brackets).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_kiosk.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Kiosk/  (renders/, export/Prop.Kiosk.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the counter's customer side). Studio: Blender (x, y, z) -> Roblox (-x, z, y).
The Blender origin is MapDepot's ShopKiosk centre "SC" on the deck (the Counter's bottom centre).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.Kiosk"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Counter", "Back", "Awning", "Trim"], glow=[])
rng = random.Random(11)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
BLUE, BLUE_HI, BLUE_EDGE = srgb("#2486D8"), srgb("#5CB8FF"), srgb("#A8DCFF")
BLUE_L, BLUE_L_HI = srgb("#4AA6EC"), srgb("#8ED0FF")
NAVY, NAVY_HI = srgb("#1E3480"), srgb("#3456C0")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
RED, RED_HI, RED_EDGE = srgb("#E03830"), srgb("#FF6A58"), srgb("#FFA898")
WHITE, WHITE_HI = srgb("#ECEAF0"), srgb("#FFFFFF")
WOOD, WOOD_HI, WOOD_BARE, WOOD_DK = srgb("#E08A40"), srgb("#FFB46A"), srgb("#F4CFA0"), srgb("#8A4A1E")
GOODS = ["#E83830", "#FFC41E", "#9646E6", "#3BBF4A", "#2E96E2", "#FF7A1E"]

M_BLUE = kit.mat_gloss("CounterBlue", BLUE, BLUE_HI, edge=BLUE_EDGE, rough=0.28, grad=0.45)
M_BLUE_L = kit.mat_gloss("PanelBlue", BLUE_L, BLUE_L_HI, edge=srgb("#CDEBFF"), rough=0.3, grad=0.4)
M_NAVY = kit.mat_gloss("Navy", NAVY, NAVY_HI, edge=srgb("#7A9AFF"), rough=0.32, grad=0.4)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_RED = kit.mat_gloss("StripeRed", RED, RED_HI, edge=RED_EDGE, rough=0.42, grad=0.4, ao=0.55)
M_WHITE = kit.mat_gloss("StripeWhite", WHITE, WHITE_HI, edge=WHITE_HI, rough=0.45, grad=0.35, ao=0.55)
M_WOOD = kit.mat_paint_wood("Shelf", WOOD, WOOD_HI, WOOD_BARE, WOOD_DK)
M_GOODS = [kit.mat_gloss(f"Goods{i}", srgb(h), tuple(min(1.0, c * 1.6 + 0.08) if j < 3 else c for j, c in enumerate(srgb(h))), rough=0.32, grad=0.4) for i, h in enumerate(GOODS)]
M_PAPER = kit.mat_gloss("Paper", srgb("#FFF3E2"), WHITE_HI, rough=0.5, grad=0.3, ao=0.5)

# ── Dimensions (studs): MapDepot's ShopKiosk ─────────────────────────────────────────────────────────────────────
CW, CD, CH = 14.0, 3.0, 3.4  # "Counter"
TW, TD, TT = 14.6, 3.6, 0.4  # "CounterTop" on it
BACK_Y0, BACK_Y1, BACK_H = 3.5, 4.5, 9.0  # "Back" 14 x 9 x 1 at y 3.5..4.5
AW_TILT = math.radians(16)  # "Awning" slats: 2 x 0.3 x 5.4, centre (x, 8.6, y 1.2), sloping down to the front
AW_C = Vector((0, 1.2, 8.6))
AW_LEN, AW_STRIPE, AW_N = 5.4, 2.0, 7
SIGN_C, SIGN_W, SIGN_H, SIGN_FRONT = Vector((0, 3.2, 10.2)), 10.0, 2.0, 3.0  # "ShopSign" 10 x 2 x 0.4
FRONT = -CD / 2


def star(name, r, center, normal, mat, group, depth=0.08):
    return kit.prism(name, kit.star_pts(5, r, r * 0.45), depth, center, normal, mat, group, bev=0.025, bev_segs=1)


# ── The counter ──────────────────────────────────────────────────────────────────────────────────────────────────
kit.box("Kick", (CW - 0.3, CD - 0.3, 0.5), (0, 0, 0.25), M_NAVY, "Counter", bev=0.08, segs=2)
kit.box("CounterBody", (CW, CD, CH - 0.45), (0, 0, 0.45 + (CH - 0.45) / 2), M_BLUE, "Counter", bev=0.16, segs=3)
for i in range(4):
    x = (i - 1.5) * 3.3
    kit.prism(f"Panel{i}", kit.rounded_rect_pts(2.8, 2.1, 0.28, steps=3), 0.07, (x, FRONT, 1.92), (0, -1, 0), M_BLUE_L, "Counter", bev=0.03, bev_segs=2)
    star(f"PanelStar{i}", 0.62, (x, FRONT - 0.07, 1.92), (0, -1, 0), M_GOLD, "Counter")
kit.box("CounterTop", (TW, TD, TT), (0, 0, CH + TT / 2), M_GOLD, "Counter", bev=0.12, segs=3)


def goods_box(name, w, d, h, at, mat, group, yaw=0.0):
    """A firework box: a glossy coloured box with a paper band round it."""
    rot = Matrix.Rotation(yaw, 3, "Z")
    kit.box(name, (w, d, h), tuple(Vector(at) + Vector((0, 0, h / 2))), mat, group, bev=0.05, segs=1, rot=rot)
    kit.box(name + "Band", (w + 0.02, d + 0.02, h * 0.3), tuple(Vector(at) + Vector((0, 0, h * 0.55))), M_PAPER, group, bev=0.03, segs=1, rot=rot)


def rocket_bundle(name, at, mat, group, n=3):
    """Three little rockets standing in a tied bundle: coloured tubes, white cone tips, a paper tie."""
    for k in range(n):
        a = 2 * math.pi * k / n + 0.4
        p = Vector(at) + Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0))
        h = 1.05 + 0.15 * (k % 2)
        kit.cylinder(f"{name}Tube{k}", 0.14, h, tuple(p + Vector((0, 0, h / 2))), mat, group, segs=6, bev=0.02, bev_segs=1)
        kit.cylinder(f"{name}Tip{k}", 0.17, 0.32, tuple(p + Vector((0, 0, h + 0.16))), M_WHITE, group, segs=6, bev=0.0, r2=0.0)
    kit.torus(f"{name}Tie", 0.33, 0.05, tuple(Vector(at) + Vector((0, 0, 0.45))), M_PAPER, group, major=10, minor=3)


# little stacks at the counter-top's ends
TOPZ = CH + TT
goods_box("TopBoxL", 1.1, 0.9, 0.8, (-6.1, 0.5, TOPZ), M_GOODS[0], "Counter", yaw=0.12)
goods_box("TopBoxL2", 0.8, 0.7, 0.6, (-6.15, 0.5, TOPZ + 0.8), M_GOODS[1], "Counter", yaw=-0.2)
goods_box("TopBoxR", 1.0, 0.9, 0.7, (6.0, 0.6, TOPZ), M_GOODS[2], "Counter", yaw=-0.1)
rocket_bundle("TopRockets", (6.0, 0.6, TOPZ + 0.7), M_GOODS[3], "Counter")

# ── The back wall, its shelves and their goods ──────────────────────────────────────────────────────────────────
kit.box("BackWall", (CW, BACK_Y1 - BACK_Y0, BACK_H), (0, (BACK_Y0 + BACK_Y1) / 2, BACK_H / 2), M_NAVY, "Back", bev=0.14, segs=3)
SHELF_D = 1.0
for si, z in enumerate((4.75, 6.15)):
    kit.box(f"Shelf{si}", (12.6, SHELF_D, 0.18), (0, BACK_Y0 - SHELF_D / 2, z), M_WOOD, "Back", bev=0.05, segs=2)
    for bx in (-5.6, 0.0, 5.6):
        kit.box(f"Bracket{si}{bx}", (0.16, SHELF_D * 0.8, 0.5), (bx, BACK_Y0 - SHELF_D * 0.42, z - 0.32), M_GOLD, "Trim", bev=0.04, segs=1)
    x = -5.9
    k = 0
    while x < 5.9:
        mat = M_GOODS[(k + si * 3) % len(M_GOODS)]
        y = BACK_Y0 - SHELF_D / 2 + rng.uniform(-0.08, 0.08)
        if (k + si) % 3 == 2:
            rocket_bundle(f"ShelfRockets{si}{k}", (x + 0.35, y, z + 0.09), mat, "Back")
            x += 1.05
        else:
            w = rng.uniform(0.75, 1.05)
            h = rng.uniform(0.6, 0.95)
            goods_box(f"ShelfBox{si}{k}", w, 0.7, h, (x + w / 2, y, z + 0.09), mat, "Back", yaw=rng.uniform(-0.12, 0.12))
            x += w + 0.22
        k += 1

# ── The awning: seven puffy stripes on the old slats' slope, a scalloped valance, a gold rod ────────────────────
aw_rot = Matrix.Rotation(AW_TILT, 3, "X")  # turns the slab so its back (+Y) end rises
along = aw_rot @ Vector((0, 1, 0))
aw_n = aw_rot @ Vector((0, 0, 1))
front_edge = AW_C - along * (AW_LEN / 2)
for i in range(AW_N):
    x = -CW / 2 + AW_STRIPE * (i + 0.5)
    mat = M_RED if i % 2 == 0 else M_WHITE
    kit.box(f"Stripe{i}", (AW_STRIPE + 0.02, AW_LEN, 0.34), tuple(AW_C + Vector((x, 0, 0)) + aw_n * 0.02), mat, "Awning", bev=0.13, segs=3, rot=aw_rot)
    # the scallop under this stripe's front edge: a half-disc flap, its top tucked under the stripe
    pts = [(-AW_STRIPE / 2, 0.32), (-AW_STRIPE / 2, 0.0)]
    for j in range(1, 10):
        a = math.pi + math.pi * j / 10
        pts.append((math.cos(a) * AW_STRIPE / 2, math.sin(a) * AW_STRIPE * 0.42))
    pts += [(AW_STRIPE / 2, 0.0), (AW_STRIPE / 2, 0.32)]
    kit.prism(f"Scallop{i}", pts, 0.12, front_edge + Vector((x, 0.02, -0.28)), (0, -1, 0), mat, "Awning", bev=0.04, bev_segs=1)
kit.cylinder("AwningRod", 0.11, CW + 0.5, tuple(front_edge + Vector((0, -0.16, -0.04))), M_GOLD, "Trim", axis="X", segs=12, bev=0.03, bev_segs=1)
for sx in (-1, 1):
    kit.sphere(f"RodKnob{sx}", 0.2, tuple(front_edge + Vector((sx * (CW / 2 + 0.3), -0.16, -0.04))), M_GOLD, "Trim", u=12, v=8)

# the poles: from the counter top's front corners up under the awning's front edge
for sx in (-1, 1):
    px, py = sx * (CW / 2 - 0.35), FRONT + 0.3
    # the awning's underside above (px, py)
    t = (py - AW_C.y) / along.y
    top = (AW_C + along * t).z - 0.17
    h = top - TOPZ
    kit.cylinder(f"Pole{sx}", 0.13, h, (px, py, TOPZ + h / 2), M_GOLD, "Trim", segs=12, bev=0.02, bev_segs=1)
    kit.cylinder(f"PoleFoot{sx}", 0.24, 0.14, (px, py, TOPZ + 0.07), M_GOLD, "Trim", segs=12, bev=0.04, bev_segs=1)
    for zz in (0.5,):
        kit.torus(f"PoleRing{sx}{zz}", 0.14, 0.045, (px, py, TOPZ + h * zz), M_GOLD, "Trim", major=12, minor=5)

# ── The sign frame round MapDepot's ShopSign (its SurfaceGui text stays on the part) ────────────────────────────
outer = kit.rounded_rect_pts(SIGN_W + 0.8, SIGN_H + 0.8, 0.4, steps=4)
inner = kit.rounded_rect_pts(SIGN_W - 0.1, SIGN_H - 0.1, 0.1, steps=4)
bm_c = Vector((0, SIGN_C.y + 0.22, SIGN_C.z))  # the back face, just behind the sign's back
# a ring standing proud of the sign's front by 0.08
bm = bmesh.new()
depth = 0.22 + 0.2 + 0.08
ob = [bm.verts.new((p[0], p[1], 0)) for p in outer]
ot = [bm.verts.new((p[0], p[1], depth)) for p in outer]
ib = [bm.verts.new((p[0], p[1], 0)) for p in inner]
it = [bm.verts.new((p[0], p[1], depth)) for p in inner]
n = len(outer)
for i in range(n):
    j = (i + 1) % n
    bm.faces.new((ot[i], ot[j], it[j], it[i]))
    bm.faces.new((ob[j], ob[i], ib[i], ib[j]))
    bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
    bm.faces.new((ib[j], ib[i], it[i], it[j]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
kit.orient(bm, (0, -1, 0), bm_c)
frame = kit.give(kit.mesh_obj("SignFrame", bm, "Trim"), M_GOLD)
kit.bevel(frame, 0.06, 2, angle=30)
kit.smooth(frame)
for sx in (-1, 1):
    star(f"SignStar{sx}", 0.85, (sx * (SIGN_W / 2 + 0.75), SIGN_FRONT - 0.04, SIGN_C.z), (0, -1, 0), M_GOLD, "Trim", depth=0.16)
star("SignStarTop", 0.6, (0, SIGN_FRONT - 0.04, SIGN_C.z + SIGN_H / 2 + 0.55), (0, -1, 0), M_GOLD, "Trim", depth=0.14)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

# Review-only stand-in for the game's ShopSign (navy board with its text); never baked or exported.
preview = []
if DO_RENDER:
    kit.S.groups["_preview"] = []
    preview.append(kit.box("PrevSign", (SIGN_W, 0.4, SIGN_H), tuple(SIGN_C), kit.mat_flat("PrevSignMat", NAVY, 0.5), "_preview", bev=0.03))
    kit.text("PrevText", "FIREWORKS & SKINS", 1.05, 0.04, kit.mat_flat("PrevSpark", srgb("#FFD84A"), 0.4), "_preview", (0, SIGN_FRONT - 0.03, SIGN_C.z), bold=0.02, bev=0.0)
    preview.append(kit.S.groups["_preview"][-1])

kit.render_setup(target=(0, 0, 5.0))
if DO_RENDER:
    kit.shoot("hero", (14.0, -24.0, 9.0), lens=40, target=(0, 0.5, 5.5))
    kit.shoot("front", (0, -30.0, 6.0), lens=45, target=(0, 0.5, 5.6))
    kit.shoot("awning", (-6.0, -9.0, 6.0), lens=35, target=(-1.5, 0.0, 7.4))
    kit.shoot("side", (24.0, -6.0, 8.0), lens=45, target=(0, 1.0, 5.5))
    for o in preview:
        o.hide_render = True

maps = kit.bake_all(parts, {"Counter": 1024, "Back": 1024, "Awning": 1024, "Trim": 1024}) if BAKE else {}
kit.export_fbx(parts)
origin = Vector((0, 0, 0))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "GDD §19.1 the Depot's shop stall; Asset Bible §4.3",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "glow": [],
        "markers": {
            "CounterBase": {"blender": kit.blend(origin), "roblox_from_pivot": kit.rbx(origin, pivot)},
            "ShopSign": {"blender": kit.blend(SIGN_C), "roblox_from_pivot": kit.rbx(SIGN_C, pivot)},
        },
        "front_note": "The counter's customer side faces the front (-Y in Blender = the model's LookVector in Roblox). "
        "CounterBase = MapDepot's Counter bottom centre (ShopKiosk 'SC').",
    }
)
