#!/usr/bin/env python3
"""Lay out concept images side by side with name labels.

  python3 tools/models/contact_sheet.py out.png [name ...] [--all] [--cols 5] [--h 600]

By default, uses each character's picked concept (the first PNG in
assets/characters/<name>/concepts/, sorted). With --all, includes every candidate.
"""
import argparse
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
CHARS = os.path.join(ROOT, "assets", "characters")
FONT = os.path.join(ROOT, "assets", "fonts")


def _font(size):
    for f in sorted(glob.glob(os.path.join(FONT, "*"))):
        if "teko" in f.lower() or "rajdhani" in f.lower():
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                pass
    return ImageFont.load_default(size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("names", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--h", type=int, default=600)
    a = ap.parse_args()
    info = json.load(open(os.path.join(ROOT, "data", "characters.json")))
    names = a.names or [n for n in info if os.path.isdir(os.path.join(CHARS, n, "concepts"))]
    tiles = []
    for n in names:
        files = sorted(glob.glob(os.path.join(CHARS, n, "concepts", "*.png")))
        files = [f for f in files if "_weapon" not in f]
        for f in (files if a.all else files[:1]):
            tiles.append((n, os.path.basename(f), f))
    if not tiles:
        raise SystemExit("no concepts found")
    th = a.h
    tw = int(th * 832 / 1216)
    lab = 64
    cols = min(a.cols, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * (th + lab)), (18, 20, 28))
    d = ImageDraw.Draw(sheet)
    big, small = _font(40), _font(22)
    for i, (n, fname, f) in enumerate(tiles):
        x, y = (i % cols) * tw, (i // cols) * (th + lab)
        im = Image.open(f).convert("RGB")
        im = im.resize((tw, int(im.height * tw / im.width)))
        sheet.paste(im.crop((0, 0, tw, th)), (x, y))
        col = info.get(n, {}).get("color", "#ffffff")
        d.rectangle([x, y + th, x + tw, y + th + 6], fill=col)
        title = info.get(n, {}).get("name", n.upper())
        d.text((x + 12, y + th + 10), title, font=big, fill=col)
        d.text((x + tw - 12, y + th + 22), fname if a.all else info.get(n, {}).get("title", ""),
               font=small, fill=(200, 205, 215), anchor="ra")
    sheet.save(a.out)
    print("sheet:", a.out, sheet.size, len(tiles), "tiles")


if __name__ == "__main__":
    main()
