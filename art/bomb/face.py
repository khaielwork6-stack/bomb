"""FUSE VALLEY — the bomb's face rig (Asset Bible §3.8): eyes, lids, brows and mouths for "The Tick".

The face makes the bomb a character: it smirks while it's LIT, grimaces at HOT, screams white-hot at CRITICAL, blinks,
and its pupils track the nearest player. Every piece is a rigid part that only *rotates* about a pivot, so the game
can drive the exact same rig with Motor6D/Weld C0s at runtime (BombController):

  Eye      porcelain dome, sunk into the body (proud 0.07)          fixed
  Pupil    ink cap on the eye sphere + a porcelain glint             rotates about the eye centre (gaze)
  Lid      ink half-shell over the eye                                rotates about the eye's horizontal axis (blink,
                                                                      squint) and its out axis (slant)
  Brow     forged ink bar on the body above the eye                   rotates about the body centre (raise, tilt)
  Mouth    one mesh per shape (Smirk, Grimace, Panic, Ooh, Grin)      shown one at a time; Panic has a glowing core

The face sits on the front (+Y, away from the clamp: what everyone behind the Carrier, the Carrier's own camera
included, sees) between the two front weld seams, eyes above the brass belt, mouth below it. Nothing changes the
silhouette (§10.4) and it is shared by every skin (§3.6): porcelain + ink enamel read on any body.

Renders the review set to art/out/Bomb.Face/renders (expressions, stages, skins, in context, silhouette);
art/bomb/face_sheet.py composes the contact sheet.

Run:  blender -b --python-exit-code 1 --python art/bomb/face.py -- [--samples 48] [--only name,name]
Units: 1 Blender unit = 1 stud, Z-up (the GLB's Y-up converted on import, as in skins.py).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(HERE, "build.py")
GLB = os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "export", "Bomb.ClassicIron.glb")
SKINS = os.path.join(ROOT, "art", "out", "Skins")
OUT = os.path.join(ROOT, "art", "out", "Bomb.Face")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAMPLES = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 48
ONLY = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None

# ── The studio: build.py's Golden Fuse lights, cyclorama, camera and glare (its procedural bomb is swapped out) ───
sys.argv = [sys.argv[0], "--", "--no-render", "--out", OUT, "--samples", str(SAMPLES)]
B = {"__name__": "fv_build", "__file__": BUILD}
exec(compile(open(BUILD, encoding="utf-8").read(), BUILD, "exec"), B)
scene = bpy.context.scene
srgb, new_mat, node, give, mat_emit = B["srgb"], B["new_mat"], B["node"], B["give"], B["mat_emit"]
aim, render, orbit, ground = B["aim"], B["render"], B["orbit"], B["ground"]
R = B["R"]

# Apple silicon: Cycles on Metal (build.py only tries OPTIX / CUDA)
prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    scene.cycles.device = "GPU"
except Exception:
    pass

for o in list(B["bomb"].objects):
    if o.name.startswith("SparkCore"):
        B["bomb"].objects.unlink(o)
        scene.collection.objects.link(o)
    else:
        bpy.data.objects.remove(o, do_unlink=True)
spark, spark_core = B["spark"], B["spark_core"]
# closer to the in-game bloom than the hero sheet's: the face has to read through the CRITICAL glow
B["glare"].inputs["Threshold"].default_value = 3.5
B["glow"].inputs["Strength"].default_value = 0.18

# ── Palette + face materials ─────────────────────────────────────────────────────────────────────────────────────
INK = srgb("#16121C")
INK2 = srgb("#241D2E")
WHITE_HOT = (1.0, 0.92, 0.7, 1)


def mat_ink():
    # glossy ink enamel: hand-painted, so its roughness wanders a little (Quality Bar #6)
    m, nt, b = new_mat("InkEnamel")
    L = nt.links
    tc = node(nt, "ShaderNodeTexCoord", (-900, 0))
    nz = node(nt, "ShaderNodeTexNoise", (-650, 0), Scale=38.0, Detail=3.0)
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    rr = node(nt, "ShaderNodeMapRange", (-400, 0), **{"To Min": 0.22, "To Max": 0.48})
    L.new(nz.outputs["Fac"], rr.inputs["Value"])
    L.new(rr.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Base Color"].default_value = INK
    b.inputs["Coat Weight"].default_value = 0.5
    return m


M_PORC = B["M_PORC"]  # the fuse socket's crackle-glazed porcelain: the eyes and teeth are the same ceramic
M_INK = mat_ink()
M_BRASS = B["M_BRASS"]  # the belt's brass: brows and mouth rims read on iron and on every skin
M_GLINT = mat_emit("Glint", (1, 1, 1, 1), 1.5)
M_MOUTH_HOT = mat_emit("MouthCore", WHITE_HOT, 9.0)
M_RECESS, _, rb = new_mat("Recess")
rb.inputs["Base Color"].default_value = INK2
rb.inputs["Roughness"].default_value = 0.9
M_SEAM = mat_emit("SeamGlowStage", B["EMBER"], 0.0)
M_LAMP = mat_emit("LampStage", B["SPARK"], 6.0)

# ── The exported bomb (the in-game mesh and maps) under one root, so CRITICAL can swell everything together ──────
bpy.ops.import_scene.gltf(filepath=GLB)
root = bpy.data.objects.new("BombRoot", None)
scene.collection.objects.link(root)
parts = {}
for o in list(bpy.data.objects):
    if o.type == "MESH" and o.name not in ("Cyclorama",) and not o.name.startswith("SparkCore") and o.parent is None:
        o.parent = root
    if o.type == "MESH":
        parts[o.name.split(".")[0]] = o
for n in ("SeamGlow1", "SeamGlow2"):
    give(parts[n], M_SEAM)
for n in ("LampF", "LampB"):
    give(parts[n], M_LAMP)
fuse = [parts[f"Fuse{i}"] for i in range(1, 13)]
classic_mats = {n: list(parts[n].data.materials) for n in ("Body", "Brass", "Clamp", "Socket")}


# ── Geometry helpers ─────────────────────────────────────────────────────────────────────────────────────────────
def direction(az_deg, el_deg):
    """A unit vector from the body centre: azimuth from +Y (the front) toward +X, elevation up from the belt."""
    az, el = math.radians(az_deg), math.radians(el_deg)
    return Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))


def frame(d):
    """Local axes at a surface direction: x = right along the surface, y = out (the normal), z = up along it."""
    right = d.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(d).normalized()
    return Matrix((right, d, up)).transposed()  # columns


def obj_from_bm(name, bm, mat, coll):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    for p in o.data.polygons:
        p.use_smooth = True
    give(o, mat)
    return o


def shell(radius, pred, thickness, segs=64, rings=32):
    """A UV sphere cut down to the faces whose centre passes `pred`, given thickness inward."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    gone = [f for f in bm.faces if not pred(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    if thickness > 0:
        r = bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thickness)
        del r
    return bm


