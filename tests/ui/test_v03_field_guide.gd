extends TestCase

func after_each() -> void:
	AudioManager.request_music(&"")
	AudioManager.music._update_fade(AudioManager.music._fade_start + 10000000)

func test_saved_research_filters_unseen_affinities_traits_and_later_boss_moves() -> void:
	var registry := Database.registry
	var definition: EnemyDefinition = registry.enemies[&"mirebell_cantor"]
	var bestiary := BestiaryState.new()
	var config := registry.research
	assert_null(FieldGuideReadout.build(definition, bestiary, config), "unseen species has no identity or portrait")
	bestiary.points[definition.id] = config.observed_threshold
	var observed := FieldGuideReadout.build(definition, bestiary, config)
	assert_not_null(observed.portrait)
	assert_false(observed.plain_text().contains("Cracked Resonance"))
	assert_false(observed.plain_text().contains("Normal damage"))
	bestiary.points[definition.id] = config.studied_threshold
	var studied := FieldGuideReadout.build(definition, bestiary, config)
	assert_true(studied.plain_text().contains("Normal damage"))
	assert_false(studied.plain_text().contains("Cracked Resonance"))
	bestiary.points[definition.id] = config.understood_threshold
	var understood := FieldGuideReadout.build(definition, bestiary, config)
	assert_true(understood.plain_text().contains("Cracked Resonance"))
	# This initial trait mentions Final Knell itself; prove phase move sections are gated by heading.
	var later: EnemyActionDefinition = definition.phases.back().actions.back()
	assert_false(understood.sections.any(func(section: Dictionary) -> bool: return section.heading == later.display_name))
	bestiary.points[definition.id] = config.mastered_threshold
	var mastered := FieldGuideReadout.build(definition, bestiary, config)
	assert_true(mastered.sections.any(func(section: Dictionary) -> bool: return section.heading == later.display_name))
	assert_true(mastered.plain_text().contains(definition.ai_tendencies))

func test_guide_and_battle_apply_the_same_research_gates() -> void:
	var registry := Database.registry
	var config := registry.research
	var definition: EnemyDefinition = registry.enemies[&"mirebell_cantor"]
	var thresholds := {Enums.ResearchLevel.OBSERVED: config.observed_threshold,
		Enums.ResearchLevel.STUDIED: config.studied_threshold,
		Enums.ResearchLevel.UNDERSTOOD: config.understood_threshold,
		Enums.ResearchLevel.MASTERED: config.mastered_threshold}
	for level: Enums.ResearchLevel in thresholds:
		var bestiary := BestiaryState.new()
		bestiary.points[definition.id] = thresholds[level]
		var headings: Array = FieldGuideReadout.build(definition, bestiary, config).sections.map(
			func(section: Dictionary) -> String: return section.heading)
		var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"mirebell_cantor"],
			Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER),
			registry.assist(Enums.ExecutionAssist.STANDARD), 7)
		setup.research_levels[definition.id] = level
		var engine := BattleEngine.new(setup)
		var unit: BattleUnit = engine.get_state().enemies(false).filter(
			func(candidate: BattleUnit) -> bool: return candidate.definition.id == definition.id)[0]
		var label := EnumText.research_level(level)
		assert_eq(headings.has("Affinities"), BattleKnowledge.knows_affinity(engine, unit, UnitDetails.AFFINITY_TYPES[0]), label)
		assert_eq(headings.has("Traits"), BattleKnowledge.knows_traits(engine, unit), label)
		assert_eq(headings.has("Base stats"), BattleKnowledge.knows_moves(engine, unit), label)
		assert_eq(headings.has("Tendencies"), BattleKnowledge.knows_tendencies(engine, unit), label)

func test_unrecognised_saved_research_sources_are_not_described() -> void:
	var bestiary := BestiaryState.from_dict({"points": {"thornhound": 5},
		"sources": {"thornhound": [Enums.ResearchSource.INSPECT, 42]}})
	var readout := FieldGuideReadout.build(Database.registry.enemies[&"thornhound"], bestiary, Database.registry.research)
	var learned: Array = readout.sections.filter(func(section: Dictionary) -> bool: return section.heading == "How you learned")
	assert_eq(learned[0].body, "Inspected", "a value this build does not know is skipped, not called Quest")
	assert_eq(bestiary.sources[&"thornhound"].size(), 2, "the saved list itself is untouched")

