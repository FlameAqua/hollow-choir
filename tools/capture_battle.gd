extends SceneTree
## Renders real screenshots of the running battle UI for visual review (M1.1 visual checks).
## Needs a display (not --headless). One run captures one state:
##
##   godot --path . --script res://tools/capture_battle.gd -- --encounter=fen_patrol \
##       --loadout=starter_sword --size=1280x720 --scale=1.0 --state=planning --out=res://captures/x.png
##
## States: planning (first player turn), details (planning with Details on), target (choosing a
## target), command (an action command running), reaction (a reaction mid wind-up), pause-before
## (Assisted reaction waiting for Confirm), result (end of an autoplayed battle), practice / lab
## (the sandbox setup views).
## Options: --enemies=thornhound,thornhound,… builds a custom encounter; --reduced turns on reduce
## motion + reduce flashing and turns screen shake off; --assist=ASSISTED; --knowledge=UNDERSTOOD;
## --seed=N; --no-art disables sprites and the backdrop.



func _initialize() -> void:
	# Autoloads are not compile-time identifiers for a --script main loop, so the work happens in a
	# node script loaded once they exist.
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/capture_runner.gd").new())
