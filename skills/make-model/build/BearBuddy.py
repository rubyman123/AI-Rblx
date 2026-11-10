# Example build script from fwjelaa's Blender -> Roblox model pipeline (FWJ STUDIOS). See CREDITS.md.
"""Bear Buddy: the finished example model. A round brown bear cub with a cream muzzle, rosy cheeks and a happy
smile, in a red tee, navy shorts and chunky sneakers. Read this before writing a new build script: it shows every
technique (sculpting, crisp colour regions, eyes, clothes, limbs, shoes, a head turn)."""
import importlib
import math
import os
import sys

from mathutils import Matrix, Vector

KIT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "kit")
if KIT not in sys.path:
    sys.path.insert(0, KIT)
import cuhkit as k  # noqa: E402

importlib.reload(k)

CUH = "BearBuddy"
FUR, MUZZLE, NOSE, MOUTH, BLUSH, EAR_IN = "#93603a", "#f3dcb4", "#3a2418", "#4a2a1a", "#f08a8a", "#e7a39a"

HEAD_C = Vector((0.0, 0.0, 2.86))
HEAD_R = (0.98, 0.9, 0.86)


def mouth_z(x):
    """Smile line in head space, under the nose: a soft U that turns up at the corners."""
    t = min(abs(x) / 0.3, 1.0)
    return -0.36 + 0.1 * t ** 2


def build():
    coll = k.new_scene(CUH)
    fur = k.mat(f"{CUH}_Fur", FUR, rough=0.8, sheen=0.4, bump="fabric", bump_scale=60, bump_strength=0.08)

    # Head: a sphere pushed into a bear face: a round muzzle, soft cheeks and eye domes.
    head = k.quadsphere(f"{CUH}_Head", coll, HEAD_C, HEAD_R, cuts=64)
    k.push(head, (0, -0.72, -0.25), 0.5, 0.2, direction=(0, -1, 0))        # muzzle
    for s in (-1, 1):
        k.push(head, (s * 0.5, -0.6, -0.15), 0.4, 0.06)                     # cheeks
        k.push(head, (s * 0.34, -0.72, 0.12), 0.3, 0.05)                     # eye domes
    k.groove(head, mouth_z, (-0.3, 0.3), width=0.06, depth=0.03, front_y=-0.5)

    # Crisp colour regions: each function is > 0 inside its region (in the head's own space).
    def muzzle(c):
        return min(1 - math.sqrt((c.x / 0.42) ** 2 + ((c.z + 0.26) / 0.3) ** 2), (-0.4 - c.y) * 2)

    def blush(c):
        return max(0.13 - math.hypot(abs(c.x) - 0.56, c.z + 0.12), -1) if c.y < -0.3 else -1

    def mouth_line(c):
        return min(0.016 - abs(c.z - mouth_z(c.x)), 0.3 - abs(c.x), (-0.6 - c.y) * 2)
    k.sdf_attr(head, "muzzle", muzzle)
    k.sdf_attr(head, "blush", blush)
    k.sdf_attr(head, "mouth", mouth_line)
    k.set_mats(head, k.region_mat(f"{CUH}_Head", FUR, [("muzzle", MUZZLE, 0.5), ("blush", BLUSH, 0.55),
                                                     ("mouth", MOUTH, 0.6)], rough=0.82, coat=0.0))
    k.subdivide(head, 1)

    # Nose: a glossy rounded triangle on the tip of the muzzle.
    k.sphere(f"{CUH}_Nose", coll, HEAD_C + Vector((0, -1.04, -0.12)), 0.13,
             k.mat(f"{CUH}_Nose", NOSE, rough=0.2, coat=0.8), scale=(1.25, 0.8, 0.85))

    # Ears: round fur ears with a pink inside, facing forward.
    ear_in = k.mat(f"{CUH}_EarIn", EAR_IN, rough=0.6)
    for s in (-1, 1):
        base = HEAD_C + Vector((s * 0.6, 0.05, 0.62))
        k.sphere(f"{CUH}_Ear{s}", coll, base, 0.35, fur, scale=(1, 0.62, 1), rot=(0, 0, s * -12))
        k.sphere(f"{CUH}_EarIn{s}", coll, base + Vector((0, -0.15, -0.01)), 0.22, ear_in, scale=(1, 0.4, 1),
                 rot=(0, 0, s * -12))

    # Eyes: big and friendly, no lids, looking straight ahead.
    for s in (-1, 1):
        k.eye(CUH, coll, HEAD_C + Vector((s * 0.33, -0.76, 0.14)), 0.2, look=(s * 0.08, -1, 0.0),
              iris="#3b2416", iris_size=0.7, side=s)

    # A small head tilt gives it personality.
    head_parts = k.by_prefix(coll, f"{CUH}_Head", f"{CUH}_Nose", f"{CUH}_Ear", f"{CUH}_Eye", f"{CUH}_Iris",
                             f"{CUH}_Pupil", f"{CUH}_Glint")
    k.turn(head_parts, (0, 0, 2.05), (0, 5, -9))  # tilt, and turn towards the viewer

    # Body: red tee over navy shorts, a short neck, arms hanging loose with round paws.
    k.tshirt(CUH, coll, 1.3, 2.02, 0.86, 0.6, "#e5453b", sleeve_angle=38, sleeve_len=0.28, sleeve_r=0.135,
             neck=0.11)
    k.shorts(CUH, coll, 0.9, 1.38, 0.82, 0.58, "#2c3f8e", waistband=False)
    k.tube(f"{CUH}_Neck", coll, [(0, 0.02, 1.85), (0, 0.0, 2.08), (0, -0.02, 2.3)], [0.13, 0.13, 0.15], fur)
    for s in (-1, 1):
        k.tube(f"{CUH}_Arm{s}", coll,
               [(s * 0.38, 0.0, 1.86), (s * 0.55, -0.02, 1.62), (s * 0.62, -0.06, 1.36), (s * 0.63, -0.08, 1.2)],
               [0.1, 0.095, 0.09, 0.088], fur)
        k.sphere(f"{CUH}_Paw{s}", coll, (s * 0.64, -0.09, 1.12), 0.13, fur, scale=(1, 1, 1.1))
    k.sphere(f"{CUH}_Tail", coll, (0, 0.34, 1.12), 0.14, fur)

    # Legs into chunky sneakers, toes turned a little out.
    L, W, H = 1.08, 0.56, 0.54
    for s, yaw in ((1, 14), (-1, -14)):
        heel = Vector((s * 0.3, 0.2, 0.0))
        k.sneaker(CUH, coll, "L" if s > 0 else "R", heel, yaw, length=L, width=W, height=H,
                  upper="#f5f3ee", sole="#f2c230", laces="#e5453b", stripe="#e5453b")
        ankle = heel + Matrix.Rotation(math.radians(yaw), 3, "Z") @ Vector((0, -0.17 * L, 0.55 * H))
        k.tube(f"{CUH}_Leg{s}", coll,
               [(s * 0.2, 0.0, 1.05), (s * 0.24, -0.02, 0.82), (ankle.x, ankle.y, 0.58), (ankle.x, ankle.y, ankle.z)],
               [0.11, 0.1, 0.095, 0.09], fur)
    return coll


if __name__ == "__main__":
    build()
