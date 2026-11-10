# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Uploads every exported model whose FBX changed since its last upload, then writes the Studio install script.

    python -I kit/upload_all.py [ModelId ...]      # default: every out/<ModelId>_export.json

Keeps uploads.json: {ModelId: {assetId, sha1, bbox_min, bbox_max, low_tris}}, so unchanged models are skipped.
Writes out/install.luau: paste it into Studio's command bar (Edit mode) after installing roblox/ModelInstaller.luau
as a ModuleScript in ServerStorage (see Automatic upload in GUIDE.html).
Optional icons.json ({ModelId: "rbxassetid://..."}) also swaps each model's icon image.
"""
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from upload_asset import upload  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "out"
LEDGER = ROOT / "uploads.json"
ICONS_FILE = ROOT / "icons.json"


def main(only):
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    prefix = config.get("name_prefix", "")
    icons = json.loads(ICONS_FILE.read_text(encoding="utf-8")) if ICONS_FILE.exists() else {}
    ledger = json.loads(LEDGER.read_text(encoding="utf-8")) if LEDGER.exists() else {}
    for path in sorted(OUT.glob("*_export.json")):
        info = json.loads(path.read_text(encoding="utf-8"))
        model_id = info["cuh"]
        if only and model_id not in only:
            continue
        fbx = OUT / f"{model_id}.fbx"
        sha1 = hashlib.sha1(fbx.read_bytes()).hexdigest()
        entry = ledger.get(model_id, {})
        if entry.get("sha1") == sha1 and entry.get("assetId"):
            print(f"{model_id}: unchanged ({entry['assetId']})")
        else:
            res = upload(fbx, "Model", f"{prefix}{model_id}", f"{model_id} model")
            if "assetId" not in res:
                print(f"{model_id}: UPLOAD FAILED {res}")
                continue
            entry = {"assetId": res["assetId"], "sha1": sha1}
            print(f"{model_id}: uploaded {res['assetId']}")
        entry["bbox_min"], entry["bbox_max"] = info["bbox_min"], info["bbox_max"]
        entry["low_tris"] = info["low_tris"]
        ledger[model_id] = entry
        LEDGER.write_text(json.dumps(ledger, indent=1, sort_keys=True), encoding="utf-8")

    # :Clone() so Studio's command bar never runs a cached old copy of the installer
    lines = ["local install = require(game.ServerStorage.ModelInstaller:Clone())", "local out = {}"]
    for model_id, e in sorted(ledger.items()):
        if only and model_id not in only:
            continue
        lo, hi = e["bbox_min"], e["bbox_max"]
        icon = f', "{icons[model_id]}"' if model_id in icons else ""
        lines.append(
            f'table.insert(out, install("{model_id}", {e["assetId"]}, {{{lo[0]}, {lo[1]}, {lo[2]}}}, '
            f'{{{hi[0]}, {hi[1]}, {hi[2]}}}{icon}))')
    lines.append('print(table.concat(out, "\\n"))')
    (OUT / "install.luau").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT / 'install.luau'}")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
