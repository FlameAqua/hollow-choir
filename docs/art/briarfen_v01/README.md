# Briarfen v01 — source provenance and repackaged cast

This generation batch is retained for provenance. Runtime art now follows the
[shared art library](../../../assets/art/README.md), using the same individual sprite/resource
layout as v02.

Six lossless rectangular PNG exports preserve the measured original pixels: Hollow and Mara
in global characters, Bell Crow in global familiars, Bogshell/Thornhound/Fen Wisp in Briarfen enemies.
The marsh backdrop is in Briarfen environments. SpriteFrames still use one `idle` frame with
`display_height` and `faces_left`; the familiar portrait references its own PNG.
No repainting, palette reduction, alpha cleanup or animation was introduced by extraction.

The original cast atlas remains at
[assets/art/sources/briarfen/v01/cast.png](../../../assets/art/sources/briarfen/v01/cast.png).
It is excluded from Godot imports and is no longer needed at runtime.
[manifest.json](manifest.json) records original source rectangles alongside current project-root paths.
[Path migration](../path_migration.json) resolves the former pack paths.

All cast resources are integrated. Final pixel/alpha cleanup and human art review remain open.
Follow the [style guide](../../../assets/art/STYLE_GUIDE.md) and
[current UI contract](../../design/ICON_FIRST_COMBAT_UI.md).

