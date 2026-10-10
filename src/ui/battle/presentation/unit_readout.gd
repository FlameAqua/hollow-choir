class_name UnitReadout
extends RefCounted
## Structured, filtered inspection. Mutable combat facts come only from the presentation ledger.
var title := ""
var enemy := false
var role := ""
var knowledge := ""
var alive := true
var hp := 0
var max_hp := 1
var resource := 0
var max_resource := 0
var broken := false
## Playtest revision: the unit's own Break meter as displayed (enemies and party members). resource /
## max_resource keep their meaning: an enemy's Break, a party member's Focus.
var has_break := false
var break_current := 0
var break_max := 0
var weak_point := ""
var exposed := false
var affinities: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var notes := PackedStringArray()
var intent: IntentReadout

static func build(engine: BattleEngine, unit: BattleUnit, display: PresentationLedger.UnitDisplay,
		declared: IntentReadout, planning: bool) -> UnitReadout:
	var r := UnitReadout.new()
	r.title = unit.display_name
	r.enemy = unit.is_enemy()
	if display == null:
		return r
	r.alive = display.alive
	r.hp = roundi(display.hp)
	r.max_hp = display.max_hp
	r.resource = roundi(display.stagger) if r.enemy else display.focus
	r.max_resource = roundi(display.max_stagger) if r.enemy else display.max_focus
	r.broken = display.broken
	r.has_break = display.has_break
	r.break_current = roundi(display.stagger)
	r.break_max = roundi(display.max_stagger)
	r.exposed = display.weak_point
	r.intent = declared
	for status in display.statuses:
		r.effects.append({"icon": CombatIcons.mapping("statuses", status.status), "name": EnumText.status(status.status),
			"value": UnitDetails.remaining_text(status.definition, status.remaining),
			"text": status.definition.description if status.definition != null else ""})
	for buff in display.buffs:
		r.effects.append({"icon": CombatIcons.mapping("buffs", buff.definition.id if buff.definition != null else ""),
			"name": buff.name, "value": "%d turns" % buff.remaining,
			"text": buff.definition.description if buff.definition != null else ""})
	if display.covered_by >= 0:
		r.notes.append("Covered by " + BattleKnowledge.unit_name(engine, display.covered_by))
	elif display.covering >= 0:
		r.notes.append("Covering " + BattleKnowledge.unit_name(engine, display.covering))
	if not r.enemy:
		r.role = EnumText.family(unit.weapon_family)
		return r
	var definition := unit.enemy_def()
	r.role = (UnitDetails.TIER_WORDS[definition.tier] + " " + EnumText.role(definition.role)).strip_edges()
	# Research can advance ahead of playback. Only query it at a stable planning point.
	if not planning:
		return r
	r.knowledge = EnumText.research_level(BattleKnowledge.level(engine, unit))
	if definition.has_weak_point:
		r.weak_point = definition.weak_point_name
	for type in UnitDetails.AFFINITY_TYPES:
		var category := "Unknown"
		if BattleKnowledge.knows_affinity(engine, unit, type):
			category = "Weakness" if definition.is_weak_to(type) else "Resistance" if definition.resists(type) else "Normal damage"
		r.affinities.append({"type": type, "category": category})
	if BattleKnowledge.knows_traits(engine, unit):
		for status in definition.status_immunities:
			r.notes.append("Immune to " + EnumText.status(status))
		for trait_def in definition.traits:
			if trait_def != null and not trait_def.description.is_empty():
				r.notes.append(trait_def.display_name + ": " + trait_def.description)
	if BattleKnowledge.knows_tendencies(engine, unit) and not definition.ai_tendencies.is_empty():
		r.notes.append("Tendencies: " + definition.ai_tendencies)
	return r

## Every field this readout can show, as plain text. The inspector re-renders the card whenever this
## changes, so a new cover note, effect or declared move can never leave a stale card on screen.
func plain_text() -> String:
	var lines := PackedStringArray([title])
	if not alive:
		lines.append("Defeated")
		return "\n".join(lines)
	if not role.is_empty():
		lines.append(role)
	if not knowledge.is_empty():
		lines.append("Knowledge: " + knowledge)
	lines.append("Health %d / %d" % [hp, max_hp])
	if enemy:
		lines.append("Break remaining " + ("Broken" if broken else "%d / %d" % [resource, max_resource]))
	else:
		lines.append("Focus %d / %d" % [resource, max_resource])
		if has_break:
			lines.append("Break remaining " + ("Broken" if broken else "%d / %d" % [break_current, break_max]))
	if not weak_point.is_empty():
		lines.append("Weak point: %s · %s" % [weak_point, "Exposed" if exposed else "Covered"])
	for affinity in affinities:
		lines.append("%s: %s" % [EnumText.damage_type(affinity.type), affinity.category])
	for effect in effects:
		lines.append("%s · %s" % [effect.name, effect.value])
	lines.append_array(notes)
	if intent != null:
		var damage := PackedStringArray()
		for uid in intent.target_uids:
			damage.append(intent.damage_text(uid))
		lines.append("Declared move: %s → %s · %s · %s" % [intent.label, intent.target_text, intent.threat_word, ", ".join(damage)])
	return "\n".join(lines)
