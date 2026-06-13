# Stellar (Godot 4)

The production codebase for **Stellar**, a co-op space raid extraction game.
Design: [`../docs/GDD.md`](../docs/GDD.md) · Tech stack:
[`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

> The Python/ModernGL game in the repo root is the legacy prototype, kept for
> reference. New work happens here.

## Current state: Milestone 3 — playable Ghost Station loop

Fly the **Wayfarer** to a derelict station, dock, survive enemy waves while the
Data Core is hacked, then race to the extraction point before the meltdown timer
runs out — or fail by losing the ship or the clock. Built on M1 flight (chase
camera, asteroid field) and M2 combat (lasers, drones, damage, explosions).
Everything is placeholder primitives + procedural juice built in code — no art
yet (see `docs/`: mechanics-first until the loop is proven fun).

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
| `LMB` | Fire primary weapon |
| `F` | Dock (when prompted at the station) |
| `Shift` | Boost |
| `Ctrl` | Brake |
| `Esc` | Toggle mouse capture |
| `F11` | Toggle fullscreen |
| `F8` | Quit |

### Gamepad (DualSense / any SDL-mapped pad)

Plug in or pair a controller — it works alongside keyboard+mouse, no setup.

| Input | Action |
| --- | --- |
| Left stick | Thrust (up/down) · strafe (left/right) |
| Right stick | Steer the nose (yaw + pitch) |
| `R2` / `L2` | Fire / boost |
| `L1` / `R1` | Roll left / right |
| ✕ (Cross) | Dock |
| ○ (Circle) | Brake |

Pitch can be inverted via `ShipController.invert_pitch`.

## Layout

See [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) §6 for the full tree.
Key folders: `scripts/` (code by layer), `scenes/` (`.tscn`), `data/` (`.tres`
configs), `assets/` (art/audio).

## Next milestones

✅ M1 flight · ✅ M2 combat · ✅ M3 mission FSM (dock, hack, extract) →
**M4** station hub + economy + upgrades + persistence → **M5** co-op multiplayer.
