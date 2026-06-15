import { ShipController } from "../ship/ShipController";

export interface HudStats {
  drones: number;
  threat: number; // 0..1
  weaponHeat: number; // 0..1
}

// Flight + combat readout (top-left), mirroring the Godot HUD's text panel. Floating
// health bars / markers / indicators come back with the full HUD pass.
export class Hud {
  constructor(private el: HTMLElement) {}

  update(ship: ShipController, stats: HudStats): void {
    const boostPct = Math.round((ship.boostEnergy / ship.cfg.boostCapacity) * 100);
    const boost = ship.boostLocked ? "RECHARGING" : ship.isBoosting ? "ENGAGED" : `${boostPct}%`;
    this.el.textContent =
      `HULL    ${Math.round(ship.hull)} / ${ship.cfg.hullMax}\n` +
      `SHIELD  ${Math.round(ship.shield)} / ${ship.cfg.shieldMax}\n` +
      `SPEED   ${Math.round(ship.speed)} m/s\n` +
      `BOOST   ${boost}\n` +
      `ASSIST  ${ship.flightAssist ? "on" : "OFF — NEWTONIAN"}\n` +
      `HEAT    ${Math.round(stats.weaponHeat * 100)}%\n` +
      `DRONES  ${stats.drones}\n` +
      `THREAT  ${Math.round(stats.threat * 100)}%` +
      (ship.alive ? "" : "\n\n*** SHIP DESTROYED ***");
  }
}
