class_name ReactionRequest
extends BattleRequest
## REACTION_WINDOW: an enemy action is about to hit the party. One reaction applies to every
## target of the action (DECISION_LOG D-008). Answer with BattleEngine.submit_reaction().

var attacker_uid: int = -1
var target_uids: Array[int] = []
var action: EnemyActionDefinition
var spec: ReactionSpec


func _init() -> void:
	kind = Kind.REACTION
