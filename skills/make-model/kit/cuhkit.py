# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
"""Shared building blocks for the Cuh character models (Blender 5.1, works headless too).

Units are studs: a Cuh stands on z = 0, faces -Y and is about 4 tall. Every builder takes the Cuh's
collection so parts land in one place, and names parts "<Cuh>_<part>" (no dots: metaball families
merge by the name before the dot).

Organic forms (heads, muzzles, bellies, tails) are metaball blends converted to a mesh, so shapes
fuse like clay. Clothes and shoes are blends too, then trimmed. Limbs are tapered curves.
"""
import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

# ---------------------------------------------------------------- scene

def new_scene(cuh: str) -> bpy.types.Collection:
    """Empties the current scene and returns a fresh collection for this Cuh."""
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in list(scene.collection.children):
        bpy.data.collections.remove(coll)
    for block in (bpy.data.meshes, bpy.data.metaballs, bpy.data.curves, bpy.data.materials,
                  bpy.data.lights, bpy.data.cameras, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)
    coll = bpy.data.collections.new(cuh)
    scene.collection.children.link(coll)
    return coll


def _link(obj, coll):
    coll.objects.link(obj)
    return obj


def _active(obj):
    view_layer = bpy.context.view_layer
    for o in view_layer.objects.selected:
        o.select_set(False)
    view_layer.objects.active = obj
    obj.select_set(True)


def smooth(obj, angle=None):
    me = obj.data
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.update()
    return obj


def apply_modifiers(obj):
    _active(obj)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def subdivide(obj, levels=1, render=None):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels if render is None else render
    return mod

# ---------------------------------------------------------------- materials

def _hex(color):
    if isinstance(color, str):
        c = color.lstrip("#")
        srgb = [int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in srgb]
        return (*lin, 1.0)
    return (*color[:3], 1.0)


