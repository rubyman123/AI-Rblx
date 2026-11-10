"""Upload images, audio and models (GLB) to Roblox as the place owner (Open Cloud). Method by fwjelaa (FWJ STUDIOS).

Measured 2026-10-24: an image created by a USER key loads in that user's place; a GROUP-owned one renders blank."""
import json
import time
import urllib.request
import uuid
from pathlib import Path

API = "https://apis.roblox.com/assets/v1"
TYPES = {".png": "image/png", ".jpg": "image/jpeg", ".wav": "audio/wav", ".ogg": "audio/ogg", ".mp3": "audio/mpeg",
         ".glb": "model/gltf-binary"}


def multipart(request_json, filename, content, content_type):
    b = uuid.uuid4().hex
    head = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(request_json)}\r\n"
            f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{filename}\"\r\n"
            f"Content-Type: {content_type}\r\n\r\n").encode()
    return head + content + f"\r\n--{b}--\r\n".encode(), f"multipart/form-data; boundary={b}"


def _post(url, body, headers):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers, method="POST"), timeout=120))


def _poll(url, headers):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60))


def upload_file(path, asset_type, display_name, key, user_id, post=None, poll=None, wait=2.0):
    path = Path(path)
    req = {"assetType": asset_type, "displayName": display_name[:50],
           "description": "Roblox Maps by fwjelaa (CC0 / generated)",
           "creationContext": {"creator": {"userId": str(user_id)}}}
    body, ctype = multipart(req, path.name, path.read_bytes(), TYPES.get(path.suffix.lower(), "application/octet-stream"))
    headers = {"x-api-key": key}
    op = (post or _post)(f"{API}/assets", body, {**headers, "Content-Type": ctype})
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            if "response" not in op:
                raise RuntimeError(f"upload of {path.name} failed: {op.get('error')}")
            return "rbxassetid://" + str(op["response"]["assetId"])
        time.sleep(wait)
        op = (poll or _poll)(f"{API}/operations/{op_id}", headers)
    raise TimeoutError(f"upload of {path.name} did not finish")


def upload_material(name, files, key, user_id, **injected):
    # every map uploads before anything is returned: a failure leaves no half-filled entry behind
    ids = {}
    for kind, path in files.items():
        ids[kind] = upload_file(path, "Image", f"{name} {kind}", key, user_id, **injected)
    return ids
