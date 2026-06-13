"""Minimal 2D overlay for an OpenGL-mode Pygame window.

There is no SDL surface to blit onto in OpenGL mode, so text is rasterised with
pygame.font into an RGBA texture and drawn as a screen-space quad. Textures are
rebuilt each frame and released in end(), which is plenty fast for a few labels.
"""

import numpy as np
import pygame
import moderngl

_VERT = """
#version 330 core
in vec2 in_pos;
in vec2 in_uv;
out vec2 v_uv;
void main() {
    v_uv = in_uv;
    gl_Position = vec4(in_pos, 0.0, 1.0);
}
"""

_FRAG = """
#version 330 core
in vec2 v_uv;
uniform sampler2D tex;
uniform vec4 tint;
out vec4 frag_color;
void main() {
    frag_color = texture(tex, v_uv) * tint;
}
"""


class Hud:
    def __init__(self, ctx):
        self.ctx = ctx
        self.width = 1
        self.height = 1
        self.prog = ctx.program(vertex_shader=_VERT, fragment_shader=_FRAG)
        self.vbo = ctx.buffer(reserve=4 * 4 * 4)  # 4 verts * (2 pos + 2 uv) * f4
        self.vao = ctx.vertex_array(self.prog, [(self.vbo, "2f 2f", "in_pos", "in_uv")])
        self.white = ctx.texture((1, 1), 4, b"\xff\xff\xff\xff")
        self._fonts = {}
        self._temp = []

    def resize(self, width, height):
        self.width, self.height = max(1, width), max(1, height)

    def _font(self, size):
        if size not in self._fonts:
            try:
                self._fonts[size] = pygame.font.SysFont("consolas,couriernew", size)
            except Exception:
                self._fonts[size] = pygame.font.Font(None, size)
        return self._fonts[size]

    def begin(self):
        self.ctx.disable(moderngl.DEPTH_TEST)
        self.ctx.enable(moderngl.BLEND)
        self._temp = []

    def end(self):
        for t in self._temp:
            t.release()
        self._temp = []
        self.ctx.enable(moderngl.DEPTH_TEST)

    def _draw(self, px, py, w, h, tex, tint):
        x0 = 2.0 * px / self.width - 1.0
        x1 = 2.0 * (px + w) / self.width - 1.0
        y0 = 1.0 - 2.0 * py / self.height
        y1 = 1.0 - 2.0 * (py + h) / self.height
        # TRIANGLE_STRIP: TL, BL, TR, BR
        data = np.array([
            x0, y0, 0.0, 0.0,
            x0, y1, 0.0, 1.0,
            x1, y0, 1.0, 0.0,
            x1, y1, 1.0, 1.0,
        ], dtype="f4")
        self.vbo.write(data.tobytes())
        tex.use(0)
        self.prog["tex"].value = 0
        self.prog["tint"].value = tint
        self.vao.render(moderngl.TRIANGLE_STRIP)

    def panel(self, px, py, w, h, color=(0.0, 0.0, 0.0, 0.45)):
        self._draw(px, py, w, h, self.white, color)

    def border_panel(self, px, py, w, h, fill=(0.04, 0.05, 0.09, 0.72),
                     border=(0.45, 0.55, 0.85, 0.55), bw=2):
        self.panel(px - bw, py - bw, w + 2 * bw, h + 2 * bw, border)
        self.panel(px, py, w, h, fill)

    def text_center(self, cx, py, string, size=20, color=(255, 255, 255)):
        w, _h = self.measure(string, size)
        return self.text(int(cx - w / 2), py, string, size, color)

    def text(self, px, py, string, size=20, color=(255, 255, 255)):
        if not string:
            return (0, 0)
        surf = self._font(size).render(string, True, color).convert_alpha()
        w, h = surf.get_size()
        # GL samples v=0 at the first data row; keep the glyph's top row first so
        # text reads upright on screen (origin bottom-left).
        data = pygame.image.tostring(surf, "RGBA", False)
        tex = self.ctx.texture((w, h), 4, data)
        tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
        self._temp.append(tex)
        self._draw(px, py, w, h, tex, (1.0, 1.0, 1.0, 1.0))
        return (w, h)

    def measure(self, string, size=20):
        return self._font(size).size(string)
