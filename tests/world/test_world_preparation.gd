extends TestCase
## V0.5A campaign preparation through the production WorldSession (V0.5 UI: equipment is a field
## command from Character, blocked only by a pending or active encounter); unknown, unowned, wrong-slot items and an
## over-limit loadout are rejected whole with a typed reason; optional slots empty; failed writes
## change nothing; an older saved loadout keeps valid gear. Equipping the restoration reward reaches
## the next immutable entry and a real Wet → Shock battle through the Grounding trait.

## Species and encounter names: preparation readouts carry item facts only.
const FORBIDDEN := ["fen_patrol", "rot_grove", "Fen Patrol", "Rot Grove", "Bogshell", "Thornhound", "Fen Wisp",
	"Rotcap", "Sporecaller", "affinit", "weakness", "resist"]
const BENCH := &"preparation_bench"

var kit: WorldKit


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()


func after_each() -> void:
	kit.restore()


static func _win(session: WorldSession, site_id: StringName) -> void:
	var entry := session.begin_entry(site_id, site_id)
	session.commit_victory(entry, WorldKit.victory(site_id))


## Guard victory and the deliberate bell restoration: the Storm Salt Charm is owned.
func _earn_charm(session: WorldSession) -> void:
	_win(session, &"bell_guard")
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_true(GameState.progress.owned_equipment.has(&"storm_salt_charm"))


## The live progress as canonical JSON (numbers and key order as on disk).
static func _snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())), "", true)


func test_equipment_is_a_field_command_blocked_only_by_an_encounter() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	assert_eq(session.station(), &"")
	var readout := session.preparation()
	assert_true(readout.available(), "no station is needed or consulted")
	assert_eq([readout.station_id, readout.reason], [&"", PreparationResult.Reason.OK])
	assert_true(readout.slot(Enums.EquipSlot.CHARM).option(&"storm_salt_charm").selectable)
	# In the field, outside an encounter: each command writes once and charts no station.
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	assert_eq(session.choose_weapon(&"reedbow"), OK)
	assert_eq(session.unequip(Enums.EquipSlot.GARB), OK)
	assert_eq(kit.writer.writes.size(), 3)
	assert_false(GameState.progress.world.is_discovered(BENCH), "a field change charts no station")
	# Re-choosing the equipped item or emptying an empty slot is an accepted no-op: no write.
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	assert_false(session.last_preparation.changed)
	assert_eq(session.unequip(Enums.EquipSlot.RELIC), OK)
	assert_false(session.last_preparation.changed)
	assert_eq(kit.writer.writes.size(), 3, "no-ops write nothing")
	assert_eq(session.enter_station(&"bellkeeper"), ERR_INVALID_PARAMETER, "only a preparation landmark")
	assert_eq(session.enter_station(&"no_such_place"), ERR_INVALID_PARAMETER)
	# A pending or active encounter blocks every equipment change, whatever context is set.
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_not_null(entry)
	assert_eq(session.enter_station(BENCH), ERR_UNAVAILABLE)
	session._station = BENCH
	session._service = LandmarkDefinition.Service.FORGE
	var pending := _snapshot()
	for command: Callable in [
			func() -> Error: return session.equip(Enums.EquipSlot.GARB, &"pilgrims_coat"),
			func() -> Error: return session.unequip(Enums.EquipSlot.CHARM),
			func() -> Error: return session.choose_weapon(&"pilgrims_edge")]:
		assert_eq(command.call(), ERR_UNAVAILABLE)
		assert_eq(session.last_preparation.reason, PreparationResult.Reason.ENCOUNTER_PENDING)
	assert_eq(session.preparation().reason, PreparationResult.Reason.ENCOUNTER_PENDING)
	for option in session.preparation().slot(Enums.EquipSlot.WEAPON).options:
		assert_eq([option.selectable, option.reason], [false, PreparationResult.Reason.ENCOUNTER_PENDING])
	assert_eq(_snapshot(), pending, "nothing changed")
	assert_eq(kit.writer.writes.size(), 4, "only the entry was written")


