class_name WorldSession
extends RefCounted
## World save boundaries (V0.4 rules 5–10). Every change that matters goes through commit(): the
## live progress is copied, the copy is changed and written, and only a successful write replaces
## GameState.progress. A failed write leaves the live state exactly as it was, so nothing is
## announced or published and the caller can offer Retry save / Return to title.
##
## Discoveries and walked links are map knowledge; they go into the live state at once and reach
## the disk with the next successful commit.

var definition: WorldDefinition
## func(candidate: ProgressState) -> Error. Defaults to the active save slot; tests inject failures.
var writer: Callable
var last_error: Error = OK
## Exploration-only randomness (battle seeds for new entries). Never the combat RNG.
var _rng := RandomNumberGenerator.new()


func _init(p_definition: WorldDefinition = null, p_writer: Callable = Callable(), rng_seed: int = -1) -> void:
	definition = p_definition if p_definition != null else WorldDefinition.load_default()
	writer = p_writer if p_writer.is_valid() else func(candidate: ProgressState) -> Error:
		return SaveManager.write_progress(GameState.active_slot, candidate)
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func world() -> WorldState:
	return GameState.progress.world


## Entering the world from the title. Validates the saved section against approved content and
## turns an interrupted battle back into an available encounter at its approach (no award).
func open() -> PackedStringArray:
	var problems := world().sanitize(definition)
	if world().pending_entry != null:
		var entry := world().pending_entry
		world().area = entry.area_id()
		world().anchor = entry.approach_anchor()
		world().pending_entry = null
	for problem in problems:
		push_warning("WorldSession: " + problem)
	return problems


## Copies the live progress, applies [param mutator] (func(candidate: ProgressState)) and writes it.
## On success the copy becomes the live progress; on failure the live progress is untouched.
func commit(mutator: Callable) -> Error:
	var candidate := ProgressState.from_dict(GameState.progress.to_dict())
	mutator.call(candidate)
	last_error = writer.call(candidate)
	if last_error != OK:
		return last_error
	GameState.progress = candidate
	return OK


## Area arrival through a portal (a safe boundary).
func arrive(area_id: StringName, anchor_id: StringName) -> Error:
	if not definition.is_anchor(area_id, anchor_id):
		return ERR_INVALID_PARAMETER
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.area = area_id
		candidate.world.anchor = anchor_id
		if definition.area(area_id).landmark(anchor_id) != null:
			candidate.world.discover(anchor_id))


## Explicit save from the world menu. Keeps the last committed safe anchor (never raw coordinates).
func save() -> Error:
	return commit(func(_candidate: ProgressState) -> void: pass)


## A completed discrete interaction at [param landmark_id]; safe-anchor landmarks become the resume point.
func complete_interaction(area_id: StringName, landmark_id: StringName) -> Error:
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.discover(landmark_id)
		if definition.is_anchor(area_id, landmark_id):
			candidate.world.area = area_id
			candidate.world.anchor = landmark_id)


func restore_bell(area_id: StringName) -> Error:
	if not WorldRules.can_ring_bell(world()):
		return ERR_UNAVAILABLE
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.wayside_bell_restored = true
		candidate.world.discover(&"wayside_bell")
		candidate.world.area = area_id
		candidate.world.anchor = &"wayside_bell")


## Opens the return latch. The caller has checked the far side; the flag is independent of the bell.
func open_latch(area_id: StringName, link_id: StringName) -> Error:
	if world().return_latch_open:
		return ERR_ALREADY_EXISTS
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.return_latch_open = true
		candidate.world.discover(&"return_latch")
		candidate.world.add_link(link_id)
		candidate.world.area = area_id
		candidate.world.anchor = &"return_latch")


## Menu → Reset journey: a fresh journey at the start anchor, in one write. Only the `world` section
## changes (discoveries, walked links, cleared sites, both flags, any pending entry); research,
## mastery, loadout, inventory and statistics stay, and settings live in their own file. The entry
## serial and last applied token carry over, so a completion from before the reset can never be
## applied to the new journey and a new victory is never mistaken for an old one. The host calls
## this only from its paused exploration menu, never while a battle owns the session.
func reset_journey() -> Error:
	return commit(func(candidate: ProgressState) -> void:
		var fresh := WorldState.fresh(definition)
		fresh.entry_serial = candidate.world.entry_serial
		fresh.last_applied_token = candidate.world.last_applied_token
		candidate.world = fresh)