def cap(radius, axis, ang_deg, thickness=0.0, segs=48, rings=48):
    """The part of a sphere within ang_deg of `axis` (a pupil, a glint)."""
    c = math.cos(math.radians(ang_deg))
    return shell(radius, lambda p: p.normalized().dot(axis) >= c, thickness, segs, rings)


def project(bm, origin_dir, r_surface, lift):
    """Wrap a flat shape built in a surface frame's (x, z) plane onto the body sphere, `lift` studs proud."""
    m = frame(origin_dir)
    for v in bm.verts:
        flat = m @ Vector((v.co.x, 0, v.co.z))
        v.co = (origin_dir * r_surface + flat).normalized() * (r_surface + lift + v.co.y)


def flat_shape(outline, holes=(), depth=0.03, cuts=3):
    """A filled 2D outline (x, z pairs) with optional holes, extruded `depth` outward (+y), finely subdivided so it can
    wrap onto the sphere."""
    bm = bmesh.new()
    loops = [outline, *holes]
    edges = []
    for loop in loops:
        vs = [bm.verts.new((x, 0, z)) for (x, z) in loop]
        for i in range(len(vs)):
            edges.append(bm.edges.new((vs[i], vs[(i + 1) % len(vs)])))
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges)
    if holes:
        # triangle_fill fills the holes too: drop faces whose centre sits inside a hole
        def inside(pt, poly):
            x, z = pt
            hit = False
            for i in range(len(poly)):
                (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
                if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
                    hit = not hit
            return hit

        drop = [f for f in bm.faces if any(inside((f.calc_center_median().x, f.calc_center_median().z), h) for h in holes)]
        bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def ellipse(w, h, n=48, cx=0.0, cz=0.0, bottom_bulge=1.0):
    pts = []
    for i in range(n):
        a = i / n * math.pi * 2
        z = math.sin(a) * h / 2
        if z < 0:
            z *= bottom_bulge
        pts.append((cx + math.cos(a) * w / 2, cz + z))
    return pts


def stroke(fn, x0, x1, width, n=40):
    """A thick stroke along z = fn(x), with round ends."""
    top, bot = [], []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        e = 1e-3
        dz = (fn(x + e) - fn(x - e)) / (2 * e)
        k = 1 / math.sqrt(1 + dz * dz)
        nx, nz = -dz * k, k
        w = width / 2 * (0.75 + 0.25 * math.sin(math.pi * i / n))  # a brush stroke: fuller in the middle
        top.append((x + nx * w, fn(x) + nz * w))
        bot.append((x - nx * w, fn(x) - nz * w))
    return top + bot[::-1]


def rounded_rect(w, h, r, n=8, cx=0.0, cz=0.0):
    pts = []
    for qx, qz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        ccx, ccz = cx + qx * (w / 2 - r), cz + qz * (h / 2 - r)
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((ccx + math.cos(a) * r, ccz + math.sin(a) * r))
    return pts


# ── The rig (dimensions in studs; tunables mirrored into Config.Feel / the face module when it ships) ─────────────
EYE_AZ, EYE_EL = 21.5, 26.0  # each eye's centre on the body (± azimuth)
EYE_R, EYE_SINK = 0.26, 0.17  # porcelain dome radius; its centre sits this far inside the surface (0.09 proud)
PUPIL_ANG, GLINT_ANG = 25.0, 6.5
LID_R, LID_T = EYE_R * 1.07, 0.016
BROW_EL, BROW_LEN, BROW_H, BROW_T = 47.5, 0.46, 0.115, 0.06
MOUTH_EL = -33.0

face = bpy.data.collections.new("Face")
scene.collection.children.link(face)
rig = {}


def place(o, matrix):
    o.parent = root
    o.matrix_basis = matrix


for side, sgn in (("L", 1), ("R", -1)):
    d = direction(sgn * EYE_AZ, EYE_EL)
    centre = d * (R - EYE_SINK)
    m = frame(d).to_4x4()
    base = Matrix.Translation(centre) @ m
    eye = obj_from_bm(f"Eye{side}", shell(EYE_R, lambda p: True, 0), M_PORC, face)
    place(eye, base)
    pupil = obj_from_bm(f"Pupil{side}", cap(EYE_R * 1.012, Vector((0, 1, 0)), PUPIL_ANG), M_INK, face)
    glint_axis = (Matrix.Rotation(math.radians(9), 3, "Z") @ Matrix.Rotation(math.radians(9), 3, "X")) @ Vector((0, 1, 0))
    glint = obj_from_bm(f"Glint{side}", cap(EYE_R * 1.02, glint_axis, GLINT_ANG), M_GLINT, face)
    # the lid: the upper half-shell; rotating it about local X (+ = back into the body, − = down over the eye)
    lid = obj_from_bm(f"Lid{side}", shell(LID_R, lambda p: p.z >= -0.002, LID_T), M_INK, face)
    # the brow: a forged bar swept along the body above the eye, tapering to its ends
    bm = bmesh.new()
    rows = []
    n = 24
    for i in range(n + 1):
        t = i / n - 0.5
        taper = 0.62 + 0.38 * math.cos(t * math.pi)
        az = sgn * EYE_AZ + t * math.degrees(BROW_LEN / (R * math.cos(math.radians(BROW_EL))))
        dd = direction(az, BROW_EL)
        up = frame(dd) @ Vector((0, 0, 1))
        h = BROW_H * taper / 2
        rows.append([bm.verts.new(p) for p in (
            dd * (R - 0.01) - up * h, dd * (R + BROW_T) - up * h * 0.8,
            dd * (R + BROW_T) + up * h * 0.8, dd * (R - 0.01) + up * h)])
    for i in range(n):
        for k in range(4):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % 4], rows[i + 1][(k + 1) % 4], rows[i + 1][k]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    brow = obj_from_bm(f"Brow{side}", bm, M_BRASS, face)
    bevel = brow.modifiers.new("Bevel", "BEVEL")
    bevel.width, bevel.segments = 0.012, 3
    rig[side] = {
        "sgn": sgn, "base": base, "eye": eye, "pupil": pupil, "glint": glint, "lid": lid, "brow": brow,
        "brow_dir": direction(sgn * EYE_AZ, BROW_EL), "right": frame(d) @ Vector((1, 0, 0)),
    }
    place(pupil, base)
    place(glint, base)
    place(lid, base)
    place(brow, Matrix.Identity(4))

