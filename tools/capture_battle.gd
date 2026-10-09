extends SceneTree
## Renders real screenshots of the running game UI for visual review. Needs a display (not
## --headless). One run captures one state; run it through tools/qa_godot.py so the capture uses
## default settings in a throwaway user-data home:
##
##   python tools/qa_godot.py --hidden --rendering-method gl_compatibility \
##       --script res://tools/capture_battle.gd -- --state=planning --out=res://captures/planning.png
##
## States:
##   planning           first player turn          details    planning with Details expanded
##   target             recipient review (--action=<id>, default the first legal targeted action;
##                      --then=<id> then chooses that action or item during the review)
##   prepare-command    actual attack meter inside the 400 ms preparation beat, held for the shot
##   prepare-reaction   actual reaction ring/cards inside the preparation beat, held for the shot
##   command            a running action command   reaction   a reaction just before impact
##   pause-before       Assisted reaction waiting for Confirm (use --assist=ASSISTED)
##   result             end of an autoplayed battle
##   condition-card     compact condition card (--condition=<id>), held
##   condition-flight   the same card mid-flight to its header icon
##   opening            first encounter banner held, pointer over an ally (no card may cover it)
##   opening-condition  the opening's Flooded Ground card held, pointer over an ally
##   setup / resumed    sandbox Setup covering a paused battle / the battle after closing Setup
##   practice / lab     the sandbox setup views     settings   the Settings screen (--tab=N)
##   field-guide / field-guide-empty / weapon-practice   V0.3 save-readout fixtures (no save writes)
##   audio-lab          intense mix at 45s; --preview-ending or --audio-controls for scrolled controls
## Planning options: --inspect-action=<id> hovers that action or supply button; --hover=enemy|
## intent|action|supply hovers a source; --expanded holds Details (Alt).
## --dwell=1.2 holds the pointer before capture to check delayed native tooltips.
## --actor=<unit id> commits Guard until that actor's planning turn (capture fixture only).
## Common options: --size=1280x720 (supported game presets only), --encounter=<id>, --loadout=<id>,
## --enemies=thornhound,thornhound,… (custom encounter, optional --condition=<id>), --reduced
## (reduce motion + flashing, no shake), --assist=ASSISTED, --knowledge=UNDERSTOOD, --seed=N,
## --no-art (sprites and backdrop off), --out=res://… or user://… (PNG).
##
## These are capture fixtures (see capture_runner.gd): held tweens, frozen clocks and synthetic
## input make a moment reviewable; they do not measure timing skill or certify input latency.


func _initialize() -> void:
	# Autoloads are not compile-time identifiers for a --script main loop, so the work happens in a
	# node script loaded once they exist.
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/capture_runner.gd").new())
