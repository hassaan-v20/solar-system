import math
import sys

import numpy as np
import pygame
import moderngl

from camera import Camera
from scene import SolarSystem
from hud import Hud
from world import World, BODY_TYPES, has_save, save_game, load_game

WINDOWED = (1280, 720)
HOTBAR = list(BODY_TYPES.keys())
_NUM_KEYS = [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5,
             pygame.K_6, pygame.K_7, pygame.K_8, pygame.K_9, pygame.K_0]
KIND_KEYS = {_NUM_KEYS[i]: k for i, k in enumerate(HOTBAR) if i < len(_NUM_KEYS)}
MODE_SPEED = {"explore": 1.0, "creative": 0.10, "survival": 0.10}
CLICK_PIXELS = 6


# ── shared UI layout (used by both drawing and click hit-testing) ──────────────
def point_in(rect, pos):
    x, y, w, h = rect
    return x <= pos[0] <= x + w and y <= pos[1] <= y + h


def mode_badge_rects(W):
    badges = [("Explore", "explore"), ("Creative", "creative"), ("Survival", "survival")]
    bw, bh, gap = 160, 34, 10
    total = len(badges) * bw + (len(badges) - 1) * gap
    x = (W - total) // 2
    return [((x + i * (bw + gap), 10, bw, bh), lbl, m) for i, (lbl, m) in enumerate(badges)]


def hotbar_rects(W, H):
    slot, gap = 62, 8
    n = len(HOTBAR)
    total = n * slot + (n - 1) * gap
    x0 = (W - total) // 2
    y = H - slot - 42
    return [((x0 + i * (slot + gap), y, slot, slot), HOTBAR[i]) for i in range(n)]


def title_button_rects(W, H, save_exists):
    items = [("continue", "Continue", save_exists),
             ("explore", "New Game  —  Explore", True),
             ("creative", "New Game  —  Creative", True),
             ("survival", "New Game  —  Survival", True),
             ("quit", "Quit", True)]
    bw, bh, gap = 360, 50, 14
    total = len(items) * bh + (len(items) - 1) * gap
    x = (W - bw) // 2
    y = H // 2 - total // 2 + 80
    out = []
    for action, label, enabled in items:
        out.append(((x, y, bw, bh), action, label, enabled))
        y += bh + gap
    return out


# ── display / GL setup (rebuilt on fullscreen toggle) ──────────────────────────
def setup_display(fullscreen):
    flags = pygame.OPENGL | pygame.DOUBLEBUF
    if fullscreen:
        pygame.display.set_mode((0, 0), flags | pygame.FULLSCREEN)
    else:
        pygame.display.set_mode(WINDOWED, flags | pygame.RESIZABLE)
    pygame.display.set_caption("Stellar — solar system sandbox")
    W, H = pygame.display.get_surface().get_size()
    ctx = moderngl.create_context()
    ctx.enable(moderngl.DEPTH_TEST | moderngl.BLEND | moderngl.PROGRAM_POINT_SIZE)
    ctx.blend_func = moderngl.SRC_ALPHA, moderngl.ONE_MINUS_SRC_ALPHA
    return ctx, W, H


def pick_comet(camera, world, pos):
    origin, d = camera.screen_ray(*pos)
    best, best_t = None, 1e9
    for c in world.comets:
        oc = np.array([c.x, c.y, c.z], dtype="f8") - origin
        tca = oc @ d
        if tca < 0:
            continue
        if oc @ oc - tca * tca <= 0.9 * 0.9 and tca < best_t:
            best, best_t = c.cid, tca
    return best


