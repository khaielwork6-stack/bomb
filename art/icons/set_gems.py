"""FUSE VALLEY icons — set Gems: Gem, GemPile, GemHeap, GemBag, GemChest (the Gems currency; art/ref/gems/
fv_gems_reference.png is a style reference only — every icon here is real geometry).

The gem is a flat-shaded brilliant cut whose `ruby` material is self-lit and toon-shaded: an emissive ramp from a hot
yellow core (each gem's own "core" point, low and in front, so every gem in a heap glows from its own heart) out to
deep ruby, sampled partly per facet and slid hotter or deeper by a random value per facet so neighbours always differ,
a hard pink-red flash on facets turned to the house key light, and thin bright facet edges from a shader bevel — so
the cut reads crisp at 20 px. Heaps are gems scattered over a dome (`mound`) on a dark glowing bed (`filler`); a few
camera-facing glints sparkle on the front gems.
"""

import math
import random

import bmesh
import bpy
import lib
from lib import box, glossy, gold, icon, prism, srgb
from mathutils import Matrix, Vector

# ── Palette ─────────────────────────────────────────────────────────────────────────────────────────────────────
CORE = srgb("#FFE65C")
HOT = srgb("#FFB40C")
EMBER = srgb("#FF5210")
RUBY = srgb("#EA1020")
DEEP = srgb("#8E0020")
RUBY_BASE = srgb("#4A0410")
FLASH = srgb("#FF5A5A")
KEY = (-0.35, -0.45, 0.82)  # the house key light direction (lib._lights), for the toon flash
KEY_FROM, KEY_FLASH = 0.86, 0.7
EDGE = srgb("#FFC0A8")
EDGE_R, EDGE_LIFT = 0.025, 0.5  # facet-edge line: shader bevel radius (object units), strength
CORE_WORLD = (0.0, -0.35, -0.22)  # default glow centre: in front of and below the gem's middle (gem units)
VARY = 0.3  # per-gem ramp shift range
FLAT = 0.35  # how much of the glow is sampled per facet rather than per pixel
BURLAP = srgb("#A27842")
BURLAP_DK = srgb("#7A5630")
ROPE = srgb("#B5803A")
WOOD = srgb("#7A3C1E")
WOOD_DK = srgb("#3E1A0C")
HOLE = srgb("#24140C")
BED = srgb("#8A0A22")


