"""FUSE VALLEY — shared helpers for the 3D-rendered icon set (Asset Bible §6.4; DECISIONS 2026-10-17: icons are
modelled in Blender and rendered, matching the owner's reference video: chunky, glossy, rounded game icons with soft
studio light, saturated colour, a slight 3/4 tilt and a thin darker edge).

Each icon is built from bevelled primitives at roughly unit size, then `render_icon` frames it from its bounding box
and writes a transparent PNG. Imported by art/icons/build.py.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

_mats = {}
OUTLINE = True
ICONS = {}


def icon(fn):
    """Register an icon builder: the function name is the icon's Assets.Icon key."""
    ICONS[fn.__name__] = fn
    return fn



def srgb(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [a])


def reset():
    _mats.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = srgb("#B9C4DA")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    sc.world = w
    _lights()


def _light(kind, loc, energy, color, size=3.0):
    ld = bpy.data.lights.new(kind, kind)
    ld.energy = energy
    ld.color = color[:3]
    if kind == "AREA":
        ld.size = size
    o = bpy.data.objects.new(kind, ld)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)


def _lights():
    _light("AREA", (-3.5, -6, 6), 1500, srgb("#FFF6EA"), 5.0)  # key, high front-left
    _light("AREA", (6, -4, 2.0), 450, srgb("#E2EAFF"), 4.0)  # fill, right
    _light("AREA", (1.5, 6, 5), 1400, srgb("#FFFFFF"), 3.0)  # rim, behind
    _light("AREA", (0, -8, -2), 200, srgb("#FFF0E0"), 6.0)  # bounce from below


def glossy(name, color, rough=0.28, metal=0.0, coat=0.55, emit=0.0):
    """A saturated toy-plastic / enamel material with a clear-coat sheen."""
    key = (name, color, rough, metal, coat, emit)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.08
    if emit:
        b.inputs["Emission Color"].default_value = color
        b.inputs["Emission Strength"].default_value = emit
    _mats[key] = m
    return m


def gold(name="Gold"):
    return glossy(name, srgb("#F7AE14"), 0.24, 0.4, 0.6)


def silver(name="Silver"):
    return glossy(name, srgb("#A9B4C6"), 0.24, 0.55, 0.5)


def edge_mat(color):
    """The thin darker edge (inverted hull): the hull faces turned toward the camera are see-through (Cycles ignores
    backface culling, so it's done in the shader), the far ones render as the base colour, much darker."""
    d = tuple([c * 0.1 for c in color[:3]] + [1.0])
    m = bpy.data.materials.new("Edge")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dark = nt.nodes.new("ShaderNodeEmission")
    dark.inputs["Color"].default_value = d
    dark.inputs["Strength"].default_value = 1.0
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(dark.outputs["Emission"], mix.inputs[1])
    nt.links.new(clear.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return m


def _obj(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def finish(o, bevel=0.04, segs=3, smooth=True, outline=0.035, sub=0):
    if bevel:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segs
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(35)
    if sub:
        s = o.modifiers.new("Sub", "SUBSURF")
        s.levels = s.render_levels = sub
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    if outline and OUTLINE:
        o["outline"] = outline  # the hull is added at render time, after the tilt (add_hulls)
    return o


def add_hulls():
    """For every mesh marked with an outline: a copy of its final surface pushed out along the normals, faces reversed,
    in the darker edge material — the far side shows round the silhouette as the thin dark edge."""
    deps = bpy.context.evaluated_depsgraph_get()
    for o in [x for x in bpy.context.scene.objects if x.type == "MESH" and "outline" in x.keys()]:
        t = o["outline"]
        ev = o.evaluated_get(deps)
        me = bpy.data.meshes.new_from_object(ev, depsgraph=deps)
        me.transform(o.matrix_world)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * t
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        base = o.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        me.materials.clear()
        me.materials.append(edge_mat(tuple(base)))
        h = bpy.data.objects.new(o.name + "_hull", me)
        # camera rays only: the hull must never shadow or reflect into the icon it outlines
        h.visible_shadow = False
        h.visible_diffuse = False
        h.visible_glossy = False
        h.visible_transmission = False
        h.visible_volume_scatter = False
        bpy.context.scene.collection.objects.link(h)


def xform(bm, loc=(0, 0, 0), rot=None, scale=None):
    if scale:
        bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    if rot:
        for axis, deg in rot:
            bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(deg), 3, axis), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)


def box(name, size, mat, loc=(0, 0, 0), rot=None, bevel=0.06, outline=0.035, sub=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    xform(bm, loc, rot, size)
    return finish(_obj(name, bm, mat), bevel, outline=outline, sub=sub)


def cyl(name, r, depth, mat, loc=(0, 0, 0), rot=None, segs=48, r2=None, bevel=0.03, outline=0.035):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    xform(bm, loc, rot)
    return finish(_obj(name, bm, mat), bevel, outline=outline)


def sphere(name, r, mat, loc=(0, 0, 0), scale=None, rot=None, outline=0.035):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=r)
    xform(bm, loc, rot, scale)
    return finish(_obj(name, bm, mat), 0, outline=outline)


def torus(name, major, minor, mat, loc=(0, 0, 0), rot=None, outline=0.02, seg=64, mseg=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=seg, minor_segments=mseg)
    o = bpy.context.active_object
    o.name = name
    bm = bmesh.new()
    bm.from_mesh(o.data)
    xform(bm, loc, rot)
    bm.to_mesh(o.data)
    bm.free()
    o.data.materials.append(mat)
    return finish(o, 0, outline=outline)


def prism(name, pts2d, depth, mat, loc=(0, 0, 0), rot=None, bevel=0.05, outline=0.035, segs=3):
    """Extrude a 2D outline (in XZ, facing -Y) by `depth` along Y."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -depth / 2, z)) for x, z in pts2d]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, depth, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    xform(bm, loc, rot)
    return finish(_obj(name, bm, mat), bevel, segs=segs, outline=outline)


def star_pts(points, r_out, r_in, rot_deg=90.0):
    out = []
    for i in range(points * 2):
        a = math.radians(rot_deg) + math.pi * i / points
        r = r_out if i % 2 == 0 else r_in
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def tube(name, pts, radius, mat, outline=0.02, caps=True):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.use_fill_caps = caps
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    # convert so the outline modifier can apply
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.select_set(False)
    return finish(o, 0, outline=outline)


def group_tilt(yaw=-24, pitch=10):
    """Give the whole icon the house 3/4 tilt (rotate every mesh about the scene origin)."""
    rot = Matrix.Rotation(math.radians(pitch), 4, "X") @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.matrix_world = rot @ o.matrix_world


def render_icon(out_path, res=512, margin=1.12):
    add_hulls()
    sc = bpy.context.scene
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in sc.objects:
        if o.type == "MESH":
            ev = o.evaluated_get(deps)
            pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    size = max(hi.x - lo.x, hi.z - lo.z)
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = size * margin
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    cam.location = center + Vector((0, -20, 0))
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.filepath = out_path
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
