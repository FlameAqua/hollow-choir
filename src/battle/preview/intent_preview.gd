class_name IntentPreview
extends RefCounted
## What a declared enemy intent will do, for the intent UI and the party autopilot.
## Damage ranges per target uid for each reaction outcome.

enum Threat { NONE = 0, LIGHT = 1, MODERATE = 2, HEAVY = 3, SEVERE = 4 }

var enemy_uid: int = -1
var action: EnemyActionDefinition
var target_uids: Array[int] = []
var detail_level: Enums.ResearchLevel = Enums.ResearchLevel.UNKNOWN
var allowed: Array[Enums.ReactionType] = []
## Activations until release as declared (EnemyIntent.turns_until_release()).
var turns_until_release: int = 0
## The channel has started: [member turns_until_release] counts down remaining activations.
var channeling: bool = false
var statuses: Array[Enums.StatusId] = []
var unreacted: Dictionary[int, Vector2i] = {}
var braced: Dictionary[int, Vector2i] = {}
var evade_failed: Dictionary[int, Vector2i] = {}
var parry_failed: Dictionary[int, Vector2i] = {}
## Worst case relative to the target's max HP, readable without exact numbers.
var threat: Threat = Threat.NONE
## Unit covering the target (Intercept), or -1.
var covered_by: int = -1
var reasons: PackedStringArray = PackedStringArray()


func max_unreacted() -> int:
	var best := 0
	for value: Vector2i in unreacted.values():
		best = maxi(best, value.y)
	return best
