"""Renders UIKit's 3D icon pack in Blender (tested on 5.1, EEVEE) as PNGs with transparent backgrounds.

Inside Blender's Python (or through the Blender MCP):
    exec(open(r"<path>/render_icons_blender.py").read())
    render_icons(r"<out_dir>")                      # every icon
    render_icons(r"<out_dir>", ["coin", "gem"])     # a few
From a terminal:
    blender --background --python render_icons_blender.py -- <out_dir>

Everything is built in a separate scene ("UIKitIcons") and the window switches back afterwards, so the open file's own
scene is never touched. Icons are original shapes made from primitives: glossy cartoon materials plus a Freestyle ink
outline, lit from the top-left like the icons in top Roblox simulators.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

SCENE_NAME = "UIKitIcons"
RESOLUTION = 512
# "cel" matches the flat, navy-outlined simulator icon packs (2-tone shading + highlight);
# "gloss" is a shiny 3D render with a thin ink line
STYLE = "cel"
OUTLINE_PX = 26 if STYLE == "cel" else 10  # ink width at 512 px; the reference pack uses ~14 px at 256
OUTLINE_COLOR = (0.0003, 0.0, 0.034) if STYLE == "cel" else (0.018, 0.012, 0.03)  # navy #000034 in linear
INNER_LINE_PX = 11  # lines where two colours meet, thinner than the silhouette like hand-drawn icons
CEL_EXPOSURE = 0.36  # maps lit diffuse into the toon ramp's 0..1 range: faces → base, edges away from the light → shadow
VIEW_DIR = Vector((0.0, -1.0, 0.32))  # camera looks from the front, a little above
FRAME_MARGIN = 1.18

# ---------------------------------------------------------------- scene, materials, helpers


def _scene() -> bpy.types.Scene:
    scene = bpy.data.scenes.get(SCENE_NAME) or bpy.data.scenes.new(SCENE_NAME)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = RESOLUTION
    scene.render.resolution_y = RESOLUTION
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"  # saturated cartoon colours, not filmic
    except TypeError as err:
        print("view transform:", err)
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1
    layer = scene.view_layers[0]
    layer.use_freestyle = True
    settings = layer.freestyle_settings
    lineset = settings.linesets.get("Ink") or settings.linesets.new("Ink")
    lineset.select_by_visibility = True
    lineset.select_by_edge_types = True
    # thick ink on the silhouette only; crease lines draw on every bevel and look scratchy
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = False
    lineset.select_material_boundary = False
    lineset.linestyle.color = OUTLINE_COLOR
    lineset.linestyle.thickness = OUTLINE_PX
    inner = settings.linesets.get("InnerInk") or settings.linesets.new("InnerInk")
    inner.select_by_visibility = True
    inner.select_by_edge_types = True
    inner.select_silhouette = False
    inner.select_border = False
    inner.select_crease = False
    inner.select_material_boundary = True
    inner.linestyle.color = OUTLINE_COLOR
    inner.linestyle.thickness = INNER_LINE_PX
    for extra in [ls for ls in settings.linesets if ls.name not in ("Ink", "InnerInk")]:
        extra.show_render = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("UIKitIconsWorld")
    scene.world.use_nodes = True
    background = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs[0].default_value = (0.62, 0.64, 0.72, 1)
    background.inputs[1].default_value = 0.7
    return scene


def _clear(scene: bpy.types.Scene) -> None:
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def _link(scene: bpy.types.Scene, obj: bpy.types.Object) -> bpy.types.Object:
    scene.collection.objects.link(obj)
    return obj


_MATERIALS: dict = {}


def _cel_material(material: bpy.types.Material, color: tuple) -> None:
    """Flat cartoon shading: light → shadow / base / highlight bands through a constant colour ramp."""
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nodes.new("ShaderNodeShaderToRGB")
    ramp = nodes.new("ShaderNodeValToRGB")
    emit = nodes.new("ShaderNodeEmission")
    ramp.color_ramp.interpolation = "CONSTANT"
    shadow = tuple(c * 0.58 for c in color)
    highlight = tuple(c + (1 - c) * 0.45 for c in color)
    stops = ramp.color_ramp.elements
    stops[0].position, stops[0].color = 0.0, (*shadow, 1)
    stops[1].position, stops[1].color = 0.32, (*color, 1)
    extra = stops.new(0.82)
    extra.color = (*highlight, 1)
    # lit diffuse comes out far above 1 under the area lights; scale it so the bands fall where the ramp expects
    to_bw = nodes.new("ShaderNodeRGBToBW")
    exposure = nodes.new("ShaderNodeMath")
    exposure.operation = "MULTIPLY"
    exposure.inputs[1].default_value = CEL_EXPOSURE
    links.new(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
    links.new(to_rgb.outputs["Color"], to_bw.inputs["Color"])
    links.new(to_bw.outputs["Val"], exposure.inputs[0])
    links.new(exposure.outputs["Value"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], output.inputs["Surface"])


def mat(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.32, emission: float = 0.0) -> bpy.types.Material:
    key = (name, color, metallic, roughness, emission, STYLE)
    if key in _MATERIALS:
        return _MATERIALS[key]
    material = bpy.data.materials.new("UIKitIcon_" + name)
    material.use_nodes = True
    if STYLE == "cel":
        _cel_material(material, color)
        _MATERIALS[key] = material
        return material
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgba = (*color, 1.0)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    _MATERIALS[key] = material
    return material


def hexc(value: str) -> tuple:
    value = value.lstrip("#")
    srgb = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # Blender colour inputs are linear
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def _finish(scene, obj, material, bevel=0.0, smooth=True, segments=3):
    _link(scene, obj)
    obj.data.materials.append(material)
    if smooth and obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if bevel > 0 and obj.type == "MESH":
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    return obj


def _bm_object(name: str, bm: bmesh.types.BMesh) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return bpy.data.objects.new(name, mesh)


def cylinder(scene, name, radius, depth, material, location=(0, 0, 0), rotation=(0, 0, 0), segments=48, bevel=0.03, radius_top=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=depth)
    obj = _bm_object(name, bm)
    obj.location = location
    obj.rotation_euler = rotation
    return _finish(scene, obj, material, bevel)


def box(scene, name, size, material, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.06):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    obj = _bm_object(name, bm)
    obj.location = location
    obj.rotation_euler = rotation
    return _finish(scene, obj, material, bevel, smooth=False)


def sphere(scene, name, radius, material, location=(0, 0, 0), scale=(1, 1, 1), rotation=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=24, radius=radius)
    obj = _bm_object(name, bm)
    obj.location = location
    obj.scale = scale
    obj.rotation_euler = rotation
    return _finish(scene, obj, material)


def torus(scene, name, major, minor, material, location=(0, 0, 0), rotation=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings, sides = 40, 16
    verts = []
    for i in range(rings):
        a = 2 * math.pi * i / rings
        row = []
        for j in range(sides):
            b = 2 * math.pi * j / sides
            r = major + minor * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
        verts.append(row)
    for i in range(rings):
        for j in range(sides):
            bm.faces.new((verts[i][j], verts[(i + 1) % rings][j], verts[(i + 1) % rings][(j + 1) % sides], verts[i][(j + 1) % sides]))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.rotation_euler = rotation
    return _finish(scene, obj, material)


def slab(scene, name, points, depth, material, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.06):
    """A flat 2D outline (x, z points) extruded toward the camera, edges bevelled."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
    face = bm.faces.new(front)
    bmesh.ops.recalc_face_normals(bm, faces=[face])
    result = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in result["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=Vector((0, depth, 0)), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj = _bm_object(name, bm)
    obj.location = location
    obj.rotation_euler = rotation
    return _finish(scene, obj, material, bevel, smooth=False)


def arc_tube(scene, name, radius, start_deg, end_deg, thickness, material, rotation=(0, 0, 0)):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = thickness
    curve.bevel_resolution = 6
    spline = curve.splines.new("POLY")
    steps = 32
    spline.points.add(steps - 1)
    for i in range(steps):
        a = math.radians(start_deg + (end_deg - start_deg) * i / (steps - 1))
        spline.points[i].co = (radius * math.cos(a), 0, radius * math.sin(a), 1)
    obj = bpy.data.objects.new(name, curve)
    obj.rotation_euler = rotation
    _link(scene, obj)
    obj.data.materials.append(material)
    return obj


def star_points(outer, inner, count=5, start=90):
    pts = []
    for i in range(count * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(start + i * 180 / count)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


# ---------------------------------------------------------------- icons

GOLD = ("gold", hexc("#FFC83A"), 0.85, 0.28)


def icon_coin(s):
    gold = mat(*GOLD)
    cylinder(s, "Coin", 1.0, 0.3, gold, rotation=(math.radians(90), 0, 0), segments=64)
    # inner parts sit clearly in front of the face: coplanar overlaps draw broken boundary lines
    cylinder(s, "Face", 0.74, 0.03, mat("gold_deep", hexc("#F2A516"), 0.85, 0.3), location=(0, -0.165, 0), rotation=(math.radians(90), 0, 0), segments=64, bevel=0.0)
    slab(s, "Star", star_points(0.48, 0.21), 0.08, mat("gold_light", hexc("#FFE27A"), 0.7, 0.25), location=(0, -0.21, 0), bevel=0.02)


def icon_gem(s):
    bm = bmesh.new()
    table, girdle, sides = 0.55, 1.0, 8
    top = [bm.verts.new((table * math.cos(2 * math.pi * i / sides), table * math.sin(2 * math.pi * i / sides), 0.42)) for i in range(sides)]
    mid = [bm.verts.new((girdle * math.cos(2 * math.pi * (i + 0.5) / sides), girdle * math.sin(2 * math.pi * (i + 0.5) / sides), 0.12)) for i in range(sides)]
    tip = bm.verts.new((0, 0, -1.0))
    bm.faces.new(top)
    for i in range(sides):
        bm.faces.new((top[i], mid[i], top[(i + 1) % sides]))
        bm.faces.new((top[(i + 1) % sides], mid[i], mid[(i + 1) % sides]))
        bm.faces.new((mid[i], tip, mid[(i + 1) % sides]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj = _bm_object("Gem", bm)
    obj.rotation_euler = (math.radians(-12), 0, math.radians(10))
    _finish(s, obj, mat("gem", hexc("#36C8FF"), 0.1, 0.08, 0.25), smooth=False)


def icon_cash(s):
    green = mat("cash", hexc("#5BD25E"), 0.0, 0.4)
    band = mat("band", hexc("#FFD23A"), 0.3, 0.3)
    for i in range(3):
        z = -0.45 + i * 0.3
        box(s, f"Bill{i}", (2.0, 1.1, 0.22), green, location=(i * 0.06, 0, z), rotation=(0, 0, math.radians(-6 + i * 5)))
        box(s, f"Band{i}", (0.34, 1.16, 0.26), band, location=(i * 0.06, 0, z), rotation=(0, 0, math.radians(-6 + i * 5)), bevel=0.03)


def icon_shop(s):
    red = mat("bag", hexc("#FF4D6A"), 0.0, 0.35)
    box(s, "Bag", (1.5, 0.7, 1.55), red, location=(0, 0, -0.25), bevel=0.12)
    box(s, "Fold", (1.52, 0.72, 0.28), mat("bag_fold", hexc("#FFF1F4"), 0.0, 0.4), location=(0, 0, 0.42), bevel=0.06)
    torus(s, "Handle", 0.42, 0.08, mat("handle", hexc("#B8243F"), 0.0, 0.4), location=(0, 0, 0.62), rotation=(math.radians(90), 0, 0))
    slab(s, "Star", star_points(0.36, 0.16), 0.78, mat("star", hexc("#FFD23A"), 0.2, 0.3), location=(0, 0, -0.32), bevel=0.03)


def icon_egg(s):
    sphere(s, "Egg", 1.0, mat("egg", hexc("#FFF3D9"), 0.0, 0.35), scale=(0.88, 0.88, 1.15))
    spot = mat("egg_spot", hexc("#7BD64F"), 0.0, 0.35)
    for x, z, r in ((-0.35, 0.35, 0.22), (0.3, -0.05, 0.27), (-0.15, -0.55, 0.2), (0.42, 0.62, 0.15)):
        y = -math.sqrt(max(0.0, 0.88 ** 2 * (1 - (x / 0.88) ** 2 - (z / 1.15) ** 2))) + 0.04
        sphere(s, "Spot", r, spot, location=(x, y, z), scale=(1, 0.35, 1))


def icon_upgrade(s):
    pts = [(-0.34, -1.0), (0.34, -1.0), (0.34, 0.05), (0.82, 0.05), (0.0, 1.0), (-0.82, 0.05), (-0.34, 0.05)]
    slab(s, "Arrow", pts, 0.45, mat("arrow", hexc("#43D94F"), 0.0, 0.3), bevel=0.08)


def icon_rebirth(s):
    colours = (mat("rebirth", hexc("#3AA8FF"), 0.1, 0.3), mat("rebirth_green", hexc("#43D94F"), 0.1, 0.3))
    radius, end = 0.8, 140
    for k in range(2):
        offset = 180 * k
        arc_tube(s, f"Arc{k}", radius, 15 + offset, end + offset, 0.2, colours[k])
        a = math.radians(end + offset)
        tip = Vector((radius * math.cos(a), 0, radius * math.sin(a)))
        # arrowhead points along the arc's tangent (counter-clockwise)
        head = slab(s, f"Head{k}", [(-0.38, 0.0), (0.38, 0.0), (0.0, 0.5)], 0.42, colours[k], bevel=0.04)
        head.location = tip
        head.rotation_euler = (0, -a, 0)


def icon_gift(s):
    red = mat("gift", hexc("#FF4D6D"), 0.0, 0.35)
    gold = mat("ribbon", hexc("#FFD23A"), 0.3, 0.3)
    box(s, "Box", (1.6, 1.6, 1.2), red, location=(0, 0, -0.3), bevel=0.06)
    box(s, "Lid", (1.78, 1.78, 0.36), red, location=(0, 0, 0.42), bevel=0.06)
    box(s, "RibbonA", (0.34, 1.82, 1.62), gold, location=(0, 0, -0.1), bevel=0.03)
    box(s, "RibbonB", (1.82, 0.34, 1.62), gold, location=(0, 0, -0.1), bevel=0.03)
    for side in (-1, 1):
        torus(s, "Bow", 0.32, 0.11, gold, location=(side * 0.3, 0, 0.82), rotation=(math.radians(90), math.radians(side * 35), 0))


def icon_star(s):
    slab(s, "Star", star_points(1.0, 0.45), 0.42, mat("star", hexc("#FFD23A"), 0.35, 0.25), bevel=0.1)


def icon_book(s):
    box(s, "Cover", (1.5, 0.42, 1.9), mat("cover", hexc("#3D7BFF"), 0.0, 0.35), bevel=0.06)
    box(s, "Pages", (1.38, 0.36, 1.78), mat("pages", hexc("#FFF6E0"), 0.0, 0.5), location=(0.1, 0.02, 0), bevel=0.02)
    box(s, "Spine", (0.22, 0.44, 1.92), mat("spine", hexc("#2453C9"), 0.0, 0.35), location=(-0.72, 0, 0), bevel=0.04)
    slab(s, "Star", star_points(0.38, 0.17), 0.46, mat("star", hexc("#FFD23A"), 0.35, 0.25), location=(0.06, -0.04, 0.1), bevel=0.03)


def icon_backpack(s):
    body = mat("pack", hexc("#E0603F"), 0.0, 0.4)
    box(s, "Body", (1.3, 0.8, 1.6), body, location=(0, 0, -0.15), bevel=0.3)
    box(s, "Flap", (1.32, 0.86, 0.5), mat("pack_flap", hexc("#B8442A"), 0.0, 0.4), location=(0, -0.02, 0.5), bevel=0.18)
    box(s, "Pocket", (0.95, 0.3, 0.62), mat("pack_pocket", hexc("#F2835F"), 0.0, 0.4), location=(0, -0.45, -0.45), bevel=0.14)
    torus(s, "Handle", 0.25, 0.07, mat("pack_flap", hexc("#B8442A"), 0.0, 0.4), location=(0, 0, 0.82), rotation=(math.radians(90), 0, 0))


def icon_dumbbell(s):
    metal = mat("metal", hexc("#C9D1DE"), 0.9, 0.25)
    cylinder(s, "Bar", 0.09, 2.7, metal, rotation=(0, math.radians(90), 0), bevel=0.01)
    for side in (-1, 1):
        cylinder(s, "PlateBig", 0.62, 0.24, mat("plate", hexc("#3A3F4C"), 0.2, 0.4), location=(side * 0.78, 0, 0), rotation=(0, math.radians(90), 0))
        cylinder(s, "PlateRed", 0.5, 0.2, mat("plate_red", hexc("#FF4D5A"), 0.1, 0.35), location=(side * 1.04, 0, 0), rotation=(0, math.radians(90), 0))
    for obj in s.objects:
        obj.rotation_euler.z += math.radians(-18)


def icon_trophy(s):
    gold = mat(*GOLD)
    cylinder(s, "Cup", 0.45, 1.1, gold, location=(0, 0, 0.45), radius_top=0.95, segments=48)
    cylinder(s, "Inside", 0.85, 0.06, mat("gold_deep", hexc("#C98A10"), 0.85, 0.35), location=(0, 0, 1.0), bevel=0.0)
    for side in (-1, 1):
        torus(s, "Handle", 0.32, 0.08, gold, location=(side * 0.95, 0, 0.55), rotation=(math.radians(90), 0, 0))
    cylinder(s, "Stem", 0.14, 0.45, gold, location=(0, 0, -0.32))
    box(s, "Base", (1.1, 0.7, 0.32), mat("base", hexc("#5A3A2A"), 0.0, 0.45), location=(0, 0, -0.7), bevel=0.05)


def icon_crown(s):
    gold = mat(*GOLD)
    cylinder(s, "Band", 0.95, 0.55, gold, location=(0, 0, -0.35))
    # red velvet cap fills the band so the camera, looking slightly down, doesn't see a flat gold lid
    sphere(s, "Velvet", 0.86, mat("velvet", hexc("#D6264A"), 0.0, 0.55), location=(0, 0, -0.08), scale=(1, 1, 0.55))
    for i in range(5):
        a = math.radians(-90 + i * 45)
        x, y = 0.88 * math.cos(math.radians(180 + i * 45)), 0.88 * math.sin(math.radians(180 + i * 45))
        cylinder(s, "Spike", 0.26, 0.75, gold, location=(x, y, 0.25), radius_top=0.0, segments=4, bevel=0.02)
        sphere(s, "Ball", 0.12, gold, location=(x, y, 0.66))
    sphere(s, "Ruby", 0.2, mat("ruby", hexc("#FF3B5C"), 0.1, 0.1, 0.15), location=(0, -0.95, -0.35), scale=(1, 0.5, 1))
    for side in (-1, 1):
        sphere(s, "Sapphire", 0.14, mat("sapphire", hexc("#3AA8FF"), 0.1, 0.1, 0.15), location=(side * 0.6, -0.72, -0.35), scale=(1, 0.5, 1))


def icon_clover(s):
    leaf = mat("clover", hexc("#44C84E"), 0.0, 0.35)
    for i in range(4):
        a = math.radians(45 + i * 90)
        sphere(s, "Leaf", 0.52, leaf, location=(0.5 * math.cos(a), 0, 0.5 * math.sin(a) + 0.15), scale=(1, 0.38, 1))
    cylinder(s, "Stem", 0.08, 1.0, mat("stem", hexc("#2E9E3A"), 0.0, 0.4), location=(0.2, 0, -0.75), rotation=(0, math.radians(-25), 0))


def icon_potion(s):
    sphere(s, "Flask", 0.82, mat("potion", hexc("#B455FF"), 0.05, 0.12, 0.2), location=(0, 0, -0.3))
    cylinder(s, "Neck", 0.26, 0.6, mat("glass", hexc("#E9D7FF"), 0.0, 0.15), location=(0, 0, 0.62))
    cylinder(s, "Cork", 0.3, 0.26, mat("cork", hexc("#B07A47"), 0.0, 0.6), location=(0, 0, 1.0))
    sphere(s, "Shine", 0.16, mat("shine", (1, 1, 1), 0.0, 0.1, 2.0), location=(-0.38, -0.66, 0.0), scale=(1, 0.4, 1.4))


def icon_sword(s):
    blade = mat("blade", hexc("#DDE6F2"), 0.9, 0.2)
    gold = mat(*GOLD)
    box(s, "Blade", (0.5, 0.14, 2.1), blade, location=(0, 0, 0.55), bevel=0.04)
    box(s, "Fuller", (0.12, 0.16, 1.7), mat("fuller", hexc("#9FB0C8"), 0.9, 0.25), location=(0, 0, 0.45), bevel=0.02)
    slab(s, "Tip", [(-0.25, 0.0), (0.25, 0.0), (0.0, 0.55)], 0.14, blade, location=(0, 0, 1.6), bevel=0.02)
    box(s, "Guard", (1.25, 0.3, 0.26), gold, location=(0, 0, -0.55), bevel=0.08)
    cylinder(s, "Grip", 0.14, 0.62, mat("grip", hexc("#7A4A2A"), 0.0, 0.5), location=(0, 0, -0.95))
    sphere(s, "Pommel", 0.22, gold, location=(0, 0, -1.34))
    _rotate_all(s, math.radians(-40))


def _rotate_all(s, angle):
    pivot = bpy.data.objects.new("Pivot", None)
    _link(s, pivot)
    for obj in s.objects:
        if obj is not pivot:
            obj.parent = pivot
    pivot.rotation_euler = (0, angle, 0)


def _shield_outline(scale):
    # heater shield: flat-ish top, sides that stay wide then sweep in to a point
    pts = []
    for i in range(13):
        t = i / 12
        x = -0.85 + 1.7 * t
        pts.append((x * scale, (0.95 + 0.06 * math.cos(x * 1.8)) * scale))
    for i in range(1, 25):
        t = i / 24
        pts.append((0.85 * math.sqrt(max(0.0, 1 - t ** 2.2)) * scale, (0.95 - 1.95 * t) * scale))
    for i in range(23, 0, -1):
        t = i / 24
        pts.append((-0.85 * math.sqrt(max(0.0, 1 - t ** 2.2)) * scale, (0.95 - 1.95 * t) * scale))
    return pts


def icon_shield(s):
    slab(s, "Rim", _shield_outline(1.0), 0.3, mat("shield_rim", hexc("#FFC83A"), 0.7, 0.3), bevel=0.06)
    slab(s, "Face", _shield_outline(0.82), 0.06, mat("shield", hexc("#3D7BFF"), 0.1, 0.3), location=(0, -0.18, 0), bevel=0.02)
    slab(s, "Star", star_points(0.36, 0.16), 0.06, mat("star_white", hexc("#FFFFFF"), 0.0, 0.3), location=(0, -0.24, 0.1), bevel=0.02)


def icon_bolt(s):
    pts = [(0.25, 1.0), (-0.48, -0.02), (-0.04, -0.02), (-0.32, -1.0), (0.52, 0.16), (0.07, 0.16), (0.48, 1.0)]
    slab(s, "Bolt", pts, 0.38, mat("bolt", hexc("#FFD23A"), 0.2, 0.25, 0.25), bevel=0.06)


def icon_skull(s):
    bone = mat("bone", hexc("#F4F1EA"), 0.0, 0.4)
    dark = mat("socket", hexc("#2A2233"), 0.0, 0.6)
    sphere(s, "Cranium", 0.95, bone, location=(0, 0, 0.2), scale=(1, 0.95, 0.92))
    box(s, "Jaw", (1.05, 0.9, 0.6), bone, location=(0, -0.1, -0.55), bevel=0.2)
    for side in (-1, 1):
        sphere(s, "Eye", 0.24, dark, location=(side * 0.34, -0.82, 0.05), scale=(1, 0.4, 1.1))
    slab(s, "Nose", [(-0.12, 0.0), (0.12, 0.0), (0.0, 0.2)], 0.12, dark, location=(0, -0.92, -0.3), bevel=0.0)


def icon_gear(s):
    metal = mat("gear", hexc("#A7B0C2"), 0.8, 0.3)
    cylinder(s, "Wheel", 0.78, 0.36, metal, rotation=(math.radians(90), 0, 0))
    for i in range(10):
        a = 2 * math.pi * i / 10
        box(s, "Tooth", (0.34, 0.36, 0.32), metal, location=(0.9 * math.cos(a), 0, 0.9 * math.sin(a)), rotation=(0, -a, 0), bevel=0.04)
    cylinder(s, "Hole", 0.3, 0.42, mat("hole", hexc("#3A3F4C"), 0.2, 0.5), rotation=(math.radians(90), 0, 0))


def icon_heart(s):
    pts = []
    for i in range(64):
        t = 2 * math.pi * i / 64
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 16, z / 16 + 0.1))
    slab(s, "Heart", pts, 0.5, mat("heart", hexc("#FF3B5C"), 0.0, 0.25), bevel=0.14)


# Turn each icon to a 3/4 view (x tilt, z turn in degrees) so boxes show two sides and discs show their edge
POSES = {
    "coin": (0, 28), "cash": (12, 20), "shop": (8, 28), "gift": (14, 32), "book": (6, 26), "backpack": (6, 26),
    "trophy": (6, 0), "crown": (14, 0), "gear": (0, 24), "potion": (0, 0), "egg": (0, 0), "skull": (0, 14),
    # flat shapes turn a little so their extruded edge shows as a darker side, like the reference pack
    "star": (8, 22), "heart": (6, 22), "shield": (6, 20), "bolt": (6, 24), "upgrade": (6, 22),
}


# Curve objects report loose bounds, so a few icons need a manual zoom to fill the frame like the rest
ZOOM = {"rebirth": 1.5}


def _pose(scene, tilt_deg, turn_deg):
    pivot = bpy.data.objects.new("Pivot", None)
    _link(scene, pivot)
    for obj in scene.objects:
        if obj is not pivot and obj.parent is None:
            obj.parent = pivot
    pivot.rotation_euler = (math.radians(tilt_deg), 0, math.radians(turn_deg))


ICONS = {
    "coin": icon_coin, "gem": icon_gem, "cash": icon_cash, "shop": icon_shop, "egg": icon_egg, "upgrade": icon_upgrade,
    "rebirth": icon_rebirth, "gift": icon_gift, "star": icon_star, "book": icon_book, "backpack": icon_backpack,
    "dumbbell": icon_dumbbell, "trophy": icon_trophy, "crown": icon_crown, "clover": icon_clover, "potion": icon_potion,
    "sword": icon_sword, "shield": icon_shield, "bolt": icon_bolt, "skull": icon_skull, "gear": icon_gear, "heart": icon_heart,
}

# ---------------------------------------------------------------- camera, lights, render


def _bounds(scene):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in scene.objects:
        if obj.type not in ("MESH", "CURVE"):
            continue
        evaluated = obj.evaluated_get(depsgraph)
        for corner in evaluated.bound_box:
            world = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, world))
            hi = Vector(map(max, hi, world))
    return lo, hi


