# Art and audio asset continuation — engineering handoff

Audio receipt update: [six candidate deliveries](../audio/DELIVERY_REVIEW_2026_10_08.md) are cataloged,
measured and converted to whole-file comparison Oggs under `source/review/`. Read
[the intake handoff](AUDIO_DELIVERY_INTAKE.md) before selecting or wiring music. No cue is selected;
catalog v2 candidates are separate from the cue's null selected/runtime fields.

Current art/UI state is superseded by [the stage refresh handoff](STAGE_PRESENTATION_REFRESH.md):
six flat numbered day/night images, Departure Mono, title frame integration, compact break bars and
dead poses are now present. The combat frame textures remain staged. Audio intake/approval rules here
are unchanged; the text below records the earlier asset delivery boundary.

## IMPLEMENTATION BRIEF

The user authorized two Briarfen backdrop alternatives, a reusable decorative frame/bar kit, and a
music intake/contract/prompt pack while Claude reviews the combat UI. This pass adds assets and native
review resources only; current battle defaults, UI scripts and AudioManager are preserved.

ChatGPT owns visual/audio direction and presentation integration. Claude owns core engineering and
may assist with later wiring to these contracts. Do not rebuild the icon-first layout or introduce an
audio subsystem just because folders now exist. Runtime assignment is a separate follow-up.

## DATA CONTRACT

- `assets/art/environments/briarfen/catalog.json`: delivery metadata, stable decorative
  environment IDs, exact sizes/hashes/prompts and `runtime_assignment: pending`. Not encounter rules.
- `assets/art/global/ui/frames/choir_v01`: ten SVG textures, ten StyleBoxTexture resources, sample Theme.
  Keep current margins/text scale when merging styles; use normal flat fallbacks. The sample Theme is
  a review aid, not a replacement for UITheme.build or its accessibility overrides.
- `assets/audio/AUDIO_CONTRACT.md` governs delivery. `music/catalog.json` is a delivery ledger with null
  paths until reviewed media exists, not a runtime Resource or save format.
- Existing defaults.battle_backdrop, unit/public readouts, ledger, settings and Music/SFX buses remain
  the future integration boundaries. Art/audio never provide rule state, knowledge or impact time.

## STATE FLOW

Backdrop/frame: generated/authored source → exact resource metadata → actual Godot review → visual
approval → future assignment through existing presentation hooks, preserving existing fallback.

Music: source intake → provenance/evidence recorded → audition → edits if needed → approved master →
reviewed runtime export/loop → explicit cue assignment → later playback integration. Missing cues use
silence. No automatic folder scans, invented paths, or promotion based on filenames.

## ACCEPTANCE TESTS

Load all frame resources and sample Theme in Godot; inspect real rendered frames/bars at final sizes,
including empty/partial/full fills and focus. Check four-actor stage compositions on both alternatives
with actual backdrop crop and low/high-contrast actors. Native resources may pass loading while artistic
approval remains pending. Apply FRAME/ENV requirements in the art addendum and AUDIO-01–AUDIO-06.

Future runtime assignment must retain icon UI tests, knowledge gates, text scaling, mouse bounds,
reaction/command parity, volume/mute and scene cleanup. Current pass does not claim human acceptance.

## KNOWN EDGE CASES

Generated backgrounds retain high-resolution pixel detail; no artist cleanup is claimed. Ornate edges
can overwhelm 40 px controls, so ornaments are restricted to corners. Texture fills must show exact
fractions, including zero. Unsupported imports require flat fallbacks. Audio may have no verified loop,
unknown usage evidence or a poor mix; null catalog values are deliberate. Independent generated tracks
are not sample-aligned stems. Existing victory/defeat SFX must not be duplicated accidentally.

## NON-GOALS

No live UI rewrite while it is under review, default background replacement, random scenery system,
new encounter/environment rules, collision, parallax, shaders, bespoke enemy panels, music player,
middleware, adaptive stems, beat-synchronized combat, balance or save changes.
