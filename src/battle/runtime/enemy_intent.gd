class_name EnemyIntent
extends RefCounted
## A declared enemy plan, visible to the player before it resolves.

var action: EnemyActionDefinition
var target_uids: Array[int] = []
var declared_round: int = 0
## Activations of channeling before release (includes Story-mode bonus turns).
var channel_total: int = 0
## Activations left before release once channeling has started.
var channel_remaining: int = 0
var channeling: bool = false
var score: float = 0.0
## Main factors behind the choice (shown as "why" at research MASTERED / sandbox debug).
var reasons: PackedStringArray = PackedStringArray()
## The original target died and the action was re-aimed by its target rule.
var retargeted: bool = false


func is_channel() -> bool:
	return channel_total > 0


## Activations until release, as shown by the hourglass (0 = this activation).
func turns_until_release() -> int:
	if not is_channel():
		return 0
	return channel_remaining if channeling else channel_total
