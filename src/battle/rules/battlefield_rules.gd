class_name BattlefieldRules
extends RefCounted
## Adds and removes battlefield conditions. At most one MAJOR and one MINOR at a time: adding a
## condition replaces the active one of the same severity.


static func add(ctx: BattleContext, definition: BattlefieldConditionDefinition) -> void:
	if definition == null or ctx.state.has_condition(definition):
		return
	for active: ActiveCondition in ctx.state.conditions.duplicate():
		if active.definition.severity == definition.severity:
			remove(ctx, active.definition)
	var active := ActiveCondition.new()
	active.definition = definition
	for trait_def in definition.traits:
		if trait_def != null:
			active.trait_instances.append(TraitInstance.new(trait_def, -1, definition.display_name))
	ctx.state.conditions.append(active)
	var event := BattleEvent.new(BattleEvent.Type.CONDITION_ADDED)
	event.text = definition.display_name
	ctx.emit(event)


static func remove(ctx: BattleContext, definition: BattlefieldConditionDefinition) -> void:
	var active := ctx.state.find_condition(definition)
	if active == null:
		return
	active.deactivate()
	ctx.state.conditions.erase(active)
	var event := BattleEvent.new(BattleEvent.Type.CONDITION_REMOVED)
	event.text = definition.display_name
	ctx.emit(event)
