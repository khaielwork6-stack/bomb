"""FUSE VALLEY — the Depot's toy powder keg (MapDepot Dressing "Barrel"; GDD §19.1 lobby, Asset Bible §4.3 props).

A chunky cartoon powder keg the size of MapDepot's part-built barrel (2 across, 3 tall): a bulged keg of twelve
orange-wood staves (each its own shade, grooves between them, grain along them) with a raised chime round a recessed
lid, four glossy red hoops riveted in gold, a curved cream label on the front with the bomb emblem, and a brass bung on
the lid with a short curled fuse ending in a lit spark (glow part).

MeshPart groups: Wood (the keg), Trim (hoops, label, emblem, bung, fuse), Spark (Neon glow).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_powder_keg.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.PowderKeg/  (renders/, export/Prop.PowderKeg.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the label). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import kit  # noqa: E402
from kit import Vector, srgb  # noqa: E402

KEY = "Prop.PowderKeg"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Wood", "Trim"], glow=["Spark"])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
WOOD_A, WOOD_B, WOOD_HI, WOOD_DK = srgb("#D2843E"), srgb("#E89A50"), srgb("#FFC888"), srgb("#7A4420")
RED, RED_HI, RED_EDGE = srgb("#D8202C"), srgb("#FF5048"), srgb("#FF9A90")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
CREAM, CREAM_HI = srgb("#FFEFD2"), srgb("#FFFFFF")
INK, INK_HI = srgb("#1A1822"), srgb("#4A4658")
ORANGE, ORANGE_HI = srgb("#FF8A1E"), srgb("#FFC060")
CORD, CORD_HI = srgb("#C8945A"), srgb("#F0C890")

STAVES = 12


def mat_staves(name):
    """Orange-wood staves round Z: each stave its own shade (white noise per stave index), a dark groove between them
    (and in the normal map), grain along the stave, a top-lit gradient and bright worn edges."""
    m, nt, b = kit.new_mat(name)
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    sep = kit.nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    ang = kit.nd(nt, "ShaderNodeMath", operation="ARCTAN2")
    nt.links.new(sep.outputs["Y"], ang.inputs[0])
    nt.links.new(sep.outputs["X"], ang.inputs[1])
    sc = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    sc.inputs[1].default_value = STAVES / (2 * math.pi)
    nt.links.new(ang.outputs[0], sc.inputs[0])
    fr = kit.nd(nt, "ShaderNodeMath", operation="FRACT")
    nt.links.new(sc.outputs[0], fr.inputs[0])
    fl = kit.nd(nt, "ShaderNodeMath", operation="FLOOR")
    nt.links.new(sc.outputs[0], fl.inputs[0])
    wn = kit.nd(nt, "ShaderNodeTexWhiteNoise", noise_dimensions="1D")
    nt.links.new(fl.outputs[0], wn.inputs["W"])
    col = kit.mix_rgb(nt, wn.outputs["Value"], WOOD_A, WOOD_B)
    # grain: stretched waves along Z
    mp = kit.nd(nt, "ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (5.0, 5.0, 0.6)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = kit.nd(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    wave.inputs["Scale"].default_value = 2.0
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 3.0
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    col = kit.mix_rgb(nt, kit.map_range(nt, wave.outputs["Fac"], 0.3, 1.0, 0.0, 0.14), col, WOOD_DK)
    # groove: near the stave's edges (fract near 0 or 1)
    pp = kit.nd(nt, "ShaderNodeMath", operation="PINGPONG")
    pp.inputs[1].default_value = 0.5
    nt.links.new(fr.outputs[0], pp.inputs[0])
    groove = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    groove.inputs["From Min"].default_value = 0.0
    groove.inputs["From Max"].default_value = 0.06
    groove.inputs["To Min"].default_value = 1.0
    groove.inputs["To Max"].default_value = 0.0
    nt.links.new(pp.outputs[0], groove.inputs["Value"])
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.6, 1.0, 0.35), col, WOOD_HI)
    col = kit.mix_rgb(nt, kit.map_range(nt, groove.outputs["Result"], 0, 1, 0, 0.75), col, WOOD_DK)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.04, 2.5), col, WOOD_HI)
    col = kit.ao_mult(nt, col, 0.7)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(kit.map_range(nt, wave.outputs["Fac"], 0, 1, 0.5, 0.72), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    inv = kit.nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(groove.outputs["Result"], inv.inputs[1])
    h = kit.nd(nt, "ShaderNodeMath", operation="ADD")
    nt.links.new(inv.outputs[0], h.inputs[0])
    nt.links.new(kit.map_range(nt, wave.outputs["Fac"], 0, 1, 0, 0.15), h.inputs[1])
    bn = kit.nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.45
    bn.inputs["Distance"].default_value = 0.03
    nt.links.new(h.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


M_WOOD = mat_staves("Staves")
M_RED = kit.mat_paint_metal("Hoops", RED, RED_HI, RED_EDGE, srgb("#8A8C98"), rough=0.3, chip=0.5)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_CREAM = kit.mat_gloss("Label", CREAM, CREAM_HI, rough=0.45, grad=0.3, ao=0.45)
M_INK = kit.mat_gloss("Ink", INK, INK_HI, rough=0.3, grad=0.4)
M_ORANGE = kit.mat_gloss("Orange", ORANGE, ORANGE_HI, rough=0.35, grad=0.4)
M_CORD = kit.mat_carpet("Cord", CORD, CORD_HI, srgb("#8A5E30"))
M_SPARK = kit.mat_emit("Spark", srgb("#FFD84A"), 6.0)

# ── Dimensions (studs): MapDepot's "Barrel" is 3 tall, 2 across ─────────────────────────────────────────────────
KH = 3.0  # keg height
R_END, R_MID = 0.9, 1.06
LID_Z = KH - 0.16


def r_at(z):
    t = (z / KH) * 2 - 1
    return R_END + (R_MID - R_END) * (1 - t * t)


# The keg: one closed lathe — bottom, bulged side, the chime, down into the recessed lid.
prof = [(0.0, 0.0), (R_END - 0.08, 0.0), (R_END - 0.01, 0.03)]
for i in range(1, 15):
    z = KH * i / 15
    prof.append((r_at(z), z))
prof[-1] = (R_END - 0.01, KH - 0.03)
prof += [(R_END - 0.1, KH), (R_END - 0.15, KH - 0.04), (R_END - 0.16, LID_Z + 0.02), (R_END - 0.2, LID_Z), (0.0, LID_Z)]
kit.lathe("Keg", prof, M_WOOD, "Wood", segs=STAVES * 4)

# Hoops: four red bands riding the bulge, gold rivets on each.
for k, z in enumerate((0.3, 0.78, KH - 0.78, KH - 0.3)):
    r = r_at(z)
    kit.torus(f"Hoop{k}", r + 0.01, 0.075, (0, 0, z), M_RED, "Trim", major=32, minor=7, scale=(1, 1, 1.9))
    for j in range(4):
        a = math.radians(45 + 90 * j + (22.5 if k % 2 else 0))
        n = Vector((math.cos(a), math.sin(a), 0))
        kit.rivet(f"HoopRivet{k}{j}", tuple(n * (r + 0.085) + Vector((0, 0, z))), tuple(n), M_GOLD, "Trim", r=0.06, segs=8)


def curved_plate(name, z0, z1, a0, a1, lift, thick, mat, group, cols=10):
    """A plate wrapped on the keg's surface between heights z0..z1 and angles a0..a1, `lift` off it, `thick` deep."""
    bm = bmesh.new()
    rows = 4
    grid_o, grid_i = [], []
    for i in range(rows + 1):
        z = z0 + (z1 - z0) * i / rows
        ro, ri = [], []
        for j in range(cols + 1):
            a = a0 + (a1 - a0) * j / cols
            n = Vector((math.cos(a), math.sin(a), 0))
            r = r_at(z)
            ro.append(bm.verts.new(n * (r + lift + thick) + Vector((0, 0, z))))
            ri.append(bm.verts.new(n * (r + lift - 0.02) + Vector((0, 0, z))))
        grid_o.append(ro)
        grid_i.append(ri)
    for i in range(rows):
        for j in range(cols):
            bm.faces.new((grid_o[i][j], grid_o[i][j + 1], grid_o[i + 1][j + 1], grid_o[i + 1][j]))
            bm.faces.new((grid_i[i][j], grid_i[i + 1][j], grid_i[i + 1][j + 1], grid_i[i][j + 1]))
    for i in range(rows):
        for j in (0, cols):
            bm.faces.new((grid_o[i][j], grid_o[i + 1][j], grid_i[i + 1][j], grid_i[i][j]))
    for j in range(cols):
        for i in (0, rows):
            bm.faces.new((grid_o[i][j], grid_i[i][j], grid_i[i][j + 1], grid_o[i][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = kit.give(kit.mesh_obj(name, bm, group), mat)
    kit.bevel(o, 0.02, 1, angle=40)
    return kit.smooth(o)


# The label on the front (-Y): a curved cream plate between the middle hoops, the bomb emblem on it.
FA = -math.pi / 2
curved_plate("Label", 1.04, 1.96, FA - 0.52, FA + 0.52, 0.0, 0.04, M_CREAM, "Trim")
LZ = 1.47
front_r = r_at(LZ) + 0.05
ic = Vector((-0.05, -front_r, LZ - 0.06))
kit.cylinder("EmblemBomb", 0.27, 0.06, tuple(ic + Vector((0, -0.02, 0))), M_INK, "Trim", axis="Y", segs=20, bev=0.02, bev_segs=1)
kit.box("EmblemCap", (0.14, 0.06, 0.1), tuple(ic + Vector((0.13, -0.03, 0.22))), M_INK, "Trim", bev=0.02, segs=1)
kit.rope("EmblemFuse", [tuple(ic + Vector((0.16, -0.04, 0.27))), tuple(ic + Vector((0.24, -0.04, 0.38))), tuple(ic + Vector((0.32, -0.04, 0.36)))], 0.024, M_CORD, "Trim", res=3, bres=1)
kit.prism("EmblemSpark", kit.star_pts(6, 0.13, 0.05), 0.03, ic + Vector((0.36, -0.05, 0.39)), (0, -1, 0), M_ORANGE, "Trim", bev=0.0, smooth_it=False)
kit.sphere("EmblemShine", 0.055, tuple(ic + Vector((-0.1, -0.06, 0.1))), M_CREAM, "Trim", scale=(1, 0.4, 1), u=8, v=6)
# stencilled stars either side of the emblem
for sx, dz in ((-1, 0.3), (1, -0.3)):
    a = FA + sx * 0.38
    n = Vector((math.cos(a), math.sin(a), 0))
    kit.prism(f"LabelStar{sx}", kit.star_pts(5, 0.12, 0.05), 0.03, n * (r_at(LZ + dz) + 0.04) + Vector((0, 0, LZ + dz)), tuple(n), M_ORANGE, "Trim", bev=0.0, smooth_it=False)

# The bung on the lid and its fuse.
BUNG = Vector((0.32, 0.12, LID_Z))
kit.cylinder("Bung", 0.2, 0.16, tuple(BUNG + Vector((0, 0, 0.08))), M_GOLD, "Trim", segs=16, bev=0.03, bev_segs=1)
kit.torus("BungRing", 0.2, 0.035, tuple(BUNG + Vector((0, 0, 0.03))), M_GOLD, "Trim", major=16, minor=6)
FUSE = [tuple(BUNG + Vector((0, 0, 0.15))), tuple(BUNG + Vector((0.0, 0.0, 0.42))), tuple(BUNG + Vector((0.14, -0.06, 0.62))), tuple(BUNG + Vector((0.34, -0.1, 0.66)))]
kit.rope("Fuse", FUSE, 0.045, M_CORD, "Trim", res=5, bres=2)
SPARK_AT = Vector(FUSE[-1]) + Vector((0.06, -0.02, 0.03))
kit.prism("Spark", kit.star_pts(8, 0.2, 0.08), 0.05, SPARK_AT, (0, -1, 0), M_SPARK, "Spark", bev=0.012, bev_segs=1)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), flush=True)

kit.render_setup(target=(0, 0, 1.7))
if DO_RENDER:
    kit.shoot("hero", (4.6, -7.4, 4.0), lens=50, target=(0, 0, 1.75))
    kit.shoot("front", (0, -9.5, 1.8), lens=50, target=(0, 0, 1.75))
    kit.shoot("top", (2.0, -3.6, 6.2), lens=45, target=(0.1, 0, 2.7))

maps = kit.bake_all(parts, {"Wood": 1024, "Trim": 1024}) if BAKE else {}
kit.export_fbx(parts)
foot = Vector((0, 0, 0))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "GDD §19.1 the Depot lobby dressing; Asset Bible §4.3",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "keg_height_studs": KH,
        "parts": maps,
        "glow": ["Spark"],
        "markers": {
            "KegBase": {"blender": kit.blend(foot), "roblox_from_pivot": kit.rbx(foot, pivot)},
            "Spark": {"blender": kit.blend(SPARK_AT), "roblox_from_pivot": kit.rbx(SPARK_AT, pivot)},
        },
        "front_note": "The label faces the front (-Y in Blender = the model's LookVector in Roblox).",
    }
)
