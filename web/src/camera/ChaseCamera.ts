import * as THREE from "three";
import { damp } from "../core/mathf";

// Smooth third-person chase: sits behind/above the ship (local +Z is behind, since
// forward is -Z) and eases toward that pose so fast maneuvers read with a little lag.
export class ChaseCamera {
  private readonly offset = new THREE.Vector3(0, 2.4, 9.5);
  private readonly lookAhead = new THREE.Vector3(0, 0.8, -6);
  private readonly _desired = new THREE.Vector3();
  private readonly _look = new THREE.Vector3();

  constructor(public camera: THREE.PerspectiveCamera, private posRate = 9) {}

  update(dt: number, target: THREE.Object3D, snap = false): void {
    this._desired.copy(this.offset).applyQuaternion(target.quaternion).add(target.position);
    this._look.copy(this.lookAhead).applyQuaternion(target.quaternion).add(target.position);
    if (snap) {
      this.camera.position.copy(this._desired);
    } else {
      this.camera.position.lerp(this._desired, damp(this.posRate, dt));
    }
    // Ease the look target too, then orient with the ship's own up so rolls read.
    this.camera.up.set(0, 1, 0).applyQuaternion(target.quaternion);
    this.camera.lookAt(this._look);
  }
}