func test_rejections_are_typed_and_change_nothing() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.enter_station(BENCH), OK)
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	var before := _snapshot()
	var cases := [
		[Enums.EquipSlot.CHARM, &"mirebell_sigil", PreparationResult.Reason.UNKNOWN_ITEM],
		[Enums.EquipSlot.GARB, &"storm_salt_charm", PreparationResult.Reason.WRONG_SLOT],
		[Enums.EquipSlot.CHARM, &"pilgrims_edge", PreparationResult.Reason.WRONG_SLOT],
		[Enums.EquipSlot.WEAPON, &"pilgrims_coat", PreparationResult.Reason.WRONG_SLOT],
		[Enums.EquipSlot.CHARM, &"ember_locket", PreparationResult.Reason.NOT_OWNED],
		[Enums.EquipSlot.WEAPON, &"thunderhead", PreparationResult.Reason.NOT_OWNED],
		[Enums.EquipSlot.RELIC, &"hollow_reliquary", PreparationResult.Reason.NOT_OWNED],
		[Enums.EquipSlot.WEAPON, &"", PreparationResult.Reason.REQUIRED_SLOT],
	]
	for case: Array in cases:
		assert_eq(session.equip(case[0], case[1]), ERR_INVALID_PARAMETER, "%s in %s" % [case[1], case[0]])
		var result := session.last_preparation
		assert_eq([result.reason, result.slot, result.item_id], [case[2], case[0], case[1]])
		assert_false(result.ok() or result.changed)
		assert_false(result.text().is_empty(), "a public reason")
	assert_eq(session.unequip(Enums.EquipSlot.WEAPON), ERR_INVALID_PARAMETER)
	assert_eq(session.last_preparation.reason, PreparationResult.Reason.REQUIRED_SLOT)
	assert_eq(kit.writer.writes.size(), 0, "nothing written")
	assert_eq(_snapshot(), before, "nothing changed")


func test_optional_slots_empty_and_starter_choices_survive() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.enter_station(BENCH), OK)
	assert_eq(session.unequip(Enums.EquipSlot.GARB), OK)
	assert_eq([session.last_preparation.previous_id, session.last_preparation.changed], [&"pilgrims_coat", true])
	assert_eq(GameState.progress.loadout_garb, &"")
	assert_eq(String(kit.writer.last().loadout.garb), "", "saved empty")
	assert_eq(session.unequip(Enums.EquipSlot.RELIC), OK, "an empty slot stays empty")
	assert_eq(session.equip(Enums.EquipSlot.GARB, &"pilgrims_coat"), OK)
	for weapon_id in [&"mire_maul", &"reedbow", &"pilgrims_edge"]:
		assert_eq(session.choose_weapon(weapon_id), OK, "every starter weapon stays available")
		assert_eq(GameState.progress.loadout_weapon, weapon_id)
	var writes := kit.writer.writes.size()
	assert_eq(session.choose_weapon(&"pilgrims_edge"), OK, "re-choosing the equipped weapon is fine")
	assert_false(session.last_preparation.changed)
	assert_eq(kit.writer.writes.size(), writes, "and writes nothing")


func test_failed_equip_write_changes_nothing_and_retry_applies_once() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	var before := _snapshot()
	kit.writer.fail = true
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), ERR_FILE_CANT_WRITE)
	assert_eq(session.last_preparation.reason, PreparationResult.Reason.WRITE_FAILED)
	assert_false(session.last_preparation.changed)
	assert_true(session.last_preparation.actions_removed.is_empty() and session.last_preparation.actions_added.is_empty())
	assert_eq(_snapshot(), before, "the live loadout and arrangement are unchanged")
	kit.writer.fail = false
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	assert_eq(GameState.progress.loadout_charm, &"storm_salt_charm")
	assert_eq(kit.writer.writes.size(), 1, "one successful change")


func test_an_over_limit_loadout_is_rejected_whole() -> void:
	# No shipped item adds actions; a test charm teaching two would give the Hollow nine.
	var registry := DefinitionRegistry.load_default()
	var charm := ArmorDefinition.new()
	charm.id = &"test_chorus_charm"
	charm.display_name = "Chorus Charm"
	charm.slot = Enums.EquipSlot.CHARM
	charm.granted_actions.assign([registry.actions[&"hammer_blow"], registry.actions[&"shockwave"]])
	registry.armor[charm.id] = charm
	var session := kit.session()
	session.registry = registry
	session.open()
	GameState.progress.owned_equipment.append(charm.id)
	assert_eq(session.enter_station(BENCH), OK)
	var readout := session.preparation()
	assert_eq(readout.granted_actions, 7, "the Hollow's shipped gear grants seven actions")
	assert_eq(readout.protagonist_actions, CombatRules.STARTING_CAPACITY, "and battle takes the six arranged")
	var option := readout.slot(Enums.EquipSlot.CHARM).option(charm.id)
	assert_eq(option.actions, 9)
	assert_false(option.selectable)
	assert_eq(option.reason, PreparationResult.Reason.ACTION_LIMIT)
	var before := _snapshot()
	assert_eq(session.equip(Enums.EquipSlot.CHARM, charm.id), ERR_INVALID_PARAMETER)
	assert_eq(session.last_preparation.reason, PreparationResult.Reason.ACTION_LIMIT)
	assert_true(session.last_preparation.text().contains(str(PartyLoadout.MAX_ACTIONS)))
	assert_eq(_snapshot(), before, "rejected whole: nothing truncated, nothing written")
	assert_eq(kit.writer.writes.size(), 0)
	# One extra action still fits the eight slots, Guard stance and Inspect included.
	charm.granted_actions.assign([registry.actions[&"hammer_blow"]])
	assert_eq(session.equip(Enums.EquipSlot.CHARM, charm.id), OK)
	var loadout := PartyLoadout.from_ids(registry, GameState.progress.loadout_ids())
	var actions := UnitFactory.protagonist_actions(loadout, registry.balance)
	assert_eq(actions.size(), PartyLoadout.MAX_ACTIONS)
	assert_true(actions.has(registry.balance.default_inspect_action) and actions.has(loadout.weapon.guard_action),
		"the stance and Inspect are never squeezed out")


