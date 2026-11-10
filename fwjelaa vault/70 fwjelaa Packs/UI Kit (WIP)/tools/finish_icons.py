"""Turns Blender's 512 px icon renders into the 256 px PNGs that get uploaded to Roblox.

Usage: python finish_icons.py <raw_dir> <out_dir>
Downscaling from 512 keeps the ink outline smooth; 256 px is plenty for icons shown at 40-120 px in game.
"""
import sys
from pathlib import Path

from PIL import Image

SIZE = 256


def main() -> None:
    raw, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    names = []
    for path in sorted(raw.glob("*.png")):
        icon = Image.open(path).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        icon.save(out / path.name, optimize=True)
        names.append(path.stem)
    print(f"{len(names)} icons -> {out}: {', '.join(names)}")


if __name__ == "__main__":
    main()
