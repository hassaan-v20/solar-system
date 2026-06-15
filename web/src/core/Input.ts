// Keyboard + pointer-lock mouse, mirroring the Godot capture model: click the
// canvas to capture the mouse for aiming; Esc releases it. Mouse motion accumulates
// as a per-frame delta the ship consumes (like Godot's screen_relative).

export class Input {
  private keys = new Set<string>();
  private mdx = 0;
  private mdy = 0;
  locked = false;

  constructor(canvas: HTMLElement, private onLockChange?: (locked: boolean) => void) {
    canvas.addEventListener("click", () => {
      if (!this.locked) canvas.requestPointerLock();
    });
    document.addEventListener("pointerlockchange", () => {
      this.locked = document.pointerLockElement === canvas;
      if (!this.locked) this.keys.clear(); // dropping capture shouldn't leave keys stuck
      this.onLockChange?.(this.locked);
    });
    document.addEventListener("mousemove", (e) => {
      if (!this.locked) return;
      this.mdx += e.movementX;
      this.mdy += e.movementY;
    });
    window.addEventListener("keydown", (e) => {
      this.keys.add(e.code);
      // Stop Space/Ctrl/Tab from scrolling or stealing focus while flying.
      if (this.locked && ["Space", "ControlLeft", "Tab"].includes(e.code)) e.preventDefault();
    });
    window.addEventListener("keyup", (e) => this.keys.delete(e.code));
    window.addEventListener("blur", () => this.keys.clear());
  }

  held(code: string): boolean {
    return this.keys.has(code);
  }

  /** Axis from two keys: positive − negative, in [-1, 1]. */
  axis(negative: string, positive: string): number {
    return (this.held(positive) ? 1 : 0) - (this.held(negative) ? 1 : 0);
  }

  /** Accumulated mouse motion since the last call, then reset to zero. */
  consumeMouse(): { dx: number; dy: number } {
    const d = { dx: this.mdx, dy: this.mdy };
    this.mdx = 0;
    this.mdy = 0;
    return d;
  }
}
