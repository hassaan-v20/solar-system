"""First-person 'on the planet' survival mode.

Pure game logic (no rendering): walk around, fight creatures with an aim cone,
collect the loot they drop, and craft better weapons and armour. Single-player.
"""

import math
import random
from dataclasses import dataclass

PLAY_RADIUS   = 70.0
EYE_HEIGHT    = 1.7
PLAYER_SPEED  = 10.0
PLAYER_MAX_HP = 100.0
CREATURE_CAP  = 11
SPAWN_GAP     = 2.2

# weapon key -> stats.  range >10 counts as ranged (narrower aim).
WEAPONS = {
    "fists":   {"name": "Fists",          "dmg": 7,  "range": 3.0,  "cd": 0.45},
    "blade":   {"name": "Alloy Blade",    "dmg": 18, "range": 3.8,  "cd": 0.40},
    "blaster": {"name": "Plasma Blaster", "dmg": 34, "range": 30.0, "cd": 0.30},
}
ARMORS = {
    "none":   {"name": "No Armour",    "def": 0},
    "hide":   {"name": "Hide Armour",  "def": 6},
    "plated": {"name": "Plated Armour", "def": 16},
}
# recipe key -> (slot, cost). recipe key doubles as the weapon/armor key.
RECIPES = {
    "blade":   ("weapon", {"bone": 3, "crystal": 2}),
    "hide":    ("armor",  {"hide": 5}),
    "blaster": ("weapon", {"alloy": 4, "crystal": 5}),
    "plated":  ("armor",  {"alloy": 6, "hide": 4}),
}
RECIPE_ORDER = ["blade", "hide", "blaster", "plated"]
RECIPE_LABEL = {"blade": "Alloy Blade", "hide": "Hide Armour",
                "blaster": "Plasma Blaster", "plated": "Plated Armour"}

CREATURES = {
    "critter": {"hp": 18, "dmg": 6,  "speed": 3.6, "size": 1.7,
                "loot": ["hide", "bone"],        "color": (0.55, 0.85, 0.40)},
    "beast":   {"hp": 46, "dmg": 15, "speed": 2.9, "size": 2.7,
                "loot": ["hide", "bone", "bone"], "color": (0.75, 0.45, 0.30)},
    "alien":   {"hp": 30, "dmg": 12, "speed": 4.4, "size": 2.0,
                "loot": ["crystal", "alloy"],     "color": (0.55, 0.45, 0.95)},
}
ITEM_COLOR = {"hide": (0.75, 0.52, 0.35), "bone": (0.92, 0.92, 0.82),
              "crystal": (0.50, 0.90, 1.00), "alloy": (0.80, 0.82, 0.95)}
ITEM_ORDER = ["hide", "bone", "crystal", "alloy"]


@dataclass
class Creature:
    kind: str
    x: float
    z: float
    hp: float
    cd: float = 0.0
    alive: bool = True


@dataclass
class Loot:
    item: str
    x: float
    z: float
    alive: bool = True


