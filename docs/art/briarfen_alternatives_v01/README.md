# Briarfen alternatives v01 review

The built-in imagegen tool created two sibling variants from the existing marsh reference. Exact
prompts are in [prompts.json](prompts.json). Runtime PNGs and catalog are in
[alternatives](../../../assets/art/environments/briarfen/README.md).

No image resizing, palette conversion, painting or alpha cleanup was applied. Generated files are
unchanged. They remain candidates; neither is assigned to a runtime encounter. Actual Godot stage
captures are recorded below. All 24 new Godot resources load; PNG dimensions/hashes and frame margins
match their manifests. No combat script, default backdrop, SFX media or playback system was changed.

| Actual Godot review | Capture |
|---|---|
| Causeway, four mixed enemies / 100% text | [Stage](causeway_stage.png) |
| Root Hollow, four mixed enemies / 100% text | [Stage](root_hollow_stage.png) |
| Causeway / 150% text / Flooded Ground | [Stage](causeway_150.png) |
| Root Hollow / 200% text / Spore Fog | [Stage](root_hollow_200.png) |

All four captures use the existing crop and full-size actors; background assignment is an in-memory
review override only. [Capture arguments](captures.json) record the exact states. Five renders including
the separate frame-kit preview completed without runtime errors. Source/hash, documentation-link,
catalog/anchor and whitespace checks pass. Sandboxed editor settings emit their existing safe-save
warning; the resource checks and runtime renders complete cleanly.

These views support composition review, not a passed human art/READ gate. Backgrounds retain high-resolution
generated detail, and final composed contrast/physical-controller/human checks remain open. No music
has been received or auditioned in this pass.
