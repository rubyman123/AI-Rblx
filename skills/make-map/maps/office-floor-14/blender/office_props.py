"""Office Floor 14: procedural office props in Blender (CC0, made here). Map tool for MapKit by fwjelaa.

Every prop is built in metres around the origin, its front facing Blender +Y (Roblox -Z after the kit's prep),
from beveled, smooth-shaded parts. Each object is named `<part>.<mat>`: the map's build gives every mat key a
Roblox material, colour or MaterialVariant (screens and LEDs become Neon / SurfaceGuis there).

Live Blender:  exec(open(path).read()); build_all(preview=True)
Headless:      blender -b --factory-startup -P office_props.py -- --out <dir> [--only a,b]
               (writes <dir>/<name>.glb, one per prop, for `maps/office-floor-14/props.py`)"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

UV_METRES = 0.5  # one UV unit = this many metres (box projection, same density everywhere)

PREVIEW_COLORS = {
    "upholstery": (0.05, 0.055, 0.06), "plastic_black": (0.02, 0.02, 0.022), "plastic_dark": (0.05, 0.05, 0.055),
    "plastic_grey": (0.3, 0.3, 0.31), "plastic_white": (0.75, 0.74, 0.7), "chrome": (0.8, 0.8, 0.82),
    "alu": (0.55, 0.56, 0.58), "paint_metal": (0.12, 0.13, 0.14), "cabinet_grey": (0.55, 0.54, 0.5),
    "oak": (0.55, 0.4, 0.25), "walnut": (0.2, 0.12, 0.07), "screen": (0.005, 0.006, 0.008),
    "screen_lcd": (0.2, 0.25, 0.15), "led_green": (0.1, 1, 0.2), "led_amber": (1, 0.6, 0.05),
    "led_blue": (0.1, 0.4, 1), "led_white": (1, 1, 1), "neon_white": (1, 1, 0.95), "tube": (0.9, 0.9, 0.9),
    "glass": (0.6, 0.7, 0.75), "glass_dark": (0.02, 0.02, 0.025), "water": (0.4, 0.6, 0.85),
    "paint_red": (0.6, 0.03, 0.03), "rubber": (0.02, 0.02, 0.02), "paper": (0.9, 0.9, 0.88),
    "ceramic": (0.85, 0.85, 0.82), "plastic_red": (0.6, 0.05, 0.05), "plastic_blue": (0.05, 0.15, 0.6),
    "plastic_yellow": (0.8, 0.6, 0.05), "plastic_green": (0.05, 0.4, 0.15), "plastic_orange": (0.85, 0.35, 0.05),
    "paint_black": (0.015, 0.015, 0.017), "cable": (0.03, 0.03, 0.035),
}


# ---------- helpers ----------

def material(key):
    m = bpy.data.materials.get(key)
    if not m:
        m = bpy.data.materials.new(key)
        c = PREVIEW_COLORS.get(key, (0.5, 0.5, 0.5))
        m.diffuse_color = (*c, 1)
        try:
            m.use_nodes = True
            bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = (*c, 1)
        except Exception:  # noqa: BLE001
            pass
    return m


class Part:
    """Accumulates geometry for one object (one material) in a bmesh."""

    def __init__(self, name, mat):
        self.name, self.mat = name, mat
        self.bm = bmesh.new()

    def _add(self, geom_fn, matrix, bevel=0.0, segs=2, taper_top=0.0):
        tmp = bmesh.new()
        geom_fn(tmp)
        if taper_top:
            top = max(v.co.z for v in tmp.verts)
            for v in tmp.verts:
                if abs(v.co.z - top) < 1e-6:
                    v.co.x *= 1 - taper_top
                    v.co.y *= 1 - taper_top
        if bevel > 0:
            edges = [e for e in tmp.edges if not e.is_manifold or e.calc_face_angle(0) > 0.35]
            bmesh.ops.bevel(tmp, geom=edges, offset=bevel, segments=segs, profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        return self

    def box(self, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segs=2, taper_top=0.0):
        sx, sy, sz = size

        def g(b):
            bmesh.ops.create_cube(b, size=1.0)
            bmesh.ops.scale(b, vec=Vector((sx, sy, sz)), verts=b.verts)
        return self._add(g, xform(loc, rot), min(bevel, min(size) * 0.49), segs, taper_top / max(sx, sy) if taper_top else 0)

    def cyl(self, r, depth, loc=(0, 0, 0), rot=(0, 0, 0), r2=None, segs=20, bevel=0.0, bsegs=2, caps=True):
        def g(b):
            bmesh.ops.create_cone(b, cap_ends=caps, cap_tris=False, segments=segs, radius1=r,
                                  radius2=r if r2 is None else r2, depth=depth)
        return self._add(g, xform(loc, rot), bevel, bsegs)

    def sphere(self, radii, loc=(0, 0, 0), rot=(0, 0, 0), u=16, v=10):
        def g(b):
            bmesh.ops.create_uvsphere(b, u_segments=u, v_segments=v, radius=1.0)
            bmesh.ops.scale(b, vec=Vector(radii), verts=b.verts)
        return self._add(g, xform(loc, rot))

    def raw(self, fn, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segs=2):
        return self._add(fn, xform(loc, rot), bevel, segs)

    def finish(self, smooth_angle=35):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for loop in f.loops:
                c = loop.vert.co
                a, b = ((c.y, c.z), (c.x, c.z), (c.x, c.y))[ax]
                loop[uv].uv = (a / UV_METRES, b / UV_METRES)
        me = bpy.data.meshes.new(f"{self.name}.{self.mat}")
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        try:
            me.set_sharp_from_angle(angle=math.radians(smooth_angle))
        except Exception:  # noqa: BLE001
            pass
        ob = bpy.data.objects.new(f"{self.name}.{self.mat}", me)
        me.materials.append(material(self.mat))
        return ob


def xform(loc, rot):
    return Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") \
        @ Matrix.Rotation(rot[0], 4, "X")


def between(p, a, b, r, segs=12):
    """A cylinder from a to b (a cable, a tube, a rod)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    return p.cyl(r, d.length, loc=(a + b) / 2, rot=(rot.x, rot.y, rot.z), segs=segs)


