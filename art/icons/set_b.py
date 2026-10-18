"""FUSE VALLEY icons — set B: Shop, Items, Scroll, Calendar, Camera, Sleep, Crown, Trophy, Lock, Ticket
(art/ref/icons/icons_sheet1.png, references only: every icon is real geometry built here)."""

import math

import bmesh
import lib
from lib import box, cyl, finish, glossy, gold, icon, prism, sphere, srgb, star_pts, torus, tube, xform
from mathutils import Matrix, Vector

# ── Palette ─────────────────────────────────────────────────────────────────────────────────────────────────────
RED = srgb("#E8322B")
DEEP_RED = srgb("#B81E22")
ORANGE = srgb("#F06A1E")
CREAM = srgb("#FFF0D6")
PAPER = srgb("#F2DCA8")
INK = srgb("#1B1622")
BLUE = srgb("#2F7BFF")
YELLOW = srgb("#FFD84A")
WHITE = srgb("#FFF8F0")


# ── Local helpers ───────────────────────────────────────────────────────────────────────────────────────────────
def lathe(name, prof, mat, segs=64, loc=(0, 0, 0), bevel=0, outline=0.035, sub=0):
    """Spin a closed (r, z) profile — first and last points on the axis — around Z."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=segs, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    xform(bm, loc)
    return finish(lib._obj(name, bm, mat), bevel, outline=outline, sub=sub)


def arc(cx, cz, r, a0, a1, n):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def rrect(w, h, r, n=6):
    """Rounded rectangle outline, centred."""
    x, z = w / 2 - r, h / 2 - r
    return arc(x, -z, r, -90, 0, n) + arc(x, z, r, 0, 90, n) + arc(-x, z, r, 90, 180, n) + arc(-x, -z, r, 180, 270, n)


def pivot(objs, mat4, p=(0, 0, 0)):
    """Transform objects about a pivot point (world space)."""
    t = Matrix.Translation(Vector(p))
    m = t @ mat4 @ t.inverted()
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def track(objs):
    """Collect every object created after this call (for pivot)."""
    import bpy

    before = set(bpy.context.scene.objects)
    return lambda: [o for o in bpy.context.scene.objects if o not in before]


# ── Shop: striped awning stall over a fireworks crate ──────────────────────────────────────────────────────────
@icon
def Shop():
    wood = glossy("WoodRed", srgb("#A3301F"), 0.45, coat=0.3)
    dark = glossy("WoodDark", srgb("#5E2A16"), 0.5, coat=0.2)
    inner = glossy("Inner", srgb("#3A1A10"), 0.7, coat=0)
    g = gold()
    W, D, H = 1.9, 1.2, 0.7
    # crate walls (two planks each on the front)
    for i, z in enumerate((-H / 4, H / 4)):
        box(f"Front{i}", (W, 0.14, H / 2 - 0.03), wood, loc=(0, -D / 2, z), bevel=0.04)
        box(f"Side{i}", (0.14, D, H / 2 - 0.03), wood, loc=(W / 2, 0, z), bevel=0.04)
        box(f"SideL{i}", (0.14, D, H / 2 - 0.03), wood, loc=(-W / 2, 0, z), bevel=0.04)
    box("Back", (W, 0.14, H), wood, loc=(0, D / 2, 0), bevel=0.04)
    box("Floor", (W - 0.1, D - 0.1, 0.1), inner, loc=(0, 0, 0.05), bevel=0.02, outline=0)
    box("Gap", (W - 0.06, D - 0.06, H - 0.1), inner, loc=(0, 0, -0.02), bevel=0.0, outline=0)
    # top rim + bottom rail
    box("RimF", (W + 0.08, 0.2, 0.12), dark, loc=(0, -D / 2, H / 2 + 0.02), bevel=0.04)
    box("RimR", (0.2, D + 0.08, 0.12), dark, loc=(W / 2, 0, H / 2 + 0.02), bevel=0.04)
    box("RimL", (0.2, D + 0.08, 0.12), dark, loc=(-W / 2, 0, H / 2 + 0.02), bevel=0.04)
    box("RimB", (W + 0.08, 0.2, 0.12), dark, loc=(0, D / 2, H / 2 + 0.02), bevel=0.04)
    # gold corner caps
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                box(f"Cap{sx}{sy}{sz}", (0.26, 0.26, 0.24), g, loc=(sx * W / 2, sy * D / 2, sz * (H / 2 - 0.06) + 0.02), bevel=0.05)
    # posts
    az, tilt = H / 2 + 1.5, 14
    for sx in (-1, 1):
        for sy in (-1, 1):
            py = sy * (D / 2 - 0.05)
            top = az + py * math.tan(math.radians(tilt)) - 0.08  # stop under the sloped awning
            ph = top - H / 2
            box(f"Post{sx}{sy}", (0.13, 0.13, ph), dark, loc=(sx * (W / 2 - 0.06), py, H / 2 + ph / 2), bevel=0.03)
    # fireworks
    red = glossy("Rocket", RED, 0.25)
    blue = glossy("RocketB", BLUE, 0.25)
    yel = glossy("Yel", YELLOW, 0.3)
    r1 = [cyl("R1", 0.17, 0.7, red, loc=(0, 0, 0)), cyl("R1Tip", 0.2, 0.34, red, loc=(0, 0, 0.52), r2=0.0, bevel=0.02),
          cyl("R1Band", 0.185, 0.08, yel, loc=(0, 0, 0.16), outline=0.015), cyl("R1Band2", 0.185, 0.08, yel, loc=(0, 0, -0.1), outline=0.015)]
    for o in r1:
        o.matrix_world = Matrix.Translation((-0.52, -0.12, 0.66)) @ rot("Y", -16) @ o.matrix_world
    cyl("Mid", 0.24, 0.7, red, loc=(0.0, -0.18, 0.62))
    cyl("MidCap", 0.26, 0.1, yel, loc=(0.0, -0.18, 0.98), outline=0.015)
    for i, (x, z) in enumerate(((-0.08, 0.8), (0.1, 0.62), (-0.06, 0.48))):
        prism(f"MidStar{i}", star_pts(5, 0.085, 0.04), 0.03, yel, loc=(x, -0.43, z), bevel=0.008, outline=0)
    r3 = [cyl("R3", 0.18, 0.66, blue, loc=(0, 0, 0)), cyl("R3Tip", 0.21, 0.42, blue, loc=(0, 0, 0.53), r2=0.0, bevel=0.02)]
    for i, (x, z) in enumerate(((-0.06, 0.14), (0.07, -0.08), (0.0, 0.38))):
        r3.append(prism(f"R3Star{i}", star_pts(5, 0.08, 0.036), 0.03, yel, loc=(x, -0.19, z), bevel=0.008, outline=0))
    for o in r3:
        o.matrix_world = Matrix.Translation((0.55, -0.08, 0.68)) @ rot("Y", 14) @ o.matrix_world
    # awning: red slab with white stripes, scalloped valance
    N = 6
    AW, AD = W + 0.32, D + 0.3
    w = AW / N
    awn = glossy("AwnRed", srgb("#E0262A"), 0.3)
    wht = glossy("AwnWhite", WHITE, 0.3)
    box("Awning", (AW, AD, 0.12), awn, loc=(0, 0, az), rot=[("X", tilt)], bevel=0.04)
    for i in range(N):
        if i % 2 == 1:
            box(f"Stripe{i}", (w, AD + 0.012, 0.135), wht, loc=(-AW / 2 + w * (i + 0.5), 0, az), rot=[("X", tilt)], bevel=0.02, outline=0)
    fy = -AD / 2 * math.cos(math.radians(tilt)) - 0.02
    fz = az - AD / 2 * math.sin(math.radians(tilt)) + 0.02
    hv, rs = 0.16, w / 2
    val = [(AW / 2, 0)]
    for i in range(N):
        cx = AW / 2 - w * (i + 0.5)
        val += arc(cx, -hv, rs, 0, -180, 10)[0:]
    val += [(-AW / 2, 0)]
    prism("Valance", val, 0.1, awn, loc=(0, fy, fz), bevel=0.03)
    for i in range(N):
        if i % 2 == 1:
            cx = -AW / 2 + w * (i + 0.5)
            pts = [(cx + rs, 0)] + arc(cx, -hv, rs, 0, -180, 10) + [(cx - rs, 0)]
            prism(f"ValW{i}", pts, 0.115, wht, loc=(0, fy, fz), bevel=0.02, outline=0)
    lib.group_tilt(-24, 15)


# ── Items: orange backpack with a brass buckle ─────────────────────────────────────────────────────────────────
@icon
def Items():
    org = glossy("Pack", srgb("#E8661C"), 0.32)
    flapc = glossy("Flap", srgb("#CF3A1A"), 0.32)
    brown = glossy("Strap", srgb("#7A3516"), 0.45, coat=0.3)
    g = gold("Brass")
    box("BackPanel", (1.5, 0.3, 1.66), brown, loc=(0, 0.42, -0.02), bevel=0.22)
    box("Body", (1.42, 0.8, 1.6), org, loc=(0, 0, 0), bevel=0.26)
    box("Flap", (1.5, 0.9, 0.66), flapc, loc=(0, -0.02, 0.5), bevel=0.24)
    # buckle strap + buckle
    box("Tab", (0.3, 0.08, 0.42), brown, loc=(0, -0.48, 0.24), bevel=0.03, outline=0.02)
    bz, bs, bt = 0.18, 0.4, 0.09
    box("BkT", (bs, 0.1, bt), g, loc=(0, -0.53, bz + bs / 2 - bt / 2), bevel=0.03, outline=0.02)
    box("BkB", (bs, 0.1, bt), g, loc=(0, -0.53, bz - bs / 2 + bt / 2), bevel=0.03, outline=0.02)
    box("BkL", (bt, 0.1, bs), g, loc=(-bs / 2 + bt / 2, -0.53, bz), bevel=0.03, outline=0.02)
    box("BkR", (bt, 0.1, bs), g, loc=(bs / 2 - bt / 2, -0.53, bz), bevel=0.03, outline=0.02)
    # front pocket
    box("Pocket", (1.12, 0.36, 0.66), org, loc=(0, -0.42, -0.42), bevel=0.16)
    box("PocketFlap", (1.16, 0.4, 0.2), flapc, loc=(0, -0.44, -0.12), bevel=0.08)
    for sx in (-1, 1):
        sphere(f"Stud{sx}", 0.06, g, loc=(sx * 0.36, -0.64, -0.17), outline=0.015)
        sphere(f"Rivet{sx}", 0.055, g, loc=(sx * 0.56, -0.47, 0.62), outline=0.015)
        sphere(f"PRiv{sx}", 0.05, g, loc=(sx * 0.42, -0.6, -0.6), outline=0.012)
    # side pocket
    box("SidePocket", (0.26, 0.56, 0.62), org, loc=(-0.78, -0.05, -0.32), bevel=0.1)
    box("SidePocketR", (0.26, 0.56, 0.62), org, loc=(0.78, -0.05, -0.32), bevel=0.1)
    sphere("SideStud", 0.05, g, loc=(-0.82, -0.34, -0.12), outline=0.012)
    # handle
    tube("Handle", [Vector((-0.28, 0.2, 0.75)), Vector((-0.24, 0.2, 1.08)), Vector((0.0, 0.2, 1.18)), Vector((0.24, 0.2, 1.08)), Vector((0.28, 0.2, 0.75))], 0.075, flapc)
    # shoulder straps peeking at the sides
    for sx in (-1, 1):
        tube(f"Shoulder{sx}", [Vector((sx * 0.55, 0.45, 0.7)), Vector((sx * 0.86, 0.38, 0.2)), Vector((sx * 0.8, 0.4, -0.75))], 0.08, brown)
    lib.group_tilt(-26, 10)


# ── Scroll: parchment with a red wax seal and ribbon ───────────────────────────────────────────────────────────
@icon
def Scroll():
    import bpy

    paper = glossy("Parch", srgb("#D2A35A"), 0.55, coat=0.15)
    edge = glossy("ParchDark", srgb("#A87A3E"), 0.55, coat=0.1)
    wax = glossy("Wax", srgb("#D8242A"), 0.22, coat=0.7)
    waxd = glossy("WaxD", srgb("#B0151C"), 0.25, coat=0.7)
    L = 1.5
    # sheet with gently wavy sides
    pts = []
    n = 12
    for i in range(n + 1):
        z = -0.62 + 1.24 * i / n
        pts.append((0.66 + 0.035 * math.sin(i * 1.3), z))
    for i in range(n, -1, -1):
        z = -0.62 + 1.24 * i / n
        pts.append((-0.66 + 0.035 * math.sin(i * 1.7 + 1), z))
    prism("Sheet", pts, 0.06, paper, loc=(0, 0, 0), bevel=0.025)
    for name, zc, side in (("Top", 0.66, 1), ("Bot", -0.66, -1)):
        cyl(f"Roll{name}", 0.22, L, paper, loc=(0, 0.08, zc), rot=[("Y", 90)], bevel=0.05)
        # spiral curl on both ends
        for ex in (-1, 1):
            sp = []
            for k in range(13):
                a = k * 0.8
                r = 0.19 * (1 - k / 16)
                sp.append(Vector((ex * (L / 2 + 0.005), 0.08 + r * math.cos(a), zc + r * math.sin(a))))
            tube(f"Curl{name}{ex}", sp, 0.03, edge, outline=0)
        cyl(f"RollLip{name}", 0.23, 0.06, paper, loc=(-L / 2 + 0.03, 0.08, zc), rot=[("Y", 90)], bevel=0.02, outline=0.02)
    # ribbon tails behind the seal
    for sx in (-1, 1):
        rib = [(0, 0), (sx * 0.16, 0.02), (sx * 0.34, -0.5), (sx * 0.23, -0.42), (sx * 0.17, -0.56)]
        o = prism(f"Ribbon{sx}", rib, 0.05, wax, loc=(0.18, -0.08, -0.12), bevel=0.015, outline=0.02)
        o.matrix_world = Matrix.Translation((0.18, -0.08, -0.12)) @ rot("Y", sx * -8) @ Matrix.Translation((-0.18, 0.08, 0.12)) @ o.matrix_world
    # seal: wavy disc, raised ring, star
    seal = []
    for i in range(72):
        a = 2 * math.pi * i / 72
        r = 0.32 + 0.022 * math.cos(a * 9)
        seal.append((math.cos(a) * r, math.sin(a) * r))
    prism("Seal", seal, 0.14, wax, loc=(0.18, -0.13, -0.08), bevel=0.05)
    torus("SealRing", 0.21, 0.03, waxd, loc=(0.18, -0.205, -0.08), rot=[("X", 90)], outline=0)
    prism("SealStar", star_pts(5, 0.15, 0.065), 0.06, waxd, loc=(0.18, -0.2, -0.08), bevel=0.015, outline=0)
    for o in [x for x in bpy.context.scene.objects if x.type == "MESH"]:
        o.matrix_world = rot("Y", -14) @ o.matrix_world
    lib.group_tilt(-16, 8)


# ── Calendar: desk calendar with red band, brass rings, day squares ────────────────────────────────────────────
@icon
def Calendar():
    red = glossy("CalRed", srgb("#E0302A"), 0.3)
    redd = glossy("CalRedD", srgb("#B71F1F"), 0.35)
    page = glossy("Page", CREAM, 0.4, coat=0.3)
    day = glossy("Day", srgb("#D4AA80"), 0.45, coat=0.2)
    g = gold("Brass")
    get = track(None)
    PW, PH = 1.7, 1.42
    box("Board", (PW, 0.12, PH), page, loc=(0, 0, PH / 2), bevel=0.06)
    box("Band", (PW + 0.06, 0.24, 0.34), red, loc=(0, 0, PH - 0.02), bevel=0.07)
    for sx in (-1, 1):
        torus(f"Ring{sx}", 0.17, 0.05, g, loc=(sx * 0.5, 0, PH + 0.14), rot=[("Y", 90)], outline=0.02)
    cols, rows = 4, 4
    sw, sh = 0.26, 0.2
    gx, gz = 0.36, 0.26
    for r in range(rows):
        for c in range(cols):
            if (r == 3 and c == 3) or (r == 0 and c == 3):
                continue
            mat = red if (r == 1 and c == 3) else day
            x = -gx * 1.5 + c * gx
            z = PH - 0.42 - r * gz
            box(f"D{r}{c}", (sw, 0.04, sh), mat, loc=(x, -0.07, z), bevel=0.025, outline=0)
    front = get()
    pivot(front, rot("X", 12), (0, 0, 0))
    # back leg leaning the other way, base
    leg = [box("Leg", (PW - 0.1, 0.1, PH - 0.1), redd, loc=(0, 0.02, (PH - 0.1) / 2), bevel=0.05)]
    pivot(leg, rot("X", -26), (0, 0, 0))
    for o in leg:
        o.matrix_world = Matrix.Translation((0, 0.62, 0)) @ o.matrix_world
    box("Base", (PW + 0.14, 1.0, 0.12), red, loc=(0, 0.28, 0.02), bevel=0.05)
    lib.group_tilt(-26, 10)


# ── Camera: red body, gold trim, big blue lens ─────────────────────────────────────────────────────────────────
@icon
def Camera():
    red = glossy("CamRed", srgb("#D8402A"), 0.3)
    blk = glossy("CamBlack", srgb("#2A2730"), 0.35, coat=0.5)
    g = gold()
    glass = glossy("Glass", srgb("#3B2BD8"), 0.06, coat=1.0)
    BW, BD, BH = 2.0, 0.9, 1.2
    box("Body", (BW, BD, BH), red, loc=(0, 0, 0), bevel=0.12)
    box("Top", (BW + 0.04, BD + 0.04, 0.2), g, loc=(0, 0, BH / 2 - 0.09), bevel=0.07)
    box("Bottom", (BW + 0.04, BD + 0.04, 0.26), blk, loc=(0, 0, -BH / 2 + 0.12), bevel=0.09)
    box("GripR", (0.22, BD + 0.06, BH - 0.3), g, loc=(BW / 2 - 0.1, 0, 0), bevel=0.06)
    # viewfinder hump
    hump = [(-0.42, 0), (0.42, 0), (0.3, 0.34), (-0.3, 0.34)]
    prism("Hump", hump, 0.6, blk, loc=(0.25, 0.05, BH / 2 - 0.02), bevel=0.06)
    cyl("Button", 0.15, 0.14, red, loc=(-0.6, 0.0, BH / 2 + 0.06), bevel=0.04)
    cyl("ButtonBase", 0.18, 0.06, blk, loc=(-0.6, 0.0, BH / 2 + 0.0), bevel=0.02, outline=0.02)
    # lens
    lx, lz = -0.2, -0.06
    cyl("Barrel", 0.54, 0.34, g, loc=(lx, -BD / 2 - 0.12, lz), rot=[("X", 90)], bevel=0.05)
    torus("LensRim", 0.5, 0.075, g, loc=(lx, -BD / 2 - 0.3, lz), rot=[("X", 90)], outline=0.02)
    cyl("LensBlack", 0.44, 0.1, blk, loc=(lx, -BD / 2 - 0.3, lz), rot=[("X", 90)], bevel=0.02, outline=0)
    sphere("Glass", 0.36, glass, loc=(lx, -BD / 2 - 0.33, lz), scale=(1, 0.45, 1), outline=0)
    sphere("Glint", 0.08, glossy("Glint", WHITE, 0.2, emit=2.5), loc=(lx - 0.13, -BD / 2 - 0.5, lz + 0.14), scale=(1, 0.3, 0.8), outline=0)
    lib.group_tilt(-26, 12)


# ── Sleep: crescent moon with a closed eye and bubbles ─────────────────────────────────────────────────────────
@icon
def Sleep():
    moon = glossy("Moon", srgb("#A9B6FA"), 0.3, coat=0.6)
    crater = glossy("Crater", srgb("#8E9BEA"), 0.4)
    bub = glossy("Bubble", srgb("#3F96FF"), 0.12, coat=0.9)
    ink = glossy("Ink", srgb("#232050"), 0.5, coat=0)
    # tapered tube along an arc = crescent with rounded tips
    cx, cz, R = 0.18, 0.0, 0.72
    a0, a1 = 62, 298
    wtip, wmax = 0.07, 0.46
    n = 48
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        w = wtip + (wmax - wtip) * math.sin(math.pi * t) ** 0.85
        # crescent: thickness offset mostly outward so the inner edge stays a clean arc
        ro, ri = R + w * 0.75, R - w * 1.05
        outer.append((cx + ro * math.cos(a), cz + ro * math.sin(a)))
        inner.append((cx + ri * math.cos(a), cz + ri * math.sin(a)))
    pts = outer + list(reversed(inner))
    prism("Moon", pts, 0.5, moon, bevel=0.2, segs=6)
    fy = -0.26
    # closed eye: a curved lid line with a lash
    tube("Eye", [Vector((-0.5, fy, 0.08)), Vector((-0.33, fy, -0.02)), Vector((-0.16, fy, 0.08))], 0.034, ink, outline=0)
    tube("Lash", [Vector((-0.17, fy, 0.075)), Vector((-0.13, fy, 0.1))], 0.026, ink, outline=0)
    for i, (x, z, r) in enumerate(((-0.62, -0.4, 0.1), (-0.32, -0.66, 0.07), (-0.72, 0.3, 0.06))):
        cyl(f"Crater{i}", r, 0.04, crater, loc=(x, fy + 0.005, z), rot=[("X", 90)], bevel=0.015, outline=0)
    for i, (x, z, r) in enumerate(((1.0, 1.08, 0.17), (0.72, 0.84, 0.12), (1.0, 0.6, 0.11))):
        sphere(f"Bubble{i}", r, bub, loc=(x, -0.05, z), outline=0.025)
        sphere(f"BubGlint{i}", r * 0.28, glossy("BG", WHITE, 0.2, emit=2.0), loc=(x - r * 0.35, -0.05 - r * 0.85, z + r * 0.38), scale=(1, 0.4, 1), outline=0)
    lib.group_tilt(-18, 8)


# ── Crown: gold band with points, ball tips, red velvet, gems ──────────────────────────────────────────────────
def crown_band(name, R, t, h0, hp, npts, mat, segs=200, phase=-90):
    bm = bmesh.new()
    cols = []
    for i in range(segs):
        th = 2 * math.pi * i / segs
        f = ((math.degrees(th) - phase) / (360 / npts)) % 1.0
        tri = 1 - min(f, 1 - f) * 2
        top = h0 + hp * tri ** 1.0
        c, s = math.cos(th), math.sin(th)
        cols.append((bm.verts.new((R * c, R * s, 0)), bm.verts.new((R * c, R * s, top)),
                     bm.verts.new(((R - t) * c, (R - t) * s, top)), bm.verts.new(((R - t) * c, (R - t) * s, 0))))
    for i in range(segs):
        a, b = cols[i], cols[(i + 1) % segs]
        for k in range(4):
            bm.faces.new((a[k], b[k], b[(k + 1) % 4], a[(k + 1) % 4]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(lib._obj(name, bm, mat), 0.03, segs=2)


@icon
def Crown():
    g = gold()
    velvet = glossy("Velvet", srgb("#C81E26"), 0.42, coat=0.4)
    R, h0, hp = 1.0, 0.55, 0.6
    sphere("Velvet", R * 0.9, velvet, loc=(0, 0, 0.42), scale=(1, 1, 0.72))
    crown_band("Band", R, 0.1, h0, hp, 5, g)
    torus("RimBottom", R + 0.02, 0.11, g, loc=(0, 0, 0.02), outline=0.03, seg=96)
    torus("RimTop", R + 0.0, 0.05, g, loc=(0, 0, h0 - 0.02), outline=0.02, seg=96)
    for k in range(5):
        th = math.radians(-90 + 72 * k)
        sphere(f"Ball{k}", 0.13, g, loc=(R * math.cos(th) * 0.98, R * math.sin(th) * 0.98, h0 + hp + 0.06))
    # gems: chamfered rhombus prisms (the 1-segment bevel reads as facets)
    gems = ((-90, BLUE, 0.2), (-30, BLUE, 0.15), (-150, RED, 0.15))
    for i, (deg, col, s) in enumerate(gems):
        th = math.radians(deg)
        o = prism(f"Gem{i}", [(0, s * 1.25), (s * 0.8, 0), (0, -s * 1.25), (-s * 0.8, 0)], 0.1, glossy(f"Gem{i}", col, 0.08, coat=1.0), bevel=0.04, segs=1, outline=0.02)
        o.matrix_world = Matrix.Translation(((R + 0.04) * math.cos(th), (R + 0.04) * math.sin(th), h0 * 0.55 + 0.04)) @ rot("Z", deg + 90) @ o.matrix_world
    lib.group_tilt(-14, 18)


# ── Trophy: gold cup with handles on a dark plinth ─────────────────────────────────────────────────────────────
@icon
def Trophy():
    g = gold()
    plinth = glossy("Plinth", srgb("#3B2C2E"), 0.35, coat=0.5)
    cup = [(0, 0.95), (0.55, 1.05), (0.72, 1.55), (0.74, 1.66), (0.84, 1.68), (0.86, 1.6), (0.82, 1.45), (0.66, 1.02),
           (0.42, 0.78), (0.18, 0.66), (0.12, 0.58), (0.1, 0.42), (0.2, 0.36), (0.2, 0.3), (0.12, 0.26), (0.13, 0.14),
           (0.36, 0.08), (0.44, 0.0), (0, 0.0)]
    lathe("Cup", cup, g, segs=72, outline=0.035)
    for sx in (-1, 1):
        tube(f"Handle{sx}", [Vector((sx * 0.74, 0, 1.42)), Vector((sx * 1.12, 0, 1.46)), Vector((sx * 1.12, 0, 1.12)),
                              Vector((sx * 0.8, 0, 0.95)), Vector((sx * 0.6, 0, 0.92))], 0.09, g, outline=0.03)
    box("Plinth", (1.3, 0.9, 0.36), plinth, loc=(0, 0, -0.18), bevel=0.08)
    box("Plinth2", (1.0, 0.7, 0.12), plinth, loc=(0, 0, 0.04), bevel=0.04, outline=0.02)
    box("Plate", (0.7, 0.04, 0.16), g, loc=(0, -0.46, -0.19), bevel=0.02, outline=0.015)
    lib.group_tilt(-22, 12)


# ── Lock: brass padlock with keyhole and rivets ────────────────────────────────────────────────────────────────
@icon
def Lock():
    g = gold()
    shk = glossy("Shackle", srgb("#D9A030"), 0.22, 0.55, 0.6)
    hole = glossy("Keyhole", srgb("#2A1608"), 0.6, coat=0)
    riv = glossy("LockRivet", srgb("#E59A12"), 0.25, 0.5, 0.6)
    BW, BD, BH = 1.6, 0.6, 1.3
    tube("Shackle", [Vector((-0.5, 0, 0.3)), Vector((-0.5, 0, 0.95)), Vector((0, 0, 1.36)), Vector((0.5, 0, 0.95)), Vector((0.5, 0, 0.3))], 0.14, shk, outline=0.03)
    box("Body", (BW, BD, BH), g, loc=(0, 0, 0), bevel=0.16)
    # keyhole: circle + flared slot
    kh = arc(0, 0.12, 0.17, -62, 242, 24) + [(-0.14, -0.34), (0.14, -0.34)]
    prism("Keyhole", kh, 0.1, hole, loc=(0, -BD / 2 + 0.02, -0.05), bevel=0.02, outline=0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            sphere(f"Rivet{sx}{sz}", 0.075, riv, loc=(sx * (BW / 2 - 0.2), -BD / 2 - 0.01, sz * (BH / 2 - 0.2)), outline=0.015)
    lib.group_tilt(-22, 10)


# ── Ticket: red ticket, cream panel, gold star ─────────────────────────────────────────────────────────────────
def ticket_outline(w, h, rc, rn, n=8):
    x, z = w / 2, h / 2
    pts = []
    pts += arc(x - rc, -z + rc, rc, -90, 0, n)
    pts += arc(x, 0, rn, -90, -270, n * 2)  # right notch (concave)
    pts += arc(x - rc, z - rc, rc, 0, 90, n)
    pts += arc(-x + rc, z - rc, rc, 90, 180, n)
    pts += arc(-x, 0, rn, 90, -90, n * 2)  # left notch (concave)
    pts += arc(-x + rc, -z + rc, rc, 180, 270, n)
    return pts


def inner_outline(w, h, rc, n=6):
    """Rectangle with concave quarter-circle corners."""
    x, z = w / 2, h / 2
    return (arc(x, -z, rc, 180, 90, n) + arc(x, z, rc, 270, 180, n) + arc(-x, z, rc, 0, -90, n) + arc(-x, -z, rc, 90, 0, n))


@icon
def Ticket():
    import bpy

    red = glossy("TicketRed", srgb("#E2302A"), 0.3)
    cream = glossy("TicketCream", srgb("#F6D9A6"), 0.4, coat=0.3)
    g = gold()
    W, H = 2.0, 1.2
    prism("Ticket", ticket_outline(W, H, 0.12, 0.2), 0.2, red, bevel=0.06, segs=4)
    prism("Border", inner_outline(1.46, 0.86, 0.14), 0.06, g, loc=(0, -0.11, 0), bevel=0.02, outline=0.015)
    prism("Panel", inner_outline(1.36, 0.76, 0.14), 0.06, cream, loc=(0, -0.135, 0), bevel=0.02, outline=0)
    prism("Star", star_pts(5, 0.36, 0.18), 0.14, g, loc=(0, -0.2, 0), bevel=0.05, segs=4, outline=0.02)
    # gold corner caps
    for sx in (-1, 1):
        for sz in (-1, 1):
            pts = [(0, 0), (-0.26, 0), (-0.26, -0.07), (-0.07, -0.07), (-0.07, -0.26), (0, -0.26)]
            pts = [(p[0] * sx, p[1] * sz) for p in pts]
            prism(f"Corner{sx}{sz}", pts, 0.05, g, loc=(sx * (W / 2 - 0.08), -0.11, sz * (H / 2 - 0.08)), bevel=0.015, outline=0.012)
    for o in [x for x in bpy.context.scene.objects if x.type == "MESH"]:
        o.matrix_world = rot("Y", -22) @ o.matrix_world
    lib.group_tilt(-18, 10)
