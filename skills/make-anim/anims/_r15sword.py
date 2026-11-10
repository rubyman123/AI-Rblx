"""R15 one-handed sword set: stance, blade aiming, key poses and timelines (method by fwjelaa).

Built on anims/_r15.py: feet and hands are placed and two-bone IK bends the knees and elbows.
Unlike the fist clips, these timelines are solved on EVERY frame: the key poses are parameters
(hand position, blade direction, hips, chest, feet...), the in-betweens blend the parameters with
the key's ease and run the IK again. So the planted feet never slide, the sword hand travels on a
curve through its keys, and the blade turns smoothly in the world instead of whatever blending the
joint angles would do to it.

The sword (joint `Handle`, keyed at rest) sits in the right hand; the blade is aimed by turning the
WRIST: the forearm enters the hand on its +Y and the blade leaves on its -Z, so the fist stays lined
up with the forearm like a real grip. Where the elbow points is chosen per key so the wrist twist
stays inside what a real wrist can do (about +-90 deg).

Blade directions are (pitch, yaw) in character space: (0, 0) straight at the opponent, +pitch up,
+yaw to the character's left (the same way the pose language turns).
"""
import math

from mathutils import Matrix, Vector

import animkit as ak
import checks
import rigs
from _r15 import STANCE as FIST, _pivot, angles_of, fighter, fk, reach

PROPS = ("Sword",)
_RIGP = rigs.with_props("R15", PROPS)

# Same footwork as the fist stance (R15_Idle), a little less bladed so the sword arm is free.
SWORD = dict(FIST)
SWORD.update({
    "hips": (-4, -28, 0),
    "chest": (-10, 6, 0),
    "head": (8, 20, 0),
    "lead_fist": ((-0.75, 0.45, -1.35), (-0.5, -1, 0.2)),  # free hand: loose guard in front of the chest
})
_TOE = fk(fighter(SWORD))["RightFoot"] @ Vector((0, -0.15, -0.5))  # front-bottom edge of the rear foot


def toe(yaw, pitch):
    """Rear foot on its toe edge (heel up when pitch < 0), the edge kept where the stance put it."""
    return {"x": _TOE.x, "z": _TOE.z, "yaw": yaw, "pitch": pitch, "anchor": "toe"}


SWORD["rear_foot"] = toe(-50, 0)  # the stance foot, written the same way so it blends into a heel lift


def direction(pitch, yaw):
    return Matrix.Rotation(math.radians(yaw), 3, "Y") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ Vector((0, 0, -1))


def aim(pose, blade):
    """Turn the sword wrist so the blade points along `blade` (world vector)."""
    frames = fk(pose)
    elbow = _pivot(frames, "RightLowerArm").to_translation()
    wrist = _pivot(frames, "RightHand")
    fore = (elbow - wrist.to_translation()).normalized()
    z = -Vector(blade).normalized()
    y = fore - z * fore.dot(z)  # the forearm, squared off against the blade
    if y.length < 1e-4:
        y = Vector((0, 1, 0)) - z * z.y
    y.normalize()
    m = Matrix((y.cross(z), y, z)).transposed()
    pose["RightHand"] = angles_of(wrist.to_3x3().inverted() @ m)
    pose["Handle"] = (0.0, 0.0, 0.0)
    return pose


def wrist_angles(pose):
    """(twist, bend) of the sword wrist in degrees. Twist: the blade around the forearm, 0 = on the
    thumb side (a hanging arm holds it pointing forward); a real wrist manages about +-90. Bend: > 0
    the blade tilts back toward the elbow (stiff past ~20), < 0 it continues the arm line (fine to ~-70,
    the grip is diagonal in the palm)."""
    f = fk(pose)
    d = f["RightLowerArm"].to_3x3().inverted() @ (f["RightHand"].to_3x3() @ Vector((0, 0, -1)))
    return math.degrees(math.atan2(-d.x, -d.z)), math.degrees(math.asin(max(-1.0, min(1.0, d.y))))


def tip(pose):
    """World position of the blade tip (for checking arcs and floor clearance)."""
    f = checks.forward_kinematics(_RIGP, ak.pose_transforms(pose, _RIGP))["Handle"]
    return f @ Vector((0, rigs.PROPS["Sword"]["size"][1] / 2, 0))


