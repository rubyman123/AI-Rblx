"""Shadow Wolf: a sleek blue-black wolf pup with a big round head, a very short muzzle, huge leaf-shaped ears
glowing cyan inside, huge fierce glowing cyan almond eyes, a mane of long shards sweeping back along the neck, a
grey-blue chest ruff of big leaf shards, slim legs on big four-toed paws and a huge fan of flame-shaped tail lobes
with grey-blue undersides.

Every position here was measured off a grid on the reference picture (4.0 studs tall to the ear tips)."""
import importlib
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

KIT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "kit")
if KIT not in sys.path:
    sys.path.insert(0, KIT)
import cuhkit as k  # noqa: E402

importlib.reload(k)

CUH = "ShadowWolf"
VIEW_YAW = 28  # the picture is seen from the front right

FUR, GREY, NOSE = "#1f222c", "#4a5872", "#0b0c10"
CYAN, CYAN_CORE, GLOW_EDGE = "#5fe6fb", "#b8fbff", "#2a78d8"

HEAD = Vector((0, -0.90, 2.42))   # head centre (before the turn)
HEAD_PIVOT = Vector((0, -0.77, 1.97))
HEAD_TURN = (10, 0, -4)            # nods down and faces forward, so the ruff sits under the throat, not the mouth
HEAD_SIZE = 1.28
EAR_HALF_W, EAR_THICK = 0.5, 0.13
GREY_LIGHT = "#5d6b88"

# Legs: joints from the shoulder or hip down to the ankle, radii, paw (x, y). A compact body: the right hind leg
# reaches back a little and the left front paw steps forward, like the picture.
LEGS = {  # muscular at the top, tapering to the wrist
    "FR": ([(-0.27, -0.52, 1.35), (-0.33, -0.60, 0.85), (-0.36, -0.72, 0.32), (-0.37, -0.76, 0.16)],
           [0.25, 0.2, 0.17, 0.16], (-0.37, -0.78)),
    "FL": ([(0.27, -0.52, 1.35), (0.33, -0.68, 0.85), (0.36, -0.95, 0.32), (0.37, -1.00, 0.16)],
           [0.25, 0.2, 0.17, 0.16], (0.37, -1.03)),
    "HR": ([(-0.27, 0.70, 1.35), (-0.33, 0.78, 0.85), (-0.36, 1.10, 0.42), (-0.37, 1.06, 0.16)],
           [0.29, 0.21, 0.18, 0.16], (-0.37, 1.04)),
    "HL": ([(0.27, 0.70, 1.35), (0.33, 0.45, 0.85), (0.36, 0.50, 0.40), (0.37, 0.38, 0.16)],
           [0.29, 0.21, 0.18, 0.16], (0.37, 0.35)),
}
TOE_LINE = "#0e0f14"

TAIL_BASE = Vector((-0.05, 1.00, 1.75))   # inside the hips, so the lobes grow straight out of the rump
TAIL_DIR = Vector((-0.25, 0.97, 0)).normalized()
# A huge tail, almost as big as the body: wide flame lobes that overlap into one fluffy fan, arcing like the
# picture's (tip, control, half width, colour). Grey lobes sit underneath the black ones.
TAIL_LOBES = [
    ((-0.35, 2.45, 3.10), (0.15, 1.55, 3.05), 0.68, "fur"),
    ((-0.72, 2.95, 2.40), (-0.15, 1.90, 2.55), 0.62, "grey"),
    ((-0.62, 2.70, 1.95), (-0.15, 1.85, 2.15), 0.58, "fur"),
    ((-0.66, 2.65, 1.25), (-0.15, 1.95, 1.35), 0.6, "grey"),
]

# Chest ruff outline, traced from the picture: (across, down) from the middle of the throat. A shield wider than
# the chin, with a short left point, a long middle point and a right point.
RUFF_TOP = Vector((0, -1.16, 1.92))
RUFF_SCALE = 1.2
RUFF_OUTLINE = [(-0.60, 0.0), (-0.14, 0.06), (0.20, 0.06), (0.62, 0.0), (0.70, -0.35), (0.64, -0.68), (0.40, -0.48),
                (0.14, -1.0), (-0.02, -0.58), (-0.28, -0.78), (-0.40, -0.50), (-0.62, -0.58), (-0.66, -0.22)]


def flame_profile(t):
    """Narrow at the root, widest about a third along, then a long sharp point (peaks at 1)."""
    return (1 - t) ** 1.3 * (0.45 + 2.2 * t) / 0.7