# Mouths: one mesh per shape, wrapped onto the body below the belt.
md = direction(0, MOUTH_EL)


MOUTH_SCALE = 1.3


def mouth(name, layers):
    objs = []
    for i, (outline, holes, mat, depth, lift) in enumerate(layers):
        k = MOUTH_SCALE
        outline = [(x * k, z * k) for (x, z) in outline]
        holes = [[(x * k, z * k) for (x, z) in h] for h in holes]
        bm = flat_shape(outline, holes, depth)
        project(bm, md, R, lift)
        o = obj_from_bm(f"Mouth{name}_{i}", bm, mat, face)
        o.parent = root
        objs.append(o)
    return objs


mouths = {
    # LIT: a cocky smirk, the right corner hooked up
    "Smirk": mouth("Smirk", [(stroke(lambda x: 0.12 * (x / 0.24) ** 2 + 0.05 * (x / 0.24) - 0.055, -0.22, 0.26, 0.07),
                              (), M_BRASS, 0.03, 0.004)]),
    # HOT: clenched porcelain teeth in an ink grimace
    "Grimace": mouth("Grimace", [
        (rounded_rect(0.48, 0.19, 0.08), [rounded_rect(0.38, 0.105, 0.04)], M_BRASS, 0.03, 0.004),
        (rounded_rect(0.38, 0.105, 0.04), (), M_PORC, 0.022, 0.002),
        *[(rounded_rect(0.014, 0.1, 0.006, cx=x), (), M_INK, 0.03, 0.004) for x in (-0.115, -0.04, 0.04, 0.115)],
        (rounded_rect(0.37, 0.012, 0.005), (), M_INK, 0.03, 0.004),
    ]),
    # CRITICAL: a scream, the blast glowing white-hot inside like the seams
    "Panic": mouth("Panic", [
        (ellipse(0.38, 0.32, bottom_bulge=1.25), [ellipse(0.27, 0.21, bottom_bulge=1.3)], M_BRASS, 0.034, 0.004),
        (ellipse(0.27, 0.21, bottom_bulge=1.3), (), M_MOUTH_HOT, 0.012, 0.0),
    ]),
    # Pass flight: "oooh"
    "Ooh": mouth("Ooh", [
        (ellipse(0.17, 0.19), [ellipse(0.085, 0.1)], M_BRASS, 0.032, 0.004),
        (ellipse(0.085, 0.1), (), M_RECESS, 0.006, 0.0),
    ]),
    # Stick (it just got someone): a wicked grin full of teeth
    "Grin": mouth("Grin", [
        ([(0.24, 0.05), *[(0.24 * math.cos(a), 0.05 - 0.17 * math.sin(a)) for a in [i / 24 * math.pi for i in range(1, 24)]],
          (-0.24, 0.05)], [[(0.19, 0.025), *[(0.19 * math.cos(a), 0.025 - 0.12 * math.sin(a)) for a in
                                               [i / 24 * math.pi for i in range(1, 24)]], (-0.19, 0.025)]],
         M_BRASS, 0.03, 0.004),
        ([(0.19, 0.025), *[(0.19 * math.cos(a), 0.025 - 0.12 * math.sin(a)) for a in [i / 24 * math.pi for i in range(1, 24)]],
          (-0.19, 0.025)], (), M_PORC, 0.022, 0.002),
        *[(rounded_rect(0.012, 0.09, 0.005, cx=x, cz=-0.015), (), M_INK, 0.03, 0.004) for x in (-0.1, -0.035, 0.035, 0.1)],
    ]),
}


