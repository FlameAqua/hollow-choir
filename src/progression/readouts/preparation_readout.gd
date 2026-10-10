class_name PreparationReadout
extends RefCounted
## Campaign equipment (V0.5A; a field command since the V0.5 UI pass): whether commands are
## accepted now, the party's action counts, and one EquipmentSlotReadout per weapon, garb, charm and
## relic slot.

## Kept for older callers: always &"" (equipment needs no station context any more).
var station_id: StringName = &""
## OK when equip/unequip would be accepted now (ENCOUNTER_PENDING otherwise).
var reason: PreparationResult.Reason = PreparationResult.Reason.OK
var reason_text: String = ""
var action_limit: int = PartyLoadout.MAX_ACTIONS
## Actions the Hollow and the companion take into the next battle (0 without a companion): the
## Hollow's arranged actions (CombatRules), the companion's every action.
var protagonist_actions: int = 0
var companion_actions: int = 0
## Every action the Hollow's gear grants, arranged or not (held to action_limit).
var granted_actions: int = 0
## Usable combat positions (CombatRules.capacity); independent of action_limit.
var combat_capacity: int = CombatRules.STARTING_CAPACITY
var slots: Array[EquipmentSlotReadout] = []


func available() -> bool:
	return reason == PreparationResult.Reason.OK


func slot(value: Enums.EquipSlot) -> EquipmentSlotReadout:
	for entry in slots:
		if entry.slot == value:
			return entry
	return null
