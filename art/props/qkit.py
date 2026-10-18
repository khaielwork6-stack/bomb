"""FUSE VALLEY — shared helpers for The Quarry's hero props (docs/maps/QUARRY_BRIEF.md; Asset Bible §1 Quality Bar).

Sits on top of kit.py (same pipeline: bevelled primitives -> procedural Cycles materials -> per-group join -> Smart-UV +
baked PBR maps -> one FBX). Adds what the canyon kit needs:
  • mat_timber: orange-brown toy timber whose grain follows the beam's own axis (rings round it), so diagonal braces
    and posts read as wood from every side; top-lit paint, chipped bare edges, grain in the normal map;
  • mat_sandstone: terracotta sandstone with wavy cream strata, a sandy top, darker seams;
  • mat_cactus: glossy toy-green with a scatter of cream spine dots;
  • beam(): a timber box between two points; loop_tube(): a closed tube along a 3D polyline;
  • sweep(): a (ribbed) tube along a smooth 3D path with domed ends (cactus trunks and arms);
  • hull_rock(): a faceted boulder from the convex hull of jittered points;
  • export(): picks the FBX scale (0.1 when any single part is over 20 studs, see kit.export_fbx);
  • use_gpu(): Cycles on the GPU when one is there (renders and bakes), the CPU otherwise.

Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import math
import random

import bmesh
import bpy
import kit
from kit import Matrix, Vector, srgb

# ── Render / bake device ─────────────────────────────────────────────────────────────────────────────────────────


def use_gpu():
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
            except TypeError:
                continue
            prefs.get_devices()
            devs = [d for d in prefs.devices if d.type == kind]
            if devs:
                for d in prefs.devices:
                    d.use = d.type == kind
                kit.S.scene.cycles.device = "GPU"
                print("CYCLES DEVICE", kind, flush=True)
                return kind
    except Exception as e:  # noqa: BLE001 - any failure just means the CPU
        print("GPU unavailable:", e, flush=True)
    kit.S.scene.cycles.device = "CPU"
    return "CPU"


# ── Materials ────────────────────────────────────────────────────────────────────────────────────────────────────

_timber_cache = {}


def mat_timber(name, paint, hi, bare, dark, axis=(1, 0, 0), chip=0.44, grain=0.2, rough=(0.55, 0.8), bump=0.3):
    """Toy timber: grain as noise-distorted rings round `axis` (world space, since kit.finalize bakes every part into
    world coordinates), a top-lit gradient paint -> hi, dark grain lines, chipped edges showing `bare`."""
    a = Vector(axis).normalized()
    key = (name, round(a.x, 2), round(a.y, 2), round(a.z, 2))
    if key in _timber_cache:
        return _timber_cache[key]
    m, nt, b = kit.new_mat(f"{name}_{len(_timber_cache)}")
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    # rotate the world so the beam's axis lands on X, then stretch along X (long grain)
    rot = Vector((1, 0, 0)).rotation_difference(a).to_matrix().inverted()
    m1 = kit.nd(nt, "ShaderNodeMapping")
    m1.inputs["Rotation"].default_value = rot.to_euler("XYZ")
    nt.links.new(tc.outputs["Object"], m1.inputs["Vector"])
    m2 = kit.nd(nt, "ShaderNodeMapping")
    m2.inputs["Scale"].default_value = (0.35, 2.6, 2.6)
    nt.links.new(m1.outputs["Vector"], m2.inputs["Vector"])
    wave = kit.nd(nt, "ShaderNodeTexWave", wave_type="RINGS", rings_direction="X")
    wave.inputs["Scale"].default_value = 1.6
    wave.inputs["Distortion"].default_value = 9.0
    wave.inputs["Detail"].default_value = 3.0
    wave.inputs["Detail Scale"].default_value = 1.4
    nt.links.new(m2.outputs["Vector"], wave.inputs["Vector"])
    grain_c = kit.map_range(nt, wave.outputs["Fac"], 0.25, 1.0, 0.0, grain)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.2, 1.0, 0.35), paint, hi)
    col = kit.mix_rgb(nt, grain_c, col, dark)
    # plank-to-plank tone drift so neighbouring boards differ
    tone = kit.noise_tex(nt, 0.35, 1.0)
    col = kit.mix_rgb(nt, kit.map_range(nt, tone.outputs["Fac"], 0.3, 0.7, 0.0, 0.25), col, hi)
    noise = kit.noise_tex(nt, 7.0, 6.0)
    edge = kit.edge_mask(nt, 0.05, 3.0)
    ch = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(edge, ch.inputs[0])
    nt.links.new(noise.outputs["Fac"], ch.inputs[1])
    cht = kit.nd(nt, "ShaderNodeMath", operation="GREATER_THAN")
    cht.inputs[1].default_value = chip
    nt.links.new(ch.outputs[0], cht.inputs[0])
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.05, 1.6), col, hi)
    col = kit.mix_rgb(nt, cht.outputs[0], col, bare)
    col = kit.ao_mult(nt, col, 0.7)
    nt.links.new(col, b.inputs["Base Color"])
    rr = kit.nd(nt, "ShaderNodeMath", operation="MAXIMUM")
    nt.links.new(kit.map_range(nt, wave.outputs["Fac"], 0, 1, rough[0], rough[0] + 0.12), rr.inputs[0])
    nt.links.new(kit.map_range(nt, cht.outputs[0], 0, 1, 0.0, rough[1]), rr.inputs[1])
    nt.links.new(rr.outputs[0], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    bn = kit.nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = bump
    bn.inputs["Distance"].default_value = 0.02
    nt.links.new(wave.outputs["Fac"], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    _timber_cache[key] = m
    return m


def mat_sandstone(name, base, hi, cream, seam, strata=1.15, cap=0.55, seed_offset=0.0, rough=(0.62, 0.86), light=None, lines=0.45):
    """Toy sandstone: strata `strata` studs thick (noise-warped), each its own tone between `base` and `light`, top-lit
    to `hi`; a thin cream line on top of about `lines` of the strata; a sandy cream top on up-facing faces (`cap` =
    how far down it reaches); darker blotches, speckle and seams."""
    light = light or tuple(min(1.0, c * 1.35) if i < 3 else c for i, c in enumerate(base))
    m, nt, b = kit.new_mat(name)
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    sep = kit.nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    warp = kit.noise_tex(nt, 0.18, 2.0)
    wamp = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY_ADD")
    wamp.inputs[1].default_value = strata * 1.6
    wamp.inputs[2].default_value = seed_offset - strata * 0.8
    nt.links.new(warp.outputs["Fac"], wamp.inputs[0])
    zw = kit.nd(nt, "ShaderNodeMath", operation="ADD")
    nt.links.new(sep.outputs["Z"], zw.inputs[0])
    nt.links.new(wamp.outputs[0], zw.inputs[1])
    zs = kit.nd(nt, "ShaderNodeMath", operation="DIVIDE")
    zs.inputs[1].default_value = strata
    nt.links.new(zw.outputs[0], zs.inputs[0])
    band_id = kit.nd(nt, "ShaderNodeMath", operation="FLOOR")
    nt.links.new(zs.outputs[0], band_id.inputs[0])
    frac = kit.nd(nt, "ShaderNodeMath", operation="FRACT")
    nt.links.new(zs.outputs[0], frac.inputs[0])
    wn = kit.nd(nt, "ShaderNodeTexWhiteNoise", noise_dimensions="1D")
    nt.links.new(band_id.outputs[0], wn.inputs["W"])
    col = kit.mix_rgb(nt, wn.outputs["Value"], base, light)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.8, 1.0, 0.4), col, hi)
    blot = kit.noise_tex(nt, 1.3, 3.0)
    col = kit.mix_rgb(nt, kit.map_range(nt, blot.outputs["Fac"], 0.35, 0.7, 0.0, 0.2), col, seam)
    # the cream line at the top of some strata
    line = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    line.inputs["From Min"].default_value = 0.9
    line.inputs["From Max"].default_value = 0.94
    nt.links.new(frac.outputs[0], line.inputs["Value"])
    wn2 = kit.nd(nt, "ShaderNodeTexWhiteNoise", noise_dimensions="1D")
    off = kit.nd(nt, "ShaderNodeMath", operation="ADD")
    off.inputs[1].default_value = 17.3
    nt.links.new(band_id.outputs[0], off.inputs[0])
    nt.links.new(off.outputs[0], wn2.inputs["W"])
    pick = kit.nd(nt, "ShaderNodeMath", operation="LESS_THAN")
    pick.inputs[1].default_value = lines
    nt.links.new(wn2.outputs["Value"], pick.inputs[0])
    lm = kit.nd(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(line.outputs["Result"], lm.inputs[0])
    nt.links.new(pick.outputs[0], lm.inputs[1])
    col = kit.mix_rgb(nt, kit.map_range(nt, lm.outputs[0], 0, 1, 0, 0.9), col, cream)
    # a darker seam just under each stratum's top
    seam_l = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    seam_l.inputs["From Min"].default_value = 0.0
    seam_l.inputs["From Max"].default_value = 0.05
    seam_l.inputs["To Min"].default_value = 0.35
    seam_l.inputs["To Max"].default_value = 0.0
    nt.links.new(frac.outputs[0], seam_l.inputs["Value"])
    col = kit.mix_rgb(nt, seam_l.outputs["Result"], col, seam)
    # the sandy cap on up-facing faces
    geo = kit.nd(nt, "ShaderNodeNewGeometry")
    nsep = kit.nd(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], nsep.inputs["Vector"])
    capm = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    capm.inputs["From Min"].default_value = cap
    capm.inputs["From Max"].default_value = cap + 0.2
    nt.links.new(nsep.outputs["Z"], capm.inputs["Value"])
    col = kit.mix_rgb(nt, capm.outputs["Result"], col, cream)
    speck = kit.noise_tex(nt, 18.0, 6.0)
    col = kit.mix_rgb(nt, kit.map_range(nt, speck.outputs["Fac"], 0.62, 0.75, 0.0, 0.22), col, seam)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.08, 1.6), col, hi)
    col = kit.ao_mult(nt, col, 0.75, dist=0.6)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(kit.map_range(nt, speck.outputs["Fac"], 0, 1, rough[0], rough[1]), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    bn = kit.nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.35
    bn.inputs["Distance"].default_value = 0.05
    hsum = kit.nd(nt, "ShaderNodeMath", operation="ADD")
    nt.links.new(seam_l.outputs["Result"], hsum.inputs[0])
    nt.links.new(kit.map_range(nt, speck.outputs["Fac"], 0, 1, 0, 0.5), hsum.inputs[1])
    inv = kit.nd(nt, "ShaderNodeMath", operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(hsum.outputs[0], inv.inputs[1])
    nt.links.new(inv.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_cactus(name, base, hi, dark, spine, dots=4.0, dot_r=0.15):
    """Glossy toy cactus: top-lit green, deep shade in the rib grooves (AO), a scatter of cream spine dots."""
    m, nt, b = kit.new_mat(name)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -0.6, 1.0, 0.45), base, hi)
    tone = kit.noise_tex(nt, 2.5, 2.0)
    col = kit.mix_rgb(nt, kit.map_range(nt, tone.outputs["Fac"], 0.3, 0.7, 0.0, 0.25), col, dark)
    col = kit.mix_rgb(nt, kit.edge_mask(nt, 0.06, 1.4), col, hi)
    tc = kit.nd(nt, "ShaderNodeTexCoord")
    vor = kit.nd(nt, "ShaderNodeTexVoronoi", feature="F1")
    vor.inputs["Scale"].default_value = dots
    vor.inputs["Randomness"].default_value = 0.85
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    dot = kit.nd(nt, "ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    dot.inputs["From Min"].default_value = dot_r
    dot.inputs["From Max"].default_value = dot_r * 0.7
    nt.links.new(vor.outputs["Distance"], dot.inputs["Value"])
    col = kit.mix_rgb(nt, dot.outputs["Result"], col, spine)
    col = kit.ao_mult(nt, col, 0.85, dist=0.3)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(kit.map_range(nt, dot.outputs["Result"], 0, 1, 0.34, 0.6), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    bn = kit.nd(nt, "ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.4
    bn.inputs["Distance"].default_value = 0.02
    nt.links.new(dot.outputs["Result"], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_ore(name):
    """Gold ore nuggets: bright toy gold with hot edges and a little grit in the normal map."""
    return kit.mat_metal(name, srgb("#D88A14"), srgb("#FFC530"), srgb("#FFF4B8"), rough=(0.18, 0.34), metal=0.35, edge_gain=5.0, bump=0.25)


def mat_dark(name, color="#1C1418", hi="#3A2A26"):
    """The inside of a tunnel: near-black with a warm lift toward the light, matte."""
    m, nt, b = kit.new_mat(name)
    col = kit.mix_rgb(nt, kit.up_gradient(nt, -1.0, 1.0, 0.6), srgb(color), srgb(hi))
    col = kit.ao_mult(nt, col, 0.9, dist=1.5)
    nt.links.new(col, b.inputs["Base Color"])
    n = kit.noise_tex(nt, 4.0)
    nt.links.new(kit.map_range(nt, n.outputs["Fac"], 0, 1, 0.8, 0.95), b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    return m


# ── Geometry ─────────────────────────────────────────────────────────────────────────────────────────────────────


def frame_from(d, up_hint=(0, 0, 1)):
    """A rotation matrix whose X column is `d` (local X -> d), Z as close to `up_hint` as possible."""
    x = Vector(d).normalized()
    up = Vector(up_hint)
    if abs(x.dot(up.normalized())) > 0.98:
        up = Vector((0, 1, 0)) if abs(x.y) < 0.9 else Vector((1, 0, 0))
    y = up.cross(x).normalized()
    z = x.cross(y).normalized()
    return Matrix((x, y, z)).transposed()


def beam(name, a, b, w, h, mat_fn, group, bev=0.07, segs=2, up=(0, 0, 1), ext=0.0):
    """A timber beam from point a to b (extended `ext` past each end), section w (across) x h (up)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length + 2 * ext
    rot = frame_from(d, up)
    mid = (a + b) / 2
    return kit.box(name, (L, w, h), tuple(mid), mat_fn(d), group, bev=bev, segs=segs, rot=rot)


