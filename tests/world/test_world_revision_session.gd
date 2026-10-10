extends TestCase
## Playtest revision through the production WorldSession: direct-crafted fittings (ownership, the
## exact Forge service, free Fit/Remove, the grandfathered older kit), the travelling familiar and
## its one selected passive, the bounded quest journal, the save origin of every write, one adopted
## fact per changed operation, structured gear reconciliation and a victory's Bestiary Learnings.

const BENCH := &"preparation_bench"
const STILLROOM := &"stillroom_table"
const KIT := &"forge.first_fitting"
const CRAFT_GRIP := &"forge.merciful_grip"
const CRAFT_ECHO := &"forge.hollow_echo"
const GRIP := &"fitting.merciful_grip"
const ECHO := &"fitting.hollow_echo"
const EDGE := &"pilgrims_edge"
const PATROL := &"reedway_patrol"
const GUARD := &"bell_guard"
const REEDWAY := &"briarfen_reedway"

var kit: WorldKit
var crafted: Array[CraftingResult] = []
var prepared: Array[PreparationResult] = []
var familiars: Array[FamiliarResult] = []
var quests: Array[QuestChange] = []
var saves: Array[SaveFact] = []
var legacy_saves: Array = []
var _slot: int


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	_slot = GameState.active_slot
	for list: Array in [crafted, prepared, familiars, quests, saves, legacy_saves]:
		list.clear()
	EventBus.crafting_completed.connect(_on_crafted)
	EventBus.preparation_completed.connect(_on_prepared)
	EventBus.familiar_changed.connect(_on_familiar)
	EventBus.quest_changed.connect(_on_quest)
	EventBus.save_completed.connect(_on_saved)
	EventBus.game_saved.connect(_on_legacy_saved)


func after_each() -> void:
	EventBus.crafting_completed.disconnect(_on_crafted)
	EventBus.preparation_completed.disconnect(_on_prepared)
	EventBus.familiar_changed.disconnect(_on_familiar)
	EventBus.quest_changed.disconnect(_on_quest)
	EventBus.save_completed.disconnect(_on_saved)
	EventBus.game_saved.disconnect(_on_legacy_saved)
	GameState.active_slot = _slot
	GameState.take_fresh_journey()
	kit.restore()


func _on_crafted(result: CraftingResult) -> void:
	crafted.append(result)


func _on_prepared(result: PreparationResult) -> void:
	prepared.append(result)


func _on_familiar(result: FamiliarResult) -> void:
	familiars.append(result)


func _on_quest(change: QuestChange) -> void:
	quests.append(change)


## Records the origin with the live state it saw, to prove the fact came after adoption.
func _on_saved(fact: SaveFact) -> void:
	saves.append(fact)
	assert_eq(JSON.stringify(GameState.progress.to_dict()), JSON.stringify(kit.writer.last()), "published after adoption")


func _on_legacy_saved(slot: int, ok: bool) -> void:
	legacy_saves.append([slot, ok])


static func _snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())), "", true)


static func _fund(iron: int, mastery: int = 1) -> void:
	var progress := GameState.progress
	progress.materials.clear()
	if iron > 0:
		progress.materials[&"bog_iron"] = iron
	progress.weapon_mastery.clear()
	if mastery > 0:
		progress.weapon_mastery[EDGE] = mastery


# --- Fittings ---------------------------------------------------------------------------------------