# ── Materials ───────────────────────────────────────────────────────────────────────────────────────────────────
def _math(N, L, op, a, b, c=None):
    """A Math node; each input is a constant or a node output socket."""
    n = N.new("ShaderNodeMath")
    n.operation = op
    for i, v in enumerate((a, b, c)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            L.new(v, n.inputs[i])
    return n.outputs["Value"]


def ruby(name="Ruby", reach=1.2, glow=1.05):
    """The gem material (see the module doc): a self-lit, toon-shaded ruby. The glow centre is each gem's "core"
    property (object space, set by `gem`); `reach` is the distance at which the colour has fallen to deep ruby. The colour is emission, so it stays saturated
    under the studio lights; the "highlight" is a hard toon flash on the facets that face the house key light."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]  # unlinked; the outline hull reads its base colour
    b.inputs["Base Color"].default_value = RUBY_BASE
    tc = N.new("ShaderNodeTexCoord")
    geo = N.new("ShaderNodeNewGeometry")
    # the glow is partly sampled at each facet's centre ("fc", object space) so facets read as planes of colour
    fcn = N.new("ShaderNodeAttribute")
    fcn.attribute_name = "fc"
    pos = N.new("ShaderNodeMix")
    pos.data_type = "VECTOR"
    pos.inputs["Factor"].default_value = FLAT
    L.new(tc.outputs["Object"], pos.inputs[4])
    L.new(fcn.outputs["Vector"], pos.inputs[5])
    cor = N.new("ShaderNodeAttribute")
    cor.attribute_type = "OBJECT"
    cor.attribute_name = "core"
    d = N.new("ShaderNodeVectorMath")
    d.operation = "DISTANCE"
    L.new(cor.outputs["Vector"], d.inputs[1])
    L.new(pos.outputs[1], d.inputs[0])
    # a random value per face ("facet") slides each facet along the ramp (hotter or deeper, never muddier)
    at = N.new("ShaderNodeAttribute")
    at.attribute_name = "facet"
    fct = at.outputs["Fac"]
    t = _math(N, L, "ADD", _math(N, L, "DIVIDE", d.outputs["Value"], reach), _math(N, L, "MULTIPLY_ADD", fct, 0.42, -0.2))
    # and each gem in a heap burns a little hotter or deeper than its neighbours
    oi = N.new("ShaderNodeObjectInfo")
    t = _math(N, L, "ADD", t, _math(N, L, "MULTIPLY_ADD", oi.outputs["Random"], VARY, -VARY / 2))
    ramp = N.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.0, CORE
    cr.elements[1].position, cr.elements[1].color = 1.0, DEEP
    for p, col in ((0.14, HOT), (0.37, EMBER), (0.64, RUBY)):
        cr.elements.new(p).color = col
    L.new(t, ramp.inputs["Fac"])
    # shade: a little random per facet, darker toward the silhouette
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    shade = _math(N, L, "MULTIPLY_ADD", lw.outputs["Facing"], -0.22, _math(N, L, "MULTIPLY_ADD", fct, 0.2, 0.82))
    mul = N.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    L.new(ramp.outputs["Color"], mul.inputs[6])
    L.new(shade, mul.inputs[7])
    # flash: the facets turned to the key light (hard-edged), plus a few random sparkling ones
    kd = N.new("ShaderNodeVectorMath")
    kd.operation = "DOT_PRODUCT"
    kd.inputs[1].default_value = Vector(KEY).normalized()
    L.new(geo.outputs["Normal"], kd.inputs[0])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = KEY_FROM
    mr.inputs["From Max"].default_value = 1.0
    mr.inputs["To Max"].default_value = KEY_FLASH
    L.new(kd.outputs["Value"], mr.inputs["Value"])
    flash = _math(N, L, "ADD", mr.outputs["Result"], _math(N, L, "MULTIPLY", _math(N, L, "POWER", fct, 8.0), 0.45))
    # facet edges: where the shader-bevelled normal leaves the flat facet normal, a thin bright line (crisp cut)
    bv = N.new("ShaderNodeBevel")
    bv.samples = 8
    bv.inputs["Radius"].default_value = EDGE_R
    ed = N.new("ShaderNodeVectorMath")
    ed.operation = "DOT_PRODUCT"
    L.new(bv.outputs["Normal"], ed.inputs[0])
    L.new(geo.outputs["Normal"], ed.inputs[1])
    er = N.new("ShaderNodeMapRange")
    er.inputs["From Min"].default_value = 0.995
    er.inputs["From Max"].default_value = 0.94
    er.inputs["To Max"].default_value = EDGE_LIFT
    L.new(ed.outputs["Value"], er.inputs["Value"])
    addc = N.new("ShaderNodeMix")
    addc.data_type = "RGBA"
    addc.blend_type = "ADD"
    addc.clamp_result = True
    addc.inputs[7].default_value = FLASH
    L.new(flash, addc.inputs["Factor"])
    L.new(mul.outputs[2], addc.inputs[6])
    edge = N.new("ShaderNodeMix")
    edge.data_type = "RGBA"
    edge.inputs[7].default_value = EDGE
    L.new(er.outputs["Result"], edge.inputs["Factor"])
    L.new(addc.outputs[2], edge.inputs[6])
    em = N.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = glow
    L.new(edge.outputs[2], em.inputs["Color"])
    out = next(n for n in N if n.type == "OUTPUT_MATERIAL")
    L.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def burlap(name="Burlap"):
    """Woven sack cloth: two crossed wave bands (warp and weft) bump the surface and darken the gaps."""
    m = glossy(name, BURLAP, 0.85, coat=0.0)
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    waves = []
    for axis in ("X", "Z"):
        w = N.new("ShaderNodeTexWave")
        w.wave_type = "BANDS"
        w.bands_direction = axis
        w.inputs["Scale"].default_value = 10.0
        w.inputs["Distortion"].default_value = 0.6
        w.inputs["Detail"].default_value = 1.0
        L.new(tc.outputs["Object"], w.inputs["Vector"])
        waves.append(w)
    add = N.new("ShaderNodeMath")
    add.operation = "MAXIMUM"
    L.new(waves[0].outputs["Fac"], add.inputs[0])
    L.new(waves[1].outputs["Fac"], add.inputs[1])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.18
    bump.inputs["Distance"].default_value = 0.02
    L.new(add.outputs["Value"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], b.inputs["Normal"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = BURLAP_DK
    mix.inputs[7].default_value = BURLAP
    L.new(add.outputs["Value"], mix.inputs["Factor"])
    L.new(mix.outputs[2], b.inputs["Base Color"])
    return m


# ── Gem geometry ────────────────────────────────────────────────────────────────────────────────────────────────
CUTS = {
    # table radius, crown height, girdle half-thickness, pavilion depth, table sides, girdle verts per table side,
    # girdle jaggedness (random radius change, so pile gems aren't all perfect circles)
    "brilliant": (0.56, 0.42, 0.035, 1.12, 8, 2, 0.0),
    "chunky": (0.58, 0.44, 0.05, 0.9, 5, 2, 0.16),
}


def gem_mesh(cut, seed=0):
    tr, ch, gh, pd, n, k, jag = CUTS[cut]
    rng = random.Random(seed)
    bm = bmesh.new()
    gn = n * k
    tab = [bm.verts.new((math.cos(2 * math.pi * i / n) * tr, math.sin(2 * math.pi * i / n) * tr, ch)) for i in range(n)]
    off = -math.pi / n if k == 2 else math.pi / n
    rad = [1.0 + rng.uniform(-jag, jag * 0.4) for _ in range(gn)]
    gt = [bm.verts.new((math.cos(2 * math.pi * j / gn + off) * rad[j], math.sin(2 * math.pi * j / gn + off) * rad[j], gh)) for j in range(gn)]
    gb = [bm.verts.new((v.co.x, v.co.y, -gh)) for v in gt]
    cul = bm.verts.new((0, 0, -pd))
    bm.faces.new(tab)
    for i in range(n):
        a, c = tab[i], tab[(i + 1) % n]
        if k == 2:
            g0, g1, g2 = gt[2 * i], gt[2 * i + 1], gt[(2 * i + 2) % gn]
            bm.faces.new((a, g0, g1))
            bm.faces.new((a, g1, c))
            bm.faces.new((c, g1, g2))
        else:
            bm.faces.new((a, gt[i - 1], gt[i]))
            bm.faces.new((a, gt[i], c))
    for j in range(gn):
        k2 = (j + 1) % gn
        bm.faces.new((gt[j], gb[j], gb[k2], gt[k2]))
        bm.faces.new((gb[k2], gb[j], cul))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lay = bm.faces.layers.float.new("facet")
    fc = bm.faces.layers.float_vector.new("fc")
    for f in bm.faces:
        f[lay] = rng.random()
        f[fc] = f.calc_center_median()
    return bm


def gem(name, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, cut="chunky", seed=0, outline=0.035, normal=None, twist=0.0, core=None):
    """A gem with its own origin at `loc` (so the ruby glow sits in its heart). `rot` is XYZ degrees; at (0, 0, 0)
    the table faces +Z. With `normal`, the table faces that direction instead (turned `twist` degrees about it).
    The glow centre is `core` (object space) or, by default, CORE_WORLD turned into the gem's own frame — so every gem
    in a heap glows from low and in front, whichever way it lies."""
    bm = gem_mesh(cut, seed)
    o = lib._obj(name, bm, mat)
    s = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    if normal is not None:
        q = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_matrix().to_4x4()
        q = q @ Matrix.Rotation(math.radians(twist), 4, "Z")
    else:
        q = Matrix.Rotation(math.radians(rot[2]), 4, "Z") @ Matrix.Rotation(math.radians(rot[1]), 4, "Y") @ Matrix.Rotation(math.radians(rot[0]), 4, "X")
    o.matrix_world = Matrix.Translation(Vector(loc)) @ q @ Matrix.Diagonal((*s, 1.0))
    o["core"] = list(core) if core is not None else list(q.to_3x3().inverted() @ Vector(CORE_WORLD))
    return lib.finish(o, 0, smooth=False, outline=outline)


def mound_z(r, R, H, power=0.7):
    """Height of a heap's dome at radius r (a lower `power` gives a flatter, fuller top with steeper sides)."""
    return H * max(0.0, 1 - (r / R) ** 2) ** power


def mound(prefix, mat, ctr, R, H, size, seed, spacing=1.55, back=0.3, toward=0.25, outline=0.03, sy=1.0, jitter=0.55, clip=None, power=0.7):
    """Heap gems over a dome (radius R, height H, centred on `ctr`; `sy` squashes it in depth), tables turned out of
    the surface and partly toward the viewer. Only the front and the sides are filled (`back`: how far behind the
    centre line gems still go, as a fraction of R) — the back is never seen. `clip` (half-width, front y) keeps the
    gem centres inside a container's walls. Returns the gem objects."""
    rng = random.Random(seed)
    c = Vector(ctr)
    pts = []
    for _ in range(4000):
        a = rng.uniform(0, 2 * math.pi)
        r = R * math.sqrt(rng.random())
        x, y = math.cos(a) * r, math.sin(a) * r * sy
        if y > back * R:
            continue
        if clip and (abs(x) > clip[0] or c.y + y < clip[1]):
            continue
        sc = size * rng.uniform(0.82, 1.12)
        p = c + Vector((x, y, mound_z(r, R, H, power)))
        if all((p - q).length > (sc + s2) * spacing * 0.5 for q, s2 in pts):
            pts.append((p, sc))
    objs = []
    for i, (p, sc) in enumerate(pts):
        r = math.hypot(p.x - c.x, (p.y - c.y) / sy)
        k = power * H * max(1e-3, 1 - (r / R) ** 2) ** (power - 1) * 2 * r / R**2 if r < R * 0.999 else 3.0
        n = Vector(((p.x - c.x) / max(r, 1e-4) * k, (p.y - c.y) / max(r, 1e-4) * k, 1.0)).normalized()
        n = (n.lerp(Vector((0, -1, 0.35)).normalized(), toward) + Vector([rng.uniform(-jitter, jitter) for _ in range(3)])).normalized()
        objs.append(gem(f"{prefix}{i}", mat, loc=p, scale=sc, seed=seed * 100 + i, normal=n, twist=rng.uniform(0, 360), outline=outline))
    return objs


def filler(name, ctr, R, H, sy=1.0, drop=0.12, power=0.7):
    """The dark glowing bed under a heap, so the gaps between gems read as deeper gems, never as background."""
    prof = [(0.0, mound_z(0, R, H, power) - drop)]
    for i in range(1, 17):
        r = R * i / 16 * 0.98
        prof.append((r, mound_z(r, R, H, power) - drop))
    prof.append((R * 0.98, -drop))
    prof.append((0.0, -drop))
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=48, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.scale(bm, vec=(1, sy, 1), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(ctr), verts=bm.verts)
    return lib.finish(lib._obj(name, bm, emissive("Bed", BED, 1.0)), 0, outline=0)


def catmull(pts, n=8):
    """Densify an open control polyline with a Catmull-Rom spline."""
    p = [Vector(x) for x in pts]
    out = []
    for i in range(len(p) - 1):
        p0, p1, p2, p3 = p[max(i - 1, 0)], p[i], p[i + 1], p[min(i + 2, len(p) - 1)]
        for j in range(n):
            t = j / n
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t**3))
    out.append(p[-1].copy())
    return out


