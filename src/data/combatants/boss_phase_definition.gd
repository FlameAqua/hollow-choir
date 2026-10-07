class_name BossPhaseDefinition
extends Resource
## A phase change for elites/bosses, entered once when HP falls to [member hp_threshold].
##
## Phases let a boss "test every important system, but not simultaneously" (GDD roadmap).

@export var display_name: String = ""
## Enter when current HP fraction <= this value.
@export_range(0.0, 1.0, 0.01) var hp_threshold: float = 0.5
## Shown as a banner; should tell the player what changed.
@export_multiline var announce_text: String = ""
## Replaces the action set when not empty.
@export var actions: Array[EnemyActionDefinition] = []
@export var add_conditions: Array[BattlefieldConditionDefinition] = []
@export var remove_conditions: Array[BattlefieldConditionDefinition] = []
## Resolved with owner = the boss.
@export var on_enter_effects: Array[EffectDefinition] = []
## If set, becomes the boss's next declared intent.
@export var opening_action: EnemyActionDefinition


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("boss phase without display_name")
	for action in actions:
		if action == null:
			problems.append("phase %s has a null action" % display_name)
	for effect in on_enter_effects:
		if effect == null:
			problems.append("phase %s has a null effect" % display_name)
		else:
			problems.append_array(effect.validate())
	return problems
