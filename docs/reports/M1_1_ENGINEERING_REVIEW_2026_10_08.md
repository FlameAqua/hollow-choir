# M1.1 engineering review — icon-first UI, stage refresh and audio intake

**Claude (Lead Gameplay Engineer), 8 October 2026.** Working tree on `dev` (HEAD `6e4c554` plus
uncommitted work by both agents); Godot `4.7.2.stable.official.ed1daf0bf`. Nothing was committed.
Answers [the icon-first integration brief](../briefs/ICON_FIRST_UI_INTEGRATION.md), the
[stage contract](../design/STAGE_PRESENTATION_REFRESH.md) / [stage evidence](stage_refresh/README.md)
and the [audio intake handoff](../briefs/AUDIO_DELIVERY_INTAKE.md).

**All evidence below is automated and headless.** No fresh-player READ/REACT session, physical
controller, screen reader, colour-vision review or music listening took place; those gates stay open.

## Verdict

- The stage refresh meets its automated acceptance checks. One engineering defect was found and
  fixed: the **intent rail could run ahead of playback** (Inspect rebuilt every slot from the
  already-resolved engine state; round starts and intent declarations used resolved life).
- **UI layout findings R1–R4 are reported, not changed** (ChatGPT owns layout). The material ones:
  at 150% the Parry card's effect/risk lines sit below the reaction cards' fold in every encounter;
  at 200% the dock's frozen-clock instructions are ellipsised; long inspection text scrolls by
  mouse wheel only.
- Audio intake is consistent: six candidates, none selected, originals and comparison files
  intact, and nothing under `assets/audio/source/` is visible to Godot or referenced at runtime.
- The presentation leaks and regressions fixed during earlier today's icon-first validation are
  intact and still pass on top of the stage pass.

Combat rules, balance, timing windows, graders, save formats and data definitions are unchanged by
this work. **No rule change or design deviation is proposed**; one presentation behaviour changes
(Inspect, see question 1).

## Pillar review of the completed presentation

| Pillar | Holds | Engineering caveat |
|---|---|---|
| READ | Departure Mono is the theme default and a preloaded export dependency; enemy plates show HP digits only (break value in inspection); Broken cracks and the exposed bullseye are static, drawn together, and vanish on their own events or defeat; a corpse is legible and never takes a living lane | R1–R3 hide card and inspection text at enlarged sizes |
| REACT | Windows, graders and the input clock are untouched; the reaction cue lights only when a press would be read; reaction keys are consumed before focusable cards can act on them; the rail now never shows a turn, defeat or intent before it plays (F1–F3) | R1/R2 at 150/200% during a live window |
| ADAPT | Openings (Broken, exposed weak point, channel) come from presented ledger flags; Inspect's reveal reaches the inspected intent immediately | — |
| EXPERIMENT | Art on/off and day/night change no outcome, target or condition; tint comes only from announced conditions | Five non-default backgrounds need explicit assignment |
| AFFECT THE WORLD | Bodies persist for the battle only, by unit ID; no corpse rules, persistence or music state | Visual continuity only, as the contract states |

Only the title uses the shared `choir_v01` frame styles; combat frame/bar textures remain staged
(code-drawn), consistent with the stage contract.

## FILES CREATED/MODIFIED

Only the hunks described are mine; every listed file except the new test also carries other
uncommitted work, which was preserved.

