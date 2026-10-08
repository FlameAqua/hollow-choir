# Stage presentation review — 8 October 2026

Working-tree evidence for [the canonical stage contract](../../design/STAGE_PRESENTATION_REFRESH.md).
Godot 4.7.2, 1280×720, compatibility renderer. Captures use real project scenes and controls, with
the existing deterministic capture harness and reduced motion/flashing. Day background selection
overrides the shared Texture2D only in memory. No encounter data/default is changed by a review.

| View | Evidence | What was inspected |
|---|---|---|
| Title, normal / 200% | [Normal](title.png), [200%](title_200.png) | Shared stepped frame, marsh, working entry actions, focus/scroll |
| Glyph specimen | [22 / 33 / 44 px](font.png) | G/C, 5/S, 0/O, 1/I/l; clear pixel edges |
| Planning, night default | [Normal](planning.png) | Full-size mixed enemies, red HP, thin break bars, common feet |
| Day pairs | [Day 1](day_1.png), [Day 2 at 150%](day_2_150.png), [Day 3 at 200%](day_3_200.png) | Actual crop/footing, mixed cast, Flooded Ground/Spore Fog tint, larger text |
| Broken / exposed | [Separate](states.png), [Together at 200%](states_both_200.png) | Static cracks/bullseye, normal labels/enlarged icon, intent-strip separation |
| Defeated cast | [Thornhound/Bogshell/Fen Wisp](dead_fen.png), [Penitent/Sporecaller/Brute](dead_fungal.png), [Bogwife/Bramblejaw/Cantor](dead_elites.png) | All nine own poses, stable foot plane, dim visible corpses, no corpse HP tracks |
| Defense | [Normal](reaction.png), [200%](reaction_200.png), [Flooded at 200%](reaction_flooded_200.png) | Fixed impact meter, keys and legal reactions, readable effect/risk, bounded caveat scrolling |
| Attack | [Normal](attack.png), [200%](attack_200.png) | Separate title/instruction, visible real timing meter, feedback above residual floating text |

Exact final capture arguments are in [captures.json](captures.json). State/defeated reviews set
**artificial PresentationLedger flags** after the harness reaches planning. Those images verify art
and layout only: their engine target preview/intent may still describe the original living state.
They are not gameplay kills, evidence that a corpse can be targeted, or future-rule demonstrations.
Automated event/eligibility tests provide that separate regression evidence. Timing captures hold
the existing clock near impact for visual review; they do not measure human reaction success.

Validation: **173 scripts checked, 0 failed. 147 tests passed, 0 failed, 1010 assertions.** The five
new stage tests cover ledger-driven life selection despite HP tween state, retained instance IDs
with living-target exclusion, all nine dead frames, stable mixed-cast footing and enlarged title
focus/scroll. Existing input, timing, knowledge, preview, engine and save tests remain passing.
The suite intentionally logs invalid-save errors and one rejected illegal action; its error logger
reports no unexpected failures. Editor import completed, with a sandbox editor-settings safe-save
warning; runtime capture and script checks had no engine/script errors.

Six environment PNGs and twelve generated refresh deliveries match their recorded dimensions and
SHA-256 hashes; all nine dead SpriteFrames load. PNG bytes are preserved unchanged. Font/texture
export dependencies are explicit. Removed environment paths remain only as historical migration keys.

Limits: these are automated/synthetic scene reviews, not a fresh-player session or final artist
approval. Full text remains in inspection when icon layouts abbreviate labels. Unusually long
reaction caveats can scroll at 200%; the meter stays fixed. Final palette/pixel cleanup, localisation,
colour-vision/contrast measurement and human READ/REACT acceptance remain open. Combat frame textures
and five nondefault backgrounds are available for explicit assignment; no automatic cycling, corpse
gameplay or day/night simulation is added.
