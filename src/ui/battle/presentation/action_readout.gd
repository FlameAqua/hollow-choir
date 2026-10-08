class_name ActionReadout
extends RefCounted
## Knowledge-filtered view of the player's selected action (M1.1 F1, the brief's "typed adapter").
## Built from the engine's exact ActionPreview for every affected target; a quantity the player has
## not learned is *absent* (has_numbers false), never zero, a guess or "?". Unknown affinity on one
## target never hides what is known about another, and nothing is ever summed across targets.
## Building a readout is pure: it consumes no RNG and changes no state.

enum Scope { NONE = 0, DIRECT_HIT = 1, PER_TARGET = 2, SELF = 3, ALLY = 4, BATTLEFIELD = 5 }
## Break / kill claims: made only when the minimum roll at the stated grade proves them.
enum Claim { NONE = 0, ANY_GRADE = 1, GOOD_OR_BETTER = 2, PERFECT_ONLY = 3, POSSIBLE = 4 }

const MISS := Enums.ExecutionGrade.MISS
const GOOD := Enums.ExecutionGrade.GOOD
const PERFECT := Enums.ExecutionGrade.PERFECT


## One affected unit.
class TargetRow:
	extends RefCounted
	var uid: int = -1
	var name: String = ""
	## The unit that was chosen when Intercept cover redirects the hit to [member uid]; else -1.
	var chosen_uid: int = -1
	var chosen_name: String = ""
	var is_enemy: bool = false
	var research: Enums.ResearchLevel = Enums.ResearchLevel.MASTERED
	var deals_damage: bool = false
	var affinity_known: bool = true
	## Exact per-grade damage and Stagger; only meaningful when true.
	var has_numbers: bool = false
	var damage_min: Array[int] = [0, 0, 0]
	var damage_max: Array[int] = [0, 0, 0]
	var stagger: Array[float] = [0.0, 0.0, 0.0]
	var weakness: bool = false
	var resisted: bool = false
	var heal: Array[int] = [0, 0, 0]
	## Public state (visible on the stage).
	var weak_point: bool = false
	var broken: bool = false
	var hp: int = 0
	var stagger_remaining: float = 0.0
	var break_claim: Claim = Claim.NONE
	var kill_claim: Claim = Claim.NONE
	## Statuses this action applies that would be doused on this target, and what douses them.
	var doused: Array[Enums.StatusId] = []
	var doused_by: Array[Enums.StatusId] = []


var actor_uid: int = -1
var actor_name: String = ""
var action: ActionDefinition
var label: String = ""
var category_text: String = ""
var description: String = ""
var details: String = ""
var focus_cost: int = 0
## Potion charges left (-1 = not an item).
var item_charges: int = -1
var legal: bool = true
## Why it cannot be used, e.g. "Needs 3 Focus · have 2".
var reason: String = ""
var scope: Scope = Scope.NONE
var damage_type: Enums.DamageType = Enums.DamageType.NONE
var targets: Array[TargetRow] = []
var statuses: Array[RuleNotes.StatusNote] = []
var support_effects: Array[RuleNotes.SupportNote] = []
## Focus from timing and the action's own flat effects (public), per grade.
var focus_timing: Array[int] = [0, 0, 0]
## Weakness Focus (granted once per action), only when an affected target is known to be weak.
var focus_weakness: int = 0
## An affinity bonus might apply but the player has not learned the affinity.
var focus_affinity_unknown: bool = false
## Focus that still fits after paying the cost (Focus at cap).
var focus_room: int = 0
var command_type: Enums.ActionCommandType = Enums.ActionCommandType.NONE
var good_window_ms: float = 0.0
var perfect_window_ms: float = 0.0
var beat_count: int = 0
## Lowest grade the battle's Execution Assist allows (claims use it).
var grade_floor: Enums.ExecutionGrade = Enums.ExecutionGrade.MISS
var tags: PackedStringArray = PackedStringArray()
## Good-grade formula lines; only for a single target whose affinity is known.
var breakdown: PackedStringArray = PackedStringArray()


