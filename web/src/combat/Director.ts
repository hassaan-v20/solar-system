import * as THREE from "three";
import { Combat } from "./Combat";
import { ShipController } from "../ship/ShipController";
import { clamp } from "../core/mathf";

// Escalating-threat wave spawner, ported from Godot's HeatDirector. Heat rises with
// time; higher heat means faster, bigger waves, capped so it never runs away.
const TIME_TO_MAX = 150;
const SPAWN_SLOW = 13;
const SPAWN_FAST = 3.5;
const MAX_ALIVE = 8;
const SPAWN_MIN = 80;
const SPAWN_MAX = 130;

export class Director {
  heat = 0;
  private cooldown = 2; // first wave shortly after start

  constructor(private combat: Combat, private ship: ShipController) {}

  update(dt: number): void {
    if (!this.ship.alive) return;
    this.heat = clamp(this.heat + dt / TIME_TO_MAX, 0, 1);
    this.cooldown -= dt;
    if (this.cooldown <= 0) {
      this.cooldown = SPAWN_SLOW + (SPAWN_FAST - SPAWN_SLOW) * this.heat;
      this.spawnWave();
    }
  }

  private spawnWave(): void {
    if (this.combat.drones.length >= MAX_ALIVE) return;
    const count = 1 + Math.round(this.heat * 2); // 1..3, scaling with heat
    for (let i = 0; i < count; i++) {
      const pos = new THREE.Vector3()
        .randomDirection()
        .multiplyScalar(SPAWN_MIN + Math.random() * (SPAWN_MAX - SPAWN_MIN))
        .add(this.ship.position);
      this.combat.spawnDrone(pos);
    }
  }
}
