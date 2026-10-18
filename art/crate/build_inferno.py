"""FUSE VALLEY — the Inferno Crate (GDD §17.4 F-STORE-10, Asset Bible §7.4): the fiery loot-crate variant.

Same silhouette, dimensions and part split as the approved Spark Crate (art/crate/build.py) so the crate-opening
code works unchanged: BodyWood / BodyBrass / LidWood / LidBrass (baked PBR) + Neon Spark / LatchSpark / InnerGlow, the
lid hinged on the back top edge at the same point. The Inferno dresses it in charred plank wood with ember-bright
chipped edges, a black-iron band and lid rims, gold corner caps / straps / rivets, a gold flame-shaped latch with a
glowing flame core (LatchSpark) and glowing lava cracks: "Lava" on the body, and the lid's cracks folded into "Spark"
(the lid's Neon part, which the opening code already swings with the lid). Style reference: icons_sheet2.png #7.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/crate/build_inferno.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Crate.Inferno/  (renders/, export/Crate.Inferno.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "props"))

import bmesh  # noqa: E402
import kit  # noqa: E402
from kit import Vector, box, cylinder, give, mesh_obj, rivet, rope, smooth, srgb  # noqa: E402
from mathutils import Matrix  # noqa: E402

KEY = "Crate.Inferno"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["BodyWood", "BodyBrass", "LidWood", "LidBrass"], glow=["Lava", "Spark", "LatchSpark", "InnerGlow"])
rng = random.Random(11)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
CHAR = srgb("#30241F")  # charred plank
CHAR_HI = srgb("#4C3830")
CHAR_DK = srgb("#110B0A")
EMBER = srgb("#FF7424")  # chipped edges glow like embers
CORE = srgb("#24191A")
IRON_LO, IRON, IRON_HI = srgb("#24262D"), srgb("#4A4E5A"), srgb("#A3A9B8")
GOLD_LO, GOLD, GOLD_HI = srgb("#D08A1C"), srgb("#FFC437"), srgb("#FFF0A8")
CORD, CORD_DK = srgb("#C9A57A"), srgb("#6E4E30")
INK = srgb("#1E1416")
LAVA = srgb("#FF6410")
LAVA_CORE = srgb("#FF9A2A")
HEAT = srgb("#A3290C")

# ── Dimensions (studs): identical to the Spark Crate ────────────────────────────────────────────────────────────
W, D = 4.4, 2.5
HB = 1.5
LR = 0.95
PT = 0.10
STRAP_X = 1.12
STRAP_W = 0.40
BAND_Z, BAND_H = 1.32, 0.26

# ── Materials ────────────────────────────────────────────────────────────────────────────────────────────────────
M_CHAR = kit.mat_paint_wood("CharWood", CHAR, CHAR_HI, EMBER, CHAR_DK, chip=0.3, grain=0.4, rough=(0.7, 0.5), bump=0.4)
M_CORE = kit.mat_flat("CharCore", CORE, 0.9, ao=0.8)
M_IRON = kit.mat_metal("BlackIron", IRON_LO, IRON, IRON_HI, rough=(0.32, 0.48), metal=0.3, edge_gain=3.0, bump=0.08)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_INK = kit.mat_flat("Ink", INK, 0.6, ao=0.2)


def mat_cord():
    m, nt, b = kit.new_mat("Cord")
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    mp = kit.nd(nt, "ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(35))
    mp.inputs["Scale"].default_value = (22.0, 22.0, 22.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = kit.nd(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
    wave.inputs["Scale"].default_value = 1.0
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    col = kit.mix_rgb(nt, wave.outputs["Fac"], CORD_DK, CORD)
    col = kit.ao_mult(nt, col, 0.6, 0.1)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    bump = kit.nd(nt, "ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


M_CORD = mat_cord()
M_LAVA = kit.mat_emit("Lava", LAVA, 2.6)
M_SPARK = kit.mat_emit("Spark", LAVA_CORE, 2.6)
M_HEAT = kit.mat_gloss("Heat", HEAT, srgb("#D2461A"), rough=0.5, ao=0.3, grad=0.3)
M_GLOW = kit.mat_emit("InnerGlow", srgb("#FF8A2A"), 3.0)


# ── Lid arc helpers (as the Spark Crate) ─────────────────────────────────────────────────────────────────────────
def lid_point(t, grow=0.0):
    return Vector((0.0, -math.cos(t) * (D / 2 + grow), HB + math.sin(t) * (LR + grow)))


def lid_normal(t):
    return Vector((0.0, -math.cos(t) / (D / 2), math.sin(t) / LR)).normalized()


def sweep_arc(name, x0, x1, t0, t1, grow, thick, mat, group, steps=28, bev=0.03):
    bm = bmesh.new()
    rows = []
    for i in range(steps + 1):
        t = t0 + (t1 - t0) * i / steps
        p_in = lid_point(t, grow)
        p_out = lid_point(t, grow + thick)
        rows.append([bm.verts.new((x, p.y, p.z)) for p in (p_in, p_out) for x in (x0, x1)])
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[2], a[3], b[3], b[2]))
        bm.faces.new((a[1], a[0], b[0], b[1]))
        bm.faces.new((a[0], a[2], b[2], b[0]))
        bm.faces.new((a[3], a[1], b[1], b[3]))
    bm.faces.new((rows[0][0], rows[0][1], rows[0][3], rows[0][2]))
    bm.faces.new((rows[-1][2], rows[-1][3], rows[-1][1], rows[-1][0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = give(mesh_obj(name, bm, group), mat)
    kit.bevel(o, bev, 2)
    return smooth(o)


def half_ellipse_disc(name, x, thick, grow, mat, group, steps=40, bev=0.03):
    bm = bmesh.new()
    pts = [lid_point(math.pi * i / steps, grow) for i in range(steps + 1)]
    a = [bm.verts.new((x - thick / 2, p.y, p.z)) for p in pts]
    b = [bm.verts.new((x + thick / 2, p.y, p.z)) for p in pts]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(steps):
        bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
    bm.faces.new((a[-1], b[-1], b[0], a[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = give(mesh_obj(name, bm, group), mat)
    kit.bevel(o, bev, 2)
    return smooth(o)


# ── Lava crack generator ─────────────────────────────────────────────────────────────────────────────────────────
def jag(p0, p1, seg=0.11, amp=0.05):
    """A jagged crack line from p0 to p1 (2D)."""
    p0, p1 = Vector(p0), Vector(p1)
    n = max(2, int((p1 - p0).length / seg))
    d = (p1 - p0)
    perp = Vector((-d.y, d.x)).normalized()
    pts = []
    for i in range(n + 1):
        t = i / n
        off = 0 if i in (0, n) else rng.uniform(-amp, amp) * (1.0 if i % 2 else -0.6)
        pts.append(p0 + d * t + perp * off)
    return pts


def taper(n, wmax, wide_start, w_end=0.012):
    """Crack widths along a line: from a junction it starts wide and thins out; a lone crack swells in the middle."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        if wide_start:
            out.append(wmax * (1 - t) ** 0.9 + w_end * t)
        else:
            out.append(w_end + (wmax - w_end) * math.sin(math.pi * t) ** 0.7)
    return out