# ---- solving a key --------------------------------------------------------------------------------

def K(hand, pitch, yaw, elbow=(0.55, -1, 0.35), free=None, **over):
    """Key parameters: SWORD stance overridden by `over` (hips, move, chest, head, rear_foot...), the
    sword wrist at `hand` (studs, character space), the blade aimed (pitch, yaw), `elbow` = where the
    elbow would rather point, `free` = (wrist, elbow) of the free hand in chest axes."""
    k = dict(SWORD)
    k.update(over)
    if free:
        k["lead_fist"] = free
    k.update(hand=tuple(hand), pitch=pitch, yaw=yaw, elbow=tuple(elbow), turn=None, free_turn=None)
    return k


_BODY = ("UpperTorso", "LowerTorso", "Head")


def clip(pose, side):
    """How deep (studs) the arm on `side` (and the sword, for the right) sinks into the torso or head:
    the same pairs the export checks look at."""
    frames = checks.forward_kinematics(_RIGP, ak.pose_transforms(pose, _RIGP))
    sizes = _RIGP["parts"]
    limbs = [f"{side}LowerArm", f"{side}Hand"] + (["Handle"] if side == "Right" else [])
    worst = 0.0
    for limb in [f"{side}UpperArm"] + limbs:
        body = ("Head",) if limb.endswith("UpperArm") else _BODY
        for pt in checks._samples_along(frames[limb], sizes[limb]):
            for b in body:
                worst = max(worst, checks._depth_inside(pt, frames[b], sizes[b]))
    return worst


def _turned(pose, side, wrist, elbow, turn):
    """reach() with the elbow direction turned `turn` degrees around the shoulder-wrist line."""
    axis = (Vector(wrist) - _pivot(fk(pose), f"{side}UpperArm").to_translation()).normalized()
    return reach(pose, side, Vector(wrist), elbow=Matrix.Rotation(math.radians(turn), 3, axis) @ Vector(elbow))


def solve(k, blade=None, prev=None):
    """Pose for key parameters k. Each elbow turns around its shoulder-wrist line from the preferred
    direction (as a real shoulder does): `k["turn"]` for the sword arm, `k["free_turn"]` for the free
    arm. With None, the turn is searched (least wrist twist and nothing sunk into the body, staying
    near the preferred direction and near `prev`, the key before, so the arm doesn't roll over between
    keys) and stored in k, so the in-betweens can blend it."""
    body = fighter(k)
    chest = fk(body)["UpperTorso"]
    (fw, fe) = k["lead_fist"]
    free_wrist, free_elbow = chest @ Vector(fw), chest.to_3x3() @ Vector(fe)
    if k.get("free_turn") is None:
        last = prev["free_turn"] if prev else 0
        k["free_turn"] = min(range(-90, 91, 15), key=lambda t: 300 * max(0.0, clip(
            _turned(dict(body), "Left", free_wrist, free_elbow, t), "Left") - 0.05) + 0.4 * abs(t) + 0.5 * abs(t - last))
    _turned(body, "Left", free_wrist, free_elbow, k["free_turn"])
    blade = blade or direction(k["pitch"], k["yaw"])

    def arm(turn):
        return aim(_turned(dict(body), "Right", k["hand"], k["elbow"], turn), blade)

    if k["turn"] is None:
        def cost(turn):
            p = arm(turn)
            tw, bd = wrist_angles(p)
            return (abs(tw) + 2 * max(0.0, bd - 20) + 2 * max(0.0, -bd - 70) + 0.4 * abs(turn)
                    + 300 * max(0.0, clip(p, "Right") - 0.05) + (0.8 * abs(turn - prev["turn"]) if prev else 0.0))
        k["turn"] = min(range(-150, 151, 15), key=cost)
    return arm(k["turn"])


STANCE_K = K((1.0, -0.25, -1.65), 25, 8)  # arm out in front, blade at the opponent's throat
STANCE = solve(STANCE_K)


# ---- timelines ------------------------------------------------------------------------------------

