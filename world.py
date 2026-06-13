"""Authoritative game state for the solar-system game.

Everything that *is* the universe lives here: the list of bodies, comets,
resources, and the current game mode. Rendering (scene.py) and input (main.py)
read this; they never own state. Mutations go through `apply(command)` so the
co-op server can replay the exact same commands on every client.
"""

import math
import random
from dataclasses import dataclass, field

ORBIT_SPEED = 0.3          # sim-years per sim-second (shared with renderer)
EARTH_DIST  = 20.0         # reference distance for Kepler period scaling
HAB_CENTER  = 20.0         # habitable-zone centre (max energy yield)
HAB_WIDTH   = 16.0

START_ENERGY    = 150.0
SUN_BASE_RATE   = 2.0      # energy/sec the star always provides
PLANET_YIELD    = 6.0      # peak energy/sec from one ideally-placed planet

COMET_SPEED      = 9.0     # world units / sec
COMET_START_DIST = 105.0
COMET_HIT_PAD    = 0.7     # extra radius around a planet that counts as a hit
COMET_BASE_GAP   = 9.0     # seconds between comet spawns at the start
COMET_MIN_GAP    = 2.5     # hardest spawn cadence
COMET_RAMP       = 0.02    # how fast the cadence tightens per second survived

# kind -> (display, texture, radius, special, cost)
BODY_TYPES = {
    "moon":   ("Moon",   "2k_moon.jpg",          0.30, None,     40.0),
    "rocky":  ("Rocky",  None,                   0.60, None,     90.0),
    "terran": ("Terran", "2k_earth_daymap.jpg",  1.00, "earth", 200.0),
    "gas":    ("Gas",    None,                   2.60, "gas",   350.0),
}
ROCKY_TEX = ["2k_mercury.jpg", "2k_mars.jpg", "2k_venus_surface.jpg", "2k_moon.jpg"]
GAS_TEX   = ["2k_jupiter.jpg", "2k_uranus.jpg", "2k_neptune.jpg"]


def kepler_period(dist):
    if dist <= 0.0:
        return 0.0
    return max(0.05, (dist / EARTH_DIST) ** 1.5)


def body_world_pos(body, t):
    """Position of a body at sim-time t (numpy-free tuple)."""
    if body.dist <= 0.0:
        return (0.0, 0.0, 0.0)
    w = 2.0 * math.pi * ORBIT_SPEED / body.period
    a = body.phase + w * t
    return (body.dist * math.cos(a), 0.0, body.dist * math.sin(a))


@dataclass
class Body:
    name: str
    texture: str
    radius: float
    dist: float
    period: float
    tilt: float = 0.0
    special: str = None        # 'sun' | 'earth' | 'saturn' | 'gas' | None
    phase: float = 0.0
    owner: str = ""
    alive: bool = True


@dataclass
class Comet:
    cid: int
    x: float
    y: float
    z: float
    vx: float
    vy: float
    vz: float
    target: int               # index into bodies, or -1
    alive: bool = True


