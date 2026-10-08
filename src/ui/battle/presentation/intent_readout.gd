class_name IntentReadout
extends RefCounted
## Knowledge-filtered view of one enemy's declared intent (M1.1 F1). The intent rail, unit details,
## the reaction header and the log all use it, so a move reads the same everywhere: its name once
## the enemy is UNDERSTOOD (or Inspected), otherwise its category. Actor, targets, threat word,
## reactions, status payload and channel countdown are always public.

const THREAT_WORDS := ["", "Light", "Moderate", "Heavy", "Severe"]
const REACTIONS: Array[Enums.ReactionType] = [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE,
	Enums.ReactionType.PARRY]

var enemy_uid: int = -1
var enemy_name: String = ""
var action: EnemyActionDefinition
var label: String = ""
## The move's name is known (UNDERSTOOD or Inspect).
var named: bool = false
var category: Enums.IntentCategory = Enums.IntentCategory.WAIT
var category_text: String = ""
## Always-visible flavour ("Rears up for a crushing slam. Cannot be Parried.").
var telegraph: String = ""
## Revealed with the name.
var telegraph_detail: String = ""
var target_uids: Array[int] = []
## Stable public identities for cards; captured alongside the displayed intent.
var target_names: Dictionary[int, String] = {}
var target_text: String = ""
## Party unit intercepting the attack (it is already the target in [member target_uids]), or -1.
var covered_by: int = -1
var targets_party: bool = false
## A real-time reaction window will open (the move hits the party and allows at least one reaction).
var reactable: bool = false
## Per reaction in Brace / Evade / Parry order.
var allowed: Array[bool] = [false, false, false]
var statuses: Array[RuleNotes.StatusNote] = []
var threat: IntentPreview.Threat = IntentPreview.Threat.NONE
var threat_word: String = ""
var is_channel: bool = false
var channeling: bool = false
## This enemy's activations until the move releases, counting the coming one (1 = this activation).
var activations_to_release: int = 0
var interruptible: bool = true
## Exact incoming damage per target; only when [member named].
var damage_known: bool = false
var unreacted: Dictionary[int, Vector2i] = {}
var braced: Dictionary[int, Vector2i] = {}
var evade_failed: Dictionary[int, Vector2i] = {}
var parry_failed: Dictionary[int, Vector2i] = {}
## AI scoring reasons: Lab debug only, never gated by research.
var debug_reasons: PackedStringArray = PackedStringArray()


static func build(engine: BattleEngine, preview: IntentPreview, show_debug: bool = false) -> IntentReadout:
	var readout := IntentReadout.new()
	var enemy := engine.get_unit(preview.enemy_uid)
	var action := preview.action
	readout.enemy_uid = preview.enemy_uid
	readout.enemy_name = enemy.display_name if enemy != null else "?"
	readout.action = action
	readout.named = BattleKnowledge.knows_moves(engine, enemy)
	readout.label = BattleKnowledge.action_label(engine, enemy, action)
	readout.category = action.intent_category
	readout.category_text = EnumText.intent_category(action.intent_category)
	readout.telegraph = action.telegraph_text
	if readout.named:
		readout.telegraph_detail = action.telegraph_detail
	readout.target_uids = preview.target_uids.duplicate()
	for uid in readout.target_uids:
		readout.target_names[uid] = BattleKnowledge.unit_name(engine, uid)
	readout.covered_by = preview.covered_by
	readout.targets_party = action.targets_enemies()
	readout.reactable = readout.targets_party and action.is_reactable()
	for index in REACTIONS.size():
		readout.allowed[index] = preview.allowed.has(REACTIONS[index])
	readout.statuses = RuleNotes.applied_statuses(action)
	readout.threat = preview.threat
	readout.threat_word = THREAT_WORDS[preview.threat]
	readout.channeling = preview.channeling
	readout.is_channel = preview.channeling or preview.turns_until_release > 0
	if readout.is_channel:
		readout.activations_to_release = preview.turns_until_release if preview.channeling else preview.turns_until_release + 1
	readout.interruptible = action.interruptible
	readout.target_text = _target_text(engine, readout, action)
	if readout.named:
		readout.damage_known = not preview.unreacted.is_empty()
		readout.unreacted = preview.unreacted.duplicate()
		readout.braced = preview.braced.duplicate()
		readout.evade_failed = preview.evade_failed.duplicate()
		readout.parry_failed = preview.parry_failed.duplicate()
	if show_debug:
		readout.debug_reasons = preview.reasons
	return readout


## "Releases this activation" / "3 activations until release" (never rounds).
func channel_text() -> String:
	if not is_channel:
		return ""
	if activations_to_release <= 1:
		return "Releases this activation"
	return "%d activations until release" % activations_to_release


func interrupt_text() -> String:
	return "Break to interrupt" if interruptible else "Cannot be interrupted"


## "Brace · Evade · Parry" with unavailable ones marked in words (BBCode strike for emphasis).
func reactions_text(bbcode: bool = true) -> String:
	if not reactable:
		return "No reaction needed" if not targets_party else "Cannot be reacted to"
	var parts := PackedStringArray()
	for index in REACTIONS.size():
		var name := EnumText.reaction(REACTIONS[index])
		if allowed[index]:
			parts.append(name)
		elif bbcode:
			parts.append("[s][color=%s]%s[/color][/s] [color=%s](no)[/color]" % [UITheme.hex(UITheme.TEXT_FAINT), name,
				UITheme.hex(UITheme.DANGER)])
		else:
			parts.append("no %s" % name)
	return " · ".join(parts)


## "applies Wet · may apply Burn" (empty when the move applies no status).
func status_text() -> String:
	var always := PackedStringArray()
	var maybe := PackedStringArray()
	for note in statuses:
		if note.qualifier == RuleNotes.Qualifier.ALWAYS:
			always.append(EnumText.status(note.status))
		else:
			maybe.append(EnumText.status(note.status))
	var parts := PackedStringArray()
	if not always.is_empty():
		parts.append("applies " + ", ".join(always))
	if not maybe.is_empty():
		parts.append("may apply " + ", ".join(maybe))
	return " · ".join(parts)


## Worst case vs one target as text, or "" when not known.
func damage_text(uid: int) -> String:
	if not damage_known or not unreacted.has(uid):
		return ""
	var raw: Vector2i = unreacted[uid]
	return "%d–%d" % [raw.x, raw.y]


static func _target_text(engine: BattleEngine, readout: IntentReadout, action: EnemyActionDefinition) -> String:
	match action.target_rule:
		Enums.TargetRule.NONE:
			return "the battlefield"
		Enums.TargetRule.SELF:
			return "itself"
		Enums.TargetRule.ALL_ENEMIES:
			return "your whole party"
		Enums.TargetRule.ALL_ALLIES:
			return "all of its side"
	var names := PackedStringArray()
	for uid in readout.target_uids:
		names.append(BattleKnowledge.unit_name(engine, uid))
	var text := ", ".join(names)
	if readout.covered_by >= 0:
		text += " (intercepting)"
	return text