EASE = {
    "linear": lambda u: u,
    "quad_in": lambda u: u * u,
    "quad_out": lambda u: 1 - (1 - u) ** 2,
    "cubic_in": lambda u: u ** 3,
    "cubic_out": lambda u: 1 - (1 - u) ** 3,
    "cubic_inout": lambda u: 4 * u ** 3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2,
    "sine_inout": lambda u: 0.5 - 0.5 * math.cos(math.pi * u),
}


def _lerp(a, b, t):
    if isinstance(a, dict):
        return {key: _lerp(a[key], b[key], t) for key in a}
    if isinstance(a, (tuple, list)):
        return tuple(_lerp(x, y, t) for x, y in zip(a, b))
    if isinstance(a, (int, float)):
        return a + (b - a) * t
    return a if t < 0.5 else b


def _catmull(p0, p1, p2, p3, u):
    p0, p1, p2, p3 = (Vector(p) for p in (p0, p1, p2, p3))
    return tuple(0.5 * (2 * p1 + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u ** 2
                        + (3 * p1 - p0 - 3 * p2 + p3) * u ** 3))


def sample(keys, f):
    """Key parameters at frame f (clamped to the timeline): each key's ease shapes the move to the
    next key, the sword hand follows a Catmull-Rom curve through the key positions."""
    f = max(keys[0][0], min(keys[-1][0], f))
    i = max(j for j in range(len(keys) - 1) if keys[j][0] <= f) if f < keys[-1][0] else len(keys) - 2
    (f0, k0, ease), (f1, k1, _) = keys[i], keys[i + 1]
    u = EASE[ease]((f - f0) / (f1 - f0))
    k = _lerp(k0, k1, u)
    hands = [keys[max(0, j)][1]["hand"] for j in (i - 1, i)] + [keys[min(len(keys) - 1, j)][1]["hand"] for j in (i + 1, i + 2)]
    k["hand"] = _catmull(*hands, u)
    return k


def timeline(name, keys, blade_lag=1, free_lag=2, **anim):
    """Animation keyed on every frame from (frame, K(...), ease) keys. The blade direction runs
    `blade_lag` frames behind the hand and the free arm `free_lag` frames behind the body (overlap)."""
    for i, (_, k, _) in enumerate(keys):
        if k["turn"] is None or k["free_turn"] is None:
            solve(k, prev=keys[i - 1][1] if i else None)  # fixes each key's elbow turns; the in-betweens blend them
    length = keys[-1][0]
    a = ak.Anim(name, rig="R15", props=PROPS, length=length, **anim)
    for f in range(length + 1):
        k = sample(keys, f)
        late_free = sample(keys, f - free_lag)
        k["lead_fist"], k["free_turn"] = late_free["lead_fist"], late_free["free_turn"]
        late = sample(keys, f - blade_lag)
        a.full(f, solve(k, direction(late["pitch"], late["yaw"])), "linear")
    return a


# ---- the moves ------------------------------------------------------------------------------------
# Each swing: wind-up -> mid (the blade still trails the hand) -> contact (Hit, blade square to the
# target) -> follow-through -> settle (moving hold) -> recover -> stance. The head counter-turns so the
# eyes stay on the opponent. Snappy timing: wind-up 8, strike 4 over three keys, recovery 22.

