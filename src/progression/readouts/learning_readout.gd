class_name LearningReadout
extends RefCounted
## One Bestiary Learning of a saved victory (playtest revision): an enemy whose knowledge tier rose,
## with the tier it had before the victory was adopted and the tier it has now. Only real increases
## are reported, only after the write succeeded, and the public name is the one that tier allows.

var enemy_id: StringName = &""
## The enemy's public name (a tier rise always reaches at least OBSERVED, which names it).
var name: String = ""
## The same portrait the Field Guide shows (the first idle frame), or null; its path when it is a
## file resource ("" for an embedded frame).
var icon: Texture2D
var icon_path: String = ""
## Enums.ResearchLevel before and after, with their public words.
var previous_tier: int = Enums.ResearchLevel.UNKNOWN
var new_tier: int = Enums.ResearchLevel.UNKNOWN
var previous_tier_name: String = ""
var new_tier_name: String = ""


static func make(enemy: EnemyDefinition, enemy_id_value: StringName, before: int, after: int) -> LearningReadout:
	var result := LearningReadout.new()
	result.enemy_id = enemy_id_value
	result.previous_tier = before
	result.new_tier = after
	result.previous_tier_name = EnumText.research_level(before as Enums.ResearchLevel)
	result.new_tier_name = EnumText.research_level(after as Enums.ResearchLevel)
	if enemy != null:
		result.name = enemy.display_name
		if enemy.sprite_frames != null and enemy.sprite_frames.has_animation(&"idle") \
				and enemy.sprite_frames.get_frame_count(&"idle") > 0:
			result.icon = enemy.sprite_frames.get_frame_texture(&"idle", 0)
			result.icon_path = result.icon.resource_path if result.icon != null else ""
	return result


func plain_text() -> String:
	return "%s: %s → %s" % [name, previous_tier_name, new_tier_name]
