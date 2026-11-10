"""R15 sword idle, snappy: 120-frame loop in the sword guard. Method by fwjelaa.

The R15_Idle body (bounce on bent knees, breath, weight shift; feet planted by IK) holding the sword:
  - the sword wrist rides the chest 5 f late and circles 0.03-0.04 studs
  - the blade rides the chest 11 f late and its point draws a slow 2-3 deg circle, never dead still
  - the free hand rides the chest 7 f late; the head counters the chest 8 f late
Both elbows keep the direction the stance solved for, so they can't flip between keys.
"""
import math

from mathutils import Matrix, Vector

import animkit as ak
from _r15 import _pivot, fighter, fk, reach
from _r15sword import PROPS, STANCE, STANCE_K, SWORD, aim, direction

NAME = "R15_SwordIdle"
LENGTH = 120
BOB = 60  # frames per bounce (divides LENGTH)
STEP = 10  # one key every STEP frames, smoothed with bezier
HAND_LAG, BLADE_LAG, FREE_LAG, HEAD_LAG = 5, 11, 7, 8
TAU = 2 * math.pi

_frames = fk(STANCE)
_chest = _frames["UpperTorso"]
_HAND = _chest.inverted() @ Vector(STANCE_K["hand"])  # sword wrist, chest axes
_BLADE = _chest.to_3x3().inverted() @ direction(STANCE_K["pitch"], STANCE_K["yaw"])
def _hint(side, wrist, preferred, turn):
    """The elbow direction the stance solved for (turned around the shoulder-wrist line), in chest axes."""
    axis = (Vector(wrist) - _pivot(_frames, f"{side}UpperArm").to_translation()).normalized()
    return _chest.to_3x3().inverted() @ (Matrix.Rotation(math.radians(turn), 3, axis) @ Vector(preferred))


_ELBOW = _hint("Right", STANCE_K["hand"], STANCE_K["elbow"], STANCE_K["turn"])
_FREE_ELBOW = _hint("Left", _chest @ Vector(SWORD["lead_fist"][0]), _chest.to_3x3() @ Vector(SWORD["lead_fist"][1]),
                    STANCE_K["free_turn"])
_FREE = Vector(SWORD["lead_fist"][0])


def body(t):
    """Stance parameters at frame t (hands not solved yet)."""
    bob = math.cos(TAU * t / BOB)  # +1 high, -1 low
    breath = math.cos(TAU * (t - 6) / BOB)  # chest opens just after the body rises
    shift = math.sin(TAU * t / LENGTH)  # +1 weight on the rear (right) foot
    hx, hy, hz = SWORD["hips"]
    mx, my, mz = SWORD["move"]
    cx, cy, cz = SWORD["chest"]
    return {
        "hips": (hx + 1.4 * bob, hy + 2.5 * shift, hz + 1.2 * shift),
        "move": (mx + 0.06 * shift, my + 0.06 * bob, mz + 0.025 * bob),
        "chest": (cx + 2.2 * breath, cy - 2.0 * shift, cz - 0.8 * shift),
    }


def chest(t):
    return fk(fighter(SWORD, **body(t)))["UpperTorso"]


def pose_at(t):
    pose = fighter(SWORD, **body(t))
    late = chest(t - FREE_LAG)
    a = TAU * t / BOB
    at = _FREE + Vector((0.03 * math.sin(a + 1.0), 0.04 * math.cos(a + 1.0), 0))
    reach(pose, "Left", late @ at, elbow=late.to_3x3() @ _FREE_ELBOW)
    hand = chest(t - HAND_LAG)
    circle = Vector((0.03 * math.sin(a), 0.04 * math.cos(a), 0.02 * math.sin(TAU * t / LENGTH)))
    reach(pose, "Right", hand @ (_HAND + circle), elbow=hand.to_3x3() @ _ELBOW)
    b = TAU * (t - BLADE_LAG) / LENGTH
    wobble = (Matrix.Rotation(math.radians(2.5 * math.sin(b)), 3, "X")
              @ Matrix.Rotation(math.radians(3.0 * math.cos(b)), 3, "Y"))
    aim(pose, chest(t - BLADE_LAG).to_3x3() @ (wobble @ _BLADE))
    lag = body(t - HEAD_LAG)  # head counters the chest's breath and the hips' turn, a few frames late
    hx, hy, hz = SWORD["head"]
    dx = lag["chest"][0] - SWORD["chest"][0] + lag["hips"][0] - SWORD["hips"][0]
    dy = lag["chest"][1] - SWORD["chest"][1] + lag["hips"][1] - SWORD["hips"][1]
    pose["Head"] = (hx - 0.8 * dx, hy - 0.7 * dy, hz + 0.6 * math.sin(TAU * (t - HEAD_LAG) / LENGTH))
    return pose


def build():
    a = ak.Anim(NAME, rig="R15", props=PROPS, length=LENGTH, loop=True, priority="Idle")
    for t in range(0, LENGTH, STEP):
        a.full(t, pose_at(t), ease="bezier")
    return a