## [param chosen_target]: the target the player is pointing at (-1 = the default for the action).
static func build(engine: BattleEngine, actor_uid: int, option: ActionOption, chosen_target: int = -1) -> ActionReadout:
	var readout := ActionReadout.new()
	var ctx := engine.ctx
	var actor := engine.get_unit(actor_uid)
	var action := option.action
	readout.actor_uid = actor_uid
	readout.actor_name = actor.display_name if actor != null else ""
	readout.action = action
	readout.label = BattleKnowledge.action_label(engine, actor, action)
	readout.category_text = EnumText.category(action.category)
	readout.description = action.description
	readout.details = action.details
	readout.focus_cost = action.focus_cost
	if option.item_slot >= 0 and option.item_slot < engine.get_state().potion_slots.size():
		var slot := engine.get_state().potion_slots[option.item_slot]
		readout.label = slot.potion.display_name
		readout.description = slot.potion.description if not slot.potion.description.is_empty() else action.description
		readout.item_charges = slot.charges
	readout.legal = option.legal
	readout.reason = reason_text(actor, option)
	readout.scope = scope_for(action)
	readout.damage_type = DamageCalculator.resolve_damage_type(actor, action)
	readout.statuses = RuleNotes.applied_statuses(action)
	if not action.deals_damage():
		readout.support_effects = RuleNotes.support_effects(action)
	readout.grade_floor = ctx.assist.minimum_grade
	for tag in action.tags:
		readout.tags.append(String(Enums.ActionTag.keys()[tag]).capitalize())
	var spec := CommandRules.build_spec(ctx, actor, action)
	readout.command_type = spec.type
	if spec.type != Enums.ActionCommandType.NONE:
		readout.good_window_ms = spec.good_window_ms
		readout.perfect_window_ms = spec.perfect_window_ms
		readout.beat_count = spec.beat_count if spec.type == Enums.ActionCommandType.RHYTHM else 0
	if actor == null:
		return readout
	var first_preview: ActionPreview = null
	for target in _affected(engine, actor, option, chosen_target):
		var preview := PreviewRules.preview_action(ctx, actor, action, target)
		if first_preview == null:
			first_preview = preview
		readout.targets.append(_row(engine, readout, preview))
	if first_preview == null:
		first_preview = PreviewRules.preview_action(ctx, actor, action, null)
	_focus(engine, readout, actor, first_preview)
	if readout.targets.size() == 1 and readout.targets[0].has_numbers and readout.targets[0].deals_damage:
		readout.breakdown = first_preview.breakdown
	return readout


static func scope_for(action: ActionDefinition) -> Scope:
	match action.target_rule:
		Enums.TargetRule.SINGLE_ENEMY:
			return Scope.DIRECT_HIT
		Enums.TargetRule.ALL_ENEMIES, Enums.TargetRule.ALL_ALLIES:
			return Scope.PER_TARGET
		Enums.TargetRule.SELF:
			return Scope.SELF
		Enums.TargetRule.SINGLE_ALLY, Enums.TargetRule.OTHER_ALLY:
			return Scope.ALLY
	return Scope.BATTLEFIELD


static func reason_text(actor: BattleUnit, option: ActionOption) -> String:
	if option.legal:
		return ""
	if actor != null and actor.focus < option.action.focus_cost:
		return "Needs %d Focus · have %d" % [option.action.focus_cost, actor.focus]
	return option.reason


## True when any number on any row is hidden by unknown affinity.
func has_hidden_numbers() -> bool:
	for row in targets:
		if row.deals_damage and not row.has_numbers:
			return true
	return false


func deals_damage() -> bool:
	return action != null and action.deals_damage()


## The units this action would affect, in stage order, for the chosen target.
static func _affected(engine: BattleEngine, actor: BattleUnit, option: ActionOption, chosen: int) -> Array[BattleUnit]:
	var ctx := engine.ctx
	var action := option.action
	var result: Array[BattleUnit] = []
	if action.needs_target_choice():
		var target := engine.get_unit(chosen)
		if target == null or not option.target_uids.has(chosen):
			target = engine.get_unit(option.target_uids[0]) if not option.target_uids.is_empty() else null
		if target != null:
			result.append(target)
	elif action.target_rule != Enums.TargetRule.NONE:
		result = ActionRules.valid_targets(ctx, actor, action)
	return result


