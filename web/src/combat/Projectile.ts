import * as THREE from "three";
import { Team } from "./types";

// A fired energy bolt. Travels straight at its spawn velocity (muzzle + inherited
// ship velocity) and despawns after `range`. Hit-testing is done by Combat against
// the opposing team (segment vs sphere), so the bolt itself stays dumb.
export class Projectile {
  readonly mesh: THREE.Mesh;
  readonly velocity = new THREE.Vector3();
  readonly prev = new THREE.Vector3();
  dead = false;
  private life: number;

  // Shared geometry across all bolts (cheap); each gets its own unlit material so it
  // blooms. The capsule's axis is +Y, so we orient that to the travel direction.
  private static geo = new THREE.CapsuleGeometry(0.13, 1.7, 4, 8);

  constructor(
    private scene: THREE.Scene,
    pos: THREE.Vector3,
    vel: THREE.Vector3,
    readonly team: Team,
    readonly damage: number,
    readonly color: number,
    range: number,
  ) {
    this.velocity.copy(vel);
    this.mesh = new THREE.Mesh(Projectile.geo, new THREE.MeshBasicMaterial({ color }));
    this.mesh.position.copy(pos);
    this.mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), vel.clone().normalize());
    this.life = range / Math.max(1, vel.length());
    scene.add(this.mesh);
  }

  update(dt: number): void {
    this.prev.copy(this.mesh.position);
    this.mesh.position.addScaledVector(this.velocity, dt);
    this.life -= dt;
    if (this.life <= 0) this.dead = true;
  }

  dispose(): void {
    this.scene.remove(this.mesh);
    (this.mesh.material as THREE.Material).dispose();
  }
}
