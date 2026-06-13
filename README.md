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
server.py      authoritative co-op server (websockets)
netclient.py   client networking (background thread + snapshots)
hud.py         2D text/panel overlay (title, mode badges, hotbar, help)
sprites.py     procedural galaxy / nebula sprite generation
mesh.py        sphere / ring / quad geometry
shaders/       GLSL: planets, skybox, galaxies, clouds, rings, bloom passes
textures/      planet + galaxy texture maps
fonts/         Orbitron (UI font)
savegame.json  your saved game (created on Esc; git-ignored)
```

## Co-op multiplayer

Play together in real time. One machine runs an authoritative **server**
(`server.py`) that owns the world and the simulation clock; everyone else
connects and sees the exact same universe. Anyone can place worlds, deflect
comets, and switch modes — changes show up for all players instantly.

![co-op](coop.png)

**Host a game**

- From the title screen click **Host Co-op Game** — this starts a local server
  and drops you straight in, or
- run the server yourself: `python server.py --mode creative` (also
  `explore` / `survival`).

**Join a game**

- Click **Join Co-op Game** and type the host's address, e.g.
  `ws://192.168.1.20:8765`.

**Where the host's address comes from**

- **Same Wi-Fi / LAN:** the host runs `ipconfig` (Windows) / `ip addr` and
  shares their local IP — `ws://<that-ip>:8765`.
- **Over the internet (anywhere in the world):** the host must make port `8765`
  reachable. Easiest options:
  - **[Tailscale](https://tailscale.com)** (recommended) — both install it; it
    puts your machines on one private network with no router setup. Join using
    the host's Tailscale IP.
  - A tunnel such as `ngrok tcp 8765` or [playit.gg](https://playit.gg), then
    join using the public address it gives you.
  - Or forward TCP port `8765` on the host's router to their PC.

**Security note:** the server has no authentication or encryption — anyone who
can reach the address can join and edit the world. Only share it with people you
trust, and prefer Tailscale, which keeps it private to your devices.

Architecture: the `World` (`world.py`) is fully command-driven (`world.apply`)
and JSON-serialisable, so the server just applies commands and broadcasts state
snapshots (~20 Hz); clients extrapolate between snapshots for smooth motion.
Next up: free-fly avatars so you can see where each other is looking.

## Credits

Planet, Sun, Moon, ring, and Milky Way textures by **Solar System Scope**
(<https://www.solarsystemscope.com/textures>), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Based on NASA
elevation and imagery data.

UI font **Orbitron** by Matt McInerney, licensed under the
[SIL Open Font License 1.1](fonts/OFL.txt). Distant galaxies are generated
procedurally (`sprites.py`).
