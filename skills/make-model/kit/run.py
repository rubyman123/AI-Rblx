# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""One command for everything. It finds Blender by itself.

    python kit/run.py check               check the setup (Blender, Pillow)
    python kit/run.py build  <ModelId>    build build/<ModelId>.py, render front + back, make out/compare_<ModelId>.png
    python kit/run.py export <ModelId>    the same, then bake the Roblox mesh: out/<ModelId>.fbx + its textures
    python kit/run.py baked  <ModelId>    render the baked Roblox mesh: out/baked_<ModelId>.png (after export)
    python kit/run.py ref <picture> <ModelId>   copy a picture (PNG/JPG/WEBP) into ref/<ModelId>.png
    python kit/run.py measure <ModelId>   compare the picture's and the render's proportions, band by band

Blender is found from the BLENDER environment variable, the PATH, or the usual install folders (Windows, Steam,
macOS, Linux); the newest version wins.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "kit"
MIN_VERSION = (4, 2)


def find_blender():
    env = os.environ.get("BLENDER")
    if env and Path(env).exists():
        return env
    found = shutil.which("blender")
    if found:
        return found
    candidates = []
    if os.name == "nt":
        bases = [os.environ.get("ProgramFiles", r"C:\Program Files"), os.environ.get("ProgramFiles(x86)", ""),
                 os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs")]
        for base in filter(None, bases):
            candidates += glob.glob(os.path.join(base, "Blender Foundation", "Blender*", "blender.exe"))
            candidates += glob.glob(os.path.join(base, "Steam", "steamapps", "common", "Blender", "blender.exe"))
    elif sys.platform == "darwin":
        candidates += glob.glob("/Applications/Blender*.app/Contents/MacOS/Blender")
        candidates += glob.glob(os.path.expanduser("~/Applications/Blender*.app/Contents/MacOS/Blender"))
    else:
        candidates += ["/snap/bin/blender", "/usr/bin/blender", "/usr/local/bin/blender"]
        candidates += glob.glob(os.path.expanduser("~/blender*/blender"))
    candidates = [c for c in candidates if os.path.exists(c)]

    def version(path):
        nums = re.findall(r"(\d+)\.(\d+)", path)
        return tuple(int(n) for n in nums[-1]) if nums else (0, 0)
    return max(candidates, key=version) if candidates else None


def blender_or_exit():
    blender = find_blender()
    if not blender:
        sys.exit("Blender not found. Install it from blender.org (4.2 or newer), or set the BLENDER environment "
                 "variable to blender.exe / the Blender app.")
    return blender


def run_blender(script, args):
    blender = blender_or_exit()
    proc = subprocess.run([blender, "-b", "--factory-startup", "--python", str(KIT / script), "--", *args],
                          cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = (proc.stdout + proc.stderr).splitlines()
    ok = [ln for ln in lines if ln.startswith(("PREVIEW_OK", "BAKED_OK"))]
    if ok and proc.returncode == 0:
        for ln in ok:
            print(ln)
        return True
    print("\n".join(lines[-40:]))  # the traceback says what to fix in the build script
    print(f"FAILED ({script} {' '.join(args)})")
    return False


def compare(model_id):
    proc = subprocess.run([sys.executable, "-I", str(KIT / "compare.py"), model_id], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode != 0:
        if "PIL" in proc.stderr:
            sys.exit("Pillow is missing: run  pip install pillow")
        sys.exit(proc.stderr[-800:])
    print("compare:", proc.stdout.strip())


def check():
    good = True
    blender = find_blender()
    if not blender:
        print("Blender: NOT FOUND. Install it from blender.org (4.2 or newer) or set BLENDER.")
        good = False
    else:
        out = subprocess.run([blender, "-b", "--factory-startup", "--version"], capture_output=True, text=True,
                             encoding="utf-8", errors="replace").stdout
        m = re.search(r"Blender (\d+)\.(\d+)(\.\d+)?", out)
        ver = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
        note = "" if ver >= MIN_VERSION else "  <- too old, install 4.2 or newer"
        print(f"Blender: {m.group(0) if m else 'unknown version'} at {blender}{note}")
        good = good and ver >= MIN_VERSION
    try:
        import PIL  # noqa: F401
        print("Pillow: ok")
    except ImportError:
        print("Pillow: missing, run  pip install pillow")
        good = False
    key = (ROOT / ".secrets" / "roblox-api-key.txt").exists() or bool(os.environ.get("ROBLOX_API_KEY"))
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    owner = config.get("group_id") or config.get("user_id")
    print(f"Roblox auto-upload: {'ready' if key and owner else 'not set up (optional, see Automatic upload in GUIDE.html)'}")
    print("READY" if good else "NOT READY")
    return good


def save_ref(picture, model_id):
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow is missing: run  python -m pip install pillow")
    src = Path(picture).expanduser()
    if not src.exists():
        sys.exit(f"Picture not found: {src}")
    dst = ROOT / "ref" / f"{model_id}.png"
    dst.parent.mkdir(exist_ok=True)
    im = Image.open(src).convert("RGBA")
    im.save(dst)
    print(f"saved ref/{model_id}.png ({im.width} x {im.height})")


def main(argv):
    commands = ("check", "build", "export", "baked", "ref", "measure")
    if not argv or argv[0] not in commands or (argv[0] != "check" and len(argv) < 2) or (argv[0] == "ref" and len(argv) < 3):
        sys.exit(__doc__)
    cmd = argv[0]
    if cmd == "check":
        sys.exit(0 if check() else 1)
    if cmd == "ref":
        save_ref(argv[1], argv[2])
        return
    if cmd == "measure":
        sys.exit(subprocess.run([sys.executable, "-I", str(KIT / "measure.py"), argv[1]], cwd=ROOT).returncode)
    model_id = argv[1]
    if cmd == "baked":
        sys.exit(0 if run_blender("render_baked.py", [model_id]) else 1)
    if not (ROOT / "build" / f"{model_id}.py").exists():
        sys.exit(f"No build script: build/{model_id}.py")
    if not run_blender("preview.py", [model_id] + (["--export"] if cmd == "export" else [])):
        sys.exit(1)
    compare(model_id)
    if cmd == "export":
        info = json.loads((ROOT / "out" / f"{model_id}_export.json").read_text(encoding="utf-8"))
        x, y, z = info["size"]
        print(f"ROBLOX READY: out/{model_id}.fbx  ({info['low_tris']:,} triangles; {x:.1f} wide x {z:.1f} tall x {y:.1f} deep, in studs)"
              f" + out/{model_id}_Color.png, _Normal.png, _Rough.png")


if __name__ == "__main__":
    main(sys.argv[1:])
