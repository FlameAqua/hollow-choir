class_name BattleMetrics
extends RefCounted
## Per-battle measurements for balance analysis (GDD "Track: round count, damage taken, healing
## used, Focus generated, Stagger events, action usage, enemy action usage, win/loss, status uptime").

var outcome: Enums.BattleOutcome = Enums.BattleOutcome.NONE
var rounds: int = 0
var damage_taken: int = 0
var damage_dealt: int = 0
var healing_done: int = 0
var focus_generated: int = 0
var focus_spent: int = 0
var stagger_breaks: int = 0
## Playtest revision: times a party member was Broken (counted apart from enemy breaks).
var party_breaks: int = 0
var interrupts: int = 0
var weakness_hits: int = 0
var party_defeats: int = 0
var potions_used: int = 0
## action id -> uses (party) / (enemies)
var action_usage: Dictionary[StringName, int] = {}
var enemy_action_usage: Dictionary[StringName, int] = {}
## StatusId -> unit-turns spent with it, split by side; turns = total unit-turns per side.
var party_status_turns: Dictionary[int, int] = {}
var enemy_status_turns: Dictionary[int, int] = {}
var party_turns: int = 0
var enemy_turns: int = 0
## ReactionType -> [attempts, successes]
var reactions: Dictionary[int, Vector2i] = {}
## ExecutionGrade -> count
var grades: Dictionary[int, int] = {}
## trait source name -> activations
var trigger_activations: Dictionary[String, int] = {}


func consume(engine: BattleEngine, events: Array[BattleEvent]) -> void:
	for event in events:
		_consume_one(engine, event)


func _consume_one(engine: BattleEngine, event: BattleEvent) -> void:
	var subject := engine.get_unit(event.subject)
	match event.type:
		BattleEvent.Type.DAMAGE:
			if subject != null and subject.side == Enums.Side.PLAYER:
				damage_taken += int(event.amount)
			elif subject != null:
				damage_dealt += int(event.amount)
				if event.has_flag(BattleEvent.FLAG_WEAKNESS):
					weakness_hits += 1
		BattleEvent.Type.HEAL:
			if subject != null and subject.side == Enums.Side.PLAYER:
				healing_done += int(event.amount)
		BattleEvent.Type.FOCUS_CHANGED:
			if subject != null and subject.side == Enums.Side.PLAYER:
				if event.amount > 0:
					focus_generated += int(event.amount)
				else:
					focus_spent -= int(event.amount)
		BattleEvent.Type.BROKEN:
			if subject != null and subject.side == Enums.Side.PLAYER:
				party_breaks += 1
			else:
				stagger_breaks += 1
		BattleEvent.Type.CHANNEL_INTERRUPTED:
			interrupts += 1
		BattleEvent.Type.ACTION_STARTED:
			if event.action != null and subject != null:
				var usage := enemy_action_usage if subject.is_enemy() else action_usage
				usage[event.action.id] = usage.get(event.action.id, 0) + 1
		BattleEvent.Type.ITEM_USED:
			potions_used += 1
		BattleEvent.Type.UNIT_DEFEATED:
			if subject != null and subject.side == Enums.Side.PLAYER:
				party_defeats += 1
		BattleEvent.Type.REACTION_RESULT:
			var counts: Vector2i = reactions.get(event.reaction, Vector2i.ZERO)
			counts.x += 1
			if event.success:
				counts.y += 1
			reactions[event.reaction] = counts
		BattleEvent.Type.COMMAND_RESULT:
			grades[event.grade] = grades.get(event.grade, 0) + 1
		BattleEvent.Type.TRIGGER_ACTIVATED:
			trigger_activations[event.text] = trigger_activations.get(event.text, 0) + 1
		BattleEvent.Type.TURN_ENDED:
			if subject == null:
				return
			var mask := int(event.amount)
			var bucket := enemy_status_turns if subject.is_enemy() else party_status_turns
			if subject.is_enemy():
				enemy_turns += 1
			else:
				party_turns += 1
			for status in Enums.StatusId.values():
				if status != Enums.StatusId.NONE and (mask & (1 << status)) != 0:
					bucket[status] = bucket.get(status, 0) + 1


func finalize(engine: BattleEngine) -> void:
	outcome = engine.get_outcome()
	rounds = engine.get_state().round


func is_win() -> bool:
	return outcome == Enums.BattleOutcome.VICTORY
