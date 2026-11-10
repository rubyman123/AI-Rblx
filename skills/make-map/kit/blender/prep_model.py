"""Prep a CC0 model for Roblox in headless Blender. Method by fwjelaa (FWJ STUDIOS).

  blender -b --factory-startup -P kit/blender/prep_model.py -- --in model.gltf --out model.glb --tris 18000

Imports the glTF, scales metres to studs, decimates so the whole model stays under --tris (and every mesh under
19,500, Roblox's limit is 20,000), moves the group's bottom-centre to the origin, and exports a GLB. Prints one
line `PREP {json}` with the result (size in studs, Roblox axes: x, up, depth)."""
import json
import sys

import bmesh
import bpy
import mathutils

MESH_LIMIT = 19500


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def main(argv):
    args = dict(zip(argv[0::2], argv[1::2]))
    src, out = args["--in"], args["--out"]
    target, scale = int(args.get("--tris", 18000)), float(args.get("--scale", 1 / 0.28))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit(f"no meshes in {src}")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    # bake the importer's transforms (and any parents) into the meshes, then scale metres → studs
    for o in bpy.context.scene.objects:
        if o.parent:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
    for o in meshes:
        o.matrix_world = mathutils.Matrix.Scale(scale, 4) @ o.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.ops.object.make_single_user(object=True, obdata=True)  # shared meshes can't take transform_apply
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    # one shared ratio for every mesh, but no mesh drops below a floor (tiny parts like knobs, handles and lamp
    # glass break when collapsed, so they stay whole); the floor shrinks when a model is all small pieces, and the
    # ratio is searched so the total lands on the target
    before = {o.name: tri_count(o) for o in meshes}
    total = sum(before.values())
    keep = min(200.0, 0.5 * target / len(meshes))

    def after(r):
        return sum(max(r * n, min(n, keep)) for n in before.values())
    shared = 1.0
    if total > target:
        lo_r, hi_r = 0.0, 1.0
        for _ in range(40):
            mid = (lo_r + hi_r) / 2
            lo_r, hi_r = (mid, hi_r) if after(mid) <= target else (lo_r, mid)
        shared = max(lo_r, 0.01)
    for o in meshes:
        n = before[o.name]
        ratio = max(shared, min(1.0, keep / n)) if n > 0 else 1.0
        if tri_count(o) * ratio > MESH_LIMIT:
            ratio = MESH_LIMIT / tri_count(o)
        if ratio < 0.999:
            # scans arrive with their vertices doubled along every UV seam (glTF stores one UV per vertex), and
            # collapse stalls on those open edges (boulder_01 stopped at 3x its target); welding them keeps the
            # UVs (Blender stores those per corner) and lets collapse reach the target
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            bm.to_mesh(o.data)
            bm.free()
            ratio = min(1.0, n * ratio / max(1, tri_count(o)))
            bpy.context.view_layer.objects.active = o
            m = o.modifiers.new("decimate", "DECIMATE")
            m.ratio = ratio
            m.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=m.name)
    # ground the group: bottom-centre of the combined bounds to the origin
    pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = mathutils.Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in meshes:
        o.data.transform(mathutils.Matrix.Translation(o.matrix_world.inverted().to_3x3() @ -shift))
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    counts = [tri_count(o) for o in meshes]
    size = hi - lo
    print("PREP " + json.dumps({"tris": sum(counts), "max_mesh_tris": max(counts), "objects": len(meshes),
                                "meshes": [[o.name, before[o.name], tri_count(o)] for o in meshes],
                                "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)]}))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
