"""Compose an asset's review renders into one contact sheet (Asset Bible §10.3).

Usage: python art/tools/sheet.py <asset folder> "<title>"
Writes <folder>/contact_sheet.html (standard library only), then rasterises it to contact_sheet.png with headless
Edge. Layout: the hero shot, the three ticking stages, the material close-up, the silhouette, the R6 scale view
and the 8 turntable angles, on the brand's dark ink with labelled tiles.
"""

import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

CSS = """
*{box-sizing:border-box} body{margin:0;background:#16121C;color:#FFF3E2;font:600 15px 'Segoe UI',sans-serif;width:2400px}
.wrap{padding:28px} h1{font:800 54px 'Segoe UI';margin:0;letter-spacing:.02em}
.sub{color:#8C8498;font-size:22px;margin:6px 0 14px} .bar{height:4px;background:#FF6A1F;margin-bottom:24px}
.grid{display:grid;grid-template-columns:1060px 1fr;gap:30px;align-items:start}
.t{background:#241D2E;border-radius:14px;padding:8px} .t img{width:100%;display:block;border-radius:8px}
.t b{display:block;padding:8px 6px 2px;font-size:20px;letter-spacing:.06em}
.stages{display:grid;grid-template-columns:repeat(3,1fr);gap:24px}
.mid{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-top:24px;align-items:start} .mid:last-child{grid-template-columns:1fr}
.side{display:grid;gap:24px}
.turn{display:grid;grid-template-columns:repeat(8,1fr);gap:20px;margin-top:30px}
"""


def tile(src, label):
    return f'<div class="t"><img src="{src}"><b>{label}</b></div>'


def main():
    folder = Path(sys.argv[1]).resolve()
    title = sys.argv[2] if len(sys.argv) > 2 else folder.name
    r = folder / "renders"

    def img(name):
        return (r / f"{name}.png").as_uri()

    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body><div class="wrap">
<h1>{title.upper()}</h1><div class="sub">FUSE VALLEY · Asset review sheet · Cycles, Golden Fuse lighting</div><div class="bar"></div>
<div class="grid"><div class="side">{tile(img("hero"), "HERO · LIT")}</div>
<div><div class="stages">{tile(img("stage_LIT"), "LIT")}{tile(img("stage_HOT"), "HOT")}{tile(img("stage_CRITICAL"), "CRITICAL")}</div>
<div class="mid">{tile(img("detail"), "MATERIAL CLOSE-UP")}<div class="side">{tile(img("silhouette"), "SILHOUETTE")}</div></div><div class="mid">{tile(img("scale_r6"), "R6 SCALE (5 STUDS)")}</div></div></div>
<div class="turn">{"".join(tile(img(f"turn_{a:03d}"), f"{a}°") for a in range(0, 360, 45))}</div>
</div></body></html>"""
    out_html = folder / "contact_sheet.html"
    out_html.write_text(html, encoding="utf-8")
    edge = next(
        (p for p in (r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", r"C:\Program Files\Microsoft\Edge\Application\msedge.exe") if os.path.exists(p)),
        None,
    )
    if not edge:
        print(out_html)
        return
    png = folder / "contact_sheet.png"
    profile = Path(tempfile.gettempdir()) / f"edgesheet_{uuid.uuid4().hex}"
    subprocess.run(
        [edge, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={profile}", "--window-size=2400,2480",
         "--virtual-time-budget=8000", "--allow-file-access-from-files", f"--screenshot={png}", out_html.as_uri()],
        check=False,
        timeout=120,
    )
    print(png)


if __name__ == "__main__":
    main()
