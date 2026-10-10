extends SceneTree
## V0.5A backend demonstration (a developer fixture, not a playtest or acceptance result):
##
##   python tools/qa_godot.py --headless --script res://tools/demo_v05a.gd
##
## Drives the production code in an isolated QA home and refuses to run without one: a guard battle
## played by the party autopilot is committed → its salvage is saved → the bell is rung and the
## Storm Salt Charm is granted → the save is reloaded from disk → the charm is equipped in the field
## (V0.5 UI: Character equipment, no station) → after another reload the next encounter entry
## carries the Grounding trait, and a Wet → Shock turn shows it fire. Prints public results only
## (item names, counts, readout text; no creature names or hidden enemy numbers).


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/demo_v05a_runner.gd").new())
