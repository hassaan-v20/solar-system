import math
import sys

import numpy as np
import pygame
import moderngl

from camera import Camera
from scene import SolarSystem
from hud import Hud
from world import World, BODY_TYPES

WIDTH, HEIGHT = 1280, 720

KIND_KEYS = {
    pygame.K_1: "moon", pygame.K_2: "rocky", pygame.K_3: "ocean", pygame.K_4: "desert",
    pygame.K_5: "lava", pygame.K_6: "ice", pygame.K_7: "gas", pygame.K_8: "star",
}
HOTBAR = list(BODY_TYPES.keys())
MODE_SPEED = {"explore": 1.0, "creative": 0.10, "survival": 0.10}
CLICK_PIXELS = 6  # mouse travel under this on a press+release counts as a click


def pick_comet(camera, world, pos):
    """Return the cid of the comet under the cursor, or None."""
    origin, d = camera.screen_ray(*pos)
    best, best_t = None, 1e9
    for c in world.comets:
        oc = np.array([c.x, c.y, c.z], dtype="f8") - origin
        tca = oc @ d
        if tca < 0:
            continue
        d2 = oc @ oc - tca * tca
        r = 0.9
        if d2 <= r * r and tca < best_t:
            best, best_t = c.cid, tca
    return best


def main():
    pygame.init()
    pygame.display.set_mode((WIDTH, HEIGHT), pygame.OPENGL | pygame.DOUBLEBUF | pygame.RESIZABLE)
    pygame.display.set_caption("Stellar — solar system sandbox")

    ctx = moderngl.create_context()
    ctx.enable(moderngl.DEPTH_TEST | moderngl.BLEND | moderngl.PROGRAM_POINT_SIZE)
    ctx.blend_func = moderngl.SRC_ALPHA, moderngl.ONE_MINUS_SRC_ALPHA

    camera = Camera(WIDTH, HEIGHT)
    renderer = SolarSystem(ctx)
    renderer.resize(WIDTH, HEIGHT)
    hud = Hud(ctx)
    hud.resize(WIDTH, HEIGHT)

    world = World("explore")
    clock = pygame.time.Clock()
    sim_time = 0.0
    speed = MODE_SPEED[world.mode]
    running = True            # sim running (not paused)
    selected = "rocky"
    show_help = True
    dragging = False
    moved = 0.0
    down_pos = (0, 0)
    last_pos = (0, 0)

    def set_mode(mode):
        nonlocal world, speed, running
        world = World(mode)
        speed = MODE_SPEED[mode]
        running = True
        world.notify(mode.title() + " mode")

    while True:
        dt = clock.tick(60) / 1000.0
        if running:
            sim_time += dt * speed
        world.tick(dt, sim_time, running)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit(); sys.exit()

            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit(); sys.exit()
                elif event.key == pygame.K_F1:
                    set_mode("explore")
                elif event.key == pygame.K_F2:
                    set_mode("creative")
                elif event.key == pygame.K_F3:
                    set_mode("survival")
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
                        handle_click(camera, world, event.pos, selected, sim_time)

            elif event.type == pygame.MOUSEMOTION:
                if dragging:
                    dx = event.pos[0] - last_pos[0]
                    dy = event.pos[1] - last_pos[1]
                    moved += abs(dx) + abs(dy)
                    camera.rotate(dx, dy)
                    last_pos = event.pos

            elif event.type == pygame.VIDEORESIZE:
                camera.resize(event.w, event.h)
                renderer.resize(event.w, event.h)
                hud.resize(event.w, event.h)

        preview = build_preview(camera, world, selected, dragging)
        renderer.render(world, camera, sim_time, preview)
        draw_hud(hud, world, selected, speed, running, preview,
                 pygame.mouse.get_pos(), show_help)
        pygame.display.flip()


def handle_click(camera, world, pos, selected, sim_time):
    if world.threats_enabled:
        cid = pick_comet(camera, world, pos)
        if cid is not None:
            world.deflect(cid)
            world.notify("Comet deflected")
            return
    if world.mode in ("creative", "survival"):
        hit = camera.ground_hit(*pos)
        if hit is not None:
            world.apply({"type": "place", "body": selected,
                         "x": float(hit[0]), "z": float(hit[2]), "t": sim_time})


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