# ── Expressions: the poses the game drives (angles in degrees) ───────────────────────────────────────────────────
#   lid      + swings back into the body (open), 0 = half-lidded, −95 closed     slant: + droops the outer corner (sad)
#   brow     raise: + up the body           tilt: + inner end down (angry), − inner end up (worried)
#   gaze     yaw (+ toward the viewer's right), pitch (+ up); pupil scale
POSES = {
    "SMUG": dict(lid=8, slant=-10, raise_=0, tilt=14, yaw=14, pitch=-2, pupil=1.0, mouth="Smirk"),
    "BLINK": dict(lid=-95, slant=-10, raise_=-2, tilt=14, yaw=14, pitch=-2, pupil=1.0, mouth="Smirk"),
    "UH-OH": dict(lid=38, slant=12, raise_=2, tilt=-18, yaw=0, pitch=-4, pupil=0.9, mouth="Grimace"),
    "PANIC": dict(lid=72, slant=0, raise_=4, tilt=-24, yaw=0, pitch=2, pupil=0.7, mouth="Panic"),
    "GOTCHA": dict(lid=14, slant=-18, raise_=-1, tilt=22, yaw=0, pitch=0, pupil=1.0, mouth="Grin"),
    "WHEE": dict(lid=76, slant=0, raise_=5, tilt=-8, yaw=0, pitch=10, pupil=0.72, mouth="Ooh"),
    "LOOK-L": dict(lid=8, slant=-10, raise_=0, tilt=14, yaw=-28, pitch=-2, pupil=1.0, mouth="Smirk"),
    "LOOK-R": dict(lid=8, slant=-10, raise_=0, tilt=14, yaw=28, pitch=-2, pupil=1.0, mouth="Smirk"),
}


