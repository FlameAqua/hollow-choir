# Fixed game display contract

Director · 8 October 2026 · explicitly requested by Adrian after the V0.3 push

Design one **1280×720 game canvas**, with **22 px Departure Mono body text**. Keep the existing
five window presets: 1280×720, 1366×768, 1600×900, 1920×1080 and 2560×1440. Scale the whole canvas
uniformly; text and controls keep their proportions. This gives 33 px body text at 1080p and 44 px
at 1440p. There is no independent player text-size preference or free window resizing.

This supersedes earlier 75–200% font-size options, independently enlarged-text qualification and
arbitrary-width layout requirements in the combat, Field Guide, audio, world and art briefs. Earlier
captures/reports remain historical evidence; they are not a requirement to repeat that matrix.

Windowed mode selects only supported presets that fit the desktop work area. An oversized saved
selection falls back to a smaller supported preset, never a custom-shaped window. If none fits,
use borderless fullscreen. Fullscreen modes fill the existing display while retaining the same
16:9 game canvas, with letterboxing where required. No operating-system display-mode changer or
monitor-specific layout is needed. This follows Godot's distinction between physical window size
and the [fixed virtual canvas](https://docs.godotengine.org/en/latest/classes/class_window.html#class-window-property-content-scale-size);
[fullscreen uses the monitor size](https://docs.godotengine.org/en/latest/classes/class_displayserver.html#enum-displayserver-windowmode).

Old `display/text_scale` settings are ignored and omitted on subsequent settings writes. Difficulty,
assist, bindings, volume, motion/flashing controls and progress saves retain their current meanings.

Verification is one canonical game layout plus a basic supported-preset/output check. Do not add
phone widths, freely resizable desktop layouts or another font-size matrix. Reuse existing container
layout for content lengths and scrolling; preserving readable text does not require a new subsystem.
The conversation's map diagram is a design aid, not a supported game display or UI implementation.