def crack_set(name, matrix, lines, group, mat, rim_group, thick=0.018):
    """lines: list of (points2d, wmax, wide_start) — wide_start means the crack begins wide (a junction). Each crack
    is a Neon core strip on a wider, flatter dark-red heat rim (baked into the wood group)."""
    for i, (pts, wmax, wide_start) in enumerate(lines):
        ws = taper(len(pts), wmax, wide_start)
        p2 = [(p.x, p.y) for p in pts]
        kit.strip_on_plane(f"{name}_{i}", p2, ws, thick, mat, group, matrix)
        kit.strip_on_plane(f"{name}Rim_{i}", p2, [w * 2.0 + 0.035 for w in ws], 0.008, M_HEAT, rim_group, matrix @ Matrix.Translation((0, 0, -0.002)))


def network(origin, spokes, branch_p=0.7):
    """A burst of jagged cracks from `origin`: spokes = [(end2d, width)], each with an optional side branch."""
    lines = []
    for end, w in spokes:
        main = jag(origin, end)
        lines.append((main, w, True))
        if rng.random() < branch_p and len(main) > 3:
            k = rng.randint(1, len(main) - 3)
            p = main[k]
            d = (Vector(end) - Vector(origin)).normalized()
            ang = rng.choice((-1, 1)) * rng.uniform(0.6, 1.0)
            dd = Matrix.Rotation(ang, 2) @ d
            ln = (Vector(end) - Vector(origin)).length * rng.uniform(0.3, 0.45)
            lines.append((jag(p, p + dd * ln, amp=0.035), w * 0.6, True))
    return lines


