import * as THREE from "three";
import { Input } from "../core/Input";
import { clamp, moveToward } from "../core/mathf";
import { settings } from "../core/Settings";
import { ShipConfig, WAYFARER } from "./shipConfig";
import { Damageable } from "../combat/types";

// Newtonian rigid-body flight, ported from Godot's ship_controller.gd. Thrust and
// steering are accelerations applied to conserved linear/angular momentum, so the
// ship coasts and drifts. Flight assist (Z) is an RCS controller that nulls the
// velocity/spin the pilot isn't commanding, within a thrust budget (coupled flight).
//
// Convention: forward is local -Z, up is +Y (matches three's camera + Godot).
// `velocity` and `angularVelocity` are world-space, like Godot's body state.
// Toggle to true during testing to disable boost drain and lock-out.
export const DEV_INFINITE_BOOST = true;

export class ShipController implements Damageable {
  readonly object = new THREE.Group();
  readonly velocity = new THREE.Vector3();
  readonly angularVelocity = new THREE.Vector3();

  flightAssist: boolean;
  isBoosting = false;
  boostEnergy: number;
  boostLocked = false;
  boostLatched = false; // L3 toggles sustained boost; cleared by L2 or a full drain
  throttle = 0; // forward thrust 0..1 this frame (for engine FX later)

  // Combat: shield-then-hull health; the ship is a Damageable target for enemy bolts.
  readonly hitRadius = 3;
  alive = true;
  hull: number;
  shield: number;

  // scratch vectors reused each frame (no per-frame allocation)
  private readonly _inv = new THREE.Quaternion();
  private readonly _w = new THREE.Vector3();
  private readonly _cmd = new THREE.Vector3();
  private readonly _vLocal = new THREE.Vector3();
  private readonly _thrust = new THREE.Vector3();
  private readonly _dq = new THREE.Quaternion();
  private readonly _axis = new THREE.Vector3();

  constructor(public cfg: ShipConfig = WAYFARER) {
    this.flightAssist = cfg.flightAssistDefault;
    this.boostEnergy = cfg.boostCapacity;
    this.hull = cfg.hullMax;
    this.shield = cfg.shieldMax;
  }

  get speed(): number {
    return this.velocity.length();
  }

  get position(): THREE.Vector3 {
    return this.object.position;
  }

  // Damage flows shield-first, then hull (GDD §13). Death zeroes control (see update).
  applyDamage(amount: number): void {
    if (amount <= 0 || !this.alive) return;
    const toShield = Math.min(this.shield, amount);
    this.shield -= toShield;
    this.hull = Math.max(0, this.hull - (amount - toShield));
    if (this.hull <= 0) this.alive = false;
  }

  update(dt: number, input: Input): void {
    this._inv.copy(this.object.quaternion).invert();
    if (!this.alive) {
      // Controls are dead after destruction: coast to a stop, bleed off spin.
      this.moveVecToward(this.velocity, this.cfg.brakeDecel * dt);
      this.angularVelocity.multiplyScalar(Math.max(0, 1 - 3 * dt));
      this.applySpin(dt);
      this.object.position.addScaledVector(this.velocity, dt);
      return;
    }
    this.integrateRotation(dt, input);
    this.integrateTranslation(dt, input);
    this.object.position.addScaledVector(this.velocity, dt);
  }

  private integrateRotation(dt: number, input: Input): void {
    const c = this.cfg;
    const { dx, dy } = input.consumeMouse();
    const aim = input.aimStick();
    const roll = input.roll();
    // Mouse + right-stick + roll feed a commanded turn RATE (steering has inertia).
    this._cmd.set(
      clamp(-dy * settings.mouseSensitivity + aim.y * c.turnRate, -c.turnRate, c.turnRate), // pitch (local x)
      clamp(-dx * settings.mouseSensitivity - aim.x * c.turnRate, -c.turnRate, c.turnRate), // yaw   (local y)
      clamp(roll * c.rollRate, -c.rollRate, c.rollRate), // roll  (local z)
    );

    // Current spin in local axes, ramped toward the command (assist damps the rest).
    this._w.copy(this.angularVelocity).applyQuaternion(this._inv);
    for (const k of ["x", "y", "z"] as const) {
      if (Math.abs(this._cmd[k]) > 1e-4) {
        this._w[k] = moveToward(this._w[k], this._cmd[k], c.turnAccel * dt);
      } else if (this.flightAssist) {
        this._w[k] = moveToward(this._w[k], 0, c.rotAssist * dt);
      }
    }
    this.angularVelocity.copy(this._w).applyQuaternion(this.object.quaternion);
    this.applySpin(dt);
  }

