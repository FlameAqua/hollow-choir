class_name EnemyDefinition
extends CombatantDefinition
## Enemy identity = species (stats, affinities, traits) + combat role (AI defaults) + biome
## interaction (traits / conditions). Adding an enemy is data + art, never new combat code.

@export var role: Enums.EnemyRole = Enums.EnemyRole.RAVAGER
@export var tier: Enums.EnemyTier = Enums.EnemyTier.NORMAL
@export var species: String = ""
@export_multiline var habitat: String = ""
@export_multiline var lore: String = ""

@export_group("Stagger")
@export var max_stagger: float = 30.0
## Activations lost when Broken.
@export var break_turns: int = 1
## Max Stagger multiplier applied after each break (bosses > 1 to prevent stun-locks).
@export var stagger_growth_on_break: float = 1.0
@export var has_weak_point: bool = false
@export var weak_point_name: String = ""
## Breaking exposes the weak point (if any) until the enemy recovers.
@export var expose_weak_point_on_break: bool = true

@export_group("Affinities")
@export var weaknesses: Array[Enums.DamageType] = []
@export var resistances: Array[Enums.DamageType] = []
@export var status_immunities: Array[Enums.StatusId] = []

@export_group("Actions")
@export var actions: Array[EnemyActionDefinition] = []
## Elites and bosses only. Order by descending hp_threshold.
@export var phases: Array[BossPhaseDefinition] = []

@export_group("Research")
## Revealed at MASTERED in the bestiary and the intent "why" line.
@export_multiline var ai_tendencies: String = ""
## Revealed at MASTERED: unusual interactions worth knowing.
@export_multiline var rare_interactions: String = ""


func is_weak_to(damage_type: Enums.DamageType) -> bool:
	return weaknesses.has(damage_type)


func resists(damage_type: Enums.DamageType) -> bool:
	return resistances.has(damage_type)


func validate() -> PackedStringArray:
	var problems := super.validate()
	if actions.is_empty() and phases.is_empty():
		problems.append("enemy %s has no actions" % id)
	if max_stagger <= 0.0:
		problems.append("enemy %s needs max_stagger > 0" % id)
	for damage_type in weaknesses:
		if resistances.has(damage_type):
			problems.append("enemy %s is both weak and resistant to %s" % [id, Enums.DamageType.keys()[damage_type]])
	for action in actions:
		if action == null:
			problems.append("enemy %s has a null action" % id)
		else:
			for problem in action.validate():
				problems.append("enemy %s: %s" % [id, problem])
	var last_threshold := 1.01
	for phase in phases:
		if phase == null:
			problems.append("enemy %s has a null phase" % id)
			continue
		if phase.hp_threshold >= last_threshold:
			problems.append("enemy %s phases must be ordered by descending hp_threshold" % id)
		last_threshold = phase.hp_threshold
		problems.append_array(phase.validate())
	return problems
