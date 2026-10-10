extends TestCase
## V0.5A salvage through the production WorldSession: a committed victory or bell restoration
## grants its stable campaign reward exactly once, inside the same write. Duplicate results, failed
## writes and retries, Reset journey, reloads, defeat, leaving, interrupted entries, Practice and the
## recording Lab never duplicate or invent a grant. Older saves catch up only what their journey
## still proves, once, through the same atomic boundary.

const THROWAWAY_SLOT := 99

var kit: WorldKit
var received: Array[RewardReadout] = []


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	received.clear()
	EventBus.rewards_granted.connect(_on_reward)


func after_each() -> void:
	EventBus.rewards_granted.disconnect(_on_reward)
	kit.restore()


func _on_reward(receipt: RewardReadout) -> void:
	received.append(receipt)


## The authored count of [param material_id] in reward [param claim_id] (tests follow the data).
static func _authored(claim_id: StringName, material_id: StringName) -> int:
	var total := 0
	for item in Database.registry.rewards[claim_id].items:
		if item.kind == RewardItem.Kind.MATERIAL and item.material.id == material_id:
			total += item.count
	return total


static func _win(session: WorldSession, site_id: StringName) -> Error:
	var entry := session.begin_entry(site_id, site_id)
	if entry == null:
		return session.last_error
	return session.commit_victory(entry, WorldKit.victory(site_id))


## An older (pre-V0.5A) save: no `rewards` section, loaded through the migrator.
static func _old_save(prepare: Callable) -> void:
	var old := ProgressState.new()
	prepare.call(old)
	var data := old.to_dict()
	data.erase("rewards")
	GameState.progress = ProgressState.from_dict(SaveMigrator.migrate({"save_version": 1, "game_version": "0.3.0", "data": data}))


## Saved claims and material counts in the last write.
func _saved() -> Dictionary:
	var last := kit.writer.last()
	return {"claims": last.rewards.claims, "materials": last.inventory.materials, "equipment": last.inventory.equipment}


func test_patrol_victory_grants_its_salvage_once_in_the_same_write() -> void:
	var session := kit.session()
	session.open()
	var writes := kit.writer.writes.size()
	assert_eq(_win(session, &"reedway_patrol"), OK)
	assert_eq(kit.writer.writes.size(), writes + 2, "entry + victory: the reward is not a second write")
	var bog := _authored(&"first_footsteps.patrol", &"bog_iron")
	assert_eq(bog, 2, "the brief's provisional quantity")
	var progress := GameState.progress
	assert_eq(progress.material_count(&"bog_iron"), bog)
	assert_eq(progress.reward_claims, [&"first_footsteps.patrol"] as Array[StringName])
	var saved := _saved()
	assert_eq(saved.claims, ["first_footsteps.patrol"], "the claim is in the victory write")
	assert_eq(int(saved.materials.bog_iron), bog)
	assert_true(kit.writer.last().world.cleared.has("reedway_patrol"), "together with the clear")
	assert_false(progress.has_claim(&"first_footsteps.guard") or progress.has_claim(&"first_footsteps.restoration"),
		"the guard and the bell have their own eligibility")
	assert_eq(progress.material_count(&"storm_salt"), 0)
	assert_eq(received.size(), 1, "one receipt, published after the write")
	assert_eq(session.last_receipts, received)
	var receipt := received[0]
	assert_eq([receipt.claim_id, receipt.status], [&"first_footsteps.patrol", RewardReadout.Status.GRANTED])
	assert_eq([receipt.items[0].added, receipt.items[0].total], [bog, bog])
	# Reload: the counts and the claim come back from the written save.
	var reloaded := ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq(reloaded.material_count(&"bog_iron"), bog)
	assert_true(reloaded.has_claim(&"first_footsteps.patrol"))


func test_guard_and_bell_rewards_are_independent_and_need_the_deliberate_ring() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.world.discover(&"wayside_bell")
	assert_eq(_win(session, &"bell_guard"), OK)
	var progress := GameState.progress
	assert_eq(progress.material_count(&"bog_iron"), _authored(&"first_footsteps.guard", &"bog_iron"))
	assert_eq(progress.material_count(&"storm_salt"), _authored(&"first_footsteps.guard", &"storm_salt"))
	assert_false(progress.owned_equipment.has(&"storm_salt_charm"), "winning the guard fight is not the restoration")
	assert_false(progress.has_claim(&"first_footsteps.restoration"))
	assert_false(progress.has_claim(&"first_footsteps.patrol"), "the optional patrol is still unclaimed")
	assert_eq(session.complete_interaction(&"briarfen_reedway", &"wayside_bell"), OK)
	assert_false(GameState.progress.owned_equipment.has(&"storm_salt_charm"), "examining the bell grants nothing")
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	progress = GameState.progress
	assert_true(progress.owned_equipment.has(&"storm_salt_charm"))
	assert_eq(progress.reward_claims, [&"first_footsteps.guard", &"first_footsteps.restoration"] as Array[StringName])
	assert_true(kit.writer.last().inventory.equipment.has("storm_salt_charm"), "in the restoration write")
	assert_true(kit.writer.last().world.flags.wayside_bell_restored)
	assert_eq(session.last_receipts.size(), 1)
	assert_eq(session.last_receipts[0].summary(), "Storm Salt Charm, 5 equipment slots")
	assert_eq(received.size(), 2)
	assert_eq(progress.loadout_charm, &"", "owning the charm does not equip it")


