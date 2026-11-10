"""Leaf-cluster cards from CC0 leaf atlases (ambientCG LeafSet / Foliage / PineNeedles). Method by fwjelaa (FWJ STUDIOS).

A tree crown is made of cards, and a card that shows one big leaf looks wrong on a 40-stud tree. This cuts the
single leaves out of an atlas and lays dozens of small, turned copies along a twig: one RGBA colour map (alpha =
the leaves), one OpenGL normal map whose vectors turn with each leaf."""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

FLAT = (128, 128, 255)


def _runs(flags):
    out, start = [], None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(flags)))
    return out


def extract_leaves(color, opacity, normal=None, min_area=0.002):
    # atlases lay leaves out with clear space between them: split by empty columns, then empty rows
    mask = np.asarray(opacity.convert("L")) > 128
    h, w = mask.shape
    normal = normal or Image.new("RGB", color.size, FLAT)
    leaves = []
    for x0, x1 in _runs(mask.any(axis=0)):
        for y0, y1 in _runs(mask[:, x0:x1].any(axis=1)):
            sub = mask[y0:y1, x0:x1]
            xs = _runs(sub.any(axis=0))
            if not xs or (y1 - y0) * (x1 - x0) < min_area * w * h:
                continue
            bx0, bx1 = x0 + xs[0][0], x0 + xs[-1][1]
            box = (bx0, y0, bx1, y1)
            rgba = color.convert("RGB").crop(box).convert("RGBA")
            rgba.putalpha(opacity.convert("L").crop(box))
            leaves.append((rgba, normal.convert("RGB").crop(box)))
    return leaves


def rotate_normal(nrm, angle_deg):
    # turn the image and the tangent-space vectors with it (OpenGL: green = +Y = up the image)
    img = nrm.convert("RGB").rotate(angle_deg, resample=Image.BICUBIC, expand=True, fillcolor=FLAT)
    v = np.asarray(img, dtype=np.float32) / 127.5 - 1.0
    a = math.radians(angle_deg)
    x, y = v[..., 0], v[..., 1]
    v[..., 0], v[..., 1] = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
    return Image.fromarray(np.clip((v + 1.0) * 127.5, 0, 255).astype(np.uint8))