| File | Change |
|---|---|
| `src/ui/battle/battle_event_player.gd` | **This pass.** INSPECTED re-reads only the inspected enemy's intent, and only while the engine holds that same intent in the displayed round (`_refresh_inspected_intent`). ROUND_STARTED resets and intent declarations use presented life (`_shown_alive`), not resolved life. Earlier: condition banner summary reads the ledger. |
| `src/ui/battle/presentation/presentation_ledger.gd` | Earlier: announced battlefield conditions, last stable forecast and `displayed_forecast()` (forecast omits units shown defeated; hidden once a new round starts on screen). |
| `src/ui/battle/timeline_bar.gd` | Earlier: life, Broken, channel hourglass and forecast come from the ledger / rail, not live units. |
| `src/ui/battle/condition_ribbon.gd`, `src/ui/battle/battlefield.gd` | Earlier: header icons and ground tint show announced conditions only. |
| `scenes/battle/battle_scene.gd` | Earlier: ledger/rail wiring; `pause_for_host()` so a host page opens only over a paused battle; ribbon rebuild only when its set changes. |
| `scenes/sandbox/combat_sandbox.gd` | Earlier: Setup button goes through `pause_for_host()` (`_toggle_setup`). |
| `src/ui/battle/action_picker.gd` | Earlier: `back_to_menu()`; Cancel in target review returns to the same menu. |
| `src/ui/battle/hover_inspector.gd` | Earlier: pinned ally-target details sit on the enemy half; controls outside its battle are not inspected. |
| `src/ui/battle/commands/reaction_widget.gd` | Earlier: `window_open()` uses `ReactionRules.is_success`; `invites_press()` (no NOW / bright arc while frozen); a struck key's "Unavailable" note persists 600 ms. |
| `src/ui/battle/combat_icons.gd`, `src/ui/ui_theme.gd`, `src/ui/battle/preview_panel.gd`, `src/ui/battle/unit_view.gd` | Earlier: portrait fallback without an `idle` frame; explicit default font; heal glyph only on healing rows; plate maxima from the ledger. |
| `tests/ui/test_presentation_boundaries.gd` | New suite, 12 tests (2 added this pass: rail mid-batch, corpse/state fallbacks). |
| `docs/TESTING.md`, `docs/DATA_CONTRACTS.md` | Suite table (four UI suites were missing); presentation-state rule under Runtime contracts. |

## ARCHITECTURE SUMMARY

The engine resolves a whole batch before presentation sees it (D-013). The rule this review
enforces: **while a batch plays, every widget shows `PresentationLedger` state advanced event by
event; live engine state is read only at stable points** (start, batch end, a pending request). A
mid-batch event may refresh only what it names, and only while the engine still holds that state.

The Inspect defect broke that rule: `refresh_rail()` (a stable-point rebuild) also ran on INSPECTED.
Because Inspect is a player action, the rest of its batch (enemy turns, round end, new declarations)
was already resolved, so the rail jumped ahead. Defeat presentation itself was already correct:
`UnitView.presentation_animation()` follows `ledger.alive`, set only by UNIT_DEFEATED.

## DATA CONTRACT

No Resource, schema, catalog or save field changed. `PresentationLedger` (runtime only) gained
`conditions`, `forecast`, `forecast_round` and `displayed_forecast()` earlier today; it remains the
single life/state source for presentation, as the stage contract requires. Documented in
`docs/DATA_CONTRACTS.md` §5.

## PUBLIC API

Unchanged this pass (new helpers are private). From earlier today: `PresentationLedger.conditions /
forecast / forecast_round / displayed_forecast()`, `BattleScene.pause_for_host() -> bool`,
`ActionPicker.back_to_menu()`, `ReactionWidget.window_open() / invites_press()`,
`PreviewPanel.row_icon()`, `ConditionRibbon.ledger / shown_conditions()`, `TimelineBar.ledger / rail`.

## SAVE IMPACT

None. No save, settings, progress or catalog format is touched; no migration.

## TEST PROCEDURE

```sh
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tests/run_tests.gd
```

**Results on the current tree (run alone, exit code 0): 174 scripts checked, 0 failed. 159 tests
passed, 0 failed, 1,127 assertions (20.7 s).** The stage baseline was 173 / 147 / 1,010; the
difference is the new boundary suite (one script, 12 tests, 117 assertions). As before, the suite
deliberately logs four invalid-save errors and one rejected illegal action; nothing else.

Scratch probes (not committed; they drive the real scenes headless) supplied the evidence below.

### Stage acceptance (this brief)

