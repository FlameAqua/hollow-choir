class_name ActionOption
extends RefCounted
## One entry in a unit's action menu, with legality and the reason when illegal.

var action: ActionDefinition
## Potion slot for ITEM options, otherwise -1.
var item_slot: int = -1
var legal: bool = true
## Why it cannot be used ("Needs 3 Focus", "Cooldown 1", "Empty"), shown in the menu.
var reason: String = ""
var target_uids: Array[int] = []


func category() -> Enums.ActionCategory:
	return action.category
