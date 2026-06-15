import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

// The sector: an equirectangular Milky Way skybox (also used as a subtle IBL env),
// a real GLB asteroid field, and a distant planet for depth — porting the Godot
// raid environment. Bloom/tonemapping live in the post-processing chain (main.ts).
// Everything loads async and populates the scene as it arrives; nothing blocks.

const PANORAMA_URL = "/assets/textures/8k_stars_milky_way.jpg";
const ASTEROID_URL = "/assets/models/asteroids/asteroids_andromeda.glb";
const PLANET_URL = "/assets/models/planets/planet_phoenix_1k.glb";
const ASTEROID_COUNT = 140;

export function createWorld(scene: THREE.Scene, renderer: THREE.WebGLRenderer): { nebula: THREE.Object3D } {
  // Warm key + cool ambient/rim, matching the Godot raid lighting.
  scene.add(new THREE.AmbientLight(0x44506e, 0.65));
  const key = new THREE.DirectionalLight(0xfff4e8, 2.4);
  key.position.set(-0.5, 0.8, 0.6);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x88aaff, 0.8);
  rim.position.set(0.4, -0.3, -0.8);
  scene.add(rim);

  loadSky(scene, renderer);
  loadAsteroids(scene);
  loadPlanet(scene);

  // Colored nebula clouds layered over the starfield for the dramatic Godot look.
  // Caller recenters this on the camera each frame so it reads as "at infinity".
  const nebula = makeNebula();
  scene.add(nebula);
  return { nebula };
}

// Soft radial-gradient sprite texture (generated, no asset) used for nebula clouds.
function cloudTexture(): THREE.Texture {
  const s = 128;
  const c = document.createElement("canvas");
  c.width = c.height = s;
  const ctx = c.getContext("2d")!;
  const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  g.addColorStop(0, "rgba(255,255,255,0.85)");
  g.addColorStop(0.45, "rgba(255,255,255,0.25)");
  g.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, s, s);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function makeNebula(): THREE.Group {
  const tex = cloudTexture();
  const palette = [0x4a1c6e, 0x1c3a7e, 0x14606e, 0x5e1c52, 0x2a1c6e, 0x1c5e5a];
  const group = new THREE.Group();
  const radius = 2600;
  for (let i = 0; i < 9; i++) {
    const mat = new THREE.SpriteMaterial({
      map: tex,
      color: palette[i % palette.length],
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      transparent: true,
      opacity: 0.38,
    });
    const sprite = new THREE.Sprite(mat);
    sprite.position.copy(new THREE.Vector3().randomDirection().multiplyScalar(radius));
    const scale = 1500 + Math.random() * 1800;
    sprite.scale.set(scale, scale, 1);
    group.add(sprite);
  }
  return group;
}

function loadSky(scene: THREE.Scene, renderer: THREE.WebGLRenderer): void {
  new THREE.TextureLoader().load(PANORAMA_URL, (tex) => {
    tex.mapping = THREE.EquirectangularReflectionMapping;
    tex.colorSpace = THREE.SRGBColorSpace;
    scene.background = tex;
    // Prefilter once into an environment map so the metallic hull picks up subtle
    // reflections from the starfield.
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromEquirectangular(tex).texture;
    pmrem.dispose();
  });
}

function loadAsteroids(scene: THREE.Scene): void {
  new GLTFLoader().load(
    ASTEROID_URL,
    (gltf) => {
      const sources: THREE.Mesh[] = [];
      gltf.scene.traverse((o) => {
        const m = o as THREE.Mesh;
        if (m.isMesh && m.geometry) sources.push(m);
      });
      if (sources.length === 0) {
        fallbackAsteroids(scene);
        return;
      }
      for (let i = 0; i < ASTEROID_COUNT; i++) {
        const src = sources[Math.floor(Math.random() * sources.length)];
        src.geometry.computeBoundingSphere();
        const baseR = src.geometry.boundingSphere?.radius || 1;
        const target = 2 + Math.random() * 6; // gameplay radius, independent of model size
        const m = new THREE.Mesh(src.geometry, src.material); // share geometry/material across instances
        m.scale.setScalar(target / baseR);
        m.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
        // Shell around the origin so the spawn point stays clear.
        m.position.copy(new THREE.Vector3().randomDirection().multiplyScalar(45 + Math.random() * 240));
        scene.add(m);
      }
    },
    undefined,
    () => fallbackAsteroids(scene),
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
function fallbackAsteroids(scene: THREE.Scene): void {
  const geos = [0, 1].map((d) => new THREE.IcosahedronGeometry(1, d));
  for (let i = 0; i < ASTEROID_COUNT; i++) {
    const shade = 0.28 + Math.random() * 0.18;
    const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color(shade, shade * 0.96, shade * 0.9), roughness: 1, flatShading: true });
    const m = new THREE.Mesh(geos[Math.random() < 0.5 ? 0 : 1], mat);
    m.scale.setScalar(2 + Math.random() * 6);
    m.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
    m.position.copy(new THREE.Vector3().randomDirection().multiplyScalar(45 + Math.random() * 240));
    scene.add(m);
  }
}