def mat(name, color, rough=0.5, metal=0.0, coat=0.0, sss=0.0, emit=0.0, sheen=0.0,
        bump=None, bump_scale=40.0, bump_strength=0.25, emit_color=None):
    """Principled material. bump: None, 'pores' (fruit peel), 'fabric', 'skin' or 'scales'."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = _hex(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Sheen Weight"].default_value = sheen
    if sss:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Radius"].default_value = (0.3, 0.12, 0.06)
        bsdf.inputs["Subsurface Scale"].default_value = 0.05
    if emit:
        bsdf.inputs["Emission Color"].default_value = _hex(emit_color or color)
        bsdf.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = _hex(color)
    if bump:
        coord = nt.nodes.new("ShaderNodeTexCoord")
        bmp = nt.nodes.new("ShaderNodeBump")
        bmp.inputs["Strength"].default_value = bump_strength
        if bump in ("pores", "scales"):
            tex = nt.nodes.new("ShaderNodeTexVoronoi")
            tex.inputs["Scale"].default_value = bump_scale
            tex.feature = "F1" if bump == "pores" else "SMOOTH_F1"
            nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeMapRange")
            ramp.inputs["From Min"].default_value = 0.0
            ramp.inputs["From Max"].default_value = 0.45
            if bump == "pores":
                ramp.inputs["To Min"].default_value = 0.0
                ramp.inputs["To Max"].default_value = 1.0
            else:
                ramp.inputs["To Min"].default_value = 1.0
                ramp.inputs["To Max"].default_value = 0.0
            nt.links.new(tex.outputs["Distance"], ramp.inputs["Value"])
            nt.links.new(ramp.outputs["Result"], bmp.inputs["Height"])
        else:
            tex = nt.nodes.new("ShaderNodeTexNoise")
            tex.inputs["Scale"].default_value = bump_scale
            tex.inputs["Detail"].default_value = 6.0 if bump == "fabric" else 3.0
            nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
            nt.links.new(tex.outputs["Fac"], bmp.inputs["Height"])
        nt.links.new(bmp.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def set_mats(obj, *materials):
    obj.data.materials.clear()
    for m in materials:
        obj.data.materials.append(m)
    return obj


def sdf_attr(obj, name, fn):
    """Stores fn(local vertex position) as a per-vertex float. Use a signed distance (> 0 inside the
    region): the shader thresholds it at 0, so region edges stay crisp and smooth across faces."""
    me = obj.data
    attr = me.attributes.get(name) or me.attributes.new(name, "FLOAT", "POINT")
    attr.data.foreach_set("value", [fn(v.co.copy()) for v in me.vertices])
    me.update()


def _socket(node, name, kind):
    return next(s for s in node.inputs if s.name == name and s.type == kind)


def region_mat(name, color, layers, rough=0.4, coat=0.2, sss=0.0, bump=None, bump_scale=40.0,
               bump_strength=0.3, edge=0.004, pore_dark=0.0):
    """One material that paints regions from sdf_attr() fields.

    layers: list of (attribute, color, roughness), painted in order over the base colour.
    The base bump (if any) fades out inside the layers, e.g. fruit pores stop at the muzzle.
    pore_dark darkens the bump's pits in the base colour so pores read from a distance.
    """
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type not in ("OUTPUT_MATERIAL", "BSDF_PRINCIPLED"):
            nt.nodes.remove(n)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Coat Weight"].default_value = coat
    if sss:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Radius"].default_value = (0.3, 0.12, 0.06)
        bsdf.inputs["Subsurface Scale"].default_value = 0.05
    col = nt.nodes.new("ShaderNodeRGB")
    col.outputs[0].default_value = _hex(color)
    col_out = col.outputs[0]
    height = None
    if bump:
        coord = nt.nodes.new("ShaderNodeTexCoord")
        tex = nt.nodes.new("ShaderNodeTexVoronoi")
        tex.inputs["Scale"].default_value = bump_scale
        nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeMapRange")
        ramp.inputs["From Max"].default_value = 0.45
        nt.links.new(tex.outputs["Distance"], ramp.inputs["Value"])
        height = ramp.outputs["Result"]
        if pore_dark:
            pit = nt.nodes.new("ShaderNodeMath")
            pit.operation = "MULTIPLY_ADD"
            pit.inputs[1].default_value = -pore_dark
            pit.inputs[2].default_value = pore_dark
            nt.links.new(height, pit.inputs[0])
            dark = nt.nodes.new("ShaderNodeMix")
            dark.data_type = "RGBA"
            dark.blend_type = "MULTIPLY"
            nt.links.new(pit.outputs[0], dark.inputs["Factor"])
            nt.links.new(col_out, _socket(dark, "A", "RGBA"))
            _socket(dark, "B", "RGBA").default_value = (0.45, 0.55, 0.3, 1.0)
            col_out = next(o for o in dark.outputs if o.type == "RGBA")
    rough_out = None
    mask_total = None
    for attr_name, lcolor, lrough in layers:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_type = "GEOMETRY"
        a.attribute_name = attr_name
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.clamp = True
        mr.inputs["From Min"].default_value = -edge
        mr.inputs["From Max"].default_value = edge
        nt.links.new(a.outputs["Fac"], mr.inputs["Value"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
        nt.links.new(col_out, _socket(mix, "A", "RGBA"))
        _socket(mix, "B", "RGBA").default_value = _hex(lcolor)
        col_out = next(o for o in mix.outputs if o.type == "RGBA")
        rmix = nt.nodes.new("ShaderNodeMix")
        rmix.data_type = "FLOAT"
        nt.links.new(mr.outputs["Result"], rmix.inputs["Factor"])
        if rough_out is None:
            _socket(rmix, "A", "VALUE").default_value = rough
        else:
            nt.links.new(rough_out, _socket(rmix, "A", "VALUE"))
        _socket(rmix, "B", "VALUE").default_value = lrough
        rough_out = next(o for o in rmix.outputs if o.type == "VALUE")
        if mask_total is None:
            mask_total = mr.outputs["Result"]
        else:
            mx = nt.nodes.new("ShaderNodeMath")
            mx.operation = "MAXIMUM"
            nt.links.new(mask_total, mx.inputs[0])
            nt.links.new(mr.outputs["Result"], mx.inputs[1])
            mask_total = mx.outputs[0]
    nt.links.new(col_out, bsdf.inputs["Base Color"])
    if rough_out is not None:
        nt.links.new(rough_out, bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Roughness"].default_value = rough
    if height is not None:
        if mask_total is not None:
            # inside a layer the surface sits flat at the top of the pores: h*(1-m) + m
            inv = nt.nodes.new("ShaderNodeMath")
            inv.operation = "SUBTRACT"
            inv.inputs[0].default_value = 1.0
            nt.links.new(mask_total, inv.inputs[1])
            fused = nt.nodes.new("ShaderNodeMath")
            fused.operation = "MULTIPLY_ADD"
            nt.links.new(height, fused.inputs[0])
            nt.links.new(inv.outputs[0], fused.inputs[1])
            nt.links.new(mask_total, fused.inputs[2])
            height = fused.outputs[0]
        bmp = nt.nodes.new("ShaderNodeBump")
        bmp.inputs["Strength"].default_value = bump_strength
        nt.links.new(height, bmp.inputs["Height"])
        nt.links.new(bmp.outputs["Normal"], bsdf.inputs["Normal"])
    m.diffuse_color = _hex(color)
    return m


def paint_regions(obj, fn):
    """fn(local_face_center: Vector, normal: Vector) -> material index."""
    me = obj.data
    for p in me.polygons:
        p.material_index = fn(p.center.copy(), p.normal.copy())
    me.update()

# ---------------------------------------------------------------- primitives

def _mesh_obj(name, coll, build):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(me)
    bm.free()
    return _link(bpy.data.objects.new(name, me), coll)


def sphere(name, coll, loc, radius, material=None, scale=(1, 1, 1), rot=(0, 0, 0), segs=48, rings=32):
    obj = _mesh_obj(name, coll, lambda bm: bmesh.ops.create_uvsphere(
        bm, u_segments=segs, v_segments=rings, radius=radius))
    obj.location = loc
    obj.scale = scale
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    if material:
        set_mats(obj, material)
    return smooth(obj)


def box(name, coll, loc, dims, material=None, bevel=0.1, rot=(0, 0, 0), sub=2):
    """Rounded box: dims are full sizes, bevel is the corner radius."""
    obj = _mesh_obj(name, coll, lambda bm: bmesh.ops.create_cube(bm, size=1.0))
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    obj.scale = dims
    apply_scale(obj)
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 4
        b.limit_method = "NONE"
    if sub:
        subdivide(obj, sub)
    if material:
        set_mats(obj, material)
    return smooth(obj)


def torus(name, coll, loc, major, minor, material=None, rot=(0, 0, 0), scale=(1, 1, 1)):
    """Ring with a round tube. major is a radius or (radius x, radius y) for an oval ring."""
    rx, ry = (major, major) if isinstance(major, (int, float)) else major

    def build(bm):
        n_major, n_minor = 64, 16
        verts = []
        for i in range(n_major):
            a = 2 * math.pi * i / n_major
            cx, cy = rx * math.cos(a), ry * math.sin(a)
            nrm = Vector((math.cos(a) / rx, math.sin(a) / ry, 0)).normalized()
            ring = []
            for j in range(n_minor):
                b = 2 * math.pi * j / n_minor
                ring.append(bm.verts.new((cx + nrm.x * minor * math.cos(b), cy + nrm.y * minor * math.cos(b),
                                          minor * math.sin(b))))
            verts.append(ring)
        for i in range(n_major):
            for j in range(n_minor):
                a, b = verts[i][j], verts[(i + 1) % n_major][j]
                c, d = verts[(i + 1) % n_major][(j + 1) % n_minor], verts[i][(j + 1) % n_minor]
                bm.faces.new((a, b, c, d))
    obj = _mesh_obj(name, coll, build)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    obj.scale = scale
    if material:
        set_mats(obj, material)
    return smooth(obj)


def quadsphere(name, coll, center, radii, material=None, cuts=48):
    """Even quad sphere (no pinched poles) with the radii baked in, origin at center, so it can be
    sculpted with push() in object space."""
    def build(bm):
        bmesh.ops.create_cube(bm, size=2.0)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
        for v in bm.verts:
            v.co = v.co.normalized()
            v.co.x *= radii[0]
            v.co.y *= radii[1]
            v.co.z *= radii[2]
        bm.normal_update()
    obj = _mesh_obj(name, coll, build)
    obj.location = center
    if material:
        set_mats(obj, material)
    return smooth(obj)


def leaf(name, coll, base, direction, length, width, material, curl=0.25, fold=0.12, up=(0, 0, 1)):
    """Pointed leaf with a centre fold, curling towards `up` along its length."""
    d = Vector(direction).normalized()
    side = d.cross(Vector(up)).normalized()
    n = side.cross(d).normalized()
    nu, nv = 24, 8

    def build(bm):
        rows = []
        for i in range(nu + 1):
            u = i / nu
            w = width * (math.sin(math.pi * min(u * 1.08, 1.0)) ** 0.85) * (1.0 - 0.15 * u) + 0.002
            row = []
            for j in range(nv + 1):
                v = -1 + 2 * j / nv
                p = Vector(base) + d * (u * length) + side * (v * w) \
                    + n * (curl * length * u * u + fold * abs(v) * w)
                row.append(bm.verts.new(p))
            rows.append(row)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    obj = _mesh_obj(name, coll, build)
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = width * 0.06
    sol.offset = 0.0
    subdivide(obj, 1)
    set_mats(obj, material)
    return smooth(obj)


def groove(obj, curve_fn, x_range, width, depth, front_y=-0.15, lip=0.0):
    """Cuts a line into the front of a mesh, e.g. a mouth. curve_fn(x) -> z in object space.
    Verts within `width` of the curve sink by `depth`; `lip` lifts the band just above it."""
    me = obj.data
    lo, hi = x_range
    normals = [v.normal.copy() for v in me.vertices]  # see push(): read normals before moving
    for v in me.vertices:
        x, y, z = v.co
        if y > front_y or x < lo or x > hi:
            continue
        zc = curve_fn(x)
        slope = (curve_fn(min(x + 0.01, hi)) - curve_fn(max(x - 0.01, lo))) / 0.02
        dz = (z - zc) / math.sqrt(1 + slope * slope)
        if abs(dz) < width:
            v.co -= normals[v.index] * depth * (1 - (dz / width) ** 2) ** 2
        elif lip and 0 < dz < width * 3:
            t = (dz - width) / (width * 2)
            v.co += normals[v.index] * lip * math.sin(math.pi * t)
    me.update()


def turn(objects, pivot, rot_deg):
    """Rotates a group of top-level objects (e.g. a head with its eyes) about a pivot, so a Cuh can
    look sideways or tilt its head like its reference pose."""
    m = (Matrix.Translation(Vector(pivot)) @ Euler([math.radians(a) for a in rot_deg]).to_matrix().to_4x4()
         @ Matrix.Translation(-Vector(pivot)))
    bpy.context.view_layer.update()  # new objects have no world matrix until the scene updates
    for obj in objects:
        if obj.parent is None:
            obj.matrix_world = m @ obj.matrix_world


def by_prefix(coll, *prefixes):
    return [o for o in coll.all_objects if any(o.name.startswith(p) for p in prefixes)]


def apply_scale(obj):
    me = obj.data
    me.transform(Matrix.Diagonal((*obj.scale, 1.0)))
    obj.scale = (1, 1, 1)
    me.update()

# ---------------------------------------------------------------- blends (metaballs)

# A lone metaball (stiffness 2, threshold 0.6) surfaces at 0.575 of its radius; dividing by this
# makes `size` / `r` the real half-extents of each element.
_SURFACE = 0.575


def blob(name, coll, elements, material=None, resolution=0.035, threshold=0.6, remesh=None):
    """Fuses ellipsoids/capsules into one smooth mesh.

    Each element: dict(co=(x,y,z), type='ELLIPSOID'|'BALL'|'CAPSULE', rot=(deg x,y,z), neg=False).
    ELLIPSOID: size=(half x, half y, half z). BALL: r. CAPSULE: r plus size=(half length, 1, 1).
    A capsule's length runs along its local X: rot=(0, 90, 0) stands it up. Easiest: capsule(p0, p1, r) builds
    a capsule element between two points.
    Sizes are the real surface sizes of a lone element; touching elements fuse and swell a little.
    """
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    obj = _link(bpy.data.objects.new(name, mb), coll)
    for e in elements:
        kind = e.get("type", "ELLIPSOID")
        el = mb.elements.new(type=kind)
        el.co = e["co"]
        size = e.get("size", (1, 1, 1))
        if kind == "ELLIPSOID":
            el.radius = 1.0 / _SURFACE
            el.size_x, el.size_y, el.size_z = size
        else:
            el.radius = e.get("r", 1.0) / _SURFACE
            el.size_x, el.size_y, el.size_z = size
        el.stiffness = e.get("stiff", 2.0)
        el.use_negative = e.get("neg", False)
        rot = e.get("rot")
        if rot:
            el.rotation = Euler([math.radians(a) for a in rot]).to_quaternion()
    bpy.context.view_layer.update()
    _active(obj)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    if remesh:
        r = obj.modifiers.new("Remesh", "REMESH")
        r.mode = "VOXEL"
        r.voxel_size = remesh
        apply_modifiers(obj)
    if material:
        set_mats(obj, material)
    return smooth(obj)


def capsule(p0, p1, r):
    """A blob() CAPSULE element from point p0 to point p1 with radius r (no rotation maths needed)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    if d.length < 1e-6:
        return dict(type="BALL", co=tuple(a), r=r)
    q = Vector((1, 0, 0)).rotation_difference(d.normalized())
    return dict(type="CAPSULE", co=tuple((a + b) / 2), r=r, size=(d.length / 2, 1, 1),
                rot=tuple(math.degrees(x) for x in q.to_euler()))