def loop_tube(name, pts, radius, mat, group, bres=3, closed=True):
    """A round tube along a 3D polyline (closed by default)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = bres
    cu.use_fill_caps = not closed
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for pt, p in zip(sp.points, pts):
        pt.co = (p[0], p[1], p[2], 1)
    sp.use_cyclic_u = closed
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(mat)
    return kit.link(o, group)


def rounded_rect3(w, l, r, z, steps=4):
    """A rounded rectangle (w along X, l along Y) at height z, CCW, as 3D points."""
    return [(p[0], p[1], z) for p in kit.rounded_rect_pts(w, l, r, steps=steps)]


def _smooth_path(pts, n):
    """Catmull-Rom through 3D control points (open), n samples per span."""
    P = [Vector(p) for p in pts]
    out = []
    for i in range(len(P) - 1):
        p0 = P[i - 1] if i > 0 else P[0] * 2 - P[1]
        p1, p2 = P[i], P[i + 1]
        p3 = P[i + 2] if i + 2 < len(P) else P[-1] * 2 - P[-2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return out


def sweep(name, ctrl, radius, mat, group, segs=24, ribs=0, rib_depth=0.0, n=6, cap_start=True, cap_end=True, cap_rings=5, taper=None):
    """A tube along a smooth path through `ctrl` (3D points), radius `radius` (optionally `taper(t)` scales it, t 0..1
    along the path), with `ribs` rounded ribs `rib_depth` deep, and domed caps (a hemisphere squashed to 0.9)."""
    path = _smooth_path(ctrl, n)
    L = [0.0]
    for i in range(1, len(path)):
        L.append(L[-1] + (path[i] - path[i - 1]).length)
    total = L[-1]
    tans = []
    for i in range(len(path)):
        a = path[max(0, i - 1)]
        c = path[min(len(path) - 1, i + 1)]
        tans.append((c - a).normalized())
    # parallel-transport frames
    t0 = tans[0]
    ref = Vector((1, 0, 0)) if abs(t0.x) < 0.9 else Vector((0, 1, 0))
    u = (ref - t0 * ref.dot(t0)).normalized()
    frames = []
    for i, t in enumerate(tans):
        if i > 0:
            u = (u - t * u.dot(t)).normalized()
        frames.append((u.copy(), t.cross(u).normalized()))

    def rad(theta, t):
        r = radius * (taper(t) if taper else 1.0)
        if ribs:
            # rounded ribs, sharp-ish grooves between them
            r *= 1.0 - rib_depth * (1.0 - abs(math.cos(ribs * theta / 2))) ** 1.4
        return r

    bm = bmesh.new()
    rings = []

    def ring_at(c, uu, vv, r_scale, t):
        ring = []
        for k in range(segs):
            th = 2 * math.pi * k / segs
            r = rad(th, t) * r_scale
            ring.append(bm.verts.new(c + (uu * math.cos(th) + vv * math.sin(th)) * r))
        return ring

    if cap_start:
        c, t = path[0], tans[0]
        uu, vv = frames[0]
        for j in range(cap_rings, 0, -1):
            ang = (math.pi / 2) * j / cap_rings
            rings.append(ring_at(c - t * math.sin(ang) * radius * 0.9 * (taper(0) if taper else 1), uu, vv, math.cos(ang), 0.0))
    for i, c in enumerate(path):
        uu, vv = frames[i]
        rings.append(ring_at(c, uu, vv, 1.0, L[i] / total))
    if cap_end:
        c, t = path[-1], tans[-1]
        uu, vv = frames[-1]
        for j in range(1, cap_rings + 1):
            ang = (math.pi / 2) * j / cap_rings
            rings.append(ring_at(c + t * math.sin(ang) * radius * 0.9 * (taper(1) if taper else 1), uu, vv, max(0.02, math.cos(ang)), 1.0))
    for a, b in zip(rings, rings[1:]):
        for k in range(segs):
            k2 = (k + 1) % segs
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    first, last = rings[0], rings[-1]
    bm.faces.new(list(reversed(first)))
    bm.faces.new(list(last))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = kit.give(kit.mesh_obj(name, bm, group), mat)
    return kit.smooth(o)


def hull_rock(name, size, loc, mat, group, seed, n=16, jitter=0.18, bev=0.18, bev_segs=2, rot_z=0.0, squash_top=0.0, corner=(0.62, 0.8)):
    """A chunky faceted boulder: the convex hull of `n` points jittered round a box of `size`, edges rounded by an
    angle-limited bevel. `squash_top` flattens the upper points (a flatter cap)."""
    rr = random.Random(seed)
    sx, sy, sz = size
    pts = []
    for i in range(n):
        # points spread on the box surface: pick a face, a spot on it, then jitter inward / outward
        ax = rr.choice((0, 1, 2))
        s = rr.choice((-1, 1))
        p = [rr.uniform(-0.5, 0.5), rr.uniform(-0.5, 0.5), rr.uniform(-0.5, 0.5)]
        p[ax] = 0.5 * s
        p = Vector((p[0] * sx, p[1] * sy, p[2] * sz))
        p += Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-1, 1))) * jitter * min(size)
        pts.append(p)
    # the corners, pulled in, so the hull stays blocky
    for cx in (-1, 1):
        for cy in (-1, 1):
            for cz in (-1, 1):
                k = rr.uniform(*corner)
                pts.append(Vector((cx * sx / 2 * k, cy * sy / 2 * k, cz * sz / 2 * (k if cz > 0 else 1.0))))
    # a flat bottom
    for cx in (-1, 1):
        for cy in (-1, 1):
            pts.append(Vector((cx * sx / 2 * rr.uniform(0.7, 0.85), cy * sy / 2 * rr.uniform(0.7, 0.85), -sz / 2)))
    for p in pts:
        p.z = max(p.z, -sz / 2)
        if squash_top and p.z > sz * 0.2:
            p.z = sz * 0.2 + (p.z - sz * 0.2) * (1 - squash_top)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts, edges=bm.edges)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(rot_z, 3, "Z"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc) + Vector((0, 0, sz / 2)), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = kit.give(kit.mesh_obj(name, bm, group), mat)
    if bev:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bev
        m.segments = bev_segs
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(25)
        m.use_clamp_overlap = True
        m.harden_normals = False
    return kit.smooth(o)


def nugget(name, r, loc, mat, group, seed, squash=0.8):
    """A faceted gold nugget: a jittered low icosphere, flat-ish facets with soft edges."""
    rr = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    for v in bm.verts:
        v.co *= rr.uniform(0.86, 1.1)
    bmesh.ops.scale(bm, vec=(1, 1, squash), verts=bm.verts)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(rr.uniform(0, 6.28), 3, Vector((rr.random(), rr.random(), rr.random())).normalized()), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return kit.give(kit.mesh_obj(name, bm, group), mat)


# ── Export ───────────────────────────────────────────────────────────────────────────────────────────────────────


def max_part_extent(parts):
    big = 0.0
    for o in parts.values():
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for v in o.data.vertices:
            lo = Vector(map(min, lo, v.co))
            hi = Vector(map(max, hi, v.co))
        big = max(big, *(hi - lo))
    return big


def export(parts):
    """Export the FBX at 100 units per stud, or 10 when any single part is over 20 studs on an axis (Roblox's
    2048-unit mesh cap). Returns the FBX units per stud for the manifest."""
    big = max_part_extent(parts)
    scale = 0.1 if big > 20.0 else 1.0
    kit.export_fbx(parts, scale=scale)
    ups = 10 if scale == 0.1 else 100
    print("FBX units per stud", ups, "largest part", round(big, 3), flush=True)
    return ups
