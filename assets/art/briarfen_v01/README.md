# Briarfen v0.1 — staged art candidates

Original art generated for Hollow Choir on 7 October 2026. No external reference art was supplied.
The cast was revised from a project-generated initial study; the backdrop was generated separately.
See [manifest.json](manifest.json) for source provenance, exact regions and file dimensions.

Contents: six idle character candidates in one transparent atlas; one flattened marsh background;
six native Godot SpriteFrames resources with one `idle` frame each. The Bell Crow resource is a visual
candidate, not a new combat unit. Godot assets are declarative data, not gameplay code.

**Integration is pending.** No CombatantDefinition currently references these resources. Current
UnitView ignores `sprite_frames`, so assigning them alone would not change the running sandbox.
Claude's [brief](../../../docs/briefs/M1_1_IMPLEMENTATION.md) describes the required presentation hookup.

The generated sheet did not respect a regular grid. Use the manifest's irregular atlas rectangles,
not 512×512 slicing. `filter_clip` prevents adjacent sampling, but is not pixel cleanup. Source pixels
retain partial alpha, fine detail and occasional edge residue. The resources are suitable for a
direction/integration prototype; **not approved final pixel sprites or completed animation**.

Final acceptance requires restricted-palette cleanup at the target logical sprite size, opaque
interiors, transparent empty space, no neighbouring pixels, consistent feet anchors, and inspection
on light/dark backdrops. Do not silently quantize or resize the sheet as a substitute for art review.
Source PNGs remain untouched. Final target cells and animation limits are in the
[design specification](../../../docs/design/M1_1_COMBAT_CLARITY.md#f5--art-direction-and-production-limit).

Validation on 7 October 2026: Godot 4.7.2 imported both PNGs, loaded all six SpriteFrames and
verified each atlas region is in bounds with exactly one idle frame. The backdrop loaded at 1672×941.
This validates the resource packaging, not final pixel-art quality or the pending renderer hookup.

Import with lossless compression, no mipmaps and nearest filtering. Existing project filtering is
nearest. Candidate frames face right for party/familiar and left for enemies. Do not apply the
procedural placeholder's enemy flip a second time. Preserve logical effect/selection anchors.

Art direction: worn ivory and tarnished brass for the Choir's material legacy; uneven peat, moss and
rust for living growth. Neither palette is a moral alignment. Distinct silhouettes carry identity;
UI markers carry reaction legality, knowledge, targeting and all other rules.
