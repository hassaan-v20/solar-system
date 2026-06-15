// Weapon tuning. Heat rises per shot and bleeds off over time; firing is blocked
// while overheated or on cooldown. Drones pass maxHeat huge so they never overheat.
export interface WeaponDef {
  damage: number;
  fireRate: number; // shots per second
  projectileSpeed: number; // m/s
  range: number; // max bolt travel before it despawns
  boltColor: number;
  maxHeat: number;
  heatPerShot: number;
  cooldownRate: number; // heat bled per second
}

export const LASER_MK1: WeaponDef = {
  damage: 34,
  fireRate: 6,
  projectileSpeed: 240,
  range: 700,
  boltColor: 0x66e0ff,
  maxHeat: 1,
  heatPerShot: 0.07,
  cooldownRate: 0.55,
};
