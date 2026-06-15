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

## Status — flight slice

- Newtonian flight ported from the Godot `ship_controller.gd` (coast/drift, flight
  assist, finite boost reserve). Controls: **W/S** thrust · **mouse** aim · **A/D**
  roll · **Q/E** strafe · **Space/C** up·down · **Shift** boost · **Ctrl** brake ·
  **Z** flight-assist. Click the canvas to capture the mouse; **Esc** releases it.
- Chase camera, procedural asteroid field, starfield, real ship GLB.

## Next

Combat → mission (defend) → co-op via an authoritative **Colyseus** server. See
`../docs/CHECKPOINT.md` for the feature target.

## Layout

- `src/core` — input, math, loop helpers
- `src/ship` — flight controller + tuning (`shipConfig.ts`) + model loader
- `src/camera` — chase camera
- `src/world` — sector (lights, starfield, asteroids)
- `src/ui` — HUD
- `public/assets` — GLB models (copied from `game/assets`)
