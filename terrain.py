"""Procedural heightmap terrain for planet surfaces (mountains + valleys)."""

import numpy as np
from PIL import Image


class Terrain:
    def __init__(self, seed=0, amp=6.0, octaves=5, base_cells=6, extent=130.0, res=110):
        self.extent = float(extent)
        self.res = int(res)
        rng = np.random.default_rng(seed)
        size = self.res + 1

        field = np.zeros((size, size), np.float32)
        a, cells, total = 1.0, base_cells, 0.0
        for _ in range(octaves):
            small = rng.random((cells, cells)).astype(np.float32)
            up = np.asarray(
                Image.fromarray((small * 255).astype(np.uint8)).resize((size, size), Image.BILINEAR),
                dtype=np.float32) / 255.0
            field += up * a
            total += a
            a *= 0.5
            cells = min(cells * 2, size)
        field /= max(total, 1e-6)

        # Ridged detail makes mountains feel sharper.
        field = field ** 1.4
        self.h = ((field - field.mean()) * 2.0 * amp).astype(np.float32)

        # Flatten a small landing clearing at the centre so you don't spawn in rock.
        xs = np.linspace(-self.extent, self.extent, size)
        gx, gz = np.meshgrid(xs, xs)
        clear = np.clip(1.0 - (np.hypot(gx, gz) / 14.0), 0.0, 1.0) ** 2
        self.h *= (1.0 - clear)

    def height(self, x, z):
        res, ext = self.res, self.extent
        u = (x + ext) / (2 * ext) * res
        v = (z + ext) / (2 * ext) * res
        u = min(max(u, 0.0), res - 1e-3)
        v = min(max(v, 0.0), res - 1e-3)
        i, j = int(u), int(v)
        fu, fv = u - i, v - j
        g = self.h
        h0 = g[j, i] * (1 - fu) + g[j, i + 1] * fu
        h1 = g[j + 1, i] * (1 - fu) + g[j + 1, i + 1] * fu
        return float(h0 * (1 - fv) + h1 * fv)

    def mesh(self):
        res, ext = self.res, self.extent
        xs = np.linspace(-ext, ext, res + 1).astype(np.float32)
        X, Z = np.meshgrid(xs, xs)
        Y = self.h
        dz, dx = np.gradient(Y, xs, xs)
        nx, ny, nz = -dx, np.ones_like(Y), -dz
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx / ln, ny / ln, nz / ln
        uv = 1.0 / 7.0
        verts = np.stack([X, Y, Z, nx, ny, nz, X * uv, Z * uv], axis=-1).astype("f4").reshape(-1)

        s = res + 1
        a = np.arange(res * s).reshape(res, s)[:, :res]
        a = a.reshape(-1)
        idx = np.empty((a.size, 6), dtype="u4")
        idx[:, 0] = a
        idx[:, 1] = a + s
        idx[:, 2] = a + 1
        idx[:, 3] = a + 1
        idx[:, 4] = a + s
        idx[:, 5] = a + s + 1
        return verts, idx.reshape(-1)
