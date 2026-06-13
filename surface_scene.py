import math
from pathlib import Path

import moderngl
import numpy as np
import pyrr

from sprites import generate_creature, generate_orb, generate_rock, generate_weapon
from surface import CREATURES, ITEM_COLOR

SHADER_DIR = Path(__file__).parent / "shaders"

# planet kind -> (ground texture, ground tint, sky/fog colour, terrain amplitude)
THEME = {
    "rocky":  ("2k_mercury.jpg",       (1.00, 0.95, 0.90), (0.16, 0.13, 0.11), 26.0),
    "ocean":  ("2k_earth_daymap.jpg",  (0.70, 1.00, 0.72), (0.35, 0.55, 0.85), 12.0),
    "desert": ("2k_venus_surface.jpg", (1.12, 0.92, 0.55), (0.62, 0.46, 0.28), 28.0),
    "lava":   ("2k_venus_surface.jpg", (1.45, 0.45, 0.22), (0.26, 0.07, 0.05), 42.0),
    "ice":    ("2k_moon.jpg",          (0.72, 0.85, 1.12), (0.62, 0.70, 0.82), 22.0),
    "toxic":  ("2k_venus_surface.jpg", (0.50, 1.10, 0.42), (0.20, 0.36, 0.16), 26.0),
    "sulfur": ("2k_venus_surface.jpg", (1.30, 1.12, 0.38), (0.48, 0.44, 0.16), 30.0),
}


