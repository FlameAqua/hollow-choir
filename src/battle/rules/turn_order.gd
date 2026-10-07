class_name TurnOrder
extends RefCounted
## Round-based initiative (DECISION_LOG D-003). Every living unit acts once per round, ordered by
## live Tempo (descending). Ties: party before enemies, then lower unit id. Delayed units go last.


static func compute(ctx: BattleContext) -> Array[int]:
	return _ordered(ctx, ctx.state.round, ctx.state.living_units(), true)


## Projected order of the next round, for the timeline (does not consume delay flags).
static func forecast_next_round(ctx: BattleContext) -> Array[int]:
	return _ordered(ctx, ctx.state.round + 1, ctx.state.living_units(), false)


static func _ordered(ctx: BattleContext, round_number: int, units: Array[BattleUnit],
		consume_delays: bool) -> Array[int]:
	var party_first := round_number == 1 and ctx.state.advantage == Enums.Advantage.PARTY_AMBUSH
	var enemies_first := round_number == 1 and ctx.state.advantage == Enums.Advantage.ENEMY_AMBUSH
	var entries: Array[Dictionary] = []
	for unit in units:
		entries.append({
			"uid": unit.uid,
			"delayed": unit.delayed_next_round,
			"group": _group(unit, party_first, enemies_first),
			"tempo": Stats.tempo(ctx, unit),
			"side": int(unit.side),
		})
	entries.sort_custom(_before)
	var result: Array[int] = []
	for entry in entries:
		result.append(entry.uid)
	if consume_delays:
		for unit in units:
			unit.delayed_next_round = false
	return result


static func _group(unit: BattleUnit, party_first: bool, enemies_first: bool) -> int:
	if party_first:
		return 0 if unit.side == Enums.Side.PLAYER else 1
	if enemies_first:
		return 0 if unit.side == Enums.Side.ENEMY else 1
	return 0


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.delayed != b.delayed:
		return not a.delayed
	if a.group != b.group:
		return a.group < b.group
	if not is_equal_approx(a.tempo, b.tempo):
		return a.tempo > b.tempo
	if a.side != b.side:
		return a.side < b.side
	return a.uid < b.uid


## Moves the unit's pending activation to the end of this round; if it already acted (or is
## acting now) it will act last next round instead.
static func delay(ctx: BattleContext, unit: BattleUnit) -> void:
	var order := ctx.state.turn_order
	var position := order.find(unit.uid)
	if position > ctx.state.turn_index:
		order.remove_at(position)
		order.append(unit.uid)
	else:
		unit.delayed_next_round = true
	ctx.emit(BattleEvent.new(BattleEvent.Type.DELAYED, unit.uid))
