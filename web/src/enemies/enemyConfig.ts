// Enemy tuning — ported from the Godot light_drone.tres (with the tuned-up damage).
export interface EnemyDef {
  hullMax: number;
  moveSpeed: number;
  accel: number;
  turnSpeed: number; // rad/s slewed toward the lead point
  preferredRange: number;
  weaponDamage: number;
  fireRate: number;
  projectileSpeed: number;
}

export const LIGHT_DRONE: EnemyDef = {
  hullMax: 60,
  moveSpeed: 26,
  accel: 18,
  turnSpeed: 2.6,
  preferredRange: 42,
  weaponDamage: 16,
  fireRate: 1.3,
  projectileSpeed: 120,
};
