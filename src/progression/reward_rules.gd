class_name RewardRules
extends RefCounted
## V0.5A campaign rewards (salvage). Which approved RewardDefinitions a committed accomplishment
## grants, applying them exactly once to a WorldSession candidate, catch-up for older saves, the
## filtered readouts and the catalog checks. Pure: callers pass the registry and the progress they
## own. Only WorldSession applies rewards; Practice, the Lab and GameState.record_battle never do.


## The approved rewards of one accomplishment, in claim-id order.
static func rewards_for(registry: DefinitionRegistry, source: RewardDefinition.Source,
		source_id: StringName) -> Array[RewardDefinition]:
	var result: Array[RewardDefinition] = []
	for id in registry.sorted_ids(registry.rewards):
		var reward: RewardDefinition = registry.rewards[id]
		if reward.source == source and reward.source_id == source_id:
			result.append(reward)
	return result


## Has [param progress]'s journey still got the accomplishment behind [param reward]? Only the
## typed world state counts (a cleared site, a set flag; V0.5C: a gathered node, a found secret, a
## solved puzzle): never a discovery, a pending entry or
## statistics, so an accomplishment erased by an earlier Reset journey is not inferred.
static func accomplished(progress: ProgressState, reward: RewardDefinition) -> bool:
	match reward.source:
		RewardDefinition.Source.SITE_VICTORY:
			return progress.world.is_cleared(reward.source_id)
		RewardDefinition.Source.WORLD_FLAG:
			return progress.world.flag(reward.source_id)
		RewardDefinition.Source.GATHERED:
			return progress.world.is_gathered(reward.source_id)
		RewardDefinition.Source.SECRET_FOUND:
			return progress.world.is_found(reward.source_id)
		RewardDefinition.Source.PUZZLE_SOLVED:
			return progress.world.is_solved(reward.source_id)
	return false


## Unclaimed rewards whose accomplishment is still present in [param progress] (older saves made
## before rewards existed, or repaired claims). In claim-id order.
static func catch_up(progress: ProgressState, registry: DefinitionRegistry) -> Array[RewardDefinition]:
	var result: Array[RewardDefinition] = []
	for id in registry.sorted_ids(registry.rewards):
		var reward: RewardDefinition = registry.rewards[id]
		if not progress.has_claim(reward.id) and accomplished(progress, reward):
			result.append(reward)
	return result


## Applies every unclaimed reward in [param rewards] to [param progress] (a WorldSession candidate):
## records the claim, adds material counts (saturating at MaterialDefinition.MAX_COUNT) and adds
## equipment that is not owned yet. Returns one GRANTED receipt per newly claimed reward, in
## claim-id order; an already claimed reward changes nothing and has no receipt.
static func grant(progress: ProgressState, rewards: Array[RewardDefinition]) -> Array[RewardReadout]:
	var ordered: Array[RewardDefinition] = []
	for reward in rewards:
		if reward != null:
			ordered.append(reward)
	ordered.sort_custom(func(a: RewardDefinition, b: RewardDefinition) -> bool: return String(a.id) < String(b.id))
	var receipts: Array[RewardReadout] = []
	for reward in ordered:
		if not progress.add_claim(reward.id):
			continue
		var receipt := _readout(reward, RewardReadout.Status.GRANTED)
		for index in reward.items.size():
			var item := reward.items[index]
			var entry: Dictionary = receipt.items[index]
			if item == null or item.item_id() == &"":
				continue
			match item.kind:
				RewardItem.Kind.MATERIAL:
					var held := progress.material_count(item.material.id)
					var total := mini(held + clampi(item.count, 0, RewardItem.MAX_COUNT), MaterialDefinition.MAX_COUNT)
					progress.materials[item.material.id] = total
					entry.added = total - held
					entry.total = total
				RewardItem.Kind.EQUIPMENT:
					entry.owned = progress.owned_equipment.has(item.item_id())
					if not entry.owned:
						progress.owned_equipment.append(item.item_id())
						entry.added = 1
					entry.total = 1
		receipts.append(receipt)
	return receipts


## Previews of the approved rewards for one accomplishment: AVAILABLE or CLAIMED for this save,
## with current holdings. Item facts only; nothing about the encounter's creatures.
static func previews(progress: ProgressState, registry: DefinitionRegistry, source: RewardDefinition.Source,
		source_id: StringName) -> Array[RewardReadout]:
	var result: Array[RewardReadout] = []
	for reward in rewards_for(registry, source, source_id):
		result.append(preview(progress, reward))
	return result


