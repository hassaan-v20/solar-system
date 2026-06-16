import * as THREE from "three";
import { Weapon } from "../combat/Weapon";
import { WeaponDef } from "../combat/weaponConfig";
import { Damageable, Team } from "../combat/types";
import { EnemyDef } from "./enemyConfig";
import { clamp } from "../core/mathf";
import { interceptTime } from "../combat/ballistics";

const FORWARD = new THREE.Vector3(0, 0, -1);
const UP = new THREE.Vector3(0, 1, 0);
const X_AXIS = new THREE.Vector3(1, 0, 0);

// What a drone needs from Combat to shoot (kept as an interface to avoid a circular
// import; Combat satisfies it structurally).
export interface BoltSink {
  fireFrom(source: THREE.Object3D, team: Team, def: WeaponDef, inheritedVel: THREE.Vector3): void;
}

// Light drone AI ported from Godot's enemy_drone_ai.gd: slew to face the lead point,
// hold preferred range while orbiting, fire when lined up and in range. No physics —
// it moves itself directly (it phased through the environment in Godot too).
export class Drone implements Damageable {
  readonly object = new THREE.Group();
  readonly velocity = new THREE.Vector3();
  hull: number;
  alive = true;
  readonly hitRadius = 2.5;
  private weapon: Weapon;

  // scratch vectors — reused every frame, no per-frame heap allocation
  private readonly _toTarget = new THREE.Vector3();
  private readonly _dir = new THREE.Vector3();
  private readonly _aim = new THREE.Vector3();
  private readonly _wantQ = new THREE.Quaternion();
  private readonly _radial = new THREE.Vector3();
  private readonly _tangent = new THREE.Vector3();
  private readonly _desired = new THREE.Vector3();
  private readonly _fwd = new THREE.Vector3();
  private readonly _vrel = new THREE.Vector3();
  private readonly _d = new THREE.Vector3();

  constructor(private scene: THREE.Scene, private def: EnemyDef, proto: THREE.Object3D | null) {
    this.hull = def.hullMax;
    this.buildModel(proto);
    this.weapon = new Weapon({
      damage: def.weaponDamage,
      fireRate: def.fireRate,
      projectileSpeed: def.projectileSpeed,
      range: 600,
      boltColor: 0xff7a28,
      maxHeat: 1e9, // drones never overheat
      heatPerShot: 0,
      cooldownRate: 0,
    });
    scene.add(this.object);
  }

  get position(): THREE.Vector3 {
    return this.object.position;
  }

  applyDamage(amount: number): void {
    if (!this.alive) return;
    this.hull = Math.max(0, this.hull - amount);
    if (this.hull <= 0) this.alive = false;
  }

  healthFraction(): number {
    return clamp(this.hull / this.def.hullMax, 0, 1);
  }

  dispose(): void {
    this.scene.remove(this.object);
  }

  update(dt: number, target: Damageable, sink: BoltSink): void {
    this.weapon.tick(dt);
    this._toTarget.subVectors(target.position, this.object.position);
    const dist = this._toTarget.length();
    if (dist < 0.01) return;
    this._dir.copy(this._toTarget).divideScalar(dist);
    this.leadDirection(this._toTarget, target.velocity, this._aim);

    // Slew to face the lead point.
    this._wantQ.setFromUnitVectors(FORWARD, this._aim);
    this.object.quaternion.slerp(this._wantQ, clamp(this.def.turnSpeed * dt, 0, 1));

    // Station-keeping: close/hold the preferred range while orbiting (moving target).
    const rangeErr = dist - this.def.preferredRange;
    this._radial.copy(this._dir).multiplyScalar(clamp(rangeErr / 20, -1, 1));
    this._tangent.crossVectors(this._dir, UP);
    if (this._tangent.length() < 0.01) this._tangent.crossVectors(this._dir, X_AXIS);
    this._tangent.normalize();
    this._desired.copy(this._radial).addScaledVector(this._tangent, 0.6).clampLength(0, 1).multiplyScalar(this.def.moveSpeed);
    this.moveVelToward(this._desired, this.def.accel * dt);
    this.object.position.addScaledVector(this.velocity, dt);

    // Fire only when actually lined up on the lead point and in range.
    this._fwd.copy(FORWARD).applyQuaternion(this.object.quaternion);
    if (dist <= this.def.preferredRange * 1.8 && this._fwd.dot(this._aim) > 0.985 && this.weapon.ready) {
      sink.fireFrom(this.object, "enemy", this.weapon.def, this.velocity);
      this.weapon.fired();
    }
  }

  // Where to point so a bolt (muzzle speed + our own velocity) intercepts the moving
  // target; falls back to aiming straight at it when there's no solution.
  private leadDirection(toTarget: THREE.Vector3, targetVel: THREE.Vector3, out: THREE.Vector3): void {
    const bs = Math.max(1, this.def.projectileSpeed);
    this._vrel.copy(targetVel).sub(this.velocity);
    const t = interceptTime(toTarget, this._vrel, bs);
    if (t <= 0) { out.copy(toTarget).normalize(); return; }
    out.copy(toTarget).addScaledVector(this._vrel, t);
    const len = out.length();
    if (len > 0.001) out.divideScalar(len); else out.copy(toTarget).normalize();
  }

  private moveVelToward(target: THREE.Vector3, maxDelta: number): void {
    this._d.subVectors(target, this.velocity);
    const len = this._d.length();
    if (len <= maxDelta || len === 0) this.velocity.copy(target);
    else this.velocity.addScaledVector(this._d.divideScalar(len), maxDelta);
  }

  private buildModel(proto: THREE.Object3D | null): void {
    if (proto) {
      const model = proto.clone(true);
      const box = new THREE.Box3().setFromObject(model);
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z) || 1;
      model.position.sub(center);
      const holder = new THREE.Group();
      holder.scale.setScalar(3.5 / maxDim);
      holder.add(model);
      this.object.add(holder);
    } else {
      const mat = new THREE.MeshStandardMaterial({ color: 0x551016, emissive: 0xaa2014, emissiveIntensity: 0.7, metalness: 0.4, roughness: 0.5 });
      this.object.add(new THREE.Mesh(new THREE.BoxGeometry(2, 1, 2.2), mat));
    }
  }
}
