"""CC0 materials: fetch from ambientCG / Poly Haven, prep for Roblox, record in assets.json. Method by fwjelaa (FWJ STUDIOS).

Both libraries are CC0 1.0. Poly Haven asks API users to send a unique User-Agent and to credit them lightly; the
pack credits both in CREDITS.md and records every asset's source in assets.json."""
import io
import json
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

import keyfile

UA = {"User-Agent": "roblox-maps-by-fwjelaa/1.0"}
CACHE = keyfile.PACK / "cache"
MANIFEST = keyfile.PACK / "assets.json"
ZIP_SUFFIXES = {"color": "_Color", "normal": "_NormalGL", "roughness": "_Roughness", "metalness": "_Metalness"}


def http_get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()


def ambientcg_maps(asset_id, size="1K", cache=None, get=http_get):
    cache = CACHE if cache is None else cache
    zpath = Path(cache) / "downloads" / f"{asset_id}_{size}-JPG.zip"
    if not zpath.exists():
        zpath.parent.mkdir(parents=True, exist_ok=True)
        zpath.write_bytes(get(f"https://ambientcg.com/get?file={asset_id}_{size}-JPG.zip"))
    out = {}
    with zipfile.ZipFile(zpath) as z:
        for name in z.namelist():
            stem = name.rsplit(".", 1)[0]
            for kind, suffix in ZIP_SUFFIXES.items():
                if stem.endswith(suffix):
                    out[kind] = z.read(name)
    if "color" not in out or "normal" not in out:
        raise SystemExit(f"{asset_id}: the download has no _Color or _NormalGL map (is it a material?)")
    return out


def _png_bytes(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def polyhaven_maps(asset_id, size="1k", get=http_get):
    files = json.loads(get(f"https://api.polyhaven.com/files/{asset_id}"))

    def url(key, fmt="jpg"):
        return files[key][size][fmt]["url"]

    out = {"color": get(url("Diffuse")), "normal": get(url("nor_gl"))}
    if "Rough" in files:
        out["roughness"] = get(url("Rough"))
    elif "arm" in files:
        _, g, b = Image.open(io.BytesIO(get(url("arm", "png")))).convert("RGB").split()
        out["roughness"] = _png_bytes(g)
        out["metalness"] = _png_bytes(b)
    return out


def _tinted(im, hex_color):
    # re-colour from the map's own luminance: keeps the pattern, makes the whole thing one hue
    rgb = tuple(int(hex_color.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    gray = im.convert("L")
    mean = max(1.0, sum(gray.getdata()) / (gray.width * gray.height))
    bands = [gray.point(lambda v, c=c: min(255, int(v / mean * c))) for c in rgb]
    return Image.merge("RGB", bands)


def _motif(im, spec):
    # "kind:period:strength": a faint printed pattern multiplied into the colour map (kit-made, so no licence
    # question). The period must divide the texture size or the tile seam shows.
    kind, period, strength = spec.split(":")
    period, strength = int(period), float(strength)
    w, h = im.size
    if w % period or h % period:
        raise SystemExit(f"motif period {period} must divide the texture size {w}")
    pat = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(pat)
    for y0 in range(0, h, period):
        for x0 in range(0, w, period):
            if kind == "chevron":
                d.line([(x0, y0 + period * 0.6), (x0 + period / 2, y0 + period * 0.3), (x0 + period, y0 + period * 0.6)],
                       fill=255, width=max(1, period // 12))
            elif kind == "dots":
                r = max(1, period // 8)
                cx, cy = x0 + period // 2, y0 + period // 2
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
            elif kind == "stripes":
                d.rectangle([x0, y0, x0 + period // 4, y0 + period - 1], fill=255)
            else:
                raise SystemExit(f"unknown motif {kind!r} (chevron, dots, stripes)")
    shade = pat.point(lambda v: int(255 * (1 - strength * v / 255)))
    return ImageChops.multiply(im, Image.merge("RGB", [shade, shade, shade]))


def prep(maps, out_dir, size=1024, tint=None, motif=None):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    for kind, data in maps.items():
        im = Image.open(io.BytesIO(data))
        im = im.convert("RGB") if kind in ("color", "normal") else im.convert("L")
        if im.size != (size, size):
            im = im.resize((size, size), Image.LANCZOS)
        if kind == "color" and tint:
            im = _tinted(im, tint)
        if kind == "color" and motif:
            im = _motif(im, motif)
        path = out_dir / f"{kind}.png"
        im.save(path)
        files[kind] = path
    return files


def record(manifest, name, entry, replace=False):
    # replace=True starts the entry afresh (a re-run with a new source must not keep the old ids or maps)
    import manifest as _manifest

    def change(data):
        data.setdefault("materials", {})
        merged = {} if replace else dict(data["materials"].get(name, {}))
        for k, v in entry.items():
            merged[k] = {**merged[k], **v} if isinstance(v, dict) and isinstance(merged.get(k), dict) else v
        data["materials"][name] = merged
        return merged
    return _manifest.update(manifest, change)
