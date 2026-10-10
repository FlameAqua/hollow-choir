class_name ExplorationResult
extends RefCounted
## Outcome of one V0.5C field interaction: WorldSession.gather(), find_secret() and strike_rune()
## record it in WorldSession.last_exploration. A rejected or failed interaction changed nothing:
## no world state, claim, material, equipment or save write. Reward receipts are in
## WorldSession.last_receipts (and EventBus.rewards_granted) only after the write succeeded.

enum Command { GATHER = 0, SEARCH = 1, STRIKE = 2 }

enum Reason {
	OK = 0,
	## Not a gathering node, secret or rune with an approved definition in this world.
	UNKNOWN_FEATURE = 1,
	## A world encounter entry is pending or in battle.
	ENCOUNTER_PENDING = 2,
	## A secret whose reveal condition does not hold (it offers no interaction yet).
	HIDDEN = 3,
	## Already gathered (once per save), already found in this journey, or the puzzle is solved.
	ALREADY_DONE = 4,
	## Valid, but the save write failed (see error); the live state is unchanged. Retry is safe.
	WRITE_FAILED = 5,
}

## STRIKE only: what the strike did to the puzzle (deterministic from the saved input).
enum Strike {
	NONE = 0,
	## The expected rune: the input grew.
	ADVANCED = 1,
	## A wrong rune: the input was cleared (or restarted, when it was the first rune).
	MISTAKE = 2,
	## The last expected rune: the puzzle is solved and its rewards were claimed in the same write.
	SOLVED = 3,
}

var command: Command = Command.GATHER
var reason: Reason = Reason.OK
## OK; ERR_INVALID_PARAMETER (UNKNOWN_FEATURE); ERR_UNAVAILABLE (ENCOUNTER_PENDING, HIDDEN);
## ERR_ALREADY_EXISTS (ALREADY_DONE); the writer's error for WRITE_FAILED.
var error: Error = OK
var landmark_id: StringName = &""
## STRIKE: the rune's puzzle, the outcome, the runes entered after it and the solution length.
var puzzle_id: StringName = &""
var strike: Strike = Strike.NONE
var progress: int = 0
var length: int = 0
## Secrets newly revealed by this write (a solved puzzle can reveal one).
var revealed: Array[StringName] = []
## True when the write claimed at least one reward (false when, e.g., a secret is found again after
## Reset journey: its reward stays claimed).
var rewarded := false


static func make(p_command: Command, p_landmark_id: StringName) -> ExplorationResult:
	var result := ExplorationResult.new()
	result.command = p_command
	result.landmark_id = p_landmark_id
	return result


func ok() -> bool:
	return reason == Reason.OK


static func error_for(value: Reason) -> Error:
	match value:
		Reason.OK:
			return OK
		Reason.ENCOUNTER_PENDING, Reason.HIDDEN:
			return ERR_UNAVAILABLE
		Reason.ALREADY_DONE:
			return ERR_ALREADY_EXISTS
		Reason.WRITE_FAILED:
			return FAILED
	return ERR_INVALID_PARAMETER
