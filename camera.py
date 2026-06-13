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
