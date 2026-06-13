import math
from pathlib import Path

import moderngl
import numpy as np
import pyrr
from PIL import Image

from mesh import (
    create_fullscreen_quad,
    create_orbit_circle,
    create_ring,
    create_sphere,
)

SHADER_DIR = Path(__file__).parent / "shaders"
TEX_DIR = Path(__file__).parent / "textures"

# (name, texture, radius, dist, period_yrs, tilt_deg, special)
PLANETS = [
    ("Sun",     "2k_sun.jpg",           5.00,  0.0,   0.000,   7.25, "sun"),
    ("Mercury", "2k_mercury.jpg",       0.40,  9.5,   0.241,   0.03, None),
    ("Venus",   "2k_venus_surface.jpg", 0.95, 14.5,   0.615, 177.40, None),
    ("Earth",   "2k_earth_daymap.jpg",  1.00, 20.0,   1.000,  23.44, "earth"),
    ("Mars",    "2k_mars.jpg",          0.53, 27.0,   1.881,  25.19, None),
    ("Jupiter", "2k_jupiter.jpg",       3.20, 39.0,  11.862,   3.13, None),
    ("Saturn",  "2k_saturn.jpg",        2.60, 54.0,  29.457,  26.73, "saturn"),
    ("Uranus",  "2k_uranus.jpg",        1.80, 67.0,  84.011,  97.77, None),
    ("Neptune", "2k_neptune.jpg",       1.75, 80.0, 164.795,  28.32, None),
]

ORBIT_SPEED   = 0.3    # simulation years per real second at speed 1.0
RING_INNER    = 1.45   # Saturn ring inner radius, in planet radii
RING_OUTER    = 2.55   # Saturn ring outer radius, in planet radii
EARTH_ATMO    = (0.30, 0.55, 1.00)
BLOOM_ITERS   = 5
SKYBOX_RADIUS = 900.0

# Moon: orbit radius (in Earth radii), body radius, orbital period (sim years)
MOON_DIST   = 2.4
MOON_RADIUS = 0.27
MOON_PERIOD = 0.075


