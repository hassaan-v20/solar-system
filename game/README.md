# Stellar (Godot 4)

The production codebase for **Stellar**, a co-op space raid extraction game.
Design: [`../docs/GDD.md`](../docs/GDD.md) · Tech stack:
[`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

> The Python/ModernGL game in the repo root is the legacy prototype, kept for
> reference. New work happens here.

## Current state: Milestone 2 — combat (polished)

Fly the **Wayfarer** and fight escalating waves in a dogfight that actually reads:
- **Laser** (heat/overheat) + **homing missiles** (right-click / F, limited regen ammo).
- **Three enemy types** — light drones (shooters), **interceptors** (kamikaze rush),
  **gunships** (tanky), plus a **boss Dreadnought every 5th wave** with a health bar.
- **Combat overlay**: crosshair, hitmarkers, **off-screen enemy arrows**, target
  brackets + enemy health bars, damage vignette.
- **Juice**: procedural sound (lasers, hits, explosions), **camera shake**, engine
  glow, explosions, and **heal/shield pickups** dropped by enemies.
- Ship damage (shields → hull, with regen), death/respawn, scoring.

Visuals: ships are now **modelled from primitives** (fuselage, swept wings,
cockpit, engines — not boxes), plus an infinite **starfield + nebula sky**, depth
fog, and spinning asteroids.

## In progress: Milestone 3 — the raid loop

A first mission state machine: **fly to the derelict station → hack its data core
(hold position) → extract at the jump point before the timer runs out**, all while
fighting. Objective text, an extraction countdown, and cyan objective markers
(with off-screen arrows) guide you; mission complete/failed banners close it out.

## Run it

```bash
# install Godot 4 (macOS, Apple Silicon)
brew install --cask godot

# run from this folder's parent (repo root):
godot --path game
```

Or open the Godot editor, **Import** → select `game/project.godot`, then press F5.

## Controls

| Input | Action |
| --- | --- |
| `W` / `S` | Thrust forward / back |
| Mouse | Steer the nose (yaw + pitch) |
| `A` / `D` | Roll left / right |
| `Q` / `E` | Strafe left / right |
| `Shift` | Boost |
| `Ctrl` | Brake |
| `Space` / Left Mouse | Fire laser |
| Right Mouse / `F` | Fire homing missile |
| `Esc` | Toggle mouse capture |
| `F8` | Quit |

## Layout

See [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) §6 for the full tree.
Key folders: `scripts/` (code by layer), `scenes/` (`.tscn`), `data/` (`.tres`
configs), `assets/` (art/audio).

## Next milestones

✅ M2 combat → 🔧 **M3** mission FSM (dock, hack, extract — first pass in) → M4
station + economy + persistence → M5 co-op multiplayer.
