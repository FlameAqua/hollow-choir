class_name ActionChoice
extends RefCounted
## The player's (or autopilot's) answer to an ActionSelectRequest.

var unit_uid: int = -1
var action: ActionDefinition
## Required for single-target rules; ignored for area / self actions.
var target_uid: int = -1
## Potion slot when using an item, otherwise -1.
var item_slot: int = -1


static func make(p_unit_uid: int, p_action: ActionDefinition, p_target_uid: int = -1,
		p_item_slot: int = -1) -> ActionChoice:
	var choice := ActionChoice.new()
	choice.unit_uid = p_unit_uid
	choice.action = p_action
	choice.target_uid = p_target_uid
	choice.item_slot = p_item_slot
	return choice


static func from_option(p_unit_uid: int, option: ActionOption, p_target_uid: int = -1) -> ActionChoice:
	return make(p_unit_uid, option.action, p_target_uid, option.item_slot)
