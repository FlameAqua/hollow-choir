class_name Stamina
extends RefCounted
## V0.5 sprint stamina (pure state; WorldPlayer owns one, nothing saves it). From full, sprinting
## lasts DRAIN_SECONDS. Whenever Hollow is not sprinting the meter refills at a rate that takes
## RECOVER_SECONDS from empty, so a partly used meter refills in proportion. Emptying it leaves Hollow
## exhausted: no sprint until the sprint input is released, so a held key never flickers between
## sprinting and walking at an empty meter. Only exploration frames advance it (modals freeze it).

const DRAIN_SECONDS := 5.0
const RECOVER_SECONDS := 5.0

## 0 (empty) to 1 (full).
var value := 1.0
## Emptied while sprinting; cleared when the sprint input is released.
var exhausted := false
## Hollow sprinted in the last update.
var sprinting := false


## Whether Hollow may sprint this frame with the sprint input [param held]. Call every frame: a
## released input is what ends exhaustion.
func can_sprint(held: bool) -> bool:
	if not held:
		exhausted = false
	return held and not exhausted and value > 0.0


## Advances one exploration frame of [param delta] seconds. [param spent]: Hollow actually moved at
## sprint speed this frame (standing still or pushing into a wall spends nothing).
func update(delta: float, spent: bool) -> void:
	sprinting = spent and delta > 0.0
	if sprinting:
		value = maxf(0.0, value - delta / DRAIN_SECONDS)
		if value <= 0.0:
			exhausted = true
	else:
		value = minf(1.0, value + maxf(delta, 0.0) / RECOVER_SECONDS)


func is_full() -> bool:
	return value >= 1.0


func reset() -> void:
	value = 1.0
	exhausted = false
	sprinting = false
