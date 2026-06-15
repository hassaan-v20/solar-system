import * as THREE from "three";
import { ShipController } from "../ship/ShipController";

export interface Collider {
  position: THREE.Vector3;
  radius: number;
}

// Sphere-vs-sphere collision: each obstacle is a sphere and the ship a small sphere.
// On overlap we push the ship back to the surface and cancel its inward velocity (with
// a slight bounce), so it stops/slides instead of phasing through. Keeps the custom
// Newtonian integrator — no physics engine needed at this scale.
export class Collision {
  readonly colliders: Collider[] = [];
  private _n = new THREE.Vector3();

  add(position: THREE.Vector3, radius: number): void {
    this.colliders.push({ position, radius });
  }

  resolveShip(ship: ShipController): void {
    const shipR = ship.hitRadius;
    for (const c of this.colliders) {
      const n = this._n.subVectors(ship.position, c.position);
      const dist = n.length();
      const min = c.radius + shipR;
      if (dist >= min || dist < 1e-4) continue;
      n.divideScalar(dist); // contact normal
      ship.position.addScaledVector(n, min - dist); // push out to the surface
      const vn = ship.velocity.dot(n);
      if (vn < 0) ship.velocity.addScaledVector(n, -vn * 1.15); // remove inward velocity + slight bounce
    }
  }
}
