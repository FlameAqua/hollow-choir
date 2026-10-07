extends Node
## Read-only access to every content definition (DECISION_LOG D-012).

var registry: DefinitionRegistry
var library: CombatLibrary
## Validation problems found at startup (also printed as errors).
var problems: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


func reload() -> void:
	registry = DefinitionRegistry.load_default()
	problems = registry.validate()
	for problem in problems:
		push_error("Content: %s" % problem)
	library = registry.make_library()


func difficulty(tier: Enums.TacticalDifficulty) -> TacticalDifficultyProfile:
	return registry.difficulty(tier)


func assist(kind: Enums.ExecutionAssist) -> ExecutionAssistProfile:
	return registry.assist(kind)