class SolarSystem:
    def __init__(self, ctx: moderngl.Context):
        self.ctx = ctx
        self.fbo_size = (0, 0)
        self.scene_fbo = None
        self.pp_fbos = []
        self._load_programs()
        self._build_geometry()
        self._build_textures()
        print("Solar system ready.  drag = orbit   scroll = zoom   +/- = speed   Space = pause   R = reset")

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
        # in_position / in_normal / in_texcoord
        return self.ctx.vertex_array(
            prog,
            [(vbo, "3f 3f 2f", "in_position", "in_normal", "in_texcoord")],
            ibo,
        )

    def _pos_only_vao(self, prog, vbo, ibo):
        # Skybox shader uses only in_position; pad past normal+uv (20 bytes).
        return self.ctx.vertex_array(prog, [(vbo, "3f 20x", "in_position")], ibo)

    def _build_geometry(self):
        verts, idx = create_sphere(96)
        svbo = self.ctx.buffer(verts.tobytes())
        sibo = self.ctx.buffer(idx.tobytes())
        self.sphere_planet = self._full_vao(self.prog_planet, svbo, sibo)
        self.sphere_cloud  = self._full_vao(self.prog_cloud, svbo, sibo)
        self.sphere_sky    = self._pos_only_vao(self.prog_sky, svbo, sibo)

        sat_r = next(p[2] for p in PLANETS if p[0] == "Saturn")
        rverts, ridx = create_ring(sat_r * RING_INNER, sat_r * RING_OUTER, 192)
        rvbo = self.ctx.buffer(rverts.tobytes())
        ribo = self.ctx.buffer(ridx.tobytes())
        self.ring_vao = self._full_vao(self.prog_ring, rvbo, ribo)

        self.orbit_vaos = []
        for _, _, _, dist, *_ in PLANETS:
            if dist == 0.0:
                self.orbit_vaos.append(None)
                continue
            vbo = self.ctx.buffer(create_orbit_circle(dist, 256).tobytes())
            self.orbit_vaos.append(
                self.ctx.vertex_array(self.prog_line, [(vbo, "3f", "in_position")])
            )

        quad = self.ctx.buffer(create_fullscreen_quad().tobytes())
        self.quad_bright = self.ctx.vertex_array(self.prog_bright, [(quad, "2f", "in_position")])
        self.quad_blur   = self.ctx.vertex_array(self.prog_blur, [(quad, "2f", "in_position")])
        self.quad_comp   = self.ctx.vertex_array(self.prog_comp, [(quad, "2f", "in_position")])

    # ── textures ─────────────────────────────────────────────────────────────
    def _load(self, name, alpha=False):
        img = Image.open(TEX_DIR / name)
        img = img.convert("RGBA" if alpha else "RGB")
        img = img.transpose(Image.FLIP_TOP_BOTTOM)  # PIL top-left -> GL bottom-left
        comps = 4 if alpha else 3
        tex = self.ctx.texture(img.size, comps, img.tobytes())
        tex.build_mipmaps()
        tex.filter = (moderngl.LINEAR_MIPMAP_LINEAR, moderngl.LINEAR)
        try:
            tex.anisotropy = 8.0
        except Exception:
            pass
        return tex

    def _build_textures(self):
        self.textures = [self._load(p[1]) for p in PLANETS]
        self.tex_skybox = self._load("8k_stars_milky_way.jpg")
        self.tex_night  = self._load("2k_earth_nightmap.jpg")
        self.tex_cloud  = self._load("2k_earth_clouds.jpg")
        self.tex_ring   = self._load("2k_saturn_ring_alpha.png", alpha=True)
        self.tex_moon   = self._load("2k_moon.jpg")

    # ── framebuffers (bloom pipeline) ──────────────────────────────────────────
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
    def render(self, camera, time: float):
        if self.scene_fbo is None:
            self.resize(camera.width, camera.height)

        view = camera.get_view_matrix()
        proj = camera.get_projection_matrix()
        cam_pos = tuple(float(x) for x in camera.position)
        ctx = self.ctx

        self.scene_fbo.use()
        ctx.clear(0.0, 0.0, 0.0)

        # Galaxy skybox: drawn first, never writes depth.
        ctx.disable(moderngl.DEPTH_TEST)
        ctx.depth_mask = False
        self.prog_sky["view"].write(view)
        self.prog_sky["proj"].write(proj)
        self.prog_sky["tex"].value = 0
        self.tex_skybox.use(0)
        self.sphere_sky.render()
        ctx.depth_mask = True
        ctx.enable(moderngl.DEPTH_TEST)

        # Orbit guide rings.
        self.prog_line["view"].write(view)
        self.prog_line["proj"].write(proj)
        self.prog_line["color"].value = (0.30, 0.32, 0.55, 0.18)
        for vao in self.orbit_vaos:
            if vao:
                vao.render(moderngl.LINE_STRIP)

        # Planets and Sun.
        p = self.prog_planet
        p["view"].write(view)
        p["proj"].write(proj)
        p["sun_pos"].value = (0.0, 0.0, 0.0)
        p["cam_pos"].value = cam_pos
        p["tex"].value = 0
        p["night_tex"].value = 1
        p["atmo_color"].value = EARTH_ATMO

        earth_pos = None
        earth_radius = 1.0
        saturn = None

        for i, (name, _tex, radius, dist, period, tilt, special) in enumerate(PLANETS):
            pos = self._orbital_pos(dist, period, time)
            p["model"].write(self._body_model(pos, radius, tilt, time, period))
            p["emit"].value = 6.0 if special == "sun" else 0.0
            p["is_earth"].value = 1 if special == "earth" else 0
            self.textures[i].use(0)
            if special == "earth":
                self.tex_night.use(1)
                earth_pos, earth_radius = pos, radius
            self.sphere_planet.render()
            if special == "saturn":
                saturn = (pos, radius, tilt)

        # Earth's Moon.
        if earth_pos is not None:
            ang = 2.0 * math.pi * time * ORBIT_SPEED / MOON_PERIOD
            moon_pos = earth_pos + np.array(
                [MOON_DIST * math.cos(ang), 0.0, MOON_DIST * math.sin(ang)], dtype="f4"
            )
            p["model"].write(self._body_model(moon_pos, MOON_RADIUS, 6.7, time, MOON_PERIOD))
            p["emit"].value = 0.0
            p["is_earth"].value = 0
            self.tex_moon.use(0)
            self.sphere_planet.render()

            # Cloud shell, slightly larger than Earth.
            ctx.depth_mask = False
            c = self.prog_cloud
            c["view"].write(view)
            c["proj"].write(proj)
            c["sun_pos"].value = (0.0, 0.0, 0.0)
            c["tex"].value = 0
            c["model"].write(self._body_model(earth_pos, earth_radius * 1.015, 23.44, time, 0.9))
            self.tex_cloud.use(0)
            self.sphere_cloud.render()
            ctx.depth_mask = True

        # Saturn's rings (transparent, drawn last).
        if saturn is not None:
            spos, sradius, stilt = saturn
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
            r["model"].write(T @ Z)
            self.tex_ring.use(0)
            self.ring_vao.render()
            ctx.depth_mask = True

        self._bloom_and_present()

    # ── bloom post-processing ──────────────────────────────────────────────────
    def _bloom_and_present(self):
        ctx = self.ctx
        ctx.disable(moderngl.DEPTH_TEST)
        ctx.disable(moderngl.BLEND)
        hw, hh = self.pp_half

        # Bright-pass extract into pp[0].
        self.pp_fbos[0].use()
        ctx.clear(0.0, 0.0, 0.0)
        self.prog_bright["scene"].value = 0
        self.prog_bright["threshold"].value = 1.0
        self.scene_color.use(0)
        self.quad_bright.render(moderngl.TRIANGLE_STRIP)

        # Separable Gaussian blur, ping-ponging pp[0] <-> pp[1].
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

        # Composite scene + bloom to the screen with tone mapping.
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
    def _orbital_pos(self, dist, period, time):
        if dist == 0.0:
            return np.zeros(3, dtype="f4")
        angle = 2.0 * math.pi * time * ORBIT_SPEED / period
        return np.array([dist * math.cos(angle), 0.0, dist * math.sin(angle)], dtype="f4")

    def _body_model(self, pos, radius, tilt, time, period):
        spin = time * (0.4 if period == 0.0 else 2.0 / max(period, 0.001))
        T = pyrr.matrix44.create_from_translation(pos, dtype="f4")
        Z = pyrr.matrix44.create_from_z_rotation(math.radians(tilt), dtype="f4")
        Y = pyrr.matrix44.create_from_y_rotation(spin, dtype="f4")
        S = pyrr.matrix44.create_from_scale([radius] * 3, dtype="f4")
        return T @ Z @ Y @ S
