class_name UnitFactory
extends RefCounted
## Builds the battle's units, potion slots and conditions from a BattleSetup.
## Trait sources are labelled so every trigger can announce where it came from.

const SUFFIXES := ["A", "B", "C", "D", "E", "F"]


static func populate(ctx: BattleContext) -> void:
	var setup := ctx.setup
	var loadout := setup.loadout
	_add_protagonist(ctx, loadout)
	if loadout.companion != null:
		_add_companion(ctx, loadout.companion)
	var counts: Dictionary[StringName, int] = {}
	for enemy_def in setup.enemies:
		counts[enemy_def.id] = counts.get(enemy_def.id, 0) + 1
	var seen: Dictionary[StringName, int] = {}
	for enemy_def in setup.enemies:
		var index: int = seen.get(enemy_def.id, 0)
		seen[enemy_def.id] = index + 1
		var suffix: String = SUFFIXES[index % SUFFIXES.size()] if counts[enemy_def.id] > 1 else ""
		_add_enemy(ctx, enemy_def, suffix)
	for potion in loadout.potions:
		if potion != null:
			ctx.state.potion_slots.append(PotionSlotState.new(potion, potion.charges))
	ctx.state.familiar = loadout.familiar


## Conditions are added at BATTLE_START so the presentation sees them arrive.
static func add_conditions(ctx: BattleContext) -> void:
	for condition in ctx.setup.conditions:
		BattlefieldRules.add(ctx, condition)


static func _new_unit(ctx: BattleContext, definition: CombatantDefinition, side: Enums.Side) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.uid = ctx.state.units.size()
	unit.side = side
	unit.definition = definition
	unit.display_name = definition.display_name
	unit.max_hp = definition.max_hp
	unit.base_force = definition.force
	unit.base_guard = definition.guard
	unit.base_tempo = definition.tempo
	unit.max_focus = definition.max_focus
	for trait_def in definition.traits:
		if trait_def != null:
			unit.traits.append(TraitInstance.new(trait_def, unit.uid, definition.display_name))
	ctx.state.units.append(unit)
	return unit


static func _finalize(ctx: BattleContext, unit: BattleUnit, starting_focus: int) -> void:
	unit.max_hp = maxi(1, roundi(ModifierQuery.apply(ctx, Enums.ModifierStat.MAX_HP, unit.max_hp, unit, null, false)))
	unit.hp = unit.max_hp
	var focus := unit.definition.starting_focus if unit.definition.starting_focus >= 0 else starting_focus
	unit.focus = clampi(focus, 0, Stats.max_focus(ctx, unit))


static func _add_protagonist(ctx: BattleContext, loadout: PartyLoadout) -> void:
	var definition := loadout.protagonist
	var unit := _new_unit(ctx, definition, Enums.Side.PLAYER)
	unit.is_protagonist = true
	var weapon := loadout.weapon
	unit.weapon = weapon
	unit.weapon_family = weapon.family
	unit.weapon_damage_type = weapon.damage_type
	unit.weapon_power = weapon.base_power
	unit.weapon_stagger = weapon.base_stagger
	unit.base_tempo += weapon.tempo_modifier
	_append_action(unit, weapon.basic_attack)
	for technique in weapon.techniques:
		_append_action(unit, technique)
	for action in definition.innate_actions:
		_append_action(unit, action)
	for item in loadout.equipped_armor():
		for action in item.granted_actions:
			_append_action(unit, action)
	_append_action(unit, weapon.guard_action if weapon.guard_action != null else ctx.balance.default_guard_action)
	_append_action(unit, ctx.balance.default_inspect_action)
	for trait_def in weapon.traits:
		_add_trait(unit, trait_def, weapon.display_name)
	for item in loadout.equipped_armor():
		for trait_def in item.traits:
			_add_trait(unit, trait_def, item.display_name)
	for resonance in active_resonances(ctx.library, loadout):
		_add_trait(unit, resonance.trait_def, "Resonance: %s" % resonance.display_name)
	if loadout.familiar != null:
		_add_trait(unit, loadout.familiar.trait_def, loadout.familiar.display_name)
	_finalize(ctx, unit, ctx.balance.party_starting_focus)


static func _add_companion(ctx: BattleContext, definition: CompanionDefinition) -> void:
	var unit := _new_unit(ctx, definition, Enums.Side.PLAYER)
	unit.is_companion = true
	unit.weapon_family = definition.weapon_family
	unit.weapon_damage_type = definition.weapon_damage_type
	unit.weapon_power = definition.weapon_power
	unit.weapon_stagger = definition.weapon_stagger
	_append_action(unit, definition.basic_action)
	for technique in definition.techniques:
		_append_action(unit, technique)
	_append_action(unit, definition.guard_action if definition.guard_action != null else ctx.balance.default_guard_action)
	_append_action(unit, ctx.balance.default_inspect_action)
	if definition.passive != null:
		_add_trait(unit, definition.passive, definition.display_name)
	_finalize(ctx, unit, ctx.balance.party_starting_focus)


static func _add_enemy(ctx: BattleContext, definition: EnemyDefinition, suffix: String) -> void:
	var unit := _new_unit(ctx, definition, Enums.Side.ENEMY)
	if not suffix.is_empty():
		unit.display_name = "%s %s" % [definition.display_name, suffix]
	unit.enemy_actions.assign(definition.actions)
	unit.max_stagger = definition.max_stagger
	unit.stagger = definition.max_stagger
	unit.research_level = ctx.setup.research_level(definition.id)
	_finalize(ctx, unit, ctx.balance.enemy_starting_focus)


## Resonance synergies active for a loadout: two equipped items sharing a tag.
static func active_resonances(library: CombatLibrary, loadout: PartyLoadout) -> Array[ResonanceDefinition]:
	var counts: Dictionary[int, int] = {}
	var items: Array = [loadout.weapon]
	items.append_array(loadout.equipped_armor())
	for item in items:
		if item == null:
			continue
		for tag in item.resonance_tags:
			counts[tag] = counts.get(tag, 0) + 1
	var result: Array[ResonanceDefinition] = []
	var tags := counts.keys()
	tags.sort()
	for tag in tags:
		if counts[tag] >= ResonanceDefinition.REQUIRED_COUNT:
			var definition := library.resonance_def(tag)
			if definition != null and definition.trait_def != null:
				result.append(definition)
	return result


static func _append_action(unit: BattleUnit, action: ActionDefinition) -> void:
	if action != null and not unit.actions.has(action):
		unit.actions.append(action)


static func _add_trait(unit: BattleUnit, trait_def: TraitDefinition, source_name: String) -> void:
	if trait_def != null:
		unit.traits.append(TraitInstance.new(trait_def, unit.uid, source_name))
