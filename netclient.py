"""Client-side networking for Stellar co-op.

Runs an asyncio websocket connection on a background thread so the render loop
never blocks. Holds the latest server snapshot; the main loop calls get_world()
each frame, which rebuilds the World and extrapolates sim_time between snapshots
so orbital motion stays smooth at the 20 Hz broadcast rate.
"""

import asyncio
import json
import queue
import threading
import time

import websockets

from world import World


class NetClient:
    def __init__(self, url, name="Player"):
        self.url = url
        self.name = name
        self.status = "connecting"   # connecting | connected | error | closed
        self.error = ""
        self.pid = None
        self.players = []

        self._lock = threading.Lock()
        self._snapshot = None
        self._recv_mono = 0.0
        self._sendq = queue.Queue()
        self._loop = None
        self._ws = None
        self._stop = False

        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    # ── background thread ───────────────────────────────────────────────────────
    def _run(self):
        try:
            asyncio.run(self._main())
        except Exception as e:
            self.status = "error"
            self.error = str(e)

    async def _main(self):
        self._loop = asyncio.get_event_loop()
        # Retry briefly so "Host Game" works while the server is still starting.
        ws = None
        for _ in range(20):
            if self._stop:
                self.status = "closed"
                return
            try:
                ws = await websockets.connect(self.url, open_timeout=5)
                break
            except Exception as e:
                self.error = str(e)
                await asyncio.sleep(0.5)
        if ws is None:
            self.status = "error"
            return

        self._ws = ws
        self.status = "connected"
        try:
            await ws.send(json.dumps({"t": "name", "name": self.name}))
            sender = asyncio.create_task(self._sender(ws))
            async for raw in ws:
                msg = json.loads(raw)
                if msg.get("t") == "welcome":
                    self.pid = msg.get("pid")
                elif msg.get("t") == "state":
                    with self._lock:
                        self._snapshot = msg
                        self._recv_mono = time.monotonic()
                        self.players = msg.get("players", [])
            sender.cancel()
        except websockets.ConnectionClosed:
            pass
        finally:
            self.status = "closed"

    async def _sender(self, ws):
        loop = asyncio.get_event_loop()
        while True:
            msg = await loop.run_in_executor(None, self._sendq.get)
            if msg is None:
                return
            await ws.send(json.dumps(msg))

    # ── main-thread API ──────────────────────────────────────────────────────────
    def send_cmd(self, cmd):
        self._sendq.put({"t": "cmd", "cmd": cmd})

    def send_ctrl(self, action, value=None):
        self._sendq.put({"t": "ctrl", "action": action, "value": value})

    def get_world(self):
        """Return (world, sim_time, speed, running, players) or None if no snapshot yet."""
        with self._lock:
            snap = self._snapshot
            recv = self._recv_mono
            players = list(self.players)
        if snap is None:
            return None
        world, sim_time = World.from_dict(snap["world"])
        speed = snap.get("speed", 0.0)
        running = snap.get("running", True)
        if running:
            sim_time += (time.monotonic() - recv) * speed   # smooth between snapshots
        return world, sim_time, speed, running, players

    def close(self):
        self._stop = True
        self._sendq.put(None)
        if self._loop and self._ws:
            try:
                asyncio.run_coroutine_threadsafe(self._ws.close(), self._loop)
            except Exception:
                pass
