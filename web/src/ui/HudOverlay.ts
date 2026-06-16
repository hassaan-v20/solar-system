import * as THREE from "three";
import { ShipController } from "../ship/ShipController";
import { Combat } from "../combat/Combat";
import { Drone } from "../enemies/Drone";
import { interceptTime } from "../combat/ballistics";
import { settings } from "../core/Settings";

export interface Waypoint {
  position: THREE.Vector3;
  color: string;
  label: string;
}

const ENEMY = "#ff5a40";
const MARGIN = 56;

// 2D-canvas HUD layer: projected flight markers (crosshair / velocity / lead pip),
// floating drone health bars, off-screen enemy arrows + on-screen reticles, a mission
// waypoint, and the player's shield/hull/boost bars. Ported from the Godot ship_hud +
// target_indicators + world/local health bars. Drawn after the 3D render each frame.
export class HudOverlay {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private w = 0;
  private h = 0;
  waypoint: Waypoint | null = null;

  private _v = new THREE.Vector3();
  private _ndc = new THREE.Vector3();
  private _fwd = new THREE.Vector3();

  constructor(parent: HTMLElement, private camera: THREE.PerspectiveCamera) {
    this.canvas = document.createElement("canvas");
    this.canvas.style.cssText = "position:fixed;inset:0;pointer-events:none;";
    parent.appendChild(this.canvas);
    this.ctx = this.canvas.getContext("2d")!;
    this.resize();
    window.addEventListener("resize", () => this.resize());
  }

