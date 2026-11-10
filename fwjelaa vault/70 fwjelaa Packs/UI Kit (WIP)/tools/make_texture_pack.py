"""Draws UIKit's texture pack: the stud tile used by Stud Simulator surfaces.

Usage: python make_texture_pack.py <out_dir> [--preview]

The stud is a rounded square, a little lighter than the surface it sits on, with a light top-left bevel and a dark
bottom-right bevel, on a transparent tile. It is mostly translucent white/black, so laid over any colour it reads as
the same colour, embossed (tone-on-tone) - the look of top Roblox simulator UIs.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

TILE = 64  # final pixels per stud cell
SUPER = 4  # draw at 4x and downsample for clean edges
STUD = 32  # stud face size inside the cell
RADIUS = 9  # stud corner radius
BEVEL = 3  # bevel line width
FACE_ALPHA = 58  # how much lighter the stud face is than the surface
LIGHT_ALPHA = 150  # top-left highlight
DARK_ALPHA = 60  # bottom-right shade
SHADOW_ALPHA = 34  # soft drop shadow under the stud
SHADOW_BLUR = 3


def _box(offset: float = 0.0) -> tuple:
    start = (TILE - STUD) / 2 + offset
    return (start * SUPER, start * SUPER, (start + STUD) * SUPER, (start + STUD) * SUPER)


def stud_tile() -> Image.Image:
    size = TILE * SUPER
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(_box(2), RADIUS * SUPER, fill=(0, 0, 0, SHADOW_ALPHA))
    tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR * SUPER)))
    face = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(face)
    draw.rounded_rectangle(_box(), RADIUS * SUPER, fill=(255, 255, 255, FACE_ALPHA))
    clear = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # light rim on the top-left half and a soft dark rim on the bottom-right half read as a raised bevel
    top_left = Image.new("L", (size, size), 0)
    ImageDraw.Draw(top_left).polygon([(0, 0), (size, 0), (0, size)], fill=255)
    bottom_right = Image.new("L", (size, size), 0)
    ImageDraw.Draw(bottom_right).polygon([(size, 0), (size, size), (0, size)], fill=255)
    light = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(light).rounded_rectangle(_box(), RADIUS * SUPER, outline=(255, 255, 255, LIGHT_ALPHA), width=BEVEL * SUPER)
    dark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(dark).rounded_rectangle(_box(), RADIUS * SUPER, outline=(0, 0, 0, DARK_ALPHA), width=BEVEL * SUPER)
    face.alpha_composite(Image.composite(light, clear, top_left))
    face.alpha_composite(Image.composite(dark, clear, bottom_right))
    tile.alpha_composite(face)
    return tile.resize((TILE, TILE), Image.LANCZOS)


def preview(tile: Image.Image, path: Path) -> None:
    """A yellow studded button at the size Roblox would show it, next to a blue and a dark panel swatch."""
    width, height, cell = 900, 300, 26
    canvas = Image.new("RGBA", (width, height), (40, 20, 20, 255))
    swatches = [((255, 214, 64), (247, 160, 32)), ((70, 150, 255), (40, 100, 230)), ((52, 46, 60), (36, 32, 44))]
    small = tile.resize((cell, cell), Image.LANCZOS)
    for i, (top, bottom) in enumerate(swatches):
        x0 = 20 + i * 295
        swatch = Image.new("RGBA", (270, 220), (0, 0, 0, 0))
        grad = Image.new("RGBA", (270, 220))
        for y in range(220):
            t = y / 219
            grad.paste(tuple(int(top[c] + (bottom[c] - top[c]) * t) for c in range(3)) + (255,), (0, y, 270, y + 1))
        for gy in range(0, 220, cell):
            for gx in range(0, 270, cell):
                grad.alpha_composite(small, (gx, gy))
        mask = Image.new("L", (270, 220), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, 269, 219), 18, fill=255)
        swatch.paste(grad, (0, 0), mask)
        ImageDraw.Draw(swatch).rounded_rectangle((0, 0, 269, 219), 18, outline=(15, 10, 20, 255), width=4)
        canvas.alpha_composite(swatch, (x0, 40))
    canvas.convert("RGB").save(path, quality=92)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    tile = stud_tile()
    path = out / "stud_tile.png"
    tile.save(path)
    print(path)
    if "--preview" in sys.argv:
        preview_path = out / "stud_tile_preview.jpg"
        preview(tile, preview_path)
        print(preview_path)


if __name__ == "__main__":
    main()
