import math
import numpy as np
import pyrr


class Camera:
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.distance = 95.0
        self.yaw = 30.0
        self.pitch = 28.0
        self._update()

    def _update(self):
        p = math.radians(self.pitch)
        y = math.radians(self.yaw)
        self.position = np.array([
            self.distance * math.cos(p) * math.sin(y),
            self.distance * math.sin(p),
            self.distance * math.cos(p) * math.cos(y),
        ], dtype="f4")

    def rotate(self, dx, dy):
        self.yaw -= dx * 0.25
        self.pitch = max(-89.0, min(89.0, self.pitch - dy * 0.25))
        self._update()

    def zoom(self, delta):
        self.distance = max(12.0, min(500.0, self.distance + delta))
        self._update()

    def reset(self):
        self.distance = 95.0
        self.yaw = 30.0
        self.pitch = 28.0
        self._update()

    def resize(self, width, height):
        self.width = width
        self.height = height

    def get_view_matrix(self):
        return pyrr.matrix44.create_look_at(
            self.position,
            np.zeros(3, dtype="f4"),
            np.array([0.0, 1.0, 0.0], dtype="f4"),
            dtype="f4",
        )

    def get_projection_matrix(self):
        return pyrr.matrix44.create_perspective_projection_matrix(
            45.0, self.width / max(1, self.height), 0.5, 1500.0, dtype="f4"
        )

    def screen_ray(self, mx, my):
        """Unproject a pixel into a world-space ray (origin, direction)."""
        ndc_x = 2.0 * mx / self.width - 1.0
        ndc_y = 1.0 - 2.0 * my / self.height
        # pyrr arrays are row-major; transpose to the column-vector matrices GL uses.
        view = self.get_view_matrix().T
        proj = self.get_projection_matrix().T
        inv = np.linalg.inv(proj @ view)

        near = inv @ np.array([ndc_x, ndc_y, -1.0, 1.0], dtype="f8")
        far = inv @ np.array([ndc_x, ndc_y, 1.0, 1.0], dtype="f8")
        near = near[:3] / near[3]
        far = far[:3] / far[3]
        direction = far - near
        direction /= np.linalg.norm(direction)
        return self.position.astype("f8"), direction

    def world_to_screen(self, p):
        """Project a world point to pixel coords, or None if behind the camera."""
        view = self.get_view_matrix().T
        proj = self.get_projection_matrix().T
        clip = proj @ view @ np.array([p[0], p[1], p[2], 1.0], dtype="f8")
        if clip[3] <= 1e-6:
            return None
        ndc = clip[:3] / clip[3]
        sx = (ndc[0] * 0.5 + 0.5) * self.width
        sy = (1.0 - (ndc[1] * 0.5 + 0.5)) * self.height
        return (sx, sy)

    def ground_hit(self, mx, my):
        """Where the cursor ray meets the orbital plane (y=0), or None."""
        origin, d = self.screen_ray(mx, my)
        if abs(d[1]) < 1e-6:
            return None
        t = -origin[1] / d[1]
        if t < 0:
            return None
        return origin + d * t
