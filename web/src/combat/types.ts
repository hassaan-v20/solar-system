import * as THREE from "three";

// Friend/foe is decided by team, not collision layers (web has no physics layers yet).
export type Team = "player" | "enemy";

// Anything a bolt can hit and hurt — the player ship and enemy drones both satisfy it.
export interface Damageable {
  readonly position: THREE.Vector3;
  readonly velocity: THREE.Vector3;
  readonly hitRadius: number;
  alive: boolean;
  applyDamage(amount: number): void;
}