func test_a_fitting_is_crafted_once_then_fitted_and_removed_for_free() -> void:
	var session := kit.session()
	session.open()
	_fund(5)
	# Station and encounter rules: only the open Forge anvil crafts and fits.
	var before := _snapshot()
	assert_eq(session.craft_fitting(GRIP), ERR_UNAVAILABLE)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.NO_STATION)
	session.enter_station(STILLROOM)
	assert_eq(session.craft_fitting(GRIP), ERR_UNAVAILABLE)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.WRONG_STATION)
	assert_eq(session.fit(EDGE, GRIP), ERR_UNAVAILABLE)
	session.enter_station(BENCH)
	# An unowned fitting cannot be fitted: the readout offers Craft, never Fit.
	assert_eq(session.fit(EDGE, GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.FITTING_NOT_OWNED)
	assert_eq(session.craft_fitting(&"fitting.unknown"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.UNKNOWN_FITTING)
	assert_eq([_snapshot(), kit.writer.writes.size(), crafted.size()], [before, 0, 0])
	var readout := session.crafting().fitting(EDGE)
	assert_eq([readout.sockets.size(), readout.socket_capacity, readout.capacity, readout.kit_owned], [3, 1, true, false])
	assert_eq(readout.sockets.map(func(socket: Dictionary) -> bool: return socket.locked), [false, true, true])
	assert_eq(readout.sockets[1].reason, CraftingResult.Reason.LOCKED_SOCKET)
	var grip: Dictionary = readout.option(GRIP)
	assert_eq([grip.owned, grip.owned_source, grip.action, grip.can_craft, grip.can_fit, grip.recipe_id, grip.mastery_met],
		[false, &"", &"craft", true, false, CRAFT_GRIP, true])
	assert_eq((grip.costs as Array).map(func(cost: Dictionary) -> Array: return [cost.id, cost.count, cost.held, cost.enough]),
		[[&"bog_iron", 2, 5, true]])
	assert_eq(grip.reason, CraftingResult.Reason.FITTING_NOT_OWNED)
	# Craft: the price is spent once and ownership recorded, in one write, with one adopted fact.
	assert_eq(session.craft_fitting(GRIP), OK)
	var result := session.last_crafting
	assert_eq([result.command, result.changed, result.modification_id, result.recipe_id, result.weapon_id, result.operation()],
		[CraftingResult.Command.CRAFT, true, GRIP, CRAFT_GRIP, EDGE, &"craft"])
	assert_eq(result.spent.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]), [[&"bog_iron", 2, 3]])
	assert_eq([GameState.progress.material_count(&"bog_iron"), GameState.progress.crafting_recipes],
		[3, [CRAFT_GRIP] as Array[StringName]])
	assert_eq([kit.writer.writes.size(), crafted.size(), saves.size()], [1, 1, 1])
	assert_eq(AudioManager.operation_cue(result), AudioManager.Cue.CRAFT_SMITH)
	assert_false(GameState.progress.weapon_fittings.has(EDGE), "crafting does not install")
	# Never charged twice.
	assert_eq(session.craft_fitting(GRIP), ERR_ALREADY_EXISTS)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.ALREADY_OWNED)
	assert_eq([GameState.progress.material_count(&"bog_iron"), kit.writer.writes.size(), crafted.size()], [3, 1, 1])
	grip = session.crafting().fitting(EDGE).option(GRIP)
	assert_eq([grip.owned, grip.owned_source, grip.action, grip.can_craft, grip.can_fit],
		[true, CraftingRules.OWNED_CRAFTED, &"fit", false, true])
	# Fit and Remove are free and need a usable socket.
	assert_eq(session.fit(EDGE, GRIP, 1), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.LOCKED_SOCKET)
	assert_eq(session.fit(EDGE, GRIP, 5), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.INVALID_SOCKET)
	assert_eq(session.fit(EDGE, GRIP, 0), OK)
	assert_eq([session.last_crafting.operation(), session.last_crafting.spent.size(), session.last_crafting.socket],
		[&"fit", 0, 0])
	assert_eq(AudioManager.operation_cue(session.last_crafting), AudioManager.Cue.UI_EQUIP)
	assert_eq([GameState.progress.weapon_fittings.get(EDGE), GameState.progress.material_count(&"bog_iron")], [GRIP, 3])
	assert_eq(session.fit(EDGE, GRIP), OK, "re-choosing the installed fitting is an accepted no-op")
	assert_eq([session.last_crafting.changed, kit.writer.writes.size(), crafted.size()], [false, 2, 2])
	grip = session.crafting().fitting(EDGE).option(GRIP)
	assert_eq([grip.installed, grip.action, grip.can_remove], [true, &"remove", true])
	assert_eq(session.crafting().fitting(EDGE).sockets[0].fitting_id, GRIP)
	assert_eq(session.fit(EDGE, ECHO), ERR_INVALID_PARAMETER, "the other fitting has not been crafted")
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.FITTING_NOT_OWNED)
	assert_eq(session.remove_fitting(EDGE), OK)
	assert_eq([session.last_crafting.operation(), GameState.progress.weapon_fittings.has(EDGE),
		GameState.progress.material_count(&"bog_iron")], [&"remove", false, 3], "removing refunds nothing")
	assert_eq(AudioManager.operation_cue(session.last_crafting), AudioManager.Cue.UI_UNEQUIP)
	assert_true(CraftingRules.fitting_owned(GameState.progress, session.registry, EDGE, GRIP), "and the fitting stays owned")
	assert_eq(session.fit(EDGE, GRIP), OK)
	# The second fitting has its own price; the route's materials decide what can be afforded.
	assert_eq(session.craft_fitting(ECHO), OK)
	assert_eq(GameState.progress.material_count(&"bog_iron"), 1)
	assert_eq(session.fit(EDGE, ECHO), OK, "swapping between owned fittings is free")
	assert_eq(GameState.progress.material_count(&"bog_iron"), 1)
	# The fitting reaches the next immutable entry; ownership survives Reset journey and a reload.
	var entry := session.begin_entry(PATROL, PATROL)
	assert_eq(entry.loadout().modifications, ["fitting.hollow_echo"])
	assert_eq(session.leave_entry(entry), OK)
	assert_eq(session.reset_journey(), OK)
	var reloaded := ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq([reloaded.crafting_recipes, reloaded.weapon_fittings.get(EDGE)], [[CRAFT_ECHO, CRAFT_GRIP] as Array[StringName], ECHO])
	assert_empty(PreparationRules.repair_loadout(reloaded, session.registry), "nothing to repair")


