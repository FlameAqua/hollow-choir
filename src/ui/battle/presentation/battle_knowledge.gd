class_name BattleKnowledge
extends RefCounted
## The single display-knowledge policy (M1.1 F1, DECISION_LOG D-018). Every widget asks here before
## it shows research-gated information, so a rule cannot be filtered in one place and leaked in
## another. Reads ResearchRules and the battle's revealed affinities; never changes them. Engine
## previews and simulation stay exact: this only decides what the player is shown.
##
##   Always public: legality, targets, intent category, threat band, reactions, status payloads,
##     channel countdown and interruptibility, HP and Stagger meters, conditions, telegraph text.
##   UNDERSTOOD (or Inspect): move names, exact incoming damage, telegraph details, species traits.
##   STUDIED (or a direct hit of that damage type): the affinity for that type, and everything
##     derived from it (exact outgoing damage/Stagger, weakness Focus, break/kill claims, formula).
##   MASTERED: AI tendencies.


static func level(engine: BattleEngine, unit: BattleUnit) -> Enums.ResearchLevel:
	if unit == null or not unit.is_enemy():
		return Enums.ResearchLevel.MASTERED
	return ResearchRules.detail_level(engine.ctx, unit)


## Move names, exact incoming damage and telegraph details.
static func knows_moves(engine: BattleEngine, unit: BattleUnit) -> bool:
	return level(engine, unit) >= Enums.ResearchLevel.UNDERSTOOD


static func knows_traits(engine: BattleEngine, unit: BattleUnit) -> bool:
	return level(engine, unit) >= Enums.ResearchLevel.UNDERSTOOD


static func knows_tendencies(engine: BattleEngine, unit: BattleUnit) -> bool:
	return level(engine, unit) >= Enums.ResearchLevel.MASTERED


## Whether [param unit]'s response to [param damage_type] (weak / resisted / neutral) is known.
## Types no affinity applies to (none, PURE) are always known.
static func knows_affinity(engine: BattleEngine, unit: BattleUnit, damage_type: Enums.DamageType) -> bool:
	if unit == null or not unit.is_enemy():
		return true
	if damage_type == Enums.DamageType.NONE or damage_type == Enums.DamageType.PURE:
		return true
	return PreviewRules.affinity_known(engine.ctx, unit, damage_type)


## The one label every widget uses for an action: the move's name for party actions or once the
## actor's moves are known, otherwise the public intent category ("Heavy attack").
static func action_label(engine: BattleEngine, actor: BattleUnit, action: ActionDefinition) -> String:
	if action == null:
		return "?"
	var enemy_action := action as EnemyActionDefinition
	if enemy_action == null or actor == null or not actor.is_enemy() or knows_moves(engine, actor):
		return action.display_name
	return EnumText.intent_category(enemy_action.intent_category)


## Display name of a unit by id ("the battlefield" when none).
static func unit_name(engine: BattleEngine, uid: int) -> String:
	var unit := engine.get_unit(uid) if engine != null else null
	return unit.display_name if unit != null else "the battlefield"
