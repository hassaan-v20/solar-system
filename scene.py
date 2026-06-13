import math
from pathlib import Path

import moderngl
import numpy as np
import pyrr

from mesh import (
    create_fullscreen_quad,
    create_orbit_circle,
    create_ring,
    create_sphere,
)
from world import ORBIT_SPEED, body_world_pos

SHADER_DIR = Path(__file__).parent / "shaders"
TEX_DIR = Path(__file__).parent / "textures"

RING_INNER    = 1.45
RING_OUTER    = 2.55
EARTH_ATMO    = (0.30, 0.55, 1.00)
BLOOM_ITERS   = 5

MOON_DIST   = 2.4
MOON_RADIUS = 0.27
MOON_PERIOD = 0.075

IDENTITY = pyrr.matrix44.create_identity(dtype="f4")


class SolarSystem:
    def __init__(self, ctx: moderngl.Context):
        self.ctx = ctx
        self.fbo_size = (0, 0)
        self.scene_fbo = None
        self.pp_fbos = []
        self._load_programs()
        self._build_geometry()
        self._build_textures()
        print("Renderer ready.")

    # ── shaders ──────────────────────────────────────────────────────────────
    def _load_programs(self):
        def src(name):
            return (SHADER_DIR / name).read_text()

        self.prog_planet = self.ctx.program(src("planet.vert"), src("planet.frag"))
        self.prog_cloud  = self.ctx.program(src("planet.vert"), src("cloud.frag"))
        self.prog_ring   = self.ctx.program(src("planet.vert"), src("ring.frag"))
        self.prog_line   = self.ctx.program(src("line.vert"), src("line.frag"))
        self.prog_sky    = self.ctx.program(src("skybox.vert"), src("skybox.frag"))
        self.prog_bright = self.ctx.program(src("fsquad.vert"), src("brightpass.frag"))
        self.prog_blur   = self.ctx.program(src("fsquad.vert"), src("blur.frag"))
        self.prog_comp   = self.ctx.program(src("fsquad.vert"), src("composite.frag"))

    # ── geometry ─────────────────────────────────────────────────────────────
    def _full_vao(self, prog, vbo, ibo):
        return self.ctx.vertex_array(
            prog, [(vbo, "3f 3f 2f", "in_position", "in_normal", "in_texcoord")], ibo
        )

    def _build_geometry(self):
        verts, idx = create_sphere(96)
        svbo = self.ctx.buffer(verts.tobytes())
        sibo = self.ctx.buffer(idx.tobytes())
        self.sphere_planet = self._full_vao(self.prog_planet, svbo, sibo)
        self.sphere_cloud  = self._full_vao(self.prog_cloud, svbo, sibo)
        self.sphere_sky    = self.ctx.vertex_array(
            self.prog_sky, [(svbo, "3f 20x", "in_position")], sibo
        )

        rverts, ridx = create_ring(RING_INNER, RING_OUTER, 192)
        rvbo = self.ctx.buffer(rverts.tobytes())
        ribo = self.ctx.buffer(ridx.tobytes())
        self.ring_vao = self._full_vao(self.prog_ring, rvbo, ribo)

        # Unit circle, scaled per-orbit via the line shader's model matrix.
        cvbo = self.ctx.buffer(create_orbit_circle(1.0, 256).tobytes())
        self.circle_vao = self.ctx.vertex_array(self.prog_line, [(cvbo, "3f", "in_position")])

        quad = self.ctx.buffer(create_fullscreen_quad().tobytes())
        self.quad_bright = self.ctx.vertex_array(self.prog_bright, [(quad, "2f", "in_position")])
        self.quad_blur   = self.ctx.vertex_array(self.prog_blur, [(quad, "2f", "in_position")])
        self.quad_comp   = self.ctx.vertex_array(self.prog_comp, [(quad, "2f", "in_position")])

    # ── textures ─────────────────────────────────────────────────────────────
    def _load(self, name, alpha=False):
        from PIL import Image
        img = Image.open(TEX_DIR / name)
        img = img.convert("RGBA" if alpha else "RGB").transpose(Image.FLIP_TOP_BOTTOM)
        tex = self.ctx.texture(img.size, 4 if alpha else 3, img.tobytes())
        tex.build_mipmaps()
        tex.filter = (moderngl.LINEAR_MIPMAP_LINEAR, moderngl.LINEAR)
        try:
            tex.anisotropy = 8.0
        except Exception:
            pass
        return tex

    def _build_textures(self):
        self.tex = {}
        for path in TEX_DIR.glob("*"):
            if path.suffix.lower() in (".jpg", ".jpeg", ".png"):
                self.tex[path.name] = self._load(path.name, alpha=path.suffix.lower() == ".png")

    def _get_tex(self, name):
        return self.tex.get(name) or self.tex.get("2k_moon.jpg")

    # ── framebuffers (bloom) ───────────────────────────────────────────────────
    def resize(self, width, height):
        width, height = max(1, width), max(1, height)
        if (width, height) == self.fbo_size:
            return
        self.fbo_size = (width, height)

        for fbo in [self.scene_fbo] + self.pp_fbos:
            if fbo:
                fbo.release()
        if getattr(self, "scene_color", None):
            self.scene_color.release()
            self.scene_depth.release()
            for t in self.pp_colors:
                t.release()

        self.scene_color = self.ctx.texture((width, height), 4, dtype="f2")
        self.scene_color.filter = (moderngl.LINEAR, moderngl.LINEAR)
        self.scene_depth = self.ctx.depth_renderbuffer((width, height))
        self.scene_fbo = self.ctx.framebuffer([self.scene_color], self.scene_depth)

        hw, hh = max(1, width // 2), max(1, height // 2)
        self.pp_half = (hw, hh)
        self.pp_colors, self.pp_fbos = [], []
        for _ in range(2):
            t = self.ctx.texture((hw, hh), 4, dtype="f2")
            t.filter = (moderngl.LINEAR, moderngl.LINEAR)
            t.repeat_x = t.repeat_y = False
            self.pp_colors.append(t)
            self.pp_fbos.append(self.ctx.framebuffer([t]))

    # ── render ──────────────────────────────────────────────────────────────
    def render(self, world, camera, time, preview=None):
        if self.scene_fbo is None:
            self.resize(camera.width, camera.height)

        view = camera.get_view_matrix()
        proj = camera.get_projection_matrix()
        cam_pos = tuple(float(x) for x in camera.position)
        ctx = self.ctx

        self.scene_fbo.use()
        ctx.clear(0.0, 0.0, 0.0)

        # Galaxy skybox.
        ctx.disable(moderngl.DEPTH_TEST)
        ctx.depth_mask = False
        self.prog_sky["view"].write(view)
        self.prog_sky["proj"].write(proj)
        self.prog_sky["tex"].value = 0
        self._get_tex("8k_stars_milky_way.jpg").use(0)
        self.sphere_sky.render()
        ctx.depth_mask = True
        ctx.enable(moderngl.DEPTH_TEST)

        # Orbit guide rings (one per living, orbiting body).
        self.prog_line["view"].write(view)
        self.prog_line["proj"].write(proj)
        self.prog_line["color"].value = (0.30, 0.32, 0.55, 0.16)
        for b in world.bodies:
            if b.alive and b.dist > 0.0:
                self.prog_line["model"].write(self._scale(b.dist))
                self.circle_vao.render(moderngl.LINE_STRIP)

        # Placement preview ring + marker.
        if preview is not None:
            ok = preview["ok"]
            col = (0.3, 1.0, 0.8, 0.7) if ok else (1.0, 0.3, 0.3, 0.7)
            self.prog_line["color"].value = col
            self.prog_line["model"].write(self._scale(preview["dist"]))
            self.circle_vao.render(moderngl.LINE_STRIP)

        # Bodies.
        p = self.prog_planet
        p["view"].write(view)
        p["proj"].write(proj)
        p["sun_pos"].value = (0.0, 0.0, 0.0)
        p["cam_pos"].value = cam_pos
        p["tex"].value = 0
        p["night_tex"].value = 1
        p["atmo_color"].value = EARTH_ATMO

        earths = []
        saturns = []
        for b in world.bodies:
            if not b.alive:
                continue
            pos = np.array(body_world_pos(b, time), dtype="f4")
            p["model"].write(self._body_model(pos, b.radius, b.tilt, time, b.period))
            p["emit"].value = 6.0 if b.special == "sun" else 0.0
            p["is_earth"].value = 1 if b.special == "earth" else 0
            self._get_tex(b.texture).use(0)
            if b.special == "earth":
                self._get_tex("2k_earth_nightmap.jpg").use(1)
                earths.append((pos, b.radius))
            self.sphere_planet.render()
            if b.special == "saturn":
                saturns.append((pos, b.radius, b.tilt))

        # Comets — small glowing heads (bloom makes them streak nicely).
        for c in world.comets:
            pos = np.array([c.x, c.y, c.z], dtype="f4")
            p["model"].write(self._body_model(pos, 0.32, 0.0, time, 0.05))
            p["emit"].value = 2.2
            p["is_earth"].value = 0
            self._get_tex("2k_moon.jpg").use(0)
            self.sphere_planet.render()

        # Preview body marker (glowing ghost at the cursor).
        if preview is not None:
            pos = np.array([preview["x"], 0.0, preview["z"]], dtype="f4")
            p["model"].write(self._body_model(pos, preview["radius"], 0.0, time, 0.2))
            p["emit"].value = 1.1 if preview["ok"] else 0.4
            p["is_earth"].value = 0
            self._get_tex("2k_moon.jpg").use(0)
            self.sphere_planet.render()

        # Moons + cloud shells for earth-like bodies.
        for pos, radius in earths:
            ang = 2.0 * math.pi * time * ORBIT_SPEED / MOON_PERIOD
            moon = pos + np.array([MOON_DIST * math.cos(ang), 0.0, MOON_DIST * math.sin(ang)], dtype="f4")
            p["model"].write(self._body_model(moon, MOON_RADIUS, 6.7, time, MOON_PERIOD))
            p["emit"].value = 0.0
            p["is_earth"].value = 0
            self._get_tex("2k_moon.jpg").use(0)
            self.sphere_planet.render()

            ctx.depth_mask = False
            c = self.prog_cloud
            c["view"].write(view)
            c["proj"].write(proj)
            c["sun_pos"].value = (0.0, 0.0, 0.0)
            c["tex"].value = 0
            c["model"].write(self._body_model(pos, radius * 1.015, 23.44, time, 0.9))
            self._get_tex("2k_earth_clouds.jpg").use(0)
            self.sphere_cloud.render()
            ctx.depth_mask = True

        # Saturn rings.
        for spos, sradius, stilt in saturns:
            ctx.depth_mask = False
            r = self.prog_ring
            r["view"].write(view)
            r["proj"].write(proj)
            r["sun_pos"].value = (0.0, 0.0, 0.0)
            r["planet_pos"].value = tuple(float(x) for x in spos)
            r["planet_radius"].value = float(sradius)
            r["tex"].value = 0
            T = pyrr.matrix44.create_from_translation(spos, dtype="f4")
            Z = pyrr.matrix44.create_from_z_rotation(math.radians(stilt), dtype="f4")
            S = pyrr.matrix44.create_from_scale([sradius] * 3, dtype="f4")
            r["model"].write(T @ Z @ S)
            self._get_tex("2k_saturn_ring_alpha.png").use(0)
            self.ring_vao.render()
            ctx.depth_mask = True

        self._bloom_and_present()

    # ── bloom ───────────────────────────────────────────────────────────────
    def _bloom_and_present(self):
        ctx = self.ctx
        ctx.disable(moderngl.DEPTH_TEST)
        ctx.disable(moderngl.BLEND)
        hw, hh = self.pp_half

        self.pp_fbos[0].use()
        ctx.clear(0.0, 0.0, 0.0)
        self.prog_bright["scene"].value = 0
        self.prog_bright["threshold"].value = 1.0
        self.scene_color.use(0)
        self.quad_bright.render(moderngl.TRIANGLE_STRIP)

        self.prog_blur["image"].value = 0
        src, dst = 0, 1
        for _ in range(BLOOM_ITERS):
            for dx, dy in ((1.0 / hw, 0.0), (0.0, 1.0 / hh)):
                self.pp_fbos[dst].use()
                ctx.clear(0.0, 0.0, 0.0)
                self.prog_blur["direction"].value = (dx, dy)
                self.pp_colors[src].use(0)
                self.quad_blur.render(moderngl.TRIANGLE_STRIP)
                src, dst = dst, src

        ctx.screen.use()
        ctx.clear(0.0, 0.0, 0.0)
        self.prog_comp["scene"].value = 0
        self.prog_comp["bloom"].value = 1
        self.prog_comp["exposure"].value = 1.25
        self.scene_color.use(0)
        self.pp_colors[src].use(1)
        self.quad_comp.render(moderngl.TRIANGLE_STRIP)

        ctx.enable(moderngl.BLEND)
        ctx.enable(moderngl.DEPTH_TEST)

    # ── helpers ────────────────────────────────────────────────────────────────
    def _scale(self, s):
        return pyrr.matrix44.create_from_scale([s, s, s], dtype="f4")

    def _body_model(self, pos, radius, tilt, time, period):
        spin = time * (0.4 if period == 0.0 else 2.0 / max(period, 0.001))
        T = pyrr.matrix44.create_from_translation(pos, dtype="f4")
        Z = pyrr.matrix44.create_from_z_rotation(math.radians(tilt), dtype="f4")
        Y = pyrr.matrix44.create_from_y_rotation(spin, dtype="f4")
        S = pyrr.matrix44.create_from_scale([radius] * 3, dtype="f4")
        return T @ Z @ Y @ S
