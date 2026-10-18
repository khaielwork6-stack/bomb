"""FUSE VALLEY — the Fireworks Yard's wooden pallet (Asset Bible §4.2 / §4.4 Yard props: dressing, stacks).

A 4 x 4 block pallet, 0.65 tall so it stacks on the Yard's existing 0.65-stud pitch: five pale deck boards, three
stringer boards, nine darker blocks and three bottom boards, chunky soft bevels, grain running along every board,
nail heads where the deck crosses the stringers.

Run:  blender -b --factory-startup --python-exit-code 1 --python art/props/build_pallet.py -- [--samples 64] [--no-bake] [--no-render]
Out:  art/out/Prop.Pallet/  (renders/, export/Prop.Pallet.fbx, export/textures/*.png, manifest.json)
Units: 1 Blender unit = 1 stud, Z up, front = -Y. Studio: Blender (x, y, z) -> Roblox model space (-x, z, y).
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from kit import srgb  # noqa: E402

KEY = "Prop.Pallet"
BAKE = "--no-bake" not in kit.argv
DO_RENDER = "--no-render" not in kit.argv
kit.setup(KEY, bake=["Pallet"], glow=[])
rng = random.Random(1178)


def mat_wood(name, paint, hi, bare, dark, along, grain=0.22, chip=0.5):
    """kit.mat_paint_wood with the grain running along the board (`along` = "X" or "Y"), so it shows on the tops."""
    m = kit.mat_paint_wood(name, paint, hi, bare, dark, chip=chip, grain=grain, rough=(0.55, 0.78), bump=0.3)
    nt = m.node_tree
    wave = next(n for n in nt.nodes if n.type == "TEX_WAVE")
    mapg = next(n for n in nt.nodes if n.type == "MAPPING")
    if along == "X":
        wave.bands_direction = "Y"
        mapg.inputs["Scale"].default_value = (0.5, 5.0, 5.0)
    else:
        wave.bands_direction = "X"
        mapg.inputs["Scale"].default_value = (5.0, 0.5, 5.0)
    return m


# ── Palette ──────────────────────────────────────────────────────────────────────────────────────────────────────
DECK, DECK_HI, DECK_BARE, DECK_GRAIN = srgb("#EBA65C"), srgb("#FFCB86"), srgb("#FFE2B8"), srgb("#A6602A")
DECK2, DECK2_HI = srgb("#E0974C"), srgb("#FBBE74")
BLOCK, BLOCK_HI, BLOCK_BARE, BLOCK_GRAIN = srgb("#B86C34"), srgb("#D88A4C"), srgb("#E8B07C"), srgb("#6E3A16")
IRON_LO, IRON, IRON_HI = srgb("#2A2C34"), srgb("#4A4E5C"), srgb("#9AA2B8")

M_DECK = mat_wood("Deck", DECK, DECK_HI, DECK_BARE, DECK_GRAIN, "X")
M_DECK2 = mat_wood("Deck2", DECK2, DECK2_HI, DECK_BARE, DECK_GRAIN, "X")
M_STRINGER = mat_wood("Stringer", DECK2, DECK2_HI, DECK_BARE, DECK_GRAIN, "Y")
M_BLOCK = mat_wood("Block", BLOCK, BLOCK_HI, BLOCK_BARE, BLOCK_GRAIN, "Y", grain=0.18)
M_IRON = kit.mat_metal("Iron", IRON_LO, IRON, IRON_HI, rough=(0.25, 0.4), metal=0.3)

# ── Dimensions (studs) ───────────────────────────────────────────────────────────────────────────────────────────
S = 4.0
Z_BOT, Z_BLK, Z_STR, Z_DECK = 0.12, 0.29, 0.1, 0.14  # layer thicknesses (sum 0.65)
LANES = (-1.62, 0.0, 1.62)  # stringer / block lines (x) and block rows (y)

for i, x in enumerate(LANES):
    kit.box(f"Bottom{i}", (0.74, S, Z_BOT), (x, 0, Z_BOT / 2), M_STRINGER, "Pallet", bev=0.04, segs=2)
    for j, y in enumerate(LANES):
        kit.box(f"Block{i}{j}", (0.7, 0.66 if abs(y) > 0 else 0.6, Z_BLK), (x + rng.uniform(-0.01, 0.01), y, Z_BOT + Z_BLK / 2), M_BLOCK, "Pallet", bev=0.045, segs=2)
    kit.box(f"Stringer{i}", (0.74, S - 0.02, Z_STR), (x, 0, Z_BOT + Z_BLK + Z_STR / 2), M_STRINGER, "Pallet", bev=0.035, segs=2)
DECK_W = 0.7
for k, y in enumerate((-1.65, -0.83, 0.0, 0.83, 1.65)):
    zc = Z_BOT + Z_BLK + Z_STR + Z_DECK / 2
    kit.box(f"Deck{k}", (S, DECK_W, Z_DECK), (rng.uniform(-0.02, 0.02), y, zc), M_DECK if k % 2 == 0 else M_DECK2, "Pallet", bev=0.045, segs=2)
    for x in LANES:
        for dy in (-0.18, 0.18):
            kit.rivet(f"Nail{k}{x}{dy}", (x + rng.uniform(-0.12, 0.12), y + dy, zc + Z_DECK / 2), (0, 0, 1), M_IRON, "Pallet", r=0.045, squash=0.45, segs=6)

# ── Finalize ─────────────────────────────────────────────────────────────────────────────────────────────────────
parts = kit.finalize()
tris = kit.tris_of(parts)
print("TRIS", tris, "total", sum(tris.values()), flush=True)
pivot, lo, hi = kit.pivot_of(parts)

kit.render_setup(target=(0, 0, 0.3))
if DO_RENDER:
    kit.shoot("hero", (6.0, -7.6, 4.6), lens=50)
    kit.shoot("front", (0, -11, 1.2), lens=55)

maps = kit.bake_all(parts, {"Pallet": 1024}) if BAKE else {}
kit.export_fbx(parts)
kit.write_manifest(
    {
        "key": KEY,
        "tris": tris,
        "tris_total": sum(tris.values()),
        "pivot_blender": kit.blend(pivot),
        "size_studs": kit.rbx_size(lo, hi),
        "parts": maps,
        "glow": [],
    }
)
