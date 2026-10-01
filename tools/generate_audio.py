#!/usr/bin/env python3
"""Generate original procedural audio for the Aurora Strike vertical slice.

No samples or third-party recordings are used. The output is deterministic 44.1 kHz
mono PCM WAV suitable for Godot's built-in importer.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "game" / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def write(name: str, samples: list[float]) -> None:
    peak = max(1.0, max(abs(v) for v in samples))
    pcm = b"".join(struct.pack("<h", int(max(-1, min(1, v / peak)) * 32767)) for v in samples)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)


def lowpass(values: list[float], strength: float) -> list[float]:
    out: list[float] = []
    state = 0.0
    for value in values:
        state += (value - state) * strength
        out.append(state)
    return out


def gunshot(name: str, seed: int, duration: float, body_hz: float, crack: float, tail: float) -> None:
    rng = random.Random(seed)
    count = int(RATE * duration)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(count)], 0.32)
    samples = []
    for i in range(count):
        t = i / RATE
        transient = math.exp(-t * 78.0) * rng.uniform(-1, 1) * crack
        body = math.sin(math.tau * (body_hz * (1.0 - t * 0.8)) * t) * math.exp(-t * 24.0)
        mechanical = math.sin(math.tau * 1650 * t) * math.exp(-t * 95.0) * 0.22
        echo = noise[i] * math.exp(-t * tail) * 0.48
        samples.append(transient + body * 0.82 + mechanical + echo)
    write(name, samples)


def click_sequence(name: str, events: list[tuple[float, float, float]], duration: float, seed: int) -> None:
    rng = random.Random(seed)
    samples = [0.0] * int(RATE * duration)
    for at, pitch, volume in events:
        start = int(at * RATE)
        length = int(0.055 * RATE)
        for j in range(length):
            i = start + j
            if i >= len(samples):
                break
            t = j / RATE
            metal = math.sin(math.tau * pitch * t) * math.exp(-t * 62)
            snap = rng.uniform(-1, 1) * math.exp(-t * 115)
            samples[i] += (metal * 0.65 + snap * 0.35) * volume
    write(name, samples)


def tone(name: str, notes: list[tuple[float, float, float]], duration: float) -> None:
    samples = [0.0] * int(RATE * duration)
    for at, hz, volume in notes:
        start = int(at * RATE)
        length = int(0.16 * RATE)
        for j in range(length):
            i = start + j
            if i >= len(samples):
                break
            t = j / RATE
            env = min(1.0, t * 90) * math.exp(-t * 18)
            samples[i] += (math.sin(math.tau * hz * t) + 0.3 * math.sin(math.tau * hz * 2 * t)) * env * volume
    write(name, samples)


def rain_loop() -> None:
    rng = random.Random(88421)
    duration = 8.0
    count = int(RATE * duration)
    raw = [rng.uniform(-1, 1) for _ in range(count)]
    broad = lowpass(raw, 0.08)
    samples = [broad[i] * 0.16 + raw[i] * 0.018 for i in range(count)]
    for _ in range(240):
        start = rng.randrange(0, count - 900)
        length = rng.randrange(180, 700)
        gain = rng.uniform(0.025, 0.09)
        for j in range(length):
            t = j / length
            samples[start + j] += math.sin(math.pi * t) * rng.uniform(-1, 1) * gain
    # Gentle crossfade makes the imported loop seamless.
    fade = int(RATE * 0.35)
    for i in range(fade):
        a = i / fade
        mixed = samples[i] * a + samples[-fade + i] * (1 - a)
        samples[i] = mixed
        samples[-fade + i] = mixed
    write("dockyard_rain.wav", samples)


gunshot("ak47_fire.wav", 4701, 0.42, 82, 1.2, 7.0)
gunshot("m4a1_fire.wav", 4702, 0.34, 104, 0.92, 9.5)
gunshot("awp_fire.wav", 4703, 0.72, 58, 1.45, 4.2)
gunshot("glock_fire.wav", 4704, 0.25, 138, 0.74, 13.0)
click_sequence("rifle_reload.wav", [(0.03, 920, 0.55), (0.38, 540, 0.78), (0.82, 1220, 0.72), (1.12, 760, 0.45)], 1.35, 81)
click_sequence("pistol_reload.wav", [(0.02, 1180, 0.48), (0.28, 680, 0.65), (0.62, 1450, 0.62)], 0.82, 82)
click_sequence("dry_fire.wav", [(0.0, 1100, 0.5)], 0.12, 83)
tone("hit_confirm.wav", [(0.0, 980, 0.33), (0.045, 1320, 0.26)], 0.20)
tone("headshot_confirm.wav", [(0.0, 1040, 0.4), (0.04, 1560, 0.34), (0.09, 2080, 0.22)], 0.25)
tone("ui_confirm.wav", [(0.0, 480, 0.24), (0.06, 720, 0.20)], 0.22)
rain_loop()
print(f"Generated {len(list(OUT.glob('*.wav')))} original WAV assets in {OUT}")
