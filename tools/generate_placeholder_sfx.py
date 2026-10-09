#!/usr/bin/env python3
"""Build Hollow Choir's soft material SFX palette (Python standard library only).

The historical filename remains the regeneration entry point. The original 22 cue names and
meanings stay fixed; three material footsteps are appended. Modal wood, ceramic and muted bronze, filtered friction and small room
reflections replace the old arcade oscillators, pitch sweeps and ascending outcome jingles.
These are original procedural sounds, not recordings. No network or third-party samples.

    python tools/generate_placeholder_sfx.py
    python tools/generate_placeholder_sfx.py --out .godot/sfx-review --preview .godot/palette.wav

The optional preview plays every cue in CUES order, with 0.35 seconds between cues.
"""

import argparse
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/sfx"
TAU = 2 * math.pi
SEED = 9102026
CUES = (
    "ui_move", "ui_confirm", "ui_cancel", "hit", "hit_heavy", "weakness", "perfect",
    "good", "miss", "parry", "brace", "evade", "break", "status", "heal", "focus",
    "telegraph", "channel", "beat", "charge", "victory", "defeat",
    "step_peat", "step_stone", "step_wood",
)

# Inharmonic material modes: frequency ratio, weight, decay multiplier. Upper modes die first.
WOOD = ((1, 1, 1), (2.72, .32, .53), (4.93, .10, .24))
CLAY = ((1, 1, 1), (1.57, .38, .72), (2.21, .21, .43), (3.08, .08, .24))
BRONZE = ((1, 1, 1), (2.01, .30, .69), (2.76, .18, .42), (3.89, .07, .23))
SKIN = ((1, 1, 1), (1.59, .43, .57), (2.14, .16, .30))


def envelope(t, attack, decay):
    """A rounded mallet onset, exponential release; no hard oscillator gate."""
    onset = math.sin(min(1.0, t / attack) * math.pi / 2) ** 2
    return onset * math.exp(-max(0, t - attack) / decay)


def modal(freq, duration, material=WOOD, decay=.06, attack=.004, gain=1.0):
    result = [0.0] * round(duration * RATE)
    for ratio, weight, damping in material:
        hz = freq * ratio
        # Modes above the useful material band add fatigue rather than identity.
        if hz > 4200:
            continue
        for i in range(len(result)):
            t = i / RATE
            result[i] += gain * weight * math.sin(TAU * hz * t) * envelope(t, attack, decay * damping)
    return result


def lowpass(samples, cutoff):
    alpha = 1 - math.exp(-TAU * cutoff / RATE)
    previous = 0.0
    result = []
    for sample in samples:
        previous += alpha * (sample - previous)
        result.append(previous)
    return result


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [sample - bass for sample, bass in zip(samples, low)]


def friction(duration, rng, low=180, high=1700, attack=.004, decay=.035, gain=.4, swell=False):
    """Band-limited noise for felt, reed, cloth and porous material contact."""
    grain = highpass(lowpass([rng.uniform(-1, 1) for _ in range(round(duration * RATE))], high), low)
    result = []
    for i, sample in enumerate(grain):
        t = i / RATE
        shape = math.sin(math.pi * t / duration) ** 2 if swell else envelope(t, attack, decay)
        result.append(sample * gain * shape)
    return result


def mix(*tracks):
    result = [0.0] * max(len(track) for track in tracks)
    for track in tracks:
        for i, sample in enumerate(track):
            result[i] += sample
    return result


def delay(track, seconds):
    return [0.0] * round(seconds * RATE) + track


def room(track, wet=.12):
    """Subtle, dark early reflections; rhythm cues deliberately stay dry."""
    reflection = lowpass(track, 1500)
    return mix(track, *(
        delay([sample * wet * level for sample in reflection], seconds)
        for seconds, level in ((.031, 1), (.053, .55), (.089, .28))
    ))


