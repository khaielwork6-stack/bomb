"""FUSE VALLEY — Classic Iron before / after review (Asset Bible §3, §10.3; DECISIONS 2026-10-17 "Bomb").

Renders the exported hero bomb twice with the same camera, under bright midday light like the restyled Yard
(Roblox ClockTime 13.6: a high sun in a clear blue sky over grass), once with the BEFORE map set and once with the
AFTER map set, and puts them side by side. The game's own look is mirrored: the baked parts carry their four PBR maps,
the lenses are glass, the lamps glow (LIT) and the seam glow strips are hidden.

  blender -b --factory-startup --python-exit-code 1 --python art/bomb/compare.py -- \
      --before <export dir> [--after art/out/Bomb.ClassicIron/export] [--out renders/compare_before_after.png]

An export dir holds Bomb.ClassicIron.glb and textures/Bomb_<Part>_<COLOR|ROUGHNESS|NORMAL|METAL>.png.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


AFTER = os.path.abspath(arg("--after", os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "export")))
BEFORE = os.path.abspath(arg("--before", AFTER))
OUT = os.path.abspath(arg("--out", os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "renders", "compare_before_after.png")))
SAMPLES = int(arg("--samples", "128"))
RES = int(arg("--res", "1000"))

BAKED = ("Body", "Brass", "Socket", "Clamp")  # + Fuse1..12, which share the FuseCord maps
SUN_ELEVATION = 62.0  # degrees: ClockTime 13.6 in the Yard
SUN_AZIMUTH = 112.0  # where the sun stands, in the camera's orbit angles (camera at 148): front-right, like a
# player looking at a Carrier's back with the sun over their shoulder
SUN_STRENGTH = 2.6
SKY_STRENGTH = 0.7
SKY_HORIZON = (0.62, 0.80, 1.0, 1)  # linear
SKY_ZENITH = (0.10, 0.36, 0.95, 1)
EXPOSURE = 0.0
VIEW = "Standard"  # Roblox keeps toy colours saturated; AgX washes a sunny scene to pastel
GRASS = (0.18, 0.42, 0.08, 1)  # the Yard's toy grass (linear)
LAMP = (1.0, 0.85, 0.29, 1)  # Theme Spark #FFD84A, LIT

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(AFTER, "Bomb.ClassicIron.glb"))
parts = {}
for o in list(scene.objects):
    if o.type == "MESH":
        parts[o.name.split(".")[0]] = o


def map_material(name, tex_dir, part):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def tex(kind, non_color):
        img = bpy.data.images.load(os.path.join(tex_dir, "textures", f"Bomb_{part}_{kind}.png"), check_existing=False)
        if non_color:
            img.colorspace_settings.name = "Non-Color"
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        return n

    nt.links.new(tex("COLOR", False).outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex("ROUGHNESS", True).outputs["Color"], b.inputs["Roughness"])
    nt.links.new(tex("METAL", True).outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex("NORMAL", True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m


def flat(name, color, rough=0.5, emit=0.0, transmission=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["Alpha"].default_value = alpha
    if emit:
        b.inputs["Emission Color"].default_value = color
        b.inputs["Emission Strength"].default_value = emit
    return m


def dress(tex_dir, tag):
    sets = {p: map_material(f"{tag}_{p}", tex_dir, p) for p in BAKED + ("FuseCord",)}
    for name, o in parts.items():
        o.hide_render = False
        o.data.materials.clear()
        if name in sets:
            o.data.materials.append(sets[name])
        elif name.startswith("Fuse"):
            o.data.materials.append(sets["FuseCord"])
        elif name.startswith("Lamp"):
            o.data.materials.append(flat(f"{tag}_lamp", LAMP, emit=8.0))
        elif name.startswith("Lens"):
            o.data.materials.append(flat(f"{tag}_lens", (0.9, 0.95, 1.0, 1), 0.05, transmission=1.0, alpha=0.55))
        elif name.startswith("SeamGlow"):
            o.hide_render = True  # transparent at LIT in game


# ── The Yard at midday ───────────────────────────────────────────────────────────────────────────────────────────
world = bpy.data.worlds.new("Midday")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
# a clear toy sky: pale at the horizon, saturated blue overhead (the Yard's skybox), lighting the bomb as ambient
wtc = world.node_tree.nodes.new("ShaderNodeTexCoord")
wsep = world.node_tree.nodes.new("ShaderNodeSeparateXYZ")
world.node_tree.links.new(wtc.outputs["Generated"], wsep.inputs["Vector"])
wramp = world.node_tree.nodes.new("ShaderNodeValToRGB")
wramp.color_ramp.elements[0].position, wramp.color_ramp.elements[0].color = 0.0, SKY_HORIZON
wramp.color_ramp.elements[1].position, wramp.color_ramp.elements[1].color = 0.6, SKY_ZENITH
world.node_tree.links.new(wsep.outputs["Z"], wramp.inputs["Fac"])
world.node_tree.links.new(wramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = SKY_STRENGTH
scene.world = world

sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = SUN_STRENGTH
sun.angle = math.radians(1.5)
sun.color = (1.0, 0.97, 0.9)
so = bpy.data.objects.new("Sun", sun)
el, az = math.radians(SUN_ELEVATION), math.radians(SUN_AZIMUTH)
toward_sun = Vector((math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el)))
so.rotation_euler = (-toward_sun).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(so)

bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -1.12))
ground = bpy.context.active_object
ground.data.materials.append(flat("Grass", GRASS, 0.7))

# ── Camera: the hero 3/4 front (build.py orbit(148, 9.4, 2.7) on the bomb + fuse) ──────────────────────────────────
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 70
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
a = math.radians(148)
cam.location = Vector((math.sin(a) * 9.4, -math.cos(a) * 9.4, 2.7))
cam.rotation_euler = (Vector((0, 0, 0.55)) - cam.location).to_track_quat("-Z", "Y").to_euler()

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
scene.view_settings.view_transform = VIEW
scene.view_settings.look = "None"
scene.view_settings.exposure = EXPOSURE
scene.render.resolution_x = scene.render.resolution_y = RES
scene.render.film_transparent = False


label_data = bpy.data.curves.new("Label", "FONT")
label_data.size = 0.075
label = bpy.data.objects.new("Label", label_data)
label.parent = cam
label.location = (-0.47, 0.43, -2.0)  # the top-left corner of the 70 mm frame, 2 units in front of the lens
label.data.materials.append(flat("LabelInk", (1, 1, 1, 1), emit=4.0))
for vis in ("visible_shadow", "visible_diffuse", "visible_glossy", "visible_transmission"):
    setattr(label, vis, False)
scene.collection.objects.link(label)


def shoot(tex_dir, tag):
    dress(tex_dir, tag)
    label_data.body = tag.upper()
    path = os.path.join(os.path.dirname(OUT), f"_compare_{tag}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"  # read the display-referred bytes as they are
    px = np.array(img.pixels[:], dtype=np.float32).reshape(RES, RES, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    print("rendered", tag, flush=True)
    return px


os.makedirs(os.path.dirname(OUT), exist_ok=True)
left = shoot(BEFORE, "before")
right = shoot(AFTER, "after")
gap = np.ones((RES, 12, 4), dtype=np.float32)
gap[..., :3] = (0.086, 0.071, 0.11)  # Theme Ink between the halves
sheet = np.concatenate([left, gap, right], axis=1)
h, w = sheet.shape[:2]
out = bpy.data.images.new("compare", w, h, alpha=False)
out.colorspace_settings.name = "Non-Color"  # write them back untouched
out.pixels = sheet.ravel()
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
print("DONE", OUT, flush=True)
