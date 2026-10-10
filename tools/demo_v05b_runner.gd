extends Node
## Runtime half of tools/demo_v05b.gd (loaded once the autoloads exist). See that file.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")
## A throwaway slot inside the isolated QA home.
const SLOT := 7
const BENCH := &"preparation_bench"
const STILLROOM := &"stillroom_table"
const KIT := &"forge.first_fitting"
const SALVE := &"stillroom.clotting_salve"
const TINCTURE := &"stillroom.focus_tincture"
const GRIP := &"fitting.merciful_grip"
const EDGE := &"pilgrims_edge"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment(QA_USER_DATA.ENV).is_empty() or not QA_USER_DATA.check():
		printerr("Run this through tools/qa_godot.py: it writes a save, and only into an isolated QA home.")
		get_tree().quit(1)
		return
	var ok: bool = await _demo()
	SaveManager.delete_slot(SLOT)
	print("\nDemo %s." % ("finished" if ok else "FAILED"))
	# Release every cue voice and music deck so the audio server drops their playbacks before exit.
	AudioManager.silence()
	for frame in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if ok else 1)


func _demo() -> bool:
	GameState.active_slot = SLOT
	SaveManager.delete_slot(SLOT)
	GameState._session_resumed = true
	GameState.new_game()
	print("1. New game in throwaway slot %d. Recipes: %s. Materials: none. Mastery: none." % [SLOT, _recipes()])

	var session := WorldSession.new(null, Callable(), 21)
	session.open()
	var entry: EncounterEntry
	var result: BattleResult
	for attempt in 6:
		entry = session.begin_entry(&"bell_guard", &"bell_guard")
		if entry == null:
			return _fail("could not capture the guard entry (%s)" % error_string(session.last_error))
		result = _autoplay(entry.build_setup(Database.registry, Database.library))
		if result.is_victory():
			break
		session.return_home(entry)
	if result == null or not result.is_victory() or session.commit_victory(entry, result) != OK:
		return _fail("the guard victory was not committed")
	if session.restore_bell(&"briarfen_reedway") != OK:
		return _fail("bell restoration write failed")
	print("2. Guard victory and bell committed. Held: %s. Pilgrim's Edge mastery: %d." % [_held(),
		GameState.progress.weapon_mastery.get(EDGE, 0)])

	# The stations (V0.5 UI): the anvil's interaction opens the Forge service, the Stillroom table's the
	# Stillroom service; each rejects the other's work. Potion choices are field choices.
	var host := WorldHost.new()
	host.session = WorldSession.new(null, Callable(), 22)
	add_child(host)
	await get_tree().process_frame
	await get_tree().physics_frame
	host.load_area(&"gloamstead", &"town_bell")
	var station := host.session
	station.purchase(KIT)
	print("3. Away from the stations: purchase → %s (%s)" % [error_string(station.last_error), station.last_crafting.text()])
	if not await _open_station(host, BENCH):
		return _fail("the Forge did not open")
	print("   At the Forge anvil (station: %s):\n      %s" % [station.station(), station.crafting().plain_text().replace("\n", "\n      ")])
	_run_commands(station, [["purchase(%s)" % KIT, func() -> Error: return station.purchase(KIT)],
			["purchase(%s) at the anvil" % TINCTURE, func() -> Error: return station.purchase(TINCTURE)],
			["fit(Pilgrim's Edge, Merciful Grip)", func() -> Error: return station.fit(EDGE, GRIP)],
			["refund(%s)" % KIT, func() -> Error: return station.refund(KIT)],
			["purchase(%s) again" % KIT, func() -> Error: return station.purchase(KIT)],
			["fit(Pilgrim's Edge, Merciful Grip) again", func() -> Error: return station.fit(EDGE, GRIP)]])
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	if not await _open_station(host, STILLROOM):
		return _fail("the Stillroom did not open")
	print("   At the Stillroom (station: %s):" % station.station())
	_run_commands(station, [["refund(%s) at the Stillroom" % KIT, func() -> Error: return station.refund(KIT)],
			["purchase(%s)" % TINCTURE, func() -> Error: return station.purchase(TINCTURE)],
			["purchase(%s)" % SALVE, func() -> Error: return station.purchase(SALVE)]])
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	station.refund(KIT)
	print("   Stations closed (station: '%s'); refund now → %s" % [station.station(), error_string(station.last_error)])
	_run_commands(station, [["prepare_potion(2, Focus Tincture) in the field", func() -> Error: return station.prepare_potion(1, &"focus_tincture")]])
	host.queue_free()
	await get_tree().process_frame

	# Reload; the next entry captures the fitting and the potions.
	GameState.progress = ProgressState.new()
	if SaveManager.load_slot(SLOT) != OK:
		return _fail("could not reload the slot")
	print("4. Reloaded from disk. Recipes: %s. Fittings: %s. Potions: %s." % [_recipes(),
		GameState.progress.weapon_fittings, GameState.progress.loadout_potions])
	var journey := WorldSession.new(null, Callable(), 23)
	journey.open()
	var next := journey.begin_entry(&"reedway_patrol", &"reedway_patrol")
	if next == null:
		return _fail("could not capture the patrol entry")
	print("5. Next entry %s captures fittings %s and potions %s." % [next.token(), next.to_dict().loadout.modifications,
		next.to_dict().loadout.potions])
	var engine := BattleEngine.new(next.build_setup(Database.registry, Database.library))
	var traits := PackedStringArray()
	for instance in engine.get_state().protagonist().traits:
		traits.append("%s (%s)" % [instance.trait_def.display_name, instance.source_name])
	print("   The Hollow's traits: %s" % ", ".join(traits))
	var slots := PackedStringArray()
	for state in engine.get_state().potion_slots:
		slots.append("%s ×%d (authored %d)" % [state.potion.display_name, state.charges, state.potion.charges])
	print("   Potion slots: %s" % ", ".join(slots))
	var battle := _parry_then_tincture(engine)
	if battle.is_empty():
		return _fail("the scripted Parry and tincture turn did not happen")
	print("6. The Hollow Parried successfully: %s fired, restoring %.0f HP." % [battle.source, battle.heal])
	print("   Focus Tincture used: Focus %d → %d; charges left %d." % [battle.focus_before, battle.focus_after, battle.charges])
	journey.leave_entry(next)

	if journey.reset_journey() != OK:
		return _fail("reset failed")
	print("7. Reset journey. Recipes: %s. Fittings: %s. Held: %s." % [_recipes(), GameState.progress.weapon_fittings, _held()])
	return battle.heal == 8.0 and GameState.progress.crafting_recipes.size() == 2


