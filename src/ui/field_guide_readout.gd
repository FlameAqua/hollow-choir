class_name FieldGuideReadout
extends RefCounted
## Save-only knowledge, filtered before it reaches the screen. No BattleEngine, temporary Inspect
## state, hidden phase identity or mutable definition is retained in a readout.
var id: StringName
var title := ""
var level: Enums.ResearchLevel
var points := 0
var progress_text := ""
var progress_fraction := 0.0
var portrait: Texture2D
var sections: Array[Dictionary] = []

static func build(definition: EnemyDefinition, bestiary: BestiaryState, config: ResearchConfig) -> FieldGuideReadout:
	if definition == null or bestiary.level(definition.id, config) == Enums.ResearchLevel.UNKNOWN:
		return null
	var r := FieldGuideReadout.new()
	r.id = definition.id
	r.title = definition.display_name
	r.level = bestiary.level(r.id, config)
	r.points = bestiary.points_for(r.id)
	var thresholds := [config.observed_threshold, config.studied_threshold, config.understood_threshold, config.mastered_threshold]
	if r.level == Enums.ResearchLevel.MASTERED:
		r.progress_text = "%d research points · Mastered" % r.points
		r.progress_fraction = 1.0
	else:
		var next: int = thresholds[int(r.level)]
		var previous: int = thresholds[int(r.level) - 1]
		r.progress_text = "%d / %d research · next: %s" % [r.points, next, EnumText.research_level((int(r.level) + 1) as Enums.ResearchLevel)]
		r.progress_fraction = clampf(float(r.points - previous) / maxi(1, next - previous), 0.0, 1.0)
	if definition.sprite_frames != null and definition.sprite_frames.has_animation(&"idle"):
		r.portrait = definition.sprite_frames.get_frame_texture(&"idle", 0)
	r._section("Field notes", "\n".join(PackedStringArray([definition.species, definition.description, definition.habitat, definition.lore])))
	var learned := PackedStringArray()
	for source in bestiary.sources.get(r.id, PackedInt32Array()):
		# An unrecognised saved value is skipped, not described as some other source.
		if Enums.ResearchSource.values().has(source):
			learned.append(EnumText.research_source(source as Enums.ResearchSource))
	r._section("How you learned", ", ".join(learned) if not learned.is_empty() else "Research recorded in an earlier save.")
	if BattleKnowledge.saved_affinities_known(r.level):
		var affinities := PackedStringArray()
		for type in UnitDetails.AFFINITY_TYPES:
			affinities.append("%s: %s" % [EnumText.damage_type(type), "Weakness" if definition.is_weak_to(type) else "Resistance" if definition.resists(type) else "Normal damage"])
		r._section("Affinities", " · ".join(affinities))
	else:
		r._section("Affinities · Studied", "Not yet recorded. A revealing hit or Inspect can teach you during a battle; temporary reveals do not fill this guide.")
	if BattleKnowledge.saved_moves_known(r.level):
		r._section("Base stats", "Heart %d · Force %d · Guard %d · Tempo %d · Break %s" % [definition.max_hp, definition.force, definition.guard, definition.tempo, str(definition.max_stagger)])
		var traits := PackedStringArray()
		for trait_def in definition.traits:
			traits.append(trait_def.display_name + ": " + trait_def.description)
		for status in definition.status_immunities:
			traits.append("Immune to " + EnumText.status(status))
		r._section("Traits", "\n".join(traits) if not traits.is_empty() else "No species traits recorded.")
		var moves: Array[EnemyActionDefinition] = definition.actions.duplicate()
		if BattleKnowledge.saved_tendencies_known(r.level):
			for phase in definition.phases:
				for action in phase.actions:
					if not moves.has(action):
						moves.append(action)
				if phase.opening_action != null and not moves.has(phase.opening_action):
					moves.append(phase.opening_action)
		for move in moves:
			var defenses := PackedStringArray()
			for reaction in ReactionReadout.REACTIONS:
				defenses.append(EnumText.reaction(reaction) + ("" if move.allows_reaction(reaction) else " unavailable"))
			var notes := PackedStringArray([move.telegraph_text])
			if not move.telegraph_detail.is_empty():
				notes.append(move.telegraph_detail)
			notes.append(" · ".join(defenses))
			if move.channel_turns > 0:
				notes.append("Channel: %d turns · %s" % [move.channel_turns, "can be interrupted by breaking" if move.interruptible else "cannot be interrupted"])
			r._section(move.display_name, "\n".join(notes))
	else:
		r._section("Moves and traits · Understood", "Not yet recorded. Read each enemy's declared intent in combat for its current targets and legal defenses.")
	if BattleKnowledge.saved_tendencies_known(r.level):
		r._section("Tendencies", definition.ai_tendencies)
		r._section("Rare interactions", definition.rare_interactions)
	else:
		r._section("Tendencies · Mastered", "Not yet recorded.")
	return r

func _section(heading: String, body: String) -> void:
	if not body.strip_edges().is_empty():
		sections.append({"heading": heading, "body": body.strip_edges()})

func plain_text() -> String:
	var lines := PackedStringArray([title, EnumText.research_level(level), progress_text])
	for section in sections:
		lines.append(section.heading + "\n" + section.body)
	return "\n".join(lines)
