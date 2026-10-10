extends Node
## Runtime half of tools/demo_v05c.gd (loaded once the autoloads exist). See that file.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")
const KIT := preload("res://tests/fixtures/exploration_kit.gd")
## A throwaway slot inside the isolated QA home.
const SLOT := 7


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment(QA_USER_DATA.ENV).is_empty() or not QA_USER_DATA.check():
		printerr("Run this through tools/qa_godot.py: it writes a save, and only into an isolated QA home.")
		get_tree().quit(1)
		return
	var ok: bool = _demo()
	SaveManager.delete_slot(SLOT)
	print("\nDemo %s." % ("finished" if ok else "FAILED"))
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
	var world: WorldDefinition = KIT.world()
	var session := _session(world)
	print("1. New game in throwaway slot %d on the V0.5C fixture world." % SLOT)
	_line("2. Gather the iron seam", session.gather(KIT.REEDWAY, KIT.NODE), session)
	_line("   Gather it again", session.gather(KIT.REEDWAY, KIT.NODE), session)
	_line("3. Search the drowned niche before the puzzle", session.find_secret(KIT.REEDWAY, KIT.SECRET), session)
	for rune: StringName in [KIT.LOW, KIT.MID, KIT.LOW, KIT.HIGH, KIT.MID]:
		_line("   Strike %s" % rune, session.strike_rune(KIT.REEDWAY, rune), session)
	_line("4. Search the drowned niche", session.find_secret(KIT.REEDWAY, KIT.SECRET), session)

	GameState.progress = ProgressState.new()
	if SaveManager.load_slot(SLOT) != OK:
		return _fail("could not reload the slot")
	session = _session(world)
	var state := GameState.progress
	print("5. Reloaded from disk. Gathered %s, solved %s, found %s. Claims: %s. Bog Iron %d. Owns Fenrunner Leathers: %s." % [
		state.world.gathered, state.world.solved, state.world.found, state.reward_claims, state.material_count(&"bog_iron"),
		state.owned_equipment.has(&"fenrunner_leathers")])
	if session.reset_journey() != OK:
		return _fail("reset failed")
	state = GameState.progress
	print("6. Reset journey. Gathered %s, solved %s, found %s; claims kept: %d." % [state.world.gathered, state.world.solved,
		state.world.found, state.reward_claims.size()])
	_line("   Gather again", session.gather(KIT.REEDWAY, KIT.NODE), session)
	for rune: StringName in [KIT.LOW, KIT.HIGH, KIT.MID]:
		_line("   Strike %s" % rune, session.strike_rune(KIT.REEDWAY, rune), session)
	_line("   Search the niche again", session.find_secret(KIT.REEDWAY, KIT.SECRET), session)
	print("7. After the repeat: Bog Iron %d, Fenrunner Leathers owned once: %s." % [
		GameState.progress.material_count(&"bog_iron"), GameState.progress.owned_equipment.count(&"fenrunner_leathers") == 1])
	return GameState.progress.material_count(&"bog_iron") == 1 and GameState.progress.owned_equipment.count(&"fenrunner_leathers") == 1


func _session(world: WorldDefinition) -> WorldSession:
	var session := WorldSession.new(world, Callable(), 31)
	session.registry = KIT.registry(world)
	session.open()
	return session


func _line(label: String, err: Error, session: WorldSession) -> void:
	var result := session.last_exploration
	var parts := PackedStringArray([error_string(err)])
	if err == OK and result.command == ExplorationResult.Command.STRIKE:
		parts.append("%s %d/%d" % [ExplorationResult.Strike.keys()[result.strike].capitalize(), result.progress, result.length])
		if not result.revealed.is_empty():
			parts.append("revealed %s" % result.revealed)
	elif err != OK:
		parts.append(ExplorationResult.Reason.keys()[result.reason].capitalize())
	var receipts := PackedStringArray()
	for receipt in session.last_receipts:
		receipts.append("%s → %s" % [receipt.label, receipt.summary()])
	if not receipts.is_empty():
		parts.append("received " + "; ".join(receipts))
	elif err == OK and result.command != ExplorationResult.Command.STRIKE:
		parts.append("no reward (already claimed)" if not result.rewarded else "")
	print("%s → %s" % [label, ", ".join(parts)])


func _fail(message: String) -> bool:
	printerr("Demo stopped: " + message)
	return false
