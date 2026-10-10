class_name ExplorationRules
extends RefCounted
## V0.5C exploration vocabulary: gathering nodes, discoverable secrets and the rune-sequence puzzle
## grammar. Pure: every answer derives from typed WorldState and the WorldDefinition; WorldSession
## owns the writes and RewardRules the claims. Scenes follow the same state through WorldStateView.
##
## Persistence policy (world section of the save; journey = cleared by Reset journey):
## - gathered nodes: kept by Reset journey (a node yields once per save; its reward is a claim);
## - found secrets, solved puzzles and the current rune input: journey state; the rewards they
##   claimed stay claimed, so repeating them after a reset grants nothing.


static func gathering(definition: WorldDefinition, landmark_id: StringName) -> GatheringDefinition:
	for entry in definition.gathering:
		if entry != null and entry.landmark == landmark_id:
			return entry
	return null


static func secret(definition: WorldDefinition, landmark_id: StringName) -> SecretDefinition:
	for entry in definition.secrets:
		if entry != null and entry.landmark == landmark_id:
			return entry
	return null


static func puzzle(definition: WorldDefinition, puzzle_id: StringName) -> RuneSequenceDefinition:
	for entry in definition.puzzles:
		if entry != null and entry.id == puzzle_id:
			return entry
	return null


## The puzzle a RUNE landmark belongs to, or null.
static func puzzle_of(definition: WorldDefinition, rune_id: StringName) -> RuneSequenceDefinition:
	for entry in definition.puzzles:
		if entry != null and entry.runes.has(rune_id):
			return entry
	return null


## Does [param entry]'s reveal condition hold in [param world]?
static func revealed(world: WorldState, entry: SecretDefinition) -> bool:
	match entry.reveal:
		SecretDefinition.Reveal.ALWAYS:
			return true
		SecretDefinition.Reveal.PUZZLE_SOLVED:
			return world.is_solved(entry.reveal_key)
		SecretDefinition.Reveal.WORLD_FLAG:
			return world.flag(entry.reveal_key)
	return false


## May the player perceive [param landmark] (prompt, proximity discovery, map entry)? Only a secret
## whose reveal condition does not hold is imperceptible; everything else keeps its V0.4 rules.
static func perceivable(world: WorldState, definition: WorldDefinition, landmark: LandmarkDefinition) -> bool:
	if landmark.kind != LandmarkDefinition.Kind.SECRET:
		return true
	var entry := secret(definition, landmark.id)
	return entry != null and revealed(world, entry)


