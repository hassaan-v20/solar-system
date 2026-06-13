import math
from pathlib import Path

import moderngl
import numpy as np
import pyrr

from sprites import generate_creature, generate_orb
from surface import CREATURES, ITEM_COLOR

SHADER_DIR = Path(__file__).parent / "shaders"

# planet kind -> (ground texture, ground tint, sky/fog colour)
THEME = {
    "rocky":  ("2k_mercury.jpg",       (1.00, 0.95, 0.90), (0.16, 0.13, 0.11)),
    "ocean":  ("2k_earth_daymap.jpg",  (0.75, 1.00, 0.75), (0.30, 0.50, 0.82)),
    "desert": ("2k_venus_surface.jpg", (1.10, 0.95, 0.60), (0.55, 0.42, 0.28)),
    "lava":   ("2k_venus_surface.jpg", (1.40, 0.50, 0.25), (0.24, 0.07, 0.05)),
    "ice":    ("2k_moon.jpg",          (0.72, 0.85, 1.10), (0.55, 0.64, 0.78)),
    "toxic":  ("2k_venus_surface.jpg", (0.55, 1.10, 0.45), (0.20, 0.34, 0.16)),
    "sulfur": ("2k_venus_surface.jpg", (1.30, 1.15, 0.40), (0.42, 0.40, 0.16)),
}


class SurfaceRenderer:
    def __init__(self, ctx, tex_dict):
        self.ctx = ctx
        self.tex = tex_dict

        def src(n):
            return (SHADER_DIR / n).read_text()

        self.prog_ground = ctx.program(src("surface_ground.vert"), src("surface_ground.frag"))
        self.prog_bb = ctx.program(src("surface_bb.vert"), src("surface_bb.frag"))

        # Big ground quad with tiled UVs.
        S = 130.0
        t = S / 6.0
        g = np.array([
            -S, 0.0, -S, -t, -t,
             S, 0.0, -S,  t, -t,
            -S, 0.0,  S, -t,  t,
             S, 0.0,  S,  t,  t,
        ], dtype="f4")
        gvbo = ctx.buffer(g.tobytes())
        self.ground_vao = ctx.vertex_array(
            self.prog_ground, [(gvbo, "3f 2f", "in_pos", "in_uv")])

        # Unit billboard quad (base on ground).
        q = np.array([
            -0.5, 0.0, 0.0, 0.0,
             0.5, 0.0, 1.0, 0.0,
            -0.5, 1.0, 0.0, 1.0,
             0.5, 1.0, 1.0, 1.0,
        ], dtype="f4")
        qvbo = ctx.buffer(q.tobytes())
        self.bb_vao = ctx.vertex_array(
            self.prog_bb, [(qvbo, "2f 2f", "in_corner", "in_uv")])

        self.tex_creature = self._sprite(generate_creature(128))
        self.tex_orb = self._sprite(generate_orb(64))

    def _sprite(self, data):
        h, w = data.shape[:2]
        tex = self.ctx.texture((w, h), 4, data.tobytes())
        tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
        return tex

    def render(self, surf, width, height):
        ctx = self.ctx
        theme = THEME.get(surf.planet_kind, THEME["rocky"])
        gtex, tint, sky = theme

        eye = np.array([surf.x, 1.7, surf.z], dtype="f4")
        cp, sp = math.cos(surf.pitch), math.sin(surf.pitch)
        fwd = np.array([cp * math.sin(surf.yaw), sp, cp * math.cos(surf.yaw)], dtype="f4")
        view = pyrr.matrix44.create_look_at(eye, eye + fwd,
                                            np.array([0, 1, 0], dtype="f4"), dtype="f4")
        proj = pyrr.matrix44.create_perspective_projection_matrix(
            70.0, width / max(1, height), 0.05, 600.0, dtype="f4")

        up = np.array([0.0, 1.0, 0.0], dtype="f4")
        right = np.cross(fwd, up)
        n = np.linalg.norm(right)
        right = right / n if n > 1e-5 else np.array([1.0, 0.0, 0.0], dtype="f4")

        ctx.screen.use()
        ctx.clear(sky[0], sky[1], sky[2])
        ctx.enable(moderngl.DEPTH_TEST)
        ctx.disable(moderngl.BLEND)

        # Ground.
        self.prog_ground["view"].write(view)
        self.prog_ground["proj"].write(proj)
        self.prog_ground["tex"].value = 0
        self.prog_ground["tint"].value = tuple(tint)
        self.prog_ground["sky"].value = tuple(sky)
        self.prog_ground["cam"].value = (float(surf.x), 1.7, float(surf.z))
        gt = self.tex.get(gtex)
        if gt is not None:
            gt.use(0)
            self.ground_vao.render(moderngl.TRIANGLE_STRIP)

        # Billboards (alpha-cutout, so draw order does not matter).
        self.prog_bb["view"].write(view)
        self.prog_bb["proj"].write(proj)
        self.prog_bb["right"].value = tuple(float(v) for v in right)
        self.prog_bb["up"].value = (0.0, 1.0, 0.0)
        self.prog_bb["tex"].value = 0

        self.tex_creature.use(0)
        for c in surf.creatures:
            if not c.alive:
                continue
            st = CREATURES[c.kind]
            self.prog_bb["center"].value = (float(c.x), 0.0, float(c.z))
            self.prog_bb["size"].value = float(st["size"])
            self.prog_bb["color"].value = tuple(st["color"])
            self.bb_vao.render(moderngl.TRIANGLE_STRIP)

        self.tex_orb.use(0)
        for l in surf.loot:
            if not l.alive:
                continue
            self.prog_bb["center"].value = (float(l.x), 0.4, float(l.z))
            self.prog_bb["size"].value = 0.8
            self.prog_bb["color"].value = tuple(ITEM_COLOR.get(l.item, (1, 1, 1)))
            self.bb_vao.render(moderngl.TRIANGLE_STRIP)

        ctx.enable(moderngl.BLEND)
