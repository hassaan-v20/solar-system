// Small scalar/vector helpers mirroring the bits of Godot's API the flight model used.

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

/** Move `current` toward `target` by at most `maxDelta` (Godot's move_toward). */
export function moveToward(current: number, target: number, maxDelta: number): number {
  const d = target - current;
  if (Math.abs(d) <= maxDelta) return target;
  return current + Math.sign(d) * maxDelta;
}

/** Frame-rate independent smoothing factor for an exponential approach (lerp t). */
export function damp(rate: number, dt: number): number {
  return 1 - Math.exp(-rate * dt);
}
