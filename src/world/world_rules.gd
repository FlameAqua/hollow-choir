class_name WorldRules
extends RefCounted
## Pure V0.4 world rules: objective, interaction eligibility and the filtered readouts. Every answer
## derives from typed WorldState/ProgressState; there is no quest stage to keep in sync.

const ACT_TALK := &"talk"
const ACT_PREPARE := &"prepare"
const ACT_ENGAGE := &"engage"
const ACT_RING := &"ring_bell"
const ACT_OPEN_LATCH := &"open_latch"
const ACT_READ := &"read"
const ACT_LEAVE := &"leave"
const ACT_GATHER := &"gather"
const ACT_SEARCH := &"search"


static func objective(world: WorldState, definition: WorldDefinition, area_id: StringName) -> String:
	if world.wayside_bell_restored:
		return WorldCopy.OBJECTIVE_DONE if area_id == definition.start_area else WorldCopy.OBJECTIVE_RETURN
	if world.is_cleared(&"bell_guard"):
		return WorldCopy.OBJECTIVE_RESTORE
	return WorldCopy.OBJECTIVE_FIND


## True when [param player] stands on the latch's far side (where the bar can be lifted).
static func on_far_side(landmark: LandmarkDefinition, landmark_position: Vector2, player: Vector2) -> bool:
	return landmark.far_side != Vector2i.ZERO and (player - landmark_position).dot(Vector2(landmark.far_side)) > 0.0


## The prompt label for Confirm at [param landmark], or "" when it offers no interaction.
## [param definition] (the session's world; default: the authored journey) answers V0.5C questions.
static func interaction_label(landmark: LandmarkDefinition, world: WorldState, far_side: bool,
		definition: WorldDefinition = null) -> String:
	var source := definition if definition != null else WorldDefinition.load_default()
	match landmark.kind:
		LandmarkDefinition.Kind.DIALOGUE:
			return WorldCopy.PROMPT_TALK % landmark.display_name
		LandmarkDefinition.Kind.PREPARATION:
			return WorldCopy.PROMPT_PREPARE % landmark.display_name.to_lower()
		LandmarkDefinition.Kind.ENCOUNTER:
			return "" if world.is_cleared(landmark.id) else WorldCopy.PROMPT_ENGAGE % landmark.threat_label.to_lower()
		LandmarkDefinition.Kind.RESTORATION:
			return WorldCopy.PROMPT_EXAMINE % landmark.display_name.to_lower()
		LandmarkDefinition.Kind.SHORTCUT:
			if world.return_latch_open:
				return ""
			return WorldCopy.ACTION_OPEN_LATCH if far_side else WorldCopy.PROMPT_GATE
		LandmarkDefinition.Kind.DISCOVERY:
			return WorldCopy.PROMPT_LOOK % landmark.display_name.to_lower()
		LandmarkDefinition.Kind.GATHERING:
			return "" if world.is_gathered(landmark.id) else WorldCopy.PROMPT_GATHER % landmark.display_name.to_lower()
		LandmarkDefinition.Kind.SECRET:
			if not ExplorationRules.perceivable(world, source, landmark):
				return ""
			if world.is_found(landmark.id):
				return WorldCopy.PROMPT_LOOK % landmark.display_name.to_lower()
			return WorldCopy.PROMPT_SEARCH % landmark.display_name.to_lower()
		LandmarkDefinition.Kind.RUNE:
			var entry := ExplorationRules.puzzle_of(source, landmark.id)
			if entry == null or world.is_solved(entry.id):
				return ""
			return WorldCopy.PROMPT_STRIKE % landmark.display_name.to_lower()
	return ""


## Is [param landmark] perceivable now (prompt, proximity discovery and map entry)? Only a V0.5C
## secret whose reveal condition does not hold is not.
static func perceivable(landmark: LandmarkDefinition, world: WorldState, definition: WorldDefinition = null) -> bool:
	return ExplorationRules.perceivable(world, definition if definition != null else WorldDefinition.load_default(), landmark)


