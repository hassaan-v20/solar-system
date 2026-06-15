import * as THREE from "three";
import { Input } from "./core/Input";
import { ChaseCamera } from "./camera/ChaseCamera";
import { createWorld } from "./world/createWorld";
import { createShip } from "./ship/createShip";
import { Hud } from "./ui/Hud";

const app = document.getElementById("app")!;
const readout = document.getElementById("readout")!;
const clickToFly = document.getElementById("click-to-fly")!;

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
app.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x05070d);

const camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.1, 6000);

createWorld(scene);
const ship = createShip(scene);
const chase = new ChaseCamera(camera);
const hud = new Hud(readout);

const input = new Input(renderer.domElement, (locked) => clickToFly.classList.toggle("hidden", locked));

let first = true;
const clock = new THREE.Clock();

function frame(): void {
  const dt = Math.min(clock.getDelta(), 1 / 30); // clamp so a stutter can't fling the ship
  ship.update(dt, input);
  chase.update(dt, ship.object, first);
  hud.update(ship);
  first = false;
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

window.addEventListener("resize", () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});
