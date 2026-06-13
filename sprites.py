"""Procedural galaxy / nebula sprites for the distant background billboards."""

import numpy as np
from PIL import Image


def _smooth_noise(size, cells, rng):
    small = rng.random((cells, cells)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((size, size), Image.BILINEAR)
    return np.asarray(img, dtype=np.float32) / 255.0


def generate_galaxy(size=256, seed=0, kind="spiral"):
    """Return an RGBA uint8 array: white glow, alpha = brightness."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[-1:1:size * 1j, -1:1:size * 1j]
    r = np.hypot(xx, yy)
    theta = np.arctan2(yy, xx)

    core = np.exp(-(r / 0.11) ** 2)
    if kind == "spiral":
        arms = 0.5 + 0.5 * np.cos(2.0 * theta - np.log(r + 0.05) * 7.0)
        disk = np.exp(-(r / 0.55) ** 2) * (0.20 + 0.80 * arms)
    elif kind == "elliptical":
        disk = np.exp(-(r / 0.50) ** 2) * 0.9
    else:  # irregular nebula
        disk = np.exp(-(r / 0.62) ** 2) * (0.25 + 0.85 * _smooth_noise(size, size // 8, rng))

    b = np.clip(core * 1.25 + disk, 0.0, 1.0)
    speckle = (rng.random((size, size)) > 0.9975).astype(np.float32)
    b = np.clip(b + speckle, 0.0, 1.0)

    alpha = (b * 255).astype(np.uint8)
    white = np.full((size, size), 255, np.uint8)
    return np.stack([white, white, white, alpha], axis=-1)


def generate_creature(size=128):
    """A simple monster silhouette (row 0 = bottom). White, tinted in-shader."""
    v = np.linspace(0.0, 1.0, size).reshape(-1, 1)   # 0 bottom -> 1 top
    u = np.linspace(0.0, 1.0, size).reshape(1, -1)
    body = ((u - 0.5) / 0.34) ** 2 + ((v - 0.34) / 0.32) ** 2 <= 1.0
    head = ((u - 0.5) / 0.24) ** 2 + ((v - 0.74) / 0.24) ** 2 <= 1.0
    legL = (np.abs(u - 0.40) < 0.07) & (v < 0.12)
    legR = (np.abs(u - 0.60) < 0.07) & (v < 0.12)
    mask = body | head | legL | legR
    eyeL = ((u - 0.42) / 0.055) ** 2 + ((v - 0.77) / 0.06) ** 2 <= 1.0
    eyeR = ((u - 0.58) / 0.055) ** 2 + ((v - 0.77) / 0.06) ** 2 <= 1.0
    rgb = np.ones((size, size), np.float32)
    rgb[eyeL | eyeR] = 0.10
    a = np.broadcast_to(mask, (size, size)).astype(np.float32)
    return np.stack([(rgb * 255).astype(np.uint8)] * 3 + [(a * 255).astype(np.uint8)], axis=-1)


def generate_orb(size=64):
    yy, xx = np.mgrid[-1:1:size * 1j, -1:1:size * 1j]
    r = np.hypot(xx, yy)
    rgb = np.clip(1.2 - r, 0.0, 1.0)
    alpha = (r < 0.85).astype(np.float32)
    return np.stack([(rgb * 255).astype(np.uint8)] * 3 + [(alpha * 255).astype(np.uint8)], axis=-1)
