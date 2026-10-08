class_name UnitDetails
extends RefCounted
## Details-view text for one unit (the analysis layer). Public state is always listed: HP, Stagger
## remaining, statuses and buffs with their remaining turns, cover and the declared intent. Species
## knowledge goes through BattleKnowledge exactly like the previews: affinities per damage type
## (STUDIED or a revealing hit), traits and immunities (UNDERSTOOD), tendencies (MASTERED).
## Replaces M1's UnitInfo.

const TIER_WORDS := ["", "Elite", "Boss"]
## Damage types the slice can deal (BLIGHT is reserved; PURE ignores affinity).
const AFFINITY_TYPES: Array[Enums.DamageType] = [Enums.DamageType.SLASH, Enums.DamageType.BLUNT,
	Enums.DamageType.PIERCE, Enums.DamageType.FIRE, Enums.DamageType.STORM]


static func describe(engine: BattleEngine, unit: BattleUnit, show_debug: bool = false) -> String:
	if unit == null:
		return ""
	var lines := PackedStringArray()
	if unit.is_enemy():
		_enemy(engine, unit, lines, show_debug)
	else:
		_party(engine, unit, lines)
	return "\n".join(lines)


static func _party(engine: BattleEngine, unit: BattleUnit, lines: PackedStringArray) -> void:
	var ctx := engine.ctx
	lines.append("[b]%s[/b]%s" % [unit.display_name, "" if unit.is_alive() else "  [color=%s]Down[/color]" % UITheme.hex(UITheme.DANGER)])
	lines.append("HP %d / %d · Focus %d / %d" % [unit.hp, unit.max_hp, unit.focus, Stats.max_focus(ctx, unit)])
	if unit.weapon != null:
		lines.append(_dim("%s · %s · deals %s" % [unit.weapon.display_name, EnumText.family(unit.weapon_family),
			EnumText.damage_type(unit.weapon_damage_type)]))
	_effects(unit, lines)
	_cover(engine, unit, lines)
	lines.append(_dim("Force %d · Guard %d · Tempo %d" % [roundi(Stats.force(ctx, unit)), roundi(Stats.guard(ctx, unit)),
		roundi(Stats.tempo(ctx, unit))]))


static func _enemy(engine: BattleEngine, unit: BattleUnit, lines: PackedStringArray, show_debug: bool) -> void:
	var ctx := engine.ctx
	var definition := unit.enemy_def()
	var level := BattleKnowledge.level(engine, unit)
	var tier: String = TIER_WORDS[definition.tier]
	lines.append("[b]%s[/b]  %s" % [unit.display_name, _dim("%s%s · Knowledge: %s" % [tier + " " if not tier.is_empty() else "",
		EnumText.role(definition.role), EnumText.research_level(level)])])
	if not unit.is_alive():
		lines.append(_dim("Defeated."))
		return
	if unit.is_broken():
		lines.append("HP %d / %d · [color=%s]Broken[/color]" % [unit.hp, unit.max_hp, UITheme.hex(UITheme.STAGGER)])
		lines.append(_dim("Broken: loses its next activation and takes ×%.1f damage; its channel, if any, was interrupted." %
			ctx.balance.broken_damage_taken_multiplier))
	else:
		lines.append("HP %d / %d · Stagger remaining %d / %d" % [unit.hp, unit.max_hp, roundi(unit.stagger), roundi(unit.max_stagger)])
	if definition.has_weak_point:
		var exposed := " [color=%s](exposed)[/color]" % UITheme.hex(UITheme.FOCUS) if unit.is_weak_point_exposed() else ""
		lines.append("Weak point: %s%s" % [definition.weak_point_name, exposed])
	lines.append(affinity_line(engine, unit))
	_effects(unit, lines)
	_cover(engine, unit, lines)
	if BattleKnowledge.knows_traits(engine, unit):
		if not definition.status_immunities.is_empty():
			var immune := PackedStringArray()
			for status in definition.status_immunities:
				immune.append(EnumText.status(status))
			lines.append("Immune to %s" % ", ".join(immune))
		for trait_def in definition.traits:
			if trait_def != null and not trait_def.description.is_empty():
				lines.append(_dim("%s: %s" % [trait_def.display_name, trait_def.description]))
	if BattleKnowledge.knows_tendencies(engine, unit) and not definition.ai_tendencies.is_empty():
		lines.append(_dim("Tendencies: %s" % definition.ai_tendencies))
	if unit.intent != null:
		var preview := engine.preview_intent(unit.uid)
		if preview != null:
			lines.append("")
			lines.append(intent_text(engine, IntentReadout.build(engine, preview, show_debug)))


