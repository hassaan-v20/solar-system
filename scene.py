import math
from pathlib import Path

import moderngl
import numpy as np
import pyrr

from mesh import create_orbit_circle, create_ring, create_sphere
from texture_gen import (
    generate_earth_texture,
    generate_jupiter_texture,
    generate_planet_texture,
    generate_sun_texture,
)

SHADER_DIR = Path(__file__).parent / "shaders"

# (name, color, radius, dist, period_yrs, tilt_deg, seed, has_ring)
PLANETS = [
    ("Sun",     (1.00, 0.85, 0.20), 5.0,   0.0,    0.000,   7.25, 0, False),
    ("Mercury", (0.55, 0.45, 0.38), 0.40,  9.5,    0.241,   0.03, 1, False),
    ("Venus",   (0.85, 0.70, 0.30), 0.95, 14.5,    0.615, 177.40, 2, False),
    ("Earth",   (0.20, 0.50, 0.90), 1.00, 20.0,    1.000,  23.44, 3, False),
    ("Mars",    (0.75, 0.30, 0.15), 0.53, 27.0,    1.881,  25.19, 4, False),
    ("Jupiter", (0.82, 0.65, 0.45), 3.20, 39.0,   11.862,   3.13, 5, False),
    ("Saturn",  (0.92, 0.82, 0.55), 2.60, 54.0,   29.457,  26.73, 6,  True),
    ("Uranus",  (0.50, 0.82, 0.90), 1.80, 67.0,   84.011,  97.77, 7, False),
    ("Neptune", (0.20, 0.30, 0.85), 1.75, 80.0,  164.795,  28.32, 8, False),
]

ORBIT_SPEED   = 0.3   # simulation years per real second
RING_INNER    = 1.45  # Saturn ring inner radius in planet-radii
RING_OUTER    = 2.55  # Saturn ring outer radius in planet-radii


