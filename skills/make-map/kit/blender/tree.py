"""A procedural dead tree for Roblox, in headless Blender. Method by fwjelaa (FWJ STUDIOS).

  blender -b --factory-startup -P kit/blender/tree.py -- --out tree.glb --bark <dir with color/normal/roughness.png>
          [--seed 1] [--height 40] [--tris 16000] [--tile 7]

Grows a gnarled, leafless tree from tapered tubes (trunk, three branch levels, twigs, root flare along the ground),
UV-maps the bark so it tiles every --tile studs, scales it to exactly --height studs, lowers the detail until it fits
--tris, puts the bottom-centre at the origin and exports a GLB (1 unit = 1 stud). Prints `PREP {json}`."""
import json
import math
import random
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector

# per level: sides, segment length (fraction of the branch), children, child length (fraction of parent),
# start radius (fraction of parent radius), gnarl
LEVELS = [
    {"sides": 16, "segs": 12, "kids": 4, "len": 0.95, "rad": 0.72, "gnarl": 0.16, "taper": 0.45, "from": 0.5},
    {"sides": 10, "segs": 11, "kids": 4, "len": 0.55, "rad": 0.55, "gnarl": 0.3, "taper": 0.8, "from": 0.3},
    {"sides": 7, "segs": 7, "kids": 3, "len": 0.5, "rad": 0.5, "gnarl": 0.42, "taper": 0.8, "from": 0.3},
    {"sides": 5, "segs": 5, "kids": 2, "len": 0.45, "rad": 0.5, "gnarl": 0.5, "taper": 0.85, "from": 0.35},
    {"sides": 3, "segs": 3, "kids": 0, "len": 0.0, "rad": 0.0, "gnarl": 0.55, "taper": 0.9, "from": 0.0},
]


def grow(rng, start, direction, length, radius, level, detail, out):
    spec = LEVELS[level]
    segs = max(2, round(spec["segs"] * detail))
    pts, rad = [start], [radius]
    d = direction.normalized()
    for i in range(1, segs + 1):
        wobble = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.35, 0.6)))
        d = (d + wobble * spec["gnarl"]).normalized()
        if level == 0:
            d = (d + Vector((0, 0, 0.9))).normalized()  # the trunk stays mostly upright
        pts.append(pts[-1] + d * (length / segs))
        rad.append(radius * (1 - spec["taper"] * i / segs))
    # the trunk is a broken-off snag: cap its top so the cut end isn't hollow
    out.append((pts, rad, max(3, round(spec["sides"] * min(1.0, detail + 0.2))), level == 0))
    if spec["kids"] == 0:
        return
    for _ in range(spec["kids"]):
        i = rng.randint(max(1, int(segs * spec["from"])), segs - 1)
        along = (pts[i + 1] - pts[i]).normalized()
        side = along.orthogonal().normalized()
        side = Quaternion(along, rng.uniform(0, 2 * math.pi)) @ side
        tilt = math.radians(rng.uniform(30, 70))
        cdir = (along * math.cos(tilt) + side * math.sin(tilt)).normalized()
        grow(rng, pts[i], cdir, length * LEVELS[level]["len"] * rng.uniform(0.75, 1.15),
             rad[i] * LEVELS[level]["rad"], level + 1, detail, out)


def roots(rng, radius, height, out):
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
        reach = height * rng.uniform(0.06, 0.1)
        pts = [Vector((0, 0, height * 0.05)), Vector((math.cos(a) * reach * 0.5, math.sin(a) * reach * 0.5, height * 0.015)),
               Vector((math.cos(a) * reach, math.sin(a) * reach, 0.0))]
        out.append((pts, [radius * 0.55, radius * 0.3, 0.02], 6, False))  # tips taper to a point at the ground


def tube(bm, uvl, pts, rad, sides, tile, cap=False):
    rings, length, n, prev_t = [], 0.0, None, None
    for i, p in enumerate(pts):
        t = (pts[i + 1] - p).normalized() if i < len(pts) - 1 else (p - pts[i - 1]).normalized()
        if n is None:
            n = t.orthogonal().normalized()
        else:
            length += (p - pts[i - 1]).length
            axis = prev_t.cross(t)
            if axis.length > 1e-6:
                n = Quaternion(axis.normalized(), prev_t.angle(t)) @ n
        b = t.cross(n)
        rings.append(([bm.verts.new(p + (n * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * max(rad[i], 0.02))
                       for k in range(sides)], length))
        prev_t = t
    urep = max(1, round(2 * math.pi * max(rad[0], 0.2) / tile))
    for i in range(len(rings) - 1):
        (r0, l0), (r1, l1) = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((r0[k], r0[k2], r1[k2], r1[k]))
            u0, u1 = k / sides * urep, (k + 1) / sides * urep
            for loop, uv in zip(f.loops, [(u0, l0 / tile), (u1, l0 / tile), (u1, l1 / tile), (u0, l1 / tile)]):
                loop[uvl].uv = uv
    if cap:
        f = bm.faces.new(rings[-1][0])
        for loop in f.loops:
            loop[uvl].uv = (loop.vert.co.x / tile, loop.vert.co.y / tile)


def bark_material(folder):
    m = bpy.data.materials.new("Bark")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")

    def image(name, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(f"{folder}/{name}.png")
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node
    links.new(image("color", False).outputs["Color"], bsdf.inputs["Base Color"])
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(image("normal", True).outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(image("roughness", True).outputs["Color"], bsdf.inputs["Roughness"])
    return m


def build(seed, height, detail, tile):
    rng = random.Random(seed)
    out = []
    radius = height * 0.05
    grow(rng, Vector((0, 0, 0)), Vector((0, 0, 1)), height * 0.42, radius, 0, detail, out)
    roots(rng, radius, height, out)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for pts, rad, sides, cap in out:
        tube(bm, uvl, pts, rad, sides, tile, cap)
    return bm


def main(argv):
    args = dict(zip(argv[0::2], argv[1::2]))
    seed, height = int(args.get("--seed", 1)), float(args.get("--height", 40))
    target, tile = int(args.get("--tris", 16000)), float(args.get("--tile", 7))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    detail = 1.0
    while True:
        bm = build(seed, height, detail, tile)
        tris = sum(len(f.verts) - 2 for f in bm.faces)
        if tris <= min(target, 19500) or detail < 0.2:
            break
        bm.free()
        detail *= 0.85
    # exact height, then bottom-centre to the origin (roots lie on the ground at z = 0)
    zs = [v.co.z for v in bm.verts]
    s = height / (max(zs) - min(zs))
    for v in bm.verts:
        v.co *= s
    lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in bm.verts:
        v.co -= shift
    me = bpy.data.meshes.new("Tree")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Tree", me)
    bpy.context.scene.collection.objects.link(obj)
    if args.get("--bark"):
        me.materials.append(bark_material(args["--bark"]))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=args["--out"], export_format="GLB", use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    size = hi - lo
    print("PREP " + json.dumps({"tris": tris, "max_mesh_tris": tris, "objects": 1, "detail": round(detail, 3),
                                "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],  # already scaled
                                "base": [round(-shift.x, 3), round(-shift.y, 3), round(-shift.z, 3)]}))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
