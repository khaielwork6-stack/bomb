"""FUSE VALLEY — the gameplay / reward SFX pack, sound-designed in-house (Asset Bible §9.2; DECISIONS 2026-10-17:
library sounds + sounds made in code, never AI, never samples we don't own).

Same school as make_ticks.py / make_ui.py — every sound is built from first principles in numpy:
  * modal synthesis: struck objects are banks of damped sinusoids excited by a shaped pulse (iron, wood, steel, bells);
  * shaped noise: band-limited noise through fixed or moving (state-variable) filters — air, steam, scrapes, debris;
  * sub thumps: pitch-dropping sines for the weight you feel on a phone speaker;
  * additive brass: harmonics whose roll-off opens with loudness (the "blat"), with a lip scoop and vibrato;
  * additive formant voices: band-limited glottal saws through vowel formant banks (choir, crowd);
  * a synthetic (noise) reverb, and tanh glue on the master; peaks normalised to -1 dBFS.
Loops (Bomb.Critical, Crowd.Chant, Reward.CrateRattle) are rendered circularly (events and reverb wrap around), so
the last sample flows into the first with no crossfade.

  key                    file                       what it is
  Bomb.Ignite            bomb_ignite.wav            match strike + flare + the fuse catching (hands over to FuseHiss)
  Bomb.Critical          bomb_critical_loop.wav     endless-rising whistle (Shepard glide) + kettle overtone, 1 s loop
  Boom.Far               boom_far.wav               low-passed distant boom with hill echoes
  Fuse.Snuff             fuse_snuff.wav             steam hiss cut off by a "pft"
  Bomb.Release           bomb_release.wav           the clamp's latch click (spring + latch pop)
  Bomb.Drop              bomb_drop.wav              heavy iron clunk, a bounce, a short roll
  Clutch.Choir           clutch_choir.wav           bright choral "aah" chord hit + gold shimmer
  Field.Detonate         field_detonate.wav         rolling firecracker chain into a big low boom
  Crowd.Chant            crowd_chant_loop.wav       stadium "HEY! HEY! HEY!" with stomps and claps, 4 s loop (120 BPM)
  Crowd.Groan            crowd_groan.wav            a stadium's descending "ohhh"
  Stinger.Bombers        stinger_bombers.wav        menacing low brass stab + taiko hit
  Stinger.BombersWin     stinger_bombers_win.wav    triumphant-menacing brass + timpani phrase
  Reward.CrateRattle     crate_rattle_loop.wav      a wooden crate shaken twice a second, 1 s loop
  Reward.CratePop        crate_pop.wav              wooden lid pop + confetti burst
  Reward.CrateLegendary  crate_legendary.wav        brass fanfare flourish
  Defuse                 defuse.wav                 a short whoosh into a snuff
  PassWhoosh             pass_whoosh.wav            the bomb tumbling past: doppler whoosh
  Stamp                  stamp.wav                  rubber ink stamp on paper on a desk
  LevelUp                level_up.wav               bright bell-and-brass fanfare jingle
  QuestDone              quest_done.wav             two-note success chime + sparkle
  Dash                   dash.wav                   quick air burst
  HardStop               hard_stop.wav              sneaker skid squeak + foot-plant thud
  Slide                  slide.wav                  cloth-on-ground slide scrape
  Land                   land.wav                   soft landing thump
  Footstep1..4           footstep_1..4.wav          four light steps on concrete (heel + toe)

Run: python -I art/audio/make_sfx.py [name ...]
  48 kHz, 16-bit mono WAVs in art/out/Audio/SFX/; a waveform + spectrogram review sheet per sound (and 8-up contact
  sheets) in art/out/Audio/SFX_review/ — kept out of SFX/ so the uploader never sees them.
"""

import math
import os
import sys
import wave
import zlib

import numpy as np
from PIL import Image, ImageDraw
from scipy.signal import butter, fftconvolve, lfilter, sosfilt

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Audio", "SFX")
REVIEW = os.path.join(ROOT, "art", "out", "Audio", "SFX_review")
PEAK = 10 ** (-1.0 / 20)
TAU = 2 * math.pi


# ---------------------------------------------------------------------------------------------------------- basics
def ns(d):
    return int(round(d * SR))


def tb(d):
    return np.arange(ns(d)) / SR


def env(t, pts):
    xs, ys = zip(*pts)
    return np.interp(t, xs, ys)


def place(y, x, start, gain=1.0, circ=False):
    """Mix x into y at `start` seconds (wrapping around when circ, for loops)."""
    n = len(y)
    i = ns(start)
    if not circ:
        if i < 0:
            x, i = x[-i:], 0
        m = min(len(x), n - i)
        if m > 0:
            y[i : i + m] += gain * x[:m]
        return y
    i %= n
    pos = 0
    while pos < len(x):
        m = min(len(x) - pos, n - i)
        y[i : i + m] += gain * x[pos : pos + m]
        pos += m
        i = 0
    return y


def _sos(kind, f, order):
    return butter(order, f, btype=kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return sosfilt(_sos("lowpass", min(f, SR * 0.45), order), x)


def hp(x, f, order=2):
    return sosfilt(_sos("highpass", f, order), x)


def bp(x, lo, hi, order=2):
    return sosfilt(_sos("bandpass", [lo, min(hi, SR * 0.45)], order), x)


def cnoise(g, n, lo=20.0, hi=20000.0, tilt=0.0):
    """Unit-RMS noise shaped in the frequency domain (circular, so it loops seamlessly). tilt: dB/oct ÷ 6."""
    x = np.fft.rfft(g.normal(size=n))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-6
    m = 1 / np.sqrt(1 + (lo / f) ** 4) / np.sqrt(1 + (f / hi) ** 4) * (f / 1000) ** tilt
    m[0] = 0
    y = np.fft.irfft(x * m, n)
    return y / (np.std(y) + 1e-12)


def wobble(g, n, hz):
    """Slow unit-RMS random modulation (band-limited to `hz`)."""
    return cnoise(g, n, 0.05, hz)


def pulse(ms):
    """A raised-cosine striking pulse: its width is the hardness of the hammer (0.1 ms steel, 2 ms felt)."""
    n = max(3, ns(ms / 1000))
    p = np.hanning(n)
    return p / p.sum()


def strike(g, dur, freqs, amps, decays_ms, hard_ms=0.3, noise=0.0, jitter=0.0):
    """A struck object: modal impulse response (sin, phase 0 — no step) convolved with the hammer pulse."""
    t = tb(dur)
    ir = np.zeros_like(t)
    for f, a, d in zip(freqs, amps, decays_ms):
        f *= 1 + g.normal(0, jitter)
        if f < SR * 0.45:
            ir += a * np.exp(-t / (d / 1000)) * np.sin(TAU * f * t)
    exc = pulse(hard_ms)
    if noise:
        k = np.arange(len(exc) * 4)
        nb = g.normal(size=len(k)) * np.exp(-k / len(exc)) * noise / len(exc)
        exc = np.concatenate([exc, np.zeros(len(k) - len(exc))]) + nb
    y = fftconvolve(ir, exc)[: len(t)]
    return taper(y / (np.max(np.abs(y)) + 1e-12))


def thump(dur, f0, f1, drop_s, decay_s, attack_ms=1.0):
    """A pitch-dropping sine: the weight of a hit."""
    t = tb(dur)
    f = f1 + (f0 - f1) * np.exp(-t / drop_s)
    ph = TAU * np.cumsum(f) / SR
    return taper(np.exp(-t / decay_s) * np.clip(t / (attack_ms / 1000), 0, 1) * np.sin(ph), 0.2)


def burst(g, ms, decay_ms=None, tail=0.01):
    """A short noise excitation (hann-shaped, or exponential with decay_ms), with room for a filter's ring."""
    n = max(4, ns(ms / 1000))
    k = np.arange(n) / SR
    shape = np.exp(-k / (decay_ms / 1000)) if decay_ms else np.hanning(n)
    e = g.normal(size=n) * shape
    a = min(n, 12)
    e[:a] *= np.linspace(0, 1, a)
    e[-a:] *= np.linspace(1, 0, a)
    return np.concatenate([e, np.zeros(ns(tail))])


def svf(x, fc, q, mode="bp"):
    """A time-varying TPT state-variable filter (stable at any cutoff). bp output is peak-normalised."""
    fc = np.broadcast_to(np.asarray(fc, float), x.shape)
    gg = np.tan(np.pi * np.minimum(fc, SR * 0.45) / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + gg * (gg + k))
    a2 = gg * a1
    a3 = gg * a2
    ic1 = ic2 = 0.0
    out = np.empty(len(x))
    xs, A1, A2, A3 = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist()
    band = mode == "bp"
    for i in range(len(xs)):
        v3 = xs[i] - ic2
        v1 = A1[i] * ic1 + A2[i] * v3
        v2 = ic2 + A2[i] * ic1 + A3[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1 * k if band else v2
    return out


def crackle(g, dur, t0, t1, rate_pts, amp_pts, lo, hi, width_ms=(0.15, 0.6), circ=False):
    """Poisson clicks (sparks, grit, paper): rate and level follow breakpoint envelopes over absolute time."""
    y = np.zeros(ns(dur))
    t = t0
    while True:
        rate = max(1e-3, float(env(np.array([t]), rate_pts)[0]))
        t += g.exponential(1 / rate)
        if t >= t1:
            break
        a = float(env(np.array([t]), amp_pts)[0]) * g.uniform(0.25, 1.0)
        place(y, burst(g, g.uniform(*width_ms), tail=0.0) * a, t, circ=circ)
    return bp(y, lo, hi, 2)


def saw(f, phase0=0.0):
    """Band-limited (polyBLEP) sawtooth following the frequency array f."""
    dt = f / SR
    p = (np.cumsum(dt) + phase0) % 1.0
    y = 2 * p - 1
    m = p < dt
    x = p[m] / dt[m]
    y[m] -= x + x - x * x - 1
    m = p > 1 - dt
    x = (p[m] - 1) / dt[m]
    y[m] -= x * x + x + x + 1
    return y


def make_ir(g, rt60, lp_hz=6000, hf=0.5, predelay=0.012, build_ms=18):
    """A synthetic room: decaying noise, darker as it decays (high band dies at hf × rt60)."""
    dur = rt60 * 1.15
    t = tb(dur)
    w = g.normal(size=len(t))
    ir = lp(w, 2200) * np.exp(-6.91 * t / rt60) + 0.6 * hp(w, 2200) * np.exp(-6.91 * t / (rt60 * hf))
    ir = lp(ir, lp_hz) * np.clip(t / (build_ms / 1000), 0, 1)
    ir = np.concatenate([np.zeros(ns(predelay)), ir])
    return ir / np.sqrt(np.sum(ir**2))


def reverb(x, ir, wet):
    return x + wet * fftconvolve(x, ir)[: len(x)]


def reverb_circ(x, ir, wet):
    n = len(x)
    fold = np.zeros(n)
    for i in range(0, len(ir), n):
        seg = ir[i : i + n]
        fold[: len(seg)] += seg
    return x + wet * np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(fold), n)


def norm(x):
    return x / (np.max(np.abs(x)) + 1e-12)


def taper(y, frac=0.25):
    """Raised-cosine fade over the last `frac` of a layer's buffer, so no layer is ever cut off mid-ring."""
    k = max(2, int(len(y) * frac))
    y[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, k))
    return y


