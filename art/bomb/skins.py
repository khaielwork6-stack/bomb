"""FUSE VALLEY — bomb skins (Asset Bible §3.6, §3.7): texture sets for the shared hero mesh.

Rules (§3.6): same mesh, same silhouette, same parts — a skin is a texture set per part (colour, normal, roughness,
metalness) plus a lamp colour; the fuse, seams and lamp stages are never changed. No dominant Runner cyan or Bomber
red-orange on the body.

For each skin: imports the exported hero bomb (its UVs are the game's), gives Body / Brass / Clamp / Socket a
procedural material from the skin's recipe (object-space patterns, so nothing seams on the UVs), bakes the four maps
(data maps raw / Non-Color), then renders a review shot with the baked maps on the real mesh.

  art/out/Skins/<SkinId>/<Part>_<COLOR|ROUGHNESS|NORMAL|METAL>.png
  art/out/Skins/<SkinId>/preview.png      art/out/Skins/sheet.png (all of them)

Run: blender -b --python-exit-code 1 --python art/bomb/skins.py -- [SkinId ...]
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GLB = os.path.join(ROOT, "art", "out", "Bomb.ClassicIron", "export", "Bomb.ClassicIron.glb")
OUT = os.path.join(ROOT, "art", "out", "Skins")
PARTS = ("Body", "Brass", "Clamp", "Socket")
RES = {"Body": 1024, "Brass": 1024, "Clamp": 512, "Socket": 512}


# ── node helpers ────────────────────────────────────────────────────────────────────────────────────────────────
class G:
    """A tiny graph builder over one material's node tree."""

    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.out = self.nt.nodes.new("ShaderNodeOutputMaterial")
        self.bsdf = self.nt.nodes.new("ShaderNodeBsdfPrincipled")
        self.link(self.bsdf.outputs["BSDF"], self.out.inputs["Surface"])
        tc = self.nt.nodes.new("ShaderNodeTexCoord")
        self.obj = tc.outputs["Object"]

    def link(self, a, b):
        self.nt.links.new(a, b)

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def vec(self, scale=1.0, offset=(0, 0, 0)):
        m = self.node("ShaderNodeMapping")
        m.inputs["Scale"].default_value = (scale, scale, scale)
        m.inputs["Location"].default_value = offset
        self.link(self.obj, m.inputs["Vector"])
        return m.outputs["Vector"]

    def noise(self, scale, detail=4.0, rough=0.5, distortion=0.0, vec=None, w=None):
        n = self.node("ShaderNodeTexNoise")
        if w is not None:
            n.noise_dimensions = "4D"
            n.inputs["W"].default_value = w
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distortion
        self.link(vec or self.obj, n.inputs["Vector"])
        return n

    def voronoi(self, scale, feature="F1", vec=None, randomness=1.0):
        n = self.node("ShaderNodeTexVoronoi", feature=feature)
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = randomness
        self.link(vec or self.obj, n.inputs["Vector"])
        return n

    def wave(self, scale, direction="Z", kind="BANDS", distortion=0.0, detail=2.0, vec=None, profile="SIN"):
        n = self.node("ShaderNodeTexWave", wave_type=kind)
        if kind == "BANDS":
            n.bands_direction = direction
        else:
            n.rings_direction = direction
        n.wave_profile = profile
        n.inputs["Scale"].default_value = scale
        n.inputs["Distortion"].default_value = distortion
        n.inputs["Detail"].default_value = detail
        self.link(vec or self.obj, n.inputs["Vector"])
        return n

    def ramp(self, fac, stops):
        """stops: [(pos, (r,g,b)) …] → Color output."""
        r = self.node("ShaderNodeValToRGB")
        els = r.color_ramp.elements
        while len(els) > 1:
            els.remove(els[-1])
        els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1)
        for pos, col in stops[1:]:
            e = els.new(pos)
            e.color = (*col, 1)
        self.link(fac, r.inputs["Fac"])
        return r.outputs["Color"]

    def vramp(self, fac, stops):
        """A value ramp (float stops) → a float socket."""
        return self.bw(self.ramp(fac, [(p, (v, v, v)) for p, v in stops]))

    def bw(self, color):
        n = self.node("ShaderNodeRGBToBW")
        self.link(color, n.inputs["Color"])
        return n.outputs["Val"]

    def mix(self, fac, a, b):
        """Colour lerp: a → b by fac (sockets or tuples)."""
        n = self.node("ShaderNodeMix", data_type="RGBA")
        self._in(fac, n.inputs[0])
        self._in(a, n.inputs[6], True)
        self._in(b, n.inputs[7], True)
        return n.outputs[2]

    def math(self, op, a, b=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op)
        n.use_clamp = clamp
        self._in(a, n.inputs[0])
        if b is not None:
            self._in(b, n.inputs[1])
        return n.outputs[0]

    def maprange(self, v, a, b, c, d):
        n = self.node("ShaderNodeMapRange")
        self._in(v, n.inputs["Value"])
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.inputs["To Min"].default_value = c
        n.inputs["To Max"].default_value = d
        return n.outputs["Result"]

    def vmath(self, op, a, b=None):
        """Vector math; returns the Vector output (or Value for DOT_PRODUCT / LENGTH)."""
        n = self.node("ShaderNodeVectorMath", operation=op)
        self._in(a, n.inputs[0])
        if b is not None:
            self._in(b, n.inputs[1])
        return n.outputs["Value"] if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else n.outputs["Vector"]

    def sep(self, vec=None):
        n = self.node("ShaderNodeSeparateXYZ")
        self.link(vec or self.obj, n.inputs["Vector"])
        return n

    def _in(self, v, socket, color=False):
        if isinstance(v, (int, float)):
            socket.default_value = (v, v, v, 1) if color else v
        elif isinstance(v, tuple):
            socket.default_value = (*v, 1) if len(v) == 3 and len(socket.default_value) == 4 else v
        else:
            self.link(v, socket)

    def surface(self, color, rough, metal, height=None, bump=0.3, dist=0.02, emit=None, emit_strength=0.0):
        self._in(color, self.bsdf.inputs["Base Color"], True)
        self._in(rough, self.bsdf.inputs["Roughness"])
        self._in(metal, self.bsdf.inputs["Metallic"])
        if height is not None:
            b = self.node("ShaderNodeBump")
            b.inputs["Strength"].default_value = bump
            b.inputs["Distance"].default_value = dist
            self._in(height, b.inputs["Height"])
            self.link(b.outputs["Normal"], self.bsdf.inputs["Normal"])
        if emit is not None:
            self._in(emit, self.bsdf.inputs["Emission Color"], True)
            self.bsdf.inputs["Emission Strength"].default_value = emit_strength


