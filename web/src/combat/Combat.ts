import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { Projectile } from "./Projectile";
import { Explosion } from "./Explosion";
import { Weapon } from "./Weapon";
import { LASER_MK1, WeaponDef } from "./weaponConfig";
import { Team, Damageable } from "./types";
import { Drone } from "../enemies/Drone";
import { LIGHT_DRONE } from "../enemies/enemyConfig";
import { ShipController } from "../ship/ShipController";

const DRONE_URL = "/assets/models/enemies/scifi_drone.glb";

// Owns the combat sim: player firing, projectiles + hit-testing, drones (AI + their
// fire), explosions, and death FX. Host-authoritative-ready in shape — this is the
// logic the Colyseus server will eventually run.
export class Combat {
  projectiles: Projectile[] = [];
  explosions: Explosion[] = [];
  drones: Drone[] = [];
  readonly playerWeapon = new Weapon(LASER_MK1);
  killCount = 0;

  private droneProto: THREE.Object3D | null = null;
  private shipDeathShown = false;

  constructor(private scene: THREE.Scene, private ship: ShipController) {
    new GLTFLoader().load(
      DRONE_URL,
      (g) => {
        this.droneProto = g.scene;
      },
      undefined,
      () => {}, // fall back to a placeholder hull per drone if the model is missing
    );
  }

  spawnDrone(pos: THREE.Vector3): void {
    const d = new Drone(this.scene, LIGHT_DRONE, this.droneProto);
    d.object.position.copy(pos);
    this.drones.push(d);
  }

  fireFrom(source: THREE.Object3D, team: Team, def: WeaponDef, inheritedVel: THREE.Vector3): void {
    const dir = new THREE.Vector3(0, 0, -1).applyQuaternion(source.quaternion);
    const muzzle = source.position.clone().addScaledVector(dir, 2.6);
    const vel = dir.multiplyScalar(def.projectileSpeed).add(inheritedVel);
    this.projectiles.push(new Projectile(this.scene, muzzle, vel, team, def.damage, def.boltColor, def.range));
  }

  explode(pos: THREE.Vector3, size: number, color: number): void {
    this.explosions.push(new Explosion(this.scene, pos, size, color));
  }

  update(dt: number, fire: boolean): void {
    // Player weapon.
    this.playerWeapon.tick(dt);
    if (fire && this.ship.alive && this.playerWeapon.ready) {
      this.fireFrom(this.ship.object, "player", this.playerWeapon.def, this.ship.velocity);
      this.playerWeapon.fired();
    }

    // Drones: AI + their own fire.
    for (const d of this.drones) if (d.alive) d.update(dt, this.ship, this);
    // Remove dead drones with a bang.
    this.drones = this.drones.filter((d) => {
      if (d.alive) return true;
      this.explode(d.position, 2.4, 0xffa030);
      d.dispose();
      this.killCount++;
      return false;
    });

    // Projectiles: move, then hit-test the segment against the opposing team.
    for (const p of this.projectiles) {
      p.update(dt);
      if (p.dead) continue;
      const targets: Damageable[] = p.team === "player" ? this.drones : [this.ship];
      for (const t of targets) {
        if (t.alive && segmentHitsSphere(p.prev, p.mesh.position, t.position, t.hitRadius)) {
          t.applyDamage(p.damage);
          this.explode(p.mesh.position, 0.7, p.color);
          p.dead = true;
          break;
        }
      }
    }
    this.projectiles = this.projectiles.filter((p) => {
      if (!p.dead) return true;
      p.dispose();
      return false;
    });

    // Player death FX, once.
    if (!this.ship.alive && !this.shipDeathShown) {
      this.shipDeathShown = true;
      this.explode(this.ship.position, 3.8, 0xff8c33);
    }

    // Explosions.
    this.explosions = this.explosions.filter((e) => {
      e.update(dt);
      if (!e.dead) return true;
      e.dispose();
      return false;
    });
  }
}

// True if the segment a→b passes within `r` of `c` (bolt-vs-target, tunnel-safe).
function segmentHitsSphere(a: THREE.Vector3, b: THREE.Vector3, c: THREE.Vector3, r: number): boolean {
  const ab = new THREE.Vector3().subVectors(b, a);
  const len2 = ab.lengthSq();
  let t = len2 > 0 ? new THREE.Vector3().subVectors(c, a).dot(ab) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  const closest = a.clone().addScaledVector(ab, t);
  return closest.distanceToSquared(c) <= r * r;
}