# --------------------------------------------------------------------------------------------- voices & instruments
# Formant tables: (Hz, dB, bandwidth Hz). Speech vowels (adult male; ×1.17 for female) and the classic choir "a" set.
V_A = [(730, 0, 80), (1090, -5, 90), (2440, -14, 120), (3400, -22, 150)]
V_E = [(530, 0, 70), (1840, -5, 90), (2480, -9, 120), (3500, -20, 150)]
V_I = [(300, 0, 60), (2250, -7, 90), (3000, -11, 120), (3600, -20, 150)]
V_O = [(500, 0, 70), (850, -5, 80), (2500, -22, 120), (3300, -30, 150)]
V_U = [(330, 0, 60), (800, -9, 80), (2250, -26, 120), (3300, -34, 150)]
V_ER = [(490, 0, 70), (1350, -4, 90), (1690, -10, 110), (3300, -24, 150)]
CH_SOP = [(800, 0, 80), (1150, -6, 90), (2900, -26, 120), (3900, -16, 130), (4950, -40, 140)]
CH_ALT = [(800, 0, 80), (1150, -4, 90), (2800, -18, 120), (3500, -30, 130), (4950, -50, 140)]
CH_TEN = [(650, 0, 80), (1080, -6, 90), (2650, -7, 120), (2900, -8, 130), (3250, -22, 140)]
CH_BAS = [(600, 0, 60), (1040, -7, 70), (2250, -9, 110), (2450, -9, 120), (2750, -20, 130)]


def reson(x, f, bw):
    r = math.exp(-math.pi * bw / SR)
    c = (1 - r * r) / 2
    return lfilter([c, 0, -c], [1, -2 * r * math.cos(TAU * f / SR), r * r], x)


def formants(x, table, fs=1.0):
    y = np.zeros_like(x)
    for f, db, bw in table:
        if f * fs < SR * 0.45:
            y += 10 ** (db / 20) * reson(x, f * fs, bw * (0.6 + 0.4 * fs))
    return y


def voice(g, dur, f0, voiced_pts, vowels, breath_pts=((0, 0.05),), bright=3000, vib=(5.5, 0.004), jitter=0.004, fs=1.0):
    """One singer / shouter. f0: array (Hz). vowels: [(time, table), ...] crossfaded between keypoints."""
    t = tb(dur)
    n = len(t)
    f = np.asarray(f0, float) * (1 + vib[1] * np.sin(TAU * vib[0] * t + g.uniform(0, TAU)) + jitter * wobble(g, n, 9))
    src = lp(saw(f, g.uniform()), bright, 1)
    nz = hp(g.normal(size=n), 500)
    exc = src * env(t, voiced_pts) + 0.5 * nz * env(t, breath_pts)
    times = [v[0] for v in vowels]
    y = np.zeros(n)
    for j, (_, table) in enumerate(vowels):
        w = np.interp(t, times, [1.0 if i == j else 0.0 for i in range(len(vowels))])
        if w.max() > 0:
            y += w * formants(exc, table, fs)
    return y


def brass(g, dur, f0, amp_pts, bright=1.0, scoop=-35, vib=0.0, detune=0.0, fmax=9000):
    """An additive brass voice: the spectrum opens with loudness (a soft note is round, a loud one blares)."""
    t = tb(dur)
    n = len(t)
    e = env(t, amp_pts)
    f = f0 * 2 ** (detune / 1200) * 2 ** ((scoop / 1200) * np.exp(-t / 0.028))
    f = f * (1 + vib * np.sin(TAU * 5.1 * t + g.uniform(0, TAU)) * np.clip((t - 0.25) / 0.3, 0, 1) + 0.0012 * wobble(g, n, 7))
    ph = TAU * np.cumsum(f) / SR + g.uniform(0, TAU)
    b = 0.7 + 7.5 * bright * np.maximum(e, 0) ** 1.4
    y = np.zeros(n)
    for k in range(1, int(fmax / f0) + 1):
        y += np.exp(-(k - 1) / b) * np.sin(k * ph)
    y = y * e + 0.025 * e * bp(g.normal(size=n), 900, 4500)
    return y + 0.35 * reson(y, 1150, 600)


def section(g, dur, notes, amp_pts, players=2, spread=7, bright=1.0, scoop=-35, vib=0.0):
    """A brass section: each note doubled by slightly detuned, slightly late players."""
    y = np.zeros(ns(dur))
    for f in notes:
        for _ in range(players):
            v = brass(g, dur, f, amp_pts, bright * g.uniform(0.9, 1.1), scoop, vib, g.normal(0, spread))
            place(y, v / (1 + 0.15 * len(notes)), g.uniform(0, 0.012))
    return y