# ── preset: the real solar system (Explore mode) ──────────────────────────────
# (name, texture, radius, dist, period_yrs, tilt, special)
_REAL = [
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


class World:
    def __init__(self, mode="explore"):
        self.mode = mode
        self.bodies = []
        self.comets = []
        self.energy = float("inf")
        self.score = 0
        self._next_cid = 0
        self._comet_timer = COMET_BASE_GAP
        self._elapsed = 0.0
        self.message = ""
        self.message_t = 0.0
        self._build(mode)

    # ── construction ──────────────────────────────────────────────────────────
    def _build(self, mode):
        if mode == "explore":
            for n, tex, r, d, p, tilt, sp in _REAL:
                self.bodies.append(Body(n, tex, r, d, p, tilt, sp))
            self.energy = float("inf")
        else:
            self.bodies.append(Body("Sun", "2k_sun.jpg", 5.0, 0.0, 0.0, 7.25, "sun"))
            self.energy = float("inf") if mode == "creative" else START_ENERGY

    @property
    def infinite_energy(self):
        return self.mode in ("explore", "creative")

    @property
    def threats_enabled(self):
        return self.mode == "survival"

    def planets(self):
        return [b for b in self.bodies if b.special != "sun" and b.alive]

    # ── command interface (what the co-op server replays) ───────────────────────
    def apply(self, cmd):
        kind = cmd.get("type")
        if kind == "place":
            return self.place_body(cmd["body"], cmd["x"], cmd["z"], cmd["t"],
                                   cmd.get("owner", ""))
        if kind == "deflect":
            return self.deflect(cmd["cid"])
        return None

    def place_body(self, kind, x, z, t, owner=""):
        spec = BODY_TYPES.get(kind)
        if not spec:
            return False
        _disp, tex, radius, special, cost = spec
        if not self.infinite_energy and self.energy < cost:
            self.notify("Not enough energy")
            return False

        dist = math.hypot(x, z)
        if dist < 6.0:
            self.notify("Too close to the star")
            return False

        period = kepler_period(dist)
        theta = math.atan2(z, x)
        w = 2.0 * math.pi * ORBIT_SPEED / period
        phase = theta - w * t

        if special == "gas":
            tex = random.choice(GAS_TEX)
            special = "saturn" if random.random() < 0.5 else None  # half get rings
        elif tex is None:
            tex = random.choice(ROCKY_TEX)

        tilt = random.uniform(0.0, 30.0)
        self.bodies.append(Body(kind.title(), tex, radius, dist, period, tilt,
                                special, phase, owner))
        if not self.infinite_energy:
            self.energy -= cost
        self.score += 1
        return True

    def deflect(self, cid):
        for c in self.comets:
            if c.cid == cid and c.alive:
                c.alive = False
                return True
        return False

    # ── simulation tick (real dt; gated by `running` so pause freezes it) ───────
    def tick(self, dt, t, running):
        if not running or self.mode == "explore":
            return
        self._elapsed += dt

        if not self.infinite_energy:
            self.energy = min(self.energy + self.energy_rate() * dt, 99999.0)

        if self.threats_enabled:
            self._spawn_comets(dt, t)
            self._move_comets(dt, t)

        if self.message_t > 0.0:
            self.message_t -= dt

    def energy_rate(self):
        rate = SUN_BASE_RATE
        for b in self.planets():
            hab = math.exp(-((b.dist - HAB_CENTER) / HAB_WIDTH) ** 2)
            rate += PLANET_YIELD * hab * min(b.radius, 2.0)
        return rate

    def _spawn_comets(self, dt, t):
        targets = [i for i, b in enumerate(self.bodies)
                   if b.alive and b.special != "sun"]
        if not targets:
            return
        self._comet_timer -= dt
        if self._comet_timer > 0.0:
            return
        gap = max(COMET_MIN_GAP, COMET_BASE_GAP - self._elapsed * COMET_RAMP)
        self._comet_timer = gap

        ang = random.uniform(0.0, 2.0 * math.pi)
        x = COMET_START_DIST * math.cos(ang)
        z = COMET_START_DIST * math.sin(ang)
        y = random.uniform(-2.0, 2.0)
        tgt = random.choice(targets)
        tx, _ty, tz = body_world_pos(self.bodies[tgt], t)
        dx, dy, dz = tx - x, -y, tz - z
        n = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        s = COMET_SPEED
        self.comets.append(Comet(self._next_cid, x, y, z,
                                 dx / n * s, dy / n * s, dz / n * s, tgt))
        self._next_cid += 1

    def _move_comets(self, dt, t):
        for c in self.comets:
            if not c.alive:
                continue
            # Gentle homing toward the (moving) target planet.
            if 0 <= c.target < len(self.bodies) and self.bodies[c.target].alive:
                tx, ty, tz = body_world_pos(self.bodies[c.target], t)
                dx, dy, dz = tx - c.x, ty - c.y, tz - c.z
                n = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
                blend = 0.06
                c.vx += (dx / n * COMET_SPEED - c.vx) * blend
                c.vy += (dy / n * COMET_SPEED - c.vy) * blend
                c.vz += (dz / n * COMET_SPEED - c.vz) * blend
            c.x += c.vx * dt
            c.y += c.vy * dt
            c.z += c.vz * dt

            # Burned up by the star.
            if math.hypot(c.x, c.z) < 3.0:
                c.alive = False
                continue
            # Impact?
            for b in self.bodies:
                if not b.alive or b.special == "sun":
                    continue
                bx, by, bz = body_world_pos(b, t)
                if (c.x - bx) ** 2 + (c.y - by) ** 2 + (c.z - bz) ** 2 < \
                        (b.radius + COMET_HIT_PAD) ** 2:
                    b.alive = False
                    c.alive = False
                    self.notify(f"{b.name} destroyed!")
                    break

        self.comets = [c for c in self.comets if c.alive]

    # ── ui helpers ──────────────────────────────────────────────────────────────
    def notify(self, text, secs=2.5):
        self.message = text
        self.message_t = secs
