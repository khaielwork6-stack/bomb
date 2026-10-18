"""FUSE VALLEY — the winner's crown (GDD §8.3 F-WIN-04, Asset Bible §5.5; the level-50 Obsidian Crown, §8.6).

A real royal crown in the toy style, ~1.4 studs wide and ~1.2 tall: a rounded gold band with embossed rims, five tall
concave-sided points with ball finials and five small fleur-de-lis points between them, big faceted gems set in the
band (ruby front, sapphires, emeralds) with a row of small diamonds between, a gem on every tall point, a puffy red
velvet cap with five gold arches over it meeting under an orb with a star on top.

MeshPart groups: Gold (band, points, arches, bezels), Velvet (the cap), Gems (every stone, ONE group so Studio can
make them Neon or recolour them), Finials (balls, fleurs, orb, star).
Two texture sets on the same mesh/UVs: the gold crown (export/textures/) and the OBSIDIAN crown (black volcanic glass
with violet veins, dark-violet velvet, amethysts) in export/textures_obsidian/.
The code's sparkler is NOT in the mesh; the manifest's "sparkler_base" is the top centre (from the pivot).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_crown.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Crown/  (renders/, export/Prop.Crown.fbx, export/textures*/ *.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import kit  # noqa: E402
from kit import Matrix, Vector, srgb  # noqa: E402

KEY = "Prop.Crown"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Gold", "Velvet", "Gems", "Finials"], glow=[])

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
GOLD_LO, GOLD, GOLD_HI = srgb("#E39A1C"), srgb("#FFD03A"), srgb("#FFF6C4")
VELVET, VELVET_HI, VELVET_DK = srgb("#C0142E"), srgb("#F04A5E"), srgb("#6A0616")
GEMS = {
    "Ruby": (srgb("#7A0012"), srgb("#E8182E"), srgb("#FFB0B8")),
    "Sapphire": (srgb("#0A1E7A"), srgb("#2A62FF"), srgb("#B8D0FF")),
    "Emerald": (srgb("#03562A"), srgb("#18C860"), srgb("#B8FFD2")),
    "Diamond": (srgb("#8FB6D8"), srgb("#E6F4FF"), srgb("#FFFFFF")),
}
# The OBSIDIAN set: black volcanic glass with violet veins, dark-violet velvet, amethysts.
OBS_LO, OBS, OBS_HI, OBS_EDGE = srgb("#07050C"), srgb("#1A1426"), srgb("#3A2C56"), srgb("#8A6CC8")
VEIN, VEIN_HOT = srgb("#9A3CFF"), srgb("#E6B0FF")
OVELVET, OVELVET_HI, OVELVET_DK = srgb("#2C0C4C"), srgb("#5C2A96"), srgb("#12041F")
OGEMS = {
    "Ruby": (srgb("#3A0A6A"), srgb("#B040FF"), srgb("#F0C8FF")),
    "Sapphire": (srgb("#200A5A"), srgb("#7A3CFF"), srgb("#D8C4FF")),
    "Emerald": (srgb("#4A0A5A"), srgb("#D050FF"), srgb("#FFD0FF")),
    "Diamond": (srgb("#7A60A8"), srgb("#E8DCFF"), srgb("#FFFFFF")),
}


def mat_gem(name, deep, mid, hi):
    """A cut stone: each flat facet takes its own shade (deep -> mid -> hi by how it faces a fixed key light), a bright
    edge glint on the facet edges, glassy roughness."""
    m, nt, b = kit.new_mat(name)
    geo = kit.nd(nt, "ShaderNodeNewGeometry")
    dot = kit.nd(nt, "ShaderNodeVectorMath", operation="DOT_PRODUCT")
    dot.inputs[1].default_value = Vector((0.45, -0.55, 0.7)).normalized()
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    t = kit.map_range(nt, dot.outputs["Value"], -0.4, 1.0, 0.0, 1.0)
    col = kit.mix_rgb(nt, t, deep, mid)
    t2 = kit.map_range(nt, dot.outputs["Value"], 0.82, 1.0, 0.0, 1.0)
    col = kit.mix_rgb(nt, t2, col, hi)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.006, 3.0), col, hi, blend="SCREEN")
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.06
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Coat Weight"].default_value = 0.6
    return m


def mat_obsidian(name, vein_amt=1.0):
    """Black volcanic glass: top-lit near-black, lavender bevel glints, branching violet veins."""
    m, nt, b = kit.new_mat(name)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.6, 1.0, 1.0), OBS_LO, OBS)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.012, 3.0), col, OBS_EDGE)
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    n = kit.nd(nt, "ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 2.6
    n.inputs["Detail"].default_value = 4.0
    n.inputs["Distortion"].default_value = 1.6
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    sub = kit.nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    sub.inputs[1].default_value = 0.5
    nt.links.new(n.outputs["Fac"], sub.inputs[0])
    ab = kit.nd(nt, "ShaderNodeMath", operation="ABSOLUTE")
    nt.links.new(sub.outputs[0], ab.inputs[0])
    # a coarse mask so the veins come and go (a few bold cracks, not a marble net)
    n2 = kit.nd(nt, "ShaderNodeTexNoise")
    n2.inputs["Scale"].default_value = 1.4
    n2.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    mask = kit.map_range(nt, n2.outputs["Fac"], 0.42, 0.58, 0.0, 1.0)
    v0 = kit.map_range(nt, ab.outputs[0], 0.0, 0.022 * vein_amt, 1.0, 0.0)
    h0 = kit.map_range(nt, ab.outputs[0], 0.0, 0.007 * vein_amt, 1.0, 0.0)
    vm = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(v0, vm.inputs[0])
    nt.links.new(mask, vm.inputs[1])
    hm = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(h0, hm.inputs[0])
    nt.links.new(mask, hm.inputs[1])
    vein, hot = vm.outputs[0], hm.outputs[0]
    col = kit.mix_rgb(nt, vein, col, VEIN)
    col = kit.mix_rgb(nt, hot, col, VEIN_HOT)
    col = kit.ao_mult(nt, col, 0.5)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(kit.map_range(nt, vein, 0, 1, 0.08, 0.3), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    return m


def mat_velvet(name, base, hi, dark):
    """Plush velvet: soft fibre shading (low contrast, so it doesn't read as sponge), lighter on the tops, matte."""
    m, nt, b = kit.new_mat(name)
    n = kit.noise_tex(nt, 90.0, 6.0)
    fib = kit.map_range(nt, n.outputs["Fac"], 0.3, 0.7, 0.0, 0.35)
    col = kit.mix_rgb(nt, fib, base, dark)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.1, 1.0, 0.45), col, hi)
    col = kit.ao_mult(nt, col, 0.75, dist=0.12)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.8
    b.inputs["Metallic"].default_value = 0.0
    bump = kit.nd(nt, "ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(n.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI, rough=(0.12, 0.24))
M_FIN = kit.mat_metal("FinialGold", GOLD_LO, GOLD, GOLD_HI, rough=(0.1, 0.2), edge_gain=5.0)
M_VELVET = mat_velvet("Velvet", VELVET, VELVET_HI, VELVET_DK)
M_GEM = {k: mat_gem("Gem" + k, *v) for k, v in GEMS.items()}
OBS_SWAP = {
    "Gold": mat_obsidian("ObsGold"),
    "FinialGold": mat_obsidian("ObsFinial", vein_amt=1.4),
    "Velvet": mat_velvet("ObsVelvet", OVELVET, OVELVET_HI, OVELVET_DK),
}
OBS_SWAP.update({"Gem" + k: mat_gem("ObsGem" + k, *v) for k, v in OGEMS.items()})

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
R0 = 0.585  # band outer radius
T = 0.05  # shell thickness
BT = 0.36  # band top (the points rise above it)
FLARE = 0.16  # the points lean out: + FLARE studs of radius per stud of height above the band
HB, WB = 0.38, 0.215  # tall point: height above the band, half-width (arc studs)
HS, WS = 0.17, 0.12  # small point
LIP = 0.05  # the shell's top edge between points, above the band top
COLS = 120
FRONT = -math.pi / 2  # angle of the front (-Y)
BIG = [FRONT + k * 2 * math.pi / 5 for k in range(5)]
SMALL = [a + math.pi / 5 for a in BIG]


def ang_dist(a, b):
    return abs((a - b + math.pi) % (2 * math.pi) - math.pi)


def top_h(a):
    s_b = min(ang_dist(a, c) for c in BIG) * R0
    s_s = min(ang_dist(a, c) for c in SMALL) * R0
    hb = HB * (1 - s_b / WB) ** 1.6 if s_b < WB else 0.0
    hs = HS * (1 - s_s / WS) ** 1.6 if s_s < WS else 0.0
    return BT + LIP + max(hb, hs, 0.0)


def rad_at(z):
    return R0 + max(0.0, z - BT) * FLARE


def out_dir(a):
    return Vector((math.cos(a), math.sin(a), 0))


def surf_normal(a):
    """Outward normal of the flared point surface at angle a."""
    return (out_dir(a) - Vector((0, 0, FLARE))).normalized()


# Band + points: one continuous shell, the top edge following top_h (only its top edges bevelled round). Columns are
# denser across the points (every point's tip is a column) and sparse on the flat lip between them.
angles = set()
for c in BIG:
    for j in range(-5, 6):
        angles.add(round((c + j / 5 * WB / R0 - FRONT) % (2 * math.pi), 6))
for c in SMALL:
    for j in range(-3, 4):
        angles.add(round((c + j / 3 * WS / R0 - FRONT) % (2 * math.pi), 6))
angles = sorted(angles)
fill = []
for i, a0 in enumerate(angles):
    a1 = angles[(i + 1) % len(angles)] + (2 * math.pi if i == len(angles) - 1 else 0)
    n_extra = int((a1 - a0) * R0 / 0.07)
    fill += [a0 + (a1 - a0) * (k + 1) / (n_extra + 1) for k in range(n_extra)]
angles = sorted(angles + [a % (2 * math.pi) for a in fill])
COLS = len(angles)
bm = bmesh.new()
cols = []
for i in range(COLS):
    a = angles[i] + FRONT
    h = top_h(a)
    d = out_dir(a)
    ro, rt = rad_at(h), rad_at(h) - T
    col = [
        bm.verts.new(d * R0 + Vector((0, 0, 0.0))),
        bm.verts.new(d * R0 + Vector((0, 0, BT))),
        bm.verts.new(d * ro + Vector((0, 0, h))),
        bm.verts.new(d * rt + Vector((0, 0, h))),
        bm.verts.new(d * (R0 - T) + Vector((0, 0, BT))),
        bm.verts.new(d * (R0 - T) + Vector((0, 0, 0.0))),
    ]
    cols.append(col)
wl = bm.edges.layers.float.new("bevel_weight_edge")
for i in range(COLS):
    a, b = cols[i], cols[(i + 1) % COLS]
    for k in range(6):
        k2 = (k + 1) % 6
        bm.faces.new((a[k], b[k], b[k2], a[k2]))
    for k in (2, 3):  # the outer and inner top edges
        e = bm.edges.get((a[k], b[k]))
        e[wl] = 1.0
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
shell = kit.give(kit.mesh_obj("Shell", bm, "Gold"), M_GOLD)
bv = shell.modifiers.new("Bevel", "BEVEL")
bv.width = 0.016
bv.segments = 2
bv.limit_method = "WEIGHT"
bv.harden_normals = False
kit.smooth(shell)
for poly in shell.data.polygons:  # the flat bottom ring stays flat-shaded (a hard edge, unbevelled: under the rim)
    if all(shell.data.vertices[v].co.z < 1e-5 for v in poly.vertices):
        poly.use_smooth = False

# Embossed rims: a fat rolled rim at the bottom, a slimmer one at the band top, a bead row between.
kit.torus("RimLow", R0 + 0.005, 0.042, (0, 0, 0.045), M_GOLD, "Gold", major=48, minor=6)
kit.torus("RimTop", R0 + 0.002, 0.03, (0, 0, BT - 0.005), M_GOLD, "Gold", major=48, minor=5)


def ring(name, R, r, center, normal, mat, group, sx=1.0, sy=1.0, major=24, minor=6):
    """A torus (bezel) in local XY scaled (sx, sy), laid on a surface with outward `normal`."""
    b2 = bmesh.new()
    for i in range(major):
        a = 2 * math.pi * i / major
        for j in range(minor):
            c = 2 * math.pi * j / minor
            rr = R + r * math.cos(c)
            b2.verts.new((rr * math.cos(a) * sx, rr * math.sin(a) * sy, r * math.sin(c)))
    b2.verts.ensure_lookup_table()
    for i in range(major):
        for j in range(minor):
            q = [i * minor + j, ((i + 1) % major) * minor + j, ((i + 1) % major) * minor + (j + 1) % minor, i * minor + (j + 1) % minor]
            b2.faces.new([b2.verts[x] for x in q])
    bmesh.ops.recalc_face_normals(b2, faces=b2.faces)
    kit.orient(b2, normal, center)
    return kit.smooth(kit.give(kit.mesh_obj(name, b2, group), mat))


def gem(name, center, normal, rx, ry, h, n, mat):
    """A faceted cabochon-brilliant: girdle ellipse (rx, ry), a table at 55 %, star facets between, a short pavilion
    sunk into the setting. Flat-shaded so every facet catches the light on its own."""
    b2 = bmesh.new()
    gird = [b2.verts.new((rx * math.cos(2 * math.pi * i / n), ry * math.sin(2 * math.pi * i / n), 0)) for i in range(n)]
    mid = [b2.verts.new((rx * 0.8 * math.cos(2 * math.pi * (i + 0.5) / n), ry * 0.8 * math.sin(2 * math.pi * (i + 0.5) / n), h * 0.6)) for i in range(n)]
    tab = [b2.verts.new((rx * 0.5 * math.cos(2 * math.pi * i / n), ry * 0.5 * math.sin(2 * math.pi * i / n), h)) for i in range(n)]
    bot = b2.verts.new((0, 0, -h * 0.8))
    for i in range(n):
        j = (i + 1) % n
        b2.faces.new((gird[i], gird[j], mid[i]))
        b2.faces.new((gird[i], mid[i], tab[i]))
        b2.faces.new((gird[j], tab[j], mid[i]))
        b2.faces.new((mid[i], tab[j], tab[i]))
        b2.faces.new((gird[j], gird[i], bot))
    b2.faces.new(tab)
    bmesh.ops.recalc_face_normals(b2, faces=b2.faces)
    kit.orient(b2, normal, center)
    return kit.give(kit.mesh_obj(name, b2, "Gems"), mat)


# Big faceted gems in the band under the tall points, medium ones under the small points, tiny diamonds between.
BIG_GEMS = ["Ruby", "Sapphire", "Emerald", "Emerald", "Sapphire"]
MED_GEMS = ["Emerald", "Ruby", "Sapphire", "Ruby", "Emerald"]
GZ = 0.19  # the band's gem line
for k, a in enumerate(BIG):
    d = out_dir(a)
    c = d * (R0 + 0.006) + Vector((0, 0, GZ))
    ring(f"BigBezel{k}", 0.112, 0.024, c, d, M_GOLD, "Gold", sx=1.0, sy=1.12, major=16, minor=5)
    gem(f"BigGem{k}", c + d * 0.012, d, 0.1, 0.112, 0.06, 10, M_GEM[BIG_GEMS[k]])
    # claws: four little gold prongs on the bezel
    for p in range(4):
        pa = math.pi / 4 + p * math.pi / 2
        loc = Vector((math.cos(pa) * 0.108, math.sin(pa) * 0.12, 0))
        # local (x along tangent, y up) -> world
        tang = Vector((-math.sin(a), math.cos(a), 0))
        w = c + tang * loc.x + Vector((0, 0, loc.y)) + d * 0.03
        kit.sphere(f"Claw{k}{p}", 0.022, w, M_FIN, "Finials", u=6, v=3)
for k, a in enumerate(SMALL):
    d = out_dir(a)
    c = d * (R0 + 0.004) + Vector((0, 0, GZ))
    ring(f"MedBezel{k}", 0.07, 0.018, c, d, M_GOLD, "Gold", major=14, minor=5)
    gem(f"MedGem{k}", c + d * 0.008, d, 0.064, 0.064, 0.045, 8, M_GEM[MED_GEMS[k]])
for k in range(10):
    a = FRONT + (k + 0.5) * 2 * math.pi / 10
    d = out_dir(a)
    c = d * (R0 - 0.004) + Vector((0, 0, GZ))
    gem(f"Diamond{k}", c, d, 0.034, 0.034, 0.03, 6, M_GEM["Diamond"])

# A round gem on every tall point, in a bezel.
for k, a in enumerate(BIG):
    z = BT + LIP + HB * 0.36
    n = surf_normal(a)
    c = out_dir(a) * rad_at(z) + Vector((0, 0, z))
    ring(f"PtBezel{k}", 0.058, 0.016, c, n, M_GOLD, "Gold", major=14, minor=4)
    gem(f"PtGem{k}", c + n * 0.006, n, 0.052, 0.06, 0.04, 8, M_GEM["Ruby" if k == 0 else "Diamond"])

# Finials: a gold ball on every tall point, a fleur-de-lis on every small one.
TIP_Z = BT + LIP + HB
for k, a in enumerate(BIG):
    c = out_dir(a) * rad_at(TIP_Z) + Vector((0, 0, TIP_Z + 0.035))
    kit.sphere(f"Ball{k}", 0.068, c, M_FIN, "Finials", u=10, v=7)

# The fleur-de-lis: one outline (centre petal, two curling side petals, the collar band, a foot), right half from the
# top tip down, mirrored.
FLEUR_R = [
    (0.0, 1.0),
    (0.18, 0.77),
    (0.16, 0.55),
    (0.08, 0.44),
    (0.22, 0.6),
    (0.38, 0.74),
    (0.52, 0.7),
    (0.55, 0.56),
    (0.46, 0.44),
    (0.33, 0.37),
    (0.27, 0.36),
    (0.27, 0.23),
    (0.12, 0.22),
    (0.15, 0.1),
    (0.25, 0.0),
]
FLEUR_SHARP_R = [0, 3, 7, 10, 11, 12, 14]
FLEUR = FLEUR_R + [(-x, y) for x, y in reversed(FLEUR_R[1:])]
FLEUR_SHARP = FLEUR_SHARP_R + [len(FLEUR) - i for i in FLEUR_SHARP_R if i > 0]
FLEUR_PTS = kit.outline(FLEUR, FLEUR_SHARP, n=2)
FL_H = 0.26
for k, a in enumerate(SMALL):
    z0 = BT + LIP + HS - 0.06
    d = out_dir(a)
    base = d * (rad_at(z0) - 0.025) + Vector((0, 0, z0))
    kit.prism(f"Fleur{k}", [(x * FL_H, y * FL_H) for x, y in FLEUR_PTS], 0.05, base, d, M_FIN, "Finials", bev=0, smooth_it=False)

# The velvet cap: a puffy dome inside the band, tufted down along the arches.
prof = [(0, 0.04), (0.5, 0.04), (0.515, 0.08), (0.52, 0.3), (0.5, 0.47), (0.44, 0.6), (0.34, 0.71), (0.21, 0.79), (0.09, 0.83), (0, 0.84)]
cap = kit.lathe("Cap", prof, M_VELVET, "Velvet", segs=45)
for v in cap.data.vertices:
    r = math.hypot(v.co.x, v.co.y)
    if r < 1e-5 or v.co.z < 0.3:
        continue
    a = math.atan2(v.co.y, v.co.x)
    crease = min(ang_dist(a, c) for c in BIG) / (math.pi / 5)  # 0 on an arch, 1 midway
    puff = math.sin(min(1.0, crease) * math.pi / 2) ** 0.7
    w = min(1.0, (v.co.z - 0.3) / 0.3) * min(1.0, r / 0.15)
    f = 1 + 0.07 * w * (puff - 0.6)
    v.co.x *= f
    v.co.y *= f
    v.co.z += 0.035 * w * (puff - 0.6)

# Five arches springing from behind the tall points' balls, dipping under the orb.
ORB_Z = 0.935
for k, a in enumerate(BIG):
    d = out_dir(a)
    rt = rad_at(TIP_Z) - 0.03
    pts = [
        d * (rt - 0.01) + Vector((0, 0, TIP_Z - 0.02)),
        d * 0.47 + Vector((0, 0, TIP_Z + 0.13)),
        d * 0.27 + Vector((0, 0, TIP_Z + 0.16)),
        d * 0.07 + Vector((0, 0, ORB_Z - 0.06)),
    ]
    kit.rope(f"Arch{k}", [tuple(p) for p in pts], 0.03, M_GOLD, "Gold", res=4, bres=1)

# Orb on top: a gold ball with an equator band and a meridian, and a puffy star.
kit.sphere("Orb", 0.085, (0, 0, ORB_Z), M_FIN, "Finials", u=16, v=10)
kit.torus("OrbBand", 0.086, 0.014, (0, 0, ORB_Z), M_FIN, "Finials", major=20, minor=5)
kit.torus("OrbArc", 0.086, 0.012, (0, 0, ORB_Z), M_FIN, "Finials", axis="Y", major=20, minor=5)
kit.cylinder("StarStem", 0.022, 0.05, (0, 0, ORB_Z + 0.1), M_FIN, "Finials", segs=10, bev=0.006, bev_segs=1)
STAR_R = 0.09
STAR_C = Vector((0, 0.022, ORB_Z + 0.085 + 0.03 + STAR_R * 0.92))
kit.prism("Star", kit.star_pts(5, STAR_R, STAR_R * 0.48), 0.044, STAR_C, (0, -1, 0), M_FIN, "Finials", bev=0.016, bev_segs=2)
kit.sphere("StarGem", 0.026, STAR_C - Vector((0, 0.05, 0)), M_GEM["Diamond"], "Gems", scale=(1, 0.6, 1), u=10, v=6)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
if "--debug-tris" in kit.argv:
    import bpy  # noqa: E402

    deps = bpy.context.evaluated_depsgraph_get()
    per = {}
    for g, objs in kit.S.groups.items():
        for o in objs:
            me = o.evaluated_get(deps).to_mesh()
            key = g + ":" + "".join(ch for ch in o.name if not ch.isdigit()).rstrip("-.")
            per[key] = per.get(key, 0) + sum(len(p.vertices) - 2 for p in me.polygons)
    for k_, v_ in sorted(per.items(), key=lambda kv: -kv[1]):
        print("OBJTRIS", k_, v_, flush=True)
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
top_centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, hi.z))
print("SIZE", kit.rbx_size(lo, hi), flush=True)


