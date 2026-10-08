class_name RuleNotes
extends RefCounted
## Plain-language rule facts derived from the same data the engine runs, so an explanation cannot
## drift from its rule. Deliberately narrow: it recognises the few trait shapes the slice uses
## (reaction-triggered statuses, status interactions, effect qualifiers) and otherwise falls back to
## authored descriptions. It is not a general expression system (M1.1 data contract).

enum Qualifier { ALWAYS = 0, CONDITIONAL = 1, CHANCE = 2 }

## Public support facts. Amounts are only claimed for unconditional, flat data; the authored
## explanation remains authoritative for complex effects. No combat simulation occurs here.
class SupportNote:
	extends RefCounted
	var icon: String = "action_item"
	var label: String = ""
	var recipient: String = "target"
	var explanation: String = ""
	var color: Color = UITheme.INFO

static func support_effects(action: ActionDefinition) -> Array[SupportNote]:
	var notes: Array[SupportNote] = []
	for effect in action.effects:
		var note := SupportNote.new()
		note.recipient = recipient_text(effect.target)
		match effect.type:
			Enums.EffectType.GAIN_FOCUS, Enums.EffectType.LOSE_FOCUS:
				note.icon = "focus"
				note.color = UITheme.FOCUS
				var sign_text := "+" if effect.type == Enums.EffectType.GAIN_FOCUS else "−"
				note.label = sign_text + str(roundi(effect.amount)) + " Focus" if effect.scaling == Enums.AmountScaling.FLAT else "Focus change"
				note.explanation = "Limited by the recipient's current Focus and maximum."
			Enums.EffectType.GRANT_BUFF:
				if effect.buff == null:
					continue
				note.icon = CombatIcons.mapping("buffs", effect.buff.id, "action_guard")
				note.label = effect.buff.display_name
				note.explanation = effect.buff.description
			Enums.EffectType.INTERCEPT:
				note.icon = CombatIcons.mapping("player_actions", action.id, "action_guard")
				note.label = "Cover ally"
				note.explanation = "Single-target attacks on this ally hit the user instead, until the user's next turn."
			Enums.EffectType.CLEANSE:
				note.label = "Cleanse statuses"
			Enums.EffectType.EXPOSE_WEAK_POINT:
				note.icon = "weak_point"
				note.label = "Expose weak point"
			Enums.EffectType.DELAY_TURN:
				note.label = "Delay activation"
			_:
				continue
		if not effect.conditions.is_empty() or effect.chance < 1.0:
			note.label = "May: " + note.label
			note.explanation += " Conditional effect." if not effect.conditions.is_empty() else " %d%% chance." % roundi(effect.chance * 100)
		notes.append(note)
	return notes

const GERUNDS := {
	Enums.ReactionType.BRACE: "Bracing",
	Enums.ReactionType.EVADE: "Evading",
	Enums.ReactionType.PARRY: "Parrying",
}


## One status an action can apply, with the honest qualifier ("may apply" when gated).
class StatusNote:
	extends RefCounted
	var status: Enums.StatusId = Enums.StatusId.NONE
	var qualifier: Qualifier = Qualifier.ALWAYS
	var chance: float = 1.0
	## Who receives it, relative to the action (TARGET, OWNER…).
	var recipient: Enums.EffectTarget = Enums.EffectTarget.TARGET

	func text() -> String:
		var name := EnumText.status(status)
		var whom := "" if recipient == Enums.EffectTarget.TARGET else " (%s)" % RuleNotes.recipient_text(recipient)
		match qualifier:
			Qualifier.CONDITIONAL:
				return "May apply %s%s (conditional)" % [name, whom]
			Qualifier.CHANCE:
				return "Applies %s%s · %d%% chance" % [name, whom, roundi(chance * 100.0)]
		return "Applies %s%s" % [name, whom]


## Statuses an action's own effects can apply. Unconditional ones say "Applies"; gated or random
## ones never claim a guarantee. Triggered effects from traits are not listed here.
static func applied_statuses(action: ActionDefinition) -> Array[StatusNote]:
	var notes: Array[StatusNote] = []
	if action == null:
		return notes
	for effect in action.effects:
		if effect == null or effect.type != Enums.EffectType.APPLY_STATUS:
			continue
		var note := StatusNote.new()
		note.status = effect.status
		note.recipient = effect.target
		note.chance = effect.chance
		if not effect.conditions.is_empty():
			note.qualifier = Qualifier.CONDITIONAL
		elif effect.chance < 1.0:
			note.qualifier = Qualifier.CHANCE
		notes.append(note)
	return notes


