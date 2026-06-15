import * as THREE from "three";

// Builds the sector: lighting, a starfield backdrop, and a scattered asteroid field
// (procedural low-poly rocks for now — the GLB rocks can drop in later). Returns the
// asteroid meshes so collision can use them down the line.
export function createWorld(scene: THREE.Scene): { asteroids: THREE.Mesh[] } {
  const ambient = new THREE.AmbientLight(0x44506e, 1.1);
  scene.add(ambient);

  const key = new THREE.DirectionalLight(0xfff4e8, 2.0);
  key.position.set(-0.5, 0.8, 0.6);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x88aaff, 0.7);
  rim.position.set(0.4, -0.3, -0.8);
  scene.add(rim);

  scene.add(makeStarfield());
  scene.fog = null;

  const asteroids = makeAsteroids(140);
  for (const a of asteroids) scene.add(a);
  return { asteroids };
}

function makeStarfield(count = 3500, radius = 2200): THREE.Points {
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    // Random direction on a sphere shell, far out so it reads as the sky.
    const dir = new THREE.Vector3().randomDirection().multiplyScalar(radius * (0.8 + Math.random() * 0.2));
    positions.set([dir.x, dir.y, dir.z], i * 3);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  const mat = new THREE.PointsMaterial({ color: 0xffffff, size: 2.2, sizeAttenuation: false });
  const pts = new THREE.Points(geo, mat);
  pts.frustumCulled = false;
  return pts;
}

function makeAsteroids(count: number): THREE.Mesh[] {
  const geos = [0, 1].map((d) => new THREE.IcosahedronGeometry(1, d)); // two roughness levels
  const out: THREE.Mesh[] = [];
  for (let i = 0; i < count; i++) {
    const g = geos[Math.random() < 0.5 ? 0 : 1];
    const shade = 0.28 + Math.random() * 0.18;
    const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color(shade, shade * 0.96, shade * 0.9), roughness: 1, flatShading: true });
    const m = new THREE.Mesh(g, mat);
    const r = 2 + Math.random() * 6;
    m.scale.setScalar(r).multiply(new THREE.Vector3(0.8 + Math.random() * 0.4, 0.8 + Math.random() * 0.4, 0.8 + Math.random() * 0.4));
    m.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
    // Shell around the origin so the ship's spawn point stays clear.
    m.position.copy(new THREE.Vector3().randomDirection().multiplyScalar(45 + Math.random() * 240));
    out.push(m);
  }
  return out;
}
