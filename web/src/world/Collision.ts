import * as THREE from "three";
import { ShipController } from "../ship/ShipController";

interface Sphere {
  position: THREE.Vector3;
  radius: number;
}

interface MeshEntry {
  mesh: THREE.Mesh;
  center: THREE.Vector3; // world-space bounding sphere center, computed once
  radius: number;        // world-space bounding sphere radius, computed once
}

const ASTEROID_BOUNCE   = 1.15; // bounce off rocks — feels punchy
const STATION_BOUNCE    = 1.00; // cancel inward velocity exactly — no bounce, smooth slide
// Only run station collision when ship is within this distance of the station
// center. The station bounding sphere is ~460u; add margin for approach.
const STATION_GATE_DIST = 550;
// Maximum candidate meshes to raycast against per frame — caps per-frame cost
// when the ship is inside a dense part of the model.
const MAX_CANDIDATES    = 24;

export class Collision {
  private spheres: Sphere[] = [];

  private stationEntries: MeshEntry[] = [];
  private stationCenter  = new THREE.Vector3();
  private stationGateDist = STATION_GATE_DIST;

  private readonly raycaster = new THREE.Raycaster();
  private readonly _prevPos  = new THREE.Vector3();
  private prevPosReady = false;

  private readonly _n   = new THREE.Vector3();
  private readonly _tmp = new THREE.Vector3();

  add(position: THREE.Vector3, radius: number): void {
    this.spheres.push({ position, radius });
  }

  /**
   * Register the station's mesh objects for triangle-accurate collision.
   * Call once after the model and its matrixWorld are finalised (after
   * g.updateMatrixWorld(true)).  Precomputes world-space bounding spheres
   * so the per-frame hot path is cheap.
   */
  setStationMeshes(meshes: THREE.Mesh[]): void {
    const wholeBbox = new THREE.Box3();
    this.stationEntries = meshes.map((mesh) => {
      mesh.geometry.computeBoundingSphere();
      const ls = mesh.geometry.boundingSphere!;
      // Transform centre + radius to world space via the mesh's matrixWorld.
      const center = ls.center.clone().applyMatrix4(mesh.matrixWorld);
      const scaleVec = new THREE.Vector3();
      mesh.matrixWorld.decompose(new THREE.Vector3(), new THREE.Quaternion(), scaleVec);
      const radius = ls.radius * Math.max(scaleVec.x, scaleVec.y, scaleVec.z);
      wholeBbox.expandByPoint(center);
      return { mesh, center, radius };
    });
    // Distance gate: skip all raycasting when the ship is farther than this
    // from the station's geometric centre.
    if (!wholeBbox.isEmpty()) {
      wholeBbox.getCenter(this.stationCenter);
      const r = wholeBbox.getBoundingSphere(new THREE.Sphere()).radius;
      this.stationGateDist = r + 60;
    }
  }

  resolveShip(ship: ShipController): void {
    const r = ship.hitRadius;
    for (const c of this.spheres) this.resolveSphere(ship, c, r);
    this.resolveStation(ship);
    this._prevPos.copy(ship.position);
    this.prevPosReady = true;
  }

  private resolveSphere(ship: ShipController, c: Sphere, shipR: number): void {
    const n = this._n.subVectors(ship.position, c.position);
    const dist = n.length();
    const min = c.radius + shipR;
    if (dist >= min || dist < 1e-4) return;
    n.divideScalar(dist);
    this.pushOut(ship, n, min - dist, ASTEROID_BOUNCE);
  }

  private resolveStation(ship: ShipController): void {
    if (this.stationEntries.length === 0) return;

    // Distance gate — most of the flight is far from the station.
    if (ship.position.distanceTo(this.stationCenter) > this.stationGateDist) {
      this._prevPos.copy(ship.position);
      return;
    }

    if (!this.prevPosReady) {
      this._prevPos.copy(ship.position);
      return;
    }

    // Ray from last-good position toward current position.
    const curr   = ship.position;
    const dir    = this._n.subVectors(curr, this._prevPos);
    const moveDist = dir.length();
    if (moveDist > 1e-4) dir.divideScalar(moveDist);
    else dir.copy(curr).sub(this.stationCenter).normalize(); // fallback: aim outward

    // Sphere-sweep check: the sphere's leading edge reaches a surface
    // (moveDist + hitRadius) ahead of the previous center.
    const checkFar = moveDist + ship.hitRadius + 0.5;
    this.raycaster.set(this._prevPos, dir);
    this.raycaster.near = 0;
    this.raycaster.far  = checkFar;

    // Pre-filter: only test meshes whose world-space bounding sphere the ray
    // could possibly reach (center within radius + checkFar of the ray origin).
    const gate2 = (ship.hitRadius + checkFar);
    const candidates: THREE.Mesh[] = [];
    for (const e of this.stationEntries) {
      const d2 = this._prevPos.distanceToSquared(e.center);
      if (d2 < (e.radius + gate2) * (e.radius + gate2)) {
        candidates.push(e.mesh);
        if (candidates.length >= MAX_CANDIDATES) break;
      }
    }
    if (candidates.length === 0) return;

    const hits = this.raycaster.intersectObjects(candidates, false);
    if (hits.length === 0) return;

    const hit = hits[0];
    // Only respond if the sphere's leading edge actually reaches this surface.
    if (hit.distance > moveDist + ship.hitRadius) return;
    if (!hit.face) return;

    // Transform the face normal to world space.
    const normal = this._tmp
      .copy(hit.face.normal)
      .transformDirection(hit.object.matrixWorld)
      .normalize();

    // Ensure the normal faces TOWARD the ship (i.e., opposes the ray direction).
    // If we hit a back-face, the raw normal would point away and snap us further in.
    if (normal.dot(dir) > 0) normal.negate();

    // Place ship so its surface just grazes the hit point.
    ship.position.copy(hit.point).addScaledVector(normal, ship.hitRadius + 0.05);
    const vn = ship.velocity.dot(normal);
    if (vn < 0) ship.velocity.addScaledVector(normal, -vn * STATION_BOUNCE);
  }

  private pushOut(
    ship: ShipController, n: THREE.Vector3, depth: number, bounce: number,
  ): void {
    ship.position.addScaledVector(n, depth);
    const vn = ship.velocity.dot(n);
    if (vn < 0) ship.velocity.addScaledVector(n, -vn * bounce);
  }
}
