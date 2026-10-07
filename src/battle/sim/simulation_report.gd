class_name SimulationReport
extends RefCounted
## Aggregates a batch of BattleMetrics and flags the GDD's balance smells: overlong encounters,
## unfair matchups, party actions nobody uses, enemy actions the AI never selects.

## Target round ranges by encounter tier (GDD: normal encounters ~3-5 rounds).
const TARGET_ROUNDS := {
	Enums.EnemyTier.NORMAL: Vector2(3.0, 5.0),
	Enums.EnemyTier.ELITE: Vector2(4.0, 7.0),
	Enums.EnemyTier.BOSS: Vector2(7.0, 13.0),
}

var config: SimulationConfig
var battles: Array[BattleMetrics] = []


func _init(p_config: SimulationConfig = null) -> void:
	config = p_config


func add(metrics: BattleMetrics) -> void:
	battles.append(metrics)


func runs() -> int:
	return battles.size()


func win_rate() -> float:
	return _fraction(func(m: BattleMetrics) -> bool: return m.is_win())


func timeout_rate() -> float:
	return _fraction(func(m: BattleMetrics) -> bool: return m.outcome == Enums.BattleOutcome.TIMEOUT)


func mean_of(field: String) -> float:
	if battles.is_empty():
		return 0.0
	var total := 0.0
	for metrics in battles:
		total += float(metrics.get(field))
	return total / battles.size()


## Mean / median / p90 / min / max rounds.
func rounds_summary() -> Dictionary:
	var values: Array[int] = []
	for metrics in battles:
		values.append(metrics.rounds)
	values.sort()
	if values.is_empty():
		return {"mean": 0.0, "median": 0, "p90": 0, "min": 0, "max": 0}
	return {
		"mean": mean_of("rounds"),
		"median": values[values.size() / 2],
		"p90": values[mini(values.size() - 1, int(values.size() * 0.9))],
		"min": values[0],
		"max": values[values.size() - 1],
	}


func encounter_tier() -> Enums.EnemyTier:
	var tier := Enums.EnemyTier.NORMAL
	if config != null and config.encounter != null:
		for enemy in config.encounter.enemies:
			tier = maxi(tier, enemy.tier) as Enums.EnemyTier
	return tier


func action_usage_totals(enemy: bool = false) -> Dictionary[StringName, int]:
	var totals: Dictionary[StringName, int] = {}
	for metrics in battles:
		var usage := metrics.enemy_action_usage if enemy else metrics.action_usage
		for action_id: StringName in usage:
			totals[action_id] = totals.get(action_id, 0) + usage[action_id]
	return totals


## Every enemy action the encounter can ever use (base set + all phases).
func possible_enemy_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	if config == null or config.encounter == null:
		return result
	for enemy in config.encounter.enemies:
		var sets: Array = [enemy.actions]
		for phase in enemy.phases:
			sets.append(phase.actions)
			if phase.opening_action != null and not result.has(phase.opening_action.id):
				result.append(phase.opening_action.id)
		for action_set: Array in sets:
			for action: EnemyActionDefinition in action_set:
				if action != null and not result.has(action.id):
					result.append(action.id)
	return result


## Every party action the loadout offers (including potions). Inspect is excluded: its value is
## knowledge for the player, which no autopilot can model, so "never used" would be noise.
func possible_party_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	if config == null:
		return result
	var engine := BattleEngine.new(config.make_setup(0))
	for unit in engine.get_state().party(false):
		for action in unit.actions:
			if action.category != Enums.ActionCategory.INSPECT and not result.has(action.id):
				result.append(action.id)
	for slot in engine.get_state().potion_slots:
		if slot.potion != null and not result.has(slot.potion.action.id):
			result.append(slot.potion.action.id)
	return result


func never_used(enemy: bool) -> Array[StringName]:
	var used := action_usage_totals(enemy)
	var possible := possible_enemy_actions() if enemy else possible_party_actions()
	var result: Array[StringName] = []
	for action_id in possible:
		if not used.has(action_id):
			result.append(action_id)
	return result


## Fraction of unit-turns spent with each status, per side.
func status_uptime(enemy_side: bool) -> Dictionary[int, float]:
	var turns := 0
	var with_status: Dictionary[int, int] = {}
	for metrics in battles:
		turns += metrics.enemy_turns if enemy_side else metrics.party_turns
		var bucket := metrics.enemy_status_turns if enemy_side else metrics.party_status_turns
		for status: int in bucket:
			with_status[status] = with_status.get(status, 0) + bucket[status]
	var result: Dictionary[int, float] = {}
	for status: int in with_status:
		result[status] = float(with_status[status]) / maxf(1.0, turns)
	return result


func reaction_rates() -> Dictionary[int, Vector2]:
	var totals: Dictionary[int, Vector2i] = {}
	for metrics in battles:
		for reaction: int in metrics.reactions:
			totals[reaction] = totals.get(reaction, Vector2i.ZERO) + metrics.reactions[reaction]
	var result: Dictionary[int, Vector2] = {}
	for reaction: int in totals:
		var counts := totals[reaction]
		result[reaction] = Vector2(counts.x, float(counts.y) / maxf(1.0, counts.x))
	return result


