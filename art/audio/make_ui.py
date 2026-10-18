"""FUSE VALLEY — the UI sound pack, sound-designed in-house (Asset Bible §9.2 UI.* / Reward.*; DECISIONS 2026-10-17:
library sounds + sounds made in code, never AI).

Same approach as make_ticks.py: physical-style modal synthesis, no samples. Each sound is a struck object (a bank of
damped, slightly inharmonic sinusoids) excited by a shaped noise burst, plus a sub "thump" where it should be felt on a
phone, glued with gentle tanh saturation:

  ui_hover.wav    a soft plastic tick (very quiet, short)            — pointer enters a button
  ui_press.wav    an arcade microswitch: the snap down (two clicks)   — button pressed
  ui_release.wav  the lighter snap back up                            — button released
  ui_deny.wav     a muted low double buzz                             — disabled / not enough Stars
  ui_open.wav     a short rising whoosh into a soft pop               — a panel springs open
  ui_close.wav    the reverse: a falling whoosh, no pop               — a panel closes
  ui_tab.wav      a wooden tok                                        — switching tabs
  coin.wav        a bright two-partial chime (pitch-up per coin in game) — a Star lands in the counter
  claim.wav       a three-note rising chime with a sparkle tail       — claiming a reward

Run: python -I art/audio/make_ui.py   (48 kHz, 16-bit mono WAVs in art/out/Audio/UI/)
"""

import math
import os
import wave

import numpy as np

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Audio", "UI")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261018)


def timebase(dur):
    n = int(SR * dur)
    return np.arange(n) / SR


def modes(t, freqs, amps, decays_ms, start=0.0):
    y = np.zeros_like(t)
    on = t >= start
    tt = t[on] - start
    for f, a, d in zip(freqs, amps, decays_ms):
        y[on] += a * np.exp(-tt / (d / 1000)) * np.sin(2 * math.pi * f * tt + RNG.uniform(0, 2 * math.pi))
    return y


def burst(t, start, length_ms, color=0.6):
    """A short noise excitation; `color` 0 = white, 1 = darker (one-pole low-pass)."""
    y = np.zeros_like(t)
    n0 = int(start * SR)
    n = max(1, int(length_ms / 1000 * SR))
    seg = RNG.normal(0, 1, n) * np.hanning(n * 2)[n:] ** 0.5
    lp = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc = acc * color + seg[i] * (1 - color)
        lp[i] = acc
    y[n0 : n0 + n] += lp[: max(0, min(n, len(y) - n0))]
    return y


def thump(t, start, f0, f1, decay_ms, amp):
    y = np.zeros_like(t)
    on = t >= start
    tt = t[on] - start
    f = f1 + (f0 - f1) * np.exp(-tt / 0.02)
    ph = 2 * math.pi * np.cumsum(f) / SR
    y[on] = amp * np.exp(-tt / (decay_ms / 1000)) * np.sin(ph)
    return y


def sweep(t, start, dur, f0, f1, amp, noise=0.6):
    """Band-limited noise whoosh with a moving resonant peak (a crude state-variable filter)."""
    y = np.zeros_like(t)
    n0 = int(start * SR)
    n = int(dur * SR)
    x = RNG.normal(0, 1, n)
    low = band = 0.0
    out = np.zeros(n)
    for i in range(n):
        p = i / n
        f = f0 * (f1 / f0) ** p
        fc = 2 * math.sin(math.pi * min(f, SR / 6) / SR)
        q = 0.35
        high = x[i] - low - q * band
        band += fc * high
        low += fc * band
        out[i] = band * noise + low * (1 - noise) * 0.3
    env = np.sin(np.linspace(0, math.pi, n)) ** 1.5
    y[n0 : n0 + n] = amp * out * env
    return y


def finish(y, gain=1.0, drive=1.6):
    y = np.tanh(y * drive) / np.tanh(drive)
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.89 * gain
    fade = min(len(y), int(0.004 * SR))
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def save(name, y):
    pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name, f"{len(y) / SR:.2f}s")


