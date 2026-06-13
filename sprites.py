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


def generate_creature(variant=0, size=128):
    """Parametric monster silhouette (row 0 = bottom), white + shaded, glowing
    eyes; tinted per-kind in the shader. Variants give distinct alien shapes."""
    v = np.linspace(0.0, 1.0, size).reshape(-1, 1)
    u = np.linspace(0.0, 1.0, size).reshape(1, -1)
    mask = np.zeros((size, size), bool)
    eyes = np.zeros((size, size), bool)

    def ell(cx, cy, rx, ry):
        return ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1.0

    def disc(cx, cy, r):
        return (u - cx) ** 2 + (v - cy) ** 2 <= r * r

    if variant == 0:        # critter
        mask |= ell(0.5, 0.34, 0.34, 0.30) | ell(0.5, 0.72, 0.24, 0.24)
        mask |= ((np.abs(u - 0.40) < 0.06) | (np.abs(u - 0.60) < 0.06)) & (v < 0.12)
        eyes |= disc(0.43, 0.75, 0.05) | disc(0.57, 0.75, 0.05)
    elif variant == 1:      # alien: tall, two antennae, one big eye
        mask |= ell(0.5, 0.32, 0.20, 0.30) | ell(0.5, 0.70, 0.20, 0.22)
        mask |= (np.abs(u - 0.5) < 0.04) & (v < 0.10)
        mask |= (np.abs(u - (0.5 - (v - 0.86) * 1.0)) < 0.02) & (v > 0.86)
        mask |= (np.abs(u - (0.5 + (v - 0.86) * 1.0)) < 0.02) & (v > 0.86)
        eyes |= disc(0.5, 0.72, 0.09)
    elif variant == 2:      # brute: wide, spikes, three eyes
        mask |= ell(0.5, 0.36, 0.40, 0.30) | ell(0.5, 0.66, 0.30, 0.22)
        mask |= ((np.abs(u - 0.34) < 0.07) | (np.abs(u - 0.66) < 0.07)) & (v < 0.13)
        for sx in (0.34, 0.5, 0.66):
            mask |= (np.abs(u - sx) < 0.05 * np.clip(1 - (v - 0.80) / 0.18, 0, 1)) & (v > 0.80) & (v < 0.98)
        eyes |= disc(0.40, 0.68, 0.045) | disc(0.5, 0.70, 0.045) | disc(0.60, 0.68, 0.045)
    elif variant == 3:      # stalker: spidery, many eyes, legs
        mask |= ell(0.5, 0.46, 0.26, 0.20)
        for lx in (0.18, 0.34, 0.66, 0.82):
            mask |= (np.abs(u - lx) < 0.03) & (v < 0.48)
        eyes |= (disc(0.42, 0.52, 0.03) | disc(0.5, 0.55, 0.03)
                 | disc(0.58, 0.52, 0.03) | disc(0.5, 0.46, 0.03))
    else:                   # flyer: orb body with tentacles
        mask |= disc(0.5, 0.6, 0.26)
        for tx in (0.38, 0.5, 0.62):
            mask |= (np.abs(u - tx) < 0.025) & (v < 0.46)
        eyes |= disc(0.44, 0.63, 0.05) | disc(0.56, 0.63, 0.05)

    grad = np.broadcast_to((0.45 + 0.55 * v).astype(np.float32), (size, size))
    rgb = np.where(mask, grad, 0.0).astype(np.float32)
    rgb = np.where(eyes, 1.0, rgb)
    alpha = (mask | eyes).astype(np.float32)
    return np.stack([(rgb * 255).astype(np.uint8)] * 3 + [(alpha * 255).astype(np.uint8)], axis=-1)


def generate_rock(size=96, seed=7):
    rng = np.random.default_rng(seed)
    v = np.linspace(0.0, 1.0, size).reshape(-1, 1)
    cols = np.linspace(0.0, 1.0, size)
    hcol = 0.18 + 0.62 * np.exp(-((cols - 0.5) / 0.30) ** 2)
    hcol = np.clip(hcol + (rng.random(size) - 0.5) * 0.14, 0.0, 0.95).reshape(1, -1)
    mask = v < hcol
    grad = np.broadcast_to((0.35 + 0.55 * v).astype(np.float32), (size, size))
    rgb = np.where(mask, grad, 0.0).astype(np.float32)
    alpha = mask.astype(np.float32)
    return np.stack([(rgb * 255).astype(np.uint8)] * 3 + [(alpha * 255).astype(np.uint8)], axis=-1)


def generate_orb(size=64):
    yy, xx = np.mgrid[-1:1:size * 1j, -1:1:size * 1j]
    r = np.hypot(xx, yy)
    rgb = np.clip(1.2 - r, 0.0, 1.0)
    alpha = (r < 0.85).astype(np.float32)
    return np.stack([(rgb * 255).astype(np.uint8)] * 3 + [(alpha * 255).astype(np.uint8)], axis=-1)
