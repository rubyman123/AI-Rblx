"""Living trees for Roblox: bark from tree.py plus alpha leaf cards, in headless Blender. Method by fwjelaa (FWJ STUDIOS).

  blender -b --factory-startup -P kit/blender/leafy_tree.py -- --out t.glb --bark <dir> --leaves <dir>
          [--kind broadleaf|pine] [--seed 1] [--height 40] [--tris 16000] [--tile 7]

broadleaf: a trunk splitting into spreading limbs (tree.py's grower with crown settings) and leaf-cluster cards
(foliage.compose_cluster) round every twig. pine: a straight trunk with whorls of drooping branches and needle
cards (foliage.compose_needles) laid along them. Two objects, "Tree" (bark) and "Leaves" (cards, see-through in
Roblox via K.Models), so the trunk keeps its own normal map. Prints `PREP {json}`."""
import json
import math
import os
import random
import struct
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clump  # noqa: E402
import tree  # noqa: E402

BROADLEAF = [
    {"sides": 12, "segs": 10, "kids": 5, "len": 0.75, "rad": 0.62, "gnarl": 0.1, "taper": 0.55, "from": 0.45},
    {"sides": 8, "segs": 8, "kids": 4, "len": 0.6, "rad": 0.55, "gnarl": 0.22, "taper": 0.75, "from": 0.3},
    {"sides": 5, "segs": 5, "kids": 3, "len": 0.5, "rad": 0.5, "gnarl": 0.3, "taper": 0.8, "from": 0.3},
    {"sides": 3, "segs": 3, "kids": 0, "len": 0.0, "rad": 0.0, "gnarl": 0.35, "taper": 0.9, "from": 0.0},
]


def card(bm, uvl, centre, normal, up, size):
    side = normal.cross(up)
    if side.length < 1e-4:
        side = normal.orthogonal()
    side.normalize()
    top = side.cross(normal).normalized()
    h = size / 2
    v = [bm.verts.new(centre + (-side - top) * h), bm.verts.new(centre + (side - top) * h),
         bm.verts.new(centre + (side + top) * h), bm.verts.new(centre + (-side + top) * h)]
    f = bm.faces.new(v)
    for loop, uv in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop[uvl].uv = uv


def broadleaf(rng, height, detail):
    tree.LEVELS = BROADLEAF
    out = []
    radius = height * 0.035
    tree.grow(rng, Vector((0, 0, 0)), Vector((0, 0, 1)), height * 0.5, radius, 0, detail, out)
    tree.roots(rng, radius, height, out)
    leaves = []
    for pts, rad, sides, _cap in out:
        if rad[0] < radius * 0.2 and pts[-1].z > height * 0.25:  # the twigs: cards along their outer part
            for i in range(len(pts) // 3, len(pts)):
                for _ in range(2):
                    jitter = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 1))) * height * 0.04
                    leaves.append(pts[i] + jitter)
    return out, leaves


def pine(rng, height, detail):
    out = []
    radius = height * 0.028
    trunk = [Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), height * i / 12)) for i in range(13)]
    out.append((trunk, [radius * (1 - 0.92 * i / 12) for i in range(13)], max(5, round(10 * detail)), False))
    tree.roots(rng, radius, height, out)
    sprays = []  # (start, direction, length)
    whorls = max(10, round(20 * detail))
    for w in range(whorls):
        z = height * (0.2 + 0.75 * w / whorls)
        length = height * (0.06 + 0.3 * (1 - (z / height)) ** 1.1)
        n = rng.randint(4, 6)
        spin = rng.uniform(0, 2 * math.pi)
        for k in range(n):
            a = spin + 2 * math.pi * k / n + rng.uniform(-0.2, 0.2)
            d = Vector((math.cos(a), math.sin(a), -rng.uniform(0.05, 0.3))).normalized()
            start = Vector((0, 0, z))
            pts = [start + d * length * t + Vector((0, 0, -length * 0.15 * t * t)) for t in (0, 0.5, 1)]
            r0 = radius * 0.25 * (1 - z / height) + 0.05
            out.append((pts, [r0, r0 * 0.6, 0.03], 4, False))
            sprays.append((start, d, length))
    return out, sprays


