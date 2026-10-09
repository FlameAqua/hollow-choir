class_name WorldMapReadout
extends RefCounted
## Discovered local map for the current area, in area pixel space. Undiscovered landmarks and
## unwalked links are absent (not hidden flags), so no view can leak them.

var area_name: String = ""
var area_size: Vector2 = Vector2.ZERO
var player_position: Vector2 = Vector2.ZERO
## [{label: String, position: Vector2, description: String}] sorted by label.
var landmarks: Array[Dictionary] = []
## Each entry is one walked link's polyline in area pixels.
var links: Array[PackedVector2Array] = []
