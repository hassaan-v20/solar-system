import * as THREE from "three";
import { ShipController } from "../ship/ShipController";

interface Sphere {
  position: THREE.Vector3;
  radius: number;
}

const BOUNCE = 1.15; // >1 = cancel inward velocity + a little push-back

// Sphere + AABB collision against the ship (a small sphere). Asteroids are spheres;
// the station registers a box per hull sub-mesh so collision follows the real shape.
// On overlap the ship is pushed to the surface and its inward velocity cancelled, so
// it stops/slides instead of phasing through — keeps the custom Newtonian integrator.
export class Collision {
  private spheres: Sphere[] = [];
  private boxes: THREE.Box3[] = [];
  private _n = new THREE.Vector3();

  add(position: THREE.Vector3, radius: number): void {
    this.spheres.push({ position, radius });
  }

  addBox(box: THREE.Box3): void {
    this.boxes.push(box);
  }

  resolveShip(ship: ShipController): void {
    const r = ship.hitRadius;
    for (const c of this.spheres) this.resolveSphere(ship, c, r);
    for (const b of this.boxes) this.resolveBox(ship, b, r);
  }

  private resolveSphere(ship: ShipController, c: Sphere, shipR: number): void {
    const n = this._n.subVectors(ship.position, c.position);
    const dist = n.length();
    const min = c.radius + shipR;
    if (dist >= min || dist < 1e-4) return;
    n.divideScalar(dist);
    this.pushOut(ship, n, min - dist);
  }

  private resolveBox(ship: ShipController, box: THREE.Box3, shipR: number): void {
    const p = ship.position;
    // Closest point on the box to the ship center.
    const cx = Math.max(box.min.x, Math.min(p.x, box.max.x));
    const cy = Math.max(box.min.y, Math.min(p.y, box.max.y));
    const cz = Math.max(box.min.z, Math.min(p.z, box.max.z));
    const dx = p.x - cx;
    const dy = p.y - cy;
    const dz = p.z - cz;
    const d2 = dx * dx + dy * dy + dz * dz;

    if (d2 > shipR * shipR) return;

    if (d2 > 1e-8) {
      // Outside the box, within shipR of the surface — push out along the contact normal.
      const d = Math.sqrt(d2);
      this.pushOut(ship, this._n.set(dx / d, dy / d, dz / d), shipR - d);
    } else {
      // Center inside the box — push out along the least-penetration axis.
      const px = Math.min(p.x - box.min.x, box.max.x - p.x);
      const py = Math.min(p.y - box.min.y, box.max.y - p.y);
      const pz = Math.min(p.z - box.min.z, box.max.z - p.z);
      if (px <= py && px <= pz) this._n.set(p.x - box.min.x < box.max.x - p.x ? -1 : 1, 0, 0);
      else if (py <= pz) this._n.set(0, p.y - box.min.y < box.max.y - p.y ? -1 : 1, 0);
      else this._n.set(0, 0, p.z - box.min.z < box.max.z - p.z ? -1 : 1);
      this.pushOut(ship, this._n, Math.min(px, py, pz) + shipR);
    }
  }

  private pushOut(ship: ShipController, n: THREE.Vector3, depth: number): void {
    ship.position.addScaledVector(n, depth);
    const vn = ship.velocity.dot(n);
    if (vn < 0) ship.velocity.addScaledVector(n, -vn * BOUNCE);
  }
}
