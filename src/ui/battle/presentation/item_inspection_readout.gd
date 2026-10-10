class_name ItemInspectionReadout
extends RefCounted
## Public item/character facts for the shared inspector. No commands or eligibility rules.

var title := ""
var category := ""
var description := ""
var icon_path := ""
var facts := PackedStringArray()
var details := PackedStringArray()


static func from_item(item: Dictionary, ingredient: bool = false) -> ItemInspectionReadout:
	var result := ItemInspectionReadout.new()
	result.title = String(item.name)
	result.description = String(item.description)
	result.icon_path = String(item.get("icon_path", ""))
	result.category = "Ingredient" if ingredient else String(item.get("slot_label", item.get("category", "Equipment")))
	if ingredient:
		result.facts.append("Held  ×%d" % item.get("count", 0))
		result.details.append(WorldCopy.MATERIALS_NOTE)
	else:
		result.facts.append("%s · %s" % [item.get("rarity", ""), "Equipped" if item.get("equipped", false) else "Owned"])
		for trait_info: Dictionary in item.get("traits", []):
			result.facts.append("%s\n%s" % [trait_info.name, trait_info.description])
		for grant: Dictionary in item.get("grants", []):
			result.details.append("%s\n%s" % [grant.name, grant.description])
		if item.has("mastery") and item.get("slot", -1) == Enums.EquipSlot.WEAPON:
			result.details.append("Weapon mastery  %d" % item.mastery)
		if not String(item.get("details", "")).is_empty():
			result.details.append(String(item.details))
		if not item.get("resonance", PackedStringArray()).is_empty():
			result.details.append("Resonance  " + " · ".join(item.resonance))
		result.details.append("Change gear outside an encounter.")
	return result


func describe(expanded: bool) -> String:
	var lines := PackedStringArray()
	var icon := "[img=32x32]%s[/img]  " % icon_path if not icon_path.is_empty() else ""
	lines.append("%s[color=%s][b]%s[/b][/color]\n[color=%s]%s[/color]" % [icon, UITheme.hex(UITheme.ACCENT), title, UITheme.hex(UITheme.INFO), category])
	if not facts.is_empty():
		lines.append("\n".join(facts))
	if not description.is_empty():
		lines.append(description)
	if expanded:
		lines.append_array(details)
	return "\n\n".join(lines)
