import * as THREE from "three";

// Smallest positive time at which a projectile of muzzle speed `bs` intercepts a
// target at relative position `p` closing at relative velocity `vrel`. 0 = no
// solution. Shared by drone aiming and the HUD lead pip.
export function interceptTime(p: THREE.Vector3, vrel: THREE.Vector3, bs: number): number {
  const a = bs * bs - vrel.lengthSq();
  const pv = p.dot(vrel);
  if (Math.abs(a) < 0.0001) return Math.abs(pv) > 0.0001 ? -p.lengthSq() / (2 * pv) : 0;
  const disc = pv * pv + a * p.lengthSq();
  if (disc < 0) return 0;
  const root = Math.sqrt(disc);
  let best = -1;
  for (const tt of [(pv + root) / a, (pv - root) / a]) {
    if (tt > 0 && (best < 0 || tt < best)) best = tt;
  }
  return best;
}