def rgb(h):
    h = h.lstrip("#")
    # sRGB hex → linear for Blender colour sockets
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ── shared material ingredients ─────────────────────────────────────────────────────────────────────────────────
def metal(g, base, rough=0.3, var=0.06, scale=9.0, hammered=0.0, smudge=0.0):
    """A metal: subtle tonal variation, optional hammered dimples (voronoi) and fingerprint smudges (roughness)."""
    n = g.noise(scale, 6, 0.55)
    col = g.mix(g.maprange(n.outputs["Fac"], 0.3, 0.7, 0, 1), tuple(max(0, c * (1 - var)) for c in base), tuple(min(1, c * (1 + var)) for c in base))
    r = g.maprange(n.outputs["Fac"], 0.2, 0.8, rough - 0.06, rough + 0.06)
    if smudge > 0:
        s = g.noise(3.5, 2, 0.4, 0.6)
        r = g.math("ADD", r, g.maprange(s.outputs["Fac"], 0.55, 0.75, 0, smudge), True)
    height = None
    if hammered > 0:
        v = g.voronoi(14.0)
        height = g.math("POWER", v.outputs["Distance"], 0.6)
    g.surface(col, r, 1.0, height, bump=hammered, dist=0.01)


def porcelain_col(g, base=rgb("#F6F4EE")):
    """The tin-white glaze colour alone (for skins that paint on top of it)."""
    n = g.noise(25, 3, 0.5)
    return g.mix(n.outputs["Fac"], tuple(c * 0.97 for c in base), base)


def porcelain(g, base=rgb("#F4EFE6")):
    n = g.noise(25, 3, 0.5)
    g.surface(g.mix(n.outputs["Fac"], tuple(c * 0.96 for c in base), base), 0.12, 0.0, n.outputs["Fac"], 0.02)


# ── the skins ───────────────────────────────────────────────────────────────────────────────────────────────────
def skin_rookie_brass(part, g):
    if part == "Body":
        metal(g, rgb("#C9973F"), rough=0.2, var=0.05, smudge=0.12)
    elif part == "Brass":
        metal(g, rgb("#B8643A"), rough=0.28, var=0.08)  # copper rivets and belt
    elif part == "Clamp":
        metal(g, rgb("#6E5230"), rough=0.4)
    else:
        porcelain(g)


def skin_copper_kettle(part, g):
    if part == "Body":
        n = g.noise(4.0, 5, 0.6)
        verd = g.maprange(n.outputs["Fac"], 0.58, 0.68, 0, 1)
        v = g.voronoi(13.0)
        dim = g.math("POWER", v.outputs["Distance"], 0.6)
        col = g.mix(verd, rgb("#B8643A"), rgb("#3E8C72"))
        g.surface(col, g.maprange(verd, 0, 1, 0.32, 0.75), g.maprange(verd, 0, 1, 1.0, 0.1), dim, bump=0.35, dist=0.012)
    elif part == "Brass":
        metal(g, rgb("#C9973F"), rough=0.3)
    elif part == "Clamp":
        metal(g, rgb("#7A4A2A"), rough=0.4)
    else:
        porcelain(g)


def skin_watermelon(part, g):
    if part == "Body":
        # rind stripes running pole to pole, wobbling like the real thing
        sep = g.sep()
        ang = g.math("ARCTAN2", sep.outputs["X"], sep.outputs["Y"])
        wob = g.noise(3.0, 3, 0.5)
        a = g.math("ADD", ang, g.maprange(wob.outputs["Fac"], 0, 1, -0.35, 0.35))
        s = g.math("SINE", g.math("MULTIPLY", a, 9.0))
        stripe = g.maprange(s, -0.15, 0.25, 0, 1)
        speck = g.noise(30, 2, 0.5)
        dark, light = rgb("#1F5A23"), rgb("#79B547")
        col = g.mix(stripe, light, dark)
        col = g.mix(g.maprange(speck.outputs["Fac"], 0.6, 0.75, 0, 0.25), col, rgb("#C9E28A"))
        g.surface(col, 0.22, 0.0, speck.outputs["Fac"], 0.05)
    elif part == "Brass":
        # pink flesh belt with dark seeds
        v = g.voronoi(26.0)
        seeds = g.maprange(v.outputs["Distance"], 0.06, 0.1, 1, 0)
        col = g.mix(seeds, rgb("#F06A7E"), rgb("#1E1416"))
        g.surface(col, 0.35, 0.0)
    elif part == "Clamp":
        g.surface(rgb("#2A3A20"), 0.45, 0.2)
    else:
        g.surface(rgb("#F3F0D8"), 0.3, 0.0)


