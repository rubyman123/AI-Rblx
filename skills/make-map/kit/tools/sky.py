"""Skyboxes from CC0 HDRIs: a tonemapped equirect panorama → Roblox's six Sky faces. Method by fwjelaa (FWJ STUDIOS).

Directions are Roblox world axes (Y up, north = -Z). Face orientation was measured in Studio
(research/00-measured.md, "Skybox face orientation"): a face pixel (u right, v down, 0..1) looks along
  Ft (2u-1, 1-2v, -1)   Rt (-1, 1-2v, 1-2u)   Bk (1-2u, 1-2v, 1)   Lf (1, 1-2v, 2u-1)
  Up (1-2v, 1, 1-2u)    Dn (2v-1, -1, 1-2u)
The panorama's centre column looks north (-Z); its left half is west (-X)."""
import math

import numpy as np
from PIL import Image

FACES = {
    "Ft": lambda u, v: (2 * u - 1, 1 - 2 * v, -np.ones_like(u)),
    "Rt": lambda u, v: (-np.ones_like(u), 1 - 2 * v, 1 - 2 * u),
    "Bk": lambda u, v: (1 - 2 * u, 1 - 2 * v, np.ones_like(u)),
    "Lf": lambda u, v: (np.ones_like(u), 1 - 2 * v, 2 * u - 1),
    "Up": lambda u, v: (1 - 2 * v, np.ones_like(u), 1 - 2 * u),
    "Dn": lambda u, v: (2 * v - 1, -np.ones_like(u), 1 - 2 * u),
}


def equirect_uv(d):
    x, y, z = d
    lon = math.atan2(x, -z)  # 0 = north (-Z), +pi/2 = east (+X)
    lat = math.asin(max(-1.0, min(1.0, y / math.sqrt(x * x + y * y + z * z))))
    return 0.5 + lon / (2 * math.pi), 0.5 - lat / math.pi


def equirect_dir(u, v):
    lon, lat = (u - 0.5) * 2 * math.pi, (0.5 - v) * math.pi
    return (math.sin(lon) * math.cos(lat), math.sin(lat), -math.cos(lon) * math.cos(lat))


def cube_faces(equirect, size=1024, yaw_deg=0.0):
    # yaw turns the whole sky about Y (to line the panorama's sun up with the lighting's)
    src = np.asarray(equirect.convert("RGB"), dtype=np.float32)
    h, w, _ = src.shape
    c = (np.arange(size) + 0.5) / size
    u, v = np.meshgrid(c, c)
    yaw = math.radians(yaw_deg)
    out = {}
    for name, f in FACES.items():
        x, y, z = (np.asarray(a, dtype=np.float64) for a in f(u, v))
        x, z = x * math.cos(yaw) + z * math.sin(yaw), -x * math.sin(yaw) + z * math.cos(yaw)
        lon = np.arctan2(x, -z)
        lat = np.arcsin(np.clip(y / np.sqrt(x * x + y * y + z * z), -1, 1))
        fx = (0.5 + lon / (2 * np.pi)) * w - 0.5
        fy = (0.5 - lat / np.pi) * h - 0.5
        x0 = np.floor(fx).astype(int)
        y0 = np.clip(np.floor(fy).astype(int), 0, h - 1)
        y1 = np.clip(y0 + 1, 0, h - 1)
        tx, ty = (fx - x0)[..., None], np.clip(fy - np.floor(fy), 0, 1)[..., None]
        xa, xb = x0 % w, (x0 + 1) % w  # wraps round the panorama's seam
        top = src[y0, xa] * (1 - tx) + src[y0, xb] * tx
        bot = src[y1, xa] * (1 - tx) + src[y1, xb] * tx
        out[name] = Image.fromarray(np.clip(top * (1 - ty) + bot * ty, 0, 255).astype(np.uint8))
    return out


def sun_direction(equirect, work=512):
    # the sun is the brightest blob; downscale first so one hot pixel doesn't win
    small = equirect.convert("L").resize((work, work // 2), Image.BILINEAR)
    a = np.asarray(small, dtype=np.float32)
    js, is_ = np.nonzero(a >= a.max() * 0.98)  # the sun disc: its centre, not its first bright pixel
    lon = (is_ + 0.5) / a.shape[1] * 2 * np.pi
    u = (math.atan2(np.sin(lon).mean(), np.cos(lon).mean()) / (2 * np.pi)) % 1.0  # circular: the disc may wrap the seam
    return equirect_dir(u, (js.mean() + 0.5) / a.shape[0])


def rotate_dir(d, yaw_deg):
    # the same turn cube_faces applies when it samples: it takes yaw_deg off a direction's bearing
    a = math.radians(yaw_deg)
    x, y, z = d
    return (x * math.cos(a) + z * math.sin(a), y, -x * math.sin(a) + z * math.cos(a))


def yaw_for(sun, azimuth_deg):
    # the yaw that moves the panorama's sun to `azimuth_deg` (degrees from north, -Z, toward east, +X)
    return azimuth_deg - math.degrees(math.atan2(sun[0], -sun[2]))
