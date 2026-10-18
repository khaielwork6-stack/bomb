"""FUSE VALLEY icons — set A: Star, Bomb, Gear, Gift (art/ref/icons/icons_sheet1.png)."""

import math

import lib
from lib import box, cyl, glossy, gold, icon, prism, silver, sphere, srgb, star_pts, torus, tube
from mathutils import Vector

# ── Palette ─────────────────────────────────────────────────────────────────────────────────────────────────────
RED = srgb("#E8322B")
ORANGE = srgb("#FF6A1F")
WOOD = srgb("#C2410F")
CREAM = srgb("#FFF0D6")
PAPER = srgb("#F4DDAE")
INK = srgb("#1B1622")
BLUE = srgb("#2F7BFF")
CYAN = srgb("#2FD3FF")
GREEN = srgb("#2BC24A")
PURPLE = srgb("#9B4DFF")
PINK = srgb("#FF5FB8")
YELLOW = srgb("#FFD84A")


@icon
def Star():
    prism("Star", star_pts(5, 1.0, 0.48), 0.42, gold(), bevel=0.16, segs=5)


@icon
def Bomb():
    sphere("Body", 0.82, glossy("Iron", srgb("#26232C"), 0.3, 0.2, 0.7))
    torus("Band", 0.83, 0.075, gold(), rot=[("X", 0)], loc=(0, 0, -0.05))
    for i in range(10):
        a = 2 * math.pi * i / 10
        sphere(f"Rivet{i}", 0.045, gold(), loc=(math.cos(a) * 0.9, math.sin(a) * 0.9, -0.05), outline=0)
    cyl("Collar", 0.2, 0.22, gold(), loc=(0.22, 0, 0.78), rot=[("Y", 22)])
    tube("Fuse", [Vector((0.27, 0, 0.88)), Vector((0.36, 0, 1.08)), Vector((0.56, 0, 1.18))], 0.06, glossy("Cord", srgb("#C99A5A"), 0.8, coat=0))
    prism("Spark", star_pts(8, 0.3, 0.12), 0.06, glossy("SparkG", YELLOW, emit=6), loc=(0.66, -0.05, 1.22), bevel=0.01, outline=0.015)
    lib.group_tilt(-18, 8)


@icon
def Gear():
    pts = []
    teeth = 8
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = 1.0 if (i % 4) in (1, 2) else 0.78
        pts.append((math.cos(a) * r, math.sin(a) * r))
    g = prism("Gear", pts, 0.36, silver(), bevel=0.07)
    # hub hole: a dark recessed disc
    cyl("Hole", 0.3, 0.38, glossy("Hole", srgb("#3A3F4A"), 0.6), rot=[("X", 90)], outline=0)
    torus("HubRim", 0.32, 0.06, silver(), rot=[("X", 90)], loc=(0, -0.19, 0))
    lib.group_tilt(-22, 12)


@icon
def Gift():
    paper = glossy("Paper", ORANGE, 0.35)
    box("Box", (1.5, 1.5, 1.15), paper, loc=(0, 0, 0), bevel=0.08)
    box("Lid", (1.62, 1.62, 0.34), paper, loc=(0, 0, 0.72), bevel=0.08)
    ribbon = gold("Ribbon")
    box("RibX", (0.3, 1.64, 1.5), ribbon, loc=(0, 0, 0.17), bevel=0.04, outline=0.015)
    box("RibY", (1.64, 0.3, 1.5), ribbon, loc=(0, 0, 0.17), bevel=0.04, outline=0.015)
    for side in (-1, 1):
        torus(f"Bow{side}", 0.32, 0.11, ribbon, loc=(side * 0.34, 0, 1.05), rot=[("X", 90), ("Y", side * 30)])
    sphere("Knot", 0.16, ribbon, loc=(0, 0, 0.98))
    for i, (x, z) in enumerate(((-0.5, -0.25), (0.45, 0.15), (-0.2, 0.3), (0.5, -0.38))):
        prism(f"Dot{i}", star_pts(5, 0.11, 0.05), 0.02, glossy("StarDeco", srgb("#FFB347"), 0.3), loc=(x, -0.76, z), bevel=0.005, outline=0)
    lib.group_tilt(-28, 14)