def push(obj, center, radius, amount, direction=None, power=2.0):
    """Sculpt-style move: verts within radius of center move by amount (along their normal, or a
    fixed direction) with a smooth falloff. Works in object space."""
    me = obj.data
    c = Vector(center)
    d = Vector(direction).normalized() if direction else None
    # read every normal before moving anything: moving a vertex invalidates its neighbours' normals,
    # and reading them mid-loop crumples dense surfaces
    normals = None if d else [v.normal.copy() for v in me.vertices]
    for i, v in enumerate(me.vertices):
        dist = (v.co - c).length
        if dist < radius:
            w = (1 - (dist / radius) ** 2) ** power
            v.co += (d if d else normals[i]) * amount * w
    me.update()


def trim(obj, plane_co, plane_no, cap=False):
    """Cuts the mesh with a plane and keeps the side the normal points away from."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=plane_co, plane_no=plane_no,
                           clear_outer=True, clear_inner=False)
    if cap:
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(me)
    bm.free()
    me.update()

# ---------------------------------------------------------------- limbs

def tube(name, coll, points, radii, material=None, res=12):
    """Smooth tapered tube through points (one radius per point)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 6
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for p, co, r in zip(sp.points, points, radii):
        p.co = (*co, 1.0)
        p.radius = r
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    obj = _link(bpy.data.objects.new(name, cu), coll)
    if material:
        cu.materials.append(material)
    return obj


