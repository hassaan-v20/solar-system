import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { ShipController } from "./ShipController";

const MODEL_URL = "/assets/models/ship/spaceship_ezno.glb";
const TARGET_LENGTH = 6; // world units along the longest axis

// Builds the ship controller with an immediate placeholder hull, then swaps in the
// real GLB once it loads (so the loop never blocks). The visual model is recentered,
// scaled, and yawed 180° so its nose points along the ship's forward (-Z).
export function createShip(scene: THREE.Scene): ShipController {
  const ship = new ShipController();
  scene.add(ship.object);

  const placeholder = makePlaceholder();
  ship.object.add(placeholder);

  new GLTFLoader().load(
    MODEL_URL,
    (gltf) => {
      const model = gltf.scene;
      const box = new THREE.Box3().setFromObject(model);
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z) || 1;
      model.position.sub(center); // recenter on origin
      const holder = new THREE.Group();
      holder.scale.setScalar(TARGET_LENGTH / maxDim);
      holder.rotation.y = Math.PI; // GLB nose is +Z; face it -Z
      holder.add(model);
      ship.object.remove(placeholder);
      ship.object.add(holder);
    },
    undefined,
    () => {
      // Keep flying with the placeholder if the asset is missing.
      console.warn(`[stellar] ship model not found at ${MODEL_URL}; using placeholder`);
    },
  );

  return ship;
}

function makePlaceholder(): THREE.Object3D {
  const mat = new THREE.MeshStandardMaterial({ color: 0x8a97a8, metalness: 0.3, roughness: 0.5 });
  const cone = new THREE.Mesh(new THREE.ConeGeometry(1.1, 4, 12), mat);
  cone.rotation.x = -Math.PI / 2; // point the cone down -Z
  return cone;
}
