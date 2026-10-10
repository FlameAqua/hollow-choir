class_name PresentationLedger
extends RefCounted
## What the player has *seen* so far, per unit: HP, Stagger (Break), Focus, statuses, buffs, cover,
## Broken, exposed weak point and life (playtest revision: Break and Broken for party members too), plus the familiar's readiness this round, the active battlefield
## conditions and the next-round forecast (DECISION_LOG D-013, M1.1 F3). The engine resolves a whole
## step before presentation sees it, so widgets must not read live unit state while a batch plays:
## they read this ledger, which is snapshotted from the engine at every reconcile and advanced by
## each event as it plays.
##
## Status and buff countdowns have no event of their own: they are snapped from the engine at the
## bearer's TURN_ENDED (or the Bleed tick that spends a charge), and only when no later event in the
## same batch touches that status, so a future application never shows early. The forecast has no
## event either: it is only computed at stable points (see [method displayed_forecast]).


class DisplayStatus:
	extends RefCounted
	var status: Enums.StatusId = Enums.StatusId.NONE
	var stacks: int = 1
	var remaining: int = 0
	var definition: StatusDefinition


class DisplayBuff:
	extends RefCounted
	var name: String = ""
	var definition: BuffDefinition
	var remaining: int = 0


class UnitDisplay:
	extends RefCounted
	var uid: int = -1
	var hp: float = 0.0
	var max_hp: int = 1
	## The unit's Break meter as shown. Enemies always have one; since the playtest revision each
	## controlled party member has its own (has_break). STAGGER_DAMAGE, BROKEN and RECOVERED events
	## advance it for either side; a renderer only draws these values.
	var stagger: float = 0.0
	var max_stagger: float = 0.0
	var has_break: bool = false
	var focus: int = 0
	var max_focus: int = 0
	var statuses: Array[DisplayStatus] = []
	var buffs: Array[DisplayBuff] = []
	var covered_by: int = -1
	var covering: int = -1
	var broken: bool = false
	var weak_point: bool = false
	var alive: bool = true

	func status(id: Enums.StatusId) -> DisplayStatus:
		for entry in statuses:
			if entry.status == id:
				return entry
		return null

	func buff(name: String) -> DisplayBuff:
		for entry in buffs:
			if entry.name == name:
				return entry
		return null


var units: Dictionary[int, UnitDisplay] = {}
var round: int = 0
## Times the familiar's trigger fired this round, and its per-round limit (0 = unlimited).
var familiar_uses: int = 0
var familiar_limit: int = 0
## Battlefield conditions announced so far (CONDITION_ADDED / CONDITION_REMOVED), in order.
var conditions: Array[BattlefieldConditionDefinition] = []
## Next-round order at the last stable point, and the round it was computed in.
var forecast: Array[int] = []
var forecast_round: int = 0
var _familiar_name: String = ""
var _last_touch: Dictionary[String, int] = {}


func unit(uid: int) -> UnitDisplay:
	return units.get(uid)


## Copies the engine's real state (battle start and every batch end).
func snapshot(engine: BattleEngine) -> void:
	var state := engine.get_state()
	round = state.round
	for battle_unit in state.units:
		var display := UnitDisplay.new()
		display.uid = battle_unit.uid
		display.hp = battle_unit.hp
		display.max_hp = battle_unit.max_hp
		display.stagger = battle_unit.stagger
		display.max_stagger = battle_unit.max_stagger
		display.has_break = battle_unit.has_break_meter()
		display.focus = battle_unit.focus
		display.max_focus = Stats.max_focus(engine.ctx, battle_unit)
		display.covered_by = battle_unit.intercepted_by
		display.covering = battle_unit.intercepting_for
		display.broken = battle_unit.is_broken()
		display.weak_point = battle_unit.is_weak_point_exposed()
		display.alive = battle_unit.is_alive()
		for instance in battle_unit.statuses:
			var entry := DisplayStatus.new()
			entry.status = instance.status
			entry.stacks = instance.stacks
			entry.remaining = instance.remaining
			entry.definition = instance.definition
			display.statuses.append(entry)
		for instance in battle_unit.buffs:
			var buff := DisplayBuff.new()
			buff.name = instance.definition.display_name
			buff.definition = instance.definition
			buff.remaining = instance.remaining
			display.buffs.append(buff)
		units[battle_unit.uid] = display
	conditions.clear()
	for active in state.conditions:
		conditions.append(active.definition)
	forecast = engine.forecast_next_round()
	forecast_round = state.round
	_snapshot_familiar(engine)


