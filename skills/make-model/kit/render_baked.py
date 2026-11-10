# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Renders the baked game mesh (what Roblox gets) for one or more models, from their saved out/blend files.

    blender -b --factory-startup --python kit/render_baked.py -- <CuhId> [CuhId ...]
    -> out/baked_<CuhId>.png
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

for cuh in sys.argv[sys.argv.index("--") + 1:]:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "out", "blend", f"{cuh}.blend"))
    import cuhkit
    low = bpy.data.objects.get(cuh)
    if not low:
        print(f"BAKED_FAIL {cuh}: no baked object (export first)")
        continue
    for o in bpy.context.scene.objects:
        if o.type in ("MESH", "CURVE", "META"):
            o.hide_render = o is not low
    low.location = (0, 0, 0)
    cuhkit.studio()
    cuhkit.render(os.path.join(ROOT, "out", f"baked_{cuh}.png"))
    print(f"BAKED_OK {cuh}")
