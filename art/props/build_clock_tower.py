"""FUSE VALLEY — the Depot's MEGA BOMB clock tower shell (GDD §19.1 lobby / §15 MEGA BOMB clock, Asset Bible §4.3).

The modelled shell of MapDepot's part-built "ClockTower", at the same size (1 Blender unit = 1 stud): a toy-brick tower
on a cream stone plinth, a 6 x 6 rounded shaft 26 studs tall in chunky red toy bricks, four cream bands, arched navy
windows with cream frames and sills, a gold frame round the front clock face (the game's own "ClockFace" part, which
DepotController writes the countdown on, sits inside it), cream bomb roundels on the other three sides, a cream cornice,
a gold crown band with ball finials, a red dome and a gold cup the giant hero bomb (DepotController's FV_TowerBomb,
radius 3.3, centred 36 studs up) sits in.
NOT in the mesh (they stay MapDepot's parts, which the code reads): ClockFace, TowerBomb, SpiralFuse.Seg*, Spark.
Everything stays inside the old shell's envelope: the 8 x 8 base, and radius <= 4.1 from the axis above it, so the
spiral fuse (radius 4.4) wraps the tower without cutting into it.

MeshPart groups: Brick (shaft, base block), Trim (cream stone, navy windows, roundels, red dome), Gold (clock frame,
crown band, finials, cup, rivets).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_clock_tower.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.ClockTower/  (renders/, export/Prop.ClockTower.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the clock face). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.ClockTower"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Brick", "Trim", "Gold"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
BRICK_A, BRICK_B, BRICK_HI, MORTAR = srgb("#D8402C"), srgb("#E9573A"), srgb("#FF8A66"), srgb("#9E2A1C")
CREAM, CREAM_HI, CREAM_EDGE = srgb("#F2DDB4"), srgb("#FFF6E2"), srgb("#FFFFFF")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
NAVY, NAVY_HI = srgb("#1E3480"), srgb("#3E62C8")
GLASS, GLASS_HI = srgb("#24408E"), srgb("#7FB4FF")
RED, RED_HI = srgb("#D8202C"), srgb("#FF6050")
INK, INK_HI = srgb("#1A1822"), srgb("#4A4658")
ORANGE, ORANGE_HI = srgb("#FF8A1E"), srgb("#FFC060")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")


def mat_brick(name):
    """Chunky toy bricks (2 x 1 studs, half-bond), two reds per brick, deep grooves for mortar (raised bricks in the
    normal map), a top-lit gradient and light bevel edges. Mapped in object space on (x + y, z) so the four faces of a
    square shaft wrap continuously round the corners."""
    m, nt, b = kit.new_mat(name)
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    sep = kit.nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    add = kit.nd(nt, "ShaderNodeMath", operation="ADD")
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Y"], add.inputs[1])
    comb = kit.nd(nt, "ShaderNodeCombineXYZ")
    nt.links.new(add.outputs[0], comb.inputs["X"])
    nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
    br = kit.nd(nt, "ShaderNodeTexBrick", offset=0.5, offset_frequency=2, squash=1.0, squash_frequency=2)
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.06
    br.inputs["Mortar Smooth"].default_value = 0.35
    br.inputs["Bias"].default_value = 0.0
    br.inputs["Brick Width"].default_value = 2.0
    br.inputs["Row Height"].default_value = 1.0
    br.inputs["Color1"].default_value = BRICK_A
    br.inputs["Color2"].default_value = BRICK_B
    br.inputs["Mortar"].default_value = MORTAR
    nt.links.new(comb.outputs[0], br.inputs["Vector"])
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.6, 1.0, 0.3), br.outputs["Color"], BRICK_HI)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.05, 2.0), col, BRICK_HI)
    col = kit.ao_mult(nt, col, 0.6)
    nt.links.new(col, b.inputs["Base Color"])
    n2 = kit.noise_tex(nt, 6.0, 4.0)
    rough = kit.map_range(nt, n2.outputs["Fac"], 0, 1, 0.34, 0.5)
    mix = kit.nd(nt, "ShaderNodeMath", operation="MAXIMUM")
    nt.links.new(rough, mix.inputs[0])
    nt.links.new(kit.map_range(nt, br.outputs["Fac"], 0, 1, 0.0, 0.8), mix.inputs[1])
    nt.links.new(mix.outputs[0], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    inv = kit.nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(br.outputs["Fac"], inv.inputs[1])
    bn = kit.nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.7
    bn.inputs["Distance"].default_value = 0.06
    nt.links.new(inv.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


M_BRICK = mat_brick("Brick")
M_CREAM = kit.mat_paint_metal("Cream", CREAM, CREAM_HI, CREAM_EDGE, srgb("#C8A878"), rough=0.36, chip=0.46, spots=0.8)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_NAVY = kit.mat_gloss("Navy", NAVY, NAVY_HI, edge=srgb("#7A9AFF"), rough=0.3, grad=0.4)
M_GLASS = kit.mat_gloss("Glass", GLASS, GLASS_HI, edge=srgb("#B8D8FF"), rough=0.12, grad=0.7, ao=0.5)
M_RED = kit.mat_gloss("Dome", RED, RED_HI, edge=srgb("#FF9A90"), rough=0.26, grad=0.45)
M_INK = kit.mat_gloss("Ink", INK, INK_HI, rough=0.3, grad=0.4)
M_ORANGE = kit.mat_gloss("Orange", ORANGE, ORANGE_HI, rough=0.35, grad=0.4)
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))

# ── Dimensions (studs): MapDepot's ClockTower ────────────────────────────────────────────────────────────────────
BASE_W, BASE_H = 8.0, 3.0  # MapDepot "Base" 8 x 3 x 8
SHAFT_W, SHAFT_TOP = 6.0, 29.0  # "Shaft" 6 x 26 x 6, from 3 to 29
BANDS = (6.0, 13.0, 20.0, 27.0)  # "Band" centres
FACE_Z, FACE_W = 24.0, 4.6  # "ClockFace" 4.6 square, 0.3 thick, its back on the shaft's front
HALF = SHAFT_W / 2
BOMB_Z, BOMB_R = 36.0, 3.3  # DepotController's FV_TowerBomb: the hero bomb (radius 1.1) at scale 3 on "TowerBomb"
SIDES = [Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0))]  # front first


def rsq(name, w, r, z0, h, mat, group, bev=0.08, steps=6, segs=3):
    """A rounded-square slab w x w (corner radius r) from z0 up h."""
    return kit.prism(name, kit.rounded_rect_pts(w, w, r, steps=steps), h, (0, 0, z0), (0, 0, 1), mat, group, bev=bev, bev_segs=segs)


def arch_pts(w, h, steps=8):
    pts = [(-w / 2, 0.0), (w / 2, 0.0)]
    for i in range(steps + 1):
        a = math.pi * i / steps
        pts.append((math.cos(a) * w / 2, h - w / 2 + math.sin(a) * w / 2))
    return pts


def circle_pts(r, n=24):
    return [(math.cos(2 * math.pi * i / n) * r, math.sin(2 * math.pi * i / n) * r) for i in range(n)]


def frame_ring(name, outer, inner, depth, center, normal, mat, group, bev=0.04):
    """A flat ring (outer and inner 2D outlines with the same point count, CCW) extruded `depth` along `normal`."""
    bm = bmesh.new()
    n = len(outer)
    ob = [bm.verts.new((p[0], p[1], 0)) for p in outer]
    ot = [bm.verts.new((p[0], p[1], depth)) for p in outer]
    ib = [bm.verts.new((p[0], p[1], 0)) for p in inner]
    it = [bm.verts.new((p[0], p[1], depth)) for p in inner]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ot[i], ot[j], it[j], it[i]))  # front
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))  # back
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # outer side
        bm.faces.new((ib[j], ib[i], it[i], it[j]))  # inner side
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    kit.orient(bm, normal, center)
    o = kit.give(kit.mesh_obj(name, bm, group), mat)
    kit.bevel(o, bev, 2, angle=30)
    return kit.smooth(o)


def face_frame(n):
    """(right, up) on a side facing n, as seen from outside."""
    up = Vector((0, 0, 1))
    return up.cross(n).normalized(), up


# ── The base: cream plinth, a toy-brick block, cream coping; a navy star panel on every side ─────────────────────
rsq("Plinth", BASE_W, 0.45, 0.0, 0.8, M_CREAM, "Trim", bev=0.12, steps=3, segs=2)
rsq("BaseBlock", BASE_W - 0.5, 0.3, 0.75, 1.9, M_BRICK, "Brick", bev=0.06, segs=2)
rsq("Coping", BASE_W, 0.45, 2.6, 0.4, M_CREAM, "Trim", bev=0.1, steps=3, segs=2)
for k, n in enumerate(SIDES):
    right, up = face_frame(n)
    c = n * ((BASE_W - 0.5) / 2) + Vector((0, 0, 1.7))
    kit.prism(f"BasePanel{k}", kit.rounded_rect_pts(5.0, 1.25, 0.3, steps=3), 0.08, c, n, M_NAVY, "Trim", bev=0.03, bev_segs=1)
    for j in (-1, 0, 1):
        kit.prism(f"BaseStar{k}{j}", kit.star_pts(5, 0.42 if j == 0 else 0.34, 0.18 if j == 0 else 0.145), 0.07, c + right * (j * 1.55) + n * 0.07, n, M_GOLD, "Gold", bev=0.0, smooth_it=False)
    for sx in (-1, 1):
        kit.rivet(f"BaseRivet{k}{sx}", c + right * (sx * 3.05), n, M_GOLD, "Gold", r=0.14, segs=8)

# ── The shaft and its bands ──────────────────────────────────────────────────────────────────────────────────────
rsq("Shaft", SHAFT_W, 0.6, BASE_H - 0.05, SHAFT_TOP - BASE_H + 0.1, M_BRICK, "Brick", bev=0.06, segs=2)
for i, z in enumerate(BANDS):
    rsq(f"Band{i}", 6.5, 1.3, z - 0.35, 0.7, M_CREAM, "Trim", bev=0.12, steps=3, segs=2)

# ── Windows: two rows of arched navy windows with cream frames and sills on every side ───────────────────────────
for row, z0 in enumerate((7.7, 14.7)):
    for k, n in enumerate(SIDES):
        right, up = face_frame(n)
        c = n * HALF + Vector((0, 0, z0))
        kit.prism(f"WinFrame{row}{k}", arch_pts(2.1, 3.7, steps=4), 0.12, c, n, M_CREAM, "Trim", bev=0.04, bev_segs=1)
        kit.prism(f"WinGlass{row}{k}", arch_pts(1.55, 3.15, steps=4), 0.07, c + up * 0.27 + n * 0.12, n, M_GLASS, "Trim", bev=0.025, bev_segs=1)
        # a sill, and glazing bars up the middle and across (cream)
        kit.box(f"WinSill{row}{k}", (2.5, 0.32, 0.26), c + n * 0.16 - up * 0.08, M_CREAM, "Trim", bev=0.06, segs=1, rot=Matrix((right, n, up)).transposed())
        rot = Matrix((right, n, up)).transposed()
        kit.box(f"WinBarV{row}{k}", (0.14, 0.06, 2.8), c + up * (0.27 + 1.4) + n * 0.21, M_CREAM, "Trim", bev=0.02, segs=1, rot=rot)
        kit.box(f"WinBarH{row}{k}", (1.5, 0.06, 0.14), c + up * 1.75 + n * 0.21, M_CREAM, "Trim", bev=0.02, segs=1, rot=rot)

# ── The clock: a gold frame round MapDepot's ClockFace (4.6 square, 0.3 thick, front at -3.3) ────────────────────
FN = SIDES[0]
FC = FN * HALF + Vector((0, 0, FACE_Z))
frame_ring("ClockFrame", kit.rounded_rect_pts(5.6, 5.6, 0.75, steps=4), kit.rounded_rect_pts(4.45, 4.45, 0.22, steps=4), 0.44, FC, FN, M_GOLD, "Gold", bev=0.06)
for sx in (-1, 1):
    for sz in (-1, 1):
        kit.rivet(f"FrameRivet{sx}{sz}", FC + Vector((sx * 2.48, 0, sz * 2.48)) + FN * 0.44, FN, M_GOLD, "Gold", r=0.12, segs=8)

# ── Bomb roundels on the other three sides ───────────────────────────────────────────────────────────────────────
for k, n in enumerate(SIDES[1:], start=1):
    right, up = face_frame(n)
    c = n * HALF + Vector((0, 0, FACE_Z))
    kit.prism(f"RoundDisc{k}", circle_pts(2.05, 20), 0.14, c, n, M_CREAM, "Trim", bev=0.05, bev_segs=1)
    kit.torus(f"RoundRing{k}", 2.08, 0.2, tuple(c + n * 0.12), M_GOLD, "Gold", axis="Y" if abs(n.y) > 0.5 else "X", major=24, minor=5)
    ic = c + n * 0.14 - up * 0.15 - right * 0.1
    kit.prism(f"IconBomb{k}", circle_pts(0.95, 20), 0.1, ic, n, M_INK, "Trim", bev=0.035, bev_segs=1)
    kit.box(f"IconCap{k}", (0.5, 0.1, 0.36), ic + up * 1.16 + right * 0.08 + n * 0.05, M_INK, "Trim", bev=0.04, segs=1, rot=Matrix((right, n, up)).transposed())
    kit.prism(f"IconShine{k}", circle_pts(0.2, 10), 0.05, ic + n * 0.1 + up * 0.38 - right * 0.38, n, M_CREAM, "Trim", bev=0.0)
    f0 = ic + up * 1.15 + right * 0.12 + n * 0.08
    kit.rope(f"IconFuse{k}", [tuple(f0), tuple(f0 + up * 0.35 + right * 0.2), tuple(f0 + up * 0.45 + right * 0.6)], 0.07, M_CORD, "Trim", res=3, bres=1)
    kit.prism(f"IconSpark{k}", kit.star_pts(7, 0.4, 0.16), 0.08, f0 + up * 0.5 + right * 0.85 - n * 0.02, n, M_ORANGE, "Trim", bev=0.0, smooth_it=False)

# ── The top: cornice, gold crown band with ball finials, a red dome, the gold cup the bomb sits in ───────────────
rsq("Cornice", 7.1, 1.9, SHAFT_TOP - 0.05, 0.75, M_CREAM, "Trim", bev=0.14, steps=5, segs=2)
rsq("CrownBand", 6.6, 1.6, SHAFT_TOP + 0.65, 0.85, M_GOLD, "Gold", bev=0.12, steps=5, segs=2)
for k in range(4):
    a = math.radians(45 + 90 * k)
    kit.sphere(f"Finial{k}", 0.36, (math.cos(a) * 3.45, math.sin(a) * 3.45, SHAFT_TOP + 1.85), M_GOLD, "Gold", u=10, v=6)
    kit.cylinder(f"FinialFoot{k}", 0.24, 0.3, (math.cos(a) * 3.45, math.sin(a) * 3.45, SHAFT_TOP + 1.55), M_GOLD, "Gold", segs=10, bev=0.04, bev_segs=1)
TOPZ = SHAFT_TOP + 1.5
kit.lathe("Dome", [(0.0, TOPZ - 0.1), (3.12, TOPZ - 0.1), (3.18, TOPZ + 0.12), (3.0, TOPZ + 0.45), (2.55, TOPZ + 0.78), (1.8, TOPZ + 0.98), (0.0, TOPZ + 1.04)], M_RED, "Trim", segs=24)
# the cup: stem, flared bowl, rolled lip — the bomb's underside rests just inside the lip
CZ = TOPZ + 0.85
LIP_R = 2.72
LIP_Z = BOMB_Z - math.sqrt(BOMB_R**2 - LIP_R**2) - 0.12
kit.lathe(
    "Cup",
    [
        (0.0, CZ),
        (1.45, CZ),
        (1.5, CZ + 0.2),
        (1.25, CZ + 0.45),
        (1.4, CZ + 0.7),
        (1.95, CZ + 1.05),
        (2.4, LIP_Z - 0.6),
        (LIP_R + 0.08, LIP_Z - 0.05),
        (LIP_R - 0.12, LIP_Z - 0.02),
        (2.2, LIP_Z - 0.55),
        (1.4, CZ + 1.15),
        (0.0, CZ + 1.1),
    ],
    M_GOLD,
    "Gold",
    segs=24,
)
kit.torus("CupLip", LIP_R, 0.16, (0, 0, LIP_Z), M_GOLD, "Gold", major=24, minor=6)
kit.torus("CupBead", 1.42, 0.1, (0, 0, CZ + 0.7), M_GOLD, "Gold", major=20, minor=5)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

# Review-only stand-ins for the parts the game keeps (the clock face, the spiral fuse, the hero bomb): rendered for
# context, never baked or exported.
preview = []
if DO_RENDER:
    pm_face = kit.mat_flat("PrevFace", srgb("#FFF3E2"), 0.5, ao=0.3)
    pm_bomb = kit.mat_metal("PrevBomb", srgb("#14131A"), srgb("#2A2834"), srgb("#8A86A0"), rough=(0.16, 0.26), metal=0.2, edge_gain=1.0)
    pm_rope = kit.mat_carpet("PrevRope", CORD, CORD_HI, srgb("#8A5E30"))
    pm_spark = kit.mat_emit("PrevSpark", srgb("#FFD84A"), 8.0)
    kit.S.groups["_preview"] = []
    preview.append(kit.box("PrevFace", (FACE_W, 0.3, FACE_W), (0, -HALF - 0.15, FACE_Z), pm_face, "_preview", bev=0.02))
    kit.text("PrevText", "1:24", 1.6, 0.04, kit.mat_flat("PrevInk", INK, 0.4), "_preview", (0, -HALF - 0.32, FACE_Z), bold=0.02, bev=0.0)
    preview.append(kit.S.groups["_preview"][-1])
    preview.append(kit.sphere("PrevBomb", BOMB_R, (0, 0, BOMB_Z), pm_bomb, "_preview", u=48, v=24))
    pts = []
    for i in range(0, 55):
        a = i / 54 * 3 * 2 * math.pi
        # Roblox (cos a * 4.4, 4 + i/54*26, sin a * 4.4) -> Blender (-x, z, y)
        pts.append((-math.cos(a) * 4.4, math.sin(a) * 4.4, 4 + i / 54 * 26))
    preview.append(kit.rope("PrevFuse", pts, 0.25, pm_rope, "_preview", res=4, bres=3))
    preview.append(kit.sphere("PrevSpark", 0.45, pts[18], pm_spark, "_preview", u=16, v=8))

kit.render_setup(target=(0, 0, 17.0))
if DO_RENDER:
    kit.shoot("hero", (36.0, -62.0, 30.0), lens=50, target=(0, 0, 19.0))
    kit.shoot("front", (0, -78.0, 18.0), lens=50, target=(0, 0, 19.5))
    kit.shoot("top", (14.0, -26.0, 36.0), lens=50, target=(0, 0, 29.5))
    kit.shoot("base", (10.0, -16.0, 6.0), lens=40, target=(0, 0, 4.0))
    kit.shoot("back", (-30.0, 50.0, 22.0), lens=50, target=(0, 0, 18.0))
    for o in preview:
        o.hide_render = True
    kit.shoot("shell", (36.0, -62.0, 30.0), lens=50, target=(0, 0, 19.0))

maps = kit.bake_all(parts, {"Brick": 2048, "Trim": 2048, "Gold": 1024}) if BAKE else {}
kit.export_fbx(parts, scale=0.1)  # over 20.48 studs tall: see kit.export_fbx
face_c = Vector((0, -HALF - 0.15, FACE_Z))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "GDD §19.1 the Depot lobby, §15 MEGA BOMB clock; Asset Bible §4.3",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "shaft_height_studs": SHAFT_TOP - BASE_H,
        "parts": maps,
        "glow": [],
        "markers": {
            "ClockFaceCentre": {"blender": kit.blend(face_c), "roblox_from_pivot": kit.rbx(face_c, pivot)},
            "TowerBomb": {"blender": [0, 0, BOMB_Z], "roblox_from_pivot": kit.rbx((0, 0, BOMB_Z), pivot)},
        },
        "front_note": "The clock frame faces the front (-Y in Blender = the model's LookVector in Roblox). The pivot is the "
        "base's bottom centre = MapDepot's Base bottom centre; the model is built 1:1 with MapDepot's tower.",
    }
)