def pose(name):
    p = POSES[name]
    for side, s in rig.items():
        sgn = s["sgn"]
        look = Matrix.Rotation(math.radians(p["yaw"]), 3, "Z") @ Matrix.Rotation(math.radians(p["pitch"]), 3, "X")
        target = look @ Vector((0, GAZE_DIST, 0.4))
        local = s["base"].to_3x3().inverted() @ (target - s["base"].to_translation())
        gaze = Vector((0, 1, 0)).rotation_difference(local.normalized()).to_matrix().to_4x4()
        scale = Matrix.Diagonal((p["pupil"], 1, p["pupil"], 1))
        # pupil scale about the eye's out axis keeps it on the sphere closely enough at these sizes
        s["pupil"].matrix_basis = s["base"] @ gaze @ scale
        s["glint"].matrix_basis = s["base"] @ gaze
        slant = Matrix.Rotation(math.radians(p["slant"] * sgn), 4, "Y")
        s["lid"].matrix_basis = s["base"] @ slant @ Matrix.Rotation(math.radians(p["lid"]), 4, "X")
        raise_ = Matrix.Rotation(math.radians(p["raise_"]), 4, s["right"])
        tilt = Matrix.Rotation(math.radians(-p["tilt"] * sgn), 4, s["brow_dir"])
        s["brow"].matrix_basis = raise_ @ tilt
    for k, objs in mouths.items():
        for o in objs:
            o.hide_render = k != p["mouth"]


