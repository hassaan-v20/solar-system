import math
import subprocess
import sys
from pathlib import Path

import numpy as np
import pygame
import moderngl

from camera import Camera
from scene import SolarSystem
from hud import Hud
from world import World, BODY_TYPES, body_world_pos, has_save, save_game, load_game
from netclient import NetClient
from surface import Surface, RECIPE_ORDER, RECIPE_LABEL, RECIPES, WEAPONS, ARMORS, ITEM_ORDER, ITEM_COLOR, PLAYER_MAX_HP
from surface_scene import SurfaceRenderer

LOOK_SENS = 0.0026

WINDOWED = (1280, 720)
SERVER_PY = Path(__file__).parent / "server.py"
PORT = 8765
HOTBAR = list(BODY_TYPES.keys())
_NUM_KEYS = [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5,
             pygame.K_6, pygame.K_7, pygame.K_8, pygame.K_9, pygame.K_0]
KIND_KEYS = {_NUM_KEYS[i]: k for i, k in enumerate(HOTBAR) if i < len(_NUM_KEYS)}
MODE_SPEED = {"explore": 1.0, "creative": 0.10, "survival": 0.10}
CLICK_PIXELS = 6
PLAYER_COLORS = [(0.45, 0.80, 1.00), (1.00, 0.60, 0.40), (0.55, 1.00, 0.50),
                 (1.00, 0.55, 0.90), (1.00, 0.90, 0.45), (0.70, 0.70, 1.00)]


def player_color(pid):
    return PLAYER_COLORS[(pid or 0) % len(PLAYER_COLORS)]


# ── shared UI layout ───────────────────────────────────────────────────────────
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
             ("host", "Host Co-op Game", True),
             ("join", "Join Co-op Game", True),
             ("quit", "Quit", True)]
    bw, bh, gap = 360, 46, 11
    total = len(items) * bh + (len(items) - 1) * gap
    x = (W - bw) // 2
    y = H // 2 - total // 2 + 70
    out = []
    for action, label, enabled in items:
        out.append(((x, y, bw, bh), action, label, enabled))
        y += bh + gap
    return out


def normalize_addr(s):
    s = s.strip()
    if not s:
        s = "localhost"
    if not (s.startswith("ws://") or s.startswith("wss://")):
        s = "ws://" + s
    if ":" not in s.split("://", 1)[1]:
        s += f":{PORT}"
    return s


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


def pick_body(camera, world, pos, t):
    """Land on the landable planet whose on-screen position is nearest the click
    (forgiving — you don't have to hit the tiny sphere exactly)."""
    best, best_d = None, 140.0     # pixel threshold
    for b in world.bodies:
        if not b.alive or b.special in ("sun", "star"):
            continue
        sp = camera.world_to_screen(body_world_pos(b, t))
        if sp is None:
            continue
        d = math.hypot(sp[0] - pos[0], sp[1] - pos[1])
        if d < best_d:
            best, best_d = b, d
    return best


def planet_kind_from_body(b):
    n = b.name.lower()
    for k in ("ocean", "lava", "ice", "toxic", "sulfur", "desert"):
        if k in n:
            return k
    if "earth" in n:
        return "ocean"
    return "rocky"


