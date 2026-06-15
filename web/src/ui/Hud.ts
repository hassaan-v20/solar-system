import { ShipController } from "../ship/ShipController";

export interface HudStats {
  drones: number;
  threat: number; // 0..1
  weaponHeat: number; // 0..1
  objective: string;
}

// Flight + combat text readout (top-left) + the mission objective banner (top-center).
// Projected markers, health bars, and indicators live in HudOverlay (2D canvas).
export class Hud {
  constructor(private el: HTMLElement, private objectiveEl: HTMLElement) {}

  update(ship: ShipController, stats: HudStats): void {
    this.objectiveEl.textContent = stats.objective;
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
