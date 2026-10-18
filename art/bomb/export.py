"""FUSE VALLEY — export the approved hero bomb for Roblox (Asset Bible §3, §10.4).

Builds the model with art/bomb/build.py (no renders), then:
  1. evaluates every part (modifiers, curves) into plain meshes in world space;
  2. groups them into the pieces the game drives (BombController):
       Body (iron + weld beads), Brass (belt, rivets, bezels, collar, buckle, spring), Socket (porcelain),
       Clamp (straps + back plate)            → baked PBR textures (colour, roughness, metalness, normal)
       Lens F/B (glass), Lamp F/B, SeamGlow 1/2 → plain meshes (the game sets Glass / Neon and animates them)
       Fuse1..12                               → the braided cord, baked, then sliced into 12 burnable segments;
  3. writes art/out/Bomb.ClassicIron/export/Bomb.ClassicIron.glb (+ the PNG maps) for Studio's 3D Importer.

Re-bake (the GLB already exists, the normal case): the shipped meshes are kept byte for byte. Their UVs are
transferred onto the rebuilt groups, the maps are baked, written to textures/ and swapped into the GLB's embedded
images; nothing else in the GLB changes (the game's MeshParts, the 17 skins and the face rig all fit the shipped UVs).
Then upload textures/ (tools/upload_assets.py) and run art/bomb/studio_swap_maps.luau in Studio. --fresh-uvs rebuilds
UVs, fuse slices and the GLB from scratch (a brand-new mesh only: it would break every skin).

Run:  blender -b --python-exit-code 1 --python art/bomb/export.py [-- --fresh-uvs]   (Blender 4.5 or 5.x)
Pivot: the bomb's centre is the origin (the game mounts it there). Blender -Y (the clamp side) → Roblox -Z.
"""

import math
import os
import runpy
import sys

import bpy
import bmesh
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "export")
TEX = os.path.join(OUT, "textures")
os.makedirs(TEX, exist_ok=True)

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GLB = os.path.join(OUT, "Bomb.ClassicIron.glb")
# Re-bakes keep the SHIPPED meshes: the game's MeshParts, the 17 skins (art/bomb/skins.py) and the face rig were all
# made on the UVs in the existing GLB, and Smart UV Project / primitive vertex order differ between Blender versions
# (4.5 → 5.2 reshuffled Body and Brass). So when the GLB exists, its UVs are transferred onto the rebuilt groups before
# baking and its own meshes are what gets exported again (geometry, UVs and names unchanged; only the maps are new).
# --fresh-uvs forces the original path (Smart UV + new fuse slices): only for a brand-new mesh, never for a re-bake.
KEEP_SHIPPED = os.path.exists(GLB) and "--fresh-uvs" not in ARGV
UV_MATCH_MIN = 0.999  # the share of rebuilt face corners whose transferred UV must hit a shipped (position, UV) pair

sys.argv = [sys.argv[0], "--", "--no-render"]
runpy.run_path(os.path.join(HERE, "build.py"), run_name="__fv_build__")

scene = bpy.context.scene
deps = bpy.context.evaluated_depsgraph_get()
bomb = bpy.data.collections["Bomb"]

shipped = {}
if KEEP_SHIPPED:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=GLB)
    ship_coll = bpy.data.collections.new("Shipped")
    scene.collection.children.link(ship_coll)
    for o in set(bpy.data.objects) - before:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        ship_coll.objects.link(o)
        if o.type == "MESH":
            o.data.transform(o.matrix_world)  # bake any importer transform into the data
            o.matrix_world = Matrix.Identity(4)
            o.hide_render = True
            shipped[o.name.split(".")[0]] = o
    print("shipped parts:", sorted(shipped), flush=True)

# ── 1. Evaluate every part into a world-space mesh object ────────────────────────────────────────────────────────
out_coll = bpy.data.collections.new("Export")
scene.collection.children.link(out_coll)


def bake_mesh(src):
    deps.update()
    ev = src.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=deps)
    me.transform(src.matrix_world)
    o = bpy.data.objects.new(src.name[: -len("_src")] + "_x", me)
    out_coll.objects.link(o)
    return o


for o in list(bomb.objects):
    o.name = o.name + "_src"
parts = {}
for o in list(bomb.objects):
    if o.type in ("MESH", "CURVE") and o.name not in ("SparkCore",):
        parts[o.name[: -len("_src")]] = bake_mesh(o)
for o in list(bomb.objects):
    o.hide_render = True
    o.hide_viewport = True


def join(name, names):
    objs = [parts[n] for n in names if n in parts]
    if not objs:
        return None
    base = objs[0]
    with bpy.context.temp_override(active_object=base, selected_editable_objects=objs, object=base):
        bpy.ops.object.join()
    base.name = name
    base.data.name = name
    return base


GROUPS = {
    "Body": ["Body", "Seam1", "Seam2"],
    "Brass": ["Belt", "BezelF", "BezelB", "Collar", "Buckle", "Spring"] + [n for n in parts if n.startswith("Rivet")],
    "Socket": ["Socket", "SocketSoot"],
    "Clamp": ["ClawL", "ClawR", "BackPlate"],
    "FuseCord": ["Fuse"],
}
PLAIN = {"LensF": "LensF", "LensB": "LensB", "LampF": "LampCoreF", "LampB": "LampCoreB", "SeamGlow1": "SeamGlow1", "SeamGlow2": "SeamGlow2"}