func test_every_owned_shipped_choice_fits_the_eight_slots() -> void:
	var session := kit.session()
	session.open()
	for id: StringName in Database.registry.weapons:
		GameState.progress.owned_equipment.append(id)
	for id: StringName in Database.registry.armor:
		if not GameState.progress.owned_equipment.has(id):
			GameState.progress.owned_equipment.append(id)
	assert_eq(session.enter_station(BENCH), OK)
	for slot_readout in session.preparation().slots:
		for option in slot_readout.options:
			assert_true(option.selectable, "%s fits (%d actions)" % [option.id, option.actions])
			assert_lte(option.actions, PartyLoadout.MAX_ACTIONS)


func test_older_loadouts_keep_valid_gear_and_repair_the_rest_once() -> void:
	var data := ProgressState.new().to_dict()
	data.erase("rewards")
	data.loadout = {"weapon": "thunderhead", "garb": "fenrunner_leathers", "charm": "pilgrims_edge", "relic": "lost_relic",
		"companion": "mara", "familiar": "bell_crow", "potions": ["mending_draught", "fen_water_flask"]}
	GameState.progress = ProgressState.from_dict(SaveMigrator.migrate({"save_version": 1, "data": data}))
	var session := kit.session()
	session.open()
	assert_eq(session.reconcile(), OK)
	var progress := GameState.progress
	assert_eq([progress.loadout_weapon, progress.loadout_garb], [&"thunderhead", &"fenrunner_leathers"],
		"valid legacy gear is kept equipped")
	assert_true(progress.owned_equipment.has(&"thunderhead") and progress.owned_equipment.has(&"fenrunner_leathers"),
		"and recorded as owned")
	assert_eq([progress.loadout_charm, progress.loadout_relic], [&"", &""], "wrong-slot and unknown ids are not grandfathered")
	assert_false(progress.owned_equipment.has(&"lost_relic"))
	assert_eq(session.last_repairs.size(), 4)
	assert_eq(String(kit.writer.last().loadout.charm), "")
	var writes := kit.writer.writes.size()
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), writes, "repaired once")
	assert_true(session.last_repairs.is_empty())
	# An unknown or wrong-slot weapon falls back to a safe owned starter weapon.
	for bad_weapon in ["does_not_exist", "storm_salt_charm", ""]:
		GameState.progress = ProgressState.new()
		GameState.progress.loadout_weapon = StringName(bad_weapon)
		var repairing := kit.session()
		repairing.open()
		assert_eq(repairing.reconcile(), OK)
		assert_eq(GameState.progress.loadout_weapon, &"pilgrims_edge", "%s → starter weapon" % bad_weapon)
		assert_false(GameState.progress.owned_equipment.has(&"storm_salt_charm"))
	GameState.progress = ProgressState.new()
	GameState.progress.loadout_weapon = &"does_not_exist"
	GameState.progress.owned_equipment.assign([&"reedbow", &"pilgrims_coat"])
	var without_starter := kit.session()
	without_starter.open()
	assert_eq(without_starter.reconcile(), OK)
	assert_eq(GameState.progress.loadout_weapon, &"reedbow", "the first owned weapon when the starter is not owned")


