class_name UnitInspectionCard
extends VBoxContainer
## One reusable structured body for allies and enemies; no combat queries in this renderer.
var readout: UnitReadout

func show_readout(value: UnitReadout, expanded: bool) -> void:
	readout = value
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var accent := UITheme.DANGER if value.enemy else UITheme.HEART
	add_child(UITheme.label(value.title, accent, UITheme.body_size(), true))
	if not value.alive:
		add_child(UITheme.label("Defeated", UITheme.TEXT_DIM))
		return
	if expanded:
		var identity := GridContainer.new()
		identity.columns = 2 if UITheme.text_scale() < 1.5 else 1
		add_child(identity)
		_field("Type", value.role, UITheme.INFO, "", identity)
		if not value.knowledge.is_empty():
			_field("Knowledge", value.knowledge, UITheme.ACCENT, "action_inspect", identity)
	var resources := GridContainer.new()
	resources.columns = 2
	add_child(resources)
	_field("Health", "%d / %d" % [value.hp, value.max_hp], accent, "heart", resources)
	_field("Break remaining" if value.enemy else "Focus", "Broken" if value.broken else "%d / %d" % [value.resource, value.max_resource],
		UITheme.STAGGER if value.enemy else UITheme.FOCUS, "stagger" if value.enemy else "focus", resources)
	if expanded and not value.weak_point.is_empty():
		_field("Weak point", value.weak_point + (" · Exposed" if value.exposed else " · Covered"), UITheme.ACCENT)
	if expanded and not value.affinities.is_empty():
		add_child(UITheme.label("Damage affinities", UITheme.ACCENT))
		for category in ["Weakness", "Resistance", "Normal damage", "Unknown"]:
			var entries := value.affinities.filter(func(entry: Dictionary) -> bool: return entry.category == category)
			if entries.is_empty():
				continue
			var color := UITheme.FOCUS if category == "Weakness" else UITheme.STAGGER if category == "Resistance" else UITheme.TEXT_DIM
			add_child(UITheme.label(category, color))
			var row := HFlowContainer.new()
			add_child(row)
			for entry in entries:
				var cell := HBoxContainer.new()
				cell.tooltip_text = EnumText.damage_type(entry.type) + "\n" + category
				row.add_child(cell)
				cell.add_child(CombatIcons.image(_affinity_icon(entry.type), 26))
				cell.add_child(UITheme.label(EnumText.damage_type(entry.type), color))
			var explanation := "No damage bonus or reduction." if category == "Normal damage" else "Strike with this type to learn, or Inspect." if category == "Unknown" else "Takes increased damage from these types." if category == "Weakness" else "Takes reduced damage from these types."
			add_child(UITheme.label(explanation, UITheme.TEXT_FAINT, -1, true))
	for effect in value.effects:
		_field(effect.name, effect.value, UITheme.INFO, effect.icon)
		if expanded and not effect.text.is_empty():
			add_child(UITheme.label(effect.text, UITheme.TEXT_DIM, -1, true))
	for note in value.notes:
		add_child(UITheme.label(note, UITheme.TEXT_DIM, -1, true))
	if expanded and value.intent != null:
		add_child(UITheme.label("Declared move", UITheme.DANGER))
		var card := PreviewPanel.new()
		add_child(card)
		card.show_intent(value.intent)
		card.custom_minimum_size.y = PreviewPanel.intent_height(value.intent)
		if not value.intent.telegraph.is_empty():
			add_child(UITheme.label(value.intent.telegraph, UITheme.TEXT_DIM, -1, true))
		if not value.intent.telegraph_detail.is_empty():
			add_child(UITheme.label(value.intent.telegraph_detail, UITheme.INFO, -1, true))
	# Children pass pointer events to the single inspector; there is never a second tooltip.
	mouse_filter = Control.MOUSE_FILTER_PASS

func _field(label: String, value: String, color: Color, icon: String = "", host: Container = null) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.tooltip_text = label + "\n" + value
	(host if host != null else self).add_child(row)
	row.add_child(UITheme.label(label, UITheme.TEXT_DIM, -1, true))
	var content := HBoxContainer.new()
	row.add_child(content)
	if not icon.is_empty():
		var symbol := CombatIcons.image(icon, 26)
		if icon in ["heart", "stagger", "focus"]:
			symbol.modulate = color
		content.add_child(symbol)
	var text := UITheme.label(value, color, -1, true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text)

static func _affinity_icon(type: Enums.DamageType) -> String:
	match type:
		Enums.DamageType.BLUNT: return "action_blunt"
		Enums.DamageType.PIERCE: return "action_pierce"
		Enums.DamageType.FIRE: return "action_fire"
		Enums.DamageType.STORM: return "action_storm"
	return "action_slash"