baked = {name: join(name, names) for name, names in GROUPS.items()}
plain = {}
for name, src in PLAIN.items():
    if src in parts:
        o = parts[src]
        o.name = name
        o.data.name = name
        plain[name] = o

# ── 2. Bake PBR maps per group ───────────────────────────────────────────────────────────────────────────────────
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.bake.margin = 8
RES = {"Body": 1024, "Brass": 1024, "Socket": 512, "Clamp": 512, "FuseCord": 512}


def smart_uv(o):
    for other in bpy.context.view_layer.objects:
        other.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def shipped_uvs(o, src):
    """Give the rebuilt group `o` the shipped mesh's UVs (same surface, other vertex order): a Data Transfer of face-
    corner UVs by nearest corner + matching face normal, then check that the corners landed on shipped (pos, UV) pairs."""
    for layer in list(o.data.uv_layers):
        o.data.uv_layers.remove(layer)
    o.data.uv_layers.new(name="UVMap")
    dt = o.modifiers.new("ShippedUV", "DATA_TRANSFER")
    dt.object = src
    dt.use_loop_data = True
    dt.data_types_loops = {"UV"}
    dt.loop_mapping = "NEAREST_POLYNOR"
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier=dt.name)

    def key(co, uv):
        return (round(co.x, 4), round(co.y, 4), round(co.z, 4), round(uv.x, 4), round(uv.y, 4))

    sm, su = src.data, src.data.uv_layers.active.data
    have = {key(sm.vertices[lp.vertex_index].co, su[lp.index].uv) for lp in sm.loops}
    om, ou = o.data, o.data.uv_layers.active.data
    hit = sum(key(om.vertices[lp.vertex_index].co, ou[lp.index].uv) in have for lp in om.loops)
    share = hit / max(1, len(om.loops))
    print(f"shipped UVs on {o.name}: {share:.5f} of {len(om.loops)} corners match", flush=True)
    if share < UV_MATCH_MIN:
        raise RuntimeError(f"{o.name}: only {share:.4f} of the corners match the shipped UVs; the mesh has changed")


def bsdf_of(mat):
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def bake_pass(o, img, kind):
    for mat in o.data.materials:
        nt = mat.node_tree
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.name = "BAKE_TARGET"
        nt.nodes.active = node
    for other in bpy.context.view_layer.objects:
        other.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    if kind == "COLOR":
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=8)
    elif kind == "ROUGHNESS":
        bpy.ops.object.bake(type="ROUGHNESS", use_clear=True, margin=8)
    elif kind == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True, margin=8)
    elif kind == "METAL":
        bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
    for mat in o.data.materials:
        nt = mat.node_tree
        n = nt.nodes.get("BAKE_TARGET")
        if n:
            nt.nodes.remove(n)


