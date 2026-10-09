extends SceneTree
## Renders the V0.4 world host for review at the fixed game layout (needs a display):
##
##   python tools/qa_godot.py --hidden --rendering-method gl_compatibility \
##       --script res://tools/capture_world.gd -- --state=town --out=res://docs/reports/v0_4/town.png
##
## States: town, town-restored, dialogue, bench, route, patrol, encounter, map, menu, latch,
## collision, battle; Director additions: bench-hammer, bench-bow, guard, guard-approach, gate,
## facades, map-full, map-restored, victory, defeat, save-failed; Claude third pass: reset (the
## Reset journey confirmation over the paused menu).
## Options: --size=<supported preset>, --out=res://… or user://… (PNG).
##
## Capture fixtures: the runner seeds an in-memory world state, places Hollow at named spots and
## opens modals directly. It writes no saves or settings and does not measure play or readability.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/capture_world_runner.gd").new())
