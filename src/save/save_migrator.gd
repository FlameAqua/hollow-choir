class_name SaveMigrator
extends RefCounted
## Upgrades save dictionaries one version at a time (DECISION_LOG D-011).
##
## To change the save format: bump CURRENT_VERSION, write `_to_N(data)` turning a version N-1
## payload into version N, and add `N: return _to_N(data)` to _step(). Never edit a released step.

const CURRENT_VERSION := 1


## Returns the migrated payload, or an empty dictionary if the save cannot be used.
static func migrate(envelope: Dictionary) -> Dictionary:
	var version := int(envelope.get("save_version", 0))
	if version <= 0:
		push_error("SaveMigrator: missing save_version")
		return {}
	if version > CURRENT_VERSION:
		push_error("SaveMigrator: save version %d is newer than this build (%d)" % [version, CURRENT_VERSION])
		return {}
	var data: Dictionary = envelope.get("data", {}).duplicate(true)
	while version < CURRENT_VERSION:
		version += 1
		data = _step(version, data)
		if data.is_empty():
			push_error("SaveMigrator: migration to version %d failed" % version)
			return {}
	return data


static func _step(target_version: int, _data: Dictionary) -> Dictionary:
	match target_version:
		# 2: return _to_2(_data)
		_:
			return {}


static func wrap(data: Dictionary, slot: int) -> Dictionary:
	return {
		"save_version": CURRENT_VERSION,
		"game_version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"slot": slot,
		"data": data,
	}
