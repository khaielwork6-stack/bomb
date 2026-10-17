"""Compose the face rig's review renders (art/bomb/face.py) into one contact sheet (Asset Bible §10.3).

Usage: python art/bomb/face_sheet.py
Writes art/out/Bomb.Face/contact_sheet.html (standard library only), then rasterises it to contact_sheet.png with a
headless Chromium browser (Edge on Windows, Chrome on macOS).
"""

import os
import subprocess
import tempfile
import uuid
from pathlib import Path

FOLDER = Path(__file__).resolve().parents[2] / "art" / "out" / "Bomb.Face"
BROWSERS = (
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
)
CSS = """
*{box-sizing:border-box} body{margin:0;background:#16121C;color:#FFF3E2;font:600 15px 'Segoe UI','Helvetica Neue',sans-serif;width:2400px}
.wrap{padding:28px} h1{font:800 54px 'Segoe UI','Helvetica Neue';margin:0;letter-spacing:.02em}
.sub{color:#8C8498;font-size:22px;margin:6px 0 14px} .bar{height:4px;background:#FF6A1F;margin-bottom:24px}
.t{background:#241D2E;border-radius:14px;padding:8px} .t img{width:100%;display:block;border-radius:8px}
.t b{display:block;padding:8px 6px 0;font-size:20px;letter-spacing:.06em} .t i{display:block;padding:2px 6px 4px;color:#8C8498;font-style:normal;font-size:16px}
.top{display:grid;grid-template-columns:1000px 1fr;gap:28px;align-items:start}
.stages{display:grid;grid-template-columns:repeat(3,1fr);gap:22px}
h2{font:800 24px 'Segoe UI','Helvetica Neue';letter-spacing:.08em;color:#FF9442;margin:30px 0 14px}
.five{display:grid;grid-template-columns:repeat(5,1fr);gap:22px} .six{display:grid;grid-template-columns:repeat(6,1fr);gap:20px}
.ctx{display:grid;grid-template-columns:1fr 1fr 0.7fr;gap:22px;align-items:start}
.notes{background:#241D2E;border-radius:14px;padding:18px 22px;font-weight:500;font-size:18px;line-height:1.5;color:#E8DCCB;margin-top:22px}
.notes b{color:#FFD84A}
"""


def tile(name, label, note=""):
    src = (FOLDER / "renders" / f"{name}.png").as_uri()
    return f'<div class="t"><img src="{src}"><b>{label}</b>{f"<i>{note}</i>" if note else ""}</div>'


def main():
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body><div class="wrap">
<h1>THE TICK — FACE RIG</h1><div class="sub">FUSE VALLEY · Asset review sheet · Blender, hand-authored (art/bomb/face.py) · Cycles, Golden Fuse lighting · for sign-off</div><div class="bar"></div>
<div class="top">{tile("hero", "HERO · LIT", "the default: a cocky smirk, eyes on its next victim")}
<div><div class="stages">{tile("stage_LIT", "LIT · SMUG", "half-lidded, brows down, smirk")}{tile("stage_HOT", "HOT · UH-OH", "eyes open, brows worried, teeth clenched")}{tile("stage_CRITICAL", "CRITICAL · PANIC", "pin pupils, screaming white-hot mouth")}</div>
<div class="notes"><b>How it works in game.</b> Every face part is rigid and only rotates, so BombController drives the same rig with C0 rotations: the pupils track the nearest player, the lids blink every 2–4 s, and the brows, lids and mouth change with the stage (LIT → HOT → CRITICAL), with one-shot poses for a tag (GOTCHA) and a pass (WHEE).<br>
<b>Materials.</b> Porcelain eyes and teeth (the fuse socket's crackle glaze), forged brass brows and lips (the belt's brass), ink-enamel pupils and lids, and a white-hot core in the scream that matches the seams. No AI art: every shape is code in face.py.<br>
<b>Rules held.</b> One face for every skin (§3.6). The fuse, seams and lamps are untouched (§10.4). The face adds at most 0.09 studs at the front, and the side silhouette is unchanged apart from those bumps.</div></div></div>
<h2>MOMENTS</h2><div class="five">{tile("pose_BLINK", "BLINK", "every 2–4 s while LIT")}{tile("pose_GOTCHA", "GOTCHA", "it just stuck to someone")}{tile("pose_WHEE", "WHEE", "pass flight")}{tile("pose_LOOK-L", "TRACKING ←", "pupils follow the nearest player")}{tile("pose_LOOK-R", "TRACKING →", "")}</div>
<h2>EVERY SKIN, SAME FACE</h2><div class="six">{tile("skin_Watermelon", "WATERMELON")}{tile("skin_Delft", "DELFT")}{tile("skin_Gilded", "GILDED")}{tile("skin_Galaxy", "GALAXY")}{tile("skin_Frostbite", "FROSTBITE")}{tile("skin_JackOFuse", "JACK-O-FUSE")}</div>
<h2>IN CONTEXT</h2><div class="ctx">{tile("context_carrier", "THE CARRIER'S OWN CAMERA (HOT)", "the bomb faces backward, so you see its face the whole time you carry it")}{tile("context_chaser", "A CHASER 25 STUDS BACK", "still reads at distance")}{tile("silhouette", "SILHOUETTE (SIDE)", "outline unchanged but for ≤0.09 studs at the front")}</div>
</div></body></html>"""
    out_html = FOLDER / "contact_sheet.html"
    out_html.write_text(html, encoding="utf-8")
    browser = next((p for p in BROWSERS if os.path.exists(p)), None)
    if not browser:
        print(out_html)
        return
    png = FOLDER / "contact_sheet.png"
    profile = Path(tempfile.gettempdir()) / f"facesheet_{uuid.uuid4().hex}"
    subprocess.run(
        [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={profile}",
         "--window-size=2400,3330", "--virtual-time-budget=8000", "--allow-file-access-from-files",
         f"--screenshot={png}", out_html.as_uri()],
        check=False,
        timeout=120,
        capture_output=True,
    )
    print(png)


if __name__ == "__main__":
    main()
