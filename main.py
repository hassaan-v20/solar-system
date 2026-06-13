import sys
import pygame
import moderngl
from camera import Camera
from scene import SolarSystem

WIDTH, HEIGHT = 1280, 720


def main():
    pygame.init()
    pygame.display.set_mode((WIDTH, HEIGHT), pygame.OPENGL | pygame.DOUBLEBUF | pygame.RESIZABLE)
    pygame.display.set_caption("Solar System — RX 6600 XT")

    ctx = moderngl.create_context()
    ctx.enable(moderngl.DEPTH_TEST | moderngl.BLEND | moderngl.PROGRAM_POINT_SIZE)
    ctx.blend_func = moderngl.SRC_ALPHA, moderngl.ONE_MINUS_SRC_ALPHA

    camera = Camera(WIDTH, HEIGHT)
    solar_system = SolarSystem(ctx)

    clock  = pygame.time.Clock()
    time   = 0.0
    speed  = 1.0
    dragging  = False
    last_pos  = (0, 0)

    while True:
        dt = clock.tick(60) / 1000.0
        time += dt * speed

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit()
                    sys.exit()
                elif event.key in (pygame.K_EQUALS, pygame.K_PLUS):
                    speed = min(speed * 2.0, 128.0)
                elif event.key == pygame.K_MINUS:
                    speed = max(speed / 2.0, 0.0625)
                elif event.key == pygame.K_r:
                    camera.reset()
                elif event.key == pygame.K_SPACE:
                    speed = 0.0 if speed != 0.0 else 1.0
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:
                    dragging = True
                    last_pos = event.pos
                elif event.button == 4:
                    camera.zoom(-4.0)
                elif event.button == 5:
                    camera.zoom(4.0)
            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1:
                    dragging = False
            elif event.type == pygame.MOUSEMOTION:
                if dragging:
                    dx = event.pos[0] - last_pos[0]
                    dy = event.pos[1] - last_pos[1]
                    camera.rotate(dx, dy)
                    last_pos = event.pos
            elif event.type == pygame.VIDEORESIZE:
                camera.resize(event.w, event.h)

        ctx.clear(0.008, 0.008, 0.022)
        solar_system.render(camera, time)
        pygame.display.flip()


if __name__ == "__main__":
    main()
