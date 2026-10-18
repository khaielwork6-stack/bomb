"""FUSE VALLEY — the hero bomb, "The Tick" (Asset Bible §3).

Deterministic Blender 4.5 build: models every part of the §3.2 anatomy with real geometry (bevels, rivets, bezels,
a braided fuse on an S-bend, the sprung back clamp) and procedural PBR materials (§2.4: hammered cast iron with a
soot gradient and polished belt-line wear, brass with edge brightening and recess patina, crackle-glazed porcelain,
a 3-strand braided cord charring toward the tip, chipped painted steel), then renders the review set (§10.3):
hero shot, 8 turntable angles, the three ticking stages, a material close-up, a black silhouette and the R6 scale
view, under the Golden Fuse lighting preset (§2.5).

Run:  blender -b --python-exit-code 1 --python art/bomb/build.py -- [--samples 96] [--out art/out/Bomb.ClassicIron]
Units: 1 Blender unit = 1 stud. Blender is Z-up; the export step converts to Roblox Y-up / -Z forward.
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Euler

# ── Args ─────────────────────────────────────────────────────────────────────────────────────────────────────────
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    if name in argv:
        return argv[argv.index(name) + 1]
    return default


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.abspath(arg("--out", os.path.join(ROOT, "art", "out", "Bomb.ClassicIron")))
SAMPLES = int(arg("--samples", "96"))
os.makedirs(os.path.join(OUT, "renders"), exist_ok=True)

# ── Palette (Asset Bible §2.3) ─────────────────────────────────────────────────────────────────────────────────────


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (lin[0], lin[1], lin[2], 1.0)


IRON = srgb("#2E2C33")
BRASS = srgb("#C9973F")
PORCELAIN = srgb("#F4EFE6")
CORD = srgb("#C9A574")
CHAR = srgb("#2A1F1A")
INK2 = srgb("#241D2E")
SPARK = srgb("#FFD84A")
EMBER = srgb("#FF9442")
DETONATE = srgb("#E8322B")
LEATHER = srgb("#6B4A32")

R = 1.1  # body radius (studs)

# ── Classic Iron look: "Toy Arcade" pass (DECISIONS 2026-10-17 "Bomb": same mesh, better materials) ──────────────
# The first pass was a dusky golden-hour iron (metal 0.85, soot, grime) that read dark and muddy in the sunny Yard.
# These are every number the Classic Iron materials use. Roblox renders high metalness dark, so every baked METAL map
# stays <= METAL_CAP (as art/props/kit.py does); the shine comes from low roughness + a baked soft top light instead.
METAL_CAP = 0.35
# Iron: a deep blue-black glossy shell — cool top light, bright bevels on the weld beads, no soot.
IRON_LO = srgb("#111626")  # the underside (baked soft shading)
IRON_MID = srgb("#1A2033")  # the body colour
IRON_HI = srgb("#34405E")  # facing the sky: a cool sheen
IRON_EDGE = srgb("#8EA2CF")  # weld-bead and bevel highlights
IRON_BEAD_POINTINESS = (0.53, 0.62)  # convexity that marks the thin weld beads (the bevel mask misses smooth tubes)
IRON_NOISE = 0.05  # ± tonal variation (was ± 20 %: the grime)
IRON_AO = 0.55  # contact shading under the belt / collar
IRON_ROUGH = (0.16, 0.26)  # glossy (was 0.55-0.8)
IRON_METAL = 0.25
IRON_HAMMER_BUMP = 0.12  # hammered dimples: a whisper, for the hand-forged read (was 0.35)
IRON_FINE_BUMP = 0.02
# Brass: richer, brighter, polished gold.
BRASS_LO = srgb("#C9701A")  # facing down
BRASS_MID = srgb("#FFBC3A")  # the belt face and everything facing out or up
BRASS_HI = srgb("#FFF0B4")  # polished edges
BRASS_AO = 0.35
BRASS_ROUGH = (0.14, 0.26)
BRASS_METAL = METAL_CAP
# Porcelain socket: crisp glazed white, cracks only a hint.
PORC_BASE = srgb("#FBF8F1")
PORC_SHADE = srgb("#D9DCE6")  # cool underside
PORC_CRACK = 0.08  # crackle darkness (was 0.35)
PORC_ROUGH = 0.06
SOCKET_RIM = srgb("#3A3140")  # the socket mouth (was near-black soot)
# Fuse cord: a saturated braided cord whose strands read.
CORD_BASE = srgb("#FFAE3D")
CORD_GROOVE = srgb("#9A4A16")  # between the strands
CORD_CHAR_FROM = 0.92  # charring starts this far up the cord (UV U); was 0.86
CORD_ROUGH = 0.55
CORD_BUMP = 0.8
# Clamp: glossy ink-plum paint with bright steel chips, rich leather pad.
STEEL_PAINT = srgb("#3B2F52")
STEEL_PAINT_HI = srgb("#5E4E82")
STEEL_CHIP = srgb("#B9C0D2")
STEEL_ROUGH = 0.28
STEEL_CHIP_AT = 0.5  # edge x noise above this shows bare steel (was 0.32: chips everywhere on the thin straps)
STEEL_METAL = (0.1, METAL_CAP)  # paint, bare chips
LEATHER_BASE = srgb("#8C5A33")
LEATHER_HI = srgb("#B07A48")
LEATHER_ROUGH = 0.55

# ── Scene ────────────────────────────────────────────────────────────────────────────────────────────────────────
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0

bomb = bpy.data.collections.new("Bomb")
scene.collection.children.link(bomb)


def link(obj, coll=None):
    (coll or bomb).objects.link(obj)
    return obj


def mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    return link(obj)


def bevel(obj, width, segments=3):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(35)
    m.harden_normals = False
    return m


def shade_smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


# ── Materials (procedural PBR) ───────────────────────────────────────────────────────────────────────────────────
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (900, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (600, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m, nt, bsdf


def node(nt, kind, loc, **props):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in props.items():
        if k in n.inputs:
            n.inputs[k].default_value = v
        else:
            setattr(n, k, v)
    return n


# Shading helpers for the Toy Arcade materials (the same recipe as art/props/kit.py: a soft top light, bright bevels
# and contact AO baked into the colour, so the bomb reads under Roblox's flat midday light).
def edge_mask(nt, radius, gain):
    """1 on bevelled edges, 0 on flat faces (Bevel-node normal vs the true normal)."""
    bev = node(nt, "ShaderNodeBevel", (-1200, -900), samples=8, Radius=radius)
    geo = node(nt, "ShaderNodeNewGeometry", (-1200, -1100))
    dot = node(nt, "ShaderNodeVectorMath", (-1000, -1000), operation="DOT_PRODUCT")
    nt.links.new(bev.outputs["Normal"], dot.inputs[0])
    nt.links.new(geo.outputs["Normal"], dot.inputs[1])
    inv = node(nt, "ShaderNodeMath", (-850, -1000), operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(dot.outputs["Value"], inv.inputs[1])
    mul = node(nt, "ShaderNodeMath", (-700, -1000), operation="MULTIPLY", use_clamp=True)
    mul.inputs[1].default_value = gain
    nt.links.new(inv.outputs[0], mul.inputs[0])
    return mul.outputs[0]


def up_light(nt, lo=-1.0, hi=1.0):
    """0 facing down -> 1 facing up (world normal Z): the baked soft top light."""
    geo = node(nt, "ShaderNodeNewGeometry", (-1200, 1100))
    sep = node(nt, "ShaderNodeSeparateXYZ", (-1000, 1100))
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    r = node(nt, "ShaderNodeMapRange", (-850, 1100), **{"From Min": lo, "From Max": hi, "To Min": 0.0, "To Max": 1.0})
    nt.links.new(sep.outputs["Z"], r.inputs["Value"])
    return r.outputs["Result"]


def lerp(nt, fac, a, b, blend="MIX"):
    m = node(nt, "ShaderNodeMix", (0, 0), data_type="RGBA", blend_type=blend)
    for sock, v in ((m.inputs["Factor"], fac), (m.inputs["A"], a), (m.inputs["B"], b)):
        if isinstance(v, (int, float, tuple)):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return m.outputs["Result"]


def ao_shade(nt, col, strength, dist=0.12):
    ao = node(nt, "ShaderNodeAmbientOcclusion", (-600, 1300), samples=16, Distance=dist)
    return lerp(nt, strength, col, ao.outputs["AO"], "MULTIPLY")


def mat_iron():
    m, nt, b = new_mat("CastIron")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1400, 0))
    # hammered dimples (voronoi distance -> a gentle bump) + a whisper of tonal noise; no soot, no grime
    vor = node(nt, "ShaderNodeTexVoronoi", (-1100, -300), Scale=9.0, Randomness=0.85)
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    noise = node(nt, "ShaderNodeTexNoise", (-1100, 50), Scale=4.5, Detail=4.0, Roughness=0.5)
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    fine = node(nt, "ShaderNodeTexNoise", (-1100, 350), Scale=60.0, Detail=4.0)
    L.new(tc.outputs["Object"], fine.inputs["Vector"])
    # colour: underside -> body -> cool sky sheen on top, bright bevels, contact AO
    col = lerp(nt, up_light(nt, -1.0, 0.1), IRON_LO, IRON_MID)
    col = lerp(nt, up_light(nt, 0.0, 1.0), col, IRON_HI)
    tone = node(nt, "ShaderNodeMapRange", (-850, 50), **{"To Min": 1.0 - IRON_NOISE, "To Max": 1.0 + IRON_NOISE})
    L.new(noise.outputs["Fac"], tone.inputs["Value"])
    toned = node(nt, "ShaderNodeVectorMath", (-300, 200), operation="SCALE")
    L.new(col, toned.inputs[0])
    L.new(tone.outputs["Result"], toned.inputs["Scale"])
    geo = node(nt, "ShaderNodeNewGeometry", (-1200, 700))
    bead = node(nt, "ShaderNodeMapRange", (-1000, 700), **{"From Min": IRON_BEAD_POINTINESS[0], "From Max": IRON_BEAD_POINTINESS[1]})
    L.new(geo.outputs["Pointiness"], bead.inputs["Value"])
    edge = node(nt, "ShaderNodeMath", (-700, 700), operation="MAXIMUM")
    L.new(edge_mask(nt, 0.03, 3.0), edge.inputs[0])
    L.new(bead.outputs["Result"], edge.inputs[1])
    col = lerp(nt, edge.outputs[0], toned.outputs["Vector"], IRON_EDGE)
    col = ao_shade(nt, col, IRON_AO)
    L.new(col, b.inputs["Base Color"])
    rough = node(nt, "ShaderNodeMapRange", (-450, -100), **{"To Min": IRON_ROUGH[0], "To Max": IRON_ROUGH[1]})
    L.new(noise.outputs["Fac"], rough.inputs["Value"])
    L.new(rough.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = IRON_METAL
    bump = node(nt, "ShaderNodeBump", (300, -400), Strength=IRON_HAMMER_BUMP, Distance=0.02)
    L.new(vor.outputs["Distance"], bump.inputs["Height"])
    bump2 = node(nt, "ShaderNodeBump", (450, -400), Strength=IRON_FINE_BUMP, Distance=0.01)
    L.new(fine.outputs["Fac"], bump2.inputs["Height"])
    L.new(bump.outputs["Normal"], bump2.inputs["Normal"])
    L.new(bump2.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_brass(name="Brass", polish=0.0):
    m, nt, b = new_mat(name)
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1200, 0))
    noise = node(nt, "ShaderNodeTexNoise", (-900, 0), Scale=14.0, Detail=6.0)
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    # polished toy brass: top-lit gradient, bright bevelled edges, a little contact AO in the recesses
    col = lerp(nt, up_light(nt, -1.0, -0.05), BRASS_LO, BRASS_MID)
    col = lerp(nt, edge_mask(nt, 0.03, 3.5), col, BRASS_HI)
    col = ao_shade(nt, col, BRASS_AO, 0.06)
    L.new(col, b.inputs["Base Color"])
    lo, hi = max(0.05, BRASS_ROUGH[0] - polish), max(0.08, BRASS_ROUGH[1] - polish)
    rough = node(nt, "ShaderNodeMapRange", (-400, -150), **{"To Min": lo, "To Max": hi})
    L.new(noise.outputs["Fac"], rough.inputs["Value"])
    L.new(rough.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = BRASS_METAL
    return m


def mat_porcelain():
    m, nt, b = new_mat("Porcelain")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1000, 0))
    vor = node(nt, "ShaderNodeTexVoronoi", (-750, -200), Scale=22.0, feature="DISTANCE_TO_EDGE")
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    crack = node(nt, "ShaderNodeMapRange", (-500, -200), **{"From Min": 0.0, "From Max": 0.02, "To Min": 1.0, "To Max": 0.0})
    L.new(vor.outputs["Distance"], crack.inputs["Value"])
    col = lerp(nt, up_light(nt, -1.0, 0.4), PORC_SHADE, PORC_BASE)
    cm = node(nt, "ShaderNodeMath", (-350, 0), operation="MULTIPLY")
    cm.inputs[1].default_value = PORC_CRACK
    L.new(crack.outputs["Result"], cm.inputs[0])
    col = lerp(nt, cm.outputs[0], col, PORC_SHADE)
    col = ao_shade(nt, col, 0.4, 0.05)
    L.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = PORC_ROUGH
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Coat Tint"].default_value = (0.92, 0.95, 1.0, 1)
    bump = node(nt, "ShaderNodeBump", (300, -300), Strength=0.04, Distance=0.004)
    L.new(crack.outputs["Result"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_cord():
    m, nt, b = new_mat("BraidedCord")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1200, 0))
    # a 3-strand braid: twisted bands along the cord's length (UV U runs along the curve)
    wave = node(nt, "ShaderNodeTexWave", (-900, -200), wave_type="BANDS", bands_direction="DIAGONAL", Scale=26.0, Distortion=0.6, Detail=3.0)
    L.new(tc.outputs["UV"], wave.inputs["Vector"])
    wave2 = node(nt, "ShaderNodeTexWave", (-900, -500), wave_type="BANDS", bands_direction="DIAGONAL", Scale=26.0, Distortion=0.6)
    mapping = node(nt, "ShaderNodeMapping", (-1100, -500))
    mapping.inputs["Scale"].default_value = (1.0, -1.0, 1.0)
    L.new(tc.outputs["UV"], mapping.inputs["Vector"])
    L.new(mapping.outputs["Vector"], wave2.inputs["Vector"])
    braid = node(nt, "ShaderNodeMath", (-650, -350), operation="MAXIMUM")
    L.new(wave.outputs["Fac"], braid.inputs[0])
    L.new(wave2.outputs["Fac"], braid.inputs[1])
    # strands bright, grooves deep: a contrast curve on the braid so the weave reads at game distance
    strands = node(nt, "ShaderNodeMapRange", (-500, -350), **{"From Min": 0.35, "From Max": 0.85, "To Min": 0.0, "To Max": 1.0})
    L.new(braid.outputs[0], strands.inputs["Value"])
    # char toward the burning tip (UV U -> 1)
    sep = node(nt, "ShaderNodeSeparateXYZ", (-900, 200))
    L.new(tc.outputs["UV"], sep.inputs["Vector"])
    charf = node(nt, "ShaderNodeMapRange", (-650, 200), **{"From Min": CORD_CHAR_FROM, "From Max": 1.0, "To Min": 0.0, "To Max": 1.0})
    L.new(sep.outputs["X"], charf.inputs["Value"])
    col = lerp(nt, strands.outputs["Result"], CORD_GROOVE, CORD_BASE)
    col = lerp(nt, charf.outputs["Result"], col, CHAR)
    L.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = CORD_ROUGH
    b.inputs["Sheen Weight"].default_value = 0.3
    bump = node(nt, "ShaderNodeBump", (250, -350), Strength=CORD_BUMP, Distance=0.01)
    L.new(braid.outputs[0], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_painted_steel():
    m, nt, b = new_mat("PaintedSteel")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1100, 0))
    geo = node(nt, "ShaderNodeNewGeometry", (-1100, 300))
    noise = node(nt, "ShaderNodeTexNoise", (-900, 100), Scale=12.0, Detail=10.0, Roughness=0.7)
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    edge = node(nt, "ShaderNodeMapRange", (-900, 400), **{"From Min": 0.5, "From Max": 0.56, "To Min": 0.0, "To Max": 1.0})
    L.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    chip = node(nt, "ShaderNodeMath", (-650, 300), operation="MULTIPLY")
    L.new(edge.outputs["Result"], chip.inputs[0])
    L.new(noise.outputs["Fac"], chip.inputs[1])
    chipt = node(nt, "ShaderNodeMath", (-450, 300), operation="GREATER_THAN")
    chipt.inputs[1].default_value = STEEL_CHIP_AT
    L.new(chip.outputs[0], chipt.inputs[0])
    paint = lerp(nt, up_light(nt, -0.8, 1.0), STEEL_PAINT, STEEL_PAINT_HI)
    col = lerp(nt, chipt.outputs[0], paint, STEEL_CHIP)
    col = ao_shade(nt, col, 0.45, 0.08)
    L.new(col, b.inputs["Base Color"])
    met = node(nt, "ShaderNodeMapRange", (-200, -150), **{"To Min": STEEL_METAL[0], "To Max": STEEL_METAL[1]})
    L.new(chipt.outputs[0], met.inputs["Value"])
    L.new(met.outputs["Result"], b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = STEEL_ROUGH
    return m


def mat_leather():
    m, nt, b = new_mat("Leather")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-900, 0))
    vor = node(nt, "ShaderNodeTexVoronoi", (-650, -200), Scale=80.0)
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    col = lerp(nt, up_light(nt, -0.8, 1.0), LEATHER_BASE, LEATHER_HI)
    L.new(ao_shade(nt, col, 0.5, 0.08), b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = LEATHER_ROUGH
    bump = node(nt, "ShaderNodeBump", (250, -300), Strength=0.2, Distance=0.005)
    L.new(vor.outputs["Distance"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_glass():
    m, nt, b = new_mat("LampGlass")
    b.inputs["Base Color"].default_value = (1, 0.97, 0.9, 1)
    b.inputs["Transmission Weight"].default_value = 1.0
    b.inputs["Roughness"].default_value = 0.04
    b.inputs["IOR"].default_value = 1.46
    return m


def mat_emit(name, color, strength):
    m, nt, b = new_mat(name)
    b.inputs["Base Color"].default_value = color
    b.inputs["Emission Color"].default_value = color
    b.inputs["Emission Strength"].default_value = strength
    return m


M_IRON = mat_iron()
M_BRASS = mat_brass()
M_BRASS_RIVET = mat_brass("BrassPolished", polish=0.12)
M_PORC = mat_porcelain()
M_CORD = mat_cord()
M_STEEL = mat_painted_steel()
M_LEATHER = mat_leather()
M_GLASS = mat_glass()
M_LAMP = mat_emit("LampCore", SPARK, 6.0)
M_SEAM = mat_emit("SeamGlow", EMBER, 0.0)


def give(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


# ── Geometry ─────────────────────────────────────────────────────────────────────────────────────────────────────
def uv_sphere(name, radius, segs=64, rings=32, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    obj = mesh_obj(name, bm)
    obj.location = loc
    shade_smooth(obj)
    return obj


def cylinder(name, radius, depth, verts=64, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=radius, radius2=radius, depth=depth)
    obj = mesh_obj(name, bm)
    obj.location = loc
    obj.rotation_euler = rot
    shade_smooth(obj)
    return obj


def torus(name, major, minor, maj_segs=96, min_segs=16, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=maj_segs, minor_segments=min_segs)
    obj = bpy.context.active_object
    for c in obj.users_collection:
        c.objects.unlink(obj)
    link(obj)
    obj.name = name
    obj.location = loc
    obj.rotation_euler = rot
    shade_smooth(obj)
    return obj


# Body: a hand-forged sphere, a touch squashed (Y × 0.96 in Roblox = Z here) with low-frequency irregularity.
body = uv_sphere("Body", R, 96, 48)
body.scale = (1, 1, 0.96)
disp_tex = bpy.data.textures.new("ForgeNoise", "CLOUDS")
disp_tex.noise_scale = 0.9
disp = body.modifiers.new("Forge", "DISPLACE")
disp.texture = disp_tex
disp.strength = 0.032
disp.mid_level = 0.5
give(body, M_IRON)

# Seams: two sunk meridian weld beads (X when seen from the top) + their glow strips.
for i, a in enumerate((45, 135)):
    s = torus(f"Seam{i + 1}", R * 0.995, 0.016, 128, 8, rot=(math.radians(90), 0, math.radians(a)))
    give(s, M_IRON)
    g = torus(f"SeamGlow{i + 1}", R * 0.99, 0.022, 128, 8, rot=(math.radians(90), 0, math.radians(a)))
    give(g, M_SEAM)

# Belt: a chamfered brass band standing 0.05 proud of the equator.
belt = cylinder("Belt", R + 0.05, 0.30, 128)
inner = cylinder("BeltCut", R - 0.06, 0.4, 128)
boolm = belt.modifiers.new("Hollow", "BOOLEAN")
boolm.object = inner
boolm.operation = "DIFFERENCE"
bpy.context.view_layer.objects.active = belt
bpy.ops.object.modifier_apply(modifier="Hollow")
bpy.data.objects.remove(inner)
bevel(belt, 0.022, 3)
give(belt, M_BRASS)

# 14 domed rivets on the belt (skipping the lamp spots at front / back).
for i in range(16):
    a = i / 16 * math.tau
    if i in (0, 8):
        continue  # the lamps sit here
    r = uv_sphere(f"Rivet{i}", 0.05, 24, 12, loc=(math.cos(a) * (R + 0.05), math.sin(a) * (R + 0.05), 0))
    r.scale = (0.55, 1, 1)
    r.rotation_euler = (0, 0, a)
    give(r, M_BRASS_RIVET)

# Indicator lamps (front / back of the belt, Roblox -Z / +Z = Blender -Y / +Y): brass bezel, glass lens, glowing core.
lamp_cores = []
for side in (-1, 1):
    y = side * (R + 0.04)
    bez = torus(f"Bezel{'F' if side < 0 else 'B'}", 0.12, 0.035, 48, 12, loc=(0, y, 0), rot=(math.radians(90), 0, 0))
    give(bez, M_BRASS_RIVET)
    lens = uv_sphere(f"Lens{'F' if side < 0 else 'B'}", 0.11, 32, 16, loc=(0, y + side * 0.01, 0))
    lens.scale = (1, 0.6, 1)
    give(lens, M_GLASS)
    core = uv_sphere(f"LampCore{'F' if side < 0 else 'B'}", 0.06, 24, 12, loc=(0, y, 0))
    give(core, M_LAMP)
    lamp_cores.append(core)

# Knurled brass collar and the glazed porcelain fuse socket.
collar = cylinder("Collar", 0.31, 0.24, 64, loc=(0, 0, R * 0.96 - 0.02))
bevel(collar, 0.03, 3)
give(collar, mat_brass("BrassKnurl"))
knurl = collar.active_material.node_tree
kn = knurl.nodes
wave = kn.new("ShaderNodeTexWave")
wave.wave_type = "BANDS"
wave.bands_direction = "X"
wave.inputs["Scale"].default_value = 60.0
kb = kn.new("ShaderNodeBump")
kb.inputs["Strength"].default_value = 0.5
bsdf = next(n for n in kn if n.type == "BSDF_PRINCIPLED")
tc = kn.new("ShaderNodeTexCoord")
sepk = kn.new("ShaderNodeSeparateXYZ")
knurl.links.new(tc.outputs["Object"], sepk.inputs["Vector"])
ang = kn.new("ShaderNodeMath")
ang.operation = "ARCTAN2"
knurl.links.new(sepk.outputs["Y"], ang.inputs[0])
knurl.links.new(sepk.outputs["X"], ang.inputs[1])
comb = kn.new("ShaderNodeCombineXYZ")
knurl.links.new(ang.outputs[0], comb.inputs["X"])
knurl.links.new(comb.outputs["Vector"], wave.inputs["Vector"])
knurl.links.new(wave.outputs["Fac"], kb.inputs["Height"])
knurl.links.new(kb.outputs["Normal"], bsdf.inputs["Normal"])

socket = cylinder("Socket", 0.21, 0.2, 48, loc=(0, 0, R * 0.96 + 0.18))
bevel(socket, 0.04, 4)
give(socket, M_PORC)
rim = torus("SocketSoot", 0.2, 0.02, 48, 8, loc=(0, 0, R * 0.96 + 0.28))
give(rim, mat_emit("Soot", SOCKET_RIM, 0.0))

# The braided fuse: a bezier on a gentle S-bend, tapering 0.11 → 0.08, 1.25 studs long.
FUSE_BASE = R * 0.96 + 0.27
curve = bpy.data.curves.new("FuseCurve", "CURVE")
curve.dimensions = "3D"
curve.bevel_depth = 0.064
curve.bevel_resolution = 6
curve.use_fill_caps = True
curve.resolution_u = 24
spl = curve.splines.new("BEZIER")
pts = [(0, 0, 0), (0.08, 0.02, 0.42), (-0.06, -0.02, 0.86), (0.05, 0.03, 1.25)]
spl.bezier_points.add(len(pts) - 1)
for bp, p in zip(spl.bezier_points, pts):
    bp.co = Vector((p[0], p[1], FUSE_BASE + p[2]))
    bp.handle_left_type = bp.handle_right_type = "AUTO"
for i, bp in enumerate(spl.bezier_points):
    bp.radius = 1.0 - 0.27 * (i / (len(pts) - 1))
fuse = bpy.data.objects.new("Fuse", curve)
link(fuse)
fuse.data.materials.append(M_CORD)

# The sprung back clamp (between the bomb and the Carrier's back, Blender -Y = toward the torso): a chipped
# painted-steel claw of two straps round the bomb's back, a visible coil spring and a leather back plate with a
# brass buckle.
def strap(name, yaw_deg):
    c = bpy.data.curves.new(name + "Curve", "CURVE")
    c.dimensions = "3D"
    c.bevel_depth = 0.045
    c.bevel_resolution = 4
    sp = c.splines.new("POLY")
    steps = 40
    sp.points.add(steps)
    yaw = math.radians(yaw_deg)
    for k in range(steps + 1):
        a = math.radians(-70 + 140 * k / steps)  # an arc over the back from below to above
        rr = R + 0.07
        # vertical arc in the plane facing -Y, turned by `yaw` about Z
        x0, y0, z0 = 0.0, -math.cos(a) * rr, math.sin(a) * rr
        x = x0 * math.cos(yaw) - y0 * math.sin(yaw)
        y = x0 * math.sin(yaw) + y0 * math.cos(yaw)
        sp.points[k].co = (x, y, z0, 1)
    o = bpy.data.objects.new(name, c)
    link(o)
    o.data.materials.append(M_STEEL)
    return o


strap("ClawL", 24)
strap("ClawR", -24)
spring_curve = bpy.data.curves.new("SpringCurve", "CURVE")
spring_curve.dimensions = "3D"
spring_curve.bevel_depth = 0.026
spring_curve.bevel_resolution = 4
sp = spring_curve.splines.new("POLY")
turns, steps = 6, 180
sp.points.add(steps)
for k in range(steps + 1):
    t = k / steps
    a = t * turns * math.tau
    sp.points[k].co = (math.cos(a) * 0.13, -(R + 0.08 + t * 0.26), math.sin(a) * 0.13, 1)
spring = bpy.data.objects.new("Spring", spring_curve)
link(spring)
spring.data.materials.append(mat_brass("SpringSteel", polish=0.1))
plate = cylinder("BackPlate", 0.5, 0.1, 6, loc=(0, -(R + 0.39), 0), rot=(math.radians(90), 0, 0))
plate.scale = (0.95, 1.15, 1)
bevel(plate, 0.05, 4)
give(plate, M_LEATHER)
buckle = cylinder("Buckle", 0.09, 0.05, 32, loc=(0, -(R + 0.32), 0.38), rot=(math.radians(90), 0, 0))
give(buckle, M_BRASS_RIVET)
# Parent every bomb part to one root, so the CRITICAL swell (§3.3) grows the whole assembly together.
root = bpy.data.objects.new("BombRoot", None)
link(root)
for o in list(bomb.objects):
    if o is not root and o.parent is None:
        o.parent = root

# ── Stages (Asset Bible §3.3) ─────────────────────────────────────────────────────────────────────────────────────
def set_stage(stage):
    seam_strength = {"LIT": 0.0, "HOT": 6.0, "CRITICAL": 28.0}[stage]
    seam_col = {"LIT": EMBER, "HOT": EMBER, "CRITICAL": (1.0, 0.92, 0.7, 1)}[stage]
    lamp_col = {"LIT": SPARK, "HOT": EMBER, "CRITICAL": DETONATE}[stage]
    sb = M_SEAM.node_tree.nodes["Principled BSDF"]
    sb.inputs["Emission Strength"].default_value = seam_strength
    sb.inputs["Emission Color"].default_value = seam_col
    sb.inputs["Base Color"].default_value = seam_col if seam_strength > 0 else IRON
    lb = M_LAMP.node_tree.nodes["Principled BSDF"]
    lb.inputs["Emission Color"].default_value = lamp_col
    lb.inputs["Base Color"].default_value = lamp_col
    lb.inputs["Emission Strength"].default_value = 6.0 if stage != "CRITICAL" else 14.0
    root.scale = (1, 1, 1) if stage != "CRITICAL" else (1.08, 1.08, 1.08)


# ── Lighting: Golden Fuse (Asset Bible §2.5) ─────────────────────────────────────────────────────────────────────
world = bpy.data.worlds.new("GoldenFuse")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
sky = world.node_tree.nodes.new("ShaderNodeTexSky")
sky.sky_type = "NISHITA" if "NISHITA" in [i.identifier for i in sky.bl_rna.properties["sky_type"].enum_items] else "MULTIPLE_SCATTERING"
sky.sun_elevation = math.radians(14)
sky.sun_rotation = math.radians(-35)
sky.air_density = 1.4
setattr(sky, "dust_density" if hasattr(sky, "dust_density") else "aerosol_density", 2.2)  # renamed in Blender 5
world.node_tree.links.new(sky.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.12
scene.world = world


def area(name, loc, rot, size, color, power):
    l = bpy.data.lights.new(name, "AREA")
    l.size = size
    l.color = color[:3]
    l.energy = power
    o = bpy.data.objects.new(name, l)
    o.location = loc
    o.rotation_euler = rot
    scene.collection.objects.link(o)
    return o


key = area("Key", (3.6, 3.8, 3.2), (math.radians(-52), 0, math.radians(137)), 3.0, srgb("#FFC58A"), 900)
fill = area("Fill", (-4.2, 2.6, 1.4), (math.radians(-72), 0, math.radians(-122)), 4.0, srgb("#8FA2D6"), 260)
rim = area("Rim", (-1.4, -3.8, 3.0), (math.radians(52), 0, math.radians(-20)), 1.8, srgb("#FFE2B8"), 1100)

# The fuse spark for hero shots (the in-game spark is a particle effect, §5.2).
spark_l = bpy.data.lights.new("Spark", "POINT")
spark_l.energy = 40
spark_l.color = srgb("#FFB347")[:3]
spark_l.shadow_soft_size = 0.02
spark = bpy.data.objects.new("SparkLight", spark_l)
spark.location = (0.05, 0.03, FUSE_BASE + 1.3)
scene.collection.objects.link(spark)
spark_core = uv_sphere("SparkCore", 0.05, 16, 8, loc=spark.location)
give(spark_core, mat_emit("SparkCore", (1, 0.9, 0.55, 1), 140))

# A curved cyclorama (floor sweeping up into a back wall) instead of a flat ground: no horizon edge in any shot.
bm = bmesh.new()
profile = []
for k in range(0, 13):
    profile.append((-9 + k * 1.0, 0.0))  # floor
for k in range(1, 13):
    a = k / 12 * math.pi / 2
    profile.append((3 + math.sin(a) * 4, 4 - math.cos(a) * 4))  # the sweep
for k in range(1, 8):
    profile.append((7.0, 4 + k * 1.5))  # back wall
rows = []
for xs in (-12, 12):
    rows.append([bm.verts.new((xs, y, z)) for (y, z) in profile])
for i in range(len(profile) - 1):
    bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
ground = mesh_obj("Cyclorama", bm)
shade_smooth(ground)
ground.location = (0, 0, -R - 0.02)
ground.rotation_euler = (0, 0, math.radians(148))
gm, gnt, gb = new_mat("Cyclorama")
gtc = node(gnt, "ShaderNodeTexCoord", (-700, 0))
gsep = node(gnt, "ShaderNodeSeparateXYZ", (-500, 0))
gnt.links.new(gtc.outputs["Object"], gsep.inputs["Vector"])
gr = node(gnt, "ShaderNodeValToRGB", (-250, 0))
gr.color_ramp.elements[0].position = 0.0
gr.color_ramp.elements[0].color = srgb("#2B2524")
gr.color_ramp.elements[1].position = 1.0
gr.color_ramp.elements[1].color = srgb("#1E2340")
gmr = node(gnt, "ShaderNodeMapRange", (-380, 0), **{"From Min": 0.3, "From Max": 4.0})
gnt.links.new(gsep.outputs["Z"], gmr.inputs["Value"])
gnt.links.new(gmr.outputs["Result"], gr.inputs["Fac"])
gnt.links.new(gr.outputs["Color"], gb.inputs["Base Color"])
gb.inputs["Roughness"].default_value = 0.85
give(ground, gm)
bomb.objects.unlink(ground)
scene.collection.objects.link(ground)
# ── Render setup ─────────────────────────────────────────────────────────────────────────────────────────────────
scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
prefs = bpy.context.preferences.addons["cycles"].preferences
for backend in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = backend
        prefs.get_devices()
        if any(d.type == backend for d in prefs.devices):
            for d in prefs.devices:
                d.use = d.type == backend
            scene.cycles.device = "GPU"
            break
    except Exception:
        continue
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = 0.35
if hasattr(scene, "node_tree"):  # Blender 4.x: the scene's own compositor tree
    scene.use_nodes = True
    ctree = scene.node_tree
    for n in list(ctree.nodes):
        ctree.nodes.remove(n)
else:  # Blender 5.x: a compositor node group with a group output
    ctree = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    ctree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    scene.compositing_node_group = ctree


def glare_node(kind):
    g = ctree.nodes.new("CompositorNodeGlare")
    if "Type" in g.inputs:
        g.inputs["Type"].default_value = {"STREAKS": "Streaks", "FOG_GLOW": "Fog Glow"}[kind]
    else:
        g.glare_type = kind
    return g


rl = ctree.nodes.new("CompositorNodeRLayers")
glare = glare_node("STREAKS")
glare.inputs["Threshold"].default_value = 2.2
glare.inputs["Strength"].default_value = 0.6
glare.inputs["Streaks"].default_value = 6
glare.inputs["Streaks Angle"].default_value = math.radians(15)
glare.inputs["Fade"].default_value = 0.86
glow = glare_node("FOG_GLOW")
glow.inputs["Threshold"].default_value = 1.6
glow.inputs["Strength"].default_value = 0.35
glow.inputs["Size"].default_value = 0.4
comp = ctree.nodes.new("CompositorNodeComposite" if hasattr(bpy.types, "CompositorNodeComposite") else "NodeGroupOutput")
ctree.links.new(rl.outputs["Image"], glare.inputs["Image"])
ctree.links.new(glare.outputs["Image"], glow.inputs["Image"])
ctree.links.new(glow.outputs["Image"], comp.inputs[0])
scene.render.film_transparent = False

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 70
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
target = Vector((0, 0, 0.72))  # the middle of bomb + fuse + spark


def aim(loc, look=target, lens=70):
    cam.location = Vector(loc)
    d = look - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens


def render(name, res=1024, w=None):
    scene.render.resolution_x = w or res
    scene.render.resolution_y = res
    scene.render.filepath = os.path.join(OUT, "renders", name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name, flush=True)


def orbit(angle_deg, dist=10.0, height=2.6):
    a = math.radians(angle_deg)
    ground.rotation_euler = (0, 0, a)  # the backdrop always sits behind the bomb
    return (math.sin(a) * dist, -math.cos(a) * dist, height)


NO_RENDER = "--no-render" in argv  # art/bomb/export.py builds the model without the review renders
if not NO_RENDER:
    # Hero (3/4 front, LIT) and the three stages.
    set_stage("LIT")
    aim(orbit(148, 9.4, 2.7))
    render("hero", 1400, 1400)
    for st in ("LIT", "HOT", "CRITICAL"):
        set_stage(st)
        aim(orbit(148, 9.4, 2.7))
        render(f"stage_{st}", 640)
    set_stage("LIT")
    # 8 turntable angles
    for i in range(8):
        aim(orbit(i * 45, 10.0, 2.2))
        render(f"turn_{i * 45:03d}", 512)
    # Material close-up: belt, rivet, lamp, hammered iron
    ground.rotation_euler = (0, 0, math.radians(199))
    aim((-0.9, 2.6, 0.45), Vector((-0.15, 1.05, 0.05)), 85)
    render("detail", 900)
    # Silhouette: everything black on white
    for o in bomb.objects:
        if o.type in ("MESH", "CURVE"):
            o.hide_render = False
    sil = bpy.data.materials.new("Silhouette")
    sil.use_nodes = True
    sil.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    sil.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
    saved = {}
    for o in bomb.objects:
        if o.type in ("MESH", "CURVE") and o.data.materials:
            saved[o.name] = list(o.data.materials)
            o.data.materials.clear()
            o.data.materials.append(sil)
    ground.hide_render = True
    spark_core.hide_render = True
    for lk in list(world.node_tree.links):
        if lk.to_node == bg:
            world.node_tree.links.remove(lk)
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 1.0
    for l in (key, fill, rim, spark):
        l.hide_render = True
    aim(orbit(-90, 10.5, 0.7))
    render("silhouette", 512)
    for o in bomb.objects:
        if o.name in saved:
            o.data.materials.clear()
            for m in saved[o.name]:
                o.data.materials.append(m)
    ground.hide_render = False
    spark_core.hide_render = False
    world.node_tree.links.new(sky.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.12
    for l in (key, fill, rim, spark):
        l.hide_render = False

    # R6 scale view: a 5-stud R6 figure (blocks) wearing the bomb on its back (§3.2 mount).
    r6 = bpy.data.collections.new("R6")
    scene.collection.children.link(r6)
    skin = mat_emit("R6", srgb("#B9B4AC"), 0.0)
    skin.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7


    def block(name, size, loc):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        o = mesh_obj(name, bm)
        bomb.objects.unlink(o)
        r6.objects.link(o)
        o.scale = size
        o.location = loc
        give(o, skin)
        return o


    feet = -R - 0.02
    # torso centre at 3 studs up; the bomb sits behind it (+Y) per the mount
    torso_c = Vector((0, -(1.0 / 2 + 0.4 + R), 0.15))
    block("Torso", (2, 1, 2), (torso_c.x, torso_c.y, torso_c.z))
    block("Head", (1.2, 1.2, 1.2), (torso_c.x, torso_c.y, torso_c.z + 1.6))
    block("ArmL", (1, 1, 2), (torso_c.x - 1.5, torso_c.y, torso_c.z))
    block("ArmR", (1, 1, 2), (torso_c.x + 1.5, torso_c.y, torso_c.z))
    block("LegL", (1, 1, 2), (torso_c.x - 0.5, torso_c.y, torso_c.z - 2))
    block("LegR", (1, 1, 2), (torso_c.x + 0.5, torso_c.y, torso_c.z - 2))
    ground.location.z = torso_c.z - 3.0
    ground.rotation_euler = (0, 0, math.radians(113))
    aim((7.5, 3.2, 1.6), Vector((0, -1.3, 0.2)), 50)
    render("scale_r6", 900)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Bomb.ClassicIron.blend"))
    print("DONE", OUT, flush=True)