def compose_cluster(leaves, size=1024, count=90, seed=1, twig=(74, 58, 44)):
    rng = random.Random(seed)
    color = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    normal = Image.new("RGB", (size, size), FLAT)
    draw = ImageDraw.Draw(color)
    # a twig from the bottom centre with a few side shoots; leaves sit along it
    stems = []
    base = (size * 0.5, size * 0.99)
    tip = (size * rng.uniform(0.42, 0.58), size * 0.06)
    stems.append((base, tip))
    for _ in range(4):
        t = rng.uniform(0.25, 0.8)
        start = (base[0] + (tip[0] - base[0]) * t, base[1] + (tip[1] - base[1]) * t)
        side = rng.choice((-1, 1))
        end = (start[0] + side * size * rng.uniform(0.22, 0.4), start[1] - size * rng.uniform(0.1, 0.3))
        stems.append((start, end))
    for (x0, y0), (x1, y1) in stems:
        draw.line([(x0, y0), (x1, y1)], fill=twig + (255,), width=max(2, size // 110))
    leaf_len = size * math.sqrt(2.0 / max(count, 1))
    for _ in range(count):
        (x0, y0), (x1, y1) = rng.choice(stems)
        t = rng.uniform(0.1, 1.0)
        px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        out_ang = math.degrees(math.atan2(-(y1 - y0), x1 - x0)) + rng.choice((-1, 1)) * rng.uniform(25, 80)
        rgba, nrm = rng.choice(leaves)
        s = leaf_len * rng.uniform(0.75, 1.2) / max(rgba.size)
        dims = (max(2, int(rgba.size[0] * s)), max(2, int(rgba.size[1] * s)))
        leaf, lnrm = rgba.resize(dims, Image.LANCZOS), nrm.resize(dims, Image.LANCZOS)
        # atlas leaves point up the image (stem at the bottom): turn them to point away from the twig
        angle = out_ang - 90 + rng.uniform(-15, 15)
        shade = rng.uniform(0.78, 1.08)
        r, g, b, a = leaf.split()
        leaf = Image.merge("RGBA", (r.point(lambda v: min(255, int(v * shade))), g.point(lambda v: min(255, int(v * shade))),
                                    b.point(lambda v: min(255, int(v * shade * 0.95))), a))
        leaf = leaf.rotate(angle, resample=Image.BICUBIC, expand=True)
        lnrm = rotate_normal(lnrm, angle)
        reach = max(leaf.size) * 0.45
        cx = int(px + math.cos(math.radians(out_ang)) * reach - leaf.size[0] / 2)
        cy = int(py - math.sin(math.radians(out_ang)) * reach - leaf.size[1] / 2)
        color.alpha_composite(leaf, (max(0, min(size - leaf.size[0], cx)), max(0, min(size - leaf.size[1], cy))))
        normal.paste(lnrm, (max(0, min(size - leaf.size[0], cx)), max(0, min(size - leaf.size[1], cy))), leaf.split()[3])
    return color, normal


def compose_tuft(blades, size=1024, count=60, seed=1):
    # grass/fern tufts: blades rooted along the bottom, fanning out, longest in the middle
    rng = random.Random(seed)
    color = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    normal = Image.new("RGB", (size, size), FLAT)
    upright = []
    for rgba, nrm in blades:
        if rgba.size[0] > rgba.size[1]:  # lying sideways in the atlas: stand it up (tip up, normals turned too)
            rgba, nrm = rgba.rotate(90, expand=True), rotate_normal(nrm, 90)
        upright.append((rgba, nrm))
    for _ in range(count):
        rgba, nrm = rng.choice(upright)
        root = size * (0.5 + rng.gauss(0, 0.13))
        lean = rng.uniform(-28, 28) + (root - size / 2) / size * 40  # outer blades lean out
        length = size * rng.uniform(0.55, 0.98) * (1 - abs(root - size / 2) / size)
        s = length / max(rgba.size)
        dims = (max(2, int(rgba.size[0] * s)), max(2, int(rgba.size[1] * s)))
        blade, bnrm = rgba.resize(dims, Image.LANCZOS), nrm.resize(dims, Image.LANCZOS)
        shade = rng.uniform(0.75, 1.1)
        r, g, b, a = blade.split()
        blade = Image.merge("RGBA", (r.point(lambda v: min(255, int(v * shade))), g.point(lambda v: min(255, int(v * shade))), b, a))
        blade = blade.rotate(-lean, resample=Image.BICUBIC, expand=True)
        bnrm = rotate_normal(bnrm, -lean)
        x = int(root - blade.size[0] / 2)
        y = size - blade.size[1]
        x = max(0, min(size - blade.size[0], x))
        color.alpha_composite(blade, (x, max(0, y)))
        normal.paste(bnrm, (x, max(0, y)), blade.split()[3])
    return color, normal


def compose_needles(size=1024, seed=1, shoots=7, green=(46, 74, 38)):
    # a conifer spray drawn from scratch: a twig with side shoots, each bristling with short needles
    rng = random.Random(seed)
    color = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(color)
    stems = [((size * 0.5, size * 0.98), (size * rng.uniform(0.45, 0.55), size * 0.05))]
    for i in range(shoots):
        t = (i + 1) / (shoots + 1)
        (x0, y0), (x1, y1) = stems[0]
        start = (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
        side = 1 if i % 2 else -1
        reach = size * 0.42 * (1 - t * 0.6)
        stems.append((start, (start[0] + side * reach, start[1] - reach * rng.uniform(0.15, 0.45))))
    needle = size * 0.09
    width = max(1, size // 190)
    for (x0, y0), (x1, y1) in stems:
        draw.line([(x0, y0), (x1, y1)], fill=(72, 56, 40, 255), width=max(2, size // 160))
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        for k in range(int(length / (size * 0.0045))):
            t = k / max(1, length / (size * 0.0045))
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for side in (-1, 1):
                a = ang + side * math.radians(rng.uniform(35, 70))
                n = needle * rng.uniform(0.6, 1.0) * (1 - 0.4 * t)
                shade = rng.uniform(0.75, 1.25)
                col = tuple(min(255, int(c * shade)) for c in green) + (255,)
                draw.line([(px, py), (px + math.cos(a) * n, py + math.sin(a) * n)], fill=col, width=width)
    normal = Image.new("RGB", (size, size), FLAT)
    return color, normal
