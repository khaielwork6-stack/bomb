"""FUSE VALLEY — title word art (Asset Bible §6.2 display type): the big words the game shouts (LAST STAND, BOMBER!,
BOOM! …) as chunky glossy 3D toy letters, the same family as the logo (art/logo), never flat text with a stroke.

Per word:
  1. Blender renders the letters in 3D — Denk One (chunky, with open counters), bevelled and extruded, each letter
     bounced and tilted a touch (seeded: a word always bakes the same). The face carries ONE gradient across the whole
     word (bright cream top → saturated mid → deep bottom) under a clear-coat; the camera looks slightly UP so the
     extruded underside shows as a dark band of depth, like a toy title.
  2. A 2D pass (numpy) wraps the whole word in one even, anti-aliased outline (letters merge into one silhouette, the
     way display titles are drawn) and lays a soft drop shadow under it, then halves the frame for clean edges.
Glow, light streak, sparkles and the shine sweep are NOT baked: the game draws them live (Client/UI/TitleArt) so they
can move.

No AI art: geometry, light and maths only.

Run (Blender 4.5):
  blender -b --factory-startup --python-exit-code 1 --python art/titles/build.py -- [--font <file.ttf>]
  (default font: Denk One from the local Roblox Studio install)
          [--only KEY,KEY]
Out: art/out/Titles/<Key>.png (transparent, ≤1024 px wide) + art/out/Titles/_sheet.png (review sheet)
"""

import json
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Titles")
os.makedirs(OUT, exist_ok=True)
argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
FONT = argv[argv.index("--font") + 1] if "--font" in argv else ""
ARG_FONT = FONT != ""
if not FONT:
    # Denk One (DECISIONS 2026-10-18: chunky but open counters, the owner's pick), from the Roblox Studio install
    import glob

    found = sorted(glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts", "DenkOne-Regular.ttf")))
    FONT = found[-1] if found else ""
ONLY = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None


def srgb(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [a])


def hex8(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)])


# Colour families by meaning (Asset Bible §6.1): face top / mid / bottom, the extruded side top / bottom, the outline.
FAMILIES = {
    "Gold": dict(face=("#FFE466", "#FFAE12", "#FF6200"), side=("#B83E04", "#621C03"), ink="#311003"),
    "Red": dict(face=("#FF9F8A", "#FF3D33", "#C20F22"), side=("#8A0B19", "#4A050D"), ink="#2A060E"),
    "Fire": dict(face=("#FFE36B", "#FF8C12", "#E5261A"), side=("#9C1B0A", "#520C04"), ink="#2C0A04"),
    "Blue": dict(face=("#B8F1FF", "#3DB6FF", "#1A55E0"), side=("#13378F", "#0A1B52"), ink="#09143A"),
    "Green": dict(face=("#D9FF9E", "#6CDB3A", "#16932E"), side=("#126424", "#083312"), ink="#09260E"),
    "Purple": dict(face=("#E9C7FF", "#A95CFF", "#5E1FDB"), side=("#421794", "#1E0848"), ink="#190937"),
}

# key -> (text, family). The three test words first; the rest follow once the look is approved.
WORDS = {
    # moments
    "LastStand": ("LAST STAND", "Gold"),
    "Bomber": ("BOMBER!", "Red"),
    "MegaBomb": ("MEGA BOMB!", "Purple"),
    "ReadTheFace": ("READ THE FACE", "Gold"),
    "LightsOut": ("LIGHTS OUT", "Purple"),
    "TheMole": ("THE MOLE", "Purple"),
    "YoureTheMole": ("YOU'RE THE MOLE", "Red"),
    "Victory": ("VICTORY!", "Gold"),
    "SurvivorsWin": ("SURVIVORS WIN!", "Blue"),
    "BombersWin": ("BOMBERS WIN!", "Red"),
    "LevelUp": ("LEVEL UP!", "Gold"),
    "YouWon": ("YOU WON!", "Gold"),
    "Revived": ("REVIVED!", "Green"),
    "ReviveSaved": ("REVIVE SAVED", "Gold"),
    # callouts
    "Boom": ("BOOM!", "Fire"),
    "DoubleBoom": ("DOUBLE BOOM!", "Fire"),
    "TripleBoom": ("TRIPLE BOOM!", "Red"),
    "Tagged": ("TAGGED!", "Red"),
    "SlamPass": ("SLAM PASS!", "Gold"),
    "Rejected": ("REJECTED!", "Blue"),
    "CloseOne": ("CLOSE ONE!", "Fire"),
    "Defused": ("DEFUSED!", "Green"),
    "ClutchDefuse": ("CLUTCH DEFUSE!", "Gold"),
    "Revenge": ("REVENGE!", "Red"),
    "Betrayal": ("BETRAYAL!", "Purple"),
    "Chain": ("CHAIN!", "Gold"),
    "Dodge": ("DODGE!", "Blue"),
    # crossing beats
    "Go": ("GO!", "Green"),
    "Hurry": ("HURRY!", "Red"),
    "AllClear": ("ALL CLEAR!", "Green"),
    "Safe": ("SAFE!", "Green"),
}