class SolarSystem:
    def __init__(self, ctx: moderngl.Context):
        self.ctx = ctx
        self._load_programs()
        self._build_sphere()
        self._build_ring()
        self._build_stars()
        self._build_orbits()
        self._build_textures()
        print("Solar system ready.  Controls: drag=orbit  scroll=zoom  +/-=speed  Space=pause  R=reset")

    # ── shaders ──────────────────────────────────────────────────────────────
    def _load_programs(self):
        def src(name):
            return (SHADER_DIR / name).read_text()

        self.prog_planet = self.ctx.program(
            vertex_shader=src("planet.vert"),
            fragment_shader=src("planet.frag"),
        )
        self.prog_line = self.ctx.program(
            vertex_shader=src("line.vert"),
            fragment_shader=src("line.frag"),
        )
        self.prog_star = self.ctx.program(
            vertex_shader=src("stars.vert"),
            fragment_shader=src("stars.frag"),
        )

    # ── geometry ─────────────────────────────────────────────────────────────
    def _build_sphere(self):
        verts, idx = create_sphere(64)
        vbo = self.ctx.buffer(verts.tobytes())
        ibo = self.ctx.buffer(idx.tobytes())
        self.sphere_vao = self.ctx.vertex_array(
            self.prog_planet,
            [(vbo, "3f 3f 2f", "in_position", "in_normal", "in_texcoord")],
            ibo,
        )

    def _build_ring(self):
        sat_r = next(p[2] for p in PLANETS if p[0] == "Saturn")
        verts, idx = create_ring(sat_r * RING_INNER, sat_r * RING_OUTER, 128)
        vbo = self.ctx.buffer(verts.tobytes())
        ibo = self.ctx.buffer(idx.tobytes())
        self.ring_vao = self.ctx.vertex_array(
            self.prog_planet,
            [(vbo, "3f 3f 2f", "in_position", "in_normal", "in_texcoord")],
            ibo,
        )

    def _build_stars(self):
        rng = np.random.default_rng(42)
        n = 3000
        theta = rng.uniform(0, 2 * math.pi, n)
        phi   = np.arccos(rng.uniform(-1.0, 1.0, n))
        r     = rng.uniform(600, 900, n).astype("f4")
        x = (r * np.sin(phi) * np.cos(theta)).astype("f4")
        y = (r * np.sin(phi) * np.sin(theta)).astype("f4")
        z = (r * np.cos(phi)).astype("f4")
        brightness = rng.uniform(0.4, 1.0, n).astype("f4")
        data = np.column_stack([x, y, z, brightness]).astype("f4")
        vbo = self.ctx.buffer(data.tobytes())
        self.star_vao = self.ctx.vertex_array(
            self.prog_star,
            [(vbo, "3f 1f", "in_position", "in_brightness")],
        )

    def _build_orbits(self):
        self.orbit_vaos = []
        for _, _, _, dist, *_ in PLANETS:
            if dist == 0.0:
                self.orbit_vaos.append(None)
                continue
            verts = create_orbit_circle(dist, 256)
            vbo = self.ctx.buffer(verts.tobytes())
            self.orbit_vaos.append(
                self.ctx.vertex_array(self.prog_line, [(vbo, "3f", "in_position")])
            )

    def _build_textures(self):
        self.textures = []
        for name, color, _, _, _, _, seed, _ in PLANETS:
            if name == "Sun":
                data = generate_sun_texture(256, seed)
            elif name == "Earth":
                data = generate_earth_texture(512, seed)
            elif name == "Jupiter":
                data = generate_jupiter_texture(512, seed)
            else:
                data = generate_planet_texture(color, 256, seed)
            h, w = data.shape[:2]
            tex = self.ctx.texture((w, h), 3, data.tobytes())
            tex.build_mipmaps()
            tex.filter = moderngl.LINEAR_MIPMAP_LINEAR, moderngl.LINEAR
            self.textures.append(tex)

    # ── render ────────────────────────────────────────────────────────────────
    def render(self, camera, time: float):
        view = camera.get_view_matrix()
        proj = camera.get_projection_matrix()

        # Stars (background, no depth)
        self.ctx.disable(moderngl.DEPTH_TEST)
        self.prog_star["view"].write(view)
        self.prog_star["proj"].write(proj)
        self.star_vao.render(moderngl.POINTS)
        self.ctx.enable(moderngl.DEPTH_TEST)

        # Orbit rings
        self.prog_line["view"].write(view)
        self.prog_line["proj"].write(proj)
        self.prog_line["color"].value = (0.3, 0.3, 0.5, 0.22)
        for vao in self.orbit_vaos:
            if vao:
                vao.render(moderngl.LINE_STRIP)

        # Planets and sun
        self.prog_planet["view"].write(view)
        self.prog_planet["proj"].write(proj)
        self.prog_planet["sun_pos"].value = (0.0, 0.0, 0.0)
        self.prog_planet["tex"].value = 0
        self.prog_planet["is_ring"].value = False

        saturn_pos = None
        saturn_tilt = None
        saturn_color = None

        for i, (name, color, radius, dist, period, tilt, seed, has_ring) in enumerate(PLANETS):
            pos = self._orbital_pos(dist, period, time)
            model = self._planet_model(pos, radius, tilt, time, period)

            self.prog_planet["model"].write(model)
            self.prog_planet["tint"].value = color
            self.prog_planet["emit"].value = 3.5 if name == "Sun" else 0.0
            self.prog_planet["is_ring"].value = False
            self.textures[i].use(0)
            self.sphere_vao.render()

            if has_ring:
                saturn_pos   = pos
                saturn_tilt  = tilt
                saturn_color = color

        # Saturn ring drawn last (transparent)
        if saturn_pos is not None:
            T = pyrr.matrix44.create_from_translation(saturn_pos, dtype="f4")
            Z = pyrr.matrix44.create_from_z_rotation(math.radians(saturn_tilt), dtype="f4")
            self.prog_planet["model"].write(T @ Z)
            self.prog_planet["tint"].value = saturn_color
            self.prog_planet["emit"].value = 0.0
            self.prog_planet["is_ring"].value = True
            self.ring_vao.render()

    # ── helpers ───────────────────────────────────────────────────────────────
    def _orbital_pos(self, dist, period, time):
        if dist == 0.0:
            return np.zeros(3, dtype="f4")
        angle = 2.0 * math.pi * time * ORBIT_SPEED / period
        return np.array([dist * math.cos(angle), 0.0, dist * math.sin(angle)], dtype="f4")

    def _planet_model(self, pos, radius, tilt, time, period):
        spin = time * (0.4 if period == 0.0 else 2.0 / max(period, 0.001))
        T = pyrr.matrix44.create_from_translation(pos, dtype="f4")
        Z = pyrr.matrix44.create_from_z_rotation(math.radians(tilt), dtype="f4")
        Y = pyrr.matrix44.create_from_y_rotation(spin, dtype="f4")
        S = pyrr.matrix44.create_from_scale([radius] * 3, dtype="f4")
        return T @ Z @ Y @ S
