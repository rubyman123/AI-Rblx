# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Uploads one file to Roblox through Open Cloud (Assets API v1).

    python -I kit/upload_asset.py <file> <Model|Decal> "<display name>" ["<description>"]

Setup (see Automatic upload in GUIDE.html):
  - Your Open Cloud API key goes in .secrets/roblox-api-key.txt (or the ROBLOX_API_KEY environment variable).
    It is only ever sent as the x-api-key header and never printed; errors are redacted.
  - config.json says who owns the uploads: "group_id" (uploads to your group) or "user_id" (to your account).
    Games owned by a group can only use assets owned by that same group.

Prints one JSON line: {"file", "assetId"} or {"file", "status", "error"}.
"""
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
API = "https://apis.roblox.com/assets/v1"
CONTENT_TYPES = {".fbx": "model/fbx", ".png": "image/png", ".glb": "model/gltf-binary"}


def load_key() -> str:
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    path = ROOT / ".secrets" / "roblox-api-key.txt"
    if not key and path.exists():
        key = path.read_text(encoding="utf-8").strip()
    if not key:
        sys.exit("No API key: put it in .secrets/roblox-api-key.txt (see Automatic upload in GUIDE.html).")
    return key


def load_creator() -> dict:
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    group, user = str(config.get("group_id", "")).strip(), str(config.get("user_id", "")).strip()
    if group:
        return {"groupId": group}
    if user:
        return {"userId": user}
    sys.exit("config.json needs a group_id or a user_id (see Automatic upload in GUIDE.html).")


def upload(path: pathlib.Path, asset_type: str, display: str, description: str):
    key = load_key()

    def redact(text: str) -> str:
        return text.replace(key, "[redacted]")

    def request(method, url, body=None, content_type=None):
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("x-api-key", key)
        if content_type:
            req.add_header("Content-Type", content_type)
        try:
            with urllib.request.urlopen(req, timeout=120) as res:
                return res.status, json.loads(res.read() or b"{}")
        except urllib.error.HTTPError as err:
            return err.code, {"error": redact(err.read().decode("utf-8", "replace"))[:500]}

    meta = {
        "assetType": asset_type,
        "displayName": display[:50],
        "description": description[:1000],
        "creationContext": {"creator": load_creator()},
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n".encode(),
        (f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
         f"Content-Type: {CONTENT_TYPES[path.suffix.lower()]}\r\n\r\n").encode() + path.read_bytes() + b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    status, res = request("POST", f"{API}/assets", body, f"multipart/form-data; boundary={boundary}")
    if status >= 300:
        return {"file": path.name, "status": status, "error": res.get("error", res)}
    operation = res.get("path") or res.get("operationId")
    for _ in range(60):  # uploads finish asynchronously: poll the operation
        if res.get("done"):
            break
        time.sleep(2)
        status, res = request("GET", f"{API}/{operation}")
        if status >= 300:
            return {"file": path.name, "status": status, "error": res.get("error", res)}
    asset_id = (res.get("response") or {}).get("assetId")
    if not asset_id:
        return {"file": path.name, "status": status, "error": redact(json.dumps(res))[:500]}
    return {"file": path.name, "assetId": asset_id}


if __name__ == "__main__":
    file, kind, display = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    desc = sys.argv[4] if len(sys.argv) > 4 else display
    print(json.dumps(upload(file, kind, display, desc)), flush=True)
