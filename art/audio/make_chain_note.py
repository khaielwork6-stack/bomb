"""FUSE VALLEY — the Chain Song note (GDD F-BOMB-14), sound-designed in-house (Asset Bible §9: no samples, no AI).

One bright wooden mallet tone, tuned to exactly C5 (523.25 Hz), so the game pitches it up by semitones
(PlaybackSpeed = 2^(n/12)) and every pass of a chain plays the next note of a rising major scale.
Modal synthesis of a struck marimba-style bar:
  1. the bar: the tuned fundamental plus the bar's characteristic partials (≈4× and ≈10× — a tuned marimba bar's
     overtones), each with its own decay, so the attack is bright and the tail is a round, woody "bonk";
  2. the mallet: a short filtered noise strike (the felt hitting wood) and a tiny pitch-drop at the very start (the
     bar's stiffness), which is what makes it read as a real struck object instead of a synth beep;
  3. a resonator tube: a soft octave-down body that blooms in 4 ms and decays, giving it warmth on phone speakers;
  4. a short room: two low-passed early reflections.
Gentle tanh saturation, then a fade so the tail never clicks.

  chain_note.wav   (48 kHz, 16-bit mono, 0.9 s; peaks at -1 dBFS)

Run: /Applications/Blender.app/Contents/Resources/4.5/python/bin/python3.11 -I art/audio/make_chain_note.py
"""

import math
import os
import wave

import numpy as np

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Audio")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261018)
DUR = 0.9
N = int(SR * DUR)
t = np.arange(N) / SR
F0 = 523.25  # C5


def one_pole_lp(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def partial(f, amp, decay_s, attack_ms=0.6, drop=0.0):
    # a tiny downward glide at the start (the bar's stiffness), settling on the true pitch within ~25 ms
    glide = 1 + drop * np.exp(-t / 0.008)
    phase = 2 * math.pi * np.cumsum(f * glide) / SR
    env = np.exp(-t / decay_s) * (1 - np.exp(-t / (attack_ms / 1000)))
    return amp * env * np.sin(phase)


# 1. the bar: fundamental + a tuned marimba bar's overtones (≈4×, ≈9.9×), shorter as they go up
bar = (
    partial(F0, 1.0, 0.3, drop=0.012)
    + partial(F0 * 3.99, 0.32, 0.09, drop=0.02)
    + partial(F0 * 9.9, 0.12, 0.028)
    + partial(F0 * 2.0, 0.06, 0.25)  # a whisper of the octave: rounder on small speakers
)

# 2. the mallet: a short band-limited felt strike
strike = RNG.normal(0, 1, N) * np.exp(-t / 0.0028)
strike = one_pole_lp(strike, 5200) - one_pole_lp(strike, 900)  # a band: felt on wood, no hiss
strike *= 0.6

# 3. the resonator: a soft octave-down body that blooms in 4 ms and decays
body = 0.18 * np.exp(-t / 0.16) * (1 - np.exp(-t / 0.004)) * np.sin(2 * math.pi * (F0 / 2) * t)

dry = bar + strike + body

# 4. a short room: two low-passed early reflections
room = np.zeros(N)
for delay_ms, gain in ((17, 0.16), (31, 0.09)):
    d = int(SR * delay_ms / 1000)
    room[d:] += dry[:-d] * gain
room = one_pole_lp(room, 3200)

y = np.tanh((dry + room) * 0.6) / math.tanh(0.6)  # a touch of glue, never squashing the strike
fade = np.ones(N)
tail = int(SR * 0.12)
fade[-tail:] = np.linspace(1, 0, tail) ** 2
y *= fade
y *= 10 ** (-1 / 20) / np.max(np.abs(y))

pcm = (y * 32767).astype(np.int16)
path = os.path.join(OUT, "chain_note.wav")
with wave.open(path, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", path)

# self-check: the strongest frequency in the steady part must be C5 (the scale only works if it's in tune)
seg = y[int(0.06 * SR):int(0.36 * SR)]
spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), n=1 << 18))
freqs = np.fft.rfftfreq(1 << 18, 1 / SR)
peak = freqs[np.argmax(spec)]
cents = 1200 * math.log2(peak / F0)
print(f"peak {peak:.2f} Hz ({cents:+.1f} cents from C5)")
assert abs(cents) < 5, "out of tune"
