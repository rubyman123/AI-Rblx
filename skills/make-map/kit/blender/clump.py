"""A patch of grass/fern tufts made of alpha cards, in headless Blender. Method by fwjelaa (FWJ STUDIOS).

  blender -b --factory-startup -P kit/blender/clump.py -- --out patch.glb --leaves <dir with color/normal/roughness.png>
          [--seed 1] [--count 40] [--radius 6] [--height 2.5]

Each tuft is three crossed vertical cards (6 triangles) carrying a tuft texture (foliage.compose_tuft); a patch
spreads `count` tufts over a disc so one mesh carries many tufts (cheap to draw). The object and material are named
"Leaves" so the kit gives the imported part a see-through SurfaceAppearance. Prints `PREP {json}`."""
import json
import math
import random
import sys

import bmesh
import bpy
from mathutils import Vector


def leaves_material(folder):
    m = bpy.data.materials.new("Leaves")
    m.use_nodes = True
    m.use_backface_culling = False  # glTF doubleSided: cards are seen from both sides
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")

    def image(name, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(f"{folder}/{name}.png")
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node
    col = image("color", False)
    links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(col.outputs["Alpha"], bsdf.inputs["Alpha"])
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(image("normal", True).outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(image("roughness", True).outputs["Color"], bsdf.inputs["Roughness"])
    return m


def main(argv):
    args = dict(zip(argv[0::2], argv[1::2]))
    rng = random.Random(int(args.get("--seed", 1)))
    count, radius, height = int(args.get("--count", 40)), float(args.get("--radius", 6)), float(args.get("--height", 2.5))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for _ in range(count):
        ang, dist = rng.uniform(0, 2 * math.pi), radius * math.sqrt(rng.random())
        c = Vector((math.cos(ang) * dist, math.sin(ang) * dist, 0))
        h = height * rng.uniform(0.7, 1.2)
        w = h * rng.uniform(0.9, 1.2)
        spin = rng.uniform(0, math.pi)
        for k in range(3):
            a = spin + k * math.pi / 3
            d = Vector((math.cos(a), math.sin(a), 0)) * (w / 2)
            lean = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 1)) * h
            v = [bm.verts.new(c - d), bm.verts.new(c + d), bm.verts.new(c + d + lean), bm.verts.new(c - d + lean)]
            f = bm.faces.new(v)
            for loop, uv in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
                loop[uvl].uv = uv
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    tris = len(bm.faces)
    zs = [v.co.z for v in bm.verts]
    lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(zs)))
    hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(zs)))
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in bm.verts:
        v.co -= shift
    me = bpy.data.meshes.new("Leaves")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Leaves", me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(leaves_material(args["--leaves"]))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    out = args["--out"]
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    import struct
    data = open(out, "rb").read()
    j = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
    size = hi - lo
    print("PREP " + json.dumps({"tris": tris, "max_mesh_tris": tris, "objects": 1,
                                "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],
                                "alpha": j["materials"][0].get("alphaMode", "OPAQUE")}))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
