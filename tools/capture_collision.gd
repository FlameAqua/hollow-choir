extends SceneTree
## Native collision-overlay close-ups of authored prop footprints (needs a display):
##
##   python tools/qa_godot.py --hidden --rendering-method gl_compatibility \
##       --script res://tools/capture_collision.gd -- --out=res://docs/reports/v0_4_playtest_engineering/collision
##
## Each shot opens an area scene on its own, draws the debug collision shapes (painted Collision
## tiles dimmed), walks the real Hollow feet body at a prop from one side with physics steps and
## renders a 4x close-up at the fixed 1280x720 layout. --shot=<name> renders one shot. Shots and
## their walks live in tools/capture_collision_runner.gd. Capture fixture: no saves or settings.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/capture_collision_runner.gd").new())
