# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Measures the silhouette of the reference picture and of the front render, so proportions can be matched by numbers.

    python kit/run.py measure <ModelId>

The silhouette is split into 12 bands from top to bottom. For each band it prints the widest point as a fraction of
the total height, for the picture and for the render, and flags big differences: a head, belly or pair of shoes
that's the wrong size shows up straight away. The picture and the render may be seen from slightly different angles,
so treat small differences (under about 0.05) as noise.
"""
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
BANDS = 12
HEIGHT = 240
FLAG = 0.06


def silhouette(path):
    """Boolean mask image (mode L) of the subject, cropped to it. Uses alpha if the picture has transparency,
    otherwise the difference from the corner colour."""
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A")
    if alpha.getextrema()[0] < 250:
        mask = alpha.point(lambda a: 255 if a > 32 else 0)
    else:
        rgb = im.convert("RGB")
        bg = rgb.getpixel((0, 0))
        px = rgb.load()
        mask = Image.new("L", rgb.size, 0)
        mp = mask.load()
        for y in range(rgb.height):
            for x in range(rgb.width):
                r, g, b = px[x, y]
                if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 60:
                    mp[x, y] = 255
    box = mask.getbbox()
    if not box:
        sys.exit(f"Nothing to measure in {path}")
    mask = mask.crop(box)
    w = max(1, round(mask.width * HEIGHT / mask.height))
    return mask.resize((w, HEIGHT), Image.NEAREST)


def band_widths(mask):
    px = mask.load()
    widths = []
    rows = mask.height // BANDS
    for b in range(BANDS):
        best = 0
        for y in range(b * rows, (b + 1) * rows):
            xs = [x for x in range(mask.width) if px[x, y] > 0]
            if xs:
                best = max(best, xs[-1] - xs[0] + 1)
        widths.append(best / mask.height)
    return widths


def main(model_id):
    refs = [p for p in (ROOT / "ref" / f"{model_id}.png", ROOT / "ref" / f"cuh_{model_id}.png") if p.exists()]
    render = ROOT / "out" / f"preview_{model_id}.png"
    if not refs:
        sys.exit(f"No reference picture at ref/{model_id}.png")
    if not render.exists():
        sys.exit(f"No render yet: run  python kit/run.py build {model_id}")
    a, b = silhouette(refs[0]), silhouette(render)
    wa, wb = band_widths(a), band_widths(b)
    print(f"overall width / height:  picture {a.width / a.height:.2f}   render {b.width / b.height:.2f}")
    print("band (top->bottom)   picture  render   diff")
    for i, (x, y) in enumerate(zip(wa, wb)):
        d = y - x
        flag = "  <- render too wide" if d > FLAG else "  <- render too narrow" if d < -FLAG else ""
        print(f"  {i + 1:2d}  {i / BANDS:4.0%}-{(i + 1) / BANDS:4.0%}     {x:5.2f}   {y:5.2f}   {d:+.2f}{flag}")


if __name__ == "__main__":
    main(sys.argv[1])
