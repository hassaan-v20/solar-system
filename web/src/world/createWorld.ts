import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { Collision } from "./Collision";

// The sector: an equirectangular Milky Way skybox (also used as a subtle IBL env),
// a real GLB asteroid field, and a distant planet for depth — porting the Godot
// raid environment. Bloom/tonemapping live in the post-processing chain (main.ts).
// Everything loads async and populates the scene as it arrives; nothing blocks.

const PANORAMA_URL = "/assets/textures/8k_stars_milky_way.jpg";
const ASTEROID_URL = "/assets/models/asteroids/asteroids_andromeda.glb";
const PLANET_URL = "/assets/models/planets/planet_phoenix_1k.glb";
const ASTEROID_COUNT = 450;
const STATION_CENTER = new THREE.Vector3(0, 0, -700); // keep rocks out of the station

// A dense field spread along the whole spawn→station corridor (and around the
// station as cover), so you actually fly through rocks during play — not a sparse
// shell at the origin that you never touch. Clears the spawn point and the station.
function asteroidPos(): THREE.Vector3 {
  const p = new THREE.Vector3();
  for (let t = 0; t < 10; t++) {
    p.set((Math.random() * 2 - 1) * 280, (Math.random() * 2 - 1) * 200, 60 - Math.random() * 1010);
    if (p.length() < 65) continue; // keep the spawn point clear
    if (p.distanceTo(STATION_CENTER) < 380) continue; // keep the station interior clear
    return p;
  }
  return p.set(260, 180, -350);
}

export function createWorld(scene: THREE.Scene, renderer: THREE.WebGLRenderer, collision: Collision): void {
  // Layered lighting: a cool hemisphere fill (a gradient, not flat ambient), a warm
  // key, and a cool rim — plus a synthesized soft IBL environment for ambient +
  // reflections. The visible Milky Way photo is too dark to light the scene, so we
  // light it the way Godot's HDR sky did rather than from the background.
  scene.add(new THREE.HemisphereLight(0x6b82a8, 0x10131c, 0.55));
  const key = new THREE.DirectionalLight(0xfff2e0, 2.0);
  key.position.set(-0.5, 0.8, 0.6);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x88aaff, 0.6);
  rim.position.set(0.4, -0.3, -0.8);
  scene.add(rim);

  makeEnvironment(scene, renderer);
  loadSky(scene);
  loadAsteroids(scene, collision);
  loadPlanet(scene);
}

// A soft cool gradient used only as the IBL environment (not visible) so PBR
// materials get realistic ambient + subtle reflections. Built in code, no asset.
function makeEnvironment(scene: THREE.Scene, renderer: THREE.WebGLRenderer): void {
  const w = 512;
  const h = 256;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const ctx = c.getContext("2d")!;
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0.0, "#0a0e18"); // zenith — dark
  g.addColorStop(0.5, "#243352"); // horizon — cool fill
  g.addColorStop(1.0, "#0b0c12"); // nadir — dark
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
  const tex = new THREE.CanvasTexture(c);
  tex.mapping = THREE.EquirectangularReflectionMapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromEquirectangular(tex).texture;
  pmrem.dispose();
  tex.dispose();
}

function loadSky(scene: THREE.Scene): void {
  new THREE.TextureLoader().load(PANORAMA_URL, (tex) => {
    tex.mapping = THREE.EquirectangularReflectionMapping;
    tex.colorSpace = THREE.SRGBColorSpace;
    scene.background = tex; // visible background only; lighting comes from makeEnvironment
  });
}

function loadAsteroids(scene: THREE.Scene, collision: Collision): void {
  new GLTFLoader().load(
    ASTEROID_URL,
    (gltf) => {
      const sources: THREE.Mesh[] = [];
      gltf.scene.traverse((o) => {
        const m = o as THREE.Mesh;
        if (m.isMesh && m.geometry) sources.push(m);
      });
      if (sources.length === 0) {
        fallbackAsteroids(scene, collision);
        return;
      }
      for (let i = 0; i < ASTEROID_COUNT; i++) {
        const src = sources[Math.floor(Math.random() * sources.length)];
        src.geometry.computeBoundingSphere();
        const baseR = src.geometry.boundingSphere?.radius || 1;
        const target = 3 + Math.random() * 6; // gameplay radius, independent of model size
        const m = new THREE.Mesh(src.geometry, src.material); // share geometry/material across instances
        m.scale.setScalar(target / baseR);
        m.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
        m.position.copy(asteroidPos());
        scene.add(m);
        collision.add(m.position.clone(), target * 0.85);
      }
    },
    undefined,
    () => fallbackAsteroids(scene, collision),
  );
}

function loadPlanet(scene: THREE.Scene): void {
  new GLTFLoader().load(PLANET_URL, (gltf) => {
    const planet = gltf.scene;
    const box = new THREE.Box3().setFromObject(planet);
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z) || 1;
    planet.scale.setScalar(1400 / maxDim); // ~700u radius
    planet.position.set(-1000, 520, -2550); // off to one side, far beyond the field
    scene.add(planet);
  });
}

// Procedural rocks if the GLB is missing, so the field is never empty.
function fallbackAsteroids(scene: THREE.Scene, collision: Collision): void {
  const geos = [0, 1].map((d) => new THREE.IcosahedronGeometry(1, d));
  for (let i = 0; i < ASTEROID_COUNT; i++) {
    const shade = 0.28 + Math.random() * 0.18;
    const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color(shade, shade * 0.96, shade * 0.9), roughness: 1, flatShading: true });
    const r = 3 + Math.random() * 6;
    const m = new THREE.Mesh(geos[Math.random() < 0.5 ? 0 : 1], mat);
    m.scale.setScalar(r);
    m.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
    m.position.copy(asteroidPos());
    scene.add(m);
    collision.add(m.position.clone(), r * 0.85);
  }
}