def skin_paper_lantern(part, g):
    if part == "Body":
        # lacquered red paper over bamboo ribs (latitude rings) with fibre
        w = g.wave(7.0, "Z", "BANDS", 0.0, 0.0, profile="SAW")
        ribs = g.maprange(w.outputs["Fac"], 0.0, 0.08, 1, 0)
        fibre = g.noise(40, 6, 0.7)
        col = g.mix(ribs, rgb("#C2271E"), rgb("#7A1610"))
        col = g.mix(g.maprange(fibre.outputs["Fac"], 0.3, 0.7, 0, 0.15), col, rgb("#E8503A"))
        g.surface(col, 0.32, 0.0, g.math("ADD", ribs, g.math("MULTIPLY", fibre.outputs["Fac"], 0.2)), 0.25, 0.01)
    elif part == "Brass":
        n = g.voronoi(18.0, "DISTANCE_TO_EDGE")
        crack = g.maprange(n.outputs["Distance"], 0.0, 0.04, 1, 0)
        col = g.mix(crack, rgb("#E7B44A"), rgb("#9C6A1E"))
        g.surface(col, g.maprange(crack, 0, 1, 0.25, 0.5), 1.0, crack, 0.2)
    elif part == "Clamp":
        g.surface(rgb("#2B1A12"), 0.5, 0.0)
    else:
        porcelain(g, rgb("#F7E9C8"))


def skin_delft(part, g):
    if part == "Body":
        # glazed tin-white porcelain hand-painted in cobalt: eight-petal rosettes (light wash inside a dark brushed
        # outline, a dark heart), curling tendrils between them, and double border rules above and below the belt
        S = 2.1
        v = g.voronoi(S, "F1", randomness=0.7)
        d = g.vmath("SUBTRACT", g.obj, v.outputs["Position"])
        nrm = g.vmath("NORMALIZE", g.obj)
        t1 = g.vmath("NORMALIZE", g.vmath("CROSS_PRODUCT", nrm, (0.0, 0.0, 1.0)))
        t2 = g.vmath("CROSS_PRODUCT", nrm, t1)
        x = g.math("MULTIPLY", g.vmath("DOT_PRODUCT", d, t1), S)
        y = g.math("MULTIPLY", g.vmath("DOT_PRODUCT", d, t2), S)
        r = g.math("SQRT", g.math("ADD", g.math("MULTIPLY", x, x), g.math("MULTIPLY", y, y)))
        th = g.math("ARCTAN2", y, x)
        wob = g.noise(18, 2, 0.5)  # the brush is a hand, not a compass
        lobe = g.math("POWER", g.math("ABSOLUTE", g.math("COSINE", g.math("MULTIPLY", th, 4.0))), 0.7)
        R = g.math("ADD", g.math("ADD", 0.13, g.math("MULTIPLY", lobe, 0.17)), g.maprange(wob.outputs["Fac"], 0.3, 0.7, -0.015, 0.015))
        dr = g.math("SUBTRACT", r, R)
        fill = g.maprange(dr, -0.005, 0.005, 1, 0)
        outline = g.maprange(g.math("ABSOLUTE", dr), 0.012, 0.026, 1, 0)
        heart = g.maprange(r, 0.05, 0.065, 1, 0)
        ring = g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", r, 0.085)), 0.006, 0.014, 1, 0)
        # veins down each petal
        vein = g.math("MULTIPLY", g.maprange(g.math("ABSOLUTE", g.math("SINE", g.math("MULTIPLY", th, 4.0))), 0.0, 0.06, 1, 0), g.math("MULTIPLY", fill, g.maprange(r, 0.1, 0.13, 0, 1)))
        # tendrils: thin distorted ring lines, only well clear of the rosettes and only in some places
        tw = g.wave(3.2, "Z", "RINGS", distortion=7.0, detail=1.5, vec=g.vec(1.0, (3.1, 0.7, 1.9)))
        tline = g.maprange(tw.outputs["Fac"], 0.94, 0.985, 0, 1)
        tmask = g.math("MULTIPLY", g.maprange(dr, 0.07, 0.12, 0, 1), g.maprange(g.noise(2.2, 2, 0.5).outputs["Fac"], 0.48, 0.56, 0, 1))
        tendril = g.math("MULTIPLY", tline, tmask)
        # border rules: a pair of lines in each hemisphere
        az = g.math("ABSOLUTE", g.sep().outputs["Z"])
        rules = g.math("MAXIMUM", g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", az, 0.62)), 0.006, 0.012, 1, 0), g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", az, 0.69)), 0.012, 0.02, 1, 0))
        dark = g.math("MAXIMUM", g.math("MAXIMUM", g.math("MAXIMUM", outline, heart), g.math("MAXIMUM", vein, tendril)), g.math("MAXIMUM", ring, rules))
        wash = g.noise(11, 3, 0.55)
        light = g.mix(wash.outputs["Fac"], rgb("#8FA9DD"), rgb("#6C8CCF"))
        deep = g.mix(wash.outputs["Fac"], rgb("#14307F"), rgb("#2A4FA6"))
        glaze = porcelain_col(g)
        col = g.mix(dark, g.mix(fill, glaze, light), deep)
        paint = g.math("MAXIMUM", dark, g.math("MULTIPLY", fill, 0.5))
        g.surface(col, g.maprange(paint, 0, 1, 0.06, 0.12), 0.0, paint, 0.04, 0.01)
    elif part == "Brass":
        metal(g, rgb("#E2B54A"), rough=0.22)
    elif part == "Clamp":
        g.surface(rgb("#1C2C60"), 0.3, 0.3)
    else:
        porcelain(g)


