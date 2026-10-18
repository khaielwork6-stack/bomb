"""FUSE VALLEY — the game logo (Asset Bible §7.1 loading screen, store icon / thumbnails), rendered in headless Blender
in the reference video's logo style: two stacked words in huge chunky 3D letters (Luckiest Guy, the game's display
face), glossy gradient faces (FUSE: yellow → orange → red; VALLEY: sky blue → deep blue), a deep dark extruded side, a
thick navy outline (a fattened copy of each glyph behind it), each letter bounced a little, and the hero bomb
(art/out/Bomb.ClassicIron) on top with a cartoon face, its fuse lit with a star spark and confetti bursting round it.
No AI art: everything is geometry built here.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/logo/build.py -- --font <LuckiestGuy-Regular.ttf>
Out:  art/out/Logo/logo.png (2048 x 1280, transparent)
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "art", "icons"))
import lib  # noqa: E402  (the icon framework: glossy(), the camera-only outline hull, studio lights)

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
FONT = argv[argv.index("--font") + 1] if "--font" in argv else ""
OUT = os.path.join(ROOT, "art", "out", "Logo")
os.makedirs(OUT, exist_ok=True)
rng = random.Random(11)

lib.reset()
sc = bpy.context.scene
sc.cycles.samples = 128
srgb = lib.srgb


def gradient_mat(name, top, mid, bottom):
    """A glossy face material with a vertical gradient (the glyph's local Y, bottom → top)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.08
    ramp.color_ramp.elements[0].color = bottom
    ramp.color_ramp.elements[1].position = 0.92
    ramp.color_ramp.elements[1].color = top
    e = ramp.color_ramp.elements.new(0.5)
    e.color = mid
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.2
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Coat Roughness"].default_value = 0.05
    return m


def flat(name, color, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = 0.6
    if emit:
        b.inputs["Emission Color"].default_value = color
        b.inputs["Emission Strength"].default_value = emit
    return m


FUSE_FACE = gradient_mat("FuseFace", srgb("#FFF07A"), srgb("#FFB21E"), srgb("#EE3A1C"))
VALLEY_FACE = gradient_mat("ValleyFace", srgb("#A8ECFF"), srgb("#36A2FF"), srgb("#1B4AD2"))
FUSE_SIDE = lib.glossy("FuseSide", srgb("#9E2016"), 0.45, coat=0.2)
VALLEY_SIDE = lib.glossy("ValleySide", srgb("#142C78"), 0.45, coat=0.2)
NAVY = flat("Navy", srgb("#14143A"))
FONT_DATA = bpy.data.fonts.load(FONT) if FONT else None


def glyph(ch, size, offset, extrude, bevel):
    cu = bpy.data.curves.new("G_" + ch, "FONT")
    cu.body = ch
    if FONT_DATA:
        cu.font = FONT_DATA
    cu.size = size
    cu.offset = offset
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 4
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = bpy.data.objects.new("G_" + ch, cu)
    sc.collection.objects.link(o)
    return o


def to_mesh(o):
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def word(text, size, z, face, side, spacing=0.8, bounce=0.06, tilt=6.0):
    letters = [glyph(ch, size, 0, size * 0.17, size * 0.035) for ch in text]
    bpy.context.view_layer.update()
    widths = [max(o.dimensions.x, size * 0.3) for o in letters]
    total = sum(widths) * spacing
    x = -total / 2
    for o, w, ch in zip(letters, widths, text):
        cx = x + w * spacing / 2
        x += w * spacing
        rot = (math.radians(90), math.radians(rng.uniform(-tilt, tilt)), 0)
        loc = Vector((cx, 0, z + rng.uniform(-bounce, bounce) * size))
        stretch = 1 + rng.uniform(-0.03, 0.06)
        # the letter (faces in its gradient, extruded walls in the dark side colour)
        o.rotation_euler = rot
        o.location = loc
        o.scale = (1, stretch, 1)
        m = to_mesh(o)
        m.data.materials.clear()
        m.data.materials.append(face)
        m.data.materials.append(side)
        for p in m.data.polygons:
            p.material_index = 0 if p.normal.z > 0.55 else 1
            p.use_smooth = True
        # the outline: the same glyph fattened (curve offset) in navy, deeper, sitting just behind
        ol = glyph(ch, size, size * 0.075, size * 0.2, size * 0.02)
        ol.rotation_euler = rot
        ol.location = loc + Vector((0, size * 0.06, 0))
        ol.scale = (1, stretch, 1)
        om = to_mesh(ol)
        om.data.materials.clear()
        om.data.materials.append(NAVY)


word("FUSE", 3.8, 1.25, FUSE_FACE, FUSE_SIDE)
word("VALLEY", 3.1, -1.55, VALLEY_FACE, VALLEY_SIDE, bounce=0.05)

# ── the bomb on top ────────────────────────────────────────────────────────────────────────────────────────────────
glb = os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "export", "Bomb.ClassicIron.glb")
before = set(sc.objects)
bpy.ops.import_scene.gltf(filepath=glb)
bomb = [o for o in sc.objects if o not in before and o.type == "MESH"]
for o in bomb:
    o.parent = None
bpy.context.view_layer.update()
# turn it to face the camera (-Y), scale it up and sit it on the top edge of FUSE, a little right of centre
S = 1.25
place = Matrix.Translation(Vector((0.6, 0.4, 4.25))) @ Matrix.Rotation(math.radians(180 + 12), 4, "Z") @ Matrix.Scale(S, 4)
for o in bomb:
    o.matrix_world = place @ o.matrix_world
    for mat in o.data.materials:
        if mat and mat.node_tree:
            b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if b:
                b.inputs["Metallic"].default_value = min(0.3, b.inputs["Metallic"].default_value)
    if len(o.data.materials) > 0 and o.data.materials[0] and o.data.materials[0].node_tree:
        if o.data.materials[0].node_tree.nodes.get("Principled BSDF"):
            o["outline"] = 0.06
bpy.context.view_layer.update()
body = next((o for o in bomb if o.name.startswith("Body")), bomb[0])
bpts = [body.matrix_world @ Vector(c) for c in body.bound_box]
bc = sum(bpts, Vector()) / len(bpts)
brad = (max(p.x for p in bpts) - min(p.x for p in bpts)) / 2

# a cartoon face on the bomb's front (-Y): big eyes with glints and a grin
white = lib.glossy("EyeWhite", srgb("#FFFFFF"), 0.2, coat=0.5)
pupil = lib.glossy("Pupil", srgb("#14121E"), 0.15, coat=0.8)
front_y = bc.y - brad * 0.97
for side in (-1, 1):
    ex = bc.x + side * brad * 0.32
    e = lib.sphere("Eye", brad * 0.27, white, loc=(ex, front_y, bc.z + brad * 0.18), scale=(1, 0.45, 1.25))
    e["outline"] = 0.04
    lib.sphere("Pupil", brad * 0.14, pupil, loc=(ex + brad * 0.04, front_y - brad * 0.1, bc.z + brad * 0.14), scale=(1, 0.45, 1.2), outline=0)
    lib.sphere("Glint", brad * 0.05, white, loc=(ex - brad * 0.01, front_y - brad * 0.16, bc.z + brad * 0.24), outline=0)
grin = [Vector((bc.x + brad * x, front_y - brad * 0.02, bc.z - brad * (0.24 + 0.16 * (1 - (x / 0.36) ** 2)))) for x in (-0.36, -0.18, 0.0, 0.18, 0.36)]
lib.tube("Grin", grin, brad * 0.06, pupil, outline=0)

# the spark at the fuse tip, plus sparks and confetti bursting round the bomb (never over the letters)
fuse_tip = max((o for o in bomb if o.name.startswith("Fuse")), key=lambda o: (o.matrix_world @ Vector(o.bound_box[6])).z, default=body)
tip = Vector(max(((fuse_tip.matrix_world @ Vector(c)) for c in fuse_tip.bound_box), key=lambda v: v.z))
spark_mat = lib.glossy("Spark", srgb("#FFE45C"), emit=10)
lib.prism("Spark", lib.star_pts(8, 0.6, 0.24), 0.1, spark_mat, loc=(tip.x, tip.y - 0.3, tip.z + 0.1), bevel=0.01, outline=0.03)
CONF = [srgb("#FF4F6D"), srgb("#FFD23F"), srgb("#3FD3FF"), srgb("#7BE24A"), srgb("#B66BFF")]
for i in range(40):
    a = rng.uniform(0.15 * math.pi, 0.85 * math.pi)
    r = rng.uniform(brad * 1.3, brad * 2.5)
    p = Vector((bc.x + math.cos(a) * r * 1.25, bc.y - 0.8, bc.z + math.sin(a) * r * 0.85 - brad * 0.2))
    if i % 3 == 0:
        lib.prism(f"Star{i}", lib.star_pts(5, 0.2, 0.09), 0.06, lib.glossy(f"StarM{i}", srgb("#FFE45C"), emit=3), loc=p, bevel=0.005, outline=0.025)
    else:
        lib.box(
            f"Conf{i}",
            (0.26, 0.04, 0.13),
            lib.glossy(f"ConfM{i}", CONF[i % len(CONF)], 0.3),
            loc=p,
            rot=[("Y", rng.uniform(0, 180)), ("X", rng.uniform(-40, 40))],
            bevel=0.01,
            outline=0.025,
        )

# ── render: hulls for the bomb + confetti, then a 16:10 ortho frame round everything ────────────────────────────
_orig_edge = lib.edge_mat
lib.edge_mat = lambda color: _orig_edge((0.13, 0.13, 0.3, 1.0))
lib.add_hulls()
deps = bpy.context.evaluated_depsgraph_get()
pts = []
for o in sc.objects:
    if o.type == "MESH":
        ev = o.evaluated_get(deps)
        pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (lo + hi) / 2
W, H = hi.x - lo.x, hi.z - lo.z
cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = max(W, H * 1.6) * 1.06
cam = bpy.data.objects.new("Cam", cam_d)
sc.collection.objects.link(cam)
cam.location = center + Vector((0, -30, 0))
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 2048, 1280
sc.render.filepath = os.path.join(OUT, "logo.png")
bpy.ops.render.render(write_still=True)
print("LOGO", sc.render.filepath, flush=True)