static func recipient_text(target: Enums.EffectTarget) -> String:
	match target:
		Enums.EffectTarget.OWNER, Enums.EffectTarget.ACTOR:
			return "self"
		Enums.EffectTarget.OWNER_ALLIES:
			return "own side"
		Enums.EffectTarget.OWNER_ALLIES_OTHER:
			return "allies"
		Enums.EffectTarget.OWNER_ENEMIES:
			return "every foe"
		Enums.EffectTarget.TARGET_ALLIES_OTHER:
			return "the target's allies"
		Enums.EffectTarget.ALL:
			return "everyone"
	return "target"


## The status on [param unit] that would douse [param status] (Burn on a Wet target), or NONE.
static func dousing_status(library: CombatLibrary, unit: BattleUnit, status: Enums.StatusId) -> Enums.StatusId:
	var definition := library.status_def(status)
	if definition == null or unit == null:
		return Enums.StatusId.NONE
	for blocker in definition.blocked_by:
		if unit.has_status(blocker):
			return blocker
	return Enums.StatusId.NONE


## Per reaction type: consequences added by active battlefield conditions, e.g.
## "Flooded Ground: Evading makes you Wet (2 turns), even on success."
static func reaction_caveats(ctx: BattleContext) -> Dictionary[int, PackedStringArray]:
	var notes: Dictionary[int, PackedStringArray] = {}
	for active in ctx.state.conditions:
		var definition := active.definition
		for trait_def in definition.traits:
			if trait_def == null:
				continue
			for trigger in trait_def.triggers:
				if trigger == null or trigger.trigger != Enums.TriggerType.REACTION:
					continue
				var reaction := Enums.ReactionType.NONE
				var when := ""
				for condition in trigger.conditions:
					if condition == null or condition.negate:
						continue
					match condition.type:
						Enums.ConditionType.REACTION_ATTEMPTED:
							reaction = condition.reaction
							when = ", even on success"
						Enums.ConditionType.REACTION_SUCCEEDED:
							reaction = condition.reaction
							when = " when it succeeds"
						Enums.ConditionType.REACTION_FAILED:
							reaction = condition.reaction
							when = " when it fails"
				if reaction == Enums.ReactionType.NONE:
					continue
				for effect in trigger.effects:
					if effect == null or effect.type != Enums.EffectType.APPLY_STATUS:
						continue
					var turns := effect.duration if effect.duration > 0 else _default_duration(ctx.library, effect.status)
					var whom := "" if effect.target == Enums.EffectTarget.TARGET else " (attacker)"
					var line := "%s: %s%s for %d turns%s." % [definition.display_name, EnumText.status(effect.status), whom, turns, when]
					var list: PackedStringArray = notes.get(int(reaction), PackedStringArray())
					list.append(line)
					notes[int(reaction)] = list
	return notes


## Status interactions in words, from StatusDefinition data ("Wet washes away Burn").
static func status_interactions(library: CombatLibrary) -> PackedStringArray:
	var lines := PackedStringArray()
	var ids := library.statuses.keys()
	ids.sort()
	for id: int in ids:
		var definition: StatusDefinition = library.statuses[id]
		var name := EnumText.status(definition.status)
		for removed in definition.removes_on_apply:
			lines.append("%s washes away %s." % [name, EnumText.status(removed)])
		for blocker in definition.blocked_by:
			lines.append("%s on a %s target is doused, and the %s is used up." % [name, EnumText.status(blocker),
				EnumText.status(blocker)])
	return lines


## The short consequence for the condition ribbon.
static func condition_summary(definition: BattlefieldConditionDefinition) -> String:
	if not definition.summary.is_empty():
		return definition.summary
	return definition.description


## The full rule for the details view: description, nuance and the status rules it touches.
static func condition_rule(library: CombatLibrary, definition: BattlefieldConditionDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	var severity := "Major" if definition.severity == Enums.ConditionSeverity.MAJOR else "Minor"
	lines.append("%s (%s condition)" % [definition.display_name, severity])
	lines.append(definition.description)
	if not definition.details.is_empty():
		lines.append(definition.details)
	return lines


static func _default_duration(library: CombatLibrary, status: Enums.StatusId) -> int:
	var definition := library.status_def(status)
	return definition.default_duration if definition != null else 1