# ── Body ─────────────────────────────────────────────────────────────────────────────────────────────────────────
core_inset = PT
box("Core", (W - 2 * core_inset, D - 2 * core_inset, HB - 0.12), (0, 0, (HB - 0.12) / 2), M_CORE, "BodyWood", 0.02)
box("Base", (W - 0.06, D - 0.06, 0.10), (0, 0, 0.05), M_CORE, "BodyWood", 0.03)

ROWS = [(0.08, 0.52), (0.54, 0.98), (0.99, 1.47)]


def plank_row(prefix, length, along, z0, z1, outer, normal_sign, splits, mat):
    gap = 0.035
    edges = [-length / 2] + splits + [length / 2]
    for i in range(len(edges) - 1):
        a, b_ = edges[i] + (gap / 2 if i else 0), edges[i + 1] - (gap / 2 if i < len(edges) - 2 else 0)
        mid = (a + b_) / 2
        ln = b_ - a
        h = z1 - z0
        if along == "x":
            size = (ln, PT, h)
            loc = (mid, outer - normal_sign * PT / 2, (z0 + z1) / 2)
        else:
            size = (PT, ln, h)
            loc = (outer - normal_sign * PT / 2, mid, (z0 + z1) / 2)
        box(f"{prefix}_{i}", size, loc, mat, "BodyWood", 0.045)


for r, (z0, z1) in enumerate(ROWS):
    stagger = [[-0.7, 1.05], [-1.35, 0.35], [-0.2, 1.5]][r]
    plank_row(f"Front{r}", W - 0.02, "x", z0, z1, -D / 2, -1, stagger, M_CHAR)
    plank_row(f"Back{r}", W - 0.02, "x", z0, z1, D / 2, 1, [s * -1 for s in stagger][::-1], M_CHAR)
    estag = [[0.25], [-0.45], [0.5]][r]
    plank_row(f"EndL{r}", D - 2 * PT - 0.02, "y", z0, z1, -W / 2, -1, estag, M_CHAR)
    plank_row(f"EndR{r}", D - 2 * PT - 0.02, "y", z0, z1, W / 2, 1, [-s for s in estag], M_CHAR)

# Black-iron band at the lid seam.
BT = 0.07
box("BandF", (W + 0.02, BT, BAND_H), (0, -D / 2 - BT / 2 + 0.01, BAND_Z), M_IRON, "BodyBrass", 0.025)
box("BandB", (W + 0.02, BT, BAND_H), (0, D / 2 + BT / 2 - 0.01, BAND_Z), M_IRON, "BodyBrass", 0.025)
box("BandL", (BT, D + 0.02, BAND_H), (-W / 2 - BT / 2 + 0.01, 0, BAND_Z), M_IRON, "BodyBrass", 0.025)
box("BandR", (BT, D + 0.02, BAND_H), (W / 2 + BT / 2 - 0.01, 0, BAND_Z), M_IRON, "BodyBrass", 0.025)
for side in (-1, 1):
    for k in range(7):
        x = -1.9 + k * (3.8 / 6)
        if abs(abs(x) - STRAP_X) < 0.35 or abs(x) < 0.5:
            continue
        rivet(f"RivBand{side:+d}{k}", (x, side * (D / 2 + BT + 0.005), BAND_Z), (0, side, 0), M_IRON, "BodyBrass", r=0.06, segs=12)

# Gold straps down the front and back.
ST = 0.09
for sx in (-STRAP_X, STRAP_X):
    for side in (-1, 1):
        y = side * (D / 2 + ST / 2 + 0.02)
        box(f"StrapBody{sx:+.0f}{side:+d}", (STRAP_W, ST, HB - 0.02), (sx, y, (HB - 0.02) / 2 + 0.01), M_GOLD, "BodyBrass", 0.03)
        for z in (0.32, 0.86):
            rivet(f"RivS{sx:+.0f}{side:+d}{z}", (sx, side * (D / 2 + ST + 0.03), z), (0, side, 0), M_GOLD, "BodyBrass")

