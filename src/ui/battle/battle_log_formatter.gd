class_name BattleLogFormatter
extends RefCounted
## Turns BattleEvents into readable log lines, and builds the defeat recap so a player can always
## say what killed them (GDD acceptance "Information test"). Enemy moves use the same knowledge-
## filtered label as the intent rail (BattleKnowledge.action_label): a name only once understood.


static func line(event: BattleEvent, engine: BattleEngine) -> String:
	var subject := _name(engine, event.subject)
	var other := _name(engine, event.other)
	var T := BattleEvent.Type
	match event.type:
		T.ROUND_STARTED:
			return "[color=#d8b45a]— Round %d —[/color]" % int(event.amount)
		T.INTENT_DECLARED:
			var targets := _names(engine, event.uids)
			var channel := " (channel %d)" % int(event.amount) if event.amount > 0 else ""
			return "%s plans [i]%s[/i]%s%s." % [subject, _label(engine, event), " on " + targets if not targets.is_empty() else "",
				channel]
		T.INTENT_CHANGED:
			return "%s re-aims its %s at %s." % [subject, _label(engine, event), _names(engine, event.uids)]
		T.TURN_SKIPPED:
			return "[color=#c9a3ff]%s is Broken and loses its turn.[/color]" % subject
		T.ACTION_STARTED:
			return "%s uses [b]%s[/b]." % [subject, _label(engine, event)]
		T.COMMAND_RESULT:
			return "  %s timing." % EnumText.grade(event.grade)
		T.REACTION_RESULT:
			var result := "succeeds" if event.success else "fails"
			if event.reaction == Enums.ReactionType.NONE:
				return "  %s does not react." % subject
			var auto := " (auto)" if event.has_flag(BattleEvent.FLAG_AUTO) else ""
			return "  %s's %s %s%s." % [subject, EnumText.reaction(event.reaction), result, auto]
		T.DAMAGE:
			var tags := PackedStringArray()
			if event.has_flag(BattleEvent.FLAG_WEAKNESS):
				tags.append("weakness")
			if event.has_flag(BattleEvent.FLAG_RESISTED):
				tags.append("resisted")
			if event.has_flag(BattleEvent.FLAG_WEAK_POINT):
				tags.append("weak point")
			if event.has_flag(BattleEvent.FLAG_BROKEN_BONUS):
				tags.append("broken")
			if event.has_flag(BattleEvent.FLAG_STATUS_TICK):
				tags.append("status")
			var suffix := " (%s)" % ", ".join(tags) if not tags.is_empty() else ""
			return "  %s takes [color=#d65a43]%d[/color] %s damage%s." % [subject, int(event.amount),
				EnumText.damage_type(event.damage_type).to_lower(), suffix]
		T.HEAL:
			return "  %s recovers [color=#7fbf6a]%d[/color] HP." % [subject, int(event.amount)]
		T.FOCUS_CHANGED:
			if event.amount > 0:
				return "  %s +%d Focus (%s)." % [subject, int(event.amount), event.text]
			return ""
		T.STAGGER_DAMAGE:
			return "  %s Stagger -%.0f (%.0f left)." % [subject, event.amount, event.amount2] if event.amount > 0 else ""
		T.BROKEN:
			var interrupted := " Its channel is interrupted!" if event.has_flag(BattleEvent.FLAG_INTERRUPTED) else ""
			return "[color=#c9a3ff][b]%s is BROKEN![/b]%s[/color]" % [subject, interrupted]
		T.RECOVERED:
			return "%s recovers from the break." % subject
		T.WEAK_POINT_EXPOSED:
			return "[color=#e9d58c]%s's weak point is exposed.[/color]" % subject
		T.STATUS_APPLIED:
			var chain := " (chained)" if event.has_flag(BattleEvent.FLAG_CHAIN) else ""
			return "  %s: [color=%s]%s[/color] (%d)%s." % [subject, IconPainter.status_color(event.status).to_html(false),
				EnumText.status(event.status), int(event.amount2), chain]
		T.STATUS_REMOVED:
			return "  %s: %s %s." % [subject, EnumText.status(event.status), event.text]
		T.STATUS_BLOCKED:
			return "  %s: %s." % [subject, event.text]
		T.STATUS_EXTENDED:
			return "  %s: %s extended +%d." % [subject, EnumText.status(event.status), int(event.amount)]
		T.CHANNEL_STARTED:
			return "[color=%s]%s begins channeling %s (releases in %d more of its activations).[/color]" % [UITheme.hex(UITheme.ACCENT),
				subject, _label(engine, event), int(event.amount)]
		T.CHANNEL_CONTINUED:
			return "%s keeps channeling (%d)." % [subject, int(event.amount)]
		T.CHANNEL_INTERRUPTED:
			return "[color=%s]%s's %s is interrupted by %s![/color]" % [UITheme.hex(UITheme.STAGGER), subject, _label(engine, event), other]
		T.INTERCEPTED:
			return "  %s intercepts the attack meant for %s!" % [subject, other]
		T.COVER_STARTED:
			return "  %s covers %s." % [subject, other]
		T.TRIGGER_ACTIVATED:
			return "  [color=#9b978b]%s triggers.[/color]" % event.text
		T.BUFF_APPLIED:
			return "  %s: %s." % [subject, event.text]
		T.UNIT_DEFEATED:
			return "[color=#d65a43]%s falls.[/color]" % subject
		T.PHASE_CHANGED:
			return "[color=#d8b45a][b]%s[/b] — %s[/color]" % [event.text, event.text2]
		T.CONDITION_ADDED:
			return "[color=#e9d58c]Battlefield: %s.[/color]" % event.text
		T.CONDITION_REMOVED:
			return "Battlefield: %s fades." % event.text
		T.DELAYED:
			return "  %s is delayed." % subject
		T.ITEM_USED:
			return "  (%s used)" % event.text
		T.INSPECTED:
			return "  %s studies %s." % [other, subject]
		T.BATTLE_ENDED:
			return "[b]%s[/b]" % EnumText.outcome(int(event.amount))
		T.NOTE:
			return "[color=#9b978b]%s[/color]" % event.text
	return ""


