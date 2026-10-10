extends Node
## Runtime half of tools/demo_v05a.gd (loaded once the autoloads exist). See that file.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")
## A throwaway slot inside the isolated QA home.
const SLOT := 7
const BENCH := &"preparation_bench"


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
	print("1. New game in throwaway slot %d. Claims: %s. Materials: none." % [SLOT, _claims()])

	# World accomplishment: the bell guard, played by the autopilot, committed by the production session.
	var session := WorldSession.new(null, Callable(), 21)
	session.open()
	var entry: EncounterEntry
	var result: BattleResult
	for attempt in 6:
		entry = session.begin_entry(&"bell_guard", &"bell_guard")
		if entry == null:
			return _fail("could not capture the guard entry (%s)" % error_string(session.last_error))
		result = _autoplay(entry.build_setup(Database.registry, Database.library))
		print("   Guard attempt %d: %s in %d rounds." % [attempt + 1, EnumText.outcome(result.outcome), result.rounds])
		if result.is_victory():
			break
		session.return_home(entry)
	if result == null or not result.is_victory():
		return _fail("the autopilot did not win the guard fight")
	if session.commit_victory(entry, result) != OK:
		return _fail("victory write failed")
	print("2. Guard victory committed. %s" % _receipts(session))
	if session.commit_victory(entry, result) != ERR_ALREADY_EXISTS:
		return _fail("a repeated result was not a no-op")
	print("   Repeating the same result: no-op, %d receipts." % session.last_receipts.size())

	if session.restore_bell(&"briarfen_reedway") != OK:
		return _fail("bell restoration write failed")
	print("3. Wayside bell restored. %s" % _receipts(session))

	# Persistence: everything comes back from the file.
	GameState.progress = ProgressState.new()
	if SaveManager.load_slot(SLOT) != OK:
		return _fail("could not reload the slot")
	print("4. Reloaded from disk. Claims: %s." % _claims())
	print("   Inventory:\n      %s" % session.inventory().plain_text().replace("\n", "\n      "))

	# V0.5 UI: equipment is a field command from Character (no station); only an encounter blocks it.
	var host := WorldHost.new()
	host.session = WorldSession.new(null, Callable(), 22)
	add_child(host)
	await get_tree().process_frame
	await get_tree().physics_frame
	host.load_area(&"gloamstead", &"town_bell")
	print("5. In the field (station: '%s'). Charm slot before: %s" % [host.session.station(), _charm_slot(host.session)])
	if host.session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm") != OK:
		return _fail("equip failed: %s" % host.session.last_preparation.text())
	print("   equip(CHARM, storm_salt_charm) → OK: %s Charm slot now: %s" % [host.session.last_preparation.summary(),
		_charm_slot(host.session)])
	host.session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm")
	print("   The same choice again → %s" % host.session.last_preparation.summary())
	host.queue_free()
	await get_tree().process_frame

	# The next encounter entry is captured from the saved loadout and builds the battle.
	GameState.progress = ProgressState.new()
	if SaveManager.load_slot(SLOT) != OK:
		return _fail("could not reload the slot")
	var journey := WorldSession.new(null, Callable(), 23)
	journey.open()
	var next := journey.begin_entry(&"reedway_patrol", &"reedway_patrol")
	if next == null:
		return _fail("could not capture the patrol entry")
	print("6. Reloaded; next entry %s captures charm '%s' and actions %s." % [next.token(), next.to_dict().loadout.charm,
		next.to_dict().loadout.actions])
	print("   During the encounter: unequip → %s (%s)" % [error_string(journey.unequip(Enums.EquipSlot.CHARM)),
		journey.last_preparation.text()])
	var setup := next.build_setup(Database.registry, Database.library)
	var engine := BattleEngine.new(setup)
	var traits := PackedStringArray()
	for instance in engine.get_state().protagonist().traits:
		traits.append("%s (%s)" % [instance.trait_def.display_name, instance.source_name])
	print("   The Hollow's traits: %s" % ", ".join(traits))
	var stagger := _flask_then_spark(engine)
	if stagger.is_empty():
		return _fail("the scripted Wet → Shock turn did not happen")
	print("7. Fen Water Flask (Wet) then Spark (Shock) at the first enemy: Grounding fired %d time(s), %.1f Stagger%s." % [
		stagger.triggers, stagger.amount, "; the target Broke" if stagger.broke else ""])
	journey.leave_entry(next)
	return stagger.triggers == 1


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


## Companion guards; the Hollow throws the flask at the first enemy, then casts Spark at it.
func _flask_then_spark(engine: BattleEngine) -> Dictionary:
	var hero := engine.get_state().protagonist()
	var target := engine.get_state().enemies(false)[0].uid
	var flask_thrown := false
	var events: Array[BattleEvent] = []
	for step in 400:
		engine.advance()
		events.append_array(engine.drain_events())
		var request := engine.get_request()
		if request == null:
			continue
		if request is ReactionRequest:
			engine.submit_reaction(ReactionResult.none())
		elif request is CommandRequest:
			engine.submit_command_result(Enums.ExecutionGrade.GOOD)
		elif request is ActionSelectRequest:
			var select := request as ActionSelectRequest
			var wanted := &"use_fen_water_flask" if not flask_thrown else &"spark"
			if select.unit_uid != hero.uid:
				wanted = &""
			for option in select.legal_options():
				var is_guard := wanted == &"" and option.action.category == Enums.ActionCategory.GUARD
				if option.action.id == wanted or is_guard:
					if wanted == &"spark":
						var mark := events.size()
						engine.submit_action(ActionChoice.from_option(select.unit_uid, option, target))
						engine.submit_command_result(Enums.ExecutionGrade.GOOD)
						engine.advance()
						events.append_array(engine.drain_events())
						return _grounding(events.slice(mark), target)
					engine.submit_action(ActionChoice.from_option(select.unit_uid, option,
						target if option.target_uids.has(target) else (option.target_uids[0] if not option.target_uids.is_empty() else -1)))
					flask_thrown = flask_thrown or option.action.id == &"use_fen_water_flask"
					break
	return {}


static func _grounding(events: Array, target: int) -> Dictionary:
	var report := {"triggers": 0, "amount": 0.0, "broke": false}
	for index in events.size():
		var event: BattleEvent = events[index]
		if event.type == BattleEvent.Type.BROKEN and event.subject == target:
			report.broke = true
		if event.type == BattleEvent.Type.TRIGGER_ACTIVATED and event.text == "Storm Salt Charm":
			report.triggers += 1
			for later: BattleEvent in events.slice(index + 1):
				if later.type == BattleEvent.Type.STAGGER_DAMAGE and later.subject == target:
					report.amount = later.amount
					break
	return report


func _charm_slot(session: WorldSession) -> String:
	var slot := session.preparation().slot(Enums.EquipSlot.CHARM)
	var options := PackedStringArray()
	for option in slot.options:
		options.append("%s%s" % [option.name, " [equipped]" if option.equipped else ""])
	return "equipped '%s'; owned choices: %s" % [slot.equipped_name, ", ".join(options)]


static func _claims() -> String:
	var claims := PackedStringArray()
	for claim in GameState.progress.reward_claims:
		claims.append(String(claim))
	return "[%s]" % ", ".join(claims)


static func _receipts(session: WorldSession) -> String:
	var lines := PackedStringArray()
	for receipt in session.last_receipts:
		lines.append("%s → %s" % [receipt.label, receipt.summary()])
	return "Receipts: " + ("; ".join(lines) if not lines.is_empty() else "none")


func _fail(message: String) -> bool:
	printerr("Demo stopped: " + message)
	return false
