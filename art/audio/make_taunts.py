"""FUSE VALLEY — the taunt emoji sounds, sound-designed in-house (the owner, 2026-10-18: "after you use an emoji it also
plays a funny sound effect that matches the emoji"). Same school as make_sfx.py (whose helpers it reuses): built from
first principles in numpy — formant voices, additive brass, struck objects, shaped noise. Never AI, never samples.

  key               file                 what it is
  Taunt.Laugh       taunt_laugh.wav      a cartoon "HA-HA-HA-HA-ha", bouncing down
  Taunt.Cool        taunt_cool.wav       two finger snaps, a sly low brass "bwow", the sunglasses' gleam
  Taunt.Angry       taunt_angry.wav      a kettle whistle shrieking over a tremolo growl
  Taunt.Cry         taunt_cry.wav        a wailing "WAAAH" with a sob, then a smaller "waah"
  Taunt.Love        taunt_love.wav       a lip-pop kiss "mwah" and a rising harp sparkle
  Taunt.Shock       taunt_shock.wav      a sharp gasp, then the dramatic "dun, dun, DUNNN"
  Taunt.Silly       taunt_silly.wav      a raspberry "pbbbt" and a cartoon spring "boing"
  Taunt.Skull       taunt_skull.wav      a spooky "ooOOOooo" ghost and a rattle of bones
  Taunt.Fire        taunt_fire.wav       a flame whoosh and a crackling sizzle

Run: python -I art/audio/make_taunts.py [name ...]
  48 kHz, 16-bit mono WAVs in art/out/Audio/Taunt/; review sheets in art/out/Audio/Taunt_review/.
"""

import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as mk  # noqa: E402
import numpy as np  # noqa: E402

mk.OUT = os.path.join(mk.ROOT, "art", "out", "Audio", "Taunt")
REVIEW = os.path.join(mk.ROOT, "art", "out", "Audio", "Taunt_review")
SR, TAU, ns, tb, env, place = mk.SR, mk.TAU, mk.ns, mk.tb, mk.env, mk.place


def master(g, y, rt=0.6, wet=0.12):
    y = mk.reverb(y, mk.make_ir(g, rt), wet)
    y = np.tanh(1.3 * mk.norm(y))
    y = mk.norm(y) * mk.PEAK
    k = ns(0.004)
    y[:k] *= np.linspace(0, 1, k)
    k = ns(0.03)
    y[-k:] *= np.linspace(1, 0, k)
    return y


def syllable(g, dur, f0, vowel, fs=1.35, h=0.03, bright=4200, vib=(6.0, 0.01)):
    """One cartoon voice syllable: an 'h' breath onset into a voiced vowel that pops then fades."""
    t = tb(dur)
    f = f0 * (1 + 0.06 * np.exp(-t / 0.03))
    return mk.voice(
        g,
        dur,
        f,
        ((0, 0), (h, 1.0), (dur * 0.55, 0.8), (dur, 0)),
        [(0, vowel), (dur, vowel)],
        breath_pts=((0, 0.6), (h, 0.1), (dur, 0.02)),
        bright=bright,
        vib=vib,
        fs=fs,
    )


def laugh(g):
    d = 1.15
    y = np.zeros(ns(d))
    for i, f in enumerate([380, 360, 345, 320, 280]):
        dur = 0.13 if i < 4 else 0.22
        place(y, syllable(g, dur, f, mk.V_A), 0.02 + i * 0.15, 1.0 if i < 4 else 0.85)
    return master(g, y, 0.5, 0.1)


def snap(g):
    x = np.zeros(ns(0.12))
    place(x, mk.bp(g.normal(size=ns(0.01)), 1800, 6500) * np.hanning(ns(0.01)), 0)
    place(x, mk.strike(g, 0.12, (2100, 3300), (1.0, 0.5), (25, 15), 0.05), 0.002, 0.6)
    return x


def cool(g):
    d = 1.25
    y = np.zeros(ns(d))
    place(y, snap(g), 0.0, 0.9)
    place(y, snap(g), 0.2, 0.9)
    t = tb(0.6)
    bw = mk.brass(g, 0.6, 98.0, ((0, 0), (0.05, 0.9), (0.35, 0.7), (0.6, 0)), bright=0.7, scoop=-200, vib=0.012)
    bw = bw * (1 + 0.0 * t)
    place(y, mk.lp(bw, 2600), 0.42, 0.9)
    place(y, mk.glint(g, 0.5, 3135, 160), 0.78, 0.5)
    place(y, mk.glint(g, 0.4, 4186, 120), 0.84, 0.35)
    return master(g, y, 0.5, 0.1)


