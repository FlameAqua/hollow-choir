class_name ReactionReadout
extends RefCounted
## Content of the reaction dock for one incoming attack (M1.1 F2): three rows in fixed
## Brace / Evade / Parry order with the bound key on the active device, legality, effect and risk.
## Every number comes from the rules (BalanceConfig + modifiers on the actual defender); caveats come
## from active battlefield conditions. Nothing here grades input: ReactionWidget does that.

const REACTIONS: Array[Enums.ReactionType] = [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE,
	Enums.ReactionType.PARRY]
const KEYS := {
	Enums.ReactionType.BRACE: InputBindings.BRACE,
	Enums.ReactionType.EVADE: InputBindings.EVADE,
	Enums.ReactionType.PARRY: InputBindings.PARRY,
}


class Row:
	extends RefCounted
	var reaction: Enums.ReactionType = Enums.ReactionType.NONE
	var name: String = ""
	var key_action: StringName = &""
	var allowed: bool = false
	## Full window width after assist and equipment (ms).
	var window_ms: float = 0.0
	## "Reduce damage by 40%", "Avoid the hit", "Avoid the hit · 16 Stagger to Bogshell · +2 Focus".
	var effect: String = ""
	## "Statuses can still land", "Fails: +15% damage".
	var risk: String = ""
	## Battlefield consequences ("Flooded Ground: Evading makes you Wet (2 turns), even on success.").
	var caveats: PackedStringArray = PackedStringArray()
	## Shown in place of the effect when not allowed.
	var unavailable_text: String = ""

	func key_text() -> String:
		return InputBindings.label(key_action)


var attacker_uid: int = -1
var attacker_name: String = ""
## Knowledge-filtered move label (same as the intent rail).
var label: String = ""
var target_uids: Array[int] = []
var target_text: String = ""
var rows: Array[Row] = []
var statuses: Array[RuleNotes.StatusNote] = []
var auto_brace: bool = false
var pause_before: bool = false
## Assist note: auto-Brace availability, or which manual reactions are required.
var assist_text: String = ""


static func build(engine: BattleEngine, request: ReactionRequest) -> ReactionReadout:
	var readout := ReactionReadout.new()
	var ctx := engine.ctx
	var balance := ctx.balance
	var attacker := engine.get_unit(request.attacker_uid)
	var spec := request.spec
	readout.attacker_uid = request.attacker_uid
	readout.attacker_name = attacker.display_name if attacker != null else "?"
	readout.label = BattleKnowledge.action_label(engine, attacker, request.action)
	readout.target_uids = request.target_uids.duplicate()
	var names := PackedStringArray()
	var defenders: Array[BattleUnit] = []
	for uid in request.target_uids:
		var unit := engine.get_unit(uid)
		if unit != null:
			defenders.append(unit)
			names.append(unit.display_name)
	readout.target_text = ", ".join(names)
	readout.statuses = RuleNotes.applied_statuses(request.action)
	readout.auto_brace = spec.auto_brace
	readout.pause_before = spec.pause_before
	var caveats := RuleNotes.reaction_caveats(ctx)
	for reaction in REACTIONS:
		var row := Row.new()
		row.reaction = reaction
		row.name = EnumText.reaction(reaction)
		row.key_action = KEYS[reaction]
		row.allowed = spec.is_allowed(reaction)
		row.window_ms = spec.window_for(reaction)
		row.caveats = caveats.get(int(reaction), PackedStringArray())
		if not row.allowed:
			row.unavailable_text = "This attack cannot be %s" % _past(reaction)
		match reaction:
			Enums.ReactionType.BRACE:
				row.effect = "%s less damage" % _brace_text(ctx, attacker, defenders, request.action)
				row.risk = "Statuses still land"
			Enums.ReactionType.EVADE:
				row.effect = _negate_text(balance.evade_success_multiplier)
				row.risk = "Fails: +%d%% damage" % roundi((balance.evade_fail_multiplier - 1.0) * 100.0)
			Enums.ReactionType.PARRY:
				row.effect = "%s · %s Stagger · +%d Focus" % [_negate_text(balance.parry_success_multiplier),
					_parry_stagger_text(ctx, attacker, defenders, request.action), balance.parry_focus]
				row.risk = "Fails: +%d%% damage" % roundi((balance.parry_fail_multiplier - 1.0) * 100.0)
		if row.allowed and reaction != Enums.ReactionType.BRACE and not readout.statuses.is_empty() \
				and ReactionRules.blocks_effects(ReactionResult.make(reaction, true)):
			row.effect += " · blocks statuses"
		readout.rows.append(row)
	readout.assist_text = _assist_text(readout)
	return readout


