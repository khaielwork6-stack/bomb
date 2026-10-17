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


def mat_iron():
    m, nt, b = new_mat("CastIron")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1400, 0))
    # hammered dimples: voronoi distance → bump
    vor = node(nt, "ShaderNodeTexVoronoi", (-1100, -300), Scale=9.0, Randomness=0.85)
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    noise = node(nt, "ShaderNodeTexNoise", (-1100, 50), Scale=4.5, Detail=8.0, Roughness=0.62)
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    fine = node(nt, "ShaderNodeTexNoise", (-1100, 350), Scale=60.0, Detail=4.0)
    L.new(tc.outputs["Object"], fine.inputs["Vector"])
    # soot gradient toward the top (object Z), polished wear on the belt line (|Z| small)
    sep = node(nt, "ShaderNodeSeparateXYZ", (-1100, 650))
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    soot = node(nt, "ShaderNodeMapRange", (-850, 650), **{"From Min": 0.2, "From Max": 1.05, "To Min": 0.0, "To Max": 1.0})
    L.new(sep.outputs["Z"], soot.inputs["Value"])
    absz = node(nt, "ShaderNodeMath", (-850, 850), operation="ABSOLUTE")
    L.new(sep.outputs["Z"], absz.inputs[0])
    wear = node(nt, "ShaderNodeMapRange", (-650, 850), **{"From Min": 0.32, "From Max": 0.12, "To Min": 0.0, "To Max": 1.0})
    L.new(absz.outputs[0], wear.inputs["Value"])
    # base colour: iron ±6 % hue/value noise, darker soot on top, lighter polished wear
    ramp = node(nt, "ShaderNodeValToRGB", (-850, 50))
    ramp.color_ramp.elements[0].color = (IRON[0] * 0.78, IRON[1] * 0.78, IRON[2] * 0.82, 1)
    ramp.color_ramp.elements[1].color = (IRON[0] * 1.18, IRON[1] * 1.14, IRON[2] * 1.12, 1)
    L.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    sootmix = node(nt, "ShaderNodeMix", (-450, 200), data_type="RGBA", blend_type="MULTIPLY")
    sootmix.inputs["B"].default_value = (0.35, 0.33, 0.32, 1)
    L.new(soot.outputs["Result"], sootmix.inputs["Factor"])
    L.new(ramp.outputs["Color"], sootmix.inputs["A"])
    wearmix = node(nt, "ShaderNodeMix", (-200, 200), data_type="RGBA", blend_type="MIX")
    wearmix.inputs["B"].default_value = (0.42, 0.41, 0.43, 1)
    wf = node(nt, "ShaderNodeMath", (-450, 900), operation="MULTIPLY")
    L.new(wear.outputs["Result"], wf.inputs[0])
    L.new(fine.outputs["Fac"], wf.inputs[1])
    L.new(wf.outputs[0], wearmix.inputs["Factor"])
    L.new(sootmix.outputs["Result"], wearmix.inputs["A"])
    L.new(wearmix.outputs["Result"], b.inputs["Base Color"])
    # roughness 0.55–0.8 (rougher soot, smoother wear)
    rough = node(nt, "ShaderNodeMapRange", (-450, -100), **{"To Min": 0.55, "To Max": 0.8})
    L.new(noise.outputs["Fac"], rough.inputs["Value"])
    r2 = node(nt, "ShaderNodeMath", (-200, -100), operation="SUBTRACT")
    L.new(rough.outputs["Result"], r2.inputs[0])
    r2m = node(nt, "ShaderNodeMath", (-450, -250), operation="MULTIPLY")
    r2m.inputs[1].default_value = 0.3
    L.new(wear.outputs["Result"], r2m.inputs[0])
    L.new(r2m.outputs[0], r2.inputs[1])
    L.new(r2.outputs[0], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.85
    bump = node(nt, "ShaderNodeBump", (300, -400), Strength=0.35, Distance=0.02)
    L.new(vor.outputs["Distance"], bump.inputs["Height"])
    bump2 = node(nt, "ShaderNodeBump", (450, -400), Strength=0.08, Distance=0.01)
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
    geo = node(nt, "ShaderNodeNewGeometry", (-900, 300))
    edge = node(nt, "ShaderNodeMapRange", (-650, 300), **{"From Min": 0.5, "From Max": 0.6, "To Min": 0.0, "To Max": 1.0})
    L.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    ao = node(nt, "ShaderNodeAmbientOcclusion", (-900, 600), Distance=0.08)
    col = node(nt, "ShaderNodeMix", (-400, 200), data_type="RGBA", blend_type="MIX")
    col.inputs["A"].default_value = BRASS
    col.inputs["B"].default_value = (1.0, 0.86, 0.55, 1)  # brightened edges
    L.new(edge.outputs["Result"], col.inputs["Factor"])
    patina = node(nt, "ShaderNodeMix", (-150, 200), data_type="RGBA", blend_type="MULTIPLY")
    patina.inputs["B"].default_value = (0.42, 0.33, 0.18, 1)
    inv = node(nt, "ShaderNodeMath", (-650, 600), operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    L.new(ao.outputs["AO"], inv.inputs[1])
    L.new(inv.outputs[0], patina.inputs["Factor"])
    L.new(col.outputs["Result"], patina.inputs["A"])
    L.new(patina.outputs["Result"], b.inputs["Base Color"])
    rough = node(nt, "ShaderNodeMapRange", (-400, -150), **{"To Min": 0.25 - polish, "To Max": 0.45 - polish})
    L.new(noise.outputs["Fac"], rough.inputs["Value"])
    L.new(rough.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 1.0
    return m


def mat_porcelain():
    m, nt, b = new_mat("Porcelain")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-1000, 0))
    vor = node(nt, "ShaderNodeTexVoronoi", (-750, -200), Scale=22.0, feature="DISTANCE_TO_EDGE")
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    crack = node(nt, "ShaderNodeMapRange", (-500, -200), **{"From Min": 0.0, "From Max": 0.03, "To Min": 1.0, "To Max": 0.0})
    L.new(vor.outputs["Distance"], crack.inputs["Value"])
    col = node(nt, "ShaderNodeMix", (-200, 100), data_type="RGBA", blend_type="MIX")
    col.inputs["A"].default_value = PORCELAIN
    col.inputs["B"].default_value = (0.62, 0.6, 0.58, 1)
    cm = node(nt, "ShaderNodeMath", (-350, 0), operation="MULTIPLY")
    cm.inputs[1].default_value = 0.35
    L.new(crack.outputs["Result"], cm.inputs[0])
    L.new(cm.outputs[0], col.inputs["Factor"])
    L.new(col.outputs["Result"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.1
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Coat Tint"].default_value = (0.92, 0.95, 1.0, 1)
    bump = node(nt, "ShaderNodeBump", (300, -300), Strength=0.15, Distance=0.004)
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
    # char toward the burning tip (UV U → 1)
    sep = node(nt, "ShaderNodeSeparateXYZ", (-900, 200))
    L.new(tc.outputs["UV"], sep.inputs["Vector"])
    charf = node(nt, "ShaderNodeMapRange", (-650, 200), **{"From Min": 0.86, "From Max": 1.0, "To Min": 0.0, "To Max": 1.0})
    L.new(sep.outputs["X"], charf.inputs["Value"])
    shade = node(nt, "ShaderNodeMix", (-400, 0), data_type="RGBA", blend_type="MULTIPLY")
    shade.inputs["A"].default_value = CORD
    shade.inputs["B"].default_value = (0.62, 0.52, 0.4, 1)
    inv = node(nt, "ShaderNodeMath", (-500, -200), operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    L.new(braid.outputs[0], inv.inputs[1])
    L.new(inv.outputs[0], shade.inputs["Factor"])
    col = node(nt, "ShaderNodeMix", (-150, 0), data_type="RGBA", blend_type="MIX")
    col.inputs["B"].default_value = CHAR
    L.new(charf.outputs["Result"], col.inputs["Factor"])
    L.new(shade.outputs["Result"], col.inputs["A"])
    L.new(col.outputs["Result"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    b.inputs["Sheen Weight"].default_value = 0.3
    bump = node(nt, "ShaderNodeBump", (250, -350), Strength=0.6, Distance=0.01)
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
    chipt.inputs[1].default_value = 0.32
    L.new(chip.outputs[0], chipt.inputs[0])
    col = node(nt, "ShaderNodeMix", (-200, 100), data_type="RGBA", blend_type="MIX")
    col.inputs["A"].default_value = INK2
    col.inputs["B"].default_value = (0.5, 0.5, 0.52, 1)
    L.new(chipt.outputs[0], col.inputs["Factor"])
    L.new(col.outputs["Result"], b.inputs["Base Color"])
    met = node(nt, "ShaderNodeMapRange", (-200, -150), **{"To Min": 0.25, "To Max": 1.0})
    L.new(chipt.outputs[0], met.inputs["Value"])
    L.new(met.outputs["Result"], b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = 0.45
    return m


def mat_leather():
    m, nt, b = new_mat("Leather")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-900, 0))
    vor = node(nt, "ShaderNodeTexVoronoi", (-650, -200), Scale=80.0)
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    b.inputs["Base Color"].default_value = LEATHER
    b.inputs["Roughness"].default_value = 0.78
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
give(rim, mat_emit("Soot", (0.02, 0.018, 0.016, 1), 0.0))

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
sky.sky_type = "NISHITA"
sky.sun_elevation = math.radians(14)
sky.sun_rotation = math.radians(-35)
sky.air_density = 1.4
sky.dust_density = 2.2
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
scene.use_nodes = True
ctree = scene.node_tree
for n in list(ctree.nodes):
    ctree.nodes.remove(n)
rl = ctree.nodes.new("CompositorNodeRLayers")
glare = ctree.nodes.new("CompositorNodeGlare")
glare.glare_type = "STREAKS"
glare.inputs["Threshold"].default_value = 2.2
glare.inputs["Strength"].default_value = 0.6
glare.inputs["Streaks"].default_value = 6
glare.inputs["Streaks Angle"].default_value = math.radians(15)
glare.inputs["Fade"].default_value = 0.86
glow = ctree.nodes.new("CompositorNodeGlare")
glow.glare_type = "FOG_GLOW"
glow.inputs["Threshold"].default_value = 1.6
glow.inputs["Strength"].default_value = 0.35
glow.inputs["Size"].default_value = 0.4comp = ctree.nodes.new("CompositorNodeComposite")
ctree.links.new(rl.outputs["Image"], glare.inputs["Image"])
ctree.links.new(glare.outputs["Image"], glow.inputs["Image"])
ctree.links.new(glow.outputs["Image"], comp.inputs["Image"])
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
