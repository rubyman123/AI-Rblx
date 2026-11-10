"""Office Floor 14: build the procedural office props in headless Blender, prep, upload, record. MapKit by fwjelaa.

    python maps/office-floor-14/props.py [--only ofc_task_chair,ofc_monitor] [--no-upload]

blender/office_props.py builds each prop (metres, front = Blender +Y) and exports cache/models/src/<name>.glb;
the kit's prep (kit/blender/prep_model.py) scales it to studs, grounds it and checks the triangle budget; the GLB
goes up as a Model and lands in assets.json `models` like a Poly Haven scan, so K.Models.install loads it."""
import argparse
import functools
import json
import subprocess
import sys
from pathlib import Path

PACK = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PACK / "kit" / "tools"))

import keyfile  # noqa: E402
import models  # noqa: E402
import run  # noqa: E402
import textures  # noqa: E402
import upload  # noqa: E402

SCRIPT = Path(__file__).resolve().parent / "blender" / "office_props.py"
SRC = PACK / "cache" / "models" / "src"
OUT = PACK / "cache" / "models" / "glb"

# collision per prop (K.Models: Box | Hull | none); small desk clutter and ceiling fittings never collide
COLLISION = {
    "ofc_monitor": "none", "ofc_keyboard": "none", "ofc_mouse": "none", "ofc_desk_phone": "none", "ofc_mug": "none",
    "ofc_troffer": "none", "ofc_diffuser": "none", "ofc_emergency": "none", "ofc_extinguisher": "none",
    "ofc_bin": "none", "ofc_coffee": "none", "ofc_microwave": "none",
}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-upload", action="store_true")
    a = ap.parse_args(argv)
    SRC.mkdir(parents=True, exist_ok=True)
    exe = models.blender_exe()
    cmd = [exe, "-b", "--factory-startup", "-P", str(SCRIPT), "--", "--out", str(SRC)]
    if a.only:
        cmd += ["--only", a.only]
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    line = next((ln for ln in res.stdout.splitlines() if ln.startswith("PROPS ")), None)
    if not line:
        raise SystemExit("Blender build failed:\n" + (res.stdout + res.stderr)[-2000:])
    built = eval(line[6:], {})  # a dict literal printed by office_props.py
    key = keyfile.find_key()
    introspect = functools.lru_cache(maxsize=None)(run.introspect)
    for name, tris in built.items():
        glb = OUT / f"{name}.glb"
        report = models.prep(SRC / f"{name}.glb", glb, tris=19000)
        collision = COLLISION.get(name, "Box")
        entry = {"source": "generated:maps/office-floor-14/blender/office_props.py", "license": "CC0 1.0",
                 "tris": report["tris"], "maxMeshTris": report["max_mesh_tris"], "objects": report["objects"],
                 "size": report["size"], "collision": collision, "file": glb.relative_to(PACK).as_posix(),
                 "remake": f"python maps/office-floor-14/props.py --only {name}"}
        if key and not a.no_upload:
            entry["id"] = upload.upload_file(glb, "Model", f"{name} (generated)", key, introspect(key)["authorizedUserId"])
        models.record(textures.MANIFEST, name, entry)
        print(f"{name}: {report['tris']} tris, {report['objects']} parts, {report['size']} studs, {entry.get('id', 'not uploaded')}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
