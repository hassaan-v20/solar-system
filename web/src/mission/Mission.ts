import * as THREE from "three";
import { ShipController } from "../ship/ShipController";
import { Combat } from "../combat/Combat";
import { Director } from "../combat/Director";

type State = "approach" | "defend" | "success" | "failed";

const DOCK_RADIUS = 130;
const DEFEND_DURATION = 90;
const STATION_POS = new THREE.Vector3(0, 0, -520);

// Single-player Ghost Station defend, ported from the Godot CoopRaid flow: fly into
// the derelict station to begin, then hold for DEFEND_DURATION while drone waves
// escalate. Survive = complete; ship destroyed = failed. Drives the wave Director.
export class Mission {
  state: State = "approach";
  objective = "Fly into the derelict station to begin the raid";
  readonly stationPosition = STATION_POS.clone();
  private left = DEFEND_DURATION;

  constructor(scene: THREE.Scene, private ship: ShipController, private combat: Combat, private director: Director) {
    this.buildStation(scene);
  }

  /** Station waypoint for the HUD while approaching; null once the raid is live. */
  get waypoint(): THREE.Vector3 | null {
    return this.state === "approach" ? this.stationPosition : null;
  }

  update(dt: number): void {
    switch (this.state) {
      case "approach": {
        if (this.ship.position.distanceTo(this.stationPosition) < DOCK_RADIUS) this.startDefend();
        break;
      }
      case "defend": {
        if (!this.ship.alive) {
          this.finish("failed", "RAID FAILED — ship destroyed");
          break;
        }
        this.left = Math.max(0, this.left - dt);
        const s = Math.ceil(this.left);
        this.objective = `DEFEND THE STATION — hold for ${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
        if (this.left <= 0) this.finish("success", "STATION HELD — raid complete!");
        break;
      }
    }
  }

  private startDefend(): void {
    this.state = "defend";
    this.left = DEFEND_DURATION;
    this.director.active = true; // the station "wakes up" — waves begin
  }

  private finish(state: State, text: string): void {
    this.state = state;
    this.objective = text;
    this.director.active = false;
    if (state === "success") this.combat.clearDrones();
  }

  // A derelict station built from primitives (the real GLB is 33 MB — too heavy for
  // the web): dark hull cluster, a glowing data core that blooms, and a red beacon.
  private buildStation(scene: THREE.Scene): void {
    const g = new THREE.Group();
    const hull = new THREE.MeshStandardMaterial({ color: 0x39414e, metalness: 0.7, roughness: 0.55 });

    const spine = new THREE.Mesh(new THREE.CylinderGeometry(13, 13, 130, 12), hull);
    spine.rotation.z = Math.PI / 2;
    g.add(spine);
    g.add(new THREE.Mesh(new THREE.IcosahedronGeometry(34, 1), hull));

    // A few modules clustered around the hub.
    for (let i = 0; i < 6; i++) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(16 + Math.random() * 18, 14, 16), hull);
      const ang = (i / 6) * Math.PI * 2;
      m.position.set(Math.cos(ang) * 40, (Math.random() - 0.5) * 30, Math.sin(ang) * 40);
      m.rotation.y = ang;
      g.add(m);
    }

    // Glowing data core (unlit → blooms) + its light.
    const core = new THREE.Mesh(new THREE.IcosahedronGeometry(9, 1), new THREE.MeshBasicMaterial({ color: 0x66e0ff }));
    g.add(core);
    g.add(new THREE.PointLight(0x66e0ff, 6, 240));

    // Red running beacon so the derelict is findable in the dark.
    const beacon = new THREE.Mesh(new THREE.SphereGeometry(3, 8, 8), new THREE.MeshBasicMaterial({ color: 0xff3a2a }));
    beacon.position.set(0, 42, 0);
    g.add(beacon);
    const beaconLight = new THREE.PointLight(0xff3a2a, 4, 300);
    beaconLight.position.set(0, 42, 0);
    g.add(beaconLight);

    g.position.copy(STATION_POS);
    scene.add(g);
  }
}
