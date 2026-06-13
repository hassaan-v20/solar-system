"""Authoritative co-op server for Stellar.

Owns the one true World and simulation clock. Clients send commands (place /
deflect) and control messages (pause / speed / mode); the server applies them,
advances the simulation, and broadcasts state snapshots ~20x/sec to everyone.
Because the World is deterministic from its state + clock, every client that
renders the latest snapshot sees the same universe.

Run:   python server.py --mode creative --port 8765
The host then shares their address (see README for internet play).
"""

import argparse
import asyncio
import json
import time

import websockets

from world import World


class GameServer:
    def __init__(self, mode, password=""):
        self.password = password
        self.world = World(mode)
        self.sim_time = 0.0
        self.speed = 1.0 if mode == "explore" else 0.10
        self.running = True
        self.clients = {}        # websocket -> {"pid", "name"}
        self.next_pid = 1

    async def handler(self, ws, path=None):
        # First message must authenticate.
        try:
            msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
        except Exception:
            return
        if msg.get("t") != "auth" or (self.password and msg.get("password", "") != self.password):
            try:
                await ws.send(json.dumps({"t": "denied", "reason": "Wrong or missing password"}))
            except Exception:
                pass
            return

        pid = self.next_pid
        self.next_pid += 1
        name = str(msg.get("name") or f"Player{pid}")[:16]
        self.clients[ws] = {"pid": pid, "name": name, "pos": None, "cursor": None}
        await ws.send(json.dumps({"t": "welcome", "pid": pid, "mode": self.world.mode}))
        self.world.notify(f"{name} joined")
        print(f"[server] {name} connected ({len(self.clients)} online)")
        try:
            async for raw in ws:
                try:
                    self.on_message(ws, json.loads(raw))
                except Exception as e:
                    print("[server] bad message:", e)
        except websockets.ConnectionClosed:
            pass
        finally:
            info = self.clients.pop(ws, {})
            self.world.notify(f"{info.get('name', 'A player')} left")
            print(f"[server] {info.get('name')} disconnected ({len(self.clients)} online)")

    def on_message(self, ws, msg):
        info = self.clients.get(ws, {})
        t = msg.get("t")
        if t == "cmd":
            cmd = msg.get("cmd", {})
            if cmd.get("type") == "place":
                cmd["owner"] = info.get("name", "")
                ok = self.world.apply(cmd)
                if ok:
                    self.world.notify(f"{info.get('name')} added a {cmd.get('body')}")
            else:
                self.world.apply(cmd)
        elif t == "ctrl":
            action = msg.get("action")
            if action == "pause":
                self.running = False
            elif action == "resume":
                self.running = True
            elif action == "speed":
                self.speed = max(0.02, min(64.0, float(msg.get("value", self.speed))))
            elif action == "mode":
                self.world = World(msg.get("value", "creative"))
                self.sim_time = 0.0
                self.world.notify(f"{info.get('name')} switched to {self.world.mode}")
        elif t == "cam":
            info["pos"] = msg.get("pos")
            info["cursor"] = msg.get("cursor")

    def snapshot(self):
        return json.dumps({
            "t": "state",
            "world": self.world.to_dict(self.sim_time),
            "speed": self.speed,
            "running": self.running,
            "players": [{"pid": c["pid"], "name": c["name"],
                         "pos": c["pos"], "cursor": c["cursor"]}
                        for c in self.clients.values()],
        })

    async def ticker(self):
        last = time.monotonic()
        since_broadcast = 0.0
        while True:
            now = time.monotonic()
            dt = now - last
            last = now
            if self.running:
                self.sim_time += dt * self.speed
            self.world.tick(dt, self.sim_time, self.running)

            since_broadcast += dt
            if since_broadcast >= 0.05 and self.clients:   # 20 Hz
                since_broadcast = 0.0
                data = self.snapshot()
                await asyncio.gather(*(ws.send(data) for ws in list(self.clients)),
                                     return_exceptions=True)
            await asyncio.sleep(1 / 60)


async def run(mode, host, port, password):
    server = GameServer(mode, password)
    lock = "password-protected" if password else "open (no password)"
    print(f"[server] Stellar co-op ({mode}, {lock}) listening on {host}:{port}")
    async with websockets.serve(server.handler, host, port):
        await server.ticker()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="creative", choices=["explore", "creative", "survival"])
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--password", default="")
    args = ap.parse_args()
    try:
        asyncio.run(run(args.mode, args.host, args.port, args.password))
    except KeyboardInterrupt:
        print("\n[server] shutting down")
