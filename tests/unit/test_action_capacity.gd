extends TestCase
## Fifth playtest: the fixed action grid holds ActionMenu.CAPACITY (eight) non-item actions with no
## scrolling. A party member's actions come from UnitFactory: basic action, techniques, innate
## actions, armor-granted actions, the weapon's stance (or Guard) and Inspect. Every protagonist with
## every weapon and the most action-granting armor in each slot, and every companion, must fit;
## content that would exceed the grid is a loadout decision, never a silently dropped action.


func test_every_equipment_combination_fits_the_action_grid() -> void:
	var registry := Database.registry
	var granted_by_slot := {}
	for armor: ArmorDefinition in registry.armor.values():
		granted_by_slot[armor.slot] = maxi(granted_by_slot.get(armor.slot, 0), armor.granted_actions.size())
	var armor_actions := 0
	for count: int in granted_by_slot.values():
		armor_actions += count
	assert_false(registry.protagonists.is_empty())
	for hero: ProtagonistDefinition in registry.protagonists.values():
		for weapon: WeaponDefinition in registry.weapons.values():
			var count := 1 + weapon.techniques.size() + hero.innate_actions.size() + armor_actions + 2
			assert_lte(count, ActionMenu.CAPACITY, "%s with %s and the most action-granting armor" % [hero.id, weapon.id])
	for companion: CompanionDefinition in registry.companions.values():
		assert_lte(1 + companion.techniques.size() + 2, ActionMenu.CAPACITY, String(companion.id))


func test_shipped_loadouts_offer_their_real_actions_within_the_grid() -> void:
	var registry := Database.registry
	for id: StringName in registry.loadouts:
		var setup := BattleSetup.from_encounter(registry.loadouts[id], registry.encounters[&"fen_patrol"], Database.library,
			registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
		var engine := BattleEngine.new(setup)
		for unit in engine.get_state().party(false):
			var actions := ActionRules.options_for(engine.ctx, unit).filter(func(option: ActionOption) -> bool: return option.item_slot < 0)
			assert_eq(actions.size(), unit.actions.size(), "%s/%s: every action is offered" % [id, unit.display_name])
			assert_lte(actions.size(), ActionMenu.CAPACITY, "%s/%s fits the grid" % [id, unit.display_name])