def skin_disco(part, g):
    if part == "Body":
        # mirror tiles on a lat/long grid, each tilted a touch (grout lines in the normal)
        sep = g.sep()
        lon = g.math("ARCTAN2", sep.outputs["X"], sep.outputs["Y"])
        lat = g.math("ARCSINE", g.math("DIVIDE", sep.outputs["Z"], 1.12, True))
        u = g.math("FRACT", g.math("MULTIPLY", lon, 28 / (2 * math.pi)))
        vv = g.math("FRACT", g.math("MULTIPLY", lat, 14 / math.pi))
        gu = g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", u, 0.5)), 0.42, 0.48, 0, 1)
        gv = g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", vv, 0.5)), 0.42, 0.48, 0, 1)
        grout = g.math("MAXIMUM", gu, gv)
        cell = g.noise(60, 0, 0)
        tone = g.maprange(cell.outputs["Fac"], 0.3, 0.7, 0.75, 1.0)
        col = g.mix(grout, g.mix(tone, rgb("#9DA3B5"), rgb("#F2F4FA")), rgb("#2A2830"))
        g.surface(col, g.maprange(grout, 0, 1, 0.04, 0.6), g.maprange(grout, 0, 1, 1.0, 0.2), g.math("SUBTRACT", 1.0, grout), 0.6, 0.01)
    elif part == "Brass":
        metal(g, rgb("#C9973F"), rough=0.18)
    elif part == "Clamp":
        metal(g, rgb("#3A3846"), rough=0.25)
    else:
        porcelain(g)


def skin_gumball(part, g):
    if part == "Body":
        # gumballs crowding behind a glossy glass skin
        v = g.voronoi(7.5, "F1")
        ball = g.maprange(v.outputs["Distance"], 0.28, 0.42, 1, 0)
        hue = g.ramp(v.outputs["Color"], [(0.0, rgb("#F2C230")), (0.2, rgb("#55C3F0")), (0.4, rgb("#F07FB0")), (0.6, rgb("#6FD06A")), (0.8, rgb("#F3F0E8")), (1.0, rgb("#B07CE8"))])
        col = g.mix(ball, rgb("#3B3447"), hue)
        g.surface(col, g.maprange(ball, 0, 1, 0.2, 0.06), 0.0, ball, 0.3, 0.02)
    elif part == "Brass":
        g.surface(rgb("#D63A2A"), 0.25, 0.4)  # red-painted metal belt
    elif part == "Clamp":
        g.surface(rgb("#8E2018"), 0.3, 0.5)
    else:
        metal(g, rgb("#C8CCD6"), rough=0.2)


def skin_lava(part, g):
    if part == "Body":
        v = g.voronoi(5.0, "DISTANCE_TO_EDGE")
        n = g.noise(6, 4, 0.6)
        crack = g.maprange(g.math("ADD", v.outputs["Distance"], g.maprange(n.outputs["Fac"], 0, 1, -0.03, 0.03)), 0.0, 0.05, 1, 0)
        glow = g.ramp(crack, [(0.0, rgb("#0B0A0C")), (0.35, rgb("#5A1406")), (0.7, rgb("#FF6A1F")), (1.0, rgb("#FFD84A"))])
        g.surface(glow, g.maprange(crack, 0, 1, 0.12, 0.8), 0.0, g.math("SUBTRACT", 1.0, crack), 0.5, 0.015)
    elif part == "Brass":
        metal(g, rgb("#3A2E2A"), rough=0.45, hammered=0.2)
    elif part == "Clamp":
        metal(g, rgb("#241E1C"), rough=0.5)
    else:
        g.surface(rgb("#2A2220"), 0.6, 0.0)