func test_crafting_needs_mastery_and_materials_and_fails_safely() -> void:
	var session := kit.session()
	session.open()
	session.enter_station(BENCH)
	_fund(2, 0)
	assert_eq(session.craft_fitting(GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.MASTERY_REQUIRED)
	assert_false(session.last_crafting.text().is_empty())
	_fund(1, 1)
	assert_eq(session.craft_fitting(GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	var option: Dictionary = session.crafting().fitting(EDGE).option(GRIP)
	assert_eq([option.can_craft, option.craft_reason, option.action], [false, CraftingResult.Reason.INSUFFICIENT_MATERIALS, &"craft"])
	# A failed write spends nothing, owns nothing and announces nothing; the retry crafts once.
	_fund(2, 1)
	var before := _snapshot()
	kit.writer.fail = true
	assert_eq(session.craft_fitting(GRIP), ERR_FILE_CANT_WRITE)
	assert_eq([session.last_crafting.reason, session.last_crafting.changed, session.last_crafting.spent.size()],
		[CraftingResult.Reason.WRITE_FAILED, false, 0])
	assert_eq([_snapshot(), crafted.size(), saves.size()], [before, 0, 0])
	kit.writer.fail = false
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq([GameState.progress.material_count(&"bog_iron"), crafted.size()], [0, 1])
	# The old purchase entry point: a fitting recipe crafts, the retired kit is refused.
	_fund(4, 1)
	assert_eq(session.purchase(CRAFT_ECHO), OK)
	assert_eq([session.last_crafting.command, GameState.progress.material_count(&"bog_iron")], [CraftingResult.Command.CRAFT, 2])
	assert_eq(session.purchase(KIT), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.RECIPE_RETIRED)
	assert_false(GameState.progress.has_recipe(KIT))
	assert_eq(GameState.progress.material_count(&"bog_iron"), 2, "a retired kit can never be bought")
	var kit_recipe := session.crafting().recipe(KIT)
	assert_eq([kit_recipe.retired, kit_recipe.can_purchase, kit_recipe.purchase_reason],
		[true, false, CraftingResult.Reason.RECIPE_RETIRED])


func test_an_older_kit_keeps_its_fittings_and_its_refund_right() -> void:
	# A save from before the revision: the kit, Merciful Grip installed, 1 Bog Iron left.
	GameState.progress.add_recipe(KIT)
	GameState.progress.weapon_fittings[EDGE] = GRIP
	_fund(1)
	var session := kit.session()
	session.open()
	assert_eq(session.reconcile(), OK)
	assert_empty(kit.writer.writes, "loading refunds, clears and charges nothing")
	assert_eq(GameState.progress.weapon_fittings.get(EDGE), GRIP, "the working build is kept")
	assert_eq(PreparationRules.battle_ids(GameState.progress, session.registry).modifications, ["fitting.merciful_grip"])
	session.enter_station(BENCH)
	var readout := session.crafting().fitting(EDGE)
	assert_eq([readout.kit_owned, readout.installed_id, readout.active], [true, GRIP, true])
	for fitting_id: StringName in [GRIP, ECHO]:
		var option: Dictionary = readout.option(fitting_id)
		assert_eq([option.owned, option.owned_source, option.can_craft], [true, CraftingRules.OWNED_LEGACY_KIT, false],
			"%s is grandfathered" % fitting_id)
	assert_eq([readout.option(GRIP).action, readout.option(ECHO).action], [&"remove", &"fit"])
	assert_eq([readout.legacy_kit.id, readout.legacy_kit.owned, readout.legacy_kit.can_refund], [KIT, true, true])
	assert_eq((readout.legacy_kit.refund as Array).map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]),
		[[&"bog_iron", 2, 3]])
	# Swapping between the grandfathered fittings stays free.
	assert_eq(session.craft_fitting(ECHO), ERR_ALREADY_EXISTS)
	assert_eq(session.fit(EDGE, ECHO), OK)
	assert_eq(GameState.progress.material_count(&"bog_iron"), 1)
	# The refund is a deliberate Forge command: exactly the price, once.
	assert_eq(session.refund(KIT), OK)
	var refund := session.last_crafting
	assert_eq([refund.command, refund.operation(), refund.cleared_fitting], [CraftingResult.Command.REFUND, &"refund", ECHO])
	assert_eq(refund.refunded.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]), [[&"bog_iron", 2, 3]])
	assert_eq(AudioManager.operation_cue(refund), AudioManager.Cue.PURCHASE)
	assert_eq([GameState.progress.material_count(&"bog_iron"), GameState.progress.has_recipe(KIT),
		GameState.progress.weapon_fittings.has(EDGE)], [3, false, false])
	assert_eq(session.refund(KIT), ERR_INVALID_PARAMETER, "never a second reimbursement")
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.RECIPE_NOT_OWNED)
	assert_eq(GameState.progress.material_count(&"bog_iron"), 3)
	assert_eq(session.fit(EDGE, GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.FITTING_NOT_OWNED, "the kit's fittings went with it")
	# From here the player crafts like anyone else.
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq(session.fit(EDGE, GRIP), OK)
	assert_eq(session.refund(CRAFT_GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.NOT_REFUNDABLE, "a crafted fitting has no refund")


# --- Familiar ----------------------------------------------------------------------------------------

func test_the_familiar_and_its_passive_are_saved_validated_field_choices() -> void:
	var session := kit.session()
	session.open()
	var readout := session.familiar()
	assert_eq([readout.familiar_id, readout.passive_id, readout.passive_cells, readout.available()],
		[&"bell_crow", &"bell_crow", 3, true])
	assert_eq(readout.choices.map(func(entry: Dictionary) -> Array: return [entry.id, entry.selected, entry.selectable]),
		[[&"bell_crow", true, true], [&"cinder_pup", false, true]], "owned familiars only, in the save's order")
	assert_eq(readout.passives.map(func(entry: Dictionary) -> Array: return [entry.id, entry.selected]), [[&"bell_crow", true]],
		"today's familiars author one passive each; none is invented")
	# Rejections write nothing.
	assert_eq(session.choose_familiar(&"no_such_pet"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_familiar.reason, FamiliarResult.Reason.UNKNOWN_FAMILIAR)
	GameState.progress.familiars.erase(&"cinder_pup")
	assert_eq(session.choose_familiar(&"cinder_pup"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_familiar.reason, FamiliarResult.Reason.NOT_OWNED)
	assert_false(session.last_familiar.text().is_empty())
	GameState.progress.familiars.append(&"cinder_pup")
	assert_eq(session.choose_familiar_passive(&"cinder_pup"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_familiar.reason, FamiliarResult.Reason.UNKNOWN_PASSIVE, "a passive must belong to the travelling familiar")
	assert_eq(session.choose_familiar(&"bell_crow"), OK)
	assert_false(session.last_familiar.changed, "re-choosing is a no-op")
	assert_eq(session.choose_familiar_passive(&"bell_crow"), OK)
	assert_false(session.last_familiar.changed)
	assert_eq([kit.writer.writes.size(), familiars.size(), saves.size()], [0, 0, 0])
	# A change: one write, the default passive of the new familiar selected with it, one fact.
	assert_eq(session.choose_familiar(&"cinder_pup"), OK)
	var result := session.last_familiar
	assert_eq([result.command, result.changed, result.familiar_id, result.passive_id, result.previous_familiar_id,
		result.previous_passive_id, result.operation()],
		[FamiliarResult.Command.CHOOSE_FAMILIAR, true, &"cinder_pup", &"cinder_pup", &"bell_crow", &"bell_crow", &"equip"])
	assert_eq([GameState.progress.loadout_familiar, GameState.progress.loadout_familiar_passive], [&"cinder_pup", &"cinder_pup"])
	assert_eq([kit.writer.writes.size(), familiars.size(), saves.size()], [1, 1, 1])
	assert_eq(AudioManager.operation_cue(result), AudioManager.Cue.UI_EQUIP)
	# The loadout readout agrees with what the battle applies.
	var loadout := session.loadout()
	assert_eq([loadout.familiar.familiar_id, loadout.familiar.passive_id], [&"cinder_pup", &"cinder_pup"])
	var familiar_passives := loadout.passives.filter(func(entry: Dictionary) -> bool: return entry.kind == &"familiar")
	assert_eq(familiar_passives.map(func(entry: Dictionary) -> StringName: return entry.id), [&"cinder_pup"])
	# The entry snapshot captures both ids; the battle applies exactly that trait and no unit.
	var entry := session.begin_entry(PATROL, PATROL)
	assert_eq([entry.loadout().familiar, entry.loadout().familiar_passive], ["cinder_pup", "cinder_pup"])
	var driver := BattleDriver.new(entry.build_setup(Database.registry, Database.library))
	driver.next_request()
	var state := driver.engine.get_state()
	assert_eq([state.familiar.id, state.familiar_trait.id], [&"cinder_pup", &"cinder_pup"])
	assert_eq(state.party().size(), 2, "a familiar is never a unit: no turn, no target, no HP")
	assert_true(driver.hero().traits.any(func(instance: TraitInstance) -> bool: return instance.trait_def == state.familiar_trait))
	assert_false(driver.hero().traits.any(func(instance: TraitInstance) -> bool:
		return instance.trait_def == Database.registry.familiars[&"bell_crow"].trait_def), "the other familiar's passive is not applied")
	# During the encounter nothing can change; a failed write changes nothing.
	assert_eq(session.choose_familiar(&"bell_crow"), ERR_UNAVAILABLE)
	assert_eq(session.last_familiar.reason, FamiliarResult.Reason.ENCOUNTER_PENDING)
	assert_eq(session.leave_entry(entry), OK)
	kit.writer.fail = true
	assert_eq(session.choose_familiar(&"bell_crow"), ERR_FILE_CANT_WRITE)
	assert_eq([session.last_familiar.reason, session.last_familiar.changed, GameState.progress.loadout_familiar, familiars.size()],
		[FamiliarResult.Reason.WRITE_FAILED, false, &"cinder_pup", 1])
	kit.writer.fail = false
	assert_eq(session.choose_familiar(&"bell_crow"), OK)
	assert_eq([GameState.progress.loadout_familiar, familiars.size()], [&"bell_crow", 2])


func test_authored_passive_choices_are_selected_one_at_a_time() -> void:
	# A fixture familiar with three authored passives (today's content has one each).
	var registry := DefinitionRegistry.load_default()
	registry.familiars = registry.familiars.duplicate()
	var crow: FamiliarDefinition = registry.familiars[&"bell_crow"].duplicate()
	var second: TraitDefinition = crow.trait_def.duplicate()
	second.id = &"crow_second"
	second.display_name = "Second Bell"
	var third: TraitDefinition = crow.trait_def.duplicate()
	third.id = &"crow_third"
	third.display_name = "Third Bell"
	# A shallow duplicate shares its arrays with the shipped familiar: the fixture gets its own.
	var offered: Array[TraitDefinition] = [crow.trait_def, second, third]
	crow.passives = offered
	registry.familiars[&"bell_crow"] = crow
	assert_empty(crow.validate())
	assert_empty(Database.registry.familiars[&"bell_crow"].passives, "the shipped Bell Crow is untouched")
	var session := kit.session()
	session.registry = registry
	session.open()
	var readout := session.familiar()
	assert_eq(readout.passives.map(func(entry: Dictionary) -> Array: return [entry.id, entry.selected, entry.selectable]),
		[[&"bell_crow", true, true], [&"crow_second", false, true], [&"crow_third", false, true]])
	assert_eq(session.choose_familiar_passive(&"crow_third"), OK)
	assert_eq([session.last_familiar.changed, session.last_familiar.previous_passive_id, GameState.progress.loadout_familiar_passive],
		[true, &"bell_crow", &"crow_third"])
	assert_eq(session.familiar().passives.filter(func(entry: Dictionary) -> bool: return entry.selected).size(), 1,
		"exactly one passive is selected")
	assert_eq(session.choose_familiar_passive(&"crow_fourth"), ERR_INVALID_PARAMETER)
	# The battle applies the selected one, only.
	var ids := PreparationRules.battle_ids(GameState.progress, registry)
	assert_eq(ids.familiar_passive, "crow_third")
	var loadout := PartyLoadout.from_ids(registry, ids)
	assert_eq(loadout.familiar_trait(), third)
	# A fourth authored passive is a catalog problem, never a silent fourth choice.
	var crowded: FamiliarDefinition = crow.duplicate()
	var fourth: TraitDefinition = crow.trait_def.duplicate()
	fourth.id = &"crow_fourth"
	var too_many: Array[TraitDefinition] = [crow.trait_def, second, third, fourth]
	crowded.passives = too_many
	assert_true("\n".join(crowded.validate()).contains("more than 3 passives"))
	assert_eq(crowded.passive_choices().size(), 3)
	# An edited save naming a passive the familiar does not offer, or an unknown familiar, is repaired.
	GameState.progress.loadout_familiar_passive = &"cinder_pup"
	assert_eq(FamiliarRules.passive_id(GameState.progress, registry), &"bell_crow", "the default applies meanwhile")
	var repairs := FamiliarRules.repair(GameState.progress, registry)
	assert_eq([repairs.size(), GameState.progress.loadout_familiar_passive], [1, &""])
	GameState.progress.loadout_familiar = &"ghost_cat"
	repairs = FamiliarRules.repair(GameState.progress, registry)
	assert_eq([repairs.size(), GameState.progress.loadout_familiar], [1, &"bell_crow"])
	assert_empty(FamiliarRules.repair(GameState.progress, registry))


# --- Quest journal -----------------------------------------------------------------------------------

func test_the_journal_follows_the_bell_journey_and_announces_only_adopted_changes() -> void:
	var session := kit.session()
	session.open()
	var journal := session.quests()
	assert_eq([journal.active.size(), journal.completed.size()], [1, 0])
	var quest := journal.quest(QuestRules.BELL)
	assert_eq([quest.id, quest.stage, quest.stage_count, quest.completed, quest.objective],
		[QuestRules.BELL, QuestRules.BellStage.FIND, 4, false, WorldCopy.OBJECTIVE_FIND])
	assert_false(quest.title.is_empty())
	assert_eq(quest.steps.map(func(step: Dictionary) -> Array: return [step.text, step.done, step.current]),
		[[WorldCopy.OBJECTIVE_FIND, false, true], [WorldCopy.OBJECTIVE_RESTORE, false, false],
		[WorldCopy.OBJECTIVE_RETURN, false, false]])
	# Opening, reading and rebuilding announce nothing and write nothing.
	session.quests()
	assert_eq(session.reconcile(), OK)
	assert_eq([quests.size(), kit.writer.writes.size()], [0, 0])
	# Writes that do not move the journey change nothing.
	assert_eq(session.arrive(REEDWAY, &"reedway_entry"), OK)
	assert_eq(session.save(), OK)
	assert_empty(quests)
	# Clearing the guard advances it, in the victory's own write.
	var entry := session.begin_entry(GUARD, GUARD)
	assert_empty(quests, "entering is not progress")
	assert_eq(session.commit_victory(entry, WorldKit.victory(GUARD)), OK)
	assert_eq(quests.size(), 1)
	assert_eq([quests[0].kind, quests[0].quest_id, quests[0].previous_stage, quests[0].stage, quests[0].objective],
		[QuestChange.Kind.ADVANCED, QuestRules.BELL, QuestRules.BellStage.FIND, QuestRules.BellStage.RESTORE,
		WorldCopy.OBJECTIVE_RESTORE])
	assert_eq(session.last_quest_changes, quests)
	assert_eq(int(kit.writer.last().quests[String(QuestRules.BELL)]), QuestRules.BellStage.RESTORE, "saved with the victory")
	# A failed write announces nothing; its retry announces once.
	kit.writer.fail = true
	assert_eq(session.restore_bell(REEDWAY), ERR_FILE_CANT_WRITE)
	assert_eq(quests.size(), 1)
	kit.writer.fail = false
	assert_eq(session.restore_bell(REEDWAY), OK)
	assert_eq([quests.size(), quests[1].kind, quests[1].stage], [2, QuestChange.Kind.ADVANCED, QuestRules.BellStage.RETURN])
	# Returning home completes it; it stays completed when the player walks out again.
	assert_eq(session.arrive(&"gloamstead", &"reed_gate"), OK)
	assert_eq([quests.size(), quests[2].kind, quests[2].stage], [3, QuestChange.Kind.COMPLETED, QuestRules.BellStage.COMPLETE])
	assert_eq(session.arrive(REEDWAY, &"reedway_entry"), OK)
	assert_eq(quests.size(), 3)
	journal = session.quests()
	assert_eq([journal.active.size(), journal.completed.size()], [0, 1])
	assert_true(journal.completed[0].steps.all(func(step: Dictionary) -> bool: return step.done and not step.current))
	# No reward, flag or item comes from the journal.
	assert_eq(GameState.progress.reward_claims.filter(func(claim: StringName) -> bool: return String(claim).contains("quest")).size(), 0)
	# Reset journey returns it to the first step in the same write and says so once.
	assert_eq(session.reset_journey(), OK)
	assert_eq([quests.size(), quests[3].kind, quests[3].previous_stage, quests[3].stage],
		[4, QuestChange.Kind.RESET, QuestRules.BellStage.COMPLETE, QuestRules.BellStage.FIND])
	assert_eq(session.quests().quest(QuestRules.BELL).stage, QuestRules.BellStage.FIND)
	assert_eq(int(kit.writer.last().quests[String(QuestRules.BELL)]), QuestRules.BellStage.FIND)
	assert_eq(session.reset_journey(), OK)
	assert_eq(quests.size(), 4, "a reset that changes no stage announces nothing")


func test_loading_never_replays_quest_news_and_a_new_journey_announces_once() -> void:
	# An older save mid-journey: the guard cleared, no journal entry at all.
	GameState.progress.world.cleared.append(GUARD)
	GameState.progress.reward_claims.append(&"first_footsteps.guard")
	GameState.progress.quests.clear()
	var session := kit.session()
	session.open()
	assert_eq(session.quests().quest(QuestRules.BELL).stage, QuestRules.BellStage.RESTORE,
		"reading derives the stage from the world without writing")
	assert_empty(kit.writer.writes)
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), 1, "world entry records the derived stage once")
	assert_eq(GameState.progress.quests[QuestRules.BELL], QuestRules.BellStage.RESTORE)
	assert_empty(quests, "an older save's quest is recorded silently")
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), 1)
	# A stale or edited stage is corrected by the next world write, without news at world entry.
	GameState.progress.quests[QuestRules.BELL] = QuestRules.BellStage.COMPLETE
	assert_eq(session.reconcile(), OK)
	assert_eq([GameState.progress.quests[QuestRules.BELL], quests.size()], [QuestRules.BellStage.RESTORE, 0])
	# Without a prior world entry, the first write of any kind still records it silently.
	GameState.progress.quests.clear()
	assert_eq(session.save(), OK)
	assert_eq([GameState.progress.quests[QuestRules.BELL], quests.size()], [QuestRules.BellStage.RESTORE, 0])
	# A journey created this session is announced once, by the host's explicit call, with no write.
	var fresh := JourneyRules.fresh_progress(WorldDefinition.load_default(), &"reedbow", Enums.TacticalDifficulty.ADVENTURER,
		Database.registry)
	assert_eq(fresh.quests, {QuestRules.BELL: QuestRules.BellStage.FIND} as Dictionary[StringName, int],
		"recorded by the journey's own first write")
	GameState.progress = fresh
	var writes := kit.writer.writes.size()
	var started := kit.session()
	started.open()
	assert_eq(started.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), writes, "a new journey needs no world-entry write")
	var announced := started.announce_new_journey()
	assert_eq([announced.size(), quests.size(), quests[0].kind, quests[0].previous_stage, quests[0].stage, quests[0].objective],
		[1, 1, QuestChange.Kind.ACQUIRED, -1, QuestRules.BellStage.FIND, WorldCopy.OBJECTIVE_FIND])
	assert_eq(kit.writer.writes.size(), writes)
	# GameState hands that announcement out exactly once per created journey.
	GameState._fresh_journey = true
	assert_true(GameState.take_fresh_journey())
	assert_false(GameState.take_fresh_journey())