func test_duplicate_results_and_repeated_restoration_never_grant_twice() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	var result := WorldKit.victory(&"bell_guard")
	assert_eq(session.commit_victory(entry, result), OK)
	var counts := GameState.progress.materials.duplicate()
	var writes := kit.writer.writes.size()
	assert_eq(session.commit_victory(entry, result), ERR_ALREADY_EXISTS, "the repeated result is a no-op")
	assert_true(session.last_receipts.is_empty())
	assert_eq(GameState.progress.materials, counts)
	assert_eq(kit.writer.writes.size(), writes)
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(session.restore_bell(&"briarfen_reedway"), ERR_UNAVAILABLE, "the bell is rung once")
	assert_true(session.last_receipts.is_empty())
	assert_eq(GameState.progress.owned_equipment.count(&"storm_salt_charm"), 1)
	assert_eq(received.size(), 2, "one receipt per reward, never repeated")


func test_failed_writes_publish_nothing_and_retry_grants_once() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	var before := GameState.progress.to_dict()
	kit.writer.fail = true
	assert_eq(session.commit_victory(entry, WorldKit.victory(&"bell_guard")), ERR_FILE_CANT_WRITE)
	assert_eq(GameState.progress.to_dict(), before, "no claim, count or clear published")
	assert_true(session.last_receipts.is_empty())
	assert_true(received.is_empty(), "no reward announced for an unsaved victory")
	kit.writer.fail = false
	assert_eq(session.commit_victory(entry, WorldKit.victory(&"bell_guard")), OK, "retry")
	assert_eq(GameState.progress.material_count(&"bog_iron"), _authored(&"first_footsteps.guard", &"bog_iron"))
	assert_eq(received.size(), 1)
	before = GameState.progress.to_dict()
	kit.writer.fail = true
	assert_eq(session.restore_bell(&"briarfen_reedway"), ERR_FILE_CANT_WRITE)
	assert_eq(GameState.progress.to_dict(), before, "no charm, claim or flag published")
	assert_true(session.last_receipts.is_empty())
	assert_eq(received.size(), 1)
	kit.writer.fail = false
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(GameState.progress.owned_equipment.count(&"storm_salt_charm"), 1)
	assert_eq(received.size(), 2)


func test_reset_journey_keeps_claims_and_inventory_so_replays_grant_nothing() -> void:
	var session := kit.session()
	session.open()
	assert_eq(_win(session, &"reedway_patrol"), OK)
	assert_eq(_win(session, &"bell_guard"), OK)
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	var materials := GameState.progress.materials.duplicate()
	var claims := GameState.progress.reward_claims.duplicate()
	assert_eq(claims.size(), 3)
	assert_eq(session.reset_journey(), OK)
	var progress := GameState.progress
	assert_true(progress.world.cleared.is_empty() and not progress.world.wayside_bell_restored, "the journey restarted")
	assert_eq(progress.materials, materials, "materials kept")
	assert_eq(progress.reward_claims, claims, "claims kept")
	assert_true(progress.owned_equipment.has(&"storm_salt_charm"), "equipment kept")
	var events := received.size()
	var won := progress.battles_won
	assert_eq(_win(session, &"bell_guard"), OK, "the site can be cleared again")
	assert_eq(GameState.progress.battles_won, won + 1, "the victory itself still counts")
	assert_true(session.last_receipts.is_empty(), "but grants no salvage again")
	assert_eq(_win(session, &"reedway_patrol"), OK)
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_true(session.last_receipts.is_empty())
	progress = GameState.progress
	assert_eq(progress.materials, materials, "no farming through Reset journey")
	assert_eq(progress.owned_equipment.count(&"storm_salt_charm"), 1)
	assert_eq(received.size(), events)
	assert_eq(session.reconcile(), OK)
	assert_true(session.last_receipts.is_empty(), "nothing to catch up either")
	var reloaded := ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq(reloaded.reward_claims, claims, "claims survive the reload")
	assert_eq(reloaded.material_count(&"bog_iron"), materials[&"bog_iron"])


