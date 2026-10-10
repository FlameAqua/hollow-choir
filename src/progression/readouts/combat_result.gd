class_name CombatResult
extends RefCounted
## Outcome of one combat-arrangement command (V0.5 UI): WorldSession.arrange_action(),
## swap_actions() and move_action() record it in WorldSession.last_combat. A rejected or failed
## command changed nothing: no arrangement, no save write, no event.

enum Command { PUT = 0, SWAP = 1, MOVE = 2 }

enum Reason {
	OK = 0,
	## A world encounter entry is pending or in battle; its captured arrangement is final.
	ENCOUNTER_PENDING = 1,
	## Not one of the CombatRules.POSITIONS shown positions.
	INVALID_POSITION = 2,
	## A shown position beyond the unlocked capacity: it accepts and executes nothing.
	LOCKED_POSITION = 3,
	## Not an approved action id.
	UNKNOWN_ACTION = 4,
	## An approved action the current campaign gear does not grant the Hollow.
	NOT_GRANTED = 5,
	## A passive skill (trait): always active, never a combat position or a battle command.
	PASSIVE_SKILL = 6,
	## SWAP / MOVE named a position that holds no action.
	EMPTY_POSITION = 7,
	## Valid, but the save write failed (see error); the live state is unchanged. Retry is safe.
	WRITE_FAILED = 8,
}

var command: Command = Command.PUT
var reason: Reason = Reason.OK
## OK; ERR_UNAVAILABLE (ENCOUNTER_PENDING); ERR_INVALID_PARAMETER (other rejections); the
## writer's error for WRITE_FAILED.
var error: Error = OK
## Public wording for [member reason] (WorldCopy; presentation may restyle it).
var reason_text: String = ""
## PUT / MOVE: the action and its target position. SWAP: the two positions.
var action_id: StringName = &""
var position: int = -1
var other_position: int = -1
## PUT: the action that held the position before (&"" for an empty position); it leaves the
## arrangement unless it was swapped into the placed action's old position.
var previous_id: StringName = &""
## The arranged ids before and after (after == before for a rejection or a no-op).
var before: Array[StringName] = []
var after: Array[StringName] = []
## True when a successful command changed the arrangement (the same arrangement writes nothing).
var changed := false


static func make(p_command: Command) -> CombatResult:
	var result := CombatResult.new()
	result.command = p_command
	return result


func ok() -> bool:
	return reason == Reason.OK


func text() -> String:
	return reason_text


static func reason_text_for(value: Reason) -> String:
	match value:
		Reason.ENCOUNTER_PENDING:
			return WorldCopy.COMBAT_ENCOUNTER_PENDING
		Reason.INVALID_POSITION:
			return WorldCopy.COMBAT_INVALID_POSITION
		Reason.LOCKED_POSITION:
			return WorldCopy.COMBAT_LOCKED_POSITION
		Reason.UNKNOWN_ACTION:
			return WorldCopy.COMBAT_UNKNOWN_ACTION
		Reason.NOT_GRANTED:
			return WorldCopy.COMBAT_NOT_GRANTED
		Reason.PASSIVE_SKILL:
			return WorldCopy.COMBAT_PASSIVE
		Reason.EMPTY_POSITION:
			return WorldCopy.COMBAT_EMPTY_POSITION
		Reason.WRITE_FAILED:
			return WorldCopy.SAVE_FAILED_TITLE
	return ""


static func error_for(value: Reason) -> Error:
	match value:
		Reason.OK:
			return OK
		Reason.ENCOUNTER_PENDING:
			return ERR_UNAVAILABLE
		Reason.WRITE_FAILED:
			return FAILED
	return ERR_INVALID_PARAMETER
