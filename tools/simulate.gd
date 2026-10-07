extends SceneTree
## Batch combat simulation from the command line (GDD "AI and balance testing").
##
##   godot --headless --path . --script res://tools/simulate.gd -- [options]
##
## Options (comma-separated lists or "all"):
##   --encounter=fen_patrol,mirebell_cantor   default: all
##   --loadout=starter_sword                   default: starter_sword,starter_hammer,starter_bow
##   --exec=MISS,GOOD,PERFECT,MIXED            default: MIXED
##   --difficulty=STORY,ADVENTURER,TACTICIAN   default: ADVENTURER
##   --assist=STANDARD                         default: STANDARD
##   --policy=SMART|BASIC_ONLY|RANDOM          default: SMART
##   --runs=100 --seed=1
##   --detail        print the full markdown report per batch (default: one summary line each)
##   --out=user://sim_report.md                also write the full markdown (or .json) report
##   --research=MASTERED                       assume this bestiary level for every enemy

var _options: Dictionary = {}


func _initialize() -> void:
	_options = _parse(OS.get_cmdline_user_args())
	var registry := DefinitionRegistry.load_default()
	var problems := registry.validate()
	if not problems.is_empty():
		for problem in problems:
			printerr(problem)
		quit(1)
		return
	var library := registry.make_library()
	var encounters := _select(registry.encounters, "encounter", registry.sorted_ids(registry.encounters))
	var loadouts := _select(registry.loadouts, "loadout", [&"starter_sword", &"starter_hammer", &"starter_bow"])
	var execs := _select_enum(Enums.SimulatedExecution, "exec", ["MIXED"])
	var difficulties := _select_enum(Enums.TacticalDifficulty, "difficulty", ["ADVENTURER"])
	var assists := _select_enum(Enums.ExecutionAssist, "assist", ["STANDARD"])
	var policy: PartyAutopilot.Policy = PartyAutopilot.Policy.get(String(_options.get("policy", "SMART")).to_upper(), PartyAutopilot.Policy.SMART)
	var runs := int(_options.get("runs", "100"))
	var seed := int(_options.get("seed", "1"))
	var research_level := -1
	if _options.has("research"):
		research_level = Enums.ResearchLevel.get(String(_options.research).to_upper(), -1)

	var started := Time.get_ticks_msec()
	var markdown := PackedStringArray(["# Hollow Choir — simulation report", ""])
	var json_rows: Array = []
	var matrix: Dictionary = {}
	for encounter_id: StringName in encounters:
		var encounter: EncounterDefinition = registry.encounters[encounter_id]
		for loadout_id: StringName in loadouts:
			for exec: int in execs:
				for tier: int in difficulties:
					for assist_kind: int in assists:
						var config := SimulationConfig.new()
						config.loadout = registry.loadouts[loadout_id]
						config.encounter = encounter
						config.library = library
						config.difficulty = registry.difficulty(tier)
						config.assist = registry.assist(assist_kind)
						config.skill = registry.skill(exec)
						config.policy = policy
						config.runs = runs
						config.base_seed = seed
						if research_level >= 0:
							for enemy in encounter.enemies:
								config.research_levels[enemy.id] = research_level
						config.label = "%s | %s | %s | %s" % [encounter_id, loadout_id,
							EnumText.simulated_execution(exec), EnumText.difficulty(tier)]
						var report := SimulationRunner.run_batch(config)
						if _options.has("detail"):
							print(report.to_markdown())
						else:
							print(report.summary_line())
							for smell in report.flags():
								print("    ! %s" % smell)
						markdown.append(report.to_markdown())
						json_rows.append(report.to_dict())
						var key := "%s|%s|%s" % [encounter_id, EnumText.simulated_execution(exec), EnumText.difficulty(tier)]
						if not matrix.has(key):
							matrix[key] = {}
						matrix[key][loadout_id] = report.win_rate()
	if loadouts.size() > 1:
		var table := _matrix_table(matrix, loadouts)
		print("")
		print(table)
		markdown.append(table)
	print("Done in %.1fs" % ((Time.get_ticks_msec() - started) / 1000.0))
	if _options.has("out"):
		_write(String(_options.out), "\n".join(markdown), json_rows)
	quit(0)


func _matrix_table(matrix: Dictionary, loadouts: Array[StringName]) -> String:
	var lines := PackedStringArray()
	var header := "| Matchup |"
	var rule := "|---|"
	for loadout_id in loadouts:
		header += " %s |" % loadout_id
		rule += "---|"
	lines.append("## Win rate by loadout (dominance check)")
	lines.append("")
	lines.append(header)
	lines.append(rule)
	var keys := matrix.keys()
	keys.sort()
	for key: String in keys:
		var row := "| %s |" % key
		for loadout_id in loadouts:
			row += " %.0f%% |" % (float(matrix[key].get(loadout_id, 0.0)) * 100.0)
		lines.append(row)
	return "\n".join(lines)


func _write(path: String, markdown: String, rows: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % path)
		return
	if path.ends_with(".json"):
		file.store_string(JSON.stringify(rows, "  "))
	else:
		file.store_string(markdown)
	print("Report written to %s" % ProjectSettings.globalize_path(path))


func _parse(args: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return result


func _select(collection: Dictionary, option: String, defaults: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw := String(_options.get(option, ""))
	if raw == "all":
		for id: StringName in collection.keys():
			result.append(id)
		result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		return result
	var wanted: Array = defaults if raw.is_empty() else Array(raw.split(","))
	for id in wanted:
		if collection.has(StringName(id)):
			result.append(StringName(id))
		else:
			printerr("unknown %s '%s'" % [option, id])
	return result


func _select_enum(enum_dict: Dictionary, option: String, defaults: Array) -> Array[int]:
	var result: Array[int] = []
	var raw := String(_options.get(option, ""))
	var wanted: Array = defaults if raw.is_empty() else Array(raw.to_upper().split(","))
	if raw == "all":
		wanted = enum_dict.keys()
	for name in wanted:
		if enum_dict.has(name):
			result.append(enum_dict[name])
		else:
			printerr("unknown %s '%s'" % [option, name])
	return result
