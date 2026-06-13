---
name: run-stellar
description: Launch and drive the Stellar Godot game in game/. Use when asked to run, start, play, or screenshot the game, or to verify a change works in-engine (not just tests).
---

# Run Stellar (Godot 4)

Stellar is a Godot 4.6 project living in `game/` (the Python/ModernGL code at the
repo root is the legacy prototype — ignore it). Main scene:
`game/scenes/raid/ghost_station_raid.tscn`.

## One command

From anywhere in the repo:

```bash
.claude/skills/run-stellar/run.sh
```

This validates the project headless, **auto-heals a stale `.godot` class cache**
if it sees one, then opens the game window. Any args are passed through to Godot
(e.g. `run.sh --headless --quit-after 5` for a CI-style smoke check).

Requires Godot 4.6+ (`brew install --cask godot`). Override the binary with
`GODOT=/path/to/godot run.sh` if it's not on `PATH`.

## The stale-cache trap (the usual reason it "won't run")

When a branch **moves, renames, or deletes script files** (branches in this repo
lay `scripts/` out differently), Godot's
`game/.godot/global_script_class_cache.cfg` keeps pointing at the old paths. You
then get parse errors like:

```
Parse Error: Class "WeaponController" hides a global script class.
Parse Error: Could not find script for class "WeaponController" / "EnemyDroneAI".
ERROR: Failed to load script "res://scripts/core/main.gd" with error "Parse error".
```

It looks like broken code but it's a stale cache. `game/.godot/` is gitignored and
regenerable, so the fix is:

```bash
rm -rf game/.godot
godot --headless --editor --quit   # rebuilds the global class registry
```

`run.sh` does exactly this automatically, only when it detects the symptom.

## Verify a change without opening a window

```bash
godot --headless --path game --quit-after 5   # clean = no output, exit 0
```

To validate scripts compile after edits, the import pass above re-registers all
`class_name`s and surfaces parse errors.

## Drive it

It's an interactive flight/combat game — launch the window and fly. Controls:
`W/S` thrust · mouse steer · `A/D` roll · `Q/E` strafe · `Shift` boost · `Ctrl`
brake · `Space`/LMB fire laser · `Esc` toggle mouse capture · `F8` quit. A blank
window or a window that closes instantly is a failure — check the launch log for
parse errors and clear the cache.
