class_name EnemyActionDefinition
extends ActionDefinition
## An enemy ability: an ActionDefinition plus utility-AI data, telegraph data and reaction rules.
##
## GDD contract: base_priority, resource_cost (= focus_cost), cooldown, target_rules (= target_rule),
## conditions (= use_conditions), role_tags, synergy_tags, can_brace/can_evade/can_parry.

@export_group("AI")
@export var base_priority: float = 1.0
## 0 = unlimited uses per battle.
@export var max_uses: int = 0
## All must pass for the action to be legal (actor = the enemy).
@export var use_conditions: Array[ConditionDefinition] = []
## Role behaviours this action expresses; empty = the enemy's own role. Role default
## considerations are merged in from EnemyRoleDefinition.
@export var role_tags: Array[Enums.EnemyRole] = []
## Combo vocabulary: setups create opportunities that allies' payoffs exploit.
@export var synergy_setup: Array[Enums.SynergyTag] = []
@export var synergy_payoff: Array[Enums.SynergyTag] = []
@export var considerations: Array[AIConsiderationDefinition] = []

@export_group("Telegraph")
@export var intent_category: Enums.IntentCategory = Enums.IntentCategory.ATTACK
## Activations spent channeling before release (0 = immediate). Shown as an hourglass.
@export var channel_turns: int = 0
## Breaking Stagger cancels the channel.
@export var interruptible: bool = true
## Always-visible flavour of the intent, e.g. "Preparing a heavy strike."
@export var telegraph_text: String = ""
## Revealed at research level UNDERSTOOD, e.g. "Parries easily after the second flash."
@export var telegraph_detail: String = ""
## Parrying a signature move awards research.
@export var signature: bool = false
## Observing a rare move awards research.
@export var rare: bool = false

@export_group("Reactions")
@export var can_brace: bool = true
@export var can_evade: bool = true
@export var can_parry: bool = true
## Wind-up animation length before impact (presentation; reaction timing centres on impact).
@export var windup_ms: float = 900.0
## Scales all reaction windows for this move (fast jabs < 1, slow slams > 1).
@export var reaction_window_scale: float = 1.0
## Playtest revision: Break this action removes from a party target that does not react
## (-1 = BalanceConfig.party_break_hit). Only a damaging action deals it; reactions scale it
## (StaggerRules.party_break_amount).
@export var party_break: float = -1.0


func allows_reaction(reaction: Enums.ReactionType) -> bool:
	match reaction:
		Enums.ReactionType.BRACE:
			return can_brace
		Enums.ReactionType.EVADE:
			return can_evade
		Enums.ReactionType.PARRY:
			return can_parry
	return false


func is_reactable() -> bool:
	return can_brace or can_evade or can_parry


func validate() -> PackedStringArray:
	var problems := super.validate()
	if base_priority <= 0.0:
		problems.append("enemy action %s needs base_priority > 0" % id)
	if channel_turns < 0:
		problems.append("enemy action %s has negative channel_turns" % id)
	if telegraph_text.is_empty():
		problems.append("enemy action %s has no telegraph_text (intent must be readable)" % id)
	for consideration in considerations:
		if consideration == null:
			problems.append("enemy action %s has a null consideration" % id)
	for condition in use_conditions:
		if condition == null:
			problems.append("enemy action %s has a null use_condition" % id)
	return problems
