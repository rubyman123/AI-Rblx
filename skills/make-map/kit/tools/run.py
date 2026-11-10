"""Roblox Maps by fwjelaa: the pack's command line. Method by fwjelaa (FWJ STUDIOS).

  python kit/tools/run.py check          is everything set up? (Python, Pillow, the API key and who it uploads as)
  python kit/tools/run.py serve          serve the kit to Studio on 127.0.0.1:8777 (leave it running)
  python kit/tools/run.py budget <map>   print the Luau that measures triangles/draw calls at the map's shots
  python kit/tools/run.py material <name> --from ambientcg:<ID>|polyhaven:<id> [--tint "#hex"] [--studs 8]
                                         [--base Fabric] [--pattern Regular|Organic] [--px 1024]
                                         fetch a CC0 material, prep it, upload it (with a key), record it
  python kit/tools/run.py record <name> color=rbxassetid://.. normal=.. roughness=..   ids from upload_image
  python kit/tools/run.py hum <name> [--base 120]      generate a looping fluorescent hum and upload it
  python kit/tools/run.py wind <name> [--seconds 12]   generate a looping night wind and upload it
  python kit/tools/run.py record-sound <name> rbxassetid://..   a sound you uploaded yourself
  python kit/tools/run.py model <name> --from polyhaven:<id> [--tris 18000] [--collision Box|Hull|Default|none]
                                         fetch a CC0 model, prep it in Blender (studs, <20k tris), upload, record
  python kit/tools/run.py tree <name> [--kind dead|broadleaf|pine] [--seed 1] [--height 40]
                          [--bark polyhaven:bark_brown_02] [--leaves ambientcg:LeafSet010|needles]
                                         grow a tree in Blender (CC0 bark, leaf cards from a CC0 atlas), upload
  python kit/tools/run.py clump <name> [--leaves ambientcg:Foliage001] [--count 40] [--radius 6] [--height 2.5]
                                         a patch of grass/reed tufts made of alpha cards, upload
  python kit/tools/run.py sky <name> --from polyhaven:<hdri>_puresky [--azimuth -40]
                                         an HDRI turned into Roblox's six sky faces (sun turned to --azimuth), upload
  python kit/tools/run.py record-sky <name> Bk=rbxassetid://.. Dn=.. Ft=.. Lf=.. Rt=.. Up=..   faces from upload_image
  python kit/tools/run.py water <name>  generate a looping lapping-water sound and upload it
  python kit/tools/run.py guide          rebuild GUIDE.html from GUIDE.md (run after editing the guide)
  python kit/tools/run.py zip [dest]     package the pack (default Desktop/Roblox-Maps-by-fwjelaa.zip)
"""
import json
import sys
import urllib.request

import keyfile


