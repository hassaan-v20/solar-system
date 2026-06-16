# Stellar — web build handoff

Web-first rebuild of Stellar in **three.js + TypeScript** (Vite), living in `web/`.
The Godot prototype in `../game` (tagged `godot-engine-checkpoint`, see
`../docs/CHECKPOINT.md`) is the reference for feel + mechanics. Branch:
`first-vertical-slice`.

## Run

```bash
cd web
npm install
npm run dev        # Vite dev server (HMR); exposed on the LAN (host:true)
npm run typecheck  # tsc --noEmit  (warnings are errors)
npm run build      # typecheck + production bundle to dist/
```

Click the canvas (or press a gamepad button) to start / capture the mouse; Esc
releases it. `F` or the ⛶ button toggles fullscreen.

**Controls** — W/S thrust · mouse aim · LMB fire · A/D roll · Q/E strafe · Space/C
up·down · Shift boost · Ctrl brake · Z flight-assist. Controller: left stick move ·
right stick aim · RT fire · L3 toggle-boost · LB/RB roll · L2 brake · ▲ flight-assist.

## What works (single-player, end to end)

Fly out of spawn through a dense asteroid field to the derelict station → fly into
it to begin the raid → defend it for 90 s against escalating drone waves → survive
(complete) or die (failed).

- **Newtonian flight** ported 1:1 from Godot `ship_controller.gd`: coast/drift,
  flight assist (RCS nulls uncommanded drift/spin within a budget), turn-rate
  steering with angular inertia, **finite boost reserve** (Shift hold / L3 latch;
  L2 or a full drain cancels the latch), speed governor.
- **Combat**: rate + heat-limited laser; bolts inherit ship velocity; segment-vs-
  sphere hit-testing; **drones** with lead-aim AI (orbit at range, fire when lined
  up); explosions; escalating **wave Director** (gated by the mission).
- **Health/death**: shield→hull on ship + drones; death cuts control and coasts +
  explodes.
- **HUD**: a 2D-canvas overlay (`HudOverlay`) — fixed center crosshair, prograde/
  retrograde markers, **lead pip**, floating drone health bars, off-screen enemy
  arrows + on-screen reticles, station **waypoint**, bottom-left shield/hull/boost
  bars. DOM text: top-left readout + top-center objective banner.
- **Collision**: ship vs **asteroids (spheres)** and the **station hull (an AABB per
  GLB sub-mesh)** — pushes the ship out + cancels inward velocity. Keeps the custom
  integrator; no physics engine.
- **Graphics**: 8K Milky Way skybox + a synthesized soft IBL environment for PBR
  ambient/reflections; hemisphere + warm key + cool rim lights; **MSAA + HDR** post
  target; subtle UnrealBloom + ACES tonemap + gentle contrast/saturation grade.

## Architecture (`web/src`)

- `main.ts` — bootstrap: renderer, EffectComposer (bloom → output → grade), the game
  loop, fullscreen, and wiring of every system.
- `core/Input.ts` — keyboard + pointer-lock mouse + gamepad fused into high-level
  **intents** (thrust/strafe/lift/roll/aim/fire/boost/brake/assist) so the ship is
  input-source-agnostic.
- `core/mathf.ts` — clamp / moveToward / damp.
- `ship/ShipController.ts` — Newtonian flight + boost reserve + health/death;
  implements `Damageable`. Forward is local **−Z**; velocity + angular velocity are
  world-space and integrated by hand.
- `ship/shipConfig.ts` — `WAYFARER` flight tuning (mirrors `wayfarer.tres`).
- `ship/createShip.ts` — loads the ship GLB (placeholder cone until it arrives).
- `camera/ChaseCamera.ts` — smoothed third-person chase.
- `world/createWorld.ts` — lights, IBL env, skybox, planet, and the asteroid field
  (registers a sphere collider per rock).
- `world/Collision.ts` — sphere + AABB collision resolution against the ship.
- `combat/Combat.ts` — owns player fire, projectiles + hit-testing, drones, explosions,
  damage routing; `combat/{Weapon,Projectile,Explosion,ballistics,weaponConfig,types}.ts`.
- `combat/Director.ts` — escalating wave spawner (HeatDirector port); `active` flag
  flipped on by the mission.
- `enemies/{Drone,enemyConfig}.ts` — drone AI + `LIGHT_DRONE` tuning.
- `mission/Mission.ts` — the derelict station (real GLB) + dock-to-start defend FSM;
  builds the hull colliders and derives the dock radius from the model's bounds.
- `ui/Hud.ts` (DOM text) + `ui/HudOverlay.ts` (2D-canvas markers/bars/indicators).
- `public/assets/...` — GLBs + the panorama, copied from `../game/assets`.

## Tuning knobs

- Flight feel → `ship/shipConfig.ts`.
- Drone lethality → `enemies/enemyConfig.ts` (damage/fireRate) + the aim cone in
  `enemies/Drone.ts`. Player weapon → `combat/weaponConfig.ts`.
- Wave pacing → constants in `combat/Director.ts`.
- Asteroid density / placement → `ASTEROID_COUNT` + `asteroidPos()` in
  `world/createWorld.ts`.
- Station size / position / dock → `mission/Mission.ts`.
- Post-processing → bloom args + exposure + grade in `main.ts`; lights + IBL gradient
  in `world/createWorld.ts`.

## Gotchas (hard-won)

- **Don't judge speed/collision by flying in a headless browser.** Software-WebGL
  headless runs at low FPS and the `dt` clamp (1/30) makes the sim run in slow motion
  — the ship barely moves in wall-clock time. Use deterministic checks (teleport a
  body onto a collider and call `resolveShip`) instead. Playwright + system Chrome
  with `--use-angle=swiftshader` works for this; install it ad-hoc, don't keep it as a
  dep (its postinstall pulls browsers, bloating `npm i`).
- **Collisions are about *encounters*, not just the math.** The first field was 140
  rocks in a sparse shell at the origin (~8% hit chance) while play happens 700u away
  at the station — felt like no collision. It's now a dense corridor field.
- **Post-processing bypasses the renderer's MSAA.** Must render into a multisampled
  (+ half-float) composer target, or every edge is jaggy.
- **The Milky Way photo can't light the scene** (it's near-black) — lighting comes
  from a synthesized gradient IBL env + lights, not the visible background.
- **Asset weight:** the 89 MB nebula HDR was dropped for the 1.8 MB panorama. The
  station GLB is **33 MB** — instant locally, but a heavy one-time download on a
  deployed build; Draco/decimate it before hosting.
- A single sphere can't represent the station — it walls off the approach. Hence the
  per-sub-mesh AABB hull + bounds-derived dock radius.

## What's next

1. **Co-op via an authoritative Colyseus server** — the headline remaining item.
   Rooms, host-authoritative state, client interpolation. The combat/mission logic is
   already shaped to be server-authoritative.
2. **Engine/thruster FX** — ships have no engine glow yet (Godot had `ShipFX`).
3. **Meta loop** — salvage, credits, upgrades, a lobby/ship bay (none ported).
4. **Deploy + asset optimization** — compress GLBs, host it, share a URL.
5. **Polish** — enemy archetypes, hitstop/juice, audio (none yet).

## Known caveats

- Station AABBs are axis-aligned → a little loose around rotated parts; gaps between
  sub-meshes are flyable.
- Drones don't collide with the world (they phase through, as in Godot).
- One mission, one ship, no persistence, no audio yet.