def to_mesh(obj):
    _active(obj)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        bpy.ops.object.convert(target="MESH")
    return smooth(bpy.context.view_layer.objects.active)

# ---------------------------------------------------------------- faces

def eye(cuh, coll, center, radius, look=(0, -1, 0), iris="#1d4d2a", lid=None, lid_close=0.0,
        lid_tilt=0.0, iris_size=0.62, pupil_size=0.45, white="#fbf7ec", lower_lid=0.0, side=1,
        highlight=True):
    """Cartoon eye: glossy white ball, domed iris and pupil, catch-light, optional heavy lids.

    look: direction the eye points. lid_close: 0 = open, 1 = shut (upper lid comes down).
    lid_tilt: degrees the lid edge leans (positive = outer corner lower, a sleepy/smug look).
    side: +1 for the Cuh's left eye (+X), -1 for its right, mirrors the tilt.
    """
    c = Vector(center)
    fwd = Vector(look).normalized()
    rot = fwd.to_track_quat("-Y", "Z")
    tag = "L" if side > 0 else "R"
    parts = []
    ball = sphere(f"{cuh}_Eye{tag}", coll, c, radius, mat(f"{cuh}_EyeWhite", white, rough=0.12, coat=0.6))
    ball.rotation_mode = "QUATERNION"
    ball.rotation_quaternion = rot
    parts.append(ball)
    ir = sphere(f"{cuh}_Iris{tag}", coll, c + fwd * radius * 0.86, radius * iris_size,
                mat(f"{cuh}_Iris", iris, rough=0.15, coat=0.8), scale=(1, 0.32, 1))
    ir.rotation_mode = "QUATERNION"
    ir.rotation_quaternion = rot
    pu = sphere(f"{cuh}_Pupil{tag}", coll, c + fwd * radius * 0.95, radius * iris_size * pupil_size,
                mat(f"{cuh}_Pupil", "#08090b", rough=0.1, coat=1.0), scale=(1, 0.3, 1))
    pu.rotation_mode = "QUATERNION"
    pu.rotation_quaternion = rot
    parts += [ir, pu]
    if highlight:
        up = rot @ Vector((0, 0, 1))
        left = rot @ Vector((1, 0, 0))
        hl = sphere(f"{cuh}_Glint{tag}", coll,
                    c + fwd * radius * 1.0 + up * radius * 0.32 + left * radius * 0.22 * side,
                    radius * 0.14, mat(f"{cuh}_Glint", "#ffffff", rough=0.0, emit=3.0),
                    scale=(1, 0.4, 0.8))
        hl.rotation_mode = "QUATERNION"
        hl.rotation_quaternion = rot
        parts.append(hl)
    if lid is not None and lid_close > 0:
        parts.append(_lid(f"{cuh}_Lid{tag}", coll, c, radius * 1.07, rot, lid, lid_close, lid_tilt * side))
    if lid is not None and lower_lid > 0:
        parts.append(_lid(f"{cuh}_LowLid{tag}", coll, c, radius * 1.06, rot, lid, lower_lid,
                          -lid_tilt * side * 0.5, lower=True))
    return parts


