class_name PreviewPanel
extends PanelContainer
## Shared action / enemy-move card (dock preview column and inspector cards, M1.1 F1). Title and
## Focus/charges or threat at the top, status payloads beneath, targets at left and outcomes at
## right, honest scope ("Good · hit", "Good · each") at the bottom. Analysis text (per-grade
## numbers, formula, windows) comes from the static describe helpers. Everything comes from an
## ActionReadout or IntentReadout; this widget never reads research itself.

const BIG := 1.5
## The engine's general party Focus sources (ActionResolver timing/weakness/parry, StaggerRules Break,
## GAIN_FOCUS on Inspect and Guard-category actions). Each weapon replaces plain Guard with its own
## Guard action (a stance or Steady Aim), so no single action name is promised.
const FOCUS_SOURCES := "Basic attacks on Good or Perfect, other timed actions on Perfect, weakness hits, parries, Breaks, Inspect and each weapon's Guard action restore it. Traits, gear and supplies can add more."

var _summary: Control
var _readout: ActionReadout
var _intent_readout: IntentReadout
var _regions: Array[Dictionary] = []
## Equivalent plain text of the card for accessibility and test clients.
var _plain := ""
## The dock uses the same native-font transform as inspection. Nested inspector cards stay at 1.
var summary_scale: float = 1.0
## The shared dock removes the spare title row used by larger floating cards.
var compact := false


func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new() if compact else UICraft.panel("inspection", 14, 10))


func show_readout(readout: ActionReadout) -> void:
	_intent_readout = null
	_readout = readout
	_plain = UITheme.plain_text(describe(readout, false))
	_ensure_summary()
	tooltip_text = describe(readout, true)
	_summary.queue_redraw()


func _ensure_summary() -> void:
	if _summary == null:
		_summary = Control.new()
		_summary.mouse_filter = Control.MOUSE_FILTER_PASS
		_summary.draw.connect(_draw_summary)
		_summary.resized.connect(_summary.queue_redraw)
		add_child(_summary)