# hover: a soft plastic tick
t = timebase(0.09)
y = burst(t, 0.0, 1.2, 0.3) * 0.5 + modes(t, [3100, 4870, 7200], [0.5, 0.3, 0.15], [7, 5, 3])
save("ui_hover.wav", finish(y, 0.55, 1.2))

# press: an arcade microswitch snapping down — actuator click then the plunger bottoming out
t = timebase(0.16)
y = burst(t, 0.0, 1.0, 0.2) * 0.8 + modes(t, [2400, 3650, 5900], [0.6, 0.4, 0.2], [14, 9, 5])
y += burst(t, 0.011, 1.4, 0.45) * 0.9 + modes(t, [1250, 1980, 3300], [0.8, 0.45, 0.25], [22, 15, 8], start=0.011)
y += thump(t, 0.011, 210, 95, 28, 0.55)
save("ui_press.wav", finish(y))

# release: lighter, higher, single snap
t = timebase(0.12)
y = burst(t, 0.0, 0.8, 0.2) * 0.6 + modes(t, [2900, 4400, 6800], [0.55, 0.35, 0.2], [11, 7, 4])
y += thump(t, 0.0, 300, 170, 14, 0.2)
save("ui_release.wav", finish(y, 0.8))

# deny: muted low double buzz (square-ish through a soft clip), two hits
t = timebase(0.32)
y = np.zeros_like(t)
for s in (0.0, 0.14):
    on = (t >= s) & (t < s + 0.12)
    tt = t[on] - s
    y[on] += np.sign(np.sin(2 * math.pi * 118 * tt)) * 0.5 * np.exp(-tt / 0.07) + np.sin(2 * math.pi * 236 * tt) * 0.25 * np.exp(-tt / 0.05)
    y += thump(t, s, 140, 90, 40, 0.4)
save("ui_deny.wav", finish(y, 0.8, 2.2))

# open: rising whoosh into a soft pop
t = timebase(0.34)
y = sweep(t, 0.0, 0.22, 500, 3400, 0.8, 0.7)
y += burst(t, 0.2, 2.0, 0.55) * 0.6 + modes(t, [720, 1180, 1900], [0.7, 0.4, 0.2], [40, 25, 14], start=0.2)
y += thump(t, 0.2, 260, 120, 45, 0.5)
save("ui_open.wav", finish(y, 0.85))

# close: falling whoosh
t = timebase(0.24)
y = sweep(t, 0.0, 0.2, 2800, 420, 0.8, 0.7) + thump(t, 0.16, 180, 90, 30, 0.25)
save("ui_close.wav", finish(y, 0.75))

# tab: a wooden tok
t = timebase(0.14)
y = burst(t, 0.0, 1.6, 0.6) * 0.7 + modes(t, [880, 1395, 2210, 3010], [0.9, 0.5, 0.3, 0.15], [35, 22, 12, 7])
y += thump(t, 0.0, 240, 150, 20, 0.35)
save("ui_tab.wav", finish(y, 0.85))

# coin: bright chime, two inharmonic partials of a small bell
t = timebase(0.42)
y = burst(t, 0.0, 0.6, 0.1) * 0.3 + modes(t, [2093, 2637, 4186, 5274], [0.9, 0.55, 0.35, 0.18], [260, 180, 110, 70])
save("coin.wav", finish(y, 0.75, 1.3))

# claim: three rising bell notes (C6 E6 G6) and a sparkle tail
t = timebase(0.9)
y = np.zeros_like(t)
for i, f in enumerate((1046.5, 1318.5, 1568.0)):
    s = i * 0.085
    y += modes(t, [f, f * 2.01, f * 3.03], [0.8, 0.35, 0.15], [380, 240, 130], start=s)
    y += burst(t, s, 0.5, 0.1) * 0.25
for k in range(14):
    s = 0.26 + RNG.uniform(0, 0.45)
    f = RNG.uniform(4200, 7800)
    y += modes(t, [f], [0.12 * RNG.uniform(0.4, 1)], [40], start=s)
save("claim.wav", finish(y, 0.85, 1.4))
