class_name AICandidate
extends RefCounted
## One (action, targets) option scored by EnemyAI.

var action: EnemyActionDefinition
var targets: Array[BattleUnit] = []
var score: float = 0.0
## [reason, multiplier] pairs for factors that changed the score, strongest first after sorting.
var factors: Array[Array] = []


func add_factor(reason: String, multiplier: float) -> void:
	if not reason.is_empty() and not is_equal_approx(multiplier, 1.0):
		factors.append([reason, multiplier])


## Top factors as readable lines, e.g. "Ally badly hurt (x2.5)".
func reason_lines(limit: int = 3) -> PackedStringArray:
	var sorted := factors.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool:
		return absf(log(a[1])) > absf(log(b[1])))
	var lines := PackedStringArray()
	for factor in sorted.slice(0, limit):
		lines.append("%s (x%.1f)" % [factor[0], factor[1]])
	return lines