def to_emission(o, input_name):
    """Route each material's input_name (Base Color / Metallic) into Emission (strength 1) so an EMIT bake records it
    exactly (a DIFFUSE colour bake comes out black on metals); returns an undo list."""
    undo = []
    for mat in o.data.materials:
        b = bsdf_of(mat)
        if not b:
            continue
        nt = mat.node_tree
        prev = (b.inputs["Emission Strength"].default_value, tuple(b.inputs["Emission Color"].default_value))
        links = [l for l in nt.links if l.to_socket == b.inputs["Emission Color"]]
        for l in links:
            nt.links.remove(l)
        m_in = b.inputs[input_name]
        if m_in.is_linked:
            src = m_in.links[0].from_socket
            nt.links.new(src, b.inputs["Emission Color"])
        else:
            v = m_in.default_value
            b.inputs["Emission Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1)
        b.inputs["Emission Strength"].default_value = 1.0
        undo.append((mat, b, prev))
    return undo


def restore_emission(undo):
    for mat, b, prev in undo:
        nt = mat.node_tree
        for l in [l for l in nt.links if l.to_socket == b.inputs["Emission Color"]]:
            nt.links.remove(l)
        b.inputs["Emission Strength"].default_value = prev[0]
        b.inputs["Emission Color"].default_value = prev[1]


def final_material(name, maps):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = bsdf_of(m)

    def tex(img, non_color):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        if non_color:
            img.colorspace_settings.name = "Non-Color"
        return n

    nt.links.new(tex(maps["COLOR"], False).outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex(maps["ROUGHNESS"], True).outputs["Color"], b.inputs["Roughness"])
    nt.links.new(tex(maps["METAL"], True).outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(maps["NORMAL"], True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m


for name, o in baked.items():
    if o is None:
        continue
    if name == "FuseCord":
        pass  # the cord keeps its along-the-length UVs (the braid runs with them; identical across versions)
    elif KEEP_SHIPPED:
        shipped_uvs(o, shipped[name])
    else:
        smart_uv(o)
    res = RES[name]
    maps = {}
    for kind in ("COLOR", "ROUGHNESS", "NORMAL", "METAL"):
        img = bpy.data.images.new(f"{name}_{kind}", res, res, alpha=False, float_buffer=(kind == "NORMAL"))
        if kind != "COLOR":
            img.colorspace_settings.name = "Non-Color"  # data maps: saved raw, never gamma-encoded
        if kind in ("METAL", "COLOR"):
            undo = to_emission(o, "Metallic" if kind == "METAL" else "Base Color")
            bake_pass(o, img, "METAL")  # an EMIT bake
            restore_emission(undo)
        else:
            bake_pass(o, img, kind)
        img.filepath_raw = os.path.join(TEX, f"Bomb_{name}_{kind}.png")
        img.file_format = "PNG"
        img.save()
        maps[kind] = img
        print("baked", name, kind, flush=True)
    mat = final_material("Bomb_" + name, maps)
    o.data.materials.clear()
    o.data.materials.append(mat)

# ── 3. Slice the cord into 12 burnable segments (bottom → top: Fuse1 … Fuse12) ───────────────────────────────────
if KEEP_SHIPPED:
    # Re-bake: the shipped GLB keeps every byte of its meshes (a glTF re-export through the importer would re-split
    # vertices: Fuse12 gained 4); only its embedded images are swapped for the new maps. glTF packs roughness (G) and
    # metalness (B) into one image per material.
    import json
    import struct
    import tempfile

    def packed_mr(part):
        rough = bpy.data.images.load(os.path.join(TEX, f"Bomb_{part}_ROUGHNESS.png"), check_existing=False)
        metal = bpy.data.images.load(os.path.join(TEX, f"Bomb_{part}_METAL.png"), check_existing=False)
        for im in (rough, metal):
            im.colorspace_settings.name = "Non-Color"
        w, h = rough.size
        r, m = list(rough.pixels[:]), list(metal.pixels[:])
        px = [0.0] * (w * h * 4)
        px[1::4], px[2::4], px[3::4] = r[0::4], m[0::4], [1.0] * (w * h)
        im = bpy.data.images.new(f"{part}_MR", w, h, alpha=False)
        im.colorspace_settings.name = "Non-Color"
        im.pixels = px
        path = os.path.join(tempfile.gettempdir(), f"fv_bomb_{part}_MR.png")
        im.filepath_raw = path
        im.file_format = "PNG"
        im.save()
        return open(path, "rb").read()

    def new_image_bytes(name):
        if name.endswith("_ROUGHNESS") and "_METAL-" in name:  # "Body_METAL-Body_ROUGHNESS"
            return packed_mr(name.split("_")[0])
        return open(os.path.join(TEX, name + ".png"), "rb").read()  # "Bomb_Body_COLOR" / "Bomb_Body_NORMAL"

    data = open(GLB, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + jlen])
    boff = 20 + jlen
    blob = data[boff + 8:boff + 8 + struct.unpack("<I", data[boff:boff + 4])[0]]
    swap = {img["bufferView"]: new_image_bytes(img["name"]) for img in gltf["images"]}
    out_bin = bytearray()
    for i, bv in enumerate(gltf["bufferViews"]):
        chunk = swap.get(i) or blob[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        out_bin += b"\x00" * (-len(out_bin) % 4)
        bv["byteOffset"], bv["byteLength"] = len(out_bin), len(chunk)
        out_bin += chunk
    out_bin += b"\x00" * (-len(out_bin) % 4)
    gltf["buffers"][0]["byteLength"] = len(out_bin)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out_bin)
    with open(GLB, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(out_bin), 0x004E4942) + bytes(out_bin))
    print("EXPORTED", GLB, f"(shipped meshes kept; {len(swap)} images swapped)", flush=True)
else:
    cord = baked["FuseCord"]
    zs = [v.co.z for v in cord.data.vertices]
    z0, z1 = min(zs), max(zs)
    h = (z1 - z0) / 12
    fuse_parts = []
    for i in range(12):
        lo, hi = z0 + i * h, z0 + (i + 1) * h
        me = cord.data.copy()
        seg = bpy.data.objects.new(f"Fuse{i + 1}", me)
        out_coll.objects.link(seg)
        bm = bmesh.new()
        bm.from_mesh(me)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, lo), plane_no=(0, 0, 1), clear_inner=True)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, hi), plane_no=(0, 0, 1), clear_outer=True)
        bm.to_mesh(me)
        bm.free()
        fuse_parts.append(seg)
    bpy.data.objects.remove(cord)
    del baked["FuseCord"]

    # Plain parts keep simple materials (the game sets Glass / Neon on them).
    for name, o in plain.items():
        o.data.materials.clear()

    # ── 4. Export ────────────────────────────────────────────────────────────────────────────────────────────────────
    export_objs = [o for o in baked.values() if o is not None] + list(plain.values()) + fuse_parts
    for o in scene.objects:
        o.select_set(False)
    for o in export_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = export_objs[0]
    glb = os.path.join(OUT, "Bomb.ClassicIron.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_image_format="AUTO",
    )
    print("EXPORTED", glb, [o.name for o in export_objs], flush=True)
