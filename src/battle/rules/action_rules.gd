class_name ActionRules
extends RefCounted
## Legality, target lists and menu options. Illegal options carry a readable reason.


static func valid_targets(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition) -> Array[BattleUnit]:
	match action.target_rule:
		Enums.TargetRule.SELF:
			return [actor] as Array[BattleUnit]
		Enums.TargetRule.SINGLE_ENEMY, Enums.TargetRule.ALL_ENEMIES:
			return ctx.opponents_of(actor)
		Enums.TargetRule.SINGLE_ALLY, Enums.TargetRule.ALL_ALLIES:
			return ctx.allies_of(actor, true)
		Enums.TargetRule.OTHER_ALLY:
			return ctx.allies_of(actor, false)
	return [] as Array[BattleUnit]


## Empty string = legal.
static func illegal_reason(ctx: BattleContext, unit: BattleUnit, action: ActionDefinition,
		item_slot: int = -1) -> String:
	if action == null:
		return "No action"
	if not unit.is_alive():
		return "Defeated"
	if unit.focus < action.focus_cost:
		return "Needs %d Focus" % action.focus_cost
	var cooldown := unit.cooldown_left(action)
	if cooldown > 0:
		return "Ready in %d" % cooldown
	if item_slot >= 0:
		if item_slot >= ctx.state.potion_slots.size():
			return "No such slot"
		if ctx.state.potion_slots[item_slot].charges <= 0:
			return "Empty"
	if action.target_rule != Enums.TargetRule.NONE and valid_targets(ctx, unit, action).is_empty():
		return "No target"
	return ""


static func options_for(ctx: BattleContext, unit: BattleUnit) -> Array[ActionOption]:
	var options: Array[ActionOption] = []
	for action in unit.actions:
		options.append(_option(ctx, unit, action, -1))
	for slot_index in ctx.state.potion_slots.size():
		var slot := ctx.state.potion_slots[slot_index]
		if slot.potion != null and slot.potion.action != null:
			options.append(_option(ctx, unit, slot.potion.action, slot_index))
	return options


static func _option(ctx: BattleContext, unit: BattleUnit, action: ActionDefinition, item_slot: int) -> ActionOption:
	var option := ActionOption.new()
	option.action = action
	option.item_slot = item_slot
	option.reason = illegal_reason(ctx, unit, action, item_slot)
	option.legal = option.reason.is_empty()
	for target in valid_targets(ctx, unit, action):
		option.target_uids.append(target.uid)
	return option


## Empty string = the choice may be submitted.
static func validate_choice(ctx: BattleContext, choice: ActionChoice) -> String:
	var unit := ctx.unit(choice.unit_uid)
	if unit == null:
		return "Unknown unit"
	if choice.item_slot >= 0:
		var slots := ctx.state.potion_slots
		if choice.item_slot >= slots.size() or slots[choice.item_slot].potion == null \
				or slots[choice.item_slot].potion.action != choice.action:
			return "Item does not match slot"
	elif not unit.actions.has(choice.action):
		return "Action not available to %s" % unit.display_name
	var reason := illegal_reason(ctx, unit, choice.action, choice.item_slot)
	if not reason.is_empty():
		return reason
	if choice.action.needs_target_choice():
		var target := ctx.unit(choice.target_uid)
		if target == null or not valid_targets(ctx, unit, choice.action).has(target):
			return "Invalid target"
	return ""


static func targets_for_choice(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition,
		target_uid: int) -> Array[BattleUnit]:
	if action.needs_target_choice():
		var target := ctx.unit(target_uid)
		if target != null and target.is_alive():
			return [target] as Array[BattleUnit]
		return [] as Array[BattleUnit]
	return valid_targets(ctx, actor, action)