class SurfaceRenderer:
    def __init__(self, ctx, tex_dict):
        self.ctx = ctx
        self.tex = tex_dict

        def src(n):
            return (SHADER_DIR / n).read_text()

        self.prog_ground = ctx.program(src("surface_ground.vert"), src("surface_ground.frag"))
        self.prog_bb = ctx.program(src("surface_bb.vert"), src("surface_bb.frag"))

        q = np.array([
            -0.5, 0.0, 0.0, 0.0,
             0.5, 0.0, 1.0, 0.0,
            -0.5, 1.0, 0.0, 1.0,
             0.5, 1.0, 1.0, 1.0,
        ], dtype="f4")
        qvbo = ctx.buffer(q.tobytes())
        self.bb_vao = ctx.vertex_array(self.prog_bb, [(qvbo, "2f 2f", "in_corner", "in_uv")])

        self.tex_creature = {var: self._sprite(generate_creature(var, 192)) for var in range(5)}
        self.tex_orb = self._sprite(generate_orb(64))
        self.tex_rock = self._sprite(generate_rock(96))
        self.weapon_tex = {k: self._sprite(generate_weapon(k))
                           for k in ("fists", "blade", "bow", "blaster")}

        self._terrain = None
        self._terrain_vao = None
        self._rocks = []

    def _sprite(self, data):
        h, w = data.shape[:2]
        tex = self.ctx.texture((w, h), 4, data.tobytes())
        tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
        return tex

    def _ensure_terrain(self, terrain):
        if terrain is self._terrain or terrain is None:
            return
        self._terrain = terrain
        verts, idx = terrain.mesh()
        vbo = self.ctx.buffer(verts.tobytes())
        ibo = self.ctx.buffer(idx.tobytes())
        self._terrain_vao = self.ctx.vertex_array(
            self.prog_ground, [(vbo, "3f 3f 2f", "in_pos", "in_nrm", "in_uv")], ibo)
        rng = np.random.default_rng(1234)
        self._rocks = []
        for _ in range(46):
            x, z = rng.uniform(-105, 105), rng.uniform(-105, 105)
            if math.hypot(x, z) < 16:
                continue
            self._rocks.append((float(x), float(z), float(rng.uniform(2.0, 6.0))))

    def render(self, surf, width, height):
        ctx = self.ctx
        gtex, tint, base_sky, _amp = THEME.get(surf.planet_kind, THEME["rocky"])
        self._ensure_terrain(surf.terrain)

        dl = surf.daylight                       # 1 day .. 0 night
        night_sky = tuple(c * 0.16 + 0.02 for c in base_sky)
        sky = tuple(night_sky[i] * (1 - dl) + base_sky[i] * dl for i in range(3))

        def gh(x, z):
            return surf.terrain.height(x, z) if surf.terrain else 0.0

        eye_y = gh(surf.x, surf.z) + surf.eye_off
        eye = np.array([surf.x, eye_y, surf.z], dtype="f4")
        cp, sp = math.cos(surf.pitch), math.sin(surf.pitch)
        fwd = np.array([cp * math.sin(surf.yaw), sp, cp * math.cos(surf.yaw)], dtype="f4")
        view = pyrr.matrix44.create_look_at(eye, eye + fwd,
                                            np.array([0, 1, 0], dtype="f4"), dtype="f4")
        proj = pyrr.matrix44.create_perspective_projection_matrix(
            72.0, width / max(1, height), 0.05, 700.0, dtype="f4")
        up = np.array([0.0, 1.0, 0.0], dtype="f4")
        right = np.cross(fwd, up)
        nrm = np.linalg.norm(right)
        right = right / nrm if nrm > 1e-5 else np.array([1.0, 0.0, 0.0], dtype="f4")

        sun_dir = surf.sky[0]["dir"] if surf.sky else (0.4, 0.8, 0.3)
        day_amb = tuple(base_sky[i] * 0.5 + 0.18 for i in range(3))
        night_amb = (0.07, 0.08, 0.14)
        ambient = tuple(night_amb[i] * (1 - dl) + day_amb[i] * dl for i in range(3))
        sun_col = tuple(c * (0.16 + 0.84 * dl) for c in (1.0, 0.95, 0.85))

        ctx.screen.use()
        ctx.clear(sky[0], sky[1], sky[2])
        ctx.enable(moderngl.DEPTH_TEST)
        ctx.disable(moderngl.BLEND)

        if self._terrain_vao is not None:
            g = self.prog_ground
            g["view"].write(view)
            g["proj"].write(proj)
            g["tex"].value = 0
            g["tint"].value = tuple(tint)
            g["sky"].value = tuple(sky)
            g["cam"].value = (float(surf.x), eye_y, float(surf.z))
            g["sun_dir"].value = tuple(float(v) for v in sun_dir)
            g["sun_col"].value = sun_col
            g["ambient"].value = ambient
            gt = self.tex.get(gtex)
            if gt is not None:
                gt.use(0)
                self._terrain_vao.render()

        self.prog_bb["view"].write(view)
        self.prog_bb["proj"].write(proj)
        self.prog_bb["right"].value = tuple(float(v) for v in right)
        self.prog_bb["up"].value = (0.0, 1.0, 0.0)
        self.prog_bb["tex"].value = 0
        self.prog_bb["lit"].value = 0

        # Celestial bodies (Sun + planets) far in the sky.
        BIGR = 480.0
        self.tex_orb.use(0)

        def sky_quad(dx, dy, dz, size, color):
            self.prog_bb["center"].value = (float(surf.x) + dx * BIGR,
                                            eye_y + dy * BIGR - size * 0.5,
                                            float(surf.z) + dz * BIGR)
            self.prog_bb["size"].value = size
            self.prog_bb["color"].value = color
            self.bb_vao.render(moderngl.TRIANGLE_STRIP)

        for i, sb in enumerate(surf.sky):
            dx, dy, dz = sb["dir"]
            col = sb["color"]
            if i == 0:                       # the Sun fades out at night
                col = tuple(c * dl for c in col)
                if dl < 0.05:
                    continue
            sky_quad(dx, dy, dz, sb["size"], tuple(col))

        # Moon, rising as the Sun sets.
        if dl < 0.7:
            b = (1.0 - dl) * 0.95
            sky_quad(0.35, 0.72, -0.45, 34.0, (b, b, b * 0.95))

        # Rocks.
        self.tex_rock.use(0)
        self.prog_bb["color"].value = (tint[0] * 0.55, tint[1] * 0.55, tint[2] * 0.55)
        for rx, rz, rs in self._rocks:
            self.prog_bb["center"].value = (rx, gh(rx, rz), rz)
            self.prog_bb["size"].value = rs
            self.bb_vao.render(moderngl.TRIANGLE_STRIP)

        # Creatures (with hop / hover animation), lit volumetrically.
        self.prog_bb["lit"].value = 1
        tnow = surf.time
        for c in surf.creatures:
            if not c.alive:
                continue
            st = CREATURES[c.kind]
            base = gh(c.x, c.z)
            hover = st.get("hover", 0.0)
            if hover > 0.0:
                y = base + hover + math.sin(tnow * 2.2 + c.phase) * 0.5
            else:
                y = base + abs(math.sin(tnow * 6.0 + c.phase)) * 0.18
            self.tex_creature[st["variant"]].use(0)
            self.prog_bb["center"].value = (float(c.x), float(y), float(c.z))
            self.prog_bb["size"].value = float(st["size"])
            self.prog_bb["color"].value = tuple(st["color"])
            self.bb_vao.render(moderngl.TRIANGLE_STRIP)

        # Loot.
        self.prog_bb["lit"].value = 0
        self.tex_orb.use(0)
        for l in surf.loot:
            if not l.alive:
                continue
            self.prog_bb["center"].value = (float(l.x), gh(l.x, l.z) + 0.4, float(l.z))
            self.prog_bb["size"].value = 0.8
            self.prog_bb["color"].value = tuple(ITEM_COLOR.get(l.item, (1, 1, 1)))
            self.bb_vao.render(moderngl.TRIANGLE_STRIP)

        ctx.enable(moderngl.BLEND)