# Gold corner caps with rivets.
CAP = 0.5
for cx in (-1, 1):
    for cy in (-1, 1):
        for cz, zc in (("lo", CAP / 2), ("hi", BAND_Z)):
            loc = (cx * (W / 2 - CAP / 2 + 0.07), cy * (D / 2 - CAP / 2 + 0.07), zc)
            box(f"Cap{cx:+d}{cy:+d}{cz}", (CAP, CAP, CAP if cz == "lo" else BAND_H + 0.16), loc, M_GOLD, "BodyBrass", 0.07)
            rivet(f"RivCapF{cx:+d}{cy:+d}{cz}", (loc[0] - cx * 0.06, cy * (D / 2 + 0.075), zc), (0, cy, 0), M_GOLD, "BodyBrass", 0.075)
            rivet(f"RivCapS{cx:+d}{cy:+d}{cz}", (cx * (W / 2 + 0.075), loc[1] - cy * 0.06, zc), (cx, 0, 0), M_GOLD, "BodyBrass", 0.075)

# The flame latch: a chunky gold flame plate over the band, a glowing flame core (LatchSpark), a keyhole.
FLAME = [(0, -0.52), (0.32, -0.45), (0.47, -0.20), (0.46, 0.08), (0.40, 0.26), (0.52, 0.52), (0.26, 0.40), (0.24, 0.62),
         (0.14, 0.84), (-0.06, 1.06), (-0.04, 0.80), (-0.16, 0.56), (-0.26, 0.40), (-0.48, 0.48), (-0.42, 0.24), (-0.48, 0.0),
         (-0.46, -0.22), (-0.32, -0.45)]
flame = kit.outline(FLAME, sharp=[5, 6, 9, 12, 13], n=4)
LZ = 0.98
PLATE_BACK = -D / 2 - BT - 0.005
PLATE_T = 0.22
kit.prism("LatchPlate", flame, PLATE_T, (0, PLATE_BACK, LZ), (0, -1, 0), M_GOLD, "BodyBrass", bev=0.085, bev_segs=4)
box("LatchHasp", (0.34, 0.14, 0.34), (0, -D / 2 - 0.06, LZ), M_IRON, "BodyBrass", 0.04)
inner = [(x * 0.5, y * 0.5 + 0.17) for x, y in flame]
kit.prism("LatchCoreRim", [(x * 0.6, y * 0.6 + 0.13) for x, y in flame], 0.03, (0, PLATE_BACK - PLATE_T + 0.01, LZ), (0, -1, 0), M_HEAT, "BodyBrass", bev=0.012, bev_segs=2)
kit.prism("LatchCore", inner, 0.05, (0, PLATE_BACK - PLATE_T - 0.005, LZ), (0, -1, 0), M_SPARK, "LatchSpark", bev=0.015, bev_segs=2)
# Keyhole on the plate's lower bulb.
circle = [(math.cos(math.radians(a)) * 0.075, math.sin(math.radians(a)) * 0.075) for a in range(-55, 236, 15)]
keyhole = circle + [(-0.045, -0.06), (-0.065, -0.19), (0.065, -0.19), (0.045, -0.06)]
kit.prism("Keyhole", keyhole, 0.02, (0, PLATE_BACK - PLATE_T + 0.012, LZ - 0.24), (0, -1, 0), M_INK, "BodyBrass", bev=0.006, bev_segs=1)

# Lava cracks on the body faces (Neon "Lava").
FRONT_M = kit.plane_matrix((0, -D / 2 - 0.004, 0), (0, -1, 0), (1, 0, 0))
BACK_M = kit.plane_matrix((0, D / 2 + 0.004, 0), (0, 1, 0), (-1, 0, 0))
END_R = kit.plane_matrix((W / 2 + 0.004, 0, 0), (1, 0, 0), (0, 1, 0))
END_L = kit.plane_matrix((-W / 2 - 0.004, 0, 0), (-1, 0, 0), (0, -1, 0))