SIZE = 1.0  # letter size (Blender units)
WORD_PX = 2000  # a long word's width in the render; the PNG is halved (≈1000 px plus outline) for clean edges
LETTER_PX = 560  # the letters' height in the render at most (≈280 px in the PNG): short words stay this sharp


# ── scene ───────────────────────────────────────────────────────────────────────────────────────────────────────────
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 96
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = srgb("#6A5A52")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
    sc.world = w
    # a big soft key from above-front (the gloss band across the top of the letters), a warm fill from the front, a
    # cool rim from behind, and a low bounce so the underside depth isn't dead black
    light("AREA", (-1.5, -6, 8), 900, "#FFFFFF", 7.0)  # key: high front, makes the gloss band
    light("AREA", (-7, -10, 1.0), 420, "#FFF3E2", 9.0)  # warm front fill
    light("AREA", (7, -9, 0.0), 260, "#E8EEFF", 7.0)  # cool fill
    light("AREA", (0, 7, 4), 500, "#FFFFFF", 6.0)  # rim
    light("AREA", (0, -6, -6), 45, "#FFD8B0", 8.0)  # a whisper of bounce into the underside


def light(kind, loc, energy, color, size):
    ld = bpy.data.lights.new(kind, kind)
    ld.energy = energy
    ld.color = srgb(color)[:3]
    ld.size = size
    o = bpy.data.objects.new(kind, ld)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)