def skin_frost(part, g):
    if part == "Body":
        # glacier ice: deep blue at the belly brightening upward, fractured into facets with fine hairline cracks,
        # a matte crust of rime creeping down from the top, and diamond-dust glints in the glaze
        z = g.sep().outputs["Z"]
        n = g.noise(2.6, 6, 0.62, distortion=0.6)
        depth = g.math("ADD", g.maprange(z, -1.1, 1.0, 0.0, 0.7), g.maprange(n.outputs["Fac"], 0.3, 0.7, -0.15, 0.3))
        ice = g.ramp(depth, [(0.0, rgb("#1D5E96")), (0.35, rgb("#3D8CC4")), (0.65, rgb("#8CCBEA")), (0.95, rgb("#DDF2FB"))])
        big = g.voronoi(4.2, "DISTANCE_TO_EDGE", vec=g.vec(1.0, (0.4, 1.3, 0.2)))
        fine = g.voronoi(13.0, "DISTANCE_TO_EDGE")
        crack = g.math("MAXIMUM", g.maprange(big.outputs["Distance"], 0.0, 0.03, 1, 0), g.math("MULTIPLY", g.maprange(fine.outputs["Distance"], 0.0, 0.02, 1, 0), 0.45))
        rime_n = g.noise(26, 8, 0.72)
        crust = g.maprange(g.math("ADD", z, g.maprange(g.noise(4, 4, 0.6).outputs["Fac"], 0, 1, -0.35, 0.35)), 0.45, 0.62, 0, 1)
        crust = g.math("MULTIPLY", crust, g.maprange(rime_n.outputs["Fac"], 0.35, 0.5, 0.4, 1))
        glint = g.maprange(g.voronoi(70.0).outputs["Distance"], 0.04, 0.09, 1, 0)
        glint = g.math("MULTIPLY", glint, g.maprange(g.noise(9, 2, 0.5).outputs["Fac"], 0.55, 0.62, 0, 1))
        col = g.mix(crack, ice, rgb("#EAF7FD"))
        col = g.mix(crust, col, rgb("#F4FAFD"))
        col = g.mix(glint, col, rgb("#FFFFFF"))
        rough = g.math("ADD", g.maprange(crust, 0, 1, 0.07, 0.72), g.math("MULTIPLY", crack, 0.15))
        height = g.math("SUBTRACT", g.math("MULTIPLY", crust, g.math("ADD", 0.5, rime_n.outputs["Fac"])), g.math("MULTIPLY", crack, 0.6))
        g.surface(col, rough, 0.0, height, 0.35, 0.01)
    elif part == "Brass":
        metal(g, rgb("#C8D0DA"), rough=0.2)
    elif part == "Clamp":
        metal(g, rgb("#8C98A8"), rough=0.3)
    else:
        porcelain(g, rgb("#EAF4FA"))


def skin_galaxy(part, g):
    if part == "Body":
        n1 = g.noise(2.2, 8, 0.62, 0.4)
        n2 = g.noise(4.5, 6, 0.55, 0.0, w=1.3)
        neb = g.ramp(n1.outputs["Fac"], [(0.3, rgb("#05040F")), (0.5, rgb("#1B1050")), (0.62, rgb("#5A2A9E")), (0.72, rgb("#D0508F")), (0.8, rgb("#F7B07A"))])
        neb = g.mix(g.maprange(n2.outputs["Fac"], 0.55, 0.75, 0, 0.6), neb, rgb("#2A6BD8"))
        stars = g.voronoi(60.0)
        star = g.maprange(stars.outputs["Distance"], 0.0, 0.05, 1, 0)
        star = g.math("MULTIPLY", star, g.maprange(stars.outputs["Color"], 0.75, 0.8, 0, 1))
        col = g.mix(star, neb, rgb("#FFFFFF"))
        g.surface(col, 0.05, 0.0)
    elif part == "Brass":
        metal(g, rgb("#D8DDE6"), rough=0.08)  # chrome belt
    elif part == "Clamp":
        metal(g, rgb("#4A4E5A"), rough=0.2)
    else:
        porcelain(g, rgb("#E8E4F4"))


def skin_dragon(part, g):
    if part == "Body":
        v = g.voronoi(11.0, "F1", randomness=0.7)
        scale_h = g.math("POWER", g.maprange(v.outputs["Distance"], 0.0, 0.5, 1, 0), 0.7)
        edge = g.voronoi(11.0, "DISTANCE_TO_EDGE", randomness=0.7)
        rim = g.maprange(edge.outputs["Distance"], 0.0, 0.05, 1, 0)
        shift = g.ramp(v.outputs["Color"], [(0.0, rgb("#1D6E66")), (0.35, rgb("#2A9C8A")), (0.65, rgb("#5A3E9E")), (1.0, rgb("#C9973F"))])
        col = g.mix(rim, shift, rgb("#0E1A1A"))
        g.surface(col, g.maprange(rim, 0, 1, 0.2, 0.55), g.maprange(rim, 0, 1, 0.65, 0.2), scale_h, 0.5, 0.02)
    elif part == "Brass":
        metal(g, rgb("#E6B23E"), rough=0.22, hammered=0.25)  # the gold claw belt
    elif part == "Clamp":
        metal(g, rgb("#3C2C14"), rough=0.35)
    else:
        g.surface(rgb("#E9D9A8"), 0.3, 0.0)