func test_defeat_leaving_and_interrupted_entries_award_no_salvage() -> void:
	var session := kit.session()
	session.open()
	var before := GameState.progress.to_dict()
	var left := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(session.leave_entry(left), OK)
	var lost := session.begin_entry(&"bell_guard", &"bell_guard")
	assert_eq(session.return_home(lost), OK)
	assert_eq(session.commit_victory(lost, WorldKit.victory(&"bell_guard")), ERR_INVALID_PARAMETER, "a closed entry cannot win later")
	session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	# The app closes mid-battle; the next run recovers the entry at its approach.
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	var next := kit.session()
	next.open()
	assert_eq(next.reconcile(), OK)
	assert_null(GameState.progress.world.pending_entry)
	var progress := GameState.progress
	assert_true(progress.reward_claims.is_empty(), "no claim from leaving, defeat or an interrupted battle")
	assert_true(progress.materials.is_empty())
	assert_eq(progress.owned_equipment, ProgressState.new().owned_equipment)
	assert_eq(progress.to_dict().inventory, before.inventory)
	assert_true(received.is_empty())


func test_practice_and_the_recording_lab_award_no_salvage() -> void:
	# The recording Lab folds results into progress through GameState.record_battle: research and
	# mastery as before, never salvage or claims.
	var previous_slot := GameState.active_slot
	GameState.active_slot = THROWAWAY_SLOT
	var result := WorldKit.victory(&"bell_guard")
	GameState.record_battle(result)
	assert_gt(GameState.progress.bestiary.points_for(&"rotcap_brute"), 0, "Lab research still recorded")
	assert_eq(GameState.progress.weapon_mastery.get(&"pilgrims_edge", 0), 5, "Lab mastery still recorded")
	assert_true(GameState.progress.materials.is_empty(), "no salvage from the Lab")
	assert_true(GameState.progress.reward_claims.is_empty())
	SaveManager.delete_slot(THROWAWAY_SLOT)
	GameState.active_slot = previous_slot
	# Practice never records, and may still audition gear the save does not own.
	var sandbox: CombatSandbox = load("res://scenes/sandbox/combat_sandbox.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sandbox)
	var bow := -1
	for index in sandbox._practice_loadout.item_count:
		var loadout: PartyLoadout = sandbox._practice_loadout.get_item_metadata(index)
		if loadout.id == &"starter_bow":
			bow = index
	sandbox._practice_loadout.select(bow)
	var launch := sandbox.make_practice_launch(5)
	assert_false(launch.record_progress, "Practice records nothing")
	assert_eq(launch.setup.loadout.garb.id, &"fenrunner_leathers")
	assert_false(GameState.progress.owned_equipment.has(&"fenrunner_leathers"), "unowned gear stays available to Practice")
	sandbox.queue_free()
	assert_true(received.is_empty())


func test_an_older_completed_save_catches_up_once() -> void:
	_old_save(func(old: ProgressState) -> void:
		old.world.cleared.assign([&"reedway_patrol", &"bell_guard"])
		old.world.wayside_bell_restored = true
		old.battles_won = 3)
	assert_true(GameState.progress.reward_claims.is_empty(), "nothing claimed in an older save")
	var session := kit.session()
	session.open()
	var research := GameState.progress.bestiary.to_dict()
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), 1, "one write")
	var progress := GameState.progress
	assert_eq(progress.reward_claims.size(), 3)
	assert_eq(progress.material_count(&"bog_iron"),
		_authored(&"first_footsteps.patrol", &"bog_iron") + _authored(&"first_footsteps.guard", &"bog_iron"))
	assert_eq(progress.material_count(&"storm_salt"), _authored(&"first_footsteps.guard", &"storm_salt"))
	assert_true(progress.owned_equipment.has(&"storm_salt_charm"))
	assert_eq(progress.battles_won, 3, "statistics untouched")
	assert_eq(progress.bestiary.to_dict(), research, "research untouched")
	assert_eq(session.last_receipts.map(func(receipt: RewardReadout) -> StringName: return receipt.claim_id),
		[&"first_footsteps.guard", &"first_footsteps.patrol", &"first_footsteps.restoration"])
	assert_eq(received.size(), 3)
	assert_eq(session.reconcile(), OK, "a second reconciliation")
	assert_eq(kit.writer.writes.size(), 1, "is a no-op: nothing written")
	assert_true(session.last_receipts.is_empty())
	assert_eq(received.size(), 3)