def stage(st):
    """The ticking stage on the real mesh: seams, lamps, the fuse burnt to the stage, the CRITICAL swell."""
    strength = {"LIT": 0.0, "HOT": 5.0, "CRITICAL": 12.0}[st]
    col = {"LIT": B["EMBER"], "HOT": B["EMBER"], "CRITICAL": WHITE_HOT}[st]
    sb = M_SEAM.node_tree.nodes["Principled BSDF"]
    sb.inputs["Emission Strength"].default_value = strength
    sb.inputs["Emission Color"].default_value = col
    sb.inputs["Base Color"].default_value = col if strength > 0 else B["IRON"]
    lamp = {"LIT": B["SPARK"], "HOT": B["EMBER"], "CRITICAL": B["DETONATE"]}[st]
    lb = M_LAMP.node_tree.nodes["Principled BSDF"]
    lb.inputs["Emission Color"].default_value = lamp
    lb.inputs["Base Color"].default_value = lamp
    lb.inputs["Emission Strength"].default_value = 14.0 if st == "CRITICAL" else 6.0
    root.scale = (1.08,) * 3 if st == "CRITICAL" else (1.0,) * 3
    left = {"LIT": 1.0, "HOT": 0.55, "CRITICAL": 0.22}[st]
    burnt = math.floor((1 - left) * 12)
    tip = None
    for i, seg in enumerate(fuse, start=1):
        seg.hide_render = (12 - i) < burnt
        if not seg.hide_render:
            tip = seg
    bpy.context.view_layer.update()
    if tip:
        top = max((tip.matrix_world @ Vector(c) for c in tip.bound_box), key=lambda v: v.z)
        spark.location = top + Vector((0, 0, 0.03))
        spark_core.location = spark.location