def finish(samples, peak):
    samples = lowpass(highpass(samples, 32), 4600)
    # Fade actual endpoints after filtering/reflections. Avoid truncated tails and DC clicks.
    fade_in = round(.002 * RATE)
    fade_out = min(round(.035 * RATE), len(samples) // 4)
    for i in range(fade_in):
        samples[i] *= math.sin(i / fade_in * math.pi / 2) ** 2
    for i in range(fade_out):
        samples[-i - 1] *= math.sin(i / fade_out * math.pi / 2) ** 2
    scale = peak / max(1e-9, max(abs(sample) for sample in samples))
    return [sample * scale for sample in samples]


def palette():
    # A private RNG for each cue keeps regeneration independent of build order and gameplay RNG.
    sounds = {}
    for name in CUES:
        rng = random.Random(f"{SEED}:{name}")

        def grain(duration, **kwargs):
            return friction(duration, rng, **kwargs)

        if name == "ui_move":
            track = mix(modal(310, .09, decay=.018), grain(.065, gain=.45, decay=.012))
            peak = .12
        elif name == "ui_confirm":
            track = room(mix(modal(370, .19, decay=.043),
                             modal(550, .23, CLAY, decay=.060, gain=.28), grain(.075, gain=.3)))
            peak = .18
        elif name == "ui_cancel":
            track = mix(modal(205, .16, decay=.033), grain(.14, high=1000, gain=.55, decay=.025))
            peak = .14
        elif name == "hit":
            track = mix(modal(142, .23, decay=.052), modal(88, .22, SKIN, decay=.048, gain=.5),
                        grain(.15, high=2400, gain=1.9, decay=.026, attack=.002))
            peak = .29
        elif name == "hit_heavy":
            track = room(mix(modal(96, .38, SKIN, decay=.085), modal(255, .22, WOOD, gain=.48),
                             grain(.23, low=130, high=2000, gain=2.5, decay=.042)), wet=.06)
            peak = .35
        elif name == "weakness":
            track = room(mix(modal(142, .24, decay=.058), grain(.16, high=2300, gain=1.9),
                             modal(620, .35, BRONZE, decay=.10, gain=.42)), wet=.08)
            peak = .31
        elif name == "perfect":
            track = room(mix(modal(660, .34, BRONZE, decay=.105, attack=.005),
                             modal(330, .19, WOOD, gain=.32), grain(.06, gain=.25)), wet=.10)
            peak = .23
        elif name == "good":
            track = mix(modal(370, .17, CLAY, decay=.040), grain(.06, gain=.28))
            peak = .17
        elif name == "miss":
            track = mix(grain(.16, low=120, high=950, gain=1, decay=.037),
                        modal(125, .12, WOOD, decay=.023, gain=.13))
            peak = .15
        elif name == "parry":
            track = room(mix(modal(740, .52, BRONZE, decay=.16, attack=.003),
                             modal(465, .27, CLAY, decay=.075, gain=.38),
                             grain(.11, low=500, high=3200, gain=1.15, decay=.018)), wet=.10)
            peak = .31
        elif name == "brace":
            track = mix(modal(135, .23, SKIN, decay=.045), modal(235, .15, WOOD, gain=.4),
                        grain(.12, high=1300, gain=1.4, decay=.022))
            peak = .27
        elif name == "evade":
            track = grain(.25, low=320, high=1800, gain=1, swell=True)
            peak = .19
        elif name == "break":
            crack = mix(modal(125, .12, WOOD, decay=.025), modal(475, .12, CLAY, decay=.021, gain=.5),
                        grain(.12, high=2600, gain=3.2, decay=.017, attack=.002))
            # Let the crack finish before the low, porous body falls away.
            crack = finish(crack, .34)
            tail = mix(modal(76, .52, SKIN, decay=.14, attack=.007, gain=.8),
                       grain(.41, low=80, high=850, gain=1.2, decay=.10, attack=.009))
            track = mix(crack, delay(tail, .155))
            peak = .37
        elif name == "status":
            track = room(mix(grain(.30, low=160, high=1250, gain=1, decay=.07, attack=.012),
                             modal(207, .33, CLAY, decay=.085, attack=.011, gain=.25)), wet=.07)
            peak = .19
        elif name == "heal":
            track = room(mix(modal(392, .79, CLAY, decay=.23, attack=.015),
                             modal(523.25, .79, BRONZE, decay=.20, attack=.018, gain=.35),
                             grain(.55, low=260, high=1500, gain=.40, swell=True)), wet=.13)
            peak = .21
        elif name == "focus":
            track = room(mix(modal(440, .23, CLAY, decay=.062, attack=.006),
                             grain(.10, gain=.16)), wet=.06)
            peak = .16
        elif name == "telegraph":
            # Same two-pulse warning; prompt, rounded onset and a dry gap remain easy to locate.
            tap = mix(modal(460, .065, CLAY, decay=.016, attack=.003), grain(.05, gain=.6, decay=.012))
            track = mix(tap, delay([sample * .90 for sample in tap], .100))
            peak = .27
        elif name == "channel":
            track = room(mix(modal(174.6, .52, CLAY, decay=.32, attack=.065),
                             modal(177.1, .52, SKIN, decay=.28, attack=.07, gain=.28),
                             grain(.45, high=1200, gain=.40, swell=True)), wet=.08)
            peak = .22
        elif name == "beat":
            track = mix(modal(270, .065, WOOD, decay=.013, attack=.002),
                        grain(.045, low=200, high=1700, gain=.8, decay=.009, attack=.002))
            peak = .21
        elif name == "charge":
            track = mix(grain(.34, low=200, high=1400, gain=.85, swell=True),
                        modal(220, .34, BRONZE, decay=.25, attack=.11, gain=.24))
            peak = .18
        elif name == "victory":
            # Simultaneous open fifth, a breath of relief; no escalating melody or fanfare.
            track = room(mix(modal(196, 1.46, CLAY, decay=.37, attack=.018),
                             modal(293.66, 1.46, BRONZE, decay=.32, attack=.022, gain=.48),
                             modal(392, 1.21, BRONZE, decay=.27, attack=.024, gain=.16),
                             grain(.70, high=1300, gain=.28, swell=True)), wet=.15)
            peak = .23
        elif name == "defeat":
            track = room(mix(modal(130.81, 1.22, WOOD, decay=.30, attack=.025),
                             modal(196, 1.22, CLAY, decay=.32, attack=.027, gain=.42),
                             grain(.59, low=120, high=950, gain=.50, swell=True)), wet=.12)
            peak = .20
        elif name == "step_peat":
            # Soft sole compression followed by damp earth releasing; no ringing modes.
            track = mix(grain(.25, low=45, high=420, gain=1.7, decay=.070, attack=.022),
                        delay(grain(.19, low=140, high=1050, gain=.40, swell=True), .040))
            peak = .085
        elif name == "step_stone":
            # Dusty worn path: rounded sole contact and a short grit scuff, not a ceramic tap.
            track = mix(grain(.20, low=60, high=650, gain=1.2, decay=.045, attack=.015),
                        delay(grain(.17, low=380, high=1700, gain=.27, swell=True), .022))
            peak = .09
        elif name == "step_wood":
            track = mix(modal(95, .18, WOOD, decay=.020, gain=.08, attack=.012),
                        grain(.21, low=55, high=750, gain=1.3, decay=.050, attack=.017))
            peak = .085
        else:
            raise ValueError(name)
        sounds[name] = finish(track, peak)
    return sounds


def write(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = [round(sample * 32767) for sample in samples]
    frames = struct.pack(f"<{len(samples)}h", *pcm)
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(frames)
    peak = max(abs(sample) for sample in pcm) / 32768
    rms = math.sqrt(sum(sample * sample for sample in pcm) / len(pcm)) / 32768
    return {
        "file": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "frames": len(samples),
        "duration_seconds": round(len(samples) / RATE, 6),
        "sample_peak_dbfs": round(20 * math.log10(peak), 2),
        "rms_dbfs": round(20 * math.log10(rms), 2),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    sounds = palette()
    measurements = [write(args.out / f"{name}.wav", sounds[name]) for name in CUES]
    manifest = {
        "palette": "soft_material_v02",
        "date": "2026-10-09",
        "creator": "Codex / original deterministic procedural synthesis",
        "authorization": "Adrian requested replacing arcade-style SFX with a soothing palette on 2026-10-09",
        "recipe": "tools/generate_placeholder_sfx.py",
        "seed": SEED,
        "sample_rate_hz": RATE,
        "channels": 1,
        "bits_per_sample": 16,
        "loop": False,
        "external_samples": False,
        "human_listening_approval": "pending",
        "measurement_note": "PCM sample peaks and whole-file RMS, not LUFS or true-peak measurements",
        "cues": measurements,
    }
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if args.preview:
        preview = [0.0] * round(.2 * RATE)
        for name in CUES:
            preview.extend(sounds[name])
            preview.extend([0.0] * round(.35 * RATE))
        write(args.preview, preview)
        print(f"Preview: {args.preview.resolve()} ({len(preview) / RATE:.2f}s)")
    print(f"Wrote {len(measurements)} cues and manifest to {args.out.resolve()}")


if __name__ == "__main__":
    main()