def skin_thunder(part, g):
    if part == "Body":
        sep = g.sep()
        # one side is cracked open: amethyst crystal facets; the rest is rough nodular stone
        open_side = g.maprange(g.math("ADD", sep.outputs["X"], g.maprange(g.noise(3, 3, 0.5).outputs["Fac"], 0, 1, -0.2, 0.2)), 0.25, 0.32, 0, 1)
        stone_n = g.noise(10, 6, 0.6)
        stone = g.mix(stone_n.outputs["Fac"], rgb("#5E5348"), rgb("#9A8C7A"))
        fac = g.voronoi(16.0, "F1")
        crystal = g.ramp(fac.outputs["Color"], [(0.0, rgb("#3B1E6E")), (0.5, rgb("#8B5CD6")), (1.0, rgb("#E2C8FF"))])
        rimband = g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", open_side, 0.5)), 0.0, 0.2, 1, 0)
        col = g.mix(open_side, stone, crystal)
        col = g.mix(g.math("MULTIPLY", rimband, 0.8), col, rgb("#EDE6DC"))
        rough = g.maprange(open_side, 0, 1, 0.85, 0.08)
        height = g.mix(open_side, stone_n.outputs["Fac"], fac.outputs["Distance"])
        g.surface(col, rough, 0.0, g.bw(height), 0.5, 0.02)
    elif part == "Brass":
        metal(g, rgb("#8C6A3A"), rough=0.4, hammered=0.2)
    elif part == "Clamp":
        g.surface(rgb("#3A3530"), 0.7, 0.2)
    else:
        g.surface(rgb("#CFC6B8"), 0.6, 0.0)


def skin_clockwork(part, g):
    if part == "Body":
        # brass shell engraved with gear trains: rings of teeth around a few centres
        sep = g.sep()
        pattern = None
        for cx, cz, r, teeth in ((0.0, 0.2, 0.42, 14), (0.5, -0.35, 0.3, 10), (-0.55, -0.3, 0.26, 9), (-0.2, 0.75, 0.22, 8)):
            dx = g.math("SUBTRACT", sep.outputs["X"], cx)
            dz = g.math("SUBTRACT", sep.outputs["Z"], cz)
            d = g.math("SQRT", g.math("ADD", g.math("MULTIPLY", dx, dx), g.math("MULTIPLY", dz, dz)))
            ang = g.math("ARCTAN2", dz, dx)
            tooth = g.maprange(g.math("SINE", g.math("MULTIPLY", ang, teeth)), -0.2, 0.2, 0, 0.05)
            ring = g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", d, g.math("ADD", r, tooth))), 0.0, 0.025, 1, 0)
            hub = g.maprange(d, r * 0.25, r * 0.3, 1, 0)
            spokes = g.math("MULTIPLY", g.maprange(g.math("ABSOLUTE", g.math("SINE", g.math("MULTIPLY", ang, 3))), 0.0, 0.12, 1, 0), g.maprange(d, r * 0.9, r, 1, 0))
            one = g.math("MAXIMUM", g.math("MAXIMUM", ring, hub), spokes)
            pattern = one if pattern is None else g.math("MAXIMUM", pattern, one)
        col = g.mix(pattern, rgb("#C9973F"), rgb("#6B4A18"))
        g.surface(col, g.maprange(pattern, 0, 1, 0.22, 0.45), 1.0, g.math("SUBTRACT", 1.0, pattern), 0.4, 0.01)
    elif part == "Brass":
        metal(g, rgb("#B7BCC6"), rough=0.2)  # a steel dial belt
    elif part == "Clamp":
        metal(g, rgb("#5A4220"), rough=0.35)
    else:
        porcelain(g, rgb("#F3EAD6"))


def skin_gilded(part, g):
    if part == "Body":
        # gold leaf over iron, engraved scrollwork, iron peeking through worn edges
        w = g.wave(6.0, "Z", "RINGS", 7.0, 3.0)
        scroll = g.maprange(w.outputs["Fac"], 0.42, 0.5, 0, 1)
        wear = g.noise(5, 5, 0.6)
        iron = g.maprange(wear.outputs["Fac"], 0.68, 0.74, 0, 1)
        gold = g.mix(scroll, rgb("#E9B940"), rgb("#9C6A16"))
        col = g.mix(iron, gold, rgb("#2E2C33"))
        g.surface(col, g.maprange(scroll, 0, 1, 0.18, 0.35), 1.0, scroll, 0.35, 0.01)
    elif part == "Brass":
        metal(g, rgb("#F2D27A"), rough=0.15)
    elif part == "Clamp":
        metal(g, rgb("#2E2C33"), rough=0.4)
    else:
        porcelain(g)


