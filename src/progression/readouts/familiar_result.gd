class_name FamiliarResult
extends RefCounted
## Outcome of one familiar command (playtest revision): WorldSession.choose_familiar() and
## choose_familiar_passive() record it in WorldSession.last_familiar. A rejected, failed or no-op
## command changed nothing: no loadout, no save write, no event.

enum Command { CHOOSE_FAMILIAR = 0, CHOOSE_PASSIVE = 1 }

enum Reason {
	OK = 0,
	## A world encounter entry is pending or in battle; its captured loadout is final.
	ENCOUNTER_PENDING = 1,
	## Not an approved familiar (or, for a passive command, no familiar travels with the party).
	UNKNOWN_FAMILIAR = 2,
	## An approved familiar this save does not own.
	NOT_OWNED = 3,
	## Not one of the travelling familiar's authored passive choices.
	UNKNOWN_PASSIVE = 4,
	## Valid, but the save write failed (see error); the live state is unchanged. Retry is safe.
	WRITE_FAILED = 5,
}

var command: Command = Command.CHOOSE_FAMILIAR
var reason: Reason = Reason.OK
## OK; ERR_UNAVAILABLE (ENCOUNTER_PENDING); ERR_INVALID_PARAMETER (other rejections); the writer's
## error for WRITE_FAILED.
var error: Error = OK
## Public wording for [member reason] (WorldCopy when the Director adds the line).
var reason_text: String = ""
## The familiar and passive in effect after a successful command (the requested ones otherwise).
var familiar_id: StringName = &""
var passive_id: StringName = &""
## What travelled, and which passive was in effect, before the command.
var previous_familiar_id: StringName = &""
var previous_passive_id: StringName = &""
## True when a successful command changed the save (re-choosing the same is a no-op).
var changed := false


static func make(p_command: Command) -> FamiliarResult:
	var result := FamiliarResult.new()
	result.command = p_command
	return result


func ok() -> bool:
	return reason == Reason.OK


func text() -> String:
	return reason_text


## The stable feedback name of a changed command (&"equip"), or &"" when nothing changed.
func operation() -> StringName:
	return &"equip" if ok() and changed else &""


static func error_for(value: Reason) -> Error:
	match value:
		Reason.OK:
			return OK
		Reason.ENCOUNTER_PENDING:
			return ERR_UNAVAILABLE
		Reason.WRITE_FAILED:
			return FAILED
	return ERR_INVALID_PARAMETER
