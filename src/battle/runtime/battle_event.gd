class_name BattleEvent
extends RefCounted
## One thing that happened, in order. Presentation animates these, metrics count them and the
## battle log prints them. Nothing ever reads engine state back out of an event.
##
## Field usage per type is documented next to each value. subject/other are unit ids (-1 = none).

enum Type {
	BATTLE_STARTED = 0,
	ROUND_STARTED = 1,        ## amount = round
	TURN_ORDER = 2,           ## uids = order this round
	INTENT_DECLARED = 3,      ## subject = enemy, uids = targets, action
	INTENT_CHANGED = 4,       ## subject = enemy, uids = new targets, action, text = why
	TURN_STARTED = 5,         ## subject
	TURN_SKIPPED = 6,         ## subject (Broken)
	ACTION_STARTED = 7,       ## subject = actor, uids = targets, action
	COMMAND_RESULT = 8,       ## subject = actor, grade, action
	REACTION_RESULT = 9,      ## subject = defender, other = attacker, reaction, success, flags AUTO
	DAMAGE = 10,              ## subject = damaged, other = source, amount, damage_type, flags, action
	HEAL = 11,                ## subject = healed, other = healer, amount, amount2 = overheal
	FOCUS_CHANGED = 12,       ## subject, amount = delta, amount2 = new total, text = reason
	STAGGER_DAMAGE = 13,      ## subject = enemy, other = source, amount, amount2 = remaining
	BROKEN = 14,              ## subject, other = breaker, flags INTERRUPTED
	RECOVERED = 15,           ## subject
	WEAK_POINT_EXPOSED = 16,  ## subject, other = cause
	WEAK_POINT_CLOSED = 17,   ## subject
	STATUS_APPLIED = 18,      ## subject = bearer, other = source, status, amount = stacks, amount2 = duration, flags CHAIN/REFRESHED
	STATUS_REMOVED = 19,      ## subject, status, text = reason
	STATUS_BLOCKED = 20,      ## subject, status, text = reason (doused / immune)
	STATUS_EXTENDED = 21,     ## subject, status, amount = added
	CHANNEL_STARTED = 22,     ## subject, action, amount = activations until release
	CHANNEL_CONTINUED = 23,   ## subject, action, amount = activations left
	CHANNEL_INTERRUPTED = 24, ## subject, other = interrupter, action
	INTERCEPTED = 25,         ## subject = interceptor, other = protected unit
	TRIGGER_ACTIVATED = 26,   ## subject = owner (-1 battlefield), text = source name
	BUFF_APPLIED = 27,        ## subject, other = source, text = buff name
	BUFF_EXPIRED = 28,        ## subject, text = buff name
	UNIT_DEFEATED = 29,       ## subject, other = killer, action
	PHASE_CHANGED = 30,       ## subject, text = phase name, text2 = announcement
	CONDITION_ADDED = 31,     ## text = condition name
	CONDITION_REMOVED = 32,   ## text = condition name
	DELAYED = 33,             ## subject
	ITEM_USED = 34,           ## subject, other = target, text = potion name, amount = slot
	RESEARCH = 35,            ## text = enemy id, amount = ResearchSource
	TURN_ENDED = 36,          ## subject, amount = status bitmask at turn end
	ROUND_ENDED = 37,         ## amount = round
	BATTLE_ENDED = 38,        ## amount = Enums.BattleOutcome
	NOTE = 39,                ## text
	COVER_STARTED = 40,       ## subject = interceptor, other = protected unit
	COVER_ENDED = 41,         ## subject = interceptor, other = formerly protected unit
	INSPECTED = 42,           ## subject = inspected enemy, other = inspector
}

const FLAG_WEAKNESS := 1
const FLAG_RESISTED := 2
const FLAG_WEAK_POINT := 4
const FLAG_BROKEN_BONUS := 8
const FLAG_CHAIN := 16
const FLAG_AUTO := 32
const FLAG_STATUS_TICK := 64
const FLAG_REFRESHED := 128
const FLAG_INTERRUPTED := 256
const FLAG_EFFECT := 512

var type: Type = Type.NOTE
var round: int = 0
var subject: int = -1
var other: int = -1
var uids: Array[int] = []
var amount: float = 0.0
var amount2: float = 0.0
var status: Enums.StatusId = Enums.StatusId.NONE
var grade: Enums.ExecutionGrade = Enums.ExecutionGrade.GOOD
var reaction: Enums.ReactionType = Enums.ReactionType.NONE
var success: bool = false
var damage_type: Enums.DamageType = Enums.DamageType.NONE
var flags: int = 0
var action: ActionDefinition
var text: String = ""
var text2: String = ""


func _init(p_type: Type = Type.NOTE, p_subject: int = -1, p_other: int = -1) -> void:
	type = p_type
	subject = p_subject
	other = p_other


func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


func type_name() -> String:
	return Type.keys()[type]
