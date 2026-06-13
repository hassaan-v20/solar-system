# Solar System

A real-time 3D solar system simulation in Python using ModernGL (OpenGL 3.3)
and Pygame. Real NASA-based planet textures, a Milky Way galaxy skybox, HDR
bloom on the Sun, day/night city lights and clouds on Earth, and Saturn's rings.

![preview](preview.png)

## Features

- **All 8 planets + the Sun** with photographic surface textures
- **Milky Way skybox** — full 8K galaxy panorama as the background
- **HDR bloom** post-processing so the Sun glows realistically
- **Earth**: day/night terminator with city lights, ocean specular highlight,
  atmospheric rim glow, rotating cloud layer, and an orbiting Moon
- **Saturn**: textured rings with a soft planet shadow
- Axial tilts, relative orbital periods, and orbit guide rings

## Run it

```bash
pip install -r requirements.txt
python main.py
```

Requires Python 3.10+ and a GPU supporting OpenGL 3.3 (any card from the last
decade). Developed and tested on an AMD Radeon RX 6600 XT.

## Controls

| Input          | Action                |
| -------------- | --------------------- |
| Drag mouse     | Orbit the camera      |
| Scroll wheel   | Zoom in / out         |
| `+` / `-`      | Speed up / slow down  |
| `Space`        | Pause / resume        |
| `R`            | Reset the camera      |
| `Esc`          | Quit                  |

## Project layout

```
main.py        window, input, main loop
scene.py       planets, skybox, rings, bloom pipeline
camera.py      orbital camera
mesh.py        sphere / ring / quad geometry
shaders/       GLSL: planets, skybox, clouds, rings, bloom passes
textures/      planet + galaxy texture maps
```

## Multiplayer roadmap

Ideas for turning this into a shared experience (see the GitHub issues for
discussion):

1. **Shared spectator view** — a small Python `asyncio`/`websockets` server holds
   the authoritative simulation time; clients connect and see the exact same
   sky. Easiest first step: the server just broadcasts `time` and `speed`.
2. **Free-fly avatars** — each player controls a labelled ship/camera; the
   server relays everyone's position so you can see each other fly around.
3. **Co-op controls** — anyone can pause/scrub time or drop annotations
   ("look at Saturn"), synced to all clients.
4. **Authoritative physics later** — once it's fun, replace the analytic orbits
   with real n-body gravity on the server so players can launch probes.

Networking stack suggestion: `websockets` + JSON for the prototype, moving to
a binary protocol (`msgpack`) if bandwidth matters. Keep the server
authoritative for time so nobody desyncs.

## Credits

Planet, Sun, Moon, ring, and Milky Way textures by **Solar System Scope**
(<https://www.solarsystemscope.com/textures>), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Based on NASA
elevation and imagery data.
