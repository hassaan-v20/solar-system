import { WeaponDef } from "./weaponConfig";

// Rate- and heat-limited trigger. The owner calls tick() each frame, checks `ready`,
// fires the bolt itself (via Combat), then calls fired().
export class Weapon {
  heat = 0;
  private cooldown = 0;

  constructor(readonly def: WeaponDef) {}

  tick(dt: number): void {
    this.cooldown = Math.max(0, this.cooldown - dt);
    this.heat = Math.max(0, this.heat - this.def.cooldownRate * dt);
  }

  get ready(): boolean {
    return this.cooldown <= 0 && this.heat + this.def.heatPerShot <= this.def.maxHeat;
  }

  fired(): void {
    this.cooldown = 1 / Math.max(0.01, this.def.fireRate);
    this.heat += this.def.heatPerShot;
  }

  get heatFrac(): number {
    return this.def.maxHeat > 0 ? this.heat / this.def.maxHeat : 0;
  }
}