def tail_profile(t):
    """Like flame_profile but with a longer, sharper flame tip."""
    return (1 - t) ** 1.7 * (0.45 + 2.8 * t) / 0.78


def leaf_ear_profile(t):
    """Wide base with gently bulging sides, tapering to a sharp tip."""
    return (1 - t) ** 0.75


def matte(m, spec=0.15):
    """Less white specular, so the black fur stays black instead of turning grey."""
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Specular IOR Level"].default_value = spec
    return m


def cone(bm, base, tip, r_a, r_b, axis_a=(1, 0, 0), ctrl=None, rings=7, segs=12, power=1.0, profile=None):
    """Adds a pointed cone along the curve base -> ctrl -> tip. The cross-section is an ellipse: r_a across axis_a,
    r_b the other way, so a small r_a makes a thin blade (fur shards, ears, tail lobes). profile(t) overrides the
    straight taper (1 - t) ** power."""
    base, tip = Vector(base), Vector(tip)
    ctrl = (base + tip) / 2 if ctrl is None else Vector(ctrl)
    axis = Vector(axis_a)
    loops = []
    for i in range(rings):
        t = i / rings
        c = (1 - t) ** 2 * base + 2 * (1 - t) * t * ctrl + t * t * tip
        tg = (2 * (1 - t) * (ctrl - base) + 2 * t * (tip - ctrl)).normalized()
        a = axis - tg * axis.dot(tg)
        a = a.normalized() if a.length > 1e-6 else tg.orthogonal().normalized()
        b = tg.cross(a)
        f = profile(t) if profile else (1 - t) ** power
        loops.append([bm.verts.new(c + a * (r_a * f * math.cos(2 * math.pi * j / segs))
                                   + b * (r_b * f * math.sin(2 * math.pi * j / segs))) for j in range(segs)])
    end = bm.verts.new(tip)
    for i in range(rings - 1):
        for j in range(segs):
            jn = (j + 1) % segs
            bm.faces.new((loops[i][j], loops[i][jn], loops[i + 1][jn], loops[i + 1][j]))
    for j in range(segs):
        bm.faces.new((loops[-1][j], loops[-1][(j + 1) % segs], end))
    bm.faces.new(list(reversed(loops[0])))


def limb(points, radii):
    """Blob elements for a smooth tapered limb through points: a dense chain of balls. Packed this tight (spacing
    0.35 r) their fields add up and the surface grows to about r / 0.805, so each ball is made that much smaller.
    Unlike capsules, the joints don't swell into knobs."""
    els = []
    for i in range(len(points) - 1):
        a, b = Vector(points[i]), Vector(points[i + 1])
        length = (b - a).length
        t = 0.0
        while t < 1.0:
            r = radii[i] + (radii[i + 1] - radii[i]) * t
            els.append(dict(type="BALL", co=tuple(a.lerp(b, t)), r=0.805 * r))
            t += 0.35 * r / max(length, 1e-6)
    els.append(dict(type="BALL", co=tuple(points[-1]), r=0.805 * radii[-1]))
    return els


