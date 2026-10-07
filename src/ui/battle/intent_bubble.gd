class_name IntentBubble
extends Control
## The telegraph above an enemy. Always shows the rules the player needs (category, target,
## reaction availability, channel countdown, threat). Exact numbers, the move's name and its
## "why" are unlocked by bestiary research or Inspect — knowledge is progression, rules never hide.

signal hovered(enemy_uid: int)

const SIZE := Vector2(184, 48)
const THREAT_WORDS := ["", "Light", "Moderate", "Heavy", "Severe"]
const THREAT_COLORS := [Color.WHITE, Color(0.8, 0.85, 0.8), Color(0.95, 0.85, 0.45), Color(1.0, 0.55, 0.3), Color(1.0, 0.3, 0.3)]

var enemy_uid: int = -1
var preview: IntentPreview
var target_names: String = ""
var _font: Font


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(enemy_uid))


func show_intent(p_preview: IntentPreview, p_target_names: String) -> void:
	preview = p_preview
	target_names = p_target_names
	visible = preview != null
	queue_redraw()


func _draw() -> void:
	if preview == null:
		return
	var action := preview.action
	var known := preview.detail_level >= Enums.ResearchLevel.UNDERSTOOD
	var box := Rect2(Vector2.ZERO, SIZE)
	var threat_color: Color = THREAT_COLORS[preview.threat]
	draw_rect(box, Color(0.06, 0.06, 0.09, 0.92))
	draw_rect(box, threat_color if preview.threat >= IntentPreview.Threat.HEAVY else UITheme.BORDER, false, 1.5)
	# Pointer toward the enemy below.
	draw_colored_polygon(PackedVector2Array([Vector2(SIZE.x * 0.5 - 6, SIZE.y), Vector2(SIZE.x * 0.5 + 6, SIZE.y),
		Vector2(SIZE.x * 0.5, SIZE.y + 7)]), Color(0.06, 0.06, 0.09, 0.92))
	IconPainter.draw_intent(self, Rect2(5, 5, 22, 22), action.intent_category, threat_color)
	var font_size := UITheme.font_size(0.75)
	var title := action.display_name if known else EnumText.intent_category(action.intent_category)
	draw_string(_font, Vector2(32, 17), title, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 36, font_size, UITheme.TEXT)
	var line2 := ""
	if not target_names.is_empty():
		line2 = "> " + target_names
	draw_string(_font, Vector2(32, 33), line2, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 100, UITheme.font_size(0.68), UITheme.INFO)
	# Damage: exact range when understood, otherwise a threat word.
	var damage_text := ""
	if preview.threat > IntentPreview.Threat.NONE:
		if known:
			var best := Vector2i.ZERO
			for value: Vector2i in preview.unreacted.values():
				if value.y > best.y:
					best = value
			damage_text = "%d-%d" % [best.x, best.y]
		else:
			damage_text = THREAT_WORDS[preview.threat]
	draw_string(_font, Vector2(SIZE.x - 66, 33), damage_text, HORIZONTAL_ALIGNMENT_RIGHT, 62, UITheme.font_size(0.68), threat_color)
	# Reaction availability (always shown when the move targets the party).
	if action.targets_enemies():
		var x := 32.0
		for reaction in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
			IconPainter.draw_reaction(self, Rect2(x, 36, 11, 10), reaction, preview.allowed.has(reaction), _font, UITheme.font_size(0.5))
			x += 14.0
	if preview.turns_until_release > 0:
		IconPainter.draw_hourglass(self, Rect2(SIZE.x - 26, 4, 12, 14), UITheme.ACCENT, _font, preview.turns_until_release)


## Analysis text for tooltips (immediate + unlocked details).
static func describe(p_preview: IntentPreview, battle: BattleEngine, show_reasons: bool) -> String:
	var action := p_preview.action
	var lines := PackedStringArray()
	var known := p_preview.detail_level >= Enums.ResearchLevel.UNDERSTOOD
	lines.append("[b]%s[/b]  (%s)" % [action.display_name if known else "Unknown move", EnumText.intent_category(action.intent_category)])
	lines.append(action.telegraph_text)
	if known and not action.telegraph_detail.is_empty():
		lines.append("[i]%s[/i]" % action.telegraph_detail)
	var reactions := PackedStringArray()
	for reaction in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
		reactions.append("%s %s" % [EnumText.reaction(reaction), "yes" if p_preview.allowed.has(reaction) else "NO"])
	if action.targets_enemies():
		lines.append("Reactions: " + ", ".join(reactions))
	if p_preview.turns_until_release > 0:
		lines.append("Channel: releases in %d of its turns. Break its Stagger to interrupt." % p_preview.turns_until_release)
	for status in p_preview.statuses:
		lines.append("Applies %s" % EnumText.status(status))
	for uid: int in p_preview.unreacted:
		var unit := battle.get_unit(uid)
		var name := unit.display_name if unit != null else "?"
		if known:
			var raw: Vector2i = p_preview.unreacted[uid]
			var brace: Vector2i = p_preview.braced.get(uid, raw)
			var evade: Vector2i = p_preview.evade_failed.get(uid, raw)
			var parry: Vector2i = p_preview.parry_failed.get(uid, raw)
			lines.append("vs %s: %d-%d unreacted · Brace %d-%d · failed Evade %d-%d · failed Parry %d-%d" % [
				name, raw.x, raw.y, brace.x, brace.y, evade.x, evade.y, parry.x, parry.y])
		else:
			lines.append("vs %s: %s threat (Inspect or research for numbers)" % [name, THREAT_WORDS[p_preview.threat]])
	if p_preview.covered_by >= 0:
		lines.append("Intercepted by %s" % battle.get_unit(p_preview.covered_by).display_name)
	if show_reasons and not p_preview.reasons.is_empty():
		lines.append("[color=#c9a3ff]Why: %s[/color]" % "; ".join(p_preview.reasons))
	return "\n".join(lines)
