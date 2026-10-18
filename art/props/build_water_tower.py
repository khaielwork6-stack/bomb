"""FUSE VALLEY — The Quarry's water tower, a backdrop landmark on the cliff ledges (docs/maps/QUARRY_BRIEF.md "Backdrop";
GDD §19 maps, Asset Bible §4 props, §1 Quality Bar).

A chunky toy desert water tower: four splayed timber legs on sandstone footings, girts and X braces, a plank deck, a
ladder up the front leg; a terracotta-red stave tank (each stave its own shade, grooves between them) held by three
dark iron hoops with gold rivets; a deep-red shingled cone roof with a gold ball finial; a swing spout with an iron
pipe and a canvas sock on the right side.

MeshPart groups: Timber (legs, girts, braces, deck, ladder), Tank (staves), Roof (cone, finial), Trim (hoops,
rivets, footings, spout, plates).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_water_tower.py -- [--samples 64] [--no-render]
Out:  art/out/Prop.WaterTower/  (renders/, export/Prop.WaterTower.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y (the ladder). Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
import qkit  # noqa: E402
from kit import Vector, srgb  # noqa: E402

KEY = "Prop.WaterTower"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Timber", "Tank", "Roof", "Trim"], glow=[])
rng = random.Random(77)

# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK = srgb("#8E4C24"), srgb("#C27A44"), srgb("#E8B07C"), srgb("#3E1E0C")
DECK, DECK_HI = srgb("#B0683A"), srgb("#DE9860")
TANK_A, TANK_B, TANK_HI, TANK_DK = srgb("#C8452C"), srgb("#DA5636"), srgb("#FF8A60"), srgb("#7A2414")
ROOF_A, ROOF_B, ROOF_HI, ROOF_DK = srgb("#8E2A22"), srgb("#A4342A"), srgb("#E06A50"), srgb("#4A120C")
IRON, IRON_HI, IRON_EDGE, IRON_BARE = srgb("#33363F"), srgb("#5C6070"), srgb("#8E94A6"), srgb("#9EA2AE")
IRON_LO, IRON_M, IRON_MHI = srgb("#24262E"), srgb("#4A4E5C"), srgb("#B4BCD0")
GOLD_LO, GOLD, GOLD_HI = srgb("#D8901C"), srgb("#FFC83A"), srgb("#FFF2B0")
STONE, STONE_HI, STONE_CREAM, STONE_SEAM = srgb("#C8784A"), srgb("#E89C68"), srgb("#F6D9A6"), srgb("#9A4E2E")
CANVAS, CANVAS_HI = srgb("#D8C49A"), srgb("#F4E6C4")


def timber(axis):
    return qkit.mat_timber("Tower", TIMBER, TIMBER_HI, TIMBER_BARE, TIMBER_DK, axis=axis, chip=0.45)


def deck(axis):
    return qkit.mat_timber("Deck", DECK, DECK_HI, TIMBER_BARE, TIMBER_DK, axis=axis, chip=0.45)


def mat_radial(name, a, b, hi, dk, count, rows=0.0, groove=0.05, rough=(0.45, 0.7)):
    """Staves / shingles round Z: `count` sectors, each its own shade between a and b, a dark groove between them,
    optional horizontal shingle rows every `rows` studs, grain along Z, top-lit to `hi`, bright worn edges."""
    m, nt, bs = kit.new_mat(name)
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    sep = kit.nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    ang = kit.nd(nt, "ShaderNodeMath", operation="ARCTAN2")
    nt.links.new(sep.outputs["Y"], ang.inputs[0])
    nt.links.new(sep.outputs["X"], ang.inputs[1])
    sc = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    sc.inputs[1].default_value = count / (2 * math.pi)
    nt.links.new(ang.outputs[0], sc.inputs[0])
    if rows:
        # stagger every other row by half a sector
        rz = kit.nd(nt, "ShaderNodeMath", operation="DIVIDE")
        rz.inputs[1].default_value = rows
        nt.links.new(sep.outputs["Z"], rz.inputs[0])
        rfl = kit.nd(nt, "ShaderNodeMath", operation="FLOOR")
        nt.links.new(rz.outputs[0], rfl.inputs[0])
        half = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
        half.inputs[1].default_value = 0.5
        nt.links.new(rfl.outputs[0], half.inputs[0])
        sc2 = kit.nd(nt, "ShaderNodeMath", operation="ADD")
        nt.links.new(sc.outputs[0], sc2.inputs[0])
        nt.links.new(half.outputs[0], sc2.inputs[1])
        sc = sc2
        rfr = kit.nd(nt, "ShaderNodeMath", operation="FRACT")
        nt.links.new(rz.outputs[0], rfr.inputs[0])
    fr = kit.nd(nt, "ShaderNodeMath", operation="FRACT")
    nt.links.new(sc.outputs[0], fr.inputs[0])
    fl = kit.nd(nt, "ShaderNodeMath", operation="FLOOR")
    nt.links.new(sc.outputs[0], fl.inputs[0])
    idv = fl.outputs[0]
    if rows:
        mix_id = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY_ADD")
        mix_id.inputs[1].default_value = 31.7
        nt.links.new(rfl.outputs[0], mix_id.inputs[0])
        nt.links.new(fl.outputs[0], mix_id.inputs[2])
        idv = mix_id.outputs[0]
    wn = kit.nd(nt, "ShaderNodeTexWhiteNoise", noise_dimensions="1D")
    nt.links.new(idv, wn.inputs["W"])
    col = kit.mix_rgb(nt, wn.outputs["Value"], a, b)
    mp = kit.nd(nt, "ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (5.0, 5.0, 0.5)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = kit.nd(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    wave.inputs["Scale"].default_value = 2.0
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 3.0
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    col = kit.mix_rgb(nt, kit.map_range(nt, wave.outputs["Fac"], 0.3, 1.0, 0.0, 0.12), col, dk)
    pp = kit.nd(nt, "ShaderNodeMath", operation="PINGPONG")
    pp.inputs[1].default_value = 0.5
    nt.links.new(fr.outputs[0], pp.inputs[0])
    gr = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    gr.inputs["From Min"].default_value = 0.0
    gr.inputs["From Max"].default_value = groove
    gr.inputs["To Min"].default_value = 1.0
    gr.inputs["To Max"].default_value = 0.0
    nt.links.new(pp.outputs[0], gr.inputs["Value"])
    g_out = gr.outputs["Result"]
    if rows:
        rg = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
        rg.inputs["From Min"].default_value = 0.0
        rg.inputs["From Max"].default_value = 0.12
        rg.inputs["To Min"].default_value = 1.0
        rg.inputs["To Max"].default_value = 0.0
        nt.links.new(rfr.outputs[0], rg.inputs["Value"])
        both = kit.nd(nt, "ShaderNodeMath", operation="MAXIMUM")
        nt.links.new(g_out, both.inputs[0])
        nt.links.new(rg.outputs["Result"], both.inputs[1])
        g_out = both.outputs[0]
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.6, 1.0, 0.35), col, hi)
    col = kit.mix_rgb(nt, kit.map_range(nt, g_out, 0, 1, 0, 0.7), col, dk)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.05, 2.2), col, hi)
    col = kit.ao_mult(nt, col, 0.7)
    nt.links.new(col, bs.inputs["Base Color"])
    nt.links.new(kit.map_range(nt, wave.outputs["Fac"], 0, 1, rough[0], rough[1]), bs.inputs["Roughness"])
    bs.inputs["Metallic"].default_value = 0.0
    inv = kit.nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(g_out, inv.inputs[1])
    bn = kit.nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.5
    bn.inputs["Distance"].default_value = 0.04
    nt.links.new(inv.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], bs.inputs["Normal"])
    return m


M_TANK = mat_radial("Staves", TANK_A, TANK_B, TANK_HI, TANK_DK, 32)
M_ROOF = mat_radial("Shingles", ROOF_A, ROOF_B, ROOF_HI, ROOF_DK, 28, rows=0.55, groove=0.06)
M_IRON = kit.mat_paint_metal("Iron", IRON, IRON_HI, IRON_EDGE, IRON_BARE, rough=0.4, chip=0.45, spots=0.8)
M_BRIGHT = kit.mat_metal("BrightIron", IRON_LO, IRON_M, IRON_MHI, rough=(0.22, 0.36), metal=0.3)
M_GOLD = kit.mat_metal("Gold", GOLD_LO, GOLD, GOLD_HI)
M_STONE = qkit.mat_sandstone("Footing", STONE, STONE_HI, STONE_CREAM, STONE_SEAM, strata=0.7, lines=0.6)
M_CANVAS = kit.mat_carpet("Canvas", CANVAS, CANVAS_HI, srgb("#9A845A"))

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
BASE, TOP = 3.7, 3.0  # leg feet / tops at (±BASE, ±BASE) / (±TOP, ±TOP)
FOOT_H, LEG_TOP, LEG = 0.8, 12.4, 1.0
GIRTS = (4.4, 8.4, 12.1)
DECK_Z0, DECK_T = 12.4, 0.45
TANK_Z0 = DECK_Z0 + DECK_T
TANK_H, TANK_R0, TANK_R1 = 6.9, 4.05, 3.85
TANK_Z1 = TANK_Z0 + TANK_H
ROOF_H, ROOF_R = 2.05, 4.45


def leg_at(sx, sy, z):
    t = (z - FOOT_H) / (LEG_TOP - FOOT_H)
    r = BASE + (TOP - BASE) * t
    return Vector((sx * r, sy * r, z))


def tank_r(z):
    return TANK_R0 + (TANK_R1 - TANK_R0) * (z - TANK_Z0) / TANK_H


# ── Legs, footings, girts, braces ────────────────────────────────────────────────────────────────────────────────
for sx in (-1, 1):
    for sy in (-1, 1):
        qkit.beam(f"Leg{sx}{sy}", leg_at(sx, sy, FOOT_H - 0.1), leg_at(sx, sy, LEG_TOP), LEG, LEG, timber, "Timber", bev=0.09, segs=2, up=(sx, sy, 0))
        f = leg_at(sx, sy, 0)
        kit.box(f"Footing{sx}{sy}", (1.6, 1.6, FOOT_H), (f.x, f.y, FOOT_H / 2), M_STONE, "Trim", bev=0.14, segs=2)
        kit.box(f"FootPlate{sx}{sy}", (1.2, 1.2, 0.12), (f.x, f.y, FOOT_H + 0.06), M_IRON, "Trim", bev=0.03, segs=1)
SIDES = [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]
for gi, z in enumerate(GIRTS):
    for si, (p, q) in enumerate(SIDES):
        n = Vector((p[0] + q[0], p[1] + q[1], 0)).normalized() * 0.5
        qkit.beam(f"Girt{gi}{si}", leg_at(*p, z) + n, leg_at(*q, z) + n, 0.55, 0.6, timber, "Timber", bev=0.06, segs=1, ext=0.35)
for gi in range(len(GIRTS) - 1):
    z0, z1 = GIRTS[gi] + 0.3, GIRTS[gi + 1] - 0.3
    for si, (p, q) in enumerate(SIDES):
        n = Vector((p[0] + q[0], p[1] + q[1], 0)).normalized()
        for k, (u, v) in enumerate(((p, q), (q, p))):
            off = n * (0.32 + 0.15 * k)
            qkit.beam(f"Brace{gi}{si}{k}", leg_at(*u, z0) + off, leg_at(*v, z1) + off, 0.42, 0.34, timber, "Timber", bev=0.05, segs=1, up=tuple(n))
        mid = (leg_at(*p, (z0 + z1) / 2) + leg_at(*q, (z0 + z1) / 2)) / 2 + n * 0.72
        kit.rivet(f"CrossBolt{gi}{si}", tuple(mid), tuple(n), M_BRIGHT, "Trim", r=0.13, segs=6)

# ── The deck ─────────────────────────────────────────────────────────────────────────────────────────────────────
for s in (-1, 1):
    kit.box(f"DeckBeam{s}", (9.0, 0.7, 0.55), (0, s * 2.9, DECK_Z0 - 0.15), timber((1, 0, 0)), "Timber", bev=0.07, segs=1)
for i in range(8):
    y = -3.85 + i * 1.1
    kit.box(f"DeckPlank{i}", (9.4 + rng.uniform(-0.15, 0.15), 1.04, DECK_T), (rng.uniform(-0.08, 0.08), y, DECK_Z0 + DECK_T / 2), deck((1, 0, 0)), "Timber", bev=0.06, segs=1)

# ── The ladder up the front-left leg's face (between the front legs) ─────────────────────────────────────────────
LAD_X = -1.2
for e in (-1, 1):
    a = Vector((LAD_X + e * 0.55, -BASE - 0.55, 0.0))
    b = Vector((LAD_X + e * 0.55, -TOP - 0.7, DECK_Z0 + 1.2))
    qkit.beam(f"LadderRail{e}", a, b, 0.2, 0.26, timber, "Timber", bev=0.04, segs=1, up=(0, -1, 0))
for k in range(12):
    t = (k + 0.6) / 12.6
    p = Vector((LAD_X, -BASE - 0.55 + (BASE - TOP - 0.15) * t, (DECK_Z0 + 1.2) * t))
    kit.cylinder(f"Rung{k}", 0.07, 1.1, tuple(p), M_BRIGHT, "Trim", axis="X", segs=6, bev=0.0)

# ── The tank ─────────────────────────────────────────────────────────────────────────────────────────────────────
prof = [(0.0, TANK_Z0), (TANK_R0 - 0.15, TANK_Z0), (TANK_R0 + 0.02, TANK_Z0 + 0.12)]
for i in range(1, 8):
    z = TANK_Z0 + TANK_H * i / 8
    prof.append((tank_r(z), z))
prof += [(TANK_R1 + 0.04, TANK_Z1 - 0.05), (TANK_R1 - 0.1, TANK_Z1), (0.0, TANK_Z1)]
kit.lathe("Tank", prof, M_TANK, "Tank", segs=64)
for k, z in enumerate((TANK_Z0 + 0.9, TANK_Z0 + TANK_H * 0.5, TANK_Z1 - 0.9)):
    r = tank_r(z)
    kit.torus(f"Hoop{k}", r + 0.03, 0.1, (0, 0, z), M_IRON, "Trim", major=44, minor=5, scale=(1, 1, 1.8))
    for j in range(6):
        a = math.radians(30 * (k % 2) + 60 * j - 90)
        n = Vector((math.cos(a), math.sin(a), 0))
        kit.rivet(f"HoopRivet{k}{j}", tuple(n * (r + 0.13) + Vector((0, 0, z))), tuple(n), M_GOLD, "Trim", r=0.09, segs=6)

# ── The roof and finial ──────────────────────────────────────────────────────────────────────────────────────────
RZ = TANK_Z1 - 0.15
roof = [(0.0, RZ), (ROOF_R - 0.1, RZ), (ROOF_R, RZ + 0.1), (ROOF_R - 0.05, RZ + 0.28)]
for i in range(1, 6):
    t = i / 6
    roof.append(((ROOF_R - 0.05) * (1 - t) + 0.35 * t, RZ + 0.28 + (ROOF_H - 0.28) * (t ** 0.92)))
roof += [(0.32, RZ + ROOF_H + 0.04), (0.0, RZ + ROOF_H + 0.05)]
kit.lathe("Roof", roof, M_ROOF, "Roof", segs=56)
kit.cylinder("FinialFoot", 0.32, 0.3, (0, 0, RZ + ROOF_H + 0.12), M_GOLD, "Roof", segs=14, bev=0.05, bev_segs=1)
kit.sphere("Finial", 0.42, (0, 0, RZ + ROOF_H + 0.62), M_GOLD, "Roof", u=18, v=10)

# ── The spout on the right side: a pipe out of the tank, a hinged arm, a canvas sock ─────────────────────────────
SZ = TANK_Z0 + 0.9
s0 = Vector((tank_r(SZ) + 0.05, 0, SZ + 0.45))
kit.cylinder("SpoutCollar", 0.42, 0.3, tuple(s0 + Vector((0.1, 0, 0))), M_IRON, "Trim", axis="X", segs=14, bev=0.04, bev_segs=1)
s1 = s0 + Vector((1.8, 0, -0.5))
qkit.loop_tube("SpoutPipe", [tuple(s0), tuple(s0 + Vector((0.8, 0, 0.0))), tuple(s1)], 0.28, M_IRON, "Trim", bres=2, closed=False)
kit.torus("SpoutLip", 0.3, 0.06, tuple(s1), M_BRIGHT, "Trim", axis="X", major=14, minor=4)
qkit.sweep("Sock", [tuple(s1 + Vector((0.0, 0, 0))), tuple(s1 + Vector((0.25, 0, -0.6))), tuple(s1 + Vector((0.3, 0, -1.4)))], 0.26, M_CANVAS, "Trim", segs=12, n=4, cap_start=False, cap_end=True, cap_rings=3, taper=lambda t: 1.0 - 0.25 * t)
# a chain from the tank top down to the arm's tip (to swing it)
qkit.loop_tube("SpoutChain", [(tank_r(TANK_Z1 - 1) + 0.1, 0, TANK_Z1 - 1.0), tuple(s1 + Vector((0, 0, 0.3)))], 0.04, M_BRIGHT, "Trim", bres=1, closed=False)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)
print("SIZE", kit.rbx_size(lo, hi), "PIVOT", kit.blend(pivot), "LO", kit.blend(lo), "HI", kit.blend(hi), flush=True)

kit.render_setup(target=(0, 0, 11.0), floor_color="#D9AE78", world_color="#9EC4EE")
qkit.use_gpu()
if DO_RENDER:
    kit.shoot("hero", (30.0, -46.0, 22.0), lens=50, target=(0.3, 0, 11.0))
    kit.shoot("front", (0, -60.0, 11.0), lens=50, target=(0.3, 0, 11.0))
    kit.shoot("top", (9.0, -16.0, 24.0), lens=45, target=(0, 0, 17.5))

maps = kit.bake_all(parts, {"Timber": 2048, "Tank": 1024, "Roof": 1024, "Trim": 1024}) if BAKE else {}
ups = qkit.export(parts)
tank_c = Vector((0, 0, TANK_Z0 + TANK_H / 2))
kit.write_manifest(
    {
        "key": KEY,
        "gdd": "QUARRY_BRIEF Backdrop (a water tower); GDD §19; Asset Bible §4, §1",
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "fbx_units_per_stud": ups,
        "parts": maps,
        "glow": [],
        "markers": {
            "TankCentre": {"blender": kit.blend(tank_c), "roblox_from_pivot": kit.rbx(tank_c, pivot), "radius": TANK_R0},
            "DeckTop": {"height_from_pivot": round(DECK_Z0 + DECK_T - lo.z, 4)},
        },
        "front_note": "The ladder faces the front (-Y in Blender = the model's LookVector in Roblox); the spout is on "
        "the model's left in Roblox (Blender +X).",
    }
)