def rad(d):
    return math.radians(d)


# ---------- props ----------

def office_chair():
    base, cast, chrome = Part("base", "plastic_black"), Part("casters", "plastic_dark"), Part("lift", "chrome")
    seat, back = Part("seat", "upholstery"), Part("back", "upholstery")
    shell, arms = Part("shell", "plastic_black"), Part("arms", "plastic_dark")
    base.cyl(0.045, 0.06, loc=(0, 0, 0.09), segs=16, bevel=0.006)
    for i in range(5):
        a = rad(90 + i * 72)
        c, s = math.cos(a), math.sin(a)
        base.box((0.29, 0.045, 0.032), loc=(c * 0.18, s * 0.18, 0.083), rot=(0, rad(5), a), bevel=0.008, taper_top=0.01)
        base.cyl(0.012, 0.03, loc=(c * 0.315, s * 0.315, 0.06), segs=10)
        for side in (-1, 1):  # twin-wheel caster
            cast.cyl(0.026, 0.014, loc=(c * 0.315 - s * 0.012 * side, s * 0.315 + c * 0.012 * side, 0.026),
                     rot=(0, rad(90), a + rad(90)), segs=10)
        cast.box((0.035, 0.04, 0.02), loc=(c * 0.315, s * 0.315, 0.05), rot=(0, 0, a), bevel=0.006, segs=1)
    base.cyl(0.032, 0.17, loc=(0, 0, 0.2), segs=16)  # lift sleeve
    chrome.cyl(0.022, 0.15, loc=(0, 0, 0.35), segs=16)
    base.box((0.22, 0.24, 0.05), loc=(0, -0.01, 0.43), bevel=0.01)  # tilt mechanism
    between(base, (0.1, 0.06, 0.425), (0.24, 0.1, 0.42), 0.007, 8)
    base.sphere((0.016, 0.016, 0.016), loc=(0.245, 0.102, 0.42), u=10, v=6)
    shell.box((0.47, 0.45, 0.022), loc=(0, 0.01, 0.462), bevel=0.01)

    def cushion(b, w, d, h, nx, ny):
        bmesh.ops.create_grid(b, x_segments=nx, y_segments=ny, size=0.5)
        top = list(b.faces)
        res = bmesh.ops.extrude_face_region(b, geom=top)
        verts = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(b, vec=Vector((0, 0, -1)), verts=verts)
        for v in b.verts:
            x, y, z = v.co.x * 2, v.co.y * 2, v.co.z  # -1..1, z 0 or -1
            bulge = (1 - x * x) * (1 - y * y)
            v.co = Vector((x * w / 2, y * d / 2, (z + 1) * h * (0.55 + 0.45 * bulge) if z > -0.5 else 0))
        bmesh.ops.recalc_face_normals(b, faces=b.faces)

    seat.raw(lambda b: cushion(b, 0.5, 0.48, 0.075, 6, 6), loc=(0, 0.02, 0.473), bevel=0.012, segs=2)
    # backrest: curved, leaning back 12 degrees, its front facing +Y
    def back_geo(b):
        cushion(b, 0.46, 0.56, 0.06, 6, 6)
        for v in b.verts:
            v.co.z += 0.045 * (v.co.x / 0.23) ** 2  # sides wrap toward the sitter
    back.raw(back_geo, loc=(0, -0.235, 0.84), rot=(rad(-90 + 12), 0, 0), bevel=0.01, segs=2)
    shell.box((0.47, 0.03, 0.57), loc=(0, -0.274, 0.832), rot=(rad(12), 0, 0), bevel=0.012)
    shell.box((0.06, 0.035, 0.36), loc=(0, -0.2, 0.6), rot=(rad(30), 0, 0), bevel=0.01)  # spine
    for sx in (-1, 1):
        arms.box((0.03, 0.05, 0.2), loc=(sx * 0.26, 0.0, 0.56), bevel=0.008)
        arms.box((0.04, 0.12, 0.02), loc=(sx * 0.24, 0.0, 0.465), bevel=0.006)
        arms.box((0.075, 0.26, 0.03), loc=(sx * 0.265, 0.01, 0.675), bevel=0.012)
    return [p.finish() for p in (base, cast, chrome, seat, back, shell, arms)]


