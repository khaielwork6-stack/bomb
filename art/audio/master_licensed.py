"""Master the licensed SFX pack (art/audio/in/*.wav) for the game: trim the dead air before the attack (so a click
sounds on the frame you click), cut the silent tail, level-match the four footsteps to one loudness (so no step pops
out), cap peaks at -1 dBFS, and write art/out/Audio/Licensed/<slot>.wav ready to upload. Standard library + numpy.

    python art/audio/master_licensed.py
"""

import os
import wave

import numpy as np

SRC = os.path.join("art", "audio", "in")
OUT = os.path.join("art", "out", "Audio", "Licensed")

# source file -> (output name, mono?)
FILES = {
    "Click Ui MA BG.wav": ("ui_click", False),
    "Hover UI MA BG.wav": ("ui_hover", False),
    "Enable Noti MA BG.wav": ("ui_on", False),
    "Disable Noti MA BG.wav": ("ui_off", False),
    "Earn Smth MA BG.wav": ("earn", False),
    "Purchase UI MA BG.wav": ("purchase", False),
    "Server Announcement MA BG.wav": ("notify", False),
    "Concrete Steps 1 Martial BG.wav": ("step_concrete_1", True),
    "Concrete Steps 2 Martial BG.wav": ("step_concrete_2", True),
    "Concrete Steps 3 Martial BG.wav": ("step_concrete_3", True),
    "Concrete Steps 4 Martial BG.wav": ("step_concrete_4", True),
}
CEILING_DB = -1.0
HEAD_DB, TAIL_DB = -50.0, -62.0  # below the peak: where the attack starts / where the tail is inaudible
STEP_LOUDNESS = -20.5  # every footstep lands on this short-term loudness (the quietest one sets the ceiling)


def load(p):
    with wave.open(p) as w:
        ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
        assert w.getsampwidth() == 2, p
        a = np.frombuffer(w.readframes(n), "<i2").astype(np.float64).reshape(-1, ch) / 32768
    return a, sr


def save(p, a, sr):
    data = (np.clip(a, -1, 1) * 32767).round().astype("<i2")
    with wave.open(p, "wb") as w:
        w.setnchannels(a.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def short_term(m, sr):
    w = int(sr * 0.1)
    if len(m) <= w:
        return 20 * np.log10(np.sqrt(np.mean(m**2)) + 1e-12)
    c = np.cumsum(np.insert(m**2, 0, 0))
    return 20 * np.log10(np.sqrt((c[w:] - c[:-w]) / w).max() + 1e-12)


def trim(a, sr):
    env = np.abs(a).max(1)
    pk = env.max()
    loud = np.nonzero(env > pk * 10 ** (HEAD_DB / 20))[0]
    start = max(0, loud[0] - int(sr * 0.001))
    audible = np.nonzero(env > pk * 10 ** (TAIL_DB / 20))[0]
    end = min(len(a), audible[-1] + int(sr * 0.02))
    a = a[start:end].copy()
    fi, fo = int(sr * 0.001), min(int(sr * 0.015), len(a) // 4)
    a[:fi] *= np.linspace(0, 1, fi)[:, None]
    a[-fo:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fo)))[:, None]
    return a


def main():
    os.makedirs(OUT, exist_ok=True)
    for src, (name, mono) in FILES.items():
        a, sr = load(os.path.join(SRC, src))
        if mono:
            a = a.mean(1, keepdims=True)
        a = trim(a, sr)
        if name.startswith("step_"):
            gain = STEP_LOUDNESS - short_term(a.mean(1), sr)
        else:
            gain = 0.0
        pk = 20 * np.log10(np.abs(a).max() + 1e-12)
        gain = min(gain, CEILING_DB - pk)
        a *= 10 ** (gain / 20)
        save(os.path.join(OUT, name + ".wav"), a, sr)
        print(f"{name:18s} {len(a) / sr:5.2f}s  gain {gain:+5.1f} dB  peak {20 * np.log10(np.abs(a).max()):5.1f}  "
              f"loudness {short_term(a.mean(1), sr):6.1f}")


if __name__ == "__main__":
    main()