def timpani(g, dur, f, vel=1.0):
    t = tb(dur)
    glide = 1 + 0.025 * vel * np.exp(-t / 0.06)
    ratios = (1.0, 1.504, 1.742, 2.0, 2.245, 2.494, 2.8)
    amps = (1.0, 0.55, 0.35, 0.3, 0.2, 0.12, 0.08)
    decs = (1.3, 0.6, 0.45, 0.35, 0.25, 0.17, 0.12)
    ir = np.zeros_like(t)
    for r, a, d in zip(ratios, amps, decs):
        ir += a * np.exp(-t / d) * np.sin(TAU * np.cumsum(f * r * glide) / SR)
    y = fftconvolve(ir, pulse(3.0 - 1.4 * vel))[: len(t)]
    y = norm(y) + 0.5 * thump(dur, f * 1.7, f, 0.012, 0.25) + 0.25 * vel * lp(burst(g, 6, 2, tail=dur)[: len(t)], 1800)
    return taper(y * vel, 0.35)


def taiko(g, dur, f=58):
    y = 1.0 * thump(dur, f * 2.6, f, 0.018, 0.33, 0.6)
    y += 0.45 * strike(g, dur, (f * 1.5, f * 2.3, f * 3.4), (1, 0.6, 0.35), (380, 230, 140), hard_ms=2.0)
    y += 0.55 * lp(burst(g, 7, 2.5, tail=dur)[: ns(dur)], 1600)
    return y


def crash(g, dur, decay=0.9):
    t = tb(dur)
    n = len(t)
    y = (0.7 * hp(g.normal(size=n), 3500, 2) + 0.5 * bp(g.normal(size=n), 5000, 12000)) * np.exp(-t / decay)
    y *= np.clip(t / 0.0015, 0, 1)
    y += 0.4 * strike(g, dur, g.uniform(2500, 11000, 24), g.uniform(0.2, 1, 24), g.uniform(150, 900, 24), 0.2)
    return taper(y, 0.35)


def bell(g, dur, f, decay=0.5, ratios=(1.0, 2.0, 3.01, 4.17, 5.43), amps=(1.0, 0.45, 0.22, 0.1, 0.05), hard=0.12):
    return strike(g, dur, [f * r for r in ratios], amps, [decay * 1000 / (1 + 0.7 * i) for i in range(len(ratios))], hard)


def glint(g, dur, f, decay_ms=120):
    """A glockenspiel-bar ping (free-bar ratios): the gold sparkle."""
    return strike(g, dur, (f, f * 2.756, f * 5.404), (1.0, 0.4, 0.15), (decay_ms, decay_ms * 0.5, decay_ms * 0.25), 0.08)


def sparkle(g, dur, t0, t1, count, lo, hi, amp=1.0, decay=(50, 180), circ=False):
    y = np.zeros(ns(dur))
    for _ in range(count):
        s = g.uniform(t0, t1)
        place(y, glint(g, 0.6, g.uniform(lo, hi), g.uniform(*decay)) * amp * g.uniform(0.3, 1.0), s, circ=circ)
    return y


