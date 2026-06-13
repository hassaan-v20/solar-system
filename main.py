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

KIND_KEYS = {pygame.K_1: "moon", pygame.K_2: "rocky", pygame.K_3: "terran", pygame.K_4: "gas"}
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
        draw_hud(hud, world, selected, speed, running)
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
    _disp, _tex, radius, _spec, cost = BODY_TYPES[selected]
    ok = (world.infinite_energy or world.energy >= cost) and dist >= 6.0
    return {"x": float(hit[0]), "z": float(hit[2]), "dist": dist, "radius": radius, "ok": ok}


def draw_hud(hud, world, selected, speed, running):
    hud.begin()
    # Status panel.
    hud.panel(12, 12, 320, 104)
    hud.text(24, 18, f"Mode: {world.mode.title()}", 24, (180, 220, 255))
    if world.infinite_energy:
        hud.text(24, 50, "Energy: Unlimited", 22, (255, 230, 140))
    else:
        hud.text(24, 50, f"Energy: {world.energy:.0f}  (+{world.energy_rate():.1f}/s)", 22, (255, 230, 140))
    extra = f"Planets: {len(world.planets())}"
    if world.threats_enabled:
        extra += f"   Comets: {len(world.comets)}"
    hud.text(24, 80, extra, 20, (200, 200, 210))

    # Build palette (hidden in Explore).
    if world.mode in ("creative", "survival"):
        x = 12
        y = 128
        for key, kind in (("1", "moon"), ("2", "rocky"), ("3", "terran"), ("4", "gas")):
            disp, _t, _r, _s, cost = BODY_TYPES[kind]
            label = f"[{key}] {disp} ({int(cost)})"
            col = (120, 255, 180) if kind == selected else (170, 175, 185)
            w, _h = hud.text(x, y, label, 20, col)
            x += w + 18

    # Centre message.
    if world.message_t > 0.0 and world.message:
        w, _h = hud.measure(world.message, 30)
        hud.text((hud.width - w) // 2, hud.height // 2 - 60, world.message, 30, (255, 180, 160))

    # Controls hint.
    state = "running" if running else "PAUSED"
    hint = ("F1 Explore  F2 Creative  F3 Survival   |   "
            "Click: place / deflect   Drag: orbit   Scroll: zoom   "
            f"Space: {state}   +/-: speed x{speed:.2f}")
    hud.text(14, hud.height - 26, hint, 16, (150, 160, 175))
    hud.end()


if __name__ == "__main__":
    main()
