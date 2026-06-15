// Flight tuning — ported from the Godot wayfarer.tres ShipDef so the feel carries
// over 1:1. All accelerations are m/s², rates are rad/s. Nothing magic lives in the
// controller; tune the feel here.
export interface ShipConfig {
  maxSpeed: number;
  boostSpeed: number;
  acceleration: number;
  reverseAccel: number;
  strafeAccel: number;
  boostAccelMult: number;
  assistResponse: number;
  assistDecel: number;
  brakeDecel: number;
  turnRate: number;
  rollRate: number;
  turnAccel: number;
  rotAssist: number;
  mouseSens: number;
  flightAssistDefault: boolean;
  boostCapacity: number;
  boostDrain: number;
  boostRegen: number;
  boostRelockFrac: number;
}

export const WAYFARER: ShipConfig = {
  maxSpeed: 42,
  boostSpeed: 72,
  acceleration: 32,
  reverseAccel: 16,
  strafeAccel: 20,
  boostAccelMult: 1.8,
  assistResponse: 3,
  assistDecel: 34,
  brakeDecel: 60,
  turnRate: 2.4,
  rollRate: 2.8,
  turnAccel: 7,
  rotAssist: 5,
  mouseSens: 0.05,
  flightAssistDefault: true,
  boostCapacity: 3,
  boostDrain: 1,
  boostRegen: 0.6,
  boostRelockFrac: 0.3,
};
