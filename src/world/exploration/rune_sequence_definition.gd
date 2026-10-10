class_name RuneSequenceDefinition
extends Resource
## The first reusable puzzle grammar (V0.5C, GDD "Pressure / Rune mechanisms"): RUNE landmarks in
## one area are struck in a spatial sequence. Pure rules (ExplorationRules.strike) decide every
## outcome from the saved input; scenes only show it (WorldStateView RUNE_LIT / SOLVED). New
## puzzles are new data: other runes, lengths, repeats and areas, never new code.
##
## Grammar: each strike that matches the next expected rune advances the input; completing the
## [member solution] solves the puzzle (journey state) and claims its PUZZLE_SOLVED rewards, if any,
## in the same write. A wrong strike clears the input with no other penalty; when the wrong rune
## is the solution's first rune it starts a fresh attempt instead. Solved puzzles ignore strikes.

## Stable puzzle id ("listening_rhythm"); saved in the world section and used as reward source_id.
@export var id: StringName = &""
## Public name for readouts ("Listening stones").
@export var display_name: String = ""
## The RUNE landmark ids that belong to this puzzle (all in one area).
@export var runes: Array[StringName] = []
## The rune ids to strike, in order (2-8 strikes; a rune may repeat). Never shown by a readout.
@export var solution: Array[StringName] = []

const MIN_LENGTH := 2
const MAX_LENGTH := 8