def note(name):
    names = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3, "Gb": -3, "G": -2, "G#": -1, "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}
    return 440.0 * 2 ** ((names[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


def pft(g, dur, size=1.0):
    """A breathy plosive snuff: the flame blown out."""
    y = lp(burst(g, 45, 22, tail=dur)[: ns(dur)], 1900 * size, 2)
    y += 0.5 * bp(burst(g, 60, 34, tail=dur)[: ns(dur)], 250, 1200)
    y += 0.3 * thump(dur, 170 * size, 95, 0.01, 0.035)
    return y


# ------------------------------------------------------------------------------------------------------- the bomb
def bomb_ignite(g):
    d = 1.15
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    # 1. the strike: a rough head dragged over the box (grainy, bright friction)
    s = tb(0.13)
    grain = np.abs(lp(g.normal(size=len(s)), 260)) * 3
    scratch = bp(g.normal(size=len(s)), 1700, 7500) * (0.35 + grain) * env(s, [(0, 0), (0.012, 1), (0.08, 0.9), (0.13, 0)])
    place(y, scratch * 0.55, 0.003)
    place(y, crackle(g, 0.2, 0.0, 0.12, [(0, 140), (1, 140)], [(0, 1), (1, 1)], 2500, 9000), 0.003, 0.35)
    # 2. the flare: a "fffoomp" — a resonant sweep up through the head catching, a low whump under it
    f = tb(0.5)
    fl_env = env(f, [(0, 0), (0.012, 1), (0.06, 0.75), (0.5, 0)]) ** 1.6
    fl = svf(g.normal(size=len(f)), env(f, [(0, 350), (0.07, 3400), (0.5, 1900)]), 0.9) * fl_env
    fl += 0.45 * bp(g.normal(size=len(f)), 500, 6000) * fl_env**1.5
    place(y, fl * 1.3, 0.105)
    place(y, lp(g.normal(size=len(f)), 320, 2) * env(f, [(0, 0), (0.01, 1), (0.2, 0)]) ** 2, 0.105, 0.5)
    place(y, thump(0.3, 120, 60, 0.02, 0.07), 0.105, 0.3)
    # 3. the fuse catching: a rising whoosh and a burst of sparks settling into a low hiss (FuseHiss takes over)
    w = tb(0.32)
    place(y, svf(g.normal(size=len(w)), env(w, [(0, 600), (0.32, 4200)]), 1.4) * np.sin(np.pi * w / 0.32) ** 1.5, 0.22, 0.6)
    y += crackle(g, d, 0.28, 1.1, [(0.28, 110), (0.5, 70), (1.1, 35)], [(0.28, 0.32), (0.6, 0.16), (1.1, 0.06)], 2200, 10000)
    hiss = hp(g.normal(size=n), 3200, 2) * env(t, [(0, 0), (0.3, 0), (0.42, 0.075), (0.8, 0.05), (1.12, 0)])
    return finish(y + hiss, 1.5, fade_ms=60)


def bomb_critical(g):
    """Endless rising whistle: octave-spaced partials glide up one octave per loop under a fixed bell window
    (Shepard-Risset), so the 1 s file loops seamlessly and still always rises. Phase-chained across the seam."""
    T = 1.0
    t = tb(T)
    n = len(t)
    fmin, K = 330.0, 6
    centre, sigma = math.log2(2100 / fmin), 0.75
    y = np.zeros(n)
    phase = g.uniform(0, TAU)
    for i in range(K):
        p = i + t / T
        f = fmin * 2**p
        ph = phase + TAU * np.cumsum(f) / SR
        y += np.exp(-0.5 * ((p - centre) / sigma) ** 2) * (np.sin(ph) + 0.12 * np.sin(2 * ph))
        phase = ph[-1] % TAU  # component i ends where component i+1 begins
    y *= 1 + 0.25 * cnoise(g, n, 30, 260)  # breath on the whistle
    # kettle overtone: two close high tones beating at 7 Hz (integer Hz, so they are periodic in 1 s)
    y += 0.3 * (np.sin(TAU * 3200 * t) + 0.8 * np.sin(TAU * 3207 * t)) * (1 + 0.2 * cnoise(g, n, 20, 120))
    y += 0.08 * cnoise(g, n, 2600, 7500) * (1 + 0.35 * np.sin(TAU * 8 * t))  # the steam
    y *= 1 + 0.12 * np.sin(TAU * 8 * t)
    return finish(y, 1.3, loop=True)


def boom_far(g):
    d = 3.4
    t = tb(d)
    n = len(t)
    core = np.zeros(n)
    place(core, thump(2.0, 72, 31, 0.05, 0.55, 3.0), 0.003)
    place(core, lp(g.normal(size=n), 230, 4) * env(t, [(0, 0), (0.04, 1), (0.25, 0.7), (d, 0)]) ** 2.4, 0.003, 0.9)
    place(core, lp(burst(g, 30, 25, tail=0.2), 650, 2), 0.003, 0.5)
    y = core.copy()
    for delay, gain, cut in ((0.43, 0.38, 170), (0.97, 0.22, 140), (1.65, 0.11, 120)):
        place(y, lp(core, cut, 2), delay, gain)
    y = reverb(y, make_ir(g, 2.6, lp_hz=900, predelay=0.03), 0.6)
    return finish(lp(y, 520, 2), 2.0, fade_ms=300)


def fuse_snuff(g):
    d = 0.7
    t = tb(d)
    n = len(t)
    cut = 0.2
    hiss = svf(g.normal(size=n), env(t, [(0, 4200), (cut, 7200)]), 0.8) + 0.6 * hp(g.normal(size=n), 3000, 2)
    hiss *= env(t, [(0, 0), (0.025, 0.8), (cut - 0.01, 1), (cut + 0.012, 0)])
    y = hiss * 0.3 + crackle(g, d, 0.0, cut, [(0, 80), (1, 80)], [(0, 0.35), (1, 0.35)], 2500, 9000)
    place(y, pft(g, 0.3), cut - 0.012, 1.4)
    tail = hp(g.normal(size=n), 3800, 2) * env(t, [(0, 0), (cut + 0.02, 0), (cut + 0.06, 0.08), (d, 0)]) ** 1.5
    tail *= 1 + 0.6 * wobble(g, n, 6)
    return finish(y + tail, 1.5, fade_ms=40)


def bomb_release(g):
    d = 0.32
    y = np.zeros(ns(d))
    place(y, strike(g, 0.12, (3100, 4700, 6900, 9200), (0.6, 0.4, 0.25, 0.12), (18, 12, 8, 5), 0.1, noise=0.6), 0.002, 0.7)
    place(y, strike(g, 0.15, (1900, 2850, 4400), (0.8, 0.5, 0.3), (30, 20, 12), 0.15, noise=0.6), 0.024, 1.0)
    place(y, thump(0.1, 270, 140, 0.008, 0.025), 0.024, 0.45)
    s = tb(0.25)
    boing = np.exp(-s / 0.09) * np.sin(TAU * np.cumsum(820 * (1 + 0.03 * np.exp(-s / 0.05) * np.sin(TAU * 31 * s))) / SR)
    place(y, boing * np.clip(s / 0.002, 0, 1), 0.026, 0.14)
    place(y, lp(burst(g, 6, 3, tail=0.05), 900), 0.03, 0.25)
    return finish(y, 1.5, fade_ms=20)


def iron_hit(g, scale=1.0):
    d = 0.6
    y = thump(d, 118, 48, 0.015, 0.11 * scale, 0.8)
    y += 0.55 * strike(g, d, (310, 780, 1240, 1870, 2650, 3700), (0.7, 0.45, 0.35, 0.2, 0.12, 0.06), [x * scale for x in (150, 95, 65, 42, 26, 14)], 0.35, noise=0.8)
    y += 0.5 * lp(burst(g, 9, 3, tail=d)[: ns(d)], 1600)
    return y


def bomb_drop(g):
    d = 1.15
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    place(y, iron_hit(g, 1.0), 0.003, 1.0)
    place(y, iron_hit(g, 0.55), 0.19, 0.33)
    # the roll: bumps of a lumpy iron ball (rate slowing 9 → 5 Hz), each lightly ringing the shell, over gritty rumble
    r = t[t >= 0.23] - 0.23
    rate = 9 - 4 * np.clip(r / 0.8, 0, 1)
    rot = np.abs(np.sin(np.pi * np.cumsum(rate) / SR)) ** 6
    roll_env = env(r, [(0, 0), (0.03, 1), (0.82, 0)]) ** 1.3
    rumble = (lp(g.normal(size=len(r)), 480, 4) + 0.5 * bp(g.normal(size=len(r)), 150, 420)) * (0.35 + rot) * roll_env
    ring = fftconvolve(rot * roll_env * 0.02, strike(g, 0.15, (310, 780, 1240), (1, 0.5, 0.3), (60, 35, 20), 0.5))[: len(r)]
    grit = crackle(g, len(r) / SR, 0, 0.8, [(0, 90), (0.8, 30)], [(0, 0.25), (0.8, 0.05)], 1500, 6000)
    place(y, rumble * 0.5 + ring * 0.6 + grit, 0.23)
    return finish(y, 1.8, fade_ms=80)


# ---------------------------------------------------------------------------------------------- big moments
def clutch_choir(g):
    d = 2.6
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    parts = [
        (CH_BAS, "C3", 6, 1.0),
        (CH_TEN, "G3", 6, 0.9),
        (CH_TEN, "C4", 5, 0.8),
        (CH_ALT, "E4", 6, 0.85),
        (CH_ALT, "G4", 5, 0.8),
        (CH_SOP, "C5", 6, 0.8),
        (CH_SOP, "E5", 6, 0.6),
        (CH_SOP, "G5", 4, 0.55),
    ]
    for table, nm, count, lvl in parts:
        f0 = note(nm)
        for _ in range(count):
            lag = g.uniform(0, 0.022)
            pk = g.uniform(0.85, 1.0)
            pts = [(0, 0), (0.03, pk), (0.2, 0.38 * pk), (0.5, 0.42 * pk), (1.1, 0.34 * pk), (1.7, 0)]
            drift = 2 ** (g.normal(0, 9) / 1200 + 0.0024 * wobble(g, n, 1.5))  # ±9 cents spread, slow wander
            f = f0 * drift * (1 + 0.008 * np.exp(-t / 0.035))  # a hair sharp on the attack, settling
            v = voice(g, d, f, pts, [(0, table)], [(0, 0.02), (0.035, 0.08), (1.7, 0)], bright=4200, vib=(g.uniform(4.6, 6.2), g.uniform(0.003, 0.007)), jitter=0.006)
            place(y, v * lvl / count, lag)
    y = norm(hp(y, 110, 2))
    # the hit's weight: a soft low boom under the chord
    place(y, timpani(g, 2.0, note("C2"), 0.8), 0.004, 0.35)
    # gold shimmer: a quick glock arpeggio on the chord, sparkles, and a shimmering high air
    for i, nm in enumerate(("C7", "E7", "G7", "C8")):
        place(y, glint(g, 1.3, note(nm), 260), 0.004 + 0.035 * i, 0.22)
    y += 0.18 * sparkle(g, d, 0.12, 1.4, 26, 3500, 9000)
    air = hp(g.normal(size=n), 6500, 2) * env(t, [(0, 0), (0.03, 1), (0.6, 0.6), (1.7, 0)]) * (1 + 0.5 * np.sin(TAU * 11 * t))
    y += 0.05 * air
    y = reverb(y, make_ir(g, 2.3, lp_hz=7000, predelay=0.02), 0.3)
    return finish(y, 1.2, fade_ms=200)


def field_detonate(g):
    d = 3.4
    t = tb(d)
    n = len(t)
    chain = np.zeros(n)
    k_total = 36
    for k in range(k_total):
        s = 0.01 + 0.78 * (k / k_total) ** 0.8 + g.normal(0, 0.006)
        level = (0.45 + 0.55 * k / k_total) * g.uniform(0.55, 1.0)
        c = np.zeros(ns(0.05))
        place(c, bp(burst(g, g.uniform(1.0, 2.6), 0.5, tail=0.03), g.uniform(900, 1800), g.uniform(5000, 9500)), 0.0)
        c = norm(c) + 0.35 * thump(0.05, 420, 180, 0.004, 0.012, 0.3)
        place(chain, lp(c, g.uniform(3500, 12000)) * level, max(0.004, s))
    chain = reverb(chain, make_ir(g, 0.7, lp_hz=6000, predelay=0.008), 0.5)
    boom = np.zeros(n)
    b0 = 0.83
    place(boom, thump(2.4, 92, 30, 0.04, 0.6, 1.5), b0, 1.1)
    place(boom, lp(burst(g, 25, 9, tail=0.1), 3200), b0, 0.9)
    body = lp(g.normal(size=n), 420, 3) * env(t, [(0, 0), (b0, 0), (b0 + 0.012, 1), (b0 + 0.4, 0.45), (d, 0)]) ** 1.8
    boom += 1.1 * body
    boom += crackle(g, d, b0 + 0.12, 2.4, [(b0, 120), (2.4, 10)], [(b0, 0.35), (2.4, 0.03)], 900, 4500)
    boom = reverb(boom, make_ir(g, 2.4, lp_hz=3000, predelay=0.02), 0.45)
    return finish(1.0 * chain + boom, 2.1, fade_ms=300)


# --------------------------------------------------------------------------------------------------------- crowd
def shout_hey(g, f0, female):
    d = 0.34
    t = tb(d)
    fs = 1.17 if female else 1.0
    f = f0 * 2 ** (env(t, [(0, -1.0), (0.05, 0.6), (0.15, 0.0), (0.28, -3.0)]) / 12)
    voiced = [(0, 0), (0.03, 0), (0.055, 1.0), (0.16, 0.7), (0.24, 0.25), (0.29, 0)]
    breath = [(0, 0), (0.006, 0.9), (0.04, 0.6), (0.06, 0.12), (0.24, 0.06), (0.29, 0)]
    return voice(g, d, f, voiced, [(0, V_E), (0.14, V_E), (0.25, V_I)], breath, bright=4200, vib=(6.0, 0.004), jitter=0.012, fs=fs)


def stomp(g):
    return 0.9 * thump(0.3, 105, 48, 0.015, 0.07, 1.5) + 0.4 * lp(burst(g, 14, 5, tail=0.3)[: ns(0.3)], 700)


def clap(g):
    c = bp(burst(g, 1.5, 0.9, tail=0.03), 700, 3600)
    return norm(c + 0.4 * reson(c, g.uniform(1000, 1600), 300))


def crowd_bed(g, d, voices, level_db=0.0, circ=False):
    """Stadium murmur: babbling voices, random vowels at syllable rate."""
    y = np.zeros(ns(d))
    tables = (V_A, V_E, V_O, V_ER, V_U, V_I)
    for _ in range(voices):
        female = g.uniform() < 0.4
        base = g.uniform(190, 280) if female else g.uniform(95, 160)
        s = g.uniform(0, d)
        end = s + d
        while s < end:
            ln = g.uniform(0.12, 0.32)
            tt = tb(ln + 0.05)
            f = base * 2 ** (g.normal(0, 1.5) / 12 + env(tt, [(0, 0), (ln, g.normal(0, 1.5) / 12)]))
            a, b = tables[g.integers(len(tables))], tables[g.integers(len(tables))]
            pts = [(0, 0), (0.03, 1), (ln - 0.03, 0.8), (ln, 0)]
            v = voice(g, ln + 0.05, f, pts, [(0, a), (ln, b)], [(0, 0.1), (ln, 0.1), (ln + 0.02, 0)], bright=2400, fs=1.17 if female else 1.0)
            place(y, v * g.uniform(0.4, 1.0), s, circ=circ)
            s += ln + g.uniform(0.02, 0.25)
    return norm(y) * 10 ** (level_db / 20)


def crowd_chant(g):
    T = 4.0
    beat = 0.5
    n = ns(T)
    y = np.zeros(n)
    hey_beats = (0, 1, 2, 4, 5, 6)
    people = [(g.uniform() < 0.35, g.normal(0, 0.009)) for _ in range(40)]
    for female, lag in people:
        f0 = g.uniform(260, 420) if female else g.uniform(150, 250)
        for b in hey_beats:
            if g.uniform() < 0.92:
                place(y, shout_hey(g, f0 * 2 ** (g.normal(0, 0.4) / 12), female) * g.uniform(0.6, 1.0), b * beat + lag + g.normal(0, 0.007) - 0.05, circ=True)
    y = norm(y)
    st = np.zeros(n)
    for b in range(8):
        for _ in range(16):
            place(st, stomp(g) * g.uniform(0.5, 1.0), b * beat + g.normal(0, 0.012) - 0.01, circ=True)
    cl = np.zeros(n)
    for b in (3.0, 3.5, 7.0, 7.5):
        for _ in range(28):
            place(cl, clap(g) * g.uniform(0.4, 1.0), b * beat + g.normal(0, 0.009), circ=True)
    y = y + 0.5 * norm(st) + 0.45 * norm(cl) + crowd_bed(g, T, 18, -20, circ=True)
    y = reverb_circ(y, make_ir(g, 1.6, lp_hz=5000, predelay=0.03), 0.38)
    return finish(y, 1.6, loop=True)


def crowd_groan(g):
    d = 2.1
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    for _ in range(42):
        female = g.uniform() < 0.4
        f0 = g.uniform(230, 340) if female else g.uniform(125, 200)
        drop = g.uniform(8, 11)
        on = g.uniform(0.0, 0.12)
        end = g.uniform(1.35, 1.6)
        lift = 1.5 * np.clip(t / 0.18, 0, 1)  # "oh-" lifts a little, then the whole stadium sinks
        f = f0 * 2 ** ((lift - (drop + 1.5) * np.clip((t - 0.18) / (end - 0.18), 0, 1) ** 1.2) / 12)
        voiced = [(0, 0), (on, 0), (on + g.uniform(0.1, 0.22), 1.0), (0.55, 0.85), (end - 0.2, 0.5), (end, 0)]
        breath = [(0, 0), (on, 0.15), (0.4, 0.06), (end - 0.2, 0.12), (end + 0.1, 0)]
        v = voice(g, d, f, voiced, [(0, V_O), (0.8, V_O), (1.35, V_U)], breath, bright=2600, vib=(g.uniform(4.5, 6), 0.006), jitter=0.01, fs=1.17 if female else 1.0)
        place(y, v * g.uniform(0.6, 1.0), 0.0)
    y = norm(y) + crowd_bed(g, d, 14, -16) * env(t, [(0, 1), (0.4, 0.4), (1.6, 0.6), (d, 0)])
    y = reverb(y, make_ir(g, 1.8, lp_hz=4500, predelay=0.025), 0.55)
    return finish(y * env(t, [(0, 0), (0.01, 1), (d, 1)]), 1.4, fade_ms=200)


# -------------------------------------------------------------------------------------------------------- stingers
def stinger_bombers(g):
    d = 1.7
    y = np.zeros(ns(d))
    stab = [(0, 0), (0.014, 1.0), (0.09, 0.62), (0.32, 0.5), (0.5, 0)]
    place(y, section(g, d, [note(x) for x in ("D2", "A2", "D3", "F3", "Ab3")], stab, players=2, bright=1.1, scoop=-50), 0.004)
    y = norm(y)
    place(y, taiko(g, 1.2, 56), 0.004, 1.0)
    place(y, crash(g, 2.5, 0.55), 0.004, 0.18)
    y = reverb(y, make_ir(g, 1.8, lp_hz=5000, predelay=0.018), 0.4)
    return finish(y, 1.8, fade_ms=200)


def stinger_bombers_win(g):
    d = 2.8
    y = np.zeros(ns(d))
    br = np.zeros(ns(d))
    short = [(0, 0), (0.012, 1.0), (0.06, 0.7), (0.1, 0.55), (0.14, 0)]
    for s, notes, lvl in ((0.0, ("D3", "A3"), 0.75), (0.16, ("D3", "A3"), 0.75), (0.32, ("F3", "C4"), 0.85)):
        place(br, section(g, 0.5, [note(x) for x in notes], short, 2, bright=1.0) * lvl, s + 0.004)
    held = [(0, 0), (0.02, 1.0), (0.12, 0.7), (0.55, 0.8), (0.62, 0)]
    place(br, section(g, 0.9, [note(x) for x in ("Bb2", "F3", "Bb3", "D4")], held, 2, bright=1.0, vib=0.004), 0.5)
    place(br, section(g, 0.3, [note(x) for x in ("C3", "G3", "C4")], short, 2, bright=0.9) * 0.8, 1.16)
    final = [(0, 0), (0.02, 1.0), (0.14, 0.7), (0.5, 0.85), (0.72, 1.0), (0.8, 0)]
    place(br, section(g, 1.2, [note(x) for x in ("D2", "A2", "D3", "F3", "A3", "D4")], final, 2, bright=1.15, vib=0.005), 1.3)
    y += norm(br)
    timp = np.zeros(ns(d))
    for s, v in ((0.0, 0.8), (0.16, 0.6), (0.32, 0.7), (0.5, 0.9)):
        place(timp, timpani(g, 2.2, note("D2") if s != 0.5 else note("Bb1"), v), s + 0.004)
    for s in np.arange(1.0, 1.29, 0.034):  # the roll into the last chord
        place(timp, timpani(g, 1.2, note("A1"), 0.25 + 0.5 * (s - 1.0) / 0.29), s + g.normal(0, 0.003))
    place(timp, timpani(g, 2.5, note("D2"), 1.0), 1.3)
    y += 0.8 * norm(timp)
    place(y, taiko(g, 1.4, 50), 1.3, 0.6)
    place(y, crash(g, 1.5, 0.7), 1.3, 0.16)
    y = reverb(y, make_ir(g, 1.9, lp_hz=5000, predelay=0.018), 0.4)
    return finish(y, 1.7, fade_ms=250)


# --------------------------------------------------------------------------------------------------------- rewards
def crate_shake(g, d):
    y = np.zeros(ns(d))
    place(y, strike(g, 0.3, (210, 470, 820, 1300, 2050), (1.0, 0.6, 0.4, 0.25, 0.12), (55, 40, 28, 18, 10), 0.8, noise=0.5), 0.0, 0.8)
    place(y, thump(0.2, 140, 80, 0.01, 0.04), 0.0, 0.35)
    for lid in (0.055, 0.115):
        place(y, strike(g, 0.15, (600, 1350, 2400, 3300), (1, 0.6, 0.35, 0.15), (25, 18, 11, 6), 0.5, noise=0.6, jitter=0.03), lid + g.normal(0, 0.004), g.uniform(0.35, 0.55))
    s = 0.01
    for _ in range(g.integers(10, 15)):
        s += g.exponential(0.018)
        if s > 0.3:
            break
        fr = g.uniform(900, 2600)
        place(y, strike(g, 0.08, (fr, fr * 1.63, fr * 2.4), (1, 0.5, 0.25), (g.uniform(8, 20), 8, 5), 0.3, noise=0.8), s, 0.35 * math.exp(-s / 0.18) * g.uniform(0.4, 1))
    return y


def crate_rattle(g):
    T = 1.0
    y = np.zeros(ns(T))
    for s in (0.0, 0.5):
        place(y, crate_shake(g, 0.45), s + g.normal(0, 0.004), circ=True)
    y = reverb_circ(y, make_ir(g, 0.35, lp_hz=6000, predelay=0.006), 0.35)
    return finish(y, 1.6, loop=True)


def crate_pop(g):
    d = 1.15
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    place(y, thump(0.08, 760, 190, 0.007, 0.022, 0.4), 0.003, 0.75)
    place(y, lp(burst(g, 5, 1.6, tail=0.02), 2600), 0.003, 0.8)
    place(y, strike(g, 0.2, (520, 1180, 2050, 3100), (1, 0.6, 0.35, 0.18), (40, 25, 15, 9), 0.5, noise=0.6), 0.004, 0.6)
    place(y, strike(g, 0.25, (380, 900, 1700), (1, 0.55, 0.3), (50, 30, 15), 0.7, noise=0.6), 0.17, 0.4)
    place(y, thump(0.15, 160, 90, 0.01, 0.035), 0.17, 0.2)
    # confetti: the popper's burst, then paper fluttering down
    c = tb(0.4)
    place(y, svf(g.normal(size=len(c)), env(c, [(0, 2000), (0.05, 7000), (0.4, 5000)]), 0.7) * env(c, [(0, 0), (0.004, 1), (0.4, 0)]) ** 3, 0.012, 0.85)
    y += crackle(g, d, 0.04, 1.0, [(0.04, 420), (0.4, 120), (1.0, 20)], [(0.04, 0.3), (0.5, 0.14), (1.0, 0.04)], 2500, 11000, (0.08, 0.35))
    y += 0.06 * hp(g.normal(size=n), 2200, 2) * env(t, [(0, 0), (0.03, 1), (0.9, 0)]) ** 2
    y += 0.12 * sparkle(g, d, 0.06, 0.6, 7, 4500, 8500)
    y = reverb(y, make_ir(g, 0.6, lp_hz=7000, predelay=0.008), 0.25)
    return finish(y, 1.6, fade_ms=80)


def crate_legendary(g):
    d = 2.1
    y = np.zeros(ns(d))
    br = np.zeros(ns(d))
    run = [(0, 0), (0.01, 1.0), (0.05, 0.7), (0.075, 0)]
    for i, nm in enumerate(("A4", "B4", "C#5")):
        place(br, section(g, 0.2, [note(nm), note(nm) / 2], run, 2, bright=1.0, scoop=-20) * 0.8, 0.004 + 0.07 * i)
    hold = [(0, 0), (0.018, 1.0), (0.12, 0.72), (0.75, 0.85), (1.15, 0.0)]
    place(br, section(g, 1.4, [note(x) for x in ("D4", "A4", "D5", "F#5", "A5")], hold, 2, bright=1.1, vib=0.005), 0.214)
    y += norm(br)
    place(y, timpani(g, 2.5, note("D2"), 1.0), 0.214, 0.6)
    place(y, crash(g, 2.5, 0.8), 0.214, 0.2)
    for i, nm in enumerate(("D7", "F#7", "A7", "D8")):
        place(y, glint(g, 1.4, note(nm), 300), 0.22 + 0.04 * i, 0.14)
    y += 0.12 * sparkle(g, d, 0.3, 1.5, 22, 3500, 9500)
    y = reverb(y, make_ir(g, 1.6, lp_hz=6500, predelay=0.016), 0.38)
    return finish(y, 1.6, fade_ms=250)


def level_up(g):
    d = 1.75
    y = np.zeros(ns(d))
    for i, nm in enumerate(("C5", "E5", "G5", "C6")):
        s = 0.004 + 0.075 * i
        place(y, bell(g, 1.8, note(nm), 0.5), s, 0.75)
        place(y, section(g, 0.25, [note(nm)], [(0, 0), (0.008, 1), (0.06, 0.5), (0.1, 0)], 1, bright=0.8, scoop=-15), s, 0.35)
    s = 0.31
    place(y, section(g, 1.3, [note(x) for x in ("C4", "G4", "C5", "E5", "G5")], [(0, 0), (0.02, 1), (0.15, 0.7), (0.6, 0.75), (1.0, 0)], 2, bright=0.9, vib=0.005), s, 0.55)
    for nm in ("C6", "E6", "G6", "C7"):
        place(y, bell(g, 2.4, note(nm), 0.8), s + g.uniform(0, 0.01), 0.3)
    place(y, thump(0.4, 140, 65, 0.02, 0.12), s, 0.4)
    y += 0.2 * sparkle(g, d, s, 1.3, 20, 4000, 9500)
    y = reverb(y, make_ir(g, 1.3, lp_hz=7000, predelay=0.012), 0.3)
    return finish(y, 1.4, fade_ms=200)


def quest_done(g):
    d = 1.05
    y = np.zeros(ns(d))
    for s, nm in ((0.004, "G5"), (0.115, "C6")):
        f = note(nm)
        place(y, bell(g, 1.6, f, 0.42, ratios=(1.0, 2.0, 3.0, 4.2), amps=(1.0, 0.35, 0.18, 0.07)), s, 1.0)
        place(y, glint(g, 0.3, f * 4, 40), s, 0.15)
    y += 0.22 * sparkle(g, d, 0.14, 0.6, 12, 4500, 9000, decay=(40, 120))
    y = reverb(y, make_ir(g, 0.9, lp_hz=8000, predelay=0.01), 0.25)
    return finish(y, 1.3, fade_ms=150)


# -------------------------------------------------------------------------------------------- defuse / flight / UI
def defuse(g):
    d = 0.5
    t = tb(d)
    n = len(t)
    w = svf(g.normal(size=n), env(t, [(0, 3600), (0.18, 750), (d, 600)]), 1.1) * env(t, [(0, 0), (0.05, 1), (0.16, 0.7), (0.24, 0)]) ** 1.5
    y = 0.75 * w + 0.25 * lp(g.normal(size=n), 600) * env(t, [(0, 0), (0.06, 1), (0.22, 0)]) ** 2
    place(y, pft(g, 0.3, 0.85), 0.15, 0.9)
    tail = hp(g.normal(size=n), 4000, 2) * env(t, [(0, 0), (0.18, 0), (0.22, 0.06), (d, 0)]) ** 1.5
    return finish(y + tail, 1.5, fade_ms=40)


def pass_whoosh(g):
    d = 0.6
    t = tb(d)
    n = len(t)
    tc = 0.24
    ratio = 1 + 0.24 * np.tanh(-(t - tc) / 0.045)  # approaching high, receding low
    bell_env = np.where(t < tc, np.exp(-0.5 * ((t - tc) / 0.075) ** 2), np.exp(-0.5 * ((t - tc) / 0.11) ** 2))
    tumble = 1 + 0.5 * np.sin(TAU * np.cumsum(11 * ratio) / SR)
    air = svf(g.normal(size=n), 1000 * ratio, 3.0) * 1.6 * tumble + 0.35 * svf(g.normal(size=n), 3000 * ratio, 0.8)
    body = lp(g.normal(size=n), 260, 2) * tumble
    whistle = np.sin(TAU * np.cumsum(690 * ratio) / SR) * (1 + 0.3 * wobble(g, n, 30))
    sparks = crackle(g, d, 0.05, 0.5, [(0, 200), (1, 200)], [(0, 1), (1, 1)], 2500, 9000)
    y = (0.8 * air + 0.45 * body + 0.14 * whistle) * bell_env + 0.22 * sparks * bell_env**2
    return finish(y * env(t, [(0, 0), (0.01, 1), (d, 1)]), 1.6, fade_ms=40)


def stamp(g):
    d = 0.42
    y = np.zeros(ns(d))
    s = 0.004
    place(y, thump(0.25, 150, 72, 0.012, 0.055, 0.8), s, 1.0)
    place(y, strike(g, 0.3, (190, 410, 780, 1350), (0.6, 0.4, 0.25, 0.12), (60, 40, 25, 15), 1.2), s, 0.7)
    place(y, bp(burst(g, 6, 2, tail=0.03), 800, 5000), s, 0.55)
    place(y, lp(burst(g, 20, 8, tail=0.04), 1500), s + 0.002, 0.3)
    y += crackle(g, d, 0.165, 0.2, [(0, 260), (1, 260)], [(0, 0.12), (1, 0.12)], 2000, 7000)
    t = tb(d)
    y += 0.05 * hp(g.normal(size=len(t)), 1500) * env(t, [(0, 0), (0.165, 0), (0.18, 1), (0.22, 0)])
    y = reverb(y, make_ir(g, 0.28, lp_hz=5000, predelay=0.004), 0.18)
    return finish(y, 1.8, fade_ms=30)


# --------------------------------------------------------------------------------------------------------- movement
def dash(g):
    d = 0.34
    t = tb(d)
    n = len(t)
    e = env(t, [(0, 0), (0.007, 1), (0.04, 0.8), (0.3, 0)]) ** 2.2
    air = svf(g.normal(size=n), env(t, [(0, 650), (0.03, 2600), (0.3, 1300)]), 0.9) * e
    body = lp(g.normal(size=n), 380, 2) * env(t, [(0, 0), (0.005, 1), (0.12, 0)]) ** 2
    hiss = hp(g.normal(size=n), 5000, 2) * env(t, [(0, 0), (0.004, 1), (0.05, 0)])
    y = air + 0.6 * body + 0.15 * hiss
    place(y, thump(0.15, 95, 50, 0.01, 0.05, 2.0), 0.002, 0.4)
    return finish(y, 1.5, fade_ms=30)


def hard_stop(g):
    d = 0.4
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    place(y, thump(0.3, 130, 58, 0.012, 0.065, 0.8), 0.003, 0.9)
    place(y, lp(burst(g, 22, 7, tail=0.05), 900), 0.003, 0.6)
    place(y, strike(g, 0.2, (180, 330, 560), (1, 0.5, 0.25), (35, 22, 12), 1.5, noise=0.4), 0.003, 0.4)
    place(y, lp(burst(g, 18, 6, tail=0.05), 900), 0.085, 0.35)
    # the squeak: rubber stick-slip — a harmonic tone with a jittery rising pitch and a rough amplitude
    sq = tb(0.2)
    f = env(sq, [(0, 1550), (0.03, 1950), (0.2, 1750)]) * (1 + 0.025 * wobble(g, len(sq), 45))
    ph = TAU * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    rough = 1 + 0.35 * wobble(g, len(sq), 90)
    sq_env = env(sq, [(0, 0), (0.006, 1), (0.12, 0.75), (0.18, 0)])
    place(y, tone * rough * sq_env, 0.008, 0.38)
    place(y, bp(g.normal(size=len(sq)), 2000, 6500) * sq_env, 0.008, 0.12)
    return finish(y, 1.6, fade_ms=30)


def slide(g):
    d = 0.58
    t = tb(d)
    n = len(t)
    e = env(t, [(0, 0), (0.015, 1), (0.26, 0.85), (0.56, 0)]) ** 1.4
    grain = 0.35 + np.abs(lp(g.normal(size=n), 90)) * 2.2
    scrape = (svf(g.normal(size=n), env(t, [(0, 2300), (d, 900)]), 0.75) + 0.5 * bp(g.normal(size=n), 350, 3500)) * grain
    cloth = hp(g.normal(size=n), 3000, 2) * (1 + 0.4 * wobble(g, n, 14))
    rumble = lp(g.normal(size=n), 240, 2)
    y = (0.75 * scrape + 0.22 * cloth + 0.4 * rumble) * e
    y += crackle(g, d, 0.02, 0.5, [(0, 70), (0.5, 20)], [(0, 0.35), (0.5, 0.05)], 1500, 6000)
    place(y, thump(0.15, 110, 60, 0.01, 0.04, 2.0), 0.002, 0.35)
    return finish(y, 1.5, fade_ms=40)


def land(g):
    d = 0.32
    t = tb(d)
    n = len(t)
    y = np.zeros(n)
    place(y, thump(0.3, 125, 60, 0.015, 0.045, 1.5), 0.003, 0.9)
    place(y, strike(g, 0.25, (175, 310, 520, 840), (1.0, 0.6, 0.35, 0.15), (45, 30, 18, 10), 2.0, noise=0.4), 0.003, 0.55)
    place(y, lp(burst(g, 40, 12, tail=0.05), 1300), 0.003, 0.75)
    place(y, lp(burst(g, 25, 8, tail=0.05), 1100), 0.022, 0.35)  # the second foot
    y += 0.12 * hp(g.normal(size=n), 2200) * env(t, [(0, 0), (0.004, 1), (0.06, 0)]) ** 2
    y += crackle(g, d, 0.004, 0.06, [(0, 200), (1, 200)], [(0, 0.2), (1, 0.06)], 1800, 6000)
    return finish(y, 1.6, fade_ms=30)


def footstep(i):
    def make(g):
        d = 0.2
        t = tb(d)
        y = np.zeros(len(t))
        sc = 1 + (i - 2.5) * 0.06 + g.normal(0, 0.02)
        heel = np.zeros(ns(0.06))
        place(heel, bp(burst(g, 2.2, 0.7, tail=0.03), 900 * sc, 6000), 0.0)
        heel = norm(heel) + 0.45 * strike(g, 0.06, (1700 * sc, 2900 * sc, 4300 * sc), (0.3, 0.2, 0.1), (6, 4, 3), 0.25, noise=0.7)
        place(y, heel, 0.003, 0.8)
        place(y, strike(g, 0.08, (260 * sc, 470 * sc, 760 * sc), (1, 0.5, 0.25), (16, 10, 6), 1.2, noise=0.5), 0.003, 0.4)
        place(y, thump(0.06, 190 * sc, 110, 0.006, 0.014, 0.8), 0.003, 0.25)
        toe = 0.026 + 0.004 * i + g.uniform(0, 0.006)
        place(y, lp(burst(g, 3.5, 1.4, tail=0.03), 3600), toe, 0.5)
        sc_env = env(tb(0.05), [(0, 0), (0.003, 1), (0.04, 0)]) ** 2
        place(y, bp(g.normal(size=len(sc_env)), 1500, 7000) * sc_env, toe, 0.25)
        y += crackle(g, d, 0.005, 0.07, [(0, 120), (1, 120)], [(0, 0.15), (1, 0.05)], 2500, 8000)
        return finish(y, 1.4, fade_ms=20)

    return make


# ----------------------------------------------------------------------------------------------- finish & review
def finish(y, drive=1.5, loop=False, fade_ms=12, trim_db=-64):
    y = np.asarray(y, float)
    if loop:
        f = np.fft.rfftfreq(len(y), 1 / SR)
        Y = np.fft.rfft(y)
        Y *= 1 / np.sqrt(1 + (18 / np.maximum(f, 1e-6)) ** 4)
        Y[0] = 0
        y = np.fft.irfft(Y, len(y))
    else:
        y = hp(y, 18, 2)
    y = np.tanh(drive * norm(y)) / math.tanh(drive)
    if loop:
        y -= np.mean(y)  # tanh of an asymmetric wave leaves a hair of DC; a loop can lose it for free
    else:
        y = hp(y, 18, 1)
        idx = np.nonzero(np.abs(y) > 10 ** (trim_db / 20))[0]
        y = y[: min(len(y), idx[-1] + ns(0.03))]
        a = min(ns(0.0005), len(y))
        y[:a] *= np.linspace(0, 1, a)
        fl = min(ns(fade_ms / 1000), len(y) // 3)
        y[-fl:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fl))
    return norm(y) * PEAK, loop


def save(name, y):
    pcm = np.round(np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return pcm.astype(float) / 32767


CMAP = [(0.0, (0, 0, 4)), (0.25, (60, 15, 110)), (0.5, (185, 55, 85)), (0.75, (250, 140, 25)), (1.0, (252, 255, 165))]


def colormap(v):
    xs = [c[0] for c in CMAP]
    return np.stack([np.interp(v, xs, [c[1][k] for c in CMAP]) for k in range(3)], -1).astype(np.uint8)


def stats(y, loop):
    pk = np.max(np.abs(y))
    rms = np.sqrt(np.mean(y**2))
    dc = np.mean(y)
    clips = int(np.sum(np.abs(y) >= 0.9995))
    seam = abs(y[0] - y[-1]) / (np.percentile(np.abs(np.diff(y)), 99.5) + 1e-9) if loop else None
    lead = int(np.argmax(np.abs(y) > 0.01)) / SR * 1000
    return dict(peak=20 * math.log10(pk + 1e-12), rms=20 * math.log10(rms + 1e-12), dc=dc, clips=clips, seam=seam, lead_ms=lead, start=abs(y[0]), end=abs(y[-1]))


def sheet(name, key, y, st, path):
    W, HW, HS = 1200, 170, 330
    img = Image.new("RGB", (W, HW + HS + 34), (18, 18, 22))
    dr = ImageDraw.Draw(img)
    loopy = st["seam"] is not None
    plot = np.concatenate([y, y[: len(y) // 4]]) if loopy else y  # loops: show the seam (+25 % of the start again)
    cols = np.array_split(plot, W)
    mid = 34 + HW // 2
    sc = HW / 2 - 6
    for lvl, colr in ((1.0, (200, 40, 40)), (PEAK, (90, 90, 100))):
        for sg in (-1, 1):
            dr.line([(0, mid - sg * lvl * sc), (W, mid - sg * lvl * sc)], fill=colr)
    for x, c in enumerate(cols):
        if len(c):
            dr.line([(x, mid - c.max() * sc), (x, mid - c.min() * sc)], fill=(120, 200, 255))
            r = np.sqrt(np.mean(c**2))
            dr.line([(x, mid - r * sc), (x, mid + r * sc)], fill=(40, 120, 200))
    if loopy:
        xs = int(W * len(y) / len(plot))
        dr.line([(xs, 34), (xs, 34 + HW)], fill=(255, 220, 0))
    nfft = 2048
    hop = max(48, len(plot) // W)
    pad = np.concatenate([np.zeros(nfft // 2), plot, np.zeros(nfft)])
    frames = np.lib.stride_tricks.sliding_window_view(pad, nfft)[::hop][:W]
    mag = np.abs(np.fft.rfft(frames * np.hanning(nfft), axis=1)) / (nfft / 4)
    db = 20 * np.log10(mag + 1e-9)
    freqs = 30 * (24000 / 30) ** (np.arange(HS)[::-1] / (HS - 1))
    bins = np.clip(freqs / (SR / nfft), 0, nfft // 2)
    spec = np.stack([np.interp(bins, np.arange(nfft // 2 + 1), row) for row in db], 1)
    v = np.clip((spec + 100) / 100, 0, 1)
    im = Image.fromarray(colormap(v)).resize((W, HS))
    img.paste(im, (0, 34 + HW))
    for fq in (100, 1000, 10000):
        yy = 34 + HW + int((1 - math.log(fq / 30) / math.log(24000 / 30)) * (HS - 1))
        dr.line([(0, yy), (12, yy)], fill=(255, 255, 255))
        dr.text((14, yy - 6), f"{fq // 1000}k" if fq >= 1000 else str(fq), fill=(255, 255, 255))
    seam = f"  seam {st['seam']:.2f}x" if loopy else ""
    txt = f"{key}  ({name}.wav)  {len(y) / SR:.2f}s  peak {st['peak']:.2f} dBFS  rms {st['rms']:.1f}  dc {st['dc']:+.4f}  clips {st['clips']}  lead {st['lead_ms']:.0f}ms  first/last {st['start']:.3f}/{st['end']:.3f}{seam}"
    dr.text((8, 10), txt, fill=(235, 235, 235))
    img.save(path)
    return img


SOUNDS = [
    ("bomb_ignite", "Bomb.Ignite", bomb_ignite),
    ("bomb_critical_loop", "Bomb.Critical", bomb_critical),
    ("boom_far", "Boom.Far", boom_far),
    ("fuse_snuff", "Fuse.Snuff", fuse_snuff),
    ("bomb_release", "Bomb.Release", bomb_release),
    ("bomb_drop", "Bomb.Drop", bomb_drop),
    ("clutch_choir", "Clutch.Choir", clutch_choir),
    ("field_detonate", "Field.Detonate", field_detonate),
    ("crowd_chant_loop", "Crowd.Chant", crowd_chant),
    ("crowd_groan", "Crowd.Groan", crowd_groan),
    ("stinger_bombers", "Stinger.Bombers", stinger_bombers),
    ("stinger_bombers_win", "Stinger.BombersWin", stinger_bombers_win),
    ("crate_rattle_loop", "Reward.CrateRattle", crate_rattle),
    ("crate_pop", "Reward.CratePop", crate_pop),
    ("crate_legendary", "Reward.CrateLegendary", crate_legendary),
    ("defuse", "Defuse", defuse),
    ("pass_whoosh", "PassWhoosh", pass_whoosh),
    ("stamp", "Stamp", stamp),
    ("level_up", "LevelUp", level_up),
    ("quest_done", "QuestDone", quest_done),
    ("dash", "Dash", dash),
    ("hard_stop", "HardStop", hard_stop),
    ("slide", "Slide", slide),
    ("land", "Land", land),
    ("footstep_1", "Footstep1", footstep(1)),
    ("footstep_2", "Footstep2", footstep(2)),
    ("footstep_3", "Footstep3", footstep(3)),
    ("footstep_4", "Footstep4", footstep(4)),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REVIEW, exist_ok=True)
    want = set(sys.argv[1:])
    sheets = []
    for name, key, fn in SOUNDS:
        if want and name not in want:
            continue
        g = np.random.default_rng(zlib.crc32(name.encode()))
        y, loop = fn(g)
        y = save(name, y)
        st = stats(y, loop)
        sheets.append(sheet(name, key, y, st, os.path.join(REVIEW, name + ".png")))
        seam = f" seam {st['seam']:.2f}x" if loop else ""
        flag = "  <-- CHECK" if st["clips"] or abs(st["dc"]) > 0.002 or st["lead_ms"] > 15 or (loop and st["seam"] > 1.0) else ""
        print(f"{name:22s} {len(y) / SR:5.2f}s peak {st['peak']:6.2f} rms {st['rms']:6.1f} dc {st['dc']:+.4f} clips {st['clips']} lead {st['lead_ms']:4.0f}ms{seam}{flag}", flush=True)
    if not want:
        for k in range(0, len(sheets), 8):
            group = sheets[k : k + 8]
            cw, ch = 600, group[0].height // 2
            cs = Image.new("RGB", (cw * 2, ch * 4), (0, 0, 0))
            for j, im in enumerate(group):
                cs.paste(im.resize((cw, ch)), ((j % 2) * cw, (j // 2) * ch))
            cs.save(os.path.join(REVIEW, f"_contact_{k // 8 + 1}.png"))
    print("DONE", OUT, flush=True)


if __name__ == "__main__":
    main()
