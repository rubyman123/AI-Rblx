"""Package the pack for sharing: python kit/tools/run.py zip [dest]. Method by fwjelaa (FWJ STUDIOS).

Ships docs, the skill, the kit (with its Luau tests and their test map), styles, the example maps and research.
Leaves out caches, the Python tests, the build plans, third-party reference text and secrets, and refuses to write
anything if a shipped file contains the user's API key."""
import json
import re
from pathlib import Path

from keyfile import PACK, all_keys

NAME = "Roblox-Maps-by-fwjelaa"
SKIP_DIRS = {"__pycache__", ".git", ".secrets", "cache"}
SKIP_SUFFIX = {".pyc", ".key", ".blend1"}
# third-party text kept for reference while building (a copy of Roblox's Studio Assistant scene-analysis skill)
NOT_SHIPPED = {"research/00-roblox-scene-analysis-skill.md"}
TEXT_SUFFIX = {".md", ".py", ".luau", ".lua", ".json", ".txt", ".html", ".toml", ".yml", ".yaml", ".cfg", ".ini"}
# Open Cloud keys are long base64 runs with a wide alphabet; URL slugs and ids use far fewer distinct characters.
LONG_RUN = re.compile(r"[A-Za-z0-9+/=_-]{100,}")


def wanted(rel):
    parts = rel.parts
    if any(p in SKIP_DIRS for p in parts):
        return False
    if parts[0] == "tests":  # the Python tests; kit/studio/tests ship because the docs tell Claude to run K.test
        return False
    if len(parts) == 1 and parts[0].startswith("PLAN-"):  # the internal build plans
        return False
    if rel.as_posix() in NOT_SHIPPED:
        return False
    if rel.name.endswith(".lock") or rel.name.endswith(".tmp"):  # an assets.json write in progress
        return False
    if parts[0] == ".claude":
        return len(parts) > 1 and parts[1] in ("skills", "settings.json")
    return rel.suffix.lower() not in SKIP_SUFFIX


def looks_like_key(text):
    return any(len(set(m.group())) > 50 for m in LONG_RUN.finditer(text))


def collect(root=PACK, keys=None):
    root = Path(root)
    files = [p for p in sorted(root.rglob("*")) if p.is_file() and wanted(p.relative_to(root))]
    keys = all_keys() if keys is None else keys
    leaks = []
    for p in files:
        data = p.read_bytes()
        if any(k.encode() in data for k in keys):
            leaks.append(f"{p} (your API key)")
        elif p.suffix.lower() in TEXT_SUFFIX and looks_like_key(data.decode("utf-8", errors="ignore")):
            leaks.append(f"{p} (something that looks like an API key)")
    if leaks:
        raise SystemExit("refusing to zip: " + ", ".join(leaks))
    return files


def without_ids(manifest_text):
    # Upload ids belong to whoever uploaded them and won't load in a viewer's place, so the shipped manifest keeps
    # the recipes (source, tint, motif, ...) and drops the ids: the viewer's first build uploads their own.
    data = json.loads(manifest_text)
    for entry in data.get("materials", {}).values():
        entry.pop("ids", None)
    for section in ("sounds", "models"):
        for entry in data.get(section, {}).values():
            entry.pop("id", None)
    for entry in data.get("skies", {}).values():
        entry.pop("ids", None)
    for entry in data.get("images", {}).values():
        entry.pop("id", None)
    return json.dumps(data, indent=2, sort_keys=True) + "\n"


def make_zip(dest=None, root=PACK):
    import zipfile

    root = Path(root)
    dest = Path(dest) if dest else Path.home() / "Desktop" / f"{NAME}.zip"
    files = collect(root)
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            rel = p.relative_to(root)
            if rel.as_posix() == "assets.json":
                z.writestr((Path(NAME) / rel).as_posix(), without_ids(p.read_text(encoding="utf-8")))
            else:
                z.write(p, Path(NAME) / rel)
    print(f"wrote {dest} ({len(files)} files, {dest.stat().st_size / 1e6:.1f} MB)")
    return dest