def pick_entity(camera, world, pos, t):
    origin, d = camera.screen_ray(*pos)
    best, best_t = None, 1e9
    for e in world.entities:
        if not e.alive:
            continue
        wp = world.entity_world_pos(e, t)
        if wp is None:
            continue
        oc = np.array(wp, dtype="f8") - origin
        tca = oc @ d
        if tca < 0:
            continue
        if oc @ oc - tca * tca <= 0.6 * 0.6 and tca < best_t:
            best, best_t = e.eid, tca
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
    state = "title"                  # title | join | playing
    world = World("explore")
    sim_time = 0.0
    title_time = 0.0
    speed = MODE_SPEED["explore"]
    running = True
    selected = "rocky"
    show_help = False
    players = []
    net = None
    host_proc = None
    cam_timer = 0.0
    join_text = f"ws://localhost:{PORT}"
    join_pw = ""
    host_pw = ""
    join_focus = 0          # 0 = address field, 1 = password field
    surf = None
    surf_renderer = None
    dragging = False
    moved = 0.0
    down_pos = last_pos = (0, 0)

    def leave_to_menu():
        nonlocal net, host_proc, state
        if net:
            net.close(); net = None
        if host_proc:
            host_proc.terminate(); host_proc = None
        state = "title"

    while True:
        dt = clock.tick(60) / 1000.0
        mouse = pygame.mouse.get_pos()

        if state == "playing":
            if net is not None:                      # multiplayer: state comes from server
                snap = net.get_world()
                if snap is not None:
                    world, sim_time, speed, running, players = snap
                cam_timer += dt
                if cam_timer >= 0.1 and net.status == "connected":
                    cam_timer = 0.0
                    cur = camera.ground_hit(*mouse)
                    net.send_cam([float(v) for v in camera.position],
                                 None if cur is None else [float(cur[0]), float(cur[1]), float(cur[2])])
            else:
                players = []
                if running:
                    sim_time += dt * speed
                world.tick(dt, sim_time, running)
        elif state == "surface":
            keys = pygame.key.get_pressed()
            fwd = (1 if keys[pygame.K_w] else 0) - (1 if keys[pygame.K_s] else 0)
            strafe = (1 if keys[pygame.K_d] else 0) - (1 if keys[pygame.K_a] else 0)
            surf.update(dt, fwd, strafe)
        else:
            title_time += dt * 0.3
            camera.yaw += dt * 3.0
            camera._update()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit(); sys.exit()

            elif event.type == pygame.KEYDOWN:
                if state == "join":
                    if event.key == pygame.K_RETURN:
                        net = NetClient(normalize_addr(join_text), name="Player", password=join_pw)
                        world = World("creative"); state = "playing"
                    elif event.key == pygame.K_ESCAPE:
                        state = "title"
                    elif event.key == pygame.K_TAB:
                        join_focus ^= 1
                    elif event.key == pygame.K_BACKSPACE:
                        if join_focus == 0:
                            join_text = join_text[:-1]
                        else:
                            join_pw = join_pw[:-1]
                    elif event.unicode and event.unicode.isprintable():
                        if join_focus == 0:
                            join_text += event.unicode
                        else:
                            join_pw += event.unicode
                    continue
                if state == "host_setup":
                    if event.key == pygame.K_RETURN:
                        args = [sys.executable, str(SERVER_PY), "--mode", "creative", "--port", str(PORT)]
                        if host_pw:
                            args += ["--password", host_pw]
                        host_proc = subprocess.Popen(args)
                        net = NetClient(f"ws://127.0.0.1:{PORT}", name="Host", password=host_pw)
                        world = World("creative"); state = "playing"
                    elif event.key == pygame.K_ESCAPE:
                        state = "title"
                    elif event.key == pygame.K_BACKSPACE:
                        host_pw = host_pw[:-1]
                    elif event.unicode and event.unicode.isprintable():
                        host_pw += event.unicode
                    continue

                if state == "surface":
                    if event.key == pygame.K_ESCAPE:
                        pygame.event.set_grab(False)
                        pygame.mouse.set_visible(True)
                        state = "playing"
                    elif event.key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4):
                        idx = [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4].index(event.key)
                        surf.craft(RECIPE_ORDER[idx])
                    continue

                if event.key == pygame.K_F11:
                    fullscreen = not fullscreen
                    ctx, W, H = setup_display(fullscreen)
                    renderer = SolarSystem(ctx); renderer.resize(W, H)
                    hud = Hud(ctx); hud.resize(W, H)
                    camera.resize(W, H)
                    surf_renderer = None
                elif event.key == pygame.K_ESCAPE:
                    if state == "playing":
                        if net is not None:
                            leave_to_menu()
                        else:
                            save_game(world, sim_time)
                            state = "title"
                    else:
                        pygame.quit(); sys.exit()
                elif state == "playing":
                    if event.key in (pygame.K_F1, pygame.K_F2, pygame.K_F3):
                        m = {pygame.K_F1: "explore", pygame.K_F2: "creative", pygame.K_F3: "survival"}[event.key]
                        if net is not None:
                            net.send_ctrl("mode", m)
                        else:
                            world = World(m); sim_time = 0.0; speed = MODE_SPEED[m]; running = True
                    elif event.key in KIND_KEYS:
                        selected = KIND_KEYS[event.key]
                    elif event.key == pygame.K_h:
                        show_help = not show_help
                    elif event.key in (pygame.K_EQUALS, pygame.K_PLUS):
                        if net is not None:
                            net.send_ctrl("speed", min(speed * 2.0, 64.0))
                        else:
                            speed = min(speed * 2.0, 64.0)
                    elif event.key == pygame.K_MINUS:
                        if net is not None:
                            net.send_ctrl("speed", max(speed / 2.0, 0.02))
                        else:
                            speed = max(speed / 2.0, 0.02)
                    elif event.key == pygame.K_r:
                        camera.reset()
                    elif event.key == pygame.K_SPACE:
                        if net is not None:
                            net.send_ctrl("resume" if not running else "pause")
                        else:
                            running = not running
                    elif event.key == pygame.K_l:
                        b = pick_body(camera, world, (W // 2, H // 2), sim_time)
                        if b is not None:
                            surf = Surface(planet_kind_from_body(b))
                            if surf_renderer is None:
                                surf_renderer = SurfaceRenderer(ctx, renderer.tex)
                            pygame.event.set_grab(True)
                            pygame.mouse.set_visible(False)
                            pygame.mouse.get_rel()
                            state = "surface"
                        else:
                            world.notify("Point the view near a planet, then press L")

            elif event.type == pygame.MOUSEBUTTONDOWN:
                if state == "surface":
                    if event.button == 1:
                        surf.attack()
                    continue
                if event.button == 1:
                    dragging = True; moved = 0.0
                    down_pos = last_pos = event.pos
                elif event.button == 3 and state == "playing":
                    b = pick_body(camera, world, event.pos, sim_time)
                    if b is not None:
                        surf = Surface(planet_kind_from_body(b))
                        if surf_renderer is None:
                            surf_renderer = SurfaceRenderer(ctx, renderer.tex)
                        pygame.event.set_grab(True)
                        pygame.mouse.set_visible(False)
                        pygame.mouse.get_rel()
                        state = "surface"
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
                                    elif action == "host":
                                        state = "host_setup"
                                    elif action == "join":
                                        state = "join"
                                    else:
                                        world = World(action); sim_time = 0.0
                                        speed = MODE_SPEED[action]; running = True; state = "playing"
                                    break
                        elif state == "playing":
                            selected = handle_play_click(camera, world, event.pos, selected,
                                                         sim_time, W, H, net)

            elif event.type == pygame.MOUSEMOTION:
                if state == "surface":
                    surf.yaw += event.rel[0] * LOOK_SENS
                    surf.pitch = max(-1.4, min(1.4, surf.pitch - event.rel[1] * LOOK_SENS))
                elif dragging and state == "playing":
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
            avatars, avatar_labels = [], []
            if net is not None and net.pid is not None:
                for pl in players:
                    if pl.get("pid") == net.pid:
                        continue
                    col = player_color(pl.get("pid", 0))
                    avatars.append({"cursor": pl.get("cursor"), "color": col})
                    cur = pl.get("cursor")
                    if cur:
                        sp = camera.world_to_screen(cur)
                        if sp and 0 <= sp[0] <= W and 0 <= sp[1] <= H:
                            avatar_labels.append((sp[0], sp[1], pl.get("name", ""),
                                                  tuple(int(c * 255) for c in col)))
            preview = build_preview(camera, world, selected, dragging)
            renderer.render(world, camera, sim_time, preview, avatars)
            draw_hud(hud, world, selected, speed, running, preview, mouse, show_help,
                     net, players, avatar_labels)
        elif state == "surface":
            surf_renderer.render(surf, W, H)
            draw_surface_hud(hud, surf, W, H)
        elif state == "join":
            renderer.render(World("explore"), camera, title_time, None)
            draw_join(hud, W, H, join_text, join_pw, join_focus)
        elif state == "host_setup":
            renderer.render(World("explore"), camera, title_time, None)
            draw_host(hud, W, H, host_pw)
        else:
            renderer.render(world, camera, title_time, None)
            draw_title(hud, W, H, has_save(), mouse)
        pygame.display.flip()


def handle_play_click(camera, world, pos, selected, sim_time, W, H, net):
    for rect, _lbl, mode in mode_badge_rects(W):
        if point_in(rect, pos):
            if mode != world.mode:
                if net is not None:
                    net.send_ctrl("mode", mode)
                else:
                    new = World(mode)
                    world.bodies, world.comets = new.bodies, new.comets
                    world.mode, world.energy, world.score = mode, new.energy, 0
                    world._elapsed = 0.0
            return selected
    if world.mode in ("creative", "survival"):
        for rect, kind in hotbar_rects(W, H):
            if point_in(rect, pos):
                return kind
    # Entities (life / crystals / relics) are clickable to harvest.
    eid = pick_entity(camera, world, pos, sim_time)
    if eid is not None:
        cmd = {"type": "harvest", "eid": eid}
        net.send_cmd(cmd) if net is not None else world.apply(cmd)
        return selected
    if world.threats_enabled:
        cid = pick_comet(camera, world, pos)
        if cid is not None:
            if net is not None:
                net.send_cmd({"type": "deflect", "cid": cid})
            else:
                world.deflect(cid); world.notify("Comet deflected")
            return selected
    if world.mode in ("creative", "survival"):
        hit = camera.ground_hit(*pos)
        if hit is not None:
            cmd = {"type": "place", "body": selected, "x": float(hit[0]),
                   "z": float(hit[2]), "t": sim_time}
            if net is not None:
                net.send_cmd(cmd)
            else:
                world.apply(cmd)
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


# ── title / join screens ───────────────────────────────────────────────────────
def draw_title(hud, W, H, save_exists, mouse):
    hud.begin()
    hud.panel(0, 0, W, H, (0.0, 0.0, 0.0, 0.45))
    hud.text_center(W // 2, H // 2 - 245, "STELLAR", 80, (255, 235, 175), "title")
    hud.text_center(W // 2, H // 2 - 152, "A SOLAR SYSTEM SANDBOX", 18, (165, 200, 245), "ui")
    for rect, action, label, enabled in title_button_rects(W, H, save_exists):
        _draw_button(hud, rect, label, enabled and point_in(rect, mouse), enabled)
    hud.text_center(W // 2, H - 38, "Click an option  ·  F11 fullscreen  ·  Esc quit", 16,
                    (150, 160, 178), "body")
    hud.end()


def _field(hud, x, y, bw, bh, label, value, focused, mask=False):
    border = (0.5, 0.8, 1.0, 1.0) if focused else (0.35, 0.42, 0.6, 0.6)
    hud.text(x, y - 22, label, 15, (170, 185, 210), "ui")
    hud.border_panel(x, y, bw, bh, (0.05, 0.07, 0.12, 0.95), border, 2)
    shown = ("•" * len(value)) if mask else value
    if focused:
        shown += "_"
    hud.text(x + 14, y + 13, shown, 20, (235, 240, 250), "body")


def draw_join(hud, W, H, text, pw, focus):
    hud.begin()
    hud.panel(0, 0, W, H, (0.0, 0.0, 0.0, 0.6))
    hud.text_center(W // 2, H // 2 - 160, "JOIN CO-OP GAME", 34, (255, 235, 175), "title")
    bw, bh = 560, 48
    x = (W - bw) // 2
    _field(hud, x, H // 2 - 80, bw, bh, "HOST ADDRESS", text, focus == 0)
    _field(hud, x, H // 2 + 6, bw, bh, "PASSWORD (blank if none)", pw, focus == 1, mask=True)
    hud.text_center(W // 2, H // 2 + 86, "Tab = switch field    Enter = connect    Esc = back",
                    16, (170, 180, 200), "body")
    hud.text_center(W // 2, H // 2 + 120,
                    "e.g.  ws://12.34.56.78:8765   (host shares this — see README)",
                    15, (140, 150, 170), "body")
    hud.end()


def draw_host(hud, W, H, pw):
    hud.begin()
    hud.panel(0, 0, W, H, (0.0, 0.0, 0.0, 0.6))
    hud.text_center(W // 2, H // 2 - 150, "HOST CO-OP GAME", 34, (255, 235, 175), "title")
    bw, bh = 560, 48
    x = (W - bw) // 2
    _field(hud, x, H // 2 - 40, bw, bh, "ROOM PASSWORD (blank = open to anyone)", pw, True, mask=True)
    hud.text_center(W // 2, H // 2 + 44, "Enter = start hosting    Esc = back", 16, (170, 180, 200), "body")
    hud.text_center(W // 2, H // 2 + 80,
                    "Share your address + password with friends (see README for internet play).",
                    15, (140, 150, 170), "body")
    hud.end()


def _draw_button(hud, rect, label, hover, enabled):
    x, y, w, h = rect
    if not enabled:
        fill, border, col = (0.05, 0.05, 0.07, 0.6), (0.2, 0.22, 0.3, 0.5), (110, 110, 120)
    elif hover:
        fill, border, col = (0.20, 0.42, 0.78, 0.95), (0.7, 0.85, 1.0, 1.0), (255, 255, 255)
    else:
        fill, border, col = (0.06, 0.09, 0.16, 0.85), (0.35, 0.42, 0.6, 0.6), (215, 222, 238)
    hud.border_panel(x, y, w, h, fill, border, 2)
    hud.text_center(x + w // 2, y + h // 2 - 12, label, 19, col, "ui")


# ── in-game HUD ────────────────────────────────────────────────────────────────
def draw_hud(hud, world, selected, speed, running, preview, mouse, show_help, net, players,
             avatar_labels=None):
    hud.begin()
    W, H = hud.width, hud.height
    _draw_mode_badges(hud, world, W, mouse)
    _draw_status_card(hud, world, running, speed)
    if net is not None:
        _draw_coop(hud, W, net, players)
    for sx, sy, name, col in (avatar_labels or []):
        hud.text(int(sx) + 12, int(sy) - 10, name, 14, col, "ui")
    if world.mode in ("creative", "survival"):
        _draw_hotbar(hud, world, selected, W, H, mouse)
        _draw_tooltip(hud, world, selected, preview, mouse)
    if world.message_t > 0.0 and world.message:
        hud.text_center(W // 2, H // 2 - 90, world.message, 30, (255, 175, 150), "ui")
    hud.text(14, H - 24, "H: help    ·    L: land on a planet    ·    Esc: menu",
             15, (150, 160, 175), "body")
    if show_help:
        _draw_help(hud, world, W, H)
    hud.end()


def _draw_coop(hud, W, net, players):
    online = len(players) if players else 0
    label = f"CO-OP  ·  {online} online" if net.status == "connected" else f"CO-OP  ·  {net.status}"
    tw, _ = hud.measure(label, 16, "ui")
    x = W - tw - 34
    hud.border_panel(x - 14, 54, tw + 28, 34, (0.05, 0.10, 0.08, 0.8), (0.4, 0.8, 0.6, 0.7), 2)
    hud.text(x, 61, label, 16, (150, 240, 190), "ui")
    if net.status not in ("connected",):
        hud.text_center(W // 2, hud.height // 2,
                        "Connecting…" if net.status == "connecting" else f"Connection {net.status}",
                        26, (255, 220, 160), "ui")


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
        ("Drag / Scroll", "rotate view / zoom"),
        ("+ / -  ·  Space", "change speed / pause"),
        ("F11  ·  Esc", "fullscreen / back to menu"),
        ("L  /  right-click", "land on a planet — first-person mode"),
        ("Co-op", "Host or Join from the menu to play together"),
    ]
    pw, ph = 640, 44 + 30 * len(lines) + 40
    px, py = (W - pw) // 2, (H - ph) // 2
    hud.border_panel(px, py, pw, ph, (0.03, 0.04, 0.08, 0.93), (0.5, 0.6, 0.9, 0.85), 3)
    hud.text_center(W // 2, py + 16, "HOW TO PLAY", 24, (255, 230, 150), "title")
    y = py + 56
    for key, desc in lines:
        hud.text(px + 28, y, key, 16, (140, 210, 255), "ui")
        hud.text(px + 250, y, desc, 16, (205, 212, 228), "body")
        y += 30
    hud.text_center(W // 2, py + ph - 30,
                    "Survival tip: build near the Sun's habitable zone for more energy.",
                    15, (170, 180, 200), "body")


def draw_surface_hud(hud, surf, W, H):
    hud.begin()
    cx, cy = W // 2, H // 2
    ch = (0.9, 0.95, 1.0, 0.85)
    hud.panel(cx - 1, cy - 10, 2, 20, ch)
    hud.panel(cx - 10, cy - 1, 20, 2, ch)

    hud.text(14, 12, "WASD move   ·   mouse look   ·   click attack   ·   1-4 craft   ·   Esc leave",
             15, (165, 175, 195), "body")

    # Health card.
    hud.border_panel(14, H - 96, 320, 82)
    hud.text(26, H - 90, "HEALTH", 15, (255, 185, 175), "ui")
    frac = max(0.0, min(1.0, surf.hp / PLAYER_MAX_HP))
    hud.panel(26, H - 66, 296, 16, (0.12, 0.05, 0.05, 0.9))
    hud.panel(26, H - 66, int(296 * frac), 16,
              (0.9, 0.25, 0.25, 0.95) if frac < 0.4 else (0.3, 0.85, 0.4, 0.95))
    hud.text(30, H - 65, f"{int(surf.hp)}/{int(PLAYER_MAX_HP)}", 13, (255, 255, 255), "body")
    hud.text(26, H - 42,
             f"{WEAPONS[surf.weapon]['name']}   |   {ARMORS[surf.armor]['name']}   |   Kills {surf.kills}",
             14, (210, 215, 225), "body")

    # Inventory strip (bottom-centre).
    n = len(ITEM_ORDER)
    sw, gap = 70, 8
    x0 = (W - (n * sw + (n - 1) * gap)) // 2
    y = H - 64
    for i, item in enumerate(ITEM_ORDER):
        x = x0 + i * (sw + gap)
        hud.border_panel(x, y, sw, 50, (0.05, 0.06, 0.10, 0.82), (0.3, 0.34, 0.5, 0.6), 2)
        c = ITEM_COLOR[item]
        hud.panel(x + 8, y + 7, sw - 16, 20, (c[0], c[1], c[2], 1.0))
        hud.text_center(x + sw // 2, y + 31, f"{item} {surf.inv.get(item, 0)}", 11, (220, 225, 235), "body")

    # Crafting list (bottom-right).
    pw, ph = 300, 24 * len(RECIPE_ORDER) + 36
    x, cy2 = W - pw - 14, H - ph - 14
    hud.border_panel(x, cy2, pw, ph, (0.04, 0.05, 0.09, 0.82), (0.4, 0.46, 0.65, 0.6), 2)
    hud.text(x + 14, cy2 + 8, "CRAFT  (press 1-4)", 14, (255, 230, 150), "ui")
    yy = cy2 + 34
    for i, key in enumerate(RECIPE_ORDER):
        can = surf.can_craft(key)
        cost = "  ".join(f"{k}x{v}" for k, v in RECIPES[key][1].items())
        col = (150, 255, 180) if can else (150, 155, 165)
        hud.text(x + 14, yy, f"[{i+1}] {RECIPE_LABEL[key]}", 13, col, "body")
        hud.text(x + pw - 96, yy, cost, 11, (175, 182, 198), "body")
        yy += 24

    if surf.message_t > 0 and surf.message:
        hud.text_center(W // 2, 118, surf.message, 24, (255, 210, 170), "ui")

    if surf.dead:
        hud.panel(0, 0, W, H, (0.35, 0.02, 0.02, 0.4))
        hud.text_center(W // 2, H // 2 - 30, "YOU DIED", 60, (255, 120, 110), "title")
        hud.text_center(W // 2, H // 2 + 40, "Press Esc to return to space", 22, (235, 200, 200), "ui")

    hud.end()


if __name__ == "__main__":
    main()