def _lid(name, coll, c, r, rot, material, close, tilt, lower=False):
    """A shell over the eyeball. close is the fraction of the ball's height it covers. Built as a
    spherical cap with rings parallel to its rim, so the lid edge is a clean circle."""
    theta_max = math.acos(max(-1.0, min(1.0, 1 - 2 * close)))
    sign = -1 if lower else 1
    segs, rings = 64, 18

    def build(bm):
        top = bm.verts.new((0, 0, sign * r))
        prev = None
        for i in range(1, rings + 1):
            th = theta_max * (i / rings) ** 0.8
            ring = [bm.verts.new((r * math.sin(th) * math.cos(2 * math.pi * j / segs),
                                  r * math.sin(th) * math.sin(2 * math.pi * j / segs),
                                  sign * r * math.cos(th))) for j in range(segs)]
            for j in range(segs):
                a, b = ring[j], ring[(j + 1) % segs]
                if prev is None:
                    bm.faces.new((top, a, b) if sign > 0 else (top, b, a))
                else:
                    c, d = prev[(j + 1) % segs], prev[j]
                    bm.faces.new((d, a, b, c) if sign > 0 else (d, c, b, a))
            prev = ring
        bm.normal_update()
    obj = _mesh_obj(name, coll, build)
    set_mats(obj, material)
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = r * 0.09
    sol.offset = 1.0
    sol.use_rim = True
    sub = subdivide(obj, 1)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = rot @ Euler((0, math.radians(tilt), 0)).to_quaternion()
    obj.location = c
    return smooth(obj)

# ---------------------------------------------------------------- clothes & shoes

