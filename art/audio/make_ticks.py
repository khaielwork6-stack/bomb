"""FUSE VALLEY — the bomb's tick, sound-designed in-house (Asset Bible §9: the carrier escalation's "own tick").

Physical-style modal synthesis, no samples and no AI: each tick is a clockwork escapement firing inside an iron shell.
  1. escapement: two noise-excited clicks ~9 ms apart (the pallet locking, then dropping), each ringing a small steel
     part (an inharmonic mode bank: the bright "tik" that cuts through music);
  2. shell: the cast-iron body's low modes, excited by the same hit (the weight that makes it *the bomb*);
  3. thump: a short pitch-dropping sub sine (the punch you feel on a phone speaker's low end);
  4. room: two soft early reflections, low-passed, so it sits in the world instead of in your skull.
Gentle tanh saturation glues the layers. Variants alternate tick / tock (a real escapement's two beats) and a
brighter, tighter pair for the CRITICAL stage, so escalation changes timbre instead of chipmunk-pitching one sample.

  bomb_tick.wav  bomb_tock.wav  bomb_tick_hot.wav  bomb_tock_hot.wav   (48 kHz, 16-bit mono, 0.35 s)

Run: <blender>/4.5/python/bin/python.exe -I art/audio/make_ticks.py
"""

import math
import os
import wave

import numpy as np

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Audio")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261017)
DUR = 0.35
N = int(SR * DUR)
t = np.arange(N) / SR


def modes(freqs, amps, decays_ms, jitter=0.0):
    """The impulse response of a bank of damped sinusoids (one struck object)."""
    y = np.zeros(N)
    for f, a, d in zip(freqs, amps, decays_ms):
        f = f * (1 + RNG.normal(0, jitter))
        y += a * np.exp(-t / (d / 1000)) * np.sin(2 * math.pi * f * t + RNG.uniform(0, 2 * math.pi))
    return y


def burst(ms, decay_ms):
    """A short noise excitation: what a metal edge snapping onto another sounds like before it rings."""
    n = int(SR * ms / 1000)
    k = np.arange(n) / SR
    e = RNG.normal(0, 1, n) * np.exp(-k / (decay_ms / 1000))
    e[: int(SR * 0.00015)] *= np.linspace(0, 1, int(SR * 0.00015))  # a 0.15 ms onset: a click, not a digital step
    return e


def excite(ir, at_ms, gain, ms=1.6, decay_ms=0.35):
    """Ring `ir` with a noise burst starting at `at_ms`."""
    out = np.convolve(burst(ms, decay_ms), ir)[:N]
    shift = int(SR * at_ms / 1000)
    y = np.zeros(N)
    y[shift:] = out[: N - shift]
    return y * gain


def one_pole_lp(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def thump(f0, f1, decay_ms, amp):
    """A pitch-dropping sine: f0 → f1 over the first 30 ms."""
    f = f1 + (f0 - f1) * np.exp(-t / 0.012)
    phase = 2 * math.pi * np.cumsum(f) / SR
    env = np.exp(-t / (decay_ms / 1000)) * np.clip(t / 0.0008, 0, 1)
    return amp * env * np.sin(phase)


def tick(steel_scale, shell_scale, drop_ms, bright, name, tail=1.0):
    steel = modes(
        [2380 * steel_scale, 3960 * steel_scale, 5650 * steel_scale, 7420 * steel_scale, 9870 * steel_scale],
        [1.0, 0.72, 0.5 * bright, 0.34 * bright, 0.2 * bright],
        [d * tail for d in (26, 16, 10, 7, 4.5)],
        jitter=0.004,
    )
    shell = modes([410 * shell_scale, 1120 * shell_scale, 1690 * shell_scale, 2630 * shell_scale], [0.5, 0.3, 0.2, 0.1], [d * tail for d in (70, 40, 28, 18)])
    lock = excite(steel, 0.0, 1.0) + excite(shell, 0.0, 0.9, ms=2.2, decay_ms=0.6)
    drop = excite(modes([f * 1.06 for f in (2380 * steel_scale, 3960 * steel_scale, 5650 * steel_scale)], [0.8, 0.5, 0.3], [18, 11, 7]), drop_ms, 0.55)
    y = lock + drop
    y /= np.max(np.abs(y)) + 1e-9
    body = thump(165 * shell_scale, 96 * shell_scale, 42 * tail, 0.55)
    y = y + body
    # room: two early reflections, darker and quieter than the dry hit
    room = np.zeros(N)
    for ms, g in ((7.3, 0.16), (13.1, 0.09)):
        s = int(SR * ms / 1000)
        room[s:] += y[: N - s] * g
    y = y + one_pole_lp(room, 2800)
    # glue: soft saturation, then a 4 ms fade at the very end of the file
    y = np.tanh(1.7 * y) / np.tanh(1.7)
    fade = int(SR * 0.004)
    y[-fade:] *= np.linspace(1, 0, fade)
    y *= 10 ** (-1.0 / 20) / np.max(np.abs(y))  # peak at −1 dBFS
    pcm = (y * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    # a few objective checks for the log (onset, decay, spectral balance)
    env = np.abs(y)
    t60 = np.argmax(np.convolve(env, np.ones(48) / 48, "same") < 10 ** (-40 / 20)) / SR * 1000
    spec = np.abs(np.fft.rfft(y))
    freqs = np.fft.rfftfreq(N, 1 / SR)
    low = spec[freqs < 300].sum() / spec.sum()
    hi = spec[freqs > 2000].sum() / spec.sum()
    print(f"wrote {name}: -40 dB after {t60:.0f} ms, energy <300 Hz {low:.0%}, >2 kHz {hi:.0%}", flush=True)


tick(1.00, 1.00, 9.0, 1.0, "bomb_tick")
tick(0.86, 0.94, 11.0, 0.9, "bomb_tock")
tick(1.17, 1.06, 7.0, 1.25, "bomb_tick_hot", 0.55)
tick(1.02, 1.00, 8.0, 1.15, "bomb_tock_hot", 0.55)
print("DONE", OUT, flush=True)