| Check | Evidence | Result |
|---|---|---|
| Zero-HP DAMAGE never shows death before UNIT_DEFEATED | `test_defeated_pose_follows_ledger_event…`; a per-frame playback probe compares every unit view (pose, dimming) and rail slot with the events presented so far: 28 battles (7 encounters × seeds 1–4, SMART autopilot, MIXED execution) with art on, 28 with art off, and 28 with an autopilot that Inspects whenever it can | Pass. After F1–F3, the art-off and Inspect runs (all checks) show no death, turn or intent before its event; the art-on run (before the fix, without the Acted/missed-declaration checks) showed none either. Before the fix, the Inspect run had 21 such rail frames |
| Corpses visible, never living targets | Engine target exclusion (`test_defeated_units_remain…`); the picker's targets are exactly the engine options; at 100/150/200% a reconciled defeat keeps the dead pose, 0.72 opacity, the same view rect and every other lane; inspection says "Defeated." | Pass |
| Art-disabled presentation | New `test_corpse_and_state_fallbacks…`: all nine enemies with art off and with idle art lacking a `dead` frame, plus Broken + Exposed together, draw with no engine error and keep their lane; art-off whole battles (above) | Pass |
| Consistent foot placement | `test_footing_is_shared…` (four mixed, 100%); probe: every unit's feet on one baseline in Briarfen Gauntlet at 100/150/200%; corpse anchored at the idle feet by construction | Pass |
| Text, inspection, reaction controls at 100/150/200% | Probe at a real 1280×720 root: actions ≥ 46 px, no button < 36 px, every clipped label ellipsised, lanes disjoint, inspector on screen, reaction dock/meter/cards inside the viewport, meter fixed outside the scroll | Pass with findings R1–R4 |
| Rules and timing unchanged | No engine, rules, data-definition, autoload or core script changed after 09:55, before both UI passes; data diffs vs HEAD are presentation and sandbox-menu fields (art, portrait, backdrop, practice lists) and wording; grader/timing suites pass | Pass: art on vs off gives identical outcomes, rounds and event counts in all 28 seeded battles, and so do the 28 Inspect battles before vs after the rail fix |
| Audio unselected, outside runtime | See below | Pass |

STAGE-01 was re-checked: six flat PNGs, 1672×941, hashes equal the catalog, night 1 is
`defaults.battle_backdrop`, and no runtime file references the removed `alternatives` paths.

### Audio intake (read-only)

- Catalog v2: six unique candidates, two per supplied cue; every track's selected source/runtime,
  delivery, version, approval and gain fields are null; loop mode `unreviewed`; exploration still
  `requested`. Candidate references resolve.
- SHA-256 of all six originals and six comparison Oggs equals the catalog and each `.delivery.json`;
  no metadata claims an audition, approval or runtime file.
- Independent `ffprobe`/full `ffmpeg` decode: originals Opus 48 kHz stereo, comparisons Vorbis 48 kHz
  stereo, zero decode errors, durations within 0.014 s of each other.
- `assets/audio/source/.gdignore` exists; no `.import` sidecar under `source/`; nothing in
  `.godot/imported` or the editor filesystem cache mentions `audio/source`; runtime code references
  only `res://assets/audio/sfx/`. `music/`, `ambience/`, `stingers/` hold no media. There is no
  `export_presets.cfg` yet, so export exclusion relies on `.gdignore` (correct for Godot).

### Icon-first validation (earlier brief), still passing on this tree

UI-01–UI-05 suites and the boundary tests pass. UI-06: every semantic icon maps (19 player and 30
enemy actions, potions, buffs, conditions, statuses); the six v01 sprites are pixel-identical to their
manifest regions of the unchanged atlas; a sandbox restart from Fen Patrol (Flooded Ground, Bell Crow)
into a no-familiar, no-condition fight leaves no ribbon, familiar card, tint, extra views or rail
slots. UI-07's actual captures are ChatGPT's stage/UI evidence; its human sessions are pending.
Mutation checks: each new test fails when its fix is reverted or its draw path is broken (11
earlier, 4 this pass), and each file was restored byte-identical.

## FINDINGS

### Fixed (engineering, presentation ledger contract)

| # | Defect | Evidence | Fix |
|---|---|---|---|
| F1 | INSPECTED rebuilt the whole intent rail from resolved state: slots said "Acted" before the enemy's turn played and showed next-round intents before their declaration | Inspect-first probe before the fix: 12 frames of early "Acted", 9 of a different intent than the one declared on screen (e.g. Thornhound pack seed 3) | Re-read only the inspected enemy's intent, only while the engine still holds that same intent (same action and targets) in the displayed round |
| F2 | ROUND_STARTED reset only enemies alive in the *resolved* state, leaving a stale "Acted" on one that dies later in the batch | Code review; reproduced in `test_rail_never_shows…` | Iterate all enemies; skip only those shown defeated |
| F3 | An intent declaration was skipped when the enemy dies later in the same batch (missing telegraph) | Code review; same test | Use presented life (`_shown_alive`) |

