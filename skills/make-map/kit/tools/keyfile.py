"""Find the Roblox Open Cloud API key; it is never stored in the pack. Method by fwjelaa (FWJ STUDIOS).

Looked up in order: the ROBLOX_API_KEY environment variable, ~/.fwjelaa/roblox-open-cloud.key, then
.secrets/roblox-api-key.txt in the pack (never served by serve.py, never packed by make_zip.py)."""
import os
from pathlib import Path

PACK = Path(__file__).resolve().parents[2]
HOME_KEY = Path.home() / ".fwjelaa" / "roblox-open-cloud.key"
PACK_KEY = PACK / ".secrets" / "roblox-api-key.txt"


def all_keys(env=None, paths=None):
    """Every key found, in lookup order (an old key left in another source is still a key)."""
    env = os.environ if env is None else env
    keys = []
    if env.get("ROBLOX_API_KEY", "").strip():
        keys.append(env["ROBLOX_API_KEY"].strip())
    for p in (paths if paths is not None else (HOME_KEY, PACK_KEY)):
        p = Path(p)
        if p.is_file():
            text = p.read_text(encoding="utf-8").strip()
            if text:
                keys.append(text)
    return keys


def find_key(env=None, paths=None):
    keys = all_keys(env, paths)
    return keys[0] if keys else None
