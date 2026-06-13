"""Procedural galaxy / nebula sprites for the distant background billboards."""

import numpy as np
from PIL import Image, ImageFilter


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

    # Channels for the lit shader: R = albedo, G = height (bulge), B = eye glow, A = mask.
    maskf = mask.astype(np.float32)
    blur = Image.fromarray((maskf * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(size * 0.05))
    height = np.asarray(blur, dtype=np.float32) / 255.0 * maskf
    if height.max() > 0:
        height /= height.max()
    R = np.where(mask, 0.88, 0.0).astype(np.float32)
    G = height
    B = eyes.astype(np.float32)
    A = (mask | eyes).astype(np.float32)
    return np.stack([(R * 255).astype(np.uint8), (G * 255).astype(np.uint8),
                     (B * 255).astype(np.uint8), (A * 255).astype(np.uint8)], axis=-1)


def _seg(u, w, p0, p1, th):
    ax, ay = p0
    bx, by = p1
    abx, aby = bx - ax, by - ay
    L2 = abx * abx + aby * aby + 1e-6
    t = np.clip(((u - ax) * abx + (w - ay) * aby) / L2, 0.0, 1.0)
    cx, cy = ax + t * abx, ay + t * aby
    return (u - cx) ** 2 + (w - cy) ** 2 <= th * th


def generate_weapon(kind, size=256):
    """First-person weapon viewmodel sprite (full colour, row 0 = top)."""
    w = np.linspace(0.0, 1.0, size).reshape(-1, 1)   # 0 top -> 1 bottom
    u = np.linspace(0.0, 1.0, size).reshape(1, -1)
    rgb = np.zeros((size, size, 3), np.float32)
    a = np.zeros((size, size), np.float32)

    def paint(mask, col):
        for c in range(3):
            rgb[..., c] = np.where(mask, col[c], rgb[..., c])
        a[mask] = 1.0

    if kind == "blade":
        blade = _seg(u, w, (0.30, 0.92), (0.80, 0.16), 0.035)
        edge = _seg(u, w, (0.32, 0.90), (0.80, 0.18), 0.012)
        guard = _seg(u, w, (0.18, 0.74), (0.46, 0.92), 0.028)
        grip = _seg(u, w, (0.20, 0.78), (0.30, 0.99), 0.022)
        paint(blade, (0.62, 0.66, 0.72))
        paint(edge, (0.92, 0.95, 1.0))
        paint(guard, (0.80, 0.65, 0.25))
        paint(grip, (0.35, 0.22, 0.12))
    elif kind == "bow":
        ang = np.arctan2(w - 0.5, u - 0.28)
        r = np.hypot(u - 0.28, w - 0.5)
        arc = (np.abs(r - 0.42) < 0.03) & (np.abs(ang) < 1.25)
        string = _seg(u, w, (0.28 + 0.42 * np.cos(1.25), 0.5 - 0.42 * np.sin(1.25)),
                      (0.28 + 0.42 * np.cos(1.25), 0.5 + 0.42 * np.sin(1.25)), 0.006)
        arrow = _seg(u, w, (0.30, 0.5), (0.78, 0.5), 0.012)
        tip = _seg(u, w, (0.78, 0.5), (0.86, 0.5), 0.03)
        paint(arc, (0.45, 0.28, 0.14))
        paint(string, (0.9, 0.9, 0.85))
        paint(arrow, (0.6, 0.45, 0.3))
        paint(tip, (0.85, 0.88, 0.95))
    elif kind == "blaster":
        body = (np.abs(u - 0.5) < 0.16) & (np.abs(w - 0.5) < 0.10)
        barrel = (u > 0.5) & (u < 0.92) & (np.abs(w - 0.46) < 0.045)
        grip = _seg(u, w, (0.42, 0.58), (0.34, 0.92), 0.05)
        glow = (u - 0.90) ** 2 + (w - 0.46) ** 2 <= 0.04 ** 2
        paint(body, (0.30, 0.34, 0.42))
        paint(barrel, (0.45, 0.50, 0.58))
        paint(grip, (0.22, 0.24, 0.30))
        paint(glow, (0.5, 1.0, 1.0))
    else:  # fists
        fist = ((u - 0.5) / 0.22) ** 2 + ((w - 0.7) / 0.22) ** 2 <= 1.0
        knuckles = ((u - 0.5) / 0.22) ** 2 + ((w - 0.55) / 0.07) ** 2 <= 1.0
        paint(fist | knuckles, (0.80, 0.62, 0.5))

    out = np.concatenate([(rgb * 255).astype(np.uint8),
                          (a[..., None] * 255).astype(np.uint8)], axis=-1)
    return out


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
