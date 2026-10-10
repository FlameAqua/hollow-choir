extends SceneTree
## V0.5B backend demonstration (a developer fixture, not a playtest or acceptance result):
##
##   python tools/qa_godot.py --headless --script res://tools/demo_v05b.gd
##
## Drives the production code in an isolated QA home and refuses to run without one: a guard battle
## played by the party autopilot records weapon mastery and salvage → the bell is rung → at the real
## Forge anvil interaction the fitting kit is bought, refunded, rebought and Merciful Grip fitted (a
## Stillroom purchase there is rejected); at the Stillroom both recipes are bought (a kit refund
## there is rejected); the tincture is prepared in the field → the save is reloaded
## from disk → the next encounter entry carries the fitting and both potions, a scripted Parry
## shows Merciful Grip restore HP, and the tincture is used with its authored charges → Reset
## journey keeps every unlock. Prints public results only (item names, counts, readout text).


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/demo_v05b_runner.gd").new())
