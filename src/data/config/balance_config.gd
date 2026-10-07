class_name BalanceConfig
extends Resource
## Every global combat number in one designer-editable place. Damage previews, the live battle and
## the simulator all read from here, so a tuning change is reflected everywhere at once.

@export_group("Execution grades")
@export var miss_multiplier: float = 0.85
@export var good_multiplier: float = 1.0
@export var perfect_multiplier: float = 1.15
## Focus for GOOD / PERFECT on actions flagged generates_focus (basic attacks).
@export var focus_on_good: int = 1
@export var focus_on_perfect: int = 2
## Focus for PERFECT on other actions that have a command (techniques, magic).
@export var focus_on_perfect_other: int = 1

@export_group("Damage")
## Final = raw * guard_constant / (guard_constant + Guard).
@export var guard_constant: float = 100.0
## +/- fraction rolled on the battle RNG. Previews show the full range.
@export_range(0.0, 0.5, 0.01) var damage_variance: float = 0.05
@export var weakness_multiplier: float = 1.3
@export var resistance_multiplier: float = 0.7
@export var weakness_focus: int = 1
@export var weakness_stagger_multiplier: float = 1.5
@export var broken_damage_taken_multiplier: float = 1.5
## Any hit against an exposed weak point.
@export var weak_point_damage_multiplier: float = 1.25
## Extra multiplier for PRECISION-tagged hits against an exposed weak point (bows).
@export var weak_point_precision_multiplier: float = 1.4
@export var weak_point_stagger_multiplier: float = 1.5
## INTERRUPT-tagged hits against a channeling target.
@export var interrupt_stagger_multiplier: float = 1.75
@export var minimum_damage: int = 1

@export_group("Reactions")
## Total window widths (ms) at STANDARD assist.
@export var brace_window_ms: float = 520.0
@export var evade_window_ms: float = 280.0
@export var parry_window_ms: float = 150.0
@export var brace_damage_multiplier: float = 0.6
@export var evade_success_multiplier: float = 0.0
@export var evade_fail_multiplier: float = 1.15
@export var parry_success_multiplier: float = 0.0
@export var parry_fail_multiplier: float = 1.3
@export var parry_stagger: float = 18.0
@export var parry_focus: int = 2

@export_group("Focus")
@export var party_starting_focus: int = 2
@export var enemy_starting_focus: int = 0
@export var enemy_focus_per_turn: int = 1
## To the unit whose hit breaks an enemy.
@export var break_focus: int = 2
## Additional Focus when the break cancels a channel (an interrupt).
@export var interrupt_focus: int = 1

@export_group("Stagger")
## Party ambush: every enemy starts with this fraction of its Stagger already removed.
@export_range(0.0, 1.0, 0.01) var ambush_stagger_fraction: float = 0.25

@export_group("Default actions")
@export var default_guard_action: ActionDefinition
@export var default_inspect_action: ActionDefinition

@export_group("Safety")
## Battles longer than this end as TIMEOUT (simulation guard).
@export var max_rounds: int = 30
## Trigger recursion limit (prevents infinite chains).
@export var max_trigger_depth: int = 4


func grade_multiplier(grade: Enums.ExecutionGrade) -> float:
	match grade:
		Enums.ExecutionGrade.MISS:
			return miss_multiplier
		Enums.ExecutionGrade.PERFECT:
			return perfect_multiplier
	return good_multiplier


func reaction_window_ms(reaction: Enums.ReactionType) -> float:
	match reaction:
		Enums.ReactionType.BRACE:
			return brace_window_ms
		Enums.ReactionType.EVADE:
			return evade_window_ms
		Enums.ReactionType.PARRY:
			return parry_window_ms
	return 0.0


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not (miss_multiplier <= good_multiplier and good_multiplier <= perfect_multiplier):
		problems.append("grade multipliers must be ordered MISS <= GOOD <= PERFECT")
	if miss_multiplier <= 0.0:
		problems.append("a missed command must never cancel the action (miss_multiplier > 0)")
	if not (parry_window_ms <= evade_window_ms and evade_window_ms <= brace_window_ms):
		problems.append("reaction windows must be ordered PARRY <= EVADE <= BRACE")
	if default_guard_action == null or default_inspect_action == null:
		problems.append("default guard and inspect actions must be assigned")
	return problems
