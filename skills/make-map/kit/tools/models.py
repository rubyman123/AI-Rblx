"""CC0 models: fetch from Poly Haven, prep in headless Blender, record in assets.json. Method by fwjelaa (FWJ STUDIOS).

Measured 2026-10-24 (research/00-measured.md): a GLB uploaded as a Model arrives as a MeshPart with a
SurfaceAppearance holding all four PBR maps, at 1 Blender unit = 1 stud, Blender's front (-Y) facing the part's
LookVector."""
import glob
import json
import os
import shutil
import subprocess
from pathlib import Path, PurePosixPath

import keyfile

PREP_SCRIPT = keyfile.PACK / "kit" / "blender" / "prep_model.py"


def _safe_rel(name):
    # include paths come from the API: only plain relative paths inside the model's folder
    p = PurePosixPath(name.replace("\\", "/"))
    if p.is_absolute() or ":" in name or ".." in p.parts or not p.parts:
        raise SystemExit(f"refusing unsafe file path in the model download: {name!r}")
    return Path(*p.parts)


def polyhaven_model(asset_id, res="1k", cache=None, get=None):
    import textures  # Pillow comes in with textures; `run.py check` imports this module without it

    get = get or textures.http_get
    cache = textures.CACHE if cache is None else Path(cache)
    files = json.loads(get(f"https://api.polyhaven.com/files/{asset_id}"))
    g = files["gltf"][res]["gltf"]
    rels = {name: _safe_rel(name) for name in g.get("include", {})}  # check every path before writing any
    root = Path(cache) / "models" / asset_id
    root.mkdir(parents=True, exist_ok=True)
    main = root / f"{asset_id}.gltf"
    main.write_bytes(get(g["url"]))
    for name, inc in g.get("include", {}).items():
        dest = root / rels[name]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(get(inc["url"]))
    return main


def blender_exe():
    env = os.environ.get("BLENDER")
    if env and Path(env).exists():
        return env
    found = sorted(glob.glob("C:/Program Files/Blender Foundation/*/blender.exe"))
    if found:
        return found[-1]
    return shutil.which("blender")


# measured 2026-10-25: scans whose JPEG textures were 1.1-1.3 MB (boulder_01, tree_stump_02 normals) uploaded and
# loaded as images, but never rendered on the MeshPart (it stayed white, or black in shade); re-encoded under this
# they rendered. Re-uploading the same bytes doesn't help: Roblox reuses the failed image.
TEXTURE_LIMIT_KB = 900


def shrink_textures(glb, limit_kb=TEXTURE_LIMIT_KB):
    """Re-encode every JPEG texture in a GLB that is over limit_kb, in place. Returns how many changed."""
    import io
    import struct

    from PIL import Image

    data = Path(glb).read_bytes()
    jl = struct.unpack_from("<I", data, 12)[0]
    j = json.loads(data[20:20 + jl])
    bl = struct.unpack_from("<I", data, 20 + jl)[0]
    blob = data[28 + jl: 28 + jl + bl]
    views = [blob[v.get("byteOffset", 0): v.get("byteOffset", 0) + v["byteLength"]] for v in j["bufferViews"]]
    changed = 0
    for img in j.get("images", []):
        raw = views[img["bufferView"]] if "bufferView" in img else b""
        if img.get("mimeType") != "image/jpeg" or len(raw) <= limit_kb * 1024:
            continue
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        for quality in (90, 85, 80, 75, 70, 65, 60):
            out = io.BytesIO()
            im.save(out, "JPEG", quality=quality)
            if out.tell() <= limit_kb * 1024:
                break
        views[img["bufferView"]] = out.getvalue()
        changed += 1
    if not changed:
        return 0
    packed = b""
    for v, raw in zip(j["bufferViews"], views):
        packed += b"\0" * (-len(packed) % 4)
        v["byteOffset"] = len(packed)
        v["byteLength"] = len(raw)
        packed += raw
    packed += b"\0" * (-len(packed) % 4)
    j["buffers"][0]["byteLength"] = len(packed)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    Path(glb).write_bytes(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(packed))
                          + struct.pack("<II", len(js), 0x4E4F534A) + js
                          + struct.pack("<II", len(packed), 0x004E4942) + packed)
    return changed


