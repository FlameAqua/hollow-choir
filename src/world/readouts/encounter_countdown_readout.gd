class_name EncounterCountdownReadout
extends RefCounted
## What the world indicator shows of the move-away countdown (playtest revision). Plain data from
## WorldHost; public threat category only (never a creature name).

var state: EncounterCountdown.State = EncounterCountdown.State.IDLE
## A threat owns the countdown (counting or frozen).
var active := false
## Held by a modal, a pause, a lost focus or a transition; resumes with the same remaining time.
var frozen := false
## The encounter landmark that owns it (&"" when none) and its public threat category.
var threat_id: StringName = &""
var threat_label: String = ""
## Seconds left and the full duration.
var remaining: float = 0.0
var duration: float = EncounterCountdown.DURATION


## Remaining share of the countdown, 1.0 (just started) to 0.0 (expired).
func fraction() -> float:
	return clampf(remaining / duration, 0.0, 1.0) if duration > 0.0 else 0.0


func plain_text() -> String:
	if not active:
		return EncounterCountdown.State.keys()[state]
	return "%s %.1f / %.1f%s" % [threat_label, remaining, duration, " (held)" if frozen else ""]
