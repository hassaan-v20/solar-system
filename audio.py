"""Procedural audio: synthesized sound effects + a soothing ambient music loop.

Everything is generated with numpy and fed to pygame.mixer as in-memory sounds,
so there are no audio files to ship or license. Degrades gracefully (silently)
if the machine has no audio device.
"""

import numpy as np
import pygame

SR = 44100


def _adsr(n, attack, release):
    env = np.ones(n, dtype=np.float32)
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    env[:a] = np.linspace(0.0, 1.0, a)
    env[-r:] *= np.linspace(1.0, 0.0, r)
    return env


def _tone(freq, dur, kind="perc", detune=0.0):
    n = int(SR * dur)
    t = np.linspace(0.0, dur, n, False, dtype=np.float32)
    sig = np.sin(2 * np.pi * freq * t)
    if detune:
        sig += 0.6 * np.sin(2 * np.pi * (freq * (1 + detune)) * t)
    if kind == "perc":
        env = np.exp(-t * (3.0 / dur))
    elif kind == "bell":
        sig += 0.5 * np.sin(2 * np.pi * freq * 2.01 * t)
        env = np.exp(-t * (3.5 / dur))
    else:  # smooth
        env = _adsr(n, 0.1, 0.3)
    return (sig * env).astype(np.float32)


def _sweep(f0, f1, dur, kind="perc"):
    n = int(SR * dur)
    t = np.linspace(0.0, dur, n, False, dtype=np.float32)
    freq = np.linspace(f0, f1, n)
    phase = np.cumsum(2 * np.pi * freq / SR)
    sig = np.sin(phase).astype(np.float32)
    env = np.exp(-t * (2.5 / dur)) if kind == "perc" else _adsr(n, 0.2, 0.3)
    return sig * env


def _noise(dur, decay=8.0, lp=0.4):
    n = int(SR * dur)
    rng = np.random.default_rng(7)
    x = rng.uniform(-1, 1, n).astype(np.float32)
    # cheap low-pass
    b = lp
    for i in range(1, n):
        x[i] = b * x[i] + (1 - b) * x[i - 1]
    t = np.linspace(0.0, dur, n, False, dtype=np.float32)
    return x * np.exp(-t * decay)


def _arp(freqs, step=0.10, kind="bell"):
    parts = [_tone(f, step * 2.4, kind) for f in freqs]
    out = np.zeros(int(SR * (step * (len(freqs) - 1) + step * 2.4)) + 1, dtype=np.float32)
    for i, p in enumerate(parts):
        s = int(SR * step * i)
        out[s:s + len(p)] += p
    return out


def _norm(sig, peak=0.9):
    m = float(np.max(np.abs(sig))) or 1.0
    return (sig / m) * peak


class Audio:
    def __init__(self):
        self.enabled = False
        self.muted = False
        self.sounds = {}
        self.music = None
        self._music_chan = None
        try:
            pygame.mixer.quit()
            pygame.mixer.init(frequency=SR, size=-16, channels=2, buffer=512)
            pygame.mixer.set_num_channels(24)
            self._build_sfx()
            self._build_music()
            self.enabled = True
        except Exception as e:
            print("[audio] disabled:", e)

    def _snd(self, mono, vol=0.7):
        arr = np.clip(_norm(mono) * vol, -1, 1)
        stereo = np.repeat((arr * 32767).astype(np.int16)[:, None], 2, axis=1)
        return pygame.mixer.Sound(buffer=stereo.tobytes())

    def _build_sfx(self):
        s = self.sounds
        s["place"]   = self._snd(np.concatenate([_tone(660, 0.10, "bell"), _tone(990, 0.18, "bell")]), 0.5)
        s["harvest"] = self._snd(_sweep(520, 900, 0.18), 0.5)
        s["pickup"]  = self._snd(_tone(760, 0.08, "perc"), 0.45)
        s["deflect"] = self._snd(_sweep(1200, 300, 0.22) + 0.5 * _noise(0.22, 10), 0.5)
        s["swing"]   = self._snd(_noise(0.16, 14, 0.25), 0.4)
        s["kill"]    = self._snd(_sweep(420, 120, 0.30) + 0.4 * _noise(0.3, 9), 0.55)
        s["hurt"]    = self._snd(_tone(130, 0.22, "perc", 0.02) + 0.4 * _noise(0.22, 12), 0.55)
        s["craft"]   = self._snd(_arp([523, 659, 784, 1046], 0.07), 0.5)
        s["jump"]    = self._snd(_sweep(300, 620, 0.12), 0.4)
        s["levelup"] = self._snd(_arp([523, 659, 784, 1046, 1318], 0.09), 0.6)
        s["chime"]   = self._snd(np.concatenate([_tone(880, 0.14, "bell"), _tone(1318, 0.30, "bell")]), 0.5)
        s["warp"]    = self._snd(_sweep(200, 1200, 0.40, "perc") + 0.3 * _noise(0.4, 4), 0.5)
        s["click"]   = self._snd(_tone(1000, 0.04, "perc"), 0.35)

    def _build_music(self):
        # Soothing maj7 pad progression with soft bells; loops seamlessly.
        chords = [
            [261.63, 329.63, 392.00, 493.88],   # Cmaj7
            [220.00, 261.63, 329.63, 392.00],   # Am7
            [174.61, 220.00, 261.63, 329.63],   # Fmaj7
            [196.00, 246.94, 293.66, 349.23],   # G7
        ]
        seg = 8.0
        n = int(SR * seg)
        t = np.linspace(0.0, seg, n, False, dtype=np.float32)
        swell = (0.5 - 0.5 * np.cos(2 * np.pi * t / seg))      # gentle in/out per chord
        vib = 1.0 + 0.004 * np.sin(2 * np.pi * 0.2 * t)
        track = []
        rng = np.random.default_rng(3)
        for ci, chord in enumerate(chords):
            pad = np.zeros(n, dtype=np.float32)
            for f in chord:
                pad += np.sin(2 * np.pi * f * vib * t)
                pad += 0.5 * np.sin(2 * np.pi * f * 1.005 * t)   # detune for width
            pad *= swell / (len(chord) * 1.5)
            # a couple of soft bell notes drifting over the pad
            bell = np.zeros(n, dtype=np.float32)
            for _ in range(2):
                f = chord[int(rng.integers(len(chord)))] * 2.0
                st = int(rng.uniform(0.1, 0.6) * n)
                b = _tone(f, 2.2, "bell")
                end = min(n, st + len(b))
                bell[st:end] += b[:end - st]
            track.append(pad + 0.18 * bell)
        full = np.concatenate(track)
        full = _norm(full, 0.5)
        stereo = np.repeat((full * 32767).astype(np.int16)[:, None], 2, axis=1)
        # widen: tiny delay on right channel
        d = 600
        stereo[d:, 1] = stereo[:-d, 1]
        self.music = pygame.mixer.Sound(buffer=stereo.tobytes())

    # ── API ──────────────────────────────────────────────────────────────────────
    def play(self, name):
        if not self.enabled or self.muted:
            return
        snd = self.sounds.get(name)
        if snd:
            snd.play()

    def start_music(self):
        if self.enabled and self.music and self._music_chan is None:
            self._music_chan = self.music.play(loops=-1)
            if self._music_chan:
                self._music_chan.set_volume(0.0 if self.muted else 0.30)

    def toggle_mute(self):
        self.muted = not self.muted
        if self._music_chan:
            self._music_chan.set_volume(0.0 if self.muted else 0.30)
        return self.muted