  // Integrate orientation by the world-space angular velocity.
  private applySpin(dt: number): void {
    const angle = this.angularVelocity.length() * dt;
    if (angle > 1e-6) {
      this._axis.copy(this.angularVelocity).normalize();
      this._dq.setFromAxisAngle(this._axis, angle);
      this.object.quaternion.premultiply(this._dq).normalize();
    }
  }

  private integrateTranslation(dt: number, input: Input): void {
    const c = this.cfg;
    const thrust = input.thrust(); // +forward / −reverse
    const strafe = input.strafe();
    const lift = input.lift();
    const braking = input.brake();
    if (input.assistTogglePressed()) this.flightAssist = !this.flightAssist;
    if (input.boostTogglePressed()) this.boostLatched = !this.boostLatched;
    if (input.boostCancelPressed()) this.boostLatched = false;

    this.updateBoost(dt, input.boostHeld() || this.boostLatched);
    this.throttle = clamp(thrust, 0, 1);

    const boostMult = this.isBoosting ? c.boostAccelMult : 1;
    const fwdAccel = (thrust >= 0 ? c.acceleration : c.reverseAccel) * boostMult;
    this._thrust.set(strafe * c.strafeAccel, lift * c.strafeAccel, -thrust * fwdAccel); // nose = -Z
    this._thrust.applyQuaternion(this.object.quaternion); // local → world
    this.velocity.addScaledVector(this._thrust, dt);

    if (braking) {
      this.moveVecToward(this.velocity, c.brakeDecel * dt);
    } else if (this.flightAssist) {
      this.applyFlightAssist(dt, thrust, strafe, lift);
    }
    this.governSpeed(braking);
  }

  // Flight assist: in ship-local space, bleed off only the velocity the pilot isn't
  // commanding, capped by the RCS decel budget so it reads as thrusters, not magic.
  private applyFlightAssist(dt: number, thrust: number, strafe: number, lift: number): void {
    this._vLocal.copy(this.velocity).applyQuaternion(this._inv);
    this._vLocal.x = this.nullAxis(this._vLocal.x, Math.abs(strafe) > 0.01, dt);
    this._vLocal.y = this.nullAxis(this._vLocal.y, Math.abs(lift) > 0.01, dt);
    this._vLocal.z = this.nullAxis(this._vLocal.z, Math.abs(thrust) > 0.01, dt);
    this.velocity.copy(this._vLocal).applyQuaternion(this.object.quaternion);
  }

  private nullAxis(v: number, commanded: boolean, dt: number): number {
    if (commanded) return v;
    const want = -v * clamp(this.cfg.assistResponse * dt, 0, 1);
    const budget = this.cfg.assistDecel * dt;
    return v + clamp(want, -budget, budget);
  }

  // Powered cap with assist/brake; a raw Newtonian coast keeps momentum up to the
  // absolute boost ceiling — so boosting and releasing leaves you sliding fast.
  private governSpeed(braking: boolean): void {
    const c = this.cfg;
    const sp = this.velocity.length();
    if (this.flightAssist || braking) {
      const cap = this.isBoosting ? c.boostSpeed : c.maxSpeed;
      if (sp > cap) this.velocity.multiplyScalar(cap / sp);
    } else if (sp > c.boostSpeed) {
      this.velocity.multiplyScalar(c.boostSpeed / sp);
    }
  }

  // Finite boost reserve: drains while held, refills when idle, locks out on empty
  // until it recovers past boostRelockFrac (no stutter-boosting at zero).
  private updateBoost(dt: number, want: boolean): void {
    if (DEV_INFINITE_BOOST) {
      this.isBoosting = want;
      this.boostEnergy = this.cfg.boostCapacity;
      this.boostLocked = false;
      return;
    }
    const c = this.cfg;
    if (want && !this.boostLocked && this.boostEnergy > 0) {
      this.isBoosting = true;
      this.boostEnergy = Math.max(0, this.boostEnergy - c.boostDrain * dt);
      if (this.boostEnergy <= 0) {
        this.boostLocked = true;
        this.boostLatched = false; // drained out — drop the toggle so it doesn't auto-re-engage
      }
    } else {
      this.isBoosting = false;
      this.boostEnergy = Math.min(c.boostCapacity, this.boostEnergy + c.boostRegen * dt);
      if (this.boostLocked && this.boostEnergy >= c.boostCapacity * c.boostRelockFrac) {
        this.boostLocked = false;
      }
    }
  }

  private moveVecToward(v: THREE.Vector3, maxDelta: number): void {
    const len = v.length();
    if (len <= maxDelta) v.set(0, 0, 0);
    else v.multiplyScalar((len - maxDelta) / len);
  }
}