def side_cracks(mirror):
    s = -1 if mirror else 1
    lines = []
    # Centre panel, either side of the latch / under it.
    lines += network(Vector((s * -0.62, 0.62)), [((s * -0.86, 1.12), 0.07), ((s * -0.58, 0.14), 0.075), ((s * -0.88, 0.28), 0.05), ((s * -0.26, 0.42), 0.06)])
    lines += network(Vector((s * 0.66, 0.5)), [((s * 0.86, 0.98), 0.065), ((s * 0.84, 0.13), 0.06), ((s * 0.24, 0.24), 0.06)])
    lines += [(jag((s * -0.3, 0.3), (s * 0.28, 0.2)), 0.045, False)]
    # Outer panels between the straps and the corner caps.
    lines += network(Vector((s * -1.55, 0.78)), [((s * -1.4, 1.08), 0.05), ((s * -1.7, 0.56), 0.05), ((s * -1.45, 0.52), 0.04)], branch_p=0.0)
    lines += network(Vector((s * 1.56, 0.74)), [((s * 1.72, 1.06), 0.05), ((s * 1.42, 0.55), 0.05)], branch_p=0.0)
    return lines


crack_set("LavaF", FRONT_M, side_cracks(False), "Lava", M_LAVA, "BodyWood")
crack_set("LavaB", BACK_M, side_cracks(True), "Lava", M_LAVA, "BodyWood")
for nm, mtx in (("LavaR", END_R), ("LavaL", END_L)):
    ctr = Vector((0.0, 0.64))
    spokes = []
    for k in range(7):
        a = math.radians(90 + k * 360 / 7 + rng.uniform(-12, 12))
        ex = max(-0.72, min(0.72, math.cos(a) * 0.95))
        ez = max(0.12, min(1.12, 0.64 + math.sin(a) * 0.55))
        spokes.append(((ex, ez), rng.uniform(0.055, 0.075)))
    crack_set(nm, mtx, network(ctr, spokes, branch_p=0.35), "Lava", M_LAVA, "BodyWood")
    # A molten core where the burst starts.
    kit.prism(nm + "Core", kit.star_pts(7, 0.1, 0.06, jitter=0.12, seed=4), 0.022, (mtx.translation.x, 0, 0.64), (mtx.col[2].x, 0, 0), M_LAVA, "Lava", bev=0.008, bev_segs=1)

# The glow inside (only seen when the lid opens).
box("InnerGlow", (W - 2 * core_inset - 0.1, D - 2 * core_inset - 0.1, 0.02), (0, 0, HB - 0.11), M_GLOW, "InnerGlow", 0)

# ── Lid ──────────────────────────────────────────────────────────────────────────────────────────────────────────
half_ellipse_disc("LidCore", 0, W - 2 * PT, -PT, M_CORE, "LidWood", bev=0.01)
N = 6
for i in range(N):
    t0 = math.pi * i / N + (0.012 if i else 0.0)
    t1 = math.pi * (i + 1) / N - (0.012 if i < N - 1 else 0.0)
    cuts = [[-0.9], [0.6], [-1.4, 1.2], [-0.3], [1.0], [-1.1, 0.8]][i]
    xs = [-W / 2 + 0.01] + cuts + [W / 2 - 0.01]
    for j in range(len(xs) - 1):
        a = xs[j] + (0.018 if j else 0)
        b_ = xs[j + 1] - (0.018 if j < len(xs) - 2 else 0)
        sweep_arc(f"Stave{i}_{j}", a, b_, t0, t1, -PT, PT, M_CHAR, "LidWood", steps=6, bev=0.04)
for sx in (-1, 1):
    half_ellipse_disc(f"LidEnd{sx:+d}", sx * (W / 2 - 0.06), 0.12, -0.02, M_CHAR, "LidWood")
    sweep_arc(f"LidRim{sx:+d}", sx * (W / 2 - 0.02) - 0.07, sx * (W / 2 - 0.02) + 0.07, 0.0, math.pi, -0.05, 0.12, M_IRON, "LidBrass", steps=40)