def swap_mats(table):
    """Replace every material slot whose material is a key of `table` (by name); returns the undo table."""
    undo = {}
    for o in parts.values():
        for i, m in enumerate(o.data.materials):
            if m and m.name in table:
                undo[(o.name, i)] = m
                o.data.materials[i] = table[m.name]
    return undo


def unswap(undo):
    for (on, i), m in undo.items():
        parts[on].data.materials[i] = m


kit.render_setup(target=(0, 0, 0.55))
if DO_RENDER:
    kit.shoot("hero", (2.3, -3.1, 1.85), lens=55)
    kit.shoot("front", (0, -4.4, 0.75), lens=55, target=(0, 0, 0.6))
    kit.shoot("top", (1.2, -1.8, 3.4), lens=50, target=(0, 0, 0.55))
    u = swap_mats(OBS_SWAP)
    kit.shoot("hero_obsidian", (2.3, -3.1, 1.85), lens=55)
    kit.shoot("front_obsidian", (0, -4.4, 0.75), lens=55, target=(0, 0, 0.6))
    unswap(u)

maps, omaps = {}, {}
if BAKE:
    maps = kit.bake_all(parts, {"Gold": 1024, "Velvet": 512, "Gems": 512, "Finials": 512})
    u = swap_mats(OBS_SWAP)
    tex0, key0 = kit.S.tex, kit.S.key
    kit.S.tex = os.path.join(kit.S.exp, "textures_obsidian")
    kit.S.key = "Prop.CrownObsidian"
    os.makedirs(kit.S.tex, exist_ok=True)
    for name, res in {"Gold": 1024, "Velvet": 512, "Gems": 512, "Finials": 512}.items():
        omaps[name] = kit.bake_maps(parts[name], name, res, uv=False)
    kit.S.tex, kit.S.key = tex0, key0
    unswap(u)
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "parts_obsidian": omaps,
        "obsidian_textures_dir": "export/textures_obsidian",
        "markers": {
            "SparklerBase": {"blender": kit.blend(top_centre), "roblox_from_pivot": kit.rbx(top_centre, pivot)},
            "BandCentre": {"blender": [0.0, 0.0, 0.18], "roblox_from_pivot": kit.rbx((0, 0, 0.18), pivot)},
        },
        "markers_note": "SparklerBase = the top centre of the crown (the star's tip); the code stands its own sparkler there. "
        "BandCentre = the middle of the band (the old part-built crown's origin).",
        "glow": [],
    }
)
