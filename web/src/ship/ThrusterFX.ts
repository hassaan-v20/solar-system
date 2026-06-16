import * as THREE from "three";
import { ShipController } from "./ShipController";

// Engine nozzle in ship-object local space. Nose is -Z, so +Z is the tail.
// TARGET_LENGTH=6 → half=3; nozzle sits just past that with a slight downward offset.
const NOZZLE = new THREE.Vector3(0, -0.3, 3.5);

// Chase camera sits at local z≈9.5, so cap trail length well short of that.
const MAX_TRAIL_NORMAL = 4.0;
const MAX_TRAIL_BOOST  = 5.2;

const COL_CRUISE = new THREE.Color(0x55aaff);
const COL_BOOST  = new THREE.Color(0xff7020);

// Two additive cones (inner bright core + outer soft plume) + a nozzle glow
// sprite + a PointLight for scene illumination. All parented to ship.object.
// Trail length lerps smoothly to avoid pops when throttle changes.
export class ThrusterFX {
  private readonly light: THREE.PointLight;
  private readonly glowSprite: THREE.Sprite;
  private readonly innerGroup: THREE.Group;
  private readonly outerGroup: THREE.Group;
  private readonly innerMat: THREE.MeshBasicMaterial;
  private readonly outerMat: THREE.MeshBasicMaterial;
  private readonly spriteMat: THREE.SpriteMaterial;

  private trailLen = 0;
  private glowSz  = 0;

  constructor(private readonly ship: ShipController) {
    this.innerMat = makePlumeMat();
    this.outerMat = makePlumeMat();
    this.spriteMat = makeSpriteMat();

    // Cone geometry: base at y=0 (nozzle), tip at y=1 (rearward).
    // Parent group rotation.x = +π/2 maps local +Y → world +Z (ship's rear).
    // scale.y on the group stretches trail length without widening the radius.
    this.innerGroup = makeConeGroup(0.22, this.innerMat);
    this.outerGroup = makeConeGroup(0.80, this.outerMat);

    for (const g of [this.innerGroup, this.outerGroup]) {
      g.position.copy(NOZZLE);
      g.rotation.x = Math.PI / 2;
      ship.object.add(g);
    }

    this.glowSprite = new THREE.Sprite(this.spriteMat);
    this.glowSprite.position.copy(NOZZLE);
    ship.object.add(this.glowSprite);

    this.light = new THREE.PointLight(COL_CRUISE.getHex(), 0, 28);
    this.light.position.copy(NOZZLE);
    ship.object.add(this.light);
  }

  update(dt: number): void {
    const { ship } = this;

    if (!ship.alive) {
      this.trailLen = this.glowSz = 0;
      this.applyScale(0, 0, 0, COL_CRUISE);
      return;
    }

    const boost = ship.isBoosting;
    const t = ship.throttle; // 0..1 forward thrust

    const wantTrail = t * (boost ? MAX_TRAIL_BOOST : MAX_TRAIL_NORMAL) + (boost ? 1.1 : 0.15);
    const wantGlow  = t * 1.8 + (boost ? 2.8 : 0.15);
    const wantLight = t * 6.0 + (boost ? 7.5 : 0.0);
    const col = boost ? COL_BOOST : COL_CRUISE;

    const a = Math.min(1, dt * 16); // snappy but not instant
    this.trailLen += (wantTrail - this.trailLen) * a;
    this.glowSz   += (wantGlow  - this.glowSz)  * a;

    this.applyScale(this.trailLen, this.glowSz, wantLight, col);
  }

  private applyScale(
    trailLen: number, glowSz: number, lightIntensity: number, col: THREE.Color,
  ): void {
    this.innerGroup.scale.y = trailLen;
    this.outerGroup.scale.y = trailLen * 0.65;

    // Inner: near-white hot core tinted slightly toward the thruster colour.
    this.innerMat.color.set(0xffffff).lerp(col, 0.4);
    // Outer: the colour halo, dimmer.
    this.outerMat.color.copy(col).multiplyScalar(0.55);

    this.spriteMat.color.copy(col).lerp(new THREE.Color(0xffffff), 0.5);
    this.glowSprite.scale.setScalar(glowSz);

    this.light.color.copy(col);
    this.light.intensity = lightIntensity;
  }
}

// ── geometry helpers ──────────────────────────────────────────────────────────

// Cone with base at local y=0 (sits at the group origin = nozzle pos) and tip
// at y=1 (extends rearward when group.rotation.x = +π/2).
//
// CylinderGeometry(radiusTop=0, radiusBottom=r, height=1):
//   default layout: tip (radius=0) at y=+0.5, base at y=-0.5.
//   translate(0, 0.5, 0): tip→y=+1, base→y=0. ✓
//
// Vertex colours fade from white (base, y=0) to black (tip, y=1) so the
// material colour sets the tint and the fade-to-transparent is scale-invariant.
function makeConeGroup(baseRadius: number, mat: THREE.MeshBasicMaterial): THREE.Group {
  const geo = new THREE.CylinderGeometry(0, baseRadius, 1, 10, 6, true);
  geo.translate(0, 0.5, 0);

  const pos = geo.attributes.position as THREE.BufferAttribute;
  const col = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const b = Math.pow(Math.max(0, 1 - pos.getY(i)), 0.7);
    col[i * 3] = col[i * 3 + 1] = col[i * 3 + 2] = b;
  }
  geo.setAttribute("color", new THREE.BufferAttribute(col, 3));

  const g = new THREE.Group();
  g.add(new THREE.Mesh(geo, mat));
  return g;
}

function makePlumeMat(): THREE.MeshBasicMaterial {
  return new THREE.MeshBasicMaterial({
    vertexColors: true,
    blending: THREE.AdditiveBlending,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
}

function makeSpriteMat(): THREE.SpriteMaterial {
  const sz = 64;
  const c = document.createElement("canvas");
  c.width = sz; c.height = sz;
  const ctx = c.getContext("2d")!;
  const g = ctx.createRadialGradient(sz / 2, sz / 2, 0, sz / 2, sz / 2, sz / 2);
  g.addColorStop(0.00, "rgba(255,255,255,1.0)");
  g.addColorStop(0.20, "rgba(255,255,255,0.85)");
  g.addColorStop(0.55, "rgba(255,255,255,0.15)");
  g.addColorStop(1.00, "rgba(255,255,255,0.0)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, sz, sz);
  return new THREE.SpriteMaterial({
    map: new THREE.CanvasTexture(c),
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    transparent: true,
    color: COL_CRUISE.getHex(),
  });
}
