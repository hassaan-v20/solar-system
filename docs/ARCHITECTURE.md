# Stellar — Architecture & Tool Stack v0.1

Companion to [`GDD.md`](./GDD.md). The GDD says *what* we're building; this doc
says *what we build it with* and *how the code is organized*. Where the two
disagree, this document wins (it supersedes GDD §22 and §23).

---

## 1. Engine decision: Godot 4

**We use [Godot 4](https://godotengine.org) (target 4.3+), not Unity.**

The GDD's §22 default (Unity) was written without our team's constraints. Ours:

- **2 developers** (you + your brother), not artists, relying on **free CC0 assets**.
- The game is built primarily by an **AI coding agent working in code/text**, not a human clicking around a visual editor.

That second constraint decides it. Godot stores **everything as plain, diffable
text** — scenes (`.tscn`), resources (`.tres`), and `project.godot` are all
human- and agent-readable, and the entire engine is scriptable from code. Unity
hides half its configuration in the editor inspector and binary prefabs; Unreal
is Blueprint/`.uasset`-centric. Both fight an agent-first workflow. Godot is the
only major engine *built* the way we work.

**Trade-off we accept:** Godot's out-of-the-box 3D looks less premium than
Unity/Unreal. For a stylized, free-asset, readable sci-fi game that's fine — and
it's the same reason we lean on procedural content and clean UI (GDD §20).

**Deferred but planned:** the long-term solar-system scale (planets, real
distances) needs a **double-precision build** of Godot (`precision=double`
compile flag / floating-origin). The *Ghost Station* slice is a single small
sector, so **single precision is fine for now**. We revisit this only when we
add real interplanetary distances.

---

## 2. Tool stack

| Concern | Choice | Notes |
| --- | --- | --- |
| **Engine** | Godot 4.3+ (Forward+ renderer) | Metal on Apple Silicon; Vulkan on PC. Falls back to GL Compatibility if needed. |
| **Primary language** | **GDScript** | Python-like, tightest engine + text-scene integration, best agent fluency. |
| **Hot-path language** | C# or GDExtension (C++) | *Only* for profiled bottlenecks (mass enemy AI, physics). Not used in the slice. |
| **Networking** | Godot High-Level Multiplayer (ENet) | `MultiplayerSpawner` + `MultiplayerSynchronizer` + RPCs. Host-authoritative now, dedicated-server-ready. |
| **Persistence** | JSON via `FileAccess` + `JSON` | Local `user://profile.json` for v0.1. SQLite later, backend services much later. |
| **Data-driven config** | Godot **Resources** (`.tres`) | Typed `Resource` subclasses = Godot's version of Unity ScriptableObjects. Text/diffable. JSON schemas in GDD §24 are the canonical shapes. |
| **Assets** | Free CC0 (Kenney, Quaternius, KayKit, Poly Haven) | Placeholders first (CSG / primitive meshes built in code). glTF import. |
| **Audio** | Godot `AudioStreamPlayer(3D)` | Free SFX (freesound / sfxr). Ship-AI voice lines via TTS placeholders (GDD §21). |
| **Version control** | git + **Git LFS** | LFS for binary assets (`*.glb`, `*.png`, `*.ogg`, `*.wav`). |
| **Testing** | [GUT](https://github.com/bitwes/Gut) + `godot --headless` | Unit tests for pure logic (damage, rewards, mission FSM); headless smoke runs in CI. |
| **CI** | GitHub Actions | `godot --headless --import` then run GUT. |
| **Editor/IDE** | Godot editor + any text editor | Agent edits `.gd`/`.tscn`/`.tres` directly; humans use the editor for visual tuning. |

---

## 3. Layered architecture

The GDD's hard rule (§18.3, §30.3): **separate authoritative game state from
client input/presentation.** We structure every system in three layers so that
single-player, host, and (future) dedicated server all run the *same* logic.

```
┌─────────────────────────────────────────────┐
│ PRESENTATION (client-only, never authoritative)
│   ChaseCamera · ShipHUD · StationUI · VFX/SFX · input capture
└───────────────┬─────────────────────────────┘
                │ input intent (RPC to authority)
┌───────────────▼─────────────────────────────┐
│ SIMULATION (authority = host/server owns the truth)
│   ShipController state · DamageSystem · EnemyDroneAI
│   MissionManager (FSM) · CargoSystem · RewardCalculator
└───────────────┬─────────────────────────────┘
                │ reads
┌───────────────▼─────────────────────────────┐
│ DATA (immutable, designer-authored .tres)
│   ShipDef · WeaponDef · EnemyDef · MissionDef · CargoDef
└─────────────────────────────────────────────┘
```

**Authority rule of thumb:** if it can be cheated or must be consistent across
players (damage, enemy positions, loot validation, mission state, rewards), the
**host owns it** and clients receive synced state. If it's local feel (camera,
HUD, prediction, particle effects), the **client owns it**.

A global **`EventBus`** autoload (signals) decouples systems: e.g. the
DamageSystem emits `ship_system_damaged`, and the HUD + audio + ship-AI voice
all react without knowing about each other. This keeps UI "replaceable" (GDD
§30.3).

---

## 4. Networking model (slice → future)

- **Now (slice):** *host-authoritative*. One player hosts; ENet via Godot's
  high-level API. The host runs `MissionManager`, enemy AI, and damage; clients
  send input intent and interpolate synced transforms.
- **Sync set** (GDD §18.2): ship transform/velocity/health, shield, weapon fire
  events, projectile spawns, enemy positions/health, cargo pickups, mission &
  docking & extraction state, role assignment. Use `MultiplayerSynchronizer` for
  continuous state (transforms, health) and reliable RPCs for discrete events
  (weapon fire, pickups, state transitions).
- **Future (dedicated server):** because authority logic never touches rendering
  or input, the same project runs headless as a server (`--headless`,
  `--server`). No rewrite — just don't spawn presentation nodes on the server.

**Design constraint enforced from day one:** simulation code must never read
`Input.*` directly or reference camera/HUD nodes. Input enters the simulation
only as serializable intent.

---

## 5. Data-driven configs

Every ship, weapon, enemy, mission, and cargo type is a `Resource` subclass
authored as a `.tres` file (see `scripts/data/` and `data/`). This is the Godot
equivalent of the GDD's ScriptableObjects, and the JSON schemas in GDD §24 map
1:1 onto the exported fields.

```
scripts/data/ship_def.gd      → class_name ShipDef     → data/ships/*.tres
scripts/data/weapon_def.gd     → class_name WeaponDef    → data/weapons/*.tres
scripts/data/enemy_def.gd      → class_name EnemyDef     → data/enemies/*.tres   (M2)
scripts/data/mission_def.gd    → class_name MissionDef   → data/missions/*.tres  (M3)
scripts/data/cargo_def.gd      → class_name CargoDef     → data/cargo/*.tres     (M3)
```

Rule (GDD §30.3): **no gameplay numbers hardcoded in controllers.** Tuning lives
in `.tres`. Code reads the def.

---

## 6. Project structure

The Godot project lives in **`game/`** at the repo root (the existing Python
prototype stays in place as reference — see §9). `game/` is the Godot project
root (contains `project.godot`).

```
game/
  project.godot
  scenes/
    raid/      ghost_station_raid.tscn   # M1 playable sector
    station/   kestrel_station.tscn       # M4
    ship/      wayfarer.tscn              # split out as it grows
    enemies/   light_drone.tscn …         # M2
  scripts/
    core/      main.gd  event_bus.gd      # bootstrap + global signal bus
    data/      ship_def.gd  weapon_def.gd …   # Resource definitions (DATA layer)
    ship/      ship_controller.gd  chase_camera.gd  ship_damage_system.gd …
    combat/    projectile.gd  weapon_controller.gd        # M2
    ai/        enemy_drone_ai.gd                          # M2
    mission/   mission_manager.gd  docking_zone.gd …      # M3
    cargo/     cargo_system.gd                            # M3
    economy/   reward_calculator.gd  upgrade_system.gd  player_profile.gd  # M4
    ui/        ship_hud.gd  station_ui.gd  results_screen.gd
    net/       lobby_manager.gd  role_manager.gd  net_sync.gd   # M5
  data/
    ships/     wayfarer.tres
    weapons/   laser_cannon_mk1.tres      # M2
    …
  assets/
    models/  textures/  audio/  vfx/  fonts/
  tests/       # GUT unit tests
  .gitignore
  .gitattributes   # Git LFS rules
```

Naming: files `snake_case`, classes `PascalCase` via `class_name`, signals and
actions `snake_case`. One node responsibility per script (GDD §31).

---

## 7. Component map (GDD §30.4 → Godot)

| GDD component | Godot node / script | Layer |
| --- | --- | --- |
| ShipController | `CharacterBody3D` + `ship_controller.gd` | Simulation |
| ShipStats / ShipDef | `Resource` `ship_def.gd` | Data |
| ShipDamageSystem | `Node` `ship_damage_system.gd` | Simulation |
| ShipWeaponController | `Node` `weapon_controller.gd` | Simulation |
| Projectile | `Area3D` `projectile.gd` | Simulation |
| EnemyDroneAI / EnemyStats | `CharacterBody3D` + `enemy_drone_ai.gd` / `enemy_def.gd` | Simulation / Data |
| MissionManager / FSM | `Node` `mission_manager.gd` (state enum) | Simulation |
| DockingZone / ExtractionZone | `Area3D` | Simulation |
| HackObjective | `Node` | Simulation |
| CargoSystem | `Node` `cargo_system.gd` | Simulation |
| RewardCalculator | plain `RefCounted` (pure logic, unit-tested) | Simulation |
| PlayerProfile / UpgradeSystem | autoload + JSON | Persistence |
| StationUI / HUD / Results | `CanvasLayer` / `Control` | Presentation |
| LobbyManager / RoleManager | autoload + high-level multiplayer | Net |

---

## 8. Build, run, test

```bash
# install Godot 4 (macOS, Apple Silicon)
brew install --cask godot

# run the slice (editor)
godot --path game

# run headless (CI / smoke test)
godot --headless --path game --quit-after 200

# run unit tests (after GUT is vendored into game/addons/gut)
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

CI (GitHub Actions): import project headless, run GUT, fail the build on test or
import errors.

---

## 9. Status of the Python prototype

The existing Python/ModernGL/Pygame game (`main.py`, `world.py`, `scene.py`, …)
is **legacy/reference**, kept in the repo for its design lessons (the
command-driven `World` model, the progression system, the netcode shape). It is
**not** the production codebase. New work happens in `game/`. We do not port
Python code line-by-line — we port *design*, rebuilding idiomatically in Godot.

---

## 10. Roadmap alignment

Build order follows GDD §27 / §30.1. This doc currently supports:

- **Milestone 1 (in progress):** ship movement + chase camera + flyable sector.
  → `scenes/raid/ghost_station_raid.tscn`, `scripts/ship/*`, `scripts/ui/ship_hud.gd`.

Next: M2 combat (weapons, projectiles, drone AI, damage system), then M3 mission
FSM, M4 station/economy/persistence, M5 multiplayer.
