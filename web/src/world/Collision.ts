import * as THREE from "three";
import { ShipController } from "../ship/ShipController";

interface Sphere {
  position: THREE.Vector3;
  radius: number;
}

const BOUNCE = 1.15; // >1 = cancel inward velocity + a little push-back

// Sphere + mesh-raycast collision against the ship.
// Asteroids use sphere colliders (fast, accurate for rocks).
// The station uses a THREE.Raycaster against its actual triangles — no AABB
// over-coverage, no invisible walls from rotated geometry.
export class Collision {
  private spheres: Sphere[] = [];
  private stationMeshes: THREE.Mesh[] = [];
  private readonly raycaster = new THREE.Raycaster();
  private readonly _prevPos = new THREE.Vector3();
  private prevPosReady = false;
  private readonly _n = new THREE.Vector3();

  add(position: THREE.Vector3, radius: number): void {
    this.spheres.push({ position, radius });
  }

  /** Register the station's actual meshes for triangle-accurate collision. */
  setStationMeshes(meshes: THREE.Mesh[]): void {
    this.stationMeshes = meshes;
  }

  resolveShip(ship: ShipController): void {
    const r = ship.hitRadius;
    for (const c of this.spheres) this.resolveSphere(ship, c, r);
    this.resolveStation(ship);
    // Save the post-correction position for next frame's ray origin.
    this._prevPos.copy(ship.position);
    this.prevPosReady = true;
  }

  private resolveSphere(ship: ShipController, c: Sphere, shipR: number): void {
    const n = this._n.subVectors(ship.position, c.position);
    const dist = n.length();
    const min = c.radius + shipR;
    if (dist >= min || dist < 1e-4) return;
    n.divideScalar(dist);
    this.pushOut(ship, n, min - dist);
  }

  // Ray from last-good position toward current position.  Any mesh triangle hit
  // closer than (moveDist + hitRadius) means the sphere would have touched it, so
  // push the ship back to the surface.  Face normals are transformed to world space.
  private resolveStation(ship: ShipController): void {
    if (this.stationMeshes.length === 0) return;

    // On the first frame, we have no previous position yet — just record it.
    if (!this.prevPosReady) {
      this._prevPos.copy(ship.position);
      return;
    }

    const curr = ship.position;
    const dir = this._n.subVectors(curr, this._prevPos);
    const moveDist = dir.length();

    // No movement: still check if we're already inside something by casting
    // a tiny ray forward to catch the "pushed into a wall" case.
    const checkDist = moveDist < 1e-4 ? 0.1 : moveDist;
    if (moveDist > 1e-4) dir.divideScalar(moveDist);
    else dir.set(0, 0, -1);

    this.raycaster.set(this._prevPos, dir);
    // We care about hits closer than (moveDist + hitRadius): the sphere's leading
    // edge reaches the surface that far ahead of its centre along the travel path.
    this.raycaster.far = checkDist + ship.hitRadius + 1.0;
    this.raycaster.near = 0;

    const hits = this.raycaster.intersectObjects(this.stationMeshes, false);
    if (hits.length === 0) return;

    const hit = hits[0];
    // Only respond if the centre path + sphere radius reaches the surface.
    if (hit.distance > moveDist + ship.hitRadius) return;
    if (!hit.face) return;

    // Transform the face normal from object space to world space.
    const normal = hit.face.normal
      .clone()
      .transformDirection(hit.object.matrixWorld)
      .normalize();

    // Position the ship so its surface just touches the hit point.
    ship.position.copy(hit.point).addScaledVector(normal, ship.hitRadius);
    const vn = ship.velocity.dot(normal);
    if (vn < 0) ship.velocity.addScaledVector(normal, -vn * BOUNCE);
  }

  private pushOut(ship: ShipController, n: THREE.Vector3, depth: number): void {
    ship.position.addScaledVector(n, depth);
    const vn = ship.velocity.dot(n);
    if (vn < 0) ship.velocity.addScaledVector(n, -vn * BOUNCE);
  }
}
