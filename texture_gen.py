import numpy as np
from PIL import Image


def _fbm(size, octaves, seed):
    rng = np.random.default_rng(seed)
    noise = np.zeros((size, size), dtype=np.float32)
    amplitude, freq = 1.0, 4
    for _ in range(octaves):
        small = max(2, size // freq)
        raw = rng.random((small, small)).astype(np.float32)
        layer = np.array(
            Image.fromarray((raw * 255).astype(np.uint8), "L").resize(
                (size, size), Image.BILINEAR
            ),
            dtype=np.float32,
        ) / 255.0
        noise += amplitude * layer
        amplitude *= 0.5
        freq = max(1, freq // 2)
    lo, hi = noise.min(), noise.max()
    return (noise - lo) / max(hi - lo, 1e-6)


def generate_planet_texture(color, size=256, seed=0):
    n = _fbm(size, 6, seed)
    r = np.clip(color[0] * (0.35 + 0.9 * n) * 255, 0, 255).astype(np.uint8)
    g = np.clip(color[1] * (0.35 + 0.9 * n) * 255, 0, 255).astype(np.uint8)
    b = np.clip(color[2] * (0.35 + 0.9 * n) * 255, 0, 255).astype(np.uint8)
    return np.stack([r, g, b], axis=-1)


def generate_earth_texture(size=512, seed=3):
    n = _fbm(size, 7, seed)
    land = n > 0.47
    r = np.where(land, np.clip((0.18 + 0.32 * n) * 255, 0, 255),
                 np.clip((0.02 + 0.12 * n) * 255, 0, 255))
    g = np.where(land, np.clip((0.42 + 0.28 * n) * 255, 0, 255),
                 np.clip((0.18 + 0.28 * n) * 255, 0, 255))
    b = np.where(land, np.clip((0.08 + 0.18 * n) * 255, 0, 255),
                 np.clip((0.52 + 0.42 * n) * 255, 0, 255))
    return np.stack([r.astype(np.uint8), g.astype(np.uint8), b.astype(np.uint8)], axis=-1)


def generate_jupiter_texture(size=512, seed=5):
    n = _fbm(size, 6, seed)
    ys = np.linspace(0, 1, size).reshape(-1, 1)
    bands = (np.sin(ys * 22.0) * 0.5 + np.sin(ys * 9.0) * 0.3 + 1.0) * 0.5
    mixed = np.clip(0.55 * bands + 0.45 * n, 0, 1)
    r = np.clip((0.55 + 0.38 * mixed) * 255, 0, 255).astype(np.uint8)
    g = np.clip((0.38 + 0.28 * mixed) * 255, 0, 255).astype(np.uint8)
    b = np.clip((0.20 + 0.22 * mixed) * 255, 0, 255).astype(np.uint8)
    return np.stack([r, g, b], axis=-1)


def generate_sun_texture(size=256, seed=0):
    n = _fbm(size, 5, seed)
    r = np.clip((0.95 + 0.05 * n) * 255, 0, 255).astype(np.uint8)
    g = np.clip((0.55 + 0.30 * n) * 255, 0, 255).astype(np.uint8)
    b = np.clip((0.05 + 0.10 * n) * 255, 0, 255).astype(np.uint8)
    return np.stack([r, g, b], axis=-1)