F2/F3 need a death later in the same batch (e.g. a damage tick before the player's next input); the
sampled battles did not produce one, so they are demonstrated by the unit test only.

### Reported for ChatGPT (UI layout; not changed)

| # | Finding | Measured | Smallest fix to consider |
|---|---|---|---|
| R1 | 150%: the Parry card's effect (4 lines) and "Fail" risk fall below the cards' fold in **every** encounter, so they need scrolling during the window | Cards need 279 px (323 on Flooded Ground); the 150% dock gives 214. 100%: only the Flooded Ground Evade caveat is below the fold (contract-allowed). 200%: fits except the same caveat | `BattleLayout.timed` uses 230 × scale for LARGE; ≈280 × scale (420 px) fits but then covers the party's stage rings, as 200% already does (the meter keeps the same timing); or shorten the 150% card text |
| R2 | 200%: the dock instruction shares a row with the attacker header, so "Release keys to continue" and "Paused · window lost focus" are ellipsised. These explain a frozen clock | Needs 672/728 px, has 596 | Instruction on its own row at ≥ 1.3 (as the attack widget already does) |
| R3 | Inspection overflow is mouse-only: the hover inspector and `DetailsPanel` scroll by wheel; neither takes keyboard/controller focus (their text has accessibility-only focus) | A focused rail slot's intent details: 304 of 728 px visible at 200%, 304 of 378 at 150% | A binding (e.g. right stick / PgUp-PgDn) that scrolls the visible inspection |
| R4 | 150%/200%: the reaction help bar ellipsises its tail ("first allowed press locks"); all three keys stay visible | 1281 / 1708 px of 1232 | Shorter tail at enlarged sizes |

Low: Godot imports `docs/reports/data/**/comparison.csv` and the `docs/playtests/` CSV templates as
translations and writes untracked `*.translation` files into `docs/`; they would ship in an export
(a `.gdignore` in those folders stops it). Earlier findings still open: the preview header
uses the generic item glyph for potions; unmapped future icons fall back to "unavailable"; an
intent slot's plain text says "Break to interrupt" for non-channels; the ribbon rebuild drops focus;
familiar readiness ignores `max_per_battle` (unused in data); Pause is ignored during target review.

## KNOWN LIMITATIONS

- Geometry was measured, pixels were not judged; visual quality rests on ChatGPT's captures.
- Probes use the autopilot and simulated execution; no physical controller or human timing.
- Within the displayed round, Inspect's re-read can show the same intent's numbers against later
  resolved state (e.g. a Guard gained later in the batch); batch-end reconcile corrects it.
- Wide corpses (Bramblejaw 228 px, Thornhound 198 px before shrink) extend into neighbouring lanes
  with four enemies, as the contract allows; click bounds do not change.

## FUTURE EXTENSION POINTS

- A batch boundary in `BattleEventPlayer.history` would let tests assert "stable point" directly.
- A shared "scroll the visible inspection" input would close R3 for every panel at once.
- Per-mode timed-dock heights in `BattleLayout` (R1) without touching the widgets.

## QUESTIONS AND DECISIONS FOR THE DIRECTOR

1. **Inspect timing (behaviour change):** knowledge revealed by Inspect now updates the inspected
   enemy's slot immediately (while its intent, targets and round are unchanged) and every other slot
   at the end of the batch. Previously all slots jumped to the resolved state. Accept?
2. **R1:** taller 150% timed dock, shorter 150% card text, or accept wheel-only scrolling?
3. **R2/R3:** approve a separate instruction row at ≥ 1.3 and an inspection-scroll binding?
4. Carried over: the sandbox Setup page now waits for a safe point and leaves the battle paused
   (Resume after closing it); ally-target details sit over the enemy half. Confirm both.
5. Approve `.gdignore` files for `docs/reports/data/` and `docs/playtests/` (import hygiene)?

Pending regardless: fresh-player READ/REACT sessions, physical-controller pass, artist cleanup,
colour-vision/contrast review, music audition/selection (AUDIO-02–06).