func test_recorded_results_and_changed_thresholds_use_existing_save_data() -> void:
	var progress := ProgressState.new()
	var config: ResearchConfig = Database.registry.research.duplicate()
	config.studied_threshold = 8
	var result := BattleResult.new()
	result.research[&"thornhound"] = [Enums.ResearchSource.ENCOUNTER, Enums.ResearchSource.INSPECT]
	result.weapon_uses[&"pilgrims_edge"] = 3
	result.weapon_perfects[&"pilgrims_edge"] = 1
	progress.apply_battle_result(result, config)
	var restored := ProgressState.from_dict(progress.to_dict())
	var readout := FieldGuideReadout.build(Database.registry.enemies[&"thornhound"], restored.bestiary, config)
	assert_true(readout.progress_text.contains("/ 8"), "threshold comes from current Resource")
	assert_true(readout.plain_text().contains("Inspected"))
	assert_eq(restored.weapon_mastery[&"pilgrims_edge"], 4)
	assert_eq(progress.to_dict(), restored.to_dict())

func test_guide_navigation_is_read_only_bounded_and_scrollable_on_fixed_canvas() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous := GameState.progress
	var previous_theme := tree.root.theme
	GameState.progress = ProgressState.new()
	GameState.progress.bestiary.points[&"thornhound"] = 18
	GameState.progress.bestiary.points[&"removed_species"] = 99
	var before := GameState.progress.to_dict()
	tree.root.theme = UITheme.build()
	var guide: FieldGuide = load(SceneRouter.FIELD_GUIDE).instantiate()
	tree.root.add_child(guide)
	guide.set_anchors_preset(Control.PRESET_TOP_LEFT)
	guide.size = Vector2(1280, 720)
	for frame in 5:
		await tree.process_frame
	assert_eq(guide._readouts.size(), 1, "unknown saved ids do not disclose other creatures")
	assert_true(guide._choices.has_focus())
	assert_lte(guide._back.get_global_rect().end.y, 720)
	assert_lte(guide._tabs.get_global_rect().end.x, 1280)
	assert_gt(guide._scroll.size.y, 100)
	guide._scroll.scroll_vertical = 100000
	assert_gt(guide._scroll.scroll_vertical, 0, "long entry can scroll")
	guide._tabs.current_tab = 1
	guide._back.grab_focus()
	assert_true(guide._back.has_focus())
	assert_eq(GameState.progress.to_dict(), before, "reading never changes progression")
	guide.queue_free()
	await tree.process_frame
	tree.root.theme = previous_theme
	GameState.progress = previous

func test_empty_guide_offers_back_without_spoiling_unseen_species() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous := GameState.progress
	GameState.progress = ProgressState.new()
	var guide: FieldGuide = load(SceneRouter.FIELD_GUIDE).instantiate()
	tree.root.add_child(guide)
	await tree.process_frame
	await tree.process_frame
	assert_true(guide._readouts.is_empty())
	assert_false(guide._choices.visible)
	assert_true(guide._back.has_focus())
	guide.queue_free()
	GameState.progress = previous

func test_fixed_reaction_help_keeps_keys_and_rule_on_one_compact_line() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_theme := tree.root.theme
	tree.root.theme = UITheme.build()
	var scene: BattleScene = load(SceneRouter.BATTLE).instantiate()
	scene.embedded = true
	tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	scene._timed_active = true
	var spec := ReactionSpec.new()
	spec.allowed = [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE]
	for paused in [false, true]:
		spec.pause_before = paused
		scene._set_help(scene._reaction_help(spec))
		scene._apply_layout()
		await tree.process_frame
		assert_eq(scene._help.get_line_count(), 1)
		assert_eq(scene._help.get_visible_line_count(), 1)
		assert_true(scene._help.text.contains(InputBindings.prompt(InputBindings.PARRY)))
		assert_true(scene._help.text.contains("First allowed press locks"))
		assert_lte(scene._help.get_global_rect().end.y, 720)
	scene.queue_free()
	tree.root.theme = previous_theme
