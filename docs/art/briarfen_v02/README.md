# Briarfen v02 — existing enemies and shared combat symbols

Generated on 8 October 2026 using the project's v01 cast/stage as references.
[Prompts and discarded trials](prompts.json), [measured manifest](manifest.json),
[original review board](asset_review.png) and [gallery](review.html) retain provenance.
Runtime paths are now organised by purpose and region in the [art library](../../../assets/art/README.md).

Six existing enemy idle candidates — Straw Penitent, Sporecaller, Rotcap Brute, Bogwife,
Bramblejaw and Mirebell Cantor — are assigned through existing enemy definitions.
Together with v01's three enemies they cover the nine current identities.
Three shared UI atlases supply 48 AtlasTextures for effects, action families, public intents,
reactions and channel markers. The [native icon map](../../../assets/art/global/ui/combat/icon_map.tres)
is integrated; it explicitly references the textures and maps current content IDs.
Unknown enemy moves use public category art until the move is known.

The current [icon-first UI contract](../../design/ICON_FIRST_COMBAT_UI.md) replaces the old
context panels and dock layout. See [actual Godot review captures](../../reports/ui_refresh/README.md).
The original v02 runtime captures document the earlier constrained enemy layout and are historical.

Source PNGs are preserved. Atlas dimensions are 1254×1254 with irregular gutters; use measured regions,
never equal slicing. Existing candidates retain high-resolution detail and alpha residue.
Deliberate final-size 64×64 ordinary / up to 96×96 elite/boss cleanup, palette restriction and human
review are still required. No new encounters, mechanics, balance, save fields or animation sets are added.
The earlier [QA record](QA.md) remains source-art evidence; it does not pass the human clarity gate.