# --- Save origin and operation facts -----------------------------------------------------------------

func test_every_successful_write_publishes_its_origin_once() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	# Automatic writes: arrival, an interaction, equipment, arrangement, entry and leaving.
	var automatic: Array[Callable] = [
		func() -> Error: return session.arrive(REEDWAY, &"reedway_entry"),
		func() -> Error: return session.complete_interaction(&"gloamstead", &"bellkeeper"),
		func() -> Error: return session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"),
		func() -> Error: return session.arrange_action(0, &"spark"),
		func() -> Error: return OK if session.begin_entry(PATROL, PATROL) != null else FAILED,
		func() -> Error: return session.leave_entry(GameState.progress.world.pending_entry),
		func() -> Error: return session.reset_journey(),
	]
	for index in automatic.size():
		assert_eq(automatic[index].call(), OK, "write %d" % index)
		assert_eq([saves.size(), legacy_saves.size()], [index + 1, index + 1], "write %d: one fact, one legacy event" % index)
		assert_eq([saves[index].origin, saves[index].manual(), saves[index].slot],
			[SaveFact.Origin.AUTOMATIC, false, GameState.active_slot], "write %d is automatic" % index)
	# The explicit Save command (Save, Save and return to title, Save and Quit all use it): manual.
	assert_eq(session.save(), OK)
	assert_eq([saves.size(), saves.back().origin, saves.back().manual()], [automatic.size() + 1, SaveFact.Origin.MANUAL, true])
	# A rejection, an accepted no-op and a failed write publish nothing.
	var count := saves.size()
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK, "a no-op")
	assert_eq(session.equip(Enums.EquipSlot.WEAPON, &"no_such_blade"), ERR_INVALID_PARAMETER)
	kit.writer.fail = true
	assert_eq(session.save(), ERR_FILE_CANT_WRITE)
	assert_eq(session.arrive(&"gloamstead", &"reed_gate"), ERR_FILE_CANT_WRITE)
	kit.writer.fail = false
	assert_eq([saves.size(), legacy_saves.size()], [count, count])
	# New Journey's first write is automatic too (and still publishes the legacy event).
	var journey := GameState.start_journey({"difficulty": Enums.TacticalDifficulty.ADVENTURER, "preset_id": &"pilgrims_edge",
		"slot": 1, "replace": true}, func(_target: int, progress: ProgressState) -> Error: return kit.writer.write(progress))
	assert_true(journey.ok())
	assert_eq([saves.size(), saves.back().origin, saves.back().slot], [count + 1, SaveFact.Origin.AUTOMATIC, 1])
	assert_true(GameState.take_fresh_journey())
	var rejected := GameState.start_journey({"difficulty": 9, "preset_id": &"pilgrims_edge", "slot": 1, "replace": true},
		func(_target: int, progress: ProgressState) -> Error: return kit.writer.write(progress))
	assert_false(rejected.ok())
	assert_eq(saves.size(), count + 1, "a rejected journey publishes nothing")
	assert_false(GameState.take_fresh_journey())


