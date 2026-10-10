extends SceneTree
## Production-widget fixtures for visual review. No writes outside the isolated QA home.
## --state=title/settings/dialogue/reward/inventory/inventory15/loadout/loadout-popup/journal
## Station variants: forge[-locked/-owned/-fitted], stillroom[-poor/-depleted].
## HUD-only supplied-fact fixtures: countdown/countdown-frozen/quest/autosave/manual-save.
## --size=1280x720 (any supported preset), --out=res://docs/reports/v0_5_playtest_revision/name.png
## --edge=tl/tr/bl/br positions a tooltip fixture at a canvas edge.
## --inspect=<node name> uses real focus inspection of that production control.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	await process_frame
	root.add_child(load("res://tools/capture_playtest_revision_runner.gd").new())
