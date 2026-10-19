"""Write baked R6 clips (tools/anim, baked by bake.luau in Studio) to .rbxmx KeyframeSequence files for tools/upload.py.

Usage:
  python tools/anim/export_rbxmx.py <dump.json> <out_dir>

<dump.json> is the JSON a Studio execute_luau returns for ReplicatedStorage.FV_AnimDev clips:
  { "<Name>": { "loop": bool, "priority": int, "frames": [ { "t": s, "p": [ pose ] } ] } }
  pose = { "n": name, "c": [12 CFrame components], "w": weight, "k": [ child poses ] }
(the MCP tool may wrap the JSON in quotes; both forms are read). One <Name>.rbxmx is written per clip.
"""
import json
import os
import sys
from xml.sax.saxutils import escape

ref = 0


def next_ref() -> str:
    global ref
    ref += 1
    return f"RBX{ref:08X}"


def cframe(c) -> str:
    names = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    return "".join(f"<{n}>{v}</{n}>" for n, v in zip(names, c))


def pose_xml(p) -> str:
    kids = "".join(pose_xml(k) for k in p.get("k", []))
    return (
        f'<Item class="Pose" referent="{next_ref()}"><Properties>'
        f'<CoordinateFrame name="CFrame">{cframe(p["c"])}</CoordinateFrame>'
        '<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
        f'<string name="Name">{escape(p["n"])}</string>'
        f'<float name="Weight">{p.get("w", 1)}</float>'
        f"</Properties>{kids}</Item>"
    )


def clip_xml(name: str, clip) -> str:
    frames = "".join(
        f'<Item class="Keyframe" referent="{next_ref()}"><Properties>'
        '<string name="Name">Keyframe</string>'
        f'<float name="Time">{f["t"]}</float>'
        "</Properties>" + "".join(pose_xml(p) for p in f["p"]) + "</Item>"
        for f in clip["frames"]
    )
    return (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        f'<Item class="KeyframeSequence" referent="{next_ref()}"><Properties>'
        f'<bool name="Loop">{"true" if clip["loop"] else "false"}</bool>'
        f'<string name="Name">{escape(name)}</string>'
        f'<token name="Priority">{clip["priority"]}</token>'
        f"</Properties>{frames}</Item></roblox>"
    )


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    raw = open(src, encoding="utf-8").read().strip()
    data = json.loads(raw)
    if isinstance(data, str):
        data = json.loads(data)
    os.makedirs(out_dir, exist_ok=True)
    for name, clip in data.items():
        path = os.path.join(out_dir, f"{name}.rbxmx")
        open(path, "w", encoding="utf-8").write(clip_xml(name, clip))
        print(path, len(clip["frames"]), "keyframes")


if __name__ == "__main__":
    main()