def monitor():
    h, s, scr, led = Part("housing", "plastic_black"), Part("stand", "plastic_dark"), Part("screen", "screen"), Part("led", "led_white")
    s.box((0.24, 0.19, 0.014), loc=(0, -0.03, 0.007), bevel=0.012, segs=3)
    s.box((0.055, 0.024, 0.36), loc=(0, -0.055, 0.19), rot=(rad(-4), 0, 0), bevel=0.008)
    h.box((0.552, 0.028, 0.332), loc=(0, 0, 0.385), bevel=0.005, segs=2)
    h.box((0.3, 0.035, 0.2), loc=(0, -0.025, 0.38), bevel=0.02, segs=3)
    scr.box((0.527, 0.002, 0.298), loc=(0, 0.0145, 0.392))
    led.box((0.006, 0.002, 0.003), loc=(0.24, 0.0146, 0.226))
    return [p.finish() for p in (h, s, scr, led)]


def keyboard():
    base, keys = Part("base", "plastic_black"), Part("keys", "plastic_dark")
    base.box((0.44, 0.145, 0.018), loc=(0, 0, 0.009), bevel=0.004)
    pitch, cap = 0.019, 0.0165
    # front (the typist's side) is +Y: function row at the back, space bar at the front
    rows = [(-0.038, 13, 0.0), (-0.019, 13, 0.005), (0.0, 12, 0.008), (0.019, 11, 0.013)]
    x0 = -0.205
    for y, n, off in rows:
        for i in range(n):
            keys.box((cap, cap, 0.008), loc=(x0 + off + i * pitch + cap / 2, y, 0.022), taper_top=0.003)
    for i, (x, w) in enumerate(((-0.195, 0.022), (-0.17, 0.022), (-0.145, 0.022), (-0.06, 0.11), (0.02, 0.022), (0.045, 0.022), (0.07, 0.022))):
        keys.box((w, cap, 0.008), loc=(x, 0.038, 0.022), taper_top=0.003)  # bottom row and space bar
    for i in range(12):  # function row
        keys.box((cap, 0.012, 0.006), loc=(x0 + 0.02 + i * pitch, -0.058, 0.021))
    for r in range(5):  # numpad
        for c in range(4):
            keys.box((cap, cap, 0.008), loc=(0.135 + c * pitch, -0.038 + r * 0.019, 0.022), taper_top=0.003)
    return [base.finish(), keys.finish(smooth_angle=20)]


def mouse():
    m = Part("mouse", "plastic_black")
    m.sphere((0.031, 0.056, 0.019), loc=(0, 0, 0.012), u=18, v=10)
    return [m.finish(smooth_angle=80)]


def pc_tower():
    c, f, led = Part("case", "plastic_black"), Part("front", "plastic_dark"), Part("led", "led_blue")
    c.box((0.19, 0.42, 0.43), loc=(0, 0, 0.215 + 0.01), bevel=0.005)
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.cyl(0.012, 0.01, loc=(sx * 0.07, sy * 0.18, 0.005), segs=10)
    f.box((0.186, 0.012, 0.425), loc=(0, 0.212, 0.225), bevel=0.004)
    for i in range(9):
        f.box((0.15, 0.004, 0.006), loc=(0, 0.219, 0.06 + i * 0.022))
    f.box((0.13, 0.004, 0.04), loc=(0, 0.219, 0.37), bevel=0.002)  # drive bay
    led.cyl(0.009, 0.004, loc=(0, 0.219, 0.415), rot=(rad(90), 0, 0), segs=14)
    return [p.finish() for p in (c, f, led)]


def desk_phone():
    body, keys, disp, hs = Part("body", "plastic_dark"), Part("keys", "plastic_grey"), Part("display", "screen_lcd"), Part("handset", "plastic_black")

    def wedge(b):
        bmesh.ops.create_cube(b, size=1.0)
        bmesh.ops.scale(b, vec=Vector((0.21, 0.2, 0.08)), verts=b.verts)
        for v in b.verts:
            if v.co.z > 0 and v.co.y > 0:
                v.co.z -= 0.045  # slope down to the front
            v.co.z += 0.04
    body.raw(wedge, bevel=0.008, segs=2)
    slope = math.atan2(0.045, 0.2)
    for r in range(4):
        for c in range(3):
            y = 0.06 - r * 0.026
            z = 0.04 + 0.04 - 0.045 * (0.5 + y / 0.2) + 0.006
            keys.box((0.017, 0.013, 0.006), loc=(0.02 + c * 0.024, y, z), rot=(-slope, 0, 0), bevel=0.002)
    disp.box((0.07, 0.04, 0.003), loc=(0.045, -0.055, 0.0715), rot=(-slope, 0, 0))
    body.box((0.062, 0.19, 0.05), loc=(-0.07, 0, 0.058), bevel=0.008)  # handset cradle
    hs.box((0.052, 0.21, 0.03), loc=(-0.07, 0.0, 0.098), bevel=0.012, segs=3)
    for y in (-0.085, 0.085):
        hs.box((0.056, 0.06, 0.025), loc=(-0.07, y, 0.082), bevel=0.01, segs=2)
    return [p.finish() for p in (body, keys, disp, hs)]