for sx in (-STRAP_X, STRAP_X):
    sweep_arc(f"StrapLid{sx:+.0f}", sx - STRAP_W / 2, sx + STRAP_W / 2, -0.02, math.pi + 0.02, 0.0, ST, M_GOLD, "LidBrass", steps=36)
    for t in (0.42, math.pi / 2, math.pi - 0.42):
        p = lid_point(t, ST + 0.005)
        rivet(f"RivL{sx:+.0f}{t:.2f}", (sx, p.y, p.z), lid_normal(t), M_GOLD, "LidBrass")
for side in (-1, 1):
    box(f"LidLip{side:+d}", (W - 0.1, 0.12, 0.08), (0, side * (D / 2 - 0.04), HB + 0.04), M_IRON, "LidWood", 0.02)


# Lid lava cracks: strips that follow the lid arc (drawn in (x, t) space), part of the lid's Neon "Spark".
def lid_crack(name, pts_xt, wmax, wide_start):
    ws = taper(len(pts_xt), wmax, wide_start)
    lid_strip(name, pts_xt, ws, 0.004, 0.022, "Spark", M_SPARK)
    lid_strip(name + "Rim", pts_xt, [w * 2.0 + 0.035 for w in ws], 0.002, 0.01, "LidWood", M_HEAT)