def draw_hud(hud, world, selected, speed, running, preview, mouse, show_help):
    hud.begin()
    W, H = hud.width, hud.height

    _draw_mode_badges(hud, world, W)
    _draw_status_card(hud, world, running, speed)
    if world.mode in ("creative", "survival"):
        _draw_hotbar(hud, world, selected, W, H)
        _draw_tooltip(hud, world, selected, preview, mouse)

    # Centre message (e.g. "Comet deflected", "Mars destroyed!").
    if world.message_t > 0.0 and world.message:
        hud.text_center(W // 2, H // 2 - 80, world.message, 30, (255, 175, 150))

    hud.text(14, H - 24, "H: toggle help", 16, (150, 160, 175))
    if show_help:
        _draw_help(hud, world, W, H)
    hud.end()


def _draw_mode_badges(hud, world, W):
    badges = [("Explore", "explore"), ("Creative", "creative"), ("Survival", "survival")]
    bw, bh, gap = 132, 30, 8
    total = len(badges) * bw + (len(badges) - 1) * gap
    x = (W - total) // 2
    for i, (label, mode) in enumerate(badges):
        active = world.mode == mode
        fill = (0.20, 0.42, 0.78, 0.92) if active else (0.06, 0.08, 0.14, 0.72)
        border = (0.6, 0.8, 1.0, 0.9) if active else (0.3, 0.34, 0.5, 0.5)
        hud.border_panel(x, 10, bw, bh, fill, border, 2)
        col = (255, 255, 255) if active else (165, 175, 195)
        hud.text_center(x + bw // 2, 16, f"F{i+1}  {label}", 18, col)
        x += bw + gap


def _draw_status_card(hud, world, running, speed):
    hud.border_panel(14, 52, 300, 104)
    hud.text(28, 58, world.mode.title() + " mode", 22, (185, 220, 255))
    if world.infinite_energy:
        hud.text(28, 90, "Energy: Unlimited", 20, (255, 228, 140))
    else:
        hud.text(28, 86, f"Energy {world.energy:.0f}    +{world.energy_rate():.1f}/s",
                 17, (255, 228, 140))
        cap = 1500.0
        frac = max(0.0, min(1.0, world.energy / cap))
        hud.panel(28, 108, 272, 9, (0.10, 0.10, 0.14, 0.85))
        hud.panel(28, 108, int(272 * frac), 9, (1.0, 0.80, 0.25, 0.95))
    extra = f"Planets: {len(world.planets())}"
    if world.threats_enabled:
        extra += f"    Comets: {len(world.comets)}"
    state = "Running" if running else "PAUSED"
    hud.text(28, 128, f"{extra}    {state}  x{speed:.2f}", 16, (190, 195, 210))


def _draw_hotbar(hud, world, selected, W, H):
    slot, gap = 58, 8
    n = len(HOTBAR)
    total = n * slot + (n - 1) * gap
    x0 = (W - total) // 2
    y = H - slot - 36
    for i, kind in enumerate(HOTBAR):
        spec = BODY_TYPES[kind]
        x = x0 + i * (slot + gap)
        sel = kind == selected
        border = (1.0, 0.95, 0.5, 1.0) if sel else (0.3, 0.34, 0.5, 0.6)
        hud.border_panel(x, y, slot, slot, (0.05, 0.06, 0.10, 0.82), border, 3 if sel else 2)
        sw = spec["swatch"]
        hud.panel(x + 8, y + 8, slot - 16, slot - 26, (sw[0], sw[1], sw[2], 1.0))
        hud.text(x + 5, y + 3, str(i + 1), 15, (255, 255, 255))
        hud.text_center(x + slot // 2, y + slot - 17, spec["name"], 13, (210, 215, 225))
        if not world.infinite_energy:
            hud.text_center(x + slot // 2, y + slot - 2, str(int(spec["cost"])), 12, (255, 220, 150))


def _draw_tooltip(hud, world, selected, preview, mouse):
    if preview is None:
        return
    spec = BODY_TYPES[selected]
    ok = preview["ok"]
    label = spec["name"] if world.infinite_energy else f"{spec['name']}  ({int(spec['cost'])})"
    if not ok:
        label = "Can't place here"
    tw, th = hud.measure(label, 16)
    mx, my = mouse
    px, py = mx + 16, my + 16
    hud.border_panel(px, py, tw + 16, th + 10,
                     (0.05, 0.07, 0.11, 0.9),
                     (0.4, 0.9, 0.6, 0.8) if ok else (0.9, 0.4, 0.4, 0.8), 1)
    hud.text(px + 8, py + 5, label, 16, (190, 255, 210) if ok else (255, 190, 190))


def _draw_help(hud, world, W, H):
    lines = [
        "STELLAR — a solar system sandbox",
        "",
        "F1  Explore    fly around the real solar system",
        "F2  Creative   unlimited energy, build anything",
        "F3  Survival   earn energy, expand, defend from comets",
        "",
        "1-8        pick what to build (see the bar at the bottom)",
        "Click      place it on an orbit  /  click a comet to deflect it",
        "Drag       rotate the view        Scroll  zoom",
        "+ / -      change speed           Space   pause",
        "R          reset camera           Esc     quit",
        "",
        "Tip: in Survival, planets near the Sun's habitable zone earn the",
        "most energy. Watch for comets and click them before they hit!",
        "",
        "Press H to close",
    ]
    pw, ph = 620, 26 * len(lines) + 36
    px, py = (W - pw) // 2, (H - ph) // 2
    hud.border_panel(px, py, pw, ph, (0.03, 0.04, 0.08, 0.92), (0.5, 0.6, 0.9, 0.8), 3)
    for i, line in enumerate(lines):
        if i == 0:
            hud.text_center(W // 2, py + 18 + i * 26, line, 22, (255, 230, 150))
        else:
            hud.text(px + 30, py + 18 + i * 26, line, 17, (205, 212, 228))


if __name__ == "__main__":
    main()