def main(argv):
    args = dict(zip(argv[0::2], argv[1::2]))
    kind, seed = args.get("--kind", "broadleaf"), int(args.get("--seed", 1))
    height, target = float(args.get("--height", 40)), int(args.get("--tris", 16000))
    tile = float(args.get("--tile", 7))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    detail = 1.0
    while True:
        rng = random.Random(seed)
        out, crown = (broadleaf if kind == "broadleaf" else pine)(rng, height, detail)
        bark = bmesh.new()
        buv = bark.loops.layers.uv.new("UVMap")
        for pts, rad, sides, cap in out:
            tree.tube(bark, buv, pts, rad, sides, tile, cap)
        cards = bmesh.new()
        cuv = cards.loops.layers.uv.new("UVMap")
        count = 0
        if kind == "broadleaf":
            for p in crown:
                outward = Vector((p.x, p.y, 0))
                outward = outward.normalized() if outward.length > 1e-3 else Vector((1, 0, 0))
                nrm = (outward + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 1.2)))).normalized()
                card(cards, cuv, p, nrm, Vector((0, 0, 1)), height * rng.uniform(0.11, 0.16))
                count += 1
        else:
            for start, d, length in crown:
                # crossed cards along each branch (one lying flat, one standing) give the spray volume
                for t in (0.25, 0.5, 0.75, 0.95):
                    c = start + d * length * t + Vector((0, 0, -length * 0.15 * t * t))
                    flat = Quaternion(d, rng.uniform(-0.4, 0.4)) @ Vector((0, 0, 1))
                    card(cards, cuv, c, flat, d, length * 0.75)
                    stand = Quaternion(d, math.pi / 2 + rng.uniform(-0.3, 0.3)) @ Vector((0, 0, 1))
                    card(cards, cuv, c, stand, d, length * 0.6)
                    count += 2
            top = Vector((0, 0, height * 0.97))
            for k in range(3):
                a = k * math.pi / 3
                card(cards, cuv, top - Vector((0, 0, height * 0.05)), Vector((math.cos(a), math.sin(a), 0)), Vector((0, 0, 1)), height * 0.12)
                count += 1
        tris = sum(len(f.verts) - 2 for f in bark.faces) + count * 2
        if tris <= min(target, 19500) or detail < 0.3:
            break
        bark.free()
        cards.free()
        detail *= 0.85
    # exact height, bottom-centre at the origin (both objects moved together)
    zs = [v.co.z for v in bark.verts] + [v.co.z for v in cards.verts]
    s = height / (max(zs) - min(zs))
    for bm in (bark, cards):
        for v in bm.verts:
            v.co *= s
    allv = list(bark.verts) + list(cards.verts)
    lo = Vector((min(v.co.x for v in allv), min(v.co.y for v in allv), min(v.co.z for v in allv)))
    hi = Vector((max(v.co.x for v in allv), max(v.co.y for v in allv), max(v.co.z for v in allv)))
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    objs = []
    for name, bm, mat in (("Tree", bark, tree.bark_material(args["--bark"])), ("Leaves", cards, clump.leaves_material(args["--leaves"]))):
        for v in bm.verts:
            v.co -= shift
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        if name == "Tree":
            for p in me.polygons:
                p.use_smooth = True
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        me.materials.append(mat)
        objs.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = args["--out"]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    data = open(path, "rb").read()
    j = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
    alpha = next((m.get("alphaMode") for m in j["materials"] if m.get("name") == "Leaves"), "OPAQUE")
    counts = [sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs]
    size = hi - lo
    print("PREP " + json.dumps({"tris": sum(counts), "max_mesh_tris": max(counts), "objects": 2, "cards": count,
                                "detail": round(detail, 3), "alpha": alpha,
                                "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)]}))  # already scaled


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
