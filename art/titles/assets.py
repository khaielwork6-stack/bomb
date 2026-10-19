"""Write the Assets.Title table in src/shared/Assets.luau from art/out/Titles/meta.json (sizes, glow scale, family —
written by build.py) and art/out/Titles/ids.json (uploaded ids: {"<Key>": id, "<Key>_mask": id, "<Key>_glow": id}).
Run with any Python 3:  python art/titles/assets.py"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
T = os.path.join(ROOT, "art", "out", "Titles")
meta = json.load(open(os.path.join(T, "meta.json")))
ids = json.load(open(os.path.join(T, "ids.json")))
lines = ["Assets.Title = {"]
glyphs = sorted(k for k in meta if meta[k].get("glyph"))
for key in sorted(k for k in meta if not meta[k].get("glyph")):
    if key not in ids or key + "_mask" not in ids or key + "_glow" not in ids:
        print("not uploaded yet:", key)
        continue
    m = meta[key]
    lines += [
        f"\t{key} = {{ -- {m['text']}",
        f'\t\tid = "rbxassetid://{ids[key]}",',
        f'\t\tmask = "rbxassetid://{ids[key + "_mask"]}",',
        f'\t\tglow = "rbxassetid://{ids[key + "_glow"]}",',
        f"\t\tglowScale = Vector2.new({m['glowScale'][0]}, {m['glowScale'][1]}),",
        f"\t\tsize = Vector2.new({m['size'][0]}, {m['size'][1]}),",
        f'\t\tfamily = "{m["family"]}",',
        "\t},",
    ]
lines.append("} :: { [string]: { id: string, mask: string, glow: string, glowScale: Vector2, size: Vector2, family: string } }")
# the number glyphs (Client/UI/NumberArt): no mask / glow, just the art and its pixel size
lines += ["", "-- Number glyphs (art/titles strip: same scale and baseline), neutral white, tinted live by Client/UI/NumberArt.",
          "Assets.Glyph = {"]
for key in glyphs:
    if key not in ids:
        print("glyph not uploaded yet:", key)
        continue
    m = meta[key]
    name = key[len("Glyph_"):]
    lines.append(f'	["{name}"] = {{ id = "rbxassetid://{ids[key]}", size = Vector2.new({m["size"][0]}, {m["size"][1]}) }},')
lines.append("} :: { [string]: { id: string, size: Vector2 } }")
p = os.path.join(ROOT, "src", "shared", "Assets.luau")
s = open(p, encoding="utf-8").read()
start = s.index("Assets.Title =")
end = s.index("-- The live layers behind a title")
s2 = s[:start] + "\n".join(lines) + "\n\n" + s[end:]
open(p, "w", encoding="utf-8", newline="").write(s2)
print("Assets.Title:", sum(1 for k in meta if k in ids), "titles")