def skin(skin_id):
    """Put a skin's baked maps on Body / Brass / Clamp / Socket (as skins.py's review does); None = Classic Iron."""
    for part in ("Body", "Brass", "Clamp", "Socket"):
        o = parts[part]
        o.data.materials.clear()
        if not skin_id:
            for m in classic_mats[part]:
                o.data.materials.append(m)
            continue
        mat = bpy.data.materials.new(f"{skin_id}_{part}_face")
        mat.use_nodes = True
        nt = mat.node_tree
        b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

        def tex(kind, data):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(os.path.join(SKINS, skin_id, f"{part}_{kind}.png"), check_existing=True)
            if data:
                n.image.colorspace_settings.name = "Non-Color"
            return n

        nt.links.new(tex("COLOR", False).outputs["Color"], b.inputs["Base Color"])
        nt.links.new(tex("ROUGHNESS", True).outputs["Color"], b.inputs["Roughness"])
        nt.links.new(tex("METAL", True).outputs["Color"], b.inputs["Metallic"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex("NORMAL", True).outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        o.data.materials.append(mat)


FACE_TARGET = Vector((0, 0, 0.62))
GAZE_DIST = 6.0  # studs: where the eyes focus in the review shots (a player a few steps away)


def shot(name, res, view="front"):
    if ONLY and name not in ONLY:
        return
    if view == "front":
        aim(orbit(180, 10.4, 1.3), FACE_TARGET, 70)
    elif view == "hero":
        aim(orbit(160, 9.0, 2.2), Vector((0, 0, 0.6)), 70)
    render(name, res)


# ── The review set ───────────────────────────────────────────────────────────────────────────────────────────────
skin(None)
stage("LIT")
pose("SMUG")
shot("hero", 1400, "hero")
for st, ps in (("LIT", "SMUG"), ("HOT", "UH-OH"), ("CRITICAL", "PANIC")):
    stage(st)
    pose(ps)
    shot(f"stage_{st}", 640)
stage("LIT")
for ps in ("BLINK", "GOTCHA", "WHEE", "LOOK-L", "LOOK-R"):
    pose(ps)
    shot(f"pose_{ps}", 512)
pose("SMUG")
for sid in ("Skin_Watermelon", "Skin_Delft", "Skin_Gilded", "Skin_Galaxy", "Skin_Frostbite", "Skin_JackOFuse"):
    skin(sid)
    shot(f"skin_{sid[5:]}", 512)
skin(None)

# Silhouette (front and side): the face never changes the outline (§10.4)
if not ONLY or "silhouette" in ONLY:
    sil = bpy.data.materials.new("Silhouette")
    sil.use_nodes = True
    sil.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    saved = {}
    for o in list(parts.values()) + [o for o in face.objects]:
        saved[o.name] = list(o.data.materials)
        o.data.materials.clear()
        o.data.materials.append(sil)
    ground.hide_render = spark_core.hide_render = True
    world, bg = B["world"], B["bg"]
    for lk in list(world.node_tree.links):
        if lk.to_node == bg:
            world.node_tree.links.remove(lk)
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 1.0
    for l in (B["key"], B["fill"], B["rim"], spark):
        l.hide_render = True
    aim(orbit(-90, 10.5, 0.7))
    render("silhouette", 512)
    for o in list(parts.values()) + [o for o in face.objects]:
        o.data.materials.clear()
        for m in saved[o.name]:
            o.data.materials.append(m)
    ground.hide_render = spark_core.hide_render = False
    world.node_tree.links.new(B["sky"].outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.12
    for l in (B["key"], B["fill"], B["rim"], spark):
        l.hide_render = False

# In context: an R6 Carrier seen from where the Carrier's own camera sits, and from a chasing player
if not ONLY or "context_carrier" in ONLY or "context_chaser" in ONLY:
    r6 = bpy.data.collections.new("R6")
    scene.collection.children.link(r6)
    body_mat = mat_emit("R6", srgb("#B9B4AC"), 0.0)
    body_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
    torso_c = Vector((0, -(1.0 / 2 + 0.4 + R), 0.15))
    for name, size, off in (("Torso", (2, 1, 2), (0, 0, 0)), ("Head", (1.2, 1.2, 1.2), (0, 0, 1.6)),
                            ("ArmL", (1, 1, 2), (-1.5, 0, 0)), ("ArmR", (1, 1, 2), (1.5, 0, 0)),
                            ("LegL", (1, 1, 2), (-0.5, 0, -2)), ("LegR", (1, 1, 2), (0.5, 0, -2))):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        o = obj_from_bm(name, bm, body_mat, r6)
        o.scale = size
        o.location = torso_c + Vector(off)
    ground.location.z = torso_c.z - 3.0
    ground.scale = (3, 3, 3)  # the chaser stands 25 studs back: a bigger backdrop keeps its edge out of frame
    stage("HOT")
    pose("UH-OH")
    ground.rotation_euler = (0, 0, math.radians(180))
    # the Carrier's own third-person camera: behind and above the head, looking past it (the bomb faces it)
    aim((1.6, 9.5, 4.2), torso_c + Vector((0, 0, 0.9)), 50)
    if not ONLY or "context_carrier" in ONLY:
        render("context_carrier", 720)
    aim((-3.5, 24, 2.6), torso_c + Vector((0, 0, 0.4)), 50)  # a chaser 25 studs back
    if not ONLY or "context_chaser" in ONLY:
        render("context_chaser", 720)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Bomb.Face.blend"))
print("DONE", OUT, flush=True)
