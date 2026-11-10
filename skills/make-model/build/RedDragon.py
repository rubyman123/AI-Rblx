"""Red Dragon: a fierce red dragon standing on all fours mid-stride, bat wings spread wide and raised, a thick neck,
swept-back cream horns and a long spiked tail with a spade tip that curls round. Cream belly plates run from the
throat to the tail; the eyes are gold with slit pupils under a heavy brow.

The model is laid out in the picture's own units and scaled to Roblox size at the end (SCALE)."""
import importlib
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

KIT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "kit")
if KIT not in sys.path:
    sys.path.insert(0, KIT)
import cuhkit as k  # noqa: E402

importlib.reload(k)

CUH = "RedDragon"
VIEW_YAW = 25  # the picture is seen from the front right
SCALE = 0.8

RED, MEMBRANE, CREAM, PLATE_LINE = "#840b0e", "#ac2519", "#a8865f", "#8e6b4a"
GOLD, EYE_RIM, SOCKET, MOUTH = "#f7c62e", "#e39a16", "#4e0607", "#3a0507"

# Spine from the back of the head, down the neck, along the body and out to the tail tip:
# (point, chain radius, belly band half-width, how far from the spine the band reaches, plate lines on)
SPINE = [
    ((0, -0.60, 3.00), 0.30, 0.19, 0.42, 1),
    ((0, -0.63, 2.62), 0.31, 0.20, 0.44, 1),
    ((0, -0.67, 2.22), 0.34, 0.22, 0.48, 1),
    ((0, -0.72, 1.86), 0.40, 0.25, 0.56, 1),
    ((0, -0.55, 1.45), 0.42, 0.27, 0.66, 1),
    ((0, 0.35, 1.38), 0.40, 0.22, 0.58, 1),
    ((0, 1.20, 1.45), 0.36, 0.17, 0.52, 0),
    # the tail sweeps back, then curls round to the dragon's right, towards the viewer
    ((-0.10, 1.70, 1.30), 0.33, 0.30, 0.46, 0),
    ((-0.45, 2.05, 0.92), 0.25, 0.23, 0.36, 0),
    ((-0.95, 2.25, 0.62), 0.17, 0.16, 0.27, 0),
    ((-1.45, 2.40, 0.52), 0.12, 0.11, 0.20, 0),
    ((-1.90, 2.52, 0.62), 0.09, 0.08, 0.15, 0),
    ((-2.25, 2.62, 0.86), 0.065, 0.055, 0.11, 0),
]
NECK_END, TAIL_START = 4, 6  # ball chains run along P0..P4 (neck) and P6..P12 (tail); ellipsoids fill the torso
STEPS = 40
PLATE_GAP = 0.19
PLATE_HALF_WIDTH = 0.012

# Dorsal spikes: (position along the spine in SPINE indices, height)
SPIKES = [(0.45, 0.15), (1.1, 0.17), (1.75, 0.19), (2.4, 0.2), (3.05, 0.21),
          (3.7, 0.24), (4.4, 0.26), (5.0, 0.28), (5.6, 0.29), (6.2, 0.3),
          (6.8, 0.31), (7.3, 0.3), (7.8, 0.28), (8.3, 0.26), (8.8, 0.24), (9.3, 0.21), (9.8, 0.19),
          (10.3, 0.16), (10.8, 0.14), (11.3, 0.11), (11.8, 0.09)]

HEAD_PIVOT = Vector((0, -0.62, 2.88))
HEAD_TURN = (14, 0, 20)  # nods down and looks off to its left, so the picture shows it in profile
HEAD_SIZE = 1.12

# Legs: joints from the shoulder or hip down to the ankle, capsule radii, foot (x, y). Diagonal stride: the left
# front and left hind feet step forward.
LEGS = {
    "FR": ([(-0.30, -0.68, 1.30), (-0.36, -0.60, 0.78), (-0.37, -0.76, 0.26), (-0.37, -0.80, 0.12)],
           [0.22, 0.175, 0.14], (-0.37, -0.82)),
    "FL": ([(0.30, -0.72, 1.30), (0.36, -0.95, 0.80), (0.37, -1.30, 0.28), (0.37, -1.37, 0.12)],
           [0.22, 0.175, 0.14], (0.37, -1.39)),
    "HR": ([(-0.30, 1.20, 1.22), (-0.36, 0.95, 0.72), (-0.37, 1.25, 0.32), (-0.37, 1.12, 0.12)],
           [0.25, 0.165, 0.135], (-0.37, 1.09)),
    "HL": ([(0.30, 1.15, 1.22), (0.36, 0.62, 0.75), (0.37, 0.80, 0.32), (0.37, 0.67, 0.12)],
           [0.25, 0.165, 0.135], (0.37, 0.64)),
}

