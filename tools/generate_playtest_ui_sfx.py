#!/usr/bin/env python3
"""Generate only the five original V0.5 operation cues, preserving all earlier assets."""
import json
import random
from pathlib import Path

from generate_placeholder_sfx import (
    BRONZE, CLAY, WOOD, delay, finish, friction, mix, modal, room, write,
)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/sfx"


def main():
    cues = []
    for name in ("ui_equip", "ui_unequip", "craft_smith", "craft_brew", "purchase"):
        rng = random.Random("hollow-choir-playtest-v05:" + name)
        cloth = friction(.17, rng, low=120, high=1200, gain=.35, decay=.04)
        if name == "ui_equip":
            sound = mix(cloth, delay(modal(310, .17, WOOD, decay=.035), .035))
        elif name == "ui_unequip":
            sound = mix(modal(220, .14, WOOD, decay=.028), delay(cloth, .025))
        elif name == "craft_smith":
            sound = room(mix(modal(480, .29, BRONZE, decay=.055, gain=.6),
                             modal(130, .18, WOOD, decay=.032), cloth), wet=.05)
        elif name == "craft_brew":
            sound = room(mix(modal(270, .22, CLAY, decay=.045, attack=.008),
                             delay(modal(370, .19, CLAY, decay=.033, gain=.35), .08),
                             friction(.22, rng, high=900, gain=.4, swell=True)), wet=.06)
        else:
            sound = mix(modal(410, .22, BRONZE, decay=.045, gain=.45),
                        delay(modal(205, .16, WOOD, decay=.027), .045), cloth)
        cues.append(write(OUT / f"{name}.wav", finish(sound, .14)))
    manifest = {
        "palette": "playtest_operations_v05", "date": "2026-10-10",
        "creator": "Codex / original deterministic procedural synthesis",
        "recipe": "tools/generate_playtest_ui_sfx.py", "external_samples": False,
        "sample_rate_hz": 44100, "channels": 1, "bits_per_sample": 16, "loop": False,
        "human_listening_approval": "pending",
        "measurement_note": "PCM sample peak/RMS only; no audition, LUFS or true-peak claim",
        "cues": cues,
    }
    (OUT / "playtest_operations_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(cues)} operation cues; existing palette preserved")


if __name__ == "__main__":
    main()