def sweep(name, pts, r, mat, n=12, closed=False, outline=0.02, rfun=None):
    """A round tube along a polyline (rounded caps when open), as a mesh so it takes a hull outline."""
    pts = [Vector(x) for x in pts]
    m = len(pts)
    tans = []
    for i in range(m):
        a = pts[(i - 1) % m] if closed else pts[max(i - 1, 0)]
        c = pts[(i + 1) % m] if closed else pts[min(i + 1, m - 1)]
        tans.append((c - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    b = (ref - tans[0] * ref.dot(tans[0])).normalized()
    frames = []
    for t in tans:
        b = (b - t * b.dot(t)).normalized()
        frames.append((b, t.cross(b)))
    bm = bmesh.new()

    def rad(i):
        return r * (rfun(i / (m - 1)) if rfun else 1.0)

    rings = [[bm.verts.new(p + bb * math.cos(2 * math.pi * j / n) * rad(i) + nn * math.sin(2 * math.pi * j / n) * rad(i)) for j in range(n)] for i, (p, (bb, nn)) in enumerate(zip(pts, frames))]

    def bridge(a, c):
        for j in range(n):
            bm.faces.new((a[j], a[(j + 1) % n], c[(j + 1) % n], c[j]))

    for i in range(m - 1):
        bridge(rings[i], rings[i + 1])
    if closed:
        bridge(rings[-1], rings[0])
    else:
        for end, sgn in ((0, -1), (m - 1, 1)):
            p, t = pts[end], tans[end] * sgn
            prev = rings[end]
            for j in (1, 2, 3):
                phi = j / 4 * math.pi / 2
                cur = [bm.verts.new(p + (v.co - p) * math.cos(phi) + t * math.sin(phi) * rad(end)) for v in rings[end]]
                bridge(prev, cur)
                prev = cur
            cv = bm.verts.new(p + t * rad(end))
            for j in range(n):
                bm.faces.new((prev[j], prev[(j + 1) % n], cv))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=outline)


def rope(prefix, path, r, mat, twists=3.0, closed=False, outline=0.02):
    """A three-strand twisted rope along a path: three thinner tubes wound round the centre line."""
    c = catmull(path, 10) if not closed else [Vector(x) for x in path]
    m = len(c)
    length = sum((c[i + 1] - c[i]).length for i in range(m - 1)) + ((c[0] - c[-1]).length if closed else 0)
    turns = twists * length / (2 * math.pi * r * 3)
    ref = Vector((0, 0, 1))
    out = []
    for k in range(3):
        pts = []
        acc = 0.0
        for i in range(m):
            t = (c[(i + 1) % m] - c[i - 1]).normalized() if closed else (c[min(i + 1, m - 1)] - c[max(i - 1, 0)]).normalized()
            if i:
                acc += (c[i] - c[i - 1]).length
            b = ref - t * ref.dot(t)
            b = b.normalized() if b.length > 1e-4 else Vector((1, 0, 0))
            nn = t.cross(b)
            a = 2 * math.pi * (k / 3 + turns * acc / max(length, 1e-4))
            pts.append(c[i] + (b * math.cos(a) + nn * math.sin(a)) * r * 0.55)
        out.append(sweep(f"{prefix}{k}", pts, r * 0.58, mat, n=10, closed=closed, outline=outline))
    return out


def pivot(objs, mat4, p):
    t = Matrix.Translation(Vector(p))
    m = t @ mat4 @ t.inverted()
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def emissive(name, color, strength=1.0):
    """Pure emission (the Principled node stays, unlinked, for the hull's base colour)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = color
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def twinkle(name, loc, r):
    """A camera-facing four-point glint (added after the tilt, in front of everything)."""
    prism(name, lib.star_pts(4, r, r * 0.22), 0.02, emissive("Glint", srgb("#FFFFFF"), 1.0), loc=loc, bevel=0.003, outline=0)


def glints(gems, count, seed):
    """After the tilt: a glint on a few of the front-most gems, near each one's upper-left (where the key light hits)."""
    rng = random.Random(seed)
    front = sorted(gems, key=lambda o: o.matrix_world.translation.y)[: max(count * 3, 1)]
    rng.shuffle(front)
    picked = []
    for o in front:
        if len(picked) < count and all((o.matrix_world.translation - q.matrix_world.translation).length > 0.6 for q in picked):
            picked.append(o)
    for i, o in enumerate(picked):
        sc = o.matrix_world.to_scale().x
        p = o.matrix_world.translation
        twinkle(f"Glint{i}", (p.x - 0.22 * sc, -6.0, p.z + 0.2 * sc), 0.32 * sc)


# ── Icons ───────────────────────────────────────────────────────────────────────────────────────────────────────
@icon
def Gem():
    gem("Gem", ruby(reach=1.65), cut="brilliant", seed=3, outline=0.045, core=(0.0, -0.6, -0.2))
    lib.group_tilt(-12, 14)
    twinkle("Glint", (-0.36, -3.0, 0.36), 0.2)


@icon
def GemPile():
    m = ruby()
    gem("G0", m, loc=(-0.7, 0.1, -0.1), rot=(62, -30, -20), scale=0.84, seed=1)
    gem("G1", m, loc=(0.72, 0.1, -0.12), rot=(40, 28, 30), scale=0.82, seed=2)
    gem("G2", m, loc=(0.0, 0.5, 0.62), rot=(28, -6, 10), scale=0.88, seed=3)
    gem("G3", m, loc=(0.04, -0.55, -0.34), rot=(70, 4, -8), scale=0.62, seed=4)
    lib.group_tilt(-10, 8)
    twinkle("Glint", (-0.48, -6.0, 0.78), 0.2)


def spill(prefix, mat, spots, seed):
    """Loose gems lying in front: (x, y, size) each, tables tipped every which way but mostly up and out."""
    rng = random.Random(seed)
    out = []
    for i, (x, y, sc) in enumerate(spots):
        n = Vector((rng.uniform(-0.7, 0.7), rng.uniform(-1.0, -0.4), rng.uniform(0.3, 1.0)))
        out.append(gem(f"{prefix}{i}", mat, loc=(x, y, sc * 0.5), scale=sc, seed=seed * 50 + i, normal=n, twist=rng.uniform(0, 360)))
    return out


@icon
def GemHeap():
    m = ruby()
    gs = mound("H", m, (0, 0, 0), 1.5, 1.7, 0.46, seed=7, spacing=1.12, outline=0.03, power=1.25, sy=0.8)
    filler("Bed", (0, 0.3, 0), 1.0, 1.62, drop=0.35, power=1.25, sy=0.5)
    gs += spill("S", m, [(-0.2, -1.12, 0.36), (0.5, -1.1, 0.34)], seed=8)
    lib.group_tilt(-10, 12)
    glints(gs, 3, 7)


SACK = [(0.0, 0.0), (0.5, 0.0), (0.84, 0.08), (1.0, 0.28), (0.98, 0.5), (0.84, 0.7), (0.62, 0.85), (0.5, 0.94), (0.48, 1.0),
        (0.56, 1.1), (0.72, 1.22), (0.82, 1.32), (0.8, 1.38), (0.68, 1.36), (0.54, 1.3), (0.0, 1.26)]
SACK_DEPTH = 0.84  # the sack is a little flatter front to back


def sack_front(z, off=0.0):
    """The y of the sack's front surface at height z (below the neck), pushed `off` further out."""
    for (r0, z0), (r1, z1) in zip(SACK[1:9], SACK[2:10]):
        if z0 <= z <= z1:
            return -((r0 + (r1 - r0) * (z - z0) / (z1 - z0)) * SACK_DEPTH + off)
    return -off


def sack(name, mat):
    """The burlap sack: a lathe with a pinched neck and a wide, rolled, wavy lip, then gathered folds and soft lumps."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in SACK]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=72, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    for v in bm.verts:
        th = math.atan2(v.co.y, v.co.x)
        z = v.co.z
        neck = max(0.0, 1 - abs(z - 0.98) / 0.3)
        lip = max(0.0, (z - 1.2) / 0.2)
        k = 1 + 0.08 * math.sin(11 * th + 0.4) * neck + 0.04 * math.sin(3 * th + 1.0) * math.sin(z * 3.5) * (1 - neck)
        v.co.x *= k
        v.co.y *= k * SACK_DEPTH
        v.co.z += 0.05 * math.sin(6 * th + 0.8) * lip
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return lib.finish(lib._obj(name, bm, mat), 0, outline=0.035, sub=1)


@icon
def GemBag():
    m = ruby()
    sack("Sack", burlap())
    rmat = glossy("Rope", ROPE, 0.65, coat=0.1)
    nz = 0.97
    ring = [(math.cos(2 * math.pi * i / 56) * 0.53, math.sin(2 * math.pi * i / 56) * 0.53 * 0.84, nz + 0.015 * math.sin(4 * math.pi * i / 56)) for i in range(56)]
    rope("Tie", ring, 0.085, rmat, closed=True)
    # the knot at the front and two hanging ends with tassels, lying on the sack's belly
    kz = nz - 0.03
    lib.sphere("Knot", 0.14, rmat, loc=(0.0, sack_front(kz, 0.12), kz), scale=(1.15, 0.8, 1.0))
    for sd, (x1, z1, x2, z2) in ((-1, (-0.13, 0.68, -0.2, 0.42)), (1, (0.14, 0.66, 0.25, 0.37))):
        path = [(0.03 * sd, sack_front(nz - 0.08, 0.12), nz - 0.08), (x1, sack_front(z1, 0.07), z1), (x2, sack_front(z2, 0.07), z2)]
        rope(f"End{sd}", path, 0.07, rmat, twists=2.5)
        tip = Vector((x2, sack_front(z2 - 0.13, 0.08), z2))
        for k in range(7):
            a = 2 * math.pi * k / 7
            off = Vector((math.cos(a) * 0.04, math.sin(a) * 0.03, 0))
            sweep(f"Strand{sd}{k}", [tip + off * 0.6, tip + off * 1.5 + Vector((0, 0, -0.14)), tip + off * 2.0 + Vector((0, 0, -0.27))], 0.028, rmat, n=8, outline=0.012)
        lib.torus(f"Wrap{sd}", 0.075, 0.025, rmat, loc=tip + Vector((0, 0, -0.02)), outline=0.012, seg=24, mseg=8)
    gs = mound("T", m, (0, 0.06, 1.26), 0.54, 0.62, 0.31, seed=11, sy=0.8, spacing=1.02, toward=0.4, jitter=0.3)
    filler("Bed", (0, 0.04, 1.24), 0.56, 0.44, sy=0.82)
    spill("S", m, [(-0.9, -0.66, 0.3), (-1.12, -0.3, 0.22), (0.9, -0.62, 0.32), (1.12, -0.26, 0.22), (0.42, -0.98, 0.24)], seed=12)
    lib.group_tilt(-14, 10)
    glints(gs, 2, 11)


@icon
def GemChest():
    W, D, H = 1.8, 1.1, 0.95
    m = ruby()
    wood = glossy("Wood", WOOD, 0.5, coat=0.2)
    wood_dk = glossy("WoodDk", WOOD_DK, 0.7, coat=0.0)
    g = gold("Trim")
    box("Core", (W - 0.08, D - 0.08, H - 0.04), wood_dk, loc=(0, 0, H / 2), outline=0)
    for row in range(3):
        zc = H * (row + 0.5) / 3
        box(f"Plank{row}", (W - 0.02, D - 0.02, H / 3 - 0.035), wood, loc=(0, 0, zc), bevel=0.035, outline=0.012)
    t = 0.18
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"Post{sx}{sy}", (t, t, H + 0.04), g, loc=(sx * (W / 2 - t / 2 + 0.02), sy * (D / 2 - t / 2 + 0.02), H / 2), bevel=0.04, outline=0.018)
            for z in (0.2, H - 0.22):
                lib.sphere(f"Rv{sx}{sy}{z}", 0.04, g, loc=(sx * (W / 2 - t / 2 + 0.02), sy * (D / 2 + 0.035), z), outline=0)
    for sy in (-1, 1):
        box(f"RimX{sy}", (W + 0.04, 0.12, 0.14), g, loc=(0, sy * (D / 2 + 0.01), H - 0.05), bevel=0.035, outline=0.018)
        box(f"BaseX{sy}", (W + 0.04, 0.12, 0.12), g, loc=(0, sy * (D / 2 + 0.01), 0.06), bevel=0.035, outline=0.018)
    for sx in (-1, 1):
        box(f"RimY{sx}", (0.12, D + 0.04, 0.14), g, loc=(sx * (W / 2 + 0.01), 0, H - 0.05), bevel=0.035, outline=0.018)
    # lock plate with keyhole
    plate = [(-0.18, -0.22), (0.18, -0.22), (0.23, 0.08), (0.18, 0.24), (-0.18, 0.24), (-0.23, 0.08)]
    prism("Lock", plate, 0.07, g, loc=(0, -D / 2 - 0.05, H - 0.32), bevel=0.03, outline=0.018)
    kh = [(math.cos(math.pi * i / 10) * 0.06, 0.03 + math.sin(math.pi * i / 10) * 0.06) for i in range(-2, 13)] + [(-0.045, -0.12), (0.045, -0.12)]
    kh = [kh[-1]] + kh[:-1]
    prism("Keyhole", kh, 0.06, glossy("Hole", HOLE, 0.6), loc=(0, -D / 2 - 0.09, H - 0.32), bevel=0.008, outline=0)
    # the barrel lid, built closed, then swung open about the back hinge
    R = D / 2
    before = set(bpy.context.scene.objects)
    half = [(math.cos(math.pi * i / 24) * R, math.sin(math.pi * i / 24) * R) for i in range(25)]
    prism("LidShell", half, W - 0.04, wood, rot=[("Z", 90)], loc=(0, 0, H), bevel=0.03, outline=0.018)
    for i in range(4):
        box(f"LidPlank{i}", (W - 0.26, (D - 0.24) / 4 - 0.03, 0.04), wood_dk, loc=(0, -(D - 0.24) / 2 + (i + 0.5) * (D - 0.24) / 4, H - 0.01), bevel=0.012, outline=0)

    def arc_band(name, r_in, r_out, width, x):
        pts = [(math.cos(math.pi * i / 24) * r_out, math.sin(math.pi * i / 24) * r_out) for i in range(25)]
        pts += [(math.cos(math.pi * (24 - i) / 24) * r_in, math.sin(math.pi * (24 - i) / 24) * r_in) for i in range(25)]
        return prism(name, pts, width, g, rot=[("Z", 90)], loc=(x, 0, H), bevel=0.025, outline=0.018)

    for sx in (-1, 1):
        arc_band(f"LidRim{sx}", R - 0.12, R + 0.04, 0.16, sx * (W / 2 - 0.07))
        arc_band(f"LidStrap{sx}", R - 0.02, R + 0.04, 0.16, sx * 0.42)
    box("LidLip", (W + 0.02, 0.12, 0.12), g, loc=(0, -R, H + 0.04), bevel=0.035, outline=0.018)
    box("LidBack", (W + 0.02, 0.12, 0.12), g, loc=(0, R, H + 0.04), bevel=0.035, outline=0.018)
    box("Clasp", (0.24, 0.08, 0.22), g, loc=(0, -R - 0.04, H + 0.06), bevel=0.035, outline=0.018)
    lid = [o for o in bpy.context.scene.objects if o not in before]
    pivot(lid, Matrix.Rotation(math.radians(-104), 4, "X"), (0, R, H))
    gs = mound("T", m, (0, 0.04, H - 0.04), 1.0, 0.5, 0.31, seed=21, sy=0.62, back=0.55, spacing=0.95, toward=0.5, jitter=0.3, clip=(W / 2 - 0.24, -D / 2 + 0.2), power=0.3)
    filler("Bed", (0, 0.04, H - 0.04), 0.9, 0.45, sy=0.56, power=0.3, drop=0.16)
    # a row brimming along the front and right rims, so the heap meets the walls with no gap
    rng = random.Random(23)
    rim = [(x, -D / 2 + 0.24) for x in (-0.66, -0.33, 0.0, 0.33, 0.66)] + [(W / 2 - 0.32, y) for y in (-0.12, 0.2)] + [(-W / 2 + 0.32, -0.12)]
    for i, (x, y) in enumerate(rim):
        n = Vector((x * 0.3 + rng.uniform(-0.3, 0.3), -1.0, 0.9 + rng.uniform(-0.2, 0.2)))
        gs.append(gem(f"Rim{i}", m, loc=(x + rng.uniform(-0.04, 0.04), y, H + 0.06), scale=0.27 * rng.uniform(0.9, 1.1), seed=300 + i, normal=n, twist=rng.uniform(0, 360)))
    # and a crown of gems heaped on top
    for i, (x, y, z, sc) in enumerate(((0.0, 0.12, 0.5, 0.33), (-0.36, 0.16, 0.4, 0.3), (0.36, 0.1, 0.42, 0.31))):
        n = Vector((x * 0.6 + rng.uniform(-0.2, 0.2), -1.0, 0.8))
        gs.append(gem(f"Top{i}", m, loc=(x, y, H + z), scale=sc, seed=400 + i, normal=n, twist=rng.uniform(0, 360)))
    spill("S", m, [(-0.95, -0.86, 0.3), (-0.6, -1.0, 0.22), (-0.22, -1.08, 0.2), (0.62, -0.98, 0.25), (1.0, -0.82, 0.3), (1.2, -0.5, 0.2)], seed=22)
    lib.group_tilt(-20, 14)
    glints(gs, 2, 21)