def angry(g):
    d = 1.3
    t = tb(d)
    # the kettle: a whistle that rises and wavers, breathy
    f = 1500 + 700 * np.clip(t / 0.9, 0, 1) + 40 * np.sin(TAU * 7 * t)
    ph = TAU * np.cumsum(f) / SR
    whistle = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * env(t, ((0, 0), (0.15, 0.7), (1.0, 0.9), (1.3, 0)))
    whistle += 0.2 * mk.bp(g.normal(size=len(t)), 1200, 3500) * env(t, ((0, 0), (0.1, 0.5), (1.3, 0.1)))
    # the growl: a low brass blat with a fast tremolo, driven hard
    gr = mk.brass(g, d, 73.0, ((0, 0), (0.06, 1.0), (1.0, 0.8), (1.3, 0)), bright=1.4, scoop=-120)
    gr = np.tanh(2.2 * gr / (np.max(np.abs(gr)) + 1e-9)) * (0.6 + 0.4 * np.sin(TAU * 26 * t))
    y = 0.5 * whistle + 0.8 * mk.lp(gr, 3000)
    return master(g, y, 0.4, 0.08)


def cry(g):
    d = 1.7
    y = np.zeros(ns(d))
    t1 = tb(0.95)
    f1 = 560 - 160 * np.clip(t1 / 0.95, 0, 1) ** 1.5
    w1 = mk.voice(
        g, 0.95, f1, ((0, 0), (0.06, 1.0), (0.8, 0.8), (0.95, 0)),
        [(0, mk.V_U), (0.12, mk.V_A), (0.95, mk.V_O)],
        breath_pts=((0, 0.3), (0.06, 0.06), (0.95, 0.05)), bright=4500, vib=(6.5, 0.03), fs=1.3,
    )
    place(y, w1, 0.02)
    for k, at in enumerate([1.0, 1.1]):  # two sobbing breaths
        place(y, mk.bp(g.normal(size=ns(0.07)), 600, 2600) * np.hanning(ns(0.07)), at, 0.35 - k * 0.1)
    t2 = tb(0.45)
    w2 = mk.voice(
        g, 0.45, 470 - 90 * t2 / 0.45, ((0, 0), (0.04, 0.8), (0.35, 0.6), (0.45, 0)),
        [(0, mk.V_U), (0.08, mk.V_A), (0.45, mk.V_O)], bright=4200, vib=(7.0, 0.035), fs=1.3,
    )
    place(y, w2, 1.22, 0.8)
    return master(g, y, 0.6, 0.12)


def love(g):
    d = 1.35
    y = np.zeros(ns(d))
    # the kiss: a lip pop, then a short closed-mouth "mwah"
    pop = mk.bp(g.normal(size=ns(0.012)), 500, 3500) * np.hanning(ns(0.012))
    place(y, pop, 0.0, 1.0)
    place(y, mk.thump(0.06, 420, 180, 0.02, 0.02), 0.0, 0.5)
    t = tb(0.32)
    mwah = mk.voice(
        g, 0.32, 260 + 60 * np.clip(t / 0.2, 0, 1), ((0, 0), (0.03, 0.9), (0.2, 0.7), (0.32, 0)),
        [(0, mk.V_U), (0.08, mk.V_A), (0.32, mk.V_A)], bright=3500, vib=(5.0, 0.01), fs=1.25,
    )
    place(y, mwah, 0.05, 0.8)
    # the harp sparkle rising (C6 E6 G6 C7 E7)
    for i, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0, 2637.0]):
        place(y, mk.bell(g, 0.7, f, 0.45), 0.42 + i * 0.07, 0.42)
    place(y, mk.sparkle(g, 0.8, 0.0, 0.6, 10, 3500, 7000, 0.25), 0.5)
    return master(g, y, 0.9, 0.18)


def shock(g):
    d = 1.75
    y = np.zeros(ns(d))
    # the gasp: a sharp inhale
    t = tb(0.22)
    gasp = mk.bp(g.normal(size=len(t)), 900, 4200) * env(t, ((0, 0), (0.16, 1.0), (0.22, 0)))
    place(y, gasp, 0.0, 0.7)
    # "dun, dun, DUNNN": a brass section stab, the last one held and lower
    for k, (at, f, dur) in enumerate([(0.32, 146.8, 0.2), (0.6, 146.8, 0.2), (0.9, 138.6, 0.8)]):
        last = k == 2
        st = mk.section(
            g, dur, [f, f * 1.5, f * 2], ((0, 0), (0.02, 1.0), (dur * (0.5 if last else 0.6), 0.7), (dur, 0)),
            players=2, bright=1.3 if last else 1.0, scoop=-30, vib=0.006 if last else 0.0,
        )
        place(y, st, at, 1.0 if last else 0.75)
        place(y, mk.thump(0.3, 90, 50, 0.06, 0.12), at, 0.45 if last else 0.25)
    return master(g, y, 1.2, 0.2)