func test_equipment_publishes_one_structured_fact_per_changed_command() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	assert_eq([prepared.size(), prepared[0].operation(), prepared[0].changed], [1, &"equip", true])
	assert_eq(AudioManager.operation_cue(prepared[0]), AudioManager.Cue.UI_EQUIP)
	# A re-choice, a rejection and a failed write publish nothing and map to no cue.
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	assert_eq(AudioManager.operation_cue(session.last_preparation), -1)
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"pilgrims_coat"), ERR_INVALID_PARAMETER)
	assert_eq(AudioManager.operation_cue(session.last_preparation), -1)
	kit.writer.fail = true
	assert_eq(session.unequip(Enums.EquipSlot.CHARM), ERR_FILE_CANT_WRITE)
	assert_eq(AudioManager.operation_cue(session.last_preparation), -1)
	kit.writer.fail = false
	assert_eq(prepared.size(), 1)
	assert_eq(session.unequip(Enums.EquipSlot.CHARM), OK)
	assert_eq([prepared.size(), prepared[1].operation()], [2, &"unequip"])
	assert_eq(AudioManager.operation_cue(prepared[1]), AudioManager.Cue.UI_UNEQUIP)
	assert_eq(AudioManager.operation_cue(null), -1)
	assert_eq(AudioManager.operation_cue(CombatResult.new()), -1, "an arrangement has no operation cue")
	# A weapon change reconciles the arrangement in the same write and reports structured facts:
	# what left, what joined and what kept its position. No prose is needed to highlight them.
	var before := CombatRules.arrangement(GameState.progress, session.registry)
	assert_eq(session.choose_weapon(&"mire_maul"), OK)
	var result := session.last_preparation
	assert_eq([result.arrangement_before, result.arrangement_after],
		[before, CombatRules.arrangement(GameState.progress, session.registry)])
	assert_eq(result.actions_removed.size(), result.actions_added.size())
	assert_gt(result.actions_removed.size(), 0.0)
	for entry in result.actions_removed:
		assert_true(before.has(entry.id) and not result.arrangement_after.has(entry.id), "%s left" % entry.id)
		assert_eq(before[int(entry.position)], entry.id)
	for entry in result.actions_added:
		assert_true(result.arrangement_after.has(entry.id) and not before.has(entry.id), "%s joined" % entry.id)
	for entry in result.actions_kept:
		assert_true(before.has(entry.id), "%s was arranged before" % entry.id)
		assert_eq(result.arrangement_after[int(entry.position)], entry.id)
	assert_eq(result.actions_kept.size() + result.actions_added.size(), result.arrangement_after.size())
	assert_eq(result.arrangement_after.size(), CombatRules.STARTING_CAPACITY, "six usable positions, as before")
	# The equipment option previews the same facts before the command.
	var preview: Dictionary = session.preparation().slot(Enums.EquipSlot.WEAPON).option(&"pilgrims_edge").combat
	assert_true(preview.has("removed") and preview.has("added") and preview.has("kept"))
	assert_eq((preview.removed as Array).size(), (preview.added as Array).size())