def mesh_from(name, coll, fill, material):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    fill(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    k.set_mats(obj, material)
    return k.smooth(obj)


def lens(c, center, n, s, half_w, half_h, tilt):
    """Signed distance (> 0 inside) of an almond eye drawn on a surface: two overlapping circles in the plane facing
    n, tilted so the corner nearest the nose sits lower (a fierce look)."""
    u = Vector((0, 0, 1)).cross(n).normalized() * (-s)   # along the face, towards the nose
    v = n.cross(u).normalized() * (-s)                   # up
    d = c - center
    if d.dot(n) < -0.15:
        return -1.0
    a, b = d.dot(u), d.dot(v)
    ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
    a, b = a * ca - b * sa, a * sa + b * ca
    off = (half_w ** 2 - half_h ** 2) / (2 * half_h)
    r = half_h + off
    return min(r - math.hypot(a, b - off), r - math.hypot(a, b + off))


def build_head(coll, fur, grey):
    h = HEAD
    # A big round head with a very short muzzle pointing down and forward.
    els = [
        dict(co=tuple(h), size=(0.50, 0.46, 0.46)),                                     # skull
        dict(co=tuple(h + Vector((0, -0.18, 0.10))), size=(0.40, 0.32, 0.30)),           # forehead
        dict(co=tuple(h + Vector((0, -0.42, -0.20))), size=(0.20, 0.24, 0.15), rot=(18, 0, 0)),  # muzzle
        dict(co=tuple(h + Vector((0, -0.58, -0.28))), size=(0.11, 0.10, 0.09)),          # muzzle tip
        dict(co=tuple(h + Vector((0, -0.34, -0.36))), size=(0.16, 0.20, 0.10)),          # chin
    ]
    for s in (-1, 1):
        els.append(dict(co=tuple(h + Vector((s * 0.30, -0.12, -0.18))), size=(0.24, 0.28, 0.24)))  # cheeks
    head = k.blob(f"{CUH}_Head", coll, els, resolution=0.022)

    # Leaf-shaped ears fused into the head: the ear blades are merged with the skull by a voxel remesh, then the
    # seam is smoothed into a fillet so they grow out of the head instead of sitting on it.
    ear_frames = []
    for s in (-1, 1):
        base, tip = h + Vector((s * 0.27, 0.06, 0.24)), h + Vector((s * 0.50, 0.14, 1.05))
        ear_frames.append((s, base, tip, (base + tip) / 2 + Vector((s * 0.08, 0, 0))))

    def ears(bm):
        for s, base, tip, ctrl in ear_frames:
            cone(bm, base, tip, EAR_THICK, EAR_HALF_W, axis_a=(0, 1, 0), ctrl=ctrl, rings=12, segs=16,
                 profile=leaf_ear_profile)
    ear_mesh = mesh_from(f"{CUH}_EarTmp", coll, ears, fur)
    bm = bmesh.new()
    bm.from_mesh(head.data)
    bm.from_mesh(ear_mesh.data)
    bm.to_mesh(head.data)
    bm.free()
    bpy.data.objects.remove(ear_mesh, do_unlink=True)
    remesh = head.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.012
    k.apply_modifiers(head)

    skull = (0.5, 0.46, 0.46)
    joints = []
    for s, base, tip, ctrl in ear_frames:
        p = base
        for i in range(100):  # walk up the ear until it leaves the skull: that's where the seam is
            p = base.lerp(tip, i / 100)
            d = p - h
            if (d.x / skull[0]) ** 2 + (d.y / skull[1]) ** 2 + (d.z / skull[2]) ** 2 > 1:
                break
        joints.append(p)
    group = head.vertex_groups.new(name="fillet")
    for v in head.data.vertices:
        w = max(max(0.0, 1 - (v.co - j).length / 0.32) for j in joints)
        if w > 0:
            group.add([v.index], w, "REPLACE")
    fillet = head.modifiers.new("Fillet", "SMOOTH")
    fillet.factor = 0.9
    fillet.iterations = 14
    fillet.vertex_group = "fillet"
    k.apply_modifiers(head)

    # Cup the ears: press the inside of each ear back so it has depth instead of being a flat panel.
    for v in head.data.vertices:
        for s, base, tip, ctrl in ear_frames:
            e = (tip - base).normalized()
            front = (Vector((0, -1, 0)) - e * Vector((0, -1, 0)).dot(e)).normalized()
            across = e.cross(front)
            d = v.co - base
            a = d.dot(e) / (tip - base).length
            if not 0.15 < a < 0.95 or d.dot(front) < 0:
                continue
            half = EAR_HALF_W * leaf_ear_profile(a)
            x = abs(d.dot(across)) / max(half, 1e-6)
            if x < 1:
                # never deeper than half the ear's thickness there, or the thin tip would push through the back
                cup = min(0.07, 0.5 * EAR_THICK * leaf_ear_profile(a))
                v.co -= front * (cup * (1 - x * x) * math.sin(math.pi * min(1.0, (a - 0.15) / 0.8)))
    head.data.update()
    k.smooth(head)

    def inner_ear(c):
        # cyan on the front face of each ear, inside a black rim
        best = -1.0
        for s, base, tip, ctrl in ear_frames:
            e = (tip - base).normalized()
            front = Vector((0, -1, 0)) - e * Vector((0, -1, 0)).dot(e)
            front.normalize()
            across_axis = e.cross(front)
            d = c - base
            a = d.dot(e) / (tip - base).length
            if not 0.0 <= a <= 1.0:
                continue
            half = 0.72 * EAR_HALF_W * leaf_ear_profile(a) - 0.02
            depth = d.dot(front)
            # on the ear's (cupped) front face only: not its rim, and not the forehead bulging out in front of it
            thick = EAR_THICK * leaf_ear_profile(a)
            on_face = min(depth + 0.5 * thick - 0.2 * thick, thick + 0.02 - depth)
            best = max(best, min(half - abs(d.dot(across_axis)), (a - 0.2) * 0.6, (0.9 - a) * 0.6, on_face))
        return best

    # Huge glowing almond eyes painted on the face: a blue rim, the cyan eye and a pale core, tilted steeply.
    eyes = []
    for s in (-1, 1):
        n = Vector((s * 0.62, -0.78, 0.0)).normalized()
        eyes.append((h + Vector((s * 0.27, -0.35, 0.0)), n, s))

    def eye_field(half_w, half_h):
        return lambda c: max(lens(c, e, n, s, half_w, half_h, 38) for e, n, s in eyes)
    k.sdf_attr(head, "glow_edge", eye_field(0.29, 0.16))
    k.sdf_attr(head, "eye", eye_field(0.27, 0.14))
    k.sdf_attr(head, "eye_core", eye_field(0.16, 0.075))
    k.sdf_attr(head, "inner_ear", inner_ear)
    k.set_mats(head, matte(k.region_mat(f"{CUH}_Head", FUR, [("glow_edge", GLOW_EDGE, 0.35), ("eye", CYAN, 0.25),
                                                            ("eye_core", CYAN_CORE, 0.2), ("inner_ear", CYAN, 0.3)],
                                        rough=0.8, coat=0.0)))
    k.sphere(f"{CUH}_HeadNose", coll, h + Vector((0, -0.66, -0.27)), 0.065,
             k.mat(f"{CUH}_Nose", NOSE, rough=0.25, coat=0.6), scale=(1.3, 0.8, 0.7))

    # Mane: leaf-shaped shards in three rows, lying back along the head and neck and overlapping like layered fur:
    # behind the ears, along the sides of the head, and down the cheeks over the top of the chest ruff.
    def mane(bm):
        for s in (-1, 1):
            # framing the cheeks and neck, below the ears (none on top of the head, or it reads as quills)
            for base, tip, w in (((0.46, 0.10, -0.02), (0.66, 0.80, -0.14), 0.32),
                                 ((0.45, 0.08, -0.22), (0.64, 0.78, -0.48), 0.32),
                                 ((0.40, 0.04, -0.40), (0.56, 0.62, -0.80), 0.28),
                                 ((0.40, -0.14, -0.30), (0.58, 0.32, -0.70), 0.26)):  # cheek, over the ruff's corner
                b = h + Vector((s * base[0], base[1], base[2]))
                t = h + Vector((s * tip[0], tip[1], tip[2]))
                radial = (b - h).normalized()
                cone(bm, b, t, 0.06, w, axis_a=radial, ctrl=(b + t) / 2 + radial * 0.06, rings=8, segs=12)
    k.subdivide(mesh_from(f"{CUH}_HeadMane", coll, mane, fur), 1)


def finish(coll):
    """Centres the model over the origin (paws stay on z = 0)."""
    bpy.context.view_layer.update()
    xs, ys = [], []
    for o in coll.all_objects:
        if o.type in ("MESH", "CURVE"):
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                xs.append(w.x)
                ys.append(w.y)
    shift = Matrix.Translation((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0))
    for o in coll.all_objects:
        if o.parent is None:
            o.matrix_world = shift @ o.matrix_world


def build():
    coll = k.new_scene(CUH)
    fur = matte(k.mat(f"{CUH}_Fur", FUR, rough=0.8))
    grey = matte(k.mat(f"{CUH}_Grey", GREY, rough=0.8))

    # Body: short and compact, a deep chest, a tucked belly and round hips, with the neck leaning forward.
    els = [
        dict(co=(0, -0.50, 1.50), size=(0.42, 0.48, 0.50)),                 # chest
        dict(co=(0, 0.20, 1.50), size=(0.34, 0.48, 0.36)),                  # belly
        dict(co=(0, 0.75, 1.55), size=(0.38, 0.44, 0.44)),                  # hips
        dict(co=(0, -0.72, 2.00), size=(0.32, 0.32, 0.45)),                 # neck
    ]
    for s in (-1, 1):
        els.append(dict(co=(s * 0.27, -0.50, 1.35), size=(0.17, 0.25, 0.30)))                 # shoulders
        els.append(dict(co=(s * 0.27, 0.70, 1.38), size=(0.22, 0.40, 0.42), rot=(20, 0, 0)))  # thighs
    k.blob(f"{CUH}_Body", coll, els, fur, resolution=0.03)

    # Legs: tapered limbs fused into big round paws, with three dark toe lines drawn down the front of each paw.
    toes_mat = matte(k.region_mat(f"{CUH}_Paw", FUR, [("toes", TOE_LINE, 0.85)], rough=0.8, coat=0.0))
    for tag, (joints, radii, (px, py)) in LEGS.items():
        els = limb(joints, radii) + [dict(co=(px, py - 0.08, 0.14), size=(0.26, 0.34, 0.15)),
                                     dict(co=(px, py - 0.22, 0.11), size=(0.24, 0.2, 0.11))]
        leg = k.blob(f"{CUH}_Leg{tag}", coll, els, resolution=0.02)
        k.trim(leg, (0, 0, 0), (0, 0, -1), cap=True)

        def toes(c, px=px, py=py):
            if c.y > py - 0.12 or c.z > 0.26:  # front of the paw only
                return -1.0
            return max(0.012 - abs(c.x - (px + d)) for d in (-0.085, 0.0, 0.085))
        k.sdf_attr(leg, "toes", toes)
        k.set_mats(leg, toes_mat)

    # Grey-blue chest ruff: one shield of fur with jagged points, cut from the traced outline and bent round the
    # front of the neck and chest.
    def ruff(bm):
        verts = [bm.verts.new((u, v, 0)) for u, v in RUFF_OUTLINE]
        face = bm.faces.new(verts)
        bmesh.ops.triangulate(bm, faces=[face])
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=6, use_grid_fill=True)
        for v in bm.verts:
            u, d = v.co.x * RUFF_SCALE, v.co.y * RUFF_SCALE
            # wrap round the chest so the sides face the viewer too
            v.co = RUFF_TOP + Vector((u * 0.92, 0.7 * u * u + 0.05 * d, d * 0.95))
    shield = mesh_from(f"{CUH}_Ruff", coll, ruff, grey)
    sol = shield.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.07
    sol.offset = 1.0

    # Lighter leaf shards layered on the front of the shield, so the ruff reads as fur in layers.
    def ruff_shards(bm):
        for top, tip, w in (((0.0, -1.24, 1.89), (0.08, -1.30, 0.86), 0.34),
                            ((-0.26, -1.18, 1.86), (-0.48, -1.12, 1.18), 0.3),
                            ((0.26, -1.18, 1.86), (0.50, -1.11, 1.25), 0.3)):
            top, tip = Vector(top), Vector(tip)
            cone(bm, top, tip, 0.06, w, axis_a=(0, -1, 0.25), ctrl=(top + tip) / 2 + Vector((0, -0.07, 0)),
                 rings=10, segs=12, profile=flame_profile)
    k.subdivide(mesh_from(f"{CUH}_RuffShards", coll, ruff_shards,
                          matte(k.mat(f"{CUH}_GreyLight", GREY_LIGHT, rough=0.8))), 1)

    # Huge bushy tail: fat flame-shaped lobes fanned from the base, black on top and grey-blue underneath.
    fan_normal = TAIL_DIR.cross(Vector((0, 0, 1))).normalized()

    def lobes(color):
        def fill(bm):
            for tip, ctrl, w, c in TAIL_LOBES:
                if c == color:
                    cone(bm, TAIL_BASE, tip, 0.24, w, axis_a=fan_normal, ctrl=ctrl, rings=14, segs=16,
                         profile=tail_profile)
        return fill
    k.subdivide(mesh_from(f"{CUH}_TailFur", coll, lobes("fur"), fur), 1)
    k.subdivide(mesh_from(f"{CUH}_TailGrey", coll, lobes("grey"), grey), 1)

    # Head, then turned like the picture.
    build_head(coll, fur, grey)
    head_parts = k.by_prefix(coll, f"{CUH}_Head")
    bpy.context.view_layer.update()
    grow = Matrix.Translation(HEAD_PIVOT) @ Matrix.Scale(HEAD_SIZE, 4) @ Matrix.Translation(-HEAD_PIVOT)
    for o in head_parts:
        o.matrix_world = grow @ o.matrix_world
    k.turn(head_parts, HEAD_PIVOT, HEAD_TURN)
    finish(coll)
    return coll


if __name__ == "__main__":
    build()