## Walks the Hollow to [param landmark_id] and presses Confirm; true when its station service opened.
func _open_station(host: WorldHost, landmark_id: StringName) -> bool:
	host.player.place(host.area.point(landmark_id) + Vector2(0, 28))
	await get_tree().physics_frame
	await get_tree().physics_frame
	host.interact()
	return host.modal != null and host.modal.kind == &"crafting" and host.session.station() == landmark_id


func _run_commands(station: WorldSession, commands: Array) -> void:
	for command: Array in commands:
		var err: Error = (command[1] as Callable).call()
		var crafted := station.last_crafting
		var extra := " (fitting %s cleared)" % crafted.cleared_fitting if crafted.cleared_fitting != &"" else ""
		print("   %s → %s: %s%s Held: %s." % [command[0], error_string(err), crafted.summary(), extra, _held()])


func _autoplay(setup: BattleSetup) -> BattleResult:
	var engine := BattleEngine.new(setup)
	var autopilot := PartyAutopilot.new(PartyAutopilot.Policy.SMART, setup.seed + 1)
	var executor := ExecutionSimulator.new(Database.registry.skill(Enums.SimulatedExecution.PERFECT), setup.seed + 2)
	for guard in 5000:
		if engine.is_finished():
			break
		engine.advance()
		engine.drain_events()
		var request := engine.get_request()
		if request == null:
			continue
		match request.kind:
			BattleRequest.Kind.ACTION_SELECT:
				engine.submit_action(autopilot.choose(engine, request as ActionSelectRequest))
			BattleRequest.Kind.ACTION_COMMAND:
				engine.submit_command_result(executor.grade_command((request as CommandRequest).spec, setup.assist))
			BattleRequest.Kind.REACTION:
				engine.submit_reaction(executor.react(setup.library.balance, request as ReactionRequest))
	return engine.build_result()


## The party Guards until an attack on the Hollow can be Parried; it is Parried successfully. On
## the Hollow's next turn it drinks the Focus Tincture.
func _parry_then_tincture(engine: BattleEngine) -> Dictionary:
	var hero := engine.get_state().protagonist()
	hero.hp = hero.max_hp - 30
	var report := {}
	var events: Array[BattleEvent] = []
	var parried := false
	var mark := -1
	for step in 800:
		engine.advance()
		events.append_array(engine.drain_events())
		var request := engine.get_request()
		if request == null:
			continue
		if request is ReactionRequest:
			var reaction := request as ReactionRequest
			if not parried and reaction.target_uids.has(hero.uid) and reaction.spec.is_allowed(Enums.ReactionType.PARRY):
				parried = true
				mark = events.size()
				engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
			else:
				engine.submit_reaction(ReactionResult.none())
		elif request is CommandRequest:
			engine.submit_command_result(Enums.ExecutionGrade.GOOD)
		elif request is ActionSelectRequest:
			var select := request as ActionSelectRequest
			if parried and select.unit_uid == hero.uid:
				for option in select.legal_options():
					if option.action.id == &"use_focus_tincture":
						_parry_facts(events.slice(mark), hero.uid, report)
						hero.focus = 0
						var slot: PotionSlotState = engine.get_state().potion_slots[option.item_slot]
						engine.submit_action(ActionChoice.from_option(select.unit_uid, option, hero.uid))
						engine.advance()
						engine.drain_events()
						report.focus_before = 0
						report.focus_after = hero.focus
						report.charges = slot.charges
						return report if report.has("heal") else {}
			for option in select.legal_options():
				if option.action.category == Enums.ActionCategory.GUARD:
					engine.submit_action(ActionChoice.from_option(select.unit_uid, option,
						option.target_uids[0] if not option.target_uids.is_empty() else -1))
					break
	return {}


## The fitting trigger that followed the Parry and the HP it restored.
static func _parry_facts(events: Array, hero_uid: int, report: Dictionary) -> void:
	for index in events.size():
		var event: BattleEvent = events[index]
		if event.type == BattleEvent.Type.TRIGGER_ACTIVATED and event.subject == hero_uid:
			for later: BattleEvent in events.slice(index + 1):
				if later.type == BattleEvent.Type.HEAL and later.subject == hero_uid:
					report.source = event.text
					report.heal = later.amount
					return


static func _recipes() -> String:
	var ids := PackedStringArray()
	for id in GameState.progress.crafting_recipes:
		ids.append(String(id))
	return "[%s]" % ", ".join(ids)


static func _held() -> String:
	var parts := PackedStringArray()
	for id in Database.registry.sorted_ids(Database.registry.materials):
		parts.append("%d %s" % [GameState.progress.material_count(id), Database.registry.materials[id].display_name])
	return ", ".join(parts)


func _fail(message: String) -> bool:
	printerr("Demo stopped: " + message)
	return false
