#!/usr/bin/env python3
"""Synthesises placeholder combat sounds into assets/audio/sfx/ (stdlib only).

These exist so every mechanic has audio feedback while the combat feel is evaluated. They follow
the GDD sound brief (anticipation / impact / result; parry = glass-metal ring; Stagger break = deep
crack, short silence, heavy tail; no casino-like reward jingles) and are meant to be replaced by
real sound design. Re-run after editing: python3 tools/generate_placeholder_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
random.seed(7)


def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def tone(freq, t):
    return math.sin(2 * math.pi * freq * t)


def noise():
    return random.uniform(-1.0, 1.0)


def render(duration, fn):
    n = int(duration * RATE)
    return [fn(i / RATE) for i in range(n)]


def lowpass(samples, alpha):
    out, prev = [], 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def write(name, samples, gain=0.8):
    peak = max(1e-6, max(abs(s) for s in samples))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * gain)) * 32767)) for s in samples)
        f.writeframes(frames)


def sweep(f0, f1, duration, attack=0.005, decay=0.08):
    phase = [0.0]

    def fn(t):
        f = f0 + (f1 - f0) * (t / duration)
        phase[0] += 2 * math.pi * f / RATE
        return math.sin(phase[0]) * env(t, attack, decay)
    return render(duration, fn)


def main():
    os.makedirs(OUT, exist_ok=True)
    # UI: soft tactile clicks (wood / glass / muted bell).
    write("ui_move", render(0.045, lambda t: tone(1300, t) * env(t, 0.002, 0.012)), 0.35)
    write("ui_confirm", mix(render(0.09, lambda t: tone(660, t) * env(t, 0.002, 0.03)),
                            [0] * 1800 + render(0.07, lambda t: tone(990, t) * env(t, 0.002, 0.03))), 0.45)
    write("ui_cancel", sweep(700, 420, 0.1, decay=0.04), 0.4)
    # Impacts.
    hit_noise = lowpass(render(0.12, lambda t: noise() * env(t, 0.001, 0.03)), 0.35)
    thump = render(0.14, lambda t: tone(110 - 300 * t, t) * env(t, 0.002, 0.05))
    write("hit", mix(hit_noise, thump), 0.75)
    heavy_noise = lowpass(render(0.25, lambda t: noise() * env(t, 0.001, 0.06)), 0.18)
    heavy_thump = render(0.3, lambda t: tone(70 - 80 * t, t) * env(t, 0.003, 0.11))
    write("hit_heavy", mix(heavy_noise, heavy_thump), 0.9)
    write("weakness", mix(hit_noise, thump, render(0.2, lambda t: 0.5 * tone(1568, t) * env(t, 0.002, 0.06))), 0.8)
    # Execution grades: brighter for better, never a jackpot jingle.
    write("perfect", mix(render(0.25, lambda t: tone(1760, t) * env(t, 0.002, 0.07)),
                         render(0.25, lambda t: 0.6 * tone(2637, t) * env(t, 0.002, 0.05)),
                         render(0.25, lambda t: 0.25 * noise() * env(t, 0.001, 0.015))), 0.6)
    write("good", render(0.08, lambda t: tone(1100, t) * env(t, 0.002, 0.025)), 0.45)
    write("miss", lowpass(render(0.12, lambda t: noise() * env(t, 0.002, 0.04)), 0.08), 0.5)
    # Reactions.
    write("parry", mix(render(0.45, lambda t: tone(1210, t) * env(t, 0.001, 0.12)),
                       render(0.45, lambda t: 0.7 * tone(2420, t) * env(t, 0.001, 0.08)),
                       render(0.45, lambda t: 0.5 * tone(3157, t) * env(t, 0.001, 0.05)),
                       render(0.45, lambda t: 0.4 * noise() * env(t, 0.0005, 0.01))), 0.75)
    write("brace", mix(render(0.16, lambda t: tone(180, t) * env(t, 0.002, 0.04)),
                       lowpass(render(0.16, lambda t: noise() * env(t, 0.001, 0.02)), 0.2)), 0.7)
    write("evade", [s * 0.8 for s in lowpass(render(0.22, lambda t: noise() * math.sin(math.pi * t / 0.22)), 0.12)], 0.55)
    # Stagger break: deep crack, ceramic shards, short silence, heavy tail.
    crack = mix(render(0.18, lambda t: tone(55, t) * env(t, 0.002, 0.08)),
                render(0.18, lambda t: noise() * env(t, 0.0005, 0.025)),
                render(0.18, lambda t: 0.5 * tone(2900 + 400 * math.sin(90 * t), t) * env(t, 0.001, 0.03)))
    tail = render(0.5, lambda t: tone(48, t) * env(t, 0.01, 0.2))
    write("break", crack + [0.0] * int(0.08 * RATE) + tail, 0.95)
    # Status / support.
    write("status", mix(sweep(300, 520, 0.15, decay=0.06), render(0.15, lambda t: 0.3 * noise() * env(t, 0.002, 0.03))), 0.45)
    write("heal", mix(render(0.35, lambda t: tone(523, t) * env(t, 0.02, 0.15)),
                      [0] * 3000 + render(0.3, lambda t: tone(784, t) * env(t, 0.02, 0.12))), 0.45)
    write("focus", render(0.12, lambda t: tone(1480, t) * env(t, 0.002, 0.04)), 0.35)
    # Enemy telegraphs: a clear two-pulse warning and a low swelling channel hum.
    write("telegraph", mix(render(0.06, lambda t: tone(880, t) * env(t, 0.002, 0.02)),
                           [0] * 4400 + render(0.06, lambda t: tone(880, t) * env(t, 0.002, 0.02))), 0.5)
    write("channel", render(0.5, lambda t: (tone(98, t) + 0.5 * tone(147, t)) * math.sin(math.pi * t / 0.5)), 0.55)
    # Command helpers.
    write("beat", lowpass(render(0.05, lambda t: noise() * env(t, 0.0005, 0.008)), 0.6), 0.5)
    write("charge", sweep(220, 660, 0.3, attack=0.02, decay=0.5), 0.35)
    # Outcomes: restrained, not celebratory casino sounds.
    notes = [392, 494, 587]
    victory = []
    for index, f in enumerate(notes):
        victory = mix(victory, [0] * int(index * 0.16 * RATE) + render(0.45, lambda t, f=f: tone(f, t) * env(t, 0.01, 0.18)))
    write("victory", victory, 0.5)
    defeat = mix(render(0.5, lambda t: tone(196, t) * env(t, 0.02, 0.25)),
                 [0] * int(0.3 * RATE) + render(0.6, lambda t: tone(147, t) * env(t, 0.02, 0.3)))
    write("defeat", defeat, 0.5)
    print("wrote", len(os.listdir(OUT)), "files to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