## "What killed me": the hits that took each fallen party member to 0 and how they were met.
static func defeat_recap(history: Array[BattleEvent], engine: BattleEngine) -> String:
	var lines := PackedStringArray()
	for unit in engine.get_state().party(false):
		if unit.is_alive():
			continue
		var last_reaction := ""
		var killing := ""
		for event in history:
			if event.type == BattleEvent.Type.REACTION_RESULT and event.subject == unit.uid:
				last_reaction = "not reacted" if event.reaction == Enums.ReactionType.NONE else \
					"%s %s" % [EnumText.reaction(event.reaction), "succeeded" if event.success else "failed"]
			if event.type == BattleEvent.Type.DAMAGE and event.subject == unit.uid:
				var source := _name(engine, event.other)
				var move := _label(engine, event, event.other) if event.action != null else (EnumText.status(event.status) if event.has_flag(BattleEvent.FLAG_STATUS_TICK) else "an effect")
				killing = "%s's %s for %d (%s)" % [source, move, int(event.amount), last_reaction if not last_reaction.is_empty() else "no reaction possible"]
		lines.append("%s fell to %s." % [unit.display_name, killing if not killing.is_empty() else "unknown causes"])
	return "\n".join(lines)


## The event's action as the player knows it (actor = [param actor_uid], default the subject).
static func _label(engine: BattleEngine, event: BattleEvent, actor_uid: int = -2) -> String:
	if event.action == null:
		return "?"
	return BattleKnowledge.action_label(engine, engine.get_unit(event.subject if actor_uid == -2 else actor_uid), event.action)


static func _name(engine: BattleEngine, uid: int) -> String:
	var unit := engine.get_unit(uid)
	return unit.display_name if unit != null else "the battlefield"


static func _names(engine: BattleEngine, uids: Array[int]) -> String:
	var names := PackedStringArray()
	for uid in uids:
		names.append(_name(engine, uid))
	return ", ".join(names)