def office_desk():
    top, frame = Part("top", "oak"), Part("frame", "paint_metal")
    top.box((1.6, 0.8, 0.025), loc=(0, 0, 0.7375), bevel=0.004, segs=2)
    for sx in (-1, 1):
        x = sx * 0.74
        for sy in (-1, 1):
            frame.box((0.05, 0.05, 0.69), loc=(x, sy * 0.33, 0.37), bevel=0.004)
        frame.box((0.05, 0.71, 0.04), loc=(x, 0, 0.705), bevel=0.004)
        frame.box((0.06, 0.74, 0.03), loc=(x, 0, 0.015), bevel=0.004)
    frame.box((1.43, 0.012, 0.32), loc=(0, -0.355, 0.53), bevel=0.003)  # modesty panel
    frame.box((1.0, 0.12, 0.004), loc=(0, -0.29, 0.66))  # cable tray floor
    frame.box((1.0, 0.004, 0.06), loc=(0, -0.235, 0.69))
    return [top.finish(), frame.finish()]


def pedestal():
    body, fronts, handles = Part("body", "cabinet_grey"), Part("fronts", "cabinet_grey"), Part("handles", "alu")
    body.box((0.42, 0.55, 0.58), loc=(0, 0, 0.3), bevel=0.004)
    z = 0.58 + 0.02
    for h in (0.12, 0.12, 0.29):
        zc = z - h / 2 - 0.004
        fronts.box((0.41, 0.018, h - 0.006), loc=(0, 0.281, zc), bevel=0.003)
        handles.box((0.16, 0.022, 0.012), loc=(0, 0.296, zc + h / 2 - 0.03), bevel=0.004)
        z -= h + 0.002
    handles.cyl(0.009, 0.01, loc=(0.17, 0.292, 0.555), rot=(rad(90), 0, 0), segs=12)
    return [p.finish() for p in (body, fronts, handles)]


def filing_cabinet(open_top=False):
    body, fronts, handles, inside = Part("body", "cabinet_grey"), Part("fronts", "cabinet_grey"), Part("handles", "chrome"), Part("folders", "paper")
    body.box((0.47, 0.62, 1.32), loc=(0, 0, 0.66), bevel=0.004)
    for i in range(4):
        zc = 0.04 + 0.32 * i + 0.155
        y = 0.311 + (0.22 if open_top and i == 3 else 0)
        fronts.box((0.455, 0.02, 0.305), loc=(0, y, zc), bevel=0.003)
        handles.box((0.2, 0.025, 0.022), loc=(0, y + 0.018, zc + 0.08), bevel=0.006)
        handles.box((0.08, 0.004, 0.04), loc=(0, y + 0.011, zc + 0.12), bevel=0.002)  # label holder
        if open_top and i == 3:
            for sx in (-1, 1):
                fronts.box((0.012, 0.3, 0.24), loc=(sx * 0.21, y - 0.16, zc - 0.02))
            fronts.box((0.42, 0.3, 0.01), loc=(0, y - 0.16, zc - 0.14))
            for k in range(10):  # hanging folders, leaning
                inside.box((0.38, 0.004, 0.22), loc=(0, y - 0.03 - k * 0.026, zc - 0.03), rot=(rad(8 if k % 3 else -5), 0, 0))
    out = [body.finish(), fronts.finish(), handles.finish()]
    if open_top:
        out.append(inside.finish())
    return out


def filing_cabinet_open():
    return filing_cabinet(open_top=True)


def printer():
    body, trays, dark, lid, scr, paper, led = (Part("body", "plastic_white"), Part("trays", "plastic_grey"), Part("panel", "plastic_dark"),
                                              Part("scanner", "plastic_grey"), Part("display", "screen_lcd"), Part("paper", "paper"), Part("led", "led_green"))
    body.box((0.6, 0.62, 0.46), loc=(0, 0, 0.24), bevel=0.008)
    for i, zc in enumerate((0.13, 0.35)):
        trays.box((0.56, 0.02, 0.19), loc=(0, 0.315, zc), bevel=0.006)
        dark.box((0.14, 0.012, 0.025), loc=(0, 0.328, zc + 0.06), bevel=0.005)
    body.box((0.6, 0.62, 0.2), loc=(0, 0, 0.57), bevel=0.008)
    body.box((0.6, 0.45, 0.07), loc=(0, -0.085, 0.705), bevel=0.008)
    dark.box((0.5, 0.42, 0.06), loc=(0, 0.06, 0.71))  # output bay
    paper.box((0.21, 0.297, 0.004), loc=(0.02, 0.1, 0.682), rot=(0, 0, rad(4)))
    paper.box((0.21, 0.297, 0.004), loc=(0.0, 0.11, 0.686), rot=(0, 0, rad(-3)))
    body.box((0.6, 0.6, 0.11), loc=(0, -0.01, 0.795), bevel=0.008)
    lid.box((0.6, 0.6, 0.04), loc=(0, -0.01, 0.87), bevel=0.01)
    lid.box((0.5, 0.35, 0.05), loc=(0, -0.05, 0.915), bevel=0.012)  # document feeder
    dark.box((0.3, 0.13, 0.03), loc=(0.12, 0.33, 0.83), rot=(rad(25), 0, 0), bevel=0.008)
    scr.box((0.12, 0.07, 0.003), loc=(0.07, 0.336, 0.847), rot=(rad(25), 0, 0))
    led.box((0.008, 0.008, 0.004), loc=(0.23, 0.338, 0.843), rot=(rad(25), 0, 0))
    return [p.finish() for p in (body, trays, dark, lid, scr, paper, led)]


