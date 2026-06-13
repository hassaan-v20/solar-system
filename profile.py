"""Persistent player progression: XP, levels, lifetime stats, objectives.

Every meaningful action anywhere in the game funnels through `record()`, which
awards XP, advances tiered objectives, and unlocks new build options as you level
up. Saved to profile.json so progress carries across sessions.
"""

import json
from pathlib import Path

PROFILE_PATH = Path(__file__).parent / "profile.json"

# XP granted per action (per unit). max_* metrics grant none (they're snapshots).
ACTION_XP = {
    "placed": 6, "harvested": 8, "deflects": 12, "kills": 6,
    "lands": 20, "crafted": 25,
}
MAT_XP = 2

# Body types unlocked at each level (gated in Survival; Creative is always free).
UNLOCKS = {2: ["gas"], 3: ["star"]}

# Objective chains. metric is a key into stats; target is the threshold.
OBJECTIVES = [
    ("first_land",  "Land on a planet",              "lands",       1,  40),
    ("build_5",     "Place 5 worlds in space",       "placed",      5,  50),
    ("hunt_10",     "Defeat 10 creatures",           "kills",      10,  70),
    ("harvest_8",   "Harvest 8 lifeforms",           "harvested",   8,  70),
    ("gather_15",   "Gather 15 crystal",             "mat_crystal",15,  80),
    ("craft_blade", "Craft the Alloy Blade",         "crafted_blade", 1, 60),
    ("build_12",    "Grow a system to 12 worlds",    "max_planets",12, 130),
    ("hunt_30",     "Defeat 30 creatures",           "kills",      30, 130),
    ("deflect_8",   "Deflect 8 comets",              "deflects",    8, 120),
    ("craft_bow",   "Craft the Hunter's Bow",        "crafted_bow", 1,  70),
    ("gather_alloy","Gather 20 alloy",               "mat_alloy",  20, 120),
    ("craft_blast", "Craft the Plasma Blaster",      "crafted_blaster", 1, 160),
    ("hunt_75",     "Defeat 75 creatures",           "kills",      75, 220),
    ("build_20",    "Grow a system to 20 worlds",    "max_planets",20, 240),
]


def xp_for_level(level):
    """Total XP needed to *reach* `level` (level 1 = 0)."""
    return sum(120 + (i - 1) * 70 for i in range(1, level))


class Profile:
    def __init__(self, xp=0, stats=None, done=None):
        self.xp = int(xp)
        self.stats = dict(stats or {})
        self.done = set(done or [])

    @property
    def level(self):
        lvl = 1
        while self.xp >= xp_for_level(lvl + 1):
            lvl += 1
        return lvl

    def level_progress(self):
        lvl = self.level
        lo, hi = xp_for_level(lvl), xp_for_level(lvl + 1)
        return (self.xp - lo) / max(1, hi - lo), self.xp - lo, hi - lo

    def unlocked(self, kind):
        lvl = self.level
        for need, kinds in UNLOCKS.items():
            if kind in kinds and lvl < need:
                return False
        return True

    def unlock_level(self, kind):
        for need, kinds in UNLOCKS.items():
            if kind in kinds:
                return need
        return 1

    def active_objectives(self, k=3):
        out = []
        for oid, text, metric, target, xp in OBJECTIVES:
            if oid in self.done:
                continue
            out.append({"id": oid, "text": text, "metric": metric,
                        "target": target, "xp": xp,
                        "have": min(self.stats.get(metric, 0), target)})
            if len(out) >= k:
                break
        return out

    def record(self, metric, n=1, snapshot=None):
        """Apply an action; return a list of toast dicts (objective/level events)."""
        if metric.startswith("max_"):
            self.stats[metric] = max(self.stats.get(metric, 0), snapshot if snapshot is not None else n)
        else:
            self.stats[metric] = self.stats.get(metric, 0) + n
            if metric.startswith("mat_"):
                self.xp += MAT_XP * n
            elif metric.startswith("crafted_"):
                self.xp += ACTION_XP["crafted"] * n
            elif metric in ACTION_XP:
                self.xp += ACTION_XP[metric] * n

        before = self.level
        toasts = []
        for oid, text, m, target, xp in OBJECTIVES:
            if oid in self.done:
                continue
            if self.stats.get(m, 0) >= target:
                self.done.add(oid)
                self.xp += xp
                toasts.append({"kind": "objective", "text": text, "xp": xp})
        after = self.level
        for lvl in range(before + 1, after + 1):
            unlocked = ", ".join(UNLOCKS.get(lvl, []))
            toasts.append({"kind": "level", "level": lvl, "unlocked": unlocked})
        return toasts

    def to_dict(self):
        return {"xp": self.xp, "stats": self.stats, "done": sorted(self.done)}


def load_profile():
    try:
        with open(PROFILE_PATH) as f:
            d = json.load(f)
        return Profile(d.get("xp", 0), d.get("stats"), d.get("done"))
    except Exception:
        return Profile()


def save_profile(profile):
    try:
        with open(PROFILE_PATH, "w") as f:
            json.dump(profile.to_dict(), f)
    except Exception:
        pass
