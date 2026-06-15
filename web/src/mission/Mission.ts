import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { ShipController } from "../ship/ShipController";
import { Combat } from "../combat/Combat";
import { Director } from "../combat/Director";
import { Collision } from "../world/Collision";

type State = "approach" | "defend" | "success" | "failed";

const DOCK_RADIUS = 430; // trigger docking on approach, before the solid core
const DEFEND_DURATION = 90;
const STATION_POS = new THREE.Vector3(0, 0, -700);
const STATION_URL = "/assets/models/station/spacestation_7.glb";
const STATION_SIZE = 820; // longest-axis target — a genuinely massive derelict
const STATION_COLLIDER_R = 280; // solid core (< DOCK_RADIUS so you dock before bonking)

// Single-player Ghost Station defend, ported from the Godot CoopRaid flow: fly into
// the derelict station to begin, then hold for DEFEND_DURATION while drone waves
// escalate. Survive = complete; ship destroyed = failed. Drives the wave Director.
export class Mission {
  state: State = "approach";
  objective = "Fly into the derelict station to begin the raid";
  readonly stationPosition = STATION_POS.clone();
  private left = DEFEND_DURATION;

  constructor(scene: THREE.Scene, private ship: ShipController, private combat: Combat, private director: Director, collision: Collision) {
    this.buildStation(scene);
    collision.add(this.stationPosition, STATION_COLLIDER_R); // solid hull core
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

  // The real derelict station GLB, with a glowing core + red beacon as accents so
  // it's findable from afar. Falls back to a primitive hull if the model is missing.
  private buildStation(scene: THREE.Scene): void {
    const g = new THREE.Group();
    g.position.copy(STATION_POS);
    scene.add(g);

    // Findable accents, shown immediately while the (large) model streams in.
    const core = new THREE.Mesh(new THREE.IcosahedronGeometry(18, 1), new THREE.MeshBasicMaterial({ color: 0x66e0ff }));
    g.add(core);
    g.add(new THREE.PointLight(0x66e0ff, 8, 900));
    const beacon = new THREE.Mesh(new THREE.SphereGeometry(7, 8, 8), new THREE.MeshBasicMaterial({ color: 0xff3a2a }));
    beacon.position.set(0, 170, 0);
    g.add(beacon);
    const beaconLight = new THREE.PointLight(0xff3a2a, 5, 900);
    beaconLight.position.set(0, 170, 0);
    g.add(beaconLight);

    new GLTFLoader().load(
      STATION_URL,
      (gltf) => {
        const model = gltf.scene;
        const box = new THREE.Box3().setFromObject(model);
        const size = box.getSize(new THREE.Vector3());
        const center = box.getCenter(new THREE.Vector3());
        const maxDim = Math.max(size.x, size.y, size.z) || 1;
        model.position.sub(center);
        const holder = new THREE.Group();
        holder.scale.setScalar(STATION_SIZE / maxDim);
        holder.add(model);
        g.add(holder);
      },
      undefined,
      () => this.buildFallbackHull(g),
    );
  }

  private buildFallbackHull(g: THREE.Group): void {
    const hull = new THREE.MeshStandardMaterial({ color: 0x39414e, metalness: 0.7, roughness: 0.55 });
    const spine = new THREE.Mesh(new THREE.CylinderGeometry(13, 13, 130, 12), hull);
    spine.rotation.z = Math.PI / 2;
    g.add(spine);
    g.add(new THREE.Mesh(new THREE.IcosahedronGeometry(34, 1), hull));
    for (let i = 0; i < 6; i++) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(16 + Math.random() * 18, 14, 16), hull);
      const ang = (i / 6) * Math.PI * 2;
      m.position.set(Math.cos(ang) * 40, (Math.random() - 0.5) * 30, Math.sin(ang) * 40);
      m.rotation.y = ang;
      g.add(m);
    }
  }
}