def water_cooler():
    body, rec, taps_r, taps_b, bottle, water = (Part("body", "plastic_white"), Part("recess", "plastic_dark"), Part("tap_hot", "plastic_red"),
                                               Part("tap_cold", "plastic_blue"), Part("bottle", "water"), Part("fill", "water"))
    body.box((0.31, 0.33, 0.95), loc=(0, 0, 0.475), bevel=0.02, segs=3)
    rec.box((0.2, 0.03, 0.26), loc=(0, 0.155, 0.72), bevel=0.01)
    rec.box((0.2, 0.08, 0.02), loc=(0, 0.17, 0.6), bevel=0.006)  # drip tray
    taps_r.box((0.035, 0.03, 0.04), loc=(-0.05, 0.175, 0.8), bevel=0.008)
    taps_b.box((0.035, 0.03, 0.04), loc=(0.05, 0.175, 0.8), bevel=0.008)
    body.cyl(0.07, 0.03, loc=(0, 0, 0.965), segs=24)  # collar
    bottle.cyl(0.03, 0.06, loc=(0, 0, 0.99), segs=16)
    bottle.cyl(0.135, 0.44, loc=(0, 0, 1.26), segs=28, bevel=0.04, bsegs=3)
    water.cyl(0.128, 0.22, loc=(0, 0, 1.14), segs=28, bevel=0.03, bsegs=2)
    return [p.finish() for p in (body, rec, taps_r, taps_b, bottle, water)]