## The secrets [param puzzle_id] reveals when solved.
static func secrets_revealed_by(definition: WorldDefinition, puzzle_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in definition.secrets:
		if entry != null and entry.reveal == SecretDefinition.Reveal.PUZZLE_SOLVED and entry.reveal_key == puzzle_id:
			result.append(entry.landmark)
	return result


## One strike of the rune grammar, pure: [param input] is the current attempt (unchanged).
## Returns {"outcome": ExplorationResult.Strike, "input": Array[StringName] (the attempt after it)}.
static func strike(entry: RuneSequenceDefinition, input: Array[StringName], rune: StringName) -> Dictionary:
	if entry.solution.is_empty():
		return {"outcome": ExplorationResult.Strike.MISTAKE, "input": [] as Array[StringName]}
	var next: Array[StringName] = input.duplicate()
	if next.size() >= entry.solution.size():
		next.clear()
	if rune == entry.solution[next.size()]:
		next.append(rune)
		if next.size() == entry.solution.size():
			return {"outcome": ExplorationResult.Strike.SOLVED, "input": [] as Array[StringName]}
		return {"outcome": ExplorationResult.Strike.ADVANCED, "input": next}
	var restart: Array[StringName] = []
	if rune == entry.solution[0]:
		restart.append(rune)
	return {"outcome": ExplorationResult.Strike.MISTAKE, "input": restart}


## The public state of [param entry] in [param world] (never the solution order).
static func readout(world: WorldState, definition: WorldDefinition, entry: RuneSequenceDefinition) -> PuzzleReadout:
	var result := PuzzleReadout.new()
	result.id = entry.id
	result.name = entry.display_name
	result.solved = world.is_solved(entry.id)
	var input := world.rune_input_of(entry.id)
	result.entered = input.size()
	result.length = entry.solution.size()
	for rune_id in entry.runes:
		var found := definition.find_landmark(rune_id)
		result.runes.append({"id": rune_id, "label": (found[1] as LandmarkDefinition).display_name if not found.is_empty() else "",
			"lit": result.solved or input.has(rune_id)})
	return result


## Definition checks for WorldDefinition.validate(): every gathering node, secret and rune names a
## landmark of the right kind; each such landmark has exactly one definition; reveal keys exist;
## a puzzle's runes share one area and its solution uses only its runes, within the length limits.
static func validate(definition: WorldDefinition) -> PackedStringArray:
	var problems := PackedStringArray()
	var owners := {}
	for entry in definition.gathering:
		if entry == null:
			problems.append("null gathering definition")
			continue
		_claim(definition, entry.landmark, LandmarkDefinition.Kind.GATHERING, "gathering node", owners, problems)
		if not GatheringDefinition.Refresh.values().has(entry.refresh):
			problems.append("gathering node %s has an unknown refresh policy %d" % [entry.landmark, entry.refresh])
	var puzzle_ids := {}
	for entry in definition.puzzles:
		if entry == null:
			problems.append("null puzzle definition")
			continue
		if entry.id == &"" or entry.display_name.is_empty():
			problems.append("puzzle '%s' needs an id and a public name" % entry.id)
		if puzzle_ids.has(entry.id):
			problems.append("puzzle id %s is used twice" % entry.id)
		puzzle_ids[entry.id] = true
		if entry.runes.size() < 2:
			problems.append("puzzle %s needs at least two runes" % entry.id)
		var area_id: StringName = &""
		for rune_id in entry.runes:
			_claim(definition, rune_id, LandmarkDefinition.Kind.RUNE, "puzzle %s rune" % entry.id, owners, problems)
			var found := definition.find_landmark(rune_id)
			if not found.is_empty():
				var rune_area: StringName = (found[0] as AreaDefinition).id
				if area_id != &"" and rune_area != area_id:
					problems.append("puzzle %s has runes in two areas (%s, %s)" % [entry.id, area_id, rune_area])
				area_id = rune_area
		if entry.solution.size() < RuneSequenceDefinition.MIN_LENGTH or entry.solution.size() > RuneSequenceDefinition.MAX_LENGTH:
			problems.append("puzzle %s: the solution must take %d-%d strikes" % [entry.id, RuneSequenceDefinition.MIN_LENGTH,
				RuneSequenceDefinition.MAX_LENGTH])
		for rune_id in entry.solution:
			if not entry.runes.has(rune_id):
				problems.append("puzzle %s: solution rune %s is not one of its runes" % [entry.id, rune_id])
	for entry in definition.secrets:
		if entry == null:
			problems.append("null secret definition")
			continue
		_claim(definition, entry.landmark, LandmarkDefinition.Kind.SECRET, "secret", owners, problems)
		match entry.reveal:
			SecretDefinition.Reveal.ALWAYS:
				if entry.reveal_key != &"":
					problems.append("secret %s: an ALWAYS secret takes no reveal key" % entry.landmark)
			SecretDefinition.Reveal.PUZZLE_SOLVED:
				if not puzzle_ids.has(entry.reveal_key):
					problems.append("secret %s: reveal puzzle %s does not exist" % [entry.landmark, entry.reveal_key])
			SecretDefinition.Reveal.WORLD_FLAG:
				if not definition.flags.has(entry.reveal_key):
					problems.append("secret %s: reveal flag %s does not exist" % [entry.landmark, entry.reveal_key])
			_:
				problems.append("secret %s has an unknown reveal kind %d" % [entry.landmark, entry.reveal])
	for area in definition.areas:
		for landmark in area.landmarks:
			if landmark.kind in [LandmarkDefinition.Kind.GATHERING, LandmarkDefinition.Kind.SECRET, LandmarkDefinition.Kind.RUNE] \
					and not owners.has(landmark.id):
				problems.append("%s/%s has no exploration definition" % [area.id, landmark.id])
	return problems


static func _claim(definition: WorldDefinition, landmark_id: StringName, kind: LandmarkDefinition.Kind, what: String,
		owners: Dictionary, problems: PackedStringArray) -> void:
	var found := definition.find_landmark(landmark_id)
	if found.is_empty() or (found[1] as LandmarkDefinition).kind != kind:
		problems.append("%s %s is not a %s landmark" % [what, landmark_id, LandmarkDefinition.Kind.keys()[kind]])
	if owners.has(landmark_id):
		problems.append("landmark %s has two exploration definitions" % landmark_id)
	owners[landmark_id] = true
