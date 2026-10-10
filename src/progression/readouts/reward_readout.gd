class_name RewardReadout
extends RefCounted
## Public facts about one campaign reward (V0.5A): a preview (AVAILABLE or CLAIMED) or the receipt
## of a committed grant (GRANTED). Plain data copied from the approved definitions and the save:
## names, descriptions, icon paths and counts. It never carries enemy, species or research facts,
## and changing it changes nothing else.

enum Status {
	## Not claimed by this save yet; its accomplishment grants it.
	AVAILABLE = 0,
	## Already claimed; repeating the accomplishment (e.g. after Reset journey) grants nothing.
	CLAIMED = 1,
	## Receipt: claimed by the write that just succeeded.
	GRANTED = 2,
}

var claim_id: StringName = &""
## Public reward label ("Patrol salvage").
var label: String = ""
## RewardDefinition.Source and its stable id (an encounter landmark id or a world flag).
var source: int = RewardDefinition.Source.SITE_VICTORY
var source_id: StringName = &""
var status: Status = Status.AVAILABLE
## One entry per item, in authored order:
## {kind: RewardItem.Kind, id: StringName, name: String, description: String, icon_path: String,
##  count: int (authored), added: int (receipt: actually added; 0 in previews),
##  total: int (materials: held after the grant, or now; equipment: 1 when owned),
##  owned: bool (equipment: already owned before this grant, or owned now)}
var items: Array[Dictionary] = []
## Permanent bag slots authored by this reward (receipt: unlocked in the successful write).
var equipment_slots: int = 0


## Default public wording for the eligibility (WorldCopy; presentation may restyle it): a preview
## says whether this save can still receive it; a receipt says what was received.
func status_text() -> String:
	match status:
		Status.CLAIMED:
			return WorldCopy.REWARD_CLAIMED
		Status.GRANTED:
			return WorldCopy.REWARD_RECEIVED % summary() if not summary().is_empty() else WorldCopy.REWARD_CLAIMED
	return WorldCopy.REWARD_AVAILABLE


## What this grant added (receipts) or would add (previews), e.g. "2 Bog Iron, Storm Salt Charm".
## Also includes permanent bag slots. Empty when a receipt added no item or slots.
func summary() -> String:
	var parts := PackedStringArray()
	for item in items:
		var amount: int = item.added if status == Status.GRANTED else item.count
		if amount <= 0:
			continue
		if int(item.kind) == RewardItem.Kind.MATERIAL:
			parts.append("%d %s" % [amount, item.name])
		else:
			parts.append(String(item.name))
	if equipment_slots > 0:
		parts.append("%d equipment slots" % equipment_slots)
	return ", ".join(parts)


func plain_text() -> String:
	var lines := PackedStringArray([label])
	for item in items:
		if int(item.kind) == RewardItem.Kind.MATERIAL:
			lines.append("%s ×%d" % [item.name, item.count])
		else:
			lines.append(String(item.name))
	if equipment_slots > 0:
		lines.append("Equipment slots +%d" % equipment_slots)
	return "\n".join(lines)