# Wings, posed like the picture: the right wing is raised high and swept back, the left one reaches forward and
# droops. S (shoulder) and B (where the trailing edge meets the body) are (x, y) points dropped onto the back by
# ray casting; E elbow, W wrist (the top corner), F1 long finger tip, F2 second finger tip. bow lifts the middle
# of the long finger (and the membrane along it) so the leading edge arches.
WINGS = {
    "R": dict(S=(-0.22, 0.13), B=(-0.20, 0.55), E=(-0.82, -0.05, 2.80), W=(-1.32, -0.18, 3.70),
              F1=(-2.55, 2.85, 3.00), F2=(-2.05, 2.00, 1.95), bow=(0, 0, 0.3), sag=(0.3, 0.22)),
    "L": dict(S=(0.22, 0.13), B=(0.20, 0.30), E=(1.10, -0.50, 2.80), W=(2.10, -1.05, 3.20),
              F1=(2.70, -0.50, 1.45), F2=(1.95, -0.05, 1.60), bow=(0, 0, 0), sag=(0.3, 0.3)),
}


def matte(m, spec=0.1):
    """Less white specular on a material, so the saturated red doesn't wash out to pink."""
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Specular IOR Level"].default_value = spec
    return m


def sample_spine():
    """Catmull-Rom samples along SPINE with arc length, tangent (head -> tail), belly-side and sideways directions."""
    pts = [Vector(p[0]) for p in SPINE]
    ext = [2 * pts[0] - pts[1]] + pts + [2 * pts[-1] - pts[-2]]
    samples = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = ext[i], ext[i + 1], ext[i + 2], ext[i + 3]
        for j in range(STEPS + (1 if i == len(pts) - 2 else 0)):
            t = j / STEPS
            co = 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                        + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3)
            vals = [a + (b - a) * t for a, b in zip(SPINE[i][1:], SPINE[i + 1][1:])]
            samples.append(dict(co=co, chain=vals[0], band=vals[1], reach=vals[2], plates=vals[3], seg=i))
    s = 0.0
    for n, smp in enumerate(samples):
        if n:
            s += (smp["co"] - samples[n - 1]["co"]).length
        smp["s"] = s
        a = samples[max(n - 1, 0)]["co"]
        b = samples[min(n + 1, len(samples) - 1)]["co"]
        smp["t"] = (b - a).normalized()
        smp["ventral"] = smp["t"].cross(Vector((1, 0, 0))).normalized()
        smp["side"] = smp["ventral"].cross(smp["t"]).normalized()
    return samples


def body_elements(samples):
    els = [
        dict(co=(0, -0.62, 1.40), size=(0.42, 0.55, 0.52)),  # chest
        dict(co=(0, 0.30, 1.36), size=(0.38, 0.62, 0.48)),   # belly
        dict(co=(0, 1.20, 1.44), size=(0.36, 0.46, 0.40)),   # hips
    ]
    for s in (-1, 1):
        els.append(dict(co=(s * 0.28, -0.70, 1.28), size=(0.17, 0.26, 0.32)))                 # shoulders
        els.append(dict(co=(s * 0.29, 1.22, 1.20), size=(0.23, 0.45, 0.42), rot=(25, 0, 0)))  # thighs
    # Neck and tail are dense chains of balls, which fuse into a smooth tube. Packed this tight (spacing 0.35 r)
    # the fields add up and the surface grows to about r / 0.805, so each ball is made that much smaller.
    next_s = None
    for smp in samples:
        if NECK_END <= smp["seg"] < TAIL_START:
            next_s = None
            continue
        if next_s is None or smp["s"] >= next_s:
            els.append(dict(type="BALL", co=tuple(smp["co"]), r=0.805 * smp["chain"]))
            next_s = smp["s"] + 0.35 * smp["chain"]
    return els