def skin_jack(part, g):
    if part == "Body":
        # a pumpkin: ribbed orange skin with a carved, candle-lit face on the front (+Y, away from the clamp)
        sep = g.sep()
        ang = g.math("ARCTAN2", sep.outputs["X"], sep.outputs["Y"])
        rib = g.maprange(g.math("ABSOLUTE", g.math("SINE", g.math("MULTIPLY", ang, 5))), 0.0, 0.25, 0, 1)
        n = g.noise(12, 4, 0.5)
        skin = g.mix(rib, rgb("#C24E10"), rgb("#F07A1E"))
        skin = g.mix(g.maprange(n.outputs["Fac"], 0.55, 0.7, 0, 0.3), skin, rgb("#F6A23A"))
        # carved face (eyes + jagged grin) on the front hemisphere
        front = g.maprange(sep.outputs["Y"], 0.5, 0.9, 0, 1)
        eyes = None
        for ex in (-0.32, 0.32):
            dx = g.math("SUBTRACT", sep.outputs["X"], ex)
            dz = g.math("SUBTRACT", sep.outputs["Z"], 0.25)
            tri = g.math("ADD", g.math("ABSOLUTE", dx), g.math("MULTIPLY", g.math("SUBTRACT", dz, 0.0), 0.8))
            e = g.maprange(tri, 0.14, 0.18, 1, 0)
            e = g.math("MULTIPLY", e, g.maprange(dz, -0.16, -0.1, 0, 1))
            eyes = e if eyes is None else g.math("MAXIMUM", eyes, e)
        dz = g.math("ADD", sep.outputs["Z"], 0.28)
        teeth = g.maprange(g.math("SINE", g.math("MULTIPLY", sep.outputs["X"], 22)), -0.1, 0.4, 0.0, 0.07)
        grin = g.math("MULTIPLY", g.maprange(g.math("ABSOLUTE", sep.outputs["X"]), 0.5, 0.55, 1, 0), g.maprange(g.math("ABSOLUTE", g.math("SUBTRACT", dz, teeth)), 0.06, 0.09, 1, 0))
        carve = g.math("MULTIPLY", g.math("MAXIMUM", eyes, grin), front, True)
        col = g.mix(carve, skin, rgb("#FFC23A"))
        g.surface(col, g.maprange(carve, 0, 1, 0.45, 0.6), 0.0, g.math("SUBTRACT", rib, carve), 0.4, 0.02)
    elif part == "Brass":
        g.surface(rgb("#2F5A22"), 0.5, 0.0, g.noise(20, 4, 0.5).outputs["Fac"], 0.3)  # a vine belt
    elif part == "Clamp":
        g.surface(rgb("#3A2A1A"), 0.6, 0.0)
    else:
        g.surface(rgb("#4E6A2A"), 0.5, 0.0)  # the stem


def skin_tempered(part, g):
    if part == "Body":
        sep = g.sep()
        w = g.noise(3, 3, 0.5)
        z = g.math("ADD", sep.outputs["Z"], g.maprange(w.outputs["Fac"], 0, 1, -0.12, 0.12))
        tint = g.ramp(g.maprange(z, -1.1, 1.1, 0, 1), [(0.0, rgb("#2A3A8C")), (0.25, rgb("#4A2E8A")), (0.45, rgb("#8A3A6A")), (0.62, rgb("#B07A3A")), (0.8, rgb("#D8C080")), (1.0, rgb("#C8CCD4"))])
        g.surface(tint, 0.22, 1.0, g.noise(30, 3, 0.5).outputs["Fac"], 0.05)
    elif part == "Brass":
        metal(g, rgb("#C8CCD4"), rough=0.2)
    elif part == "Clamp":
        metal(g, rgb("#2A2E3A"), rough=0.3)
    else:
        porcelain(g)


def skin_meteorite(part, g):
    if part == "Body":
        # iron-nickel: Widmanstätten crosshatch etched in, regmaglypt thumbprints over it
        a = g.wave(26.0, "X", "BANDS", 0.4, 0.0, vec=g.vec(1.0), profile="SAW")
        b = g.wave(26.0, "DIAGONAL", "BANDS", 0.4, 0.0, profile="SAW")
        hatch = g.math("MAXIMUM", g.maprange(a.outputs["Fac"], 0.0, 0.1, 1, 0), g.maprange(b.outputs["Fac"], 0.0, 0.1, 1, 0))
        v = g.voronoi(5.0)
        dent = g.math("POWER", v.outputs["Distance"], 0.5)
        col = g.mix(hatch, rgb("#8E9098"), rgb("#4A4A52"))
        g.surface(col, g.maprange(hatch, 0, 1, 0.35, 0.6), 1.0, g.math("ADD", dent, g.math("MULTIPLY", hatch, 0.2)), 0.6, 0.03)
    elif part == "Brass":
        metal(g, rgb("#6E5A44"), rough=0.5, hammered=0.25)
    elif part == "Clamp":
        metal(g, rgb("#2A2A30"), rough=0.5)
    else:
        g.surface(rgb("#3A3836"), 0.7, 0.0)


SKINS = {
    "Skin_RookieBrass": skin_rookie_brass,
    "Skin_CopperKettle": skin_copper_kettle,
    "Skin_Watermelon": skin_watermelon,
    "Skin_PaperLantern": skin_paper_lantern,
    "Skin_Delft": skin_delft,
    "Skin_Disco": skin_disco,
    "Skin_Gumball": skin_gumball,
    "Skin_LavaForge": skin_lava,
    "Skin_Frostbite": skin_frost,
    "Skin_Galaxy": skin_galaxy,
    "Skin_DragonEgg": skin_dragon,
    "Skin_ThunderEgg": skin_thunder,
    "Skin_Clockwork": skin_clockwork,
    "Skin_Gilded": skin_gilded,
    "Skin_JackOFuse": skin_jack,
    "Skin_Tempered": skin_tempered,
    "Skin_Meteorite": skin_meteorite,
}


# ── scene, baking, review render ────────────────────────────────────────────────────────────────────────────────
def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    objs = {}
    for o in bpy.data.objects:
        if o.type == "MESH":
            base = o.name.split(".")[0]
            if base in PARTS or base.startswith("Fuse") or base in ("LensF", "LensB", "LampF", "LampB", "SeamGlow1", "SeamGlow2"):
                objs[base] = o
    return objs


