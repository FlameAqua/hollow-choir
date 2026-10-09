class_name WorldWeaponDetails
extends VBoxContainer
## Shared weapon/action definitions presented as separate material cards.
var text := ""

func present(weapon: WeaponDefinition, equipped: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 14)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 18)
	add_child(identity)
	var icon := CombatIcons.mapping("player_actions", weapon.basic_attack.id, "action_slash")
	identity.add_child(CombatIcons.image(icon, 64))
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(name_box)
	name_box.add_child(UITheme.label(weapon.display_name, UITheme.ACCENT, 33))
	var category := "%s · %s" % [Enums.WeaponFamily.keys()[weapon.family].capitalize(), EnumText.damage_type(weapon.damage_type)]
	name_box.add_child(UITheme.label(category, UITheme.INFO, 22))
	if equipped:
		var badge := UITheme.label("Equipped", UITheme.BLOOM, 22)
		identity.add_child(badge)
	add_child(UITheme.label(weapon.description, UITheme.TEXT_DIM, 22, true))
	add_child(HSeparator.new())
	text = category + "\n" + weapon.description
	var actions: Array[ActionDefinition] = [weapon.basic_attack]
	actions.append_array(weapon.techniques)
	for action in actions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		row.add_child(CombatIcons.image(CombatIcons.mapping("player_actions", action.id, "action_item"), 28))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", 4)
		row.add_child(copy)
		copy.add_child(UITheme.label(action.display_name, UITheme.ACCENT, 22))
		copy.add_child(UITheme.label(action.description, UITheme.TEXT, 22, true))
		text += "\n" + action.display_name + " — " + action.description
