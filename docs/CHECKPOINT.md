# Godot Engine Checkpoint — 2026-06-15

A stable save point of the **Stellar** vertical slice on **Godot 4** (the engine
chosen over the GDD's original Unity plan). Tagged `godot-engine-checkpoint` on
branch `first-vertical-slice`. Solo **and** live 2-player co-op are playable.

## What works at this checkpoint

**Lobby (flyable hub)** — `lobby.gd`
- Pilot the ship around Kestrel Station; fly into a service bay and dock (F / ✕):
  Departure (launch solo / host / join co-op), Upgrades, Repair, Ship Bay.

**Solo raid** — `main.gd` → `_build_solo()`
- Fly to the derelict station, dock, hack the data core, defend, extract.
- Salvage / risk-greed loop, escalating threat (`HeatDirector`), credits + upgrades
  persist between runs (`PlayerProfile`), results screen.

**Co-op raid** — `main.gd` → `_setup_coop()` (host-authoritative)
- Separate ship per player in a shared, seed-deterministic sector.
- Host = peer 1; ENet direct-IP over **ZeroTier** (network `cf719fd540c46676`).
- Fly into the station to begin → 90 s **defend** against escalating drone waves
  (`CoopRaid`). Survive = complete; all ships down = fail.
- Networked bolts (`CombatNet`, host adjudicates damage), networked drones, puppet
  transform interpolation, replicated drone hull.

**Flight & combat feel** — `ship_controller.gd`, `weapon_controller.gd`
- Newtonian rigid-body flight with flight assist (coupled/decoupled).
- Finite **boost reserve** (drains, recharges, locks out when empty).
- Damage → shield then hull → death + wreck explosion.

**HUD** — `ship_hud.gd` + overlays
- Flight markers (crosshair / prograde-retrograde / lead pip), readout panel,
  mission objective + status banners.
- `target_indicators.gd`: green edge-arrows to off-screen teammates, red reticles
  on visible enemies + red edge-arrows to off-screen ones.
- `world_health_bars.gd`: floating bars over drones (hull) and teammates (shield+hull).
- `local_health_bar.gd`: bottom-left shield / hull / boost bars for your own ship.
- Slot-coloured nameplates over teammate ships.

## Architecture map
- `scripts/core/main.gd` — raid bootstrap; solo vs co-op fork.
- `scripts/core/lobby.gd` — flyable hub + service-bay docking.
- `scripts/net/network_manager.gd` (autoload **Net**) — ENet host/join, raid handshake.
- `scripts/net/combat_net.gd` — host-authoritative projectiles.
- `scripts/mission/coop_raid.gd` — co-op defend FSM (host drives, RPC fan-out).
- `scripts/mission/mission_manager.gd` — solo Ghost Station FSM.
- `scripts/ai/heat_director.gd` / `enemy_drone_ai.gd` — wave director / drone AI.
- `scripts/ship/ship_controller.gd` — flight, boost, health.
- `scripts/data/*.gd` + `data/**/*.tres` — ShipDef / EnemyDef / WeaponDef / MissionDef.

## Networking notes (hard-won)
- Nodes used by `MultiplayerSpawner` and the targets of RPCs **must have stable
  names** on every peer (auto-names like `@MultiplayerSpawner@NN` differ per peer
  and break spawn replication / RPC routing).
- Puppet ships interpolate toward a replicated `net_position`/`net_rotation` rather
  than snapping, to hide latency jitter.
- Clients enter the raid via the `_load_raid` RPC, so anything the lobby's Launch
  button did (e.g. clearing the input lock) must also happen there.

## Running it
```bash
bash .claude/skills/run-stellar/run.sh   # auto-heals a stale .godot class cache
```
Co-op: host from the Departure panel, the other player joins the host's ZeroTier IP
(`host` or `host:port`), wait for "2 player(s)", then Launch. Both machines must be
on the same commit.

## Known gaps / next
- Co-op has no salvage, results screen, or reward tally yet (banner only on win/fail).
- Drones aren't interpolated, so they can look choppier than ships in a firefight.
- Combat depth still open: enemy archetypes, hitstop/juice, encounter pacing.
- Tuning knobs: drone lethality in `data/enemies/light_drone.tres` + the fire cone in
  `enemy_drone_ai.gd`; boost feel via `boost_capacity/drain/regen` on `ShipDef`.