def bake(o, img, kind):
    mat = o.data.materials[0]
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    for other in bpy.context.view_layer.objects:
        other.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    if kind == "COLOR" or kind == "METAL":
        # route the input into Emission and bake EMIT (exact values; a diffuse bake goes black on metals)
        b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        src = b.inputs["Base Color" if kind == "COLOR" else "Metallic"]
        old_emit = [l for l in nt.links if l.to_socket == b.inputs["Emission Color"]]
        for l in old_emit:
            nt.links.remove(l)
        if src.is_linked:
            nt.links.new(src.links[0].from_socket, b.inputs["Emission Color"])
        else:
            v = src.default_value
            b.inputs["Emission Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1)
        prev = b.inputs["Emission Strength"].default_value
        b.inputs["Emission Strength"].default_value = 1.0
        bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
        for l in [l for l in nt.links if l.to_socket == b.inputs["Emission Color"]]:
            nt.links.remove(l)
        b.inputs["Emission Strength"].default_value = prev
    elif kind == "ROUGHNESS":
        bpy.ops.object.bake(type="ROUGHNESS", use_clear=True, margin=8)
    else:
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True, margin=8)
    nt.nodes.remove(node)


def make_skin(skin_id):
    objs = load()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"
    scene.cycles.samples = 16
    scene.render.bake.margin = 8
    out = os.path.join(OUT, skin_id)
    os.makedirs(out, exist_ok=True)
    recipe = SKINS[skin_id]
    maps = {}
    for part in PARTS:
        o = objs.get(part)
        if not o:
            print("missing part", part, flush=True)
            continue
        mat = bpy.data.materials.new(f"{skin_id}_{part}")
        mat.use_nodes = True
        recipe(part, G(mat))
        o.data.materials.clear()
        o.data.materials.append(mat)
        res = RES[part]
        maps[part] = {}
        for kind in ("COLOR", "ROUGHNESS", "NORMAL", "METAL"):
            img = bpy.data.images.new(f"{skin_id}_{part}_{kind}", res, res, alpha=False, float_buffer=(kind == "NORMAL"))
            if kind != "COLOR":
                img.colorspace_settings.name = "Non-Color"
            bake(o, img, kind)
            img.filepath_raw = os.path.join(out, f"{part}_{kind}.png")
            img.file_format = "PNG"
            img.save()
            maps[part][kind] = img
        print("baked", skin_id, part, flush=True)
    # the review shot: the baked maps on the real mesh
    for part, m in maps.items():
        o = objs[part]
        mat = bpy.data.materials.new(f"{skin_id}_{part}_review")
        mat.use_nodes = True
        nt = mat.node_tree
        b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

        def tex(kind):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = m[kind]
            return n

        nt.links.new(tex("COLOR").outputs["Color"], b.inputs["Base Color"])
        nt.links.new(tex("ROUGHNESS").outputs["Color"], b.inputs["Roughness"])
        nt.links.new(tex("METAL").outputs["Color"], b.inputs["Metallic"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex("NORMAL").outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        o.data.materials.clear()
        o.data.materials.append(mat)
    # fuse + lamps as the game shows them at rest
    for name, o in objs.items():
        if name.startswith("Fuse") or name in ("LampF", "LampB"):
            mat = bpy.data.materials.new(name + "_rv")
            mat.use_nodes = True
            b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            if name.startswith("Fuse"):
                b.inputs["Base Color"].default_value = (0.69, 0.48, 0.25, 1)
                b.inputs["Roughness"].default_value = 0.8
            else:
                b.inputs["Emission Color"].default_value = (1, 0.7, 0.2, 1)
                b.inputs["Emission Strength"].default_value = 6
            o.data.materials.clear()
            o.data.materials.append(mat)
        elif name.startswith("SeamGlow") or name.startswith("Lens"):
            o.hide_render = True
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    sky = world.node_tree.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA" if hasattr(sky, "sky_type") else sky.sky_type
    try:
        sky.sun_elevation = math.radians(25)
        sky.sun_rotation = math.radians(220)
    except Exception:
        pass
    world.node_tree.links.new(sky.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.35
    sun = bpy.data.lights.new("key", "SUN")
    sun.energy = 3.5
    sun.color = (1.0, 0.86, 0.7)
    so = bpy.data.objects.new("key", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(so)
    rim = bpy.data.lights.new("rim", "AREA")
    rim.energy = 400
    rim.size = 3
    rim.color = (0.6, 0.75, 1.0)
    ro = bpy.data.objects.new("rim", rim)
    ro.location = (-3, 3, 2.5)
    ro.rotation_euler = (math.radians(-60), math.radians(-40), 0)
    scene.collection.objects.link(ro)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 70
    co = bpy.data.objects.new("cam", cam)
    scene.collection.objects.link(co)
    scene.camera = co
    # the GLB came in Y-up → Blender Z-up; the bomb sits round the origin. Shoot a 3/4 view of the front.
    co.location = (3.6, 5.2, 2.4)  # the face away from the clamp (the clamp side, -Y, is on the back)
    direction = -co.location
    co.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler() if hasattr(direction, "to_track_quat") else (1.2, 0, 0.6)
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.film_transparent = False
    scene.cycles.samples = 64
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = os.path.join(out, "preview.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", skin_id, flush=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    todo = argv or list(SKINS)
    for sid in todo:
        make_skin(sid)
    print("DONE", flush=True)