def _aim(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def _stage(scene, zoom=1.0):
    lo, hi = _bounds(scene)
    centre = (lo + hi) / 2
    direction = VIEW_DIR.normalized()
    camera_data = bpy.data.cameras.new("IconCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(hi.x - lo.x, hi.z - lo.z, (hi.y - lo.y) * 0.6) * FRAME_MARGIN / zoom
    camera = _link(scene, bpy.data.objects.new("IconCamera", camera_data))
    camera.location = centre + direction * 20
    _aim(camera, centre)
    scene.camera = camera
    for name, offset, energy, size in (("Key", (-4, -6, 6), 1400, 5), ("Fill", (6, -4, 1), 450, 6), ("Rim", (1, 6, 5), 900, 4)):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.size = size
        light = _link(scene, bpy.data.objects.new(name, light_data))
        light.location = centre + Vector(offset)
        _aim(light, centre)


def render_icons(out_dir, names=None):
    os.makedirs(out_dir, exist_ok=True)
    window = bpy.context.window
    previous = window.scene if window else None
    scene = _scene()
    if window:
        window.scene = scene
    done = []
    try:
        for name in names or list(ICONS):
            _clear(scene)
            ICONS[name](scene)
            if name in POSES:
                _pose(scene, *POSES[name])
                bpy.context.view_layer.update()
            _stage(scene, ZOOM.get(name, 1.0))
            scene.render.filepath = os.path.join(out_dir, name + ".png")
            bpy.ops.render.render(write_still=True, scene=scene.name)
            done.append(name)
    finally:
        if window and previous:
            window.scene = previous
    print("rendered:", ", ".join(done))
    return done


if __name__ == "__main__" and "--" in sys.argv:
    render_icons(sys.argv[sys.argv.index("--") + 1])
