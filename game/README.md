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

Visuals: the player ship is a **single rounded CSG hull** (smooth fuselage, nose,
swept wings, tail, engine pods + glowing cockpit/nav lights) — a real modelled
mesh, not stacked boxes — plus an infinite **starfield + nebula sky**, depth fog,
and spinning asteroids. (Enemy craft are still primitive assemblies; drop-in
`.glb` model packs are the next fidelity step.)

## In progress: Milestone 3 — the raid loop

**Data-driven missions** (`data/missions/*.tres`) — a random contract each run:
- **Ghost Station / Deep Core** (hack) — hold the station core to hack it
- **Salvage Run** — collect scattered cargo caches
- **Last Stand** (defend) — hold the station against waves
- **Bounty Hunt** — destroy a quota of raiders

…then **extract at the jump point before the timer**. Missions throw
**reinforcements** at you (start, periodic, and a surge when you start extracting),
so they're tense to finish. Objective text, an extraction countdown, and cyan
objective markers (with off-screen arrows) guide you; complete/fail chains into a
new random contract.

**Combat polish & visuals:** muzzle flashes, impact sparks, explosion flashes +
camera shake, punchy blaster audio, three distant suns lighting the sector (bright
and readable), stronger bloom, and more detailed ships.

**Realistic-look pass (engine features, no art files):** PBR **rock asteroids**
(procedural noise albedo + normal map, world-triplanar so each rock looks unique);
a richer **layered nebula + galactic-band starfield**; **GPU particles** for an
engine thrust trail and explosion debris; and modern post — **SSAO, SSR,
volumetric fog, colour grading, stronger bloom, and TAA/MSAA**. Note: the bigger
fidelity leap (modelled `.glb` ships + PBR textures) is the next step and just
needs art assets.

## The loop (M4)

**Title → Station Hub → Raid → back to Station.** The title is a live 3D space
scene (nebula, suns, a turning hero ship, drifting rocks) with a game menu. In the
**station hub** you spend **credits** on ship **upgrades** (hull, shield, laser,
engine, missile rack), pick a **contract**, and launch. Completing the raid pays
out credits (a quarter on failure); your **credits, upgrades and stats persist**
between sessions (`user://profile.cfg`). The whole game shares one **extreme**
space look: nebula sky, three suns, heavy bloom, SSAO/SSIL/SSR, volumetric haze,
colour grading, and TAA + 4× MSAA.

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

✅ M2 combat → ✅ M3 missions → 🔧 **M4** station + economy + persistence (first
pass in: hub, upgrades, credits, save) → M5 co-op multiplayer.
