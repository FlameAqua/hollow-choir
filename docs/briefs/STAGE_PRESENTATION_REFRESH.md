# Stage presentation refresh — engineering handoff

## IMPLEMENTATION BRIEF

ChatGPT has integrated the user's clearer font/title, compact enemy break tracks, shared Broken and
Exposed markers, flat day/night environment library, and nine defeated enemy art variants in the
working tree. Review against [the canonical contract](../design/STAGE_PRESENTATION_REFRESH.md).
Preserve concurrent core-engine work. This handoff records completed UI work and review boundaries;
it does not request a second implementation or authorize future necromancer/cannibal mechanics.

## DATA CONTRACT

Six explicit backgrounds live directly under `assets/art/environments/briarfen/`, named
`briarfen_marsh_<day|night>_<N>.png`, paired by numeric N. Catalog holds hashes/dimensions/provenance;
night 1 stays the default. Day/night never supplies simulation state. Existing enemy SpriteFrames
retain idle and add one nonloop dead AtlasTexture plus optional `dead_display_width` before shrink.
Bottom-centre dead art shares idle feet; control bounds remain unchanged. PresentationLedger life,
broken and weak_point fields remain authoritative. No new simulation or save field exists.

Departure Mono v1.500 and OFL are bundled; preload through UITheme is required for export. Body and
secondary sizes are 22/33/44 at 100/150/200%. Current bar drawing remains code-native; only the title
adopts the shared frame textures in this pass. The audio folder contract is unaffected.

## STATE FLOW

Existing event stream → PresentationLedger → UnitView. DAMAGE updates presented HP; UNIT_DEFEATED
sets alive=false → dead artwork at stable feet → enemy view remains at 0.72 alpha. Reconcile reads
the same ledger life. HP tween progress does not choose the pose. Defeat removes bars/selection;
engine living-target eligibility remains unchanged. Existing Broken/weak_point events select static
marks and labels. Restart rebuilds ordinary initial state through existing setup.

## ACCEPTANCE TESTS

Apply STAGE-01–STAGE-07. See [recorded evidence](../reports/stage_refresh/README.md) and
`tests/ui/test_stage_art.gd`. In particular, inspect zero-HP-before-defeat, nonzero tween after defeat,
all nine dead frames, stable control size/footing and living-target exclusion. Review all text scales,
the G/5 specimen, long preview/command titles, both state markers, restart, art-off and condition
caveats. Artificial state/death screenshots are presentation checks only; retain the human gate.

## KNOWN EDGE CASES

Generated art still needs final pixel/human review. Very wide corpses can visually overlap lanes;
their pixels never grant target geometry. Missing dead art uses a generic flattened fallback. Long
reaction caveats may scroll while the impact meter stays fixed. Current attacks cannot target dead
units, even though their UnitViews and instance IDs remain. Reconciliation must not restore the old
zero-alpha enemy fade. Flat numbered files are explicit choices, not an auto-scan/randomization API.

## NON-GOALS

No necromancer, cannibalism, corpse resource/manager, revival, corpse eligibility, decay, loot, persistent
bodies, new status, weak-point rule, weather clock, encounter count, balance, save schema, adaptive audio,
background cycling subsystem, full animation sheet or wholesale combat-frame rewrite.
