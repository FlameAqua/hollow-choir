# IMPLEMENTATION BRIEF

Implemented UI follow-up to Adrian's screenshots: restore authored action rules, replace empty
support outcomes with named effect fields, assign Cinder Pup art, integrate shared health/break
textures, and dock compact condition announcements to existing header icons. Design authority:
[support presentation contract](../design/V02_SUPPORT_PRESENTATION.md).

# DATA CONTRACT

ActionReadout adds transient support_effects from RuleNotes.SupportNote: icon, label, recipient,
explanation, color. Existing action/effect/buff/item data remains authoritative. FamiliarDefinition's
existing portrait field points to an AtlasTexture. ConditionRibbon buttons carry condition_id.
ResourceBarArt shares existing frame resources plus a slim track; zero value draws no fill.

# STATE FLOW

Hover/focus action → filtered readout → shared summary → existing expanded inspector/scroll.
CONDITION_ADDED → ledger → header refresh → compact explanation → compress/fly to matching ID →
clear highlight. Reduced motion or unavailable destination → stationary fade. Startup summaries
are not repeated in the encounter intro. No command/reaction clocks or resolver flow changed.

# ACCEPTANCE TESTS

Guard/Intercept/Tincture rules and fields, art assignment across the existing cast, familiar aspect
and footing, condition flight/reduced-motion/fallback, honest bar fractions, plus the full suite.
See the [capture/test report](../reports/v02_ui/SUPPORT_PRESENTATION.md) for actual results.

# KNOWN EDGE CASES

Complex support scaling falls back to a named effect/authored prose. Conditional effects use “May”.
Enlarged analysis intentionally scrolls. A disappearing condition cannot leave a stale destination.
Atlas cropping is presentation-only; original generated source is retained. Art-off procedural
fallbacks are intentional test/low-art presentation, not missed production assignments.

# NON-GOALS

No new familiar rules, combat balance, enemy content, animation framework, music playback, saved
progress schema, necromancy/corpse mechanics, release, commit or push. Continue reusing one shared
card/frame/bar system rather than creating per-action or per-enemy widgets.