def cone(bm, base, tip, r_a, r_b, axis_a=(1, 0, 0), ctrl=None, rings=7, segs=12, power=1.0):
    """Adds a pointed cone along the curve base -> ctrl -> tip. The cross-section is an ellipse: r_a across axis_a,
    r_b the other way, so a small r_a makes a thin blade (spikes, frills)."""
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
        f = (1 - t) ** power
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


def mesh_from(name, coll, fill, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    fill(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    k.set_mats(obj, material)
    return k.smooth(obj) if smooth else obj


def build_head(coll, bone):
    # A wedge: tall at the back, tapering down to a blunt nose.
    els = [
        dict(co=(0, -0.82, 3.00), size=(0.31, 0.37, 0.31)),                # cranium
        dict(co=(0, -1.28, 2.88), size=(0.20, 0.42, 0.18), rot=(10, 0, 0)),  # snout
        dict(co=(0, -1.60, 2.84), size=(0.15, 0.13, 0.13)),                # nose
        dict(co=(0, -1.10, 2.70), size=(0.19, 0.40, 0.14), rot=(8, 0, 0)),   # lower jaw
    ]
    for s in (-1, 1):
        els += [dict(co=(s * 0.18, -1.05, 3.17), size=(0.10, 0.19, 0.07), rot=(14, 0, 0)),  # brow ridge
                dict(co=(s * 0.19, -0.75, 2.86), size=(0.13, 0.22, 0.16))]                   # cheek
    head = k.blob(f"{CUH}_Head", coll, els, resolution=0.022)
    k.subdivide(head, 1)
    k.apply_modifiers(head)
    nostrils = [Vector((s * 0.085, -1.71, 2.91)) for s in (-1, 1)]
    for n in nostrils:
        k.push(head, n, 0.04, -0.016)

    def nostril(c):
        return max(0.026 - (c - n).length for n in nostrils)
    k.sdf_attr(head, "nostril", nostril)
    k.set_mats(head, matte(k.region_mat(f"{CUH}_Head", RED, [("nostril", MOUTH, 0.5)], rough=0.75, coat=0.0)))

    # Big almond eyes: gold with a slit pupil, set in a dark socket under a heavy angled lid.
    socket = matte(k.mat(f"{CUH}_Socket", SOCKET, rough=0.7))
    for s in (-1, 1):
        center, look, r = Vector((s * 0.155, -1.07, 3.05)), Vector((s * 0.8, -0.58, 0.06)).normalized(), 0.112
        parts = k.eye(CUH, coll, center, r, look=look, iris=GOLD, iris_size=0.8, pupil_size=0.42, white=EYE_RIM,
                      lid=socket, lid_close=0.3, lid_tilt=-16, lower_lid=0.18, side=s)
        # the kit's pupil sits inside the iris dome; bring the slit forward onto its surface
        parts[2].location = center + look * r * 1.1
        parts[2].scale = (0.28, 0.3, 1.3)

    def horns(bm):
        for s in (-1, 1):
            cone(bm, (s * 0.14, -0.68, 3.18), (s * 0.58, 0.12, 3.85), 0.135, 0.135,
                 ctrl=(s * 0.26, -0.42, 3.66), power=0.85)
            for base, tip, r in (((0.24, -0.60, 3.04), (0.46, -0.16, 3.12), 0.08),
                                 ((0.26, -0.58, 2.88), (0.50, -0.18, 2.80), 0.075),
                                 ((0.22, -0.62, 2.72), (0.40, -0.28, 2.56), 0.065),
                                 ((0.27, -0.86, 2.82), (0.44, -0.62, 2.74), 0.06),
                                 ((0.15, -0.86, 2.64), (0.21, -0.76, 2.44), 0.05)):
                cone(bm, (s * base[0], base[1], base[2]), (s * tip[0], tip[1], tip[2]), r * 0.45, r * 1.4)
    k.subdivide(mesh_from(f"{CUH}_HeadBone", coll, horns, bone), 1)


def build_wing(coll, tag, bvh, membrane, red):
    joints = WINGS[tag]

    def on_back(x, y):
        hit = bvh.ray_cast(Vector((x, y, 4.0)), Vector((0, 0, -1)), 6.0)[0]
        return hit - Vector((0, 0, 0.04))
    S, B = on_back(*joints["S"]), on_back(*joints["B"])
    E, W, F1, F2 = (Vector(joints[n]) for n in ("E", "W", "F1", "F2"))

    def edge(a, b, n, sag):
        out = []
        for i in range(n):
            t = i / n
            p = a.lerp(b, t)
            out.append(p + (W - p).normalized() * sag * math.sin(math.pi * t))
        return out
    n_outer = 18
    rim = edge(F1, F2, n_outer, joints["sag"][0]) + edge(F2, B, 20, joints["sag"][1]) + edge(B, S, 8, 0.0) + [S]
    rings = 20
    bow = Vector(joints["bow"])

    def point(j, u):
        # the bow follows the long finger's curve (a quadratic Bezier: 4u(1-u) at its control point) and fades out
        # towards the second finger
        fade = max(0.0, 1 - j / n_outer)
        return W.lerp(rim[j], u) + bow * (4 * u * (1 - u) * fade)

    def fill(bm):
        hub = bm.verts.new(W)
        grid = [[bm.verts.new(point(j, i / rings)) for i in range(1, rings + 1)] for j in range(len(rim))]
        for j in range(len(rim) - 1):
            a, b = grid[j], grid[j + 1]
            bm.faces.new((hub, a[0], b[0]))
            for i in range(rings - 1):
                bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    skin = mesh_from(f"{CUH}_Membrane{tag}", coll, fill, membrane)
    sol = skin.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.035
    sol.offset = 0.0
    k.subdivide(skin, 1)

    k.tube(f"{CUH}_WingArm{tag}", coll, [S, E, W], [0.09, 0.075, 0.065], red)
    k.tube(f"{CUH}_WingFinger1{tag}", coll, [W, W.lerp(F1, 0.5) + 2 * bow, F1], [0.065, 0.045, 0.016], red)
    k.tube(f"{CUH}_WingFinger2{tag}", coll, [W, W.lerp(F2, 0.5), F2], [0.05, 0.035, 0.014], red)
    return W


def build_spade(coll, samples, red):
    end = samples[-1]
    t, up, side, o = end["t"], -end["ventral"], end["side"], end["co"]
    outline = [(0.6, 0.0), (0.0, 0.3), (0.14, 0.07), (-0.08, 0.05), (-0.08, -0.05), (0.14, -0.07), (0.0, -0.3)]

    def fill(bm):
        layers = [[bm.verts.new(o + t * u + up * w + side * x) for u, w in outline] for x in (-0.04, 0.04)]
        bm.faces.new(layers[0])
        bm.faces.new(list(reversed(layers[1])))
        n = len(outline)
        for i in range(n):
            bm.faces.new((layers[0][i], layers[0][(i + 1) % n], layers[1][(i + 1) % n], layers[1][i]))
    spade = mesh_from(f"{CUH}_Spade", coll, fill, red, smooth=False)
    bev = spade.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.015
    bev.segments = 2


def finish(coll):
    """Scales the picture-unit layout to Roblox size and centres it over the origin (feet stay on z = 0)."""
    bpy.context.view_layer.update()
    tops = [o for o in coll.all_objects if o.parent is None]
    for o in tops:
        o.matrix_world = Matrix.Scale(SCALE, 4) @ o.matrix_world
    bpy.context.view_layer.update()
    xs, ys = [], []
    for o in coll.all_objects:
        if o.type in ("MESH", "CURVE"):
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                xs.append(w.x)
                ys.append(w.y)
    shift = Matrix.Translation((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0))
    for o in tops:
        o.matrix_world = shift @ o.matrix_world


def build():
    coll = k.new_scene(CUH)
    red = matte(k.mat(f"{CUH}_Red", RED, rough=0.75))
    membrane = matte(k.mat(f"{CUH}_Membrane", MEMBRANE, rough=0.7))
    bone = matte(k.mat(f"{CUH}_Bone", CREAM, rough=0.55, coat=0.1), 0.35)
    samples = sample_spine()

    # Body: torso, neck and tail fused into one smooth shape, with the cream belly band and its plate lines.
    body = k.blob(f"{CUH}_Body", coll, body_elements(samples), resolution=0.03)
    k.subdivide(body, 1)
    k.apply_modifiers(body)
    kd = KDTree(len(samples))
    for n, smp in enumerate(samples):
        kd.insert(smp["co"], n)
    kd.balance()

    def spine_at(c):
        smp = samples[kd.find(c)[1]]
        r = c - smp["co"]
        along = r.dot(smp["t"])
        return smp, r - smp["t"] * along, smp["s"] + along

    def belly(c):
        smp, r, _ = spine_at(c)
        return min(smp["band"] - abs(r.dot(smp["side"])), r.dot(smp["ventral"]), smp["reach"] - r.length)

    def plates(c):
        smp, r, s = spine_at(c)
        if smp["plates"] < 0.5:
            return -1.0
        d = abs((s + PLATE_GAP / 2) % PLATE_GAP - PLATE_GAP / 2)
        return min(belly(c) - 0.012, PLATE_HALF_WIDTH - d)
    k.sdf_attr(body, "belly", belly)
    k.sdf_attr(body, "plates", plates)
    k.set_mats(body, matte(k.region_mat(f"{CUH}_Body", RED, [("belly", CREAM, 0.62), ("plates", PLATE_LINE, 0.7)],
                                        rough=0.75, coat=0.0)))
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())

    # Legs: capsules from shoulder/hip to ankle (the joints swell a little into knees), a foot and three toes.
    claws = []
    for tag, (joints, radii, (fx, fy)) in LEGS.items():
        els = [k.capsule(joints[i], joints[i + 1], radii[i]) for i in range(len(joints) - 1)]
        els.append(dict(co=(fx, fy - 0.05, 0.1), size=(0.19, 0.26, 0.11)))
        for d in (-0.11, 0.0, 0.11):
            els.append(dict(type="BALL", co=(fx + d, fy - 0.23, 0.075), r=0.07))
            claws.append(((fx + d * 1.05, fy - 0.28, 0.09), (fx + d * 1.3, fy - 0.5, 0.012),
                          (fx + d * 1.2, fy - 0.44, 0.13)))
        leg = k.blob(f"{CUH}_Leg{tag}", coll, els, red, resolution=0.025)
        k.trim(leg, (0, 0, 0), (0, 0, -1), cap=True)

    # Head, eyes, horns and cheek frills, then turned like the picture.
    build_head(coll, bone)
    head_parts = k.by_prefix(coll, f"{CUH}_Head", f"{CUH}_Eye", f"{CUH}_Iris", f"{CUH}_Pupil", f"{CUH}_Glint",
                             f"{CUH}_Lid", f"{CUH}_LowLid")
    bpy.context.view_layer.update()
    grow = Matrix.Translation(HEAD_PIVOT) @ Matrix.Scale(HEAD_SIZE, 4) @ Matrix.Translation(-HEAD_PIVOT)
    for o in head_parts:
        o.matrix_world = grow @ o.matrix_world
    k.turn(head_parts, HEAD_PIVOT, HEAD_TURN)

    # Spikes along the spine (placed on the body's surface by ray casting) and the foot claws, as one mesh.
    lean = math.radians(40)

    def spikes(bm):
        for u, h in SPIKES:
            smp = samples[min(int(u * STEPS), len(samples) - 1)]
            dorsal = -smp["ventral"]
            hit, nrm, _, _ = bvh.ray_cast(smp["co"] + dorsal * 1.0, -dorsal, 2.0)
            if hit is None:
                continue
            direction = (nrm * math.cos(lean) + smp["t"] * math.sin(lean)).normalized()
            base = hit - nrm * 0.04
            cone(bm, base, base + direction * (h + 0.04), 0.035, 0.42 * h + 0.02, axis_a=smp["side"],
                 ctrl=base + nrm * (0.6 * (h + 0.04)), segs=10, rings=6)
        for base, tip, ctrl in claws:
            cone(bm, base, tip, 0.05, 0.055, ctrl=ctrl, segs=10, rings=6, power=0.9)
    k.subdivide(mesh_from(f"{CUH}_Spikes", coll, spikes, bone), 1)

    # Wings, with a hook on each wrist.
    wrists = {tag: build_wing(coll, tag, bvh, membrane, red) for tag in WINGS}

    def hooks(bm):
        for tag, w in wrists.items():
            s = 1 if tag == "L" else -1
            cone(bm, w, w + Vector((s * 0.05, -0.22, 0.2)), 0.05, 0.05, ctrl=w + Vector((s * 0.02, -0.04, 0.18)),
                 segs=10, rings=6)
    mesh_from(f"{CUH}_WingHooks", coll, hooks, red)

    build_spade(coll, samples, red)
    finish(coll)
    return coll


if __name__ == "__main__":
    build()