def sneaker(cuh, coll, tag, heel, yaw, length=1.0, width=0.5, height=0.42, upper="#f07a24",
            sole="#f6f1e6", laces="#ffffff", stripe=None, toe_cap=True):
    """Chunky cartoon sneaker. heel: ground point under the heel; yaw: degrees the toe turns
    from -Y towards +X. Returns (pivot, parts). Put the leg's ankle at heel + R(yaw) @ (0, -0.17*length, 0.55*height),
    as build/BearBuddy.py does."""
    parts = []
    m_up = mat(f"{cuh}_Shoe{upper}", upper, rough=0.45, coat=0.15)
    m_so = mat(f"{cuh}_Sole{sole}", sole, rough=0.55)
    m_la = mat(f"{cuh}_Lace{laces}", laces, rough=0.6, bump="fabric", bump_scale=120, bump_strength=0.1)
    L, W, H = length, width, height
    sole_obj = blob(f"{cuh}Sole{tag}", coll, [
        dict(co=(0, -L * 0.7, H * 0.17), size=(W * 0.53, L * 0.31, H * 0.23)),
        dict(co=(0, -L * 0.4, H * 0.17), size=(W * 0.51, L * 0.33, H * 0.23)),
        dict(co=(0, -L * 0.13, H * 0.17), size=(W * 0.51, L * 0.23, H * 0.23)),
    ], m_so, resolution=0.025)
    trim(sole_obj, (0, 0, 0), (0, 0, -1), cap=True)
    trim(sole_obj, (0, 0, H * 0.34), (0, 0, 1), cap=True)
    sole_obj.name = f"{cuh}_Sole{tag}"
    up = blob(f"{cuh}Upper{tag}", coll, [
        dict(co=(0, -L * 0.68, H * 0.38), size=(W * 0.46, L * 0.3, H * 0.32)),
        dict(co=(0, -L * 0.42, H * 0.52), size=(W * 0.48, L * 0.3, H * 0.42)),
        dict(co=(0, -L * 0.14, H * 0.58), size=(W * 0.45, L * 0.22, H * 0.48)),
    ], m_up, resolution=0.025)
    trim(up, (0, 0, H * 0.18), (0, 0, -1))
    up.name = f"{cuh}_Upper{tag}"
    collar = torus(f"{cuh}_Collar{tag}", coll, (0, -L * 0.17, H * 1.0), (W * 0.26, W * 0.31), W * 0.075,
                   mat(f"{cuh}_Collar{upper}", upper, rough=0.6), rot=(-10, 0, 0))
    tongue = box(f"{cuh}_Tongue{tag}", coll, (0, -L * 0.33, H * 1.0), (W * 0.42, L * 0.07, H * 0.32),
                 m_up, bevel=W * 0.08, rot=(-28, 0, 0), sub=2)
    parts += [sole_obj, up, collar, tongue]
    if toe_cap:
        cap = blob(f"{cuh}ToeCap{tag}", coll, [
            dict(co=(0, -L * 0.8, H * 0.28), size=(W * 0.47, L * 0.19, H * 0.2)),
        ], m_so, resolution=0.02)
        trim(cap, (0, 0, H * 0.18), (0, 0, -1))
        cap.name = f"{cuh}_ToeCap{tag}"
        parts.append(cap)
    for i, (fy, fz) in enumerate(((0.38, 0.97), (0.5, 0.88), (0.62, 0.77))):
        lace = box(f"{cuh}_Lace{tag}{i}", coll, (0, -L * fy, H * fz), (W * 0.6, L * 0.06, H * 0.07), m_la,
                   bevel=H * 0.03, rot=(-32, 0, 0), sub=1)
        parts.append(lace)
    if stripe:
        m_st = mat(f"{cuh}_Stripe{stripe}", stripe, rough=0.45)
        for s in (-1, 1):
            st = box(f"{cuh}_Stripe{tag}{s}", coll, (s * W * 0.47, -L * 0.42, H * 0.42),
                     (W * 0.05, L * 0.42, H * 0.1), m_st, bevel=0.02, rot=(14, 0, 0), sub=1)
            parts.append(st)
    pivot = bpy.data.objects.new(f"{cuh}_Shoe{tag}", None)
    _link(pivot, coll)
    for p in parts:
        p.parent = pivot
    pivot.location = heel
    pivot.rotation_euler = (0, 0, math.radians(yaw))
    return pivot, parts


def tshirt(cuh, coll, z_bottom, z_top, width, depth, color, sleeve_angle=55, sleeve_len=0.35,
           sleeve_r=0.17, y=0.0, x=0.0, neck=0.11):
    """Short-sleeve T-shirt as one soft shape with rounded shoulders and a collar around the neck.
    sleeve_angle is measured from straight down."""
    m = mat(f"{cuh}_Shirt{color}", color, rough=0.75, sheen=0.3, bump="fabric", bump_scale=90,
            bump_strength=0.06)
    h = z_top - z_bottom
    els = [
        # bell-shaped body, widest at the hem so it covers the waistband
        dict(co=(x, y, z_bottom + h * 0.05), size=(width * 0.5, depth * 0.5, h * 0.5)),
        dict(co=(x, y, z_top - h * 0.32), size=(width * 0.45, depth * 0.45, h * 0.36)),
    ]
    for s in (-1, 1):  # rounded shoulders
        els.append(dict(co=(x + s * width * 0.3, y, z_top - h * 0.2),
                        size=(width * 0.22, depth * 0.4, h * 0.2)))
    sa = math.radians(sleeve_angle)
    for s in (-1, 1):
        sx = x + s * (width * 0.42 + math.sin(sa) * sleeve_len * 0.5)
        sz = z_top - h * 0.24 - math.cos(sa) * sleeve_len * 0.5
        els.append(dict(type="CAPSULE", co=(sx, y, sz), r=sleeve_r,
                        size=(sleeve_len * 0.5, 1, 1), rot=(0, s * (90 - sleeve_angle), 0)))
    shirt = blob(f"{cuh}Shirt", coll, els, m, resolution=0.03)
    trim(shirt, (x, y, z_bottom), (0, 0, -1))
    shirt.name = f"{cuh}_Shirt"
    hem = torus(f"{cuh}_Hem", coll, (x, y, z_bottom + 0.015), (width * 0.5, depth * 0.5), 0.03, m)
    collar = torus(f"{cuh}_Collar", coll, (x, y, z_top - 0.02), (neck * 1.25, neck * 1.15), 0.035, m)
    return [shirt, hem, collar]


