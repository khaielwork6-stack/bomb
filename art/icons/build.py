"""FUSE VALLEY — the 3D icon set runner (Asset Bible §6.4, DECISIONS 2026-10-17), modelled after the ChatGPT style sheets in
art/ref/icons/ (references only: every icon is real geometry built here) and rendered to transparent PNGs. The icons live in art/icons/set_*.py (each registers its builders with @lib.icon).

Run:  blender -b --factory-startup --python-exit-code 1 --python art/icons/build.py -- [--only Star,Bomb] [--res 512]
Out:  art/out/Icons3D/<Name>.png
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import glob  # noqa: E402

import lib  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
ONLY = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
RES = int(argv[argv.index("--res") + 1]) if "--res" in argv else 512
lib.OUTLINE = "--no-outline" not in argv
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "out", "Icons3D")

# Load every icon set.
for path in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "set_*.py"))):
    importlib.import_module(os.path.splitext(os.path.basename(path))[0])


def main():
    for name, fn in lib.ICONS.items():
        if ONLY and name not in ONLY:
            continue
        lib.reset()
        fn()
        lib.render_icon(os.path.join(OUT, f"{name}.png"), RES)
        print("ICON", name, flush=True)


main()