def slash1_keys():
    """Forehand diagonal, high right -> low left: the blade chambers up behind the right shoulder,
    the hips and chest unwind left through the target, the rear heel comes up on a short lunge, and
    the arm finishes extended across the body with the blade continuing its line."""
    return [
        (0, STANCE_K, "sine_inout"),
        (4, K((1.35, 0.4, -1.0), 70, -30, hips=(-3, -40, 0), move=(0, -0.36, 0.06), chest=(-8, -4, 0),
              head=(6, 40, 0), free=((-0.65, 0.5, -1.4), (-0.5, -1, 0.2))), "sine_inout"),
        (8, K((1.45, 1.05, 0.2), 55, -165, hips=(-2, -52, 0), move=(0, -0.38, 0.12), chest=(-6, -14, 0),
              head=(4, 58, 0), free=((-0.6, 0.5, -1.45), (-0.5, -1, 0.2))), "quad_in"),
        (10, K((1.15, 0.75, -0.85), 30, -105, hips=(-4, -30, 0), move=(0, -0.38, 0), chest=(-10, -4, 0),
               head=(6, 30, 0), free=((-0.75, 0.4, -1.2), (-0.5, -1, 0.2))), "linear"),
        (12, K((0.05, 0.1, -2.15), -16, -1, elbow=(0, -1, 0.6), hips=(-6, 4, 0), move=(0, -0.42, -0.28), chest=(-16, 18, 0),
               head=(4, -20, 0), rear_foot=toe(-20, -22), free=((-0.7, 0.5, -1.1), (-0.5, -1, 0.3))), "linear"),
        (15, K((-0.35, -0.45, -2.0), -42, 43, elbow=(0.8, 0.3, 0.4), hips=(-6, 12, 0), move=(0, -0.44, -0.32), chest=(-18, 26, 0),
               head=(2, -34, 0), rear_foot=toe(-16, -26), free=((-1.35, 0.35, -0.55), (-0.4, -1, 0.4))), "cubic_out"),
        (19, K((-0.3, -0.4, -1.95), -36, 41, elbow=(0.8, 0.3, 0.4), hips=(-6, 10, 0), move=(0, -0.43, -0.3), chest=(-17, 24, 0),
               head=(3, -30, 0), rear_foot=toe(-17, -24), free=((-1.3, 0.35, -0.6), (-0.4, -1, 0.4))), "sine_inout"),
        (26, K((0.3, -0.3, -1.85), 2, 28, hips=(-5, -12, 0), move=(0, -0.4, -0.14), chest=(-13, 14, 0),
               head=(6, 0, 0), rear_foot=toe(-36, -10)), "sine_inout"),
        (34, STANCE_K, "linear"),
    ]


def slash2_keys():
    """Backhand, high left -> right (the return swing): the blade cocks over the left shoulder with the
    sword arm folded across the chest and the free hand out of the way, then the body unwinds right
    and the arm opens out through the target, finishing extended to the right."""
    return [
        (0, STANCE_K, "sine_inout"),
        (4, K((0.35, 0.35, -1.7), 65, 70, elbow=(0.6, -0.8, -0.2), hips=(-4, -10, 0), move=(0, -0.42, -0.1),
              chest=(-12, 12, 0), head=(6, 0, 0), free=((-1.2, 0.2, -0.9), (-0.4, -1, 0.3))), "sine_inout"),
        (8, K((-0.3, 0.45, -1.25), 35, 150, elbow=(0.6, -0.6, -0.5), hips=(-4, 4, 0), move=(0, -0.42, -0.06),
              chest=(-12, 24, 0), head=(6, -26, 0), rear_foot=toe(-30, -8),
              free=((-1.45, 0.05, -0.55), (-0.4, -1, 0.4))), "quad_in"),
        (10, K((0.05, 0.2, -1.75), 15, 95, elbow=(0.6, -0.8, 0.0), hips=(-4, -12, 0), move=(0, -0.42, -0.14),
               chest=(-12, 8, 0), head=(6, 6, 0), rear_foot=toe(-40, -4),
               free=((-1.35, 0.15, -0.75), (-0.4, -1, 0.3))), "linear"),
        (12, K((0.75, 0.15, -1.75), -12, -30, elbow=(0.8, 0.3, 0.4), hips=(-5, -32, 0), move=(0, -0.42, -0.24), chest=(-12, -10, 0),
               head=(6, 42, 0), free=((-0.9, 0.35, -1.1), (-0.45, -1, 0.25))), "linear"),
        (15, K((1.45, 0.1, -1.0), -22, -100, elbow=(0.8, 0.3, 0.4), hips=(-4, -46, 0), move=(0, -0.42, -0.2), chest=(-10, -18, 0),
               head=(6, 54, 0), free=((-0.8, 0.45, -1.25), (-0.45, -1, 0.25))), "cubic_out"),
        (19, K((1.38, 0.08, -1.02), -18, -95, elbow=(0.8, 0.3, 0.4), hips=(-4, -44, 0), move=(0, -0.41, -0.18), chest=(-10, -16, 0),
               head=(6, 52, 0), free=((-0.8, 0.45, -1.28), (-0.45, -1, 0.25))), "sine_inout"),
        (26, K((1.1, -0.2, -1.2), 5, -35, hips=(-4, -36, 0), move=(0, -0.38, -0.08), chest=(-10, -4, 0),
               head=(7, 34, 0)), "sine_inout"),
        (34, STANCE_K, "linear"),
    ]


