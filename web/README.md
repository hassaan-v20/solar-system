# Stellar — web build (three.js + TypeScript)

Web-first rebuild of Stellar. The Godot prototype lives in `../game` (tagged
`godot-engine-checkpoint`) and is the reference for feel + mechanics.

## Run

```bash
cd web
npm install
npm run dev      # Vite dev server with HMR; open the printed URL
```

`npm run dev` exposes the server on the LAN (`host: true`), so a second machine can
open it for quick testing while co-op is being built.

```bash
npm run typecheck   # tsc --noEmit
npm run build       # typecheck + production bundle to dist/
```

## Status — flight + combat

- Newtonian flight ported from the Godot `ship_controller.gd` (coast/drift, flight
  assist, finite boost reserve) + shield/hull health and death.
- Combat: rate/heat-limited laser, glowing bolts that inherit ship velocity, enemy
  drones (lead-aim AI, orbit, fire), explosions, and an escalating wave Director.
- 8K Milky Way skybox (also a subtle IBL env) + UnrealBloom glow + ACES tonemapping,
  real GLB asteroid field, distant planet backdrop, smoothed chase camera.

Controls: **W/S** thrust · **mouse** aim · **LMB** fire · **A/D** roll · **Q/E**
strafe · **Space/C** up·down · **Shift** boost · **Ctrl** brake · **Z** flight-assist.
Controller: left stick move · right stick aim · **RT** fire · **L3** toggle-boost ·
**LB/RB** roll · **L2** brake · **▲** flight-assist. Click / press a button to start.

## Next

Full HUD (health bars, lead pip, off-screen indicators) → mission (the station +
defend) → co-op via an authoritative **Colyseus** server. See `../docs/CHECKPOINT.md`.

## Layout

- `src/core` — input, math, loop helpers
- `src/ship` — flight controller + tuning (`shipConfig.ts`) + model loader
- `src/camera` — chase camera
- `src/world` — sector (lights, starfield, asteroids)
- `src/ui` — HUD
- `public/assets` — GLB models (copied from `game/assets`)