## Call before playing [param events]; remembers the last event touching each status / buff.
func begin_batch(events: Array[BattleEvent]) -> void:
	_last_touch.clear()
	for index in events.size():
		var key := _touch_key(events[index])
		if not key.is_empty():
			_last_touch[key] = index


## Advances the ledger by one event (index into the batch given to begin_batch).
func apply(event: BattleEvent, index: int, engine: BattleEngine) -> void:
	var T := BattleEvent.Type
	var display := unit(event.subject)
	match event.type:
		T.ROUND_STARTED:
			round = int(event.amount)
			familiar_uses = 0
		T.DAMAGE:
			if display != null:
				display.hp = maxf(0.0, display.hp - event.amount)
				# A charge-based status (Bleed) spends its charge when it hurts.
				var entry := display.status(event.status) if event.status != Enums.StatusId.NONE else null
				if entry != null and entry.definition != null and entry.definition.duration_mode == Enums.DurationMode.CHARGES:
					_snap_status(display, event.status, index, engine)
		T.HEAL:
			if display != null:
				display.hp = minf(float(display.max_hp), display.hp + event.amount)
		T.FOCUS_CHANGED:
			if display != null:
				display.focus = int(event.amount2)
		T.STAGGER_DAMAGE:
			if display != null:
				display.stagger = event.amount2
		T.BROKEN:
			if display != null:
				display.broken = true
				display.stagger = 0.0
		T.RECOVERED:
			if display != null:
				display.broken = false
				var live := engine.get_unit(event.subject)
				if live != null:
					display.max_stagger = live.max_stagger
				display.stagger = display.max_stagger
		T.WEAK_POINT_EXPOSED:
			if display != null:
				display.weak_point = true
		T.WEAK_POINT_CLOSED:
			if display != null:
				display.weak_point = false
		T.STATUS_APPLIED:
			if display != null:
				var entry := display.status(event.status)
				if entry == null:
					entry = DisplayStatus.new()
					entry.status = event.status
					entry.definition = engine.ctx.library.status_def(event.status)
					display.statuses.append(entry)
				entry.stacks = int(event.amount)
				entry.remaining = int(event.amount2)
		T.STATUS_REMOVED:
			if display != null:
				var entry := display.status(event.status)
				if entry != null:
					display.statuses.erase(entry)
		T.STATUS_EXTENDED:
			if display != null:
				var entry := display.status(event.status)
				if entry != null:
					entry.remaining = int(event.amount2)
		T.BUFF_APPLIED:
			if display != null:
				var buff := display.buff(event.text)
				if buff == null:
					buff = DisplayBuff.new()
					buff.name = event.text
					display.buffs.append(buff)
				var live_buff := _live_buff(engine, event.subject, event.text)
				if live_buff != null:
					buff.definition = live_buff.definition
					buff.remaining = live_buff.remaining
				elif buff.definition == null:
					buff.definition = _buff_definition(event.text)
					buff.remaining = buff.definition.duration if buff.definition != null else 1
		T.BUFF_EXPIRED:
			if display != null:
				var buff := display.buff(event.text)
				if buff != null:
					display.buffs.erase(buff)
		T.COVER_STARTED:
			if display != null:
				display.covering = event.other
			var protected_unit := unit(event.other)
			if protected_unit != null:
				protected_unit.covered_by = event.subject
		T.COVER_ENDED:
			if display != null and display.covering == event.other:
				display.covering = -1
			var protected_unit := unit(event.other)
			if protected_unit != null and protected_unit.covered_by == event.subject:
				protected_unit.covered_by = -1
		T.UNIT_DEFEATED:
			if display != null:
				display.alive = false
				display.hp = 0.0
		T.TURN_ENDED:
			if display != null:
				for entry in display.statuses.duplicate():
					_snap_status(display, entry.status, index, engine)
				for buff in display.buffs:
					if _last_touch.get("b:%d:%s" % [display.uid, buff.name], -1) < index:
						var live_buff := _live_buff(engine, display.uid, buff.name)
						if live_buff != null:
							buff.remaining = live_buff.remaining
		T.TRIGGER_ACTIVATED:
			if not _familiar_name.is_empty() and event.text == _familiar_name:
				familiar_uses += 1
		T.CONDITION_ADDED:
			var added := _condition_named(engine, event.text)
			if added != null and not conditions.has(added):
				conditions.append(added)
		T.CONDITION_REMOVED:
			for position in range(conditions.size() - 1, -1, -1):
				if conditions[position].display_name == event.text:
					conditions.remove_at(position)


