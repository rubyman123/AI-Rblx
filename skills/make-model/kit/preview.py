# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Headless build + preview for one model (use kit/run.py, which finds Blender for you):

    blender -b --factory-startup --python kit/preview.py -- <ModelId> [--export]

Builds build/<ModelId>.py, renders out/preview_<ModelId>.png (front three-quarter) and
out/preview_<ModelId>_back.png, saves out/blend/<ModelId>.blend, and with --export also bakes and writes
out/<ModelId>.fbx plus its textures.

A build script may set VIEW_YAW = <degrees> to orbit both preview cameras round the model, so a side-on picture
can be matched (positive = further round to the model's right side). The model itself still faces -Y.
"""
import math
import os
import sys
import time
import traceback

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
cuh = args[0]
do_export = "--export" in args
t0 = time.time()


def orbit(cam, target, degrees):
    """Swings the camera round the vertical axis through target, still looking at it."""
    turn = Matrix.Rotation(math.radians(-degrees), 4, "Z")
    cam.location = target + (turn @ (cam.location - target))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


try:
    bpy.ops.wm.read_homefile(use_empty=True)
    path = os.path.join(ROOT, "build", f"{cuh}.py")
    script = {"__file__": path, "__name__": "__main__"}
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), script)
    view_yaw = float(script.get("VIEW_YAW", 0.0))
    import cuhkit
    cam = cuhkit.studio()
    front = cam.matrix_world.copy()
    if view_yaw:
        orbit(cam, Vector((0, 0, 2.0)), view_yaw)
    cuhkit.render(os.path.join(ROOT, "out", f"preview_{cuh}.png"))
    # back three-quarter view: players walk all the way round a model, so the back must hold up too
    target = Vector((0, 0, 2.0))
    cam.location = target + Vector((0.75, 1, 0.25)).normalized() * 4.0 * 2.25
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    if view_yaw:
        orbit(cam, target, view_yaw)
    cuhkit.render(os.path.join(ROOT, "out", f"preview_{cuh}_back.png"))
    cam.matrix_world = front
    os.makedirs(os.path.join(ROOT, "out", "blend"), exist_ok=True)
    stats = None
    if do_export:
        stats = cuhkit.export_roblox(bpy.data.collections[cuh], cuh, os.path.join(ROOT, "out"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "out", "blend", f"{cuh}.blend"))
    print(f"PREVIEW_OK {cuh} {round(time.time() - t0, 1)}s {stats or ''}")
except Exception:
    traceback.print_exc()
    print(f"PREVIEW_FAIL {cuh}")
    sys.exit(1)