def shorts(cuh, coll, z_bottom, z_top, width, depth, color, leg_spread=0.18, y=0.0, x=0.0,
           drawstring=None, waistband=True):
    """Shorts with wide cuffed legs. Turn waistband off when a shirt hangs over the waist."""
    m = mat(f"{cuh}_Shorts{color}", color, rough=0.7, sheen=0.2, bump="fabric", bump_scale=70,
            bump_strength=0.05)
    h = z_top - z_bottom
    # the hip shape is centred on the waist cut, so the cut runs through its widest ring
    els = [dict(co=(x, y, z_top - 0.02), size=(width * 0.47, depth * 0.47, h * 0.5))]
    leg_w, leg_d = width * 0.29, depth * 0.48
    for s in (-1, 1):  # legs centred near the hem so the openings are wide, like the reference
        els.append(dict(co=(x + s * width * 0.25, y, z_bottom + h * 0.1),
                        size=(leg_w, leg_d, h * 0.55), rot=(0, s * leg_spread * 20, 0)))
    pants = blob(f"{cuh}Shorts", coll, els, m, resolution=0.025)
    trim(pants, (x, y, z_top), (0, 0, 1))
    trim(pants, (x, y, z_bottom), (0, 0, -1))
    pants.name = f"{cuh}_Shorts"
    parts = [pants]
    if waistband:
        parts.append(torus(f"{cuh}_Waistband", coll, (x, y, z_top - 0.03), (width * 0.48, depth * 0.48), 0.04, m))
    for s in (-1, 1):
        parts.append(torus(f"{cuh}_Cuff{s}", coll, (x + s * width * 0.25, y, z_bottom + 0.035),
                           (leg_w * 0.98, leg_d * 0.98), 0.045, m))
    if drawstring:
        md = mat(f"{cuh}_String{drawstring}", drawstring, rough=0.6)
        for s in (-1, 1):
            parts.append(tube(f"{cuh}_String{s}", coll,
                              [(x + s * 0.04, y - depth * 0.52, z_top - 0.05),
                               (x + s * 0.07, y - depth * 0.55, z_top - 0.2),
                               (x + s * 0.06, y - depth * 0.54, z_top - 0.3)],
                              [0.018, 0.018, 0.022], md))
    return parts

# ---------------------------------------------------------------- export for Roblox

def _join(objs, name):
    keep = objs[0]
    with bpy.context.temp_override(active_object=keep, object=keep, selected_objects=objs,
                                   selected_editable_objects=objs):
        bpy.ops.object.join()
    keep.name = name
    keep.data.name = name
    return keep