class Surface:
    def __init__(self, planet_kind="rocky"):
        self.planet_kind = planet_kind
        self.x = 0.0
        self.z = 0.0
        self.yaw = 0.0
        self.pitch = 0.0
        self.hp = PLAYER_MAX_HP
        self.weapon = "fists"
        self.armor = "none"
        self.inv = {}
        self.creatures = []
        self.loot = []
        self.sky = []          # celestial bodies visible overhead: {dir, color, size}
        self.kills = 0
        self.dead = False
        self.spawn_t = 1.0
        self.attack_cd = 0.0
        self.message = ""
        self.message_t = 0.0

    # ── per-frame update ────────────────────────────────────────────────────────
    def update(self, dt, forward, strafe):
        if self.dead:
            if self.message_t > 0:
                self.message_t -= dt
            return
        # Move relative to facing (yaw): forward = +Z-ish rotated by yaw.
        fx, fz = math.sin(self.yaw), math.cos(self.yaw)
        rx, rz = math.cos(self.yaw), -math.sin(self.yaw)
        mx, mz = fx * forward + rx * strafe, fz * forward + rz * strafe
        n = math.hypot(mx, mz)
        if n > 0:
            self.x += mx / n * PLAYER_SPEED * dt
            self.z += mz / n * PLAYER_SPEED * dt
            r = math.hypot(self.x, self.z)
            if r > PLAY_RADIUS:
                self.x *= PLAY_RADIUS / r
                self.z *= PLAY_RADIUS / r

        self.attack_cd = max(0.0, self.attack_cd - dt)
        if self.message_t > 0:
            self.message_t -= dt

        self.spawn_t -= dt
        if self.spawn_t <= 0 and sum(c.alive for c in self.creatures) < CREATURE_CAP:
            self.spawn_t = SPAWN_GAP
            self._spawn()

        for c in self.creatures:
            if not c.alive:
                continue
            st = CREATURES[c.kind]
            dx, dz = self.x - c.x, self.z - c.z
            d = math.hypot(dx, dz) or 1.0
            if d > 1.7:
                c.x += dx / d * st["speed"] * dt
                c.z += dz / d * st["speed"] * dt
            else:
                c.cd -= dt
                if c.cd <= 0:
                    c.cd = 1.0
                    self._hurt(st["dmg"])

        for l in self.loot:
            if l.alive and math.hypot(self.x - l.x, self.z - l.z) < 2.3:
                l.alive = False
                self.inv[l.item] = self.inv.get(l.item, 0) + 1
                self.notify(f"Picked up {l.item}")

        self.creatures = [c for c in self.creatures if c.alive]
        self.loot = [l for l in self.loot if l.alive]

    def _hurt(self, dmg):
        self.hp -= max(1.0, dmg - ARMORS[self.armor]["def"])
        if self.hp <= 0:
            self.hp = 0.0
            self.dead = True
            self.notify("You were overwhelmed.  Press Esc to return to space.", 99)

    def _spawn(self):
        kind = random.choice(list(CREATURES))
        a = random.uniform(0, 2 * math.pi)
        dist = random.uniform(26, 46)
        x, z = self.x + dist * math.cos(a), self.z + dist * math.sin(a)
        r = math.hypot(x, z)
        if r > PLAY_RADIUS:
            x *= PLAY_RADIUS / r
            z *= PLAY_RADIUS / r
        self.creatures.append(Creature(kind, x, z, CREATURES[kind]["hp"]))

    # ── actions ──────────────────────────────────────────────────────────────────
    def attack(self):
        if self.dead or self.attack_cd > 0:
            return False
        w = WEAPONS[self.weapon]
        self.attack_cd = w["cd"]
        fx, fz = math.sin(self.yaw), math.cos(self.yaw)
        cone = 0.55 if w["range"] > 10 else 0.25
        best, best_d = None, 1e9
        for c in self.creatures:
            if not c.alive:
                continue
            dx, dz = c.x - self.x, c.z - self.z
            d = math.hypot(dx, dz)
            if d > w["range"] or d < 0.1:
                continue
            if (dx * fx + dz * fz) / d < cone:
                continue
            if d < best_d:
                best, best_d = c, d
        if best is None:
            return False
        best.hp -= w["dmg"]
        if best.hp <= 0:
            best.alive = False
            self.kills += 1
            for item in CREATURES[best.kind]["loot"]:
                self.loot.append(Loot(item, best.x + random.uniform(-1, 1),
                                      best.z + random.uniform(-1, 1)))
            self.notify(f"Killed {best.kind}")
        return True

    def can_craft(self, key):
        _slot, cost = RECIPES[key]
        return all(self.inv.get(k, 0) >= v for k, v in cost.items())

    def craft(self, key):
        if key not in RECIPES:
            return False
        if not self.can_craft(key):
            self.notify("Not enough materials")
            return False
        slot, cost = RECIPES[key]
        for k, v in cost.items():
            self.inv[k] -= v
        if slot == "weapon":
            self.weapon = key
        else:
            self.armor = key
        self.notify(f"Crafted {RECIPE_LABEL[key]}!")
        return True

    def notify(self, text, secs=2.0):
        self.message = text
        self.message_t = secs