static func preview(progress: ProgressState, reward: RewardDefinition) -> RewardReadout:
	var claimed := progress.has_claim(reward.id)
	var readout := _readout(reward, RewardReadout.Status.CLAIMED if claimed else RewardReadout.Status.AVAILABLE)
	for index in reward.items.size():
		var item := reward.items[index]
		var entry: Dictionary = readout.items[index]
		if item == null:
			continue
		if item.kind == RewardItem.Kind.MATERIAL and item.material != null:
			entry.total = progress.material_count(item.material.id)
		elif item.kind == RewardItem.Kind.EQUIPMENT:
			entry.owned = progress.owned_equipment.has(item.item_id())
			entry.total = 1 if entry.owned else 0
	return readout


## Cross-definition checks for DefinitionRegistry.validate(): every reward names registered
## materials/equipment and an approved source, and the authored grants of each material stay
## below MaterialDefinition.MAX_COUNT in total (no saturation, no arithmetic overflow).
static func validate_catalog(registry: DefinitionRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var totals: Dictionary[StringName, int] = {}
	for id in registry.sorted_ids(registry.rewards):
		var reward: RewardDefinition = registry.rewards[id]
		problems.append_array(_check_source(registry, reward))
		for item in reward.items:
			if item == null:
				continue
			if item.kind == RewardItem.Kind.MATERIAL and item.material != null:
				if registry.materials.get(item.material.id) != item.material:
					problems.append("reward %s: material %s is not a registered data/ definition" % [id, item.material.id])
				totals[item.material.id] = totals.get(item.material.id, 0) + maxi(item.count, 0)
			elif item.kind == RewardItem.Kind.EQUIPMENT and item.item_id() != &"":
				var registered: Resource = registry.weapons.get(item.item_id(), registry.armor.get(item.item_id()))
				if registered != item.equipment:
					problems.append("reward %s: equipment %s is not a registered data/ definition" % [id, item.item_id()])
	for material_id: StringName in totals:
		if totals[material_id] > MaterialDefinition.MAX_COUNT:
			problems.append("rewards grant %d %s in total, above the %d stack limit" % [
				totals[material_id], material_id, MaterialDefinition.MAX_COUNT])
	return problems


static func _check_source(registry: DefinitionRegistry, reward: RewardDefinition) -> PackedStringArray:
	var problems := PackedStringArray()
	if registry.world == null:
		problems.append("reward %s needs the world definition for its source" % reward.id)
		return problems
	match reward.source:
		RewardDefinition.Source.SITE_VICTORY:
			var found := registry.world.find_landmark(reward.source_id)
			if found.is_empty() or (found[1] as LandmarkDefinition).kind != LandmarkDefinition.Kind.ENCOUNTER:
				problems.append("reward %s: source %s is not an encounter site" % [reward.id, reward.source_id])
		RewardDefinition.Source.WORLD_FLAG:
			if not registry.world.flags.has(reward.source_id):
				problems.append("reward %s: source %s is not a world flag" % [reward.id, reward.source_id])
		RewardDefinition.Source.GATHERED:
			if ExplorationRules.gathering(registry.world, reward.source_id) == null:
				problems.append("reward %s: source %s is not a gathering node" % [reward.id, reward.source_id])
		RewardDefinition.Source.SECRET_FOUND:
			if ExplorationRules.secret(registry.world, reward.source_id) == null:
				problems.append("reward %s: source %s is not a secret" % [reward.id, reward.source_id])
		RewardDefinition.Source.PUZZLE_SOLVED:
			if ExplorationRules.puzzle(registry.world, reward.source_id) == null:
				problems.append("reward %s: source %s is not a puzzle" % [reward.id, reward.source_id])
	return problems


## Plain-data readout of [param reward]'s authored items (no live counts yet).
static func _readout(reward: RewardDefinition, status: RewardReadout.Status) -> RewardReadout:
	var readout := RewardReadout.new()
	readout.claim_id = reward.id
	readout.label = reward.display_name
	readout.source = reward.source
	readout.source_id = reward.source_id
	readout.status = status
	readout.equipment_slots = reward.equipment_slots
	for item in reward.items:
		var entry := {"kind": RewardItem.Kind.MATERIAL, "id": &"", "name": "", "description": "", "icon_path": "",
			"count": 0, "added": 0, "total": 0, "owned": false}
		if item != null:
			entry.kind = item.kind
			entry.id = item.item_id()
			entry.count = item.count
			if item.kind == RewardItem.Kind.MATERIAL and item.material != null:
				entry.name = item.material.display_name
				entry.description = item.material.description
				entry.icon_path = item.material.icon.resource_path if item.material.icon != null else ""
			elif item.equipment is WeaponDefinition or item.equipment is ArmorDefinition:
				entry.name = String(item.equipment.get("display_name"))
				entry.description = String(item.equipment.get("description"))
				var icon: Texture2D = item.equipment.get("icon")
				entry.icon_path = icon.resource_path if icon != null else ""
		readout.items.append(entry)
	return readout
