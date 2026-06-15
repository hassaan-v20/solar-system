import { ShipController } from "../ship/ShipController";

// Minimal flight readout (top-left), mirroring the Godot HUD's text panel. Full HUD
// (markers, health bars, indicators) comes back once combat does.
export class Hud {
  constructor(private el: HTMLElement) {}

  update(ship: ShipController): void {
    const boostPct = Math.round((ship.boostEnergy / ship.cfg.boostCapacity) * 100);
    const boost = ship.boostLocked ? "RECHARGING" : ship.isBoosting ? "ENGAGED" : `${boostPct}%`;
    this.el.textContent =
      `SPEED   ${Math.round(ship.speed)} m/s\n` +
      `BOOST   ${boost}\n` +
      `ASSIST  ${ship.flightAssist ? "on" : "OFF — NEWTONIAN"}`;
  }
}