# --- Victory learnings -------------------------------------------------------------------------------

func test_a_victory_reports_only_real_tier_increases_with_the_tier_before_adoption() -> void:
	var session := kit.session()
	session.open()
	var site := WorldKit.site(GUARD)
	var enemy_ids: Array[StringName] = []
	for enemy in site.encounter.enemies:
		if not enemy_ids.has(enemy.id):
			enemy_ids.append(enemy.id)
	enemy_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var entry := session.begin_entry(GUARD, GUARD)
	var result := WorldKit.victory(GUARD)
	# A failed write adopts nothing: no learning, and the old tier is still the old tier.
	kit.writer.fail = true
	assert_eq(session.commit_victory(entry, result), ERR_FILE_CANT_WRITE)
	assert_empty(session.last_learnings)
	for enemy_id in enemy_ids:
		assert_eq(GameState.research_level(enemy_id), Enums.ResearchLevel.UNKNOWN)
	kit.writer.fail = false
	assert_eq(session.commit_victory(entry, result), OK)
	var learnings := session.last_learnings
	assert_eq(learnings.map(func(learning: LearningReadout) -> StringName: return learning.enemy_id), enemy_ids,
		"one entry per enemy whose tier rose, by id")
	for learning in learnings:
		var enemy: EnemyDefinition = Database.registry.enemies[learning.enemy_id]
		assert_eq([learning.previous_tier, learning.new_tier, learning.name],
			[Enums.ResearchLevel.UNKNOWN, GameState.research_level(learning.enemy_id), enemy.display_name],
			"%s: the tier before adoption, kept through the failed write" % learning.enemy_id)
		assert_gt(learning.new_tier, learning.previous_tier)
		assert_eq([learning.previous_tier_name, learning.new_tier_name],
			[EnumText.research_level(Enums.ResearchLevel.UNKNOWN), EnumText.research_level(learning.new_tier as Enums.ResearchLevel)])
		assert_false(learning.plain_text().is_empty())
	# Salvage receipts are the same saved facts as before.
	assert_eq(session.last_receipts.map(func(receipt: RewardReadout) -> StringName: return receipt.claim_id),
		[&"first_footsteps.guard"])
	# A repeated result reports nothing.
	assert_eq(session.commit_victory(entry, result), ERR_ALREADY_EXISTS)
	assert_empty(session.last_learnings)
	# Research that raises no tier (the enemies are already at the top tier) reports none.
	for enemy_id in enemy_ids:
		GameState.progress.bestiary.add(enemy_id, Enums.ResearchSource.LORE, 1000)
		assert_eq(GameState.research_level(enemy_id), Enums.ResearchLevel.MASTERED)
	var patrol := session.begin_entry(PATROL, PATROL)
	var quiet := BattleResult.new()
	quiet.outcome = Enums.BattleOutcome.VICTORY
	for enemy_id in enemy_ids:
		quiet.research[enemy_id] = result.research[enemy_id]
	assert_eq(session.commit_victory(patrol, quiet), OK)
	for enemy_id in enemy_ids:
		assert_eq(GameState.research_level(enemy_id), Enums.ResearchLevel.MASTERED)
	assert_empty(session.last_learnings, "no tier increase, no transition")
