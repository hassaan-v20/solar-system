# Stellar (Godot 4)

The production codebase for **Stellar**, a co-op space raid extraction game.
Design: [`../docs/GDD.md`](../docs/GDD.md) · Tech stack:
[`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

> The Python/ModernGL game in the repo root is the legacy prototype, kept for
> reference. New work happens here.

## Current state: Milestone 1 — flyable sector

A single space sector you can fly the **Wayfarer** around, with a chase camera,
asteroid field, starfield, and a minimal HUD. Everything is placeholder
primitives built in code — no art needed yet. The point of M1 is purely:
**does flying feel good?**

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
| `Esc` | Toggle mouse capture |
| `F8` | Quit |

## Layout

See [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) §6 for the full tree.
Key folders: `scripts/` (code by layer), `scenes/` (`.tscn`), `data/` (`.tres`
configs), `assets/` (art/audio).

## Next milestones

M2 combat (laser, projectiles, drone AI, damage) → M3 mission FSM (dock, hack,
extract) → M4 station + economy + persistence → M5 co-op multiplayer.
