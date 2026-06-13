import math
import numpy as np


def create_sphere(segments=64):
    verts, indices = [], []
    for lat in range(segments + 1):
        theta = lat * math.pi / segments
        for lon in range(segments + 1):
            phi = lon * 2.0 * math.pi / segments
            x = math.sin(theta) * math.cos(phi)
            y = math.cos(theta)
            z = math.sin(theta) * math.sin(phi)
            verts += [x, y, z, x, y, z, lon / segments, lat / segments]
    for lat in range(segments):
        for lon in range(segments):
            a = lat * (segments + 1) + lon
            b = a + segments + 1
            indices += [a, b, a + 1, b, b + 1, a + 1]
    return np.array(verts, dtype="f4"), np.array(indices, dtype="u4")


def create_ring(inner_r, outer_r, segments=128):
    verts, indices = [], []
    for i in range(segments + 1):
        angle = i * 2.0 * math.pi / segments
        c, s = math.cos(angle), math.sin(angle)
        u = i / segments
        verts += [inner_r * c, 0.0, inner_r * s, 0.0, 1.0, 0.0, u, 0.0]
        verts += [outer_r * c, 0.0, outer_r * s, 0.0, 1.0, 0.0, u, 1.0]
    for i in range(segments):
        b = i * 2
        indices += [b, b + 1, b + 2, b + 1, b + 3, b + 2]
    return np.array(verts, dtype="f4"), np.array(indices, dtype="u4")


def create_orbit_circle(radius, segments=256):
    verts = []
    for i in range(segments + 1):
        angle = i * 2.0 * math.pi / segments
        verts += [radius * math.cos(angle), 0.0, radius * math.sin(angle)]
    return np.array(verts, dtype="f4")