def prep(src_gltf, out_glb, tris=18000, scale=1 / 0.28, blender=None):
    exe = blender or blender_exe()
    if not exe:
        raise SystemExit("Blender not found: install Blender 4.2+ or set BLENDER to blender.exe")
    out_glb = Path(out_glb)
    out_glb.parent.mkdir(parents=True, exist_ok=True)
    res = subprocess.run([exe, "-b", "--factory-startup", "-P", str(PREP_SCRIPT), "--", "--in", str(src_gltf),
                          "--out", str(out_glb), "--tris", str(tris), "--scale", str(scale)],
                         capture_output=True, text=True, timeout=900)
    for line in res.stdout.splitlines():
        if line.startswith("PREP "):
            report = json.loads(line[5:])
            report["reencoded"] = shrink_textures(out_glb)
            return report
    tail = (res.stdout + res.stderr)[-1500:]
    raise SystemExit(f"Blender prep failed for {src_gltf}:\n{tail}")


TREE_SCRIPT = keyfile.PACK / "kit" / "blender" / "tree.py"


def make_tree(out_glb, bark_dir, seed=1, height=40.0, tris=16000, tile=7.0, blender=None):
    exe = blender or blender_exe()
    if not exe:
        raise SystemExit("Blender not found: install Blender 4.2+ or set BLENDER to blender.exe")
    out_glb = Path(out_glb)
    out_glb.parent.mkdir(parents=True, exist_ok=True)
    res = subprocess.run([exe, "-b", "--factory-startup", "-P", str(TREE_SCRIPT), "--", "--out", str(out_glb),
                          "--bark", str(bark_dir), "--seed", str(seed), "--height", str(height), "--tris", str(tris),
                          "--tile", str(tile)], capture_output=True, text=True, timeout=900)
    for line in res.stdout.splitlines():
        if line.startswith("PREP "):
            return json.loads(line[5:])
    raise SystemExit(f"Blender tree failed:\n{(res.stdout + res.stderr)[-1500:]}")


LEAFY_SCRIPT = keyfile.PACK / "kit" / "blender" / "leafy_tree.py"
CLUMP_SCRIPT = keyfile.PACK / "kit" / "blender" / "clump.py"


def _blender(script, args, what):
    exe = blender_exe()
    if not exe:
        raise SystemExit("Blender not found: install Blender 4.2+ or set BLENDER to blender.exe")
    res = subprocess.run([exe, "-b", "--factory-startup", "-P", str(script), "--"] + [str(a) for a in args],
                         capture_output=True, text=True, timeout=900)
    for line in res.stdout.splitlines():
        if line.startswith("PREP "):
            return json.loads(line[5:])
    raise SystemExit(f"Blender {what} failed:\n{(res.stdout + res.stderr)[-1500:]}")


def make_leafy_tree(out_glb, bark_dir, leaves_dir, kind="broadleaf", seed=1, height=40.0, tris=16000, tile=7.0):
    Path(out_glb).parent.mkdir(parents=True, exist_ok=True)
    return _blender(LEAFY_SCRIPT, ["--out", out_glb, "--bark", bark_dir, "--leaves", leaves_dir, "--kind", kind,
                                   "--seed", seed, "--height", height, "--tris", tris, "--tile", tile], "leafy tree")


def make_clump(out_glb, leaves_dir, seed=1, count=40, radius=6.0, height=2.5):
    Path(out_glb).parent.mkdir(parents=True, exist_ok=True)
    return _blender(CLUMP_SCRIPT, ["--out", out_glb, "--leaves", leaves_dir, "--seed", seed, "--count", count,
                                   "--radius", radius, "--height", height], "clump")


def record(manifest, name, entry):
    import manifest as _manifest

    def change(data):
        data.setdefault("models", {})[name] = dict(entry)
        return data["models"][name]
    return _manifest.update(manifest, change)