## "Ready this round" while the familiar can still fire this round.
func familiar_ready() -> bool:
	return familiar_limit <= 0 or familiar_uses < familiar_limit


## The next-round order the player may see: the last stable point's forecast without the units
## since shown defeated. Empty once a new round has started on screen, because that forecast now
## describes the current round; the next stable point computes the following one.
func displayed_forecast() -> Array[int]:
	var result: Array[int] = []
	if round != forecast_round:
		return result
	for uid in forecast:
		var display := unit(uid)
		if display == null or display.alive:
			result.append(uid)
	return result


func _snapshot_familiar(engine: BattleEngine) -> void:
	var familiar := engine.get_state().familiar
	# The passive in effect this battle (the loadout's selected one, else the familiar's default).
	var passive := engine.get_state().familiar_trait
	familiar_uses = 0
	familiar_limit = 0
	_familiar_name = ""
	if familiar == null or passive == null:
		return
	_familiar_name = familiar.display_name
	var unlimited := false
	for trigger in passive.triggers:
		if trigger == null:
			continue
		if trigger.max_per_round <= 0:
			unlimited = true
		familiar_limit += trigger.max_per_round
	if unlimited:
		familiar_limit = 0
	var owner := engine.get_state().protagonist()
	if owner == null:
		return
	for instance in owner.traits:
		if instance.trait_def == passive:
			for trigger_index in passive.triggers.size():
				familiar_uses += instance.fired_this_round(trigger_index)


## Copies a status countdown from the engine once no later event in this batch touches it.
func _snap_status(display: UnitDisplay, status: Enums.StatusId, index: int, engine: BattleEngine) -> void:
	if _last_touch.get("s:%d:%d" % [display.uid, status], -1) > index:
		return
	var entry := display.status(status)
	var live := engine.get_unit(display.uid)
	if entry == null or live == null:
		return
	var instance := live.get_status(status)
	if instance != null:
		entry.remaining = instance.remaining
		entry.stacks = instance.stacks


static func _touch_key(event: BattleEvent) -> String:
	var T := BattleEvent.Type
	match event.type:
		T.STATUS_APPLIED, T.STATUS_REMOVED, T.STATUS_EXTENDED, T.STATUS_BLOCKED:
			return "s:%d:%d" % [event.subject, event.status]
		T.DAMAGE:
			if event.status != Enums.StatusId.NONE:
				return "s:%d:%d" % [event.subject, event.status]
		T.BUFF_APPLIED, T.BUFF_EXPIRED:
			return "b:%d:%s" % [event.subject, event.text]
	return ""


static func _live_buff(engine: BattleEngine, uid: int, name: String) -> BuffInstance:
	var live := engine.get_unit(uid)
	if live == null:
		return null
	for instance in live.buffs:
		if instance.definition.display_name == name:
			return instance
	return null


static func _buff_definition(name: String) -> BuffDefinition:
	for definition: BuffDefinition in Database.registry.buffs.values():
		if definition.display_name == name:
			return definition
	return null


## The condition a CONDITION_ADDED event names: the live one when it is still active, otherwise the
## registered definition (it may have been replaced again later in the same batch).
static func _condition_named(engine: BattleEngine, name: String) -> BattlefieldConditionDefinition:
	for active in engine.get_state().conditions:
		if active.definition.display_name == name:
			return active.definition
	for definition: BattlefieldConditionDefinition in Database.registry.conditions.values():
		if definition.display_name == name:
			return definition
	return null
