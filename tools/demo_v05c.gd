extends SceneTree
## V0.5C backend demonstration (a developer fixture, not a playtest or acceptance result):
##
##   python tools/qa_godot.py --headless --script res://tools/demo_v05c.gd
##
## Runs the production WorldSession and SaveManager in an isolated QA home on the V0.5C fixture
## world (tests/fixtures/exploration_kit.gd: the authored journey plus the proposed, not yet placed,
## gathering node, rune puzzle and secret). Gathers the node → strikes the stones (one mistake) →
## the solved rhythm reveals the niche → the niche is searched → the save is reloaded from disk →
## Reset journey keeps the gathered node and every claim; repeating the puzzle and the secret
## grants nothing. Prints public results only.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/demo_v05c_runner.gd").new())
