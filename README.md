# Stellar — a solar system sandbox

A real-time 3D solar system game in Python using ModernGL (OpenGL 3.3) and
Pygame. Boots to a title screen; pick a mode with the mouse, build your own
universe, and pick up where you left off with **Continue**. Explore the real
solar system, freely build in Creative, or grow and defend one against incoming
comets in Survival. Real NASA-based textures, distant galaxies, a Milky Way
skybox, HDR bloom, day/night Earth, and Saturn's rings. Runs fullscreen.

![title screen](preview.png)

## Game modes

Switch any time with **F1 / F2 / F3**:

- **Explore** (F1) — the real solar system: 8 planets + Sun, true relative
  orbital periods and axial tilts. Sit back and fly around.
- **Creative** (F2) — unlimited energy. Click anywhere to place planets, moons,
  and gas giants on any orbit and build your own system.
- **Survival** (F3) — start with a star and a small energy budget. Planets in
  the *habitable zone* generate the most energy; spend it to expand. Rogue
  **comets** drift in and destroy planets on impact — **click a comet to deflect
  it**. The pressure ramps over time. Build fast, defend faster.

From the title screen, **Continue** resumes your saved game, or start a fresh one
in any mode. Your game autosaves when you return to the menu (Esc).

![build mode](build.png)

## Run it

```bash
pip install -r requirements.txt
python main.py
```

Requires Python 3.10+ and a GPU supporting OpenGL 3.3 (any card from the last
decade). Developed and tested on an AMD Radeon RX 6600 XT.

## Controls

| Input              | Action                                  |
| ------------------ | --------------------------------------- |
| `F1` / `F2` / `F3` | Explore / Creative / Survival mode      |
| Click badges / bar | Switch mode or pick a body with the mouse |
| `1` – `0`          | Pick body: Moon, Rocky, Ocean, Desert, Lava, Ice, Toxic, Sulfur, Gas, Star |
| Left click         | Place selected body, or deflect a comet |
| Drag mouse         | Orbit the camera                        |
| Scroll wheel       | Zoom in / out                           |
| `+` / `-`          | Speed up / slow down time               |
| `Space`            | Pause / resume                          |
| `H`                | Toggle the help overlay                 |
| `F11`              | Toggle fullscreen                       |
| `R`                | Reset the camera                        |
| `Esc`              | Back to the title menu (autosaves)      |

## Project layout

```
main.py        window, input, modes, HUD, main loop
world.py       authoritative game state: bodies, comets, energy, commands
scene.py       renderer: planets, skybox, rings, comets, bloom pipeline
camera.py      orbital camera + mouse-ray picking
hud.py         2D text/panel overlay (title, mode badges, hotbar, help)
sprites.py     procedural galaxy / nebula sprite generation
mesh.py        sphere / ring / quad geometry
shaders/       GLSL: planets, skybox, galaxies, clouds, rings, bloom passes
textures/      planet + galaxy texture maps
fonts/         Orbitron (UI font)
savegame.json  your saved game (created on Esc; git-ignored)
```

## Multiplayer roadmap

The whole universe lives in one command-driven `World` (`world.py`); every
change goes through `world.apply(command)`. That's the hook for co-op: a server
owns the authoritative `World` and broadcasts commands, and each client replays
them, so everyone sees the same universe.

1. **Shared world** — a small `asyncio`/`websockets` server holds the `World`
   and the sim clock; clients send `place` / `deflect` commands and receive
   state snapshots.
2. **Free-fly avatars** — each player has a labelled camera; the server relays
   positions so you can see each other.
3. **Co-op survival** — build and defend the same system together; one player
   expands while the other deflects comets.
4. **Authoritative physics later** — swap analytic orbits for real n-body
   gravity on the server so players can launch probes.

Suggested stack: `websockets` + JSON to start, `msgpack` if bandwidth matters.
Keep the server authoritative so nobody desyncs.

## Credits

Planet, Sun, Moon, ring, and Milky Way textures by **Solar System Scope**
(<https://www.solarsystemscope.com/textures>), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Based on NASA
elevation and imagery data.

UI font **Orbitron** by Matt McInerney, licensed under the
[SIL Open Font License 1.1](fonts/OFL.txt). Distant galaxies are generated
procedurally (`sprites.py`).
