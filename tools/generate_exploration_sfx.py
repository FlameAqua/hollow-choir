#!/usr/bin/env python3
"""Original soft stone tones; uses the existing material synthesis, without external samples.

Writes only three new WAVs and their own manifest, preserving the existing palette.
"""
import json
from pathlib import Path
from generate_placeholder_sfx import CLAY, finish, mix, modal, room, write

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/sfx"


def main():
    cues = []
    for name, frequency in (("rune_low", 220), ("rune_mid", 330), ("rune_high", 440)):
        sound = room(mix(modal(frequency, .48, CLAY, decay=.115, attack=.008),
                         modal(frequency / 2, .24, decay=.05, gain=.18)), wet=.07)
        cues.append(write(OUT / f"{name}.wav", finish(sound, .135)))
    manifest = {
        "palette": "exploration_stone_v01", "date": "2026-10-10",
        "creator": "Codex / original deterministic procedural synthesis",
        "authorization": "Adrian requested V0.5 art and SFX integration on 2026-10-10",
        "recipe": "tools/generate_exploration_sfx.py", "external_samples": False,
        "sample_rate_hz": 44100, "channels": 1, "bits_per_sample": 16, "loop": False,
        "human_listening_approval": "pending",
        "measurement_note": "PCM sample peak and RMS; no audition, LUFS or true peak claim",
        "cues": cues,
    }
    (OUT / "exploration_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(cues)} new stone cues; existing palette unchanged")


if __name__ == "__main__":
    main()