## Balance smells worth a designer's attention.
func flags() -> PackedStringArray:
	var result := PackedStringArray()
	if battles.is_empty():
		return result
	var target: Vector2 = TARGET_ROUNDS[encounter_tier()]
	var mean_rounds := mean_of("rounds")
	if mean_rounds > target.y:
		result.append("OVERLONG: mean %.1f rounds (target %d-%d)" % [mean_rounds, target.x, target.y])
	elif mean_rounds < target.x and win_rate() > 0.5:
		result.append("TOO SHORT: mean %.1f rounds (target %d-%d)" % [mean_rounds, target.x, target.y])
	if timeout_rate() > 0.0:
		result.append("TIMEOUTS: %.0f%% of battles hit the round cap" % (timeout_rate() * 100.0))
	var mode := config.skill.mode if config != null and config.skill != null else Enums.SimulatedExecution.GOOD
	if mode in [Enums.SimulatedExecution.GOOD, Enums.SimulatedExecution.PERFECT] and win_rate() < 0.6:
		result.append("UNFAIR?: only %.0f%% wins with %s execution" % [win_rate() * 100.0, EnumText.simulated_execution(mode)])
	if mode == Enums.SimulatedExecution.MISS and win_rate() > 0.95 and encounter_tier() != Enums.EnemyTier.NORMAL:
		result.append("TRIVIAL?: %.0f%% wins without any execution" % (win_rate() * 100.0))
	var unused_enemy := never_used(true)
	if not unused_enemy.is_empty():
		result.append("AI NEVER USED: %s" % ", ".join(unused_enemy))
	if config != null and config.policy == PartyAutopilot.Policy.SMART:
		var unused_party := never_used(false)
		if not unused_party.is_empty():
			result.append("PARTY NEVER USED: %s" % ", ".join(unused_party))
	return result


func summary_line() -> String:
	var rounds := rounds_summary()
	return "%-28s win %5.1f%%  rounds %4.1f (p90 %d)  dmg taken %5.1f  focus %4.1f  breaks %3.1f" % [
		config.label if config != null else "?", win_rate() * 100.0, rounds.mean, rounds.p90,
		mean_of("damage_taken"), mean_of("focus_generated"), mean_of("stagger_breaks")]


func to_markdown() -> String:
	var lines := PackedStringArray()
	var rounds := rounds_summary()
	lines.append("### %s" % (config.label if config != null else "Simulation"))
	if config != null:
		lines.append("%d runs · %s · %s assist · %s execution · %s policy" % [runs(),
			EnumText.difficulty(config.difficulty.difficulty), EnumText.assist(config.assist.assist),
			EnumText.simulated_execution(config.skill.mode), PartyAutopilot.Policy.keys()[config.policy]])
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("|---|---|")
	lines.append("| Win rate | %.1f%% |" % (win_rate() * 100.0))
	lines.append("| Rounds (mean / median / p90 / max) | %.2f / %d / %d / %d |" % [rounds.mean, rounds.median, rounds.p90, rounds.max])
	lines.append("| Damage taken (mean) | %.1f |" % mean_of("damage_taken"))
	lines.append("| Healing (mean) | %.1f |" % mean_of("healing_done"))
	lines.append("| Focus generated / spent (mean) | %.1f / %.1f |" % [mean_of("focus_generated"), mean_of("focus_spent")])
	lines.append("| Stagger breaks / interrupts (mean) | %.2f / %.2f |" % [mean_of("stagger_breaks"), mean_of("interrupts")])
	lines.append("| Weakness hits (mean) | %.2f |" % mean_of("weakness_hits"))
	lines.append("| Party members downed (mean) | %.2f |" % mean_of("party_defeats"))
	lines.append("")
	lines.append("Party action usage: %s" % _usage_text(action_usage_totals(false)))
	lines.append("")
	lines.append("Enemy action usage: %s" % _usage_text(action_usage_totals(true)))
	lines.append("")
	lines.append("Status uptime (enemies): %s" % _uptime_text(status_uptime(true)))
	lines.append("Status uptime (party): %s" % _uptime_text(status_uptime(false)))
	var rates := reaction_rates()
	var reaction_parts := PackedStringArray()
	for reaction: int in rates:
		reaction_parts.append("%s %d (%.0f%% ok)" % [EnumText.reaction(reaction), rates[reaction].x, rates[reaction].y * 100.0])
	lines.append("Reactions: %s" % (", ".join(reaction_parts) if not reaction_parts.is_empty() else "—"))
	var smells := flags()
	if not smells.is_empty():
		lines.append("")
		for smell in smells:
			lines.append("- ⚠ %s" % smell)
	lines.append("")
	return "\n".join(lines)


func to_dict() -> Dictionary:
	var rounds := rounds_summary()
	return {
		"label": config.label if config != null else "",
		"runs": runs(),
		"win_rate": win_rate(),
		"timeout_rate": timeout_rate(),
		"rounds": rounds,
		"damage_taken": mean_of("damage_taken"),
		"healing": mean_of("healing_done"),
		"focus_generated": mean_of("focus_generated"),
		"stagger_breaks": mean_of("stagger_breaks"),
		"interrupts": mean_of("interrupts"),
		"action_usage": action_usage_totals(false),
		"enemy_action_usage": action_usage_totals(true),
		"flags": Array(flags()),
	}


func _usage_text(usage: Dictionary[StringName, int]) -> String:
	var total := 0
	for count: int in usage.values():
		total += count
	var keys := usage.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return usage[a] > usage[b])
	var parts := PackedStringArray()
	for key: StringName in keys:
		parts.append("%s %.0f%%" % [key, 100.0 * usage[key] / maxf(1.0, total)])
	return ", ".join(parts) if not parts.is_empty() else "—"


func _uptime_text(uptime: Dictionary[int, float]) -> String:
	var parts := PackedStringArray()
	for status: int in uptime:
		parts.append("%s %.0f%%" % [EnumText.status(status), uptime[status] * 100.0])
	return ", ".join(parts) if not parts.is_empty() else "—"


func _fraction(predicate: Callable) -> float:
	if battles.is_empty():
		return 0.0
	var count := 0
	for metrics in battles:
		if predicate.call(metrics):
			count += 1
	return float(count) / battles.size()