static func _row(engine: BattleEngine, readout: ActionReadout, preview: ActionPreview) -> TargetRow:
	var ctx := engine.ctx
	var row := TargetRow.new()
	var target := engine.get_unit(preview.target_uid)
	row.uid = preview.target_uid
	row.name = target.display_name if target != null else ""
	if preview.redirected_from >= 0:
		row.chosen_uid = preview.redirected_from
		row.chosen_name = BattleKnowledge.unit_name(engine, preview.redirected_from)
	if target == null:
		return row
	row.is_enemy = target.is_enemy()
	row.research = BattleKnowledge.level(engine, target)
	row.weak_point = target.is_weak_point_exposed()
	row.broken = target.is_broken()
	row.hp = target.hp
	row.stagger_remaining = target.stagger
	row.deals_damage = preview.deals_damage
	row.affinity_known = BattleKnowledge.knows_affinity(engine, target, preview.damage_type)
	for grade in [MISS, GOOD, PERFECT]:
		row.heal[grade] = preview.heal[grade]
	if row.deals_damage and row.affinity_known:
		row.has_numbers = true
		row.damage_min = preview.damage_min.duplicate()
		row.damage_max = preview.damage_max.duplicate()
		row.stagger = preview.stagger.duplicate()
		row.weakness = preview.is_weakness
		row.resisted = preview.is_resisted
		var grades := attainable_grades(readout)
		row.kill_claim = _claim(row.damage_min, row.damage_max, float(target.hp), grades)
		if target.is_enemy() and not target.is_broken() and row.kill_claim != Claim.ANY_GRADE:
			row.break_claim = _claim(row.stagger, row.stagger, target.stagger, grades)
	for note in readout.statuses:
		if note.recipient != Enums.EffectTarget.TARGET:
			continue
		var blocker := RuleNotes.dousing_status(ctx.library, target, note.status)
		if blocker != Enums.StatusId.NONE:
			row.doused.append(note.status)
			row.doused_by.append(blocker)
	return row


## Grades the player can actually end up with, lowest first: actions without a command always
## resolve at Good, and Execution Assist may raise the floor.
static func attainable_grades(readout: ActionReadout) -> Array[Enums.ExecutionGrade]:
	if readout.command_type == Enums.ActionCommandType.NONE:
		return [GOOD] as Array[Enums.ExecutionGrade]
	var grades: Array[Enums.ExecutionGrade] = []
	for grade: Enums.ExecutionGrade in [MISS, GOOD, PERFECT]:
		if grade >= readout.grade_floor:
			grades.append(grade)
	return grades


## A claim needs the *minimum* roll at a grade to reach the threshold; a maximum roll that reaches
## it only makes the outcome possible.
static func _claim(minimum: Array, maximum: Array, threshold: float, grades: Array[Enums.ExecutionGrade]) -> Claim:
	if threshold <= 0.0 or grades.is_empty():
		return Claim.NONE
	if float(minimum[grades[0]]) >= threshold:
		return Claim.ANY_GRADE
	for grade in grades:
		if float(minimum[grade]) >= threshold:
			return Claim.GOOD_OR_BETTER if grade == GOOD else Claim.PERFECT_ONLY
	return Claim.POSSIBLE if float(maximum[grades[-1]]) >= threshold else Claim.NONE


static func _focus(engine: BattleEngine, readout: ActionReadout, actor: BattleUnit, preview: ActionPreview) -> void:
	var balance := engine.ctx.balance
	var weakness_part := balance.weakness_focus if preview.is_weakness else 0
	for grade in [MISS, GOOD, PERFECT]:
		readout.focus_timing[grade] = maxi(0, preview.focus_gain[grade] - weakness_part)
	if readout.deals_damage():
		for row in readout.targets:
			if not row.is_enemy:
				continue
			if not row.affinity_known:
				readout.focus_affinity_unknown = true
			elif row.weakness:
				readout.focus_weakness = balance.weakness_focus
	readout.focus_room = maxi(0, Stats.max_focus(engine.ctx, actor) - (actor.focus - readout.focus_cost))
