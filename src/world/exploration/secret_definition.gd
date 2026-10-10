class_name SecretDefinition
extends Resource
## One discoverable secret (V0.5C): a SECRET landmark that offers no prompt, map entry or discovery
## until its reveal condition holds, and is then found by a deliberate interaction. Finding it is
## journey state (Reset journey hides it again); its RewardDefinition (source SECRET_FOUND,
## source_id = the landmark id) is claimed once per save. A secret never blocks the main route.

enum Reveal {
	## Always revealed: hidden only by placement (found by walking close; no map hint before).
	ALWAYS = 0,
	## Revealed while the puzzle [member reveal_key] is solved in this journey.
	PUZZLE_SOLVED = 1,
	## Revealed while the world flag [member reveal_key] is set.
	WORLD_FLAG = 2,
}

## The SECRET landmark id (unique in the world).
@export var landmark: StringName = &""
@export var reveal: Reveal = Reveal.ALWAYS
## PUZZLE_SOLVED: a puzzle id; WORLD_FLAG: a WorldDefinition flag; ALWAYS: empty.
@export var reveal_key: StringName = &""