func test_readouts_match_ownership_and_never_share_state() -> void:
	var session := kit.session()
	session.open()
	_earn_charm(session)
	assert_eq(session.enter_station(BENCH), OK)
	assert_eq(session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	var readout := session.preparation()
	assert_true(readout.available())
	assert_eq(readout.station_id, &"", "equipment readouts never name a station")
	assert_eq(readout.slots.map(func(slot_readout: EquipmentSlotReadout) -> int: return slot_readout.slot),
		[Enums.EquipSlot.WEAPON, Enums.EquipSlot.GARB, Enums.EquipSlot.CHARM, Enums.EquipSlot.RELIC])
	var weapons := readout.slot(Enums.EquipSlot.WEAPON)
	assert_false(weapons.optional or weapons.can_remove)
	assert_eq(weapons.options.map(func(option: Dictionary) -> StringName: return option.id),
		[&"pilgrims_edge", &"mire_maul", &"reedbow"], "owned weapons only, starters in their bench order")
	assert_eq(weapons.options.filter(func(option: Dictionary) -> bool: return option.equipped).size(), 1)
	assert_true(weapons.option(&"pilgrims_edge").equipped)
	assert_eq(weapons.option(&"mire_maul").category, "Hammer · Blunt")
	var charm := readout.slot(Enums.EquipSlot.CHARM)
	assert_eq([charm.equipped_id, charm.equipped_name, charm.can_remove], [&"storm_salt_charm", "Storm Salt Charm", true])
	var grounding: Dictionary = charm.option(&"storm_salt_charm").traits[0]
	var authored: TraitDefinition = Database.registry.armor[&"storm_salt_charm"].traits[0]
	assert_eq([grounding.name, grounding.description], [authored.display_name, authored.description], "the public trait text")
	assert_eq(charm.option(&"storm_salt_charm").resonance, PackedStringArray(["Storm"]))
	assert_true(readout.slot(Enums.EquipSlot.RELIC).options.is_empty(), "no relic owned")
	assert_true(readout.slot(Enums.EquipSlot.GARB).option(&"fenrunner_leathers").is_empty(), "unowned garb is not offered")
	var inventory := session.inventory()
	assert_eq(inventory.count(&"bog_iron"), GameState.progress.material_count(&"bog_iron"))
	assert_eq(inventory.count(&"storm_salt"), GameState.progress.material_count(&"storm_salt"))
	assert_true(inventory.owns(&"storm_salt_charm") and inventory.owns(&"pilgrims_coat"))
	var texts := PackedStringArray([inventory.plain_text()])
	for slot_readout in readout.slots:
		for option in slot_readout.options:
			texts.append(JSON.stringify(option))
	for text in texts:
		for word: String in FORBIDDEN:
			assert_false(text.contains(word), "no creature or encounter facts: %s" % word)
	# Readouts are copies: changing them changes neither the save nor the definitions.
	var before := _snapshot()
	charm.option(&"storm_salt_charm").traits[0].description = "changed"
	charm.options.clear()
	inventory.materials[0].count = 0
	inventory.equipment.clear()
	assert_eq(_snapshot(), before)
	assert_eq(authored.description, Database.registry.armor[&"storm_salt_charm"].traits[0].description)
	assert_ne(authored.description, "changed")
	# Away from every station the choices stay available: equipment is a field command.
	session.leave_station()
	for option in session.preparation().slot(Enums.EquipSlot.WEAPON).options:
		assert_eq([option.selectable, option.reason], [true, PreparationResult.Reason.OK])


func test_the_charm_reaches_the_next_entry_and_a_real_wet_shock_battle() -> void:
	var session := kit.session()
	session.open()
	_earn_charm(session)
	# Save → reload → equip at the station through the production command.
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	var station := kit.session()
	station.open()
	assert_eq(station.reconcile(), OK)
	assert_true(station.last_receipts.is_empty(), "nothing to catch up after a reload")
	assert_eq(station.enter_station(BENCH), OK)
	assert_eq(station.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK)
	station.leave_station()
	assert_eq(String(kit.writer.last().loadout.charm), "storm_salt_charm")
	# Reload again; the next entry captures the charm.
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	var journey := kit.session(11)
	journey.open()
	var entry := journey.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(String(entry.to_dict().loadout.charm), "storm_salt_charm")
	var setup := entry.build_setup(Database.registry, Database.library)
	assert_eq(setup.loadout.charm, Database.registry.armor[&"storm_salt_charm"])
	var engine := BattleEngine.new(setup)
	var hero := engine.get_state().protagonist()
	assert_true(hero.traits.any(func(instance: TraitInstance) -> bool:
		return instance.trait_def.id == &"grounding" and instance.source_name == "Storm Salt Charm"),
		"the Hollow carries the authored Grounding trait")
	# The same captured battle with and without the charm: flask (Wet) then Spark (Shock).
	var data := entry.to_dict()
	data.loadout.charm = ""
	var plain := EncounterEntry.from_dict(data).build_setup(Database.registry, Database.library)
	var with_charm := _flask_then_spark(setup)
	var without := _flask_then_spark(plain)
	assert_eq(with_charm.target, without.target, "identical battle up to the interaction")
	assert_eq(with_charm.before_spark, 0, "Wet alone never triggers Grounding")
	assert_eq(with_charm.triggers, 1, "Shock on the Wet target triggers Grounding once")
	assert_eq(without.triggers, 0)
	var grounding: TriggeredEffectDefinition = Database.registry.armor[&"storm_salt_charm"].traits[0].triggers[0]
	assert_eq(grounding.effects[0].type, Enums.EffectType.STAGGER_DAMAGE)
	assert_gte(with_charm.trigger_stagger, grounding.effects[0].amount, "its authored Stagger (Shock may raise it)")
	assert_almost_eq(with_charm.spark_stagger - without.spark_stagger, with_charm.trigger_stagger, 0.01,
		"the charm adds exactly that Stagger to the Spark")
	# A captured entry stays immutable: no field change while it is pending; a retry keeps the charm.
	assert_eq(journey.enter_station(BENCH), ERR_UNAVAILABLE)
	GameState.progress.loadout_charm = &""
	var retry := EncounterEntry.from_dict(GameState.progress.world.pending_entry.to_dict()).build_setup(Database.registry,
		Database.library)
	assert_eq(retry.loadout.charm, Database.registry.armor[&"storm_salt_charm"])
	assert_eq(WorldKit.fingerprint(retry), WorldKit.fingerprint(entry.build_setup(Database.registry, Database.library)))
	# After the encounter closes, removing the charm applies to the next entry only.
	assert_eq(journey.return_home(entry), OK)
	assert_eq(journey.enter_station(BENCH), OK)
	assert_eq(journey.unequip(Enums.EquipSlot.CHARM), OK)
	journey.leave_station()
	var next := journey.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_null(next.build_setup(Database.registry, Database.library).loadout.charm)


## Plays [param setup] with fixed choices: Mara guards; the Hollow throws the Fen Water Flask at
## the first enemy, then casts Spark at it. Reports the Grounding triggers and the Stagger dealt to
## that enemy while Spark resolves (a Break may refill its bar, so the bar itself is not compared).
func _flask_then_spark(setup: BattleSetup) -> Dictionary:
	var driver := BattleDriver.new(setup)
	var report := {"target": -1, "before_spark": 0, "triggers": 0, "trigger_stagger": 0.0, "spark_stagger": 0.0,
		"stagger_left": -1.0}
	var hero := driver.hero()
	var target := driver.enemy(0).uid
	report.target = target
	var flask_thrown := false
	for turn in 20:
		var request := driver.to_player_turn()
		if request == null:
			break
		if request.unit_uid != hero.uid:
			var guard := request.legal_options().filter(func(option: ActionOption) -> bool:
				return option.action.category == Enums.ActionCategory.GUARD)
			assert_eq(driver.act(guard[0].action.id), OK)
			continue
		if not flask_thrown:
			assert_eq(driver.act(&"use_fen_water_flask", target), OK)
			flask_thrown = true
			continue
		report.before_spark = _charm_triggers(driver.events)
		var mark := driver.events.size()
		assert_eq(driver.act(&"spark", target), OK, "Spark is affordable on the Hollow's next turn")
		driver.next_request()
		var spark_events := driver.events.slice(mark)
		report.triggers = _charm_triggers(spark_events)
		for index in spark_events.size():
			var event: BattleEvent = spark_events[index]
			if event.type == BattleEvent.Type.STAGGER_DAMAGE and event.subject == target:
				report.spark_stagger += event.amount
			if event.type == BattleEvent.Type.TRIGGER_ACTIVATED and event.text == "Storm Salt Charm":
				for later in spark_events.slice(index + 1):
					if later.type == BattleEvent.Type.STAGGER_DAMAGE and later.subject == target:
						report.trigger_stagger = later.amount
						break
		report.stagger_left = driver.engine.get_state().units[target].stagger
		break
	assert_ne(report.stagger_left, -1.0, "the scripted turns reached Spark")
	return report


static func _charm_triggers(events: Array) -> int:
	return events.filter(func(event: BattleEvent) -> bool:
		return event.type == BattleEvent.Type.TRIGGER_ACTIVATED and event.text == "Storm Salt Charm").size()