def vending_machine():
    cab, inside, glass, shelves, panel, keys, disp, light = (Part("cabinet", "paint_metal"), Part("inside", "plastic_dark"), Part("glass", "glass"),
                                                             Part("shelves", "chrome"), Part("panel", "plastic_black"), Part("keypad", "chrome"),
                                                             Part("display", "screen_lcd"), Part("light", "neon_white"))
    W, D, H = 0.95, 0.85, 1.83
    cab.box((W, D - 0.05, H), loc=(0, -0.025, H / 2), bevel=0.01)
    cab.box((W, 0.05, 0.12), loc=(0, D / 2 - 0.025, 1.77), bevel=0.006)  # header
    cab.box((W, 0.05, 0.4), loc=(0, D / 2 - 0.025, 0.2), bevel=0.006)  # kick panel
    cab.box((0.05, 0.05, 1.3), loc=(-W / 2 + 0.025, D / 2 - 0.025, 1.05))
    cab.box((0.04, 0.05, 1.3), loc=(0.2, D / 2 - 0.025, 1.05))
    inside.box((0.61, 0.02, 1.3), loc=(-0.095, 0.08, 1.05))
    glass.box((0.63, 0.008, 1.3), loc=(-0.095, D / 2 - 0.01, 1.05))
    prods = {k: Part(f"items_{k}", f"plastic_{k}") for k in ("red", "yellow", "blue", "green", "orange")}
    keys_ = list(prods)
    for row in range(6):
        z = 0.47 + row * 0.2
        shelves.box((0.6, 0.32, 0.008), loc=(-0.095, 0.25, z))
        for i in range(6):
            k = keys_[(row * 2 + i // 2) % len(keys_)]
            x = -0.36 + i * 0.1
            if (row * 7 + i * 3) % 11 == 0:
                continue  # an empty slot
            if row % 2:
                prods[k].cyl(0.032, 0.12, loc=(x, 0.33, z + 0.064), segs=12)
            else:
                prods[k].box((0.075, 0.03, 0.15), loc=(x, 0.34, z + 0.08), rot=(rad(-8), 0, 0), bevel=0.008)
            between(shelves, (x, 0.12, z + 0.03), (x, 0.36, z + 0.03), 0.004, 6)
    panel.box((0.2, 0.02, 1.25), loc=(0.33, D / 2 - 0.01, 1.07), bevel=0.004)
    disp.box((0.12, 0.004, 0.05), loc=(0.33, D / 2 + 0.002, 1.5))
    for r in range(4):
        for c in range(3):
            keys.box((0.03, 0.01, 0.025), loc=(0.29 + c * 0.04, D / 2 + 0.004, 1.38 - r * 0.035), bevel=0.003)
    keys.box((0.06, 0.012, 0.012), loc=(0.33, D / 2 + 0.004, 1.17), bevel=0.003)  # coin slot
    keys.box((0.09, 0.015, 0.03), loc=(0.33, D / 2 + 0.006, 1.08), bevel=0.004)  # bill acceptor
    panel.box((0.62, 0.03, 0.19), loc=(-0.095, D / 2 - 0.01, 0.27), bevel=0.01)  # pickup flap
    light.box((0.012, 0.012, 1.25), loc=(-0.4, D / 2 - 0.04, 1.05))
    out = [p.finish() for p in (cab, inside, glass, shelves, panel, keys, disp, light)]
    out += [p.finish() for p in prods.values()]
    return out


def server_rack(seed=1):
    import random
    rnd = random.Random(seed)
    frame, rails, units, bays = Part("frame", "paint_black"), Part("rails", "chrome"), Part("units", "plastic_dark"), Part("bays", "plastic_grey")
    leds = {k: Part(f"leds_{k}", f"led_{k}") for k in ("green", "amber", "blue")}
    W, D, H = 0.6, 1.0, 2.0
    for sx in (-1, 1):
        frame.box((0.02, D, H), loc=(sx * (W / 2 - 0.01), 0, H / 2), bevel=0.003)
        rails.box((0.02, 0.02, 1.85), loc=(sx * 0.235, D / 2 - 0.06, 1.0))
    frame.box((W, D, 0.04), loc=(0, 0, H - 0.02), bevel=0.003)
    frame.box((W, D, 0.08), loc=(0, 0, 0.04), bevel=0.003)
    frame.box((W - 0.04, 0.02, H - 0.1), loc=(0, -D / 2 + 0.01, H / 2))
    z, U = 0.1, 0.0445
    while z < 1.9:
        n = rnd.choice((1, 1, 2, 2, 2, 4, 0))
        if n == 0:
            frame.box((0.48, 0.006, U - 0.002), loc=(0, D / 2 - 0.06, z + U / 2))  # blank panel
            z += U
            continue
        h = n * U
        if z + h > 1.9:
            break
        y = D / 2 - 0.05
        units.box((0.44, 0.03, h - 0.003), loc=(0, y, z + h / 2))
        for sx in (-1, 1):
            units.box((0.025, 0.012, min(h - 0.006, 0.07)), loc=(sx * 0.232, y + 0.01, z + h / 2))
        nb = 8 if n >= 2 else 4
        for i in range(nb):
            bx = -0.16 + i * (0.32 / max(1, nb - 1)) if nb > 1 else 0
            bh = (h - 0.012) / (2 if n >= 2 else 1)
            for r in range(2 if n >= 2 else 1):
                bz = z + 0.006 + bh / 2 + r * bh
                bays.box((0.034, 0.008, bh - 0.004), loc=(bx, y + 0.018, bz))
                if rnd.random() < 0.8:
                    k = rnd.choice(("green", "green", "green", "amber", "blue"))
                    leds[k].box((0.004, 0.003, 0.003), loc=(bx + 0.012, y + 0.023, bz + bh / 2 - 0.006))
        leds["blue" if rnd.random() < 0.5 else "green"].box((0.006, 0.003, 0.004), loc=(0.2, y + 0.017, z + h / 2))
        z += h
    out = [p.finish() for p in (frame, rails, units, bays)]
    out += [p.finish(smooth_angle=10) for p in leds.values() if p.bm.verts]
    return out


def server_rack_b():
    return server_rack(seed=7)


def troffer():
    # a recessed 2x4 parabolic troffer: its face is the bottom (z = 0), the can rises above the ceiling
    frame, louver, refl, tubes = Part("frame", "plastic_white"), Part("louver", "chrome"), Part("reflector", "plastic_white"), Part("tubes", "tube")
    L, Wd = 1.22, 0.61
    for sx in (-1, 1):
        frame.box((0.025, L, 0.012), loc=(sx * (Wd / 2 - 0.0125), 0, 0.006))
    for sy in (-1, 1):
        frame.box((Wd, 0.025, 0.012), loc=(0, sy * (L / 2 - 0.0125), 0.006))
    refl.box((Wd - 0.05, L - 0.05, 0.004), loc=(0, 0, 0.11))
    for sx in (-1, 1):
        refl.box((0.004, L - 0.05, 0.11), loc=(sx * (Wd / 2 - 0.027), 0, 0.058), rot=(0, rad(sx * -12), 0))
    for i in range(1, 3):
        x = -Wd / 2 + 0.025 + i * (Wd - 0.05) / 3
        louver.box((0.003, L - 0.05, 0.05), loc=(x, 0, 0.03))
    for j in range(1, 8):
        y = -L / 2 + 0.025 + j * (L - 0.05) / 8
        louver.box((Wd - 0.05, 0.003, 0.05), loc=(0, y, 0.03))
    for x in (-0.1, 0.1):
        tubes.cyl(0.013, L - 0.09, loc=(x, 0, 0.085), rot=(rad(90), 0, 0), segs=10)
    return [p.finish() for p in (frame, louver, refl, tubes)]


def diffuser():
    d = Part("diffuser", "plastic_white")
    s = 0.6
    for i in range(4):
        w = s - i * 0.12
        t = 0.03
        z = i * 0.025
        for sx in (-1, 1):
            d.box((t, w, 0.02), loc=(sx * (w / 2 - t / 2), 0, z + 0.01), rot=(0, rad(sx * 30), 0))
        for sy in (-1, 1):
            d.box((w, t, 0.02), loc=(0, sy * (w / 2 - t / 2), z + 0.01), rot=(rad(-sy * 30), 0, 0))
    d.box((0.12, 0.12, 0.01), loc=(0, 0, 0.1))
    return [d.finish()]


def trash_bin():
    b = Part("bin", "plastic_black")

    def g(bm):
        bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=0.105, radius2=0.135, depth=0.33)
        inner = bmesh.new()
        bmesh.ops.create_cone(inner, cap_ends=False, segments=24, radius1=0.1, radius2=0.13, depth=0.325)
        me = bpy.data.meshes.new("t")
        bmesh.ops.reverse_faces(inner, faces=inner.faces)
        bmesh.ops.translate(inner, vec=Vector((0, 0, 0.0025)), verts=inner.verts)
        inner.to_mesh(me)
        inner.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        bmesh.ops.translate(bm, vec=Vector((0, 0, 0.165)), verts=bm.verts)
    b.raw(g)
    b.cyl(0.105, 0.005, loc=(0, 0, 0.0025), segs=24)
    return [b.finish(smooth_angle=60)]


def fire_extinguisher():
    body, chrome, black, label = Part("body", "paint_red"), Part("valve", "chrome"), Part("hose", "rubber"), Part("label", "paper")
    body.cyl(0.075, 0.42, loc=(0, 0, 0.23), segs=24, bevel=0.03, bsegs=3)
    body.sphere((0.072, 0.072, 0.05), loc=(0, 0, 0.43), u=20, v=8)
    label.cyl(0.0765, 0.14, loc=(0, 0, 0.25), segs=24, caps=False)
    chrome.cyl(0.02, 0.06, loc=(0, 0, 0.5), segs=12)
    chrome.box((0.03, 0.09, 0.015), loc=(0, 0.03, 0.535), rot=(rad(10), 0, 0), bevel=0.004)
    black.box((0.03, 0.1, 0.012), loc=(0, 0.02, 0.555), rot=(rad(-12), 0, 0), bevel=0.004)
    pts = [(0, -0.02, 0.51), (0, -0.06, 0.48), (0, -0.085, 0.4), (0, -0.088, 0.25), (0, -0.085, 0.16)]
    for a, b in zip(pts, pts[1:]):
        between(black, a, b, 0.009, 10)
    black.cyl(0.014, 0.05, loc=(0, -0.085, 0.13), segs=10)
    return [p.finish() for p in (body, chrome, black, label)]


def microwave():
    body, door, win, panel, disp = Part("body", "plastic_white"), Part("door", "plastic_black"), Part("window", "glass_dark"), Part("panel", "plastic_dark"), Part("display", "screen_lcd")
    body.box((0.48, 0.36, 0.28), loc=(0, 0, 0.14), bevel=0.008)
    door.box((0.34, 0.012, 0.25), loc=(-0.06, 0.183, 0.14), bevel=0.006)
    win.box((0.24, 0.004, 0.16), loc=(-0.07, 0.19, 0.14))
    panel.box((0.11, 0.008, 0.25), loc=(0.175, 0.181, 0.14), bevel=0.004)
    disp.box((0.07, 0.003, 0.025), loc=(0.175, 0.186, 0.235))
    for r in range(4):
        for c in range(3):
            panel.box((0.02, 0.006, 0.014), loc=(0.15 + c * 0.025, 0.186, 0.19 - r * 0.025), bevel=0.002)
    return [p.finish() for p in (body, door, win, panel, disp)]


def fridge():
    body, doors, handles = Part("body", "plastic_white"), Part("doors", "plastic_white"), Part("handles", "chrome")
    body.box((0.6, 0.62, 1.78), loc=(0, -0.02, 0.89), bevel=0.01)
    doors.box((0.6, 0.05, 0.46), loc=(0, 0.315, 1.545), bevel=0.012, segs=3)
    doors.box((0.6, 0.05, 1.28), loc=(0, 0.315, 0.665), bevel=0.012, segs=3)
    handles.box((0.02, 0.035, 0.2), loc=(-0.26, 0.355, 1.43), bevel=0.008)
    handles.box((0.02, 0.035, 0.45), loc=(-0.26, 0.355, 1.0), bevel=0.008)
    return [p.finish() for p in (body, doors, handles)]


def coffee_machine():
    body, chrome, disp, tank = Part("body", "plastic_black"), Part("trim", "chrome"), Part("display", "screen_lcd"), Part("tank", "glass_dark")
    body.box((0.3, 0.42, 0.44), loc=(0, 0, 0.22), bevel=0.02, segs=3)
    chrome.box((0.2, 0.05, 0.02), loc=(0, 0.2, 0.32), bevel=0.006)
    chrome.box((0.03, 0.03, 0.05), loc=(0, 0.2, 0.29), bevel=0.008)  # spout
    chrome.box((0.22, 0.14, 0.02), loc=(0, 0.19, 0.03), bevel=0.006)  # drip grate
    disp.box((0.1, 0.003, 0.05), loc=(0, 0.211, 0.39))
    tank.box((0.06, 0.25, 0.3), loc=(0.17, -0.05, 0.26), bevel=0.01)
    return [p.finish() for p in (body, chrome, disp, tank)]


def mug():
    m = Part("mug", "ceramic")

    def g(bm):
        bmesh.ops.create_cone(bm, cap_ends=False, segments=20, radius1=0.04, radius2=0.042, depth=0.095)
        inner = bmesh.new()
        bmesh.ops.create_cone(inner, cap_ends=False, segments=20, radius1=0.035, radius2=0.037, depth=0.088)
        bmesh.ops.reverse_faces(inner, faces=inner.faces)
        bmesh.ops.translate(inner, vec=Vector((0, 0, 0.0035)), verts=inner.verts)
        me = bpy.data.meshes.new("t")
        inner.to_mesh(me)
        inner.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        bmesh.ops.translate(bm, vec=Vector((0, 0, 0.0475)), verts=bm.verts)
    m.raw(g)
    m.cyl(0.04, 0.006, loc=(0, 0, 0.003), segs=20)
    for i in range(7):  # handle: a bent rod
        a0, a1 = rad(-80 + i * 160 / 7), rad(-80 + (i + 1) * 160 / 7)
        p0 = (0.04 + 0.028 * math.cos(a0), 0, 0.048 + 0.028 * math.sin(a0))
        p1 = (0.04 + 0.028 * math.cos(a1), 0, 0.048 + 0.028 * math.sin(a1))
        between(m, p0, p1, 0.006, 8)
    return [m.finish(smooth_angle=70)]


def conference_table():
    top, base, grom = Part("top", "walnut"), Part("base", "paint_metal"), Part("grommet", "alu")
    a, b0 = 1.8, 0.6

    def outline(bm):
        n = 64
        verts_top, verts_bot = [], []
        for i in range(n):
            t = 2 * math.pi * i / n
            c, s = math.cos(t), math.sin(t)
            x = a * math.copysign(abs(c) ** (2 / 6), c)
            yb = b0 * (1 - 0.18 * (x / a) ** 2)
            y = yb * math.copysign(abs(s) ** (2 / 6), s)
            verts_top.append(bm.verts.new((x, y, 0.02)))
            verts_bot.append(bm.verts.new((x, y, -0.02)))
        bm.faces.new(verts_top)
        bm.faces.new(list(reversed(verts_bot)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((verts_bot[i], verts_bot[j], verts_top[j], verts_top[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    top.raw(outline, loc=(0, 0, 0.72), bevel=0.008, segs=2)
    for x in (-0.9, 0.9):
        base.cyl(0.18, 0.68, loc=(x, 0, 0.36), segs=28, bevel=0.01)
        base.cyl(0.3, 0.02, loc=(x, 0, 0.01), segs=28, bevel=0.006)
    grom.box((0.3, 0.12, 0.004), loc=(0, 0, 0.741), bevel=0.002)
    return [p.finish() for p in (top, base, grom)]


def emergency_light():
    body, lens = Part("body", "plastic_white"), Part("lens", "led_white")
    body.box((0.3, 0.07, 0.11), loc=(0, -0.035, 0.055), bevel=0.012, segs=2)
    for sx in (-1, 1):
        body.sphere((0.045, 0.045, 0.045), loc=(sx * 0.1, 0.02, 0.07), u=14, v=8)
        lens.cyl(0.03, 0.006, loc=(sx * 0.1, 0.064, 0.06), rot=(rad(80), 0, 0), segs=14)
    return [p.finish() for p in (body, lens)]


PROPS = {
    "ofc_task_chair": office_chair, "ofc_monitor": monitor, "ofc_keyboard": keyboard, "ofc_mouse": mouse,
    "ofc_pc": pc_tower, "ofc_desk_phone": desk_phone, "ofc_desk": office_desk, "ofc_pedestal": pedestal,
    "ofc_filing": filing_cabinet, "ofc_filing_open": filing_cabinet_open, "ofc_printer": printer,
    "ofc_water_cooler": water_cooler, "ofc_vending": vending_machine, "ofc_rack_a": server_rack,
    "ofc_rack_b": server_rack_b, "ofc_troffer": troffer, "ofc_diffuser": diffuser, "ofc_bin": trash_bin,
    "ofc_extinguisher": fire_extinguisher, "ofc_microwave": microwave, "ofc_fridge": fridge,
    "ofc_coffee": coffee_machine, "ofc_mug": mug, "ofc_conf_table": conference_table, "ofc_emergency": emergency_light,
}


def build(name, collection=None):
    objs = PROPS[name]()
    # props are modelled facing +Y; measured in Studio, the importer turns Blender +Y into Roblox +Z, and the kit's
    # convention is front = -Z (LookVector), so turn every prop round once here
    for o in objs:
        o.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
    col = collection or bpy.data.collections.new(name)
    if not collection:
        bpy.context.scene.collection.children.link(col)
    for o in objs:
        col.objects.link(o)
    return col, objs


def clear_props():
    for name in PROPS:
        col = bpy.data.collections.get(name)
        if col:
            for o in list(col.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(col)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def export(name, objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT")


def build_all(only=None, out_dir=None, preview=False):
    clear_props()
    report = {}
    x = 0.0
    for name in PROPS:
        if only and name not in only:
            continue
        col, objs = build(name)
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
        report[name] = tris
        if out_dir:
            export(name, objs, f"{out_dir}/{name}.glb")
        if preview:
            for o in objs:
                o.location.x += x
            x += 2.2 if name not in ("ofc_conf_table",) else 4.5
    return report


if __name__ == "__main__" and "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    kv = dict(zip(args[0::2], args[1::2]))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    only = set(kv["--only"].split(",")) if kv.get("--only") else None
    print("PROPS", build_all(only=only, out_dir=kv["--out"]))
