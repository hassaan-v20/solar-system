import { clamp } from "./mathf";

// Unified input: keyboard + mouse (pointer-lock aim) + gamepad, exposed as high-level
// flight intents so the ship controller doesn't care about the source. Call poll()
// once per frame (the Gamepad API is snapshot-based).
//
// Gamepad map (standard layout — Xbox/PS):
//   left stick   X strafe, Y thrust (up = forward)
//   right stick  X yaw, Y pitch (aim)
//   LB / RB      roll left / right
//   LT / RT      brake / boost
//   d-pad up/dn  thrust up / down
//   Y / Triangle toggle flight assist
export class Input {
  private keys = new Set<string>();
  private mdx = 0;
  private mdy = 0;
  locked = false;

  private axes: number[] = [];
  private buttons: number[] = [];
  private assistPrev = false;
  private edgePrev = new Map<number, boolean>();
  private mouseDown = false;

  constructor(canvas: HTMLElement) {
    // Capture the mouse on any click. (The start overlay sits above the canvas and
    // ate canvas clicks, so listen on the document.)
    document.addEventListener("click", () => {
      if (!this.locked) canvas.requestPointerLock();
    });
    document.addEventListener("pointerlockchange", () => {
      this.locked = document.pointerLockElement === canvas;
      if (!this.locked) this.keys.clear(); // releasing capture shouldn't leave keys stuck
    });
    document.addEventListener("mousemove", (e) => {
      if (this.locked) {
        this.mdx += e.movementX;
        this.mdy += e.movementY;
      }
    });
    document.addEventListener("mousedown", (e) => {
      if (e.button === 0) this.mouseDown = true;
    });
    document.addEventListener("mouseup", (e) => {
      if (e.button === 0) this.mouseDown = false;
    });
    window.addEventListener("keydown", (e) => {
      this.keys.add(e.code);
      if (this.locked && ["Space", "ControlLeft", "Tab"].includes(e.code)) e.preventDefault();
    });
    window.addEventListener("keyup", (e) => this.keys.delete(e.code));
    window.addEventListener("blur", () => {
      this.keys.clear();
      this.mouseDown = false;
    });
  }

  poll(): void {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    let gp: Gamepad | null = null;
    for (const p of pads) {
      if (p && p.connected) {
        gp = p;
        break;
      }
    }
    this.axes = gp ? Array.from(gp.axes) : [];
    this.buttons = gp ? gp.buttons.map((b) => b.value) : [];
  }

  // ── intents (keyboard + gamepad, clamped to [-1, 1]) ──────────────────────────
  consumeMouse(): { dx: number; dy: number } {
    const d = { dx: this.mdx, dy: this.mdy };
    this.mdx = 0;
    this.mdy = 0;
    return d;
  }

  /** Right-stick aim contribution: x = yaw (right +), y = pitch (up +). */
  aimStick(): { x: number; y: number } {
    return { x: this.stick(2), y: -this.stick(3) };
  }

  thrust(): number {
    return clamp(this.kbAxis("KeyS", "KeyW") + -this.stick(1), -1, 1); // stick up = forward
  }
  strafe(): number {
    return clamp(this.kbAxis("KeyQ", "KeyE") + this.stick(0), -1, 1);
  }
  lift(): number {
    const pad = (this.btn(12) ? 1 : 0) - (this.btn(13) ? 1 : 0); // d-pad up/down
    return clamp(this.kbAxis("KeyC", "Space") + pad, -1, 1);
  }
  roll(): number {
    const pad = (this.btn(4) ? 1 : 0) - (this.btn(5) ? 1 : 0); // LB/RB
    return clamp(this.kbAxis("KeyD", "KeyA") + pad, -1, 1);
  }
  /** Fire: left mouse button or right trigger. */
  fire(): boolean {
    return this.mouseDown || this.btn(7); // LMB / RT
  }
  /** Momentary boost: Shift held. (L3 latches boost — see boostTogglePressed.) */
  boostHeld(): boolean {
    return this.held("ShiftLeft") || this.held("ShiftRight");
  }
  /** L3 press toggles sustained (latched) boost. */
  boostTogglePressed(): boolean {
    return this.gpEdge(10); // L3 (left-stick click)
  }
  /** L2 press cancels latched boost (and brakes). */
  boostCancelPressed(): boolean {
    return this.gpEdge(6); // L2 / LT
  }
  brake(): boolean {
    return this.held("ControlLeft") || this.held("ControlRight") || this.btn(6); // LT
  }

  /** Edge-triggered flight-assist toggle: Z key or gamepad Y/Triangle. */
  assistTogglePressed(): boolean {
    const down = this.held("KeyZ") || this.btn(3);
    const pressed = down && !this.assistPrev;
    this.assistPrev = down;
    return pressed;
  }

  /** True if the player is driving a gamepad (used to dismiss the start overlay). */
  gamepadActive(): boolean {
    return this.buttons.some((v) => v > 0.5) || this.axes.some((v) => Math.abs(v) > 0.5);
  }

  // ── raw helpers ───────────────────────────────────────────────────────────────
  private held(code: string): boolean {
    return this.keys.has(code);
  }
  private kbAxis(negative: string, positive: string): number {
    return (this.held(positive) ? 1 : 0) - (this.held(negative) ? 1 : 0);
  }
  private stick(i: number, deadzone = 0.16): number {
    const v = this.axes[i] ?? 0;
    if (Math.abs(v) < deadzone) return 0;
    return (v - Math.sign(v) * deadzone) / (1 - deadzone); // rescale past the deadzone
  }
  private btn(i: number, threshold = 0.4): boolean {
    return (this.buttons[i] ?? 0) > threshold;
  }
  /** Rising edge for a gamepad button (call at most once per frame per index). */
  private gpEdge(i: number): boolean {
    const down = this.btn(i);
    const pressed = down && !(this.edgePrev.get(i) ?? false);
    this.edgePrev.set(i, down);
    return pressed;
  }
}
