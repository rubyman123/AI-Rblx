# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Puts a model's reference picture, its front render and its back render side by side, so you can see
exactly what still differs from the picture.

    python -I kit/compare.py <ModelId>   ->  out/compare_<ModelId>.png
The reference picture is ref/<ModelId>.png (ref/cuh_<ModelId>.png also works). Without one, it shows just the renders.
"""
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
BG = (37, 42, 54, 255)
SIZE = 640


def fit(path):
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 32 else 0).getbbox()  # ignore faint stray pixels
    if box:
        im = im.crop(box)
    scale = (SIZE - 40) / max(im.size)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    tile = Image.new("RGBA", (SIZE, SIZE), BG)
    tile.alpha_composite(im, ((SIZE - im.width) // 2, SIZE - 20 - im.height))
    return tile


def main(cuh):
    refs = [p for p in (ROOT / "ref" / f"{cuh}.png", ROOT / "ref" / f"cuh_{cuh}.png") if p.exists()]
    tiles = refs[:1] + [ROOT / "out" / f"preview_{cuh}.png"]
    back = ROOT / "out" / f"preview_{cuh}_back.png"
    if back.exists():
        tiles.append(back)
    sheet = Image.new("RGBA", (SIZE * len(tiles) + 10 * (len(tiles) - 1), SIZE), (20, 22, 28, 255))
    for i, path in enumerate(tiles):
        sheet.alpha_composite(fit(path), (i * (SIZE + 10), 0))
    out = ROOT / "out" / f"compare_{cuh}.png"
    sheet.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1])