## Bench choice: one of the already-owned starter weapons; applies to the next entry snapshot.
func choose_weapon(weapon_id: StringName) -> Error:
	var allowed := WorldRules.bench_weapons(GameState.progress).any(
		func(weapon: WeaponDefinition) -> bool: return weapon.id == weapon_id)
	if not allowed:
		return ERR_INVALID_PARAMETER
	return commit(func(candidate: ProgressState) -> void:
		candidate.loadout_weapon = weapon_id
		candidate.world.discover(&"preparation_bench"))


# --- Encounters ----------------------------------------------------------------------------------

## Captures one immutable entry for [param site_id] and saves it before any battle launches.
## Null when the site is unavailable or the write failed (see last_error).
func begin_entry(site_id: StringName, approach_anchor: StringName) -> EncounterEntry:
	var found := definition.find_landmark(site_id)
	last_error = ERR_UNAVAILABLE
	if found.is_empty() or world().pending_entry != null or world().is_cleared(site_id):
		return null
	var area: AreaDefinition = found[0]
	var site: LandmarkDefinition = found[1]
	if site.kind != LandmarkDefinition.Kind.ENCOUNTER or not definition.is_anchor(area.id, approach_anchor):
		return null
	var serial := world().entry_serial + 1
	var entry := EncounterEntry.capture("%s#%d" % [site_id, serial], area.id, site, approach_anchor,
		_rng.randi_range(1, 999_999), GameState.progress, Settings.data, Database.registry.research)
	var record := func(candidate: ProgressState) -> void:
		candidate.world.entry_serial = serial
		candidate.world.pending_entry = EncounterEntry.from_dict(entry.to_dict())
		candidate.world.discover(site_id)
		candidate.world.area = area.id
		candidate.world.anchor = approach_anchor
	if commit(record) != OK:
		return null
	return entry


## Commits a victory exactly once: research/mastery, the cleared site and the return boundary in
## one write. A repeated token is a no-op (ERR_ALREADY_EXISTS); a failed write changes nothing.
func commit_victory(entry: EncounterEntry, result: BattleResult) -> Error:
	if entry.token() == world().last_applied_token:
		last_error = ERR_ALREADY_EXISTS
		return last_error
	var pending := world().pending_entry
	if pending == null or pending.token() != entry.token() or result == null or not result.is_victory():
		last_error = ERR_INVALID_PARAMETER
		return last_error
	var research := Database.registry.research
	var before: Dictionary[StringName, int] = {}
	for enemy_id: StringName in result.research:
		before[enemy_id] = GameState.research_level(enemy_id)
	var err := commit(func(candidate: ProgressState) -> void:
		candidate.apply_battle_result(result, research)
		if not candidate.world.cleared.has(entry.site_id()):
			candidate.world.cleared.append(entry.site_id())
		candidate.world.pending_entry = null
		candidate.world.last_applied_token = entry.token()
		candidate.world.area = entry.area_id()
		candidate.world.anchor = entry.approach_anchor())
	if err != OK:
		return err
	for enemy_id: StringName in before:
		var level := GameState.research_level(enemy_id)
		if level > before[enemy_id]:
			EventBus.research_level_gained.emit(enemy_id, level)
	EventBus.battle_finished.emit(result)
	return OK


## Quitting a battle from its pause menu: back to the approach, encounter still available, no award.
func leave_entry(entry: EncounterEntry) -> Error:
	return _close_entry(entry, entry.area_id(), entry.approach_anchor())


## Defeat → Return to Gloamstead: committed victories, discoveries and flags stay; no fee.
func return_home(entry: EncounterEntry) -> Error:
	return _close_entry(entry, definition.start_area, definition.start_anchor)


func _close_entry(entry: EncounterEntry, area_id: StringName, anchor_id: StringName) -> Error:
	var pending := world().pending_entry
	if pending == null or pending.token() != entry.token():
		last_error = ERR_INVALID_PARAMETER
		return last_error
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.pending_entry = null
		candidate.world.area = area_id
		candidate.world.anchor = anchor_id)
