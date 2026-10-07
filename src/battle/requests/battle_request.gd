class_name BattleRequest
extends RefCounted
## The engine is waiting for input. Exactly one request is pending at PLAYER_SELECT,
## ACTION_COMMAND or REACTION_WINDOW; it is answered with BattleEngine.submit_*().

enum Kind { ACTION_SELECT = 0, ACTION_COMMAND = 1, REACTION = 2 }

var kind: Kind = Kind.ACTION_SELECT
## Unit being asked (the actor, or the defender for reactions).
var unit_uid: int = -1