def main():
    pygame.init()
    fullscreen = True
    ctx, W, H = setup_display(fullscreen)
    camera = Camera(W, H)
    renderer = SolarSystem(ctx)
    renderer.resize(W, H)
    hud = Hud(ctx)
    hud.resize(W, H)

    clock = pygame.time.Clock()
    state = "title"                 # "title" | "playing"
    world = World("explore")        # also serves as the title background
    sim_time = 0.0
    title_time = 0.0
    speed = MODE_SPEED["explore"]
    running = True
    selected = "rocky"
    show_help = False
    dragging = False
    moved = 0.0
    down_pos = last_pos = (0, 0)

    while True:
        dt = clock.tick(60) / 1000.0
        mouse = pygame.mouse.get_pos()

        if state == "playing":
            if running:
                sim_time += dt * speed
            world.tick(dt, sim_time, running)
        else:
            title_time += dt * 0.3
            camera.yaw += dt * 3.0
            camera._update()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit(); sys.exit()

            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_F11:
                    fullscreen = not fullscreen
                    ctx, W, H = setup_display(fullscreen)
                    renderer = SolarSystem(ctx); renderer.resize(W, H)
                    hud = Hud(ctx); hud.resize(W, H)
                    camera.resize(W, H)
                elif event.key == pygame.K_ESCAPE:
                    if state == "playing":
                        save_game(world, sim_time)     # autosave then back to menu
                        state = "title"
                    else:
                        pygame.quit(); sys.exit()
                elif state == "playing":
                    if event.key == pygame.K_F1:
                        world = World("explore"); sim_time = 0.0; speed = MODE_SPEED["explore"]; running = True
                    elif event.key == pygame.K_F2:
                        world = World("creative"); sim_time = 0.0; speed = MODE_SPEED["creative"]; running = True
                    elif event.key == pygame.K_F3:
                        world = World("survival"); sim_time = 0.0; speed = MODE_SPEED["survival"]; running = True
                    elif event.key in KIND_KEYS:
                        selected = KIND_KEYS[event.key]
                    elif event.key == pygame.K_h:
                        show_help = not show_help
                    elif event.key in (pygame.K_EQUALS, pygame.K_PLUS):
                        speed = min(speed * 2.0, 64.0)
                    elif event.key == pygame.K_MINUS:
                        speed = max(speed / 2.0, 0.02)
                    elif event.key == pygame.K_r:
                        camera.reset()
                    elif event.key == pygame.K_SPACE:
                        running = not running

            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:
                    dragging = True; moved = 0.0
                    down_pos = last_pos = event.pos
                elif event.button == 4:
                    camera.zoom(-4.0)
                elif event.button == 5:
                    camera.zoom(4.0)

            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1:
                    dragging = False
                    if moved < CLICK_PIXELS:
                        if state == "title":
                            for rect, action, _lbl, enabled in title_button_rects(W, H, has_save()):
                                if enabled and point_in(rect, event.pos):
                                    if action == "quit":
                                        pygame.quit(); sys.exit()
                                    elif action == "continue":
                                        world, sim_time = load_game()
                                        speed = MODE_SPEED.get(world.mode, 0.1); running = True; state = "playing"
                                    else:
                                        world = World(action); sim_time = 0.0
                                        speed = MODE_SPEED[action]; running = True; state = "playing"
                                    break
                        else:
                            selected = handle_play_click(camera, world, event.pos, selected, sim_time, W, H)

            elif event.type == pygame.MOUSEMOTION:
                if dragging and state == "playing":
                    dx = event.pos[0] - last_pos[0]
                    dy = event.pos[1] - last_pos[1]
                    moved += abs(dx) + abs(dy)
                    camera.rotate(dx, dy)
                    last_pos = event.pos

            elif event.type == pygame.VIDEORESIZE and not fullscreen:
                camera.resize(event.w, event.h)
                renderer.resize(event.w, event.h)
                hud.resize(event.w, event.h)
                W, H = event.w, event.h

        if state == "playing":
            preview = build_preview(camera, world, selected, dragging)
            renderer.render(world, camera, sim_time, preview)
            draw_hud(hud, world, selected, speed, running, preview, mouse, show_help)
        else:
            renderer.render(world, camera, title_time, None)
            draw_title(hud, W, H, has_save(), mouse)
        pygame.display.flip()


def handle_play_click(camera, world, pos, selected, sim_time, W, H):
    # Mode badges first.
    for rect, _lbl, mode in mode_badge_rects(W):
        if point_in(rect, pos):
            if mode != world.mode:
                new = World(mode)
                world.bodies = new.bodies
                world.comets = new.comets
                world.mode = mode
                world.energy = new.energy
                world.score = 0
                world._elapsed = 0.0
            return selected
    # Hotbar slots.
    if world.mode in ("creative", "survival"):
        for rect, kind in hotbar_rects(W, H):
            if point_in(rect, pos):
                return kind
    # Otherwise: deflect a comet or place a body in the world.
    if world.threats_enabled:
        cid = pick_comet(camera, world, pos)
        if cid is not None:
            world.deflect(cid)
            world.notify("Comet deflected")
            return selected
    if world.mode in ("creative", "survival"):
        hit = camera.ground_hit(*pos)
        if hit is not None:
            world.apply({"type": "place", "body": selected,
                         "x": float(hit[0]), "z": float(hit[2]), "t": sim_time})
    return selected


