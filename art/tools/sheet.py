"""Compose an asset's review renders into one contact sheet (Asset Bible §10.3).

Usage: python art/tools/sheet.py art/out/Bomb.ClassicIron "The Tick — Classic Iron"
Needs Pillow. Lays out: the hero shot, the three ticking stages, the 8 turntable angles, the material close-up,
the black silhouette and the R6 scale view, on the brand's dark ink with labelled tiles.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

INK = (22, 18, 28)
INK2 = (36, 29, 46)
PAPER = (255, 243, 226)
FUSE = (255, 106, 31)
ASH = (140, 132, 152)


def font(size, bold=True):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf", "arial.ttf"):
        path = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def tile(img, size):
    im = img.copy()
    im.thumbnail(size, Image.LANCZOS)
    return im


def main():
    folder = sys.argv[1]
    title = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(folder)
    r = os.path.join(folder, "renders")

    def load(name):
        p = os.path.join(r, name + ".png")
        return Image.open(p).convert("RGB") if os.path.exists(p) else None

    W, PAD = 2400, 28
    sheet = Image.new("RGB", (W, 2350), INK)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 22), title.upper(), font=font(54), fill=PAPER)
    d.text((PAD, 92), "FUSE VALLEY · Asset review sheet · Cycles, Golden Fuse lighting", font=font(24, False), fill=ASH)
    d.rectangle((PAD, 132, W - PAD, 136), fill=FUSE)

    def place(img, x, y, w, h, label):
        d.rounded_rectangle((x - 6, y - 6, x + w + 6, y + h + 40), radius=14, fill=INK2)
        if img is not None:
            t = tile(img, (w, h))
            sheet.paste(t, (x + (w - t.width) // 2, y + (h - t.height) // 2))
        d.text((x + 6, y + h + 6), label, font=font(22), fill=PAPER)

    top = 160
    place(load("hero"), PAD, top, 1100, 1100, "HERO · LIT")
    sx = PAD + 1100 + 40
    sw = (W - sx - PAD - 2 * 30) // 3
    for i, st in enumerate(("LIT", "HOT", "CRITICAL")):
        place(load("stage_" + st), sx + i * (sw + 30), top, sw, sw, st)
    place(load("detail"), sx, top + sw + 70, 640, 640, "MATERIAL CLOSE-UP")
    place(load("silhouette"), sx + 640 + 30, top + sw + 70, W - (sx + 640 + 30) - PAD, 300, "SILHOUETTE")
    place(load("scale_r6"), sx + 640 + 30, top + sw + 70 + 370, W - (sx + 640 + 30) - PAD, 270, "R6 SCALE (5 STUDS)")
    ty = top + 1100 + 80
    tw = (W - 2 * PAD - 7 * 24) // 8
    for i in range(8):
        a = i * 45
        place(load(f"turn_{a:03d}"), PAD + i * (tw + 24), ty, tw, tw, f"{a}°")
    sheet = sheet.crop((0, 0, W, ty + tw + 70))
    out = os.path.join(folder, "contact_sheet.png")
    sheet.save(out, optimize=True)
    print(out)


if __name__ == "__main__":
    main()
