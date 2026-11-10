# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Stacks compare_<CuhId>.png images (picture | front | back) into one review sheet.

    python -I review_sheet.py <out.png> <CuhId> [CuhId ...]
"""
import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[1]
W = 1164

out, cuhs = sys.argv[1], sys.argv[2:]
rows = []
for cuh in cuhs:
    im = Image.open(ROOT / "out" / f"compare_{cuh}.png").convert("RGB")
    im = im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)
    ImageDraw.Draw(im).text((8, 6), cuh, fill=(255, 255, 255))
    rows.append(im)
sheet = Image.new("RGB", (W, sum(r.height for r in rows)), (0, 0, 0))
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.height
sheet.save(ROOT / "out" / out)
print(ROOT / "out" / out)