def face_material(fam, ref, half_h):
    """The face: one vertical gradient across the whole word (world Z through `ref`), clear-coated, with a soft white
    gloss band over the upper third (the "lit plastic" read of display titles)."""
    m = bpy.data.materials.new("Face")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.object = ref
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    fac = nt.nodes.new("ShaderNodeMapRange")
    fac.inputs["From Min"].default_value = -half_h
    fac.inputs["From Max"].default_value = half_h
    nt.links.new(sep.outputs["Z"], fac.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    top, mid, bot = fam["face"]
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.12, srgb(bot)
    els[1].position, els[1].color = 0.9, srgb(top)
    e = els.new(0.5)
    e.color = srgb(mid)
    nt.links.new(fac.outputs["Result"], ramp.inputs["Fac"])
    # gloss band: white mixed in over the top ~third, fading softly
    band = nt.nodes.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.62
    band.inputs["From Max"].default_value = 0.9
    band.inputs["To Min"].default_value = 0.0
    band.inputs["To Max"].default_value = 0.26
    nt.links.new(fac.outputs["Result"], band.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(band.outputs["Result"], mix.inputs[0])
    nt.links.new(ramp.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = (1, 1, 1, 1)
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    # a measured self-glow in the gradient's own colour keeps it vivid and luminous (lighting alone goes pastel);
    # the lights still draw the gloss and the bevel shading on top
    nt.links.new(ramp.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.42
    b.inputs["Roughness"].default_value = 0.3
    b.inputs["Coat Weight"].default_value = 0.75
    b.inputs["Coat Roughness"].default_value = 0.05
    return m


def side_material(fam, ref, half_h, depth_y):
    """The extruded side: the family's deep colour, darker toward the back (local Y), slightly glossy."""
    m = bpy.data.materials.new("Side")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.object = ref
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    fac = nt.nodes.new("ShaderNodeMapRange")
    fac.inputs["From Min"].default_value = -depth_y  # the front face (toward the camera)
    fac.inputs["From Max"].default_value = depth_y  # the back
    nt.links.new(sep.outputs["Y"], fac.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, srgb(fam["side"][0])
    els[1].position, els[1].color = 1.0, srgb(fam["side"][1])
    nt.links.new(fac.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7
    b.inputs["Coat Weight"].default_value = 0.0
    return m


def letter(ch, font):
    cu = bpy.data.curves.new("L_" + ch, "FONT")
    cu.body = ch
    if font:
        cu.font = font
    cu.size = SIZE
    cu.extrude = SIZE * 0.13
    cu.bevel_depth = SIZE * 0.022
    cu.bevel_resolution = 6
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = bpy.data.objects.new("L_" + ch, cu)
    bpy.context.scene.collection.objects.link(o)
    return o


def to_mesh(o):
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def build_word(text, fam, font, seed):
    rng = random.Random(seed)
    ref = bpy.data.objects.new("Ref", None)
    bpy.context.scene.collection.objects.link(ref)
    letters = []
    for ch in text:
        if ch == " ":
            letters.append(None)
            continue
        letters.append(letter(ch, font))
    bpy.context.view_layer.update()
    # lay out: each letter's own width, overlapping a touch (chunky titles sit tight), a space = 0.32 em
    widths = [(o.dimensions.x if o else SIZE * 0.2) for o in letters]
    gap = SIZE * 0.012
    total = sum(widths) + gap * (len(widths) - 1)
    x = -total / 2
    half_h = SIZE * 0.42
    face = face_material(fam, ref, half_h)
    depth = SIZE * 0.13 + SIZE * 0.022
    side = side_material(fam, ref, half_h, depth)
    meshes = []
    for i, (o, w) in enumerate(zip(letters, widths)):
        cx = x + w / 2
        x += w + gap
        if not o:
            continue
        # letters stand up facing the camera (-Y); a small bounce and tilt each, alternating so it reads lively
        tilt = rng.uniform(1.0, 2.6) * (1 if i % 2 == 0 else -1)
        o.rotation_euler = (math.radians(90), math.radians(tilt), 0)
        o.location = Vector((cx, 0, rng.uniform(-0.018, 0.018) * SIZE))
        s = 1 + rng.uniform(-0.02, 0.05)
        o.scale = (s, s, 1)
        m = to_mesh(o)
        m.data.materials.clear()
        m.data.materials.append(face)
        m.data.materials.append(side)
        for p in m.data.polygons:
            # world-space normal: facing the camera (−Y) or bevelled toward it = face, else the extruded side
            n = m.matrix_world.to_3x3() @ p.normal
            p.material_index = 0 if n.y < -0.35 else 1
            p.use_smooth = True
        meshes.append(m)
    return meshes


def render_word(key, text, fam_name, seed):
    reset()
    font = bpy.data.fonts.load(FONT) if FONT else None  # after the reset (it clears every datablock)
    if not font or font.filepath.lower().endswith("bfont.pfb") or "DenkOne" not in os.path.basename(FONT) and not ARG_FONT:
        raise SystemExit(f"title font not loaded ({FONT!r}): refusing to bake in Blender's built-in font")
    print("FONT", key, font.name, os.path.basename(FONT), flush=True)
    fam = FAMILIES[fam_name]
    meshes = build_word(text, fam, font, seed)
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    pts = [m.matrix_world @ Vector(c) for m in meshes for c in m.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    W, H = hi.x - lo.x, hi.z - lo.z
    # camera: orthographic, a little below, looking up ~11° so the extruded underside shows as depth
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.type = "ORTHO"
    margin = 1.2 + 0.9 * H / max(W, H)  # room for the outline, shadow and glow added in 2D
    aspect_h = (H * 1.55 + 1.6 * SIZE) / (W * margin)
    cam_d.ortho_scale = W * margin
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    pitch = math.radians(8)
    dist = 30
    cam.location = centre + Vector((0, -dist * math.cos(pitch), -dist * math.sin(pitch)))
    cam.rotation_euler = (math.radians(90) + pitch, 0, 0)
    sc.camera = cam
    # pixels per unit: as sharp as the letter height allows (LETTER_PX tall), but a long word never wider than
    # WORD_PX (it's halved to ~1000 px) — every word gets the same letter sharpness, no huge renders for short ones
    ppu = min(WORD_PX / W, LETTER_PX / H)
    res_x = int(W * margin * ppu) // 4 * 4
    sc.render.resolution_x = res_x
    sc.render.resolution_y = int(res_x * aspect_h) // 4 * 4
    path = os.path.join(OUT, f"_raw_{key}.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path, fam


# ── 2D pass ─────────────────────────────────────────────────────────────────────────────────────────────────────────
def load_rgba(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return a  # bottom row first (Blender's order), straight alpha, display sRGB


def save_rgba(path, a):
    h, w = a.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels = np.clip(a, 0, 1).astype(np.float32).ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = m[ys, xs]
    return out


def dilate(m, r):
    """Grow a soft mask by a disk of radius r (repeated small disks: Minkowski sums of disks are disks), keeping the
    anti-aliased edge."""
    step = 3
    k = [(dx, dy) for dx in range(-step, step + 1) for dy in range(-step, step + 1) if dx * dx + dy * dy <= step * step + 1]
    out = m.copy()
    done = 0
    while done + step <= r:
        acc = out.copy()
        for dx, dy in k:
            np.maximum(acc, shift(out, dx, dy), out=acc)
        out = acc
        done += step
    rest = r - done
    if rest > 0:
        acc = out.copy()
        for dx in range(-rest, rest + 1):
            for dy in range(-rest, rest + 1):
                if dx * dx + dy * dy <= rest * rest:
                    np.maximum(acc, shift(out, dx, dy), out=acc)
        out = acc
    return out


def holes_of(alpha):
    """The letters' counters (the hole in A, O, R…): background the image border can't reach. Flood-filled at quarter
    resolution (a cell counts as open if any of its pixels is open, so the gaps between letters stay open)."""
    bg = alpha < 0.5
    h, w = bg.shape
    q = 4
    hh, ww = h // q, w // q
    small = bg[: hh * q, : ww * q].reshape(hh, q, ww, q).any(axis=(1, 3))
    ext = np.zeros_like(small)
    ext[0, :], ext[-1, :], ext[:, 0], ext[:, -1] = small[0, :], small[-1, :], small[:, 0], small[:, -1]
    while True:
        grow = ext.copy()
        grow[1:, :] |= ext[:-1, :]
        grow[:-1, :] |= ext[1:, :]
        grow[:, 1:] |= ext[:, :-1]
        grow[:, :-1] |= ext[:, 1:]
        grow &= small
        if (grow == ext).all():
            break
        ext = grow
    full = np.ones_like(bg)
    full[: hh * q, : ww * q] = np.repeat(np.repeat(ext, q, axis=0), q, axis=1)
    return (bg & ~full).astype(np.float32)


def blur(m, r):
    """A cheap gaussian-ish blur: three box passes each way."""
    out = m.copy()
    for _ in range(3):
        for axis in (0, 1):
            c = np.cumsum(np.pad(out, [(r + 1, r) if a == axis else (0, 0) for a in (0, 1)], mode="edge"), axis=axis)
            if axis == 0:
                out = (c[2 * r + 1 :, :] - c[: -2 * r - 1, :]) / (2 * r + 1)
            else:
                out = (c[:, 2 * r + 1 :] - c[:, : -2 * r - 1]) / (2 * r + 1)
    return out


def over(dst, rgb, alpha):
    """Composite a straight-alpha layer (rgb HxWx3 or 3-vector, alpha HxW) over dst (straight RGBA)."""
    a0 = dst[..., 3]
    a1 = alpha
    ao = a1 + a0 * (1 - a1)
    rgb = np.broadcast_to(rgb, dst[..., :3].shape)
    col = (rgb * a1[..., None] + dst[..., :3] * a0[..., None] * (1 - a1[..., None])) / np.maximum(ao[..., None], 1e-6)
    out = np.empty_like(dst)
    out[..., :3] = col
    out[..., 3] = ao
    return out


def finish(key, raw_path, fam):
    a = load_rgba(raw_path)
    h, w = a.shape[:2]
    alpha = a[..., 3]
    rows = np.nonzero(alpha.max(axis=1) > 0.05)[0]
    letter_h = rows[-1] - rows[0]
    r_out = max(6, int(letter_h * 0.064))
    r_hole = max(2, int(letter_h * 0.02))
    # the outline: bold round the outside of the word, only a hairline inside the counters (so the holes in A, O, R
    # stay open and the letters read clearly), in the family's ink
    holes = blur(holes_of(alpha), 2)
    ring = dilate(alpha, r_out) * (1 - holes) + dilate(alpha, r_hole) * holes
    ink = hex8(fam["ink"])
    # drop shadow: the outlined silhouette, pushed down and softened
    sh = blur(shift(ring, 0, -int(letter_h * 0.06)), max(2, int(letter_h * 0.035)))
    canvas = np.zeros_like(a)
    canvas = over(canvas, np.zeros(3), sh * 0.45)
    canvas = over(canvas, ink, ring)
    canvas = over(canvas, a[..., :3], alpha)
    r_in = max(2, int(letter_h * 0.014))
    core = 1 - dilate(1 - alpha, r_in)  # the letters shrunk by r_in
    rim = np.clip(alpha - core, 0, 1)
    canvas = over(canvas, hex8(fam["side"][0]), rim * 0.45)
    # crop to content + a small margin, then halve (2×2 average, premultiplied) for clean edges
    ys = np.nonzero(canvas[..., 3].max(axis=1) > 0.004)[0]
    xs = np.nonzero(canvas[..., 3].max(axis=0) > 0.004)[0]
    pad = 8
    y0, y1 = max(0, ys[0] - pad), min(h, ys[-1] + pad)
    x0, x1 = max(0, xs[0] - pad), min(w, xs[-1] + pad)
    def halve(img, box=None):
        by0, by1, bx0, bx1 = box or (y0, y1, x0, x1)
        c = img[by0:by1, bx0:bx1]
        c = c[: c.shape[0] // 2 * 2, : c.shape[1] // 2 * 2]
        pm = c.copy()
        pm[..., :3] *= pm[..., 3:4]
        sm = (pm[0::2, 0::2] + pm[1::2, 0::2] + pm[0::2, 1::2] + pm[1::2, 1::2]) / 4
        sm[..., :3] /= np.maximum(sm[..., 3:4], 1e-6)
        return sm

    small = halve(canvas)
    out = os.path.join(OUT, f"{key}.png")
    save_rgba(out, small)
    # the face mask (letters only, white): the live shine sweep runs inside it, never over the outline / shadow
    mask = np.ones_like(canvas)
    mask[..., 3] = core
    save_rgba(os.path.join(OUT, f"{key}_mask.png"), halve(mask))
    # the glow: the outlined silhouette grown and blurred wide (white; the game tints it for the colour halo and, in
    # Ink, for the dark backing). It hugs the letters the way a real glow does, unlike a plain ellipse.
    g = blur(dilate(ring, int(letter_h * 0.1)), max(4, int(letter_h * 0.16)))
    g = np.clip(g / max(g.max(), 1e-6), 0, 1) ** 0.85
    gp = int(letter_h * 0.55)
    gy0, gy1 = max(0, y0 - gp), min(h, y1 + gp)
    gx0, gx1 = max(0, x0 - gp), min(w, x1 + gp)
    gl = np.ones_like(canvas)
    gl[..., 3] = g
    glow_img = halve(gl, (gy0, gy1, gx0, gx1))
    save_rgba(os.path.join(OUT, f"{key}_glow.png"), glow_img)
    # where the word sits inside the glow frame (fractions), for the game to line them up
    ww, wh = (x1 - x0), (y1 - y0)
    meta_path = os.path.join(OUT, "meta.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta[key] = {
        "text": WORDS[key][0],
        "family": WORDS[key][1],
        "size": [int(small.shape[1]), int(small.shape[0])],
        "glowScale": [round((gx1 - gx0) / ww, 3), round((gy1 - gy0) / wh, 3)],
    }
    json.dump(meta, open(meta_path, "w"), indent=1, sort_keys=True)
    print(
        "GLOW",
        key,
        "scale=%.3f,%.3f" % ((gx1 - gx0) / ww, (gy1 - gy0) / wh),
        "centre_offset=%.3f,%.3f" % ((((gx0 + gx1) / 2) - ((x0 + x1) / 2)) / ww, -(((gy0 + gy1) / 2) - ((y0 + y1) / 2)) / wh),
        flush=True,
    )
    os.remove(raw_path)
    print("TITLE", key, small.shape[1], "x", small.shape[0], flush=True)
    return out


def main():
    if not FONT:
        print("WARNING: no --font given, using Blender's default (not the game's display face)", flush=True)
    for i, (key, (text, fam)) in enumerate(WORDS.items()):
        if ONLY and key not in ONLY:
            continue
        raw, f = render_word(key, text, fam, seed=1000 + i * 7)
        finish(key, raw, f)


main()