## Rows straight from a ReactionSpec, without rule text (widget tests, tools).
static func for_spec(spec: ReactionSpec, attacker_name: String = "?", label: String = "Attack") -> ReactionReadout:
	var readout := ReactionReadout.new()
	readout.attacker_name = attacker_name
	readout.label = label
	readout.auto_brace = spec.auto_brace
	readout.pause_before = spec.pause_before
	for reaction in REACTIONS:
		var reaction_row := Row.new()
		reaction_row.reaction = reaction
		reaction_row.name = EnumText.reaction(reaction)
		reaction_row.key_action = KEYS[reaction]
		reaction_row.allowed = spec.is_allowed(reaction)
		reaction_row.window_ms = spec.window_for(reaction)
		if not reaction_row.allowed:
			reaction_row.unavailable_text = "This attack cannot be %s" % _past(reaction)
		readout.rows.append(reaction_row)
	readout.assist_text = _assist_text(readout)
	return readout


func row(reaction: Enums.ReactionType) -> Row:
	for candidate in rows:
		if candidate.reaction == reaction:
			return candidate
	return null


func allowed_names() -> PackedStringArray:
	var names := PackedStringArray()
	for candidate in rows:
		if candidate.allowed:
			names.append(candidate.name)
	return names


static func _assist_text(readout: ReactionReadout) -> String:
	if not readout.auto_brace:
		return ""
	if readout.row(Enums.ReactionType.BRACE).allowed:
		return "Auto-Brace: if you don't press, you Brace automatically."
	var manual := readout.allowed_names()
	return "Manual %s required: this attack cannot be Braced, so auto-Brace does nothing." % " or ".join(manual)


static func _negate_text(success_multiplier: float) -> String:
	if success_multiplier <= 0.0:
		return "No damage"
	return "%d%% damage" % roundi(success_multiplier * 100.0)


static func _brace_text(ctx: BattleContext, attacker: BattleUnit, defenders: Array[BattleUnit],
		action: EnemyActionDefinition) -> String:
	var low := 100
	var high := 0
	for defender in defenders:
		var rc := RuleContext.make(Enums.TriggerType.REACTION, attacker, defender, action)
		var multiplier := ReactionRules.damage_multiplier(ctx, defender, ReactionResult.make(Enums.ReactionType.BRACE, true), rc)
		var reduction := roundi((1.0 - multiplier) * 100.0)
		low = mini(low, reduction)
		high = maxi(high, reduction)
	if defenders.is_empty():
		low = roundi((1.0 - ctx.balance.brace_damage_multiplier) * 100.0)
		high = low
	return "%d%%" % low if low == high else "%d–%d%%" % [low, high]


static func _parry_stagger_text(ctx: BattleContext, attacker: BattleUnit, defenders: Array[BattleUnit],
		action: EnemyActionDefinition) -> String:
	var low := INF
	var high := -INF
	for defender in defenders:
		var rc := RuleContext.make(Enums.TriggerType.REACTION, attacker, defender, action)
		var amount := ModifierQuery.apply(ctx, Enums.ModifierStat.PARRY_STAGGER, ctx.balance.parry_stagger, defender, rc)
		low = minf(low, amount)
		high = maxf(high, amount)
	if defenders.is_empty():
		low = ctx.balance.parry_stagger
		high = low
	return "%d" % roundi(low) if is_equal_approx(low, high) else "%d–%d" % [roundi(low), roundi(high)]


static func _past(reaction: Enums.ReactionType) -> String:
	match reaction:
		Enums.ReactionType.BRACE:
			return "Braced"
		Enums.ReactionType.EVADE:
			return "Evaded"
	return "Parried"