def lid_strip(name, pts_xt, ws, h0, h1, group, mat):
    bm = bmesh.new()
    P = [Vector(p) for p in pts_xt]
    L, R = [], []
    for i, p in enumerate(P):
        d = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        nrm = Vector((-d.y, d.x))
        # (x, t) space is anisotropic: one radian of t ~ 1.1 studs of arc. Scale the width's t component.
        w = ws[i] / 2
        L.append((p.x + nrm.x * w, p.y + nrm.y * w / 1.1))
        R.append((p.x - nrm.x * w, p.y - nrm.y * w / 1.1))
    outline = L + list(reversed(R))
    lo = [bm.verts.new((x, lid_point(t, h0).y, lid_point(t, h0).z)) for x, t in outline]
    hi = [bm.verts.new((x, lid_point(t, h1).y, lid_point(t, h1).z)) for x, t in outline]
    n = len(outline)
    m = len(L)
    for i in range(m - 1):
        j, jn = n - 1 - i, n - 2 - i
        bm.faces.new((hi[i], hi[i + 1], hi[jn], hi[j]))
        bm.faces.new((lo[j], lo[jn], lo[i + 1], lo[i]))
    for i in range(n):
        k = (i + 1) % n
        bm.faces.new((lo[i], lo[k], hi[k], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    give(mesh_obj(name, bm, group), mat)


def lid_network(origin, spokes):
    k = 0
    for end, w in spokes:
        main = jag(origin, end, seg=0.1, amp=0.045)
        lid_crack(f"LidLava{len(lid_cracks)}_{k}", main, w, True)
        k += 1
    lid_cracks.append(origin)


lid_cracks = []
# Origin in (x, t); spokes avoid the straps (|x| 0.92..1.32), the grommet and the end rims.
lid_network(Vector((-0.5, 1.0)), [((-0.82, 0.45), 0.065), ((-0.2, 0.42), 0.055), ((-0.78, 1.55), 0.05), ((-0.25, 1.28), 0.05)])
lid_network(Vector((0.48, 2.2)), [((0.8, 2.75), 0.06), ((0.2, 2.7), 0.05), ((0.82, 1.7), 0.05), ((0.3, 1.86), 0.045)])
lid_network(Vector((0.55, 0.8)), [((0.85, 0.3), 0.05), ((0.25, 0.35), 0.045)])
lid_network(Vector((-0.55, 2.35)), [((-0.85, 2.8), 0.05), ((-0.2, 2.75), 0.045), ((-0.8, 1.95), 0.04)])
for s in (-1, 1):
    lid_network(Vector((s * 1.72, 1.0)), [((s * 1.5, 0.4), 0.05), ((s * 1.95, 0.5), 0.045), ((s * 1.6, 1.6), 0.045)])
    lid_network(Vector((s * 1.66, 2.3)), [((s * 1.5, 2.8), 0.045), ((s * 1.95, 2.75), 0.04), ((s * 1.82, 1.85), 0.04)])

# Small bursts on the lid ends (also "Spark", heat rims in LidWood).
for nm, sx in (("LidLavaR", 1), ("LidLavaL", -1)):
    mtx = kit.plane_matrix((sx * (W / 2 + 0.004), 0, 0), (sx, 0, 0), (0, sx, 0))
    ctr = Vector((sx * 0.12, 1.86))
    spokes = [((sx * 0.62, 1.66), 0.05), ((sx * -0.5, 1.72), 0.045), ((sx * 0.3, 2.2), 0.04), ((sx * -0.2, 2.18), 0.035), ((sx * 0.05, 1.6), 0.04)]
    crack_set(nm, mtx, network(ctr, spokes, branch_p=0.2), "Spark", M_SPARK, "LidWood")

# Fuse on top: a gold grommet and a scorched cord, the spark at its tip (also "Spark").
top = lid_point(math.pi / 2)
gb = bmesh.new()
bmesh.ops.create_cone(gb, cap_ends=True, segments=32, radius1=0.24, radius2=0.2, depth=0.14)
bmesh.ops.translate(gb, vec=(0, 0.0, top.z + 0.05), verts=gb.verts)
smooth(kit.bevel(give(mesh_obj("Grommet", gb, "LidBrass"), M_GOLD), 0.03, 3))
cord_pts = [Vector((0, 0.0, top.z + 0.08)), Vector((0.02, 0.02, top.z + 0.32)), Vector((0.16, 0.04, top.z + 0.56)), Vector((0.4, 0.05, top.z + 0.66))]
rope("Fuse", cord_pts, 0.075, M_CORD, "LidBrass")
spark_at = cord_pts[-1] + Vector((0.06, 0, 0.02))
sb = bmesh.new()
vs = []
for i in range(12):
    a = math.pi * i / 6
    rr = 0.17 if i % 2 == 0 else 0.17 * 0.42
    vs.append(sb.verts.new((math.cos(a) * rr, 0, math.sin(a) * rr)))
f = sb.faces.new(vs)
e = bmesh.ops.extrude_face_region(sb, geom=[f])
bmesh.ops.translate(sb, vec=(0, 0.05, 0), verts=[v for v in e["geom"] if isinstance(v, bmesh.types.BMVert)])
bmesh.ops.translate(sb, vec=spark_at - Vector((0, 0.025, 0)), verts=sb.verts)
bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
give(mesh_obj("FuseSpark", sb, "Spark"), M_SPARK)

HINGE = Vector((0, D / 2, HB))
LID_PARTS = ["LidWood", "LidBrass", "Spark"]

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

if DO_RENDER:
    kit.render_setup(target=(0, 0, 1.15))
    kit.shoot("hero", (7.2, -9.2, 4.6))
    kit.shoot("front", (0, -14, 1.3), lens=70)
    kit.shoot("side", (14, 0, 1.3), lens=70)
    kit.shoot("back", (-7.5, 9.0, 4.2))
    kit.rotate_parts(parts, LID_PARTS, HINGE, (1, 0, 0), -105)
    kit.shoot("open", (6.6, -9.4, 5.6))
    kit.rotate_parts(parts, LID_PARTS, HINGE, (1, 0, 0), 0)
else:
    kit.render_setup(target=(0, 0, 1.15))

maps = kit.bake_all(parts, {"BodyWood": 1024, "BodyBrass": 1024, "LidWood": 1024, "LidBrass": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        # Same convention as Crate.Spark's manifest: [x, z, -y] of the Blender point.
        "hinge": [HINGE.x, HINGE.z, -HINGE.y],
        "hinge_blender": kit.blend(HINGE),
        "hinge_axis": "X (lid swings about the model's X axis; open = front up/back)",
        "hinge_roblox_from_pivot": kit.rbx(HINGE, pivot),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "lid_parts": LID_PARTS,
        "parts": maps,
        "glow": ["Lava", "Spark", "LatchSpark", "InnerGlow"],
        "glow_colors": {"Lava": "#FF7A1A", "Spark": "#FFB13B", "LatchSpark": "#FFB13B", "InnerGlow": "#FF8A2A"},
        "notes": "Spark = fuse spark + the lid's lava cracks (rotates with the lid). Lava = the body's cracks.",
    }
)