def build_preview(camera, world, selected, dragging):
    if dragging or world.mode not in ("creative", "survival"):
        return None
    hit = camera.ground_hit(*pygame.mouse.get_pos())
    if hit is None:
        return None
    dist = float(math.hypot(hit[0], hit[2]))
    if dist > 105.0:
        return None
    spec = BODY_TYPES[selected]
    ok = (world.infinite_energy or world.energy >= spec["cost"]) and dist >= 6.0
    return {"x": float(hit[0]), "z": float(hit[2]), "dist": dist,
            "radius": spec["radius"], "ok": ok}


# ── title screen ───────────────────────────────────────────────────────────────
def draw_title(hud, W, H, save_exists, mouse):
    hud.begin()
    hud.panel(0, 0, W, H, (0.0, 0.0, 0.0, 0.45))
    hud.text_center(W // 2, H // 2 - 235, "STELLAR", 80, (255, 235, 175), "title")
    hud.text_center(W // 2, H // 2 - 140, "A SOLAR SYSTEM SANDBOX", 18, (165, 200, 245), "ui")
    for rect, action, label, enabled in title_button_rects(W, H, save_exists):
        x, y, w, h = rect
        hover = enabled and point_in(rect, mouse)
        if not enabled:
            fill, border, col = (0.05, 0.05, 0.07, 0.6), (0.2, 0.22, 0.3, 0.5), (110, 110, 120)
        elif hover:
            fill, border, col = (0.20, 0.42, 0.78, 0.95), (0.7, 0.85, 1.0, 1.0), (255, 255, 255)
        else:
            fill, border, col = (0.06, 0.09, 0.16, 0.85), (0.35, 0.42, 0.6, 0.6), (215, 222, 238)
        hud.border_panel(x, y, w, h, fill, border, 2)
        hud.text_center(x + w // 2, y + h // 2 - 13, label, 20, col, "ui")
    hud.text_center(W // 2, H - 40, "Click an option  ·  F11 fullscreen  ·  Esc quit", 16,
                    (150, 160, 178), "body")
    hud.end()


# ── in-game HUD ────────────────────────────────────────────────────────────────
def draw_hud(hud, world, selected, speed, running, preview, mouse, show_help):
    hud.begin()
    W, H = hud.width, hud.height
    _draw_mode_badges(hud, world, W, mouse)
    _draw_status_card(hud, world, running, speed)
    if world.mode in ("creative", "survival"):
        _draw_hotbar(hud, world, selected, W, H, mouse)
        _draw_tooltip(hud, world, selected, preview, mouse)
    if world.message_t > 0.0 and world.message:
        hud.text_center(W // 2, H // 2 - 90, world.message, 30, (255, 175, 150), "ui")
    hud.text(14, H - 24, "H: help    Esc: menu", 15, (150, 160, 175), "body")
    if show_help:
        _draw_help(hud, world, W, H)
    hud.end()


def _draw_mode_badges(hud, world, W, mouse):
    for rect, label, mode in mode_badge_rects(W):
        x, y, w, h = rect
        active = world.mode == mode
        hover = point_in(rect, mouse)
        if active:
            fill, border, col = (0.20, 0.42, 0.78, 0.95), (0.7, 0.85, 1.0, 1.0), (255, 255, 255)
        elif hover:
            fill, border, col = (0.12, 0.20, 0.34, 0.9), (0.5, 0.6, 0.85, 0.8), (220, 228, 245)
        else:
            fill, border, col = (0.06, 0.08, 0.14, 0.78), (0.3, 0.34, 0.5, 0.5), (170, 178, 198)
        hud.border_panel(x, y, w, h, fill, border, 2)
        hud.text_center(x + w // 2, y + 9, label, 16, col, "ui")


def _draw_status_card(hud, world, running, speed):
    hud.border_panel(14, 54, 300, 104)
    hud.text(28, 60, world.mode.upper(), 20, (185, 220, 255), "ui")
    if world.infinite_energy:
        hud.text(28, 92, "Energy: Unlimited", 18, (255, 228, 140), "body")
    else:
        hud.text(28, 88, f"Energy {world.energy:.0f}    +{world.energy_rate():.1f}/s",
                 17, (255, 228, 140), "body")
        frac = max(0.0, min(1.0, world.energy / 1500.0))
        hud.panel(28, 110, 272, 9, (0.10, 0.10, 0.14, 0.85))
        hud.panel(28, 110, int(272 * frac), 9, (1.0, 0.80, 0.25, 0.95))
    extra = f"Planets: {len(world.planets())}"
    if world.threats_enabled:
        extra += f"    Comets: {len(world.comets)}"
    hud.text(28, 130, f"{extra}    {'Running' if running else 'PAUSED'}  x{speed:.2f}",
             15, (190, 195, 210), "body")


def _draw_hotbar(hud, world, selected, W, H, mouse):
    for (rect, kind) in hotbar_rects(W, H):
        x, y, w, h = rect
        spec = BODY_TYPES[kind]
        sel = kind == selected
        hover = point_in(rect, mouse)
        border = (1.0, 0.95, 0.5, 1.0) if sel else ((0.6, 0.7, 0.95, 0.8) if hover else (0.3, 0.34, 0.5, 0.6))
        hud.border_panel(x, y, w, h, (0.05, 0.06, 0.10, 0.82), border, 3 if sel else 2)
        sw = spec["swatch"]
        hud.panel(x + 8, y + 8, w - 16, h - 28, (sw[0], sw[1], sw[2], 1.0))
        hud.text(x + 5, y + 3, str((HOTBAR.index(kind) + 1) % 10), 14, (255, 255, 255), "ui")
        hud.text_center(x + w // 2, y + h - 18, spec["name"], 12, (210, 215, 225), "ui")
        if not world.infinite_energy:
            hud.text_center(x + w // 2, y + h - 3, str(int(spec["cost"])), 11, (255, 220, 150), "body")


def _draw_tooltip(hud, world, selected, preview, mouse):
    if preview is None:
        return
    spec = BODY_TYPES[selected]
    ok = preview["ok"]
    if not ok:
        label = "Can't place here"
    else:
        label = spec["name"] if world.infinite_energy else f"{spec['name']}  ({int(spec['cost'])})"
    tw, th = hud.measure(label, 16, "body")
    px, py = mouse[0] + 16, mouse[1] + 16
    hud.border_panel(px, py, tw + 16, th + 10, (0.05, 0.07, 0.11, 0.92),
                     (0.4, 0.9, 0.6, 0.8) if ok else (0.9, 0.4, 0.4, 0.8), 1)
    hud.text(px + 8, py + 5, label, 16, (190, 255, 210) if ok else (255, 190, 190), "body")


def _draw_help(hud, world, W, H):
    lines = [
        ("F1 / F2 / F3", "Explore / Creative / Survival"),
        ("1 - 0", "pick a world or star (see the bar below)"),
        ("Left click", "place it on an orbit, or deflect a comet"),
        ("Click badges/bar", "switch mode or select a body with the mouse"),
        ("Drag", "rotate view        Scroll  zoom"),
        ("+ / -", "change speed       Space  pause"),
        ("F11", "fullscreen         Esc    back to menu"),
        ("R", "reset camera        H      close help"),
    ]
    pw, ph = 640, 44 + 30 * len(lines) + 40
    px, py = (W - pw) // 2, (H - ph) // 2
    hud.border_panel(px, py, pw, ph, (0.03, 0.04, 0.08, 0.93), (0.5, 0.6, 0.9, 0.85), 3)
    hud.text_center(W // 2, py + 16, "HOW TO PLAY", 24, (255, 230, 150), "title")
    y = py + 56
    for key, desc in lines:
        hud.text(px + 28, y, key, 16, (140, 210, 255), "ui")
        hud.text(px + 240, y, desc, 16, (205, 212, 228), "body")
        y += 30
    hud.text_center(W // 2, py + ph - 30,
                    "Survival tip: build near the Sun's habitable zone for more energy.",
                    15, (170, 180, 200), "body")


if __name__ == "__main__":
    main()