def silly(g):
    d = 1.3
    y = np.zeros(ns(d))
    # the raspberry: a lip buzz (a low saw, randomly flapped) through a mouth band
    t = tb(0.5)
    f = 62 + 8 * mk.wobble(g, len(t), 12)
    buzz = mk.saw(f, g.uniform()) * (0.6 + 0.4 * np.clip(mk.wobble(g, len(t), 40), -1, 1))
    buzz = mk.bp(buzz, 250, 2200) * env(t, ((0, 0), (0.03, 1.0), (0.42, 0.8), (0.5, 0)))
    place(y, buzz, 0.0, 0.9)
    # the boing: a spring whose pitch wobbles and settles
    tb2 = tb(0.7)
    fb = 160 * (1 + 0.45 * np.exp(-tb2 / 0.18) * np.sin(TAU * 13 * tb2)) * (1 + 0.6 * np.exp(-tb2 / 0.05))
    ph = TAU * np.cumsum(fb) / SR
    boing = (np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * np.exp(-tb2 / 0.28)
    boing *= np.clip(tb2 / 0.004, 0, 1)  # no click at the start
    boing = mk.taper(boing, 0.35)  # nor at the end
    place(y, boing, 0.55, 0.95)
    return master(g, y, 0.4, 0.1)


def skull(g):
    d = 1.9
    y = np.zeros(ns(d))
    t = tb(1.3)
    f = 200 + 140 * np.sin(np.pi * np.clip(t / 1.3, 0, 1)) ** 1.3
    ghost = mk.voice(
        g, 1.3, f, ((0, 0), (0.2, 0.8), (1.0, 0.7), (1.3, 0)),
        [(0, mk.V_U), (0.5, mk.V_O), (1.3, mk.V_U)],
        breath_pts=((0, 0.25), (1.3, 0.2)), bright=2600, vib=(5.0, 0.04), fs=1.1,
    )
    place(y, ghost, 0.0, 0.75)
    # the bones: a fast wooden rattle, falling
    for i in range(9):
        fr = 1700 - i * 110 + g.uniform(-40, 40)
        place(y, mk.strike(g, 0.12, (fr, fr * 2.3), (1.0, 0.3), (40, 20), 0.2), 1.0 + i * 0.055, 0.55)
    return master(g, y, 1.4, 0.3)


def fire(g):
    d = 1.3
    t = tb(d)
    n = len(t)
    # the whoosh: noise through a rising, then falling, band
    fc = env(t, ((0, 300), (0.25, 2200), (1.3, 700)))
    whoosh = mk.svf(g.normal(size=n), fc, 0.8) * env(t, ((0, 0), (0.2, 1.0), (0.7, 0.6), (1.3, 0)))
    # the sizzle: crackles
    crack = mk.crackle(g, d, 0.15, 1.25, ((0, 25), (1.3, 60)), ((0, 0.5), (1.3, 0.2)), 2500, 9000)
    y = 0.8 * whoosh + 0.5 * crack + 0.4 * mk.thump(d, 70, 40, 0.2, 0.3)
    return master(g, y, 0.5, 0.1)


SOUNDS = [
    ("taunt_laugh", "Taunt.Laugh", laugh),
    ("taunt_cool", "Taunt.Cool", cool),
    ("taunt_angry", "Taunt.Angry", angry),
    ("taunt_cry", "Taunt.Cry", cry),
    ("taunt_love", "Taunt.Love", love),
    ("taunt_shock", "Taunt.Shock", shock),
    ("taunt_silly", "Taunt.Silly", silly),
    ("taunt_skull", "Taunt.Skull", skull),
    ("taunt_fire", "Taunt.Fire", fire),
]


def main():
    os.makedirs(mk.OUT, exist_ok=True)
    os.makedirs(REVIEW, exist_ok=True)
    want = set(sys.argv[1:])
    for name, key, fn in SOUNDS:
        if want and name not in want:
            continue
        g = np.random.default_rng(zlib.crc32(name.encode()))
        y = mk.save(name, fn(g))
        st = mk.stats(y, False)
        mk.sheet(name, key, y, st, os.path.join(REVIEW, name + ".png"))
        print(f"{name:14s} {len(y) / SR:5.2f}s peak {st['peak']:6.2f} rms {st['rms']:6.1f} clips {st['clips']}", flush=True)
    print("DONE", mk.OUT, flush=True)


if __name__ == "__main__":
    main()