def heavy_keys():
    """Overhead cleave: rise and lean back with the blade hanging behind the head, a short telegraph
    that keeps loading, then chop down through the target with the whole body (drop, lunge, lean),
    the tip stopping just off the floor, and a recovery that shows the weight of it."""
    return [
        (0, STANCE_K, "sine_inout"),
        (8, K((1.1, 0.6, -1.2), 75, -5, elbow=(0.8, -0.4, 0.4), hips=(0, -32, 0), move=(0, -0.28, 0.04),
              chest=(0, -2, 0), head=(2, 26, 0), free=((-0.75, 0.7, -1.4), (-0.5, -1, 0.2))), "sine_inout"),
        (16, K((0.95, 1.6, 0.15), 125, -10, elbow=(0.8, 0.2, 0.6), hips=(2, -34, 0), move=(0, -0.22, 0.1),
               chest=(6, -6, 0), head=(-4, 30, 0), free=((-0.75, 0.9, -1.4), (-0.5, -1, 0.2))), "sine_inout"),
        (19, K((0.95, 1.65, 0.3), 140, -10, elbow=(0.8, 0.2, 0.6), hips=(3, -36, 0), move=(0, -0.2, 0.14),
               chest=(8, -8, 0), head=(-6, 32, 0), free=((-0.75, 0.95, -1.35), (-0.5, -1, 0.2))), "quad_in"),
        (22, K((0.85, 1.4, -1.0), 87, 0, elbow=(0.8, -0.6, 0.3), hips=(-4, -24, 0), move=(0, -0.32, -0.1),
               chest=(-8, 0, 0), head=(6, 22, 0), free=((-0.8, 0.45, -1.2), (-0.5, -1, 0.2))), "linear"),
        (25, K((0.5, -0.3, -2.1), -18, -11, elbow=(0.3, -1, 0.3), hips=(-10, -14, 0), move=(0, -0.6, -0.4), chest=(-18, 4, 0),
               head=(10, 6, 0), rear_foot=toe(-20, -24), free=((-1.4, -0.3, -0.4), (-0.4, -1, 0.4))), "quad_out"),
        (28, K((0.45, -0.75, -2.3), -28, -11, elbow=(0.4, -0.6, 0.8), hips=(-13, -12, 0), move=(0, -0.68, -0.44), chest=(-21, 4, 0),
               head=(14, 4, 0), rear_foot=toe(-16, -28), free=((-1.4, -0.35, -0.3), (-0.4, -1, 0.4))), "cubic_out"),
        (34, K((0.46, -0.7, -2.27), -25, -11, elbow=(0.6, -0.8, -0.2), hips=(-12, -13, 0), move=(0, -0.66, -0.42), chest=(-20, 4, 0),
               head=(13, 5, 0), rear_foot=toe(-17, -27), free=((-1.4, -0.3, -0.35), (-0.4, -1, 0.4))), "sine_inout"),
        (46, K((0.55, -0.5, -1.9), -8, 8, hips=(-9, -22, 0), move=(0, -0.5, -0.22), chest=(-16, 6, 0),
               head=(10, 16, 0), rear_foot=toe(-36, -12), free=((-1.0, 0.2, -1.2), (-0.5, -1, 0.3))), "sine_inout"),
        (60, STANCE_K, "linear"),
    ]


def slash(name, keys, n=1):
    a = timeline(name, keys, priority="Action", style="snappy")
    return a.marker(8, "TrailOn").marker(12, "Hit", str(n)).marker(15, "TrailOff")


def heavy(name):
    a = timeline(name, heavy_keys(), priority="Action", style="snappy")
    return a.marker(16, "Windup").marker(19, "TrailOn").marker(25, "Hit", "heavy").marker(27, "TrailOff")
