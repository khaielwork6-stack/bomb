"""FUSE VALLEY — The Quarry's mine tunnel mouth, two at the back of each Safe Strip (docs/maps/QUARRY_BRIEF.md
"Safe Strips"; GDD §19 maps, Asset Bible §4 props, §1 Quality Bar).

A timber-framed mine entrance set into a chunky sandstone outcrop: two thick posts and a header beam with knee braces,
iron strap plates and bolts at the joints, two more timber sets receding into a dark tunnel (each darker than the
last, so the opening reads deep), a rail line on sleepers running out of the dark to the front edge, and two
hanging lanterns on iron brackets either side of the mouth (their glass is the glow part). The outcrop is faceted
terracotta sandstone with cream strata and a sandy top.

MeshPart groups: Rock (outcrop), Tunnel (the dark inside), Timber (sets, braces), Trim (iron plates, bolts, brackets,
lantern frames, rails, sleepers), Glow (lantern glass; Neon).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_tunnel_mouth.py -- [--samples 64] [--no-render]
Out:  art/out/Prop.TunnelMouth/  (renders/, export/Prop.TunnelMouth.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the opening). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
import qkit  # noqa: E402
from kit import Vector, srgb  # noqa: E402

KEY = "Prop.TunnelMouth"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Rock", "Tunnel", "Timber", "Trim"], glow=["Glow"])
rng = random.Random(4242)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
SAND_BASE, SAND_HI, SAND_CREAM, SAND_SEAM = srgb("#D0663A"), srgb("#F08E58"), srgb("#F6D9A6"), srgb("#9A4426")
TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK = srgb("#A85C2C"), srgb("#D88A4E"), srgb("#F0C08A"), srgb("#4E2812")
IRON, IRON_HI, IRON_EDGE, IRON_BARE = srgb("#33363F"), srgb("#5C6070"), srgb("#8E94A6"), srgb("#9EA2AE")
IRON_LO, IRON_M, IRON_MHI = srgb("#24262E"), srgb("#4A4E5C"), srgb("#B4BCD0")
SLEEPER, SLEEPER_HI = srgb("#8A4E26"), srgb("#B87442")
GLOW = srgb("#FFC46E")

M_ROCK = qkit.mat_sandstone("Sandstone", SAND_BASE, SAND_HI, SAND_CREAM, SAND_SEAM, strata=1.6, light=srgb("#E8844A"))
M_DARK = qkit.mat_dark("TunnelDark")
M_IRON = kit.mat_paint_metal("Iron", IRON, IRON_HI, IRON_EDGE, IRON_BARE, rough=0.4, chip=0.45, spots=0.8)
M_BRIGHT = kit.mat_metal("BrightIron", IRON_LO, IRON_M, IRON_MHI, rough=(0.22, 0.36), metal=0.3)
M_GLOW = kit.mat_emit("Lantern", GLOW, 8.0)


def timber(axis, shade=0):
    """Frame timber; shade 1 / 2 = the receding sets, darker so the mouth reads deep."""
    k = (1.0, 0.62, 0.38)[shade]
    p = tuple(c * k if i < 3 else c for i, c in enumerate(TIMBER))
    h = tuple(c * k if i < 3 else c for i, c in enumerate(TIMBER_HI))
    return qkit.mat_timber(f"Timber{shade}", p, h, TIMBER_BARE if shade == 0 else h, TIMBER_DK, axis=axis)


def sleeper_mat(axis):
    return qkit.mat_timber("Sleeper", SLEEPER, SLEEPER_HI, srgb("#E0A878"), TIMBER_DK, axis=axis)


# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
OPEN_W, OPEN_H = 5.9, 8.2  # the clear opening between the posts / under the header
POST, POST_X, POST_Y = 0.95, 3.42, -2.3
HEAD_Z0, HEAD_H = OPEN_H, 1.2
FRONT_Y = POST_Y - POST / 2
CAV_X, CAV_TOP, CAV_BACK = 2.95, 7.75, 2.9
GAUGE = 0.9
RAIL_TOP = 0.37

# ── The outcrop ──────────────────────────────────────────────────────────────────────────────────────────────────
qkit.hull_rock("RockL", (3.4, 5.0, 9.8), (-5.3, 0.4, 0), M_ROCK, "Rock", seed=11, n=22, jitter=0.1, bev=0.16)
qkit.hull_rock("RockR", (3.3, 4.8, 9.2), (5.35, 0.5, 0), M_ROCK, "Rock", seed=12, n=22, jitter=0.1, bev=0.16)
qkit.hull_rock("RockTop", (13.4, 5.0, 4.4), (0, 0.45, 8.3), M_ROCK, "Rock", seed=13, n=26, jitter=0.07, bev=0.18, squash_top=0.2)
qkit.hull_rock("RockTopKnob", (5.0, 3.4, 1.6), (-2.6, 1.0, 11.3), M_ROCK, "Rock", seed=17, n=14, jitter=0.1, bev=0.16)
qkit.hull_rock("RockFootL", (2.0, 2.2, 1.9), (-5.75, -2.0, 0), M_ROCK, "Rock", seed=15, n=14, jitter=0.12, bev=0.14)
qkit.hull_rock("RockFootR", (1.8, 1.9, 1.4), (5.9, -1.9, 0), M_ROCK, "Rock", seed=16, n=14, jitter=0.12, bev=0.14)
qkit.hull_rock("RockLedgeR", (3.0, 2.8, 1.3), (5.0, -0.2, 8.9), M_ROCK, "Rock", seed=18, n=14, jitter=0.1, bev=0.14)

# ── The dark inside: walls, ceiling, back, floor (inner faces at ±CAV_X, CAV_TOP, CAV_BACK) ─────────────────────────
DEPTH0 = FRONT_Y + 0.25
cav_len = CAV_BACK - DEPTH0
kit.box("CavL", (0.9, cav_len, CAV_TOP + 0.4), (-CAV_X - 0.45, DEPTH0 + cav_len / 2, (CAV_TOP + 0.4) / 2), M_DARK, "Tunnel", bev=0.0)
kit.box("CavR", (0.9, cav_len, CAV_TOP + 0.4), (CAV_X + 0.45, DEPTH0 + cav_len / 2, (CAV_TOP + 0.4) / 2), M_DARK, "Tunnel", bev=0.0)
kit.box("CavTop", (2 * CAV_X + 1.8, cav_len, 0.8), (0, DEPTH0 + cav_len / 2, CAV_TOP + 0.4), M_DARK, "Tunnel", bev=0.0)
kit.box("CavBack", (2 * CAV_X + 0.2, 0.4, CAV_TOP + 0.2), (0, CAV_BACK + 0.2, (CAV_TOP + 0.2) / 2), M_DARK, "Tunnel", bev=0.0)
kit.box("CavFloor", (2 * CAV_X + 0.2, cav_len, 0.06), (0, DEPTH0 + cav_len / 2, 0.03), M_DARK, "Tunnel", bev=0.0)

# ── The front set: posts, header, knee braces, iron plates ───────────────────────────────────────────────────────
for s in (-1, 1):
    x = s * POST_X
    kit.box(f"Post{s}", (POST, POST, HEAD_Z0 + 0.1), (x, POST_Y, (HEAD_Z0 + 0.1) / 2), timber((0, 0, 1)), "Timber", bev=0.1, segs=2)
    kit.box(f"PostFoot{s}", (POST + 0.3, POST + 0.3, 0.45), (x, POST_Y, 0.225), timber((1, 0, 0)), "Timber", bev=0.08, segs=2)
    # knee brace from the post up to the header's underside
    a = Vector((x - s * POST / 2 + s * 0.05, POST_Y, HEAD_Z0 - 1.75))
    b = Vector((x - s * 1.95, POST_Y, HEAD_Z0 + 0.05))
    qkit.beam(f"Brace{s}", a, b, 0.5, 0.45, timber, "Timber", bev=0.07, segs=2, up=(0, -1, 0), ext=0.12)
    # iron plate where post meets header, and one on the foot
    kit.box(f"Plate{s}", (POST + 0.12, 0.08, 1.4), (x, FRONT_Y - 0.04, HEAD_Z0 + 0.15), M_IRON, "Trim", bev=0.03, segs=1)
    for z in (HEAD_Z0 - 0.3, HEAD_Z0 + 0.6):
        for e in (-1, 1):
            kit.rivet(f"PlateBolt{s}{z}{e}", (x + e * 0.28, FRONT_Y - 0.08, z), (0, -1, 0), M_BRIGHT, "Trim", r=0.09, segs=6)
    kit.box(f"FootBand{s}", (POST + 0.34, POST + 0.34, 0.14), (x, POST_Y, 0.52), M_IRON, "Trim", bev=0.03, segs=1)
kit.box("Header", (2 * POST_X + POST + 1.5, 1.15, HEAD_H), (0, POST_Y - 0.05, HEAD_Z0 + HEAD_H / 2), timber((1, 0, 0)), "Timber", bev=0.11, segs=2)
kit.box("Cap", (2 * POST_X + POST + 2.1, 1.45, 0.4), (0, POST_Y + 0.05, HEAD_Z0 + HEAD_H + 0.2), timber((1, 0, 0)), "Timber", bev=0.09, segs=2)
for e in (-1, 0, 1):
    kit.rivet(f"HeaderBolt{e}", (e * 1.6, POST_Y - 0.05 - 0.6, HEAD_Z0 + HEAD_H / 2), (0, -1, 0), M_BRIGHT, "Trim", r=0.1, segs=6)

# ── The receding sets inside the tunnel ──────────────────────────────────────────────────────────────────────────
for k, (y, shade) in enumerate(((0.2, 1), (1.9, 2))):
    for s in (-1, 1):
        kit.box(f"InPost{k}{s}", (0.7, 0.7, CAV_TOP), (s * (CAV_X - 0.35), y, CAV_TOP / 2), timber((0, 0, 1), shade), "Timber", bev=0.07, segs=1)
    kit.box(f"InHead{k}", (2 * CAV_X, 0.75, 0.7), (0, y, CAV_TOP - 0.35), timber((1, 0, 0), shade), "Timber", bev=0.07, segs=1)
# ceiling lagging: planks along the tunnel between the sets
for i in range(5):
    x = -2.3 + i * 1.15
    kit.box(f"Lagging{i}", (0.95, cav_len - 0.4, 0.14), (x, DEPTH0 + cav_len / 2 + 0.2, CAV_TOP - 0.08), timber((0, 1, 0), 2), "Timber", bev=0.04, segs=1)

# ── Rails running out of the dark to the front edge ──────────────────────────────────────────────────────────────
RAIL_Y0, RAIL_Y1 = FRONT_Y - 0.55, CAV_BACK - 0.1
for i in range(6):
    y = RAIL_Y0 + 0.45 + i * 1.0
    kit.box(f"Sleeper{i}", (2.7, 0.6, 0.16), (rng.uniform(-0.04, 0.04), y, 0.08), sleeper_mat((1, 0, 0)), "Trim", bev=0.05, segs=1)
for s in (-1, 1):
    x = s * GAUGE
    L = RAIL_Y1 - RAIL_Y0
    kit.box(f"RailFoot{s}", (0.34, L, 0.05), (x, RAIL_Y0 + L / 2, 0.185), M_BRIGHT, "Trim", bev=0.02, segs=1)
    kit.box(f"RailWeb{s}", (0.1, L, 0.1), (x, RAIL_Y0 + L / 2, 0.26), M_BRIGHT, "Trim", bev=0.02, segs=1)
    kit.box(f"RailHead{s}", (0.2, L, 0.09), (x, RAIL_Y0 + L / 2, RAIL_TOP - 0.045), M_BRIGHT, "Trim", bev=0.035, segs=1)

# ── Lanterns on iron brackets either side of the mouth ───────────────────────────────────────────────────────────
LANTERN_Z = 5.75
lanterns = []
for s in (-1, 1):
    x = s * POST_X
    ly = FRONT_Y - 0.62
    top = Vector((x, ly, LANTERN_Z + 0.95))
    # bracket: a wall plate, an arm out from the post, a little scroll under it, the hook
    kit.box(f"BracketPlate{s}", (0.42, 0.08, 0.8), (x, FRONT_Y - 0.04, LANTERN_Z + 1.1), M_IRON, "Trim", bev=0.03, segs=1)
    kit.box(f"BracketArm{s}", (0.12, 0.72, 0.12), (x, FRONT_Y - 0.36, LANTERN_Z + 1.38), M_IRON, "Trim", bev=0.03, segs=1)
    qkit.beam(f"BracketStrut{s}", (x, FRONT_Y - 0.05, LANTERN_Z + 0.85), (x, FRONT_Y - 0.5, LANTERN_Z + 1.36), 0.09, 0.09, lambda d: M_IRON, "Trim", bev=0.02, segs=1)
    kit.rope(f"Hanger{s}", [(x, ly, LANTERN_Z + 1.38), (x, ly, LANTERN_Z + 1.16), (x, ly, top.z - 0.02)], 0.035, M_IRON, "Trim", res=2, bres=1)
    # the lantern: cap, ring, four bars round the glass, base
    kit.torus(f"Ring{s}", 0.11, 0.03, (x, ly, top.z + 0.06), M_IRON, "Trim", axis="Y", major=10, minor=4)
    kit.cylinder(f"Cap{s}", 0.36, 0.26, (x, ly, LANTERN_Z + 0.75), M_IRON, "Trim", segs=12, bev=0.03, bev_segs=1, r2=0.14)
    kit.cylinder(f"Base{s}", 0.32, 0.16, (x, ly, LANTERN_Z - 0.32), M_IRON, "Trim", segs=12, bev=0.04, bev_segs=1)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        kit.box(f"Bar{s}{k}", (0.06, 0.06, 1.0), (x + math.cos(a) * 0.29, ly + math.sin(a) * 0.29, LANTERN_Z + 0.2), M_IRON, "Trim", bev=0.015, segs=1)
    g = kit.lathe(f"Glass{s}", [(0.0, -0.26), (0.2, -0.26), (0.26, -0.1), (0.27, 0.2), (0.22, 0.56), (0.0, 0.6)], M_GLOW, "Glow", segs=14)
    g.location = (x, ly, LANTERN_Z)
    lanterns.append(Vector((x, ly, LANTERN_Z + 0.17)))

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), "LO", kit.blend(lo), "HI", kit.blend(hi), flush=True)

kit.render_setup(target=(0, 0, 6.0), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (20.0, -30.0, 15.0), lens=50, target=(0, 0, 6.0))
    kit.shoot("front", (0, -40.0, 6.5), lens=50, target=(0, 0, 6.3))
    kit.shoot("close", (4.5, -11.0, 4.0), lens=35, target=(0, 0, 4.0))

maps = kit.bake_all(parts, {"Rock": 2048, "Tunnel": 512, "Timber": 2048, "Trim": 1024}) if BAKE else {}
ups = qkit.export(parts)
open_c = Vector((0, FRONT_Y, OPEN_H / 2))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Safe Strips (a timber-framed mine tunnel mouth behind each strip); GDD §19; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": ["Glow"],
        "markers": {
            "OpeningCentre": {"blender": kit.blend(open_c), "roblox_from_pivot": kit.rbx(open_c, pivot), "opening_size_studs": [OPEN_W, OPEN_H]},
            "FrontFace": {"note": "the posts' front faces", "roblox_from_pivot_z": kit.rbx((0, FRONT_Y, 0), pivot)[2]},
            "RailTop": {"height_from_pivot": RAIL_TOP, "gauge_centres_studs": 2 * GAUGE, "rails_run": "model Z (out of the tunnel toward the front)"},
            "Lanterns": [{"blender": kit.blend(p), "roblox_from_pivot": kit.rbx(p, pivot)} for p in lanterns],
        },
        "front_note": "The opening faces the front (-Y in Blender = the model's LookVector in Roblox).",
    }
)
