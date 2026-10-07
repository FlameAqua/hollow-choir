class_name UnitInfo
extends RefCounted
## Info-panel text for a hovered or targeted unit. The immediate layer is always shown (HP, Stagger,
## statuses, buffs, cover, its declared intent). Species knowledge is gated by research the same way
## the previews are: affinities at STUDIED (or once revealed), traits at UNDERSTOOD, AI tendencies at
## MASTERED. Exact stats are the analysis layer (info key held).

const TIER_WORDS := ["", "Elite", "Boss"]


static func describe(unit: BattleUnit, engine: BattleEngine, advanced: bool, show_ai_reasons: bool) -> String:
	if unit == null:
		return ""
	var lines := PackedStringArray()
	var ctx := engine.ctx
	if unit.is_enemy():
		_describe_enemy(unit, engine, lines, show_ai_reasons)
	else:
		lines.append("[b]%s[/b]%s" % [unit.display_name, "" if unit.is_alive() else "  [color=#d65a43](down)[/color]"])
		lines.append("HP %d/%d · Focus %d/%d" % [unit.hp, unit.max_hp, unit.focus, unit.max_focus])
		if unit.weapon != null:
			lines.append("[color=#9b978b]%s (%s, %s)[/color]" % [unit.weapon.display_name, EnumText.family(unit.weapon_family),
				EnumText.damage_type(unit.weapon_damage_type)])
	for status in unit.statuses:
		var definition := status.definition
		var stacks := " x%d" % status.stacks if status.stacks > 1 else ""
		lines.append("[color=%s]%s%s[/color] (%d): %s" % [IconPainter.status_color(status.status).to_html(false),
			definition.display_name, stacks, status.remaining, definition.description])
	for buff in unit.buffs:
		var color := "#d65a43" if buff.definition.is_debuff else "#6fa8d8"
		lines.append("[color=%s]%s[/color] (%d): %s" % [color, buff.definition.display_name, buff.remaining,
			buff.definition.description])
	if unit.intercepted_by >= 0:
		lines.append("[color=#6fa8d8]Covered by %s: single-target attacks hit them instead.[/color]" %
			engine.get_unit(unit.intercepted_by).display_name)
	elif unit.intercepting_for >= 0:
		lines.append("[color=#6fa8d8]Covering %s.[/color]" % engine.get_unit(unit.intercepting_for).display_name)
	if advanced:
		lines.append("[color=#9b978b]Force %d · Guard %d · Tempo %d[/color]" % [roundi(Stats.force(ctx, unit)),
			roundi(Stats.guard(ctx, unit)), roundi(Stats.tempo(ctx, unit))])
	return "\n".join(lines)


static func _describe_enemy(unit: BattleUnit, engine: BattleEngine, lines: PackedStringArray, show_ai_reasons: bool) -> void:
	var ctx := engine.ctx
	var definition := unit.enemy_def()
	var level := ResearchRules.detail_level(ctx, unit)
	var tier: String = TIER_WORDS[definition.tier]
	var header := "[b]%s[/b]  [color=#9b978b]%s%s · %s[/color]" % [unit.display_name, tier + " " if not tier.is_empty() else "",
		EnumText.role(definition.role), EnumText.research_level(level)]
	lines.append(header)
	if not unit.is_alive():
		lines.append("[color=#9b978b]Defeated.[/color]")
		return
	lines.append("HP %d/%d · Stagger %.0f/%.0f" % [unit.hp, unit.max_hp, unit.stagger, unit.max_stagger])
	if unit.is_broken():
		lines.append("[color=#c9a3ff]BROKEN: loses its next turn and takes x%.1f damage.[/color]" %
			ctx.balance.broken_damage_taken_multiplier)
	lines.append(_affinity_line(ctx, unit, definition.weaknesses, "Weak"))
	lines.append(_affinity_line(ctx, unit, definition.resistances, "Resists"))
	if definition.has_weak_point:
		var exposed := " [color=#e9d58c](EXPOSED)[/color]" if unit.is_weak_point_exposed() else ""
		lines.append("Weak point: %s%s" % [definition.weak_point_name, exposed])
	if level >= Enums.ResearchLevel.UNDERSTOOD:
		for trait_def in definition.traits:
			if trait_def != null and not trait_def.description.is_empty():
				lines.append("[color=#9b978b]%s: %s[/color]" % [trait_def.display_name, trait_def.description])
	if level >= Enums.ResearchLevel.MASTERED and not definition.ai_tendencies.is_empty():
		lines.append("[color=#c9a3ff]Tendencies: %s[/color]" % definition.ai_tendencies)
	if unit.intent != null:
		var preview := engine.preview_intent(unit.uid)
		if preview != null:
			lines.append("")
			lines.append(IntentBubble.describe(preview, engine, show_ai_reasons))


## Affinities are listed once known (revealed in battle, or all of them at STUDIED). Until then a
## single "?" marks that more may exist, without leaking how many.
static func _affinity_line(ctx: BattleContext, unit: BattleUnit, types: Array[Enums.DamageType], label: String) -> String:
	var names := PackedStringArray()
	for damage_type in types:
		if PreviewRules.affinity_known(ctx, unit, damage_type):
			names.append(EnumText.damage_type(damage_type))
	if ResearchRules.detail_level(ctx, unit) < Enums.ResearchLevel.STUDIED:
		names.append("?")
	return "%s: %s" % [label, ", ".join(names) if not names.is_empty() else "none"]
