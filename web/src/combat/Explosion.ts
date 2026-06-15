import * as THREE from "three";

// A quick additive glow burst that expands and fades, then removes itself. Bloom in
// the post chain makes it pop. Combat owns the list and calls update()/dispose().
export class Explosion {
  private mesh: THREE.Mesh;
  private mat: THREE.MeshBasicMaterial;
  private age = 0;
  dead = false;

  private static geo = new THREE.SphereGeometry(1, 12, 12);

  constructor(private scene: THREE.Scene, pos: THREE.Vector3, private size: number, color: number, private life = 0.45) {
    this.mat = new THREE.MeshBasicMaterial({
      color,
      transparent: true,
      opacity: 1,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });
    this.mesh = new THREE.Mesh(Explosion.geo, this.mat);
    this.mesh.position.copy(pos);
    this.scene.add(this.mesh);
  }

  update(dt: number): void {
    this.age += dt;
    const t = this.age / this.life;
    if (t >= 1) {
      this.dead = true;
      return;
    }
    this.mesh.scale.setScalar(this.size * (0.3 + t * 1.2));
    this.mat.opacity = 1 - t;
  }

  dispose(): void {
    this.scene.remove(this.mesh);
    this.mat.dispose();
  }
}