## A RUNE landmark is struck directly by Confirm (no dialogue; see WorldSession.strike_rune).
static func dialogue(landmark: LandmarkDefinition, world: WorldState, far_side: bool,
		definition: WorldDefinition = null) -> WorldDialogueReadout:
	var source := definition if definition != null else WorldDefinition.load_default()
	var leave := WorldDialogueReadout.action(ACT_LEAVE, WorldCopy.ACTION_LEAVE)
	var close := WorldDialogueReadout.action(ACT_LEAVE, WorldCopy.ACTION_CLOSE)
	match landmark.kind:
		LandmarkDefinition.Kind.DIALOGUE:
			var lines: Array = WorldCopy.BELLKEEPER_AFTER if world.wayside_bell_restored else WorldCopy.BELLKEEPER_BEFORE
			return WorldDialogueReadout.make(WorldCopy.BELLKEEPER, lines, [close])
		LandmarkDefinition.Kind.RESTORATION:
			if world.wayside_bell_restored:
				return WorldDialogueReadout.make(WorldCopy.WAYSIDE_BELL, [WorldCopy.BELL_RESTORED], [close])
			if not world.is_cleared(&"bell_guard"):
				return WorldDialogueReadout.make(WorldCopy.WAYSIDE_BELL, [WorldCopy.BELL_GUARDED], [leave])
			return WorldDialogueReadout.make(WorldCopy.WAYSIDE_BELL, [WorldCopy.BELL_READY],
				[WorldDialogueReadout.action(ACT_RING, WorldCopy.ACTION_RING), leave])
		LandmarkDefinition.Kind.SHORTCUT:
			if world.return_latch_open:
				return WorldDialogueReadout.make(WorldCopy.LATCH, [WorldCopy.LATCH_OPEN], [close])
			if not far_side:
				return WorldDialogueReadout.make(WorldCopy.LATCH, [WorldCopy.LATCH_NEAR], [close])
			return WorldDialogueReadout.make(WorldCopy.LATCH, [WorldCopy.LATCH_FAR],
				[WorldDialogueReadout.action(ACT_OPEN_LATCH, WorldCopy.ACTION_OPEN_LATCH), leave])
		LandmarkDefinition.Kind.DISCOVERY:
			return WorldDialogueReadout.make(landmark.display_name, [WorldCopy.STONES_TEXT], [close])
		LandmarkDefinition.Kind.GATHERING:
			if world.is_gathered(landmark.id):
				return WorldDialogueReadout.make(landmark.display_name, [WorldCopy.GATHERED_TEXT], [close])
			return WorldDialogueReadout.make(landmark.display_name, [landmark.description],
				[WorldDialogueReadout.action(ACT_GATHER, WorldCopy.ACTION_GATHER), leave])
		LandmarkDefinition.Kind.SECRET:
			if not ExplorationRules.perceivable(world, source, landmark):
				return null
			if world.is_found(landmark.id):
				return WorldDialogueReadout.make(landmark.display_name, [WorldCopy.SECRET_FOUND_TEXT], [close])
			return WorldDialogueReadout.make(landmark.display_name, [landmark.description],
				[WorldDialogueReadout.action(ACT_SEARCH, WorldCopy.ACTION_SEARCH), leave])
	return null


## May the bell be rung now? Guard victory permits; restoring is the separate deliberate step.
static func can_ring_bell(world: WorldState) -> bool:
	return world.is_cleared(&"bell_guard") and not world.wayside_bell_restored


static func encounter_card(site: LandmarkDefinition, progress: ProgressState) -> EncounterCardReadout:
	var card := EncounterCardReadout.new()
	card.threat = site.threat_label
	card.optional = site.optional
	card.group_count = site.encounter.enemies.size()
	var research := Database.registry.research
	for enemy in site.encounter.enemies:
		var known := progress.bestiary.level(enemy.id, research) >= Enums.ResearchLevel.OBSERVED
		card.creatures.append(enemy.display_name if known else WorldCopy.UNKNOWN_CREATURE)
	for condition in site.encounter.conditions:
		card.conditions.append({"name": condition.display_name,
			"summary": condition.summary if not condition.summary.is_empty() else condition.description})
	card.resource_rule = WorldCopy.RESOURCE_RULE
	card.rewards = RewardRules.previews(progress, Database.registry, RewardDefinition.Source.SITE_VICTORY, site.id)
	return card


## Weapons the bench can offer: every owned, approved weapon (V0.5A; V0.4 offered only the starter
## loadouts' weapons). Ordered by family, rarity and id, so the three starters keep their order.
static func bench_weapons(progress: ProgressState) -> Array[WeaponDefinition]:
	var result: Array[WeaponDefinition] = []
	for item in PreparationRules.owned_items(progress, Database.registry, Enums.EquipSlot.WEAPON):
		result.append(item as WeaponDefinition)
	return result


## [param positions]: landmark id -> area pixel position from the live area scene. An imperceptible
## V0.5C secret is never charted, even if an earlier journey discovered it.
static func map_readout(area: AreaDefinition, world: WorldState, tile_size: int, player: Vector2,
		positions: Dictionary, definition: WorldDefinition = null) -> WorldMapReadout:
	var source := definition if definition != null else WorldDefinition.load_default()
	var readout := WorldMapReadout.new()
	readout.area_name = area.display_name
	readout.area_size = area.pixel_size(tile_size)
	readout.player_position = player
	for landmark in area.landmarks:
		if not world.is_discovered(landmark.id) or not ExplorationRules.perceivable(world, source, landmark):
			continue
		var description := landmark.description
		if landmark.kind == LandmarkDefinition.Kind.HOME and world.wayside_bell_restored:
			description = WorldCopy.MAP_HOME_RESTORED
		elif landmark.kind == LandmarkDefinition.Kind.ENCOUNTER and world.is_cleared(landmark.id):
			description = WorldCopy.MAP_CLEARED
		elif landmark.kind == LandmarkDefinition.Kind.SHORTCUT:
			description = WorldCopy.LATCH_OPEN if world.return_latch_open else description
		elif landmark.kind == LandmarkDefinition.Kind.RESTORATION and world.wayside_bell_restored:
			description = WorldCopy.BELL_RESTORED
		elif landmark.kind == LandmarkDefinition.Kind.GATHERING and world.is_gathered(landmark.id):
			description = WorldCopy.GATHERED_TEXT
		elif landmark.kind == LandmarkDefinition.Kind.SECRET and world.is_found(landmark.id):
			description = WorldCopy.SECRET_FOUND_TEXT
		var position: Vector2 = positions.get(landmark.id, (Vector2(landmark.tile) + Vector2(0.5, 0.5)) * tile_size)
		readout.landmarks.append({"label": landmark.display_name, "position": position, "description": description})
	readout.landmarks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.label < b.label)
	for path in area.paths:
		if not world.links.has(path.id):
			continue
		if path.requires_flag != &"" and not world.flag(path.requires_flag):
			continue
		var line := PackedVector2Array()
		for point in path.points:
			line.append((point + Vector2(0.5, 0.5)) * tile_size)
		readout.links.append(line)
	return readout