func test_incomplete_older_saves_receive_only_what_their_journey_proves() -> void:
	# Guard cleared, bell not rung, patrol only discovered, an interrupted patrol battle pending.
	_old_save(func(old: ProgressState) -> void:
		old.world.cleared.assign([&"bell_guard"])
		old.world.discover(&"reedway_patrol")
		old.battles_won = 5)
	var session := kit.session()
	GameState.progress.world.pending_entry = EncounterEntry.from_dict({"token": "reedway_patrol#4", "site": "reedway_patrol",
		"encounter": "fen_patrol", "area": "briarfen_reedway", "approach_anchor": "reedway_patrol", "seed": 7,
		"loadout": GameState.progress.loadout_ids(), "research": {}, "difficulty": 1, "assist": 1})
	session.open()
	assert_eq(session.reconcile(), OK)
	assert_eq(GameState.progress.reward_claims, [&"first_footsteps.guard"] as Array[StringName])
	assert_false(GameState.progress.owned_equipment.has(&"storm_salt_charm"), "the bell was never rung")
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK, "ringing it later grants the charm then")
	assert_true(GameState.progress.owned_equipment.has(&"storm_salt_charm"))
	# A journey erased by an earlier Reset journey proves nothing, whatever the statistics say.
	_old_save(func(old: ProgressState) -> void:
		old.battles_won = 9
		old.world.entry_serial = 6
		old.world.last_applied_token = "bell_guard#6")
	var after_reset := kit.session()
	after_reset.open()
	var writes := kit.writer.writes.size()
	var events := received.size()
	assert_eq(after_reset.reconcile(), OK)
	# Playtest revision: an older save gets its one-time supply stock and journal stage here, in one
	# write. That is bookkeeping, not a reward: no claim, no material, no receipt.
	assert_eq(kit.writer.writes.size(), writes + 1, "one compatibility write")
	assert_false(after_reset.last_migrations.is_empty())
	assert_true(after_reset.last_receipts.is_empty(), "and nothing to catch up")
	assert_eq(received.size(), events)
	assert_true(GameState.progress.reward_claims.is_empty())
	assert_true(GameState.progress.materials.is_empty())
	assert_eq(after_reset.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), writes + 1, "then nothing to write")


func test_failed_reconciliation_changes_nothing_and_retry_applies_once() -> void:
	_old_save(func(old: ProgressState) -> void:
		old.world.cleared.assign([&"bell_guard"])
		old.world.wayside_bell_restored = true)
	var session := kit.session()
	session.open()
	var before := GameState.progress.to_dict()
	kit.writer.fail = true
	assert_eq(session.reconcile(), ERR_FILE_CANT_WRITE)
	assert_eq(GameState.progress.to_dict(), before, "nothing published")
	assert_true(session.last_receipts.is_empty() and received.is_empty())
	kit.writer.fail = false
	assert_eq(session.reconcile(), OK, "retry")
	assert_eq(GameState.progress.reward_claims, [&"first_footsteps.guard", &"first_footsteps.restoration"] as Array[StringName])
	assert_eq(received.size(), 2)
	assert_eq(session.reconcile(), OK)
	assert_eq(received.size(), 2, "applied once")


func test_malformed_saved_reward_data_cannot_create_rewards() -> void:
	var data := ProgressState.new().to_dict()
	data.rewards = {"claims": {"first_footsteps.patrol": true}}
	data.world.cleared = ["bell_guard", 7, null]
	data.world.flags = {"wayside_bell_restored": "yes"}
	data.inventory.materials = {"bog_iron": -40, "storm_salt": "99"}
	GameState.progress = ProgressState.from_dict(data)
	var session := kit.session()
	session.open()
	assert_eq(session.reconcile(), OK)
	var progress := GameState.progress
	assert_eq(progress.reward_claims, [&"first_footsteps.guard"] as Array[StringName],
		"only the approved, provable clear: no patrol claim from a malformed list, no bell from \"yes\"")
	assert_eq(progress.material_count(&"bog_iron"), _authored(&"first_footsteps.guard", &"bog_iron"), "never negative")
	assert_eq(progress.material_count(&"storm_salt"), _authored(&"first_footsteps.guard", &"storm_salt"))
	assert_false(progress.owned_equipment.has(&"storm_salt_charm"))
	# A claim for a reward this save never earned blocks nothing real and grants nothing.
	data = ProgressState.new().to_dict()
	data.rewards = {"claims": ["first_footsteps.restoration", "a.reward.from.a.later.build"]}
	GameState.progress = ProgressState.from_dict(data)
	var other := kit.session()
	other.open()
	assert_eq(other.reconcile(), OK)
	assert_false(GameState.progress.owned_equipment.has(&"storm_salt_charm"))
	assert_true(GameState.progress.has_claim(&"a.reward.from.a.later.build"), "unknown claims are preserved")
