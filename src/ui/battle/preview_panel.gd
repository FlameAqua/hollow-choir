class_name PreviewPanel
extends PanelContainer
## Selected-action preview. Immediate layer: expected results per execution grade, Stagger, break,
## statuses, Focus. Analysis layer (hold the info key / setting ALWAYS): the full damage formula,
## command windows, tags and nuance text (GDD "Interface philosophy").

var _text: RichTextLabel


func _ready() -> void:
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = true
	_text.add_theme_font_size_override("normal_font_size", UITheme.font_size(0.82))
	_text.add_theme_font_size_override("bold_font_size", UITheme.font_size(0.82))
	add_child(_text)


func show_text(bbcode: String) -> void:
	_text.text = bbcode


func show_preview(preview: ActionPreview, engine: BattleEngine, advanced: bool, spec: CommandSpec) -> void:
	_text.text = describe(preview, engine, advanced, spec)


static func describe(preview: ActionPreview, engine: BattleEngine, advanced: bool, spec: CommandSpec) -> String:
	var action := preview.action
	var lines := PackedStringArray()
	var cost := " · %d Focus" % action.focus_cost if action.focus_cost > 0 else ""
	lines.append("[b]%s[/b] · %s%s" % [action.display_name.to_upper(), EnumText.category(action.category), cost])
	var target := engine.get_unit(preview.target_uid)
	if action.is_area():
		lines.append("[color=#6fa8d8]> all %d targets[/color]" % preview.area_targets)
	elif target != null:
		lines.append("[color=#6fa8d8]> %s[/color]" % target.display_name)
	lines.append(action.description)
	var miss := Enums.ExecutionGrade.MISS
	var good := Enums.ExecutionGrade.GOOD
	var perfect := Enums.ExecutionGrade.PERFECT
	if preview.deals_damage:
		lines.append("Damage  Miss %d-%d · [color=#e8e3d4]Good %d-%d[/color] · [color=#d8b45a]Perfect %d-%d[/color]" % [
			preview.damage_min[miss], preview.damage_max[miss], preview.damage_min[good], preview.damage_max[good],
			preview.damage_min[perfect], preview.damage_max[perfect]])
		if preview.stagger[good] > 0.0:
			var stagger_line := "Stagger %.0f (Good) · %.0f (Perfect)" % [preview.stagger[good], preview.stagger[perfect]]
			if preview.would_break:
				stagger_line += "  [color=#c9a3ff][b]BREAKS IT[/b][/color]"
			lines.append(stagger_line)
		var tags := PackedStringArray()
		if preview.is_weakness:
			tags.append("[color=#d8b45a]WEAK to %s[/color]" % EnumText.damage_type(preview.damage_type) if preview.affinity_known else "[color=#d8b45a]Weakness?[/color]")
		elif preview.is_resisted:
			tags.append("[color=#9b978b]Resists %s[/color]" % EnumText.damage_type(preview.damage_type) if preview.affinity_known else "[color=#9b978b]Resisted?[/color]")
		if preview.hits_weak_point:
			tags.append("[color=#e9d58c]Weak point![/color]")
		if preview.target_broken:
			tags.append("[color=#c9a3ff]Target Broken x1.5[/color]")
		if preview.would_kill:
			tags.append("[color=#d65a43]Lethal[/color]")
		if not tags.is_empty():
			lines.append(" · ".join(tags))
	if preview.heal[good] > 0:
		lines.append("[color=#7fbf6a]Heals %d (Good) · %d (Perfect)[/color]" % [preview.heal[good], preview.heal[perfect]])
	for status in preview.statuses:
		lines.append("Applies [color=%s]%s[/color]" % [IconPainter.status_color(status).to_html(false), EnumText.status(status)])
	if preview.focus_gain[perfect] > 0 or preview.focus_gain[good] > 0:
		lines.append("[color=#d8b45a]Focus +%d (Good) · +%d (Perfect)[/color]" % [preview.focus_gain[good], preview.focus_gain[perfect]])
	if action.command_type() != Enums.ActionCommandType.NONE:
		lines.append("[color=#9b978b]Command: %s[/color]" % EnumText.command_type(action.command_type()))
	if advanced:
		lines.append("")
		lines.append("[color=#9b978b]— Analysis —[/color]")
		for line in preview.breakdown:
			lines.append("[color=#9b978b]%s[/color]" % line)
		if spec != null and spec.type != Enums.ActionCommandType.NONE:
			lines.append("[color=#9b978b]Windows: Good %d ms · Perfect %d ms%s[/color]" % [roundi(spec.good_window_ms),
				roundi(spec.perfect_window_ms), " · %d beats" % spec.beat_count if spec.type == Enums.ActionCommandType.RHYTHM else ""])
		var tag_names := PackedStringArray()
		for tag in action.tags:
			tag_names.append(String(Enums.ActionTag.keys()[tag]).capitalize())
		if not tag_names.is_empty():
			lines.append("[color=#9b978b]Tags: %s[/color]" % ", ".join(tag_names))
		if not action.details.is_empty():
			lines.append("[color=#9b978b]%s[/color]" % action.details)
	else:
		lines.append("[color=#5f5c55]Hold %s for details[/color]" % InputBindings.key_label(InputBindings.INFO))
	return "\n".join(lines)