  private resize(): void {
    const dpr = Math.min(window.devicePixelRatio, 2);
    this.w = window.innerWidth;
    this.h = window.innerHeight;
    this.canvas.width = this.w * dpr;
    this.canvas.height = this.h * dpr;
    this.canvas.style.width = `${this.w}px`;
    this.canvas.style.height = `${this.h}px`;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  draw(ship: ShipController, combat: Combat): void {
    this.ctx.clearRect(0, 0, this.w, this.h);
    if (settings.showCrosshair) this.drawCrosshair();
    if (settings.showMarkers) this.drawMarkers(ship, combat);
    if (settings.showDroneBars) this.drawDroneBars(combat);
    if (settings.showEnemyIndicators) this.drawEnemyIndicators(combat);
    if (this.waypoint) this.drawWaypoint(this.waypoint);
    if (settings.showPlayerBars) this.drawPlayerBars(ship);
  }

  // ── projection: world → screen pixels (+ whether it's behind the camera) ────────
  private project(world: THREE.Vector3): { x: number; y: number; behind: boolean } {
    const cs = this._v.copy(world).applyMatrix4(this.camera.matrixWorldInverse);
    const ndc = this._ndc.copy(world).project(this.camera);
    return { x: (ndc.x * 0.5 + 0.5) * this.w, y: (-ndc.y * 0.5 + 0.5) * this.h, behind: cs.z >= 0 };
  }

  // Fixed reticle at screen center — your bolts fire along the nose, which sits at
  // center in the chase cam; projecting the nose point instead made it swim.
  private drawCrosshair(): void {
    const ctx = this.ctx;
    const x = this.w / 2;
    const y = this.h / 2;
    ctx.strokeStyle = "rgba(255,255,255,0.8)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.moveTo(x - 2, y);
    ctx.lineTo(x + 2, y);
    ctx.moveTo(x, y - 2);
    ctx.lineTo(x, y + 2);
    ctx.stroke();
  }

  // ── flight markers ──────────────────────────────────────────────────────────────
  private drawMarkers(ship: ShipController, combat: Combat): void {
    const origin = ship.position;
    const v = ship.velocity;
    if (v.length() > 1.5) {
      const vn = v.clone().normalize();
      this.marker(this._v.copy(origin).addScaledVector(vn, 250), "pro", "#66ff99");
      this.marker(this._v.copy(origin).addScaledVector(vn, -250), "retro", "#7fafe0");
    }
    const lead = this.leadPoint(ship, combat);
    if (lead) this.marker(lead, "lead", "#ff8a4d");
  }

  private marker(world: THREE.Vector3, kind: string, color: string): void {
    const p = this.project(world);
    if (p.behind) return;
    const ctx = this.ctx;
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    if (kind === "cross") {
      ctx.moveTo(p.x - 6, p.y); ctx.lineTo(p.x + 6, p.y);
      ctx.moveTo(p.x, p.y - 6); ctx.lineTo(p.x, p.y + 6);
      ctx.stroke();
    } else if (kind === "pro") {
      ctx.arc(p.x, p.y, 5, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(p.x, p.y - 9); ctx.lineTo(p.x, p.y - 5);
      ctx.moveTo(p.x - 9, p.y); ctx.lineTo(p.x - 5, p.y);
      ctx.moveTo(p.x + 5, p.y); ctx.lineTo(p.x + 9, p.y);
      ctx.stroke();
    } else if (kind === "retro") {
      ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
      ctx.moveTo(p.x - 4, p.y - 4); ctx.lineTo(p.x + 4, p.y + 4);
      ctx.moveTo(p.x + 4, p.y - 4); ctx.lineTo(p.x - 4, p.y + 4);
      ctx.stroke();
    } else if (kind === "lead") {
      ctx.strokeRect(p.x - 7, p.y - 7, 14, 14);
    }
  }

  // Nearest drone ahead and in range, with bolt-lead solved — where to aim to hit it.
  private leadPoint(ship: ShipController, combat: Combat): THREE.Vector3 | null {
    const def = combat.playerWeapon.def;
    const bs = Math.max(1, def.projectileSpeed);
    const origin = ship.position;
    this._fwd.set(0, 0, -1).applyQuaternion(ship.object.quaternion);
    let best: Drone | null = null;
    let bestD = def.range;
    for (const e of combat.drones) {
      if (!e.alive) continue;
      const to = e.position.clone().sub(origin);
      const d = to.length();
      if (d < 0.001 || d > def.range || this._fwd.dot(to.clone().divideScalar(d)) < 0.3) continue;
      if (d < bestD) { bestD = d; best = e; }
    }
    if (!best) return null;
    const p = best.position.clone().sub(origin);
    const vrel = best.velocity.clone().sub(ship.velocity);
    const t = interceptTime(p, vrel, bs);
    if (t <= 0) return null;
    const dir = p.add(vrel.multiplyScalar(t)).divideScalar(bs * t);
    if (dir.length() < 0.001) return null;
    return origin.clone().addScaledVector(dir.normalize(), bestD);
  }

  // ── drone health bars + indicators ──────────────────────────────────────────────
  private drawDroneBars(combat: Combat): void {
    const ctx = this.ctx;
    for (const d of combat.drones) {
      if (!d.alive) continue;
      const p = this.project(d.position);
      if (p.behind || p.x < 0 || p.x > this.w || p.y < 0 || p.y > this.h) continue;
      const f = d.healthFraction();
      const bw = 34;
      const x = p.x - bw / 2;
      const y = p.y - 24;
      ctx.fillStyle = "rgba(0,0,0,0.55)";
      ctx.fillRect(x, y, bw, 4);
      ctx.fillStyle = ENEMY;
      ctx.fillRect(x, y, bw * f, 4);
    }
  }

  private drawEnemyIndicators(combat: Combat): void {
    for (const d of combat.drones) {
      if (!d.alive) continue;
      const p = this.project(d.position);
      const onscreen = !p.behind && p.x >= MARGIN && p.x <= this.w - MARGIN && p.y >= MARGIN && p.y <= this.h - MARGIN;
      if (onscreen) this.reticle(p.x, p.y, ENEMY);
      else this.edgeArrow(p.x, p.y, p.behind, ENEMY);
    }
  }

  private drawWaypoint(wp: Waypoint): void {
    const p = this.project(wp.position);
    const onscreen = !p.behind && p.x >= MARGIN && p.x <= this.w - MARGIN && p.y >= MARGIN && p.y <= this.h - MARGIN;
    const ctx = this.ctx;
    ctx.fillStyle = wp.color;
    ctx.font = "12px ui-monospace, monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    if (onscreen) {
      this.reticle(p.x, p.y, wp.color);
      ctx.fillText(wp.label, p.x, p.y - 16);
    } else {
      const e = this.edgeArrow(p.x, p.y, p.behind, wp.color);
      if (e) ctx.fillText(wp.label, e.x, e.y - 16);
    }
  }

  // Returns the clamped edge point it drew at (for labelling), or null.
  private edgeArrow(px: number, py: number, behind: boolean, color: string): { x: number; y: number } | null {
    const cx = this.w / 2;
    const cy = this.h / 2;
    let sx = px;
    let sy = py;
    if (behind) { sx = cx - (px - cx); sy = cy - (py - cy); }
    let dx = sx - cx;
    let dy = sy - cy;
    const len = Math.hypot(dx, dy);
    if (len < 0.001) return null;
    dx /= len; dy /= len;
    const halfW = this.w / 2 - MARGIN;
    const halfH = this.h / 2 - MARGIN;
    const s = Math.min(Math.abs(dx) > 1e-4 ? halfW / Math.abs(dx) : Infinity, Math.abs(dy) > 1e-4 ? halfH / Math.abs(dy) : Infinity);
    const ex = cx + dx * s;
    const ey = cy + dy * s;
    const ctx = this.ctx;
    const a = Math.atan2(dy, dx);
    ctx.save();
    ctx.translate(ex, ey);
    ctx.rotate(a);
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(11, 0); ctx.lineTo(-8, 8); ctx.lineTo(-8, -8);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
    return { x: ex, y: ey };
  }

  private reticle(x: number, y: number, color: string): void {
    const ctx = this.ctx;
    const r = 11;
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(x, y - r); ctx.lineTo(x + r, y); ctx.lineTo(x, y + r); ctx.lineTo(x - r, y);
    ctx.closePath();
    ctx.stroke();
  }

  // ── bottom-left player bars ───────────────────────────────────────────────────
  private drawPlayerBars(ship: ShipController): void {
    const barX = 92;
    const w = 240;
    const h = 14;
    const gap = 5;
    let y = this.h - 118;
    this.bar(barX, y, w, h, ship.shield / ship.cfg.shieldMax, "#5aa8ff", "SHLD");
    y += h + gap;
    this.bar(barX, y, w, h, ship.hull / ship.cfg.hullMax, "#5cff8c", "HULL");
    y += h + gap;
    const boostCol = ship.boostLocked ? "#ff5a33" : "#ffb13d";
    this.bar(barX, y, w, h, ship.boostEnergy / ship.cfg.boostCapacity, boostCol, "BST");
  }

  private bar(x: number, y: number, w: number, h: number, frac: number, color: string, label: string): void {
    const ctx = this.ctx;
    const f = Math.max(0, Math.min(1, frac));
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = color;
    ctx.fillRect(x, y, w * f, h);
    ctx.strokeStyle = "rgba(255,255,255,0.22)";
    ctx.lineWidth = 1;
    ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
    ctx.fillStyle = "rgba(255,255,255,0.78)";
    ctx.font = "12px ui-monospace, monospace";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    ctx.fillText(label, x - 66, y + h / 2);
  }
}