def introspect(key):
    req = urllib.request.Request("https://apis.roblox.com/api-keys/v1/introspect",
                                 data=json.dumps({"apiKey": key}).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    info = json.load(urllib.request.urlopen(req, timeout=20))
    info.pop("apiKey", None)
    return info


def asset_owners(info):
    for s in info.get("scopes", []):
        if s.get("name") == "asset":
            return {"users": s.get("userIds", []), "groups": s.get("groupIds", []),
                    "write": "write" in s.get("operations", [])}
    return None


def budget_luau(map_id):
    spec = json.loads((keyfile.PACK / "maps" / map_id / "map.json").read_text(encoding="utf-8"))
    views = [{"name": s["name"], "cam": s["cam"], "look": s["look"]} for s in spec["shots"]]
    template = (keyfile.PACK / "kit" / "studio" / "snippets" / "budget.luau").read_text(encoding="utf-8")
    return template.replace("--[[VIEWS]]", json.dumps(views))


def material_cmd(args):
    import argparse
    import textures
    import upload

    ap = argparse.ArgumentParser(prog="run.py material")
    ap.add_argument("name")
    ap.add_argument("--from", dest="source", required=True, help="ambientcg:<ID> or polyhaven:<id>")
    ap.add_argument("--size", default=None)
    ap.add_argument("--px", type=int, default=1024)
    ap.add_argument("--tint", default=None)
    ap.add_argument("--studs", type=float, default=8)
    ap.add_argument("--base", default="Plastic")
    ap.add_argument("--pattern", default="Regular")
    ap.add_argument("--motif", default=None, help="kind:period:strength, e.g. chevron:32:0.12 (dots, stripes)")
    a = ap.parse_args(args)
    lib, asset = a.source.split(":", 1)
    maps = (textures.ambientcg_maps(asset, a.size or "1K") if lib == "ambientcg"
            else textures.polyhaven_maps(asset, a.size or "1k"))
    files = textures.prep(maps, textures.CACHE / "textures" / a.name, a.px, a.tint, a.motif)
    url = f"https://ambientcg.com/view?id={asset}" if lib == "ambientcg" else f"https://polyhaven.com/a/{asset}"
    textures.record(textures.MANIFEST, a.name, {
        "source": a.source, "url": url, "license": "CC0 1.0", "tint": a.tint, "motif": a.motif,
        "studsPerTile": a.studs, "base": a.base, "pattern": a.pattern,
        "files": {k: p.relative_to(keyfile.PACK).as_posix() for k, p in files.items()},
    }, replace=True)
    key = keyfile.find_key()
    if key:
        ids = upload.upload_material(a.name, files, key, introspect(key)["authorizedUserId"])
        textures.record(textures.MANIFEST, a.name, {"ids": ids})
        print(f"{a.name}: uploaded {ids}")
    else:
        print(f"{a.name}: no API key, so upload with the Studio MCP tool upload_image:")
        for p in files.values():
            print(f"  http://127.0.0.1:8777/{p.relative_to(keyfile.PACK).as_posix()}")
        print(f"then: python kit/tools/run.py record {a.name} " + " ".join(f"{k}=rbxassetid://..." for k in files))
    return 0


def model_cmd(args):
    import argparse
    import models
    import textures
    import upload

    ap = argparse.ArgumentParser(prog="run.py model")
    ap.add_argument("name")
    ap.add_argument("--from", dest="source", required=True, help="polyhaven:<id>")
    ap.add_argument("--tris", type=int, default=18000)
    ap.add_argument("--res", default="1k")
    ap.add_argument("--collision", default="Box", choices=["Box", "Hull", "Default", "none"])
    a = ap.parse_args(args)
    lib, _, asset = a.source.partition(":")
    if lib != "polyhaven" or not asset:
        raise SystemExit("--from must be polyhaven:<id> (e.g. polyhaven:Rockingchair_01)")
    src = models.polyhaven_model(asset, a.res)
    glb = textures.CACHE / "models" / "glb" / f"{a.name}.glb"
    report = models.prep(src, glb, tris=a.tris)
    entry = {"source": a.source, "url": f"https://polyhaven.com/a/{asset}", "license": "CC0 1.0", "res": a.res,
             "tris": report["tris"], "maxMeshTris": report["max_mesh_tris"], "objects": report["objects"],
             "size": report["size"], "collision": a.collision, "file": glb.relative_to(keyfile.PACK).as_posix(),
             "remake": f"python kit/tools/run.py model {a.name} --from {a.source} --tris {a.tris} --res {a.res} --collision {a.collision}"}
    models.record(textures.MANIFEST, a.name, entry)
    key = keyfile.find_key()
    if not key:
        print(f"{a.name}: {report['tris']} tris, {report['size']} studs; no API key, so import "
              f"{glb} in Studio (File > Import 3D), publish it, then: python kit/tools/run.py record-model {a.name} rbxassetid://...")
        return 0
    mid = upload.upload_file(glb, "Model", f"{a.name} (CC0)", key, introspect(key)["authorizedUserId"])
    models.record(textures.MANIFEST, a.name, {**entry, "id": mid})
    print(f"{a.name}: {report['tris']} tris, {report['size']} studs, uploaded {mid}")
    return 0


def tree_cmd(args):
    import argparse
    import models
    import textures
    import upload

    ap = argparse.ArgumentParser(prog="run.py tree")
    ap.add_argument("name")
    ap.add_argument("--bark", default="polyhaven:bark_brown_02", help="polyhaven:<id> or ambientcg:<ID>")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--height", type=float, default=40)
    ap.add_argument("--tris", type=int, default=16000)
    ap.add_argument("--tile", type=float, default=7)
    ap.add_argument("--kind", default="dead", choices=["dead", "broadleaf", "pine"])
    ap.add_argument("--leaves", default=None, help="ambientcg:LeafSetNNN (leaf atlas) or needles; broadleaf/pine only")
    a = ap.parse_args(args)
    lib, _, asset = a.bark.partition(":")
    maps = textures.ambientcg_maps(asset) if lib == "ambientcg" else textures.polyhaven_maps(asset)
    maps.pop("metalness", None)
    bark_dir = textures.CACHE / "textures" / f"{a.name}_bark"
    textures.prep(maps, bark_dir, 1024)
    glb = textures.CACHE / "models" / "glb" / f"{a.name}.glb"
    leaves = a.leaves or ("needles" if a.kind == "pine" else "ambientcg:LeafSet010")
    if a.kind == "dead":
        report = models.make_tree(glb, bark_dir, seed=a.seed, height=a.height, tris=a.tris, tile=a.tile)
    else:
        leaves_dir = _leaf_card(f"{a.name}_leaves", leaves, a.seed)
        report = models.make_leafy_tree(glb, bark_dir, leaves_dir, kind=a.kind, seed=a.seed, height=a.height,
                                        tris=a.tris, tile=a.tile)
    remake = (f"python kit/tools/run.py tree {a.name} --kind {a.kind} --seed {a.seed} --height {a.height:g} "
              f"--bark {a.bark} --tris {a.tris} --tile {a.tile:g}") + ("" if a.kind == "dead" else f" --leaves {leaves}")
    entry = {"source": f"generated:{a.kind} tree seed={a.seed} height={a.height}", "bark": a.bark, "license": "CC0 1.0",
             "leaves": None if a.kind == "dead" else leaves,
             "tris": report["tris"], "maxMeshTris": report["max_mesh_tris"], "objects": report["objects"],
             "size": report["size"], "collision": "Hull", "file": glb.relative_to(keyfile.PACK).as_posix(),
             "remake": remake}
    models.record(textures.MANIFEST, a.name, entry)
    key = keyfile.find_key()
    if not key:
        print(f"{a.name}: {report['tris']} tris, {report['size']} studs; no API key, so import {glb} in Studio "
              f"(File > Import 3D), publish it, then: python kit/tools/run.py record-model {a.name} rbxassetid://...")
        return 0
    mid = upload.upload_file(glb, "Model", f"{a.name} (generated tree)", key, introspect(key)["authorizedUserId"])
    models.record(textures.MANIFEST, a.name, {**entry, "id": mid})
    print(f"{a.name}: {report['tris']} tris, {report['size']} studs, uploaded {mid}")
    return 0


def _atlas(asset):
    # an ambientCG foliage atlas: colour + opacity + OpenGL normal from the downloaded zip
    import io
    import zipfile

    from PIL import Image

    import textures
    textures.ambientcg_maps(asset)  # downloads and caches the zip
    z = zipfile.ZipFile(textures.CACHE / "downloads" / f"{asset}_1K-JPG.zip")

    def get(suffix):
        name = next((n for n in z.namelist() if n.endswith(suffix)), None)
        if not name:
            raise SystemExit(f"{asset} has no {suffix} map: pick an ambientCG LeafSet/Foliage atlas")
        return Image.open(io.BytesIO(z.read(name)))
    return get("_Color.jpg"), get("_Opacity.jpg"), get("_NormalGL.jpg")


def _leaf_card(dirname, leaves, seed, tuft=False):
    from PIL import Image

    import foliage
    import textures
    out = textures.CACHE / "textures" / dirname
    out.mkdir(parents=True, exist_ok=True)
    if leaves == "needles":
        color, normal = foliage.compose_needles(size=1024, seed=seed)
    else:
        lib, _, asset = leaves.partition(":")
        if lib != "ambientcg" or not asset:
            raise SystemExit("--leaves must be ambientcg:<LeafSet/Foliage atlas> or needles")
        parts = foliage.extract_leaves(*_atlas(asset))
        color, normal = (foliage.compose_tuft(parts, size=1024, count=70, seed=seed) if tuft
                         else foliage.compose_cluster(parts, size=1024, count=110, seed=seed))
    color.save(out / "color.png")
    normal.save(out / "normal.png")
    Image.new("L", color.size, 200).save(out / "roughness.png")
    return out


def _upload_model(name, glb, entry, label):
    import models
    import textures
    import upload
    models.record(textures.MANIFEST, name, entry)
    key = keyfile.find_key()
    if not key:
        print(f"{name}: {entry['tris']} tris; no API key, so import {glb} in Studio (File > Import 3D), publish it, "
              f"then: python kit/tools/run.py record-model {name} rbxassetid://...")
        return 0
    mid = upload.upload_file(glb, "Model", f"{name} ({label})", key, introspect(key)["authorizedUserId"])
    models.record(textures.MANIFEST, name, {**entry, "id": mid})
    print(f"{name}: {entry['tris']} tris, {entry['size']} studs, uploaded {mid}")
    return 0


def clump_cmd(args):
    import argparse
    import models
    import textures

    ap = argparse.ArgumentParser(prog="run.py clump")
    ap.add_argument("name")
    ap.add_argument("--leaves", default="ambientcg:Foliage001", help="ambientcg:<Foliage atlas>")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--count", type=int, default=40)
    ap.add_argument("--radius", type=float, default=6)
    ap.add_argument("--height", type=float, default=2.5)
    a = ap.parse_args(args)
    leaves_dir = _leaf_card(f"{a.name}_tuft", a.leaves, a.seed, tuft=True)
    glb = textures.CACHE / "models" / "glb" / f"{a.name}.glb"
    rep = models.make_clump(glb, leaves_dir, seed=a.seed, count=a.count, radius=a.radius, height=a.height)
    entry = {"source": f"generated:clump seed={a.seed}", "leaves": a.leaves, "license": "CC0 1.0", "tris": rep["tris"],
             "maxMeshTris": rep["max_mesh_tris"], "objects": 1, "size": rep["size"], "collision": "none",
             "file": glb.relative_to(keyfile.PACK).as_posix(),
             "remake": (f"python kit/tools/run.py clump {a.name} --leaves {a.leaves} --seed {a.seed} --count {a.count} "
                        f"--radius {a.radius:g} --height {a.height:g}")}
    return _upload_model(a.name, glb, entry, "generated clump")


def sky_cmd(args):
    import argparse
    import json as _json
    import math

    from PIL import Image

    import sky
    import textures
    import upload

    ap = argparse.ArgumentParser(prog="run.py sky")
    ap.add_argument("name")
    ap.add_argument("--from", dest="source", required=True, help="polyhaven:<hdri id>, a *_puresky one is best")
    ap.add_argument("--azimuth", type=float, default=None, help="where the sun should end up, degrees from north (-Z) toward east (+X)")
    ap.add_argument("--size", type=int, default=512, help="face size; 1024 faces load as images but never render as a sky")
    a = ap.parse_args(args)
    lib, _, asset = a.source.partition(":")
    if lib != "polyhaven" or not asset:
        raise SystemExit("--from must be polyhaven:<hdri id>")
    files = _json.loads(textures.http_get(f"https://api.polyhaven.com/files/{asset}"))
    url = files.get("tonemapped", {}).get("url")
    if not url:
        raise SystemExit(f"{asset} has no tonemapped JPG on Poly Haven")
    jpg = textures.CACHE / "skies" / f"{asset}.jpg"
    if not jpg.exists():
        jpg.parent.mkdir(parents=True, exist_ok=True)
        jpg.write_bytes(textures.http_get(url))
    Image.MAX_IMAGE_PIXELS = None  # Poly Haven's 8K panoramas
    pano = Image.open(jpg).convert("RGB")
    sun = sky.sun_direction(pano)
    yaw = 0.0 if a.azimuth is None else sky.yaw_for(sun, a.azimuth)
    faces = sky.cube_faces(pano, size=a.size, yaw_deg=yaw)
    out = textures.CACHE / "skies" / a.name
    out.mkdir(parents=True, exist_ok=True)
    paths = {}
    for k, im in faces.items():
        paths[k] = out / f"{k}.png"
        im.save(paths[k])
    final = sky.rotate_dir(sun, -yaw)
    entry = {"source": a.source, "url": f"https://polyhaven.com/a/{asset}", "license": "CC0 1.0",
             "sun": [round(c, 4) for c in final], "yaw": round(yaw, 2),
             "remake": f"python kit/tools/run.py sky {a.name} --from {a.source}" + ("" if a.azimuth is None else f" --azimuth {a.azimuth:g}")}
    key = keyfile.find_key()
    if key:  # upload first: the manifest is only locked for the moment of the write
        uid = introspect(key)["authorizedUserId"]
        entry["ids"] = {k: upload.upload_file(p, "Image", f"{a.name} sky {k}", key, uid) for k, p in paths.items()}
    import manifest
    manifest.update(textures.MANIFEST, lambda data: data.setdefault("skies", {}).__setitem__(a.name, entry))
    if key:
        print(f"{a.name}: six faces uploaded, sun at {entry['sun']}")
    else:
        print(f"{a.name}: no API key, so upload the six faces with the Studio MCP tool upload_image:")
        for k in sorted(paths):
            print(f"  {k}: http://127.0.0.1:8777/{paths[k].relative_to(keyfile.PACK).as_posix()}")
        print(f"then: python kit/tools/run.py record-sky {a.name} "
              + " ".join(f"{k}=rbxassetid://..." for k in sorted(paths)))
    return 0


def record_sky_cmd(args):
    import re
    import manifest
    import textures

    faces = ("Bk", "Dn", "Ft", "Lf", "Rt", "Up")
    name = args[0]
    usage = f"usage: python kit/tools/run.py record-sky {name} " + " ".join(f"{f}=rbxassetid://<number>" for f in faces)
    ids = {}
    for arg in args[1:]:
        face, _, value = arg.partition("=")
        if face not in faces:
            raise SystemExit(f"{face!r} is not a sky face ({', '.join(faces)}). {usage}")
        if not re.fullmatch(r"rbxassetid://\d+", value):
            raise SystemExit(f"{face}={value!r} is not an uploaded id like rbxassetid://123456. {usage}")
        ids[face] = value
    missing = [f for f in faces if f not in ids]
    if missing:
        raise SystemExit(f"missing ids for {', '.join(missing)}: a sky needs all six faces. {usage}")

    def change(data):
        entry = data.get("skies", {}).get(name)
        if not entry:
            raise SystemExit(f"no sky {name!r} in assets.json: run `python kit/tools/run.py sky {name} --from ...` first")
        entry["ids"] = ids
    manifest.update(textures.MANIFEST, change)
    print(f"{name}: recorded six faces")
    return 0


def water_cmd(args):
    import argparse
    import audio
    import textures

    ap = argparse.ArgumentParser(prog="run.py water")
    ap.add_argument("name")
    ap.add_argument("--seconds", type=float, default=10.0)
    a = ap.parse_args(args)
    return _generated_sound(a.name, audio.water_wav(textures.CACHE / "audio" / f"{a.name}.wav", seconds=a.seconds), "generated water")


def _record_sound(name, sid, source):
    import textures

    import manifest

    manifest.update(textures.MANIFEST, lambda data: data.setdefault("sounds", {}).__setitem__(
        name, {"id": sid, "source": source, "license": "CC0 1.0"}))


def _generated_sound(name, path, label):
    import upload

    key = keyfile.find_key()
    if not key:
        print(f"wrote {path}; no API key, so upload it in Studio (Asset Manager) and run: "
              f"python kit/tools/run.py record-sound {name} rbxassetid://...")
        return 0
    sid = upload.upload_file(path, "Audio", f"{name} ({label})", key, introspect(key)["authorizedUserId"])
    _record_sound(name, sid, "generated by kit/tools/audio.py")
    print(f"{name}: uploaded {sid}")
    return 0


def hum_cmd(args):
    import argparse
    import audio
    import textures

    ap = argparse.ArgumentParser(prog="run.py hum")
    ap.add_argument("name")
    ap.add_argument("--base", type=float, default=120.0)
    a = ap.parse_args(args)
    return _generated_sound(a.name, audio.hum_wav(textures.CACHE / "audio" / f"{a.name}.wav", base=a.base), "generated hum")


def wind_cmd(args):
    import argparse
    import audio
    import textures

    ap = argparse.ArgumentParser(prog="run.py wind")
    ap.add_argument("name")
    ap.add_argument("--seconds", type=float, default=12.0)
    a = ap.parse_args(args)
    return _generated_sound(a.name, audio.wind_wav(textures.CACHE / "audio" / f"{a.name}.wav", seconds=a.seconds), "generated wind")


def record_cmd(args):
    import re
    import textures

    name = args[0]
    data = json.loads(textures.MANIFEST.read_text(encoding="utf-8")) if textures.MANIFEST.exists() else {}
    entry = data.get("materials", {}).get(name)
    if not entry or not entry.get("files"):
        raise SystemExit(f"no prepared material {name!r}: run `python kit/tools/run.py material {name} --from ...` first")
    kinds = sorted(entry["files"])
    usage = f"usage: python kit/tools/run.py record {name} " + " ".join(f"{k}=rbxassetid://<number>" for k in kinds)
    pairs = {}
    for a in args[1:]:
        kind, _, value = a.partition("=")
        if kind not in entry["files"]:
            raise SystemExit(f"{name} has no {kind!r} map (it has {', '.join(kinds)}). {usage}")
        if not re.fullmatch(r"rbxassetid://\d+", value):
            raise SystemExit(f"{kind}={value!r} is not an uploaded id like rbxassetid://123456. {usage}")
        pairs[kind] = value
    missing = [k for k in kinds if k not in pairs]
    if missing:
        raise SystemExit(f"missing ids for {', '.join(missing)}: give one per map. {usage}")
    textures.record(textures.MANIFEST, name, {"ids": pairs})
    print(f"{name}: recorded {pairs}")
    return 0


def check():
    ok = sys.version_info >= (3, 9)
    print(f"Python {sys.version.split()[0]}", "OK" if ok else "-- need 3.9 or newer")
    try:
        import PIL
        print(f"Pillow {PIL.__version__} OK")
    except ImportError:
        ok = False
        print("Pillow missing -- run: python -m pip install pillow numpy")
    try:
        import numpy
        print(f"numpy {numpy.__version__} OK")
    except ImportError:
        ok = False
        print("numpy missing (run.py hum needs it) -- run: python -m pip install numpy")
    import models
    exe = models.blender_exe()
    print(f"Blender OK ({exe})" if exe else "Blender: not found (only realistic props need it; set BLENDER to blender.exe)")
    key = keyfile.find_key()
    if not key:
        print("API key: none (fine for stylized maps; realistic maps need one, see README)")
    else:
        try:
            info = introspect(key)
            owners = asset_owners(info)
            print(f"API key OK: user {info.get('authorizedUserId')}, asset scope {owners}")
            if not owners or not owners["write"]:
                ok = False
                print("-- the key cannot upload: add Assets API Read + Write for your own account")
        except Exception as e:  # offline, or a revoked key
            ok = False
            print(f"API key could not be checked: {e}")
    print("ALL GOOD" if ok else "FIX THE LINES ABOVE")
    return ok


def main(argv):
    cmd = argv[0] if argv else "help"
    if cmd == "check":
        return 0 if check() else 1
    if cmd == "serve":
        import serve
        serve.serve()
        return 0
    if cmd == "zip":
        import make_zip
        make_zip.make_zip(argv[1] if len(argv) > 1 else None)
        return 0
    if cmd == "guide":
        import guide
        out = keyfile.PACK / "GUIDE.html"
        out.write_text(guide.build((keyfile.PACK / "GUIDE.md").read_text(encoding="utf-8")), encoding="utf-8",
                       newline="\n")
        print(f"wrote {out}")
        return 0
    if cmd == "material":
        return material_cmd(argv[1:])
    if cmd == "record" and len(argv) > 2:
        return record_cmd(argv[1:])
    if cmd == "hum" and len(argv) > 1:
        return hum_cmd(argv[1:])
    if cmd == "wind" and len(argv) > 1:
        return wind_cmd(argv[1:])
    if cmd == "tree" and len(argv) > 1:
        return tree_cmd(argv[1:])
    if cmd == "clump" and len(argv) > 1:
        return clump_cmd(argv[1:])
    if cmd == "record-sky" and len(argv) > 1:
        return record_sky_cmd(argv[1:])
    if cmd == "sky" and len(argv) > 1:
        return sky_cmd(argv[1:])
    if cmd == "water" and len(argv) > 1:
        return water_cmd(argv[1:])
    if cmd == "model" and len(argv) > 1:
        return model_cmd(argv[1:])
    if cmd == "record-model" and len(argv) > 2:
        import models
        import re
        import textures
        data = json.loads(textures.MANIFEST.read_text(encoding="utf-8")) if textures.MANIFEST.exists() else {}
        entry = data.get("models", {}).get(argv[1])
        if not entry or not re.fullmatch(r"rbxassetid://\d+", argv[2]):
            raise SystemExit(f"usage: python kit/tools/run.py record-model <prepared model> rbxassetid://<number>")
        models.record(textures.MANIFEST, argv[1], {**entry, "id": argv[2]})
        print(f"{argv[1]}: recorded {argv[2]}")
        return 0
    if cmd == "record-sound" and len(argv) > 2:
        _record_sound(argv[1], argv[2], "uploaded by the user")
        print(f"{argv[1]}: recorded {argv[2]}")
        return 0
    if cmd == "budget" and len(argv) > 1:
        sys.stdout.write(budget_luau(argv[1]))
        return 0
    print(__doc__)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