func _draw_summary() -> void:
	_regions.clear()
	_summary.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * summary_scale)
	if _intent_readout != null:
		_draw_intent_summary()
		return
	if _readout == null:
		return
	var r := _readout
	var font := get_theme_default_font()
	var small := UITheme.secondary_size()
	var available := _summary.size / summary_scale
	var line := float(small + 12)
	var side := 26.0
	var icon := CombatIcons.mapping("player_actions", r.action.id, "action_item")
	var count := str(r.item_charges) if r.item_charges >= 0 else str(r.focus_cost)
	var cost_width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 36
	var cost_x := available.x - cost_width
	_summary.draw_string(font, Vector2(0, small), UITheme.fit_text(r.label, cost_x - 12, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.ACCENT)
	CombatIcons.paint(_summary, "action_item" if r.item_charges >= 0 else "focus", Rect2(cost_x, 0, side, side))
	_summary.draw_string(font, Vector2(cost_x + 32, small), count, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.FOCUS)
	_regions.append({"rect": Rect2(cost_x, 0, cost_width, line), "text": "%s\n%s\n%s" % ["Charges" if r.item_charges >= 0 else "Focus cost", count, "Remaining uses of this equipped supply." if r.item_charges >= 0 else "Focus spent when this action is used. " + FOCUS_SOURCES]})
	var y := line
	var scope := target_scope(r) + " · " + ("No timing" if r.command_type == Enums.ActionCommandType.NONE else "Good timing")
	_summary.draw_string(font, Vector2(0, available.y - 3), UITheme.fit_text(scope, available.x, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.TEXT_DIM)
	_regions.append({"rect": Rect2(0, available.y - small - 5, available.x, small + 5), "text": target_scope(r) + "\n" + ("This action has no timing input." if r.command_type == Enums.ActionCommandType.NONE else "The displayed outcome assumes Good timing. " + grades_hint())})
	if not r.legal:
		_summary.draw_string(font, Vector2(0, y + small), UITheme.fit_text(r.reason, available.x, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.DANGER)
		return
	# Status payloads occupy a stable strip below the cost, aligned to the right.
	if not r.statuses.is_empty():
		var shown := mini(r.statuses.size(), maxi(1, int(available.x / 42)))
		var x := available.x - shown * 42
		for i in shown:
			var note := r.statuses[i]
			var explanation := note.text()
			var doused := false
			for target in r.targets:
				if target.doused.has(note.status):
					doused = true
					explanation += "\nDoused on " + target.name
			var rect := Rect2(x, y, 34, 32)
			_summary.draw_rect(rect, UITheme.BG)
			CombatIcons.paint(_summary, CombatIcons.mapping("statuses", note.status), rect.grow(-3))
			if doused or note.qualifier != RuleNotes.Qualifier.ALWAYS:
				_summary.draw_string(font, Vector2(x + 21, y + 26), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITheme.TEXT)
			_regions.append({"rect": rect, "text": explanation})
			x += 42
		y += 38
	y = maxf(y, available.y - small - 12 - (maxi(1, r.targets.size()) + r.support_effects.size()) * line)
	for i in r.targets.size():
		var row := r.targets[i]
		if y + line + small > available.y:
			_summary.draw_string(font, Vector2(0, y + small), "+%d targets" % (r.targets.size() - i), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
			break
		# An ally target is still meaningful when the action has no damage or healing outcome.
		# Never fabricate a green dash beside a potion or support icon.
		if not row.deals_damage and row.heal[Enums.ExecutionGrade.GOOD] <= 0:
			_summary.draw_string(font, Vector2(0, y + small), UITheme.fit_text(row.name, available.x, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
			y += line
			continue
		var amount := _range(row.damage_min[Enums.ExecutionGrade.GOOD], row.damage_max[Enums.ExecutionGrade.GOOD]) if row.has_numbers else "?"
		if not row.deals_damage:
			amount = "+" + str(row.heal[Enums.ExecutionGrade.GOOD])
		var amount_width := font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		var show_stagger := row.has_numbers and row.deals_damage and available.x >= 380 * UITheme.text_scale()
		var stagger_width := (font.get_string_size(str(roundi(row.stagger[Enums.ExecutionGrade.GOOD])), HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 44) if show_stagger else 0.0
		var result_x := available.x - amount_width - 32 - stagger_width
		_summary.draw_string(font, Vector2(0, y + small), UITheme.fit_text(row.name, result_x - 12, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
		CombatIcons.paint(_summary, row_icon(row, icon), Rect2(result_x, y, side, side))
		_summary.draw_string(font, Vector2(result_x + 32, y + small), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.DANGER if row.deals_damage else UITheme.HEART)
		_regions.append({"rect": Rect2(result_x, y, amount_width + 32, line), "text": "%s\n%s\n%s" % ["Damage" if row.deals_damage else "Healing / support", amount, _row_summary(row, r) if row.deals_damage else r.description]})
		if show_stagger:
			var sx := available.x - stagger_width + 8
			CombatIcons.paint(_summary, "stagger", Rect2(sx, y, side, side))
			_summary.draw_string(font, Vector2(sx + 32, y + small), str(roundi(row.stagger[Enums.ExecutionGrade.GOOD])), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.STAGGER)
			_regions.append({"rect": Rect2(sx, y, stagger_width, line), "text": "Break damage\n%d at Good timing · %d remaining" % [roundi(row.stagger[Enums.ExecutionGrade.GOOD]), roundi(row.stagger_remaining)]})
		y += line
	if r.targets.is_empty():
		_summary.draw_string(font, Vector2(0, y + small), UITheme.fit_text(r.category_text, available.x, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
		y += line
	for note in r.support_effects:
		var recipient := r.actor_name if note.recipient == "self" else note.recipient
		var recipient_width := minf(available.x * 0.4, font.get_string_size(recipient, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
		var rect := Rect2(0, y, available.x, line)
		CombatIcons.paint(_summary, note.icon, Rect2(0, y, side, side))
		_summary.draw_string(font, Vector2(32, y + small), UITheme.fit_text(note.label, available.x - recipient_width - 46, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, note.color)
		_summary.draw_string(font, Vector2(available.x - recipient_width, y + small), UITheme.fit_text(recipient, recipient_width, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.TEXT_DIM)
		_regions.append({"rect": rect, "text": "%s · %s\n%s" % [note.label, recipient, note.explanation]})
		y += line


func _get_tooltip(point: Vector2) -> String:
	var field := field_tooltip(point)
	return field if not field.is_empty() else tooltip_text


func field_tooltip(point: Vector2) -> String:
	if _summary != null and _summary.visible:
		for region in _regions:
			if (region.rect as Rect2).has_point((point - _summary.position) / summary_scale):
				return region.text
	return ""


## Enemy moves use the same title / resource / payload / outcome card, with filtered facts only.
func show_intent(readout: IntentReadout) -> void:
	_ensure_summary()
	_readout = null
	_intent_readout = readout
	_plain = "%s\n%s\n%s" % [readout.label, readout.target_text, readout.telegraph]
	_summary.queue_redraw()


func _draw_intent_summary() -> void:
	var r := _intent_readout
	var font := get_theme_default_font()
	var small := UITheme.secondary_size()
	var line := float(small + 12)
	var width := _summary.size.x / summary_scale
	var threat := threat_label(r)
	var threat_width := font.get_string_size(threat, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 12
	var badge := Rect2(maxf(0, width - threat_width), 0, minf(width, threat_width), line)
	_summary.draw_rect(badge, UITheme.BG)
	_summary.draw_string(font, Vector2(badge.position.x + 6, small), UITheme.fit_text(threat, badge.size.x - 12, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.DANGER)
	_regions.append({"rect": badge, "text": "Threat\n" + threat + "\nRelative danger of this move; exact damage is shown separately when learned."})
	# Keep a stable top-right badge and wrap the move title onto its own row when necessary.
	var title_y := 0.0 if font.get_string_size(r.label, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + threat_width + 18 <= width else line
	_summary.draw_string(font, Vector2(0, title_y + small), UITheme.fit_text(r.label, width if title_y > 0 else badge.position.x - 12, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.DANGER)
	var y := line * (1 if compact and title_y == 0.0 else 2)
	var x := width - r.statuses.size() * 38
	for note in r.statuses:
		var rect := Rect2(maxf(0, x), y, 32, 32)
		_summary.draw_rect(rect, UITheme.BG)
		CombatIcons.paint(_summary, CombatIcons.mapping("statuses", note.status), rect.grow(-3))
		if note.qualifier != RuleNotes.Qualifier.ALWAYS:
			_summary.draw_string(font, Vector2(x + 20, y + 26), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITheme.TEXT)
		_regions.append({"rect": rect, "text": note.text()})
		x += 38
	if not r.statuses.is_empty():
		y += 38
	y = maxf(y, _summary.size.y / summary_scale - (50 if r.targets_party or r.is_channel else 0) - maxi(1, r.target_uids.size()) * line - 10)
	for uid in r.target_uids:
		var amount := r.damage_text(uid)
		if amount.is_empty():
			amount = "?" if r.threat > IntentPreview.Threat.NONE else "—"
		var amount_width := font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 32
		var rx := width - amount_width
		_summary.draw_string(font, Vector2(0, y + small), UITheme.fit_text(r.target_names.get(uid, "Target"), rx - 10, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
		CombatIcons.paint(_summary, CombatIcons.intent(r), Rect2(rx, y, 26, 26))
		_summary.draw_string(font, Vector2(rx + 32, y + small), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.DANGER)
		_regions.append({"rect": Rect2(rx, y, amount_width, line), "text": "Incoming damage · per target\n" + (amount if r.damage_known else "Exact damage unlocks at Understood, or Inspect.")})
		y += line
	if r.target_uids.is_empty():
		_summary.draw_string(font, Vector2(0, y + small), UITheme.fit_text(r.target_text, width, font, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.INFO)
		y += line
	x = 0
	if r.targets_party:
		for i in ReactionReadout.REACTIONS.size():
			var reaction := ReactionReadout.REACTIONS[i]
			var rect := Rect2(x, y, 44, 44)
			CombatIcons.paint(_summary, CombatIcons.mapping("reactions", reaction), rect, Color.WHITE if r.allowed[i] else Color(0.45, 0.45, 0.45, 0.75))
			if not r.allowed[i]:
				_summary.draw_line(rect.position, rect.end, UITheme.DANGER, 2)
			_regions.append({"rect": rect, "text": EnumText.reaction(reaction) + ("\nAvailable" if r.allowed[i] else "\nUnavailable")})
			x += 54
	if r.is_channel:
		CombatIcons.paint(_summary, "channel", Rect2(width - 70, y, 30, 30))
		_summary.draw_string(font, Vector2(width - 34, y + small), str(r.activations_to_release), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.ACCENT)
		_regions.append({"rect": Rect2(width - 70, y, 70, line), "text": r.channel_text() + "\n" + r.interrupt_text()})

## Where the other timing grades are, for the player's actual Details key and mode.
static func grades_hint() -> String:
	match Settings.data.advanced_tooltips:
		GameSettings.TooltipMode.TOGGLE:
			return "%s shows the other timing grades." % InputBindings.prompt(InputBindings.INFO)
		GameSettings.TooltipMode.ALWAYS:
			return "Details below list the other timing grades."
	return "Hold %s for the other timing grades." % InputBindings.prompt(InputBindings.INFO)

static func threat_label(readout: IntentReadout) -> String:
	return "No threat" if readout.threat == IntentPreview.Threat.NONE else readout.threat_word + " threat"

static func intent_height(readout: IntentReadout, compact: bool = false) -> float:
	return 44 + (1 if compact else 2) * (UITheme.secondary_size() + 12) + maxi(1, readout.target_uids.size()) * (UITheme.secondary_size() + 12) + (38 if not readout.statuses.is_empty() else 0) + (50 if readout.targets_party or readout.is_channel else 0)

static func intent_details(readout: IntentReadout) -> String:
	var lines := PackedStringArray()
	if not readout.telegraph.is_empty():
		lines.append(readout.telegraph)
	if not readout.telegraph_detail.is_empty():
		lines.append("[color=%s]%s[/color]" % [UITheme.hex(UITheme.INFO), readout.telegraph_detail])
	if readout.is_channel:
		lines.append(readout.channel_text() + "\n" + readout.interrupt_text())
	for uid in readout.target_uids:
		if not readout.damage_known:
			continue
		lines.append("[color=%s]%s[/color]" % [UITheme.hex(UITheme.INFO), readout.target_names.get(uid, "Target")])
		lines.append("[color=%s]Unreacted: %s[/color]" % [UITheme.hex(UITheme.DANGER), readout.damage_text(uid)])
		for i in ReactionReadout.REACTIONS.size():
			if not readout.allowed[i]:
				continue
			var ranges: Dictionary = [readout.braced, readout.evade_failed, readout.parry_failed][i]
			if ranges.has(uid):
				var amount: Vector2i = ranges[uid]
				lines.append("%s: %s" % [["Braced", "Failed evade", "Failed parry"][i], _range(amount.x, amount.y)])
	if not readout.damage_known and readout.threat > IntentPreview.Threat.NONE:
		lines.append(_dim("Exact damage unlocks at Understood, or Inspect."))
	if not readout.debug_reasons.is_empty():
		lines.append("Lab debug\n" + "\n".join(readout.debug_reasons))
	return "\n\n".join(lines)


## Glyph beside one target row: the heal symbol only where the row actually heals (Guard, stances
## and Inspect do not), otherwise the action's own symbol.
static func row_icon(row: ActionReadout.TargetRow, action_icon: String) -> String:
	return "action_heal" if not row.deals_damage and row.heal[Enums.ExecutionGrade.GOOD] > 0 else action_icon


func get_text() -> String:
	return _plain


## The card as BBCode text: the immediate layer, plus the analysis layer when [param details].
static func describe(readout: ActionReadout, details: bool) -> String:
	var lines := PackedStringArray()
	if not readout.legal:
		lines.append("[color=%s]Unavailable · %s[/color]" % [UITheme.hex(UITheme.THREAT), readout.reason])
	lines.append(_header(readout))
	var redirect := _redirect_line(readout)
	if not redirect.is_empty():
		lines.append(redirect)
	if not readout.description.is_empty():
		lines.append("[font_size=%d]%s[/font_size]" % [UITheme.secondary_size(), _dim(readout.description)])
	if readout.deals_damage():
		_damage_block(readout, lines)
	else:
		_support_block(readout, lines)
	for note in readout.statuses:
		lines.append(note.text())
		for row in readout.targets:
			var index := row.doused.find(note.status)
			if index >= 0:
				lines.append("[color=%s]%s on %s would be doused: it is %s.[/color]" % [UITheme.hex(UITheme.WET),
					EnumText.status(note.status), row.name, EnumText.status(row.doused_by[index])])
	if details:
		lines.append("")
		_details_block(readout, lines)
	return "\n".join(lines)


## The analysis layer alone (expanded inspection beneath the card): authored rules, named support
## effects, per-grade numbers, formula and windows.
static func describe_details(readout: ActionReadout, include_description: bool = true) -> String:
	var lines := PackedStringArray()
	lines.append("[color=%s]%s[/color]" % [UITheme.hex(UITheme.INFO), readout.category_text])
	if include_description and not readout.description.is_empty():
		lines.append(_dim(readout.description))
	for note in readout.support_effects:
		lines.append("[color=%s]%s · %s[/color]\n%s" % [UITheme.hex(note.color), note.label, readout.actor_name if note.recipient == "self" else note.recipient, note.explanation])
	_details_block(readout, lines)
	return "\n\n".join(lines)


static func target_scope(readout: ActionReadout) -> String:
	match readout.scope:
		ActionReadout.Scope.DIRECT_HIT: return "1 enemy"
		ActionReadout.Scope.PER_TARGET:
			return "All enemies" if readout.action.targets_enemies() else "All allies"
		ActionReadout.Scope.ALLY: return "1 ally"
		ActionReadout.Scope.SELF: return "Self"
		ActionReadout.Scope.BATTLEFIELD: return "Battlefield"
	return "No target"

static func action_height(readout: ActionReadout) -> float:
	if not readout.legal:
		return 80 + UITheme.secondary_size() + 12
	return 80 + (UITheme.secondary_size() + 12) * (maxi(1, readout.targets.size()) + readout.support_effects.size()) + (38 if not readout.statuses.is_empty() else 0)


## Native (unscaled) height a nested card needs for [param readout]: its rows are drawn bottom-up,
## so callers size the card with this rather than with their own row arithmetic.
static func card_height(readout: RefCounted, compact: bool = false) -> float:
	if readout is IntentReadout:
		return intent_height(readout, compact)
	if readout is ActionReadout:
		return action_height(readout)
	return 0.0


static func _header(readout: ActionReadout) -> String:
	var target := ""
	match readout.scope:
		ActionReadout.Scope.DIRECT_HIT, ActionReadout.Scope.ALLY:
			if not readout.targets.is_empty():
				var row := readout.targets[0]
				target = " → " + (row.chosen_name if row.chosen_uid >= 0 else row.name).to_upper()
		ActionReadout.Scope.PER_TARGET:
			var side := "ALL ENEMIES" if readout.action.targets_enemies() else "ALL ALLIES"
			target = " → %s (%d)" % [side, readout.targets.size()]
		ActionReadout.Scope.SELF:
			target = " · SELF"
	var cost := ""
	if readout.item_charges >= 0:
		cost = " · %d left" % readout.item_charges
	elif readout.focus_cost > 0:
		cost = " · %d Focus" % readout.focus_cost
	var knowledge := ""
	if readout.scope == ActionReadout.Scope.DIRECT_HIT and not readout.targets.is_empty() and readout.targets[0].is_enemy:
		knowledge = "  " + _dim(EnumText.research_level(readout.targets[0].research).to_upper())
	return "[b]%s[/b]%s%s%s" % [readout.label.to_upper(), target, cost, knowledge]


static func _redirect_line(readout: ActionReadout) -> String:
	for row in readout.targets:
		if row.chosen_uid >= 0:
			return "[color=%s]%s is covered: this hit lands on %s instead.[/color]" % [UITheme.hex(UITheme.INFO),
				row.chosen_name, row.name]
	return ""


static func _damage_block(readout: ActionReadout, lines: PackedStringArray) -> void:
	var good := ActionReadout.GOOD
	if readout.scope == ActionReadout.Scope.PER_TARGET:
		for row in readout.targets:
			lines.append("%s: %s" % [row.name, _row_summary(row, readout)])
		lines.append(_dim("%s · per target · no total" % _grade_scope(readout)))
	elif not readout.targets.is_empty():
		var row := readout.targets[0]
		if row.has_numbers:
			var big := UITheme.font_size(BIG)
			var parts := PackedStringArray()
			parts.append("[font_size=%d]%s[/font_size] damage" % [big, _range(row.damage_min[good], row.damage_max[good])])
			if row.stagger[good] > 0.0:
				parts.append("[font_size=%d]%d[/font_size] Stagger" % [big, roundi(row.stagger[good])])
			var focus := readout.focus_timing[good] + readout.focus_weakness
			if focus > 0:
				parts.append("[font_size=%d]+%d[/font_size] Focus" % [big, focus])
			lines.append("   ".join(parts))
			var tags := _affinity_tags(row, readout)
			if not tags.is_empty():
				lines.append(tags)
			lines.append(_dim("%s · direct hit" % _grade_scope(readout)))
			var claims := _claims(row)
			if not claims.is_empty():
				lines.append(claims)
		else:
			lines.append("[color=%s]Affinity unknown[/color] · strike to learn, or Inspect." % UITheme.hex(UITheme.FOCUS))
			lines.append(_dim("%s damage · %s" % [EnumText.damage_type(readout.damage_type), _public_focus(readout)]))
	_focus_cap(readout, lines)


static func _support_block(readout: ActionReadout, lines: PackedStringArray) -> void:
	var good := ActionReadout.GOOD
	for row in readout.targets:
		if row.heal[good] > 0:
			lines.append("[color=%s]Heals %s %d[/color]%s" % [UITheme.hex(UITheme.HEART), row.name, row.heal[good],
				_dim(" (Good timing)") if readout.command_type != Enums.ActionCommandType.NONE else ""])
	var focus := readout.focus_timing[good]
	if focus > 0:
		lines.append("[color=%s]+%d Focus[/color]" % [UITheme.hex(UITheme.FOCUS), focus])
	_focus_cap(readout, lines)


static func _row_summary(row: ActionReadout.TargetRow, readout: ActionReadout) -> String:
	var good := ActionReadout.GOOD
	if not row.has_numbers:
		return "[color=%s]affinity unknown[/color]" % UITheme.hex(UITheme.FOCUS)
	var parts := PackedStringArray()
	parts.append("%s damage" % _range(row.damage_min[good], row.damage_max[good]))
	if row.stagger[good] > 0.0:
		parts.append("%d Stagger" % roundi(row.stagger[good]))
	var tags := _affinity_tags(row, readout)
	if not tags.is_empty():
		parts.append(tags)
	var claims := _claims(row)
	if not claims.is_empty():
		parts.append(claims)
	return " · ".join(parts)


static func _affinity_tags(row: ActionReadout.TargetRow, readout: ActionReadout) -> String:
	var tags := PackedStringArray()
	if row.weakness:
		tags.append("[color=%s]Weak to %s[/color]" % [UITheme.hex(UITheme.FOCUS), EnumText.damage_type(readout.damage_type)])
	elif row.resisted:
		tags.append(_dim("Resists %s" % EnumText.damage_type(readout.damage_type)))
	if row.weak_point:
		tags.append("[color=%s]Weak point exposed[/color]" % UITheme.hex(UITheme.FOCUS))
	if row.broken:
		tags.append("[color=%s]Broken ×1.5[/color]" % UITheme.hex(UITheme.STAGGER))
	return " · ".join(tags)


## Break/kill wording; never an unconditional promise without proof at the minimum roll.
static func _claims(row: ActionReadout.TargetRow) -> String:
	var parts := PackedStringArray()
	match row.kill_claim:
		ActionReadout.Claim.ANY_GRADE:
			parts.append("[color=%s]Lethal at any timing[/color]" % UITheme.hex(UITheme.THREAT))
		ActionReadout.Claim.GOOD_OR_BETTER:
			parts.append("[color=%s]Lethal with Good timing or better[/color]" % UITheme.hex(UITheme.THREAT))
		ActionReadout.Claim.PERFECT_ONLY:
			parts.append("Lethal only with Perfect timing")
		ActionReadout.Claim.POSSIBLE:
			parts.append(_dim("Can be lethal on a high roll"))
	match row.break_claim:
		ActionReadout.Claim.ANY_GRADE:
			parts.append("[color=%s]Breaks it at any timing[/color]" % UITheme.hex(UITheme.STAGGER))
		ActionReadout.Claim.GOOD_OR_BETTER:
			parts.append("[color=%s]Breaks it with Good timing or better[/color]" % UITheme.hex(UITheme.STAGGER))
		ActionReadout.Claim.PERFECT_ONLY:
			parts.append("Breaks it only with Perfect timing")
	return " · ".join(parts)


static func _grade_scope(readout: ActionReadout) -> String:
	if readout.command_type == Enums.ActionCommandType.NONE:
		return "No timing command"
	return "Good timing"


## Focus the player can rely on without knowing the affinity (timing and flat effects only).
static func _public_focus(readout: ActionReadout) -> String:
	var good := ActionReadout.GOOD
	var text := "+%d Focus (Good)" % readout.focus_timing[good]
	if readout.command_type == Enums.ActionCommandType.NONE:
		text = "+%d Focus" % readout.focus_timing[good]
	if readout.focus_affinity_unknown:
		text += " + any affinity bonus"
	return text


static func _focus_cap(readout: ActionReadout, lines: PackedStringArray) -> void:
	var good := ActionReadout.GOOD
	var gain := readout.focus_timing[good] + readout.focus_weakness
	if gain > readout.focus_room:
		lines.append(_dim("Focus is near its cap: only %d of +%d fits." % [readout.focus_room, gain]))


static func _details_block(readout: ActionReadout, lines: PackedStringArray) -> void:
	var miss := ActionReadout.MISS
	var good := ActionReadout.GOOD
	var perfect := ActionReadout.PERFECT
	if readout.deals_damage():
		for row in readout.targets:
			var who := "" if readout.targets.size() == 1 else "%s: " % row.name
			if not row.has_numbers:
				lines.append(_dim("%sexact damage, Stagger, weakness Focus, break/kill and the formula stay hidden until you learn its %s affinity." % [
					who, EnumText.damage_type(readout.damage_type)]))
				continue
			lines.append("[color=%s]%sDamage[/color]\nMiss: %s\nGood: %s\nPerfect: %s" % [UITheme.hex(UITheme.DANGER), who,
				_range(row.damage_min[miss], row.damage_max[miss]), _range(row.damage_min[good], row.damage_max[good]),
				_range(row.damage_min[perfect], row.damage_max[perfect])])
			if row.stagger[good] > 0.0:
				lines.append("[color=%s]%sBreak damage[/color]\nMiss: %d\nGood: %d\nPerfect: %d\nRemaining: %d" % [UITheme.hex(UITheme.STAGGER), who,
					roundi(row.stagger[miss]), roundi(row.stagger[good]), roundi(row.stagger[perfect]), roundi(row.stagger_remaining)])
		if not readout.breakdown.is_empty():
			lines.append(_dim("Formula (Good): " + " · ".join(readout.breakdown)))
	if readout.command_type != Enums.ActionCommandType.NONE:
		var focus_line := "[color=%s]Focus gained[/color]\nMiss: +%d\nGood: +%d\nPerfect: +%d" % [UITheme.hex(UITheme.FOCUS), readout.focus_timing[miss], readout.focus_timing[good],
			readout.focus_timing[perfect]]
		if readout.focus_weakness > 0:
			focus_line += " · +%d weakness" % readout.focus_weakness
		lines.append(focus_line)
		var beats := " · %d beats" % readout.beat_count if readout.beat_count > 0 else ""
		lines.append(_dim("%s command\nGood window: %d ms\nPerfect window: %d ms%s" % [EnumText.command_type(readout.command_type),
			roundi(readout.good_window_ms), roundi(readout.perfect_window_ms), beats]))
	if not readout.tags.is_empty():
		lines.append(_dim("Tags: " + ", ".join(readout.tags)))
	if readout.deals_damage():
		lines.append(_dim("Not included: effects triggered by equipment, your familiar or the battlefield."))
	if not readout.details.is_empty() and readout.details.strip_edges() != readout.description.strip_edges():
		lines.append(_dim(readout.details))


static func _range(low: int, high: int) -> String:
	return str(low) if low == high else "%d–%d" % [low, high]


static func _dim(text: String) -> String:
	return "[color=%s]%s[/color]" % [UITheme.hex(UITheme.TEXT_DIM), text]
