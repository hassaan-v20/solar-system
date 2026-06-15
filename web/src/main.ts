import * as THREE from "three";
import { Input } from "./core/Input";
import { ChaseCamera } from "./camera/ChaseCamera";
import { createWorld } from "./world/createWorld";
import { createShip } from "./ship/createShip";
import { Hud } from "./ui/Hud";
import { HudOverlay } from "./ui/HudOverlay";
import { Combat } from "./combat/Combat";
import { Director } from "./combat/Director";
import { Mission } from "./mission/Mission";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";
import { ShaderPass } from "three/examples/jsm/postprocessing/ShaderPass.js";

const app = document.getElementById("app")!;
const readout = document.getElementById("readout")!;
const objectiveEl = document.getElementById("objective")!;
const clickToFly = document.getElementById("click-to-fly")!;
const fullscreenBtn = document.getElementById("fullscreen-btn")!;

function toggleFullscreen(): void {
  if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
  else document.documentElement.requestFullscreen().catch(() => {});
}
// stopPropagation so the button click doesn't also trigger the canvas pointer-lock.
fullscreenBtn.addEventListener("click", (e) => {
  e.stopPropagation();
  toggleFullscreen();
});
window.addEventListener("keydown", (e) => {
  if (e.code === "KeyF") toggleFullscreen();
});

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2; // a touch punchier, like the Godot grade
app.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x05070d);

const camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.1, 6000);

// Post-processing: soft/wide bloom (engine glow + bright stars/nebula), tonemap +
// sRGB output, then a contrast/saturation grade — porting the Godot glow + grade.
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 0.85, 0.8, 0.78);
composer.addPass(bloom);
composer.addPass(new OutputPass());
composer.addPass(
  new ShaderPass({
    uniforms: { tDiffuse: { value: null }, contrast: { value: 1.06 }, saturation: { value: 1.22 } },
    vertexShader: "varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
    fragmentShader: `
      uniform sampler2D tDiffuse; uniform float contrast; uniform float saturation; varying vec2 vUv;
      void main() {
        vec4 c = texture2D(tDiffuse, vUv);
        vec3 col = (c.rgb - 0.5) * contrast + 0.5;
        float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
        col = mix(vec3(l), col, saturation);
        gl_FragColor = vec4(clamp(col, 0.0, 1.0), c.a);
      }`,
  }),
);

const world = createWorld(scene, renderer);
const ship = createShip(scene);
const chase = new ChaseCamera(camera);
const hud = new Hud(readout, objectiveEl);
const hudOverlay = new HudOverlay(app, camera);
const combat = new Combat(scene, ship);
const director = new Director(combat, ship);
const mission = new Mission(scene, ship, combat, director);

const input = new Input(renderer.domElement);

let first = true;
let started = false;
const clock = new THREE.Clock();

function frame(): void {
  const dt = Math.min(clock.getDelta(), 1 / 30); // clamp so a stutter can't fling the ship
  input.poll(); // gamepad is snapshot-based — refresh each frame
  if (!started && (input.locked || input.gamepadActive())) {
    started = true; // dismiss the start overlay on first mouse-capture or gamepad input
    clickToFly.classList.add("hidden");
  }
  world.nebula.position.copy(camera.position); // keep the nebula "at infinity" (no parallax)
  ship.update(dt, input);
  combat.update(dt, input.fire());
  director.update(dt);
  mission.update(dt);
  chase.update(dt, ship.object, first);
  hud.update(ship, {
    drones: combat.drones.length,
    threat: director.heat,
    weaponHeat: combat.playerWeapon.heatFrac,
    objective: mission.objective,
  });
  const wp = mission.waypoint;
  hudOverlay.waypoint = wp ? { position: wp, color: "#5cff8c", label: "DOCK" } : null;
  first = false;
  composer.render();
  hudOverlay.draw(ship, combat); // after the 3D render, so camera matrices are current
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

window.addEventListener("resize", () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  composer.setSize(window.innerWidth, window.innerHeight);
});