## "Weak: Blunt · Resists: Slash, Pierce · Neutral: Fire · Unknown: Storm" — only learned entries.
static func affinity_line(engine: BattleEngine, unit: BattleUnit) -> String:
	var definition := unit.enemy_def()
	var weak := PackedStringArray()
	var resists := PackedStringArray()
	var neutral := PackedStringArray()
	var unknown := PackedStringArray()
	for damage_type in AFFINITY_TYPES:
		var name := EnumText.damage_type(damage_type)
		if not BattleKnowledge.knows_affinity(engine, unit, damage_type):
			unknown.append(name)
		elif definition.is_weak_to(damage_type):
			weak.append(name)
		elif definition.resists(damage_type):
			resists.append(name)
		else:
			neutral.append(name)
	var parts := PackedStringArray()
	if not weak.is_empty():
		parts.append("Weak: " + ", ".join(weak))
	if not resists.is_empty():
		parts.append("Resists: " + ", ".join(resists))
	if not neutral.is_empty():
		parts.append("Neutral: " + ", ".join(neutral))
	if not unknown.is_empty():
		parts.append("Unknown: %s %s" % [", ".join(unknown), _dim("(strike to learn, or Inspect)")])
	return " · ".join(parts)


## Intent block shared by unit details and the rail's tooltip.
static func intent_text(engine: BattleEngine, readout: IntentReadout) -> String:
	var lines := PackedStringArray()
	var head := "[b]%s[/b] → %s" % [readout.label, readout.target_text]
	if readout.threat > IntentPreview.Threat.NONE:
		head += "  [color=%s]! %s threat[/color]" % [UITheme.hex(UITheme.THREAT), readout.threat_word]
	lines.append(head)
	if not readout.telegraph.is_empty():
		lines.append(readout.telegraph)
	if not readout.telegraph_detail.is_empty():
		lines.append("[i]%s[/i]" % readout.telegraph_detail)
	if readout.targets_party:
		lines.append("Reactions: %s" % readout.reactions_text())
	var statuses := readout.status_text()
	if not statuses.is_empty():
		lines.append(statuses.left(1).to_upper() + statuses.substr(1))
	if readout.is_channel:
		lines.append("Channel: %s · %s" % [readout.channel_text(), readout.interrupt_text()])
	for uid in readout.target_uids:
		var text := readout.damage_text(uid)
		if text.is_empty():
			continue
		var braced: Vector2i = readout.braced.get(uid, Vector2i.ZERO)
		var evade: Vector2i = readout.evade_failed.get(uid, Vector2i.ZERO)
		var parry: Vector2i = readout.parry_failed.get(uid, Vector2i.ZERO)
		lines.append(_dim("vs %s: %s unreacted · Braced %d–%d · failed Evade %d–%d · failed Parry %d–%d" % [
			BattleKnowledge.unit_name(engine, uid), text, braced.x, braced.y, evade.x, evade.y, parry.x, parry.y]))
	if not readout.damage_known and readout.threat > IntentPreview.Threat.NONE:
		lines.append(_dim("Exact damage unlocks at Understood, or Inspect it."))
	if not readout.debug_reasons.is_empty():
		lines.append("[color=%s]Lab debug · AI reasoning: %s[/color]" % [UITheme.hex(UITheme.STAGGER), "; ".join(readout.debug_reasons)])
	return "\n".join(lines)


static func _effects(unit: BattleUnit, lines: PackedStringArray) -> void:
	for status in unit.statuses:
		var definition := status.definition
		var stacks := " ×%d" % status.stacks if status.stacks > 1 else ""
		lines.append("[color=%s]%s%s[/color] · %s: %s" % [UITheme.hex(IconPainter.status_color(status.status)),
			definition.display_name, stacks, remaining_text(definition, status.remaining), definition.description])
	for buff in unit.buffs:
		var color := UITheme.DANGER if buff.definition.is_debuff else UITheme.INFO
		lines.append("[color=%s]%s[/color] · %s" % [UITheme.hex(color), buff.definition.display_name,
			buff.definition.description])


static func remaining_text(definition: StatusDefinition, remaining: int) -> String:
	if definition != null and definition.duration_mode == Enums.DurationMode.CHARGES:
		return "%d charge%s" % [remaining, "" if remaining == 1 else "s"]
	return "%d turn%s" % [remaining, "" if remaining == 1 else "s"]


static func _cover(engine: BattleEngine, unit: BattleUnit, lines: PackedStringArray) -> void:
	if unit.intercepted_by >= 0:
		var cover := BattleKnowledge.unit_name(engine, unit.intercepted_by)
		lines.append("[color=%s]Covered by %s: single-target attacks on %s hit %s instead.[/color]" % [UITheme.hex(UITheme.INFO),
			cover, unit.display_name, cover])
	elif unit.intercepting_for >= 0:
		lines.append("[color=%s]Covering %s until its next turn.[/color]" % [UITheme.hex(UITheme.INFO),
			BattleKnowledge.unit_name(engine, unit.intercepting_for)])


static func _dim(text: String) -> String:
	return "[color=%s]%s[/color]" % [UITheme.hex(UITheme.TEXT_DIM), text]