def _tris(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def export_roblox(coll, cuh, out_dir, tri_budget=16000, tex_size=1024, min_part_tris=80):
    """Bakes a Cuh into one game-ready mesh: <out_dir>/<cuh>.fbx plus Color/Normal/Rough PNGs.

    HIGH = every part with modifiers applied (keeps the region attributes for crisp face lines).
    LOW  = each part decimated to its share of tri_budget, joined, unwrapped. Colour, normal and
    roughness are baked from HIGH onto LOW, so the light mesh keeps the detail.
    Returns stats for the log.
    """
    import os
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    work = bpy.data.collections.get(f"{cuh}_Export") or bpy.data.collections.new(f"{cuh}_Export")
    if work.name not in scene.collection.children:
        scene.collection.children.link(work)
    for o in list(work.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    high_parts = []
    for obj in coll.all_objects:
        if obj.type not in ("MESH", "CURVE") or obj.hide_render:
            continue
        me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True,
                                             depsgraph=dg)
        me.transform(obj.matrix_world)
        if not me.polygons:
            bpy.data.meshes.remove(me)
            continue
        part = bpy.data.objects.new(f"{cuh}HP{len(high_parts)}", me)
        work.objects.link(part)
        high_parts.append(part)
    high_total = sum(_tris(p.data) for p in high_parts)
    ratio = min(1.0, tri_budget / max(high_total, 1))

    low_parts = []
    for part in high_parts:
        lo = part.copy()
        lo.data = part.data.copy()
        lo.name = part.name.replace("HP", "LP")
        work.objects.link(lo)
        n = _tris(lo.data)
        r = min(1.0, max(ratio, min_part_tris / max(n, 1)))
        if r < 1.0:
            dec = lo.modifiers.new("Decimate", "DECIMATE")
            dec.ratio = r
            dec.use_collapse_triangulate = True
            apply_modifiers(lo)
        low_parts.append(lo)

    high = _join(high_parts, f"{cuh}_High")
    low = _join(low_parts, cuh)
    # A diffuse-colour bake of a metallic surface comes out near black (diffuse = base * (1 - metallic)).
    # Roblox gets no metalness map, so bake metals as their base colour: gold stays gold, steel stays grey.
    for m in high.data.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    sock = n.inputs["Metallic"]
                    for link in list(sock.links):
                        m.node_tree.links.remove(link)
                    sock.default_value = 0.0
    for p in low.data.polygons:
        p.use_smooth = True
    low.data.materials.clear()

    # unwrap
    _active(low)
    with bpy.context.temp_override(active_object=low, object=low, selected_objects=[low]):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003, area_weight=0.0,
                                 correct_aspect=True, scale_to_bounds=False)
        bpy.ops.uv.pack_islands(margin=0.003, rotate=True)
        bpy.ops.object.mode_set(mode="OBJECT")

    # bake targets on a single material
    imgs = {}
    for kind, space in (("Color", "sRGB"), ("Normal", "Non-Color"), ("Rough", "Non-Color")):
        img_name = f"{cuh}_{kind}"
        old = bpy.data.images.get(img_name)
        if old:
            bpy.data.images.remove(old)
        img = bpy.data.images.new(img_name, tex_size, tex_size, alpha=False)
        img.colorspace_settings.name = space
        if kind == "Normal":
            img.generated_color = (0.5, 0.5, 1.0, 1.0)
        imgs[kind] = img
    bake_mat = bpy.data.materials.new(f"{cuh}_Baked")
    bake_mat.use_nodes = True
    nt = bake_mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nodes = {}
    for kind, img in imgs.items():
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nodes[kind] = tex
    low.data.materials.append(bake_mat)

    prev_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = 0.03
    bake.max_ray_distance = 0.08
    bake.margin = 6
    bake.use_pass_direct = False
    bake.use_pass_indirect = False
    bake.use_pass_color = True
    for o in bpy.context.view_layer.objects.selected:
        o.select_set(False)
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    for kind, btype in (("Color", "DIFFUSE"), ("Normal", "NORMAL"), ("Rough", "ROUGHNESS")):
        for n in nt.nodes:
            n.select = False
        nodes[kind].select = True
        nt.nodes.active = nodes[kind]
        with bpy.context.temp_override(active_object=low, object=low, selected_objects=[high, low],
                                       selected_editable_objects=[high, low]):
            bpy.ops.object.bake(type=btype, use_selected_to_active=True, cage_extrusion=0.03,
                                max_ray_distance=0.08, margin=6, normal_space="TANGENT")
        path = os.path.join(out_dir, f"{cuh}_{kind}.png")
        imgs[kind].filepath_raw = path
        imgs[kind].file_format = "PNG"
        imgs[kind].save()
    scene.render.engine = prev_engine

    # wire the baked maps so the .blend and FBX preview the final look
    nt.links.new(nodes["Color"].outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(nodes["Rough"].outputs["Color"], bsdf.inputs["Roughness"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nodes["Normal"].outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    high.hide_render = True
    high.hide_set(True)

    fbx = os.path.join(out_dir, f"{cuh}.fbx")
    for o in bpy.context.view_layer.objects.selected:
        o.select_set(False)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    with bpy.context.temp_override(active_object=low, object=low, selected_objects=[low]):
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"},
                                 apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                                 axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                                 path_mode="COPY", embed_textures=True, bake_space_transform=True)
    dims = low.dimensions
    xs, ys, zs = zip(*[tuple(low.matrix_world @ v.co) for v in low.data.vertices])
    lo, hi = (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))
    stats = dict(cuh=cuh, high_tris=high_total, low_tris=_tris(low.data),
                 size=[round(d, 4) for d in dims],
                 bbox_min=[round(v, 4) for v in lo], bbox_max=[round(v, 4) for v in hi], fbx=fbx)
    import json
    with open(os.path.join(out_dir, f"{cuh}_export.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=1)  # the Studio installer places the mesh on the Root's feet from this
    return stats

# ---------------------------------------------------------------- preview

def studio(target_height=4.0, background=None):
    """Three-point light rig, soft world and a 3/4 camera matching the reference renders."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        pass
    scene.render.film_transparent = background is None
    scene.render.resolution_x = scene.render.resolution_y = 900
    # Roblox shows colours without a filmic curve; AgX would wash the saturated toy colours out.
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = _hex("#9fb4cc")
    bg.inputs["Strength"].default_value = 0.55
    coll = bpy.data.collections.get("Studio") or bpy.data.collections.new("Studio")
    if coll.name not in scene.collection.children:
        scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    def light(name, kind, loc, energy, size, color="#ffffff"):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = _hex(color)[:3]
        if kind == "AREA":
            ld.size = size
        o = bpy.data.objects.new(name, ld)
        coll.objects.link(o)
        o.location = loc
        direction = Vector((0, 0, target_height * 0.55)) - Vector(loc)
        o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        return o

    h = target_height
    bg.inputs["Color"].default_value = _hex("#c9d3e0")
    bg.inputs["Strength"].default_value = 0.35
    light("Key", "AREA", (-4.5, -6, h * 1.6), 1400, 4, "#fff6ea")
    light("Fill", "AREA", (6, -4, h * 0.8), 350, 5, "#eef3ff")
    light("Rim", "AREA", (2, 6, h * 1.4), 900, 3, "#ffffff")
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    coll.objects.link(cam)
    target = Vector((0, 0, h * 0.5))
    cam.location = target + Vector((-0.42, -1, 0.18)).normalized() * h * 2.25
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    return cam


def render(path):
    scene = bpy.context.scene
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    bpy.ops.render.render(write_still=True)
    return path
